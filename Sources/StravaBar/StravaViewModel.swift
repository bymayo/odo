import Foundation
import SwiftUI

// On-disk cache model
private struct ActivityCache: Codable {
    let activities: [Int: [StravaActivity]]
    let lastUpdated: Date
}

@MainActor
class StravaViewModel: ObservableObject {
    let settings = AppSettings.shared
    private let api = StravaAPI()
    private let auth = StravaAuth()
    private var refreshTimer: Timer?

    @Published var activities: [Int: [StravaActivity]] = [:]
    @Published var isLoading = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var error: String?
    @Published var selectedSport: SportCategory?
    @Published var lastUpdated: Date?
    @Published var detectedSports: [SportCategory] = []
    @Published var availableSports: [SportCategory] = []

    private static var cacheURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("StravaBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("activity_cache.json")
    }

    var isAuthenticated: Bool { settings.isAuthenticated }

    init() {
        loadCache()
        startRefreshTimer()
    }

    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    /// All years that have activity data (sorted descending)
    var yearsWithData: [Int] {
        activities.keys.filter { activities[$0]?.isEmpty == false }.sorted(by: >)
    }

    /// Years to show in the comparison section (respects user selection)
    var visibleComparisonYears: [Int] {
        let previous = yearsWithData.filter { $0 != currentYear }
        if settings.visibleYears.isEmpty {
            return previous
        }
        return previous.filter { settings.visibleYears.contains($0) }
    }

    var currentDayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }

    func statsForYear(_ year: Int, sport: SportCategory) -> YearStats {
        guard let yearActivities = activities[year] else {
            return YearStats(year: year)
        }

        let filtered = yearActivities.filter { sport.matches(sportType: $0.sportType) }

        let calendar = Calendar.current
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]

        // Fallback for dates with fractional seconds
        let iso8601Frac = ISO8601DateFormatter()
        iso8601Frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var stats = YearStats(year: year)

        for activity in filtered {
            let distance = activity.distance * settings.distanceConversion
            let elevation = activity.totalElevationGain * settings.elevationConversion
            let time = Double(activity.movingTime) / 3600.0

            stats.totalDistance += distance
            stats.totalElevation += elevation
            stats.totalTime += time
            stats.activityCount += 1

            if let date = iso8601.date(from: activity.startDate) ?? iso8601Frac.date(from: activity.startDate) {
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 366
                if year == currentYear || dayOfYear <= currentDayOfYear {
                    stats.distanceToDate += distance
                    stats.elevationToDate += elevation
                    stats.timeToDate += time
                    stats.activityCountToDate += 1
                }
            }
        }

        return stats
    }

    var currentYearStats: YearStats {
        guard let sport = selectedSport else { return YearStats(year: currentYear) }
        return statsForYear(currentYear, sport: sport)
    }

    /// The sport used for menu bar display, falling back to first detected
    var menuBarSportCategory: SportCategory? {
        let name = settings.menuBarSport
        if !name.isEmpty && detectedSports.contains(.sport(name)) {
            return .sport(name)
        }
        return detectedSports.first
    }

    var menuBarText: String {
        guard let yearActivities = activities[currentYear],
              let sport = menuBarSportCategory else { return "—" }

        let metric = settings.menuBarMetric
        let filtered = yearActivities.filter { sport.matches(sportType: $0.sportType) }

        let value: Double
        let unit: String
        switch metric {
        case "elevation":
            value = filtered.reduce(0.0) { $0 + $1.totalElevationGain * settings.elevationConversion }
            unit = settings.elevationUnit
        case "time":
            let hours = filtered.reduce(0.0) { $0 + Double($1.movingTime) / 3600.0 }
            var text = formatTime(hours)
            if settings.menuBarShowGoal {
                let goal = settings.goalFor(sport)
                if goal.timeHours > 0 {
                    text = "\(text) / \(formatTime(goal.timeHours))"
                }
            }
            return text
        default:
            value = filtered.reduce(0.0) { $0 + $1.distance * settings.distanceConversion }
            unit = settings.distanceUnit
        }

        var text = "\(formatNumber(value)) \(unit)"

        if settings.menuBarShowGoal {
            let goal = settings.goalFor(sport)
            let goalValue = metric == "elevation" ? goal.elevationFeet : goal.distanceMiles
            if goalValue > 0 {
                text = "\(formatNumber(value)) / \(formatNumber(goalValue)) \(unit)"
            }
        }

        return text
    }

    // MARK: - Cache

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let cache = try? JSONDecoder().decode(ActivityCache.self, from: data) else {
            return
        }
        activities = cache.activities
        lastUpdated = cache.lastUpdated
        updateAvailableSports()
    }

    private func saveCache() {
        let cache = ActivityCache(activities: activities, lastUpdated: lastUpdated ?? Date())
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }

    // MARK: - Refresh Timer

    func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        let minutes = settings.refreshIntervalMinutes
        guard minutes > 0 else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isAuthenticated else { return }
                await self.fetchAllData()
            }
        }
    }

    // MARK: - Data Fetching

    private func ensureValidToken() async throws -> String {
        guard let accessToken = settings.accessToken,
              let refreshToken = settings.refreshToken else {
            throw StravaError.notAuthenticated
        }

        if settings.tokenExpiresAt < Int(Date().timeIntervalSince1970) + 60 {
            let response = try await auth.refreshTokens(
                refreshToken: refreshToken,
                clientId: settings.clientId,
                clientSecret: settings.clientSecret
            )
            settings.saveTokens(response)
            return response.accessToken
        }

        return accessToken
    }

    func fetchAllData() async {
        isLoading = true
        syncStatus = .syncing(year: currentYear, total: 1, completed: 0)
        error = nil

        do {
            let token = try await ensureValidToken()

            // Figure out how many years we need to fetch (uncached past years)
            var yearsToFetch: [Int] = [currentYear]
            var tempEmpty = 0
            for year in stride(from: currentYear - 1, through: 2000, by: -1) {
                if activities[year] != nil {
                    tempEmpty = 0
                    continue
                }
                yearsToFetch.append(year)
                // We can't know if they're empty yet, so estimate conservatively
                tempEmpty += 1
                if tempEmpty >= 3 { break }
            }
            let totalYears = yearsToFetch.count
            var completed = 0

            // Always re-fetch the current year (it's still changing)
            syncStatus = .syncing(year: currentYear, total: totalYears, completed: completed)
            do {
                let yearActivities = try await api.fetchActivities(year: currentYear, accessToken: token)
                activities[currentYear] = yearActivities
                completed += 1
            } catch let err as StravaError {
                if case .rateLimited(let retry) = err {
                    syncStatus = .rateLimited(retryAfter: retry)
                    self.error = err.localizedDescription
                    isLoading = false
                    return
                }
                self.error = "Current year: \(err.localizedDescription)"
                completed += 1
            } catch {
                self.error = "Current year: \(error.localizedDescription)"
                completed += 1
            }

            // For past years, only fetch if not already cached.
            // Walk backwards until we hit 3 consecutive empty years.
            var consecutiveEmpty = 0
            for year in stride(from: currentYear - 1, through: 2000, by: -1) {
                if activities[year] != nil {
                    // Already cached — skip
                    consecutiveEmpty = 0
                    continue
                }

                syncStatus = .syncing(year: year, total: totalYears, completed: completed)

                do {
                    let yearActivities = try await api.fetchActivities(year: year, accessToken: token)
                    completed += 1
                    if yearActivities.isEmpty {
                        consecutiveEmpty += 1
                    } else {
                        activities[year] = yearActivities
                        consecutiveEmpty = 0
                    }
                } catch let err as StravaError {
                    if case .rateLimited(let retry) = err {
                        syncStatus = .rateLimited(retryAfter: retry)
                        self.error = err.localizedDescription
                        // Save what we have so far
                        updateAvailableSports()
                        lastUpdated = Date()
                        saveCache()
                        isLoading = false
                        return
                    }
                    self.error = "\(year): \(err.localizedDescription)"
                    break
                } catch {
                    self.error = "\(year): \(error.localizedDescription)"
                    break
                }

                if consecutiveEmpty >= 3 { break }
            }

            updateAvailableSports()
            prefillGoalsFromLastYear()
            lastUpdated = Date()
            saveCache()
        } catch {
            self.error = error.localizedDescription
        }

        syncStatus = .done
        isLoading = false

        // Clear "done" status after a few seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if syncStatus == .done {
                syncStatus = .idle
            }
        }
    }

    /// Force re-fetch a specific year (clears cache for it first)
    func refetchYear(_ year: Int) async {
        do {
            let token = try await ensureValidToken()
            let yearActivities = try await api.fetchActivities(year: year, accessToken: token)
            if yearActivities.isEmpty {
                activities.removeValue(forKey: year)
            } else {
                activities[year] = yearActivities
            }
            updateAvailableSports()
            saveCache()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateAvailableSports() {
        var sportNames: Set<String> = []
        for yearActivities in activities.values {
            for activity in yearActivities {
                if case .sport(let name) = SportCategory.from(sportType: activity.sportType) {
                    sportNames.insert(name)
                }
            }
        }

        detectedSports = sportNames.sorted().map { .sport($0) }

        var visible: [SportCategory] = []
        for sport in detectedSports {
            if !settings.hiddenSports.contains(sport.rawValue) {
                visible.append(sport)
            }
        }
        availableSports = visible

        // If selectedSport is nil or was hidden, select the first available
        if let selected = selectedSport, availableSports.contains(selected) {
            // keep current selection
        } else {
            selectedSport = availableSports.first
        }
    }

    // MARK: - Goal Suggestions

    /// Returns last year's totals for a sport, to use as suggested goals
    func lastYearStats(for sport: SportCategory) -> YearStats? {
        let lastYear = currentYear - 1
        guard activities[lastYear] != nil else { return nil }
        let stats = statsForYear(lastYear, sport: sport)
        guard stats.activityCount > 0 else { return nil }
        return stats
    }

    /// Pre-fill goals from last year's data for any sport that has no goal set yet
    func prefillGoalsFromLastYear() {
        var changed = false
        for sport in availableSports {
            let existing = settings.goalFor(sport)
            if existing.distanceMiles == 0 && existing.elevationFeet == 0 && existing.timeHours == 0 {
                if let last = lastYearStats(for: sport) {
                    // Round up to a clean number (different rounding for metric vs imperial)
                    let distRound: Double = settings.useMetricUnits ? 100 : 100
                    let elevRound: Double = settings.useMetricUnits ? 500 : 1000
                    let dist = (last.totalDistance / distRound).rounded(.up) * distRound
                    let elev = (last.totalElevation / elevRound).rounded(.up) * elevRound
                    let time = (last.totalTime / 10).rounded(.up) * 10
                    settings.setGoal(SportGoal(distanceMiles: dist, elevationFeet: elev, timeHours: time), for: sport)
                    changed = true
                }
            }
        }
        if changed {
            objectWillChange.send()
        }
    }

    // MARK: - Authentication

    func startAuth() {
        guard settings.isConfigured else { return }

        auth.startCallbackServer { [weak self] code in
            guard let self = self, let code = code else { return }
            Task { @MainActor in
                do {
                    let response = try await self.auth.exchangeCode(
                        code,
                        clientId: self.settings.clientId,
                        clientSecret: self.settings.clientSecret
                    )
                    self.settings.saveTokens(response)
                    await self.fetchAllData()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }

        auth.authorize(clientId: settings.clientId)
    }

    func disconnect() {
        settings.clearTokens()
        activities = [:]
        availableSports = []
        selectedSport = nil
        lastUpdated = nil
        error = nil
        try? FileManager.default.removeItem(at: Self.cacheURL)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
