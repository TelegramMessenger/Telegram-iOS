import Foundation
import Display
import Postbox
import SwiftSignalKit

public struct ChatListNodePeersFilter: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let onlyWriteable = ChatListNodePeersFilter(rawValue: 1 << 0)
    public static let onlyPrivateChats = ChatListNodePeersFilter(rawValue: 1 << 1)
    public static let onlyGroups = ChatListNodePeersFilter(rawValue: 1 << 2)
    public static let onlyChannels = ChatListNodePeersFilter(rawValue: 1 << 3)
    public static let onlyManageable = ChatListNodePeersFilter(rawValue: 1 << 4)
    
    public static let excludeSecretChats = ChatListNodePeersFilter(rawValue: 1 << 5)
    public static let excludeRecent = ChatListNodePeersFilter(rawValue: 1 << 6)
    public static let excludeSavedMessages = ChatListNodePeersFilter(rawValue: 1 << 7)
    
    public static let doNotSearchMessages = ChatListNodePeersFilter(rawValue: 1 << 8)
    public static let removeSearchHeader = ChatListNodePeersFilter(rawValue: 1 << 9)
    
    public static let excludeDisabled = ChatListNodePeersFilter(rawValue: 1 << 10)
    public static let includeSavedMessages = ChatListNodePeersFilter(rawValue: 1 << 11)
}

public final class PeerSelectionControllerParams {
    public let context: AccountContext
    public let filter: ChatListNodePeersFilter
    public let hasContactSelector: Bool
    public let title: String?
    
    public init(context: AccountContext, filter: ChatListNodePeersFilter = [.onlyWriteable], hasContactSelector: Bool = true, title: String? = nil) {
        self.context = context
        self.filter = filter
        self.hasContactSelector = hasContactSelector
        self.title = title
    }
}

public protocol PeerSelectionController: ViewController {
    var peerSelected: ((PeerId) -> Void)? { get set }
    var inProgress: Bool { get set }
}
