import Foundation

struct BoardSize: Equatable {
    var width: Int
    var height: Int
    var mines: Int

    static let beginner = BoardSize(width: 9, height: 9, mines: 10)
    static let intermediate = BoardSize(width: 16, height: 16, mines: 40)
    static let expert = BoardSize(width: 30, height: 16, mines: 99)

    /// Same limits as the original Custom Field dialog:
    /// height 9–24, width 9–30, mines 10 … (height − 1) × (width − 1).
    func clamped() -> BoardSize {
        let w = min(max(width, 9), 30)
        let h = min(max(height, 9), 24)
        let m = min(max(mines, 10), (w - 1) * (h - 1))
        return BoardSize(width: w, height: h, mines: m)
    }
}

enum Level: String, CaseIterable {
    case beginner, intermediate, expert, custom

    var title: String { rawValue.capitalized }
    static let ranked: [Level] = [.beginner, .intermediate, .expert]
}

enum Mark: Int { case none = 0, flag = 1, question = 2 }

struct Cell {
    var isMine = false
    var isOpen = false
    var mark = Mark.none
    var adjacent = 0
}

enum GameStatus { case ready, playing, won, lost }

/// One player action, as sent to the leaderboard server for replay.
/// `t` is milliseconds since the first square was opened.
struct Move: Codable, Equatable {
    enum Action: String, Codable { case reveal = "r", chord = "c", mark = "m" }
    let t: Int
    let a: Action
    let i: Int
    var m: Int? = nil
}

/// mulberry32 — tiny, and bit-for-bit identical to the server's copy
/// in server/src/game.ts, so a seed gives the same minefield on both sides.
struct Mulberry32 {
    private var state: UInt32
    init(seed: UInt32) { state = seed }

    mutating func next() -> UInt32 {
        state &+= 0x6D2B_79F5
        var t = (state ^ (state >> 15)) &* (state | 1)
        t = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t
        return t ^ (t >> 14)
    }
}

/// The rules of Windows Minesweeper (3.1 – XP).
final class Game {
    let width: Int
    let height: Int
    let mineCount: Int
    private(set) var seed: UInt32?
    private(set) var cells: [Cell]
    private(set) var status = GameStatus.ready
    private(set) var elapsed = 0
    /// Mines that were clicked on; drawn on a red background.
    private(set) var exploded: Set<Int> = []
    private(set) var moves: [Move] = []
    private var openCount = 0

    init(size: BoardSize, mines: some Sequence<Int>) {
        width = size.width
        height = size.height
        cells = Array(repeating: Cell(), count: size.width * size.height)
        for i in mines { cells[i].isMine = true }
        mineCount = cells.filter(\.isMine).count
        countAdjacent()
    }

    convenience init(size: BoardSize, seed: UInt32 = .random(in: .min ... .max)) {
        self.init(size: size, mines: Game.layout(size, seed: seed))
        self.seed = seed
    }

    /// Fisher–Yates shuffle driven by the seed; the first `mines` squares get a mine.
    static func layout(_ size: BoardSize, seed: UInt32) -> [Int] {
        var rng = Mulberry32(seed: seed)
        var squares = Array(0..<(size.width * size.height))
        for i in stride(from: squares.count - 1, to: 0, by: -1) {
            squares.swapAt(i, Int(rng.next() % UInt32(i + 1)))
        }
        return Array(squares.prefix(size.mines))
    }

    /// Swaps in a server-issued minefield. Only possible before the first square opens.
    func reseed(_ seed: UInt32) {
        guard status == .ready else { return }
        let mines = Set(Game.layout(BoardSize(width: width, height: height, mines: mineCount), seed: seed))
        for i in cells.indices { cells[i].isMine = mines.contains(i) }
        countAdjacent()
        self.seed = seed
    }

    var isActive: Bool { status == .ready || status == .playing }

    /// Can go negative when the player places more flags than there are mines.
    var minesLeft: Int { mineCount - cells.filter { $0.mark == .flag }.count }

    /// Winning time in milliseconds, for the online leaderboard.
    var winTimeMs: Int? { status == .won ? moves.last?.t : nil }

    // MARK: - Moves

    /// Left click on a square. `t` is ms since the first click (0 for the first click itself).
    func reveal(_ i: Int, at t: Int = 0) {
        guard isActive, !cells[i].isOpen, cells[i].mark != .flag else { return }
        if status == .ready {
            // The first click can never lose: the mine is moved to the first
            // free square scanning from the top-left corner.
            if cells[i].isMine { moveMine(from: i) }
            status = .playing
            elapsed = 1   // the clock reads 1 as soon as the first square opens
        }
        moves.append(Move(t: t, a: .reveal, i: i))
        if cells[i].isMine {
            lose(hitting: [i])
        } else {
            open(i)
            checkWin()
        }
    }

    /// Both buttons (or the middle button) on an open number: if the right
    /// number of flags surround it, open every other neighbour.
    func chord(_ i: Int, at t: Int = 0) {
        guard status == .playing, cells[i].isOpen, cells[i].adjacent > 0 else { return }
        let around = neighbors(of: i)
        guard around.filter({ cells[$0].mark == .flag }).count == cells[i].adjacent else { return }
        let targets = around.filter { !cells[$0].isOpen && cells[$0].mark != .flag }
        guard !targets.isEmpty else { return }
        moves.append(Move(t: t, a: .chord, i: i))
        let hits = targets.filter { cells[$0].isMine }
        for s in targets where !cells[s].isMine { open(s) }
        if hits.isEmpty { checkWin() } else { lose(hitting: hits) }
    }

    /// Right click: blank → flag → ? (when Marks is on) → blank.
    func cycleMark(_ i: Int, allowQuestion: Bool, at t: Int = 0) {
        guard isActive, !cells[i].isOpen else { return }
        switch cells[i].mark {
        case .none: cells[i].mark = .flag
        case .flag: cells[i].mark = allowQuestion ? .question : .none
        case .question: cells[i].mark = .none
        }
        moves.append(Move(t: status == .ready ? 0 : t, a: .mark, i: i, m: cells[i].mark.rawValue))
    }

    /// Updates the counter from the game clock; stops at 999 like the original.
    func updateClock(ms: Int) {
        guard status == .playing else { return }
        elapsed = min(999, 1 + ms / 1000)
    }

    // MARK: - Rules

    func neighbors(of i: Int) -> [Int] {
        let x = i % width, y = i / width
        var out: [Int] = []
        for dy in -1...1 {
            for dx in -1...1 where dx != 0 || dy != 0 {
                let nx = x + dx, ny = y + dy
                if nx >= 0, nx < width, ny >= 0, ny < height { out.append(ny * width + nx) }
            }
        }
        return out
    }

    private func countAdjacent() {
        for i in cells.indices {
            cells[i].adjacent = neighbors(of: i).filter { cells[$0].isMine }.count
        }
    }

    private func moveMine(from i: Int) {
        guard let free = cells.indices.first(where: { !cells[$0].isMine }) else { return }
        cells[i].isMine = false
        cells[free].isMine = true
        countAdjacent()
    }

    /// Opens a square; blank squares flood-open their neighbours.
    /// Flags stop the flood, question marks do not.
    private func open(_ i: Int) {
        var stack = [i]
        while let j = stack.popLast() {
            guard !cells[j].isOpen, cells[j].mark != .flag else { continue }
            cells[j].isOpen = true
            cells[j].mark = .none
            openCount += 1
            if cells[j].adjacent == 0 { stack.append(contentsOf: neighbors(of: j)) }
        }
    }

    private func checkWin() {
        guard openCount == cells.count - mineCount else { return }
        status = .won
        for i in cells.indices where cells[i].isMine { cells[i].mark = .flag }
    }

    private func lose(hitting mines: [Int]) {
        status = .lost
        exploded = Set(mines)
    }
}
