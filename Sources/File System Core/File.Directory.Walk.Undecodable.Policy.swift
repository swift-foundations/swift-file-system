extension File.Directory.Walk.Undecodable {

    public enum Policy: Sendable {

        case skip

        case emit

        case stopAndThrow
    }
}
