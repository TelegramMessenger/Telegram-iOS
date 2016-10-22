import Foundation
import Postbox

enum ChatPresentationInputContext {
    case hashtag
    case mention
}

enum ChatInputMode {
    case none
    case text
    case media
}

struct ChatPresentationInterfaceState: Equatable {
    let interfaceState: ChatInterfaceState
    let peer: Peer?
    let inputTextPanelState: ChatTextInputPanelState
    let inputContext: ChatPresentationInputContext?
    let inputMode: ChatInputMode
    
    init() {
        self.interfaceState = ChatInterfaceState()
        self.inputTextPanelState = ChatTextInputPanelState()
        self.peer = nil
        self.inputContext = nil
        self.inputMode = .none
    }
    
    init(interfaceState: ChatInterfaceState, peer: Peer?, inputTextPanelState: ChatTextInputPanelState, inputContext: ChatPresentationInputContext?, inputMode: ChatInputMode) {
        self.interfaceState = interfaceState
        self.peer = peer
        self.inputTextPanelState = inputTextPanelState
        self.inputContext = inputContext
        self.inputMode = inputMode
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
        
        if lhs.inputTextPanelState != rhs.inputTextPanelState {
            return false
        }
        
        if lhs.inputContext != rhs.inputContext {
            return false
        }
        
        if lhs.inputMode != rhs.inputMode {
            return false
        }
        
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputContext: self.inputContext, inputMode: self.inputMode)
    }
    
    func updatedPeer(_ f: (Peer?) -> Peer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: f(self.peer), inputTextPanelState: self.inputTextPanelState, inputContext: self.inputContext, inputMode: self.inputMode)
    }
    
    func updatedInputContext(_ f: (ChatPresentationInputContext?) -> ChatPresentationInputContext?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputContext: f(self.inputContext), inputMode: self.inputMode)
    }
    
    func updatedInputTextPanelState(_ f: (ChatTextInputPanelState) -> ChatTextInputPanelState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: f(self.inputTextPanelState), inputContext: self.inputContext, inputMode: self.inputMode)
    }
    
    func updatedInputMode(_ f: (ChatInputMode) -> ChatInputMode) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputContext: self.inputContext, inputMode: f(self.inputMode))
    }
}
