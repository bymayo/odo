import SwiftUI
import Charts

struct YearComparisonView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @State private var metric = "distance"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YEAR COMPARISON")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.4))

                Spacer()

                Picker("", selection: $metric) {
                    Text("Dist").tag("distance")
                    Text("Elev").tag("elevation")
                    Text("Time").tag("time")
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            if let sport = viewModel.selectedSport {
                YearChart(
                    series: buildSeries(sport: sport),
                    target: targetFor(sport),
                    currentYear: viewModel.currentYear,
                    today: viewModel.currentDayOfYear,
                    unit: unitFor(metric),
                    useTimeFormat: metric == "time"
                )
            }
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
    }

    private func buildSeries(sport: SportCategory) -> [YearSeries] {
        let years = [viewModel.currentYear] + viewModel.visibleComparisonYears
        return years.enumerated().map { index, year in
            YearSeries(
                year: year,
                values: viewModel.cumulativeDaily(year, sport: sport, metric: metric),
                color: year == viewModel.currentYear
                    ? Theme.accent
                    : YearChart.palette[(index - 1) % YearChart.palette.count],
                holdsAfterEnd: year == viewModel.currentYear
            )
        }
    }

    private func targetFor(_ sport: SportCategory) -> Double {
        let goal = settings.goalFor(sport)
        switch metric {
        case "elevation": return goal.elevationFeet
        case "time": return goal.timeHours
        default: return goal.distanceMiles
        }
    }

    private func unitFor(_ metric: String) -> String {
        switch metric {
        case "elevation": return settings.elevationUnit
        case "time": return "hrs"
        default: return settings.distanceUnit
        }
    }
}

struct YearSeries: Identifiable {
    let year: Int
    /// Cumulative value indexed by day of year (0 = start)
    let values: [Double]
    let color: Color
    /// Current year: past today, hold today's total (as if you stopped now)
    var holdsAfterEnd = false

    var id: Int { year }

    var lastDay: Int { values.count - 1 }

    func value(on day: Int) -> Double? {
        if values.indices.contains(day) { return values[day] }
        return holdsAfterEnd && day > lastDay ? values.last : nil
    }
}

struct YearChart: View {
    let series: [YearSeries]
    let target: Double
    let currentYear: Int
    let today: Int
    let unit: String
    let useTimeFormat: Bool

    @State private var hoverDay: Int?
    @State private var lockedDay: Int?
    @State private var focusedYear: Int?

    private static let dimmed = Color.white.opacity(0.13)

    private func isDimmed(_ s: YearSeries) -> Bool {
        focusedYear != nil && focusedYear != s.year
    }

    /// Draw order: past years, then current, then the focused year on top
    private var drawOrder: [YearSeries] {
        let base = Array(series.reversed())
        guard let focusedYear else { return base }
        return base.filter { $0.year != focusedYear } + base.filter { $0.year == focusedYear }
    }

    static let palette: [Color] = [
        Color(red: 0.40, green: 0.62, blue: 0.98),
        Color(red: 0.68, green: 0.52, blue: 0.96),
        Color(red: 0.35, green: 0.80, blue: 0.75),
        Color(red: 0.95, green: 0.78, blue: 0.35),
        Color(red: 0.92, green: 0.50, blue: 0.70),
        Color(red: 0.60, green: 0.60, blue: 0.65),
    ]

    private static let targetColor = Color.white.opacity(0.55)
    private static let monthStarts = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
    private static let monthLetters = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    private var daysInYear: Int {
        let cal = Calendar.current
        return cal.date(from: DateComponents(year: currentYear, month: 1, day: 1))
            .flatMap { cal.range(of: .day, in: .year, for: $0)?.count } ?? 365
    }

    private var selectedDay: Int { lockedDay ?? hoverDay ?? today }

    /// Year with the highest total on the selected day
    private var bestYear: Int? {
        let ranked = series.compactMap { s in s.value(on: selectedDay).map { (s.year, $0) } }
        guard let best = ranked.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return best.0
    }

    private func targetValue(on day: Int) -> Double {
        target * Double(day) / Double(daysInYear)
    }

    private func fmt(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : formatNumber(value, decimals: value >= 1000 ? 0 : 1)
    }

    private func axisLabel(_ value: Double) -> String {
        if useTimeFormat { return "\(Int(value))h" }
        if value >= 1000 { return String(format: "%.0fk", value / 1000) }
        return String(format: "%.0f", value)
    }

    /// Thin out daily points for drawing; scrubbing still uses exact daily values.
    private func plotPoints(_ s: YearSeries) -> [(day: Int, value: Double)] {
        let last = s.values.count - 1
        return stride(from: 0, through: last, by: 3).map { ($0, s.values[$0]) }
            + (last % 3 == 0 ? [] : [(last, s.values[last])])
    }

    private func dateLabel(for day: Int) -> String {
        let cal = Calendar.current
        guard let start = cal.date(from: DateComponents(year: currentYear, month: 1, day: 1)),
              let date = cal.date(byAdding: .day, value: max(day, 1) - 1, to: start) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        let label = f.string(from: date)
        let suffix = day == today ? " (today)" : day > today ? " (if you stop today)" : ""
        return "1 Jan → \(label)" + suffix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chart
                .frame(height: 200)
            readout
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            if target > 0 {
                LineMark(x: .value("Day", 0), y: .value("Value", 0), series: .value("Series", "Target"))
                    .foregroundStyle(Self.targetColor)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                LineMark(x: .value("Day", daysInYear), y: .value("Value", target), series: .value("Series", "Target"))
                    .foregroundStyle(Self.targetColor)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }

            // Past years first so the current year draws on top
            ForEach(drawOrder) { s in
                let emphasised = focusedYear == s.year || (focusedYear == nil && s.year == currentYear)
                ForEach(plotPoints(s), id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Value", point.value),
                        series: .value("Series", String(s.year))
                    )
                    .foregroundStyle(isDimmed(s) ? Self.dimmed : emphasised ? s.color : s.color.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: emphasised ? 2.5 : 1.5))
                }
            }

            // "If you stopped today" — hold the current total flat to year end
            if let current = series.first(where: { $0.year == currentYear }),
               let last = current.values.last, current.lastDay < daysInYear {
                ForEach([current.lastDay, daysInYear], id: \.self) { day in
                    LineMark(x: .value("Day", day), y: .value("Value", last), series: .value("Series", "Hold"))
                        .foregroundStyle(isDimmed(current) ? Self.dimmed : current.color.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
            }

            RuleMark(x: .value("Day", selectedDay))
                .foregroundStyle(lockedDay != nil ? Theme.accent.opacity(0.6)
                    : Color.white.opacity(hoverDay == nil ? 0.12 : 0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: lockedDay != nil ? [3, 2] : []))

            ForEach(drawOrder) { s in
                if let v = s.value(on: selectedDay) {
                    if s.year == bestYear && !isDimmed(s) {
                        PointMark(x: .value("Day", selectedDay), y: .value("Value", v))
                            .foregroundStyle(Color.white)
                            .symbolSize(80)
                    }
                    PointMark(x: .value("Day", selectedDay), y: .value("Value", v))
                        .foregroundStyle(isDimmed(s) ? Self.dimmed : s.color)
                        .symbolSize(s.year == currentYear || s.year == bestYear ? 30 : 18)
                }
            }
        }
        .chartXScale(domain: 0...daysInYear)
        .chartXAxis {
            AxisMarks(values: Self.monthStarts) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel {
                    if let day = value.as(Int.self), let i = Self.monthStarts.firstIndex(of: day) {
                        Text(Self.monthLetters[i])
                            .font(.system(size: 8))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(axisLabel(v))
                            .font(.system(size: 8))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoverDay = day(at: location, proxy: proxy, geo: geo)
                        case .ended:
                            hoverDay = nil
                        }
                    }
                    .onTapGesture { location in
                        lockedDay = lockedDay == nil ? day(at: location, proxy: proxy, geo: geo) : nil
                    }
            }
        }
    }

    private func day(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Int? {
        let originX = geo[proxy.plotAreaFrame].origin.x
        guard let day: Int = proxy.value(atX: location.x - originX) else { return nil }
        return min(max(day, 1), daysInYear)
    }

    // MARK: - Readout

    private static let green = Color(red: 0.4, green: 0.85, blue: 0.5)
    private static let red = Color(red: 1.0, green: 0.45, blue: 0.4)

    private var readout: some View {
        let current = series.first { $0.year == currentYear }?.value(on: selectedDay)
        let targetNow = targetValue(on: selectedDay)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateLabel(for: selectedDay))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(lockedDay != nil ? "🔒 Locked" : "Click to lock")
                    .font(.system(size: 9))
                    .foregroundColor(lockedDay != nil ? Theme.accent : Color.white.opacity(0.3))

                let lockedToToday = lockedDay == today
                Button(action: { lockedDay = lockedToToday ? nil : today }) {
                    Text("Today")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundColor(lockedToToday ? Theme.background : Theme.accent)
                        .background(lockedToToday ? Theme.accent : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Theme.accent.opacity(0.6), lineWidth: 1)
                        )
                        .cornerRadius(5)
                }
                .buttonStyle(.borderless)
                .help(lockedToToday ? "Unlock" : "Lock graph to today")
            }

            Grid(alignment: .trailing, horizontalSpacing: 6, verticalSpacing: 0) {
                GridRow {
                    header("Year").gridColumnAlignment(.leading)
                    header(unit)
                    header("Δ Prev")
                    header("Δ \(String(currentYear))")
                    header("Δ Target")
                }
                .padding(.bottom, 4)

                ForEach(Array(series.enumerated()), id: \.element.id) { index, s in
                    let value = s.value(on: selectedDay)
                    let prev = index + 1 < series.count ? series[index + 1].value(on: selectedDay) : nil

                    Divider().overlay(Color.white.opacity(0.06))
                    GridRow {
                        let isBest = s.year == bestYear
                        HStack(spacing: 3) {
                            Text(String(s.year))
                                .font(.system(size: 11, weight: s.year == currentYear || isBest ? .bold : .medium))
                                .foregroundColor(s.color)
                            if isBest {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.3))
                            }
                        }
                        Text(value.map(fmt) ?? "–")
                            .font(.system(size: 11, weight: isBest ? .bold : .regular, design: .rounded).monospacedDigit())
                            .foregroundColor(value == nil ? Color.white.opacity(0.25)
                                : isBest ? Color(red: 1.0, green: 0.82, blue: 0.3) : .white)
                            .lineLimit(1)
                        delta(value, prev)
                        delta(s.year == currentYear ? nil : value, current)
                        delta(target > 0 ? value : nil, targetNow)
                    }
                    .padding(.vertical, 4)
                    .opacity(isDimmed(s) ? 0.35 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedYear = focusedYear == s.year ? nil : s.year
                    }
                    .help(focusedYear == s.year ? "Show all years" : "Show only \(String(s.year))")
                }

                if target > 0 {
                    Divider().overlay(Color.white.opacity(0.06))
                    GridRow {
                        Text("Target")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Self.targetColor)
                        cell(fmt(targetNow), color: Color.white.opacity(0.7))
                        cell(nil)
                        delta(targetNow, current)
                        cell(nil)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(Color.white.opacity(0.4))
    }

    private func cell(_ text: String?, color: Color = Color.white.opacity(0.25)) -> some View {
        Text(text ?? "–")
            .font(.system(size: 11, design: .rounded).monospacedDigit())
            .foregroundColor(text == nil ? Color.white.opacity(0.25) : color)
            .lineLimit(1)
    }

    @ViewBuilder
    private func delta(_ value: Double?, _ other: Double?) -> some View {
        if let value, let other {
            let diff = value - other
            Text("\(diff >= 0 ? "+" : "−")\(fmt(abs(diff)))")
                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundColor(diff >= 0 ? Self.green : Self.red)
                .lineLimit(1)
        } else {
            cell(nil)
        }
    }
}
