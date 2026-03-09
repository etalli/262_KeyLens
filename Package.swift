// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyLens",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "KeyLensCore",
            path: "Sources/KeyLensCore"
        ),
        .executableTarget(
            name: "KeyLens",
            dependencies: [
                "KeyLensCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
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
