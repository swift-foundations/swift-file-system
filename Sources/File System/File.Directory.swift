//
//  File.Directory.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Subscript Access

extension File.Directory {
    /// Access a file in this directory.
    ///
    /// - Parameter name: The file name.
    /// - Returns: A file for the named file.
    public subscript(_ name: String) -> File {
        File(path.appending(name))
    }

    /// Access a file in this directory (labeled).
    ///
    /// ## Example
    /// ```swift
    /// let readme = dir[file: "README.md"]
    /// ```
    ///
    /// - Parameter name: The file name.
    /// - Returns: A file for the named file.
    public subscript(file name: String) -> File {
        File(path.appending(name))
    }

    /// Access a subdirectory (labeled).
    ///
    /// ## Example
    /// ```swift
    /// let src = dir[directory: "src"]
    /// let nested = dir[directory: "src"][file: "main.swift"]
    /// ```
    ///
    /// - Parameter name: The subdirectory name.
    /// - Returns: A directory for the named subdirectory.
    public subscript(directory name: String) -> File.Directory {
        File.Directory(path.appending(name))
    }

    /// Access a subdirectory.
    ///
    /// - Parameter name: The subdirectory name.
    /// - Returns: A directory for the named subdirectory.
    public func subdirectory(_ name: String) -> File.Directory {
        File.Directory(path.appending(name))
    }
}

// MARK: - Path Navigation

extension File.Directory {
    /// The parent directory, or `nil` if this is a root path.
    public var parent: File.Directory? {
        path.parent.map(File.Directory.init)
    }

    /// The directory name (last component of the path).
    public var name: String {
        path.lastComponent.map { String($0) } ?? ""
    }

    /// Returns a new directory with the given component appended.
    ///
    /// - Parameter component: The component to append.
    /// - Returns: A new directory with the appended path.
    public func appending(_ component: String) -> File.Directory {
        File.Directory(path.appending(component))
    }

    /// Appends a component to a directory.
    ///
    /// - Parameters:
    ///   - lhs: The base directory.
    ///   - rhs: The component to append.
    /// - Returns: A new directory with the appended path.
    public static func / (lhs: File.Directory, rhs: String) -> File.Directory {
        lhs.appending(rhs)
    }
}

// MARK: - CustomStringConvertible

extension File.Directory: CustomStringConvertible {
    public var description: String {
        String(path)
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Directory: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Directory(\(String(path).debugDescription))"
    }
}
