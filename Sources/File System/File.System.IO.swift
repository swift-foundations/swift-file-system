//
//  File.System.IO.swift
//  swift-file-system
//
//  Experimental domain-IO bundle for the file-system domain.
//
//  Parallels swift-io's `Basic` domain. Validates whether the
//  `IO<Capabilities>` architecture scales cleanly to a second, path-
//  oriented domain. If this reads well and compiles without friction,
//  the multi-domain pattern is confirmed.
//

public import IO

extension File.System {
    /// Namespace for the file-system `IO<Capabilities>` bundle.
    ///
    /// Groups the types that parameterise `IO<File.System.IO.Capabilities>`:
    /// ``File/System/IO/Capabilities`` (the operation set) and
    /// ``File/System/IO/Error`` (the domain error).
    ///
    /// Per-strategy factories live alongside this enum:
    /// - ``IO/blocking(on:)`` — dedicated OS thread + sync POSIX syscalls
    /// - ``IO/completions(on:)`` — io_uring proactor (Linux)
    /// - ``IO/default()`` — host-adaptive selection
    ///
    /// The file-system domain does NOT ship an events (readiness-reactor)
    /// factory: regular files are always "ready" to epoll/kqueue, so the
    /// reactor provides no value. Events is a socket-shaped strategy.
    public enum IO {}
}
