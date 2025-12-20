//
//  String+DirectoryEntryName.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

// MARK: - POSIX d_name

#if !os(Windows)
    extension String {
        /// Creates a string from a POSIX directory entry name (d_name).
        ///
        /// The `d_name` field in `dirent` is a fixed-size C character array.
        /// This initializer safely extracts the name using bounded access.
        ///
        /// ## Memory Safety
        /// Uses `MemoryLayout.size(ofValue:)` to determine actual buffer size,
        /// then finds the NUL terminator within that bound. Never reads past
        /// the buffer.
        ///
        /// ## Encoding Policy
        /// Uses lossy UTF-8 decoding. Invalid UTF-8 sequences are replaced with
        /// the Unicode replacement character (U+FFFD). This means path round-tripping
        /// is not guaranteed for filenames containing invalid UTF-8.
        @usableFromInline
        internal init<T>(posixDirectoryEntryName dName: T) {
            self = withUnsafePointer(to: dName) { ptr in
                // Get actual buffer size from the type, not NAME_MAX
                let bufferSize = MemoryLayout<T>.size

                return ptr.withMemoryRebound(to: UInt8.self, capacity: bufferSize) { bytes in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < bufferSize && bytes[length] != 0 {
                        length += 1
                    }

                    // Create buffer view up to NUL (or end of buffer)
                    let buffer = UnsafeBufferPointer(start: bytes, count: length)

                    // Lossy UTF-8 decode - invalid sequences become U+FFFD
                    return String(decoding: buffer, as: UTF8.self)
                }
            }
        }
    }
#endif

// MARK: - Windows cFileName

#if os(Windows)
    extension String {
        /// Creates a string from a Windows directory entry name (cFileName).
        ///
        /// The `cFileName` field in `WIN32_FIND_DATAW` is a fixed-size wide character array.
        /// This initializer safely extracts the name using bounded access.
        ///
        /// ## Memory Safety
        /// Uses `MemoryLayout.size(ofValue:)` to determine actual buffer size,
        /// then finds the NUL terminator within that bound. Never reads past
        /// the buffer.
        ///
        /// ## Encoding Policy
        /// Uses lossy UTF-16 decoding. Invalid UTF-16 sequences (e.g., lone surrogates)
        /// are replaced with the Unicode replacement character (U+FFFD). This means
        /// path round-tripping is not guaranteed for filenames containing invalid UTF-16.
        @usableFromInline
        internal init<T>(windowsDirectoryEntryName cFileName: T) {
            self = withUnsafePointer(to: cFileName) { ptr in
                // Get actual buffer size from the type, not MAX_PATH
                let bufferSize = MemoryLayout<T>.size
                let elementCount = bufferSize / MemoryLayout<UInt16>.size

                return ptr.withMemoryRebound(to: UInt16.self, capacity: elementCount) { wchars in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < elementCount && wchars[length] != 0 {
                        length += 1
                    }

                    // Create buffer view up to NUL (or end of buffer)
                    let buffer = UnsafeBufferPointer(start: wchars, count: length)

                    // Lossy UTF-16 decode - invalid sequences become U+FFFD
                    return String(decoding: buffer, as: UTF16.self)
                }
            }
        }
    }
#endif
