import File_System_Core

extension File.Directory.Contents {

    public static func names(
        at directory: File.Directory
    ) throws(Self.Error) -> [File.Name] {
        let (iterator, handle) = try makeIterator(at: directory)
        defer { closeIterator(handle) }

        var names: [File.Name] = []
        var iter = iterator
        while let name = iter.next() {
            names.append(name)
        }

        if let error = iteratorError(for: iter, directory: directory) {
            throw error
        }

        return names
    }
}
