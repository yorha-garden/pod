// swift-tools-version: 6.0
import PackageDescription

// PodKit holds every behaviour worth testing; the Pod executable is a thin
// entry point so the logic stays reachable from the test target.
let package = Package(
    name: "Pod",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PodKit", targets: ["PodKit"]),
        .executable(name: "Pod", targets: ["Pod"]),
    ],
    targets: [
        .target(
            name: "PodKit",
            path: "Sources/PodKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Pod",
            dependencies: ["PodKit"],
            path: "Sources/Pod",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PodKitTests",
            dependencies: ["PodKit"],
            path: "Tests/PodKitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
