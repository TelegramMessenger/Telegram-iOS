import Foundation

public struct InitialMessageHistoryData {
    public let peer: Peer?
    public let storedInterfaceState: StoredPeerChatInterfaceState?
    public let associatedMessages: [MessageId: Message]
}
