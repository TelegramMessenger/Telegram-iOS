import Foundation

public struct GlobalMessageIdsNamespace: Hashable {
    public let peerIdNamespace: PeerId.Namespace
    public let messageIdNamespace: MessageId.Namespace
    
    public init(peerIdNamespace: PeerId.Namespace, messageIdNamespace: MessageId.Namespace) {
        self.peerIdNamespace = peerIdNamespace
        self.messageIdNamespace = messageIdNamespace
    }
}

public struct ChatListMessageTagSummaryResultComponent {
    public let tag: MessageTags
    public let namespace: MessageId.Namespace
    
    public init(tag: MessageTags, namespace: MessageId.Namespace) {
        self.tag = tag
        self.namespace = namespace
    }
}

public struct ChatListMessageTagActionsSummaryResultComponent {
    public let type: PendingMessageActionType
    public let namespace: MessageId.Namespace
    
    public init(type: PendingMessageActionType, namespace: MessageId.Namespace) {
        self.type = type
        self.namespace = namespace
    }
}

public struct ChatListMessageTagSummaryResultCalculation {
    public let addCount: ChatListMessageTagSummaryResultComponent
    public let subtractCount: ChatListMessageTagActionsSummaryResultComponent
    
    public init(addCount: ChatListMessageTagSummaryResultComponent, subtractCount: ChatListMessageTagActionsSummaryResultComponent) {
        self.addCount = addCount
        self.subtractCount = subtractCount
    }
}

func resolveChatListMessageTagSummaryResultCalculation(addSummary: MessageHistoryTagNamespaceSummary?, subtractSummary: Int32?) -> Bool? {
    let count = (addSummary?.count ?? 0) - (subtractSummary ?? 0)
    return count > 0
}

func resolveChatListMessageTagSummaryResultCalculation(postbox: PostboxImpl, peerId: PeerId, calculation: ChatListMessageTagSummaryResultCalculation?) -> Bool? {
    guard let calculation = calculation else {
        return nil
    }
    let addSummary = postbox.messageHistoryTagsSummaryTable.get(MessageHistoryTagsSummaryKey(tag: calculation.addCount.tag, peerId: peerId, namespace: calculation.addCount.namespace))
    let subtractSummary = postbox.pendingMessageActionsMetadataTable.getCount(.peerNamespaceAction(peerId, calculation.subtractCount.namespace, calculation.subtractCount.type))
    let count = (addSummary?.count ?? 0) - subtractSummary
    return count > 0
}

public final class SeedConfiguration {
    public let globalMessageIdsPeerIdNamespaces: Set<GlobalMessageIdsNamespace>
    public let initializeChatListWithHole: (topLevel: ChatListHole?, groups: ChatListHole?)
    public let messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]]
    public let upgradedMessageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]]
    public let messageThreadHoles: [PeerId.Namespace: [MessageId.Namespace]]
    public let messageTagsWithSummary: MessageTags
    public let existingGlobalMessageTags: GlobalMessageTags
    public let peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]
    public let peerSummaryCounterTags: (Peer, Bool) -> PeerSummaryCounterTags
    public let additionalChatListIndexNamespace: MessageId.Namespace?
    public let messageNamespacesRequiringGroupStatsValidation: Set<MessageId.Namespace>
    public let defaultMessageNamespaceReadStates: [MessageId.Namespace: PeerReadState]
    public let chatMessagesNamespaces: Set<MessageId.Namespace>
    public let getGlobalNotificationSettings: (Transaction) -> PostboxGlobalNotificationSettings?
    public let defaultGlobalNotificationSettings: PostboxGlobalNotificationSettings
    
    public init(
        globalMessageIdsPeerIdNamespaces: Set<GlobalMessageIdsNamespace>,
        initializeChatListWithHole: (
            topLevel: ChatListHole?,
            groups: ChatListHole?
        ),
        messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]],
        upgradedMessageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]],
        messageThreadHoles: [PeerId.Namespace: [MessageId.Namespace]],
        existingMessageTags: MessageTags,
        messageTagsWithSummary: MessageTags,
        existingGlobalMessageTags: GlobalMessageTags,
        peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace],
        peerSummaryCounterTags: @escaping (Peer, Bool) -> PeerSummaryCounterTags,
        additionalChatListIndexNamespace: MessageId.Namespace?,
        messageNamespacesRequiringGroupStatsValidation: Set<MessageId.Namespace>,
        defaultMessageNamespaceReadStates: [MessageId.Namespace: PeerReadState],
        chatMessagesNamespaces: Set<MessageId.Namespace>,
        getGlobalNotificationSettings: @escaping (Transaction) -> PostboxGlobalNotificationSettings?,
        defaultGlobalNotificationSettings: PostboxGlobalNotificationSettings
    ) {
        self.globalMessageIdsPeerIdNamespaces = globalMessageIdsPeerIdNamespaces
        self.initializeChatListWithHole = initializeChatListWithHole
        self.messageHoles = messageHoles
        self.upgradedMessageHoles = upgradedMessageHoles
        self.messageThreadHoles = messageThreadHoles
        self.messageTagsWithSummary = messageTagsWithSummary
        self.existingGlobalMessageTags = existingGlobalMessageTags
        self.peerNamespacesRequiringMessageTextIndex = peerNamespacesRequiringMessageTextIndex
        self.peerSummaryCounterTags = peerSummaryCounterTags
        self.additionalChatListIndexNamespace = additionalChatListIndexNamespace
        self.messageNamespacesRequiringGroupStatsValidation = messageNamespacesRequiringGroupStatsValidation
        self.defaultMessageNamespaceReadStates = defaultMessageNamespaceReadStates
        self.chatMessagesNamespaces = chatMessagesNamespaces
        self.getGlobalNotificationSettings = getGlobalNotificationSettings
        self.defaultGlobalNotificationSettings = defaultGlobalNotificationSettings
    }
}
