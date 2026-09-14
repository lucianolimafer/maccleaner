// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "MacCleaner", targets: ["MacCleaner"])],
    targets: [
        .target(
            name: "MacCleanerCore",
            path: "App/Core"
        ),
        .executableTarget(
            name: "MacCleaner",
            dependencies: ["MacCleanerCore"],
            path: "App/MacCleaner"
        ),
        .testTarget(
            name: "MacCleanerCoreTests",
            dependencies: ["MacCleanerCore"],
            path: "Tests/MacCleanerCoreTests"
        ),
        .testTarget(
            name: "MacCleanerTests",
            dependencies: ["MacCleaner", "MacCleanerCore"],
            path: "Tests/MacCleanerTests"
        )
    ]
)
