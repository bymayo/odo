import Foundation
import SwiftUI

// MARK: - Theme

enum Theme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let accent = Color(red: 0.94, green: 0.48, blue: 0.30)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.45)
}

// MARK: - Strava API Response Models

struct StravaTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athlete: StravaAthlete?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

struct StravaAthlete: Codable {
    let id: Int
    let firstname: String?
    let lastname: String?
}

struct StravaActivity: Codable {
    let id: Int
    let name: String
    let distance: Double
    let totalElevationGain: Double
    let sportType: String
    let startDate: String
    let movingTime: Int
    let commute: Bool?

    /// Finer-grained type used for filtering within a sport (commutes split out)
    var subType: String { commute == true ? "Commute" : sportType }

    enum CodingKeys: String, CodingKey {
        case id, name, distance, commute
        case totalElevationGain = "total_elevation_gain"
        case sportType = "sport_type"
        case startDate = "start_date"
        case movingTime = "moving_time"
    }
}

// MARK: - Sport Categories

enum SportCategory: Identifiable, Hashable {
    case sport(String) // Dynamic, derived from activity data

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .sport(let name): return name
        }
    }

    // Maps Strava sport_type strings to a display name
    private static let sportTypeMap: [String: String] = [
        "Ride": "Cycling",
        "MountainBikeRide": "Cycling",
        "GravelRide": "Cycling",
        "EBikeRide": "Cycling",
        "VirtualRide": "Cycling",
        "Handcycle": "Cycling",
        "Velomobile": "Cycling",
        "EMountainBikeRide": "Cycling",
        "Run": "Running",
        "TrailRun": "Running",
        "VirtualRun": "Running",
        "Walk": "Walking",
        "Hike": "Walking",
        "Swim": "Swimming",
        "NordicSki": "Nordic Ski",
        "AlpineSki": "Alpine Ski",
        "BackcountrySki": "Backcountry Ski",
        "Snowboard": "Snowboard",
        "Kayaking": "Kayaking",
        "Rowing": "Rowing",
        "VirtualRow": "Rowing",
        "StandUpPaddling": "SUP",
        "Surfing": "Surfing",
        "Kitesurf": "Kitesurf",
        "Windsurf": "Windsurf",
        "RockClimbing": "Climbing",
        "IceSkate": "Ice Skating",
        "InlineSkate": "Inline Skating",
        "Skateboard": "Skateboard",
        "Crossfit": "Crossfit",
        "WeightTraining": "Weights",
        "Yoga": "Yoga",
        "Pilates": "Pilates",
        "Elliptical": "Elliptical",
        "StairStepper": "Stair Stepper",
        "Wheelchair": "Wheelchair",
        "Golf": "Golf",
        "Soccer": "Soccer",
        "Tennis": "Tennis",
        "TableTennis": "Table Tennis",
        "Pickleball": "Pickleball",
        "Racquetball": "Racquetball",
        "Squash": "Squash",
        "Badminton": "Badminton",
        "Sail": "Sailing",
        "Snowshoe": "Snowshoe",
        "Workout": "Workout",
        "HighIntensityIntervalTraining": "HIIT",
        "RollerSki": "Roller Ski",
        "Canoeing": "Canoeing",
    ]

    static func from(sportType: String) -> SportCategory {
        let name = sportTypeMap[sportType] ?? sportType
        return .sport(name)
    }

    /// Whether a given activity's sport type belongs to this category
    func matches(sportType: String) -> Bool {
        switch self {
        case .sport(let name): return Self.from(sportType: sportType) == .sport(name)
        }
    }
}

/// "VirtualRide" -> "Virtual Ride", "EBikeRide" -> "E-Bike Ride"
func subTypeDisplayName(_ subType: String) -> String {
    let special = ["EBikeRide": "E-Bike Ride", "EMountainBikeRide": "E-MTB Ride", "HighIntensityIntervalTraining": "HIIT"]
    if let name = special[subType] { return name }
    var result = ""
    for (i, ch) in subType.enumerated() {
        if i > 0 && ch.isUppercase { result.append(" ") }
        result.append(ch)
    }
    return result
}

// MARK: - Per-Sport Goals

struct SportGoal: Codable, Equatable {
    var distanceMiles: Double
    var elevationFeet: Double
    var timeHours: Double

    init(distanceMiles: Double, elevationFeet: Double, timeHours: Double = 0) {
        self.distanceMiles = distanceMiles
        self.elevationFeet = elevationFeet
        self.timeHours = timeHours
    }
}

// MARK: - App Models

struct YearStats {
    let year: Int
    var totalDistance: Double = 0    // miles
    var totalElevation: Double = 0   // feet
    var totalTime: Double = 0        // hours
    var distanceToDate: Double = 0   // miles at current day-of-year
    var elevationToDate: Double = 0  // feet at current day-of-year
    var timeToDate: Double = 0       // hours at current day-of-year
    var activityCount: Int = 0
    var activityCountToDate: Int = 0
}

func formatTime(_ hours: Double) -> String {
    let totalMinutes = Int(hours * 60)
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    if h > 0 {
        return "\(h)h \(m)m"
    }
    return "\(m)m"
}

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle
    case syncing(year: Int, total: Int, completed: Int)  // fetching year X, N of M
    case rateLimited(retryAfter: Int?)
    case done

    var isActive: Bool {
        switch self {
        case .syncing: return true
        default: return false
        }
    }

    var description: String {
        switch self {
        case .idle: return ""
        case .syncing(let year, let total, let completed):
            if total > 1 {
                return "Syncing \(year)... (\(completed)/\(total))"
            }
            return "Syncing \(year)..."
        case .rateLimited(let retry):
            if let secs = retry {
                return "Rate limited — retry in \(max(secs / 60, 1)) min"
            }
            return "Rate limited by Strava"
        case .done: return "Sync complete"
        }
    }
}

// MARK: - Helpers

let kMetersToMiles = 0.000621371
let kMetersToFeet = 3.28084

func formatNumber(_ value: Double, decimals: Int = 1) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

extension Date {
    func timeAgoDisplay() -> String {
        let seconds = -self.timeIntervalSinceNow
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}
