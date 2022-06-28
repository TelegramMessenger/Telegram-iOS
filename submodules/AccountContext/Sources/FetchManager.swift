import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences
import RangeSet

public enum FetchManagerCategory: Int32 {
    case image
    case file
    case voice
    case animation
}

public enum FetchManagerLocationKey: Comparable, Hashable {
    case messageId(MessageId)
    case free
    
    public static func <(lhs: FetchManagerLocationKey, rhs: FetchManagerLocationKey) -> Bool {
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
}

public struct FetchManagerPriorityKey: Comparable {
    public let locationKey: FetchManagerLocationKey
    public let hasElevatedPriority: Bool
    public let userInitiatedPriority: Int32?
    public let topReference: FetchManagerPriority?
    
    public init(locationKey: FetchManagerLocationKey, hasElevatedPriority: Bool, userInitiatedPriority: Int32?, topReference: FetchManagerPriority?) {
        self.locationKey = locationKey
        self.hasElevatedPriority = hasElevatedPriority
        self.userInitiatedPriority = userInitiatedPriority
        self.topReference = topReference
    }
    
    public static func <(lhs: FetchManagerPriorityKey, rhs: FetchManagerPriorityKey) -> Bool {
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
                return true
            } else {
                return false
            }
        }
        
        if lhs.hasElevatedPriority != rhs.hasElevatedPriority {
            if lhs.hasElevatedPriority {
                return true
            } else {
                return false
            }
        }
        
        if lhs.topReference != rhs.topReference {
            if let lhsTopReference = lhs.topReference, let rhsTopReference = rhs.topReference {
                return lhsTopReference < rhsTopReference
            } else if lhs.topReference != nil {
                return true
            } else {
                return false
            }
        }
        
        return lhs.locationKey < rhs.locationKey
    }
}

public enum FetchManagerLocation: Hashable {
    case chat(PeerId)
}

public enum FetchManagerForegroundDirection {
    case toEarlier
    case toLater
}

public enum FetchManagerPriority: Comparable {
    case userInitiated
    case foregroundPrefetch(direction: FetchManagerForegroundDirection, localOrder: MessageIndex)
    case backgroundPrefetch(locationOrder: HistoryPreloadIndex, localOrder: MessageIndex)
    
    public static func <(lhs: FetchManagerPriority, rhs: FetchManagerPriority) -> Bool {
        switch lhs {
        case .userInitiated:
            switch rhs {
            case .userInitiated:
                return false
            case .foregroundPrefetch:
                return true
            case .backgroundPrefetch:
                return true
            }
        case let .foregroundPrefetch(lhsDirection, lhsLocalOrder):
            switch rhs {
            case .userInitiated:
                return false
            case let .foregroundPrefetch(rhsDirection, rhsLocalOrder):
                if lhsDirection == rhsDirection {
                    switch lhsDirection {
                    case .toEarlier:
                        return lhsLocalOrder > rhsLocalOrder
                    case .toLater:
                        return lhsLocalOrder < rhsLocalOrder
                    }
                } else {
                    if lhsDirection == .toEarlier {
                        return true
                    } else {
                        return false
                    }
                }
            case .backgroundPrefetch:
                return true
            }
        case let .backgroundPrefetch(lhsLocationOrder, lhsLocalOrder):
            switch rhs {
            case .userInitiated:
                return false
            case .foregroundPrefetch:
                return false
            case let .backgroundPrefetch(rhsLocationOrder, rhsLocalOrder):
                if lhsLocationOrder != rhsLocationOrder {
                    return lhsLocationOrder < rhsLocationOrder
                }
                return lhsLocalOrder > rhsLocalOrder
            }
        }
    }
}

public protocol FetchManager {
    var queue: Queue { get }
    
    func interactivelyFetched(category: FetchManagerCategory, location: FetchManagerLocation, locationKey: FetchManagerLocationKey, mediaReference: AnyMediaReference?, resourceReference: MediaResourceReference, ranges: RangeSet<Int64>, statsCategory: MediaResourceStatsCategory, elevatedPriority: Bool, userInitiated: Bool, priority: FetchManagerPriority, storeToDownloadsPeerType: MediaAutoDownloadPeerType?) -> Signal<Void, NoError>
    func cancelInteractiveFetches(category: FetchManagerCategory, location: FetchManagerLocation, locationKey: FetchManagerLocationKey, resource: MediaResource)
    func cancelInteractiveFetches(resourceId: String)
    func toggleInteractiveFetchPaused(resourceId: String, isPaused: Bool)
    func raisePriority(resourceId: String)
    func fetchStatus(category: FetchManagerCategory, location: FetchManagerLocation, locationKey: FetchManagerLocationKey, resource: MediaResource) -> Signal<MediaResourceStatus, NoError>
}

public protocol PrefetchManager {
    var preloadedGreetingSticker: ChatGreetingData { get }
    func prepareNextGreetingSticker()
}
