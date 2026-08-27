public import Binary
public import Kernel

extension Binary.Serializable {

    public func write(
        to path: File.Path,
        options: File.System.Write.Atomic.Options = .init(),
        createIntermediates: Bool = false
    ) throws(File.System.Write.Atomic.Error) {
        try File.System.Write.Atomic.write(
            self,
            to: path,
            options: options,
            createIntermediates: createIntermediates
        )
    }

    public func write(
        to file: File,
        options: File.System.Write.Atomic.Options = .init(),
        createIntermediates: Bool = false
    ) throws(File.System.Write.Atomic.Error) {
        try write(to: file.path, options: options, createIntermediates: createIntermediates)
    }
}
