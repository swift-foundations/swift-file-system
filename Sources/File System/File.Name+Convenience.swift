//
//  File.Name+Convenience.swift
//  swift-file-system
//
//  Convenience copying initializers for File.Name bytes.
//

import File_System_Primitives

#if !os(Windows)
    extension [UInt8] {
        /// Creates a byte array by copying the file name's raw UTF-8 bytes.
        ///
        /// For zero-copy access, use `name.withUnsafeUTF8Bytes { }` instead.
        ///
        /// - Parameter fileName: The file name to copy bytes from.
        @inlinable
        public init(copying fileName: File.Name) {
            self = fileName.withUnsafeUTF8Bytes { buffer in
                Array(buffer)
            }
        }
    }
#endif

#if os(Windows)
    extension [UInt16] {
        /// Creates a code unit array by copying the file name's raw UTF-16 code units.
        ///
        /// For zero-copy access, use `name.withUnsafeCodeUnits { }` instead.
        ///
        /// - Parameter fileName: The file name to copy code units from.
        @inlinable
        public init(copying fileName: File.Name) {
            self = fileName.withUnsafeCodeUnits { buffer in
                Array(buffer)
            }
        }
    }
#endif
