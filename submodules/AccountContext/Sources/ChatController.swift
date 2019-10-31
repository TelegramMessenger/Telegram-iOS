import Foundation
import Postbox
import TelegramCore
import SyncCore
import TextFormat
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences

public enum ChatControllerInitialBotStartBehavior {
    case interactive
    case automatic(returnToPeerId: PeerId, scheduled: Bool)
}

public struct ChatControllerInitialBotStart {
    public let payload: String
    public let behavior: ChatControllerInitialBotStartBehavior
    
    public init(payload: String, behavior: ChatControllerInitialBotStartBehavior) {
        self.payload = payload
        self.behavior = behavior
    }
}

public enum ChatControllerInteractionNavigateToPeer {
    case `default`
    case chat(textInputState: ChatTextInputState?, subject: ChatControllerSubject?)
    case info
    case withBotStartPayload(ChatControllerInitialBotStart)
}

public struct ChatTextInputState: PostboxCoding, Equatable {
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
    
    public init(decoder: PostboxDecoder) {
        self.inputText = ((decoder.decodeObjectForKey("at", decoder: { ChatTextInputStateText(decoder: $0) }) as? ChatTextInputStateText) ?? ChatTextInputStateText()).attributedText()
        self.selectionRange = Int(decoder.decodeInt32ForKey("as0", orElse: 0)) ..< Int(decoder.decodeInt32ForKey("as1", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(ChatTextInputStateText(attributedText: self.inputText), forKey: "at")
        
        encoder.encodeInt32(Int32(self.selectionRange.lowerBound), forKey: "as0")
        encoder.encodeInt32(Int32(self.selectionRange.upperBound), forKey: "as1")
    }
}

public enum ChatTextInputStateTextAttributeType: PostboxCoding, Equatable {
    case bold
    case italic
    case monospace
    case textMention(PeerId)
    case textUrl(String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("t", orElse: 0) {
        case 0:
            self = .bold
        case 1:
            self = .italic
        case 2:
            self = .monospace
        case 3:
            self = .textMention(PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0)))
        case 4:
            self = .textUrl(decoder.decodeStringForKey("url", orElse: ""))
        default:
            assertionFailure()
            self = .bold
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .bold:
            encoder.encodeInt32(0, forKey: "t")
        case .italic:
            encoder.encodeInt32(1, forKey: "t")
        case .monospace:
            encoder.encodeInt32(2, forKey: "t")
        case let .textMention(id):
            encoder.encodeInt32(3, forKey: "t")
            encoder.encodeInt64(id.toInt64(), forKey: "peerId")
        case let .textUrl(url):
            encoder.encodeInt32(4, forKey: "t")
            encoder.encodeString(url, forKey: "url")
        }
    }
    
    public static func ==(lhs: ChatTextInputStateTextAttributeType, rhs: ChatTextInputStateTextAttributeType) -> Bool {
        switch lhs {
        case .bold:
            if case .bold = rhs {
                return true
            } else {
                return false
            }
        case .italic:
            if case .italic = rhs {
                return true
            } else {
                return false
            }
        case .monospace:
            if case .monospace = rhs {
                return true
            } else {
                return false
            }
        case let .textMention(id):
            if case .textMention(id) = rhs {
                return true
            } else {
                return false
            }
        case let .textUrl(url):
            if case .textUrl(url) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public struct ChatTextInputStateTextAttribute: PostboxCoding, Equatable {
    public let type: ChatTextInputStateTextAttributeType
    public let range: Range<Int>
    
    public init(type: ChatTextInputStateTextAttributeType, range: Range<Int>) {
        self.type = type
        self.range = range
    }
    
    public init(decoder: PostboxDecoder) {
        self.type = decoder.decodeObjectForKey("type", decoder: { ChatTextInputStateTextAttributeType(decoder: $0) }) as! ChatTextInputStateTextAttributeType
        self.range = Int(decoder.decodeInt32ForKey("range0", orElse: 0)) ..< Int(decoder.decodeInt32ForKey("range1", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.type, forKey: "type")
        encoder.encodeInt32(Int32(self.range.lowerBound), forKey: "range0")
        encoder.encodeInt32(Int32(self.range.upperBound), forKey: "range1")
    }
    
    public static func ==(lhs: ChatTextInputStateTextAttribute, rhs: ChatTextInputStateTextAttribute) -> Bool {
        return lhs.type == rhs.type && lhs.range == rhs.range
    }
}

public struct ChatTextInputStateText: PostboxCoding, Equatable {
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
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.attributes = decoder.decodeObjectArrayWithDecoderForKey("attributes")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeObjectArray(self.attributes, forKey: "attributes")
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
    case message(MessageId)
    case scheduledMessages
}

public enum ChatControllerPresentationMode: Equatable {
    case standard(previewing: Bool)
    case overlay
    case inline(NavigationController?)
}

public final class ChatEmbeddedInterfaceState: PeerChatListEmbeddedInterfaceState {
    public let timestamp: Int32
    public let text: NSAttributedString
    
    public init(timestamp: Int32, text: NSAttributedString) {
        self.timestamp = timestamp
        self.text = text
    }
    
    public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("d", orElse: 0)
        self.text = ((decoder.decodeObjectForKey("at", decoder: { ChatTextInputStateText(decoder: $0) }) as? ChatTextInputStateText) ?? ChatTextInputStateText()).attributedText()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "d")
        encoder.encodeObject(ChatTextInputStateText(attributedText: self.text), forKey: "at")
    }
    
    public func isEqual(to: PeerChatListEmbeddedInterfaceState) -> Bool {
        if let to = to as? ChatEmbeddedInterfaceState {
            return self.timestamp == to.timestamp && self.text.isEqual(to: to.text)
        } else {
            return false
        }
    }
}

public enum ChatPresentationInputQueryResult: Equatable {
    case stickers([FoundStickerItem])
    case hashtags([String])
    case mentions([Peer])
    case commands([PeerCommand])
    case emojis([(String, String)], NSRange)
    case contextRequestResult(Peer?, ChatContextResultCollection?)
    
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
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer != nil) != (rhsPeer != nil) {
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

public protocol ChatController: ViewController {
    var chatLocation: ChatLocation { get }
    var canReadHistory: ValuePromise<Bool> { get }
    var parentController: ViewController? { get set }
    
    func updatePresentationMode(_ mode: ChatControllerPresentationMode)
    func beginMessageSearch(_ query: String)
}

public protocol ChatMessagePrevewItemNode: class {
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
