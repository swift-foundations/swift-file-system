import Kernel

extension File.Directory.Contents {

    public final class IteratorHandle: @unchecked Sendable {
        internal let stream: Kernel.Directory.Stream

        internal init(stream: Kernel.Directory.Stream) {
            self.stream = stream
        }

        deinit {
            stream.close()
        }
    }
}
