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

                ScrollView {
                    StatsContentView(viewModel: viewModel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }

                footerView
            }
        }
        .frame(width: 360, height: 720)
        .background(Theme.background)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Theme.card)
                    .cornerRadius(7)
                Text("Odo")
                    .font(.system(size: 14, weight: .medium))
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
                    Image(systemName: sport.icon)
                        .font(.system(size: 13, weight: selected ? .medium : .regular))
                        .foregroundColor(selected ? Theme.ink : Theme.textTertiary)
                        .frame(width: 30, height: 26)
                        .background(selected ? Theme.cardRaised : Color.clear)
                        .cornerRadius(7)
                        .shadow(color: selected ? Color.black.opacity(0.06) : .clear, radius: 1, y: 1)
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

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(Theme.textSecondary)
            Text("Loading activities...")
                .font(.caption)
                .foregroundColor(Theme.ink.opacity(0.4))
            Spacer()
        }
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
            .disabled(viewModel.isLoading)
            .help("Refresh data")

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
        .font(.system(size: 11))
        .foregroundColor(Theme.textTertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var syncStatusView: some View {
        if viewModel.isLoading {
            HStack(spacing: 5) {
                ProgressView()
                    .scaleEffect(0.4)
                    .frame(width: 10, height: 10)
                Text(viewModel.syncStatus.description)
                    .lineLimit(1)
            }
            .font(.system(size: 10))
        } else if case .rateLimited = viewModel.syncStatus {
            Label(viewModel.syncStatus.description, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(Theme.gold)
                .lineLimit(1)
        } else if case .done = viewModel.syncStatus {
            Label("Synced", systemImage: "checkmark")
                .font(.system(size: 10))
        } else if let lastUpdated = viewModel.lastUpdated {
            Text("Updated \(lastUpdated.timeAgoDisplay())")
                .font(.system(size: 10))
        }
    }
}
