public import Glob
public import IO

extension File.Directory {

    public struct Glob: Sendable {

        @usableFromInline
        let directory: File.Directory

        @usableFromInline
        internal init(_ directory: File.Directory) {
            self.directory = directory
        }
    }
}

extension File.Directory {

    public var glob: Glob {
        Glob(self)
    }
}

extension File.Directory.Glob {

    @inlinable
    package func matchPaths(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern],
        options: Glob.Options
    ) throws(Glob.Error) -> [Swift.String] {
        var results: [Swift.String] = []
        try directory.path.withKernelPath { kernelPath throws(Glob.Error) in
            try Glob.match(
                include: include,
                excluding: excluding,
                in: kernelPath,
                options: options
            ) { results.append($0) }
        }

        return results
    }

    @inlinable
    package func matchPaths(
        include: [Swift.String],
        excluding: [Swift.String],
        options: Glob.Options
    ) throws(Glob.Error) -> [Swift.String] {
        var includePatterns: [Glob.Pattern] = []
        for pattern in include {
            includePatterns.append(try Glob.Pattern(pattern))
        }

        var excludePatterns: [Glob.Pattern] = []
        for pattern in excluding {
            excludePatterns.append(try Glob.Pattern(pattern))
        }

        return try matchPaths(
            include: includePatterns,
            excluding: excludePatterns,
            options: options
        )
    }
}
