# swift-file-system

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Type-safe file system operations for Swift with kernel-assisted I/O and async streaming. APFS clones, pull-based batched directory iteration, and configurable durability. Swift 6 strict concurrency with actor-based I/O executor.

## Table of Contents

- [Why swift-file-system?](#why-swift-file-system)
- [Overview](#overview)
- [Design Guarantees](#design-guarantees)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [Performance](#performance)
- [Architecture](#architecture)
- [Platform Support](#platform-support)
- [Non-goals](#non-goals)
- [Testing](#testing)
- [Related Packages](#related-packages)
- [Contributing](#contributing)
- [License](#license)

## Why swift-file-system?

Foundation's `FileManager` and `URL` APIs are designed for simplicity, not performance or async correctness. This library exists to solve problems Foundation cannot:

| Problem | Foundation | swift-file-system |
|---------|------------|-------------------|
| **Async iteration** | Blocks thread per entry | Pull-based batching (~0.6ms per 1000 files) |
| **File copy** | Always reads+writes bytes | APFS clone, kernel-assisted paths (~7.5ms for 1MB) |
| **Durability control** | No control over fsync | `.full`, `.dataOnly`, `.none` modes |
| **Thread pool starvation** | Blocking I/O starves cooperative pool | Dedicated executor option isolates I/O |
| **Concurrency safety** | Requires manual synchronization | `Sendable` throughout, actor-isolated state |
| **Symlink handling** | Implicit, inconsistent | Explicit `followSymlinks` option everywhere |

If you need predictable async behavior, kernel-level optimizations, or fine-grained durability control, this library provides what Foundation cannot.

## Overview

swift-file-system provides a modern Swift interface for file system operations with focus on performance, safety, and async-first design. Built on POSIX and Windows APIs with platform-specific optimizations like APFS cloning on macOS and `copy_file_range`/`sendfile` on Linux.

## Design Guarantees

### What this library guarantees

- **Atomic writes**: Write-sync-rename pattern ensures no partial writes on crash (when durability is `.full` or `.dataOnly`)
- **Bounded memory**: Async executor queue is bounded; backpressure suspends callers when full
- **Fallback correctness**: Copy operations try fast paths first, fall back gracefully to manual loop
- **No data races**: Full Swift 6 strict concurrency compliance with `Sendable` types throughout
- **Graceful shutdown**: In-flight operations complete; pending operations fail with explicit error

### What this library does NOT guarantee

- **Cross-process consistency**: No file locking primitives (yet); concurrent access from multiple processes requires external coordination
- **Path normalization**: `File.Path` validates structure (no NUL bytes, no empty components) but does not resolve `..`, symlinks, or canonicalize case
- **Windows path semantics**: UNC paths (`\\server\share`) and drive-relative paths (`C:foo`) are not fully validated
- **Security sandbox**: This is not a security boundary; path traversal prevention is best-effort, not hardened

Use `File.Path` for structured path manipulation, but do not rely on it as a security mechanism.

## Features

- **Kernel-assisted file copy**: APFS cloning, `copyfile()` on Darwin, `copy_file_range`/`sendfile` on Linux (~7.5ms for 1MB)
- **Batched directory iteration**: Pull-based async with configurable batch sizes (~0.6ms per 1000 files)
- **Async streaming**: `AsyncSequence` for file bytes, directory entries, and recursive walks
- **Atomic writes**: Crash-safe write-sync-rename pattern with configurable durability modes
- **Dedicated I/O executor**: Actor-based thread pool that doesn't starve Swift's cooperative pool
- **Validated paths**: `File.Path` rejects NUL bytes, empty components, and embedded newlines
- **Swift 6 strict concurrency**: Full `Sendable` compliance, no data races
- **Cross-platform**: macOS, iOS, Linux, and Windows support

## Installation

Add swift-file-system to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-file-system.git", from: "0.1.0")
]
```

Add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "File System", package: "swift-file-system"),
    ]
)
```

### Requirements

- Swift 6.2+
- macOS 26.0+, iOS 26.0+, or Linux
- Xcode 26.0+ (for Apple platforms)

## Quick Start

### File Operations

```swift
import File_System

// Create a file reference
let file: File = "/tmp/data.txt"

// Read and write
let data = try file.read()                    // sync
let data = try await file.read()              // async

try file.write("Hello, World!")               // sync
try await file.write("Hello, World!")         // async

// Append
try file.append(" More content")

// Check properties
if file.exists && file.isFile {
    print("Size: \(try file.size)")
    print("Empty: \(try file.isEmpty)")
}

// File operations
try file.copy(to: otherFile)
try file.move(to: newLocation)
try file.delete()
```

### Low-Level Handle Access

```swift
// Scoped handle access with automatic cleanup
try file.open { handle in
    let chunk = try handle.read(count: 1024)
}

try file.open.write { handle in
    try handle.write(bytes)
}

// Static API works too
try File.open(path).readWrite { handle in
    try handle.seek(to: 100)
    try handle.write(data)
}
```

### Directory Operations

```swift
let dir: File.Directory = "/tmp/mydir"

// Create and delete
try dir.create(withIntermediates: true)
try dir.delete(recursive: true)

// Contents
for entry in try dir.contents() {
    print(entry.name)
}

// Subscript access
let readme = dir[file: "README.md"]
let subdir = dir[directory: "src"]

// Async iteration (batched, 48x faster)
for try await entry in File.Directory.entries(at: dir.path) {
    print(entry.name)
}

// Recursive walk
for entry in try File.Directory.Walk(at: dir.path) {
    print("\(entry.depth): \(entry.path)")
}
```

### Sync and Async - Same API

The same method names work for both sync and async - Swift picks based on context:

```swift
// Convenience API
let data = try file.read()              // sync
let data = try await file.read()        // async

// Primitive API (for advanced options)
try File.System.Write.Atomic.write(data, to: path, options: .init(durability: .full))
try await File.System.Write.Atomic.write(data, to: path, options: .init(durability: .full))
```

### Streaming Bytes

```swift
// Async byte streaming with backpressure
for try await chunk in File.Stream.bytes(from: path) {
    process(chunk)
}
```

## Usage Examples

### Basic File Operations

```swift
let file: File = "/tmp/config.json"

// Simple read/write (uses safe defaults)
try file.write(jsonString)
let content = try file.readString()

// Copy and move
let backup = File("/tmp/config.backup.json")
try file.copy(to: backup)
try file.move(to: File("/tmp/new-location.json"))
```

### Advanced Write Options (Durability)

Use the primitive API when you need fine-grained control:

```swift
// Full durability (F_FULLFSYNC on Darwin, fsync on Linux)
try File.System.Write.Atomic.write(
    data,
    to: path,
    options: .init(durability: .full)
)

// Data-only sync (faster, metadata may be stale after crash)
try File.System.Write.Atomic.write(
    data,
    to: path,
    options: .init(durability: .dataOnly)
)

// No sync (fastest, for temporary files)
try File.System.Write.Atomic.write(
    data,
    to: path,
    options: .init(durability: .none)
)
```

### Advanced Copy Options

```swift
// Copy with attributes (permissions, timestamps)
try File.System.Copy.copy(
    from: source,
    to: destination,
    options: .init(copyAttributes: true, overwrite: true)
)

// Handle symlinks explicitly
try File.System.Copy.copy(
    from: source,
    to: destination,
    options: .init(followSymlinks: false)  // Copy symlink itself
)
```

### Directory Operations

```swift
let projectDir: File.Directory = "/Users/me/project"

// Create directory structure
try projectDir.create(withIntermediates: true)
let srcDir = projectDir[directory: "src"]
try srcDir.create()

// List contents
let files = try projectDir.files()
let subdirs = try projectDir.subdirectories()

// Check if empty
if try projectDir.isEmpty {
    try projectDir.delete()
}

// Copy/move directories
try projectDir.copy(to: File.Directory("/tmp/backup"))
try projectDir.move(to: File.Directory("/Users/me/new-project"))
```

### Directory Traversal with Filtering

```swift
// Walk with options
let options = File.Directory.Walk.Options(
    followSymlinks: false,
    skipHidden: true,
    maxDepth: 5
)

for entry in try File.Directory.Walk(at: rootPath, options: options) {
    if entry.type == .regular && entry.name.hasSuffix(".swift") {
        print("Found Swift file: \(entry.path)")
    }
}
```

### Custom Executor (Advanced)

```swift
// For heavy I/O, use a dedicated executor to avoid starving the cooperative pool
let io = File.IO.Executor(.init(workers: 4, threadModel: .dedicated))

// Pass custom executor to any operation
let data = try await File.System.Read.Full.read(from: path, io: io)
for try await entry in File.Directory.entries(at: path, io: io) { ... }

// Explicit executors must be shut down when done
await io.shutdown()
```

## Performance

Benchmarks from `swift test -c release` on Apple Silicon.

### File Operations

| Operation | Median | Throughput | Notes |
|-----------|--------|------------|-------|
| Read 1MB | 5.94ms | ~168 MB/s | `File.System.Read.Full.read` |
| Write 1MB (atomic) | 6.03ms | ~166 MB/s | Write-sync-rename pattern |
| Write 1MB (direct) | 1.87ms | ~535 MB/s | No atomicity guarantees |
| Copy 1MB | 7.51ms | ~133 MB/s | APFS clone or kernel-assisted |
| Read 10MB | 17.80ms | ~562 MB/s | Large file throughput |
| Write 10MB | 17.01ms | ~588 MB/s | Large file throughput |

### Directory Iteration

Measured with 1000 files × 100 loops (100,000 total iterations):

| Approach | Total Time | Per 1000 Files | Notes |
|----------|------------|----------------|-------|
| Sync iterator | 32.90ms | 0.33ms | Blocking, fastest |
| Async batch 64 | 78.00ms | 0.78ms | Pull-based batching |
| Async batch 128 | 57.34ms | 0.57ms | Optimal batch size |
| Async batch 256 | 63.77ms | 0.64ms | Diminishing returns |

Async iteration trades ~1.7x overhead for non-blocking execution. The batching architecture reduces executor hops from N to N/batch_size, avoiding cooperative pool starvation.

### Streaming

| Operation | Median | Notes |
|-----------|--------|-------|
| Stream 1MB (64KB chunks) | 14.20ms | `AsyncSequence` with backpressure |
| Stream 1MB (4KB chunks) | 17.22ms | Smaller chunks, more overhead |
| Early termination | 16.29ms | Clean resource cleanup on break |

### Executor Performance

| Operation | Median | Notes |
|-----------|--------|-------|
| Submit 1000 jobs | 8.10ms | Job queue throughput |
| Sequential execution | 6.32ms | Per-job overhead |
| Handle registration | 7.37ms | 1000 handles |

### Comparison with NIO FileSystem

Head-to-head benchmarks against [swift-nio](https://github.com/apple/swift-nio)'s `_NIOFileSystem`:

| Operation | swift-file-system | NIO FileSystem | Difference |
|-----------|-------------------|----------------|------------|
| Read 1MB | 6.05ms | 6.36ms | 1.05x faster |
| Write 1MB | 5.38ms | 5.08ms | 0.94x |
| Stat | 5.83ms | 7.80ms | 1.34x faster |
| Directory list (100 files) | 19.85ms | 91.36ms | **4.6x faster** |
| Directory walk (100 entries) | 50.75ms | 91.41ms | **1.8x faster** |
| Copy 1MB | 7.23ms | 7.07ms | ~same |

swift-file-system's pull-based batching architecture provides significant advantages for directory operations. File I/O performance is comparable, with slight variations depending on operation type.

### Memory Usage

The async executor maintains bounded memory regardless of workload:
- Queue limit prevents unbounded accumulation
- Batched iteration reduces intermediate allocations
- Handle store tracks open files without leaks
- Zero-allocation stat operations verified

### Methodology

Performance numbers are indicative, not guarantees. Measured on:
- Apple Silicon (M-series), macOS 26.0, Swift 6.2
- Release builds (`swift test -c release`)
- Warm filesystem cache (files read once before timing)
- APFS filesystem on internal NVMe SSD
- Statistical analysis: min, median, mean, p95, p99, stddev

Your results will vary based on hardware, filesystem, and workload characteristics.

## Architecture

### Layers

```
┌─────────────────────────────────────────────┐
│                 File System                 │  ← Public API: File, File.Directory
├─────────────────────────────────────────────┤
│   File System Primitives + Async (internal) │  ← Sync/async ops, platform abstraction
├─────────────────────────────────────────────┤
│          POSIX / Windows / Darwin           │  ← System calls
└─────────────────────────────────────────────┘
```

### API Levels

| Level | Types | Use Case |
|-------|-------|----------|
| **Convenience** | `File`, `File.Directory` | Most common operations |
| **Open/Handle** | `file.open`, `File.Handle` | Scoped low-level access |
| **Primitive** | `File.System.*` | Advanced options (durability, symlinks) |

### Copy Fallback Ladder

| Platform | Fallback Order |
|----------|----------------|
| **Darwin** | `copyfile(CLONE_FORCE)` → `copyfile(ALL/DATA)` → manual loop |
| **Linux** | `copy_file_range` → `sendfile` → manual loop |
| **Windows** | `CopyFileW` → manual loop |

### I/O Executor

- **Cooperative mode** (default): Uses `Task.detached`, shares Swift's cooperative pool
- **Dedicated mode**: Per-worker `DispatchQueue`, isolates blocking I/O
- **Backpressure**: Bounded queue with suspension when full
- **Graceful shutdown**: Completes in-flight work, fails pending jobs

## Platform Support

### Core Filesystem Operations

| Platform | Status | Optimizations |
|----------|--------|---------------|
| macOS | Full | APFS cloning, `copyfile()`, kernel-assisted copy |
| iOS | Full | Same as macOS |
| Linux | Full | `copy_file_range`, `sendfile` |
| Windows | Build ✅ | `CopyFileW`, see note below |

### Async I/O

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | Full | Cooperative and dedicated thread models |
| iOS | Full | Same as macOS |
| Linux | Full | Same as macOS |
| Windows | Build ✅ | Executor architecture ready |

### File Watching

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | Planned | FSEvents integration pending |
| iOS | Planned | FSEvents integration pending |
| Linux | Planned | inotify integration pending |
| Windows | Planned | ReadDirectoryChangesW pending |

### Windows Status

The library **builds successfully on Windows** with Swift 6.2. However, **tests are currently skipped** on Windows CI due to a Swift compiler crash when compiling swift-syntax (a transitive dependency used for test macros).

| Aspect | Status |
|--------|--------|
| Library build | ✅ Passes |
| Tests | ⏸️ Skipped (swift-syntax compiler crash) |
| Core functionality | Ready for use |

The underlying issue is in the Swift toolchain on Windows, not this library. Once Swift on Windows matures, full test coverage will be enabled. Contributions welcome.

## Non-goals

This library intentionally does not provide:

- **Virtual filesystem abstraction**: No pluggable backends or mock filesystems. Use protocol abstraction at a higher layer if needed.
- **Security sandbox**: Path validation is structural, not a security boundary. Do not use `File.Path` to prevent directory traversal attacks in untrusted input.
- **Database replacement**: For transactional semantics across multiple files, use SQLite or a proper database.
- **Watcher-first design**: File watching is planned but not the primary focus. For complex watching needs, consider dedicated solutions.
- **Complete Windows parity**: Windows support covers core operations; advanced features (ACLs, alternate data streams) are not prioritized.

## Testing

```bash
# All tests (1143 tests in 381 suites)
swift test

# Specific test suites
swift test --filter "File.System.Copy"
swift test --filter "File.IO.Executor"
swift test --filter "EdgeCase"

# Performance tests
swift test --filter "Performance"
```

Test coverage includes:
- Copy semantics (attributes, symlinks, overwrite)
- Atomic write durability modes
- Async batching and cancellation
- Executor thread model isolation
- Edge cases (empty files, long paths, unicode)
- Cross-platform behavior

## Related Packages

### Dependencies

- [apple/swift-system](https://github.com/apple/swift-system): Low-level system types
- [apple/swift-async-algorithms](https://github.com/apple/swift-async-algorithms): Async sequence algorithms
- [swift-standards](https://github.com/swift-standards/swift-standards): Binary serialization, time types

### See Also

- [swift-nio](https://github.com/apple/swift-nio): Event-driven network framework
- [swift-log](https://github.com/apple/swift-log): Logging API

## Contributing

Contributions welcome. Please:

1. Add tests - maintain coverage for new features
2. Follow conventions - Swift 6, strict concurrency, no force-unwraps
3. Update docs - inline documentation and README updates

Areas for contribution:
- Windows feature parity
- File watching implementation (FSEvents, inotify)
- Performance optimizations
- Additional edge case coverage

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
