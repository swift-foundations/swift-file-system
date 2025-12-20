//
//  File.System.Write.Atomic.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic {
    /// Options controlling atomic write behavior.
    public struct Options: Sendable {
        public var strategy: Strategy
        public var durability: Durability
        public var preservePermissions: Bool
        public var preserveOwnership: Bool
        public var strictOwnership: Bool
        public var preserveTimestamps: Bool
        public var preserveExtendedAttributes: Bool
        public var preserveACLs: Bool
        /// Create intermediate directories if they don't exist.
        ///
        /// When enabled, missing parent directories are created before writing.
        /// Note: Creating intermediates may traverse symlinks in path components.
        /// This is not hardened against symlink-based attacks.
        public var createIntermediates: Bool

        public init(
            strategy: Strategy = .replaceExisting,
            durability: Durability = .full,
            preservePermissions: Bool = true,
            preserveOwnership: Bool = false,
            strictOwnership: Bool = false,
            preserveTimestamps: Bool = false,
            preserveExtendedAttributes: Bool = false,
            preserveACLs: Bool = false,
            createIntermediates: Bool = false
        ) {
            self.strategy = strategy
            self.durability = durability
            self.preservePermissions = preservePermissions
            self.preserveOwnership = preserveOwnership
            self.strictOwnership = strictOwnership
            self.preserveTimestamps = preserveTimestamps
            self.preserveExtendedAttributes = preserveExtendedAttributes
            self.preserveACLs = preserveACLs
            self.createIntermediates = createIntermediates
        }
    }
}
