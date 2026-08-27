internal import Environment
internal import Path

extension File.Path {

    public enum Temporary: Swift.Sendable {}
}

extension File.Path.Temporary {

    public static func sibling(
        of path: File.Path,
        prefix: Swift.String,
        suffix: Swift.String = ""
    ) throws(Error) -> File.Path {
        guard let parent = path.parent else {
            throw .parent
        }

        let token: Swift.String
        do throws(File.System.Write.Error) {
            token = try File.System.Write.randomToken(length: 16)
        } catch {
            throw .random
        }

        let component: File.Path.Component
        do throws(File.Path.Component.Error) {
            component = try File.Path.Component(prefix + token + suffix)
        } catch {
            throw .component(error)
        }
        return parent / component
    }

    public static func deterministic(
        prefix: Swift.String,
        key: Swift.String,
        suffix: Swift.String
    ) throws(File.Path.Error) -> File.Path {
        #if os(Windows)
            let temporaryDirectoryString: Swift.String =
                Environment.read("TEMP") ?? Environment.read("TMP") ?? "C:\\Temp"
        #else
            let temporaryDirectoryString: Swift.String = Environment.read("TMPDIR") ?? "/tmp"
        #endif

        let temporaryDirectory = try File.Path(temporaryDirectoryString)
        let sanitizedKey = Path.sanitized(from: key)
        let trailing = try File.Path(prefix + sanitizedKey + suffix)
        return temporaryDirectory.appending(trailing)
    }
}
