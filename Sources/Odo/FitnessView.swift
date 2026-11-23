import SwiftUI
import Charts

/// The Fitness tab: fitness, fatigue and form over the last few weeks to all time
struct FitnessView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("fitness_range") private var range = 90

    private static let ranges: [(days: Int, label: String)] = [(42, "6W"), (90, "3M"), (182, "6M"), (365, "1Y"), (0, "All")]

    var body: some View {
        if let sport = viewModel.selectedSport {
            let history = viewModel.fitnessHistory(sport: sport)
            if history.days.isEmpty {
                Text("No activities yet")
                    .font(.caption)
                    .foregroundColor(Theme.ink.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Theme.card)
                    .cornerRadius(14)
            } else {
                FitnessChart(
                    days: range > 0 ? Array(history.days.suffix(range + 1)) : history.days,
                    titleBar: AnyView(titleBar)
                )
                .id("\(sport.rawValue)-\(range)") // drop a locked day when the window changes
                footnote(history)
            }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 12) {
            Text("Fitness")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            ForEach(Self.ranges, id: \.days) { option in
                Button(action: { range = option.days }) {
                    Text(option.label)
                        .font(.system(size: 11, weight: range == option.days ? .medium : .regular))
                        .foregroundColor(range == option.days ? Theme.ink : Theme.textTertiary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// Where the load came from, so the numbers can be trusted (or not)
    private func footnote(_ history: FitnessHistory) -> some View {
        let text: String
        if history.total == 0 {
            text = "No activities in the last year."
        } else if viewModel.effectiveMaxHeartRate == nil || history.heartRate == 0 {
            text = "No heart rate on your activities, so load is estimated from time and sport."
        } else {
            let percent = Int((Double(history.heartRate) / Double(history.total) * 100).rounded())
            let rest = history.total > history.heartRate ? "; the rest from Relative Effort or time" : ""
            text = "Load from heart rate on \(percent)% of the last year's activities\(rest)."
        }
        return HStack(alignment: .top, spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(Theme.textTertiary)
        .padding(.horizontal, 4)
        .help("""
            Fitness is your average daily training load over about six weeks, fatigue over about a week. \
            Form is fitness minus fatigue: negative while you're training hard, positive once you've rested. \
            Heart rate load uses your max and resting heart rate, set in Settings → General.
            """)
    }
}

struct FitnessChart: View {
    /// The visible window, oldest first, ending today
    let days: [Fitness.Day]
    let titleBar: AnyView

    @State private var hoverIndex: Int?
    @State private var lockedIndex: Int?

    private var todayIndex: Int { days.count - 1 }
    private var selectedIndex: Int { lockedIndex ?? hoverIndex ?? todayIndex }
    private var selected: Fitness.Day { days[selectedIndex] }

    private static let fatigueColor = Theme.ink.opacity(0.45)

    /// Days per drawn point: every day up to a year, then thinned so All stays quick.
    /// Scrubbing still reads exact days.
    private var step: Int { max(1, days.count / 365) }

    /// One point per step. Form keeps the bucket's most extreme day so spikes still show
    private var plotted: [(i: Int, day: Fitness.Day, form: Double)] {
        stride(from: 0, to: days.count, by: step).map { start in
            let bucket = days[start..<min(start + step, days.count)]
            let form = bucket.map(\.form).max { abs($0) < abs($1) } ?? 0
            return (start, days[start], form)
        } + (todayIndex % step == 0 ? [] : [(todayIndex, days[todayIndex], days[todayIndex].form)])
    }

    static func color(_ kind: Fitness.Zone.Kind) -> Color {
        switch kind {
        case .losing: return Theme.silver
        case .fresh: return Theme.positive
        case .neutral: return Theme.ink.opacity(0.3)
        case .building: return Theme.gold
        case .overreaching: return Theme.negative
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBar
            hero
            VStack(spacing: 4) {
                mainChart
                    .frame(height: 130)
                Text("Form")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                formChart
                    .frame(height: 46)
            }
            scrubBar
            stats
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
    }

    // MARK: - Hero

    private var hero: some View {
        let zone = Fitness.zone(form: selected.form)
        let earlier = selectedIndex >= 28 ? days[selectedIndex - 28].fitness : nil

        return HStack(alignment: .lastTextBaseline) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(selected.fitness.rounded()))")
                    .font(.system(size: 34, weight: .black).width(.condensed).italic())
                    .tracking(-0.5)
                    .foregroundColor(Theme.ink)
                Text("fitness")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Self.color(zone.kind))
                        .frame(width: 6, height: 6)
                    Text(zone.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.ink)
                }
                .help(zone.detail)
                if let earlier {
                    let change = Int((selected.fitness - earlier).rounded())
                    Text(change == 0 ? "No change in 4 weeks" : "\(signed(Double(change))) in 4 weeks")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(change == 0 ? Theme.textSecondary : change > 0 ? Theme.positive : Theme.negative)
                }
                Text(dateLabel(selected.date))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        let f = DateFormatter()
        f.dateFormat = cal.component(.year, from: date) == cal.component(.year, from: Date()) ? "EEE d MMM" : "d MMM yyyy"
        return f.string(from: date)
    }

    // MARK: - Charts

    /// Fitness as a filled line, fatigue as a thinner one over it
    private var mainChart: some View {
        // Fit the window's range, so drops and spikes show rather than sitting flat on a zero baseline
        let values = days.flatMap { [$0.fitness, $0.fatigue] }
        let high = max(values.max() ?? 1, 10)
        let low = values.min() ?? 0
        let top = high + (high - low) * 0.08
        let bottom = max(0, low - (high - low) * 0.2)

        return Chart {
            ForEach(plotted, id: \.i) { i, day, _ in
                AreaMark(x: .value("Day", i), yStart: .value("Base", bottom), yEnd: .value("Fitness", day.fitness),
                         series: .value("Series", "FitnessArea"))
                    .foregroundStyle(Theme.accent.opacity(0.14))
                    .interpolationMethod(.monotone)
            }
            ForEach(plotted, id: \.i) { i, day, _ in
                LineMark(x: .value("Day", i), y: .value("Value", day.fatigue), series: .value("Series", "Fatigue"))
                    .foregroundStyle(Self.fatigueColor)
                    .lineStyle(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            ForEach(plotted, id: \.i) { i, day, _ in
                LineMark(x: .value("Day", i), y: .value("Value", day.fitness), series: .value("Series", "Fitness"))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }

            RuleMark(x: .value("Day", selectedIndex))
                .foregroundStyle(Theme.ink.opacity(lockedIndex != nil ? 0.35 : 0.15))
                .lineStyle(StrokeStyle(lineWidth: 1))
            PointMark(x: .value("Day", selectedIndex), y: .value("Value", selected.fatigue))
                .foregroundStyle(Self.fatigueColor)
                .symbolSize(20)
            PointMark(x: .value("Day", selectedIndex), y: .value("Value", selected.fitness))
                .foregroundStyle(Theme.accent)
                .symbolSize(28)
        }
        .chartXScale(domain: 0...max(todayIndex, 1))
        .chartYScale(domain: bottom...top)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartOverlay(content: scrubOverlay)
    }

    /// Form as bars above and below zero, coloured by zone
    private var formChart: some View {
        let extent = max(plotted.map { abs($0.form) }.max() ?? 1, 10)

        return GeometryReader { geo in
            let barWidth = max(1, geo.size.width / CGFloat(plotted.count) * 0.7)
            Chart {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Theme.ink.opacity(0.12))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                ForEach(plotted, id: \.i) { i, _, form in
                    BarMark(x: .value("Day", i), yStart: .value("Zero", 0), yEnd: .value("Form", form),
                            width: .fixed(barWidth))
                        .foregroundStyle(Self.color(Fitness.zone(form: form).kind)
                            .opacity(i == selectedIndex ? 1 : 0.55))
                }
                RuleMark(x: .value("Day", selectedIndex))
                    .foregroundStyle(Theme.ink.opacity(lockedIndex != nil ? 0.35 : 0.15))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartXScale(domain: 0...max(todayIndex, 1))
            .chartYScale(domain: -extent...extent)
            .chartXAxis {
                AxisMarks(values: axisIndices) { value in
                    AxisValueLabel(anchor: .topLeading) {
                        if let i = value.as(Int.self), days.indices.contains(i) {
                            Text(axisLabel(days[i].date))
                                .font(.system(size: 9))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartOverlay(content: scrubOverlay)
        }
    }

    /// Short windows label each week, up to two years each month or two, longer ones each year or few
    private var axisIndices: [Int] {
        let cal = Calendar.current
        let years = days.count / 365
        let yearStep = years > 16 ? 4 : years > 8 ? 2 : 1
        return days.indices.filter { i in
            let date = days[i].date
            let day = cal.component(.day, from: date), month = cal.component(.month, from: date)
            if days.count <= 50 { return cal.component(.weekday, from: date) == cal.firstWeekday }
            if days.count <= 400 { return day == 1 && (month - 1) % (days.count > 200 ? 2 : 1) == 0 }
            if days.count <= 800 { return day == 1 && (month - 1) % 3 == 0 }
            return day == 1 && month == 1 && cal.component(.year, from: date) % yearStep == 0
        }
    }

    private func axisLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = days.count <= 50 ? "d MMM" : days.count <= 400 ? "MMM" : days.count <= 800 ? "MMM yy" : "yyyy"
        return f.string(from: date)
    }

    private func scrubOverlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location): hoverIndex = index(at: location, proxy: proxy, geo: geo)
                    case .ended: hoverIndex = nil
                    }
                }
                .onTapGesture { location in
                    lockedIndex = lockedIndex == nil ? index(at: location, proxy: proxy, geo: geo) : nil
                }
        }
    }

    private func index(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Int? {
        let originX = geo[proxy.plotAreaFrame].origin.x
        guard let x: Double = proxy.value(atX: location.x - originX) else { return nil }
        return min(max(Int(x.rounded()), 0), todayIndex)
    }

    // MARK: - Scrub hint and stats

    private var scrubBar: some View {
        HStack {
            Text(lockedIndex != nil ? "Locked to \(dateLabel(selected.date))" : "Hover to scrub · click to lock")
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
            Spacer()
            let lockedToToday = lockedIndex == todayIndex
            Button(action: { lockedIndex = lockedToToday ? nil : todayIndex }) {
                Text(lockedToToday ? "Unlock" : "Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .underline(lockedToToday)
            }
            .buttonStyle(.borderless)
            .help(lockedToToday ? "Unlock" : "Lock graph to today")
        }
    }

    private var stats: some View {
        let zone = Fitness.zone(form: selected.form)
        return HStack(alignment: .top, spacing: 0) {
            stat("\(Int(selected.fitness.rounded()))", "Fitness", dot: Theme.accent,
                 help: "Average daily load over about six weeks")
            Spacer(minLength: 8)
            stat("\(Int(selected.fatigue.rounded()))", "Fatigue", dot: Self.fatigueColor,
                 help: "Average daily load over about a week")
            Spacer(minLength: 8)
            stat(signed(selected.form), "Form", dot: Self.color(zone.kind),
                 help: "Fitness minus fatigue. \(zone.name): \(zone.detail.lowercased()).")
            Spacer(minLength: 8)
            stat(selected.load > 0 ? "\(Int(selected.load.rounded()))" : "–", "Load", dot: nil,
                 help: "Training load that day. About 100 is an hour flat out.")
        }
    }

    private func signed(_ value: Double) -> String {
        let n = Int(value.rounded())
        return n > 0 ? "+\(n)" : n < 0 ? "−\(-n)" : "0"
    }

    private func stat(_ value: String, _ label: String, dot: Color?, help: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(Theme.ink)
            HStack(spacing: 4) {
                if let dot {
                    Circle().fill(dot).frame(width: 5, height: 5)
                }
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .fixedSize()
        .help(help)
    }
}
