import Foundation

public final class SeedConfiguration {
    let initializeChatListWithHoles: [ChatListHole]
    let initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)]
    let existingMessageTags: MessageTags
    let messageTagsWithSummary: MessageTags
    let existingGlobalMessageTags: GlobalMessageTags
    let peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]
    
    public init(initializeChatListWithHoles: [ChatListHole], initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)], existingMessageTags: MessageTags, messageTagsWithSummary: MessageTags, existingGlobalMessageTags: GlobalMessageTags, peerNamespacesRequiringMessageTextIndex: [PeerId.Namespace]) {
        self.initializeChatListWithHoles = initializeChatListWithHoles
        self.initializeMessageNamespacesWithHoles = initializeMessageNamespacesWithHoles
        self.existingMessageTags = existingMessageTags
        self.messageTagsWithSummary = messageTagsWithSummary
        self.existingGlobalMessageTags = existingGlobalMessageTags
        self.peerNamespacesRequiringMessageTextIndex = peerNamespacesRequiringMessageTextIndex
    }
}
