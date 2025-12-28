// File.System.Write.Streaming+Windows.swift
// Windows implementation of streaming file writes

#if os(Windows)

    import WinSDK
    import INCITS_4_1986

    // MARK: - Windows Implementation

    extension File.System.Write.Streaming {
        /// Windows implementation of streaming file writes.
        public enum Windows {

            // MARK: - Generic Sequence API

            static func write<Chunks: Sequence>(
                _ chunks: Chunks,
                to path: borrowing String,
                options: borrowing File.System.Write.Streaming.Options
            ) throws(File.System.Write.Streaming.Error)
            where Chunks.Element == [UInt8] {

                let resolvedPath = normalizePath(path)
                let parent = parentDirectory(of: resolvedPath)
                try verifyOrCreateParentDirectory(
                    parent,
                    createIntermediates: options.createIntermediates
                )

                switch options.commit {
                case .atomic(let atomicOptions):
                    try writeAtomic(chunks, to: resolvedPath, parent: parent, options: atomicOptions)
                case .direct(let directOptions):
                    try writeDirect(chunks, to: resolvedPath, options: directOptions)
                }
            }

            // MARK: - Atomic Write

            private static func writeAtomic<Chunks: Sequence>(
                _ chunks: Chunks,
                to resolvedPath: String,
                parent: String,
                options: File.System.Write.Streaming.Atomic.Options
            ) throws(File.System.Write.Streaming.Error)
            where Chunks.Element == [UInt8] {

                // noClobber semantics are enforced by MoveFileExW without
                // MOVEFILE_REPLACE_EXISTING. We do NOT pre-check existence here
                // because that would be semantically wrong: noClobber means "don't
                // overwrite if file exists at publish time", not "fail if file exists
                // at start time". A pre-check could cause incorrect early failure if
                // the file is removed between check and publish.

                let tempPath = generateTempPath(in: parent, for: resolvedPath)
                let handle = try createFile(at: tempPath, exclusive: true)

                var handleClosed = false
                var renamed = false

                defer {
                    if !handleClosed { _ = CloseHandle(handle) }
                    if !renamed { _ = deleteFile(tempPath) }
                }

                // Write all chunks
                for chunk in chunks {
                    try writeAll(chunk.span, to: handle, path: resolvedPath)
                }

                try flushFile(handle, durability: options.durability)

                guard _ok(CloseHandle(handle)) else {
                    throw .closeFailed(
                        errno: Int32(GetLastError()),
                        message: "CloseHandle failed"
                    )
                }
                handleClosed = true

                // Use appropriate rename based on strategy
                switch options.strategy {
                case .replaceExisting:
                    try atomicRename(from: tempPath, to: resolvedPath)
                case .noClobber:
                    try atomicRenameNoClobber(from: tempPath, to: resolvedPath)
                }
                renamed = true

                // Directory sync after publish - only for .full durability.
                // Directory sync is a metadata persistence step, so it should NOT be
                // performed for .dataOnly (which explicitly states "metadata may not
                // be persisted").
                if options.durability == .full {
                    do {
                        try flushDirectory(parent)
                    } catch let syncError {
                        // Extract errno from the sync error for the after-commit error
                        if case .directorySyncFailed(let path, let e, let msg) = syncError {
                            throw .directorySyncFailedAfterCommit(
                                path: path,
                                errno: e,
                                message: msg
                            )
                        }
                        throw syncError
                    }
                }
            }

            // MARK: - Direct Write

            private static func writeDirect<Chunks: Sequence>(
                _ chunks: Chunks,
                to resolvedPath: String,
                options: File.System.Write.Streaming.Direct.Options
            ) throws(File.System.Write.Streaming.Error)
            where Chunks.Element == [UInt8] {

                if case .create = options.strategy {
                    if fileExists(resolvedPath) {
                        throw .destinationExists(path: File.Path(__unchecked: (), resolvedPath))
                    }
                }

                let handle = try createFile(at: resolvedPath, exclusive: options.strategy == .create)

                var handleClosed = false

                defer {
                    if !handleClosed { _ = CloseHandle(handle) }
                }

                // Write all chunks
                for chunk in chunks {
                    try writeAll(chunk.span, to: handle, path: resolvedPath)
                }

                try flushFile(handle, durability: options.durability)

                guard _ok(CloseHandle(handle)) else {
                    throw .closeFailed(
                        errno: Int32(GetLastError()),
                        message: "CloseHandle failed"
                    )
                }
                handleClosed = true
            }
        }
    }

    // MARK: - Path Handling

    extension File.System.Write.Streaming.Windows {

        private static func normalizePath(_ path: String) -> String {
            var result = ""
            result.reserveCapacity(path.utf8.count)
            for char in path {
                if char == "/" {
                    result.append("\\")
                } else {
                    result.append(char)
                }
            }

            while result.count > 3 && result.hasSuffix("\\") {
                result.removeLast()
            }

            return result
        }

        private static func parentDirectory(of path: String) -> String {
            if let lastSep = path.lastIndex(of: "\\") {
                if lastSep == path.startIndex {
                    return String(path[...lastSep])
                }
                let prefix = String(path[..<lastSep])
                if prefix.count == 2 && prefix.last == ":" {
                    return prefix + "\\"
                }
                return prefix
            }
            return "."
        }

        private static func fileName(of path: String) -> String {
            if let lastSep = path.lastIndex(of: "\\") {
                return String(path[path.index(after: lastSep)...])
            }
            return path
        }

        private static func verifyOrCreateParentDirectory(
            _ dir: String,
            createIntermediates: Bool
        ) throws(File.System.Write.Streaming.Error) {
            do {
                try File.System.Parent.Check.verify(dir, createIntermediates: createIntermediates)
            } catch let e {
                throw .parent(e)
            }
        }

        private static func fileExists(_ path: String) -> Bool {
            let attrs = withWideString(path) { GetFileAttributesW($0) }
            return attrs != INVALID_FILE_ATTRIBUTES
        }

        private static func generateTempPath(in parent: String, for destPath: String) -> String {
            let baseName = fileName(of: destPath)
            let random = randomHex(12)
            return "\(parent)\\\(baseName).streaming.\(random).tmp"
        }

        private nonisolated(unsafe) static var _counter: UInt32 = 0

        private static func randomHex(_ byteCount: Int) -> String {
            let pid = GetCurrentProcessId()
            let tick = GetTickCount64()
            _counter &+= 1

            let digit0 = UInt32(UInt8.ascii.`0`)
            let letterA = UInt32(UInt8.ascii.a)

            var result = ""
            let value = UInt64(pid) ^ tick ^ UInt64(_counter)
            var remaining = value
            for _ in 0..<min(byteCount * 2, 16) {
                let nibble = UInt32(remaining & 0xF)
                let code = nibble < 10 ? (digit0 + nibble) : (letterA - 10 + nibble)
                result.append(Character(Unicode.Scalar(code)!))
                remaining >>= 4
            }
            return result
        }
    }

    // MARK: - File Operations

    extension File.System.Write.Streaming.Windows {

        private static func createFile(
            at path: String,
            exclusive: Bool
        ) throws(File.System.Write.Streaming.Error) -> HANDLE {
            let disposition: DWORD = exclusive ? _dword(CREATE_NEW) : _dword(CREATE_ALWAYS)

            let handle = withWideString(path) { wPath in
                CreateFileW(
                    wPath,
                    _dword(GENERIC_WRITE),
                    0,
                    nil,
                    disposition,
                    _mask(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                let err = GetLastError()
                throw .fileCreationFailed(
                    path: File.Path(__unchecked: (), path),
                    errno: Int32(err),
                    message: "CreateFileW failed with error \(err)"
                )
            }

            return handle
        }

        /// Writes all bytes to handle, handling partial writes.
        private static func writeAll(
            _ span: borrowing Span<UInt8>,
            to handle: HANDLE,
            path: String
        ) throws(File.System.Write.Streaming.Error) {
            let total = span.count
            if total == 0 { return }

            var written = 0

            try span.withUnsafeBufferPointer { buffer throws(File.System.Write.Streaming.Error) in
                guard let base = buffer.baseAddress else { return }

                while written < total {
                    let remaining = total - written
                    var bytesWritten: DWORD = 0

                    let success = WriteFile(
                        handle,
                        UnsafeRawPointer(base.advanced(by: written)),
                        DWORD(truncatingIfNeeded: remaining),
                        &bytesWritten,
                        nil
                    )

                    if !_ok(success) {
                        let err = GetLastError()
                        throw File.System.Write.Streaming.Error.writeFailed(
                            path: File.Path(__unchecked: (), path),
                            bytesWritten: written,
                            errno: Int32(err),
                            message: "WriteFile failed with error \(err)"
                        )
                    }

                    if bytesWritten == 0 {
                        throw File.System.Write.Streaming.Error.writeFailed(
                            path: File.Path(__unchecked: (), path),
                            bytesWritten: written,
                            errno: 0,
                            message: "WriteFile wrote 0 bytes"
                        )
                    }

                    written += Int(bytesWritten)
                }
            }
        }

        private static func flushFile(
            _ handle: HANDLE,
            durability: File.System.Write.Streaming.Durability
        ) throws(File.System.Write.Streaming.Error) {
            switch durability {
            case .full, .dataOnly:
                if !_ok(FlushFileBuffers(handle)) {
                    let err = GetLastError()
                    throw .syncFailed(
                        errno: Int32(err),
                        message: "FlushFileBuffers failed with error \(err)"
                    )
                }
            case .none:
                break
            }
        }

        private static func deleteFile(_ path: String) -> Bool {
            return withWideString(path) { DeleteFileW($0) }
        }

        private static func atomicRename(
            from tempPath: String,
            to destPath: String
        ) throws(File.System.Write.Streaming.Error) {
            let flags: DWORD = _dword(MOVEFILE_REPLACE_EXISTING) | _dword(MOVEFILE_WRITE_THROUGH)

            let success = withWideString(tempPath) { wTemp in
                withWideString(destPath) { wDest in
                    MoveFileExW(wTemp, wDest, flags)
                }
            }

            if !success {
                let err = GetLastError()
                throw .renameFailed(
                    from: File.Path(__unchecked: (), tempPath),
                    to: File.Path(__unchecked: (), destPath),
                    errno: Int32(err),
                    message: "MoveFileExW failed with error \(err)"
                )
            }
        }

        /// Atomically renames temp file to destination, failing if destination exists.
        ///
        /// Uses MoveFileExW without MOVEFILE_REPLACE_EXISTING - the rename will
        /// fail with ERROR_ALREADY_EXISTS or ERROR_FILE_EXISTS if destination exists.
        private static func atomicRenameNoClobber(
            from tempPath: String,
            to destPath: String
        ) throws(File.System.Write.Streaming.Error) {
            // Only use MOVEFILE_WRITE_THROUGH, NOT MOVEFILE_REPLACE_EXISTING
            let flags: DWORD = _dword(MOVEFILE_WRITE_THROUGH)

            let success = withWideString(tempPath) { wTemp in
                withWideString(destPath) { wDest in
                    MoveFileExW(wTemp, wDest, flags)
                }
            }

            if !success {
                let err = GetLastError()
                // Multiple error codes can indicate "exists":
                // - ERROR_ALREADY_EXISTS (183)
                // - ERROR_FILE_EXISTS (80)
                // Note: ERROR_ACCESS_DENIED can occur for various reasons,
                // so we don't map it to destinationExists to avoid masking real permission errors
                if err == _dword(ERROR_ALREADY_EXISTS) || err == _dword(ERROR_FILE_EXISTS) {
                    throw .destinationExists(path: File.Path(__unchecked: (), destPath))
                }
                throw .renameFailed(
                    from: File.Path(__unchecked: (), tempPath),
                    to: File.Path(__unchecked: (), destPath),
                    errno: Int32(err),
                    message: "MoveFileExW failed with error \(err)"
                )
            }
        }

        /// Flushes directory to persist rename.
        ///
        /// On Windows, this is a no-op. `FlushFileBuffers` on directories requires
        /// `SE_BACKUP_PRIVILEGE` which standard applications don't have. The rename
        /// operation uses `MOVEFILE_WRITE_THROUGH` which provides write-through
        /// semantics, and NTFS's transactional journal provides durability guarantees
        /// for metadata operations like renames.
        private static func flushDirectory(_ path: String) throws(File.System.Write.Streaming.Error) {
            // No-op on Windows - directory sync is not supported without elevated
            // privileges, and MOVEFILE_WRITE_THROUGH already provides durability.
            _ = path  // Silence unused parameter warning
        }
    }

    // MARK: - Utilities

    extension File.System.Write.Streaming.Windows {

        private static func withWideString<T>(
            _ string: String,
            _ body: (UnsafePointer<WCHAR>) -> T
        ) -> T {
            string.withCString(encodedAs: UTF16.self) { utf16Ptr in
                utf16Ptr.withMemoryRebound(to: WCHAR.self, capacity: string.utf16.count + 1) {
                    wcharPtr in
                    body(wcharPtr)
                }
            }
        }
    }

    // MARK: - Multi-phase Streaming Helpers (for async)

    extension File.System.Write.Streaming.Windows {
        /// Context for multi-phase streaming writes.
        ///
        /// @unchecked Sendable because all fields are immutable value types.
        /// HANDLE is a pointer but Windows file handles are thread-safe for sequential operations.
        /// Safe to pass to io.run closures within a single async function.
        package struct Context: @unchecked Sendable {
            // HANDLE is internal in WinSDK, so this property must be internal
            internal let handle: HANDLE
            package let tempPath: String?  // nil for direct mode
            package let resolvedPath: String
            package let parent: String
            package let durability: File.System.Write.Streaming.Durability
            package let isAtomic: Bool
            package let strategy: File.System.Write.Streaming.Atomic.Strategy?
        }
    }

    extension File.System.Write.Streaming.Windows {
        /// Opens a file for multi-phase streaming write.
        ///
        /// Returns a context that can be used for subsequent write(chunk:) and commit calls.
        package static func open(
            path: String,
            options: File.System.Write.Streaming.Options
        ) throws(File.System.Write.Streaming.Error) -> Context {

            let resolvedPath = normalizePath(path)
            let parent = parentDirectory(of: resolvedPath)
            try verifyOrCreateParentDirectory(
                parent,
                createIntermediates: options.createIntermediates
            )

            switch options.commit {
            case .atomic(let atomicOptions):
                let tempPath = generateTempPath(in: parent, for: resolvedPath)
                let handle = try createFile(at: tempPath, exclusive: true)
                return Context(
                    handle: handle,
                    tempPath: tempPath,
                    resolvedPath: resolvedPath,
                    parent: parent,
                    durability: atomicOptions.durability,
                    isAtomic: true,
                    strategy: atomicOptions.strategy
                )

            case .direct(let directOptions):
                let handle = try createFile(
                    at: resolvedPath,
                    exclusive: directOptions.strategy == .create
                )
                return Context(
                    handle: handle,
                    tempPath: nil,
                    resolvedPath: resolvedPath,
                    parent: parent,
                    durability: directOptions.durability,
                    isAtomic: false,
                    strategy: nil
                )
            }
        }

        /// Writes a chunk to an open streaming context.
        ///
        /// The Span must not escape - callee uses it immediately and synchronously.
        package static func write(
            chunk span: borrowing Span<UInt8>,
            to context: borrowing Context
        ) throws(File.System.Write.Streaming.Error) {
            try writeAll(span, to: context.handle, path: context.tempPath ?? context.resolvedPath)
        }

        /// Commits a streaming write, closing the file and performing the atomic rename if needed.
        ///
        /// This function owns post-publish error semantics:
        /// - Pre-publish failures throw normal errors
        /// - Post-publish I/O failures throw `.directorySyncFailedAfterCommit`
        package static func commit(
            _ context: borrowing Context
        ) throws(File.System.Write.Streaming.Error) {

            // Sync file data
            try flushFile(context.handle, durability: context.durability)

            // Close the handle
            guard _ok(CloseHandle(context.handle)) else {
                throw .closeFailed(
                    errno: Int32(GetLastError()),
                    message: "CloseHandle failed"
                )
            }

            if context.isAtomic, let tempPath = context.tempPath {
                // Atomic rename
                switch context.strategy {
                case .replaceExisting, .none:
                    try atomicRename(from: tempPath, to: context.resolvedPath)
                case .noClobber:
                    try atomicRenameNoClobber(from: tempPath, to: context.resolvedPath)
                }

                // Directory sync after publish - only for .full durability
                if context.durability == .full {
                    do {
                        try flushDirectory(context.parent)
                    } catch let syncError {
                        if case .directorySyncFailed(let path, let e, let msg) = syncError {
                            throw .directorySyncFailedAfterCommit(
                                path: path,
                                errno: e,
                                message: msg
                            )
                        }
                        throw syncError
                    }
                }
            }
        }

        /// Cleans up a failed streaming write.
        ///
        /// Best-effort cleanup - closes handle and removes temp file if atomic mode.
        package static func cleanup(_ context: borrowing Context) {
            // Close handle if still open (ignore errors)
            _ = CloseHandle(context.handle)

            // Remove temp file if atomic mode
            if let tempPath = context.tempPath {
                _ = deleteFile(tempPath)
            }
        }
    }

#endif  // os(Windows)
