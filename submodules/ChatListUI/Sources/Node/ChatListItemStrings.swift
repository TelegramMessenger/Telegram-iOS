import Foundation
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import LocalizedPeerData

private enum MessageGroupType {
    case photos
    case videos
    case generic
}

private func singleMessageType(message: Message) -> MessageGroupType {
    for media in message.media {
        if let _ = media as? TelegramMediaImage {
            return .photos
        } else if let file = media as? TelegramMediaFile {
            if file.isVideo && !file.isInstantVideo {
                return .videos
            }
        }
    }
    return .generic
}

private func messageGroupType(messages: [Message]) -> MessageGroupType {
    if messages.isEmpty {
        return .generic
    }
    let currentType = singleMessageType(message: messages[0])
    for i in 1 ..< messages.count {
        let nextType = singleMessageType(message: messages[i])
        if nextType != currentType {
            return .generic
        }
    }
    return currentType
}

public func chatListItemStrings(strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, messages: [Message], chatPeer: RenderedPeer, accountPeerId: PeerId, enableMediaEmoji: Bool = true, isPeerGroup: Bool = false) -> (peer: Peer?, hideAuthor: Bool, messageText: String) {
    let peer: Peer?
    
    let message = messages.last
    
    var hideAuthor = false
    var messageText: String
    if let message = message {
        if let messageMain = messageMainPeer(message) {
            peer = messageMain
        } else {
            peer = chatPeer.chatMainPeer
        }
        
        messageText = ""
        for message in messages {
            if !message.text.isEmpty {
                messageText = message.text
                break
            }
        }
        
        var textIsReady = false
        if messages.count > 1 {
            let groupType = messageGroupType(messages: messages)
            switch groupType {
            case .photos:
                if !messageText.isEmpty {
                    textIsReady = true
                } else {
                    messageText = strings.ChatList_MessagePhotos(Int32(messages.count))
                    textIsReady = true
                }
            case .videos:
                if !messageText.isEmpty {
                    textIsReady = true
                } else {
                    messageText = strings.ChatList_MessageVideos(Int32(messages.count))
                    textIsReady = true
                }
            case .generic:
                break
            }
        }
        
        if !textIsReady {
            for media in message.media {
                switch media {
                    case _ as TelegramMediaImage:
                        if message.text.isEmpty {
                            messageText = strings.Message_Photo
                        } else if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                            if enableMediaEmoji {
                                messageText = "🖼 \(messageText)"
                            }
                        }
                    case let fileMedia as TelegramMediaFile:
                        var processed = false
                        inner: for attribute in fileMedia.attributes {
                            switch attribute {
                                case .Animated:
                                    messageText = strings.Message_Animation
                                    processed = true
                                    break inner
                                case let .Audio(isVoice, _, title, performer, _):
                                    if !message.text.isEmpty {
                                        messageText = "🎤 \(messageText)"
                                        processed = true
                                    } else if isVoice {
                                        if message.text.isEmpty {
                                            messageText = strings.Message_Audio
                                        } else {
                                            messageText = "🎤 \(messageText)"
                                        }
                                        processed = true
                                        break inner
                                    } else {
                                        let descriptionString: String
                                        if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                                            descriptionString = title + " — " + performer
                                        } else if let title = title, !title.isEmpty {
                                            descriptionString = title
                                        } else if let performer = performer, !performer.isEmpty {
                                            descriptionString = performer
                                        } else if let fileName = fileMedia.fileName {
                                            descriptionString = fileName
                                        } else {
                                            descriptionString = strings.Message_Audio
                                        }
                                        messageText = descriptionString
                                        processed = true
                                        break inner
                                    }
                                case let .Sticker(displayText, _, _):
                                    if displayText.isEmpty {
                                        messageText = strings.Message_Sticker
                                        processed = true
                                        break inner
                                    } else {
                                        messageText = strings.Message_StickerText(displayText).0
                                        processed = true
                                        break inner
                                    }
                                case let .Video(_, _, flags):
                                    if flags.contains(.instantRoundVideo) {
                                        messageText = strings.Message_VideoMessage
                                        processed = true
                                        break inner
                                    } else {
                                        if message.text.isEmpty {
                                            messageText = strings.Message_Video
                                            processed = true
                                        } else if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                                            if enableMediaEmoji {
                                                if !fileMedia.isAnimated {
                                                    messageText = "📹 \(messageText)"
                                                }
                                            }
                                            processed = true
                                            break inner
                                        }
                                    }
                                default:
                                    break
                            }
                        }
                        if !processed {
                            if !message.text.isEmpty {
                                messageText = "📎 \(messageText)"
                            } else {
                                if fileMedia.isAnimatedSticker {
                                    messageText = strings.Message_Sticker
                                } else {
                                    if let fileName = fileMedia.fileName {
                                        messageText = fileName
                                    } else {
                                        messageText = strings.Message_File
                                    }
                                }
                            }
                        }
                    case let location as TelegramMediaMap:
                        if location.liveBroadcastingTimeout != nil {
                            messageText = strings.Message_LiveLocation
                        } else {
                            messageText = strings.Message_Location
                        }
                    case _ as TelegramMediaContact:
                        messageText = strings.Message_Contact
                    case let game as TelegramMediaGame:
                        messageText = "🎮 \(game.title)"
                    case let invoice as TelegramMediaInvoice:
                        messageText = invoice.title
                    case let action as TelegramMediaAction:
                        switch action.action {
                            case let .phoneCall(_, discardReason, _, isVideo):
                                hideAuthor = !isPeerGroup
                                let incoming = message.flags.contains(.Incoming)
                                if let discardReason = discardReason {
                                    switch discardReason {
                                        case .busy, .disconnect:
                                            if isVideo {
                                                messageText = strings.Notification_VideoCallCanceled
                                            } else {
                                                messageText = strings.Notification_CallCanceled
                                            }
                                        case .missed:
                                            if incoming {
                                                if isVideo {
                                                    messageText = strings.Notification_VideoCallMissed
                                                } else {
                                                    messageText = strings.Notification_CallMissed
                                                }
                                            } else {
                                                if isVideo {
                                                    messageText = strings.Notification_VideoCallCanceled
                                                } else {
                                                    messageText = strings.Notification_CallCanceled
                                                }
                                            }
                                        case .hangup:
                                            break
                                    }
                                }
                                
                                if messageText.isEmpty {
                                    if incoming {
                                        if isVideo {
                                            messageText = strings.Notification_VideoCallIncoming
                                        } else {
                                            messageText = strings.Notification_CallIncoming
                                        }
                                    } else {
                                        if isVideo {
                                            messageText = strings.Notification_VideoCallOutgoing
                                        } else {
                                            messageText = strings.Notification_CallOutgoing
                                        }
                                    }
                                }
                            default:
                                hideAuthor = true
                                if let text = plainServiceMessageString(strings: strings, nameDisplayOrder: nameDisplayOrder, message: message, accountPeerId: accountPeerId) {
                                    messageText = text
                                }
                        }
                    case _ as TelegramMediaExpiredContent:
                        if let text = plainServiceMessageString(strings: strings, nameDisplayOrder: nameDisplayOrder, message: message, accountPeerId: accountPeerId) {
                            messageText = text
                        }
                    case let poll as TelegramMediaPoll:
                        messageText = "📊 \(poll.text)"
                    case let dice as TelegramMediaDice:
                        messageText = dice.emoji
                    default:
                        break
                }
            }
        }
    } else {
        peer = chatPeer.chatMainPeer
        messageText = ""
        if chatPeer.peerId.namespace == Namespaces.Peer.SecretChat {
            if let secretChat = chatPeer.peers[chatPeer.peerId] as? TelegramSecretChat {
                switch secretChat.embeddedState {
                    case .active:
                        switch secretChat.role {
                            case .creator:
                                messageText = strings.DialogList_EncryptedChatStartedOutgoing(peer?.compactDisplayTitle ?? "").0
                            case .participant:
                                messageText = strings.DialogList_EncryptedChatStartedIncoming(peer?.compactDisplayTitle ?? "").0
                        }
                    case .terminated:
                        messageText = strings.DialogList_EncryptionRejected
                    case .handshake:
                        switch secretChat.role {
                            case .creator:
                                messageText = strings.DialogList_AwaitingEncryption(peer?.compactDisplayTitle ?? "").0
                            case .participant:
                                messageText = strings.DialogList_EncryptionProcessing
                        }
                }
            }
        }
    }
    
    return (peer, hideAuthor, messageText)
}
