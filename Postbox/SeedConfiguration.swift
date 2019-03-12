import Foundation

public final class SeedConfiguration {
    public let initializeChatListWithHole: (topLevel: ChatListHole?, groups: ChatListHole?)
    public let messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]]
    public let messageTagsWithSummary: MessageTags
    public let existingGlobalMessageTags: GlobalMessageTags
    public let peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]
    public let peerSummaryCounterTags: (Peer) -> PeerSummaryCounterTags
    public let additionalChatListIndexNamespace: MessageId.Namespace?
    
    public init(initializeChatListWithHole: (topLevel: ChatListHole?, groups: ChatListHole?), messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]], messageTagsWithSummary: MessageTags, existingGlobalMessageTags: GlobalMessageTags, peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace], peerSummaryCounterTags: @escaping (Peer) -> PeerSummaryCounterTags, additionalChatListIndexNamespace: MessageId.Namespace?) {
        self.initializeChatListWithHole = initializeChatListWithHole
        self.messageHoles = messageHoles
        self.messageTagsWithSummary = messageTagsWithSummary
        self.existingGlobalMessageTags = existingGlobalMessageTags
        self.peerNamespacesRequiringMessageTextIndex = peerNamespacesRequiringMessageTextIndex
        self.peerSummaryCounterTags = peerSummaryCounterTags
        self.additionalChatListIndexNamespace = additionalChatListIndexNamespace
    }
}
