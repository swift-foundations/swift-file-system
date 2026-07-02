// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-file-system open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-file-system project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

internal import Error_Primitives

// Platform-neutral semantic codes for errors File System Core synthesizes
// itself (wrapping message-shaped failures into code-carrying cases). Each
// maps to the platform's closest native code: errno constants on POSIX,
// Win32 codes on Windows. Comparisons against codes the platform actually
// RETURNED stay per-site and platform-gated — these constants are only for
// synthesis, where the code is representative rather than observed.

extension Error_Primitives.Error.Code {
    /// Generic I/O failure (`EIO` / `ERROR_IO_DEVICE`).
    internal static var _fsIO: Self {
        #if os(Windows)
            .win32(1117)  // ERROR_IO_DEVICE (no named constant yet)
        #else
            .POSIX.EIO
        #endif
    }

    /// Path does not exist (`ENOENT` / `ERROR_FILE_NOT_FOUND`).
    internal static var _fsNotFound: Self {
        #if os(Windows)
            .Windows.ERROR_FILE_NOT_FOUND
        #else
            .POSIX.ENOENT
        #endif
    }

    /// Invalid argument (`EINVAL` / `ERROR_INVALID_PARAMETER`).
    internal static var _fsInvalid: Self {
        #if os(Windows)
            .Windows.ERROR_INVALID_PARAMETER
        #else
            .POSIX.EINVAL
        #endif
    }

    /// Access denied (`EACCES` / `ERROR_ACCESS_DENIED`).
    internal static var _fsAccessDenied: Self {
        #if os(Windows)
            .Windows.ERROR_ACCESS_DENIED
        #else
            .POSIX.EACCES
        #endif
    }

    /// Already exists (`EEXIST` / `ERROR_FILE_EXISTS`).
    internal static var _fsExists: Self {
        #if os(Windows)
            .Windows.ERROR_FILE_EXISTS
        #else
            .POSIX.EEXIST
        #endif
    }
}
