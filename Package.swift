// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-file-system",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "File System", targets: ["File System"]),
        .library(name: "File System Core", targets: ["File System Core"]),
        .library(name: "File System Test Support", targets: ["File System Test Support"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-ascii.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-environment.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-kernel.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-paths.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-strings.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-io.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-threads.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-either-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-binary-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-glob-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-path-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4648.git", branch: "main")
    ],
    targets: [
        .target(
            name: "File System Core",
            dependencies: [
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Path Primitives", package: "swift-path-primitives"),
                .product(name: "Paths", package: "swift-paths"),
                .product(name: "Strings", package: "swift-strings"),
                .product(name: "Either Primitives", package: "swift-either-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "RFC 4648", package: "swift-rfc-4648")
            ]
        ),
        .target(
            name: "File System",
            dependencies: [
                "File System Core",
                .product(name: "Glob Primitives", package: "swift-glob-primitives"),
                .product(name: "IO", package: "swift-io"),
                .product(name: "Span Raw Primitives", package: "swift-span-primitives"),
                .product(name: "Thread Pool", package: "swift-threads"),
                .product(name: "Thread Actor", package: "swift-threads")
            ]
        ),
        .target(
            name: "File System Test Support",
            dependencies: [
                "File System Core",
                "File System",
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Kernel Test Support", package: "swift-kernel"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "File System Core Tests",
            dependencies: [
                "File System Core",
                "File System Test Support",
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives")
            ]
        ),
        .testTarget(
            name: "File System Tests",
            dependencies: [
                "File System",
                "File System Test Support",
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
