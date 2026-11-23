import SwiftUI

/// One sport's week, for the breakdown on the All tab
struct SportWeek: Identifiable {
    let sport: SportCategory
    let total: Double
    let target: Double          // 0 when the sport has no goal
    let unit: String
    let useTimeFormat: Bool
    var id: String { sport.id }
    var done: Bool { target > 0 && total >= target }
}

/// "This week" card: progress against the weekly pace for the year's goal,
/// with one dot per day showing which days you were active. On the All tab
/// it also lists each sport against that sport's own weekly pace.
struct WeekProgressView: View {
    let start: Date
    let days: [Double]          // 7 values, first weekday first
    let weeklyTarget: Double    // yearly goal spread over the weeks; 0 for no goal
    let unit: String
    var useTimeFormat: Bool = false
    var streak: Int = 0
    var bestStreak: Int = 0
    var breakdown: [SportWeek] = []

    private var hasTarget: Bool { weeklyTarget > 0 }

    private var total: Double { days.reduce(0, +) }
    private var progress: Double { weeklyTarget > 0 ? min(total / weeklyTarget, 1) : 0 }

    private var todayIndex: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: start, to: cal.startOfDay(for: Date())).day ?? 0
    }

    private var daysLeft: Int { max(6 - todayIndex, 0) }

    private func fmt(_ v: Double) -> String {
        useTimeFormat ? formatTime(v) : formatNumber(v, decimals: v >= 100 ? 0 : 1)
    }

    private var dayLetters: [String] {
        let cal = Calendar.current
        // Single-letter weekday
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start).map { formatDate($0, "EEEEE") } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .medium))
                    Text("This week")
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.textSecondary)

                Spacer()

                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundColor(hasTarget && total >= weeklyTarget ? Theme.positive : Theme.textTertiary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(fmt(total))
                    .font(.system(size: 30, weight: .black).width(.condensed).italic())
                    .foregroundColor(Theme.ink)
                Text(hasTarget ? "/ \(fmt(weeklyTarget)) \(useTimeFormat ? "" : unit)" : (useTimeFormat ? "" : unit))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.top, -4)

            if hasTarget {
                ProgressBar(progress: progress)
            }

            // One dot per day
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 5) {
                        dot(for: i)
                        Text(i < dayLetters.count ? dayLetters[i] : "")
                            .font(.system(size: 9, weight: i == todayIndex ? .semibold : .regular))
                            .foregroundColor(i == todayIndex ? Theme.ink : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .help(i <= todayIndex ? "\(fmt(days[i])) \(useTimeFormat ? "" : unit)" : "")
                }
            }

            if !breakdown.isEmpty {
                VStack(spacing: 9) {
                    ForEach(breakdown) { sportRow($0) }
                }
                .padding(.top, 2)
            }

            if hasTarget {
                streakRow
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
    }

    private var streakRow: some View {
        HStack(spacing: 6) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 11))
                .foregroundColor(streak > 0 ? Theme.gold : Theme.textTertiary)
            if streak > 0 {
                (Text("\(streak)-week streak")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.ink)
                 + Text(streak >= bestStreak ? " · best this year" : " · best \(bestStreak)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary))
            } else {
                Text(bestStreak > 0
                     ? "Hit \(fmt(weeklyTarget)) \(useTimeFormat ? "" : unit) this week to restart your streak · best \(bestStreak)"
                     : "Hit \(fmt(weeklyTarget)) \(useTimeFormat ? "" : unit) this week to start a streak")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .help("Weeks in a row hitting your weekly pace")
    }

    @ViewBuilder
    private func dot(for i: Int) -> some View {
        let active = days[i] > 0
        let future = i > todayIndex
        ZStack {
            Circle()
                .fill(active ? Theme.accent : (future ? Color.clear : Theme.ink.opacity(0.08)))
            Circle()
                .stroke(i == todayIndex ? Theme.ink.opacity(0.6) : (future ? Theme.hairline : Color.clear),
                        lineWidth: i == todayIndex ? 1.5 : 1)
        }
        .frame(width: 14, height: 14)
    }

    /// A sport's week: icon, name, total against its own weekly pace
    private func sportRow(_ s: SportWeek) -> some View {
        func fmt(_ v: Double) -> String {
            s.useTimeFormat ? formatTime(v) : formatNumber(v, decimals: v >= 100 ? 0 : 1)
        }
        let unit = s.useTimeFormat ? "" : " \(s.unit)"
        return VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: s.sport.icon)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 16)
                Text(s.sport.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.ink)
                Spacer()
                if s.done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.positive)
                }
                Text(s.target > 0 ? "\(fmt(s.total)) / \(fmt(s.target))\(unit)" : "\(fmt(s.total))\(unit)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(s.total > 0 ? Theme.textSecondary : Theme.textTertiary)
            }
            if s.target > 0 {
                ProgressBar(progress: min(s.total / s.target, 1), height: 3)
                    .padding(.leading, 23)
            }
        }
        .help(s.target > 0 ? "This week against \(s.sport.displayName)'s weekly pace" : "No \(s.sport.displayName) goal set")
    }

    private var statusText: String {
        guard hasTarget else {
            let active = days.filter { $0 > 0 }.count
            if !breakdown.isEmpty, breakdown.contains(where: { $0.target > 0 }) {
                let withGoal = breakdown.filter { $0.target > 0 }
                return "\(withGoal.filter(\.done).count) of \(withGoal.count) on pace"
            }
            return active == 1 ? "1 active day" : "\(active) active days"
        }
        if total >= weeklyTarget { return "Week done ✓" }
        let remaining = weeklyTarget - total
        let left = useTimeFormat ? fmt(remaining) : "\(fmt(remaining)) \(unit)"
        switch daysLeft {
        case 0: return "\(left) to go today"
        case 1: return "\(left) to go · 1 day left"
        default: return "\(left) to go · \(daysLeft) days left"
        }
    }
}

/// Thin capsule progress bar
private struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.07))
                Capsule().fill(Theme.accent).frame(width: geo.size.width * progress)
            }
        }
        .frame(height: height)
    }
}
