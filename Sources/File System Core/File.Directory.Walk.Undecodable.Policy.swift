//
//  File.Directory.Walk.Undecodable.Policy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Walk.Undecodable {
    /// Policy for handling entries with undecodable names during directory walk.
    ///
    /// ## Semantics
    /// - `.skip`: Do NOT emit entry, do NOT descend into directory
    /// - `.emit`: Emit entry (with `.relative` location), do NOT descend into directory
    /// - `.stopAndThrow`: Stop the walk and throw an error with context
    ///
    /// ## Usage
    /// ```swift
    /// let options = File.Directory.Walk.Options(
    ///     onUndecodable: { context in
    ///         print("Found undecodable entry: \(context.name.debugDescription)")
    ///         return .emit  // Include it but don't descend
    ///     }
    /// )
    /// ```
    public enum Policy: Sendable {
        /// Skip entirely - do not emit, do not descend.
        ///
        /// The entry will not appear in walk results. If it's a directory,
        /// its contents will not be traversed.
        case skip

        /// Emit the entry with relative location, but do not descend.
        ///
        /// The entry will appear in walk results with a `.relative(parent:)` location.
        /// If it's a directory, its contents will not be traversed (since we cannot
        /// construct a valid path to descend into).
        case emit

        /// Stop the walk and throw an error.
        ///
        /// The walk will terminate immediately with an `undecodableEntry` error
        /// containing the parent path and raw name.
        case stopAndThrow
    }
}
