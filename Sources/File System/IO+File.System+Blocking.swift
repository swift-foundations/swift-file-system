public import Executors
public import IO
import Thread_Actor

extension IO where Capabilities == File.System.IO.Capabilities {

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

            }
        )
        return IO(capabilities: capabilities, runner: runner)
    }
}
