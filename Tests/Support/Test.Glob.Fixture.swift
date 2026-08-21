import File_System
public import File_System_Core
import Kernel

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

        let parentPath = fullPath.parent
        if let parent = parentPath, !File.System.Stat.exists(at: parent) {
            try File.System.Create.Directory.create(at: parent)
        }

        try File.System.Write.Atomic.write(
            [Byte]().span,
            to: fullPath,
            options: .init()
        )
    }
}
