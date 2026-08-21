internal import Error_Primitives

extension Error_Primitives.Error.Code {

    internal static var _io: Self {
        #if os(Windows)
            .win32(1117)
        #else
            .POSIX.EIO
        #endif
    }

    internal static var _notFound: Self {
        #if os(Windows)
            .Windows.ERROR_FILE_NOT_FOUND
        #else
            .POSIX.ENOENT
        #endif
    }

    internal static var _invalid: Self {
        #if os(Windows)
            .Windows.ERROR_INVALID_PARAMETER
        #else
            .POSIX.EINVAL
        #endif
    }

    internal static var _accessDenied: Self {
        #if os(Windows)
            .Windows.ERROR_ACCESS_DENIED
        #else
            .POSIX.EACCES
        #endif
    }

    internal static var _exists: Self {
        #if os(Windows)
            .Windows.ERROR_FILE_EXISTS
        #else
            .POSIX.EEXIST
        #endif
    }
}
