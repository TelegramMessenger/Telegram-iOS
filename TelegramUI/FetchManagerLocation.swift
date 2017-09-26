import Foundation
import Postbox

enum FetchManagerCategory: Int32 {
    case image
    case file
}

protocol FetchManagerLocationKey: class {
    func isEqual(to: FetchManagerLocationKey) -> Bool
    func isLess(than: FetchManagerLocationKey) -> Bool
    var hashValue: Int { get }
}

struct FetchManagerCategoryLocationKey: Hashable {
    let location: FetchManagerLocation
    let category: FetchManagerCategory
    
    var hashValue: Int {
        return self.location.hashValue &* 31 &+ self.category.hashValue
    }
    
    static func ==(lhs: FetchManagerCategoryLocationKey, rhs: FetchManagerCategoryLocationKey) -> Bool {
        if lhs.location != rhs.location {
            return false
        }
        if lhs.category != rhs.category {
            return false
        }
        return true
    }
}

struct FetchManagerPriorityKey: Comparable {
    let locationKey: FetchManagerLocationKey
    let hasElevatedPriority: Bool
    let userInitiatedPriority: Int32?
    
    static func ==(lhs: FetchManagerPriorityKey, rhs: FetchManagerPriorityKey) -> Bool {
        if !lhs.locationKey.isEqual(to: rhs.locationKey) {
            return false
        }
        if lhs.hasElevatedPriority != rhs.hasElevatedPriority {
            return false
        }
        if lhs.userInitiatedPriority != rhs.userInitiatedPriority {
            return false
        }
        return true
    }
    
    static func <(lhs: FetchManagerPriorityKey, rhs: FetchManagerPriorityKey) -> Bool {
        if let lhsUserInitiatedPriority = lhs.userInitiatedPriority, let rhsUserInitiatedPriority = rhs.userInitiatedPriority {
            if lhsUserInitiatedPriority != rhsUserInitiatedPriority {
                if lhsUserInitiatedPriority < rhsUserInitiatedPriority {
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
        
        return lhs.locationKey.isLess(than: rhs.locationKey)
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
