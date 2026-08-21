import File_System
public import File_System_Core

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    import ucrt
    import WinSDK
#endif

extension File.Directory {

    public enum Temporary {}
}

extension File.Directory.Temporary {
    #if os(Windows)

        private static func getEnvironmentVariable(_ name: Swift.String) -> String? {
            name.withCString(encodedAs: UTF16.self) { wName in

                let requiredSize = GetEnvironmentVariableW(wName, nil, 0)
                guard requiredSize > 0 else { return nil }

                var buffer = [WCHAR](repeating: 0, count: Int(requiredSize))
                let written = GetEnvironmentVariableW(wName, &buffer, requiredSize)
                guard written > 0 && written < requiredSize else { return nil }

                return String(decodingCString: buffer, as: UTF16.self)
            }
        }
    #endif

    public static var system: File.Directory {
        get throws {
            let path: Swift.String
            #if os(Windows)
                if let temp = getEnvironmentVariable("TEMP") {
                    path = temp
                } else if let tmp = getEnvironmentVariable("TMP") {
                    path = tmp
                } else {
                    path = "C:\\Temp"
                }
            #else
                if let ptr = unsafe getenv("TMPDIR") {
                    path = unsafe Swift.String(cString: ptr)
                } else {
                    path = "/tmp"
                }
            #endif
            return try File.Directory(validating: path)
        }
    }

    public static func cleanup(prefix: Swift.String = "test") throws {
        let base = try system
        let contents = try File.Directory.Contents.list(at: base)
        let targetPrefix = "\(prefix)-"

        for entry in contents {
            guard let name = Swift.String(entry.name) else { continue }
            if name.hasPrefix(targetPrefix), let component = try? File.Path.Component(name) {
                let path = base.path / component
                try? File.System.Delete.delete(at: path, recursive: true)
            }
        }
    }

    internal static func randomID() -> Swift.String {
        Swift.String(Int.random(in: (0..<Int.max)), radix: 36)
    }
}

extension File.Directory.Temporary {

    public struct Scope: Sendable {

        public let prefix: Swift.String

        public init(prefix: Swift.String = "test") {
            self.prefix = prefix
        }
    }

}

extension File.Directory.Temporary.Scope {

    @discardableResult
    public func callAsFunction<T>(
        _ body: (File.Directory) throws -> T
    ) throws -> T {
        let base = try File.Directory.Temporary.system
        let dirName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID())")
        let path = base.path / dirName

        try File.System.Create.Directory.create(at: path)
        defer { try? File.System.Delete.delete(at: path, recursive: true) }

        return try body(File.Directory(path))
    }

    @discardableResult
    public func callAsFunction<T>(
        _ body: (File.Directory) async throws -> T
    ) async throws -> T {
        let base = try File.Directory.Temporary.system
        let dirName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID())")
        let path = base.path / dirName

        try File.System.Create.Directory.create(at: path)

        do {
            let value = try await body(File.Directory(path))
            try? File.System.Delete.delete(at: path, recursive: true)
            return value
        } catch {
            try? File.System.Delete.delete(at: path, recursive: true)
            throw error
        }
    }
}

extension File.Directory {

    public static var temporary: Temporary.Scope {
        Temporary.Scope()
    }
}
