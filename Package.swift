// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DiskLEDPlus",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DiskLEDPlus",
            path: "Sources/DiskLEDPlus"
        )
    ]
)
