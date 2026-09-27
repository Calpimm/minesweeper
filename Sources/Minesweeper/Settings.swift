import Foundation

/// Everything the original kept in winmine.ini.
final class Settings {
    private let d = UserDefaults.standard

    init() {
        d.register(defaults: [
            "level": Level.beginner.rawValue,
            "customWidth": 9, "customHeight": 9, "customMines": 10,
            "marks": true, "color": true, "sound": false, "zoom": 2,
            "lastName": "Anonymous",
        ])
    }

    var level: Level {
        get { Level(rawValue: d.string(forKey: "level") ?? "") ?? .beginner }
        set { d.set(newValue.rawValue, forKey: "level") }
    }

    var custom: BoardSize {
        get {
            BoardSize(width: d.integer(forKey: "customWidth"), height: d.integer(forKey: "customHeight"),
                      mines: d.integer(forKey: "customMines")).clamped()
        }
        set {
            d.set(newValue.width, forKey: "customWidth")
            d.set(newValue.height, forKey: "customHeight")
            d.set(newValue.mines, forKey: "customMines")
        }
    }

    var boardSize: BoardSize {
        switch level {
        case .beginner: return .beginner
        case .intermediate: return .intermediate
        case .expert: return .expert
        case .custom: return custom
        }
    }

    var marks: Bool {
        get { d.bool(forKey: "marks") }
        set { d.set(newValue, forKey: "marks") }
    }

    var color: Bool {
        get { d.bool(forKey: "color") }
        set { d.set(newValue, forKey: "color") }
    }

    var sound: Bool {
        get { d.bool(forKey: "sound") }
        set { d.set(newValue, forKey: "sound") }
    }

    var zoom: Int {
        get { min(max(d.integer(forKey: "zoom"), 1), 4) }
        set { d.set(newValue, forKey: "zoom") }
    }

    var lastName: String {
        get { d.string(forKey: "lastName") ?? "Anonymous" }
        set { d.set(newValue, forKey: "lastName") }
    }

    /// Whether we already offered to join the online leaderboard.
    var offeredOnline: Bool {
        get { d.bool(forKey: "offeredOnline") }
        set { d.set(newValue, forKey: "offeredOnline") }
    }

    var skippedVersion: String? {
        get { d.string(forKey: "skippedVersion") }
        set { d.set(newValue, forKey: "skippedVersion") }
    }

    var lastUpdateCheck: Date {
        get { d.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast }
        set { d.set(newValue, forKey: "lastUpdateCheck") }
    }

    // MARK: - Best times

    func bestTime(_ level: Level) -> (seconds: Int, name: String) {
        let seconds = d.object(forKey: "best.\(level.rawValue).time") as? Int ?? 999
        let name = d.string(forKey: "best.\(level.rawValue).name") ?? "Anonymous"
        return (seconds, name)
    }

    func setBestTime(_ level: Level, seconds: Int, name: String) {
        d.set(seconds, forKey: "best.\(level.rawValue).time")
        d.set(name, forKey: "best.\(level.rawValue).name")
    }

    func resetBestTimes() {
        for level in Level.allCases {
            d.removeObject(forKey: "best.\(level.rawValue).time")
            d.removeObject(forKey: "best.\(level.rawValue).name")
        }
    }
}
