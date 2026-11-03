import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AnimationCache
import MultiAnimationRenderer

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
    
    public static let excludeChannels = ChatListNodePeersFilter(rawValue: 1 << 12)
    public static let onlyGroupsAndChannels = ChatListNodePeersFilter(rawValue: 1 << 13)
    
    public static let excludeGroups = ChatListNodePeersFilter(rawValue: 1 << 14)
    public static let excludeUsers = ChatListNodePeersFilter(rawValue: 1 << 15)
    public static let excludeBots = ChatListNodePeersFilter(rawValue: 1 << 16)
    public static let includeCommunities = ChatListNodePeersFilter(rawValue: 1 << 17)
    
    public static let includeSelf = ChatListNodePeersFilter(rawValue: 1 << 7)
}


public enum ChatListDisabledPeerReason {
    case generic
    case premiumRequired
}

public final class CommunityPeerSelectionOptions {
    public let filter: ChatListNodePeersFilter
    public let requestPeerType: [ReplyMarkupButtonRequestPeerType]?
    public let excludedPeerIds: Set<EnginePeer.Id>
    public let selectPeer: (EnginePeer) -> Void
    public let selectDisabledPeer: (EnginePeer, ChatListDisabledPeerReason) -> Void

    public init(
        filter: ChatListNodePeersFilter,
        requestPeerType: [ReplyMarkupButtonRequestPeerType]?,
        excludedPeerIds: Set<EnginePeer.Id>,
        selectPeer: @escaping (EnginePeer) -> Void,
        selectDisabledPeer: @escaping (EnginePeer, ChatListDisabledPeerReason) -> Void
    ) {
        self.filter = filter
        self.requestPeerType = requestPeerType
        self.excludedPeerIds = excludedPeerIds
        self.selectPeer = selectPeer
        self.selectDisabledPeer = selectDisabledPeer
    }
}

public final class PeerSelectionControllerParams {
    public let context: AccountContext
    public let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let filter: ChatListNodePeersFilter
    public let requestPeerType: [ReplyMarkupButtonRequestPeerType]?
    public let showPeerTypeRequirements: Bool
    public let forumPeerId: (id: EnginePeer.Id, isMonoforum: Bool)?
    public let hasFilters: Bool
    public let hasChatListSelector: Bool
    public let hasContactSelector: Bool
    public let hasGlobalSearch: Bool
    public let title: String?
    public let attemptSelection: ((EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void)?
    public let createNewGroup: (() -> Void)?
    public let pretendPresentedInModal: Bool
    public let multipleSelection: Bool
    public let multipleSelectionLimit: Int32?
    public let forwardedMessageIds: [EngineMessage.Id]
    public let hasTypeHeaders: Bool
    public let selectForumThreads: Bool
    public let hasCreation: Bool
    public let immediatelySwitchToContacts: Bool
    public let immediatelyActivateMultipleSelection: Bool
    public let suggestedPeers: [EnginePeer]
    public let excludedPeerIds: Set<EnginePeer.Id>
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        filter: ChatListNodePeersFilter = [.onlyWriteable],
        requestPeerType: [ReplyMarkupButtonRequestPeerType]? = nil,
        showPeerTypeRequirements: Bool = true,
        forumPeerId: (id: EnginePeer.Id, isMonoforum: Bool)? = nil,
        hasFilters: Bool = false,
        hasChatListSelector: Bool = true,
        hasContactSelector: Bool = true,
        hasGlobalSearch: Bool = true,
        title: String? = nil,
        attemptSelection: ((EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void)? = nil,
        createNewGroup: (() -> Void)? = nil,
        pretendPresentedInModal: Bool = false,
        multipleSelection: Bool = false,
        multipleSelectionLimit: Int32? = nil,
        forwardedMessageIds: [EngineMessage.Id] = [],
        hasTypeHeaders: Bool = false,
        selectForumThreads: Bool = false,
        hasCreation: Bool = false,
        immediatelySwitchToContacts: Bool = false,
        immediatelyActivateMultipleSelection: Bool = false,
        suggestedPeers: [EnginePeer] = [],
        excludedPeerIds: Set<EnginePeer.Id> = []
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.filter = filter
        self.requestPeerType = requestPeerType
        self.showPeerTypeRequirements = showPeerTypeRequirements
        self.forumPeerId = forumPeerId
        self.hasFilters = hasFilters
        self.hasChatListSelector = hasChatListSelector
        self.hasContactSelector = hasContactSelector
        self.hasGlobalSearch = hasGlobalSearch
        self.title = title
        self.attemptSelection = attemptSelection
        self.createNewGroup = createNewGroup
        self.pretendPresentedInModal = pretendPresentedInModal
        self.multipleSelection = multipleSelection
        self.multipleSelectionLimit = multipleSelectionLimit
        self.forwardedMessageIds = forwardedMessageIds
        self.hasTypeHeaders = hasTypeHeaders
        self.selectForumThreads = selectForumThreads
        self.hasCreation = hasCreation
        self.immediatelySwitchToContacts = immediatelySwitchToContacts
        self.immediatelyActivateMultipleSelection = immediatelyActivateMultipleSelection
        self.suggestedPeers = suggestedPeers
        self.excludedPeerIds = excludedPeerIds
    }
}

public enum AttachmentTextInputPanelSendMode {
    case generic
    case silent
    case schedule
    case whenOnline
}

public protocol PeerSelectionController: ViewController {
    var peerSelected: ((EnginePeer, Int64?) -> Void)? { get set }
    var multiplePeersSelected: (([EnginePeer], [EnginePeer.Id: EnginePeer], NSAttributedString, AttachmentTextInputPanelSendMode, ChatInterfaceForwardOptionsState?, ChatSendMessageActionSheetController.SendParameters?) -> Void)? { get set }
    var inProgress: Bool { get set }
    var customDismiss: (() -> Void)? { get set }
}

public enum SelectivePrivacySettingsKind {
    case presence
    case groupInvitations
    case voiceCalls
    case profilePhoto
    case forwards
    case phoneNumber
    case voiceMessages
    case bio
    case birthday
    case savedMusic
    case giftsAutoSave
}
