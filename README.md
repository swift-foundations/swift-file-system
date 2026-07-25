# swift-file-system

![CI](https://github.com/swift-foundations/swift-file-system/actions/workflows/ci.yml/badge.svg) ![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

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
    .package(url: "https://github.com/swift-foundations/swift-file-system.git", from: "0.6.0")
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

## Error Handling

The Quick Start's `write.atomic(_:)` throws a typed `File.System.Write.Atomic.Error`:

```
File.System.Write.Atomic.Error
├── .parentVerificationFailed          // parent directory verification or creation failed
├── .destinationStatFailed             // stat on the destination file failed
├── .tempFileCreationFailed            // temp file creation failed
├── .writeFailed                       // write operation failed (reports bytesWritten/bytesExpected)
├── .syncFailed                        // fsync/flush of the temp file failed
├── .closeFailed                       // closing the temp file failed
├── .metadataPreservationFailed        // preserving owner/mode/xattrs failed
├── .timestampPreservationFailed       // futimens timestamp preservation failed
├── .renameFailed                      // the atomic rename into place failed
├── .destinationExists                 // destination already exists (noClobber mode)
├── .directorySyncFailed               // directory sync failed before commit completed
├── .directorySyncFailedAfterCommit    // rename succeeded but directory sync failed — durability compromised
├── .randomGenerationFailed            // CSPRNG failed; cannot generate secure temp file names
├── .platformIncompatible              // platform struct-layout incompatibility at runtime
└── .invalidPath                       // input path failed validation (wraps Paths.Path.Error)
```

```swift
do {
    let config = File(try File.Path("/etc/app/config.json"))
    try config.write.atomic(#"{ "logLevel": "debug" }"#)
} catch .parentVerificationFailed {
} catch .destinationStatFailed {
} catch .tempFileCreationFailed {
} catch .writeFailed {
} catch .syncFailed {
} catch .closeFailed {
} catch .metadataPreservationFailed {
} catch .timestampPreservationFailed {
} catch .renameFailed {
} catch .destinationExists {
    // another writer beat us to it in noClobber mode
} catch .directorySyncFailed {
} catch .directorySyncFailedAfterCommit {
    // file is complete on disk, but durability is not guaranteed — do not retry
} catch .randomGenerationFailed {
} catch .platformIncompatible {
} catch .invalidPath {
    // the path string could not be validated as a File.Path
}
```

Other file-system operations expose their own typed errors with the same exhaustive shape — for example `write.append(_:)` throws `File.System.Write.Append.Error`, directory listing throws `File.Directory.Contents.Error`, and delete throws `File.System.Delete.Error`.

---

## Community

<!-- BEGIN: discussion -->
*A discussion thread will open with the first tagged release.*
<!-- END: discussion -->

## Status & maintainer

This package is public alpha (pre-1.0): interfaces are stabilizing and APIs may change between minor versions.

Maintained by [Coen ten Thije Boonkkamp](https://github.com/coenttb) — available for Swift infrastructure and document-systems consulting: coen@coenttb.com.

## License

Apache 2.0. See [LICENSE](LICENSE.md).
