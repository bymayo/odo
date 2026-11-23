import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var clientId: String {
        didSet { defaults.set(clientId, forKey: "strava_client_id") }
    }
    @Published var clientSecret: String {
        didSet { defaults.set(clientSecret, forKey: "strava_client_secret") }
    }

    var accessToken: String? {
        get { defaults.string(forKey: "strava_access_token") }
        set { defaults.set(newValue, forKey: "strava_access_token") }
    }
    var refreshToken: String? {
        get { defaults.string(forKey: "strava_refresh_token") }
        set { defaults.set(newValue, forKey: "strava_refresh_token") }
    }
    var tokenExpiresAt: Int {
        get { defaults.integer(forKey: "strava_token_expires_at") }
        set { defaults.set(newValue, forKey: "strava_token_expires_at") }
    }

    // Per-sport challenge goals (keyed by SportCategory.rawValue)
    @Published var sportGoals: [String: SportGoal] {
        didSet { saveSportGoals() }
    }

    func goalFor(_ sport: SportCategory) -> SportGoal {
        sportGoals[sport.rawValue] ?? SportGoal(distanceMiles: 0, elevationFeet: 0)
    }

    func setGoal(_ goal: SportGoal, for sport: SportCategory) {
        sportGoals[sport.rawValue] = goal
    }

    // Which years to show in the comparison (empty = show all)
    @Published var visibleYears: Set<Int> {
        didSet { defaults.set(Array(visibleYears), forKey: "visible_years") }
    }

    // Auto-refresh interval in minutes (0 = manual only)
    @Published var refreshIntervalMinutes: Int {
        didSet { defaults.set(refreshIntervalMinutes, forKey: "refresh_interval_minutes") }
    }

    // Excluded sub-types per sport, keyed "Sport|subType" (e.g. "Cycling|VirtualRide")
    @Published var excludedSubTypes: Set<String> {
        didSet { defaults.set(Array(excludedSubTypes), forKey: "excluded_sub_types") }
    }

    // Tag filter modes per sport, keyed "Sport|Tag" -> TagMode raw value ("exclude"/"only")
    @Published var tagModes: [String: String] {
        didSet { defaults.set(tagModes, forKey: "tag_modes") }
    }

    // Hidden sport names (user-toggled off)
    @Published var hiddenSports: Set<String> {
        didSet { defaults.set(Array(hiddenSports), forKey: "hidden_sports") }
    }

    // Menu bar display settings
    @Published var menuBarSport: String {  // sport name, or "" for total across all
        didSet { defaults.set(menuBarSport, forKey: "menu_bar_sport") }
    }
    @Published var menuBarMetric: String {  // "distance" or "elevation"
        didSet { defaults.set(menuBarMetric, forKey: "menu_bar_metric") }
    }
    // Smart goal percentages
    @Published var smartBeatPercent: Int {
        didSet { defaults.set(smartBeatPercent, forKey: "smart_beat_percent") }
    }
    @Published var smartStretchPercent: Int {
        didSet { defaults.set(smartStretchPercent, forKey: "smart_stretch_percent") }
    }

    @Published var menuBarShowPace: Bool {
        didSet { defaults.set(menuBarShowPace, forKey: "menu_bar_show_pace") }
    }
    @Published var menuBarShowGoal: Bool {
        didSet { defaults.set(menuBarShowGoal, forKey: "menu_bar_show_goal") }
    }

    // Heart rate for training load on the Fitness tab (0 max = use the highest seen)
    @Published var maxHeartRate: Int {
        didSet { defaults.set(maxHeartRate, forKey: "max_heart_rate") }
    }
    @Published var restingHeartRate: Int {
        didSet { defaults.set(restingHeartRate, forKey: "resting_heart_rate") }
    }

    // Notifications (for the menu bar's sport and metric)
    @Published var notifyWeekly: Bool {
        didSet { defaults.set(notifyWeekly, forKey: "notify_weekly") }
    }
    @Published var notifyMonthly: Bool {
        didSet { defaults.set(notifyMonthly, forKey: "notify_monthly") }
    }
    @Published var notifyYearly: Bool {
        didSet { defaults.set(notifyYearly, forKey: "notify_yearly") }
    }
    @Published var notifyPace: Bool {
        didSet { defaults.set(notifyPace, forKey: "notify_pace") }
    }

    @Published var notifyKudos: Bool {
        didSet { defaults.set(notifyKudos, forKey: "notify_kudos") }
    }

    var anyNotifications: Bool { notifyWeekly || notifyMonthly || notifyYearly || notifyPace || notifyKudos }

    // Unit system
    @Published var useMetricUnits: Bool {
        didSet {
            defaults.set(useMetricUnits, forKey: "use_metric_units")
            if oldValue != useMetricUnits {
                convertGoals(toMetric: useMetricUnits)
            }
        }
    }

    var distanceUnit: String { useMetricUnits ? "km" : "mi" }
    var elevationUnit: String { useMetricUnits ? "m" : "ft" }
    var distanceConversion: Double { useMetricUnits ? 0.001 : kMetersToMiles }
    var elevationConversion: Double { useMetricUnits ? 1.0 : kMetersToFeet }

    var isConfigured: Bool {
        !clientId.isEmpty && !clientSecret.isEmpty
    }

    var isAuthenticated: Bool {
        accessToken != nil && refreshToken != nil
    }

    private init() {
        clientId = defaults.string(forKey: "strava_client_id") ?? ""
        clientSecret = defaults.string(forKey: "strava_client_secret") ?? ""
        visibleYears = Set((defaults.array(forKey: "visible_years") as? [Int]) ?? [])
        refreshIntervalMinutes = defaults.integer(forKey: "refresh_interval_minutes")

        // Load per-sport goals
        if let data = defaults.data(forKey: "sport_goals"),
           let decoded = try? JSONDecoder().decode([String: SportGoal].self, from: data) {
            sportGoals = decoded
        } else {
            sportGoals = [:]
        }

        hiddenSports = Set(defaults.stringArray(forKey: "hidden_sports") ?? [])
        excludedSubTypes = Set(defaults.stringArray(forKey: "excluded_sub_types") ?? [])
        tagModes = (defaults.dictionary(forKey: "tag_modes") as? [String: String]) ?? [:]

        menuBarSport = defaults.string(forKey: "menu_bar_sport") ?? ""
        menuBarMetric = defaults.string(forKey: "menu_bar_metric") ?? "distance"
        menuBarShowGoal = defaults.bool(forKey: "menu_bar_show_goal")
        menuBarShowPace = defaults.object(forKey: "menu_bar_show_pace") as? Bool ?? true
        smartBeatPercent = defaults.object(forKey: "smart_beat_percent") as? Int ?? 5
        smartStretchPercent = defaults.object(forKey: "smart_stretch_percent") as? Int ?? 12
        useMetricUnits = defaults.bool(forKey: "use_metric_units")
        notifyWeekly = defaults.object(forKey: "notify_weekly") as? Bool ?? true
        notifyMonthly = defaults.object(forKey: "notify_monthly") as? Bool ?? true
        notifyYearly = defaults.object(forKey: "notify_yearly") as? Bool ?? true
        notifyPace = defaults.object(forKey: "notify_pace") as? Bool ?? true
        notifyKudos = defaults.object(forKey: "notify_kudos") as? Bool ?? true
        maxHeartRate = defaults.integer(forKey: "max_heart_rate")
        restingHeartRate = defaults.object(forKey: "resting_heart_rate") as? Int ?? 60

        if refreshIntervalMinutes == 0 { refreshIntervalMinutes = 30 }
    }

    private func saveSportGoals() {
        if let data = try? JSONEncoder().encode(sportGoals) {
            defaults.set(data, forKey: "sport_goals")
        }
    }

    func saveTokens(_ response: StravaTokenResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        tokenExpiresAt = response.expiresAt
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpiresAt = 0
    }

    /// Convert all stored goals when switching unit systems
    private func convertGoals(toMetric: Bool) {
        var converted: [String: SportGoal] = [:]
        for (key, goal) in sportGoals {
            if toMetric {
                // miles → km, feet → m
                converted[key] = SportGoal(
                    distanceMiles: goal.distanceMiles * 1.60934,
                    elevationFeet: goal.elevationFeet * 0.3048,
                    timeHours: goal.timeHours
                )
            } else {
                // km → miles, m → feet
                converted[key] = SportGoal(
                    distanceMiles: goal.distanceMiles * 0.621371,
                    elevationFeet: goal.elevationFeet * 3.28084,
                    timeHours: goal.timeHours
                )
            }
        }
        sportGoals = converted
    }
}
