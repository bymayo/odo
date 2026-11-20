import Foundation

/// Strava's rate limit usage, read from the headers on every API response.
///
/// Strava sends two pairs of headers, each as "15-minute,daily":
/// `X-RateLimit-*` counts every request, `X-ReadRateLimit-*` counts reads.
/// Odo only reads, so whichever pair is closer to its limit is the one that
/// matters. The 15-minute window resets at :00, :15, :30 and :45; the daily
/// one at midnight UTC.
struct RateLimit: Equatable {
    var shortUsage: Int
    var shortLimit: Int
    var dailyUsage: Int
    var dailyLimit: Int
    var observedAt: Date

    init?(headers http: HTTPURLResponse, at date: Date = Date()) {
        func pair(_ name: String) -> (Int, Int)? {
            guard let raw = http.value(forHTTPHeaderField: name) else { return nil }
            let parts = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        }

        var candidates: [(usage: (Int, Int), limit: (Int, Int))] = []
        if let u = pair("X-RateLimit-Usage"), let l = pair("X-RateLimit-Limit") { candidates.append((u, l)) }
        if let u = pair("X-ReadRateLimit-Usage"), let l = pair("X-ReadRateLimit-Limit") { candidates.append((u, l)) }
        guard !candidates.isEmpty else { return nil }

        // Take the tightest of each window across the two pairs
        func ratio(_ used: Int, _ limit: Int) -> Double { limit > 0 ? Double(used) / Double(limit) : 0 }
        let short = candidates.max { ratio($0.usage.0, $0.limit.0) < ratio($1.usage.0, $1.limit.0) }!
        let daily = candidates.max { ratio($0.usage.1, $0.limit.1) < ratio($1.usage.1, $1.limit.1) }!

        shortUsage = short.usage.0
        shortLimit = short.limit.0
        dailyUsage = daily.usage.1
        dailyLimit = daily.limit.1
        observedAt = date
    }

    var isDailyExhausted: Bool { dailyLimit > 0 && dailyUsage >= dailyLimit }

    /// When requests can start again after a 429
    var resetsAt: Date {
        isDailyExhausted ? Self.nextMidnightUTC(after: observedAt) : Self.nextQuarterHour(after: observedAt)
    }

    /// "38/100 this 15 min · 212/1,000 today", dropping each count once its window has rolled over
    var summary: String? {
        let now = Date()
        var parts: [String] = []
        if now < Self.nextQuarterHour(after: observedAt) {
            parts.append("\(shortUsage.formatted())/\(shortLimit.formatted()) this 15 min")
        }
        if now < Self.nextMidnightUTC(after: observedAt) {
            parts.append("\(dailyUsage.formatted())/\(dailyLimit.formatted()) today")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func nextQuarterHour(after date: Date) -> Date {
        let quarter: TimeInterval = 15 * 60
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / quarter).rounded(.down) * quarter + quarter)
    }

    static func nextMidnightUTC(after date: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0, second: 0),
                            matchingPolicy: .nextTime) ?? date.addingTimeInterval(86_400)
    }
}

class StravaAPI {
    /// Usage from the most recent response, rate limited or not
    private(set) var lastRateLimit: RateLimit?

    /// Fetches every activity in `year`, a page of 200 at a time.
    /// `onPage` gets the running count after each page.
    func fetchActivities(
        year: Int,
        accessToken: String,
        onPage: @MainActor (Int) -> Void = { _ in }
    ) async throws -> [StravaActivity] {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!

        let after = Int(startOfYear.timeIntervalSince1970)
        let before = Int(endOfYear.timeIntervalSince1970)

        var allActivities: [StravaActivity] = []
        var page = 1
        let perPage = 200

        while true {
            let urlString = "https://www.strava.com/api/v3/athlete/activities"
                + "?after=\(after)&before=\(before)&per_page=\(perPage)&page=\(page)"
            let url = URL(string: urlString)!

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                if let limit = RateLimit(headers: http) { lastRateLimit = limit }

                if http.statusCode != 200 {
                    if http.statusCode == 429 {
                        throw StravaError.rateLimited(resetsAt: lastRateLimit?.resetsAt
                            ?? RateLimit.nextQuarterHour(after: Date()))
                    }
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        throw StravaError.apiError(message)
                    }
                    throw StravaError.apiError("HTTP \(http.statusCode)")
                }
            }

            let activities = try JSONDecoder().decode([StravaActivity].self, from: data)
            allActivities.append(contentsOf: activities)
            await onPage(allActivities.count)

            if activities.count < perPage { break }
            page += 1
        }

        return allActivities
    }
}
