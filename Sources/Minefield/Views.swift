import SwiftUI
import AppKit

struct ContentView: View {
    let game: Game

    var body: some View {
        VStack(spacing: 14) {
            HeaderBar(game: game)
            BoardView(game: game)
            Text(statusText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(18)
        .background(Palette.window)
        .fixedSize()
    }

    private var statusText: String {
        switch game.state {
        case .won: return "Field cleared in \(game.elapsed) seconds. Press ⌘N to play again."
        case .lost: return "You hit a mine. Press ⌘N to try again."
        default: return "Click to dig, right-click to flag."
        }
    }
}

// MARK: - Header

struct HeaderBar: View {
    let game: Game

    var body: some View {
        HStack {
            Counter(symbol: "flag.fill", value: game.minesLeft)
            Spacer()
            Button { game.reset() } label: {
                Image(systemName: resetSymbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.soil))
                    .overlay(Circle().strokeBorder(Palette.soilEdge, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .help("New game")
            Spacer()
            Counter(symbol: "clock.fill", value: game.elapsed)
        }
    }

    private var resetSymbol: String {
        switch game.state {
        case .won: return "trophy.fill"
        case .lost: return "arrow.counterclockwise"
        default: return "shovel.fill"
        }
    }
}

struct Counter: View {
    let symbol: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(Palette.flag)
            Text(String(format: "%03d", max(-99, min(999, value))))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Palette.chip))
    }
}

// MARK: - Board

struct BoardView: View {
    let game: Game

    var body: some View {
        VStack(spacing: Tile.gap) {
            ForEach(0..<game.rows, id: \.self) { r in
                HStack(spacing: Tile.gap) {
                    ForEach(0..<game.cols, id: \.self) { c in
                        let i = r * game.cols + c
                        TileView(
                            cell: game.cells[i],
                            lost: game.state == .lost,
                            exploded: game.explodedIndex == i
                        )
                    }
                }
            }
        }
        .overlay(ClickCatcher { point, secondary in handle(point, secondary) })
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.boardBack))
    }

    private func handle(_ p: CGPoint, _ secondary: Bool) {
        let step = Tile.size + Tile.gap
        let c = Int(p.x / step), r = Int(p.y / step)
        guard c >= 0, c < game.cols, r >= 0, r < game.rows,
              p.x - CGFloat(c) * step <= Tile.size,
              p.y - CGFloat(r) * step <= Tile.size else { return }
        let i = r * game.cols + c
        if secondary { game.toggleFlag(i) } else { game.reveal(i) }
    }
}

struct TileView: View {
    let cell: Cell
    let lost: Bool
    let exploded: Bool

    var body: some View {
        ZStack {
            if cell.state == .revealed {
                RoundedRectangle(cornerRadius: Tile.radius)
                    .fill(exploded ? Palette.explode : Palette.soil)
                    .overlay(RoundedRectangle(cornerRadius: Tile.radius)
                        .strokeBorder(Palette.soilEdge.opacity(0.7), lineWidth: 1))
                if cell.isMine {
                    MineGlyph()
                } else if cell.adjacent > 0 {
                    Text("\(cell.adjacent)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.number(cell.adjacent))
                }
            } else {
                RoundedRectangle(cornerRadius: Tile.radius)
                    .fill(LinearGradient(colors: [Palette.turfTop, Palette.turfBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: Tile.radius)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 0.5, y: 1.5)
                if cell.state == .flagged {
                    FlagGlyph()
                    if lost && !cell.isMine {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Palette.explode)
                    }
                }
            }
        }
        .frame(width: Tile.size, height: Tile.size)
        .animation(.easeOut(duration: 0.12), value: cell.state)
    }
}

// MARK: - Hand-drawn assets

struct MineGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = size.width * 0.21
            var spikes = Path()
            for k in 0..<8 {
                let a = CGFloat(k) * .pi / 4
                spikes.move(to: c)
                spikes.addLine(to: CGPoint(x: c.x + cos(a) * r * 1.65, y: c.y + sin(a) * r * 1.65))
            }
            ctx.stroke(spikes, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                     with: .color(Palette.ink))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.6, width: r * 0.55, height: r * 0.55)),
                     with: .color(.white.opacity(0.85)))
        }
    }
}

struct FlagGlyph: View {
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var pole = Path()
            pole.move(to: CGPoint(x: w * 0.40, y: h * 0.20))
            pole.addLine(to: CGPoint(x: w * 0.40, y: h * 0.78))
            ctx.stroke(pole, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            var pennant = Path()
            pennant.move(to: CGPoint(x: w * 0.42, y: h * 0.20))
            pennant.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.33),
                                 control: CGPoint(x: w * 0.62, y: h * 0.18))
            pennant.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.50),
                                 control: CGPoint(x: w * 0.60, y: h * 0.48))
            pennant.closeSubpath()
            ctx.fill(pennant, with: .color(Palette.flag))

            var mound = Path()
            mound.addEllipse(in: CGRect(x: w * 0.24, y: h * 0.72, width: w * 0.34, height: h * 0.12))
            ctx.fill(mound, with: .color(Palette.ink.opacity(0.85)))
        }
    }
}

// MARK: - Mouse handling (left + right click)

struct ClickCatcher: NSViewRepresentable {
    var onClick: (CGPoint, Bool) -> Void

    func makeNSView(context: Context) -> ClickView {
        let view = ClickView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: ClickView, context: Context) {
        view.onClick = onClick
    }

    final class ClickView: NSView {
        var onClick: ((CGPoint, Bool) -> Void)?
        override var isFlipped: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            // Control-click also counts as a right click (trackpad friendly).
            onClick?(convert(event.locationInWindow, from: nil), event.modifierFlags.contains(.control))
        }

        override func rightMouseDown(with event: NSEvent) {
            onClick?(convert(event.locationInWindow, from: nil), true)
        }
    }
}
