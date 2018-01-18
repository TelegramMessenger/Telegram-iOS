import Foundation

public enum ChatLocation: Equatable {
    case peer(PeerId)
    case group(PeerGroupId)
    
    public static func ==(lhs: ChatLocation, rhs: ChatLocation) -> Bool {
        switch lhs {
            case let .peer(id):
                if case .peer(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .group(id):
                if case .group(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}
