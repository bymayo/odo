import Foundation

class StravaAPI {
    func fetchActivities(year: Int, accessToken: String) async throws -> [StravaActivity] {
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

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                if http.statusCode == 429 {
                    let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { Int($0) }
                    throw StravaError.rateLimited(retryAfter: retryAfter)
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    throw StravaError.apiError(message)
                }
                throw StravaError.apiError("HTTP \(http.statusCode)")
            }

            let activities = try JSONDecoder().decode([StravaActivity].self, from: data)
            allActivities.append(contentsOf: activities)

            if activities.count < perPage { break }
            page += 1
        }

        return allActivities
    }
}
