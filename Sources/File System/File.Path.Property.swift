//
//  File.Path.Property.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Path {
    /// A property that can be modified on a path.
    ///
    /// Generic over the value type to ensure type-safe property modification.
    ///
    /// ## Example
    /// ```swift
    /// // Built-in properties
    /// path.with(.extension, "txt")
    /// path.removing(.extension)
    /// path.with(.lastComponent, "config.json")
    /// ```
    public struct Property<Value: Sendable>: Sendable {
        /// Sets the property to a new value.
        public let set: @Sendable (File.Path, Value) -> File.Path

        /// Removes the property from the path.
        public let remove: @Sendable (File.Path) -> File.Path

        /// Creates a new property.
        public init(
            set: @escaping @Sendable (File.Path, Value) -> File.Path,
            remove: @escaping @Sendable (File.Path) -> File.Path
        ) {
            self.set = set
            self.remove = remove
        }
    }

    // MARK: - Modification

    /// Returns path with property set to value.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/tmp/data.json"
    /// let txt = path.with(.extension, "txt")  // /tmp/data.txt
    /// let renamed = path.with(.lastComponent, "config.json")  // /tmp/config.json
    /// ```
    @inlinable
    public func with<Value: Sendable>(_ property: Property<Value>, _ value: Value) -> Self {
        property.set(self, value)
    }

    /// Returns path with property removed.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/tmp/data.json"
    /// let noExt = path.removing(.extension)  // /tmp/data
    /// ```
    @inlinable
    public func removing<Value: Sendable>(_ property: Property<Value>) -> Self {
        property.remove(self)
    }
}

// MARK: - Built-in Properties

extension File.Path.Property where Value == File.Path.Component.Extension {
    /// The file extension.
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
    /// The last path component (filename or directory name).
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
