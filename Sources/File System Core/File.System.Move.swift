//
//  File.System.Move.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System {
    /// Namespace for file move/rename operations.
    public enum Move {}
}

// MARK: - Options

extension File.System.Move {
    /// Options for move operations.
    public struct Options: Sendable {
        /// Overwrite existing destination.
        public var overwrite: Bool

        public init(overwrite: Bool = false) {
            self.overwrite = overwrite
        }
    }
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Move {
    /// Errors that can occur during move operations.
    ///
    /// This is a union of the kernel errors that the move operation can produce.
    /// Use semantic accessors like `isSourceNotFound` or `isPermissionDenied` for common checks,
    /// or match on specific cases for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Destination exists when overwrite is disabled (pre-check).
        case destinationExists(File.Path)
        /// Error from rename operation.
        case rename(Kernel.File.Move.Error)
        /// Error from copy operation (cross-device fallback).
        case copy(File.System.Copy.Error)
        /// Error from cleanup after successful copy (cross-device).
        case cleanup(Kernel.File.Delete.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Move.Error {
    /// Returns `true` if the error indicates the source was not found.
    public var isSourceNotFound: Bool {
        switch self {
        case .destinationExists:
            return false
        case .rename(let e):
            return e == .notFound
        case .copy(let e):
            if case .sourceNotFound = e { return true }
            return false
        case .cleanup:
            return false
        }
    }

    /// Returns `true` if the error indicates the destination already exists.
    public var isDestinationExists: Bool {
        switch self {
        case .destinationExists:
            return true
        case .rename:
            return false
        case .copy(let e):
            if case .destinationExists = e { return true }
            return false
        case .cleanup:
            return false
        }
    }

    /// Returns `true` if the error indicates permission was denied.
    public var isPermissionDenied: Bool {
        switch self {
        case .destinationExists:
            return false
        case .rename(let e):
            return e == .permission
        case .copy(let e):
            if case .permissionDenied = e { return true }
            return false
        case .cleanup(let e):
            if case .permission = e { return true }
            return false
        }
    }

    /// Returns `true` if the error indicates a cross-device move.
    public var isCrossDevice: Bool {
        switch self {
        case .rename(let e):
            return e == .crossDevice
        default:
            return false
        }
    }

    /// Returns `true` if the source path is a directory.
    public var isDirectory: Bool {
        switch self {
        case .rename(let e):
            return e == .isDirectory
        case .copy(let e):
            if case .isDirectory = e { return true }
            return false
        default:
            return false
        }
    }
}

// MARK: - Core API

extension File.System.Move {
    /// Moves (renames) a file from source to destination with options.
    ///
    /// - Parameters:
    ///   - source: The source file path.
    ///   - destination: The destination file path.
    ///   - options: Move options.
    /// - Throws: `File.System.Move.Error` on failure.
    public static func move(
        from source: borrowing File.Path,
        to destination: borrowing File.Path,
        options: borrowing Options = .init()
    ) throws(File.System.Move.Error) {
        // Check if destination exists (when overwrite is disabled)
        if !options.overwrite {
            let destExists = (try? Kernel.File.Stats.get(path: destination.kernelPath)) != nil
            if destExists {
                throw .destinationExists(copy destination)
            }
        }

        // Try rename
        do throws(Kernel.File.Move.Error) {
            try Kernel.File.Move.move(from: source.kernelPath, to: destination.kernelPath)
        } catch {
            // If cross-device, fall back to copy+delete
            if case .crossDevice = error {
                try copyAndDelete(from: source, to: destination, options: options)
                return
            }
            throw .rename(error)
        }
    }

    /// Fallback: copy then delete for cross-device moves.
    private static func copyAndDelete(
        from source: File.Path,
        to destination: File.Path,
        options: Options
    ) throws(File.System.Move.Error) {
        // Use Copy to copy the file
        let copyOptions = File.System.Copy.Options(
            overwrite: options.overwrite,
            copyAttributes: true,
            followSymlinks: true
        )

        do {
            try File.System.Copy.copy(from: source, to: destination, options: copyOptions)
        } catch let copyError {
            throw .copy(copyError)
        }

        // Delete source — cleanup failure after successful copy is a soft failure.
        // The data is at the destination, but source still exists.
        do throws(Kernel.File.Delete.Error) {
            try Kernel.File.Delete.delete(source.kernelPath)
        } catch {
            throw .cleanup(error)
        }
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Move.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .destinationExists(let path):
            return "Destination already exists: \(path)"
        case .rename(let error):
            return "Rename failed: \(error)"
        case .copy(let error):
            return "Copy failed (cross-device): \(error)"
        case .cleanup(let error):
            return "Source cleanup failed after copy: \(error)"
        }
    }
}
