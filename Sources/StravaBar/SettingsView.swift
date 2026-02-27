import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Menu bar display
                Text("Menu Bar")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("Sport:")
                        .font(.caption)
                    Picker("", selection: $settings.menuBarSport) {
                        ForEach(viewModel.detectedSports) { sport in
                            Text(sport.rawValue).tag(sport.rawValue)
                        }
                    }
                    .labelsHidden()
                    .font(.caption)
                }

                HStack {
                    Text("Show:")
                        .font(.caption)
                    Picker("", selection: $settings.menuBarMetric) {
                        Text("Distance").tag("distance")
                        Text("Elevation").tag("elevation")
                        Text("Time").tag("time")
                    }
                    .pickerStyle(.segmented)
                    .font(.caption)
                }

                Toggle("Show goal", isOn: $settings.menuBarShowGoal)
                    .font(.caption)

                // Preview
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    Text(viewModel.menuBarText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)

                Divider()

                // Sport visibility
                if !viewModel.detectedSports.isEmpty {
                    Text("Sports")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Toggle which sports appear as tabs.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    ForEach(viewModel.detectedSports) { sport in
                        Toggle(sport.rawValue, isOn: Binding(
                            get: { !settings.hiddenSports.contains(sport.rawValue) },
                            set: { visible in
                                if visible {
                                    settings.hiddenSports.remove(sport.rawValue)
                                } else {
                                    settings.hiddenSports.insert(sport.rawValue)
                                }
                                viewModel.updateAvailableSports()
                            }
                        ))
                        .font(.caption)
                    }

                    Divider()
                }

                Text("Challenge Goals")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Set distance, elevation, and time targets per sport. Leave at 0 to hide.")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ForEach(viewModel.availableSports) { sport in
                    SportGoalRow(sport: sport, settings: settings, viewModel: viewModel)
                }

                Divider()

                Text("Years to Compare")
                    .font(.subheadline)
                    .fontWeight(.medium)

                let previousYears = viewModel.yearsWithData.filter { $0 != viewModel.currentYear }
                if previousYears.isEmpty {
                    Text("No previous years found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let columns = [GridItem(.adaptive(minimum: 70))]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                        ForEach(previousYears, id: \.self) { year in
                            Toggle(String(year), isOn: Binding(
                                get: {
                                    settings.visibleYears.isEmpty || settings.visibleYears.contains(year)
                                },
                                set: { visible in
                                    if settings.visibleYears.isEmpty {
                                        settings.visibleYears = Set(previousYears)
                                    }
                                    if visible {
                                        settings.visibleYears.insert(year)
                                    } else {
                                        settings.visibleYears.remove(year)
                                    }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .font(.caption)
                        }
                    }
                }

                Divider()

                // Units
                Text("Units")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("", selection: $settings.useMetricUnits) {
                    Text("Imperial (mi, ft)").tag(false)
                    Text("Metric (km, m)").tag(true)
                }
                .pickerStyle(.segmented)
                .font(.caption)

                Divider()

                HStack {
                    Text("Auto-refresh:")
                        .font(.caption)
                    Picker("", selection: $settings.refreshIntervalMinutes) {
                        Text("Manual only").tag(0)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .labelsHidden()
                    .font(.caption)
                    .onChange(of: settings.refreshIntervalMinutes) { _ in
                        viewModel.startRefreshTimer()
                    }
                }
            }
            .padding()
        }
    }
}
