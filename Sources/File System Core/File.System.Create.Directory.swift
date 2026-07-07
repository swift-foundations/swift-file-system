//
//  File.System.Create.Directory.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Kernel

extension File.System.Create {
    /// Create new directories.
    public enum Directory {}
}

// MARK: - Core API

extension File.System.Create.Directory {
    /// Creates a directory at the specified path.
    ///
    /// - Parameters:
    ///   - path: The path where the directory should be created.
    ///   - options: Creation options, such as permissions.
    ///   - createIntermediates: If `true`, creates intermediate directories as needed.
    /// - Throws: `File.System.Create.Directory.Error` on failure.
    public static func create(
        at path: borrowing File.Path,
        options: Options = .init(),
        createIntermediates: Bool = false
    ) throws(Self.Error) {
        let permissions = Kernel.File.Permissions(
            rawValue: options.permissions?.rawValue ?? File.System.Metadata.Permissions.defaultDirectory.rawValue
        )

        if createIntermediates {
            try Self.createIntermediates(at: path, permissions: permissions)
        } else {
            try mkdir(at: path, permissions: permissions)
        }
    }

    /// Creates a single directory using Kernel.Directory.Create.
    private static func mkdir(
        at path: File.Path,
        permissions: Kernel.File.Permissions
    ) throws(Self.Error) {
        do throws(Kernel.Directory.Create.Error) {
            try Kernel.Directory.Create.create(path.kernelPath, permissions: permissions)
        } catch {
            throw .mkdir(error)
        }
    }

    /// Creates a directory and all intermediate directories.
    private static func createIntermediates(
        at path: File.Path,
        permissions: Kernel.File.Permissions
    ) throws(Self.Error) {
        // Check if directory already exists
        let existsAsDirectory: Bool
        do throws(Kernel.File.Stats.Error) {
            let stats = try Kernel.File.Stats.get(path: path.kernelPath)
            existsAsDirectory = stats.type == .directory
        } catch {
            // Path doesn't exist or error occurred, that's fine
            existsAsDirectory = false
        }

        if existsAsDirectory {
            return  // Already exists as directory - success
        }

        // Try to create parent directory first
        if let parentPath = path.parent {
            try createIntermediates(at: parentPath, permissions: permissions)
        }

        // Now create this directory
        do throws(Kernel.Directory.Create.Error) {
            try Kernel.Directory.Create.create(path.kernelPath, permissions: permissions)
        } catch {
            // Check if it was created by another process/thread in the meantime
            if case .exists = error {
                let isDir: Bool
                do throws(Kernel.File.Stats.Error) {
                    let stats = try Kernel.File.Stats.get(path: path.kernelPath)
                    isDir = stats.type == .directory
                } catch {
                    isDir = false
                }
                if isDir {
                    return
                }
            }
            throw .mkdir(error)
        }
    }
}
