import Kernel

extension File.System.Stat {

    public static func isFile(at path: borrowing File.Path) -> Bool {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try Self.info(at: path)
        } catch {
            return false
        }
        return info.type == .regular
    }

    public static func isDirectory(at path: borrowing File.Path) -> Bool {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try Self.info(at: path)
        } catch {
            return false
        }
        return info.type == .directory
    }

    public static func isSymlink(at path: borrowing File.Path) -> Bool {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try Self.info(at: path, followSymlinks: false)
        } catch {
            return false
        }
        return info.type == .symbolicLink
    }
}
