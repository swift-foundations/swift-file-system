//
//  Test.Glob.Fixture.swift
//  swift-file-system
//
//  Test support for glob pattern testing with standard file structure.
//

import File_System
public import File_System_Core
import Kernel

/// Creates a standard test file structure for glob testing.
///
/// Creates:
/// ```
/// directory/
///   file1.txt
///   file2.txt
///   file3.md
///   .hidden.txt
///   src/
///     main.swift
///     test.swift
///     util.swift
///   docs/
///     readme.md
///     guide.md
///   .config/
///     settings.json
/// ```
///
/// - Parameter directory: The directory to populate.
/// - Throws: File system errors on creation failure.
public func createGlobTestFiles(in directory: File.Directory) throws {
    let files = [
        "file1.txt",
        "file2.txt",
        "file3.md",
        ".hidden.txt",
        "src/main.swift",
        "src/test.swift",
        "src/util.swift",
        "docs/readme.md",
        "docs/guide.md",
        ".config/settings.json",
    ]

    for file in files {
        let fullPath = directory.path.appending(try File.Path(file))

        // Create parent directory if needed
        let parentPath = fullPath.parent
        if let parent = parentPath, !File.System.Stat.exists(at: parent) {
            try File.System.Create.Directory.create(at: parent)
        }

        // Create file
        try File.System.Write.Atomic.write(
            [Byte]().span,
            to: fullPath,
            options: .init()
        )
    }
}
