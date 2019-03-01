import Foundation
import Postbox

enum FetchManagerCategory: Int32 {
    case image
    case file
    case voice
    case animation
}

enum FetchManagerLocationKey: Comparable, Hashable {
    case messageId(MessageId)
    case free
    
    static func ==(lhs: FetchManagerLocationKey, rhs: FetchManagerLocationKey) -> Bool {
        switch lhs {
            case let .messageId(id):
                if case .messageId(id) = rhs {
                    return true
                } else {
                    return false
                }
            case .free:
                if case .free = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: FetchManagerLocationKey, rhs: FetchManagerLocationKey) -> Bool {
        switch lhs {
            case let .messageId(lhsId):
                if case let .messageId(rhsId) = rhs {
                    return lhsId < rhsId
                } else {
                    return true
                }
            case .free:
                if case .free = rhs {
                    return false
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .messageId(id):
                return id.hashValue
            case .free:
                return 1
        }
    }
}

struct FetchManagerPriorityKey: Comparable {
    let locationKey: FetchManagerLocationKey
    let hasElevatedPriority: Bool
    let userInitiatedPriority: Int32?
    let topReference: FetchManagerPriority?
    
    static func ==(lhs: FetchManagerPriorityKey, rhs: FetchManagerPriorityKey) -> Bool {
        if lhs.locationKey != rhs.locationKey {
            return false
        }
        if lhs.hasElevatedPriority != rhs.hasElevatedPriority {
            return false
        }
        if lhs.userInitiatedPriority != rhs.userInitiatedPriority {
            return false
        }
        if lhs.topReference != rhs.topReference {
            return false
        }
        return true
    }
    
    static func <(lhs: FetchManagerPriorityKey, rhs: FetchManagerPriorityKey) -> Bool {
        if let lhsUserInitiatedPriority = lhs.userInitiatedPriority, let rhsUserInitiatedPriority = rhs.userInitiatedPriority {
            if lhsUserInitiatedPriority != rhsUserInitiatedPriority {
                if lhsUserInitiatedPriority > rhsUserInitiatedPriority {
                    return false
                } else {
                    return true
                }
            }
        } else if (lhs.userInitiatedPriority != nil) != (rhs.userInitiatedPriority != nil) {
            if lhs.userInitiatedPriority != nil {
                return false
            } else {
                return true
            }
        }
        
        if lhs.hasElevatedPriority != rhs.hasElevatedPriority {
            if lhs.hasElevatedPriority {
                return false
            } else {
                return true
            }
        }
        
        if lhs.topReference != rhs.topReference {
            if let lhsTopReference = lhs.topReference, let rhsTopReference = rhs.topReference {
                return lhsTopReference < rhsTopReference
            } else if lhs.topReference != nil {
                return false
            } else {
                return true
            }
        }
        
        return lhs.locationKey < rhs.locationKey
    }
}

enum FetchManagerLocation: Hashable {
    case chat(PeerId)
    
    static func ==(lhs: FetchManagerLocation, rhs: FetchManagerLocation) -> Bool {
        switch lhs {
            case let .chat(peerId):
                if case .chat(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .chat(peerId):
                return peerId.hashValue
        }
    }
}
