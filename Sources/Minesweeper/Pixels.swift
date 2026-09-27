import CoreGraphics
import Foundation

struct RGB: Equatable {
    let r, g, b: UInt8

    init(_ hex: UInt32) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
    }

    /// The 16-colour VGA palette the original was drawn with.
    static let white = RGB(0xFFFFFF)
    static let silver = RGB(0xC0C0C0)
    static let gray = RGB(0x808080)
    static let black = RGB(0x000000)
    static let red = RGB(0xFF0000)
    static let maroon = RGB(0x800000)
    static let yellow = RGB(0xFFFF00)

    static func number(_ n: Int) -> RGB {
        switch n {
        case 1: return RGB(0x0000FF)
        case 2: return RGB(0x008000)
        case 3: return RGB(0xFF0000)
        case 4: return RGB(0x000080)
        case 5: return RGB(0x800000)
        case 6: return RGB(0x008080)
        case 7: return RGB(0x000000)
        default: return RGB(0x808080)
        }
    }

    /// "Color" turned off: snap to black, gray, silver or white.
    var monochrome: RGB {
        if self == .red { return .black }   // flags
        let lum = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
        let levels: [UInt32] = [0x00, 0x80, 0xC0, 0xFF]
        let v = levels.min { abs(Double($0) - lum) < abs(Double($1) - lum) }!
        return RGB(v << 16 | v << 8 | v)
    }
}

/// Pixel art as text. `.` is transparent, `#` takes the ink passed to `draw`.
struct Sprite {
    let width: Int
    let height: Int
    fileprivate let pixels: [Character]

    init(_ rows: [String]) {
        width = rows[0].count
        height = rows.count
        precondition(rows.allSatisfy { $0.count == rows[0].count }, "ragged sprite")
        pixels = rows.flatMap { Array($0) }
    }

    fileprivate static func color(_ c: Character, ink: RGB) -> RGB? {
        switch c {
        case "w": return .white
        case "s": return .silver
        case "g": return .gray
        case "k": return .black
        case "r": return .red
        case "y": return .yellow
        case "#": return ink
        default: return nil
        }
    }
}

final class PixelCanvas {
    let width: Int
    let height: Int
    private var bytes: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        bytes = Array(repeating: 0, count: width * height * 4)
    }

    func put(_ x: Int, _ y: Int, _ c: RGB) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let o = (y * width + x) * 4
        bytes[o] = c.r
        bytes[o + 1] = c.g
        bytes[o + 2] = c.b
        bytes[o + 3] = 255
    }

    func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: RGB) {
        for yy in y..<(y + h) { for xx in x..<(x + w) { put(xx, yy, c) } }
    }

    /// A Windows 3D edge: `topLeft` on the top/left, `bottomRight` on the
    /// bottom/right, meeting diagonally in the corners.
    func bevel(_ x: Int, _ y: Int, _ w: Int, _ h: Int, thickness: Int, topLeft: RGB, bottomRight: RGB) {
        for i in 0..<thickness {
            fill(x, y + i, w - i, 1, topLeft)
            fill(x + i, y, 1, h - i, topLeft)
            fill(x + i + 1, y + h - 1 - i, w - i - 1, 1, bottomRight)
            fill(x + w - 1 - i, y + i + 1, 1, h - i - 1, bottomRight)
        }
    }

    func draw(_ s: Sprite, _ x: Int, _ y: Int, ink: RGB = .black) {
        for sy in 0..<s.height {
            for sx in 0..<s.width {
                if let c = Sprite.color(s.pixels[sy * s.width + sx], ink: ink) { put(x + sx, y + sy, c) }
            }
        }
    }

    func makeImage(monochrome: Bool = false) -> CGImage {
        var out = bytes
        if monochrome {
            for o in stride(from: 0, to: out.count, by: 4) {
                let m = RGB(UInt32(out[o]) << 16 | UInt32(out[o + 1]) << 8 | UInt32(out[o + 2])).monochrome
                out[o] = m.r; out[o + 1] = m.g; out[o + 2] = m.b
            }
        }
        let provider = CGDataProvider(data: Data(out) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}
