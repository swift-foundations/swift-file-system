//
//  IO+File.System+Blocking.swift
//  swift-file-system
//
//  Blocking-strategy factory for the file-system domain. Pairs a
//  Kernel.Thread.Actor (swift-threads) with a Runner (swift-io-primitives)
//  to yield an `IO<File.System.IO.Capabilities>`.
//

public import Executors
public import IO
public import Thread_Actor

extension IO where Capabilities == File.System.IO.Capabilities {
    /// Blocking-strategy file-system I/O bound to an explicit executor.
    ///
    /// Every operation runs on `executor`'s pinned OS thread via actor
    /// isolation. Consumers that forward their `unownedExecutor` to
    /// the returned bundle (TCA26 shared-executor pattern) incur no
    /// per-op hop.
    public static func blocking(
        on executor: Kernel.Thread.Executor
    ) -> IO<File.System.IO.Capabilities> {
        let actor = Kernel.Thread.Actor(executor: executor)
        let capabilities = File.System.IO.Capabilities(
            open: { path, mode throws(File.System.IO.Error) in
                try await actor.open(path, mode: mode)
            },
            close: { fd in
                await actor.close(consume fd)
            },
            read: { fd, buf throws(File.System.IO.Error) in
                try await actor.read(from: fd, into: buf)
            },
            write: { fd, buf throws(File.System.IO.Error) in
                try await actor.write(to: fd, from: buf)
            },
            stat: { path throws(File.System.IO.Error) in
                try await actor.stat(path)
            }
        )
        let runner = unsafe Self.Runner(
            executor: { unsafe actor.unownedExecutor },
            shutdown: {
                // Caller owns the supplied executor's lifecycle. The
                // factory does not shut it down.
            }
        )
        return IO(capabilities: capabilities, runner: runner)
    }
}
