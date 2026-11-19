// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Odo",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Same Sparkle line as Cargo; the CI downloads the matching tools (sign_update)
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.8.1"),
    ],
    targets: [
        .executableTarget(
            name: "Odo",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Odo",
            linkerSettings: [
                // Sparkle.framework is embedded in Odo.app/Contents/Frameworks
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
    ]
)
