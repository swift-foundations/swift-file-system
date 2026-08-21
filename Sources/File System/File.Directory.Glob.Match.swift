extension File.Directory.Glob {

    public struct Match: Sendable {

        public let file: File?

        public let subdirectory: File.Directory?

        public let path: File.Path

        @usableFromInline
        internal init(file: File) {
            self.file = file
            self.subdirectory = nil
            self.path = file.path
        }

        @usableFromInline
        internal init(directory: File.Directory) {
            self.file = nil
            self.subdirectory = directory
            self.path = directory.path
        }
    }
}

extension File.Directory.Glob.Match {

    @inlinable
    public var isFile: Bool { file != nil }

    @inlinable
    public var isDirectory: Bool { subdirectory != nil }
}

extension File.Directory.Glob.Match: Equatable {}
extension File.Directory.Glob.Match: Hashable {}
