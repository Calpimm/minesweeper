import SwiftUI

/// Visual identity: a grassy field you dig into. Hidden tiles are turf,
/// opened tiles are dug-up soil.
enum Palette {
    static let window     = Color(hex: 0x2E4428)   // deep hedge green
    static let boardBack  = Color(hex: 0x223320)
    static let turfTop    = Color(hex: 0x9CCB6B)
    static let turfBottom = Color(hex: 0x6FA84B)
    static let soil       = Color(hex: 0xE8D6AE)
    static let soilEdge   = Color(hex: 0xD2BD8E)
    static let explode    = Color(hex: 0xE5533D)
    static let flag       = Color(hex: 0xF08A24)
    static let ink        = Color(hex: 0x2A2A26)
    static let chip       = Color(hex: 0x3B5634)

    static func number(_ n: Int) -> Color {
        switch n {
        case 1: return Color(hex: 0x2F6BD8)
        case 2: return Color(hex: 0x2D8A4E)
        case 3: return Color(hex: 0xD8412F)
        case 4: return Color(hex: 0x5B3DB0)
        case 5: return Color(hex: 0x9A4A1C)
        case 6: return Color(hex: 0x178C8A)
        case 7: return Color(hex: 0x2A2A26)
        default: return Color(hex: 0x6E6A60)
        }
    }
}

enum Tile {
    static let size: CGFloat = 28
    static let gap: CGFloat = 2
    static let radius: CGFloat = 5
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
