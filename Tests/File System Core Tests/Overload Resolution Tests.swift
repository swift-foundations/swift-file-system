import Either_Primitives
import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

private struct Sentinel: Swift.Error, Equatable {}

private func countContents(
    in directory: borrowing File.Directory
) throws(Either<File.Directory.Contents.Error, Never>) -> Int {
    var count = 0
    try File.Directory.Contents.iterate(at: directory) { _ in
        count += 1
        return .continue
    }
    return count
}

private func countWalked(
    in directory: borrowing File.Directory
) throws(Either<File.Directory.Walk.Error, Never>) -> Int {
    var count = 0
    try directory.walk.iterate { _ in
        count += 1
        return .continue
    }
    return count
}

private func byteCount(
    at path: borrowing File.Path
) throws(Either<File.System.Read.Full.Error, Never>) -> Int {
    try File.System.Read.Full.read(from: path) { span in
        span.count
    }
}

private func contentsThrowing(
    in directory: borrowing File.Directory
) throws(Either<File.Directory.Contents.Error, Sentinel>) {
    try File.Directory.Contents.iterate(at: directory) {
        _ throws(Sentinel) -> File.Directory.Contents.Control in
        throw Sentinel()
    }
}

private func walkThrowing(
    in directory: borrowing File.Directory
) throws(Either<File.Directory.Walk.Error, Sentinel>) {
    try directory.walk.iterate {
        _ throws(Sentinel) -> File.Directory.Contents.Control in
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

private func listContents(
    in directory: borrowing File.Directory
) throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
    try File.Directory.Contents.list(at: directory)
}

private func walkAll(
    in directory: borrowing File.Directory
) throws(File.Directory.Walk.Error) -> [File.Directory.Entry] {
    try directory.walk()
}

private func walkFiles(
    in directory: borrowing File.Directory
) throws(File.Directory.Walk.Error) -> Int {
    var count = 0
    try directory.walk.files { _ in
        count += 1
        return .continue
    }
    return count
}

private func walkDirectories(
    in directory: borrowing File.Directory
) throws(File.Directory.Walk.Error) -> Int {
    var count = 0
    try directory.walk.directories { _ in
        count += 1
        return .continue
    }
    return count
}

@Suite
struct `Overload Resolution` {
    @Suite struct `Non Throwing Closure` {}
    @Suite struct `Throwing Closure` {}
    @Suite struct `Never Elimination` {}
}

extension `Overload Resolution`.`Non Throwing Closure` {
    @Test
    func `Contents iterate infers Never`() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: dir.path / "a.txt")
            try File.System.Write.Atomic.write([], to: dir.path / "b.txt")

            #expect(try countContents(in: dir) == 2)
        }
    }

    @Test
    func `Walk iterate infers Never`() throws {
        try File.Directory.temporary { dir in
            try File.System.Create.Directory.create(at: dir.path / "sub")
            try File.System.Write.Atomic.write([], to: dir.path / "sub" / "a.txt")

            #expect(try countWalked(in: dir) == 2)
        }
    }

    @Test
    func `Read full infers Never`() throws {
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
    func `Contents iterate propagates the closure error`() throws {
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
    func `Walk iterate propagates the closure error`() throws {
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
    func `Read full propagates the closure error`() throws {
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

extension `Overload Resolution`.`Never Elimination` {

    @Test
    func `Contents list surfaces the directory error`() throws {
        try File.Directory.temporary { dir in
            let missing = File.Directory(dir.path / "missing")

            #expect(throws: File.Directory.Contents.Error.self) {
                try listContents(in: missing)
            }
        }
    }

    @Test
    func `Walk surfaces the traversal error`() throws {
        try File.Directory.temporary { dir in
            let missing = File.Directory(dir.path / "missing")

            #expect(throws: File.Directory.Walk.Error.self) {
                try walkAll(in: missing)
            }
        }
    }

    @Test
    func `Walk filters keep their concrete error type`() throws {
        try File.Directory.temporary { dir in
            try File.System.Create.Directory.create(at: dir.path / "sub")
            try File.System.Write.Atomic.write([], to: dir.path / "sub" / "a.txt")

            #expect(try walkFiles(in: dir) == 1)
            #expect(try walkDirectories(in: dir) == 1)
        }
    }
}
