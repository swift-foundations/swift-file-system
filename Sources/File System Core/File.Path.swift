import Environment
import Kernel
public import Paths
import Strings

extension File {

    public typealias Path = Paths.Path
}

extension File.Path {

    @usableFromInline
    package init(__unchecked: Void, _ path: Paths.Path) {
        self = path
    }

    @usableFromInline
    package init(__unchecked: Void, _ string: Swift.String) {
        self = Paths.Path(stringLiteral: string)
    }

    @usableFromInline
    package var parentOrSelf: Paths.Path {
        parent ?? self
    }
}

#if !os(Windows)

    extension File.Path {

        @usableFromInline
        internal init(cString: UnsafePointer<CChar>) {
            let string = unsafe Swift.String(cString: cString)
            self = Paths.Path(stringLiteral: string)
        }
    }

#endif
