//
//  Kernel.Thread.Actor+File.System.swift
//  swift-file-system
//
//  File-system syscall bindings attached to Kernel.Thread.Actor
//  (swift-threads). Actor isolation guarantees each method runs on the
//  actor's pinned OS thread. Mirrors the Basic-domain shape from
//  swift-io but with the file-system operation set and
//  File.System.IO.Error mapping.
//

public import IO
public import Kernel
public import Memory_Primitives
public import Span_Raw_Primitives
public import Thread_Actor

extension Kernel.Thread.Actor {

    /// Open `path` in the given mode on the actor's pinned OS thread.
    public func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode
    ) throws(File.System.IO.Error) -> Kernel.Descriptor {
        do throws(Kernel.File.Open.Error) {
            // Non-optional `var` storage, not a closure return: `Kernel.Descriptor`
            // is `~Copyable`, and `withKernelPath`'s generic `R` requires Copyable,
            // so the opened descriptor cannot flow out as the closure's result.
            // Matches the established `.invalid`-sentinel pattern (see
            // `File.System.Write.Append.append`) rather than an `Optional` + `take()`.
            var descriptor: Kernel.Descriptor = .invalid
            try path.withKernelPath { kernelPath throws(Kernel.File.Open.Error) in
                descriptor = try Kernel.File.Open.open(
                    path: kernelPath,
                    mode: mode,
                    options: [.execClose],
                    permissions: Kernel.File.Permissions(rawValue: 0)
                )
            }
            return descriptor
        } catch {
            throw .open(error)
        }
    }

    /// Read file metadata for `path` on the actor's pinned OS thread.
    public func stat(
        _ path: borrowing File.Path
    ) throws(File.System.IO.Error) -> Kernel.File.Stats {
        do throws(Kernel.File.Stats.Error) {
            return try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.get(path: kernelPath)
            }
        } catch {
            throw .stat(error)
        }
    }

    /// Read bytes from `descriptor` into `buffer` on the actor's pinned
    /// OS thread. Returns bytes read, or 0 at EOF.
    public func read(
        from descriptor: borrowing Kernel.Descriptor,
        into buffer: Span.Raw.Mutable
    ) throws(File.System.IO.Error) -> Int {
        do throws(Kernel.IO.Read.Error) {
            return try unsafe Kernel.IO.Read.read(descriptor, into: unsafe buffer.base.nonNull)
        } catch {
            throw .read(error)
        }
    }

    /// Write bytes from `buffer` to `descriptor` on the actor's pinned
    /// OS thread. Returns bytes written.
    public func write(
        to descriptor: borrowing Kernel.Descriptor,
        from buffer: Span.Raw
    ) throws(File.System.IO.Error) -> Int {
        do throws(Kernel.IO.Write.Error) {
            return try unsafe Kernel.IO.Write.write(descriptor, from: unsafe buffer.base.nonNull)
        } catch {
            throw .write(error)
        }
    }

    /// Close `descriptor` on the actor's pinned OS thread.
    ///
    /// Close errors are swallowed — the fd is closed at the kernel
    /// level even when the syscall reports an error.
    public func close(_ descriptor: consuming Kernel.Descriptor) {
        do throws(Kernel.Close.Error) {
            try Kernel.Close.close(consume descriptor)
        } catch {
            // fd is already closed — error is informational only.
        }
    }
}
