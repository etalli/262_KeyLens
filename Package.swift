// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyLens",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "KeyLensCore",
            path: "Sources/KeyLensCore"
        ),
        .executableTarget(
            name: "KeyLens",
            dependencies: ["KeyLensCore"],
            path: "Sources/KeyLens",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "KeyLensTests",
            dependencies: ["KeyLensCore"],
            path: "Tests/KeyLensTests"
        ),
    ]
)
