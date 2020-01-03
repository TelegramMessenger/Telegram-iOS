import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

enum ChatPresentationInputQueryKind: Int32 {
    case emoji
    case hashtag
    case mention
    case command
    case contextRequest
    case emojiSearch
}

struct ChatInputQueryMentionTypes: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let contextBots = ChatInputQueryMentionTypes(rawValue: 1 << 0)
    static let members = ChatInputQueryMentionTypes(rawValue: 1 << 1)
    static let accountPeer = ChatInputQueryMentionTypes(rawValue: 1 << 2)
}

enum ChatPresentationInputQuery: Hashable, Equatable {
    case emoji(String)
    case hashtag(String)
    case mention(query: String, types: ChatInputQueryMentionTypes)
    case command(String)
    case emojiSearch(query: String, languageCode: String, range: NSRange)
    case contextRequest(addressName: String, query: String)
    
    var kind: ChatPresentationInputQueryKind {
        switch self {
            case .emoji:
                return .emoji
            case .hashtag:
                return .hashtag
            case .mention:
                return .mention
            case .command:
                return .command
            case .contextRequest:
                return .contextRequest
            case .emojiSearch:
                return .emojiSearch
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .emoji(value):
                return 1 &+ value.hashValue
            case let .hashtag(value):
                return 2 &+ value.hashValue
            case let .mention(text, types):
                return 3 &+ text.hashValue &* 31 &+ types.rawValue.hashValue
            case let .command(value):
                return 4 &+ value.hashValue
            case let .contextRequest(addressName, query):
                return 5 &+ addressName.hashValue &* 31 &+ query.hashValue
            case let .emojiSearch(value, languageCode, range):
                var hash = value.hashValue
                hash = hash &* 31 &+ languageCode.hashValue
                hash = hash &* 31 &+ range.hashValue
                return 6 &+ hash
        }
    }
}

enum ChatMediaInputMode {
    case gif
    case other
}

enum ChatMediaInputSearchMode {
    case gif
    case sticker
    case trending
}

enum ChatMediaInputExpanded: Equatable {
    case content
    case search(ChatMediaInputSearchMode)
}

enum ChatInputMode: Equatable {
    case none
    case text
    case media(mode: ChatMediaInputMode, expanded: ChatMediaInputExpanded?)
    case inputButtons
}

enum ChatTitlePanelContext: Equatable, Comparable {
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
    
    static func <(lhs: ChatTitlePanelContext, rhs: ChatTitlePanelContext) -> Bool {
        return lhs.index < rhs.index
    }
}

struct ChatSearchResultsState: Equatable {
    let messageIndices: [MessageIndex]
    let currentId: MessageId?
    let state: SearchMessagesState
    let totalCount: Int32
    let completed: Bool
}

enum ChatSearchDomain: Equatable {
    case everything
    case members
    case member(Peer)
    
    static func ==(lhs: ChatSearchDomain, rhs: ChatSearchDomain) -> Bool {
        switch lhs {
            case .everything:
                if case .everything = rhs {
                    return true
                } else {
                    return false
                }
            case .members:
                if case .members = rhs {
                    return true
                } else {
                    return false
                }
            case let .member(lhsPeer):
                if case let .member(rhsPeer) = rhs, lhsPeer.isEqual(rhsPeer) {
                    return true
                } else {
                    return false
                }
        }
    }
}
    
enum ChatSearchDomainSuggestionContext: Equatable {
    case none
    case members(String)
}

struct ChatSearchData: Equatable {
    let query: String
    let domain: ChatSearchDomain
    let domainSuggestionContext: ChatSearchDomainSuggestionContext
    let resultsState: ChatSearchResultsState?
    
    init(query: String = "", domain: ChatSearchDomain = .everything, domainSuggestionContext: ChatSearchDomainSuggestionContext = .none, resultsState: ChatSearchResultsState? = nil) {
        self.query = query
        self.domain = domain
        self.domainSuggestionContext = domainSuggestionContext
        self.resultsState = resultsState
    }
    
    static func ==(lhs: ChatSearchData, rhs: ChatSearchData) -> Bool {
        if lhs.query != rhs.query {
            return false
        }
        if lhs.domain != rhs.domain {
            return false
        }
        if lhs.domainSuggestionContext != rhs.domainSuggestionContext {
            return false
        }
        if lhs.resultsState != rhs.resultsState {
            return false
        }
        return true
    }
    
    func withUpdatedQuery(_ query: String) -> ChatSearchData {
        return ChatSearchData(query: query, domain: self.domain, domainSuggestionContext: self.domainSuggestionContext, resultsState: self.resultsState)
    }
    
    func withUpdatedDomain(_ domain: ChatSearchDomain) -> ChatSearchData {
        return ChatSearchData(query: self.query, domain: domain, domainSuggestionContext: self.domainSuggestionContext, resultsState: self.resultsState)
    }
    
    func withUpdatedDomainSuggestionContext(_ domain: ChatSearchDomainSuggestionContext) -> ChatSearchData {
        return ChatSearchData(query: self.query, domain: self.domain, domainSuggestionContext: domainSuggestionContext, resultsState: self.resultsState)
    }
    
    func withUpdatedResultsState(_ resultsState: ChatSearchResultsState?) -> ChatSearchData {
        return ChatSearchData(query: self.query, domain: self.domain, domainSuggestionContext: self.domainSuggestionContext, resultsState: resultsState)
    }
}

final class ChatRecordedMediaPreview: Equatable {
    let resource: TelegramMediaResource
    let fileSize: Int32
    let duration: Int32
    let waveform: AudioWaveform
    
    init(resource: TelegramMediaResource, duration: Int32, fileSize: Int32, waveform: AudioWaveform) {
        self.resource = resource
        self.duration = duration
        self.fileSize = fileSize
        self.waveform = waveform
    }
    
    static func ==(lhs: ChatRecordedMediaPreview, rhs: ChatRecordedMediaPreview) -> Bool {
        if !lhs.resource.isEqual(to: rhs.resource) {
            return false
        }
        if lhs.duration != rhs.duration {
            return false
        }
        if lhs.fileSize != rhs.fileSize {
            return false
        }
        if lhs.waveform != rhs.waveform {
            return false
        }
        return true
    }
}

struct ChatContactStatus: Equatable {
    var canAddContact: Bool
    var canReportIrrelevantLocation: Bool
    var peerStatusSettings: PeerStatusSettings?
    
    var isEmpty: Bool {
        guard var peerStatusSettings = self.peerStatusSettings else {
            return false
        }
        if !self.canAddContact {
            peerStatusSettings.remove(.canAddContact)
        }
        if !self.canReportIrrelevantLocation {
            peerStatusSettings.remove(.canReportIrrelevantGeoLocation)
        }
        return peerStatusSettings.isEmpty
    }
}

enum ChatSlowmodeVariant: Equatable {
    case timestamp(Int32)
    case pendingMessages
}

struct ChatSlowmodeState: Equatable {
    var timeout: Int32
    var variant: ChatSlowmodeVariant
}

final class ChatPresentationInterfaceState: Equatable {
    let interfaceState: ChatInterfaceState
    let chatLocation: ChatLocation
    let renderedPeer: RenderedPeer?
    let isNotAccessible: Bool
    let explicitelyCanPinMessages: Bool
    let contactStatus: ChatContactStatus?
    let hasBots: Bool
    let isArchived: Bool
    let inputTextPanelState: ChatTextInputPanelState
    let editMessageState: ChatEditInterfaceMessageState?
    let recordedMediaPreview: ChatRecordedMediaPreview?
    let inputQueryResults: [ChatPresentationInputQueryKind: ChatPresentationInputQueryResult]
    let inputMode: ChatInputMode
    let titlePanelContexts: [ChatTitlePanelContext]
    let keyboardButtonsMessage: Message?
    let pinnedMessageId: MessageId?
    let pinnedMessage: Message?
    let peerIsBlocked: Bool
    let peerIsMuted: Bool
    let peerDiscussionId: PeerId?
    let peerGeoLocation: PeerGeoLocation?
    let callsAvailable: Bool
    let callsPrivate: Bool
    let slowmodeState: ChatSlowmodeState?
    let chatHistoryState: ChatHistoryNodeHistoryState?
    let botStartPayload: String?
    let urlPreview: (String, TelegramMediaWebpage)?
    let editingUrlPreview: (String, TelegramMediaWebpage)?
    let search: ChatSearchData?
    let searchQuerySuggestionResult: ChatPresentationInputQueryResult?
    let chatWallpaper: TelegramWallpaper
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let limitsConfiguration: LimitsConfiguration
    let fontSize: PresentationFontSize
    let accountPeerId: PeerId
    let mode: ChatControllerPresentationMode
    let hasScheduledMessages: Bool
    let isScheduledMessages: Bool
    
    init(chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, limitsConfiguration: LimitsConfiguration, fontSize: PresentationFontSize, accountPeerId: PeerId, mode: ChatControllerPresentationMode, chatLocation: ChatLocation, isScheduledMessages: Bool) {
        self.interfaceState = ChatInterfaceState()
        self.inputTextPanelState = ChatTextInputPanelState()
        self.editMessageState = nil
        self.recordedMediaPreview = nil
        self.chatLocation = chatLocation
        self.renderedPeer = nil
        self.isNotAccessible = false
        self.explicitelyCanPinMessages = false
        self.contactStatus = nil
        self.hasBots = false
        self.isArchived = false
        self.inputQueryResults = [:]
        self.inputMode = .none
        self.titlePanelContexts = []
        self.keyboardButtonsMessage = nil
        self.pinnedMessageId = nil
        self.pinnedMessage = nil
        self.peerIsBlocked = false
        self.peerIsMuted = false
        self.peerDiscussionId = nil
        self.peerGeoLocation = nil
        self.callsAvailable = false
        self.callsPrivate = false
        self.slowmodeState = nil
        self.chatHistoryState = nil
        self.botStartPayload = nil
        self.urlPreview = nil
        self.editingUrlPreview = nil
        self.search = nil
        self.searchQuerySuggestionResult = nil
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.limitsConfiguration = limitsConfiguration
        self.fontSize = fontSize
        self.accountPeerId = accountPeerId
        self.mode = mode
        self.hasScheduledMessages = false
        self.isScheduledMessages = isScheduledMessages
    }
    
    init(interfaceState: ChatInterfaceState, chatLocation: ChatLocation, renderedPeer: RenderedPeer?, isNotAccessible: Bool, explicitelyCanPinMessages: Bool, contactStatus: ChatContactStatus?, hasBots: Bool, isArchived: Bool, inputTextPanelState: ChatTextInputPanelState, editMessageState: ChatEditInterfaceMessageState?, recordedMediaPreview: ChatRecordedMediaPreview?, inputQueryResults: [ChatPresentationInputQueryKind: ChatPresentationInputQueryResult], inputMode: ChatInputMode, titlePanelContexts: [ChatTitlePanelContext], keyboardButtonsMessage: Message?, pinnedMessageId: MessageId?, pinnedMessage: Message?, peerIsBlocked: Bool, peerIsMuted: Bool, peerDiscussionId: PeerId?, peerGeoLocation: PeerGeoLocation?, callsAvailable: Bool, callsPrivate: Bool, slowmodeState: ChatSlowmodeState?, chatHistoryState: ChatHistoryNodeHistoryState?, botStartPayload: String?, urlPreview: (String, TelegramMediaWebpage)?, editingUrlPreview: (String, TelegramMediaWebpage)?, search: ChatSearchData?, searchQuerySuggestionResult: ChatPresentationInputQueryResult?, chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, limitsConfiguration: LimitsConfiguration, fontSize: PresentationFontSize, accountPeerId: PeerId, mode: ChatControllerPresentationMode, hasScheduledMessages: Bool, isScheduledMessages: Bool) {
        self.interfaceState = interfaceState
        self.chatLocation = chatLocation
        self.renderedPeer = renderedPeer
        self.isNotAccessible = isNotAccessible
        self.explicitelyCanPinMessages = explicitelyCanPinMessages
        self.contactStatus = contactStatus
        self.hasBots = hasBots
        self.isArchived = isArchived
        self.inputTextPanelState = inputTextPanelState
        self.editMessageState = editMessageState
        self.recordedMediaPreview = recordedMediaPreview
        self.inputQueryResults = inputQueryResults
        self.inputMode = inputMode
        self.titlePanelContexts = titlePanelContexts
        self.keyboardButtonsMessage = keyboardButtonsMessage
        self.pinnedMessageId = pinnedMessageId
        self.pinnedMessage = pinnedMessage
        self.peerIsBlocked = peerIsBlocked
        self.peerIsMuted = peerIsMuted
        self.peerDiscussionId = peerDiscussionId
        self.peerGeoLocation = peerGeoLocation
        self.callsAvailable = callsAvailable
        self.callsPrivate = callsPrivate
        self.slowmodeState = slowmodeState
        self.chatHistoryState = chatHistoryState
        self.botStartPayload = botStartPayload
        self.urlPreview = urlPreview
        self.editingUrlPreview = editingUrlPreview
        self.search = search
        self.searchQuerySuggestionResult = searchQuerySuggestionResult
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.limitsConfiguration = limitsConfiguration
        self.fontSize = fontSize
        self.accountPeerId = accountPeerId
        self.mode = mode
        self.hasScheduledMessages = hasScheduledMessages
        self.isScheduledMessages = isScheduledMessages
    }
    
    static func ==(lhs: ChatPresentationInterfaceState, rhs: ChatPresentationInterfaceState) -> Bool {
        if lhs.interfaceState != rhs.interfaceState {
            return false
        }
        if lhs.renderedPeer != rhs.renderedPeer {
            return false
        }
        if lhs.isNotAccessible != rhs.isNotAccessible {
            return false
        }
        if lhs.explicitelyCanPinMessages != rhs.explicitelyCanPinMessages {
            return false
        }
        if lhs.contactStatus != rhs.contactStatus {
            return false
        }
        if lhs.hasBots != rhs.hasBots {
            return false
        }
        if lhs.isArchived != rhs.isArchived {
            return false
        }
        if lhs.inputTextPanelState != rhs.inputTextPanelState {
            return false
        }
        if lhs.editMessageState != rhs.editMessageState {
            return false
        }
        if lhs.recordedMediaPreview != rhs.recordedMediaPreview {
            return false
        }
        if lhs.inputQueryResults != rhs.inputQueryResults {
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
        if let lhsMessage = lhs.pinnedMessage, let rhsMessage = rhs.pinnedMessage {
            if lhsMessage.id != rhsMessage.id {
                return false
            }
            if lhsMessage.stableVersion != rhsMessage.stableVersion {
                return false
            }
        } else if (lhs.pinnedMessage != nil) != (rhs.pinnedMessage != nil) {
            return false
        }
        if lhs.callsAvailable != rhs.callsAvailable {
            return false
        }
        if lhs.callsPrivate != rhs.callsPrivate {
            return false
        }
        if lhs.slowmodeState != rhs.slowmodeState {
            return false
        }
        if lhs.peerIsBlocked != rhs.peerIsBlocked {
            return false
        }
        if lhs.peerIsMuted != rhs.peerIsMuted {
            return false
        }
        if lhs.peerDiscussionId != rhs.peerDiscussionId {
            return false
        }
        if lhs.peerGeoLocation != rhs.peerGeoLocation {
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
            if !lhsUrlPreview.1.isEqual(to: rhsUrlPreview.1) {
                return false
            }
        } else if (lhs.urlPreview != nil) != (rhs.urlPreview != nil) {
            return false
        }
        if let lhsEditingUrlPreview = lhs.editingUrlPreview, let rhsEditingUrlPreview = rhs.editingUrlPreview {
            if lhsEditingUrlPreview.0 != rhsEditingUrlPreview.0 {
                return false
            }
            if !lhsEditingUrlPreview.1.isEqual(to: rhsEditingUrlPreview.1) {
                return false
            }
        } else if (lhs.editingUrlPreview != nil) != (rhs.editingUrlPreview != nil) {
            return false
        }
        if lhs.search != rhs.search {
            return false
        }
        if lhs.searchQuerySuggestionResult != rhs.searchQuerySuggestionResult {
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
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.accountPeerId != rhs.accountPeerId {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.hasScheduledMessages != rhs.hasScheduledMessages {
            return false
        }
        if lhs.isScheduledMessages != rhs.isScheduledMessages {
            return false
        }
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedPeer(_ f: (RenderedPeer?) -> RenderedPeer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: f(self.renderedPeer), isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedIsNotAccessible(_ isNotAccessible: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedExplicitelyCanPinMessages(_ explicitelyCanPinMessages: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedContactStatus(_ contactStatus: ChatContactStatus?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedHasBots(_ hasBots: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedIsArchived(_ isArchived: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedInputQueryResult(queryKind: ChatPresentationInputQueryKind, _ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        var inputQueryResults = self.inputQueryResults
        let updated = f(inputQueryResults[queryKind])
        if let updated = updated {
            inputQueryResults[queryKind] = updated
        } else {
            inputQueryResults.removeValue(forKey: queryKind)
        }
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedInputTextPanelState(_ f: (ChatTextInputPanelState) -> ChatTextInputPanelState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: f(self.inputTextPanelState), editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedEditMessageState(_ editMessageState: ChatEditInterfaceMessageState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedRecordedMediaPreview(_ recordedMediaPreview: ChatRecordedMediaPreview?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedInputMode(_ f: (ChatInputMode) -> ChatInputMode) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: f(self.inputMode), titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedTitlePanelContext(_ f: ([ChatTitlePanelContext]) -> [ChatTitlePanelContext]) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: f(self.titlePanelContexts), keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedKeyboardButtonsMessage(_ message: Message?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: message, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedPinnedMessage(_ pinnedMessage: Message?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedPeerIsBlocked(_ peerIsBlocked: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedPeerIsMuted(_ peerIsMuted: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedPeerDiscussionId(_ peerDiscussionId: PeerId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedPeerGeoLocation(_ peerGeoLocation: PeerGeoLocation?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedCallsAvailable(_ callsAvailable: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedCallsPrivate(_ callsPrivate: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedSlowmodeState(_ slowmodeState: ChatSlowmodeState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedBotStartPayload(_ botStartPayload: String?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedChatHistoryState(_ chatHistoryState: ChatHistoryNodeHistoryState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedUrlPreview(_ urlPreview: (String, TelegramMediaWebpage)?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedEditingUrlPreview(_ editingUrlPreview: (String, TelegramMediaWebpage)?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedSearch(_ search: ChatSearchData?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedSearchQuerySuggestionResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: f(self.searchQuerySuggestionResult), chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedMode(_ mode: ChatControllerPresentationMode) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedTheme(_ theme: PresentationTheme) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedStrings(_ strings: PresentationStrings) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedDateTimeFormat(_ dateTimeFormat: PresentationDateTimeFormat) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedChatWallpaper(_ chatWallpaper: TelegramWallpaper) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
    
    func updatedHasScheduledMessages(_ hasScheduledMessages: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: hasScheduledMessages, isScheduledMessages: self.isScheduledMessages)
    }
}

func canSendMessagesToChat(_ state: ChatPresentationInterfaceState) -> Bool {
    if let peer = state.renderedPeer?.peer {
        if canSendMessagesToPeer(peer) {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}
