import Foundation

public final class SeedConfiguration {
    public let initializeChatListWithHoles: [ChatListHole]
    public let initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)]
    public let existingMessageTags: MessageTags
    public let messageTagsWithSummary: MessageTags
    public let existingGlobalMessageTags: GlobalMessageTags
    public let peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]
    
    public init(initializeChatListWithHoles: [ChatListHole], initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)], existingMessageTags: MessageTags, messageTagsWithSummary: MessageTags, existingGlobalMessageTags: GlobalMessageTags, peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]) {
        self.initializeChatListWithHoles = initializeChatListWithHoles
        self.initializeMessageNamespacesWithHoles = initializeMessageNamespacesWithHoles
        self.existingMessageTags = existingMessageTags
        self.messageTagsWithSummary = messageTagsWithSummary
        self.existingGlobalMessageTags = existingGlobalMessageTags
        self.peerNamespacesRequiringMessageTextIndex = peerNamespacesRequiringMessageTextIndex
    }
}
