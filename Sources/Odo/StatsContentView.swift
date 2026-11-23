import SwiftUI

struct StatsContentView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("stats_tab") private var tab = "goals"
    @State private var showFilters = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let stats = viewModel.currentYearStats
            let goal = viewModel.selectedSport.map { settings.goalFor($0) }
                ?? SportGoal(distanceMiles: 0, elevationFeet: 0)

            HStack(spacing: 6) {
                tabBar
                filterButton
            }

            if showFilters, let sport = viewModel.selectedSport {
                SubTypeFilterChips(viewModel: viewModel, sport: sport)
                    .transition(.opacity)
            }

            if tab == "compare" {
                if viewModel.visibleComparisonYears.isEmpty {
                    Text("No previous years to compare")
                        .font(.caption)
                        .foregroundColor(Theme.ink.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Theme.card)
                        .cornerRadius(14)
                } else {
                    YearComparisonView(viewModel: viewModel)
                }
            } else if tab == "fitness" {
                FitnessView(viewModel: viewModel)
            } else {
                goalsContent(stats: stats, goal: goal)
            }

            if let error = viewModel.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.caption2)
                .foregroundColor(Theme.negative)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.negative.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private var filterButton: some View {
        if let sport = viewModel.selectedSport, viewModel.hasFilters(sport) {
            let filtering = viewModel.isFiltering(sport)
            Button(action: { withAnimation(.easeOut(duration: 0.15)) { showFilters.toggle() } }) {
                Image(systemName: filtering
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showFilters || filtering ? Theme.ink : Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(showFilters ? Theme.cardRaised : Theme.card)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(filtering ? "Activity types (filtered)" : "Filter activity types")
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            tabButton("Goals", icon: "target", value: "goals")
            tabButton("Years", icon: "chart.xyaxis.line", value: "compare")
            tabButton("Fitness", icon: "waveform.path.ecg", value: "fitness")
        }
        .padding(3)
        .background(Theme.card)
        .cornerRadius(10)
    }

    private func tabButton(_ title: String, icon: String, value: String) -> some View {
        let selected = tab == value
        return Button(action: { tab = value }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: selected ? .medium : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundColor(selected ? Theme.ink : Theme.textSecondary)
            .background(selected ? Theme.cardRaised : Color.clear)
            .cornerRadius(7)
            .shadow(color: selected ? Color.black.opacity(0.06) : .clear, radius: 1, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func reached(_ metric: String, _ target: Double) -> Date? {
        guard let sport = viewModel.selectedSport else { return nil }
        return viewModel.goalReachedDate(sport: sport, metric: metric, goal: target)
    }

    /// Metric for the weekly card: distance, else elevation, else time
    private func primaryMetric(_ goal: SportGoal) -> (metric: String, goal: Double, unit: String)? {
        if goal.distanceMiles > 0 { return ("distance", goal.distanceMiles, settings.distanceUnit) }
        if goal.elevationFeet > 0 { return ("elevation", goal.elevationFeet, settings.elevationUnit) }
        if goal.timeHours > 0 { return ("time", goal.timeHours, "hrs") }
        return nil
    }

    private var weeksInYear: Double {
        Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365) / 7
    }

    /// The All tab's week: the combined total (against All's own goal if it
    /// has one, else time, which adds up fairly across sports), then each
    /// sport against its own weekly pace
    private func allWeek(goal: SportGoal) -> some View {
        let primary = primaryMetric(goal)
        let metric = primary?.metric ?? "time"
        let weeklyTarget = (primary?.goal ?? 0) / weeksInYear
        let week = viewModel.currentWeek(sport: .all, metric: metric)
        let streaks = weeklyTarget > 0
            ? viewModel.streaks(sport: .all, metric: metric, weeklyTarget: weeklyTarget)
            : (current: 0, best: 0)

        let breakdown: [SportWeek] = viewModel.availableSports.compactMap { sport in
            guard sport != .all else { return nil }
            let own = primaryMetric(settings.goalFor(sport))
            let m = own?.metric ?? metric
            let total = viewModel.currentWeek(sport: sport, metric: m).days.reduce(0, +)
            // Skip sports with no goal and nothing done this week
            guard own != nil || total > 0 else { return nil }
            return SportWeek(
                sport: sport,
                total: total,
                target: (own?.goal ?? 0) / weeksInYear,
                unit: own?.unit ?? (m == "time" ? "hrs" : primary?.unit ?? ""),
                useTimeFormat: m == "time"
            )
        }

        return WeekProgressView(
            start: week.start,
            days: week.days,
            weeklyTarget: weeklyTarget,
            unit: primary?.unit ?? "hrs",
            useTimeFormat: metric == "time",
            streak: streaks.current,
            bestStreak: streaks.best,
            breakdown: breakdown
        )
    }

    @ViewBuilder
    private func goalsContent(stats: YearStats, goal: SportGoal) -> some View {
            // This week, for the first goal that's set. All always gets one,
            // broken down by sport
            if viewModel.selectedSport == .all {
                allWeek(goal: goal)
            } else if let sport = viewModel.selectedSport, let primary = primaryMetric(goal) {
                let week = viewModel.currentWeek(sport: sport, metric: primary.metric)
                let daysInYear = Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
                let weeklyTarget = primary.goal / (daysInYear / 7)
                let streaks = viewModel.streaks(sport: sport, metric: primary.metric, weeklyTarget: weeklyTarget)
                WeekProgressView(
                    start: week.start,
                    days: week.days,
                    weeklyTarget: weeklyTarget,
                    unit: primary.unit,
                    useTimeFormat: primary.metric == "time",
                    streak: streaks.current,
                    bestStreak: streaks.best
                )
            }

            // Distance challenge
            if goal.distanceMiles > 0 {
                ChallengeProgressView(
                    title: "Distance",
                    icon: "ruler",
                    current: stats.totalDistance,
                    goal: goal.distanceMiles,
                    unit: settings.distanceUnit,
                    reachedOn: reached("distance", goal.distanceMiles)
                )
            }

            // Elevation challenge
            if goal.elevationFeet > 0 {
                ChallengeProgressView(
                    title: "Elevation",
                    icon: "arrow.up.right",
                    current: stats.totalElevation,
                    goal: goal.elevationFeet,
                    unit: settings.elevationUnit,
                    reachedOn: reached("elevation", goal.elevationFeet)
                )
            }

            // Time challenge
            if goal.timeHours > 0 {
                ChallengeProgressView(
                    title: "Time",
                    icon: "clock",
                    current: stats.totalTime,
                    goal: goal.timeHours,
                    unit: "hrs",
                    useTimeFormat: true,
                    reachedOn: reached("time", goal.timeHours)
                )
            }

            if goal.distanceMiles <= 0 && goal.elevationFeet <= 0 && goal.timeHours <= 0 {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No goals set")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        if let sport = viewModel.selectedSport, !viewModel.smartSuggestions(for: sport).isEmpty {
                            Button(action: { viewModel.applyDefaultSmartGoals(for: sport) }) {
                                Label("Suggest goals", systemImage: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundColor(Theme.background)
                                    .background(Theme.ink)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.borderless)
                            .padding(.top, 4)
                            Text("Beats your recent years by \(settings.smartBeatPercent)% · change in Settings")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        } else {
                            Text("Set goals in Settings")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Theme.card)
                .cornerRadius(14)
            }

    }
}
