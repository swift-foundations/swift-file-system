# ``File_System``

@Metadata {
    @DisplayName("File System")
    @TitleHeading("Swift Foundations")
}

Typed file and directory operations — read, write, copy, move, delete, glob,
stat, and directory traversal — built as a file-system domain on top of
`swift-io`'s strategy runtimes, with `blocking` (dedicated OS thread),
`completions` (`io_uring` proactor on Linux), and host-adaptive `default`
factories. The domain intentionally has no readiness-reactor factory:
regular files are always "ready" to epoll/kqueue, so the reactor strategy
provides no value here.

## When to use this

Reach for this package whenever code needs to read, write, or navigate files
and directories through a typed `File`/`File.Directory` API rather than raw
POSIX calls or `Foundation.FileManager`. Choose a specific strategy
(`.blocking(on:)`, `.completions(on:)`) only when the host-adaptive
`.default()` selection is not appropriate for the calling context. Code that
needs the underlying strategy runtime itself, for a different I/O domain
(sockets, for example), should depend on `swift-io` directly.

## Topics

### Related packages

- [swift-io](https://github.com/swift-foundations/swift-io) — the
  strategy-only async I/O runtime this domain is built on.
- [swift-paths](https://github.com/swift-foundations/swift-paths) — the
  path vocabulary this package's `File.Path` types compose.
