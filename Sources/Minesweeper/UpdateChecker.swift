import AppKit

/// Looks for a newer GitHub release and offers to download it.
@MainActor
enum UpdateChecker {
    private struct Release: Decodable {
        let tagName: String
        let htmlUrl: URL
    }

    static func check(settings: Settings, userInitiated: Bool) async {
        if !userInitiated {
            guard Date().timeIntervalSince(settings.lastUpdateCheck) > 24 * 60 * 60 else { return }
        }
        settings.lastUpdateCheck = Date()

        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(AppInfo.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Minesweeper/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let release: Release
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            release = try decoder.decode(Release.self, from: data)
        } catch {
            if userInitiated { inform("Couldn't check for updates.", error.localizedDescription) }
            return
        }

        let latest = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        guard compareVersions(latest, AppInfo.version) > 0 else {
            if userInitiated { inform("You're up to date.", "Minesweeper \(AppInfo.version) is the newest version.") }
            return
        }
        guard userInitiated || settings.skippedVersion != latest else { return }

        let alert = NSAlert()
        alert.messageText = "Minesweeper \(latest) is available."
        alert.informativeText = """
        You have version \(AppInfo.version).

        Installed with Homebrew? Run:
        brew upgrade --cask minesweeper
        """
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")
        switch alert.runModal() {
        case .alertFirstButtonReturn: NSWorkspace.shared.open(release.htmlUrl)
        case .alertThirdButtonReturn: settings.skippedVersion = latest
        default: break
        }
    }

    private static func inform(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
