import AppKit
import UserNotifications

/// Week, month and year summaries, and pace reminders, for the menu bar's
/// sport and metric. Checked after every sync; each one is sent once, and
/// never before 8am.
@MainActor
final class Notifier: NSObject, ObservableObject {
    static let shared = Notifier()

    /// Opens the popover when a notification is clicked
    var onOpen: (() -> Void)?

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let defaults = UserDefaults.standard
    private let settings = AppSettings.shared

    /// UNUserNotificationCenter needs a bundle; dev builds skip notifications
    private var center: UNUserNotificationCenter? { AppInfo.isBundled ? .current() : nil }

    var isAvailable: Bool { AppInfo.isBundled }

    func start() {
        guard let center else { return }
        center.delegate = self
        refreshAuthorization()
        if settings.anyNotifications { requestAuthorization() }
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshAuthorization() }
        }
    }

    func refreshAuthorization() {
        center?.getNotificationSettings { [weak self] s in
            let status = s.authorizationStatus
            Task { @MainActor in self?.authorization = status }
        }
    }

    // MARK: - Checking

    /// Sends whatever's due. `force` sends last week's summary and the pace
    /// reminder now, ignoring the schedule (Settings' "Send a test").
    func check(_ vm: StravaViewModel, now: Date = Date(), force: Bool = false) {
        // The installed Odo sends these; a preview build only sends tests
        guard center != nil, !AppInfo.isPreview || force, let sport = vm.menuBarSportCategory else { return }
        let metric = settings.menuBarMetric
        let cal = Calendar.current
        guard force || cal.component(.hour, from: now) >= 8 else { return }

        let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        let daysIntoWeek = cal.dateComponents([.day], from: thisWeek, to: now).day ?? 0

        if settings.notifyWeekly || force, force || daysIntoWeek < 2,
           once("notified_week", key(thisWeek), force: force) {
            weekly(vm, sport: sport, metric: metric, thisWeek: thisWeek)
        }

        if settings.notifyMonthly, !force, cal.component(.day, from: now) <= 3,
           let thisMonth = cal.dateInterval(of: .month, for: now)?.start,
           once("notified_month", key(thisMonth), force: false) {
            monthly(vm, sport: sport, metric: metric, thisMonth: thisMonth)
        }

        if settings.notifyYearly, !force, cal.component(.month, from: now) == 1, cal.component(.day, from: now) <= 7,
           once("notified_year", String(cal.component(.year, from: now)), force: false) {
            yearly(vm, sport: sport, metric: metric, year: cal.component(.year, from: now) - 1)
        }

        if settings.notifyPace || force {
            pace(vm, sport: sport, metric: metric, thisWeek: thisWeek, daysIntoWeek: daysIntoWeek, force: force)
        }
    }

    /// True the first time it's called for a period, then false until the next one
    private func once(_ name: String, _ period: String, force: Bool) -> Bool {
        if force { return true }
        guard defaults.string(forKey: name) != period else { return false }
        defaults.set(period, forKey: name)
        return true
    }

    private func key(_ date: Date) -> String {
        formatDate(date, "yyyy-MM-dd")
    }

    // MARK: - Summaries

    private func weekly(_ vm: StravaViewModel, sport: SportCategory, metric: String, thisWeek: Date) {
        let cal = Calendar.current
        guard let lastWeek = cal.date(byAdding: .day, value: -7, to: thisWeek),
              let weekBefore = cal.date(byAdding: .day, value: -14, to: thisWeek) else { return }
        let last = vm.total(sport: sport, metric: metric, from: lastWeek, to: thisWeek)
        let before = vm.total(sport: sport, metric: metric, from: weekBefore, to: lastWeek)
        guard last.count > 0 || before.count > 0 else { return }

        if last.count == 0 {
            send(id: "week", title: "A quiet week",
                 body: "No \(noun(sport)) last week. The week before: \(amount(before.value, metric)).")
            return
        }

        var body = [compare(last.value, before.value, metric, "the week before"), activities(last.count)]
        let goal = vm.goalTarget(sport: sport, metric: metric)
        if goal > 0 {
            let target = goal / (Double(cal.range(of: .day, in: .year, for: Date())?.count ?? 365) / 7)
            body.append(last.value >= target
                ? "Beat your \(amount(target, metric)) weekly pace."
                : "\(amount(target - last.value, metric)) short of your \(amount(target, metric)) weekly pace.")
        }
        send(id: "week", title: "Last week: \(amount(last.value, metric))", body: body.joined(separator: " · "))
    }

    private func monthly(_ vm: StravaViewModel, sport: SportCategory, metric: String, thisMonth: Date) {
        let cal = Calendar.current
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: thisMonth),
              let monthBefore = cal.date(byAdding: .month, value: -2, to: thisMonth) else { return }
        let last = vm.total(sport: sport, metric: metric, from: lastMonth, to: thisMonth)
        let before = vm.total(sport: sport, metric: metric, from: monthBefore, to: lastMonth)
        guard last.count > 0 || before.count > 0 else { return }

        let name = formatDate(lastMonth, "MMMM"), previous = formatDate(monthBefore, "MMMM")
        send(id: "month", title: "\(name): \(amount(last.value, metric))",
             body: [compare(last.value, before.value, metric, previous), activities(last.count)]
                .joined(separator: " · "))
    }

    private func yearly(_ vm: StravaViewModel, sport: SportCategory, metric: String, year: Int) {
        let cal = Calendar.current
        guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)),
              let before = cal.date(from: DateComponents(year: year - 1, month: 1, day: 1)) else { return }
        let last = vm.total(sport: sport, metric: metric, from: start, to: end)
        let previous = vm.total(sport: sport, metric: metric, from: before, to: start)
        guard last.count > 0 else { return }

        send(id: "year", title: "\(String(year)): \(amount(last.value, metric))",
             body: [compare(last.value, previous.value, metric, String(year - 1)), activities(last.count)]
                .joined(separator: " · "))
    }

    // MARK: - Pace

    /// Midweek nudge when behind (once a week), and a note when back on pace
    private func pace(_ vm: StravaViewModel, sport: SportCategory, metric: String,
                      thisWeek: Date, daysIntoWeek: Int, force: Bool) {
        guard let onPace = vm.menuBarOnPace, let plan = vm.catchUp(sport: sport, metric: metric) else { return }
        let goal = vm.goalTarget(sport: sport, metric: metric)

        // Back on pace: only on the change from behind
        let wasBehind = defaults.bool(forKey: "pace_was_behind")
        defaults.set(!onPace, forKey: "pace_was_behind")
        if onPace {
            if wasBehind && !force {
                send(id: "pace", title: "Back on pace", body: "You're on track for \(amount(goal, metric)) this year. Keep it going.")
            }
            return
        }

        guard force || (daysIntoWeek >= 2 && once("notified_pace", key(thisWeek), force: false)) else { return }

        // One suggestion: the doable target when the full goal is out of reach
        let body: String
        if let doable = plan.doable {
            body = "\(perWeek(doable.perWeek, metric)) gets you to \(amount(doable.total, metric)) this year."
        } else {
            body = "\(perWeek(plan.neededPerWeek, metric)) still hits your \(amount(goal, metric)) goal."
        }
        let daysInYear = Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
        let behind = goal * Double(vm.currentDayOfYear) / daysInYear - vm.yearToDate(sport: sport, metric: metric)
        send(id: "pace", title: "\(amount(max(behind, 0), metric)) behind pace", body: body)
    }

    // MARK: - Kudos

    private static let cheers = ["Kudos!", "Well done!", "Nice one!", "Great effort!", "Get in!"]

    /// A well done for each newly synced activity from the last few days
    /// `force` skips the setting and the three-day limit (Settings' "Send a test")
    func kudos(for activities: [StravaActivity], vm: StravaViewModel, force: Bool = false) {
        guard settings.notifyKudos || force, center != nil, !AppInfo.isPreview || force else { return }
        let recent = Date().addingTimeInterval(-3 * 86_400)
        let fresh = activities.filter { a in
            guard let date = vm.startDate(of: a), force || date >= recent else { return false }
            return !settings.hiddenSports.contains(SportCategory.from(sportType: a.sportType).rawValue)
        }
        guard !fresh.isEmpty else { return }

        if fresh.count > 3 {
            let hours = fresh.reduce(0.0) { $0 + vm.value(of: $1, metric: "time") }
            send(id: "kudos", title: Self.cheers.randomElement()!,
                 body: "\(fresh.count) new activities synced · \(formatTime(hours)) between them.")
            return
        }

        for a in fresh {
            let sport = SportCategory.from(sportType: a.sportType)
            var parts: [String] = []
            let distance = vm.value(of: a, metric: "distance")
            if distance > 0.05 { parts.append(amount(distance, "distance")) }
            parts.append(formatTime(vm.value(of: a, metric: "time")))
            let climb = vm.value(of: a, metric: "elevation")
            if climb >= 1 { parts.append("\(amount(climb, "elevation")) up") }

            var title = "\(a.tags.contains("Race") ? "Race done!" : Self.cheers.randomElement()!) \(a.name)"
            var body = parts.joined(separator: " · ")

            // How it moves this sport's yearly goal, in the menu bar's metric where there's a goal for it
            let metric = vm.goalTarget(sport: sport, metric: settings.menuBarMetric) > 0 ? settings.menuBarMetric : "distance"
            let goal = vm.goalTarget(sport: sport, metric: metric)
            if goal > 0 {
                let total = vm.yearToDate(sport: sport, metric: metric)
                let before = total - vm.value(of: a, metric: metric)
                if before < goal && total >= goal {
                    title = "Goal reached! \(a.name)"
                    body += ". That's your \(amount(goal, metric)) \(sport.rawValue.lowercased()) goal done for the year."
                } else if total < goal {
                    body += ". \(amount(total, metric)) of \(amount(goal, metric)) this year."
                }
            }
            send(id: "kudos.\(a.id)", title: title, body: body)
        }
    }

    // MARK: - Text

    private func amount(_ value: Double, _ metric: String) -> String {
        switch metric {
        case "time": return formatTime(value)
        case "elevation": return "\(formatNumber(value, decimals: 0)) \(settings.elevationUnit)"
        default: return "\(formatNumber(value, decimals: value >= 100 ? 0 : 1)) \(settings.distanceUnit)"
        }
    }

    /// Weekly figures are rounded to whole units: "70 mi a week", not "70.1"
    private func perWeek(_ value: Double, _ metric: String) -> String {
        guard metric != "time", value >= 10 else { return "\(amount(value, metric)) a week" }
        return "\(amount(value.rounded(), metric)) a week"
    }

    private func compare(_ value: Double, _ other: Double, _ metric: String, _ label: String) -> String {
        guard other > 0 else { return "Nothing \(label)" }
        let percent = Int(((value - other) / other * 100).rounded())
        if percent == 0 { return "Same as \(label)" }
        return "\(percent > 0 ? "Up" : "Down") \(abs(percent))% on \(label)"
    }

    private func activities(_ count: Int) -> String {
        "\(count) \(count == 1 ? "activity" : "activities")"
    }

    private func noun(_ sport: SportCategory) -> String {
        sport == .all ? "activities" : sport.rawValue.lowercased()
    }

    private func send(id: String, title: String, body: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // A fixed id per kind replaces an older one still in Notification Centre
        center.add(UNNotificationRequest(identifier: "odo.\(id)", content: content, trigger: nil))
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    /// Show banners even while Odo is the active app
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in self.onOpen?() }
        completionHandler()
    }
}
