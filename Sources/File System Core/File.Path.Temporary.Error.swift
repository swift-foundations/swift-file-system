// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-file-system open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-file-system project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension File.Path.Temporary {
    public enum Error: Swift.Error, Sendable, Equatable {
        case parent
        case random
        case component(File.Path.Component.Error)
    }
}
