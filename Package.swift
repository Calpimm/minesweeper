// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Minefield",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Minefield", path: "Sources/Minefield")
    ]
)
