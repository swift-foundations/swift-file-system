import ASCII
public import Paths
public import Strings

extension File.Path {

    public typealias Component = Paths.Path.Component
}

#if !os(Windows)
    extension File.Path.Component {

        @inlinable
        public init<Bytes: Swift.Sequence>(utf8 bytes: Bytes) throws(Paths.Path.Component.Error)
        where Bytes.Element == UInt8 {

            var collected: [UInt8] = []
            for byte in bytes {

                if byte == 0x2F || byte == 0x00 {
                    throw .containsPathSeparator
                }
                collected.append(byte)
            }

            guard !collected.isEmpty else { throw .empty }

            guard let string = Swift.String.strictUTF8(collected) else {
                throw .invalidUTF8
            }

            try self.init(string)
        }

        @inlinable
        public init(utf8 buffer: UnsafeBufferPointer<UInt8>) throws(Paths.Path.Component.Error) {
            guard !buffer.isEmpty else { throw .empty }

            if unsafe buffer.contains(where: { $0 == 0x2F || $0 == 0x00 }) {
                throw .containsPathSeparator
            }

            guard let string = unsafe Swift.String.strictUTF8(Array(buffer)) else {
                throw .invalidUTF8
            }

            try self.init(string)
        }
    }
#endif
