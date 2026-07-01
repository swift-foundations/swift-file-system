//
//  File.System.IO.Error+Completion.swift
//  swift-file-system
//
//  Map Completion.Failure (proactor strategy-level error from swift-io)
//  onto File.System.IO.Error (file-system domain error).
//

#if !os(Windows)

    public import IO

    extension Completion.Failure {
        /// Map a proactor failure onto ``File/System/IO/Error``.
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
