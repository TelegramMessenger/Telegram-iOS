
public protocol PeerChatListEmbeddedInterfaceState: Coding {
    var timestamp: Int32 { get }
    
    func isEqual(to: PeerChatListEmbeddedInterfaceState) -> Bool
}

public protocol PeerChatInterfaceState: Coding {
    var chatListEmbeddedState: PeerChatListEmbeddedInterfaceState? { get }
    
    func isEqual(to: PeerChatInterfaceState) -> Bool
}
