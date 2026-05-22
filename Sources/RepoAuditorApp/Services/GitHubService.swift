import AppKit
import Foundation

// MARK: - Models

struct GitHubUser: Decodable {
    let login: String
    let avatarUrl: String
    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct GitHubRepo: Decodable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let description: String?
    let language: String?
    let stargazersCount: Int
    let updatedAt: String
    let cloneUrl: String
    let owner: Owner

    struct Owner: Decodable { let login: String }

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, owner
        case fullName = "full_name"
        case isPrivate = "private"
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
        case cloneUrl = "clone_url"
    }
}

struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let verificationUriComplete: String
    let expiresIn: Int
    let interval: Int
    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case verificationUriComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval = "interval"
    }
}

// MARK: - Service

@MainActor
final class GitHubService: ObservableObject {
    // Replace with your GitHub OAuth App client_id.
    // Create one at https://github.com/settings/developers → New OAuth App
    // Callback URL can be anything (http://localhost) since we use device flow.
    static let clientID = "Ov23liQHhvvILYqnRBb3"

    @Published var token: String = ""
    @Published var user: GitHubUser?
    @Published var repos: [GitHubRepo] = []
    @Published var isLoading = false
    @Published var error: String?

    // Device flow state
    @Published var deviceCode: DeviceCodeResponse?
    @Published var isPolling = false

    private let tokenKey = "repoauditor_github_token"
    private var pollTask: Task<Void, Never>?

    init() {
        token = UserDefaults.standard.string(forKey: tokenKey) ?? ""
    }

    // MARK: - gh CLI

    func tryGhCLI() async -> Bool {
        let cliToken: String = await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["gh", "auth", "token"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            do {
                try p.run(); p.waitUntilExit()
                let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                cont.resume(returning: raw.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch { cont.resume(returning: "") }
        }
        guard !cliToken.isEmpty else { return false }
        token = cliToken
        return await authenticate()
    }

    // MARK: - Device Flow OAuth

    func startDeviceFlow() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let response = try await postForm(
                "https://github.com/login/device/code",
                body: "client_id=\(Self.clientID)&scope=repo",
                type: DeviceCodeResponse.self
            )
            deviceCode = response
            // Open browser to the complete URI (pre-fills the user code)
            if let url = URL(string: response.verificationUriComplete) {
                NSWorkspace.shared.open(url)
            }
            startPolling(deviceCode: response.deviceCode, interval: response.interval)
        } catch {
            self.error = "Failed to start login: \(error.localizedDescription)"
        }
    }

    func cancelDeviceFlow() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
        deviceCode = nil
    }

    private func startPolling(deviceCode: String, interval: Int) {
        isPolling = true
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                if await pollToken(deviceCode: deviceCode, interval: interval) { break }
            }
            await MainActor.run { isPolling = false }
        }
    }

    private func pollToken(deviceCode: String, interval: Int) async -> Bool {
        let body = "client_id=\(Self.clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: .utf8)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let accessToken = json["access_token"] as? String {
            token = accessToken
            self.deviceCode = nil
            let ok = await authenticate()
            if ok { await fetchRepos() }
            return true
        }

        let errCode = json["error"] as? String ?? ""
        if errCode == "expired_token" || errCode == "access_denied" {
            await MainActor.run {
                self.error = errCode == "expired_token" ? "Login expired. Please try again." : "Access denied."
                self.deviceCode = nil
            }
            return true
        }
        return false
    }

    // MARK: - Auth / Repos

    func authenticate() async -> Bool {
        guard !token.isEmpty else { return false }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            user = try await apiGet("https://api.github.com/user")
            UserDefaults.standard.set(token, forKey: tokenKey)
            return true
        } catch {
            self.error = "Authentication failed"
            return false
        }
    }

    func fetchRepos() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            var all: [GitHubRepo] = []
            var page = 1
            while true {
                let batch: [GitHubRepo] = try await apiGet(
                    "https://api.github.com/user/repos?per_page=100&page=\(page)&sort=updated&affiliation=owner,collaborator"
                )
                all += batch
                if batch.count < 100 { break }
                page += 1
            }
            repos = all
        } catch { self.error = error.localizedDescription }
    }

    func signOut() {
        pollTask?.cancel()
        token = ""; user = nil; repos = []; deviceCode = nil; isPolling = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    // MARK: - HTTP helpers

    private func apiGet<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "GitHub", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "GitHub API error \(http.statusCode)"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func postForm<T: Decodable>(_ urlString: String, body: String, type: T.Type) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: .utf8)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
