import Foundation
import TelegramCore
import WidgetItems

public extension WidgetDataPeer.Message {
    init(accountPeerId: EnginePeer.Id, message: EngineMessage) {
        var content: WidgetDataPeer.Message.Content = .text
        for media in message.media {
            switch media {
            case _ as TelegramMediaImage:
                content = .image(WidgetDataPeer.Message.Content.Image())
            case let file as TelegramMediaFile:
                var fileName = "file"
                for attribute in file.attributes {
                    if case let .FileName(value) = attribute {
                        fileName = value
                        break
                    }
                }
                content = .file(WidgetDataPeer.Message.Content.File(name: fileName))
                for attribute in file.attributes {
                    switch attribute {
                    case let .Sticker(altText, _, _):
                        content = .sticker(WidgetDataPeer.Message.Content.Sticker(altText: altText))
                    case let .Video(duration, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            content = .videoMessage(WidgetDataPeer.Message.Content.VideoMessage(duration: Int32(duration)))
                        } else {
                            content = .video(WidgetDataPeer.Message.Content.Video())
                        }
                    case let .Audio(isVoice, duration, title, performer, _):
                        if isVoice {
                            content = .voiceMessage(WidgetDataPeer.Message.Content.VoiceMessage(duration: Int32(duration)))
                        } else {
                            content = .music(WidgetDataPeer.Message.Content.Music(artist: performer ?? "", title: title ?? "", duration: Int32(duration)))
                        }
                    default:
                        break
                    }
                }
            case let action as TelegramMediaAction:
                switch action.action {
                case let .phoneCall(_, _, _, isVideo):
                    content = .call(WidgetDataPeer.Message.Content.Call(isVideo: isVideo))
                default:
                    break
                }
            case _ as TelegramMediaMap:
                content = .mapLocation(WidgetDataPeer.Message.Content.MapLocation())
            default:
                break
            }
        }
        
        var author: Author?
        if let _ = message.peers[message.id.peerId] as? TelegramGroup {
            if let authorPeer = message.author {
                author = Author(isMe: authorPeer.id == accountPeerId, title: authorPeer.debugDisplayTitle)
            }
        } else if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
            if let authorPeer = message.author {
                author = Author(isMe: authorPeer.id == accountPeerId, title: authorPeer.debugDisplayTitle)
            }
        }
        
        self.init(author: author, text: message.text, content: content, timestamp: message.timestamp)
    }
}
