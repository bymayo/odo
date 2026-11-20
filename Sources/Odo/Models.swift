import Foundation
import SwiftUI
import AppKit

// MARK: - Theme

enum Theme {
    // Neutral surfaces, Pacebar-style. Adapts to light / dark appearance.
    static let background = dynamic(light: 0xF4F5F4, dark: 0x151615)
    static let card = dynamic(light: 0xEBECEA, dark: 0x1F201F)
    static let cardRaised = dynamic(light: 0xFBFBFA, dark: 0x2A2B2A)
    /// Base ink colour; use with opacity for secondary text, hairlines and tracks
    static let ink = dynamic(light: 0x151615, dark: 0xF5F5F4)
    static let hairline = ink.opacity(0.07)

    // The one accent — reserved for data (current year, progress, markers)
    static let accent = dynamic(light: 0x268A50, dark: 0x3FB871)
    static let positive = accent
    static let negative = dynamic(light: 0xC83A32, dark: 0xFF6B5F)
    static let gold = dynamic(light: 0xA66A11, dark: 0xE8B44A)
    static let silver = dynamic(light: 0x8A9099, dark: 0xC4CAD3)
    static let bronze = dynamic(light: 0x9A5B2E, dark: 0xC98A5A)

    static let textPrimary = ink
    static let textSecondary = ink.opacity(0.55)
    static let textTertiary = ink.opacity(0.35)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
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
    /// Strava workout_type: 1/11 race, 2 long run, 3/12 workout (run/ride)
    let workoutType: Int?

    /// Strava sport type, used for type filtering within a sport
    var subType: String { sportType }

    /// Cross-cutting tags (an activity can be a Ride *and* a Commute or Race)
    var tags: [String] {
        var tags: [String] = []
        if commute == true { tags.append("Commute") }
        switch workoutType {
        case 1, 11: tags.append("Race")
        case 2: tags.append("Long Run")
        case 3, 12: tags.append("Workout")
        default: break
        }
        return tags
    }

    enum CodingKeys: String, CodingKey {
        case id, name, distance, commute
        case workoutType = "workout_type"
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

    private static let iconMap: [String: String] = [
        "Cycling": "figure.outdoor.cycle",
        "Running": "figure.run",
        "Walking": "figure.walk",
        "Swimming": "figure.pool.swim",
        "Pilates": "figure.pilates",
        "Yoga": "figure.yoga",
        "Weights": "figure.strengthtraining.traditional",
        "Crossfit": "figure.cross.training",
        "HIIT": "figure.highintensity.intervaltraining",
        "Workout": "figure.mixed.cardio",
        "Elliptical": "figure.elliptical",
        "Stair Stepper": "figure.stair.stepper",
        "Rowing": "figure.rower",
        "Kayaking": "oar.2.crossed",
        "Canoeing": "oar.2.crossed",
        "SUP": "figure.surfing",
        "Surfing": "figure.surfing",
        "Kitesurf": "figure.surfing",
        "Windsurf": "figure.surfing",
        "Sailing": "sailboat",
        "Nordic Ski": "figure.skiing.crosscountry",
        "Roller Ski": "figure.skiing.crosscountry",
        "Backcountry Ski": "figure.skiing.crosscountry",
        "Alpine Ski": "figure.skiing.downhill",
        "Snowboard": "figure.snowboarding",
        "Snowshoe": "figure.hiking",
        "Climbing": "figure.climbing",
        "Ice Skating": "figure.skating",
        "Inline Skating": "figure.skating",
        "Skateboard": "figure.skateboarding",
        "Wheelchair": "figure.roll",
        "Golf": "figure.golf",
        "Soccer": "figure.soccer",
        "Tennis": "figure.tennis",
        "Table Tennis": "figure.table.tennis",
        "Badminton": "figure.badminton",
        "Squash": "figure.racquetball",
        "Racquetball": "figure.racquetball",
        "Pickleball": "figure.pickleball",
    ]

    /// SF Symbol for the sport, falling back to a generic figure if unavailable
    var icon: String {
        let name = Self.iconMap[rawValue] ?? "figure.mixed.cardio"
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : "figure.mixed.cardio"
    }

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

/// How a tag (Commute, Race…) filters a sport's activities
enum TagMode: String {
    case any      // tag doesn't matter
    case exclude  // hide activities with this tag
    case only     // show only activities with this tag
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
    /// Fetching `year`; `fetched` counts activities downloaded so far this sync
    case syncing(year: Int, fetched: Int)
    case rateLimited(until: Date)
    case done

    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }

    var description: String {
        switch self {
        case .idle: return ""
        case .syncing(let year, let fetched):
            return fetched > 0 ? "Syncing \(year) · \(fetched.formatted()) activities" : "Syncing \(year)…"
        case .rateLimited(let until):
            return "Strava limit hit · resumes \(until.shortTimeOrTomorrow)"
        case .done: return "Synced"
        }
    }
}

// MARK: - Helpers

extension Date {
    /// "14:45" today, "tomorrow 00:00" after midnight
    var shortTimeOrTomorrow: String {
        let time = formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDateInToday(self) ? time : "tomorrow \(time)"
    }
}

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
