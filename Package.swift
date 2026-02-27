// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StravaBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "StravaBar",
            path: "Sources/StravaBar"
        )
    ]
)
