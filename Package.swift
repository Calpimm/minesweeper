// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Minesweeper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Minesweeper", path: "Sources/Minesweeper"),
        .testTarget(name: "MinesweeperTests", dependencies: ["Minesweeper"], path: "Tests/MinesweeperTests"),
    ]
)
