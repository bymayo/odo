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
    /// "distance", "elevation" or "time", for rounding the doable target
    var metric = "distance"
    /// Weekly average over the last four weeks, for the doable target
    var recentPerWeek: Double = 0
    /// Last year's total by the same day of the year (nil with no data for last year)
    var lastYearToDate: Double? = nil
    /// Collapsed cards are one line and a thin bar
    var expanded = true
    var onExpand: (() -> Void)? = nil

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

    private var goalText: String {
        useTimeFormat ? "\(Int(goal))" : formatNumber(goal, decimals: goal >= 100 ? 0 : 1)
    }

    private var paceText: String { "\(aheadBehind >= 0 ? "+" : "−")\(fmt(abs(aheadBehind)))" }
    private var paceColor: Color { aheadBehind >= 0 ? Theme.positive : Theme.behind }

    var body: some View {
        Group {
            if expanded { full } else { compact }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(14)
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: 12) {
            label

            // Hero: progress against the goal, with the percentage on the right
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(heroText)
                    .font(.odo(size: 40, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("/ \(goalText) \(heroUnit)")
                    .font(.odo(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(percentText)
                    .font(.odo(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundColor(Theme.ink)
            }
            .padding(.top, -6)

            paceBar

            HStack(alignment: .top, spacing: 0) {
                stat(paceText, aheadBehind >= 0 ? "Ahead of pace" : "Behind pace",
                     color: paceColor, marker: .tick(Self.paceTickColor))
                Spacer(minLength: 8)
                stat(fmt(projectedTotal), "Projected", marker: .fill(Self.projectedColor))
                if let lastYearToDate {
                    Spacer(minLength: 8)
                    let diff = current - lastYearToDate
                    stat("\(diff >= 0 ? "+" : "−")\(whole(abs(diff)))", "vs \(lastYearLabel)",
                         color: diff >= 0 ? Theme.positive : Theme.behind)
                        .help("\(lastYearLabel) had \(amount(lastYearToDate)) by today's date")
                }
            }

            forecastLine

            // Only when behind pace
            if aheadBehind < 0 && current < goal {
                weeklyCallout
            }
        }
        .padding(16)
    }

    /// One line and a thin bar; click to open
    private var compact: some View {
        VStack(spacing: 8) {
                HStack(spacing: 8) {
                    label
                    Spacer(minLength: 8)
                    (Text(heroText).foregroundColor(Theme.ink).font(.odo(size: 13, weight: .semibold).monospacedDigit())
                     + Text(" / \(goalText) \(heroUnit)").foregroundColor(Theme.textTertiary).font(.odo(size: 11)))
                        .lineLimit(1)
                    Text(paceText)
                        .font(.odo(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(paceColor)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.odo(size: 8, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                miniBar
            }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onExpand?() }
        .help("Show \(title.lowercased()) in full")
    }

    private var label: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.odo(size: 10, weight: .medium))
            Text(title)
                .font(.odo(size: 12))
        }
        .foregroundColor(Theme.textSecondary)
    }

    /// Whole units above 100, for differences
    private func whole(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : formatNumber(value, decimals: value >= 100 ? 0 : 1)
    }

    private var lastYearLabel: String { String(Calendar.current.component(.year, from: Date()) - 1) }

    private var miniBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.07))
                Capsule().fill(Theme.accent).frame(width: max(4, w * progress))
                Rectangle()
                    .fill(Self.paceTickColor)
                    .frame(width: 1.5, height: 8)
                    .offset(x: w * expectedProgress - 0.75)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Finish date forecast

    private var yearEnd: Date {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        return cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
    }

    private func dateText(_ date: Date) -> String {
        let cal = Calendar.current
        return formatDate(date, cal.component(.year, from: date) == cal.component(.year, from: Date()) ? "d MMM" : "d MMM yyyy")
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
        }
    }

    private func forecastRow(icon: String, lead: String, tail: String, good: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.odo(size: 10))
                .foregroundColor(Theme.textTertiary)
            Text(lead)
                .font(.odo(size: 11, weight: .medium))
                .foregroundColor(Theme.ink.opacity(0.8))
            Text("· \(tail)")
                .font(.odo(size: 11))
                .foregroundColor(good ? Theme.positive : Theme.behind)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Weekly target

    private var dayOfYear: Double {
        Double(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1)
    }

    private var daysInYear: Double {
        Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
    }

    /// Catch-up rate, plus a doable target when that's out of reach
    private var catchUp: CatchUp {
        CatchUp(current: current, goal: goal, recentPerWeek: recentPerWeek, metric: metric)
    }

    private func weekly(_ value: Double) -> String {
        useTimeFormat ? "\(formatTime(value))/wk" : "\(formatNumber(value, decimals: value >= 100 ? 0 : 1)) \(unit)/wk"
    }

    private func amount(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : "\(formatNumber(value, decimals: value >= 100 ? 0 : 1)) \(unit)"
    }

    /// Shown when behind: two small tiles side by side, the weekly amount that
    /// gets you back on pace and, when that's too much, a doable target from current form
    private var weeklyCallout: some View {
        let plan = catchUp
        return HStack(spacing: 8) {
            tile(icon: "arrow.up.right", tint: Theme.ink,
                 label: Text("To get on pace"),
                 value: weekly(plan.neededPerWeek), valueColor: Theme.ink,
                 background: Theme.cardRaised.opacity(0.6))
                .help("\(weekly(plan.neededPerWeek)) from now to 31 Dec finishes on \(amount(goal)).")

            if let doable = plan.doable {
                tile(icon: "scope", tint: Theme.gold,
                     label: Text("Doable") + Text(" · \(amount(doable.total))").foregroundColor(Theme.textTertiary),
                     value: weekly(doable.perWeek), valueColor: Theme.ink,
                     background: Theme.cardRaised.opacity(0.6))
                    .help("""
                        Set automatically from how you're going: \(weekly(plan.currentPerWeek)) is the better of \
                        this year's average and your last four weeks. Ten percent more than that, kept up to \
                        31 Dec, gets you to \(amount(doable.total)).
                        """)
            }
        }
    }

    private func tile(icon: String, tint: Color, label: Text, value: String, valueColor: Color,
                      background: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.odo(size: 7, weight: .heavy))
                    .foregroundColor(Theme.background)
                    .frame(width: 13, height: 13)
                    .background(Circle().fill(tint))
                label
                    .font(.odo(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Text(value)
                .font(.odo(size: 14, weight: .bold).monospacedDigit())
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .cornerRadius(10)
    }

    private static let paceTickColor = Theme.ink.opacity(0.6)
    private static let projectedColor = Theme.accent.opacity(0.3)

    /// The doable target, when it's showing below
    private var doableTotal: Double? {
        guard aheadBehind < 0, current < goal else { return nil }
        return catchUp.doable?.total
    }

    /// Pacebar-style scale: lime fill for progress, a fainter lime on to where
    /// this rate finishes, a dark tick for where you should be today and a gold
    /// tick for the doable target
    private var paceBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let projected = goal > 0 ? min(projectedTotal / goal, 1) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.ink.opacity(0.07))

                // Where this year's rate finishes
                if projected > progress {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.accent.opacity(0.14))
                        .frame(width: w * projected)
                    Rectangle()
                        .fill(Self.projectedColor)
                        .frame(width: 1.5)
                        .offset(x: max(0, w * projected - 1.5))
                }

                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent)
                    .frame(width: w * progress)

                Rectangle()
                    .fill(Theme.accentInk)
                    .frame(width: 2.5)
                    .offset(x: max(0, w * progress - 1.25))

                // Doable target
                if let doableTotal, goal > 0 {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.gold)
                        .frame(width: 2, height: 16)
                        .offset(x: w * min(doableTotal / goal, 1) - 1)
                }

                // Where you should be today — crosses the bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(Self.paceTickColor)
                    .frame(width: 2, height: 16)
                    .offset(x: w * expectedProgress - 1)
            }
        }
        .frame(height: 8)
        .padding(.vertical, 4)
        .help(barHelp)
    }

    private var barHelp: String {
        var lines = ["Green: \(fmt(current)) so far", "Dark tick: where pace puts you today (\(fmt(expectedValue)))"]
        if projectedTotal > current {
            lines.append("Faint green: \(fmt(projectedTotal)) by 31 Dec at this year's rate")
        }
        if let doableTotal { lines.append("Gold tick: doable target (\(fmt(doableTotal)))") }
        return lines.joined(separator: "\n")
    }

    private enum Marker {
        case fill(Color)
        case tick(Color)
    }

    private func stat(_ value: String, _ label: String, color: Color = Theme.ink, marker: Marker? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.odo(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                switch marker {
                case .fill(let c): RoundedRectangle(cornerRadius: 1.5).fill(c).frame(width: 8, height: 5)
                case .tick(let c): RoundedRectangle(cornerRadius: 0.5).fill(c).frame(width: 2, height: 8)
                case nil: EmptyView()
                }
                Text(label)
                    .font(.odo(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .fixedSize()
    }
}
