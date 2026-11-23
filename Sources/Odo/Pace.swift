import Foundation

/// What it takes to catch up on a yearly goal, and a doable alternative when
/// that's out of reach. Shared by the goal cards and the pace notifications.
struct CatchUp {
    /// Weekly amount from now that finishes exactly on the goal
    let neededPerWeek: Double
    /// The better of this year's weekly average and the last four weeks
    let currentPerWeek: Double
    /// Set only when `neededPerWeek` is more than a stretch on current form
    let doable: Doable?

    struct Doable {
        let perWeek: Double
        let total: Double
    }

    /// How much above current form still counts as doable
    static let stretch = 1.1

    init(current: Double, goal: Double, recentPerWeek: Double, metric: String, now: Date = Date()) {
        let cal = Calendar.current
        let dayOfYear = Double(cal.ordinality(of: .day, in: .year, for: now) ?? 1)
        let daysInYear = Double(cal.range(of: .day, in: .year, for: now)?.count ?? 365)
        let weeksLeft = max((daysInYear - dayOfYear) / 7, 1.0 / 7)

        neededPerWeek = max(goal - current, 0) / weeksLeft
        currentPerWeek = max(current / max(dayOfYear / 7, 1), recentPerWeek)

        let doableRate = currentPerWeek * Self.stretch
        guard doableRate > 0, neededPerWeek > doableRate else { doable = nil; return }
        let total = Self.roundDown(current + doableRate * weeksLeft, metric: metric)
        guard total > current, total < goal else { doable = nil; return }
        // Recompute the rate from the rounded total so the two agree
        doable = Doable(perWeek: (total - current) / weeksLeft, total: total)
    }

    /// Round down to a tidy target: 50s of distance above 1,000 (else 10s),
    /// 500s of elevation, 5s of hours
    private static func roundDown(_ value: Double, metric: String) -> Double {
        let step: Double
        switch metric {
        case "elevation": step = value >= 5000 ? 500 : 100
        case "time": step = value >= 50 ? 5 : 1
        default: step = value >= 1000 ? 50 : 10
        }
        return (value / step).rounded(.down) * step
    }
}
