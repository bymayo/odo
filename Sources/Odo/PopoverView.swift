import SwiftUI

/// The tallest the popover may be on the screen it's opening on.
/// AppDelegate updates it each time the popover opens.
final class PopoverLayout: ObservableObject {
    static let shared = PopoverLayout()
    @Published var maxHeight: CGFloat = 720
}

/// Natural heights of the popover's parts, gathered so it can fit its content
private struct HeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

private extension View {
    func measureHeight(_ key: String) -> some View {
        background(GeometryReader { geo in
            Color.clear.preference(key: HeightKey.self, value: [key: geo.size.height])
        })
    }
}

struct PopoverView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var layout = PopoverLayout.shared
    @State private var heights: [String: CGFloat] = [:]

    /// Screens with centred content and no natural height get a fixed one
    private static let setupHeight: CGFloat = 560
    private static let firstSyncHeight: CGFloat = 420

    private var showsFirstSync: Bool {
        viewModel.activities.isEmpty && (viewModel.isLoading || viewModel.rateLimitedUntil != nil)
    }

    /// Fits the stats, header and footer, up to what the screen allows;
    /// beyond that the stats scroll
    private var height: CGFloat {
        let wanted: CGFloat
        if !viewModel.isAuthenticated {
            wanted = Self.setupHeight
        } else if showsFirstSync {
            wanted = Self.firstSyncHeight
        } else if let content = heights["content"] {
            wanted = (heights["header"] ?? 0) + content + (heights["footer"] ?? 0)
        } else {
            wanted = layout.maxHeight // until the first measurement lands
        }
        return min(wanted.rounded(.up), layout.maxHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .measureHeight("header")

            if !viewModel.isAuthenticated {
                SetupView(viewModel: viewModel)
            } else if showsFirstSync {
                firstSyncView
            } else {
                ScrollView {
                    StatsContentView(viewModel: viewModel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .measureHeight("content")
                }
                .id(viewModel.popoverSession) // fresh on every open

                footerView
                    .measureHeight("footer")
            }
        }
        .frame(width: 360, height: height, alignment: .top)
        .background(Theme.background)
        .onPreferenceChange(HeightKey.self) { heights.merge($0) { $1 } }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 9) {
                OdoMarkView(lineWidth: 2.2)
                    .frame(width: 18, height: 18)
                    .frame(width: 26, height: 26)
                    .background(Theme.brandBlack)
                    .cornerRadius(7)
                Text("Odo")
                    .font(.odo(size: 14, weight: .medium))
                    .foregroundColor(Theme.ink)
            }

            Spacer()

            if viewModel.isAuthenticated {
                sportTabs
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Sport Tabs (icons only)

    private var sportTabs: some View {
        HStack(spacing: 2) {
            ForEach(viewModel.availableSports) { sport in
                let selected = viewModel.selectedSport == sport
                Button(action: { viewModel.selectedSport = sport }) {
                    SportTabLabel(sport: sport, selected: selected)
                        .foregroundColor(selected ? Theme.ink : Theme.textTertiary)
                        .frame(width: 30, height: 26)
                        .background(selected ? Theme.cardRaised : Color.clear)
                        .cornerRadius(7)
                        .shadow(color: selected ? Color.black.opacity(0.06) : .clear, radius: 1, y: 1)
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

    // MARK: - First sync

    /// Shown until the first year of activities arrives: what's being fetched,
    /// or when Strava will let it carry on
    private var firstSyncView: some View {
        VStack(spacing: 10) {
            Spacer()
            if let until = viewModel.rateLimitedUntil {
                Image(systemName: "hourglass")
                    .font(.odo(size: 22, weight: .light))
                    .foregroundColor(Theme.gold)
                Text("Strava needs a breather")
                    .font(.odo(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Text("Odo hit Strava's API limit. It'll pick up where it stopped at \(until.shortTimeOrTomorrow).")
                    .font(.odo(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .controlSize(.small)
                Text("Syncing your Strava history")
                    .font(.odo(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
                if case .syncing(let year, let fetched) = viewModel.syncStatus {
                    Text(fetched > 0
                         ? "Fetching \(String(year)) · \(fetched.formatted()) activities so far"
                         : "Fetching \(String(year))…")
                        .font(.odo(size: 11).monospacedDigit())
                        .foregroundColor(Theme.textSecondary)
                }
                Text("The first sync works back through every year, so it can take a minute.")
                    .font(.odo(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 12) {
            syncStatusView

            Spacer()

            Button(action: { Task { await viewModel.fetchAllData() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading || viewModel.rateLimitedUntil != nil)
            .help(viewModel.rateLimitedUntil.map { "Strava's API limit is reached until \($0.shortTimeOrTomorrow)" }
                  ?? "Refresh data")

            Button(action: { SettingsWindowController.shared.open(viewModel: viewModel) }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Odo")
        }
        .font(.odo(size: 11))
        .foregroundColor(Theme.textTertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var syncStatusView: some View {
        switch viewModel.syncStatus {
        case .syncing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text(viewModel.syncStatus.description)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .font(.odo(size: 10))
        case .rateLimited:
            Label(viewModel.syncStatus.description, systemImage: "hourglass")
                .font(.odo(size: 10))
                .foregroundColor(Theme.gold)
                .lineLimit(1)
                .help("Strava allows a set number of API requests every 15 minutes and every day. "
                      + "Odo keeps what it has and carries on automatically."
                      + (viewModel.rateLimit?.summary.map { "\n\nUsage: \($0)" } ?? ""))
        case .done:
            Label("Synced", systemImage: "checkmark")
                .font(.odo(size: 10))
        case .idle:
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(lastUpdated.timeAgoDisplay())")
                    .font(.odo(size: 10))
            }
        }
    }
}

// MARK: - Mark

/// The mark in the app's colours, for the popover header
struct OdoMarkView: View {
    var lineWidth: CGFloat = 2.4

    var body: some View {
        Canvas { ctx, size in
            let bounds = CGRect(origin: .zero, size: size)
            // Canvas is y-down; flip so the start line sits at the bottom
            let flip = CGAffineTransform(translationX: 0, y: size.height).scaledBy(x: 1, y: -1)
            let path = Path(OdoMark.trackPath(in: bounds, lineWidth: lineWidth)).applying(flip)
            let length = OdoMark.perimeter(in: bounds, lineWidth: lineWidth)

            ctx.stroke(path, with: .color(Color.white.opacity(0.2)),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            ctx.stroke(path, with: .color(Theme.brandLime),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round,
                                          dash: [length * OdoMark.progress, length]))
        }
        .aspectRatio(OdoMark.aspect, contentMode: .fit)
        .accessibilityLabel("Odo")
    }
}
