/// Hand-drawn pixel art matching the original bitmaps.
/// Square glyphs are 16×16 and drawn on top of a tile; faces are 17×17.
enum Sprites {
    static let mine = Sprite([
        "................",
        "................",
        "........k.......",
        "........k.......",
        "....k.kkkkk.k...",
        ".....kkkkkkk....",
        "....kkwwkkkkk...",
        "....kkwwkkkkk...",
        "..kkkkkkkkkkkkk.",
        "....kkkkkkkkk...",
        "....kkkkkkkkk...",
        ".....kkkkkkk....",
        "....k.kkkkk.k...",
        "........k.......",
        "........k.......",
        "................",
    ])

    static let flag = Sprite([
        "................",
        "................",
        "................",
        ".......rr.......",
        ".....rrrr.......",
        "....rrrrr.......",
        ".....rrrr.......",
        ".......rr.......",
        "........k.......",
        "........k.......",
        "......kkkk......",
        "....kkkkkkkk....",
        "....kkkkkkkk....",
        "................",
        "................",
        "................",
    ])

    static let question = Sprite([
        "................",
        "................",
        "................",
        "......kkkk......",
        ".....kk..kk.....",
        ".....kk..kk.....",
        ".........kk.....",
        "........kk......",
        ".......kk.......",
        ".......kk.......",
        "................",
        ".......kk.......",
        ".......kk.......",
        "................",
        "................",
        "................",
    ])

    /// Red cross drawn over a mine that was wrongly flagged.
    static let cross = Sprite([
        "................",
        "................",
        "................",
        "................",
        "....##......##..",
        ".....##....##...",
        "......##..##....",
        ".......####.....",
        "........##......",
        ".......####.....",
        "......##..##....",
        ".....##....##...",
        "....##......##..",
        "................",
        "................",
        "................",
    ])

    /// Digits 1–8, drawn at (3, 3) inside a square.
    static let digits: [Sprite] = [
        Sprite([
            "....###...",
            "...####...",
            "..#####...",
            "....###...",
            "....###...",
            "....###...",
            "....###...",
            "....###...",
            "..#######.",
            "..#######.",
        ]),
        Sprite([
            ".#######..",
            "###...###.",
            "......###.",
            ".....###..",
            "....###...",
            "...###....",
            "..###.....",
            ".###......",
            "#########.",
            "#########.",
        ]),
        Sprite([
            "########..",
            "########..",
            "......###.",
            "......###.",
            "..######..",
            "..######..",
            "......###.",
            "......###.",
            "########..",
            "########..",
        ]),
        Sprite([
            "...###....",
            "...###....",
            "..###.....",
            "..###.###.",
            ".###..###.",
            "##########",
            "##########",
            "......###.",
            "......###.",
            "......###.",
        ]),
        Sprite([
            "#########.",
            "#########.",
            "###.......",
            "###.......",
            "########..",
            "########..",
            "......###.",
            "......###.",
            "########..",
            "########..",
        ]),
        Sprite([
            "..######..",
            ".###......",
            "###.......",
            "###.......",
            "########..",
            "#########.",
            "###...###.",
            "###...###.",
            "#########.",
            ".#######..",
        ]),
        Sprite([
            "##########",
            "##########",
            "......###.",
            ".....###..",
            ".....###..",
            "....###...",
            "....###...",
            "...###....",
            "...###....",
            "...###....",
        ]),
        Sprite([
            ".#######..",
            "###...###.",
            "###...###.",
            "###...###.",
            ".#######..",
            "###...###.",
            "###...###.",
            "###...###.",
            "###...###.",
            ".#######..",
        ]),
    ]

    // MARK: - Faces

    static let smile = Sprite([
        "......kkkkk......",
        "....kkyyyyykk....",
        "...kyyyyyyyyyk...",
        "..kyyyyyyyyyyyk..",
        ".kyyyyyyyyyyyyyk.",
        ".kyyykkyyykkyyyk.",
        "kyyyykkyyykkyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyykyyyyyyykyyyk",
        ".kyyykyyyyykyyyk.",
        ".kyyyykkkkkyyyyk.",
        "..kyyyyyyyyyyyk..",
        "...kyyyyyyyyyk...",
        "....kkyyyyykk....",
        "......kkkkk......",
    ])

    static let ooh = Sprite([
        "......kkkkk......",
        "....kkyyyyykk....",
        "...kyyyyyyyyyk...",
        "..kyyyyyyyyyyyk..",
        ".kyyyyyyyyyyyyyk.",
        ".kyyykkyyykkyyyk.",
        "kyyyykkyyykkyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyyykkkyyyyyyk",
        "kyyyyykyyykyyyyyk",
        ".kyyyykyyykyyyyk.",
        ".kyyyyykkkyyyyyk.",
        "..kyyyyyyyyyyyk..",
        "...kyyyyyyyyyk...",
        "....kkyyyyykk....",
        "......kkkkk......",
    ])

    static let dead = Sprite([
        "......kkkkk......",
        "....kkyyyyykk....",
        "...kyyyyyyyyyk...",
        "..kyyyyyyyyyyyk..",
        ".kyykykyyykykyyk.",
        ".kyyykyyyyykyyyk.",
        "kyyykykyyykykyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyykkkkkyyyyyk",
        ".kyyykyyyyykyyyk.",
        ".kyykyyyyyyykyyk.",
        "..kyyyyyyyyyyyk..",
        "...kyyyyyyyyyk...",
        "....kkyyyyykk....",
        "......kkkkk......",
    ])

    static let cool = Sprite([
        "......kkkkk......",
        "....kkyyyyykk....",
        "...kyyyyyyyyyk...",
        "..kyyyyyyyyyyyk..",
        ".kyyyyyyyyyyyyyk.",
        ".kkkkkkkkkkkkkkk.",
        "kyykkkkkykkkkkyyk",
        "kyyykkkyyykkkyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyyyyyyyyyyyyyyk",
        "kyyykyyyyyyykyyyk",
        ".kyyykyyyyykyyyk.",
        ".kyyyykkkkkyyyyk.",
        "..kyyyyyyyyyyyk..",
        "...kyyyyyyyyyk...",
        "....kkyyyyykk....",
        "......kkkkk......",
    ])

    // MARK: - Seven-segment LED (13×23 per digit)

    /// Pixel runs for segments a–g: (isHorizontal, fixed coordinate, from, to).
    private static let segments: [[(Bool, Int, Int, Int)]] = [
        [(true, 1, 2, 10), (true, 2, 3, 9)],       // a  top
        [(false, 11, 2, 10), (false, 10, 3, 9)],   // b  top right
        [(false, 11, 12, 20), (false, 10, 13, 19)], // c  bottom right
        [(true, 21, 2, 10), (true, 20, 3, 9)],     // d  bottom
        [(false, 1, 12, 20), (false, 2, 13, 19)],  // e  bottom left
        [(false, 1, 2, 10), (false, 2, 3, 9)],     // f  top left
        [(true, 10, 4, 8), (true, 11, 3, 9), (true, 12, 4, 8)], // g  middle
    ]

    private static let litSegments: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g",
    ]

    static func drawLED(_ ch: Character, on canvas: PixelCanvas, _ x: Int, _ y: Int, on: RGB, off: RGB) {
        canvas.fill(x, y, 13, 23, .black)
        let lit = litSegments[ch] ?? ""
        for (index, runs) in segments.enumerated() {
            let name = Character(UnicodeScalar(UInt8(ascii: "a") + UInt8(index)))
            let color = lit.contains(name) ? on : off
            for (horizontal, fixed, from, to) in runs {
                for v in from...to {
                    if horizontal { canvas.put(x + v, y + fixed, color) } else { canvas.put(x + fixed, y + v, color) }
                }
            }
        }
    }
}
