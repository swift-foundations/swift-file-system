//
//  File.Directory.Walk.Async.FastPath.swift
//  swift-file-system
//
//  Fast-path walker using fts(3) on POSIX or stack-based DFS.
//  Eliminates TaskGroup/actor/channel overhead for simple walks.
//

extension File.Directory.Walk.Async {
    /// Fast-path walker that avoids structured concurrency overhead.
    ///
    /// This is used when:
    /// - `maxConcurrency == 1`
    /// - `followSymlinks == false`
    /// - Default undecodable handling
    ///
    /// Uses `fts(3)` on POSIX for maximum efficiency, with a
    /// stack-based DFS fallback on Windows.
    internal struct FastPath {

        /// Checks if fast-path can be used for the given options.
        internal static func canUse(options: Options) -> Bool {
            // Fast-path requires single-threaded traversal
            guard options.maxConcurrency == 1 else { return false }

            // Fast-path doesn't support symlink following (would need cycle detection)
            guard !options.followSymlinks else { return false }

            // We can handle hidden filtering and depth limiting in the fast path
            return true
        }

        /// Internal heuristic: detect small trees where concurrency overhead exceeds benefit.
        ///
        /// Probes the root directory to count immediate subdirectories.
        /// If the count is below a threshold, fast-path is more efficient.
        ///
        /// - Returns: `true` if fast-path should be used for this tree.
        internal static func shouldUseForSmallTree(root: File.Directory, options: Options) -> Bool {
            // Can't use fast-path with symlink following
            guard !options.followSymlinks else { return false }

            // Probe threshold: if root has fewer than this many subdirectories,
            // concurrency overhead typically exceeds parallelism benefit.
            // Tuned for typical file system latencies and TaskGroup overhead.
            let subdirectoryThreshold = 16

            // Quick probe: count immediate subdirectories
            guard let entries = try? File.Directory.Contents.list(at: root) else {
                // If we can't read root, fall back to concurrent (it handles errors)
                return false
            }

            var subdirCount = 0
            for entry in entries {
                if entry.type == .directory {
                    subdirCount += 1
                    if subdirCount >= subdirectoryThreshold {
                        // Tree is large enough that concurrency may help
                        return false
                    }
                }
            }

            // Few subdirectories - fast-path wins due to lower overhead
            return true
        }

        /// Creates a fast-path async sequence for directory walking.
        internal static func makeSequence(
            root: File.Directory,
            options: Options,
            fs: File.System.Async
        ) -> AsyncThrowingStream<File.Path, any Error> {
            AsyncThrowingStream { continuation in
                let task = Task {
                    await Self.produce(
                        root: root,
                        options: options,
                        fs: fs,
                        continuation: continuation
                    )
                }

                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }

        private static func produce(
            root: File.Directory,
            options: Options,
            fs: File.System.Async,
            continuation: AsyncThrowingStream<File.Path, any Error>.Continuation
        ) async {
            #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
            await produceFTS(root: root, options: options, fs: fs, continuation: continuation)
            #else
            await produceDFS(root: root, options: options, fs: fs, continuation: continuation)
            #endif
        }

        #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
        /// FTS-based producer for POSIX systems.
        private static func produceFTS(
            root: File.Directory,
            options: Options,
            fs: File.System.Async,
            continuation: AsyncThrowingStream<File.Path, any Error>.Continuation
        ) async {
            do {
                // Run fts operations on IO executor to avoid blocking
                try await fs.run {
                    var walker = try File.Directory.Walk.FTS(path: root.path)
                    defer { walker.close() }

                    let batchSize = 64
                    var batch: [File.Path] = []
                    batch.reserveCapacity(batchSize)

                    while let entry = try walker.next() {
                        // Check for cancellation
                        if Task.isCancelled { break }

                        // Apply depth filter
                        if let maxDepth = options.maxDepth {
                            let relativeDepth = entry.depth
                            if relativeDepth > maxDepth { continue }
                        }

                        // Apply hidden filter (dot-prefix convention on Unix-like systems)
                        if !options.includeHidden {
                            if let name = entry.path.lastComponent, name.starts(with: 0x2E) {
                                continue
                            }
                        }

                        batch.append(entry.path)

                        // Yield batch when full (reduces continuation overhead)
                        if batch.count >= batchSize {
                            for path in batch {
                                continuation.yield(path)
                            }
                            batch.removeAll(keepingCapacity: true)
                        }
                    }

                    // Yield remaining entries
                    for path in batch {
                        continuation.yield(path)
                    }
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        #endif

        /// Stack-based DFS producer for Windows and fallback.
        private static func produceDFS(
            root: File.Directory,
            options: Options,
            fs: File.System.Async,
            continuation: AsyncThrowingStream<File.Path, any Error>.Continuation
        ) async {
            var stack: [(dir: File.Directory, depth: Int)] = [(root, 0)]

            do {
                while let (dir, depth) = stack.popLast() {
                    // Check for cancellation
                    if Task.isCancelled { break }

                    // Check depth limit
                    if let maxDepth = options.maxDepth, depth > maxDepth { continue }

                    // List directory entries
                    let entries: [File.Directory.Entry]
                    do {
                        entries = try await fs.run {
                            try File.Directory.Contents.list(at: dir)
                        }
                    } catch {
                        // Skip directories we can't read (permission denied, etc.)
                        continue
                    }

                    for entry in entries {
                        // Check for cancellation
                        if Task.isCancelled { break }

                        // Apply hidden filter
                        if !options.includeHidden && entry.name.isHiddenByDotPrefix {
                            continue
                        }

                        // Skip entries with undecodable names
                        guard let path = entry.pathIfValid else {
                            // Apply undecodable policy
                            let context = File.Directory.Walk.Undecodable.Context(
                                parent: entry.parent,
                                name: entry.name,
                                type: entry.type,
                                depth: depth
                            )
                            switch options.onUndecodable(context) {
                            case .skip:
                                continue
                            case .emit:
                                // Can't emit without valid path
                                continue
                            case .stopAndThrow:
                                throw File.Directory.Walk.Error.undecodableEntry(
                                    parent: entry.parent,
                                    name: entry.name
                                )
                            }
                        }

                        // Yield this path
                        continuation.yield(path)

                        // Queue subdirectory for traversal
                        if entry.type == .directory {
                            stack.append((File.Directory(path), depth + 1))
                        }
                    }
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

// MARK: - Fast Path Iterator

extension File.Directory.Walk.Async {
    /// Iterator wrapper for fast-path AsyncThrowingStream.
    internal final class FastPathIterator: AsyncIteratorProtocol {
        public typealias Element = File.Path

        private var iterator: AsyncThrowingStream<File.Path, any Error>.AsyncIterator

        internal init(stream: AsyncThrowingStream<File.Path, any Error>) {
            self.iterator = stream.makeAsyncIterator()
        }

        public func next() async throws -> File.Path? {
            try await iterator.next()
        }
    }
}
