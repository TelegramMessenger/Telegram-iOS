import Foundation
import Postbox
import TelegramCore

enum ChatPresentationInputQuery: Equatable {
    case emoji(String)
    case hashtag(String)
    case mention(String)
    case command(String)
    case contextRequest(addressName: String, query: String)
    
    static func ==(lhs: ChatPresentationInputQuery, rhs: ChatPresentationInputQuery) -> Bool {
        switch lhs {
            case let .emoji(query):
                if case .emoji(query) = rhs {
                    return true
                } else {
                    return false
                }
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
    case stickers([FoundStickerItem])
    case hashtags([String])
    case mentions([Peer])
    case commands([PeerCommand])
    case contextRequestResult(Peer, ChatContextResultCollection?)
    
    static func ==(lhs: ChatPresentationInputQueryResult, rhs: ChatPresentationInputQueryResult) -> Bool {
        switch lhs {
        case let .stickers(lhsItems):
                if case let .stickers(rhsItems) = rhs, lhsItems == rhsItems {
                    return true
                } else {
                    return false
                }
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
    case inputButtons
}

enum ChatTitlePanelContext: Comparable {
    case pinnedMessage
    case chatInfo
    case requestInProgress
    case toastAlert(String)
    
    private var index: Int {
        switch self {
            case .pinnedMessage:
                return 0
            case .chatInfo:
                return 1
            case .requestInProgress:
                return 2
            case .toastAlert:
                return 3
        }
    }
    
    static func ==(lhs: ChatTitlePanelContext, rhs: ChatTitlePanelContext) -> Bool {
        switch lhs {
            case .pinnedMessage:
                if case .pinnedMessage = rhs {
                    return true
                } else {
                    return false
                }
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

struct ChatSearchResultsState: Equatable {
    let messageIds: [MessageId]
    let currentId: MessageId?
    
    static func ==(lhs: ChatSearchResultsState, rhs: ChatSearchResultsState) -> Bool {
        if lhs.messageIds != rhs.messageIds {
            return false
        }
        if lhs.currentId != rhs.currentId {
            return false
        }
        return false
    }
}

struct ChatSearchData: Equatable {
    let query: String
    let resultsState: ChatSearchResultsState?
    
    init(query: String = "", resultsState: ChatSearchResultsState? = nil) {
        self.query = query
        self.resultsState = resultsState
    }
    
    static func ==(lhs: ChatSearchData, rhs: ChatSearchData) -> Bool {
        if lhs.query != rhs.query {
            return false
        }
        if lhs.resultsState != rhs.resultsState {
            return false
        }
        return true
    }
    
    func withUpdatedQuery(_ query: String) -> ChatSearchData {
        return ChatSearchData(query: query, resultsState: self.resultsState)
    }
    
    func withUpdatedResultsState(_ resultsState: ChatSearchResultsState?) -> ChatSearchData {
        return ChatSearchData(query: self.query, resultsState: resultsState)
    }
}

struct ChatPresentationInterfaceState: Equatable {
    let interfaceState: ChatInterfaceState
    let peer: Peer?
    let inputTextPanelState: ChatTextInputPanelState
    let inputQueryResult: ChatPresentationInputQueryResult?
    let inputMode: ChatInputMode
    let titlePanelContexts: [ChatTitlePanelContext]
    let keyboardButtonsMessage: Message?
    let pinnedMessageId: MessageId?
    let peerIsBlocked: Bool
    let peerIsMuted: Bool
    let canReportPeer: Bool
    let chatHistoryState: ChatHistoryNodeHistoryState?
    let botStartPayload: String?
    let urlPreview: (String, TelegramMediaWebpage)?
    let search: ChatSearchData?
    let chatWallpaper: TelegramWallpaper
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    init(chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings) {
        self.interfaceState = ChatInterfaceState()
        self.inputTextPanelState = ChatTextInputPanelState()
        self.peer = nil
        self.inputQueryResult = nil
        self.inputMode = .none
        self.titlePanelContexts = []
        self.keyboardButtonsMessage = nil
        self.pinnedMessageId = nil
        self.peerIsBlocked = false
        self.peerIsMuted = false
        self.canReportPeer = false
        self.chatHistoryState = nil
        self.botStartPayload = nil
        self.urlPreview = nil
        self.search = nil
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.strings = strings
    }
    
    init(interfaceState: ChatInterfaceState, peer: Peer?, inputTextPanelState: ChatTextInputPanelState, inputQueryResult: ChatPresentationInputQueryResult?, inputMode: ChatInputMode, titlePanelContexts: [ChatTitlePanelContext], keyboardButtonsMessage: Message?, pinnedMessageId: MessageId?, peerIsBlocked: Bool, peerIsMuted: Bool, canReportPeer: Bool, chatHistoryState: ChatHistoryNodeHistoryState?, botStartPayload: String?, urlPreview: (String, TelegramMediaWebpage)?, search: ChatSearchData?, chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings) {
        self.interfaceState = interfaceState
        self.peer = peer
        self.inputTextPanelState = inputTextPanelState
        self.inputQueryResult = inputQueryResult
        self.inputMode = inputMode
        self.titlePanelContexts = titlePanelContexts
        self.keyboardButtonsMessage = keyboardButtonsMessage
        self.pinnedMessageId = pinnedMessageId
        self.peerIsBlocked = peerIsBlocked
        self.peerIsMuted = peerIsMuted
        self.canReportPeer = canReportPeer
        self.chatHistoryState = chatHistoryState
        self.botStartPayload = botStartPayload
        self.urlPreview = urlPreview
        self.search = search
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.strings = strings
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
        
        if let lhsMessage = lhs.keyboardButtonsMessage, let rhsMessage = rhs.keyboardButtonsMessage {
            if lhsMessage.id != rhsMessage.id {
                return false
            }
            if lhsMessage.stableVersion != rhsMessage.stableVersion {
                return false
            }
        } else if (lhs.keyboardButtonsMessage != nil) != (rhs.keyboardButtonsMessage != nil) {
            return false
        }
        
        if lhs.pinnedMessageId != rhs.pinnedMessageId {
            return false
        }
        
        if lhs.canReportPeer != rhs.canReportPeer {
            return false
        }
        
        if lhs.peerIsBlocked != rhs.peerIsBlocked {
            return false
        }
        
        if lhs.peerIsMuted != rhs.peerIsMuted {
            return false
        }
        
        if lhs.chatHistoryState != rhs.chatHistoryState {
            return false
        }
        
        if lhs.botStartPayload != rhs.botStartPayload {
            return false
        }
        
        if let lhsUrlPreview = lhs.urlPreview, let rhsUrlPreview = rhs.urlPreview {
            if lhsUrlPreview.0 != rhsUrlPreview.0 {
                return false
            }
            if !lhsUrlPreview.1.isEqual(rhsUrlPreview.1) {
                return false
            }
        } else if (lhs.urlPreview != nil) != (rhs.urlPreview != nil) {
            return false
        }
        
        if lhs.search != rhs.search {
            return false
        }
        
        if lhs.chatWallpaper != rhs.chatWallpaper {
            return false
        }
        
        if lhs.theme !== rhs.theme {
            return false
        }
        
        if lhs.strings !== rhs.strings {
            return false
        }
        
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedPeer(_ f: (Peer?) -> Peer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: f(self.peer), inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: f(self.inputQueryResult), inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedInputTextPanelState(_ f: (ChatTextInputPanelState) -> ChatTextInputPanelState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: f(self.inputTextPanelState), inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedInputMode(_ f: (ChatInputMode) -> ChatInputMode) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: f(self.inputMode), titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedTitlePanelContext(_ f: ([ChatTitlePanelContext]) -> [ChatTitlePanelContext]) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: f(self.titlePanelContexts), keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedKeyboardButtonsMessage(_ message: Message?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: message, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedPeerIsBlocked(_ peerIsBlocked: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedPeerIsMuted(_ peerIsMuted: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedCanReportPeer(_ canReportPeer: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedBotStartPayload(_ botStartPayload: String?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedChatHistoryState(_ chatHistoryState: ChatHistoryNodeHistoryState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedUrlPreview(_ urlPreview: (String, TelegramMediaWebpage)?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: urlPreview, search: self.search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
    
    func updatedSearch(_ search: ChatSearchData?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, inputTextPanelState: self.inputTextPanelState, inputQueryResult: self.inputQueryResult, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, canReportPeer: self.canReportPeer, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, search: search, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings)
    }
}
