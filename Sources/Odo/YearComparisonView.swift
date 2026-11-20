import SwiftUI
import Charts

struct YearComparisonView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @State private var metric = "distance"

    var body: some View {
        if let sport = viewModel.selectedSport {
            YearChart(
                series: buildSeries(sport: sport),
                target: targetFor(sport),
                currentYear: viewModel.currentYear,
                today: viewModel.currentDayOfYear,
                unit: unitFor(metric),
                useTimeFormat: metric == "time",
                titleBar: AnyView(titleBar)
            )
        }
    }

    private var titleBar: some View {
        HStack(spacing: 12) {
            Text("Year comparison")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            ForEach([("distance", "Distance"), ("elevation", "Elevation"), ("time", "Time")], id: \.0) { key, label in
                Button(action: { metric = key }) {
                    Text(label)
                        .font(.system(size: 11, weight: metric == key ? .medium : .regular))
                        .foregroundColor(metric == key ? Theme.ink : Theme.textTertiary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func buildSeries(sport: SportCategory) -> [YearSeries] {
        let years = [viewModel.currentYear] + viewModel.visibleComparisonYears
        return years.map { year in
            YearSeries(
                year: year,
                values: viewModel.cumulativeDaily(year, sport: sport, metric: metric),
                color: year == viewModel.currentYear ? Theme.accent : Theme.ink,
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
    /// Title + metric switch, pinned along with the graph
    let titleBar: AnyView

    @State private var hoverDay: Int?
    @State private var lockedDay: Int?
    @State private var focusedYear: Int?
    @State private var hoveredYear: Int?

    /// Clicked year wins; otherwise the table row under the mouse
    private var highlightedYear: Int? { focusedYear ?? hoveredYear }

    private func isDimmed(_ s: YearSeries) -> Bool {
        focusedYear != nil && focusedYear != s.year
    }

    /// Draw order: past years, then current, then the highlighted year on top
    private var drawOrder: [YearSeries] {
        let base = Array(series.reversed())
        guard let highlightedYear else { return base }
        return base.filter { $0.year != highlightedYear } + base.filter { $0.year == highlightedYear }
    }

    private func lineColor(_ s: YearSeries) -> Color {
        if s.year == highlightedYear { return s.year == currentYear ? Theme.accent : Theme.ink.opacity(0.85) }
        if focusedYear != nil { return Theme.ink.opacity(0.08) }
        if s.year == currentYear { return Theme.accent }
        return Theme.ink.opacity(hoveredYear == nil ? 0.18 : 0.1)
    }

    private func lineWidth(_ s: YearSeries) -> CGFloat {
        s.year == highlightedYear || s.year == currentYear ? 2 : 1
    }

    private static let targetColor = Theme.ink.opacity(0.3)
    private static let quarterStarts = [1, 91, 182, 274]
    private static let quarterLabels = ["Jan", "Apr", "Jul", "Oct"]

    private var daysInYear: Int {
        let cal = Calendar.current
        return cal.date(from: DateComponents(year: currentYear, month: 1, day: 1))
            .flatMap { cal.range(of: .day, in: .year, for: $0)?.count } ?? 365
    }

    private var selectedDay: Int { lockedDay ?? hoverDay ?? today }

    /// Podium on the selected day: year -> place (1, 2, 3)
    private var podium: [Int: Int] {
        let ranked = series
            .compactMap { s in s.value(on: selectedDay).map { (s.year, $0) } }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        return Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($1.0, $0 + 1) })
    }

    private var bestYear: Int? { podium.first { $0.value == 1 }?.key }

    private static func medalColor(_ place: Int) -> Color {
        switch place {
        case 1: return Theme.gold
        case 2: return Theme.silver
        default: return Theme.bronze
        }
    }

    private func targetValue(on day: Int) -> Double {
        target * Double(day) / Double(daysInYear)
    }

    private func fmt(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : formatNumber(value, decimals: value >= 1000 ? 0 : 1)
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
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                // Table card: square top (the pinned lip above provides the rounded top)
                readout
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                    .background(RoundedCornersShape(radius: 14, top: false, bottom: true).fill(Theme.card))
            } header: {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        titleBar
                        hero
                        VStack(spacing: 6) {
                            chart
                                .frame(height: 170)
                            scrubBar
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.card)
                    )

                    // Gap, then the table card's rounded top edge. Pinned with the graph
                    // so rows scroll *under* a rounded edge instead of being cut off.
                    Color.clear.frame(height: 8)
                    RoundedCornersShape(radius: 14, top: true, bottom: false)
                        .fill(Theme.card)
                        .frame(height: 14)
                }
                .padding(.top, 6)
                // Page background behind everything so rounded corners stay visible
                .background(Theme.background)
            }
        }
    }

    // MARK: - Scrub hint

    /// Sits under the graph, so the hint and Today stay with what you're scrubbing
    private var scrubBar: some View {
        HStack {
            Text(lockedDay != nil ? "Locked to \(dateLabel(for: selectedDay).replacingOccurrences(of: "1 Jan → ", with: ""))" : "Hover to scrub · click to lock")
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
            Spacer()
            let lockedToToday = lockedDay == today
            Button(action: { lockedDay = lockedToToday ? nil : today }) {
                Text(lockedToToday ? "Unlock" : "Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .underline(lockedToToday)
            }
            .buttonStyle(.borderless)
            .help(lockedToToday ? "Unlock" : "Lock graph to today")
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
                ForEach(plotPoints(s), id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Value", point.value),
                        series: .value("Series", String(s.year))
                    )
                    .foregroundStyle(lineColor(s))
                    .lineStyle(StrokeStyle(lineWidth: lineWidth(s), lineCap: .round, lineJoin: .round))
                }
            }

            // "If you stopped today" — hold the current total flat to year end
            if let current = series.first(where: { $0.year == currentYear }),
               let last = current.values.last, current.lastDay < daysInYear {
                ForEach([current.lastDay, daysInYear], id: \.self) { day in
                    LineMark(x: .value("Day", day), y: .value("Value", last), series: .value("Series", "Hold"))
                        .foregroundStyle(Theme.accent.opacity(isDimmed(current) ? 0.1 : 0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 3]))
                }
            }

            RuleMark(x: .value("Day", selectedDay))
                .foregroundStyle(Theme.ink.opacity(lockedDay != nil ? 0.35 : 0.15))
                .lineStyle(StrokeStyle(lineWidth: 1))

            // Dots only for this year and the highlighted year
            ForEach(series.filter { $0.year == currentYear || $0.year == highlightedYear }) { s in
                if let v = s.value(on: selectedDay) {
                    PointMark(x: .value("Day", selectedDay), y: .value("Value", v))
                        .foregroundStyle(lineColor(s))
                        .symbolSize(28)
                }
            }
        }
        .chartXScale(domain: 0...daysInYear)
        .chartXAxis {
            AxisMarks(values: Self.quarterStarts) { value in
                AxisValueLabel(anchor: .topLeading) {
                    if let day = value.as(Int.self), let i = Self.quarterStarts.firstIndex(of: day) {
                        Text(Self.quarterLabels[i])
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
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

    // MARK: - Hero

    /// Nike-style: this year's total on the selected day, big
    private var hero: some View {
        let current = series.first { $0.year == currentYear }?.value(on: selectedDay) ?? 0
        let vsTarget = current - targetValue(on: selectedDay)

        return HStack(alignment: .lastTextBaseline) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(useTimeFormat ? "\(Int(current))" : formatNumber(current, decimals: current >= 100 ? 0 : 1))
                    .font(.system(size: 34, weight: .black).width(.condensed).italic())
                    .tracking(-0.5)
                    .foregroundColor(Theme.ink)
                Text(useTimeFormat ? "hrs" : unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if target > 0 {
                    Text("\(vsTarget >= 0 ? "+" : "−")\(fmt(abs(vsTarget))) vs target")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(vsTarget >= 0 ? Theme.positive : Theme.negative)
                }
                Text(dateLabel(for: selectedDay))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - Readout

    private var readout: some View {
        let current = series.first { $0.year == currentYear }?.value(on: selectedDay)
        let targetNow = targetValue(on: selectedDay)

        return VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 7) {
                GridRow {
                    header("Year", alignment: .leading).gridColumnAlignment(.leading)
                    header(unit)
                    header("vs prev")
                    header("vs \(String(currentYear))")
                    header("vs target")
                }

                ForEach(Array(series.enumerated()), id: \.element.id) { index, s in
                    let value = s.value(on: selectedDay)
                    let prev = index + 1 < series.count ? series[index + 1].value(on: selectedDay) : nil
                    let isBest = s.year == bestYear
                    let isCurrent = s.year == currentYear

                    GridRow {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isCurrent ? Theme.accent : Theme.ink.opacity(s.year == highlightedYear ? 0.85 : 0.2))
                                .frame(width: 6, height: 6)
                            Text(String(s.year))
                                .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                                .foregroundColor(isCurrent || s.year == highlightedYear ? Theme.ink : Theme.textSecondary)
                            if let place = podium[s.year] {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 7))
                                    .foregroundColor(Self.medalColor(place))
                                    .help(["1st", "2nd", "3rd"][place - 1] + " on this day")
                            }
                        }
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        cell(value.map(fmt), color: Theme.ink, weight: isBest ? .semibold : .regular)
                        delta(value, prev)
                        delta(isCurrent ? nil : value, current)
                        delta(target > 0 ? value : nil, targetNow)
                    }
                    .opacity(isDimmed(s) ? 0.35 : 1)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { hoveredYear = s.year } else if hoveredYear == s.year { hoveredYear = nil }
                    }
                    .onTapGesture {
                        focusedYear = focusedYear == s.year ? nil : s.year
                    }
                    .help(focusedYear == s.year ? "Show all years" : "Show only \(String(s.year))")
                }

                if target > 0 {
                    GridRow {
                        HStack(spacing: 5) {
                            Rectangle()
                                .fill(Self.targetColor)
                                .frame(width: 6, height: 1)
                            Text("Target")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        cell(fmt(targetNow), color: Theme.textSecondary)
                        cell(nil)
                        delta(targetNow, current)
                        cell(nil)
                    }
                }
            }
        }
    }

    private func header(_ text: String, alignment: Alignment = .trailing) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func cell(_ text: String?, color: Color = Theme.textTertiary, weight: Font.Weight = .regular) -> some View {
        Text(text ?? "–")
            .font(.system(size: 11, weight: weight).monospacedDigit())
            .foregroundColor(text == nil ? Theme.ink.opacity(0.2) : color)
            .lineLimit(1)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func delta(_ value: Double?, _ other: Double?) -> some View {
        if let value, let other {
            let diff = value - other
            Text("\(diff >= 0 ? "+" : "−")\(fmt(abs(diff)))")
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(diff >= 0 ? Theme.positive : Theme.negative)
                .lineLimit(1)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            cell(nil)
        }
    }
}

/// Rectangle with rounded corners on only the top and/or bottom edge (macOS 13 compatible)
struct RoundedCornersShape: Shape {
    var radius: CGFloat
    var top: Bool
    var bottom: Bool

    func path(in rect: CGRect) -> Path {
        let tr = top ? min(radius, rect.height / 2) : 0
        let br = bottom ? min(radius, rect.height / 2) : 0
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        if tr > 0 {
            p.addArc(center: CGPoint(x: rect.minX + tr, y: rect.minY + tr), radius: tr,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr,
                     startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        if br > 0 {
            p.addArc(center: CGPoint(x: rect.minX + br, y: rect.maxY - br), radius: br,
                     startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}
