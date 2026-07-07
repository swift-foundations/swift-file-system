//
//  File.Descriptor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

@_spi(Syscall) public import Kernel

extension File {
    /// A low-level file descriptor wrapper.
    ///
    /// `File.Descriptor` is a non-copyable type that owns a file descriptor
    /// and ensures it is properly closed when the descriptor goes out of scope.
    ///
    /// This is the core primitive for file I/O. Higher-level types like
    /// `File.Handle` build on top of this.
    ///
    /// ## Example
    /// ```swift
    /// let descriptor = try File.Descriptor.open(path, mode: .read)
    /// // use descriptor...
    /// try descriptor.close()
    /// ```
    /// An owning file descriptor wrapper.
    ///
    /// Sendable because the underlying fd/HANDLE is just a number.
    /// ~Copyable enforces single-ownership (prevents double-close).
    /// For cross-task usage, move into an actor or use `duplicated()`.
    public struct Descriptor: ~Copyable, Sendable {
        @usableFromInline
        internal var _descriptor: Kernel.Descriptor

        /// Creates a descriptor from a Kernel.Descriptor.
        @usableFromInline
        internal init(__unchecked descriptor: consuming Kernel.Descriptor) {
            self._descriptor = descriptor
        }

    }
}

// MARK: - Properties

extension File.Descriptor {
    /// The underlying Kernel.Descriptor.
    @inlinable
    public var kernelDescriptor: Kernel.Descriptor {
        _read { yield _descriptor }
    }

    #if os(Windows)
        /// The raw Windows HANDLE, or INVALID_HANDLE_VALUE if closed.
        public var rawHandle: Kernel.Descriptor.RawValue {
            _descriptor._rawValue
        }
    #else
        /// The raw POSIX file descriptor, or -1 if closed.
        public var rawValue: Int32 {
            _descriptor._rawValue
        }
    #endif

    /// Whether this descriptor is valid (not closed).
    @inlinable
    public var isValid: Bool {
        _descriptor.isValid
    }
}

// MARK: - Core API

extension File.Descriptor {
    /// Opens a file and returns a descriptor.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode (use `Kernel.File.Open.Mode`).
    ///   - options: Additional options (use `Kernel.File.Open.Options`).
    /// - Returns: A file descriptor.
    /// - Throws: `Kernel.File.Open.Error` on failure.
    public static func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options = [.execClose]
    ) throws(Kernel.File.Open.Error) -> File.Descriptor {
        let descriptor = try Kernel.File.Open.open(
            path: path.kernelPath,
            mode: mode,
            options: options,
            permissions: Kernel.File.Permissions(rawValue: 0o644)
        )
        return File.Descriptor(__unchecked: descriptor)
    }

    /// Closes the file descriptor.
    ///
    /// After calling this method, the descriptor is invalid and cannot be used.
    /// The descriptor is consumed regardless of whether close succeeds or fails,
    /// preventing double-close scenarios.
    ///
    /// - Throws: `Kernel.Close.Error` on failure.
    public consuming func close() throws(Kernel.Close.Error) {
        try Kernel.Close.close(_descriptor)
    }

    /// Creates a file descriptor by duplicating another.
    ///
    /// Creates a new file descriptor that refers to the same open file.
    /// Both descriptors can be used independently and must be closed separately.
    ///
    /// ## Example
    /// ```swift
    /// let original = try File.Descriptor.open(path, mode: .read)
    /// let duplicate = try File.Descriptor(duplicating: original)
    /// // Both can be used independently
    /// ```
    ///
    /// - Parameter other: The file descriptor to duplicate.
    /// - Throws: `Kernel.Descriptor.Duplicate.Error` on failure.
    public init(duplicating other: borrowing File.Descriptor) throws(Kernel.Descriptor.Duplicate.Error) {
        let newDescriptor = try Kernel.Descriptor.Duplicate.duplicate(other._descriptor)
        self.init(__unchecked: newDescriptor)
    }
}
