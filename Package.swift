// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DiskLEDPlus",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Software updater (SPUStandardUpdaterController in AppDelegate).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "DiskLEDPlus",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/DiskLEDPlus"
        )
    ]
)
