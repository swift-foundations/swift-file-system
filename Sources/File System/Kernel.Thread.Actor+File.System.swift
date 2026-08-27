public import IO
public import Kernel
import Memory
public import Span_Raw
public import Thread_Actor

extension Kernel.Thread.Actor {

    public func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode
    ) throws(File.System.IO.Error) -> Kernel.Descriptor {
        do throws(Kernel.File.Open.Error) {

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

    public func close(_ descriptor: consuming Kernel.Descriptor) {
        do throws(Kernel.Close.Error) {
            try Kernel.Close.close(consume descriptor)
        } catch {

        }
    }
}
