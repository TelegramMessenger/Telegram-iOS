import Foundation
import Postbox
import TelegramCore

enum ChatPresentationInputQuery: Equatable {
    case hashtag(String)
    case mention(String)
    case command(String)
    case contextRequest(addressName: String, query: String)
    
    static func ==(lhs: ChatPresentationInputQuery, rhs: ChatPresentationInputQuery) -> Bool {
        switch lhs {
            case let .hashtag(query):
                if case .hashtag(query) = rhs {
                    return true
                } else {
                    return false
                }
            case let .mention(query):
                if case .mention(query) = rhs {
                    return true
                } else {
                    return false
                }
            case let .command(query):
                if case .command(query) = rhs {
                    return true
                } else {
                    return false
                }
            case let .contextRequest(addressName, query):
                if case .contextRequest(addressName, query) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

enum ChatPresentationInputQueryResult: Equatable {
    case hashtags([String])
    case mentions([Peer])
    case commands([PeerCommand])
    case contextRequestResult(Peer, ChatContextResultCollection?)
    
    static func ==(lhs: ChatPresentationInputQueryResult, rhs: ChatPresentationInputQueryResult) -> Bool {
        switch lhs {
            case let .hashtags(lhsResults):
                if case let .hashtags(rhsResults) = rhs {
                    return lhsResults == rhsResults
                } else {
                    return false
                }
            case let .mentions(lhsPeers):
                if case let .mentions(rhsPeers) = rhs {
                    if lhsPeers.count != rhsPeers.count {
                        return false
                    } else {
                        for i in 0 ..< lhsPeers.count {
                            if !lhsPeers[i].isEqual(rhsPeers[i]) {
                                return false
                            }
                        }
                        return true
                    }
                } else {
                    return false
                }
            case let .commands(lhsCommands):
                if case let .commands(rhsCommands) = rhs {
                    if lhsCommands != rhsCommands {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .contextRequestResult(lhsPeer, lhsCollection):
                if case let .contextRequestResult(rhsPeer, rhsCollection) = rhs {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if lhsCollection != rhsCollection {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
}

enum ChatInputMode {
    case none
    case text
    case media
}

enum ChatTitlePanelContext: Comparable {
    case chatInfo
    case requestInProgress
    case toastAlert(String)
    
    private var index: Int {
        switch self {
            case .chatInfo:
                return 0
            case .requestInProgress:
                return 1
            case .toastAlert:
                return 2
        }
    }
    
    static func ==(lhs: ChatTitlePanelContext, rhs: ChatTitlePanelContext) -> Bool {
        switch lhs {
            case .chatInfo:
                if case .chatInfo = rhs {
                    return true
                } else {
                    return false
                }
            case .requestInProgress:
                if case .requestInProgress = rhs {
                    return true
                } else {
                    return false
                }
            case let .toastAlert(text):
                if case .toastAlert(text) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatTitlePanelContext, rhs: ChatTitlePanelContext) -> Bool {
        return lhs.index < rhs.index
    }
}

struct ChatPresentationInterfaceState: Equatable {
    let interfaceState: ChatInterfaceState
    let peer: Peer?
    let inputTextPanelState: ChatTextInputPanelState
    let inputQueryResult: ChatPresentationInputQueryResult?
    let inputMode: ChatInputMode
    let titlePanelContexts: [ChatTitlePanelContext]
    
    init() {
        self.interfaceState = ChatInterfaceState()
        self.inputTextPanelState = ChatTextInputPanelState()
        self.peer = nil
        self.inputQueryResult = nil
        self.inputMode = .none
        self.titlePanelContexts = []
    }
    
    init(interfaceState: ChatInterfaceState, peer: Peer?, inputTextPanelState: ChatTextInputPanelState, inputQueryResult: ChatPresentationInputQueryResult?, inputMode: ChatInputMode, titlePanelContexts: [ChatTitlePanelContext]) {
        self.interfaceState = interfaceState
        self.peer = peer
        self.inputTextPanelState = inputTextPanelState
        self.inputQueryResult = inputQueryResult
        self.inputMode = inputMode
        self.titlePanelContexts = titlePanelContexts
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
        
        if lhs.inputQueryResult != rhs.inputQueryResult {
            return false
        }
        
        if lhs.inputMode != rhs.inputMode {
            return false
        }
        
        if lhs.titlePanelContexts != rhs.titlePanelContexts {
            return false
        }
        
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts)
    }
    
    func updatedPeer(_ f: (Peer?) -> Peer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: f(self.peer), inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts)
    }
    
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: f(self.inputQueryResult), inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts)
    }
    
    func updatedInputTextPanelState(_ f: (ChatTextInputPanelState) -> ChatTextInputPanelState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: f(self.inputTextPanelState), inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts)
    }
    
    func updatedInputMode(_ f: (ChatInputMode) -> ChatInputMode) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: f(self.inputMode), titlePanelContexts: self.titlePanelContexts)
    }
    
    func updatedTitlePanelContext(_ f: ([ChatTitlePanelContext]) -> [ChatTitlePanelContext]) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: f(self.titlePanelContexts))
    }
}
