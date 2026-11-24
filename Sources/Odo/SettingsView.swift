import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("settings_tab") private var tab = "general"

    struct Page: Identifiable {
        let id: String
        let title: String
        let icon: String
        let subtitle: String
    }

    static let pages: [Page] = [
        Page(id: "general", title: "General", icon: "gearshape", subtitle: "Units, refreshing and startup"),
        Page(id: "menubar", title: "Menu bar", icon: "menubar.rectangle", subtitle: "What the menu bar shows"),
        Page(id: "goals", title: "Goals", icon: "target", subtitle: ""),
        Page(id: "sports", title: "Sports", icon: "figure.mixed.cardio", subtitle: "Sport tabs and years to compare"),
        Page(id: "fitness", title: "Fitness", icon: "waveform.path.ecg", subtitle: "Heart rate for training load"),
        Page(id: "notifications", title: "Notifications", icon: "bell", subtitle: "Kudos, summaries and pace reminders"),
        Page(id: "account", title: "Account", icon: "person.crop.circle", subtitle: "Your Strava connection"),
        Page(id: "updates", title: "Updates", icon: "arrow.down.circle", subtitle: "Odo \(AppInfo.version)"),
        Page(id: "about", title: "About", icon: "info.circle", subtitle: "Who makes Odo"),
    ]

    private var page: Page { Self.pages.first { $0.id == tab } ?? Self.pages[0] }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.hairline).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(page.title)
                            .font(.odo(size: 22, weight: .bold))
                            .foregroundColor(Theme.ink)
                        if !page.subtitle.isEmpty {
                            Text(page.subtitle)
                                .font(.odo(size: 12))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .padding(.bottom, 2)

                    switch page.id {
                    case "menubar": MenuBarSettings(viewModel: viewModel, settings: settings)
                    case "goals": GoalsSettings(viewModel: viewModel, settings: settings)
                    case "sports": SportsSettings(viewModel: viewModel, settings: settings)
                    case "fitness": FitnessSettings(viewModel: viewModel, settings: settings)
                    case "notifications": NotificationsSection(viewModel: viewModel, settings: settings)
                    case "account": AccountSettings(viewModel: viewModel)
                    case "updates": UpdatesSection()
                    case "about": AboutSection()
                    default: GeneralSettings(viewModel: viewModel, settings: settings)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 40) // clear the transparent title bar
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(page.id) // start each page at the top
        }
        // Fill the window, title bar included, so no window background shows through
        .frame(minWidth: SettingsWindowController.size.width, maxWidth: .infinity,
               minHeight: SettingsWindowController.size.height, maxHeight: .infinity)
        .background(Theme.background)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                OdoMarkView(lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .frame(width: 24, height: 24)
                    .background(Theme.brandBlack)
                    .cornerRadius(6)
                Wordmark(size: 15)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 14)

            ForEach(Self.pages) { item in
                let selected = item.id == page.id
                Button(action: { tab = item.id }) {
                    HStack(spacing: 9) {
                        Image(systemName: item.icon)
                            .font(.odo(size: 12, weight: .medium))
                            .frame(width: 18)
                        Text(item.title)
                            .font(.odo(size: 13, weight: selected ? .medium : .regular))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .foregroundColor(selected ? Theme.ink : Theme.textSecondary)
                    .background(selected ? Theme.cardRaised : Color.clear)
                    .cornerRadius(7)
                    .shadow(color: selected ? Color.black.opacity(0.06) : .clear, radius: 1, y: 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            Text("Version \(AppInfo.version)")
                .font(.odo(size: 11))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 12)
        .padding(.top, 44) // below the traffic lights
        .padding(.bottom, 16)
        .frame(width: 190)
        .background(Theme.card.opacity(0.5))
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    var body: some View {
        SettingsSection("Units") {
            SettingsRow("Distance and elevation") {
                Picker("", selection: $settings.useMetricUnits) {
                    Text("Miles · feet").tag(false)
                    Text("Km · metres").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }

        SettingsSection("Syncing", footer: "How often Odo fetches new activities from Strava.") {
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
        }

        SettingsSection("Startup") {
            SettingsRow("Launch at login", detail: launchAtLoginError) {
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

// MARK: - Menu bar

private struct MenuBarSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        // Live preview, styled like the menu bar item
        HStack(spacing: 6) {
            Image(nsImage: OdoMark.menuBarImage())
                .renderingMode(.template)
            if settings.menuBarShowPace, let onPace = viewModel.menuBarOnPace {
                Circle()
                    .fill(onPace ? Color.green : Color.red)
                    .frame(width: 5, height: 5)
            }
            Text(viewModel.menuBarText)
                .font(.odo(size: 12).monospacedDigit())
        }
        .foregroundColor(Theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.cardRaised)
        .cornerRadius(7)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card)
        .cornerRadius(10)

        SettingsSection("Show") {
            SettingsRow("Sport") {
                Picker("", selection: $settings.menuBarSport) {
                    if viewModel.detectedSports.count > 1 {
                        Text(SportCategory.all.displayName).tag(SportCategory.all.rawValue)
                    }
                    ForEach(viewModel.detectedSports) { sport in
                        Text(sport.rawValue).tag(sport.rawValue)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow("Metric") {
                Picker("", selection: $settings.menuBarMetric) {
                    Text("Distance").tag("distance")
                    Text("Elevation").tag("elevation")
                    Text("Time").tag("time")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }

        SettingsSection("Extras", footer: "The sport also sets which goal the popover opens on, and what notifications report.") {
            SettingsRow("Show goal", detail: "e.g. 3,326 / 5,200 mi") {
                Toggle("", isOn: $settings.menuBarShowGoal).settingsSwitch()
            }
            SettingsDivider()
            SettingsRow("Pace dot", detail: "Green when on pace, red when behind") {
                Toggle("", isOn: $settings.menuBarShowPace).settingsSwitch()
            }
        }
    }
}

// MARK: - About

/// Links shown on the About page
enum AppLinks {
    static let website: URL? = URL(string: "https://odo.bymayo.co.uk")
    static let author = URL(string: "https://bymayo.co.uk")!
    static let github = URL(string: "https://github.com/bymayo")!
    static let x = URL(string: "https://x.com/madebymayo")!
}

/// Laid out like Cargo's About panel
private struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // The icon the app is actually running with
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Wordmark(size: 18)
                    Text("Version \(AppInfo.version)")
                        .font(.odo(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
            }

            if let website = AppLinks.website {
                SettingsDivider()
                HStack {
                    Text("Website")
                        .font(.odo(size: 14))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button(action: { NSWorkspace.shared.open(website) }) {
                        HStack(spacing: 5) {
                            Text(website.host ?? website.absoluteString)
                                .font(.odo(size: 13, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.odo(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Theme.ink)
                    }
                    .buttonStyle(.plain)
                }
            }

            SettingsDivider()

            VStack(alignment: .leading, spacing: 6) {
                Text("CREATED BY")
                    .font(.odo(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(Theme.textTertiary)
                HStack(spacing: 16) {
                    Text("Jason Mayo")
                        .font(.odo(size: 14, weight: .medium))
                        .foregroundColor(Theme.ink)
                    link("bymayo.co.uk", AppLinks.author)
                    link("GitHub", AppLinks.github)
                    link("X", AppLinks.x)
                }
            }

            SettingsDivider()

            Text("Odo is an independent project. It is not affiliated with, endorsed by or sponsored by Strava, Inc.")
                .font(.odo(size: 12))
                .foregroundColor(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Theme.card)
        .cornerRadius(14)
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Button(action: { NSWorkspace.shared.open(url) }) {
            Text(title)
                .font(.odo(size: 13))
                .underline()
                .foregroundColor(Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fitness

private struct FitnessSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsSection("Heart rate", footer: "Used to work out training load on the Fitness tab. Leave max blank to use the highest Odo has seen on your activities.") {
            SettingsRow("Max heart rate") {
                HeartRateField(value: $settings.maxHeartRate,
                               placeholder: viewModel.detectedMaxHeartRate.map(String.init) ?? "Auto")
            }
            SettingsDivider()
            SettingsRow("Resting heart rate") {
                HeartRateField(value: $settings.restingHeartRate, placeholder: "60")
            }
        }
    }
}

// MARK: - Notifications

private struct NotificationsSection: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var notifier = Notifier.shared

    private var footer: String {
        guard notifier.isAvailable else { return "Notifications work in the installed Odo.app, not dev builds." }
        if notifier.authorization == .denied { return "Notifications are off for Odo in System Settings." }
        let sport = viewModel.menuBarSportCategory?.displayName ?? "your menu bar sport"
        return "Kudos come for any sport. Summaries and pace reminders are for \(sport) \(settings.menuBarMetric), as set for the menu bar: at the start of each week, month and year, and midweek when you're behind."
    }

    var body: some View {
        SettingsSection("Send me", footer: footer) {
            toggle("Kudos", detail: "A well done when a new activity syncs", $settings.notifyKudos)
            SettingsDivider()
            toggle("Weekly summary", detail: "Last week against the week before", $settings.notifyWeekly)
            SettingsDivider()
            toggle("Monthly summary", detail: "Last month against the month before", $settings.notifyMonthly)
            SettingsDivider()
            toggle("Year in review", detail: "Last year against the year before", $settings.notifyYearly)
            SettingsDivider()
            toggle("Pace reminders", detail: "What it takes to catch up, and a doable target", $settings.notifyPace)
            SettingsDivider()
            SettingsRow(notifier.authorization == .denied ? "Turned off in System Settings" : "Try it") {
                if notifier.authorization == .denied {
                    Button("Open") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                    }
                } else {
                    Button("Send a test") {
                        notifier.requestAuthorization()
                        if let latest = viewModel.latestActivity {
                            notifier.kudos(for: [latest], vm: viewModel, force: true)
                        }
                        notifier.check(viewModel, force: true)
                    }
                    .disabled(!notifier.isAvailable)
                }
            }
        }
        .onAppear { notifier.refreshAuthorization() }
    }

    private func toggle(_ title: String, detail: String, _ isOn: Binding<Bool>) -> some View {
        SettingsRow(title, detail: detail) {
            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { on in
                    isOn.wrappedValue = on
                    if on { notifier.requestAuthorization() }
                }
            ))
            .settingsSwitch()
        }
    }
}

// MARK: - Updates

private struct UpdatesSection: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        SettingsSection("Odo", footer: updater.isAvailable ? nil : "Updates are available in the installed Odo.app, not dev builds.") {
            SettingsRow("Odo \(AppInfo.version)",
                        detail: updater.lastUpdateCheckDate.map { "Last checked \($0.timeAgoDisplay())" },
                        icon: "arrow.down.circle") {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            if updater.isAvailable {
                SettingsDivider()
                SettingsRow("Check automatically") {
                    Toggle("", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                    .settingsSwitch()
                }
                SettingsDivider()
                SettingsRow("Download and install automatically") {
                    Toggle("", isOn: Binding(
                        get: { updater.automaticallyDownloadsUpdates },
                        set: { updater.automaticallyDownloadsUpdates = $0 }
                    ))
                    .settingsSwitch()
                }
            }
        }
    }
}

// MARK: - Goals

private struct GoalsSettings: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings: AppSettings
    @State private var selected: SportCategory?

    private var sport: SportCategory? {
        selected ?? viewModel.availableSports.first { $0 != .all } ?? viewModel.availableSports.first
    }

    var body: some View {
        if viewModel.availableSports.isEmpty {
            EmptyNote("No sports yet. Sync your Strava activities first.")
        } else if let sport {
            HStack {
                Text("\(sport.displayName) · \(String(viewModel.currentYear))")
                    .font(.odo(size: 15, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
                SportIconTabs(sports: viewModel.availableSports, selection: Binding(
                    get: { sport },
                    set: { selected = $0 }
                ))
            }

            GoalEditor(sport: sport, settings: settings, viewModel: viewModel)
                .id(sport.rawValue) // reset fields on sport switch
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
    @State private var off: Set<String>

    init(sport: SportCategory, settings: AppSettings, viewModel: StravaViewModel) {
        self.sport = sport
        self.settings = settings
        self.viewModel = viewModel
        let goal = settings.storedGoal(for: sport)
        _distance = State(initialValue: goal.distanceMiles)
        _elevation = State(initialValue: goal.elevationFeet)
        _time = State(initialValue: goal.timeHours)
        _off = State(initialValue: goal.off)
    }

    private func on(_ key: String) -> Binding<Bool> {
        Binding(
            get: { !off.contains(key) },
            set: { enabled in
                if enabled { off.remove(key) } else { off.insert(key) }
                save()
            }
        )
    }

    var body: some View {
        let last = viewModel.lastYearStats(for: sport)
        let lastYear = String(viewModel.currentYear - 1)
        let smart = viewModel.smartSuggestions(for: sport)

        VStack(spacing: 10) {
            if sport != .all {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.odo(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week")
                            .font(.odo(size: 14))
                            .foregroundColor(Theme.ink)
                        Text("Progress against a weekly share of your first goal")
                            .font(.odo(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: on("week")).settingsSwitch()
                }
                .padding(16)
                .background(Theme.card)
                .cornerRadius(14)
            }

            BigNumberField(label: "Distance", icon: "ruler", value: $distance, enabled: on("distance"),
                           unit: settings.distanceUnit,
                           hint: last.map { "\(lastYear): \(formatNumber($0.totalDistance, decimals: 0)) \(settings.distanceUnit)" },
                           suggestions: smart.first { $0.metric == "distance" }, settings: settings)
            BigNumberField(label: "Elevation", icon: "arrow.up.right", value: $elevation, enabled: on("elevation"),
                           unit: settings.elevationUnit,
                           hint: last.map { "\(lastYear): \(formatNumber($0.totalElevation, decimals: 0)) \(settings.elevationUnit)" },
                           suggestions: smart.first { $0.metric == "elevation" }, settings: settings)
            BigNumberField(label: "Time", icon: "clock", value: $time, enabled: on("time"), unit: "hrs",
                           hint: last.map { "\(lastYear): \(formatTime($0.totalTime))" },
                           suggestions: smart.first { $0.metric == "time" }, settings: settings)
        }
        .onChange(of: distance) { _ in save() }
        .onChange(of: elevation) { _ in save() }
        .onChange(of: time) { _ in save() }
    }

    private func save() {
        settings.setGoal(SportGoal(distanceMiles: distance, elevationFeet: elevation, timeHours: time, off: off), for: sport)
    }
}

/// Nike-style goal input: small label, huge number you can type into
private struct BigNumberField: View {
    let label: String
    let icon: String
    @Binding var value: Double
    /// The goal's on/off switch; off keeps the number but hides the goal
    @Binding var enabled: Bool
    let unit: String
    let hint: String?
    /// Smart goal options for just this goal
    var suggestions: MetricSuggestions? = nil
    @ObservedObject var settings: AppSettings

    @State private var showSmart = false
    /// What's typed, kept as text so the field can size itself as you type
    @State private var text = ""

    private static let numberFont = Font.odo(size: 38, weight: .bold)

    private static func display(_ value: Double) -> String {
        value > 0 ? formatNumber(value, decimals: 0) : ""
    }

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
                    .font(.odo(size: 12, weight: .medium))
                Text(label)
                    .font(.odo(size: 14, weight: .medium))
                Spacer()
                if let hint {
                    Text(hint)
                        .font(.odo(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                if let suggestions, enabled {
                    Button(action: { showSmart.toggle() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.odo(size: 11, weight: .semibold))
                            Text("Suggest a goal")
                                .font(.odo(size: 12, weight: .medium))
                        }
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(showSmart ? Theme.cardRaised : Theme.cardRaised.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Suggest \(withArticle(label.lowercased())) goal")
                    .popover(isPresented: $showSmart, arrowEdge: .bottom) {
                        SmartGoalPicker(suggestions: suggestions, settings: settings, current: value) { picked in
                            value = picked
                            showSmart = false
                        }
                    }
                }
                Toggle("", isOn: $enabled)
                    .settingsSwitch()
                    .padding(.leading, 4)
                    .help(enabled ? "Hide this goal" : "Show this goal")
            }
            .foregroundColor(Theme.textSecondary)

            // An input box round the number, so it reads as something to type into
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                // Hidden text sizes the field to its content, so the unit sits right after the number
                ZStack(alignment: .leading) {
                    Text(text.isEmpty ? "0" : text)
                        .font(Self.numberFont)
                        .padding(.trailing, 2) // room for the caret
                        .hidden()
                    TextField("0", text: $text)
                        .textFieldStyle(.plain)
                        .font(Self.numberFont)
                        .foregroundColor(value > 0 ? Theme.ink : Theme.textTertiary)
                        .onSubmit { text = Self.display(value) }
                }
                .fixedSize()
                .onAppear { text = Self.display(value) }
                // Typing: keep the digits, and tidy the commas as you go
                .onChange(of: text) { typed in
                    let digits = typed.filter(\.isNumber)
                    let parsed = Double(digits) ?? 0
                    if parsed != value { value = parsed }
                    let tidy = digits.isEmpty ? "" : Self.display(parsed)
                    if tidy != typed { text = tidy }
                }
                // A suggestion picked from the popover
                .onChange(of: value) { new in
                    if Double(text.filter(\.isNumber)) ?? 0 != new { text = Self.display(new) }
                }
                Text(unit)
                    .font(.odo(size: 14, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.background.opacity(0.7))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
            .cornerRadius(10)
            .padding(.vertical, 6)
            .opacity(enabled ? 1 : 0.4)
            .disabled(!enabled)

            Text(!enabled ? "Off · hidden from the popover, your number is kept"
                 : value > 0 ? breakdown : "No goal set yet")
                .font(.odo(size: 11).monospacedDigit())
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
                                .font(.odo(size: 13, weight: on ? .medium : .regular).monospacedDigit())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
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

    private var syncDetail: String? {
        if viewModel.syncStatus.isActive { return viewModel.syncStatus.description }
        if case .rateLimited = viewModel.syncStatus { return viewModel.syncStatus.description }
        return viewModel.lastUpdated.map { "Last synced \($0.timeAgoDisplay())" }
    }

    var body: some View {
        SettingsSection("Strava") {
            SettingsRow(viewModel.isAuthenticated ? "Connected" : "Not connected",
                        detail: syncDetail,
                        icon: viewModel.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle") {
                if viewModel.isAuthenticated {
                    Button("Sync now") { Task { await viewModel.fetchAllData() } }
                        .disabled(viewModel.isLoading || viewModel.rateLimitedUntil != nil)
                }
            }
            if viewModel.isAuthenticated, let usage = viewModel.rateLimit?.summary {
                SettingsRow("API usage", detail: usage, icon: "gauge.with.dots.needle.33percent") {
                    EmptyView()
                }
                .help("Strava limits requests per app every 15 minutes and every day. "
                      + "If Odo reaches either, it pauses and carries on when the limit resets.")
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

/// A sport tab's content: the sport's icon, or the word "All"
struct SportTabLabel: View {
    let sport: SportCategory
    let selected: Bool

    var body: some View {
        if sport == .all {
            Text("All")
                .font(.odo(size: 11, weight: selected ? .semibold : .medium))
                .padding(.horizontal, 4)
        } else {
            Image(systemName: sport.icon)
                .font(.odo(size: 13, weight: selected ? .medium : .regular))
        }
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
                    SportTabLabel(sport: sport, selected: selected)
                        .foregroundColor(selected ? Theme.ink : Theme.textTertiary)
                        .frame(width: 30, height: 26)
                        .background(selected ? Theme.cardRaised : Color.clear)
                        .cornerRadius(7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(sport.displayName)
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
                .font(.odo(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .background(Theme.card)
            .cornerRadius(14)

            if let footer {
                Text(footer)
                    .font(.odo(size: 12))
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
                    .font(.odo(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.odo(size: 14))
                    .foregroundColor(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.odo(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Spacer(minLength: 12)
            control
                .controlSize(.regular)
        }
        .frame(minHeight: 32)
        .padding(.vertical, 10)
    }
}

/// A bpm field; empty means 0 (auto)
private struct HeartRateField: View {
    @Binding var value: Int
    let placeholder: String

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: Binding(
                get: { value > 0 ? String(value) : "" },
                set: { value = min(Int($0.filter(\.isNumber)) ?? 0, 250) }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 64)
            Text("bpm")
                .font(.odo(size: 13))
                .foregroundColor(Theme.textTertiary)
        }
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
            .font(.odo(size: 12))
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
