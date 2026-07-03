//
//  IO+File.System+Completions.swift
//  swift-file-system
//
//  Completions-strategy factory for the file-system domain.
//
//  Hybrid dispatch: fd byte ops (`read`, `write`) go through the
//  Completion.Actor's `submit` primitive (io_uring). Path-level ops
//  (`open`, `stat`) and `close` go through a Kernel.Thread.Actor on a
//  co-supplied executor — `Opcode` does not yet carry `.openat` or
//  `.statx`, and `close` benefits no more from io_uring than from a
//  direct `close(2)` syscall (same as Basic's completions factory).
//
//  Linux-only (io_uring). On Darwin/Windows, use ``blocking(on:)``.
//

#if os(Linux)

    public import Executors
    public import IO
    public import Kernel
    public import Memory_Primitives
    public import Span_Raw_Primitives
    public import Thread_Actor

    extension IO where Capabilities == File.System.IO.Capabilities {
        /// Completions-strategy file-system I/O bound to an explicit
        /// ``Completion/Actor`` for fd ops and a
        /// ``Kernel/Thread/Executor`` for path ops.
        public static func completions(
            on completion: Completion.Actor,
            blockingOn executor: Kernel.Thread.Executor
        ) -> IO<File.System.IO.Capabilities> {
            let thread = Kernel.Thread.Actor(executor: executor)
            let capabilities = File.System.IO.Capabilities(
                open: { path, mode throws(File.System.IO.Error) in
                    try await thread.open(path, mode: mode)
                },
                close: { fd in
                    await thread.close(consume fd)
                },
                read: { fd, buf throws(File.System.IO.Error) -> Int in
                    let raw = unsafe buf.base.nonNull
                    let descriptor: Kernel.Descriptor?
                    do throws(Kernel.Descriptor.Duplicate.Error) {
                        descriptor = try Kernel.Descriptor.Duplicate.duplicate(fd)
                    } catch {
                        throw .platform(error.code)
                    }
                    let address = unsafe Memory.Address(raw.baseAddress!)
                    let length: Memory.Address.Count = buf.count.retag(Memory.self)
                    do throws(Completion.Failure) {
                        return try await completion.submit(
                            .read(address: address, length: length, offset: nil),
                            descriptor: consume descriptor
                        ) { event throws(Completion.Failure) in
                            if let error = event.result.failure {
                                throw error.completionFailure
                            }
                            return Int(event.result.value!)
                        }
                    } catch {
                        throw error.fileSystemError
                    }
                },
                write: { fd, buf throws(File.System.IO.Error) -> Int in
                    let raw = unsafe buf.base.nonNull
                    let descriptor: Kernel.Descriptor?
                    do throws(Kernel.Descriptor.Duplicate.Error) {
                        descriptor = try Kernel.Descriptor.Duplicate.duplicate(fd)
                    } catch {
                        throw .platform(error.code)
                    }
                    let address = unsafe Memory.Address(raw.baseAddress!)
                    let length: Memory.Address.Count = buf.count.retag(Memory.self)
                    do throws(Completion.Failure) {
                        return try await completion.submit(
                            .write(address: address, length: length, offset: nil),
                            descriptor: consume descriptor
                        ) { event throws(Completion.Failure) in
                            if let error = event.result.failure {
                                throw error.completionFailure
                            }
                            return Int(event.result.value!)
                        }
                    } catch {
                        throw error.fileSystemError
                    }
                },
                stat: { path throws(File.System.IO.Error) in
                    try await thread.stat(path)
                }
            )
            let runner = unsafe Self.Runner(
                executor: { completion.unownedExecutor },
                shutdown: {}
            )
            return IO(capabilities: capabilities, runner: runner)
        }
    }

#endif
