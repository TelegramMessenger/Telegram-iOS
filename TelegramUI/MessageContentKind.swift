import Foundation
import Postbox
import TelegramCore

private enum MessageContentKind {
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
}

private func messageContentKind(_ message: Message, strings: PresentationStrings, accountPeerId: PeerId) -> MessageContentKind {
    for media in message.media {
        switch media {
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
                return .file(fileName)
            case _ as TelegramMediaContact:
                return .contact
            case let game as TelegramMediaGame:
                return .game(game.title)
            case _ as TelegramMediaMap:
                return .location
            case _ as TelegramMediaAction:
                return .text(plainServiceMessageString(strings: strings, message: message, accountPeerId: accountPeerId) ?? "")
            default:
                break
        }
    }
    return .text(message.text)
}
 
func descriptionStringForMessage(_ message: Message, strings: PresentationStrings, accountPeerId: PeerId) -> String {
    switch messageContentKind(message, strings: strings, accountPeerId: accountPeerId) {
        case let .text(text):
            return text
        case .image:
            return strings.Message_Photo
        case .video:
            return strings.Message_Video
        case .videoMessage:
            return strings.Message_VideoMessage
        case .audioMessage:
            return strings.Message_Audio
        case let .sticker(text):
            if text.isEmpty {
                return strings.Message_Sticker
            } else {
                return "\(text) \(strings.Message_Sticker)"
            }
        case .animation:
            return strings.Message_Animation
        case let .file(text):
            if text.isEmpty {
                return strings.Message_File
            } else {
                return text
            }
        case .contact:
            return strings.Message_Contact
        case let .game(text):
            return text
        case .location:
            return strings.Message_Location
    }
}
