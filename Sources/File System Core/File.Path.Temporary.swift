// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-file-system open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-file-system project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

internal import Environment
internal import Path_Primitives

extension File.Path {
    /// Construction APIs for files under the OS temporary directory.
    public enum Temporary: Swift.Sendable {}
}

extension File.Path.Temporary {
    /// A deterministic temporary `File.Path` keyed on a stable input
    /// string.
    ///
    /// Composes `<TMPDIR>/<prefix><sanitized-key><suffix>`, where:
    /// - `<TMPDIR>` is `Environment.read("TMPDIR")` if set, otherwise
    ///   `/tmp`.
    /// - `<sanitized-key>` is the result of
    ///   ``Path_Primitives/Path/sanitized(from:)`` applied to `key`.
    /// - `<prefix>` and `<suffix>` are appended verbatim and SHOULD
    ///   contain only filesystem-safe characters (the caller's
    ///   responsibility — they are not sanitized by this function).
    ///
    /// Determinism: same `(prefix, key, suffix)` triple yields the
    /// same `File.Path` within and across processes (modulo TMPDIR
    /// stability). Distinct `key` values MAY map to the same path
    /// when their sanitized forms collide; callers needing
    /// collision-free paths should key on a stable digest of the
    /// source.
    ///
    /// - Throws: ``File/Path/Error`` if the constructed path string
    ///   fails validation (interior NUL, empty result, etc.). The
    ///   sanitization step normally precludes such failures.
    public static func deterministic(
        prefix: Swift.String,
        key: Swift.String,
        suffix: Swift.String
    ) throws(File.Path.Error) -> File.Path {
        #if os(Windows)
            let temporaryDirectoryString: Swift.String =
                Environment.read("TEMP") ?? Environment.read("TMP") ?? "C:\\Temp"
        #else
            let temporaryDirectoryString: Swift.String = Environment.read("TMPDIR") ?? "/tmp"
        #endif
        // `File.Path` owns trailing-separator semantics — the typed
        // construction normalizes them so the prior manual `dropLast`
        // is unnecessary. Separator semantics, component validation,
        // and absolute-passthrough come from `File.Path.appending(_:)`
        // (see `Lint.SingleFile.Materializer.resolveConsumerPath` at
        // commit `fe2c18e` for the same pivot in the linter).
        let temporaryDirectory = try File.Path(temporaryDirectoryString)
        let sanitizedKey = Path.sanitized(from: key)
        let trailing = try File.Path(prefix + sanitizedKey + suffix)
        return temporaryDirectory.appending(trailing)
    }
}
