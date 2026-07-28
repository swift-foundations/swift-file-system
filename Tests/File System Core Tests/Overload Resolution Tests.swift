//
//  Overload Resolution Tests.swift
//  swift-file-system
//

import Either_Primitives
import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

// MARK: - Regression: non-throwing closures must not be ambiguous
//
// `Contents.iterate(at:body:)`, `Walk.iterate(options:body:)` and
// `Read.Full.read(from:body:)` each come in two overloads that differ only in
// the throwing-ness of the closure: a non-generic one taking a non-throwing
// closure, and a generic one taking a `throws(E)` closure.
//
// A non-throwing closure literal is viable for BOTH — the non-generic overload
// directly, and the generic one with `E` inferred as `Never`. Swift 6.3.3 ranked
// the non-generic overload higher; Swift 6.4 no longer does, so every such call
// became `ambiguous use of ...`. The overloads are public, so this affected any
// consumer, not just this package's own wrappers.
//
// These helpers are the regression test. They are deliberately written with
// explicit typed-throws signatures: the thrown type PINS which overload was
// selected. If the generic overload were chosen, the thrown type would be
// `Either<_, Never>` and these would not compile. So this file fails to build
// on the unfixed source under Swift 6.4, and compiles once the generic
// overloads are disfavored.

private struct Sentinel: Swift.Error, Equatable {}

// MARK: Non-throwing closure -> non-generic overload

private func countContents(
    in directory: borrowing File.Directory
) throws(File.Directory.Contents.Error) -> Int {
    var count = 0
    try File.Directory.Contents.iterate(at: directory) { _ in
        count += 1
        return .continue
    }
    return count
}

private func countWalked(
    in directory: borrowing File.Directory
) throws(File.Directory.Walk.Error) -> Int {
    var count = 0
    try directory.walk.iterate { _ in
        count += 1
        return .continue
    }
    return count
}

private func byteCount(
    at path: borrowing File.Path
) throws(File.System.Read.Full.Error) -> Int {
    try File.System.Read.Full.read(from: path) { span in
        span.count
    }
}

// MARK: Throwing closure -> generic overload (must still be reachable)

private func contentsThrowing(
    in directory: borrowing File.Directory
) throws(Either<File.Directory.Contents.Error, Sentinel>) {
    try File.Directory.Contents.iterate(at: directory) {
        (_) throws(Sentinel) -> File.Directory.Contents.Control in
        throw Sentinel()
    }
}

private func walkThrowing(
    in directory: borrowing File.Directory
) throws(Either<File.Directory.Walk.Error, Sentinel>) {
    try directory.walk.iterate {
        (_) throws(Sentinel) -> File.Directory.Contents.Control in
        throw Sentinel()
    }
}

private func readThrowing(
    at path: borrowing File.Path
) throws(Either<File.System.Read.Full.Error, Sentinel>) -> Int {
    try File.System.Read.Full.read(from: path) {
        (_: Swift.Span<Byte>) throws(Sentinel) -> Int in
        throw Sentinel()
    }
}

// MARK: - Suite

@Suite
struct `Overload Resolution` {
    @Suite struct `Non Throwing Closure` {}
    @Suite struct `Throwing Closure` {}
}

extension `Overload Resolution`.`Non Throwing Closure` {
    @Test
    func `Contents iterate selects the non-generic overload`() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: dir.path / "a.txt")
            try File.System.Write.Atomic.write([], to: dir.path / "b.txt")

            #expect(try countContents(in: dir) == 2)
        }
    }

    @Test
    func `Walk iterate selects the non-generic overload`() throws {
        try File.Directory.temporary { dir in
            try File.System.Create.Directory.create(at: dir.path / "sub")
            try File.System.Write.Atomic.write([], to: dir.path / "sub" / "a.txt")

            // The subdirectory itself plus the file inside it.
            #expect(try countWalked(in: dir) == 2)
        }
    }

    @Test
    func `Read full selects the non-generic overload`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "payload.bin"
            let content: [Byte] = [1, 2, 3, 4, 5]
            try File.System.Write.Atomic.write(content.span, to: path)

            #expect(try byteCount(at: path) == content.count)
        }
    }
}

extension `Overload Resolution`.`Throwing Closure` {
    @Test
    func `Contents iterate still reaches the generic overload`() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: dir.path / "a.txt")

            do throws(Either<File.Directory.Contents.Error, Sentinel>) {
                try contentsThrowing(in: dir)
                Issue.record("expected the closure error to propagate")
            } catch {
                #expect(error.right == Sentinel())
            }
        }
    }

    @Test
    func `Walk iterate still reaches the generic overload`() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: dir.path / "a.txt")

            do throws(Either<File.Directory.Walk.Error, Sentinel>) {
                try walkThrowing(in: dir)
                Issue.record("expected the closure error to propagate")
            } catch {
                #expect(error.right == Sentinel())
            }
        }
    }

    @Test
    func `Read full still reaches the generic overload`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "payload.bin"
            try File.System.Write.Atomic.write([Byte]([1, 2, 3]).span, to: path)

            do throws(Either<File.System.Read.Full.Error, Sentinel>) {
                _ = try readThrowing(at: path)
                Issue.record("expected the closure error to propagate")
            } catch {
                #expect(error.right == Sentinel())
            }
        }
    }
}
