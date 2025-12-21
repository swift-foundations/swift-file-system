//
//  File.Descriptor.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Descriptor {
    /// Errors that can occur during descriptor operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case isDirectory(File.Path)
        case tooManyOpenFiles
        case invalidDescriptor
        case openFailed(errno: Int32, message: String)
        case closeFailed(errno: Int32, message: String)
        case duplicateFailed(errno: Int32, message: String)
        case alreadyClosed
    }
}
