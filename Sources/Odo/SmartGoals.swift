import SwiftUI

// MARK: - Model

struct GoalSuggestion: Identifiable, Hashable {
    enum Kind: String { case lastYear, match, beat, stretch, bestEver, finishable }

    let kind: Kind
    let value: Double
    let label: String
    let detail: String

    var id: String { kind.rawValue }
}

struct MetricSuggestions: Identifiable {
    let metric: String          // "distance" | "elevation" | "time"
    let title: String
    let icon: String
    let unit: String
    let basis: String           // e.g. "based on 2025: 4,466 mi"
    let options: [GoalSuggestion]

    var id: String { metric }
    var defaultOption: GoalSuggestion? { options.first { $0.kind == .beat } ?? options.first }
}

extension StravaViewModel {
    private func total(_ stats: YearStats, _ metric: String) -> Double {
        switch metric {
        case "elevation": return stats.totalElevation
        case "time": return stats.totalTime
        default: return stats.totalDistance
        }
    }

    /// Round to a clean, goal-like number
    private func roundGoal(_ value: Double, metric: String) -> Double {
        let step: Double
        switch metric {
        case "elevation": step = settings.useMetricUnits ? 500 : 1000
        case "time": step = 5
        default: step = settings.useMetricUnits ? 100 : 50
        }
        return max(step, (value / step).rounded() * step)
    }

    private func amountText(_ value: Double, metric: String) -> String {
        switch metric {
        case "elevation": return "\(formatNumber(value, decimals: 0)) \(settings.elevationUnit)"
        case "time": return "\(formatNumber(value, decimals: 0)) hrs"
        default: return "\(formatNumber(value, decimals: 0)) \(settings.distanceUnit)"
        }
    }

    private func perWeek(_ value: Double, metric: String) -> String {
        let daysInYear = Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
        let week = value / (daysInYear / 7)
        if metric == "time" { return "\(formatTime(week))/wk" }
        let unit = metric == "elevation" ? settings.elevationUnit : settings.distanceUnit
        return "\(formatNumber(week, decimals: week >= 100 ? 0 : 1)) \(unit)/wk"
    }

    /// Match / Beat / Stretch (or Best ever) / Finishable suggestions for each metric
    func smartSuggestions(for sport: SportCategory) -> [MetricSuggestions] {
        let lastYear = currentYear - 1
        let pastYears = yearsWithData.filter { $0 < currentYear }
        let pastStats = pastYears.map { ($0, statsForYear($0, sport: sport)) }.filter { $0.1.activityCount > 0 }
        let thisYear = statsForYear(currentYear, sport: sport)
        let daysInYear = Double(Calendar.current.range(of: .day, in: .year, for: Date())?.count ?? 365)
        let yearFraction = Double(currentDayOfYear) / daysInYear

        let beatPct = Double(settings.smartBeatPercent) / 100
        let stretchPct = Double(settings.smartStretchPercent) / 100

        let metrics: [(String, String, String, String)] = [
            ("distance", "Distance", "ruler", settings.distanceUnit),
            ("elevation", "Elevation", "arrow.up.right", settings.elevationUnit),
            ("time", "Time", "clock", "hrs"),
        ]

        return metrics.compactMap { metric, title, icon, unit in
            let last = pastStats.first { $0.0 == lastYear }.map { total($0.1, metric) } ?? 0
            let recent = pastStats.filter { $0.0 >= currentYear - 3 }.map { total($0.1, metric) }
            let average = recent.isEmpty ? 0 : recent.reduce(0, +) / Double(recent.count)
            let projected = yearFraction > 0 ? total(thisYear, metric) / yearFraction : 0

            // Base: the higher of last year and the 3-year average (protects against an off year);
            // fall back to this year's projection when there's no history
            let base: Double
            let basis: String
            if max(last, average) > 0 {
                if average > last {
                    base = average
                    basis = "based on \(recent.count)-year average: \(amountText(average, metric: metric))"
                } else {
                    base = last
                    basis = "based on \(String(lastYear)): \(amountText(last, metric: metric))"
                }
            } else if projected > 0 {
                base = projected
                basis = "based on this year's pace: \(amountText(projected, metric: metric))"
            } else {
                return nil
            }

            var options: [GoalSuggestion] = []
            // Last year's exact total, to set the goal to "do it again"
            if last > 0 {
                let value = last.rounded()
                options.append(GoalSuggestion(kind: .lastYear, value: value, label: "Last year · \(String(lastYear))",
                                              detail: perWeek(value, metric: metric)))
            }
            let match = roundGoal(base, metric: metric)
            options.append(GoalSuggestion(kind: .match, value: match, label: "Match",
                                          detail: perWeek(match, metric: metric)))

            let beat = max(roundGoal(base * (1 + beatPct), metric: metric), match)
            options.append(GoalSuggestion(kind: .beat, value: beat, label: "Beat +\(settings.smartBeatPercent)%",
                                          detail: perWeek(beat, metric: metric)))

            // Stretch, or best-ever year if that's higher but still within reach (≤ +30% of base)
            let stretch = max(roundGoal(base * (1 + stretchPct), metric: metric), beat)
            if let best = pastStats.max(by: { total($0.1, metric) < total($1.1, metric) }),
               total(best.1, metric) > stretch, total(best.1, metric) <= base * 1.3 {
                let value = roundGoal(total(best.1, metric), metric: metric)
                options.append(GoalSuggestion(kind: .bestEver, value: value, label: "Best ever · \(String(best.0))",
                                              detail: perWeek(value, metric: metric)))
            } else {
                options.append(GoalSuggestion(kind: .stretch, value: stretch, label: "Stretch +\(settings.smartStretchPercent)%",
                                              detail: perWeek(stretch, metric: metric)))
            }

            // Mid-year: what's realistic from here at your current rate
            if currentDayOfYear > 30, total(thisYear, metric) > 0 {
                let finishable = roundGoal(projected, metric: metric)
                options.append(GoalSuggestion(kind: .finishable, value: finishable, label: "Finishable",
                                              detail: "at your current pace"))
            }

            return MetricSuggestions(metric: metric, title: title, icon: icon, unit: unit, basis: basis, options: options)
        }
    }

    /// One-click: apply the Beat suggestion for every metric
    func applyDefaultSmartGoals(for sport: SportCategory) {
        var goal = settings.goalFor(sport)
        for s in smartSuggestions(for: sport) {
            guard let value = s.defaultOption?.value else { continue }
            switch s.metric {
            case "elevation": goal.elevationFeet = value
            case "time": goal.timeHours = value
            default: goal.distanceMiles = value
            }
        }
        objectWillChange.send()
        settings.setGoal(goal, for: sport)
    }
}

// MARK: - Picker

/// One goal's suggestions, in a popover from its card. Picking one sets only that goal.
struct SmartGoalPicker: View {
    let suggestions: MetricSuggestions
    @ObservedObject var settings: AppSettings
    let current: Double
    var onPick: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Smart \(suggestions.title.lowercased()) goal", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Text(suggestions.basis.prefix(1).uppercased() + suggestions.basis.dropFirst())
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }

            FlowLayout(spacing: 6) {
                ForEach(suggestions.options) { option in
                    chip(option)
                }
            }

            HStack(spacing: 14) {
                Stepper(value: $settings.smartBeatPercent, in: 1...50) {
                    Text("Beat +\(settings.smartBeatPercent)%")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(Theme.textSecondary)
                }
                Stepper(value: $settings.smartStretchPercent, in: 1...100) {
                    Text("Stretch +\(settings.smartStretchPercent)%")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .controlSize(.small)

            Text("Only sets this goal.")
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }

    private func chip(_ option: GoalSuggestion) -> some View {
        let selected = option.value == current
        return Button(action: { onPick(option.value) }) {
            VStack(alignment: .leading, spacing: 1) {
                Text(option.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(selected ? Theme.background.opacity(0.7) : Theme.textTertiary)
                Text(formatNumber(option.value, decimals: 0))
                    .font(.system(size: 16, weight: .black).width(.condensed).italic())
                    .foregroundColor(selected ? Theme.background : Theme.ink)
                Text(option.detail)
                    .font(.system(size: 9))
                    .foregroundColor(selected ? Theme.background.opacity(0.7) : Theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? Theme.ink : Theme.cardRaised)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? Color.clear : Theme.hairline, lineWidth: 1))
            .cornerRadius(9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(selected ? "Your current goal" : "Set \(suggestions.title.lowercased()) to \(formatNumber(option.value, decimals: 0)) \(suggestions.unit)")
    }
}
