import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: StravaViewModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "figure.run")
                .font(.system(size: 36))
                .foregroundColor(Theme.accent)

            Text("Connect to Strava")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Enter your Strava API credentials.\nCreate an app at strava.com/settings/api\nSet callback domain to \"localhost\"")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.4))
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
                .background(settings.isConfigured ? Theme.accent : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.borderless)
            .disabled(!settings.isConfigured)
            .padding(.horizontal, 20)

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }
}
