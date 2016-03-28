import Foundation

public final class SeedConfiguration {
    let initializeChatListWithHoles: [ChatListHole]
    let initializeMessageNamespacesWithHoles: [MessageId.Namespace]
    let existingMessageTags: MessageTags
    
    public init(initializeChatListWithHoles: [ChatListHole], initializeMessageNamespacesWithHoles: [MessageId.Namespace], existingMessageTags: MessageTags) {
        self.initializeChatListWithHoles = initializeChatListWithHoles
        self.initializeMessageNamespacesWithHoles = initializeMessageNamespacesWithHoles
        self.existingMessageTags = existingMessageTags
    }
}
