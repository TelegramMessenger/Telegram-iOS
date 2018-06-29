import Foundation

public struct InitialMessageHistoryData {
    public let peer: Peer?
    public let chatInterfaceState: PeerChatInterfaceState?
    public let associatedMessages: [MessageId: Message]
}
