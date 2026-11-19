// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Odo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Odo",
            path: "Sources/Odo"
        )
    ]
)
