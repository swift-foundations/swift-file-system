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

public import Path_Primitives

extension File.System.Canonical {
    /// Errors produced while resolving a physical path.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The underlying file-system resolution failed.
        case resolution(Path_Primitives.Path.Canonical.Error)

        /// The resolved system path cannot be represented by ``File/Path``.
        case representation(File.Path.Error)
    }
}

extension File.System.Canonical.Error {
    /// Whether resolution failed because a path component does not exist.
    public var isNotFound: Bool {
        if case .resolution(.path(.notFound)) = self {
            return true
        }
        return false
    }

    /// Whether resolution encountered a symbolic-link loop.
    public var isLoop: Bool {
        if case .resolution(.path(.loop)) = self {
            return true
        }
        return false
    }
}

extension File.System.Canonical.Error: CustomStringConvertible {
    /// A human-readable description of the failure.
    public var description: Swift.String {
        switch self {
        case .resolution(let error):
            return "Path canonicalization failed: \(error)"

        case .representation(let error):
            return "Canonical path cannot be represented: \(error)"
        }
    }
}
