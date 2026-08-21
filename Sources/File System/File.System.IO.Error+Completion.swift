#if !os(Windows)

    public import IO

    extension Completion.Failure {

        @usableFromInline
        package var fileSystemError: File.System.IO.Error {
            switch self {
            case .cancelled:
                return .cancelled

            case .invalidDescriptor:
                return .platform(.POSIX.EBADF)

            case .tooManyOpen:
                return .platform(.POSIX.EMFILE)

            case .platform(let code):
                return .platform(code)

            case .kernel:
                return .platform(.POSIX.EIO)
            }
        }
    }

#endif
