import Foundation
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import PlatformRestrictionMatching

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
}

public enum MessageContentKind: Equatable {
    case text(String)
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
        }
    }
}

public func messageContentKind(contentSettings: ContentSettings, message: Message, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, accountPeerId: PeerId) -> MessageContentKind {
    for attribute in message.attributes {
        if let attribute = attribute as? RestrictedContentMessageAttribute {
            if let text = attribute.platformText(platform: "ios", contentSettings: contentSettings) {
                return .restricted(text)
            }
            break
        }
    }
    for media in message.media {
        if let kind = mediaContentKind(media, message: message, strings: strings, nameDisplayOrder: nameDisplayOrder, accountPeerId: accountPeerId) {
            return kind
        }
    }
    return .text(message.text)
}

public func mediaContentKind(_ media: Media, message: Message? = nil, strings: PresentationStrings? = nil, nameDisplayOrder: PresentationPersonNameOrder? = nil, accountPeerId: PeerId? = nil) -> MessageContentKind? {
    switch media {
    case let expiredMedia as TelegramMediaExpiredContent:
        switch expiredMedia.data {
        case .image:
            return .expiredImage
        case .file:
            return .expiredVideo
        }
    case _ as TelegramMediaImage:
        return .image
    case let file as TelegramMediaFile:
        var fileName: String = ""
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
                    return .animation
                } else {
                    if flags.contains(.instantRoundVideo) {
                        return .videoMessage
                    } else {
                        return .video
                    }
                }
            default:
                break
            }
        }
        if file.isAnimatedSticker {
            return .sticker("")
        }
        return .file(fileName)
    case _ as TelegramMediaContact:
        return .contact
    case let game as TelegramMediaGame:
        return .game(game.title)
    case let location as TelegramMediaMap:
        if location.liveBroadcastingTimeout != nil {
            return .liveLocation
        } else {
            return .location
        }
    case _ as TelegramMediaAction:
        if let message = message, let strings = strings, let nameDisplayOrder = nameDisplayOrder, let accountPeerId = accountPeerId {
            return .text(plainServiceMessageString(strings: strings, nameDisplayOrder: nameDisplayOrder, message: message, accountPeerId: accountPeerId) ?? "")
        } else {
            return nil
        }
    case let poll as TelegramMediaPoll:
        return .poll(poll.text)
    case let dice as TelegramMediaDice:
        return .dice(dice.emoji)
    default:
        return nil
    }
}

public func stringForMediaKind(_ kind: MessageContentKind, strings: PresentationStrings) -> (String, Bool) {
    switch kind {
    case let .text(text):
        return (text, false)
    case .image:
        return (strings.Message_Photo, true)
    case .video:
        return (strings.Message_Video, true)
    case .videoMessage:
        return (strings.Message_VideoMessage, true)
    case .audioMessage:
        return (strings.Message_Audio, true)
    case let .sticker(text):
        if text.isEmpty {
            return (strings.Message_Sticker, true)
        } else {
            return (strings.Message_StickerText(text).0, true)
        }
    case .animation:
        return (strings.Message_Animation, true)
    case let .file(text):
        if text.isEmpty {
            return (strings.Message_File, true)
        } else {
            return (text, true)
        }
    case .contact:
        return (strings.Message_Contact, true)
    case let .game(text):
        return (text, true)
    case .location:
        return (strings.Message_Location, true)
    case .liveLocation:
        return (strings.Message_LiveLocation, true)
    case .expiredImage:
        return (strings.Message_ImageExpired, true)
    case .expiredVideo:
        return (strings.Message_VideoExpired, true)
    case let .poll(text):
        return ("📊 \(text)", false)
    case let .restricted(text):
        return (text, false)
    case let .dice(emoji):
        return (emoji, true)
    }
}

public func descriptionStringForMessage(contentSettings: ContentSettings, message: Message, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, accountPeerId: PeerId) -> (String, Bool) {
    if !message.text.isEmpty {
        return (message.text, false)
    }
    return stringForMediaKind(messageContentKind(contentSettings: contentSettings, message: message, strings: strings, nameDisplayOrder: nameDisplayOrder, accountPeerId: accountPeerId), strings: strings)
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
    return result
}
