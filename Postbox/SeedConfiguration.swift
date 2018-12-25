import Foundation

public final class SeedConfiguration {
    public let initializeChatListWithHole: (topLevel: ChatListHole?, groups: ChatListHole?)
    public let initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)]
    public let existingMessageTags: MessageTags
    public let messageTagsWithSummary: MessageTags
    public let existingGlobalMessageTags: GlobalMessageTags
    public let peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]
    public let peerSummaryCounterTags: (Peer) -> PeerSummaryCounterTags
    public let additionalChatListIndexNamespace: MessageId.Namespace?
    
    public init(initializeChatListWithHole: (topLevel: ChatListHole?, groups: ChatListHole?), initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)], existingMessageTags: MessageTags, messageTagsWithSummary: MessageTags, existingGlobalMessageTags: GlobalMessageTags, peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace], peerSummaryCounterTags: @escaping (Peer) -> PeerSummaryCounterTags, additionalChatListIndexNamespace: MessageId.Namespace?) {
        self.initializeChatListWithHole = initializeChatListWithHole
        self.initializeMessageNamespacesWithHoles = initializeMessageNamespacesWithHoles
        self.existingMessageTags = existingMessageTags
        self.messageTagsWithSummary = messageTagsWithSummary
        self.existingGlobalMessageTags = existingGlobalMessageTags
        self.peerNamespacesRequiringMessageTextIndex = peerNamespacesRequiringMessageTextIndex
        self.peerSummaryCounterTags = peerSummaryCounterTags
        self.additionalChatListIndexNamespace = additionalChatListIndexNamespace
    }
}
