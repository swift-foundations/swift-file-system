// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-file-system",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        // Only File System is public; Primitives and Async are internal
        .library(name: "File System", targets: ["File System"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/swift-standards/swift-standards", from: "0.19.4"),
        .package(url: "https://github.com/swift-standards/swift-incits-4-1986", from: "0.7.1"),
        .package(url: "https://github.com/swift-standards/swift-rfc-4648", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "CFileSystemShims",
            path: "Sources/CFileSystemShims",
            publicHeadersPath: "include"
        ),
        .target(
            name: "File System Primitives",
            dependencies: [
                "CFileSystemShims",
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "Binary", package: "swift-standards"),
                .product(name: "StandardTime", package: "swift-standards"),
                .product(name: "INCITS 4 1986", package: "swift-incits-4-1986"),
                .product(name: "RFC 4648", package: "swift-rfc-4648"),
            ],
            path: "Sources/File System Primitives"
        ),
        .target(
            name: "File System",
            dependencies: [
                "File System Primitives",
                "File System Async",
            ],
            path: "Sources/File System"
        ),
        .testTarget(
            name: "File System Primitives Tests",
            dependencies: [
                "File System Primitives",
                .product(name: "StandardsTestSupport", package: "swift-standards"),
            ],
            path: "Tests/File System Primitives Tests"
        ),
        .testTarget(
            name: "File System Tests",
            dependencies: [
                "File System",
                .product(name: "StandardsTestSupport", package: "swift-standards"),
            ],
            path: "Tests/File System Tests"
        ),
        .target(
            name: "File System Async",
            dependencies: [
                "File System Primitives",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "Sources/File System Async"
        ),
        .testTarget(
            name: "File System Async Tests",
            dependencies: [
                "File System Async",
                "File System",
                .product(name: "StandardsTestSupport", package: "swift-standards"),
            ],
            path: "Tests/File System Async Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let existing = target.swiftSettings ?? []
    target.swiftSettings = existing + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
}
