@_spi(Syscall) public import Kernel

extension File {

    public struct Descriptor: ~Copyable, Sendable {
        @usableFromInline
        internal var _descriptor: Kernel.Descriptor

        @usableFromInline
        internal init(__unchecked descriptor: consuming Kernel.Descriptor) {
            self._descriptor = descriptor
        }

    }
}

extension File.Descriptor {

    @inlinable
    public var kernelDescriptor: Kernel.Descriptor {
        _read { yield _descriptor }
    }

    #if os(Windows)

        public var rawHandle: Kernel.Descriptor.RawValue {
            _descriptor._rawValue
        }
    #else

        public var rawValue: Int32 {
            _descriptor._rawValue
        }
    #endif

    @inlinable
    public var isValid: Bool {
        _descriptor.isValid
    }
}

extension File.Descriptor {

    public static func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options = [.execClose]
    ) throws(Kernel.File.Open.Error) -> File.Descriptor {

        var descriptor: Kernel.Descriptor = .invalid
        try path.withKernelPath { kernelPath throws(Kernel.File.Open.Error) in
            descriptor = try Kernel.File.Open.open(
                path: kernelPath,
                mode: mode,
                options: options,
                permissions: Kernel.File.Permissions(rawValue: 0o644)
            )
        }
        return File.Descriptor(__unchecked: descriptor)
    }

    public consuming func close() throws(Kernel.Close.Error) {
        try Kernel.Close.close(_descriptor)
    }

    public init(
        duplicating other: borrowing File.Descriptor
    ) throws(Kernel.Descriptor.Duplicate.Error) {
        let newDescriptor = try Kernel.Descriptor.Duplicate.duplicate(other._descriptor)
        self.init(__unchecked: newDescriptor)
    }
}
