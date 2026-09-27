import SwiftUI

@main
struct MinefieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var game = Game()

    var body: some Scene {
        Window("Minefield", id: "main") {
            ContentView(game: game)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") { game.reset() }
                    .keyboardShortcut("n")
            }
            CommandMenu("Difficulty") {
                Button("Beginner (9×9, 10 mines)") { game.reset(.beginner) }
                    .keyboardShortcut("1")
                Button("Intermediate (16×16, 40 mines)") { game.reset(.intermediate) }
                    .keyboardShortcut("2")
                Button("Expert (30×16, 99 mines)") { game.reset(.expert) }
                    .keyboardShortcut("3")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed so the window comes to the front when launched via `swift run`.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
