//
//  File.Read Overload Resolution Tests.swift
//  swift-file-system
//

import Either_Primitives
import File_System
import File_System_Test_Support
import Kernel
import Testing
import Thread_Pool

// MARK: - Regression: one typed-throws `full` per effect
//
// `File.Read.full` is the `File System` layer's re-exposure of
// `File.System.Read.Full.read`. It shipped the same pair of overloads
// differing only in the throwing-ness of the closure — in both its sync and
// its async form — so a non-throwing closure was viable for both candidates
// and Swift 6.4 reported `ambiguous use of 'full'`.
//
// Constraining the thrown type at the call site did NOT disambiguate: a
// consumer writing `do throws(File.System.Read.Full.Error) { try
// file.read.full { ... } }` hit the same error, because both overloads
// remained viable.
//
// Each pair is now collapsed to a single typed-throws generic form. These
// helpers pin the inferred thrown type: a non-throwing closure must infer
// `E == Never`. If a second overload were reintroduced, they would fail to
// compile.

private struct Sentinel: Swift.Error, Equatable {}

private func byteCount(
    of file: borrowing File
) throws(Either<File.System.Read.Full.Error, Never>) -> Int {
    try file.read.full { span in span.count }
}

private func readThrowing(
    of file: borrowing File
) throws(Either<File.System.Read.Full.Error, Sentinel>) -> Int {
    try file.read.full { (_: Swift.Span<Byte>) throws(Sentinel) -> Int in
        throw Sentinel()
    }
}

private func byteCountAsync(
    of file: File
) async throws(Either<Kernel.Thread.Pool.Error, Either<File.System.Read.Full.Error, Never>>) -> Int {
    try await file.read.full { span in span.count }
}

@Suite
struct `File Read Overload Resolution` {}

extension `File Read Overload Resolution` {
    @Test
    func `Non-throwing closure infers Never`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "payload.bin"
            let content: [Byte] = [1, 2, 3, 4, 5]
            try File.System.Write.Atomic.write(content.span, to: path)

            #expect(try byteCount(of: File(path)) == content.count)
        }
    }

    @Test
    func `Throwing closure propagates the closure error`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "payload.bin"
            try File.System.Write.Atomic.write([Byte]([1, 2, 3]).span, to: path)

            do throws(Either<File.System.Read.Full.Error, Sentinel>) {
                _ = try readThrowing(of: File(path))
                Issue.record("expected the closure error to propagate")
            } catch {
                #expect(error.right == Sentinel())
            }
        }
    }

    @Test
    func `Read failure surfaces in the left arm`() throws {
        try File.Directory.temporary { dir in
            let missing = File(dir.path / "missing.bin")

            #expect(throws: Either<File.System.Read.Full.Error, Never>.self) {
                try byteCount(of: missing)
            }
        }
    }

    @Test
    func `Async non-throwing closure infers Never`() async throws {
        try await File.Directory.temporary { dir in
            let path = dir.path / "payload.bin"
            let content: [Byte] = [7, 8, 9]
            try File.System.Write.Atomic.write(content.span, to: path)

            let count = try await byteCountAsync(of: File(path))
            #expect(count == content.count)
        }
    }
}
