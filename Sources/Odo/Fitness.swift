import Foundation

/// Fitness, fatigue and form: Banister's impulse-response model, the same one
/// behind Strava's Fitness & Freshness and TrainingPeaks' PMC.
///
/// Every activity gets a training load (about 100 for an hour flat out at
/// threshold). Fitness is a 42-day exponentially weighted average of daily
/// load, fatigue a 7-day one, and form is fitness minus fatigue.
enum Fitness {
    static let fitnessDays = 42.0
    static let fatigueDays = 7.0

    /// Where an activity's load came from, best first
    enum Source { case heartRate, relativeEffort, estimate }

    struct Day: Identifiable {
        let date: Date
        let load: Double
        let fitness: Double
        let fatigue: Double
        var form: Double { fitness - fatigue }
        var id: Date { date }
    }

    struct Zone {
        let name: String
        let detail: String
        let kind: Kind
        enum Kind { case losing, fresh, neutral, building, overreaching }
    }

    /// Form bands, as intervals.icu and TrainingPeaks draw them
    static func zone(form: Double) -> Zone {
        switch form {
        case 25...: return Zone(name: "Losing fitness", detail: "Rested for a while; fitness is fading", kind: .losing)
        case 5..<25: return Zone(name: "Fresh", detail: "Rested and ready to race", kind: .fresh)
        case -10..<5: return Zone(name: "Neutral", detail: "Maintaining", kind: .neutral)
        case -30 ..< -10: return Zone(name: "Building", detail: "Training hard enough to gain fitness", kind: .building)
        default: return Zone(name: "Overreaching", detail: "Fatigue is high; time for an easier few days", kind: .overreaching)
        }
    }

    // MARK: - Load per activity

    /// Heart-rate reserve where an hour's effort scores 100, roughly lactate threshold
    private static let thresholdReserve = 0.85

    /// Banister TRIMP per minute at a given heart-rate reserve (0...1)
    private static func trimpPerMinute(_ reserve: Double) -> Double {
        reserve * 0.64 * exp(1.92 * reserve)
    }

    /// Load from time at an average heart rate, scaled so an hour at threshold is 100
    static func heartRateLoad(minutes: Double, averageHR: Double, maxHR: Double, restingHR: Double) -> Double? {
        guard maxHR > restingHR + 20, averageHR > 0 else { return nil }
        let reserve = min(max((averageHR - restingHR) / (maxHR - restingHR), 0), 1)
        return minutes * trimpPerMinute(reserve) / (60 * trimpPerMinute(thresholdReserve)) * 100
    }

    /// Load per hour when there's no heart rate or Relative Effort, by sport type
    private static func estimatedPerHour(_ sportType: String) -> Double {
        switch sportType {
        case "Run", "TrailRun", "VirtualRun": return 60
        case "Swim": return 55
        case "Ride", "VirtualRide", "GravelRide", "MountainBikeRide", "EBikeRide", "EMountainBikeRide": return 45
        case "Walk", "Hike": return 25
        case "Yoga", "Pilates": return 15
        case "WeightTraining", "Crossfit", "Workout", "HighIntensityIntervalTraining": return 40
        default: return 40
        }
    }

    static func load(_ a: StravaActivity, maxHR: Double?, restingHR: Double) -> (value: Double, source: Source) {
        let minutes = Double(a.movingTime) / 60
        if let avg = a.averageHeartrate, let maxHR,
           let value = heartRateLoad(minutes: minutes, averageHR: avg, maxHR: maxHR, restingHR: restingHR) {
            return (value, .heartRate)
        }
        if let effort = a.sufferScore, effort > 0 {
            return (effort, .relativeEffort)
        }
        let hours = minutes / 60
        let factor = a.sportType == "EBikeRide" || a.sportType == "EMountainBikeRide" ? 0.6 : 1
        return (hours * estimatedPerHour(a.sportType) * factor, .estimate)
    }

    // MARK: - Series

    /// Runs the model day by day from the first load to `through`
    static func series(dailyLoad: [Date: Double], through end: Date, calendar: Calendar = .current) -> [Day] {
        guard let first = dailyLoad.keys.min() else { return [] }
        let kFitness = 1 - exp(-1 / fitnessDays)
        let kFatigue = 1 - exp(-1 / fatigueDays)
        let last = calendar.startOfDay(for: end)

        var days: [Day] = []
        var fitness = 0.0, fatigue = 0.0
        var day = calendar.startOfDay(for: first)
        while day <= last {
            let load = dailyLoad[day] ?? 0
            fitness += (load - fitness) * kFitness
            fatigue += (load - fatigue) * kFatigue
            days.append(Day(date: day, load: load, fitness: fitness, fatigue: fatigue))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}

/// A sport's fitness history, with how its load was worked out
struct FitnessHistory {
    var days: [Fitness.Day] = []
    /// Activities in the last year by load source
    var heartRate = 0
    var relativeEffort = 0
    var estimate = 0

    var total: Int { heartRate + relativeEffort + estimate }
}
