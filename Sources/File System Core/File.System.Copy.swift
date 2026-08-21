public import Kernel

extension File.System {

    public enum Copy {}
}

extension File.System.Copy {

    public typealias Options = Kernel.File.Copy.Options

    public typealias Error = Kernel.File.Copy.Error
}

extension File.System.Copy {

    public static func copy(
        from source: borrowing File.Path,
        to destination: borrowing File.Path,
        options: Options = .init()
    ) throws(Error) {
        try source.withKernelPath { sourceKernelPath throws(Error) in
            try destination.withKernelPath { destinationKernelPath throws(Error) in
                try Kernel.File.Copy.copy(
                    from: sourceKernelPath,
                    to: destinationKernelPath,
                    options: options
                )
            }
        }
    }
}
