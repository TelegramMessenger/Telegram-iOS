import Foundation
import UIKit
import TelegramCore
import TextFormat
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import Postbox

public final class ChatMessageItemAssociatedData: Equatable {
    public enum ChannelDiscussionGroupStatus: Equatable {
        case unknown
        case known(EnginePeer.Id?)
    }
    
    public let automaticDownloadPeerType: MediaAutoDownloadPeerType
    public let automaticDownloadNetworkType: MediaAutoDownloadNetworkType
    public let isRecentActions: Bool
    public let subject: ChatControllerSubject?
    public let contactsPeerIds: Set<EnginePeer.Id>
    public let channelDiscussionGroup: ChannelDiscussionGroupStatus
    public let animatedEmojiStickers: [String: [StickerPackItem]]
    public let additionalAnimatedEmojiStickers: [String: [Int: StickerPackItem]]
    public let forcedResourceStatus: FileMediaResourceStatus?
    public let currentlyPlayingMessageId: EngineMessage.Index?
    public let isCopyProtectionEnabled: Bool
    public let availableReactions: AvailableReactions?
    public let defaultReaction: String?
    
    public init(automaticDownloadPeerType: MediaAutoDownloadPeerType, automaticDownloadNetworkType: MediaAutoDownloadNetworkType, isRecentActions: Bool = false, subject: ChatControllerSubject? = nil, contactsPeerIds: Set<EnginePeer.Id> = Set(), channelDiscussionGroup: ChannelDiscussionGroupStatus = .unknown, animatedEmojiStickers: [String: [StickerPackItem]] = [:], additionalAnimatedEmojiStickers: [String: [Int: StickerPackItem]] = [:], forcedResourceStatus: FileMediaResourceStatus? = nil, currentlyPlayingMessageId: EngineMessage.Index? = nil, isCopyProtectionEnabled: Bool = false, availableReactions: AvailableReactions?, defaultReaction: String?) {
        self.automaticDownloadPeerType = automaticDownloadPeerType
        self.automaticDownloadNetworkType = automaticDownloadNetworkType
        self.isRecentActions = isRecentActions
        self.subject = subject
        self.contactsPeerIds = contactsPeerIds
        self.channelDiscussionGroup = channelDiscussionGroup
        self.animatedEmojiStickers = animatedEmojiStickers
        self.additionalAnimatedEmojiStickers = additionalAnimatedEmojiStickers
        self.forcedResourceStatus = forcedResourceStatus
        self.currentlyPlayingMessageId = currentlyPlayingMessageId
        self.isCopyProtectionEnabled = isCopyProtectionEnabled
        self.availableReactions = availableReactions
        self.defaultReaction = defaultReaction
    }
    
    public static func == (lhs: ChatMessageItemAssociatedData, rhs: ChatMessageItemAssociatedData) -> Bool {
        if lhs.automaticDownloadPeerType != rhs.automaticDownloadPeerType {
            return false
        }
        if lhs.automaticDownloadNetworkType != rhs.automaticDownloadNetworkType {
            return false
        }
        if lhs.isRecentActions != rhs.isRecentActions {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.contactsPeerIds != rhs.contactsPeerIds {
            return false
        }
        if lhs.channelDiscussionGroup != rhs.channelDiscussionGroup {
            return false
        }
        if lhs.animatedEmojiStickers != rhs.animatedEmojiStickers {
            return false
        }
        if lhs.additionalAnimatedEmojiStickers != rhs.additionalAnimatedEmojiStickers {
            return false
        }
        if lhs.forcedResourceStatus != rhs.forcedResourceStatus {
            return false
        }
        if lhs.currentlyPlayingMessageId != rhs.currentlyPlayingMessageId {
            return false
        }
        if lhs.isCopyProtectionEnabled != rhs.isCopyProtectionEnabled {
            return false
        }
        if lhs.availableReactions != rhs.availableReactions {
            return false
        }
        return true
    }
}

public extension ChatMessageItemAssociatedData {
    var isInPinnedListMode: Bool {
        if case .pinnedMessages = self.subject {
            return true
        } else {
            return false
        }
    }
}

public enum ChatControllerInteractionLongTapAction {
    case url(String)
    case mention(String)
    case peerMention(EnginePeer.Id, String)
    case command(String)
    case hashtag(String)
    case timecode(Double, String)
    case bankCard(String)
}

public enum ChatHistoryMessageSelection: Equatable {
    case none
    case selectable(selected: Bool)
    
    public static func ==(lhs: ChatHistoryMessageSelection, rhs: ChatHistoryMessageSelection) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .selectable(selected):
                if case .selectable(selected) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum ChatControllerInitialBotStartBehavior {
    case interactive
    case automatic(returnToPeerId: EnginePeer.Id, scheduled: Bool)
}

public struct ChatControllerInitialBotStart {
    public let payload: String
    public let behavior: ChatControllerInitialBotStartBehavior
    
    public init(payload: String, behavior: ChatControllerInitialBotStartBehavior) {
        self.payload = payload
        self.behavior = behavior
    }
}

public struct ChatControllerInitialAttachBotStart {
    public let botId: PeerId
    public let payload: String?
    
    public init(botId: PeerId, payload: String?) {
        self.botId = botId
        self.payload = payload
    }
}

public enum ChatControllerInteractionNavigateToPeer {
    case `default`
    case chat(textInputState: ChatTextInputState?, subject: ChatControllerSubject?, peekData: ChatPeekTimeout?)
    case info
    case withBotStartPayload(ChatControllerInitialBotStart)
    case withAttachBot(ChatControllerInitialAttachBotStart)
}

public struct ChatInterfaceForwardOptionsState: Codable, Equatable {
    public var hideNames: Bool
    public var hideCaptions: Bool
    public var unhideNamesOnCaptionChange: Bool
    
    public static func ==(lhs: ChatInterfaceForwardOptionsState, rhs: ChatInterfaceForwardOptionsState) -> Bool {
        return lhs.hideNames == rhs.hideNames && lhs.hideCaptions == rhs.hideCaptions && lhs.unhideNamesOnCaptionChange == rhs.unhideNamesOnCaptionChange
    }
    
    public init(hideNames: Bool, hideCaptions: Bool, unhideNamesOnCaptionChange: Bool) {
        self.hideNames = hideNames
        self.hideCaptions = hideCaptions
        self.unhideNamesOnCaptionChange = unhideNamesOnCaptionChange
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.hideNames = (try? container.decodeIfPresent(Bool.self, forKey: "hn")) ?? false
        self.hideCaptions = (try? container.decodeIfPresent(Bool.self, forKey: "hc")) ?? false
        self.unhideNamesOnCaptionChange = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.hideNames, forKey: "hn")
        try container.encode(self.hideCaptions, forKey: "hc")
    }
}

public struct ChatTextInputState: Codable, Equatable {
    public let inputText: NSAttributedString
    public let selectionRange: Range<Int>
    
    public static func ==(lhs: ChatTextInputState, rhs: ChatTextInputState) -> Bool {
        return lhs.inputText.isEqual(to: rhs.inputText) && lhs.selectionRange == rhs.selectionRange
    }
    
    public init() {
        self.inputText = NSAttributedString()
        self.selectionRange = 0 ..< 0
    }
    
    public init(inputText: NSAttributedString, selectionRange: Range<Int>) {
        self.inputText = inputText
        self.selectionRange = selectionRange
    }
    
    public init(inputText: NSAttributedString) {
        self.inputText = inputText
        let length = inputText.length
        self.selectionRange = length ..< length
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.inputText = ((try? container.decode(ChatTextInputStateText.self, forKey: "at")) ?? ChatTextInputStateText()).attributedText()
        let rangeFrom = (try? container.decode(Int32.self, forKey: "as0")) ?? 0
        let rangeTo = (try? container.decode(Int32.self, forKey: "as1")) ?? 0
        if rangeFrom <= rangeTo {
            self.selectionRange = Int(rangeFrom) ..< Int(rangeTo)
        } else {
            let length = self.inputText.length
            self.selectionRange = length ..< length
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(ChatTextInputStateText(attributedText: self.inputText), forKey: "at")
        try container.encode(Int32(self.selectionRange.lowerBound), forKey: "as0")
        try container.encode(Int32(self.selectionRange.upperBound), forKey: "as1")
    }
}

public enum ChatTextInputStateTextAttributeType: Codable, Equatable {
    case bold
    case italic
    case monospace
    case textMention(EnginePeer.Id)
    case textUrl(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch (try? container.decode(Int32.self, forKey: "t")) ?? 0 {
        case 0:
            self = .bold
        case 1:
            self = .italic
        case 2:
            self = .monospace
        case 3:
            let peerId = (try? container.decode(Int64.self, forKey: "peerId")) ?? 0
            self = .textMention(EnginePeer.Id(peerId))
        case 4:
            let url = (try? container.decode(String.self, forKey: "url")) ?? ""
            self = .textUrl(url)
        default:
            assertionFailure()
            self = .bold
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        switch self {
        case .bold:
            try container.encode(0 as Int32, forKey: "t")
        case .italic:
            try container.encode(1 as Int32, forKey: "t")
        case .monospace:
            try container.encode(2 as Int32, forKey: "t")
        case let .textMention(id):
            try container.encode(3 as Int32, forKey: "t")
            try container.encode(id.toInt64(), forKey: "peerId")
        case let .textUrl(url):
            try container.encode(4 as Int32, forKey: "t")
            try container.encode(url, forKey: "url")
        }
    }
}

public struct ChatTextInputStateTextAttribute: Codable, Equatable {
    public let type: ChatTextInputStateTextAttributeType
    public let range: Range<Int>
    
    public init(type: ChatTextInputStateTextAttributeType, range: Range<Int>) {
        self.type = type
        self.range = range
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.type = try container.decode(ChatTextInputStateTextAttributeType.self, forKey: "type")
        let rangeFrom = (try? container.decode(Int32.self, forKey: "range0")) ?? 0
        let rangeTo = (try? container.decode(Int32.self, forKey: "range1")) ?? 0

        self.range = Int(rangeFrom) ..< Int(rangeTo)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.type, forKey: "type")

        try container.encode(Int32(self.range.lowerBound), forKey: "range0")
        try container.encode(Int32(self.range.upperBound), forKey: "range1")
    }
    
    public static func ==(lhs: ChatTextInputStateTextAttribute, rhs: ChatTextInputStateTextAttribute) -> Bool {
        return lhs.type == rhs.type && lhs.range == rhs.range
    }
}

public struct ChatTextInputStateText: Codable, Equatable {
    public let text: String
    public let attributes: [ChatTextInputStateTextAttribute]
    
    public init() {
        self.text = ""
        self.attributes = []
    }
    
    public init(text: String, attributes: [ChatTextInputStateTextAttribute]) {
        self.text = text
        self.attributes = attributes
    }
    
    public init(attributedText: NSAttributedString) {
        self.text = attributedText.string
        var parsedAttributes: [ChatTextInputStateTextAttribute] = []
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: [], using: { attributes, range, _ in
            for (key, value) in attributes {
                if key == ChatTextInputAttributes.bold {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .bold, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.italic {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .italic, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.monospace {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .monospace, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.textMention, let value = value as? ChatTextInputTextMentionAttribute {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .textMention(value.peerId), range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.textUrl, let value = value as? ChatTextInputTextUrlAttribute {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .textUrl(value.url), range: range.location ..< (range.location + range.length)))
                }
            }
        })
        self.attributes = parsedAttributes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.text = (try? container.decode(String.self, forKey: "text")) ?? ""
        self.attributes = (try? container.decode([ChatTextInputStateTextAttribute].self, forKey: "attributes")) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.text, forKey: "text")
        try container.encode(self.attributes, forKey: "attributes")
    }
    
    static public func ==(lhs: ChatTextInputStateText, rhs: ChatTextInputStateText) -> Bool {
        return lhs.text == rhs.text && lhs.attributes == rhs.attributes
    }
    
    public func attributedText() -> NSAttributedString {
        let result = NSMutableAttributedString(string: self.text)
        for attribute in self.attributes {
            switch attribute.type {
            case .bold:
                result.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .italic:
                result.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .monospace:
                result.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .textMention(id):
                result.addAttribute(ChatTextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: id), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .textUrl(url):
                result.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            }
        }
        return result
    }
}

public enum ChatControllerSubject: Equatable {
    public enum MessageSubject: Equatable {
        case id(MessageId)
        case timestamp(Int32)
    }

    public struct ForwardOptions: Equatable {
        public let hideNames: Bool
        public let hideCaptions: Bool
        
        public init(hideNames: Bool, hideCaptions: Bool) {
            self.hideNames = hideNames
            self.hideCaptions = hideCaptions
        }
    }
    
    case message(id: MessageSubject, highlight: Bool, timecode: Double?)
    case scheduledMessages
    case pinnedMessages(id: EngineMessage.Id?)
    case forwardedMessages(ids: [EngineMessage.Id], options: Signal<ForwardOptions, NoError>)
    
    public static func ==(lhs: ChatControllerSubject, rhs: ChatControllerSubject) -> Bool {
        switch lhs {
        case let .message(lhsId, lhsHighlight, lhsTimecode):
            if case let .message(rhsId, rhsHighlight, rhsTimecode) = rhs, lhsId == rhsId && lhsHighlight == rhsHighlight && lhsTimecode == rhsTimecode {
                return true
            } else {
                return false
            }
        case .scheduledMessages:
            if case .scheduledMessages = rhs {
                return true
            } else {
                return false
            }
        case let .pinnedMessages(id):
            if case .pinnedMessages(id) = rhs {
                return true
            } else {
                return false
            }
        case let .forwardedMessages(lhsIds, _):
            if case let .forwardedMessages(rhsIds, _) = rhs, lhsIds == rhsIds {
                return true
            } else {
                return false
            }
        }
    }
}

public enum ChatControllerPresentationMode: Equatable {
    case standard(previewing: Bool)
    case overlay(NavigationController?)
    case inline(NavigationController?)
}

public enum ChatPresentationInputQueryResult: Equatable {
    case stickers([FoundStickerItem])
    case hashtags([String])
    case mentions([EnginePeer])
    case commands([PeerCommand])
    case emojis([(String, String)], NSRange)
    case contextRequestResult(EnginePeer?, ChatContextResultCollection?)
    
    public static func ==(lhs: ChatPresentationInputQueryResult, rhs: ChatPresentationInputQueryResult) -> Bool {
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
                if lhsPeers != rhsPeers {
                    return false
                }
                return true
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
        case let .emojis(lhsValue, lhsRange):
            if case let .emojis(rhsValue, rhsRange) = rhs {
                if lhsRange != rhsRange {
                    return false
                }
                if lhsValue.count != rhsValue.count {
                    return false
                }
                for i in 0 ..< lhsValue.count {
                    if lhsValue[i] != rhsValue[i] {
                        return false
                    }
                }
                return true
            } else {
                return false
            }
        case let .contextRequestResult(lhsPeer, lhsCollection):
            if case let .contextRequestResult(rhsPeer, rhsCollection) = rhs {
                if lhsPeer != rhsPeer {
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

public let ChatControllerCount = Atomic<Int32>(value: 0)

public protocol PeerInfoScreen: ViewController {
    
}

public protocol ChatController: ViewController {
    var chatLocation: ChatLocation { get }
    var canReadHistory: ValuePromise<Bool> { get }
    var parentController: ViewController? { get set }
    
    var purposefulAction: (() -> Void)? { get set }
    
    func updatePresentationMode(_ mode: ChatControllerPresentationMode)
    func beginMessageSearch(_ query: String)
    func displayPromoAnnouncement(text: String)
    
    var isSendButtonVisible: Bool { get }
}

public protocol ChatMessagePreviewItemNode: AnyObject {
    var forwardInfoReferenceNode: ASDisplayNode? { get }
}

public enum FileMediaResourcePlaybackStatus: Equatable {
    case playing
    case paused
}

public struct FileMediaResourceStatus: Equatable {
    public var mediaStatus: FileMediaResourceMediaStatus
    public var fetchStatus: MediaResourceStatus
    
    public init(mediaStatus: FileMediaResourceMediaStatus, fetchStatus: MediaResourceStatus) {
        self.mediaStatus = mediaStatus
        self.fetchStatus = fetchStatus
    }
}

public enum FileMediaResourceMediaStatus: Equatable {
    case fetchStatus(MediaResourceStatus)
    case playbackStatus(FileMediaResourcePlaybackStatus)
}

public protocol ChatMessageItemNodeProtocol: ListViewItemNode {
    func targetReactionView(value: String) -> UIView?
}
