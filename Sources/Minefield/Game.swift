import Foundation
import Observation

enum Difficulty: String, CaseIterable {
    case beginner, intermediate, expert

    var size: (cols: Int, rows: Int, mines: Int) {
        switch self {
        case .beginner: return (9, 9, 10)
        case .intermediate: return (16, 16, 40)
        case .expert: return (30, 16, 99)
        }
    }
}

enum CellState: Equatable { case hidden, flagged, revealed }
enum GameState: Equatable { case ready, playing, won, lost }

struct Cell {
    var isMine = false
    var adjacent = 0
    var state: CellState = .hidden
}

@Observable
final class Game {
    private(set) var difficulty: Difficulty
    private(set) var cols: Int
    private(set) var rows: Int
    private(set) var mineCount: Int
    private(set) var cells: [Cell]
    private(set) var state: GameState = .ready
    private(set) var elapsed = 0
    private(set) var explodedIndex: Int?

    @ObservationIgnored private var timer: Timer?

    var minesLeft: Int { mineCount - cells.filter { $0.state == .flagged }.count }

    init(difficulty: Difficulty = .beginner) {
        let s = difficulty.size
        self.difficulty = difficulty
        self.cols = s.cols
        self.rows = s.rows
        self.mineCount = s.mines
        self.cells = Array(repeating: Cell(), count: s.cols * s.rows)
    }

    // MARK: - Actions

    func reset(_ newDifficulty: Difficulty? = nil) {
        if let newDifficulty { difficulty = newDifficulty }
        let s = difficulty.size
        cols = s.cols
        rows = s.rows
        mineCount = s.mines
        cells = Array(repeating: Cell(), count: cols * rows)
        state = .ready
        elapsed = 0
        explodedIndex = nil
        stopTimer()
    }

    /// Left click: dig a cell, or "chord" an already-open number.
    func reveal(_ i: Int) {
        guard state == .ready || state == .playing else { return }
        if state == .ready {
            placeMines(avoiding: i)   // first click is always safe
            state = .playing
            startTimer()
        }
        switch cells[i].state {
        case .flagged: return
        case .revealed: chord(i)
        case .hidden: open(i)
        }
        if state == .playing { checkWin() }
    }

    /// Right click: place or remove a flag.
    func toggleFlag(_ i: Int) {
        guard state == .ready || state == .playing else { return }
        switch cells[i].state {
        case .hidden: cells[i].state = .flagged
        case .flagged: cells[i].state = .hidden
        case .revealed: break
        }
    }

    // MARK: - Rules

    func neighbors(of i: Int) -> [Int] {
        let c = i % cols, r = i / cols
        var out: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nc = c + dc, nr = r + dr
                if nc >= 0, nc < cols, nr >= 0, nr < rows { out.append(nr * cols + nc) }
            }
        }
        return out
    }

    private func placeMines(avoiding i: Int) {
        let safeZone = Set(neighbors(of: i) + [i])
        let spots = cells.indices.filter { !safeZone.contains($0) }.shuffled().prefix(mineCount)
        for s in spots { cells[s].isMine = true }
        for j in cells.indices {
            cells[j].adjacent = neighbors(of: j).filter { cells[$0].isMine }.count
        }
    }

    private func open(_ i: Int) {
        if cells[i].isMine {
            cells[i].state = .revealed
            explodedIndex = i
            lose()
            return
        }
        // Flood fill: empty cells open their neighbours automatically.
        var stack = [i]
        while let j = stack.popLast() {
            guard cells[j].state == .hidden else { continue }
            cells[j].state = .revealed
            if cells[j].adjacent == 0 {
                stack.append(contentsOf: neighbors(of: j).filter { cells[$0].state == .hidden })
            }
        }
    }

    private func chord(_ i: Int) {
        let around = neighbors(of: i)
        let flags = around.filter { cells[$0].state == .flagged }.count
        guard cells[i].adjacent > 0, flags == cells[i].adjacent else { return }
        for j in around where cells[j].state == .hidden {
            open(j)
            if state == .lost { return }
        }
    }

    private func checkWin() {
        let done = !cells.contains { !$0.isMine && $0.state != .revealed }
        guard done else { return }
        state = .won
        stopTimer()
        for i in cells.indices where cells[i].isMine { cells[i].state = .flagged }
    }

    private func lose() {
        state = .lost
        stopTimer()
        for i in cells.indices where cells[i].isMine && cells[i].state == .hidden {
            cells[i].state = .revealed
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.elapsed < 999 else { return }
            self.elapsed += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
