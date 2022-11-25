import Foundation
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PlatformRestrictionMatching
import TextFormat

public enum MessageContentKindKey {
    case text
    case image
    case video
    case videoMessage
    case audioMessage
    case sticker
    case animation
    case file
    case contact
    case game
    case location
    case liveLocation
    case expiredImage
    case expiredVideo
    case poll
    case restricted
    case dice
    case invoice
}

public enum MessageContentKind: Equatable {
    case text(NSAttributedString)
    case image
    case video
    case videoMessage
    case audioMessage
    case sticker(String)
    case animation
    case file(String)
    case contact
    case game(String)
    case location
    case liveLocation
    case expiredImage
    case expiredVideo
    case poll(String)
    case restricted(String)
    case dice(String)
    case invoice(String)
    
    public func isSemanticallyEqual(to other: MessageContentKind) -> Bool {
        switch self {
        case .text:
            if case .text = other {
                return true
            } else {
                return false
            }
        case .image:
            if case .image = other {
                return true
            } else {
                return false
            }
        case .video:
            if case .video = other {
                return true
            } else {
                return false
            }
        case .videoMessage:
            if case .videoMessage = other {
                return true
            } else {
                return false
            }
        case .audioMessage:
            if case .audioMessage = other {
                return true
            } else {
                return false
            }
        case .sticker:
            if case .sticker = other {
                return true
            } else {
                return false
            }
        case .animation:
            if case .animation = other {
                return true
            } else {
                return false
            }
        case .file:
            if case .file = other {
                return true
            } else {
                return false
            }
        case .contact:
            if case .contact = other {
                return true
            } else {
                return false
            }
        case .game:
            if case .game = other {
                return true
            } else {
                return false
            }
        case .location:
            if case .location = other {
                return true
            } else {
                return false
            }
        case .liveLocation:
            if case .liveLocation = other {
                return true
            } else {
                return false
            }
        case .expiredImage:
            if case .expiredImage = other {
                return true
            } else {
                return false
            }
        case .expiredVideo:
            if case .expiredVideo = other {
                return true
            } else {
                return false
            }
        case .poll:
            if case .poll = other {
                return true
            } else {
                return false
            }
        case .restricted:
            if case .restricted = other {
                return true
            } else {
                return false
            }
        case .dice:
            if case .dice = other {
                return true
            } else {
                return false
            }
        case .invoice:
            if case .invoice = other {
                return true
            } else {
                return false
            }
        }
    }
    
    public var key: MessageContentKindKey {
        switch self {
        case .text:
            return .text
        case .image:
            return .image
        case .video:
            return .video
        case .videoMessage:
            return .videoMessage
        case .audioMessage:
            return .audioMessage
        case .sticker:
            return .sticker
        case .animation:
            return .animation
        case .file:
            return .file
        case .contact:
            return .contact
        case .game:
            return .game
        case .location:
            return .location
        case .liveLocation:
            return .liveLocation
        case .expiredImage:
            return .expiredImage
        case .expiredVideo:
            return .expiredVideo
        case .poll:
            return .poll
        case .restricted:
            return .restricted
        case .dice:
            return .dice
        case .invoice:
            return .invoice
        }
    }
}

public func messageTextWithAttributes(message: EngineMessage) -> NSAttributedString {
    var attributedText = NSAttributedString(string: message.text)
    
    var entities: TextEntitiesMessageAttribute?
    for attribute in message.attributes {
        if let attribute = attribute as? TextEntitiesMessageAttribute {
            entities = attribute
            break
        }
    }
    if let entities = entities?.entities {
        let updatedString = NSMutableAttributedString(attributedString: attributedText)
        
        for entity in entities.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            guard case let .CustomEmoji(_, fileId) = entity.type else {
                continue
            }
            
            let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
            
            let currentDict = updatedString.attributes(at: range.lowerBound, effectiveRange: nil)
            var updatedAttributes: [NSAttributedString.Key: Any] = currentDict
            updatedAttributes[ChatTextInputAttributes.customEmoji] = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile)
            
            let insertString = NSAttributedString(string: updatedString.attributedSubstring(from: range).string, attributes: updatedAttributes)
            updatedString.replaceCharacters(in: range, with: insertString)
        }
        attributedText = updatedString
    }
    
    return attributedText
}

public func messageContentKind(contentSettings: ContentSettings, message: EngineMessage, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, accountPeerId: EnginePeer.Id) -> MessageContentKind {
    for attribute in message.attributes {
        if let attribute = attribute as? RestrictedContentMessageAttribute {
            if let text = attribute.platformText(platform: "ios", contentSettings: contentSettings) {
                return .restricted(text)
            }
            break
        }
    }
    for media in message.media {
        if let kind = mediaContentKind(EngineMedia(media), message: message, strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: accountPeerId) {
            return kind
        }
    }
    return .text(messageTextWithAttributes(message: message))
}

public func mediaContentKind(_ media: EngineMedia, message: EngineMessage? = nil, strings: PresentationStrings? = nil, nameDisplayOrder: PresentationPersonNameOrder? = nil, dateTimeFormat: PresentationDateTimeFormat? = nil, accountPeerId: EnginePeer.Id? = nil) -> MessageContentKind? {
    switch media {
    case let .expiredContent(expiredMedia):
        switch expiredMedia.data {
        case .image:
            return .expiredImage
        case .file:
            return .expiredVideo
        }
    case .image:
        return .image
    case let .file(file):
        var fileName: String = ""
        
        var result: MessageContentKind?
        for attribute in file.attributes {
            switch attribute {
            case let .Sticker(text, _, _):
                return .sticker(text)
            case let .FileName(name):
                fileName = name
            case let .Audio(isVoice, _, title, performer, _):
                if isVoice {
                    return .audioMessage
                } else {
                    if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                        return .file(title + " — " + performer)
                    } else if let title = title, !title.isEmpty {
                        return .file(title)
                    } else if let performer = performer, !performer.isEmpty {
                        return .file(performer)
                    }
                }
            case let .Video(_, _, flags):
                if file.isAnimated {
                    result = .animation
                } else {
                    if flags.contains(.instantRoundVideo) {
                        result = .videoMessage
                    } else {
                        result = .video
                    }
                }
            default:
                break
            }
        }
        if let result = result {
            return result
        }
        if file.isVideoSticker || file.isAnimatedSticker {
            return .sticker("")
        }
        return .file(fileName)
    case .contact:
        return .contact
    case let .game(game):
        return .game(game.title)
    case let .geo(location):
        if location.liveBroadcastingTimeout != nil {
            return .liveLocation
        } else {
            return .location
        }
    case .action:
        if let message = message, let strings = strings, let nameDisplayOrder = nameDisplayOrder, let accountPeerId = accountPeerId {
            return .text(NSAttributedString(string: plainServiceMessageString(strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat ?? PresentationDateTimeFormat(timeFormat: .military, dateFormat: .dayFirst, dateSeparator: ".", dateSuffix: "", requiresFullYear: false, decimalSeparator: ".", groupingSeparator: ""), message: message, accountPeerId: accountPeerId, forChatList: false, forForumOverview: false)?.0 ?? ""))
        } else {
            return nil
        }
    case let .poll(poll):
        return .poll(poll.text)
    case let .dice(dice):
        return .dice(dice.emoji)
    case let .invoice(invoice):
        if !invoice.description.isEmpty {
            return .invoice(invoice.description)
        } else {
            return .invoice(invoice.title)
        }
    default:
        return nil
    }
}

public func stringForMediaKind(_ kind: MessageContentKind, strings: PresentationStrings) -> (NSAttributedString, Bool) {
    switch kind {
    case let .text(text):
        return (foldLineBreaks(text), false)
    case .image:
        return (NSAttributedString(string: strings.Message_Photo), true)
    case .video:
        return (NSAttributedString(string: strings.Message_Video), true)
    case .videoMessage:
        return (NSAttributedString(string: strings.Message_VideoMessage), true)
    case .audioMessage:
        return (NSAttributedString(string: strings.Message_Audio), true)
    case let .sticker(text):
        if text.isEmpty {
            return (NSAttributedString(string: strings.Message_Sticker), true)
        } else {
            return (NSAttributedString(string: strings.Message_StickerText(text).string), true)
        }
    case .animation:
        return (NSAttributedString(string: strings.Message_Animation), true)
    case let .file(text):
        if text.isEmpty {
            return (NSAttributedString(string: strings.Message_File), true)
        } else {
            return (NSAttributedString(string: text), true)
        }
    case .contact:
        return (NSAttributedString(string: strings.Message_Contact), true)
    case let .game(text):
        return (NSAttributedString(string: text), true)
    case .location:
        return (NSAttributedString(string: strings.Message_Location), true)
    case .liveLocation:
        return (NSAttributedString(string: strings.Message_LiveLocation), true)
    case .expiredImage:
        return (NSAttributedString(string: strings.Message_ImageExpired), true)
    case .expiredVideo:
        return (NSAttributedString(string: strings.Message_VideoExpired), true)
    case let .poll(text):
        return (NSAttributedString(string: "📊 \(text)"), false)
    case let .restricted(text):
        return (NSAttributedString(string: text), false)
    case let .dice(emoji):
        return (NSAttributedString(string: emoji), true)
    case let .invoice(text):
        return (NSAttributedString(string: text), true)
    }
}

public func descriptionStringForMessage(contentSettings: ContentSettings, message: EngineMessage, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, accountPeerId: EnginePeer.Id) -> (NSAttributedString, Bool, Bool) {
    let contentKind = messageContentKind(contentSettings: contentSettings, message: message, strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: accountPeerId)
    if !message.text.isEmpty && ![.expiredImage, .expiredVideo].contains(contentKind.key) {
        return (foldLineBreaks(messageTextWithAttributes(message: message)), false, true)
    }
    let result = stringForMediaKind(contentKind, strings: strings)
    return (result.0, result.1, false)
}

public func foldLineBreaks(_ text: String) -> String {
    let lines = text.split { $0.isNewline }
    var result = ""
    for line in lines {
        if line.isEmpty {
            continue
        }
        if result.isEmpty {
            result += line
        } else {
            result += " " + line
        }
    }
    result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return result
}

public func foldLineBreaks(_ text: NSAttributedString) -> NSAttributedString {
    let remainingString = NSMutableAttributedString(attributedString: text)
    var lines: [NSAttributedString] = []
    while true {
        if let range = remainingString.string.range(of: "\n") {
            let mappedRange = NSRange(range, in: remainingString.string)
            lines.append(remainingString.attributedSubstring(from: NSRange(location: 0, length: mappedRange.upperBound)))
            remainingString.replaceCharacters(in: NSRange(location: 0, length: mappedRange.upperBound), with: "")
        } else {
            if lines.isEmpty {
                return text
            }
            if !remainingString.string.isEmpty {
                lines.append(remainingString)
            }
            break
        }
    }
    
    let result = NSMutableAttributedString()
    
    for line in lines {
        if line.string.isEmpty {
            continue
        }
        if result.string.isEmpty {
            result.append(line)
        } else {
            let currentAttributes = line.attributes(at: 0, effectiveRange: nil).filter { key, _ in
                switch key {
                case .font, .foregroundColor:
                    return true
                default:
                    return false
                }
            }
            result.append(NSAttributedString(string: " ", attributes: currentAttributes))
            result.append(line)
        }
    }
    
    return result
}

public func trimToLineCount(_ text: String, lineCount: Int) -> String {
    if lineCount < 1 {
        return ""
    }

    var result = ""
    
    var i = 0
    text.enumerateLines { line, stop in
        if !result.isEmpty {
            result += "\n"
        }
        result += line
        i += 1
        if i == lineCount {
            stop = true
        }
    }
    
    return result
}
