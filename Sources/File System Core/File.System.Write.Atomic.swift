import Binary
public import Kernel

extension File.System.Write {

    public enum Atomic {}
}

extension File.System.Write.Atomic {

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

extension File.System.Write.Atomic {

    public static func write<S: Binary.Serializable>(
        _ value: S,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try S.withSerializedBytes(value) {
            (span: borrowing Swift.Span<Byte>) throws(Error) in
            try write(span, to: path, options: options, createIntermediates: createIntermediates)
        }
    }
}

extension File.System.Write.Atomic {
    private static func ensureParent(
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
