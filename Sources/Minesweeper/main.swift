import AppKit

// `Minesweeper --export-iconset <dir>` writes the app icon for the build script.
if let flag = CommandLine.arguments.firstIndex(of: "--export-iconset"), flag + 1 < CommandLine.arguments.count {
    let dir = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let art = Renderer.icon()
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let px = points * scale
            let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            // Keep hard pixel edges wherever the art is scaled up.
            ctx.interpolationQuality = px >= art.width ? .none : .high
            ctx.draw(art, in: CGRect(x: 0, y: 0, width: px, height: px))
            let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
            let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            try png.write(to: dir.appendingPathComponent(name))
        }
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let controller = AppController()
    app.delegate = controller
    app.setActivationPolicy(.regular)
    app.run()
}
