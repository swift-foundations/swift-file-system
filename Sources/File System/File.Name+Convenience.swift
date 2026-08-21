import File_System_Core

extension [UInt8] {

    @available(
        *,
        deprecated,
        message:
            "Use `name.withCodeUnits { span in Array(span) }` (POSIX) for cross-platform zero-copy access; this POSIX-only allocating convenience is superseded."
    )
    @inlinable
    public init?(copying fileName: File.Name) {
        #if os(Windows)
            return nil
        #else
            self = fileName.rawBytes
        #endif
    }
}

extension [UInt16] {

    @available(
        *,
        deprecated,
        message:
            "Use `name.withCodeUnits { span in Array(span) }` (Windows) for cross-platform zero-copy access; this Windows-only allocating convenience is superseded."
    )
    @inlinable
    public init?(copying fileName: File.Name) {
        #if os(Windows)
            self = fileName.rawBytes
        #else
            return nil
        #endif
    }
}
