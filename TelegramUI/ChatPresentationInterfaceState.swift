import Foundation
import Postbox

enum ChatPresentationInputContext {
    case hashtag
    case mention
}

struct ChatPresentationInterfaceState: Equatable {
    let interfaceState: ChatInterfaceState
    let peer: Peer?
    let inputContext: ChatPresentationInputContext?
    
    init() {
        self.interfaceState = ChatInterfaceState()
        self.peer = nil
        self.inputContext = nil
    }
    
    init(interfaceState: ChatInterfaceState, peer: Peer?, inputContext: ChatPresentationInputContext?) {
        self.interfaceState = interfaceState
        self.peer = peer
        self.inputContext = inputContext
    }
    
    static func ==(lhs: ChatPresentationInterfaceState, rhs: ChatPresentationInterfaceState) -> Bool {
        if lhs.interfaceState != rhs.interfaceState {
            return false
        }
        if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.peer == nil) != (rhs.peer == nil) {
            return false
        }
        
        if lhs.inputContext != rhs.inputContext {
            return false
        }
        
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), peer: self.peer, inputContext: self.inputContext)
    }
    
    func updatedPeer(_ f: (Peer?) -> Peer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: f(self.peer), inputContext: self.inputContext)
    }
    
    func updatedInputContext(_ f: (ChatPresentationInputContext?) -> ChatPresentationInputContext?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputContext: f(self.inputContext))
    }
}
