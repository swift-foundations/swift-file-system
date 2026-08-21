extension File.Path.Temporary {
    public enum Error: Swift.Error, Sendable, Equatable {
        case parent
        case random
        case component(File.Path.Component.Error)
    }
}
