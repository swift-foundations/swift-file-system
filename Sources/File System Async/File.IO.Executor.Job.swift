//
//  File.IO.Executor.Job.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Executor {
    /// Type-erased job that encapsulates work and continuation.
    protocol Job: Sendable {
        func run()
        func fail(with error: any Swift.Error)
    }
}
