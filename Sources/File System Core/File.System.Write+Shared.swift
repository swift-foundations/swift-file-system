// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Kernel

// MARK: - Path Resolution

extension File.System.Write {
    internal static func resolvePaths(
        _ path: File.Path
    ) -> (resolved: File.Path, parent: File.Path) {
        (path, path.parent ?? ".")
    }

    internal static func fileName(of path: File.Path) -> File.Path.Component? {
        path.components.last
    }
}

// MARK: - File Existence

extension File.System.Write {
    internal static func fileExists(_ path: File.Path) -> Bool {
        do {
            _ = try Kernel.File.Stats.lget(path: path.kernelPath)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Random Token

extension File.System.Write {
    internal static func randomToken(
        length: Int
    ) throws(File.System.Write.Error) -> Swift.String {
        try unsafe withUnsafeTemporaryAllocation(
            of: UInt8.self,
            capacity: length
        ) { buffer throws(File.System.Write.Error) -> Swift.String in
            let rawBuffer = UnsafeMutableRawBufferPointer(buffer)
            do {
                try unsafe Random.fill(rawBuffer)
            } catch {
                throw .random("CSPRNG syscall failed: \(error)")
            }
            return unsafe hexEncode(Array(buffer).map(Byte.init))
        }
    }

    internal static func hexEncode(_ bytes: [Byte]) -> Swift.String {
        let hexChars: [Character] = [
            "0", "1", "2", "3", "4", "5", "6", "7",
            "8", "9", "a", "b", "c", "d", "e", "f",
        ]
        var result = Swift.String()
        result.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            let raw = byte.underlying
            result.append(hexChars[Int(raw >> 4)])
            result.append(hexChars[Int(raw & 0x0F)])
        }
        return result
    }
}

// MARK: - Write All

extension File.System.Write {
    /// Writes all bytes from a span to a file descriptor, handling partial writes.
    internal static func writeAll(
        _ span: borrowing Swift.Span<Byte>,
        to fd: borrowing Kernel.Descriptor
    ) throws(File.System.Write.Error) {
        let total = span.count
        if total == 0 { return }

        var written = 0

        unsafe try span.withUnsafeBufferPointer { buffer throws(File.System.Write.Error) in
            guard let base = buffer.baseAddress else { return }

            while written < total {
                let slice = unsafe UnsafeRawBufferPointer(
                    start: base.advanced(by: written),
                    count: total - written
                )

                do {
                    let rc = unsafe try Kernel.IO.Write.write(fd, from: slice)
                    if rc > 0 {
                        written += rc
                        continue
                    }
                    if rc == 0 {
                        throw File.System.Write.Error.write(
                            written: written,
                            expected: total,
                            "write returned 0"
                        )
                    }
                } catch let error as Kernel.IO.Write.Error {
                    if case .blocking(.wouldBlock) = error { continue }
                    throw File.System.Write.Error.write(
                        written: written,
                        expected: total,
                        "write failed: \(error)"
                    )
                } catch let error as File.System.Write.Error {
                    throw error
                } catch {
                    throw File.System.Write.Error.write(
                        written: written,
                        expected: total,
                        "write failed: \(error)"
                    )
                }
            }
        }
    }

    /// Writes all bytes from a raw buffer to a file descriptor, handling partial writes.
    internal static func writeAllRaw(
        _ buffer: UnsafeRawBufferPointer,
        to fd: borrowing Kernel.Descriptor
    ) throws(File.System.Write.Error) {
        let total = buffer.count
        if total == 0 { return }

        guard let base = buffer.baseAddress else { return }

        var written = 0

        while written < total {
            let slice = unsafe UnsafeRawBufferPointer(
                start: base.advanced(by: written),
                count: total - written
            )

            do {
                let rc = unsafe try Kernel.IO.Write.write(fd, from: slice)
                if rc > 0 {
                    written += rc
                    continue
                }
                if rc == 0 {
                    throw File.System.Write.Error.write(
                        written: written,
                        expected: total,
                        "write returned 0"
                    )
                }
            } catch let error as Kernel.IO.Write.Error {
                if case .blocking(.wouldBlock) = error { continue }
                throw File.System.Write.Error.write(
                    written: written,
                    expected: total,
                    "write failed: \(error)"
                )
            } catch let error as File.System.Write.Error {
                throw error
            } catch {
                throw File.System.Write.Error.write(
                    written: written,
                    expected: total,
                    "write failed: \(error)"
                )
            }
        }
    }
}

// MARK: - Sync and Close

extension File.System.Write {
    /// Syncs file data according to durability mode.
    ///
    /// - `.full`: fsync (or F_FULLFSYNC on Darwin)
    /// - `.dataOnly`: fdatasync on Linux, F_BARRIERFSYNC on Darwin, fsync elsewhere
    /// - `.none`: no-op
    internal static func syncFile(
        _ fd: borrowing Kernel.Descriptor,
        durability: File.System.Write.Durability
    ) throws(File.System.Write.Error) {
        switch durability {
        case .full:
            do {
                try Kernel.File.Flush.flush(fd)
            } catch {
                throw .sync("fsync failed: \(error)")
            }
        case .dataOnly:
            do {
                try Kernel.File.Flush.data(fd)
            } catch {
                throw .sync("data sync failed: \(error)")
            }
        case .none:
            break
        }
    }

    internal static func closeFile(
        _ fd: consuming Kernel.Descriptor
    ) throws(File.System.Write.Error) {
        do {
            try Kernel.Close.close(fd)
        } catch {
            throw .close("close failed: \(error)")
        }
    }
}

// MARK: - Rename Operations

extension File.System.Write {
    /// Atomically renames a file, propagating the actual error on failure.
    internal static func atomicRename(
        from source: File.Path,
        to dest: File.Path
    ) throws(File.System.Write.Error) {
        do {
            try Kernel.File.Move.move(from: source.kernelPath, to: dest.kernelPath)
        } catch {
            throw .rename(from: source, to: dest, "\(error)")
        }
    }

    /// Renames without overwriting.
    ///
    /// TODO: Currently a non-atomic existence-check + move (TOCTOU race window).
    /// Promote to atomic when `Kernel.File.Move.noClobber` lands upstream
    /// (requires `renameat2(RENAME_NOREPLACE)` on Linux, `renamex_np(RENAME_EXCL)`
    /// on macOS, `SetFileInformationByHandle` on Windows — currently fragmented
    /// across `Linux.Kernel.File.Rename`, `Darwin.Kernel.File.Move` extension,
    /// and `Windows.\`32\`.Kernel.File.Rename`).
    internal static func atomicRenameNoClobber(
        from source: File.Path,
        to dest: File.Path
    ) throws(File.System.Write.Error) {
        if File.System.Stat.exists(at: dest) {
            throw .exists(path: dest)
        }
        do {
            try Kernel.File.Move.move(from: source.kernelPath, to: dest.kernelPath)
        } catch {
            throw .rename(from: source, to: dest, "\(error)")
        }
    }

    /// Syncs a directory to persist rename operations.
    internal static func syncDirectory(
        _ path: File.Path
    ) throws(File.System.Write.Error) {
        #if os(Windows)
            _ = path
        #else
            do {
                let fd = try Kernel.File.Open.open(
                    path: path.kernelPath,
                    mode: .read,
                    options: [.execClose],
                    permissions: .none
                )
                try Kernel.File.Flush.flush(fd)
                // fd closes via deinit at end of scope
            } catch {
                throw .directory(
                    path: path,
                    "fsync directory failed: \(error)"
                )
            }
        #endif
    }
}
