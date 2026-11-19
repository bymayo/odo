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
            tabButton("Year Comparison", icon: "chart.xyaxis.line", value: "compare")
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

    @ViewBuilder
    private func goalsContent(stats: YearStats, goal: SportGoal) -> some View {
            // Distance challenge
            if goal.distanceMiles > 0 {
                ChallengeProgressView(
                    title: "Distance",
                    icon: "ruler",
                    current: stats.totalDistance,
                    goal: goal.distanceMiles,
                    unit: settings.distanceUnit
                )
            }

            // Elevation challenge
            if goal.elevationFeet > 0 {
                ChallengeProgressView(
                    title: "Elevation",
                    icon: "arrow.up.right",
                    current: stats.totalElevation,
                    goal: goal.elevationFeet,
                    unit: settings.elevationUnit
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
                    useTimeFormat: true
                )
            }

            if goal.distanceMiles <= 0 && goal.elevationFeet <= 0 && goal.timeHours <= 0 {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No challenge set")
                            .font(.caption)
                            .foregroundColor(Theme.ink.opacity(0.4))
                        Text("Set goals in settings")
                            .font(.caption2)
                            .foregroundColor(Theme.ink.opacity(0.25))
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Theme.card)
                .cornerRadius(14)
            }

    }
}
