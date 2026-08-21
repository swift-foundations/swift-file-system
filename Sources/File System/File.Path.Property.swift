extension File.Path {

    public struct Property<Value: Sendable>: Sendable {

        public let set: @Sendable (File.Path, Value) -> File.Path

        public let remove: @Sendable (File.Path) -> File.Path

        public init(
            set: @escaping @Sendable (File.Path, Value) -> File.Path,
            remove: @escaping @Sendable (File.Path) -> File.Path
        ) {
            self.set = set
            self.remove = remove
        }
    }

    @inlinable
    public func with<Value: Sendable>(_ property: Property<Value>, _ value: Value) -> Self {
        property.set(self, value)
    }

    @inlinable
    public func removing<Value: Sendable>(_ property: Property<Value>) -> Self {
        property.remove(self)
    }
}

extension File.Path.Property where Value == File.Path.Component.Extension {

    public static var `extension`: Self {
        Self(
            set: { path, value in
                var copy = path
                copy.extension = value
                return copy
            },
            remove: { path in
                var copy = path
                copy.extension = nil
                return copy
            }
        )
    }
}

extension File.Path.Property where Value == File.Path.Component {

    public static var lastComponent: Self {
        Self(
            set: { path, value in
                guard let parent = path.parent else {
                    return Paths.Path(stringLiteral: value.string)
                }
                return parent / value
            },
            remove: { path in
                path.parent ?? path
            }
        )
    }
}
