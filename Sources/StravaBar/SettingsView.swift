import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("settings_tab") private var tab = "general"

    private let tabs: [(id: String, title: String, icon: String)] = [
        ("general", "General", "gearshape"),
        ("goals", "Goals", "target"),
        ("sports", "Sports", "figure.mixed.cardio"),
        ("account", "Account", "person.crop.circle"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            PillTabs(tabs: tabs, selection: $tab)
                .padding(.horizontal, 20)
                .padding(.top, 34) // clear the transparent title bar
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case "goals": GoalsSettings(viewModel: viewModel, settings: settings)
                    case "sports": SportsSettings(viewModel: viewModel, settings: settings)
                    case "account": AccountSettings(viewModel: viewModel)
                    default: GeneralSettings(viewModel: viewModel, settings: settings)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 420, height: 560)
        .background(Theme.background)
        .ignoresSafeArea()
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    var body: some View {
        SettingsSection("Menu bar") {
            // Live preview, styled like the menu bar item
            HStack(spacing: 6) {
                Image(systemName: viewModel.menuBarSportCategory?.icon ?? "figure.run")
                    .font(.system(size: 11))
                Text(viewModel.menuBarText)
                    .font(.system(size: 12).monospacedDigit())
            }
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.cardRaised)
            .cornerRadius(7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            SettingsDivider()

            SettingsRow("Sport") {
                Picker("", selection: $settings.menuBarSport) {
                    ForEach(viewModel.detectedSports) { sport in
                        Text(sport.rawValue).tag(sport.rawValue)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow("Show") {
                Picker("", selection: $settings.menuBarMetric) {
                    Text("Distance").tag("distance")
                    Text("Elevation").tag("elevation")
                    Text("Time").tag("time")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow("Show goal", detail: "e.g. 3,326 / 5,200 mi") {
                Toggle("", isOn: $settings.menuBarShowGoal).settingsSwitch()
            }
        }

        SettingsSection("Units") {
            SettingsRow("Units") {
                Picker("", selection: $settings.useMetricUnits) {
                    Text("Miles · feet").tag(false)
                    Text("Km · metres").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }

        SettingsSection("App") {
            SettingsRow("Auto-refresh") {
                Picker("", selection: $settings.refreshIntervalMinutes) {
                    Text("Manual").tag(0)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: settings.refreshIntervalMinutes) { _ in
                    viewModel.startRefreshTimer()
                }
            }
            SettingsDivider()
            SettingsRow("Launch at startup", detail: launchAtLoginError) {
                Toggle("", isOn: Binding(
                    get: { launchAtLogin },
                    set: { enabled in
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                            launchAtLoginError = nil
                        } catch {
                            launchAtLoginError = error.localizedDescription
                        }
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                ))
                .settingsSwitch()
            }
        }
    }
}

// MARK: - Goals

private struct GoalsSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings
    @State private var selected: SportCategory?

    private var sport: SportCategory? { selected ?? viewModel.availableSports.first }

    var body: some View {
        if viewModel.availableSports.isEmpty {
            EmptyNote("No sports yet. Sync your Strava activities first.")
        } else if let sport {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sport.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.ink)
                    Text("\(String(viewModel.currentYear)) targets · 0 hides a goal")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                SportIconTabs(sports: viewModel.availableSports, selection: Binding(
                    get: { sport },
                    set: { selected = $0 }
                ))
            }

            GoalEditor(sport: sport, settings: settings, viewModel: viewModel)
                .id(sport) // reset field state when switching sport
        }
    }
}

private struct GoalEditor: View {
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
        let last = viewModel.lastYearStats(for: sport)
        let lastYear = String(viewModel.currentYear - 1)

        VStack(spacing: 10) {
            BigNumberField(label: "Distance", icon: "ruler", value: $distance, unit: settings.distanceUnit,
                           hint: last.map { "\(lastYear): \(formatNumber($0.totalDistance, decimals: 0)) \(settings.distanceUnit)" })
            BigNumberField(label: "Elevation", icon: "arrow.up.right", value: $elevation, unit: settings.elevationUnit,
                           hint: last.map { "\(lastYear): \(formatNumber($0.totalElevation, decimals: 0)) \(settings.elevationUnit)" })
            BigNumberField(label: "Time", icon: "clock", value: $time, unit: "hrs",
                           hint: last.map { "\(lastYear): \(formatTime($0.totalTime))" })
        }
        .onChange(of: distance) { _ in save() }
        .onChange(of: elevation) { _ in save() }
        .onChange(of: time) { _ in save() }
    }

    private func save() {
        settings.setGoal(SportGoal(distanceMiles: distance, elevationFeet: elevation, timeHours: time), for: sport)
    }
}

/// Nike-style goal input: small label, huge condensed number you can type into
private struct BigNumberField: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let unit: String
    let hint: String?

    private static let numberFont = Font.system(size: 38, weight: .black).width(.condensed).italic()

    private var daysInYear: Double {
        Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
    }

    /// Goal split evenly across the year
    private var breakdown: String {
        let perWeek = value / (daysInYear / 7)
        let perDay = value / daysInYear
        if unit == "hrs" {
            return "≈ \(formatTime(perWeek)) per week · \(formatTime(perDay)) per day"
        }
        func n(_ v: Double) -> String { formatNumber(v, decimals: v >= 100 ? 0 : 1) }
        return "≈ \(n(perWeek)) \(unit) per week · \(n(perDay)) \(unit) per day"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                if let hint {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .foregroundColor(Theme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                // Hidden text sizes the field to its content, so the unit sits right after the number
                ZStack(alignment: .leading) {
                    Text(formatNumber(value, decimals: 0) + "0")
                        .font(Self.numberFont)
                        .hidden()
                    TextField("0", value: $value, format: .number)
                        .textFieldStyle(.plain)
                        .font(Self.numberFont)
                        .foregroundColor(value > 0 ? Theme.ink : Theme.textTertiary)
                }
                .fixedSize()
                Text(unit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }

            Text(value > 0 ? breakdown : "No goal · hidden from the popover")
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(Theme.textTertiary)
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
    }
}

// MARK: - Sports

private struct SportsSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        if viewModel.detectedSports.isEmpty {
            EmptyNote("No sports yet. Sync your Strava activities first.")
        } else {
            SettingsSection("Sports", footer: "Shown as tabs in the menu bar popover.") {
                ForEach(Array(viewModel.detectedSports.enumerated()), id: \.element.id) { index, sport in
                    if index > 0 { SettingsDivider() }
                    SettingsRow(sport.rawValue, icon: sport.icon) {
                        Toggle("", isOn: Binding(
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
                        .settingsSwitch()
                    }
                }
            }
        }

        let previousYears = viewModel.yearsWithData.filter { $0 != viewModel.currentYear }
        if !previousYears.isEmpty {
            SettingsSection("Years to compare", footer: "Previous years shown in Year comparison.") {
                FlowLayout(spacing: 6) {
                    ForEach(previousYears, id: \.self) { year in
                        let on = settings.visibleYears.isEmpty || settings.visibleYears.contains(year)
                        Button(action: { toggle(year, in: previousYears) }) {
                            Text(String(year))
                                .font(.system(size: 11, weight: on ? .medium : .regular).monospacedDigit())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .foregroundColor(on ? Theme.ink : Theme.textTertiary)
                                .background(on ? Theme.cardRaised : Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.hairline, lineWidth: 1))
                                .cornerRadius(7)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func toggle(_ year: Int, in all: [Int]) {
        if settings.visibleYears.isEmpty { settings.visibleYears = Set(all) }
        if settings.visibleYears.contains(year) {
            settings.visibleYears.remove(year)
        } else {
            settings.visibleYears.insert(year)
        }
    }
}

// MARK: - Account

private struct AccountSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @State private var showDisconnectConfirm = false

    var body: some View {
        SettingsSection("Strava") {
            SettingsRow(viewModel.isAuthenticated ? "Connected" : "Not connected",
                        detail: viewModel.lastUpdated.map { "Last synced \($0.timeAgoDisplay())" },
                        icon: viewModel.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle") {
                if viewModel.isAuthenticated {
                    Button("Sync now") { Task { await viewModel.fetchAllData() } }
                        .disabled(viewModel.isLoading)
                }
            }
        }

        if viewModel.isAuthenticated {
            SettingsSection("Disconnect", footer: "Removes your Strava login and cached activities from this Mac.") {
                SettingsRow("Disconnect from Strava") {
                    Button("Disconnect", role: .destructive) { showDisconnectConfirm = true }
                }
            }
            .confirmationDialog("Disconnect from Strava?", isPresented: $showDisconnectConfirm) {
                Button("Disconnect", role: .destructive) { viewModel.disconnect() }
            } message: {
                Text("This removes your Strava login and cached activities from this Mac.")
            }
        }
    }
}

// MARK: - Building blocks

/// Segmented pill tabs, matching the popover's Goals / Year comparison switch
struct PillTabs: View {
    let tabs: [(id: String, title: String, icon: String)]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.id) { tab in
                let selected = selection == tab.id
                Button(action: { selection = tab.id }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(tab.title)
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
        }
        .padding(3)
        .background(Theme.card)
        .cornerRadius(10)
    }
}

/// Icon-only sport switcher, matching the popover header
struct SportIconTabs: View {
    let sports: [SportCategory]
    @Binding var selection: SportCategory

    var body: some View {
        HStack(spacing: 2) {
            ForEach(sports) { sport in
                let selected = selection == sport
                Button(action: { selection = sport }) {
                    Image(systemName: sport.icon)
                        .font(.system(size: 13, weight: selected ? .medium : .regular))
                        .foregroundColor(selected ? Theme.ink : Theme.textTertiary)
                        .frame(width: 30, height: 26)
                        .background(selected ? Theme.cardRaised : Color.clear)
                        .cornerRadius(7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(sport.rawValue)
            }
        }
        .padding(2)
        .background(Theme.card)
        .cornerRadius(9)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Theme.card)
            .cornerRadius(14)

            if let footer {
                Text(footer)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String?
    let icon: String?
    let control: Control

    init(_ title: String, detail: String? = nil, icon: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Spacer(minLength: 12)
            control
                .controlSize(.small)
        }
        .padding(.vertical, 9)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

private struct EmptyNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Theme.card)
            .cornerRadius(14)
    }
}

private extension View {
    func settingsSwitch() -> some View {
        self.labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.accent)
    }
}
