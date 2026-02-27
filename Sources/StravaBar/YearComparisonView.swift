import SwiftUI

struct YearComparisonView: View {
    @ObservedObject var viewModel: StravaViewModel
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

            let currentStats = viewModel.currentYearStats
            let previousYears = viewModel.visibleComparisonYears

            if previousYears.isEmpty {
                Text("No previous years to compare")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ForEach(previousYears, id: \.self) { year in
                    let stats = viewModel.selectedSport.map { viewModel.statsForYear(year, sport: $0) }
                        ?? YearStats(year: year)

                    YearRow(
                        year: year,
                        totalValue: valueFor(stats, metric: metric),
                        atThisPoint: atThisPointFor(stats, metric: metric),
                        currentValue: valueFor(currentStats, metric: metric),
                        unit: unitFor(metric),
                        useTimeFormat: metric == "time"
                    )
                }
            }
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
    }

    private func valueFor(_ stats: YearStats, metric: String) -> Double {
        switch metric {
        case "elevation": return stats.totalElevation
        case "time": return stats.totalTime
        default: return stats.totalDistance
        }
    }

    private func atThisPointFor(_ stats: YearStats, metric: String) -> Double {
        switch metric {
        case "elevation": return stats.elevationToDate
        case "time": return stats.timeToDate
        default: return stats.distanceToDate
        }
    }

    private func unitFor(_ metric: String) -> String {
        let settings = AppSettings.shared
        switch metric {
        case "elevation": return settings.elevationUnit
        case "time": return "hrs"
        default: return settings.distanceUnit
        }
    }
}

struct YearRow: View {
    let year: Int
    let totalValue: Double
    let atThisPoint: Double
    let currentValue: Double
    let unit: String
    var useTimeFormat: Bool = false

    private var difference: Double { currentValue - atThisPoint }

    private func fmt(_ value: Double) -> String {
        useTimeFormat ? formatTime(value) : formatNumber(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text("\(fmt(totalValue)) \(unit)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.35))
            }

            // Comparison bars
            GeometryReader { geo in
                let maxVal = max(currentValue, atThisPoint, 1)
                VStack(spacing: 3) {
                    // Previous year bar
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: max(4, (geo.size.width - 80) * (atThisPoint / maxVal)), height: 6)
                        Text(fmt(atThisPoint))
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.3))
                        Spacer()
                    }

                    // Current year bar
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.accent)
                            .frame(width: max(4, (geo.size.width - 80) * (currentValue / maxVal)), height: 6)

                        if atThisPoint > 0 || currentValue > 0 {
                            if difference >= 0 {
                                Text("+\(fmt(difference))")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.85, blue: 0.5))
                            } else {
                                Text("\(fmt(difference))")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
                            }
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 18)
        }
        .padding(.vertical, 6)
    }
}
