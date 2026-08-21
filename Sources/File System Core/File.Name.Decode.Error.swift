import Strings

extension File.Name.Decode {

    public struct Error: Swift.Error, Sendable, Equatable {

        public let name: File.Name

        public init(name: File.Name) {
            self.name = name
        }
    }
}

extension File.Name.Decode.Error: CustomStringConvertible {
    public var description: Swift.String {
        "File.Name.Decode.Error: \(Swift.String(describing: name))"
    }
}

extension File.Name.Decode.Error {

    public var debugRawBytes: Swift.String {
        name.rawBytes.platformNativeHex(uppercase: true)
    }
}
