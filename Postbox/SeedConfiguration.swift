import Foundation

public final class SeedConfiguration {
    let initializeChatListWithHoles: [ChatListHole]
    let initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)]
    let existingMessageTags: MessageTags
    let existingGlobalMessageTags: GlobalMessageTags
    
    public init(initializeChatListWithHoles: [ChatListHole], initializeMessageNamespacesWithHoles: [(PeerId.Namespace, MessageId.Namespace)], existingMessageTags: MessageTags, existingGlobalMessageTags: GlobalMessageTags) {
        self.initializeChatListWithHoles = initializeChatListWithHoles
        self.initializeMessageNamespacesWithHoles = initializeMessageNamespacesWithHoles
        self.existingMessageTags = existingMessageTags
        self.existingGlobalMessageTags = existingGlobalMessageTags
    }
}
