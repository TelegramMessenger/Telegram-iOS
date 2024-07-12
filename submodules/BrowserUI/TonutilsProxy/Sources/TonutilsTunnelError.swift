//
//  Created by Adam Stragner
//

import Foundation

// MARK: - TonutilsTunnelError

public enum TonutilsTunnelError {
    case unableUpdateNetworkSettings(underlyingError: Error)
}

// MARK: LocalizedError

extension TonutilsTunnelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unableUpdateNetworkSettings(underlyingError):
            return "[TonutilsTunnelError]: Unable update network settings - \(underlyingError)"
        }
    }
}
