import SwiftUI

struct StatsContentView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("stats_tab") private var tab = "goals"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let stats = viewModel.currentYearStats
            let goal = viewModel.selectedSport.map { settings.goalFor($0) }
                ?? SportGoal(distanceMiles: 0, elevationFeet: 0)

            // Activity count + year
            HStack {
                Text("\(stats.activityCount) activities")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.4))
                Spacer()
                Text(String(viewModel.currentYear))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.accent)
            }

            tabBar

            if tab == "compare" {
                if viewModel.visibleComparisonYears.isEmpty {
                    Text("No previous years to compare")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.3))
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
                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton("Goals", icon: "target", value: "goals")
            tabButton("Year Comparison", icon: "chart.xyaxis.line", value: "compare")
        }
    }

    private func tabButton(_ title: String, icon: String, value: String) -> some View {
        let selected = tab == value
        return Button(action: { tab = value }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundColor(selected ? .white : Color.white.opacity(0.45))
            .background(selected ? Theme.card : Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? Theme.accent.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .cornerRadius(9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func goalsContent(stats: YearStats, goal: SportGoal) -> some View {
            // Distance challenge
            if goal.distanceMiles > 0 {
                ChallengeProgressView(
                    title: "DISTANCE",
                    icon: "ruler",
                    current: stats.totalDistance,
                    goal: goal.distanceMiles,
                    unit: settings.distanceUnit
                )
            }

            // Elevation challenge
            if goal.elevationFeet > 0 {
                ChallengeProgressView(
                    title: "ELEVATION",
                    icon: "arrow.up.right",
                    current: stats.totalElevation,
                    goal: goal.elevationFeet,
                    unit: settings.elevationUnit
                )
            }

            // Time challenge
            if goal.timeHours > 0 {
                ChallengeProgressView(
                    title: "TIME",
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
                            .foregroundColor(Color.white.opacity(0.4))
                        Text("Set goals in settings")
                            .font(.caption2)
                            .foregroundColor(Color.white.opacity(0.25))
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Theme.card)
                .cornerRadius(14)
            }

    }
}
