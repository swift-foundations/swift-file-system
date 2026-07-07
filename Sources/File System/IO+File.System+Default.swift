//
//  IO+File.System+Default.swift
//  swift-file-system
//
//  Host-adaptive `default()` factory for the file-system domain.
//  File-system strategy preference is domain policy — regular files
//  are always epoll/kqueue-ready, so events (reactor) is not a strategy
//  here. The chain is completions → blocking.
//

public import Executors
public import IO
public import Kernel

extension IO where Capabilities == File.System.IO.Capabilities {
    /// Host-adaptive file-system I/O.
    ///
    /// Dispatch order:
    ///
    /// | Platform | Order |
    /// |----------|-------|
    /// | **Linux** | completions (io_uring, if `Kernel.IO.Uring.isSupported`) → blocking |
    /// | **other** | blocking |
    ///
    /// The caller supplies the executor used for the blocking terminal
    /// fallback; on Linux the same executor also backs the path-level
    /// ops (`open`, `stat`, `close`) inside the completions factory
    /// since `Opcode` does not yet carry `.openat` / `.statx`.
    public static func `default`(
        on executor: Kernel.Thread.Executor
    ) -> IO<File.System.IO.Capabilities> {
        #if os(Linux)
            if Kernel.IO.Uring.isSupported {
                let proactor: Completion.Actor?
                do throws(Kernel.Completion.Error) {
                    proactor = try Completion.Actor.shared()
                } catch {
                    proactor = nil
                }
                if let proactor {
                    return .completions(on: proactor, blockingOn: executor)
                }
            }
        #endif
        return .blocking(on: executor)
    }
}
