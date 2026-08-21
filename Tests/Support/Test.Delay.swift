#if os(Windows)
    import WinSDK
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif canImport(Darwin)
    import Darwin
#endif

public enum Test {}

extension Test {

    public enum Delay {}
}

extension Test.Delay {

    public static func milliseconds(_ ms: UInt32) {
        #if os(Windows)
            Sleep(ms)
        #elseif canImport(Glibc) || canImport(Musl) || canImport(Darwin)
            usleep(ms * 1_000)
        #endif
    }
}

extension Test {

    public enum Retry {}
}

extension Test.Retry {

    public static func withDelay<T>(
        attempts: Int,
        delayMs: UInt32 = 50,
        _ body: () throws -> T
    ) rethrows -> T {
        precondition(attempts >= 1, "attempts must be >= 1")
        for _ in 0..<(attempts - 1) {
            do {
                return try body()
            } catch {
                Test.Delay.milliseconds(delayMs)
            }
        }

        return try body()
    }
}
