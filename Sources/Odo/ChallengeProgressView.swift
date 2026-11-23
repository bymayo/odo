import SwiftUI

struct ChallengeProgressView: View {
    let title: String
    let icon: String
    let current: Double
    let goal: Double
    let unit: String
    var useTimeFormat: Bool = false
    /// Day the goal was reached this year (nil if not yet)
    var reachedOn: Date? = nil

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    private var expectedProgress: Double {
        let dayOfYear = Double(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1)
        let daysInYear: Double = Calendar.current.range(of: .day, in: .year, for: Date())?.count == 366 ? 366 : 365
        return dayOfYear / daysInYear
    }

    private var expectedValue: Double { goal * expectedProgress }

    private var projectedTotal: Double {
        guard expectedProgress > 0 else { return 0 }
        return current / expectedProgress
    }

    private var aheadBehind: Double { current - expectedValue }

    private func fmt(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : formatNumber(value, decimals: abs(value) >= 1000 ? 0 : 1)
    }

    /// Hero number, Nike-style: whole units only so it reads at a glance
    private var heroText: String {
        useTimeFormat ? "\(Int(current))" : formatNumber(current, decimals: current >= 100 ? 0 : 1)
    }

    private var heroUnit: String { useTimeFormat ? "hrs" : unit }

    private var percentText: String {
        guard goal > 0 else { return "–" }
        return String(format: "%.0f%%", current / goal * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Label
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(Theme.textSecondary)

            // Hero number
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(heroText)
                    .font(.system(size: 46, weight: .black).width(.condensed).italic())
                    .tracking(-1)
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(heroUnit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, -6)

            paceBar

            // Stats grid
            HStack(alignment: .top, spacing: 0) {
                stat(percentText, "Complete")
                Spacer(minLength: 8)
                stat("\(aheadBehind >= 0 ? "+" : "−")\(fmt(abs(aheadBehind)))",
                     aheadBehind >= 0 ? "Ahead of pace" : "Behind pace",
                     color: aheadBehind >= 0 ? Theme.positive : Theme.negative)
                Spacer(minLength: 8)
                stat(fmt(projectedTotal), "Projected")
                Spacer(minLength: 8)
                stat(fmt(goal), "Goal")
            }

            forecastLine

            // Only when behind pace
            if aheadBehind < 0 && current < goal {
                weeklyCallout
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(14)
    }

    // MARK: - Finish date forecast

    private var yearEnd: Date {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        return cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
    }

    /// Date you'd reach the goal at your current average daily rate
    private var forecastDate: Date? {
        guard current > 0, current < goal else { return nil }
        let perDay = current / dayOfYear
        let daysNeeded = (goal - current) / perDay
        guard daysNeeded.isFinite, daysNeeded < 365 * 20 else { return nil }
        return Calendar.current.date(byAdding: .day, value: Int(daysNeeded.rounded(.up)), to: Date())
    }

    private func dateText(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = cal.component(.year, from: date) == cal.component(.year, from: Date()) ? "d MMM" : "d MMM yyyy"
        return f.string(from: date)
    }

    /// "+12 days early" / "26 days late" relative to 31 Dec
    private func earlyLate(_ date: Date) -> (String, Bool) {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: yearEnd)).day ?? 0
        if days == 0 { return ("right on time", true) }
        return days > 0 ? ("\(days) days early", true) : ("\(-days) days late", false)
    }

    @ViewBuilder
    private var forecastLine: some View {
        if let reachedOn {
            let (label, _) = earlyLate(reachedOn)
            forecastRow(icon: "flag.checkered", lead: "Hit on \(dateText(reachedOn))", tail: label, good: true)
        } else if let date = forecastDate {
            let (label, good) = earlyLate(date)
            forecastRow(icon: "flag.checkered", lead: "At this rate, \(dateText(date))", tail: label, good: good)
        }
    }

    private func forecastRow(icon: String, lead: String, tail: String, good: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
            Text(lead)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.ink.opacity(0.8))
            Text("· \(tail)")
                .font(.system(size: 11))
                .foregroundColor(good ? Theme.positive : Theme.negative)
            Spacer(minLength: 0)
        }
        .help("Based on your average so far this year")
    }

    // MARK: - Weekly target

    private var dayOfYear: Double {
        Double(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1)
    }

    private var daysInYear: Double {
        Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
    }

    /// Weekly amount needed from now to finish exactly on the goal
    private var neededPerWeek: Double {
        let weeksLeft = max((daysInYear - dayOfYear) / 7, 1.0 / 7)
        return max(goal - current, 0) / weeksLeft
    }

    /// What you've averaged per week so far this year
    private var averagePerWeek: Double {
        current / max(dayOfYear / 7, 1.0 / 7)
    }

    private func weekly(_ value: Double) -> String {
        useTimeFormat ? "\(formatTime(value))/wk" : "\(formatNumber(value, decimals: value >= 100 ? 0 : 1)) \(unit)/wk"
    }

    private func amount(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : "\(formatNumber(value, decimals: value >= 100 ? 0 : 1)) \(unit)"
    }

    /// Shown when behind: the weekly amount that gets you back on pace
    private var weeklyCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.negative))

            Text("To get on pace")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.ink)

            Spacer(minLength: 8)

            Text(weekly(neededPerWeek))
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(Theme.negative)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Theme.negative.opacity(0.09))
        .cornerRadius(10)
        .help("You're averaging \(weekly(averagePerWeek)). \(weekly(neededPerWeek)) from now to the end of the year finishes on \(amount(goal)).")
    }

    /// Pacebar-style scale: green fill for progress, dark tick for where you should be today
    private var paceBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.ink.opacity(0.07))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: w * progress)

                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 2.5)
                    .offset(x: max(0, w * progress - 1.25))

                // Where you should be today — crosses the bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.ink.opacity(0.6))
                    .frame(width: 2, height: 16)
                    .offset(x: w * expectedProgress - 1)
            }
        }
        .frame(height: 8)
        .padding(.vertical, 4)
    }

    private func stat(_ value: String, _ label: String, color: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .lineLimit(1)
        }
        .fixedSize()
    }
}
