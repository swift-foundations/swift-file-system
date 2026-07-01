# swift-file-system

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

File system operations for Swift, exposing a `File` value type for reading, writing, scoped handles, atomic writes, and directory traversal with typed-throws error handling.

---

## Key Features

- **`File` value type** — A `Hashable`, `Sendable` reference to a path that exposes `read`, `write`, `stat`, and `open` accessors.
- **Typed throws end-to-end** — Each operation throws a specific error type (`File.System.Write.Atomic.Error`, `File.Directory.Contents.Error`, …); no `any Error` reaches the surface.
- **Zero-copy reads** — `read.full { span in … }` hands the closure a borrowed `Swift.Span<Byte>`, so decoding or checksumming needs no intermediate `[UInt8]` copy.
- **Crash-safe atomic writes** — `write.atomic(_:)` writes to a temporary file and renames it into place, so a process that dies mid-write never leaves a half-written file.
- **Async variants on a dedicated thread pool** — Read, write, create, and list each have an `async` form that runs the blocking syscall off the cooperative pool.
- **Directory traversal** — `File.Directory` provides entry listing, recursive walk, and glob matching over `files`, `directories`, and `entries`.

---

## Quick Start

```swift
import File_System

// Crash-safe configuration update: write to a temp file, then atomically
// rename it into place — readers never observe a partially written file.
let config = File(try File.Path("/etc/app/config.json"))
try config.write.atomic(#"{ "logLevel": "debug" }"#)

// Zero-copy read: the closure borrows the file's bytes directly, decoding
// without an intermediate [UInt8] allocation.
let logLevel = try config.read.full { bytes in
    String(decoding: bytes, as: UTF8.self)
}

// List a directory and act on regular files, preserving raw filename bytes.
let project = File.Directory(try File.Path("/Users/me/project"))
for entry in try project.entries() where entry.type == .file {
    print(String(lossy: entry.name))
}
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "File System", package: "swift-file-system")
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26.

---

## Architecture

Three library products. `File System` re-exports `File System Core`, so most consumers import only the umbrella.

| Product | Import | When to import |
|---------|--------|----------------|
| `File System` | `File_System` | Default. The full `File` / `File.Directory` API: sync and async read, write, open, and stat; directory creation, listing, recursive walk, glob, copy, move, and delete. |
| `File System Core` | `File_System_Core` | The synchronous `File.System.*` primitives and core value types (`File.Path`, `File.Directory.Entry`, error types) without the thread-pool-backed async surface or glob. |
| `File System Test Support` | `File_System_Test_Support` | Test targets exercising file-system code; provides fixtures and helpers built on `File System` and the kernel test support. |

---

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public flip.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).
</content>
</invoke>
