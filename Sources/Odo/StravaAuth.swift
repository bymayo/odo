import Foundation
import Network
import AppKit

class StravaAuth {
    static let callbackPort: UInt16 = 8089
    static let redirectURI = "http://localhost:\(callbackPort)/exchange_token"

    private var listener: NWListener?

    func authorize(clientId: String) {
        let urlString = "https://www.strava.com/oauth/authorize"
            + "?client_id=\(clientId)"
            + "&response_type=code"
            + "&redirect_uri=\(Self.redirectURI)"
            + "&approval_prompt=force"
            + "&scope=read,activity:read_all"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func startCallbackServer(completion: @escaping (String?) -> Void) {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.callbackPort)!)
        } catch {
            completion(nil)
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                guard let data = data,
                      let request = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }

                let code = self?.extractCode(from: request)

                let html = code != nil
                    ? "<html><body style='font-family:-apple-system,system-ui;text-align:center;padding:60px'>"
                      + "<h1 style='color:#FC4C02'>Connected!</h1>"
                      + "<p style='color:#666'>You can close this window and return to Odo.</p></body></html>"
                    : "<html><body style='font-family:-apple-system,system-ui;text-align:center;padding:60px'>"
                      + "<h1 style='color:#d00'>Error</h1>"
                      + "<p>Authorization failed. Please try again.</p></body></html>"

                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n\(html)"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })

                self?.stopCallbackServer()
                completion(code)
            }
        }

        listener?.stateUpdateHandler = { state in
            if case .failed = state {
                completion(nil)
            }
        }

        listener?.start(queue: .main)
    }

    func stopCallbackServer() {
        listener?.cancel()
        listener = nil
    }

    private func extractCode(from request: String) -> String? {
        let parts = request.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let path = String(parts[1])
        guard let components = URLComponents(string: path),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }

    func exchangeCode(_ code: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(httpResponse, data: data)
        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    func refreshTokens(refreshToken: String, clientId: String, clientSecret: String) async throws -> StravaTokenResponse {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(httpResponse, data: data)
        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    private func checkHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode == 200 else {
            if http.statusCode == 429 {
                let resetsAt = RateLimit(headers: http)?.resetsAt ?? RateLimit.nextQuarterHour(after: Date())
                throw StravaError.rateLimited(resetsAt: resetsAt)
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                throw StravaError.apiError(message)
            }
            throw StravaError.apiError("HTTP \(http.statusCode)")
        }
    }
}

enum StravaError: LocalizedError {
    case notAuthenticated
    case apiError(String)
    case rateLimited(resetsAt: Date)
    /// 403 on the activities API: since June 2026 Strava only serves its API to subscribers
    case subscriptionRequired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated with Strava"
        case .apiError(let msg): return msg
        case .rateLimited(let resetsAt):
            return "Strava's rate limit is reached until \(resetsAt.shortTimeOrTomorrow)"
        case .subscriptionRequired:
            return "Strava only lets subscribers use its API"
        }
    }
}
