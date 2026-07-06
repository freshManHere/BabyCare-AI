import Foundation

// MARK: - API Client
// Single URLSession wrapper for all backend calls.
// JWT is read from Keychain; 401 responses trigger logout notification.

@MainActor
final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Auth token
    var accessToken: String? {
        get { KeychainHelper.load(key: "access_token") }
        set {
            if let token = newValue {
                try? KeychainHelper.save(token, key: "access_token")
            } else {
                KeychainHelper.delete(key: "access_token")
            }
        }
    }
    var refreshToken: String? {
        get { KeychainHelper.load(key: "refresh_token") }
        set {
            if let token = newValue {
                try? KeychainHelper.save(token, key: "refresh_token")
            } else {
                KeychainHelper.delete(key: "refresh_token")
            }
        }
    }
    var isAuthenticated: Bool { accessToken != nil }

    // MARK: - Request builder
    func request<T: Decodable>(_ path: String,
                               method: String = "GET",
                               body: (any Encodable)? = nil) async throws -> T {
        guard let url = URL(string: AIConfig.serverBaseURL + path) else {
            throw SyncError.networkUnavailable
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.networkUnavailable
        }

        if http.statusCode == 401 {
            // Clear tokens and notify app to show login
            accessToken = nil
            refreshToken = nil
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            throw SyncError.notAuthenticated
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? ""
            throw SyncError.serverError(http.statusCode, msg)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SyncError.decodingError(error)
        }
    }

    // Void response variant
    func requestVoid(_ path: String,
                     method: String = "DELETE",
                     body: (any Encodable)? = nil) async throws {
        let _: EmptyResponse = try await request(path, method: method, body: body)
    }

    // MARK: - Auth calls
    struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
    }
    struct Credentials: Encodable {
        let email: String
        let password: String
    }

    func register(email: String, password: String) async throws {
        let resp: AuthResponse = try await request(
            "/auth/register", method: "POST",
            body: Credentials(email: email, password: password)
        )
        accessToken = resp.accessToken
        refreshToken = resp.refreshToken
    }

    func login(email: String, password: String) async throws {
        let resp: AuthResponse = try await request(
            "/auth/login", method: "POST",
            body: Credentials(email: email, password: password)
        )
        accessToken = resp.accessToken
        refreshToken = resp.refreshToken
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }

    func deleteAccount() async throws {
        try await requestVoid("/auth/account", method: "DELETE")
        logout()
    }
}

// MARK: - Helpers
private struct EmptyResponse: Decodable {}

extension Notification.Name {
    static let userDidSignOut = Notification.Name("userDidSignOut")
}
