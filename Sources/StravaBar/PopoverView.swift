import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if !viewModel.isAuthenticated {
                SetupView(viewModel: viewModel)
            } else if viewModel.isLoading && viewModel.activities.isEmpty {
                loadingView
            } else {
                sportTabs
                subTypeToggles

                ScrollView {
                    StatsContentView(viewModel: viewModel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }

                footerView
            }
        }
        .frame(width: 360, height: 540)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .foregroundColor(Theme.accent)
                    .font(.system(size: 14, weight: .semibold))
                Text("StravaBar")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()

            if viewModel.isAuthenticated {
                if viewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                        Text(viewModel.syncStatus.description)
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                } else if case .rateLimited = viewModel.syncStatus {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent)
                        Text(viewModel.syncStatus.description)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent)
                            .lineLimit(1)
                    }
                } else {
                    if case .done = viewModel.syncStatus {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.4, green: 0.85, blue: 0.5))
                    }

                    Button(action: {
                        Task { await viewModel.fetchAllData() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh data")
                }

                Button(action: {
                    SettingsWindowController.shared.open(viewModel: viewModel)
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .buttonStyle(.borderless)
            .help("Quit StravaBar")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Sport Tabs

    private var sportTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.availableSports) { sport in
                    Button(action: { viewModel.selectedSport = sport }) {
                        Text(sport.rawValue)
                            .font(.system(size: 11, weight: viewModel.selectedSport == sport ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedSport == sport
                                    ? Theme.accent.opacity(0.2)
                                    : Color.white.opacity(0.05)
                            )
                            .foregroundColor(
                                viewModel.selectedSport == sport
                                    ? Theme.accent
                                    : Color.white.opacity(0.5)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Sub-type Toggles

    @ViewBuilder
    private var subTypeToggles: some View {
        if let sport = viewModel.selectedSport {
            let subTypes = viewModel.subTypes(for: sport)
            if subTypes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(subTypes, id: \.self) { subType in
                            let included = viewModel.isSubTypeIncluded(subType, sport: sport)
                            Button(action: {
                                viewModel.setSubType(subType, sport: sport, included: !included)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: included ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 10))
                                    Text(subTypeDisplayName(subType))
                                        .font(.system(size: 10, weight: included ? .medium : .regular))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(included ? Theme.accent : Color.white.opacity(0.35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(included ? Theme.accent.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.borderless)
                            .help(included ? "Exclude \(subTypeDisplayName(subType))" : "Include \(subTypeDisplayName(subType))")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(Theme.accent)
            Text("Loading activities...")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.4))
            Spacer()
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(lastUpdated.timeAgoDisplay())")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.25))
            }

            Spacer()

            Button("Disconnect") {
                viewModel.disconnect()
            }
            .font(.system(size: 10))
            .buttonStyle(.borderless)
            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Per-Sport Goal Editor

struct SportGoalRow: View {
    let sport: SportCategory
    @ObservedObject var settings: AppSettings
    @ObservedObject var viewModel: StravaViewModel

    @State private var distance: Double
    @State private var elevation: Double
    @State private var time: Double

    init(sport: SportCategory, settings: AppSettings, viewModel: StravaViewModel) {
        self.sport = sport
        self.settings = settings
        self.viewModel = viewModel
        let goal = settings.goalFor(sport)
        _distance = State(initialValue: goal.distanceMiles)
        _elevation = State(initialValue: goal.elevationFeet)
        _time = State(initialValue: goal.timeHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(sport.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)

                if let last = viewModel.lastYearStats(for: sport) {
                    Text("(\(viewModel.currentYear - 1): \(formatNumber(last.totalDistance)) \(settings.distanceUnit), \(formatNumber(last.totalElevation)) \(settings.elevationUnit), \(formatTime(last.totalTime)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 6) {
                TextField("0", value: $distance, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .onChange(of: distance) { val in
                        settings.setGoal(SportGoal(distanceMiles: val, elevationFeet: elevation, timeHours: time), for: sport)
                    }
                Text(settings.distanceUnit)
                    .foregroundColor(.secondary)

                TextField("0", value: $elevation, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .onChange(of: elevation) { val in
                        settings.setGoal(SportGoal(distanceMiles: distance, elevationFeet: val, timeHours: time), for: sport)
                    }
                Text(settings.elevationUnit)
                    .foregroundColor(.secondary)

                TextField("0", value: $time, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .onChange(of: time) { val in
                        settings.setGoal(SportGoal(distanceMiles: distance, elevationFeet: elevation, timeHours: val), for: sport)
                    }
                Text("hrs")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}
