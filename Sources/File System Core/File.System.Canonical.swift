internal import Kernel
internal import Path_Primitives

extension File.System {

    public enum Canonical {}
}

extension File.System.Canonical {

    public static func resolve(
        _ path: borrowing File.Path
    ) throws(File.System.Canonical.Error) -> File.Path {
        let canonical: Result<File.Path, File.Path.Error>
        do throws(Path_Primitives.Path.Canonical.Error) {
            canonical = try path.withKernelPath {
                kernelPath throws(Path_Primitives.Path.Canonical.Error) in
                try Path_Primitives.Path.Canonical.withCanonicalBytes(kernelPath) { bytes in
                    do throws(File.Path.Error) {
                        return .success(try File.Path(copying: bytes))
                    } catch {
                        return .failure(error)
                    }
                }
            }
        } catch {
            throw .resolution(error)
        }

        switch canonical {
        case .success(let path):
            return path

        case .failure(let error):
            throw .representation(error)
        }
    }
}
