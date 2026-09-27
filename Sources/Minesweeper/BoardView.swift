import AppKit

@MainActor
protocol BoardViewDelegate: AnyObject {
    func boardReveal(_ square: Int)
    func boardChord(_ square: Int)
    func boardMark(_ square: Int)
    func boardNewGame()
}

/// Draws the game at an integer zoom with hard pixel edges and reproduces
/// the original mouse handling:
/// - left press sinks the square, release opens it
/// - right press cycles flag / ? immediately
/// - both buttons, the middle button or ⌥-click sink the 3×3 block and
///   "chord" on release
final class BoardView: NSView {
    weak var delegate: BoardViewDelegate?

    var game: Game! {
        didSet { resetInput(); needsDisplay = true }
    }
    var zoom = 2 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var color = true {
        didSet { needsDisplay = true }
    }

    private var leftDown = false
    private var rightDown = false
    private var middleDown = false
    private var controlClick = false
    private var chording = false
    /// Set after a chord while a button is still held: that release does nothing.
    private var spent = false
    private var hover: Int?
    private var trackingFace = false
    private var faceHot = false

    private var layout: Layout { Layout(cols: game.width, rows: game.height) }

    override var intrinsicContentSize: NSSize {
        guard game != nil else { return .zero }
        return NSSize(width: layout.width * zoom, height: layout.height * zoom)
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let game, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let image = Renderer.render(game, pressed: pressedSquares(), face: face(),
                                    facePressed: trackingFace && faceHot, color: color)
        ctx.interpolationQuality = .none
        ctx.draw(image, in: bounds)
    }

    private func pressedSquares() -> Set<Int> {
        guard game.isActive, let hover, leftDown || middleDown || chording else { return [] }
        let candidates = chording ? [hover] + game.neighbors(of: hover) : [hover]
        return Set(candidates.filter { !game.cells[$0].isOpen && game.cells[$0].mark != .flag })
    }

    private func face() -> Face {
        switch game.status {
        case .won: return .cool
        case .lost: return .dead
        default: return (leftDown || chording) && !spent ? .ooh : .smile
        }
    }

    // MARK: - Mouse

    private func pixel(_ event: NSEvent) -> (x: Int, y: Int) {
        let p = convert(event.locationInWindow, from: nil)
        let z = CGFloat(zoom)
        return (Int((p.x / z).rounded(.down)), Int(((bounds.height - p.y) / z).rounded(.down)))
    }

    private func square(_ event: NSEvent) -> Int? {
        let p = pixel(event)
        return layout.square(atX: p.x, y: p.y)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            controlClick = true
            rightMouseDown(with: event)
            return
        }
        let p = pixel(event)
        if layout.faceContains(p.x, p.y) {
            trackingFace = true
            faceHot = true
        } else if game.isActive {
            leftDown = true
            chording = chording || rightDown || event.modifierFlags.contains(.option)
            hover = square(event)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if controlClick { return rightMouseDragged(with: event) }
        if trackingFace {
            let p = pixel(event)
            faceHot = layout.faceContains(p.x, p.y)
        } else {
            hover = square(event)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if controlClick {
            controlClick = false
            return rightMouseUp(with: event)
        }
        if trackingFace {
            trackingFace = false
            if faceHot { delegate?.boardNewGame() }
            faceHot = false
            needsDisplay = true
            return
        }
        guard leftDown else { return }
        leftDown = false
        released(primary: true)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard game.isActive, !trackingFace else { return }
        rightDown = true
        hover = square(event)
        if leftDown || middleDown {
            chording = true
        } else if let hover {
            delegate?.boardMark(hover)
        }
        needsDisplay = true
    }

    override func rightMouseDragged(with event: NSEvent) {
        hover = square(event)
        needsDisplay = true
    }

    override func rightMouseUp(with event: NSEvent) {
        guard rightDown else { return }
        rightDown = false
        released(primary: false)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2, game.isActive, !trackingFace else { return }
        middleDown = true
        chording = true
        hover = square(event)
        needsDisplay = true
    }

    override func otherMouseDragged(with event: NSEvent) {
        hover = square(event)
        needsDisplay = true
    }

    override func otherMouseUp(with event: NSEvent) {
        guard middleDown else { return }
        middleDown = false
        released(primary: false)
    }

    private func released(primary: Bool) {
        let target = hover
        let anyHeld = leftDown || rightDown || middleDown
        if chording {
            chording = false
            spent = anyHeld
            if let target { delegate?.boardChord(target) }
        } else if primary, !spent, let target {
            delegate?.boardReveal(target)
        }
        if !anyHeld {
            spent = false
            hover = nil
        }
        needsDisplay = true
    }

    private func resetInput() {
        leftDown = false; rightDown = false; middleDown = false; controlClick = false
        chording = false; spent = false; hover = nil
        trackingFace = false; faceHot = false
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.specialKey == .f2 { delegate?.boardNewGame() } else { super.keyDown(with: event) }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "n" {
            delegate?.boardNewGame()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
