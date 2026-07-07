//
//  File.System.Stat.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Kernel

extension File.System.Stat {
    /// Checks if the path is a regular file.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a regular file, `false` otherwise.
    public static func isFile(at path: borrowing File.Path) -> Bool {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try Self.info(at: path)
        } catch {
            return false
        }
        return info.type == .regular
    }

    /// Checks if the path is a directory.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a directory, `false` otherwise.
    public static func isDirectory(at path: borrowing File.Path) -> Bool {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try Self.info(at: path)
        } catch {
            return false
        }
        return info.type == .directory
    }

    /// Checks if the path is a symbolic link.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a symbolic link, `false` otherwise.
    public static func isSymlink(at path: borrowing File.Path) -> Bool {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try Self.info(at: path, followSymlinks: false)
        } catch {
            return false
        }
        return info.type == .symbolicLink
    }
}
