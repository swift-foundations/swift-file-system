//
//  File.Directory.Glob.Match.swift
//  swift-file-system
//
//  Glob match result type.
//

extension File.Directory.Glob {
    /// A glob match result.
    ///
    /// Represents a single entry matched by a glob pattern.
    /// Can be either a file or a directory.
    public struct Match: Sendable {
        /// The matched file (if entry is a file).
        public let file: File?

        /// The matched directory (if entry is a directory).
        public let subdirectory: File.Directory?

        /// The absolute path of the match.
        public let path: File.Path

        /// Creates a match from a file.
        @usableFromInline
        internal init(file: File) {
            self.file = file
            self.subdirectory = nil
            self.path = file.path
        }

        /// Creates a match from a directory.
        @usableFromInline
        internal init(directory: File.Directory) {
            self.file = nil
            self.subdirectory = directory
            self.path = directory.path
        }
    }
}

extension File.Directory.Glob.Match {
    /// True if this match is a file.
    @inlinable
    public var isFile: Bool { file != nil }

    /// True if this match is a directory.
    @inlinable
    public var isDirectory: Bool { subdirectory != nil }
}

extension File.Directory.Glob.Match: Equatable {}
extension File.Directory.Glob.Match: Hashable {}
