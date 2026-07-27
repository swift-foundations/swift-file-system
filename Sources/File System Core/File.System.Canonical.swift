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

internal import Kernel
internal import Path_Primitives

extension File.System {
    /// Physical path canonicalization operations.
    ///
    /// Unlike lexical path navigation, canonicalization asks the file system to
    /// resolve every symbolic link and returns the resulting absolute path.
    public enum Canonical {}
}

extension File.System.Canonical {
    /// Resolves `path` to its physical, canonical path.
    ///
    /// The result is an owned ``File/Path`` suitable for subsequent file-system
    /// operations. Every path component and symbolic link traversed must exist.
    /// The result preserves the platform-native path code units returned by the
    /// kernel rather than round-tripping them through `Swift.String`.
    ///
    /// - Important: The returned path is a snapshot of a mutable file-system
    ///   namespace, not a stable object capability or a containment proof.
    ///   Another process can rename components after this function returns.
    ///   Use ``File/System/same(_:_:)`` to compare the identities of existing
    ///   objects. Security-sensitive traversal additionally requires
    ///   descriptor-relative, no-follow operations.
    ///
    /// - Parameter path: The path to resolve.
    /// - Returns: The resolved, absolute path.
    /// - Throws: ``File/System/Canonical/Error`` when resolution fails or the
    ///   resolved system path cannot be represented as ``File/Path``.
    public static func resolve(
        _ path: borrowing File.Path
    ) throws(File.System.Canonical.Error) -> File.Path {
        let canonical: Result<File.Path, File.Path.Error>
        do throws(Path_Primitives.Path.Canonical.Error) {
            canonical = try path.withKernelPath { kernelPath throws(Path_Primitives.Path.Canonical.Error) in
                try Path_Primitives.Path.Canonical.withCanonicalBytes(kernelPath) { bytes in
                    do throws(File.Path.Error) {
                        return .success(try File.Path(copying: bytes))
                    } catch {
                        return .failure(error)
                    }
                }
            }
        } catch {
            throw .resolution(error)
        }

        switch canonical {
        case .success(let path):
            return path

        case .failure(let error):
            throw .representation(error)
        }
    }
}
