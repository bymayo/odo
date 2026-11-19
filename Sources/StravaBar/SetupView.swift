import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "figure.run")
                .font(.system(size: 36))
                .foregroundColor(Theme.textSecondary)

            Text("Connect to Strava")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)

            Text("Enter your Strava API credentials.\nCreate an app at strava.com/settings/api\nSet callback domain to \"localhost\"")
                .font(.caption)
                .foregroundColor(Theme.ink.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            VStack(spacing: 8) {
                TextField("Client ID", text: $settings.clientId)
                    .textFieldStyle(.roundedBorder)

                SecureField("Client Secret", text: $settings.clientSecret)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 20)

            Button(action: { viewModel.startAuth() }) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                    Text("Connect with Strava")
                }
                .font(.system(.body, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                // Strava's own brand orange — the one place it belongs
                .background(settings.isConfigured ? Color(red: 0.99, green: 0.30, blue: 0.01) : Theme.ink.opacity(0.1))
                .foregroundColor(settings.isConfigured ? .white : Theme.textTertiary)
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            .disabled(!settings.isConfigured)
            .padding(.horizontal, 20)

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Theme.negative)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }
}
