import AppKit
import SwiftUI

/// Game time that can be paused (the original stops the clock while minimised).
struct GameClock {
    private var startedAt: ContinuousClock.Instant?
    private var banked = Duration.zero
    private(set) var isRunning = false

    var ms: Int {
        let total = banked + (startedAt.map { .now - $0 } ?? .zero)
        return Int(total.components.seconds) * 1000 + Int(total.components.attoseconds / 1_000_000_000_000_000)
    }

    mutating func start() { banked = .zero; startedAt = .now; isRunning = true }
    mutating func stop() { pause(); isRunning = false }

    mutating func pause() {
        if let startedAt { banked += .now - startedAt }
        startedAt = nil
    }

    mutating func resume() {
        if isRunning && startedAt == nil { startedAt = .now }
    }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, BoardViewDelegate {
    private let settings = Settings()
    private let online = OnlineService()
    private var game: Game!
    /// Server id when the current game is ranked (its seed came from the server).
    private var rankedGameID: String?
    private var window: NSWindow!
    private let board = BoardView()
    private var clock = GameClock()
    private var ticker: Timer?
    private var leaderboardWindow: NSWindow?
    private var warnedUpgrade = false

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = NSImage(cgImage: Renderer.icon(), size: NSSize(width: 512, height: 512))
        NSApp.mainMenu = buildMenu()

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Minesweeper"
        window.contentView = board
        window.delegate = self
        board.delegate = self
        board.color = settings.color
        window.center()
        window.setFrameAutosaveName("Minesweeper")

        newGame()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(board)
        NSApp.activate(ignoringOtherApps: true)

        if Bundle.main.bundleIdentifier != nil {
            Task { await UpdateChecker.check(settings: settings, userInitiated: false) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Game flow

    private func newGame() {
        stopClock()
        let level = settings.level
        game = Game(size: settings.boardSize)
        rankedGameID = nil
        board.game = game
        fitWindow()
        if Level.ranked.contains(level) && online.isSignedIn { requestRankedSeed(for: game, level: level) }
    }

    /// Asks the server for this game's minefield. If it arrives before the first
    /// click the game becomes ranked; otherwise it's simply played offline.
    private func requestRankedSeed(for target: Game, level: Level) {
        Task {
            do {
                let ticket = try await online.startGame(level)
                guard target === game, target.status == .ready else { return }
                target.reseed(ticket.seed)
                rankedGameID = ticket.id
                board.needsDisplay = true
            } catch {
                handleOnlineError(error)
            }
        }
    }

    /// Wraps every move so the clock, sounds and records follow the game state.
    private func play(_ move: (_ t: Int) -> Void) {
        let before = game.status
        move(clock.isRunning ? clock.ms : 0)
        let after = game.status
        if before == .ready && after != .ready { startClock() }
        if before != after && (after == .won || after == .lost) {
            stopClock()
            playSound(after == .won ? "Glass" : "Basso")
            if after == .won {
                let finished = game!
                DispatchQueue.main.async { self.gameWon(finished) }
            }
        }
        board.needsDisplay = true
    }

    func boardReveal(_ square: Int) { play { game.reveal(square, at: $0) } }
    func boardChord(_ square: Int) { play { game.chord(square, at: $0) } }
    func boardMark(_ square: Int) { play { game.cycleMark(square, allowQuestion: settings.marks, at: $0) } }
    func boardNewGame() { newGame() }

    private func gameWon(_ finished: Game) {
        checkBestTime()
        if let id = rankedGameID, let ms = finished.winTimeMs, finished === game {
            submitRanked(id: id, moves: finished.moves, timeMs: ms)
        } else if Level.ranked.contains(settings.level) && online.isAvailable && !online.isSignedIn && !settings.offeredOnline {
            settings.offeredOnline = true
            joinOnline(prompt: "Want to see how you rank against other players?")
        }
    }

    private func submitRanked(id: String, moves: [Move], timeMs: Int) {
        let level = settings.level
        Task {
            do {
                let result = try await online.finish(gameID: id, moves: moves)
                guard result.personalBest, let best = result.best else { return }
                let alert = NSAlert()
                alert.messageText = "New online personal best: \(formatTime(result.timeMs))"
                alert.informativeText = "You're #\(best.rank) on the \(level.rawValue) leaderboard."
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Show Leaderboard")
                if alert.runModal() == .alertSecondButtonReturn { showLeaderboard(level: level) }
            } catch {
                handleOnlineError(error)
            }
        }
    }

    private func handleOnlineError(_ error: Error) {
        // Online is a bonus: the game keeps working offline, so only an
        // outdated client is worth interrupting the player for.
        guard case OnlineError.upgradeRequired(let message) = error, !warnedUpgrade else { return }
        warnedUpgrade = true
        let alert = NSAlert()
        alert.messageText = "Update required for online play"
        alert.informativeText = message
        alert.addButton(withTitle: "Check for Updates")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn { checkForUpdates(nil) }
    }

    // MARK: - Clock

    private func startClock() {
        clock.start()
        playSound("Tink")
        runTicker()
    }

    /// Redraws whenever the counter changes; the time itself comes from `clock`.
    private func runTicker() {
        ticker?.invalidate()
        // .common keeps it ticking while a menu is open.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.game.status == .playing else { return }
                let shown = self.game.elapsed
                self.game.updateClock(ms: self.clock.ms)
                if self.game.elapsed != shown {
                    self.playSound("Tink")
                    self.board.needsDisplay = true
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopClock() {
        clock.stop()
        ticker?.invalidate()
        ticker = nil
    }

    // Like the original, the clock pauses while the window is minimised.
    func windowWillMiniaturize(_ notification: Notification) {
        clock.pause()
        ticker?.invalidate()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        guard game.status == .playing else { return }
        clock.resume()
        runTicker()
    }

    private func playSound(_ name: String) {
        guard settings.sound else { return }
        (NSSound(named: NSSound.Name(name))?.copy() as? NSSound)?.play()
    }

    // MARK: - Window

    /// Resizes the window to the board, keeping its top-left corner in place.
    /// The zoom is lowered if the board would not fit on screen.
    private func fitWindow() {
        let layout = Layout(cols: game.width, rows: game.height)
        let screen = (window.screen ?? NSScreen.main)?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let chrome = window.frameRect(forContentRect: .zero).size
        var zoom = settings.zoom
        while zoom > 1 && (CGFloat(layout.width * zoom) + chrome.width > screen.width ||
                           CGFloat(layout.height * zoom) + chrome.height > screen.height) {
            zoom -= 1
        }
        board.zoom = zoom
        let content = NSSize(width: layout.width * zoom, height: layout.height * zoom)
        let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size
        var frame = window.frame
        frame.origin.y = frame.maxY - size.height
        frame.size = size
        window.setFrame(frame, display: true)
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let main = NSMenu()

        func menu(_ title: String, _ build: (NSMenu) -> Void) -> NSMenu {
            let m = NSMenu(title: title)
            build(m)
            let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            holder.submenu = m
            main.addItem(holder)
            return m
        }
        func item(_ m: NSMenu, _ title: String, _ action: Selector, _ key: String = "",
                  _ mods: NSEvent.ModifierFlags = .command, tag: Int = 0, mine: Bool = true) {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.tag = tag
            if mine { i.target = self }
            m.addItem(i)
        }

        _ = menu("Minesweeper") { m in
            item(m, "About Minesweeper", #selector(showAbout))
            item(m, "Check for Updates…", #selector(checkForUpdates))
            m.addItem(.separator())
            item(m, "Hide Minesweeper", #selector(NSApplication.hide(_:)), "h", mine: false)
            item(m, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option], mine: false)
            item(m, "Show All", #selector(NSApplication.unhideAllApplications(_:)), mine: false)
            m.addItem(.separator())
            item(m, "Quit Minesweeper", #selector(NSApplication.terminate(_:)), "q", mine: false)
        }
        _ = menu("Game") { m in
            item(m, "New", #selector(newGameAction), String(Character(UnicodeScalar(NSF2FunctionKey)!)), [])
            m.addItem(.separator())
            item(m, "Beginner", #selector(selectLevel), "1", tag: 0)
            item(m, "Intermediate", #selector(selectLevel), "2", tag: 1)
            item(m, "Expert", #selector(selectLevel), "3", tag: 2)
            item(m, "Custom…", #selector(showCustom), "4")
            m.addItem(.separator())
            item(m, "Marks (?)", #selector(toggleMarks))
            item(m, "Color", #selector(toggleColor))
            item(m, "Sound", #selector(toggleSound))
            m.addItem(.separator())
            item(m, "Best Times…", #selector(showBestTimes))
            m.addItem(.separator())
            item(m, "Online Leaderboard…", #selector(showLeaderboardAction), "l")
            item(m, "Join Online Leaderboard…", #selector(joinOrRename))
        }
        _ = menu("View") { m in
            item(m, "Actual Size", #selector(zoomActual), "0")
            item(m, "Zoom In", #selector(zoomIn), "+")
            item(m, "Zoom Out", #selector(zoomOut), "-")
        }
        let windowMenu = menu("Window") { m in
            item(m, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m", mine: false)
            item(m, "Close", #selector(NSWindow.performClose(_:)), "w", mine: false)
        }
        NSApp.windowsMenu = windowMenu
        let helpMenu = menu("Help") { m in
            item(m, "How to Play", #selector(showHelp), "?")
        }
        NSApp.helpMenu = helpMenu
        return main
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(selectLevel):
            menuItem.state = Level.allCases[menuItem.tag] == settings.level ? .on : .off
        case #selector(showCustom):
            menuItem.state = settings.level == .custom ? .on : .off
        case #selector(toggleMarks):
            menuItem.state = settings.marks ? .on : .off
        case #selector(toggleColor):
            menuItem.state = settings.color ? .on : .off
        case #selector(toggleSound):
            menuItem.state = settings.sound ? .on : .off
        case #selector(showLeaderboardAction):
            return online.isAvailable
        case #selector(joinOrRename):
            menuItem.title = online.isSignedIn ? "Change Online Name…" : "Join Online Leaderboard…"
            return online.isAvailable
        case #selector(zoomIn):
            return settings.zoom < 4
        case #selector(zoomOut):
            return settings.zoom > 1
        default:
            break
        }
        return true
    }

    // MARK: - Actions

    @objc private func newGameAction(_ sender: Any?) { newGame() }

    @objc private func selectLevel(_ sender: NSMenuItem) {
        settings.level = Level.allCases[sender.tag]
        newGame()
    }

    @objc private func toggleMarks(_ sender: Any?) { settings.marks.toggle() }

    @objc private func toggleColor(_ sender: Any?) {
        settings.color.toggle()
        board.color = settings.color
    }

    @objc private func toggleSound(_ sender: Any?) { settings.sound.toggle() }

    @objc private func zoomActual(_ sender: Any?) { setZoom(1) }
    @objc private func zoomIn(_ sender: Any?) { setZoom(settings.zoom + 1) }
    @objc private func zoomOut(_ sender: Any?) { setZoom(settings.zoom - 1) }

    private func setZoom(_ z: Int) {
        settings.zoom = z
        fitWindow()
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Minesweeper",
            .applicationVersion: AppInfo.version,
            .version: "",
            .credits: NSAttributedString(string: "A faithful Mac remake of the classic Windows game."),
        ])
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        Task { await UpdateChecker.check(settings: settings, userInitiated: true) }
    }

    @objc private func showLeaderboardAction(_ sender: Any?) {
        showLeaderboard(level: Level.ranked.contains(settings.level) ? settings.level : .beginner)
    }

    private func showLeaderboard(level: Level) {
        let host = NSHostingController(rootView: LeaderboardView(online: online, level: level))
        if let leaderboardWindow {
            leaderboardWindow.contentViewController = host
        } else {
            let w = NSWindow(contentViewController: host)
            w.title = "Online Leaderboard"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("Leaderboard")
            leaderboardWindow = w
        }
        leaderboardWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func joinOrRename(_ sender: Any?) {
        if let name = online.account?.name {
            askForName(title: "Change your online name", message: "Your times stay with you.", initial: name,
                       action: "Rename") { try await self.online.rename(to: $0) }
        } else {
            joinOnline(prompt: "Compare your times with players around the world.")
        }
    }

    private func joinOnline(prompt: String) {
        askForName(title: "Join the online leaderboard", message: prompt + """
         Only your name and your ranked games are sent to the server.
        """, initial: settings.lastName == "Anonymous" ? "" : settings.lastName, action: "Join") { name in
            try await self.online.register(name: name)
            // Start ranking right away if the next game hasn't begun.
            if self.game.status == .ready, Level.ranked.contains(self.settings.level) {
                self.requestRankedSeed(for: self.game, level: self.settings.level)
            }
        }
    }

    /// Name prompt that stays open until the server accepts the name or the player cancels.
    private func askForName(title: String, message: String, initial: String, action: String,
                            submit: @escaping (String) async throws -> Void) {
        let field = NSTextField(string: initial)
        field.frame.size = NSSize(width: 240, height: 22)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = field
        alert.addButton(withTitle: action)
        alert.addButton(withTitle: "Not Now")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                try await submit(name)
            } catch {
                let retry = NSAlert()
                retry.messageText = error.localizedDescription
                retry.addButton(withTitle: "Try Again")
                retry.addButton(withTitle: "Cancel")
                if retry.runModal() == .alertFirstButtonReturn {
                    askForName(title: title, message: message, initial: name, action: action, submit: submit)
                }
            }
        }
    }

    @objc private func showHelp(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "How to Play"
        alert.informativeText = """
        Find all the mines without opening any of them.

        • Click a square to open it. A number tells how many mines touch that square.
        • Right-click (or Control-click) to place a flag on a square you think is a mine. \
        With Marks (?) on, right-click again for a question mark.
        • Click with both buttons, the middle button, or Option-click on a number whose \
        flags are all placed to open every other square around it.
        • Click the face or press F2 (⌘N) to start a new game.

        Your first click is always safe.
        """
        alert.runModal()
    }

    @objc private func showCustom(_ sender: Any?) {
        let current = settings.level == .custom ? settings.custom : settings.boardSize
        let height = numberField(current.height)
        let width = numberField(current.width)
        let mines = numberField(current.mines)
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Height:"), height],
            [NSTextField(labelWithString: "Width:"), width],
            [NSTextField(labelWithString: "Mines:"), mines],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowSpacing = 8
        grid.frame.size = grid.fittingSize

        let alert = NSAlert()
        alert.messageText = "Custom Field"
        alert.accessoryView = grid
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = height
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        settings.custom = BoardSize(width: width.integerValue, height: height.integerValue,
                                    mines: mines.integerValue).clamped()
        settings.level = .custom
        newGame()
    }

    private func numberField(_ value: Int) -> NSTextField {
        let f = NSTextField(string: String(value))
        f.widthAnchor.constraint(equalToConstant: 60).isActive = true
        return f
    }

    @objc private func showBestTimes(_ sender: Any?) {
        while true {
            let rows = [Level.beginner, .intermediate, .expert].map { level -> [NSView] in
                let best = settings.bestTime(level)
                return [NSTextField(labelWithString: level.title + ":"),
                        NSTextField(labelWithString: "\(best.seconds) seconds"),
                        NSTextField(labelWithString: best.name)]
            }
            let grid = NSGridView(views: rows)
            grid.columnSpacing = 16
            grid.rowSpacing = 6
            grid.frame.size = grid.fittingSize

            let alert = NSAlert()
            alert.messageText = "Fastest Mine Sweepers"
            alert.accessoryView = grid
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Reset Scores")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
            settings.resetBestTimes()
        }
    }

    private func checkBestTime() {
        let level = settings.level
        guard level != .custom, game.status == .won, game.elapsed < settings.bestTime(level).seconds else { return }

        let field = NSTextField(string: settings.lastName)
        field.frame.size = NSSize(width: 220, height: 22)
        let alert = NSAlert()
        alert.messageText = "You have the fastest time for \(level.rawValue) level."
        alert.informativeText = "Please type your name."
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.window.initialFirstResponder = field
        alert.runModal()

        let typed = field.stringValue.trimmingCharacters(in: .whitespaces)
        let name = typed.isEmpty ? "Anonymous" : String(typed.prefix(32))
        settings.lastName = name
        settings.setBestTime(level, seconds: game.elapsed, name: name)
        showBestTimes(nil)
    }
}
