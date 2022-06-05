import Foundation
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatInterfaceState

public extension ChatLocation {
    var peerId: PeerId? {
        switch self {
        case let .peer(peerId):
            return peerId
        case let .replyThread(replyThreadMessage):
            return replyThreadMessage.messageId.peerId
        case .feed:
            return nil
        }
    }
}

public enum ChatPresentationInputQueryKind: Int32 {
    case emoji
    case hashtag
    case mention
    case command
    case contextRequest
    case emojiSearch
}

public struct ChatInputQueryMentionTypes: OptionSet, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let contextBots = ChatInputQueryMentionTypes(rawValue: 1 << 0)
    public static let members = ChatInputQueryMentionTypes(rawValue: 1 << 1)
    public static let accountPeer = ChatInputQueryMentionTypes(rawValue: 1 << 2)
}

public enum ChatPresentationInputQuery: Hashable, Equatable {
    case emoji(String)
    case hashtag(String)
    case mention(query: String, types: ChatInputQueryMentionTypes)
    case command(String)
    case emojiSearch(query: String, languageCode: String, range: NSRange)
    case contextRequest(addressName: String, query: String)
    
    public var kind: ChatPresentationInputQueryKind {
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
}

public enum ChatMediaInputMode {
    case gif
    case other
}

public enum ChatMediaInputSearchMode {
    case gif
    case sticker
    case trending
}

public enum ChatMediaInputExpanded: Equatable {
    case content
    case search(ChatMediaInputSearchMode)
}

public enum ChatInputMode: Equatable {
    case none
    case text
    case media(mode: ChatMediaInputMode, expanded: ChatMediaInputExpanded?, focused: Bool)
    case inputButtons
}

public enum ChatTitlePanelContext: Equatable, Comparable {
    case pinnedMessage
    case chatInfo
    case requestInProgress
    case toastAlert(String)
    case inviteRequests([EnginePeer], Int32)
    
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
            case .inviteRequests:
                return 4
        }
    }
    
    public static func <(lhs: ChatTitlePanelContext, rhs: ChatTitlePanelContext) -> Bool {
        return lhs.index < rhs.index
    }
}

public struct ChatSearchResultsState: Equatable {
    public let messageIndices: [MessageIndex]
    public let currentId: MessageId?
    public let state: SearchMessagesState
    public let totalCount: Int32
    public let completed: Bool
    
    public init(messageIndices: [MessageIndex], currentId: MessageId?, state: SearchMessagesState, totalCount: Int32, completed: Bool) {
        self.messageIndices = messageIndices
        self.currentId = currentId
        self.state = state
        self.totalCount = totalCount
        self.completed = completed
    }
}
    
public enum ChatSearchDomainSuggestionContext: Equatable {
    case none
    case members(String)
}

public struct ChatSearchData: Equatable {
    public let query: String
    public let domain: ChatSearchDomain
    public let domainSuggestionContext: ChatSearchDomainSuggestionContext
    public let resultsState: ChatSearchResultsState?
    
    public init(query: String = "", domain: ChatSearchDomain = .everything, domainSuggestionContext: ChatSearchDomainSuggestionContext = .none, resultsState: ChatSearchResultsState? = nil) {
        self.query = query
        self.domain = domain
        self.domainSuggestionContext = domainSuggestionContext
        self.resultsState = resultsState
    }
    
    public static func ==(lhs: ChatSearchData, rhs: ChatSearchData) -> Bool {
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
    
    public func withUpdatedQuery(_ query: String) -> ChatSearchData {
        return ChatSearchData(query: query, domain: self.domain, domainSuggestionContext: self.domainSuggestionContext, resultsState: self.resultsState)
    }
    
    public func withUpdatedDomain(_ domain: ChatSearchDomain) -> ChatSearchData {
        return ChatSearchData(query: self.query, domain: domain, domainSuggestionContext: self.domainSuggestionContext, resultsState: self.resultsState)
    }
    
    public func withUpdatedDomainSuggestionContext(_ domain: ChatSearchDomainSuggestionContext) -> ChatSearchData {
        return ChatSearchData(query: self.query, domain: self.domain, domainSuggestionContext: domainSuggestionContext, resultsState: self.resultsState)
    }
    
    public func withUpdatedResultsState(_ resultsState: ChatSearchResultsState?) -> ChatSearchData {
        return ChatSearchData(query: self.query, domain: self.domain, domainSuggestionContext: self.domainSuggestionContext, resultsState: resultsState)
    }
}

public final class ChatRecordedMediaPreview: Equatable {
    public let resource: TelegramMediaResource
    public let fileSize: Int32
    public let duration: Int32
    public let waveform: AudioWaveform
    
    public init(resource: TelegramMediaResource, duration: Int32, fileSize: Int32, waveform: AudioWaveform) {
        self.resource = resource
        self.duration = duration
        self.fileSize = fileSize
        self.waveform = waveform
    }
    
    public static func ==(lhs: ChatRecordedMediaPreview, rhs: ChatRecordedMediaPreview) -> Bool {
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

public struct ChatContactStatus: Equatable {
    public var canAddContact: Bool
    public var canReportIrrelevantLocation: Bool
    public var peerStatusSettings: PeerStatusSettings?
    public var invitedBy: Peer?
    
    public init(canAddContact: Bool, canReportIrrelevantLocation: Bool, peerStatusSettings: PeerStatusSettings?, invitedBy: Peer?) {
        self.canAddContact = canAddContact
        self.canReportIrrelevantLocation = canReportIrrelevantLocation
        self.peerStatusSettings = peerStatusSettings
        self.invitedBy = invitedBy
    }
    
    public var isEmpty: Bool {
        guard var peerStatusSettings = self.peerStatusSettings else {
            return false
        }
        if !self.canAddContact {
            peerStatusSettings.flags.remove(.canAddContact)
        }
        if !self.canReportIrrelevantLocation {
            peerStatusSettings.flags.remove(.canReportIrrelevantGeoLocation)
        }
        return peerStatusSettings.flags.isEmpty
    }
    
    public static func ==(lhs: ChatContactStatus, rhs: ChatContactStatus) -> Bool {
        if lhs.canAddContact != rhs.canAddContact {
            return false
        }
        if lhs.canReportIrrelevantLocation != rhs.canReportIrrelevantLocation {
            return false
        }
        if lhs.peerStatusSettings != rhs.peerStatusSettings {
            return false
        }
        if !arePeersEqual(lhs.invitedBy, rhs.invitedBy) {
            return false
        }
        return true
    }
}

public enum ChatSlowmodeVariant: Equatable {
    case timestamp(Int32)
    case pendingMessages
}

public struct ChatSlowmodeState: Equatable {
    public var timeout: Int32
    public var variant: ChatSlowmodeVariant
    
    public init(timeout: Int32, variant: ChatSlowmodeVariant) {
        self.timeout = timeout
        self.variant = variant
    }
}

public final class ChatPinnedMessage: Equatable {
    public let message: Message
    public let index: Int
    public let totalCount: Int
    public let topMessageId: MessageId
    
    public init(message: Message, index: Int, totalCount: Int, topMessageId: MessageId) {
        self.message = message
        self.index = index
        self.totalCount = totalCount
        self.topMessageId = topMessageId
    }
    
    public static func ==(lhs: ChatPinnedMessage, rhs: ChatPinnedMessage) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.message.id != rhs.message.id {
            return false
        }
        if lhs.index != rhs.index {
            return false
        }
        if lhs.totalCount != rhs.totalCount {
            return false
        }
        if lhs.message.stableVersion != rhs.message.stableVersion {
            return false
        }
        if lhs.topMessageId != rhs.topMessageId {
            return false
        }
        return true
    }
}

public struct ChatActiveGroupCallInfo: Equatable {
    public var activeCall: CachedChannelData.ActiveCall
    
    public init(activeCall: CachedChannelData.ActiveCall) {
        self.activeCall = activeCall
    }
}

public struct ChatPresentationImportState: Equatable {
    public var progress: Float
    
    public init(progress: Float) {
        self.progress = progress
    }
}

public enum ChatHistoryNodeHistoryState: Equatable {
    case loading
    case loaded(isEmpty: Bool)
}

public final class ChatPresentationInterfaceState: Equatable {
    public let interfaceState: ChatInterfaceState
    public let chatLocation: ChatLocation
    public let renderedPeer: RenderedPeer?
    public let isNotAccessible: Bool
    public let explicitelyCanPinMessages: Bool
    public let contactStatus: ChatContactStatus?
    public let hasBots: Bool
    public let isArchived: Bool
    public let inputTextPanelState: ChatTextInputPanelState
    public let editMessageState: ChatEditInterfaceMessageState?
    public let recordedMediaPreview: ChatRecordedMediaPreview?
    public let inputQueryResults: [ChatPresentationInputQueryKind: ChatPresentationInputQueryResult]
    public let inputMode: ChatInputMode
    public let titlePanelContexts: [ChatTitlePanelContext]
    public let keyboardButtonsMessage: Message?
    public let pinnedMessageId: MessageId?
    public let pinnedMessage: ChatPinnedMessage?
    public let peerIsBlocked: Bool
    public let peerIsMuted: Bool
    public let peerDiscussionId: PeerId?
    public let peerGeoLocation: PeerGeoLocation?
    public let callsAvailable: Bool
    public let callsPrivate: Bool
    public let slowmodeState: ChatSlowmodeState?
    public let chatHistoryState: ChatHistoryNodeHistoryState?
    public let botStartPayload: String?
    public let urlPreview: (String, TelegramMediaWebpage)?
    public let editingUrlPreview: (String, TelegramMediaWebpage)?
    public let search: ChatSearchData?
    public let searchQuerySuggestionResult: ChatPresentationInputQueryResult?
    public let presentationReady: Bool
    public let chatWallpaper: TelegramWallpaper
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let limitsConfiguration: LimitsConfiguration
    public let fontSize: PresentationFontSize
    public let bubbleCorners: PresentationChatBubbleCorners
    public let accountPeerId: PeerId
    public let mode: ChatControllerPresentationMode
    public let hasScheduledMessages: Bool
    public let autoremoveTimeout: Int32?
    public let subject: ChatControllerSubject?
    public let peerNearbyData: ChatPeerNearbyData?
    public let greetingData: ChatGreetingData?
    public let pendingUnpinnedAllMessages: Bool
    public let activeGroupCallInfo: ChatActiveGroupCallInfo?
    public let hasActiveGroupCall: Bool
    public let importState: ChatPresentationImportState?
    public let reportReason: ReportReason?
    public let showCommands: Bool
    public let hasBotCommands: Bool
    public let showSendAsPeers: Bool
    public let sendAsPeers: [FoundPeer]?
    public let botMenuButton: BotMenuButton
    public let showWebView: Bool
    public let currentSendAsPeerId: PeerId?
    public let copyProtectionEnabled: Bool
    public let hasPlentyOfMessages: Bool
    public let isPremium: Bool
    public let forceInputCommandsHidden: Bool
    
    public init(chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, limitsConfiguration: LimitsConfiguration, fontSize: PresentationFontSize, bubbleCorners: PresentationChatBubbleCorners, accountPeerId: PeerId, mode: ChatControllerPresentationMode, chatLocation: ChatLocation, subject: ChatControllerSubject?, peerNearbyData: ChatPeerNearbyData?, greetingData: ChatGreetingData?, pendingUnpinnedAllMessages: Bool, activeGroupCallInfo: ChatActiveGroupCallInfo?, hasActiveGroupCall: Bool, importState: ChatPresentationImportState?) {
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
        self.presentationReady = false
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.limitsConfiguration = limitsConfiguration
        self.fontSize = fontSize
        self.bubbleCorners = bubbleCorners
        self.accountPeerId = accountPeerId
        self.mode = mode
        self.hasScheduledMessages = false
        self.autoremoveTimeout = nil
        self.subject = subject
        self.peerNearbyData = peerNearbyData
        self.greetingData = greetingData
        self.pendingUnpinnedAllMessages = pendingUnpinnedAllMessages
        self.activeGroupCallInfo = activeGroupCallInfo
        self.hasActiveGroupCall = hasActiveGroupCall
        self.importState = importState
        self.reportReason = nil
        self.showCommands = false
        self.hasBotCommands = false
        self.showSendAsPeers = false
        self.sendAsPeers = nil
        self.botMenuButton = .commands
        self.showWebView = false
        self.currentSendAsPeerId = nil
        self.copyProtectionEnabled = false
        self.hasPlentyOfMessages = false
        self.isPremium = false
        self.forceInputCommandsHidden = false
    }
    
    public init(interfaceState: ChatInterfaceState, chatLocation: ChatLocation, renderedPeer: RenderedPeer?, isNotAccessible: Bool, explicitelyCanPinMessages: Bool, contactStatus: ChatContactStatus?, hasBots: Bool, isArchived: Bool, inputTextPanelState: ChatTextInputPanelState, editMessageState: ChatEditInterfaceMessageState?, recordedMediaPreview: ChatRecordedMediaPreview?, inputQueryResults: [ChatPresentationInputQueryKind: ChatPresentationInputQueryResult], inputMode: ChatInputMode, titlePanelContexts: [ChatTitlePanelContext], keyboardButtonsMessage: Message?, pinnedMessageId: MessageId?, pinnedMessage: ChatPinnedMessage?, peerIsBlocked: Bool, peerIsMuted: Bool, peerDiscussionId: PeerId?, peerGeoLocation: PeerGeoLocation?, callsAvailable: Bool, callsPrivate: Bool, slowmodeState: ChatSlowmodeState?, chatHistoryState: ChatHistoryNodeHistoryState?, botStartPayload: String?, urlPreview: (String, TelegramMediaWebpage)?, editingUrlPreview: (String, TelegramMediaWebpage)?, search: ChatSearchData?, searchQuerySuggestionResult: ChatPresentationInputQueryResult?, presentationReady: Bool, chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, limitsConfiguration: LimitsConfiguration, fontSize: PresentationFontSize, bubbleCorners: PresentationChatBubbleCorners, accountPeerId: PeerId, mode: ChatControllerPresentationMode, hasScheduledMessages: Bool, autoremoveTimeout: Int32?, subject: ChatControllerSubject?, peerNearbyData: ChatPeerNearbyData?, greetingData: ChatGreetingData?, pendingUnpinnedAllMessages: Bool, activeGroupCallInfo: ChatActiveGroupCallInfo?, hasActiveGroupCall: Bool, importState: ChatPresentationImportState?, reportReason: ReportReason?, showCommands: Bool, hasBotCommands: Bool, showSendAsPeers: Bool, sendAsPeers: [FoundPeer]?, botMenuButton: BotMenuButton, showWebView: Bool, currentSendAsPeerId: PeerId?, copyProtectionEnabled: Bool, hasPlentyOfMessages: Bool, isPremium: Bool, forceInputCommandsHidden: Bool) {
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
        self.presentationReady = presentationReady
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.limitsConfiguration = limitsConfiguration
        self.fontSize = fontSize
        self.bubbleCorners = bubbleCorners
        self.accountPeerId = accountPeerId
        self.mode = mode
        self.hasScheduledMessages = hasScheduledMessages
        self.autoremoveTimeout = autoremoveTimeout
        self.subject = subject
        self.peerNearbyData = peerNearbyData
        self.greetingData = greetingData
        self.pendingUnpinnedAllMessages = pendingUnpinnedAllMessages
        self.activeGroupCallInfo = activeGroupCallInfo
        self.hasActiveGroupCall = hasActiveGroupCall
        self.importState = importState
        self.reportReason = reportReason
        self.showCommands = showCommands
        self.hasBotCommands = hasBotCommands
        self.showSendAsPeers = showSendAsPeers
        self.sendAsPeers = sendAsPeers
        self.botMenuButton = botMenuButton
        self.showWebView = showWebView
        self.currentSendAsPeerId = currentSendAsPeerId
        self.copyProtectionEnabled = copyProtectionEnabled
        self.hasPlentyOfMessages = hasPlentyOfMessages
        self.isPremium = isPremium
        self.forceInputCommandsHidden = forceInputCommandsHidden
    }
    
    public static func ==(lhs: ChatPresentationInterfaceState, rhs: ChatPresentationInterfaceState) -> Bool {
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
        if lhs.pinnedMessage != rhs.pinnedMessage {
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
        if lhs.presentationReady != rhs.presentationReady {
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
        if lhs.bubbleCorners != rhs.bubbleCorners {
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
        if lhs.autoremoveTimeout != rhs.autoremoveTimeout {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.peerNearbyData != rhs.peerNearbyData {
            return false
        }
        if lhs.greetingData != rhs.greetingData {
            return false
        }
        if lhs.pendingUnpinnedAllMessages != rhs.pendingUnpinnedAllMessages {
            return false
        }
        if lhs.activeGroupCallInfo != rhs.activeGroupCallInfo {
            return false
        }
        if lhs.hasActiveGroupCall != rhs.hasActiveGroupCall {
            return false
        }
        if lhs.importState != rhs.importState {
            return false
        }
        if lhs.reportReason != rhs.reportReason {
            return false
        }
        if lhs.showCommands != rhs.showCommands {
            return false
        }
        if lhs.hasBotCommands != rhs.hasBotCommands {
            return false
        }
        if lhs.showSendAsPeers != rhs.showSendAsPeers {
            return false
        }
        if lhs.sendAsPeers != rhs.sendAsPeers {
            return false
        }
        if lhs.botMenuButton != rhs.botMenuButton {
            return false
        }
        if lhs.showWebView != rhs.showWebView {
            return false
        }
        if lhs.currentSendAsPeerId != rhs.currentSendAsPeerId {
            return false
        }
        if lhs.copyProtectionEnabled != rhs.copyProtectionEnabled {
            return false
        }
        if lhs.hasPlentyOfMessages != rhs.hasPlentyOfMessages {
            return false
        }
        if lhs.isPremium != rhs.isPremium {
            return false
        }
        if lhs.forceInputCommandsHidden != rhs.forceInputCommandsHidden {
            return false
        }
        return true
    }
    
    public func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPeer(_ f: (RenderedPeer?) -> RenderedPeer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: f(self.renderedPeer), isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedIsNotAccessible(_ isNotAccessible: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedExplicitelyCanPinMessages(_ explicitelyCanPinMessages: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedContactStatus(_ contactStatus: ChatContactStatus?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedHasBots(_ hasBots: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedIsArchived(_ isArchived: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedInputQueryResult(queryKind: ChatPresentationInputQueryKind, _ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        var inputQueryResults = self.inputQueryResults
        let updated = f(inputQueryResults[queryKind])
        if let updated = updated {
            inputQueryResults[queryKind] = updated
        } else {
            inputQueryResults.removeValue(forKey: queryKind)
        }

        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedInputTextPanelState(_ f: (ChatTextInputPanelState) -> ChatTextInputPanelState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: f(self.inputTextPanelState), editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedEditMessageState(_ editMessageState: ChatEditInterfaceMessageState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedRecordedMediaPreview(_ recordedMediaPreview: ChatRecordedMediaPreview?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedInputMode(_ f: (ChatInputMode) -> ChatInputMode) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: f(self.inputMode), titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedTitlePanelContext(_ f: ([ChatTitlePanelContext]) -> [ChatTitlePanelContext]) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: f(self.titlePanelContexts), keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedKeyboardButtonsMessage(_ message: Message?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: message, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPinnedMessage(_ pinnedMessage: ChatPinnedMessage?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPeerIsBlocked(_ peerIsBlocked: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPeerIsMuted(_ peerIsMuted: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPeerDiscussionId(_ peerDiscussionId: PeerId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPeerGeoLocation(_ peerGeoLocation: PeerGeoLocation?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedCallsAvailable(_ callsAvailable: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedCallsPrivate(_ callsPrivate: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedSlowmodeState(_ slowmodeState: ChatSlowmodeState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedBotStartPayload(_ botStartPayload: String?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedChatHistoryState(_ chatHistoryState: ChatHistoryNodeHistoryState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedUrlPreview(_ urlPreview: (String, TelegramMediaWebpage)?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedEditingUrlPreview(_ editingUrlPreview: (String, TelegramMediaWebpage)?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedSearch(_ search: ChatSearchData?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedSearchQuerySuggestionResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: f(self.searchQuerySuggestionResult), presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedMode(_ mode: ChatControllerPresentationMode) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPresentationReady(_ presentationReady: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedTheme(_ theme: PresentationTheme) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedStrings(_ strings: PresentationStrings) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedDateTimeFormat(_ dateTimeFormat: PresentationDateTimeFormat) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedChatWallpaper(_ chatWallpaper: TelegramWallpaper) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedBubbleCorners(_ bubbleCorners: PresentationChatBubbleCorners) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedHasScheduledMessages(_ hasScheduledMessages: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedAutoremoveTimeout(_ autoremoveTimeout: Int32?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedPendingUnpinnedAllMessages(_ pendingUnpinnedAllMessages: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedActiveGroupCallInfo(_ activeGroupCallInfo: ChatActiveGroupCallInfo?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedHasActiveGroupCall(_ hasActiveGroupCall: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedImportState(_ importState: ChatPresentationImportState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedReportReason(_ reportReason: ReportReason?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedShowCommands(_ showCommands: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedHasBotCommands(_ hasBotCommands: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedShowSendAsPeers(_ showSendAsPeers: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedSendAsPeers(_ sendAsPeers: [FoundPeer]?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedCurrentSendAsPeerId(_ currentSendAsPeerId: PeerId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedBotMenuButton(_ botMenuButton: BotMenuButton) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedShowWebView(_ showWebView: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState,  chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedCopyProtectionEnabled(_ copyProtectionEnabled: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedHasPlentyOfMessages(_ hasPlentyOfMessages: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedIsPremium(_ isPremium: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: isPremium, forceInputCommandsHidden: self.forceInputCommandsHidden)
    }
    
    public func updatedForceInputCommandsHidden(_ forceInputCommandsHidden: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, chatLocation: self.chatLocation, renderedPeer: self.renderedPeer, isNotAccessible: self.isNotAccessible, explicitelyCanPinMessages: self.explicitelyCanPinMessages, contactStatus: self.contactStatus, hasBots: self.hasBots, isArchived: self.isArchived, inputTextPanelState: self.inputTextPanelState, editMessageState: self.editMessageState, recordedMediaPreview: self.recordedMediaPreview, inputQueryResults: self.inputQueryResults, inputMode: self.inputMode, titlePanelContexts: self.titlePanelContexts, keyboardButtonsMessage: self.keyboardButtonsMessage, pinnedMessageId: self.pinnedMessageId, pinnedMessage: self.pinnedMessage, peerIsBlocked: self.peerIsBlocked, peerIsMuted: self.peerIsMuted, peerDiscussionId: self.peerDiscussionId, peerGeoLocation: self.peerGeoLocation, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, slowmodeState: self.slowmodeState, chatHistoryState: self.chatHistoryState, botStartPayload: self.botStartPayload, urlPreview: self.urlPreview, editingUrlPreview: self.editingUrlPreview, search: self.search, searchQuerySuggestionResult: self.searchQuerySuggestionResult, presentationReady: self.presentationReady, chatWallpaper: self.chatWallpaper, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, limitsConfiguration: self.limitsConfiguration, fontSize: self.fontSize, bubbleCorners: self.bubbleCorners, accountPeerId: self.accountPeerId, mode: self.mode, hasScheduledMessages: self.hasScheduledMessages, autoremoveTimeout: self.autoremoveTimeout, subject: self.subject, peerNearbyData: self.peerNearbyData, greetingData: self.greetingData, pendingUnpinnedAllMessages: self.pendingUnpinnedAllMessages, activeGroupCallInfo: self.activeGroupCallInfo, hasActiveGroupCall: self.hasActiveGroupCall, importState: self.importState, reportReason: self.reportReason, showCommands: self.showCommands, hasBotCommands: self.hasBotCommands, showSendAsPeers: self.showSendAsPeers, sendAsPeers: self.sendAsPeers, botMenuButton: self.botMenuButton, showWebView: self.showWebView, currentSendAsPeerId: self.currentSendAsPeerId, copyProtectionEnabled: self.copyProtectionEnabled, hasPlentyOfMessages: self.hasPlentyOfMessages, isPremium: self.isPremium, forceInputCommandsHidden: forceInputCommandsHidden)
    }
}

public func canSendMessagesToChat(_ state: ChatPresentationInterfaceState) -> Bool {
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
