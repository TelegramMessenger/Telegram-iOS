import Foundation
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import LocalizedPeerData
import TextFormat

private enum MessageGroupType {
    case photos
    case videos
    case music
    case files
    case generic
}

private func singleMessageType(message: EngineMessage) -> MessageGroupType {
    for media in message.media {
        if let _ = media as? TelegramMediaImage {
            return .photos
        } else if let file = media as? TelegramMediaFile {
            if file.isMusic {
                return .music
            }
            if file.isVideo && !file.isInstantVideo {
                return .videos
            }
            return .files
        }
    }
    return .generic
}

private func singleExtendedMediaType(extendedMedia: TelegramExtendedMedia) -> MessageGroupType {
    switch extendedMedia {
    case let .preview(_, _, videoDuration):
        if let _ = videoDuration {
            return .videos
        } else {
            return .photos
        }
    case let .full(fullMedia):
        if let _ = fullMedia as? TelegramMediaImage {
            return .photos
        } else if let file = fullMedia as? TelegramMediaFile, file.isVideo {
            return .videos
        }
    }
    return .generic
}

private func messageGroupType(messages: [EngineMessage]) -> MessageGroupType {
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

private func paidContentGroupType(paidContent: TelegramMediaPaidContent) -> MessageGroupType {
    if paidContent.extendedMedia.isEmpty {
        return .generic
    }
    let currentType = singleExtendedMediaType(extendedMedia: paidContent.extendedMedia[0])
    for i in 1 ..< paidContent.extendedMedia.count {
        let nextType = singleExtendedMediaType(extendedMedia: paidContent.extendedMedia[i])
        if nextType != currentType {
            return .generic
        }
    }
    return currentType
}

public func chatListItemStrings(strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, contentSettings: ContentSettings, messages: [EngineMessage], chatPeer: EngineRenderedPeer, accountPeerId: EnginePeer.Id, enableMediaEmoji: Bool = true, isPeerGroup: Bool = false) -> (peer: EnginePeer?, hideAuthor: Bool, messageText: String, spoilers: [NSRange]?, customEmojiRanges: [(NSRange, ChatTextInputTextCustomEmojiAttribute)]?) {
    let peer: EnginePeer?
    
    let message = messages.last
    
    if let restrictionReason = message?._asMessage().restrictionReason(platform: "ios", contentSettings: contentSettings) {
        return (nil, false, restrictionReason, nil, nil)
    }
    if let restrictionReason = chatPeer.chatMainPeer?.restrictionText(platform: "ios", contentSettings: contentSettings) {
        return (nil, false, restrictionReason, nil, nil)
    }
    
    var hideAuthor = false
    var messageText: String
    var spoilers: [NSRange]?
    var customEmojiRanges: [(NSRange, ChatTextInputTextCustomEmojiAttribute)]?
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
        
        
        let paidContent = message.media.first(where: { $0 is TelegramMediaPaidContent }) as? TelegramMediaPaidContent
        
        var textIsReady = false
        if messages.count > 1 || (paidContent != nil && (paidContent?.extendedMedia.count ?? 0) > 1) {
            let groupType: MessageGroupType
            let count: Int32
            if let paidContent {
                groupType = paidContentGroupType(paidContent: paidContent)
                count = Int32(paidContent.extendedMedia.count)
            } else {
                groupType = messageGroupType(messages: messages)
                count = Int32(messages.count)
            }
            switch groupType {
            case .photos:
                if !messageText.isEmpty {
                    textIsReady = true
                } else {
                    messageText = strings.ChatList_MessagePhotos(count)
                    textIsReady = true
                }
            case .videos:
                if !messageText.isEmpty {
                    textIsReady = true
                } else {
                    messageText = strings.ChatList_MessageVideos(count)
                    textIsReady = true
                }
            case .music:
                if !messageText.isEmpty {
                    textIsReady = true
                } else {
                    messageText = strings.ChatList_MessageMusic(count)
                    textIsReady = true
                }
            case .files:
                if !messageText.isEmpty {
                    textIsReady = true
                } else {
                    messageText = strings.ChatList_MessageFiles(count)
                    textIsReady = true
                }
            case .generic:
                var messageTypes = Set<MessageGroupType>()
                if let paidContent {
                    for extendedMedia in paidContent.extendedMedia {
                        messageTypes.insert(singleExtendedMediaType(extendedMedia: extendedMedia))
                    }
                } else {
                    for message in messages {
                        messageTypes.insert(singleMessageType(message: message))
                    }
                }
                if messageTypes.count == 2 && messageTypes.contains(.photos) && messageTypes.contains(.videos) {
                    if !messageText.isEmpty {
                        textIsReady = true
                    }
                }
            }
        }
        
        if !textIsReady {
            for media in message.media {
                switch media {
                    case let paidContent as TelegramMediaPaidContent:
                        for extendedMedia in paidContent.extendedMedia {
                            let type = singleExtendedMediaType(extendedMedia: extendedMedia)
                            switch type {
                            case .photos:
                                if message.text.isEmpty {
                                    messageText = strings.Message_Photo
                                } else if enableMediaEmoji {
                                    messageText = "🖼 \(messageText)"
                                }
                            case .videos:
                                if message.text.isEmpty {
                                    messageText = strings.Message_Video
                                } else if enableMediaEmoji {
                                    messageText = "📹 \(messageText)"
                                }
                            default:
                                break
                            }
                        }
                    case _ as TelegramMediaImage:
                        if message.text.isEmpty {
                            messageText = strings.Message_Photo
                        } else if enableMediaEmoji {
                            messageText = "🖼 \(messageText)"
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
                                        messageText = strings.Message_StickerText(displayText).string
                                        processed = true
                                        break inner
                                    }
                                case let .Video(_, _, flags, _, _, _):
                                    if flags.contains(.instantRoundVideo) {
                                        messageText = strings.Message_VideoMessage
                                        processed = true
                                        break inner
                                    } else {
                                        if message.text.isEmpty {
                                            messageText = strings.Message_Video
                                            processed = true
                                        } else {
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
                            case let .conferenceCall(conferenceCall):
                                let incoming = message.flags.contains(.Incoming)
                                
                                let missedTimeout: Int32 = 30
                                let currentTime = Int32(Date().timeIntervalSince1970)
                                
                                if conferenceCall.flags.contains(.isMissed) {
                                    messageText = strings.Chat_CallMessage_DeclinedGroupCall
                                } else if conferenceCall.duration == nil && message.timestamp < currentTime - missedTimeout {
                                    messageText = strings.Chat_CallMessage_MissedGroupCall
                                } else {
                                    if incoming {
                                        messageText = strings.Chat_CallMessage_IncomingGroupCall
                                    } else {
                                        messageText = strings.Chat_CallMessage_OutgoingGroupCall
                                    }
                                }
                            case let .phoneCall(_, discardReason, _, isVideo):
                                hideAuthor = !isPeerGroup
                                let incoming = message.flags.contains(.Incoming)
                                if let discardReason = discardReason {
                                    switch discardReason {
                                        case .disconnect:
                                            if isVideo {
                                                messageText = strings.Notification_VideoCallCanceled
                                            } else {
                                                messageText = strings.Notification_CallCanceled
                                            }
                                        case .missed, .busy:
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
                                switch action.action {
                                case .topicCreated, .topicEdited:
                                    hideAuthor = false
                                default:
                                    hideAuthor = true
                                }
                                if let (text, textSpoilers, customEmojiRangesValue) = plainServiceMessageString(strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: true, forForumOverview: false) {
                                    messageText = text
                                    spoilers = textSpoilers
                                    customEmojiRanges = customEmojiRangesValue
                                }
                        }
                    case _ as TelegramMediaExpiredContent:
                        if let (text, _, _) = plainServiceMessageString(strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: true, forForumOverview: false) {
                            messageText = text
                        }
                    case let poll as TelegramMediaPoll:
                        let pollPrefix = "📊 "
                        let entityOffset = (pollPrefix as NSString).length
                        messageText = "\(pollPrefix)\(poll.text)"
                        for entity in poll.textEntities {
                            if case let .CustomEmoji(_, fileId) = entity.type {
                                if customEmojiRanges == nil {
                                    customEmojiRanges = []
                                }
                                let range = NSRange(location: entityOffset + entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: message.associatedMedia[EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile)
                                customEmojiRanges?.append((range, attribute))
                            }
                        }
                    case let dice as TelegramMediaDice:
                        messageText = dice.emoji
                    case let story as TelegramMediaStory:
                        if story.isMention, let peer {
                            if message.flags.contains(.Incoming) {
                                messageText = strings.Conversation_StoryMentionTextIncoming(peer.compactDisplayTitle).string
                            } else {
                                messageText = strings.Conversation_StoryMentionTextOutgoing(peer.compactDisplayTitle).string
                            }
                        } else {
                            messageText = strings.Notification_Story
                        }
                    case _ as TelegramMediaGiveaway:
                        if let forwardInfo = message.forwardInfo, let author = forwardInfo.author {
                            messageText = strings.Message_GiveawayStartedOther(EnginePeer(author).compactDisplayTitle).string
                        } else {
                            if let author = message.author, case let .channel(channel) = author, case .group = channel.info {
                                messageText = strings.Message_GiveawayStartedGroup
                            } else {
                                messageText = strings.Message_GiveawayStarted
                            }
                        }
                    case let results as TelegramMediaGiveawayResults:
                        if results.winnersCount == 0 {
                            messageText = strings.Message_GiveawayEndedNoWinners
                        } else {
                            messageText = strings.Message_GiveawayEndedWinners(results.winnersCount)
                        }
                    case let webpage as TelegramMediaWebpage:
                        if messageText.isEmpty, case let .Loaded(content) = webpage.content {
                            messageText = content.displayUrl
                        }
                    case let todo as TelegramMediaTodo:
                        let pollPrefix = "☑️ "
                        let entityOffset = (pollPrefix as NSString).length
                        messageText = "\(pollPrefix)\(todo.text)"
                        for entity in todo.textEntities {
                            if case let .CustomEmoji(_, fileId) = entity.type {
                                if customEmojiRanges == nil {
                                    customEmojiRanges = []
                                }
                                let range = NSRange(location: entityOffset + entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: message.associatedMedia[EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile)
                                customEmojiRanges?.append((range, attribute))
                            }
                        }
                    default:
                        break
                }
            }
        }
    } else {
        peer = chatPeer.chatMainPeer
        messageText = ""
        if chatPeer.peerId.namespace == Namespaces.Peer.SecretChat {
            if case let .secretChat(secretChat) = chatPeer.peers[chatPeer.peerId] {
                switch secretChat.embeddedState {
                    case .active:
                        switch secretChat.role {
                            case .creator:
                                messageText = strings.DialogList_EncryptedChatStartedOutgoing(peer?.compactDisplayTitle ?? "").string
                            case .participant:
                                messageText = strings.DialogList_EncryptedChatStartedIncoming(peer?.compactDisplayTitle ?? "").string
                        }
                    case .terminated:
                        messageText = strings.DialogList_EncryptionRejected
                    case .handshake:
                        switch secretChat.role {
                            case .creator:
                                messageText = strings.DialogList_AwaitingEncryption(peer?.compactDisplayTitle ?? "").string
                            case .participant:
                                messageText = strings.DialogList_EncryptionProcessing
                        }
                }
            }
        }
    }
    
    return (peer, hideAuthor, messageText, spoilers, customEmojiRanges)
}
