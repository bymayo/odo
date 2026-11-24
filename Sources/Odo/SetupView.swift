import SwiftUI
import AppKit

/// First launch: walks through making a Strava API app and signing in, all on one page
struct SetupView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared

    private static let stravaAPI = URL(string: "https://www.strava.com/settings/api")!
    // Strava's own brand orange, the one place it belongs
    private static let stravaOrange = Color(red: 0.99, green: 0.30, blue: 0.01)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                OdoMarkView(lineWidth: 4, track: Theme.ink.opacity(0.12), lap: Theme.ink, animated: true)
                    .frame(width: 44, height: 44)
                Text("Connect to Strava")
                    .font(.odo(size: 17, weight: .bold))
                    .foregroundColor(Theme.ink)
                Text("Odo reads your activities through your own Strava API app. It takes about two minutes.")
                    .font(.odo(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)

            SetupStep(number: 1, title: "Create a Strava API app",
                      detail: "Any name and website will do.") {
                Button(action: { NSWorkspace.shared.open(Self.stravaAPI) }) {
                    HStack(spacing: 5) {
                        Text("Open Strava API settings")
                        Image(systemName: "arrow.up.right")
                            .font(.odo(size: 10, weight: .semibold))
                    }
                    .font(.odo(size: 12, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.cardRaised)
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.hairline))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            SetupStep(number: 2, title: "Set the callback domain",
                      detail: "In Authorization Callback Domain, enter:") {
                CopyValue(value: "localhost")
            }

            SetupStep(number: 3, title: "Paste your keys",
                      detail: "They're on your app's page once it's created.",
                      done: settings.isConfigured) {
                VStack(spacing: 6) {
                    TextField("Client ID", text: $settings.clientId)
                    SecureField("Client Secret", text: $settings.clientSecret)
                }
                .textFieldStyle(.roundedBorder)
                .font(.odo(size: 12))
            }

            SetupStep(number: 4, title: "Connect",
                      detail: "Strava asks you to let Odo read your activities.",
                      isLast: true) {
                Button(action: { viewModel.startAuth() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                        Text("Connect with Strava")
                    }
                    .font(.odo(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(settings.isConfigured ? Self.stravaOrange : Theme.ink.opacity(0.08))
                    .foregroundColor(settings.isConfigured ? .white : Theme.textTertiary)
                    .cornerRadius(9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(!settings.isConfigured)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.odo(size: 11))
                    .foregroundColor(Theme.negative)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 16)
    }
}

/// A numbered step: badge and connecting line on the left, title, detail and control on the right
private struct SetupStep<Content: View>: View {
    let number: Int
    let title: String
    let detail: String
    var done = false
    var isLast = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? Theme.accent : Theme.card)
                if done {
                    Image(systemName: "checkmark")
                        .font(.odo(size: 10, weight: .bold))
                        .foregroundColor(Theme.brandBlack)
                } else {
                    Text("\(number)")
                        .font(.odo(size: 11, weight: .semibold))
                        .foregroundColor(Theme.ink)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.odo(size: 13, weight: .semibold))
                        .foregroundColor(Theme.ink)
                    Text(detail)
                        .font(.odo(size: 11.5))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A value to type into Strava, with a button that copies it
private struct CopyValue: View {
    let value: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.ink)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button(action: copy) {
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied" : "Copy")
                }
                .font(.odo(size: 11, weight: .medium))
                .foregroundColor(copied ? Theme.positive : Theme.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.card)
        .cornerRadius(7)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}
