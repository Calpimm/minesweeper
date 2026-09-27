import Foundation
import Security

struct OnlineAccount: Codable {
    let id: String
    var name: String
    let token: String
}

struct RankedTicket: Decodable {
    let id: String
    let seed: UInt32
}

struct PersonalBest: Decodable {
    let rank: Int
    let timeMs: Int
}

struct FinishResult: Decodable {
    let timeMs: Int
    let personalBest: Bool
    let best: PersonalBest?
}

struct LeaderboardEntry: Decodable, Identifiable {
    let rank: Int
    let name: String
    let timeMs: Int
    var id: Int { rank }
}

struct Leaderboard: Decodable {
    let entries: [LeaderboardEntry]
    let me: PersonalBest?
}

/// Error body returned by the server.
private struct APIProblem: Decodable {
    let error: String
    let message: String
}

enum OnlineError: LocalizedError {
    case notConfigured
    case upgradeRequired(String)
    case server(code: String, message: String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Online play isn't available in this build."
        case .upgradeRequired(let message): return message
        case .server(_, let message): return message
        case .network(let message): return "Couldn't reach the leaderboard server. \(message)"
        }
    }
}

/// Seconds with milliseconds, as shown on the online leaderboard.
func formatTime(_ ms: Int) -> String {
    String(format: "%d.%03d s", ms / 1000, ms % 1000)
}

/// Client for the leaderboard API in server/.
@MainActor
final class OnlineService {
    let baseURL = AppInfo.apiBaseURL
    private(set) var account: OnlineAccount?

    var isAvailable: Bool { baseURL != nil }
    var isSignedIn: Bool { account != nil }

    init() {
        if let data = Keychain.read(), let saved = try? JSONDecoder().decode(OnlineAccount.self, from: data) {
            account = saved
        }
    }

    func register(name: String) async throws {
        struct Body: Encodable { let name: String }
        let created: OnlineAccount = try await send("POST", "/v1/players", body: Body(name: name), auth: false)
        account = created
        Keychain.write(try JSONEncoder().encode(created))
    }

    func rename(to name: String) async throws {
        struct Body: Encodable { let name: String }
        struct Reply: Decodable { let name: String }
        let reply: Reply = try await send("PATCH", "/v1/players/me", body: Body(name: name))
        account?.name = reply.name
        if let account { Keychain.write(try JSONEncoder().encode(account)) }
    }

    func startGame(_ level: Level) async throws -> RankedTicket {
        struct Body: Encodable { let level: String }
        return try await send("POST", "/v1/games", body: Body(level: level.rawValue))
    }

    func finish(gameID: String, moves: [Move]) async throws -> FinishResult {
        struct Body: Encodable { let moves: [Move] }
        return try await send("POST", "/v1/games/\(gameID)/finish", body: Body(moves: moves))
    }

    func leaderboard(_ level: Level) async throws -> Leaderboard {
        try await send("GET", "/v1/leaderboard/\(level.rawValue)?limit=100", body: Optional<String>.none, auth: isSignedIn)
    }

    private func send<T: Decodable>(_ method: String, _ path: String, body: (some Encodable)?, auth: Bool = true) async throws -> T {
        guard let baseURL, let url = URL(string: path, relativeTo: baseURL) else { throw OnlineError.notConfigured }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        request.setValue(AppInfo.version, forHTTPHeaderField: "X-Client-Version")
        request.setValue("Minesweeper/\(AppInfo.version) (macOS)", forHTTPHeaderField: "User-Agent")
        if auth, let token = account?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OnlineError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let problem = try? JSONDecoder().decode(APIProblem.self, from: data)
            if status == 426 { throw OnlineError.upgradeRequired(problem?.message ?? "Please update Minesweeper.") }
            throw OnlineError.server(code: problem?.error ?? "http_\(status)", message: problem?.message ?? "Server error \(status).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// The online account lives in the login keychain, not in preferences.
enum Keychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: AppInfo.bundleID,
        kSecAttrAccount as String: "online-account",
    ]

    static func read() -> Data? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        return SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }

    static func write(_ data: Data) {
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query
            q[kSecValueData as String] = data
            SecItemAdd(q as CFDictionary, nil)
        }
    }
}
