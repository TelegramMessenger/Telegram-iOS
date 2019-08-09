import Foundation

public struct GlobalMessageIdsNamespace: Hashable {
    public let peerIdNamespace: PeerId.Namespace
    public let messageIdNamespace: MessageId.Namespace
    
    public init(peerIdNamespace: PeerId.Namespace, messageIdNamespace: MessageId.Namespace) {
        self.peerIdNamespace = peerIdNamespace
        self.messageIdNamespace = messageIdNamespace
    }
}

public final class SeedConfiguration {
    public let globalMessageIdsPeerIdNamespaces: Set<GlobalMessageIdsNamespace>
    public let initializeChatListWithHole: (topLevel: ChatListHole?, groups: ChatListHole?)
    public let messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]]
    public let messageTagsWithSummary: MessageTags
    public let existingGlobalMessageTags: GlobalMessageTags
    public let peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]
    public let peerSummaryCounterTags: (Peer) -> PeerSummaryCounterTags
    public let additionalChatListIndexNamespace: MessageId.Namespace?
    public let messageNamespacesRequiringGroupStatsValidation: Set<MessageId.Namespace>
    public let defaultMessageNamespaceReadStates: [MessageId.Namespace: PeerReadState]
    public let chatMessagesNamespaces: Set<MessageId.Namespace>
    
    public init(globalMessageIdsPeerIdNamespaces: Set<GlobalMessageIdsNamespace>, initializeChatListWithHole: (topLevel: ChatListHole?, groups: ChatListHole?), messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]], existingMessageTags: MessageTags, messageTagsWithSummary: MessageTags, existingGlobalMessageTags: GlobalMessageTags, peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace], peerSummaryCounterTags: @escaping (Peer) -> PeerSummaryCounterTags, additionalChatListIndexNamespace: MessageId.Namespace?, messageNamespacesRequiringGroupStatsValidation: Set<MessageId.Namespace>, defaultMessageNamespaceReadStates: [MessageId.Namespace: PeerReadState], chatMessagesNamespaces: Set<MessageId.Namespace>) {
        self.globalMessageIdsPeerIdNamespaces = globalMessageIdsPeerIdNamespaces
        self.initializeChatListWithHole = initializeChatListWithHole
        self.messageHoles = messageHoles
        self.messageTagsWithSummary = messageTagsWithSummary
        self.existingGlobalMessageTags = existingGlobalMessageTags
        self.peerNamespacesRequiringMessageTextIndex = peerNamespacesRequiringMessageTextIndex
        self.peerSummaryCounterTags = peerSummaryCounterTags
        self.additionalChatListIndexNamespace = additionalChatListIndexNamespace
        self.messageNamespacesRequiringGroupStatsValidation = messageNamespacesRequiringGroupStatsValidation
        self.defaultMessageNamespaceReadStates = defaultMessageNamespaceReadStates
        self.chatMessagesNamespaces = chatMessagesNamespaces
    }
}
