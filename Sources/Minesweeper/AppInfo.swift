import Foundation

enum AppInfo {
    /// The single source of truth for the app version. The build script copies it
    /// into Info.plist and the release workflow refuses tags that don't match it.
    static let version = "1.0.0"

    static let repository = "Calpimm/minesweeper"
    static let bundleID = "com.calpimm.minesweeper"

    /// Leaderboard server: Info.plist (release builds) or the environment (development).
    static let apiBaseURL: URL? = {
        let value = Bundle.main.object(forInfoDictionaryKey: "MSApiBaseURL") as? String
            ?? ProcessInfo.processInfo.environment["MINESWEEPER_API_URL"]
        guard let value, !value.isEmpty else { return nil }
        return URL(string: value)
    }()
}

/// Compares "1.2.3"-style versions; missing or non-numeric parts count as 0.
func compareVersions(_ a: String, _ b: String) -> Int {
    func parts(_ v: String) -> [Int] {
        let trimmed = v.hasPrefix("v") ? String(v.dropFirst()) : v
        let numbers = trimmed.split(whereSeparator: { ".+-".contains($0) }).prefix(3).map { Int($0) ?? 0 }
        return numbers + Array(repeating: 0, count: 3 - numbers.count)
    }
    let (x, y) = (parts(a), parts(b))
    for i in 0..<3 where x[i] != y[i] { return x[i] < y[i] ? -1 : 1 }
    return 0
}
