//
//  File.System.IO.Error.swift
//  swift-file-system
//

public import Kernel

extension File.System.IO {
    /// Domain error for the file-system `IO<Capabilities>` bundle.
    ///
    /// A tagged union of the kernel error taxonomies each operation in
    /// ``File/System/IO/Capabilities`` can produce, plus a `.cancelled`
    /// terminal for task cancellation arriving through the proactor
    /// strategy.
    public enum Error: Swift.Error, Sendable {
        /// Failure from `open(_:mode:)`.
        case open(Kernel.File.Open.Error)

        /// Failure from `stat(_:)`.
        case stat(Kernel.File.Stats.Error)

        /// Failure from `read(_:into:)`.
        case read(Kernel.IO.Read.Error)

        /// Failure from `write(_:from:)`.
        case write(Kernel.IO.Write.Error)

        /// The awaiting task was cancelled (proactor strategy).
        case cancelled

        /// Unmapped platform error code.
        case platform(Error_Primitives.Error.Code)
    }
}
