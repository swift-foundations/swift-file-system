// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-file-system",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
    ],
    products: [
        .library(name: "File System", targets: ["File System"]),
        .library(name: "File System Core", targets: ["File System Core"]),
        .library(name: "File System Test Support", targets: ["File System Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-compositions/swift-ascii.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-environment.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-kernel.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-paths.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-strings.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-io.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "main"),
        .package(
            url: "https://github.com/swift-molecules/swift-either.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-binary.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-span.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-glob.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-path.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-tagged.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4648.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "File System Core",
            dependencies: [
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Path", package: "swift-path"),
                .product(name: "Paths", package: "swift-paths"),
                .product(name: "Strings", package: "swift-strings"),
                .product(name: "Either", package: "swift-either"),
                .product(name: "Binary", package: "swift-binary"),
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "RFC 4648", package: "swift-rfc-4648"),
            ]
        ),
        .target(
            name: "File System",
            dependencies: [
                "File System Core",
                .product(name: "Glob", package: "swift-glob"),
                .product(name: "IO", package: "swift-io"),
                .product(name: "Span Raw", package: "swift-span"),
                .product(name: "Thread Pool", package: "swift-threads"),
                .product(name: "Thread Actor", package: "swift-threads"),
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
                .product(
                    name: "Tagged Standard Library Integration",
                    package: "swift-tagged"
                ),
            ]
        ),
        .testTarget(
            name: "File System Tests",
            dependencies: [
                "File System",
                "File System Test Support",
                .product(name: "Kernel", package: "swift-kernel"),
                .product(
                    name: "Tagged Standard Library Integration",
                    package: "swift-tagged"
                ),
            ]
        ),
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
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
