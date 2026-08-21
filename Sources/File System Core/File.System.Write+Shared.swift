import Kernel

extension File.System.Write {
    internal static func resolvePaths(
        _ path: File.Path
    ) -> (resolved: File.Path, parent: File.Path) {
        (path, path.parent ?? ".")
    }

    internal static func fileName(of path: File.Path) -> File.Path.Component? {
        path.components.last
    }
}

extension File.System.Write {
    internal static func fileExists(_ path: File.Path) -> Bool {
        do throws(Kernel.File.Stats.Error) {
            _ = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.lget(path: kernelPath)
            }
            return true
        } catch {
            return false
        }
    }
}

extension File.System.Write {
    internal static func randomToken(
        length: Int
    ) throws(Self.Error) -> Swift.String {
        try unsafe withUnsafeTemporaryAllocation(
            of: UInt8.self,
            capacity: length
        ) { buffer throws(Self.Error) -> Swift.String in
            let rawBuffer = UnsafeMutableRawBufferPointer(buffer)
            do throws(Random.Error) {
                try unsafe Random.fill(rawBuffer)
            } catch {
                throw .random("CSPRNG syscall failed: \(error)")
            }
            return unsafe hexEncode(Array(buffer).map(Byte.init))
        }
    }

    internal static func hexEncode(_ bytes: [Byte]) -> Swift.String {
        let hexChars: [Character] = [
            "0", "1", "2", "3", "4", "5", "6", "7",
            "8", "9", "a", "b", "c", "d", "e", "f",
        ]
        var result = Swift.String()
        result.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            let raw = byte.underlying
            result.append(hexChars[Int(raw >> 4)])
            result.append(hexChars[Int(raw & 0x0F)])
        }
        return result
    }
}

extension File.System.Write {

    internal static func writeAll(
        _ span: borrowing Swift.Span<Byte>,
        to fd: borrowing Kernel.Descriptor
    ) throws(Self.Error) {
        let total = span.count
        if total == 0 { return }

        var written = 0

        try span.withUnsafeBufferPointer { buffer throws(Self.Error) in
            guard let base = buffer.baseAddress else { return }

            while written < total {
                let slice = unsafe UnsafeRawBufferPointer(
                    start: base.advanced(by: written),
                    count: total - written
                )

                do {
                    let rc = unsafe try Kernel.IO.Write.write(fd, from: slice)
                    if rc > 0 {
                        written += rc
                        continue
                    }
                    if rc == 0 {
                        throw Self.Error.write(
                            written: written,
                            expected: total,
                            "write returned 0"
                        )
                    }
                } catch let error as Kernel.IO.Write.Error {
                    if case .blocking(.wouldBlock) = error { continue }
                    throw Self.Error.write(
                        written: written,
                        expected: total,
                        "write failed: \(error)"
                    )
                } catch let error as Self.Error {
                    throw error
                } catch {
                    throw Self.Error.write(
                        written: written,
                        expected: total,
                        "write failed: \(error)"
                    )
                }
            }
        }
    }

    internal static func writeAllRaw(
        _ buffer: UnsafeRawBufferPointer,
        to fd: borrowing Kernel.Descriptor
    ) throws(Self.Error) {
        let total = buffer.count
        if total == 0 { return }

        guard let base = buffer.baseAddress else { return }

        var written = 0

        while written < total {
            let slice = unsafe UnsafeRawBufferPointer(
                start: base.advanced(by: written),
                count: total - written
            )

            do {
                let rc = unsafe try Kernel.IO.Write.write(fd, from: slice)
                if rc > 0 {
                    written += rc
                    continue
                }
                if rc == 0 {
                    throw Self.Error.write(
                        written: written,
                        expected: total,
                        "write returned 0"
                    )
                }
            } catch let error as Kernel.IO.Write.Error {
                if case .blocking(.wouldBlock) = error { continue }
                throw Self.Error.write(
                    written: written,
                    expected: total,
                    "write failed: \(error)"
                )
            } catch let error as Self.Error {
                throw error
            } catch {
                throw Self.Error.write(
                    written: written,
                    expected: total,
                    "write failed: \(error)"
                )
            }
        }
    }
}

extension File.System.Write {

    internal static func syncFile(
        _ fd: borrowing Kernel.Descriptor,
        durability: File.System.Write.Durability
    ) throws(Self.Error) {
        switch durability {
        case .full:
            do throws(Kernel.File.Flush.Error) {
                try Kernel.File.Flush.flush(fd)
            } catch {
                throw .sync("fsync failed: \(error)")
            }

        case .dataOnly:
            do throws(Kernel.File.Flush.Error) {
                try Kernel.File.Flush.data(fd)
            } catch {
                throw .sync("data sync failed: \(error)")
            }

        case .none:
            break
        }
    }

    internal static func closeFile(
        _ fd: consuming Kernel.Descriptor
    ) throws(Self.Error) {
        do throws(Kernel.Close.Error) {
            try Kernel.Close.close(fd)
        } catch {
            throw .close("close failed: \(error)")
        }
    }
}

extension File.System.Write {

    internal static func atomicRename(
        from source: File.Path,
        to dest: File.Path
    ) throws(Self.Error) {
        do throws(Kernel.File.Move.Error) {
            try source.withKernelPath { sourceKernelPath throws(Kernel.File.Move.Error) in
                try dest.withKernelPath { destKernelPath throws(Kernel.File.Move.Error) in
                    try Kernel.File.Move.move(from: sourceKernelPath, to: destKernelPath)
                }
            }
        } catch {
            throw .rename(from: source, to: dest, "\(error)")
        }
    }

    internal static func atomicRenameNoClobber(
        from source: File.Path,
        to dest: File.Path
    ) throws(Self.Error) {
        if File.System.Stat.exists(at: dest) {
            throw .exists(path: dest)
        }
        do throws(Kernel.File.Move.Error) {
            try source.withKernelPath { sourceKernelPath throws(Kernel.File.Move.Error) in
                try dest.withKernelPath { destKernelPath throws(Kernel.File.Move.Error) in
                    try Kernel.File.Move.move(from: sourceKernelPath, to: destKernelPath)
                }
            }
        } catch {
            throw .rename(from: source, to: dest, "\(error)")
        }
    }

    internal static func syncDirectory(
        _ path: File.Path
    ) throws(Self.Error) {
        #if os(Windows)
            _ = path
        #else
            do {

                var fd: Kernel.Descriptor = .invalid
                try path.withKernelPath { kernelPath throws(Kernel.File.Open.Error) in
                    fd = try Kernel.File.Open.open(
                        path: kernelPath,
                        mode: .read,
                        options: [.execClose],
                        permissions: .none
                    )
                }
                try Kernel.File.Flush.flush(fd)

            } catch {
                throw .directory(
                    path: path,
                    "fsync directory failed: \(error)"
                )
            }
        #endif
    }
}
