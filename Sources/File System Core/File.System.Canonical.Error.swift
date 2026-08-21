public import Path_Primitives

extension File.System.Canonical {

    public enum Error: Swift.Error, Sendable, Equatable {

        case resolution(Path_Primitives.Path.Canonical.Error)

        case representation(File.Path.Error)
    }
}

extension File.System.Canonical.Error {

    public var isNotFound: Bool {
        if case .resolution(.path(.notFound)) = self {
            return true
        }
        return false
    }

    public var isLoop: Bool {
        if case .resolution(.path(.loop)) = self {
            return true
        }
        return false
    }
}

extension File.System.Canonical.Error: CustomStringConvertible {

    public var description: Swift.String {
        switch self {
        case .resolution(let error):
            return "Path canonicalization failed: \(error)"

        case .representation(let error):
            return "Canonical path cannot be represented: \(error)"
        }
    }
}
