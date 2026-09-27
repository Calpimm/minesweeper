import CoreGraphics

enum Face { case smile, ooh, dead, cool }

/// Window geometry of the original, in pixels.
struct Layout {
    static let square = 16
    static let gridX = 12
    static let gridY = 55
    static let faceSize = 26

    let cols: Int
    let rows: Int

    var width: Int { Layout.gridX + cols * Layout.square + 8 }
    var height: Int { Layout.gridY + rows * Layout.square + 8 }

    var faceX: Int { 9 + (width - 14 - Layout.faceSize) / 2 }
    var faceY: Int { 14 }
    var timerX: Int { width - 53 }

    func faceContains(_ x: Int, _ y: Int) -> Bool {
        x >= faceX && x < faceX + Layout.faceSize && y >= faceY && y < faceY + Layout.faceSize
    }

    func square(atX x: Int, y: Int) -> Int? {
        let c = (x - Layout.gridX), r = (y - Layout.gridY)
        guard c >= 0, r >= 0, c < cols * Layout.square, r < rows * Layout.square else { return nil }
        return (r / Layout.square) * cols + c / Layout.square
    }
}

enum Renderer {
    static func render(_ game: Game, pressed: Set<Int>, face: Face, facePressed: Bool, color: Bool) -> CGImage {
        let layout = Layout(cols: game.width, rows: game.height)
        let w = layout.width, h = layout.height
        let c = PixelCanvas(width: w, height: h)

        c.fill(0, 0, w, h, .silver)
        c.bevel(0, 0, w, h, thickness: 3, topLeft: .white, bottomRight: .silver)

        // Header: mine counter, face, timer.
        c.bevel(9, 9, w - 14, 37, thickness: 2, topLeft: .gray, bottomRight: .white)
        drawCounter(game.minesLeft, on: c, 16, 15, color: color)
        drawCounter(game.elapsed, on: c, layout.timerX, 15, color: color)
        drawFace(face, pressed: facePressed, on: c, layout.faceX, layout.faceY)

        // Minefield.
        c.bevel(9, 52, game.width * 16 + 6, game.height * 16 + 6, thickness: 3, topLeft: .gray, bottomRight: .white)
        for i in game.cells.indices {
            drawSquare(i, of: game, pressed: pressed.contains(i), on: c,
                       Layout.gridX + (i % game.width) * 16, Layout.gridY + (i / game.width) * 16, color: color)
        }
        return c.makeImage(monochrome: !color)
    }

    /// App icon: the face button on a raised tile, 32×32 pixels.
    static func icon() -> CGImage {
        let c = PixelCanvas(width: 32, height: 32)
        c.fill(0, 0, 32, 32, .silver)
        c.bevel(0, 0, 32, 32, thickness: 2, topLeft: .white, bottomRight: .gray)
        drawFace(.smile, pressed: false, on: c, 3, 3)
        return c.makeImage()
    }

    // MARK: - Pieces

    private static func drawCounter(_ value: Int, on c: PixelCanvas, _ x: Int, _ y: Int, color: Bool) {
        c.bevel(x, y, 41, 25, thickness: 1, topLeft: .gray, bottomRight: .white)
        let v = min(max(value, -99), 999)
        let text = v < 0 ? "-" + String(format: "%02d", -v) : String(format: "%03d", v)
        let on: RGB = color ? .red : .white
        let off: RGB = color ? .maroon : .black
        for (k, ch) in text.enumerated() {
            Sprites.drawLED(ch, on: c, x + 1 + k * 13, y + 1, on: on, off: off)
        }
    }

    private static func drawFace(_ face: Face, pressed: Bool, on c: PixelCanvas, _ x: Int, _ y: Int) {
        c.fill(x, y, 26, 26, .gray)
        c.fill(x + 1, y + 1, 24, 24, .silver)
        let sprite: Sprite
        switch face {
        case .smile: sprite = Sprites.smile
        case .ooh: sprite = Sprites.ooh
        case .dead: sprite = Sprites.dead
        case .cool: sprite = Sprites.cool
        }
        if pressed {
            c.fill(x + 1, y + 1, 24, 1, .gray)
            c.fill(x + 1, y + 1, 1, 24, .gray)
            c.draw(sprite, x + 5, y + 5)
        } else {
            c.bevel(x + 1, y + 1, 24, 24, thickness: 2, topLeft: .white, bottomRight: .gray)
            c.draw(sprite, x + 4, y + 4)
        }
    }

    private static func drawSquare(_ i: Int, of game: Game, pressed: Bool, on c: PixelCanvas, _ x: Int, _ y: Int, color: Bool) {
        let cell = game.cells[i]

        func sunken(_ fill: RGB = .silver) {
            c.fill(x, y, 16, 16, fill)
            c.fill(x, y, 16, 1, .gray)
            c.fill(x, y, 1, 16, .gray)
        }
        func raised() {
            c.fill(x, y, 16, 16, .silver)
            c.bevel(x, y, 16, 16, thickness: 2, topLeft: .white, bottomRight: .gray)
        }
        func markGlyph() {
            switch cell.mark {
            case .flag: c.draw(Sprites.flag, x, y)
            case .question: c.draw(Sprites.question, x, y)
            case .none: break
            }
        }

        if cell.isOpen {
            sunken()
            if cell.adjacent > 0 {
                c.draw(Sprites.digits[cell.adjacent - 1], x + 3, y + 3,
                       ink: color ? .number(cell.adjacent) : .black)
            }
        } else if game.status == .lost && cell.isMine && cell.mark != .flag {
            sunken(game.exploded.contains(i) ? (color ? .red : .gray) : .silver)
            c.draw(Sprites.mine, x, y)
        } else if game.status == .lost && !cell.isMine && cell.mark == .flag {
            sunken()
            c.draw(Sprites.mine, x, y)
            c.draw(Sprites.cross, x, y, ink: color ? .red : .white)
        } else if pressed && cell.mark != .flag {
            sunken()
            if cell.mark == .question { c.draw(Sprites.question, x, y) }
        } else {
            raised()
            markGlyph()
        }
    }
}
