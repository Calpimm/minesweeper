import Foundation
import Testing
@testable import Minesweeper

/// 9×9 board; `mines` are indices (row * 9 + col).
private func board(_ mines: [Int]) -> Game {
    Game(size: BoardSize(width: 9, height: 9, mines: mines.count), mines: mines)
}

@Test func firstClickOnMineMovesItToTopLeft() {
    let game = board([40, 50])
    game.reveal(40)
    #expect(game.status == .playing)
    #expect(game.cells[0].isMine)
    #expect(!game.cells[40].isMine)
    #expect(game.cells[40].isOpen)
    #expect(game.elapsed == 1)
}

@Test func relocatedMineSkipsOccupiedCorner() {
    let game = board([0, 1, 40])
    game.reveal(40)
    #expect(game.cells[2].isMine)
    #expect(game.mineCount == 3)
}

@Test func blankSquaresFloodOpen() {
    let game = board([80])
    game.reveal(0)
    #expect(game.status == .won)
    #expect(game.cells[80].mark == .flag)
    #expect(game.minesLeft == 0)
}

@Test func floodStopsAtFlags() {
    let game = board([80, 79])
    game.cycleMark(4, allowQuestion: true)
    game.reveal(0)
    #expect(!game.cells[4].isOpen)
    #expect(game.cells[4].mark == .flag)
}

@Test func markCycle() {
    let game = board([80])
    game.cycleMark(0, allowQuestion: true)
    #expect(game.cells[0].mark == .flag)
    game.cycleMark(0, allowQuestion: true)
    #expect(game.cells[0].mark == .question)
    game.cycleMark(0, allowQuestion: true)
    #expect(game.cells[0].mark == .none)
    game.cycleMark(0, allowQuestion: false)
    game.cycleMark(0, allowQuestion: false)
    #expect(game.cells[0].mark == .none)
}

@Test func minesLeftCanGoNegative() {
    let game = board([80])
    for i in 0..<3 { game.cycleMark(i, allowQuestion: true) }
    #expect(game.minesLeft == -2)
}

@Test func chordOpensNeighboursWhenFlagsMatch() {
    // Mine at (1,1) = 10. Square 0 touches it.
    let game = board([10, 80])
    game.reveal(0)
    #expect(game.cells[0].adjacent == 1)
    game.cycleMark(10, allowQuestion: true)
    game.chord(0)
    #expect(game.cells[1].isOpen && game.cells[9].isOpen)
    #expect(game.status == .playing)
}

@Test func chordWithWrongFlagLoses() {
    let game = board([10, 80])
    game.reveal(0)
    game.cycleMark(1, allowQuestion: true)
    game.chord(0)
    #expect(game.status == .lost)
    #expect(game.exploded == [10])
}

@Test func chordIgnoredWhenFlagCountDiffers() {
    let game = board([10, 80])
    game.reveal(0)
    game.chord(0)
    #expect(!game.cells[1].isOpen)
    #expect(game.status == .playing)
}

@Test func flaggedSquareCannotBeOpened() {
    let game = board([80])
    game.cycleMark(0, allowQuestion: true)
    game.reveal(0)
    #expect(game.status == .ready)
}

@Test func clockCountsWholeSecondsAndStopsAt999() {
    let game = board([10, 80])
    game.reveal(0)
    game.updateClock(ms: 999)
    #expect(game.elapsed == 1)
    game.updateClock(ms: 1000)
    #expect(game.elapsed == 2)
    game.updateClock(ms: 5_000_000)
    #expect(game.elapsed == 999)
}

@Test func customFieldLimits() {
    #expect(BoardSize(width: 100, height: 1, mines: 9999).clamped() == BoardSize(width: 30, height: 9, mines: 232))
    #expect(BoardSize(width: 30, height: 24, mines: 9999).clamped().mines == 667)
    #expect(BoardSize(width: 5, height: 5, mines: 0).clamped() == BoardSize(width: 9, height: 9, mines: 10))
}

@Test func spritesAreWellFormed() {
    _ = Renderer.render(board([80]), pressed: [], face: .smile, facePressed: false, color: true)
    #expect(Sprites.digits.allSatisfy { $0.width == 10 && $0.height == 10 })
    #expect([Sprites.smile, Sprites.ooh, Sprites.dead, Sprites.cool].allSatisfy { $0.width == 17 && $0.height == 17 })
    #expect([Sprites.mine, Sprites.flag, Sprites.question, Sprites.cross].allSatisfy { $0.width == 16 && $0.height == 16 })
}

// MARK: - Online

/// shared/test-vectors.json is produced by the server's copy of the rules.
@Test func seededLayoutsMatchTheServer() throws {
    struct Vectors: Decodable {
        struct Layout: Decodable { let width: Int; let height: Int; let seed: UInt32; let mines: [Int] }
        let layouts: [Layout]
    }
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("shared/test-vectors.json"))
    let vectors = try JSONDecoder().decode(Vectors.self, from: data)
    #expect(vectors.layouts.count == 15)
    for v in vectors.layouts {
        let size = BoardSize(width: v.width, height: v.height, mines: v.mines.count)
        #expect(Game.layout(size, seed: v.seed).sorted() == v.mines, "seed \(v.seed) \(v.width)x\(v.height)")
    }
}

@Test func reseedOnlyBeforeFirstClick() {
    let game = Game(size: .beginner, seed: 1)
    game.reseed(42)
    #expect(game.seed == 42)
    #expect(Set(game.cells.indices.filter { game.cells[$0].isMine }) == Set(Game.layout(.beginner, seed: 42)))
    let safe = game.cells.indices.first { !game.cells[$0].isMine }!
    game.reveal(safe)
    game.reseed(7)
    #expect(game.seed == 42)
}

@Test func movesAreRecordedForReplay() {
    let game = board([10, 80])
    game.cycleMark(40, allowQuestion: true, at: 999)   // before the first click: t is 0
    game.reveal(0, at: 0)
    game.cycleMark(10, allowQuestion: true, at: 1500)
    game.chord(0, at: 2000)
    game.chord(0, at: 2100)                            // nothing left to open: not recorded
    #expect(game.moves == [
        Move(t: 0, a: .mark, i: 40, m: 1),
        Move(t: 0, a: .reveal, i: 0),
        Move(t: 1500, a: .mark, i: 10, m: 1),
        Move(t: 2000, a: .chord, i: 0),
    ])
}

@Test func winTimeIsTheLastMove() {
    let game = board([80])
    #expect(game.winTimeMs == nil)
    game.reveal(0, at: 0)
    #expect(game.winTimeMs == 0)
}

@Test func versionsCompareNumerically() {
    #expect(compareVersions("1.10.0", "1.9.9") == 1)
    #expect(compareVersions("v1.1.0", "1.1") == 0)
    #expect(compareVersions("1.0.9", "1.1.0") == -1)
}
