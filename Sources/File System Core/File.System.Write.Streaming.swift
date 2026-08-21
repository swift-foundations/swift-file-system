public import Kernel

extension File.System.Write {

    public enum Streaming {}
}

extension File.System.Write.Streaming {

    public static func write<Chunks: Swift.Sequence>(
        _ chunks: Chunks,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) where Chunks.Element == [Byte] {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(chunks, to: kernelPath, options: options)
        }
    }
}

extension File.System.Write.Streaming {

    @inlinable
    public static func write(
        _ bytes: [Byte],
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(bytes, to: kernelPath, options: options)
        }
    }

    @inlinable
    public static func write(
        _ bytes: ArraySlice<Byte>,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)

        var capturedError: Self.Error? = nil

        let wasContiguous = bytes.withContiguousStorageIfAvailable { buffer -> Bool in
            do throws(Error) {

                var contextStorage: Context? = nil
                try path.withKernelPath { kernelPath throws(Error) in
                    contextStorage = try Self.open(path: kernelPath, options: options)
                }
                let context = contextStorage.take()!
                var succeeded = false
                defer {
                    if !succeeded {
                        Self.cleanup(context)
                    }
                }
                let rawBuffer = UnsafeRawBufferPointer(buffer)
                try unsafe Self.write(chunk: rawBuffer, to: context)
                try Self.commit(context)
                succeeded = true
            } catch {
                capturedError = error
            }
            return true
        }

        if let error = capturedError {
            throw error
        }

        if wasContiguous != nil {
            return
        }

        try write(Array(bytes), to: path, options: options)
    }

    @inlinable
    public static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(bytes, to: kernelPath, options: options)
        }
    }
}

extension File.System.Write.Streaming {

    public static func write<E: Swift.Error>(
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false,
        using buffer: inout [Byte],
        fill: (inout [Byte]) throws(E) -> Int
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(to: kernelPath, options: options, using: &buffer, fill: fill)
        }
    }
}

extension File.System.Write.Streaming {

    public static func open(
        path: borrowing File.Path,
        options: Options,
        createIntermediates: Bool = false
    ) throws(Error) -> Context {
        try ensureParent(for: path, createIntermediates: createIntermediates)

        var contextStorage: Context? = nil
        try path.withKernelPath { kernelPath throws(Error) in
            contextStorage = try Self.open(path: kernelPath, options: options)
        }
        return contextStorage.take()!
    }

}

extension File.System.Write.Streaming {
    @usableFromInline
    internal static func ensureParent(
        for path: borrowing File.Path,
        createIntermediates: Bool
    ) throws(Error) {
        guard createIntermediates else { return }
        let parent = path.parentOrSelf
        do throws(File.System.Parent.Check.Error) {
            try File.System.Parent.Check.verify(parent, createIntermediates: true)
        } catch {
            throw .parentVerificationFailed(
                path: parent,
                code: ._notFound,
                message: "\(error)"
            )
        }
    }
}
