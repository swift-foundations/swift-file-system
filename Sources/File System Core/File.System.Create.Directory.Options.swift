//
//  File.System.Create.Directory.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Create.Directory {
    /// Options for directory creation.
    public struct Options: Sendable {
        /// Permissions for the new directory.
        public var permissions: File.System.Metadata.Permissions?

        public init(
            permissions: File.System.Metadata.Permissions? = nil
        ) {
            self.permissions = permissions
        }
    }
}
