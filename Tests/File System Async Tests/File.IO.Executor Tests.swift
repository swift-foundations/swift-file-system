//
//  File.IO.Executor Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System
import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Async

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

extension File.IO.Executor {
    #TestSuites
}

extension File.IO.Executor.Test.Unit {

    // MARK: - Basic Execution

    @Test("Execute simple operation")
    func executeSimple() async throws {
        let executor = File.IO.Executor()
        let result = try await executor.run { 42 }
        #expect(result == 42)
        await executor.shutdown()
    }

    @Test("Execute throwing operation")
    func executeThrowing() async throws {
        let executor = File.IO.Executor()

        struct TestError: Error, Equatable {}

        do {
            try await executor.run { () throws(TestError) -> Void in throw TestError() }
            Issue.record("Expected error to be thrown")
        } catch {
            // error is File.IO.Error<TestError>
            guard case .operation(let inner) = error else {
                Issue.record("Expected .operation case, got \(error)")
                return
            }
            #expect(inner == TestError())
        }
        await executor.shutdown()
    }

    @Test("Execute multiple operations")
    func executeMultiple() async throws {
        let executor = File.IO.Executor()

        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try await executor.run { i * 2 }
                }
            }
            var results: [Int] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted()
        }

        #expect(results == [0, 2, 4, 6, 8, 10, 12, 14, 16, 18])
        await executor.shutdown()
    }

    // MARK: - Shutdown

    @Test("Run after shutdown throws")
    func runAfterShutdown() async throws {
        let executor = File.IO.Executor()
        await executor.shutdown()

        do {
            _ = try await executor.run { 42 }
            Issue.record("Expected error to be thrown")
        } catch {
            // error is File.IO.Error<Never>
            guard case .executor(.shutdownInProgress) = error else {
                Issue.record("Expected .executor(.shutdownInProgress), got \(error)")
                return
            }
            // Success - got expected error
        }
    }

    @Test("Shutdown is idempotent")
    func shutdownIdempotent() async throws {
        let executor = File.IO.Executor()
        await executor.shutdown()
        await executor.shutdown()  // Should not hang or crash
    }

    @Test("In-flight jobs complete during shutdown")
    func inFlightCompletesDuringShutdown() async throws {
        let executor = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 1))
        let started = ManagedAtomic(false)
        let completed = ManagedAtomic(false)

        // Start a long-running job
        let task = Task {
            try await executor.run {
                started.store(true, ordering: .releasing)
                usleep(100_000)  // 100ms
                completed.store(true, ordering: .releasing)
                return 42
            }
        }

        // Wait for job to start
        while !started.load(ordering: .acquiring) {
            await Task.yield()
        }

        // Shutdown while job is in-flight
        await executor.shutdown()

        // Job should have completed
        #expect(completed.load(ordering: .acquiring))

        // Task should return successfully
        let result = try await task.value
        #expect(result == 42)
    }

    // MARK: - Configuration

    @Test("Configuration default values")
    func configurationDefaults() {
        let config = File.IO.Configuration()
        #expect(config.workers == File.IO.Configuration.defaultWorkerCount)
        #expect(config.queueLimit == 10_000)
    }

    @Test("Configuration custom values")
    func configurationCustom() {
        let config = File.IO.Configuration(workers: 4, queueLimit: 100)
        #expect(config.workers == 4)
        #expect(config.queueLimit == 100)
    }

    @Test("Configuration enforces minimum values")
    func configurationMinimums() {
        let config = File.IO.Configuration(workers: 0, queueLimit: 0)
        #expect(config.workers >= 1)
        #expect(config.queueLimit >= 1)
    }

}

extension File.IO.Executor.Test.EdgeCase {

    @Test("Multiple dedicated executors don't oversubscribe")
    func multipleDedicatedExecutorsNoOversubscription() async throws {
        // Create 3 executors with 2 workers each
        let executor1 = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 2))
        let executor2 = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 2))
        let executor3 = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 2))

        // Track concurrent execution
        let concurrentCount = ManagedAtomic(0)
        let maxConcurrent = ManagedAtomic(0)

        // Submit work to all executors concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Each executor gets 4 jobs (should queue 2 per executor)
            for executor in [executor1, executor2, executor3] {
                for _ in 0..<4 {
                    group.addTask {
                        try await executor.run {
                            // Atomically increment and get new value
                            let newCurrent = concurrentCount.wrappingIncrementThenLoad(
                                ordering: .acquiring
                            )

                            // Update max using compare-exchange loop
                            var currentMax = maxConcurrent.load(ordering: .acquiring)
                            while newCurrent > currentMax {
                                let (exchanged, actual) = maxConcurrent.compareExchange(
                                    expected: currentMax,
                                    desired: newCurrent,
                                    ordering: .acquiringAndReleasing
                                )
                                if exchanged { break }
                                currentMax = actual
                            }

                            // Simulate work
                            usleep(50_000)  // 50ms

                            _ = concurrentCount.wrappingDecrementThenLoad(ordering: .releasing)
                        }
                    }
                }
            }

            for try await _ in group {}
        }

        // Max concurrent should not exceed sum of all workers (2+2+2=6)
        let max = maxConcurrent.load(ordering: .acquiring)
        #expect(max <= 6, "Expected max concurrent <= 6, got \(max)")

        await executor1.shutdown()
        await executor2.shutdown()
        await executor3.shutdown()
    }

    @Test("Dedicated pool handles blocking operations without affecting cooperative pool")
    func dedicatedPoolBlockingIsolation() async throws {
        let dedicatedExecutor = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 2))

        // Track that cooperative work completes while dedicated is blocked
        let dedicatedStarted = ManagedAtomic(false)
        let cooperativeCompleted = ManagedAtomic(false)

        // Start blocking work on dedicated pool
        let dedicatedTask = Task {
            try await dedicatedExecutor.run {
                dedicatedStarted.store(true, ordering: .releasing)
                usleep(200_000)  // 200ms - Long blocking operation
                return "dedicated"
            }
        }

        // Wait for dedicated work to start blocking
        while !dedicatedStarted.load(ordering: .acquiring) {
            await Task.yield()
        }

        // Now run cooperative async work - should complete quickly
        let cooperativeTask = Task {
            // Regular async work on cooperative pool
            try await Task.sleep(for: .milliseconds(10))
            cooperativeCompleted.store(true, ordering: .releasing)
            return "cooperative"
        }

        // Cooperative work should complete before dedicated
        let cooperativeResult = try await cooperativeTask.value
        #expect(cooperativeResult == "cooperative")
        #expect(cooperativeCompleted.load(ordering: .acquiring))

        // Dedicated work should still complete successfully
        let dedicatedResult = try await dedicatedTask.value
        #expect(dedicatedResult == "dedicated")

        await dedicatedExecutor.shutdown()
    }

    @Test("Dedicated pool shutdown is clean with no hanging threads")
    func dedicatedPoolCleanShutdown() async throws {
        let executor = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 4))

        // Submit and complete some work
        try await withThrowingTaskGroup(of: Int.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try await executor.run {
                        usleep(10_000)  // 10ms
                        return i
                    }
                }
            }
            for try await _ in group {}
        }

        // Shutdown should complete quickly without hanging
        let shutdownStart = MonotonicClock()
        await executor.shutdown()
        let shutdownDuration = shutdownStart.elapsed()

        // Shutdown should be fast (< 1 second)
        #expect(shutdownDuration < 1.0, "Shutdown took \(shutdownDuration)s, expected < 1s")
    }

    @Test("Worker count is respected - only N jobs run concurrently")
    func workerCountRespected() async throws {
        let workerCount = 2
        let executor = File.IO.Executor(
            .init(workers: workerCount)
        )

        let concurrentCount = ManagedAtomic(0)
        let maxConcurrent = ManagedAtomic(0)
        let violations = ManagedAtomic(0)

        // Submit many jobs
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await executor.run {
                        // Atomically increment and get new value
                        let newCurrent = concurrentCount.wrappingIncrementThenLoad(
                            ordering: .acquiringAndReleasing
                        )

                        // Check if we exceeded worker count
                        if newCurrent > workerCount {
                            _ = violations.wrappingIncrementThenLoad(ordering: .relaxed)
                        }

                        // Update max atomically using CAS loop
                        var currentMax = maxConcurrent.load(ordering: .relaxed)
                        while newCurrent > currentMax {
                            let (exchanged, current) = maxConcurrent.compareExchange(
                                expected: currentMax,
                                desired: newCurrent,
                                ordering: .relaxed
                            )
                            if exchanged { break }
                            currentMax = current
                        }

                        // Do work
                        usleep(20_000)  // 20ms

                        // Atomically decrement
                        _ = concurrentCount.wrappingDecrementThenLoad(
                            ordering: .acquiringAndReleasing
                        )
                    }
                }
            }

            for try await _ in group {}
        }

        let max = maxConcurrent.load(ordering: .acquiring)
        let violationCount = violations.load(ordering: .acquiring)

        #expect(
            max <= workerCount,
            "Max concurrent \(max) exceeded worker count \(workerCount)"
        )
        #expect(
            violationCount == 0,
            "Had \(violationCount) violations of worker count limit"
        )

        await executor.shutdown()
    }

    @Test("Queue limit is enforced")
    func queueLimitEnforced() async throws {
        let executor = File.IO.Executor(
            .init(
                workers: 1,
                queueLimit: 5
            )
        )

        let started = ManagedAtomic(false)
        let blocker = ManagedAtomic(true)

        // Start a blocking job to fill the worker
        let blockingTask = Task {
            try await executor.run {
                started.store(true, ordering: .releasing)
                // Block until released
                while blocker.load(ordering: .acquiring) {
                    usleep(10_000)  // 10ms
                }
                return "blocker"
            }
        }

        // Wait for blocker to start
        while !started.load(ordering: .acquiring) {
            await Task.yield()
        }

        // Now try to submit more than queueLimit jobs
        // With worker=1 and queueLimit=5, we can have:
        // - 1 running job (the blocker)
        // - 5 queued jobs
        // The queue should handle at least these jobs

        var submittedTasks: [Task<String, any Error>] = []

        // Submit 5 jobs that should queue successfully
        for i in 0..<5 {
            let task = Task {
                try await executor.run {
                    return "job-\(i)"
                }
            }
            submittedTasks.append(task)
            try await Task.sleep(for: .milliseconds(5))
        }

        // Release the blocker
        blocker.store(false, ordering: .releasing)

        // Wait for all tasks to complete
        let blockerResult = try await blockingTask.value
        #expect(blockerResult == "blocker")

        for (i, task) in submittedTasks.enumerated() {
            let result = try await task.value
            #expect(result == "job-\(i)")
        }

        await executor.shutdown()
    }

    @Test("Thread pool handles exceptions without corruption")
    func dedicatedPoolExceptionHandling() async throws {
        let executor = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 2))

        struct TestError: Error, Equatable {}

        // Submit mix of successful and failing jobs
        var successCount = 0
        var errorCount = 0

        await withTaskGroup(of: Result<String, any Error>.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        let result = try await executor.run {
                            if i % 3 == 0 {
                                throw TestError()
                            }
                            return "success-\(i)"
                        }
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case .success:
                    successCount += 1
                case .failure:
                    errorCount += 1
                }
            }
        }

        // Should have some successes and some failures
        #expect(successCount == 6)
        #expect(errorCount == 4)

        // Executor should still work after exceptions
        let result = try await executor.run { "post-exception" }
        #expect(result == "post-exception")

        await executor.shutdown()
    }

    @Test("Dedicated pool stress test - many concurrent jobs")
    func dedicatedPoolStressTest() async throws {
        let executor = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 4))

        let jobCount = 100
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for i in 0..<jobCount {
                group.addTask {
                    try await executor.run {
                        // Mix of quick and slower jobs
                        if i % 10 == 0 {
                            usleep(20_000)  // 20ms
                        }
                        return i
                    }
                }
            }

            var results: [Int] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted()
        }

        // All jobs should complete
        #expect(results.count == jobCount)
        #expect(results == Array(0..<jobCount))

        await executor.shutdown()
    }
}

// Simple atomic for testing using POSIX mutex
private final class ManagedAtomic<T>: @unchecked Sendable {
    fileprivate var _value: T
    fileprivate var mutex = pthread_mutex_t()

    init(_ value: T) {
        self._value = value
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    func load(ordering: MemoryOrder) -> T {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return _value
    }

    func store(_ value: T, ordering: MemoryOrder) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        _value = value
    }

    func compareExchange(
        expected: T,
        desired: T,
        ordering: MemoryOrder
    ) -> (exchanged: Bool, original: T) where T: Equatable {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        let original = _value
        if original == expected {
            _value = desired
            return (true, original)
        }
        return (false, original)
    }

    enum MemoryOrder {
        case acquiring, releasing, relaxed, acquiringAndReleasing
    }
}

extension ManagedAtomic where T == Int {
    func wrappingIncrementThenLoad(ordering: MemoryOrder) -> Int {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        _value += 1
        return _value
    }

    func wrappingDecrementThenLoad(ordering: MemoryOrder) -> Int {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        _value -= 1
        return _value
    }
}
