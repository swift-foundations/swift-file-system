//
//  File.Path.Component.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Path.Component {
    /// Errors that can occur during component construction.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// The component string is empty.
        case empty
        /// The component contains a path separator.
        case containsPathSeparator
        /// The component contains control characters.
        case containsControlCharacters
        /// The component is invalid.
        case invalid
    }
}
