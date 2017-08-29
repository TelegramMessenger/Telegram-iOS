
public protocol PeerChatListEmbeddedInterfaceState: PostboxCoding {
    var timestamp: Int32 { get }
    
    func isEqual(to: PeerChatListEmbeddedInterfaceState) -> Bool
}

public protocol PeerChatInterfaceState: PostboxCoding {
    var chatListEmbeddedState: PeerChatListEmbeddedInterfaceState? { get }
    
    func isEqual(to: PeerChatInterfaceState) -> Bool
}
