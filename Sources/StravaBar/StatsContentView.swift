import SwiftUI

struct StatsContentView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared

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

            if !viewModel.visibleComparisonYears.isEmpty {
                YearComparisonView(viewModel: viewModel)
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
}
