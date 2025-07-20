import Foundation
import UIKit
import TelegramCore
import Postbox
import TextFormat
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences

public final class ChatMessageItemAssociatedData: Equatable {
    public enum ChannelDiscussionGroupStatus: Equatable {
        case unknown
        case known(EnginePeer.Id?)
    }
    
    public struct DisplayTranscribeButton: Equatable {
        public let canBeDisplayed: Bool
        public let displayForNotConsumed: Bool
        public let providedByGroupBoost: Bool
        
        public init(
            canBeDisplayed: Bool,
            displayForNotConsumed: Bool,
            providedByGroupBoost: Bool
        ) {
            self.canBeDisplayed = canBeDisplayed
            self.displayForNotConsumed = displayForNotConsumed
            self.providedByGroupBoost = providedByGroupBoost
        }
    }
    
    public let automaticDownloadPeerType: MediaAutoDownloadPeerType
    public let automaticDownloadPeerId: EnginePeer.Id?
    public let automaticDownloadNetworkType: MediaAutoDownloadNetworkType
    public let preferredStoryHighQuality: Bool
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
    public let availableMessageEffects: AvailableMessageEffects?
    public let savedMessageTags: SavedMessageTags?
    public let defaultReaction: MessageReaction.Reaction?
    public let isPremium: Bool
    public let forceInlineReactions: Bool
    public let alwaysDisplayTranscribeButton: DisplayTranscribeButton
    public let accountPeer: EnginePeer?
    public let topicAuthorId: EnginePeer.Id?
    public let hasBots: Bool
    public let translateToLanguage: String?
    public let maxReadStoryId: Int32?
    public let recommendedChannels: RecommendedChannels?
    public let audioTranscriptionTrial: AudioTranscription.TrialState
    public let chatThemes: [TelegramTheme]
    public let deviceContactsNumbers: Set<String>
    public let isStandalone: Bool
    public let isInline: Bool
    public let showSensitiveContent: Bool
    public let isSuspiciousPeer: Bool
    
    public init(
        automaticDownloadPeerType: MediaAutoDownloadPeerType,
        automaticDownloadPeerId: EnginePeer.Id?,
        automaticDownloadNetworkType: MediaAutoDownloadNetworkType,
        preferredStoryHighQuality: Bool = false,
        isRecentActions: Bool = false,
        subject: ChatControllerSubject? = nil,
        contactsPeerIds: Set<EnginePeer.Id> = Set(),
        channelDiscussionGroup: ChannelDiscussionGroupStatus = .unknown,
        animatedEmojiStickers: [String: [StickerPackItem]] = [:],
        additionalAnimatedEmojiStickers: [String: [Int: StickerPackItem]] = [:],
        forcedResourceStatus: FileMediaResourceStatus? = nil,
        currentlyPlayingMessageId: EngineMessage.Index? = nil,
        isCopyProtectionEnabled: Bool = false,
        availableReactions: AvailableReactions?,
        availableMessageEffects: AvailableMessageEffects?,
        savedMessageTags: SavedMessageTags?,
        defaultReaction: MessageReaction.Reaction?,
        isPremium: Bool,
        accountPeer: EnginePeer?,
        forceInlineReactions: Bool = false,
        alwaysDisplayTranscribeButton: DisplayTranscribeButton = DisplayTranscribeButton(canBeDisplayed: false, displayForNotConsumed: false, providedByGroupBoost: false),
        topicAuthorId: EnginePeer.Id? = nil,
        hasBots: Bool = false,
        translateToLanguage: String? = nil,
        maxReadStoryId: Int32? = nil,
        recommendedChannels: RecommendedChannels? = nil,
        audioTranscriptionTrial: AudioTranscription.TrialState = .defaultValue,
        chatThemes: [TelegramTheme] = [],
        deviceContactsNumbers: Set<String> = Set(),
        isStandalone: Bool = false,
        isInline: Bool = false,
        showSensitiveContent: Bool = false,
        isSuspiciousPeer: Bool = false
    ) {
        self.automaticDownloadPeerType = automaticDownloadPeerType
        self.automaticDownloadPeerId = automaticDownloadPeerId
        self.automaticDownloadNetworkType = automaticDownloadNetworkType
        self.preferredStoryHighQuality = preferredStoryHighQuality
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
        self.availableMessageEffects = availableMessageEffects
        self.savedMessageTags = savedMessageTags
        self.defaultReaction = defaultReaction
        self.isPremium = isPremium
        self.accountPeer = accountPeer
        self.forceInlineReactions = forceInlineReactions
        self.topicAuthorId = topicAuthorId
        self.alwaysDisplayTranscribeButton = alwaysDisplayTranscribeButton
        self.hasBots = hasBots
        self.translateToLanguage = translateToLanguage
        self.maxReadStoryId = maxReadStoryId
        self.recommendedChannels = recommendedChannels
        self.audioTranscriptionTrial = audioTranscriptionTrial
        self.chatThemes = chatThemes
        self.deviceContactsNumbers = deviceContactsNumbers
        self.isStandalone = isStandalone
        self.isInline = isInline
        self.showSensitiveContent = showSensitiveContent
        self.isSuspiciousPeer = isSuspiciousPeer
    }
    
    public static func == (lhs: ChatMessageItemAssociatedData, rhs: ChatMessageItemAssociatedData) -> Bool {
        if lhs.automaticDownloadPeerType != rhs.automaticDownloadPeerType {
            return false
        }
        if lhs.automaticDownloadPeerId != rhs.automaticDownloadPeerId {
            return false
        }
        if lhs.automaticDownloadNetworkType != rhs.automaticDownloadNetworkType {
            return false
        }
        if lhs.preferredStoryHighQuality != rhs.preferredStoryHighQuality {
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
        if lhs.savedMessageTags != rhs.savedMessageTags {
            return false
        }
        if lhs.isPremium != rhs.isPremium {
            return false
        }
        if lhs.accountPeer != rhs.accountPeer {
            return false
        }
        if lhs.forceInlineReactions != rhs.forceInlineReactions {
            return false
        }
        if lhs.topicAuthorId != rhs.topicAuthorId {
            return false
        }
        if lhs.alwaysDisplayTranscribeButton != rhs.alwaysDisplayTranscribeButton {
            return false
        }
        if lhs.hasBots != rhs.hasBots {
            return false
        }
        if lhs.translateToLanguage != rhs.translateToLanguage {
            return false
        }
        if lhs.maxReadStoryId != rhs.maxReadStoryId {
            return false
        }
        if lhs.recommendedChannels != rhs.recommendedChannels {
            return false
        }
        if lhs.audioTranscriptionTrial != rhs.audioTranscriptionTrial {
            return false
        }
        if lhs.chatThemes != rhs.chatThemes {
            return false
        }
        if lhs.deviceContactsNumbers != rhs.deviceContactsNumbers {
            return false
        }
        if lhs.isStandalone != rhs.isStandalone {
            return false
        }
        if lhs.isInline != rhs.isInline {
            return false
        }
        if lhs.showSensitiveContent != rhs.showSensitiveContent {
            return false
        }
        if lhs.isSuspiciousPeer != rhs.isSuspiciousPeer {
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
    case phone(String)
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
    public let botId: EnginePeer.Id
    public let payload: String?
    public let justInstalled: Bool
    
    public init(botId: EnginePeer.Id, payload: String?, justInstalled: Bool) {
        self.botId = botId
        self.payload = payload
        self.justInstalled = justInstalled
    }
}

public struct ChatControllerInitialBotAppStart {
    public let botApp: BotApp?
    public let payload: String?
    public let justInstalled: Bool
    public let mode: ResolvedStartAppMode
    
    public init(botApp: BotApp?, payload: String?, justInstalled: Bool, mode: ResolvedStartAppMode) {
        self.botApp = botApp
        self.payload = payload
        self.justInstalled = justInstalled
        self.mode = mode
    }
}

public enum ChatControllerInteractionNavigateToPeer {
    public struct InfoParams {
        public let switchToRecommendedChannels: Bool
        public let switchToGroupsInCommon: Bool
        public let ignoreInSavedMessages: Bool
        
        public init(switchToRecommendedChannels: Bool = false, switchToGroupsInCommon: Bool = false, ignoreInSavedMessages: Bool = false) {
            self.switchToRecommendedChannels = switchToRecommendedChannels
            self.switchToGroupsInCommon = switchToGroupsInCommon
            self.ignoreInSavedMessages = ignoreInSavedMessages
        }
    }
    
    case `default`
    case chat(textInputState: ChatTextInputState?, subject: ChatControllerSubject?, peekData: ChatPeekTimeout?)
    case info(InfoParams?)
    case withBotStartPayload(ChatControllerInitialBotStart)
    case withAttachBot(ChatControllerInitialAttachBotStart)
    case withBotApp(ChatControllerInitialBotAppStart)
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
    public var inputText: NSAttributedString
    public var selectionRange: Range<Int>
    
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
    case customEmoji(stickerPack: StickerPackReference?, fileId: Int64, enableAnimation: Bool)
    case strikethrough
    case underline
    case spoiler
    case quote(isCollapsed: Bool)
    case codeBlock(language: String?)
    case collapsedQuote(text: ChatTextInputStateText)

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
        case 5:
            let stickerPack = try container.decodeIfPresent(StickerPackReference.self, forKey: "s")
            let fileId = try container.decode(Int64.self, forKey: "f")
            let enableAnimation = try container.decodeIfPresent(Bool.self, forKey: "ea") ?? true
            self = .customEmoji(stickerPack: stickerPack, fileId: fileId, enableAnimation: enableAnimation)
        case 6:
            self = .strikethrough
        case 7:
            self = .underline
        case 8:
            self = .spoiler
        case 9:
            self = .quote(isCollapsed: try container.decodeIfPresent(Bool.self, forKey: "isCollapsed") ?? false)
        case 10:
            self = .codeBlock(language: try container.decodeIfPresent(String.self, forKey: "l"))
        case 11:
            self = .collapsedQuote(text: try container.decode(ChatTextInputStateText.self, forKey: "text"))
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
        case let .customEmoji(stickerPack, fileId, enableAnimation):
            try container.encode(5 as Int32, forKey: "t")
            try container.encodeIfPresent(stickerPack, forKey: "s")
            try container.encode(fileId, forKey: "f")
            try container.encode(enableAnimation, forKey: "ea")
        case .strikethrough:
            try container.encode(6 as Int32, forKey: "t")
        case .underline:
            try container.encode(7 as Int32, forKey: "t")
        case .spoiler:
            try container.encode(8 as Int32, forKey: "t")
        case let .quote(isCollapsed):
            try container.encode(9 as Int32, forKey: "t")
            try container.encode(isCollapsed, forKey: "isCollapsed")
        case let .codeBlock(language):
            try container.encode(10 as Int32, forKey: "t")
            try container.encodeIfPresent(language, forKey: "l")
        case let .collapsedQuote(text):
            try container.encode(11 as Int32, forKey: "t")
            try container.encode(text, forKey: "text")
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
                } else if key == ChatTextInputAttributes.customEmoji, let value = value as? ChatTextInputTextCustomEmojiAttribute {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .customEmoji(stickerPack: nil, fileId: value.fileId, enableAnimation: value.enableAnimation), range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.strikethrough {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .strikethrough, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.underline {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .underline, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.spoiler {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .spoiler, range: range.location ..< (range.location + range.length)))
                }
            }
        })
        attributedText.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: attributedText.length), options: [], using: { value, range, _ in
            if let value = value as? ChatTextInputTextQuoteAttribute {
                switch value.kind {
                case .quote:
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .quote(isCollapsed: value.isCollapsed), range: range.location ..< (range.location + range.length)))
                case let .code(language):
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .codeBlock(language: language), range: range.location ..< (range.location + range.length)))
                }
            }
        })
        attributedText.enumerateAttribute(ChatTextInputAttributes.collapsedBlock, in: NSRange(location: 0, length: attributedText.length), options: [], using: { value, range, _ in
            if let value = value as? NSAttributedString {
                parsedAttributes.append(ChatTextInputStateTextAttribute(type: .collapsedQuote(text: ChatTextInputStateText(attributedText: value)), range: range.location ..< (range.location + range.length)))
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
    
    public func attributedText(files: [Int64: TelegramMediaFile] = [:]) -> NSAttributedString {
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
            case let .customEmoji(_, fileId, enableAnimation):
                result.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: files[fileId], enableAnimation: enableAnimation), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .strikethrough:
                result.addAttribute(ChatTextInputAttributes.strikethrough, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .underline:
                result.addAttribute(ChatTextInputAttributes.underline, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .spoiler:
                result.addAttribute(ChatTextInputAttributes.spoiler, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .quote(isCollapsed):
                result.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: isCollapsed), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .codeBlock(language):
                result.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .code(language: language), isCollapsed: false), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .collapsedQuote(text):
                result.addAttribute(ChatTextInputAttributes.collapsedBlock, value: text.attributedText(), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            }
        }
        return result
    }
}

public enum ChatControllerSubject: Equatable {
    public enum MessageSubject: Equatable {
        case id(EngineMessage.Id)
        case timestamp(Int32)
    }

    public struct ForwardOptions: Equatable {
        public var hideNames: Bool
        public var hideCaptions: Bool
        
        public init(hideNames: Bool, hideCaptions: Bool) {
            self.hideNames = hideNames
            self.hideCaptions = hideCaptions
        }
    }
    
    public struct LinkOptions: Equatable {
        public var messageText: String
        public var messageEntities: [MessageTextEntity]
        public var hasAlternativeLinks: Bool
        public var replyMessageId: EngineMessage.Id?
        public var replyQuote: String?
        public var url: String
        public var webpage: TelegramMediaWebpage
        public var linkBelowText: Bool
        public var largeMedia: Bool
        
        public init(
            messageText: String,
            messageEntities: [MessageTextEntity],
            hasAlternativeLinks: Bool,
            replyMessageId: EngineMessage.Id?,
            replyQuote: String?,
            url: String,
            webpage: TelegramMediaWebpage,
            linkBelowText: Bool,
            largeMedia: Bool
        ) {
            self.messageText = messageText
            self.messageEntities = messageEntities
            self.hasAlternativeLinks = hasAlternativeLinks
            self.replyMessageId = replyMessageId
            self.replyQuote = replyQuote
            self.url = url
            self.webpage = webpage
            self.linkBelowText = linkBelowText
            self.largeMedia = largeMedia
        }
    }
    
    public enum MessageOptionsInfo: Equatable {
        public struct Quote: Equatable {
            public let messageId: EngineMessage.Id
            public let text: String
            public let offset: Int?
            
            public init(messageId: EngineMessage.Id, text: String, offset: Int?) {
                self.messageId = messageId
                self.text = text
                self.offset = offset
            }
        }
        
        public struct SelectionState: Equatable {
            public var canQuote: Bool
            public var quote: Quote?
            
            public init(canQuote: Bool, quote: Quote?) {
                self.canQuote = canQuote
                self.quote = quote
            }
        }
        
        public struct Reply: Equatable {
            public var quote: Quote?
            public var selectionState: Promise<SelectionState>
            
            public init(quote: Quote?, selectionState: Promise<SelectionState>) {
                self.quote = quote
                self.selectionState = selectionState
            }
            
            public static func ==(lhs: Reply, rhs: Reply) -> Bool {
                if lhs.quote != rhs.quote {
                    return false
                }
                if lhs.selectionState !== rhs.selectionState {
                    return false
                }
                return true
            }
        }
        
        public struct Forward: Equatable {
            public var options: Signal<ForwardOptions, NoError>
            
            public init(options: Signal<ForwardOptions, NoError>) {
                self.options = options
            }
            
            public static func ==(lhs: Forward, rhs: Forward) -> Bool {
                return true
            }
        }
        
        public struct Link: Equatable {
            public var options: Signal<LinkOptions, NoError>
            public var isCentered: Bool
            
            public init(options: Signal<LinkOptions, NoError>, isCentered: Bool) {
                self.options = options
                self.isCentered = isCentered
            }
            
            public static func ==(lhs: Link, rhs: Link) -> Bool {
                return true
            }
        }
        
        case reply(Reply)
        case forward(Forward)
        case link(Link)
    }
    
    public struct MessageHighlight: Equatable {
        public struct Quote: Equatable {
            public var string: String
            public var offset: Int?
            
            public init(string: String, offset: Int?) {
                self.string = string
                self.offset = offset
            }
        }
        
        public var quote: Quote?
        public var todoTaskId: Int32?
        
        public init(quote: Quote? = nil, todoTaskId: Int32? = nil) {
            self.quote = quote
            self.todoTaskId = todoTaskId
        }
    }
    
    case message(id: MessageSubject, highlight: MessageHighlight?, timecode: Double?, setupReply: Bool)
    case scheduledMessages
    case pinnedMessages(id: EngineMessage.Id?)
    case messageOptions(peerIds: [EnginePeer.Id], ids: [EngineMessage.Id], info: MessageOptionsInfo)
    case customChatContents(contents: ChatCustomContentsProtocol)
    
    public static func ==(lhs: ChatControllerSubject, rhs: ChatControllerSubject) -> Bool {
        switch lhs {
        case let .message(lhsId, lhsHighlight, lhsTimecode, lhsSetupReply):
            if case let .message(rhsId, rhsHighlight, rhsTimecode, rhsSetupReply) = rhs, lhsId == rhsId && lhsHighlight == rhsHighlight && lhsTimecode == rhsTimecode && lhsSetupReply == rhsSetupReply {
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
        case let .messageOptions(lhsPeerIds, lhsIds, lhsInfo):
            if case let .messageOptions(rhsPeerIds, rhsIds, rhsInfo) = rhs, lhsPeerIds == rhsPeerIds, lhsIds == rhsIds, lhsInfo == rhsInfo {
                return true
            } else {
                return false
            }
        case let .customChatContents(lhsValue):
            if case let .customChatContents(rhsValue) = rhs, lhsValue === rhsValue {
                return true
            } else {
                return false
            }
        }
    }
    
    public var isService: Bool {
        switch self {
        case .message:
            return false
        default:
            return true
        }
    }
}

public enum ChatControllerPresentationMode: Equatable {
    public enum StandardPresentation: Equatable {
        case `default`
        case previewing
        case embedded(invertDirection: Bool)
    }
    
    case standard(StandardPresentation)
    case overlay(NavigationController?)
    case inline(NavigationController?)
}

public enum ChatInputTextCommand: Equatable {
    case command(PeerCommand)
    case shortcut(ShortcutMessageList.Item)
}

public struct ChatInputQueryCommandsResult: Equatable {
    public var commands: [ChatInputTextCommand]
    public var accountPeer: EnginePeer?
    public var hasShortcuts: Bool
    public var query: String
    
    public init(commands: [ChatInputTextCommand], accountPeer: EnginePeer?, hasShortcuts: Bool, query: String) {
        self.commands = commands
        self.accountPeer = accountPeer
        self.hasShortcuts = hasShortcuts
        self.query = query
    }
}

public enum ChatPresentationInputQueryResult: Equatable {
    case stickers([FoundStickerItem])
    case hashtags([String], String)
    case mentions([EnginePeer])
    case commands(ChatInputQueryCommandsResult)
    case emojis([(String, TelegramMediaFile?, String)], NSRange)
    case contextRequestResult(EnginePeer?, ChatContextResultCollection?)
    
    public static func ==(lhs: ChatPresentationInputQueryResult, rhs: ChatPresentationInputQueryResult) -> Bool {
        switch lhs {
        case let .stickers(lhsItems):
            if case let .stickers(rhsItems) = rhs, lhsItems == rhsItems {
                return true
            } else {
                return false
            }
        case let .hashtags(lhsResults, lhsQuery):
            if case let .hashtags(rhsResults, rhsQuery) = rhs {
                return lhsResults == rhsResults && lhsQuery == rhsQuery
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
                    if lhsValue[i].0 != rhsValue[i].0 {
                        return false
                    }
                    if lhsValue[i].1?.fileId != rhsValue[i].1?.fileId {
                        return false
                    }
                    if lhsValue[i].2 != rhsValue[i].2 {
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

public final class PeerInfoNavigationSourceTag {
    public let peerId: EnginePeer.Id
    public let threadId: Int64?
    
    public init(peerId: EnginePeer.Id, threadId: Int64?) {
        self.peerId = peerId
        self.threadId = threadId
    }
}

public enum PeerInfoAvatarUploadStatus {
    case progress(Float)
    case done
}

public protocol PeerInfoScreen: ViewController {
    var peerId: PeerId { get }
    var privacySettings: Promise<AccountPrivacySettings?> { get }
    
    func openBirthdaySetup()
    func toggleStorySelection(ids: [Int32], isSelected: Bool)
    func togglePaneIsReordering(isReordering: Bool)
    func cancelItemSelection()
    func openAvatarSetup(completedWithUploadingImage: @escaping (UIImage, Signal<PeerInfoAvatarUploadStatus, NoError>) -> UIView?)
    func openAvatars()
}

public extension Peer {
    func canSetupAutoremoveTimeout(accountPeerId: EnginePeer.Id) -> Bool {
        if let _ = self as? TelegramSecretChat {
            return false
        } else if let group = self as? TelegramGroup {
            if case .creator = group.role {
                return true
            } else if case let .admin(rights, _) = group.role {
                if rights.rights.contains(.canDeleteMessages) {
                    return true
                }
            }
        } else if let user = self as? TelegramUser {
            if user.id != accountPeerId && user.botInfo == nil {
                return true
            }
        } else if let channel = self as? TelegramChannel {
            if channel.hasPermission(.deleteAllMessages) {
                return true
            }
        }
        
        return false
    }
}

public struct ChatControllerCustomNavigationPanelNodeLayoutResult {
    public var backgroundHeight: CGFloat
    public var insetHeight: CGFloat
    public var hitTestSlop: CGFloat
    
    public init(backgroundHeight: CGFloat, insetHeight: CGFloat, hitTestSlop: CGFloat) {
        self.backgroundHeight = backgroundHeight
        self.insetHeight = insetHeight
        self.hitTestSlop = hitTestSlop
    }
}

public protocol ChatControllerCustomNavigationPanelNode: ASDisplayNode {
    typealias LayoutResult = ChatControllerCustomNavigationPanelNodeLayoutResult
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, chatController: ChatController) -> LayoutResult
}

public enum ChatControllerAnimateInnerChatSwitchDirection {
    case up
    case down
    case left
    case right
}

public protocol ChatController: ViewController {
    var chatLocation: ChatLocation { get }
    var canReadHistory: ValuePromise<Bool> { get }
    var parentController: ViewController? { get set }
    var customNavigationController: NavigationController? { get set }
    
    var dismissPreviewing: ((Bool) -> (() -> Void))? { get set }
    var purposefulAction: (() -> Void)? { get set }
    
    var stateUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    var customDismissSearch: (() -> Void)? { get set }
    
    var selectedMessageIds: Set<EngineMessage.Id>? { get }
    var presentationInterfaceStateSignal: Signal<Any, NoError> { get }
    
    var customNavigationBarContentNode: NavigationBarContentNode? { get }
    var customNavigationPanelNode: ChatControllerCustomNavigationPanelNode? { get }
    
    var visibleContextController: ViewController? { get }
    
    var contentContainerNode: ASDisplayNode { get }
    
    var searching: ValuePromise<Bool> { get }
    var searchResultsCount: ValuePromise<Int32> { get }
    var externalSearchResultsCount: Int32? { get set }
    
    var alwaysShowSearchResultsAsList: Bool { get set }
    var includeSavedPeersInSearchResults: Bool { get set }
    var showListEmptyResults: Bool { get set }
    func beginMessageSearch(_ query: String)
    
    func updatePresentationMode(_ mode: ChatControllerPresentationMode)
    func displayPromoAnnouncement(text: String)
    
    func updatePushedTransition(_ fraction: CGFloat, transition: ContainedViewLayoutTransition)
    
    func hintPlayNextOutgoingGift()
    
    var isSendButtonVisible: Bool { get }
    
    var isSelectingMessagesUpdated: ((Bool) -> Void)? { get set }
    func cancelSelectingMessages()
    func activateSearch(domain: ChatSearchDomain, query: String)
    func activateInput(type: ChatControllerActivateInput)
    func beginClearHistory(type: InteractiveHistoryClearingType)
    
    func performScrollToTop() -> Bool
    func transferScrollingVelocity(_ velocity: CGFloat)
    func updateIsScrollingLockedAtTop(isScrollingLockedAtTop: Bool)
    
    func playShakeAnimation()
    
    func removeAd(opaqueId: Data)
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
    public var fetchStatus: EngineMediaResource.FetchStatus
    
    public init(mediaStatus: FileMediaResourceMediaStatus, fetchStatus: EngineMediaResource.FetchStatus) {
        self.mediaStatus = mediaStatus
        self.fetchStatus = fetchStatus
    }
}

public enum FileMediaResourceMediaStatus: Equatable {
    case fetchStatus(EngineMediaResource.FetchStatus)
    case playbackStatus(FileMediaResourcePlaybackStatus)
}

public protocol ChatMessageItemNodeProtocol: ListViewItemNode {
    func makeProgress() -> Promise<Bool>?
    func targetReactionView(value: MessageReaction.Reaction) -> UIView?
    func targetForStoryTransition(id: StoryId) -> UIView?
    func contentFrame() -> CGRect
    func matchesMessage(id: MessageId) -> Bool
    func cancelInsertionAnimations()
    func messages() -> [Message]
}

public final class ChatControllerNavigationData: CustomViewControllerNavigationData {
    public let peerId: PeerId
    public let threadId: Int64?
    
    public init(peerId: PeerId, threadId: Int64?) {
        self.peerId = peerId
        self.threadId = threadId
    }
    
    public func combine(summary: CustomViewControllerNavigationDataSummary?) -> CustomViewControllerNavigationDataSummary? {
        if let summary = summary as? ChatControllerNavigationDataSummary {
            return summary.adding(peerNavigationItem: ChatNavigationStackItem(peerId: self.peerId, threadId: threadId))
        } else {
            return ChatControllerNavigationDataSummary(peerNavigationItems: [ChatNavigationStackItem(peerId: self.peerId, threadId: threadId)])
        }
    }
}

public final class ChatControllerNavigationDataSummary: CustomViewControllerNavigationDataSummary {
    public let peerNavigationItems: [ChatNavigationStackItem]
    
    public init(peerNavigationItems: [ChatNavigationStackItem]) {
        self.peerNavigationItems = peerNavigationItems
    }
    
    public func adding(peerNavigationItem: ChatNavigationStackItem) -> ChatControllerNavigationDataSummary {
        var peerNavigationItems = self.peerNavigationItems
        if let index = peerNavigationItems.firstIndex(of: peerNavigationItem) {
            peerNavigationItems.removeSubrange(0 ... index)
        }
        peerNavigationItems.insert(peerNavigationItem, at: 0)
        return ChatControllerNavigationDataSummary(peerNavigationItems: peerNavigationItems)
    }
}

public enum ChatHistoryListSource {
    public struct Quote {
        public var text: String
        public var offset: Int?
        
        public init(text: String, offset: Int?) {
            self.text = text
            self.offset = offset
        }
    }
    
    case `default`
    case custom(messages: Signal<([Message], Int32, Bool), NoError>, messageId: MessageId?, quote: Quote?, loadMore: (() -> Void)?)
    case customView(historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError>)
}

public enum ChatQuickReplyShortcutType {
    case generic
    case greeting
    case away
}

public enum ChatCustomContentsKind: Equatable {
    case quickReplyMessageInput(shortcut: String, shortcutType: ChatQuickReplyShortcutType)
    case businessLinkSetup(link: TelegramBusinessChatLinks.Link)
    case hashTagSearch(publicPosts: Bool)
}

public protocol ChatCustomContentsProtocol: AnyObject {
    var kind: ChatCustomContentsKind { get }
    var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> { get }
    var messageLimit: Int? { get }
    
    func enqueueMessages(messages: [EnqueueMessage])
    func deleteMessages(ids: [EngineMessage.Id])
    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool)
    
    func quickReplyUpdateShortcut(value: String)
    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?)
    
    func loadMore()
    
    func hashtagSearchUpdate(query: String)
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void { get set }
}

public enum ChatHistoryListDisplayHeaders {
    case none
    case all
    case allButLast
}

public enum ChatHistoryListMode: Equatable {
    case bubbles
    case list(search: Bool, reversed: Bool, reverseGroups: Bool, displayHeaders: ChatHistoryListDisplayHeaders, hintLinks: Bool, isGlobalSearch: Bool)
}

public protocol ChatControllerInteractionProtocol: AnyObject {
}

public enum ChatHistoryNodeHistoryState: Equatable {
    case loading
    case loaded(isEmpty: Bool, hasReachedLimits: Bool)
}

public protocol ChatHistoryListNode: ListView {
    var historyState: ValuePromise<ChatHistoryNodeHistoryState> { get }
    
    func scrollToEndOfHistory()
    func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets)
    func messageInCurrentHistoryView(_ id: MessageId) -> Message?
    
    var contentPositionChanged: (ListViewVisibleContentOffset) -> Void { get set }
}

public extension ChatFolderTitle {
    init(attributedString: NSAttributedString, enableAnimations: Bool) {
        let inputStateText = ChatTextInputStateText(attributedText: attributedString)
        self.init(text: inputStateText.text, entities: inputStateText.attributes.compactMap { attribute -> MessageTextEntity? in
            if case let .customEmoji(_, fileId, _) = attribute.type {
                return MessageTextEntity(range: attribute.range, type: .CustomEmoji(stickerPack: nil, fileId: fileId))
            }
            return nil
        }, enableAnimations: enableAnimations)
    }
    
    var rawAttributedString: NSAttributedString {
        let inputStateText = ChatTextInputStateText(text: self.text, attributes: self.entities.compactMap { entity -> ChatTextInputStateTextAttribute? in
            if case let .CustomEmoji(_, fileId) = entity.type {
                return ChatTextInputStateTextAttribute(type: .customEmoji(stickerPack: nil, fileId: fileId, enableAnimation: self.enableAnimations), range: entity.range)
            }
            return nil
        })
        return inputStateText.attributedText()
    }
    
    func attributedString(attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: self.rawAttributedString)
        result.addAttributes(attributes, range: NSRange(location: 0, length: result.length))
        return result
    }
    
    func attributedString(font: UIFont, textColor: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: self.rawAttributedString)
        result.addAttributes([
            .font: font,
            .foregroundColor: textColor
        ], range: NSRange(location: 0, length: result.length))
        return result
    }
}
