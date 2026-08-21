import File_System
public import File_System_Core

extension File {

    public struct Temporary: Sendable {

        public let ext: Swift.String

        public let prefix: Swift.String

        internal init(extension ext: Swift.String, prefix: Swift.String) {
            self.ext = ext
            self.prefix = prefix
        }
    }

    public static func temporary(
        extension ext: Swift.String,
        prefix: Swift.String = "test"
    ) -> Temporary {
        Temporary(extension: ext, prefix: prefix)
    }
}

extension File.Temporary {

    @discardableResult
    public func callAsFunction<T>(
        _ body: (File.Path) throws -> T
    ) throws -> T {
        let base = try File.Directory.Temporary.system
        let dirName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID())")
        let dirPath = base.path / dirName

        try File.System.Create.Directory.create(at: dirPath)
        defer { try? File.System.Delete.delete(at: dirPath, recursive: true) }

        let fileName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID()).\(ext)")
        let filePath = dirPath / fileName

        return try body(filePath)
    }

    @discardableResult
    public func callAsFunction<T>(
        _ body: (File.Path) async throws -> T
    ) async throws -> T {
        let base = try File.Directory.Temporary.system
        let dirName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID())")
        let dirPath = base.path / dirName

        try File.System.Create.Directory.create(at: dirPath)
        defer { try? File.System.Delete.delete(at: dirPath, recursive: true) }

        let fileName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID()).\(ext)")
        let filePath = dirPath / fileName

        return try await body(filePath)
    }
}
