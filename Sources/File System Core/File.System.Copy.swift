//
//  File.System.Copy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System {
    /// Namespace for file copy operations.
    ///
    /// Delegates to `Kernel.File.Copy` for all copy functionality.
    public enum Copy {}
}

// MARK: - Type Aliases

extension File.System.Copy {
    /// Options for copy operations.
    ///
    /// Re-exports `Kernel.File.Copy.Options`.
    public typealias Options = Kernel.File.Copy.Options

    /// Errors that can occur during copy operations.
    ///
    /// Re-exports `Kernel.File.Copy.Error`.
    public typealias Error = Kernel.File.Copy.Error
}

// MARK: - Core API

extension File.System.Copy {
    /// Copies a file from source to destination with options.
    ///
    /// - Parameters:
    ///   - source: The source file path.
    ///   - destination: The destination file path.
    ///   - options: Copy options.
    /// - Throws: `Kernel.File.Copy.Error` on failure.
    public static func copy(
        from source: borrowing File.Path,
        to destination: borrowing File.Path,
        options: Options = .init()
    ) throws(Error) {
        try Kernel.File.Copy.copy(from: source.kernelPath, to: destination.kernelPath, options: options)
    }
}
