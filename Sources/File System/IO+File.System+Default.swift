public import Executors
public import IO
public import Kernel

extension IO where Capabilities == File.System.IO.Capabilities {

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
