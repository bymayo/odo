import Foundation
import SwiftUI

// On-disk cache model
private struct ActivityCache: Codable {
    let activities: [Int: [StravaActivity]]
    let lastUpdated: Date
    var version: Int? = nil
}

/// Bump when StravaActivity gains fields, so cached years get re-fetched
private let kCacheVersion = 3

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

    /// Cached years fetched with an older cache version; re-fetched on next sync
    private var staleYears: Set<Int> = []

    private static var cacheURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Odo", isDirectory: true)
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

        let filtered = yearActivities.filter { includes($0, in: sport) }

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

    /// Cumulative daily totals for a metric. Index = day of year (0 = before Jan 1).
    /// Past years run to Dec 31; the current year stops at today.
    func cumulativeDaily(_ year: Int, sport: SportCategory, metric: String) -> [Double] {
        let calendar = Calendar.current
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        let iso8601Frac = ISO8601DateFormatter()
        iso8601Frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let daysInYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
            .flatMap { calendar.range(of: .day, in: .year, for: $0)?.count } ?? 365
        let lastDay = year == currentYear ? currentDayOfYear : daysInYear

        var daily = [Double](repeating: 0, count: daysInYear + 1)
        for activity in activities[year] ?? [] where includes(activity, in: sport) {
            guard let date = iso8601.date(from: activity.startDate) ?? iso8601Frac.date(from: activity.startDate),
                  let day = calendar.ordinality(of: .day, in: .year, for: date),
                  day <= daysInYear else { continue }
            switch metric {
            case "elevation": daily[day] += activity.totalElevationGain * settings.elevationConversion
            case "time": daily[day] += Double(activity.movingTime) / 3600.0
            default: daily[day] += activity.distance * settings.distanceConversion
            }
        }

        var cumulative = [Double](repeating: 0, count: lastDay + 1)
        for day in 1...lastDay {
            cumulative[day] = cumulative[day - 1] + daily[day]
        }
        return cumulative
    }

    // MARK: - Goal insights

    private func parseDate(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: string)
    }

    private func metricValue(_ a: StravaActivity, metric: String) -> Double {
        switch metric {
        case "elevation": return a.totalElevationGain * settings.elevationConversion
        case "time": return Double(a.movingTime) / 3600.0
        default: return a.distance * settings.distanceConversion
        }
    }

    /// The day this year's total first reached `goal`, if it has
    func goalReachedDate(sport: SportCategory, metric: String, goal: Double) -> Date? {
        guard goal > 0 else { return nil }
        let cumulative = cumulativeDaily(currentYear, sport: sport, metric: metric)
        guard let day = cumulative.firstIndex(where: { $0 >= goal }), day > 0 else { return nil }
        let cal = Calendar.current
        return cal.date(from: DateComponents(year: currentYear, month: 1, day: 1))
            .flatMap { cal.date(byAdding: .day, value: day - 1, to: $0) }
    }

    /// Totals for each day of the current week (locale's first weekday first)
    func currentWeek(sport: SportCategory, metric: String) -> (start: Date, days: [Double]) {
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .weekOfYear, for: Date())
        let start = interval?.start ?? cal.startOfDay(for: Date())
        var days = [Double](repeating: 0, count: 7)
        // A week can span New Year, so look at both years
        for year in [currentYear - 1, currentYear] {
            for a in activities[year] ?? [] where includes(a, in: sport) {
                guard let date = parseDate(a.startDate), date >= start,
                      let index = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: date)).day,
                      (0..<7).contains(index) else { continue }
                days[index] += metricValue(a, metric: metric)
            }
        }
        return (start, days)
    }

    /// Weekly streaks: consecutive weeks hitting `weeklyTarget`.
    /// The current week only counts once it's hit, so an in-progress week never breaks a streak.
    func streaks(sport: SportCategory, metric: String, weeklyTarget: Double) -> (current: Int, best: Int) {
        guard weeklyTarget > 0 else { return (0, 0) }
        let cal = Calendar.current
        func weekStart(_ d: Date) -> Date { cal.dateInterval(of: .weekOfYear, for: d)?.start ?? cal.startOfDay(for: d) }

        var totals: [Date: Double] = [:]
        for year in (currentYear - 2)...currentYear {
            for a in activities[year] ?? [] where includes(a, in: sport) {
                guard let date = parseDate(a.startDate) else { continue }
                totals[weekStart(date), default: 0] += metricValue(a, metric: metric)
            }
        }
        func hit(_ week: Date) -> Bool { (totals[week] ?? 0) >= weeklyTarget }

        let thisWeek = weekStart(Date())

        // Current streak: walk back from this week (if hit) or last week
        var current = 0
        var week = hit(thisWeek) ? thisWeek : cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
        while hit(week), current < 520 {
            current += 1
            week = cal.date(byAdding: .weekOfYear, value: -1, to: week)!
        }

        // Best streak this year
        var best = 0, run = 0
        let yearStart = cal.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        week = weekStart(yearStart)
        while week <= thisWeek {
            run = hit(week) ? run + 1 : (week == thisWeek ? run : 0)
            best = max(best, run)
            week = cal.date(byAdding: .weekOfYear, value: 1, to: week)!
        }
        return (current, max(best, current))
    }

    /// Menu bar sport/metric: true when on or ahead of pace, false when behind, nil with no goal
    var menuBarOnPace: Bool? {
        guard let sport = menuBarSportCategory else { return nil }
        let goal = settings.goalFor(sport)
        let metric = settings.menuBarMetric
        let target: Double
        switch metric {
        case "elevation": target = goal.elevationFeet
        case "time": target = goal.timeHours
        default: target = goal.distanceMiles
        }
        guard target > 0 else { return nil }
        let current = (activities[currentYear] ?? [])
            .filter { includes($0, in: sport) }
            .reduce(0.0) { $0 + metricValue($1, metric: metric) }
        let daysInYear = Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
        return current >= target * Double(currentDayOfYear) / daysInYear
    }

    // MARK: - Sub-type filtering

    private func subTypeKey(_ subType: String, sport: SportCategory) -> String {
        "\(sport.rawValue)|\(subType)"
    }

    func includes(_ activity: StravaActivity, in sport: SportCategory) -> Bool {
        guard sport.matches(sportType: activity.sportType),
              !settings.excludedSubTypes.contains(subTypeKey(activity.subType, sport: sport)) else { return false }

        let prefix = "\(sport.rawValue)|"
        for (key, raw) in settings.tagModes where key.hasPrefix(prefix) {
            let tag = String(key.dropFirst(prefix.count))
            let has = activity.tags.contains(tag)
            switch TagMode(rawValue: raw) {
            case .exclude where has: return false
            case .only where !has: return false
            default: break
            }
        }
        return true
    }

    /// Tags seen for a sport across all years, most common first
    func tags(for sport: SportCategory) -> [String] {
        var counts: [String: Int] = [:]
        for yearActivities in activities.values {
            for a in yearActivities where sport.matches(sportType: a.sportType) {
                for tag in a.tags { counts[tag, default: 0] += 1 }
            }
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    func tagMode(_ tag: String, sport: SportCategory) -> TagMode {
        settings.tagModes[subTypeKey(tag, sport: sport)].flatMap(TagMode.init) ?? .any
    }

    private func setTagMode(_ mode: TagMode, tag: String, sport: SportCategory) {
        objectWillChange.send()
        let key = subTypeKey(tag, sport: sport)
        settings.tagModes[key] = mode == .any ? nil : mode.rawValue
    }

    /// Click: hide / show activities with this tag
    func toggleTag(_ tag: String, sport: SportCategory) {
        setTagMode(tagMode(tag, sport: sport) == .any ? .exclude : .any, tag: tag, sport: sport)
    }

    /// Right-click: show only activities with this tag (again to undo)
    func soloTag(_ tag: String, sport: SportCategory) {
        let wasOnly = tagMode(tag, sport: sport) == .only
        for other in tags(for: sport) where tagMode(other, sport: sport) == .only {
            setTagMode(.any, tag: other, sport: sport)
        }
        setTagMode(wasOnly ? .any : .only, tag: tag, sport: sport)
    }

    /// Whether any type or tag filter is active for this sport
    func isFiltering(_ sport: SportCategory) -> Bool {
        let prefix = "\(sport.rawValue)|"
        return settings.excludedSubTypes.contains { $0.hasPrefix(prefix) }
            || settings.tagModes.keys.contains { $0.hasPrefix(prefix) }
    }

    /// Whether the filter control is worth showing for this sport
    func hasFilters(_ sport: SportCategory) -> Bool {
        subTypes(for: sport).count > 1 || !tags(for: sport).isEmpty
    }

    /// Sub-types seen for a sport across all years, most common first
    func subTypes(for sport: SportCategory) -> [String] {
        var counts: [String: Int] = [:]
        for yearActivities in activities.values {
            for a in yearActivities where sport.matches(sportType: a.sportType) {
                counts[a.subType, default: 0] += 1
            }
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    func isSubTypeIncluded(_ subType: String, sport: SportCategory) -> Bool {
        !settings.excludedSubTypes.contains(subTypeKey(subType, sport: sport))
    }

    func setSubType(_ subType: String, sport: SportCategory, included: Bool) {
        objectWillChange.send()
        let key = subTypeKey(subType, sport: sport)
        if included {
            settings.excludedSubTypes.remove(key)
        } else {
            settings.excludedSubTypes.insert(key)
        }
    }

    func includeAllSubTypes(sport: SportCategory) {
        objectWillChange.send()
        let prefix = "\(sport.rawValue)|"
        settings.excludedSubTypes = settings.excludedSubTypes.filter { !$0.hasPrefix(prefix) }
        settings.tagModes = settings.tagModes.filter { !$0.key.hasPrefix(prefix) }
    }

    /// Show only this sub-type; if it's already the only one shown, show all again
    func soloSubType(_ subType: String, sport: SportCategory) {
        objectWillChange.send()
        let all = subTypes(for: sport)
        let isSolo = all.allSatisfy { isSubTypeIncluded($0, sport: sport) == ($0 == subType) }
        for other in all {
            let key = subTypeKey(other, sport: sport)
            if isSolo || other == subType {
                settings.excludedSubTypes.remove(key)
            } else {
                settings.excludedSubTypes.insert(key)
            }
        }
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
        let filtered = yearActivities.filter { includes($0, in: sport) }

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
        if (cache.version ?? 1) < kCacheVersion {
            staleYears = Set(cache.activities.keys)
        }
        updateAvailableSports()
    }

    private func saveCache() {
        let cache = ActivityCache(
            activities: activities,
            lastUpdated: lastUpdated ?? Date(),
            version: staleYears.isEmpty ? kCacheVersion : 1
        )
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
                if activities[year] != nil && !staleYears.contains(year) {
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
                staleYears.remove(currentYear)
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
                if activities[year] != nil && !staleYears.contains(year) {
                    // Already cached — skip
                    consecutiveEmpty = 0
                    continue
                }

                syncStatus = .syncing(year: year, total: totalYears, completed: completed)

                do {
                    let yearActivities = try await api.fetchActivities(year: year, accessToken: token)
                    staleYears.remove(year)
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

    /// Pre-fill goals for any sport with none set, using the smart "Beat" suggestion
    func prefillGoalsFromLastYear() {
        for sport in availableSports {
            let existing = settings.goalFor(sport)
            if existing.distanceMiles == 0 && existing.elevationFeet == 0 && existing.timeHours == 0,
               lastYearStats(for: sport) != nil {
                applyDefaultSmartGoals(for: sport)
            }
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
