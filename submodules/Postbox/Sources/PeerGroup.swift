import Foundation

public enum PeerGroupId: Hashable, Equatable, RawRepresentable {
    case root
    case group(Int32)
    
    public var rawValue: Int32 {
        switch self {
            case .root:
                return 0
            case let .group(id):
                return id
        }
    }
    
    public init(rawValue: Int32) {
        if rawValue == 0 {
            self = .root
        } else {
            self = .group(rawValue)
        }
    }
}
