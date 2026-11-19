import SwiftUI

/// "This week" card: progress against the weekly pace for the year's goal,
/// with one dot per day showing which days you were active.
struct WeekProgressView: View {
    let start: Date
    let days: [Double]          // 7 values, first weekday first
    let weeklyTarget: Double    // yearly goal spread over the weeks
    let unit: String
    var useTimeFormat: Bool = false
    var streak: Int = 0
    var bestStreak: Int = 0

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
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // single-letter weekday
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start).map(f.string) }
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
                    .foregroundColor(total >= weeklyTarget ? Theme.positive : Theme.textTertiary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(fmt(total))
                    .font(.system(size: 30, weight: .black).width(.condensed).italic())
                    .foregroundColor(Theme.ink)
                Text("/ \(fmt(weeklyTarget)) \(useTimeFormat ? "" : unit)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.top, -4)

            // Thin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.07))
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)

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

            streakRow
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

    private var statusText: String {
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
