import Foundation
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalizedPeerData
import Display
import Markdown

private let titleFont = Font.regular(13.0)
private let titleBoldFont = Font.bold(13.0)

private func spoilerAttributes(primaryTextColor: UIColor) -> MarkdownAttributeSet {
    return MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [TelegramTextAttributes.Spoiler: true])
}

private func customEmojiAttributes(primaryTextColor: UIColor, emoji: ChatTextInputTextCustomEmojiAttribute) -> MarkdownAttributeSet {
    return MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: emoji])
}

private func peerMentionAttributes(primaryTextColor: UIColor, peerId: EnginePeer.Id) -> MarkdownAttributeSet {
    return MarkdownAttributeSet(font: titleBoldFont, textColor: primaryTextColor, additionalAttributes: [TelegramTextAttributes.PeerMention: TelegramPeerMention(peerId: peerId, mention: "")])
}

private func peerMentionsAttributes(primaryTextColor: UIColor, peerIds: [(Int, EnginePeer.Id?)]) -> [Int: MarkdownAttributeSet] {
    var result: [Int: MarkdownAttributeSet] = [:]
    for (index, peerId) in peerIds {
        if let peerId = peerId {
            result[index] = peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: peerId)
        }
    }
    return result
}

public func plainServiceMessageString(strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: EngineMessage, accountPeerId: EnginePeer.Id, forChatList: Bool, forForumOverview: Bool, forAdditionalServiceMessage: Bool = false) -> (text: String, spoilerRanges: [NSRange], customEmojiRanges: [(NSRange, ChatTextInputTextCustomEmojiAttribute)])? {
    if let attributedString = universalServiceMessageString(presentationData: nil, strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: forChatList, forForumOverview: forForumOverview, forAdditionalServiceMessage: forAdditionalServiceMessage) {
        var ranges: [NSRange] = []
        var customEmojiRanges: [(NSRange, ChatTextInputTextCustomEmojiAttribute)] = []
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: [], using: { attributes, range, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] {
                ranges.append(range)
            } else if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                customEmojiRanges.append((range, value))
            }
        })
        return (attributedString.string, ranges, customEmojiRanges)
    } else {
        return nil
    }
}

private func peerDisplayTitles(_ peerIds: [PeerId], _ dict: SimpleDictionary<PeerId, Peer>, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) -> String {
    var peers: [Peer] = []
    for id in peerIds {
        if let peer = dict[id] {
            peers.append(peer)
        }
    }
    return peerDisplayTitles(peers, strings: strings, nameDisplayOrder: nameDisplayOrder)
}

private func peerDisplayTitles(_ peers: [Peer], strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) -> String {
    if peers.count == 0 {
        return ""
    } else {
        var string = ""
        var first = true
        for peer in peers {
            if first {
                first = false
            } else {
                string.append(", ")
            }
            string.append(EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder))
        }
        return string
    }
}

public func universalServiceMessageString(presentationData: (PresentationTheme, TelegramWallpaper)?, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: EngineMessage, messageCount: Int? = nil, accountPeerId: EnginePeer.Id, forChatList: Bool, forForumOverview: Bool, forAdditionalServiceMessage: Bool = false) -> NSAttributedString? {
    var attributedString: NSAttributedString?
    
    let primaryTextColor: UIColor
    if let (theme, wallpaper) = presentationData {
        primaryTextColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper).primaryText
    } else {
        primaryTextColor = .black
    }
    
    let bodyAttributes = MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [:])
    let boldAttributes = MarkdownAttributeSet(font: titleBoldFont, textColor: primaryTextColor, additionalAttributes: [:])
    
    if !forAdditionalServiceMessage {
        for attribute in message.attributes {
            if let attribute = attribute as? PaidStarsMessageAttribute {
                let messageCount = Int32(messageCount ?? 1)
                let price = strings.Notification_PaidMessage_Stars(Int32(attribute.stars.value) * messageCount)
                if message.author?.id == accountPeerId {
                    if messageCount > 1 {
                        let messagesString = strings.Notification_PaidMessage_Messages(messageCount)
                        return addAttributesToStringWithRanges(strings.Notification_PaidMessageYouMany(price, messagesString)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes, 1: boldAttributes])
                    } else {
                        return addAttributesToStringWithRanges(strings.Notification_PaidMessageYou(price)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    }
                } else {
                    let compactAuthorName = message.author?.compactDisplayTitle ?? ""
                    var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                    attributes[1] = boldAttributes
                    if messageCount > 1 {
                        let messagesString = strings.Notification_PaidMessage_Messages(messageCount)
                        return addAttributesToStringWithRanges(strings.Notification_PaidMessageMany(compactAuthorName, price, messagesString)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                    } else {
                        return addAttributesToStringWithRanges(strings.Notification_PaidMessage(compactAuthorName, price)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                    }
                }
            }
        }
    }
    
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            let authorName = message.author?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""
            let compactAuthorName = message.author?.compactDisplayTitle ?? ""
            
            var isChannel = false
            var isMonoforum = false
            if message.id.peerId.namespace == Namespaces.Peer.CloudChannel, let peer = message.peers[message.id.peerId] as? TelegramChannel {
                if case .broadcast = peer.info {
                    isChannel = true
                }
                isMonoforum = peer.isMonoForum
            }
            
            switch action.action {
            case let .groupCreated(title):
                if isChannel {
                    attributedString = NSAttributedString(string: strings.Notification_CreatedChannel, font: titleFont, textColor: primaryTextColor)
                } else {
                    if forChatList {
                        if isMonoforum {
                            attributedString = NSAttributedString(string: strings.ChatList_MonoforumEmptyText, font: titleFont, textColor: primaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Notification_CreatedGroup, font: titleFont, textColor: primaryTextColor)
                        }
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_CreatedChatWithTitle(authorName, title)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                }
            case let .addedMembers(peerIds):
                if let peerId = peerIds.first, peerId == message.author?.id {
                    if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChannel(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChat(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                    }
                } else {
                    var attributePeerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                    let resultTitleString: PresentationStrings.FormattedString
                    if peerIds.count == 1 {
                        attributePeerIds.append((1, peerIds.first))
                        resultTitleString = strings.Notification_Invited(authorName, peerDisplayTitles(peerIds, message.peers, strings: strings, nameDisplayOrder: nameDisplayOrder))
                    } else {
                        resultTitleString = strings.Notification_InvitedMultiple(authorName, peerDisplayTitles(peerIds, message.peers, strings: strings, nameDisplayOrder: nameDisplayOrder))
                    }
                    
                    attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                }
            case let .removedMembers(peerIds):
                if peerIds.first == message.author?.id {
                    if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChannel(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChat(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                } else {
                    var attributePeerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                    if peerIds.count == 1 {
                        attributePeerIds.append((1, peerIds.first))
                    }
                    attributedString = addAttributesToStringWithRanges(strings.Notification_Kicked(authorName, peerDisplayTitles(peerIds, message.peers, strings: strings, nameDisplayOrder: nameDisplayOrder))._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                }
            case let .photoUpdated(image):
                if authorName.isEmpty || isChannel {
                    if isChannel {
                        if let image = image {
                            if !image.videoRepresentations.isEmpty {
                                attributedString = NSAttributedString(string: strings.Channel_MessageVideoUpdated, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = NSAttributedString(string: strings.Channel_MessagePhotoUpdated, font: titleFont, textColor: primaryTextColor)
                            }
                        } else {
                            attributedString = NSAttributedString(string: strings.Channel_MessagePhotoRemoved, font: titleFont, textColor: primaryTextColor)
                        }
                    } else {
                        if let image = image {
                            if !image.videoRepresentations.isEmpty {
                                attributedString = NSAttributedString(string: strings.Group_MessageVideoUpdated, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = NSAttributedString(string: strings.Group_MessagePhotoUpdated, font: titleFont, textColor: primaryTextColor)
                            }
                        } else {
                            attributedString = NSAttributedString(string: strings.Group_MessagePhotoRemoved, font: titleFont, textColor: primaryTextColor)
                        }
                    }
                } else {
                    if let image = image {
                        if !image.videoRepresentations.isEmpty {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupVideo(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        } else {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupPhoto(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        }
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_RemovedGroupPhoto(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                }
            case let .titleUpdated(title):
                if authorName.isEmpty || isChannel {
                    attributedString = NSAttributedString(string: strings.Channel_MessageTitleUpdated(title).string, font: titleFont, textColor: primaryTextColor)
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupName(authorName, title)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                }
            case .pinnedMessageUpdated:
                enum PinnnedMediaType {
                    case text(String, [MessageTextEntity])
                    case game
                    case photo
                    case video
                    case round
                    case audio
                    case file
                    case gif
                    case sticker
                    case location
                    case contact
                    case poll(TelegramMediaPollKind)
                    case deleted
                }
                
                var pinnedMessage: EngineMessage?
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        pinnedMessage = EngineMessage(message)
                    }
                }
                
                var type: PinnnedMediaType
                if let pinnedMessage = pinnedMessage?._asMessage() {
                    let entities = (pinnedMessage.textEntitiesAttribute?.entities ?? []).filter { entity in
                        switch entity.type {
                        case .Spoiler, .CustomEmoji:
                            return true
                        default:
                            return false
                        }
                    }
                    type = .text(pinnedMessage.text, entities)
                    inner: for media in pinnedMessage.media {
                        if media is TelegramMediaGame {
                            type = .game
                            break inner
                        }
                        if let _ = media as? TelegramMediaImage {
                            type = .photo
                        } else if let file = media as? TelegramMediaFile {
                            type = .file
                            if file.isAnimated {
                                type = .gif
                            } else {
                                for attribute in file.attributes {
                                    switch attribute {
                                    case let .Video(_, _, flags, _, _, _):
                                        if flags.contains(.instantRoundVideo) {
                                            type = .round
                                        } else {
                                            type = .video
                                        }
                                    case let .Audio(isVoice, _, _, _, _):
                                        if isVoice {
                                            type = .audio
                                        } else {
                                            type = .file
                                        }
                                        break inner
                                    case .Sticker:
                                        type = .sticker
                                        break inner
                                    case .Animated:
                                        break
                                    default:
                                        break
                                    }
                                }
                            }
                        } else if let _ = media as? TelegramMediaMap {
                            type = .location
                        } else if let _ = media as? TelegramMediaContact {
                            type = .contact
                        } else if let poll = media as? TelegramMediaPoll {
                            type = .poll(poll.kind)
                        }
                    }
                } else {
                    type = .deleted
                }
                
                switch type {
                case let .text(text, entities):
                    var clippedText = text
                    if !entities.isEmpty {
                        clippedText = trimToLineCount(clippedText, lineCount: 1)
                    } else {
                        clippedText = clippedText.replacingOccurrences(of: "\n", with: " ")
                    }
                    if clippedText.count > 14 {
                        clippedText = "\(clippedText[...clippedText.index(clippedText.startIndex, offsetBy: 14)])..."
                    }
                    let textWithRanges: PresentationStrings.FormattedString
                    if clippedText.isEmpty {
                        textWithRanges = strings.Message_PinnedGenericMessage(authorName)
                    } else {
                        textWithRanges = strings.Notification_PinnedTextMessage(authorName, clippedText)
                    }
                    
                    let string = textWithRanges._tuple.0
                    let stringLength = (string as NSString).length
                    let messageLength = (clippedText as NSString).length
                    var ranges = textWithRanges._tuple.1
                    let entityOffset = ranges.first(where: { $0.0 == 1 })?.1.location ?? 0
                    var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                    for entity in entities {
                        if entity.range.startIndex >= messageLength {
                            continue
                        }
                        let location = entityOffset + entity.range.startIndex
                        let length = max(0, min(entity.range.count, stringLength - location - 1))
                        if length > 0 {
                            switch entity.type {
                            case .Spoiler:
                                let index = ranges.count
                                ranges.append((ranges.count, NSRange(location: location, length: length)))
                                attributes[index] = spoilerAttributes(primaryTextColor: primaryTextColor)
                            case let .CustomEmoji(_, fileId):
                                let index = ranges.count
                                ranges.append((ranges.count, NSRange(location: location, length: length)))
                                attributes[index] = customEmojiAttributes(primaryTextColor: primaryTextColor, emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile))
                            default:
                                break
                            }
                        }
                    }
                    attributedString = addAttributesToStringWithRanges((string, ranges), body: bodyAttributes, argumentAttributes: attributes)
                case .game:
                    attributedString = addAttributesToStringWithRanges(strings.Message_AuthorPinnedGame(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .photo:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedPhotoMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .video:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedVideoMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .round:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedRoundMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .audio:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAudioMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .file:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedDocumentMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .gif:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAnimationMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .sticker:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedStickerMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .location:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedLocationMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .contact:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedContactMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case let .poll(kind):
                    switch kind {
                    case .poll:
                        attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedPollMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    case .quiz:
                        attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedQuizMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                case .deleted:
                    attributedString = addAttributesToStringWithRanges(strings.Message_PinnedGenericMessage(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                }
            case .joinedByLink:
                if message.author?.id == accountPeerId {
                    attributedString = NSAttributedString(string: strings.Notification_JoinedGroupByLinkYou, font: titleFont, textColor: primaryTextColor)
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedGroupByLink(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                }
            case .joinedByRequest:
                if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                    attributedString = NSAttributedString(string: strings.Notification_JoinedChannelByRequestYou, font: titleFont, textColor: primaryTextColor)
                } else if message.author?.id == accountPeerId {
                    attributedString = NSAttributedString(string: strings.Notification_JoinedGroupByRequestYou, font: titleFont, textColor: primaryTextColor)
                } else if let peerId = message.author?.id {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedGroupByRequest(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                } else {
                    attributedString = NSAttributedString(string: "", font: titleFont, textColor: primaryTextColor)
                }
            case .channelMigratedFromGroup, .groupMigratedToChannel:
                attributedString = NSAttributedString(string: "", font: titleFont, textColor: primaryTextColor)
            case let .messageAutoremoveTimeoutUpdated(timeout, autoSourcePeerId):
                let authorString: String
                if let author = messageMainPeer(message) {
                    authorString = author.compactDisplayTitle
                } else {
                    authorString = ""
                }
                
                let messagePeer = message.peers[message.id.peerId]
                
                if timeout > 0 {
                    let timeValue = timeIntervalString(strings: strings, value: timeout, preferLowerValue: false)
                    
                    if let user = messagePeer as? TelegramUser {
                        if let autoSourcePeerId = autoSourcePeerId {
                            if autoSourcePeerId == accountPeerId {
                                attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetUserGlobalYou(timeValue).string, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = addAttributesToStringWithRanges(strings.Conversation_AutoremoveTimerSetUserGlobal(authorString, timeValue)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, user.id)]))
                            }
                        } else if message.author?.id == accountPeerId {
                            attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetUserYou(timeValue).string, font: titleFont, textColor: primaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetUser(authorString, timeValue).string, font: titleFont, textColor: primaryTextColor)
                        }
                    } else if let _ = messagePeer as? TelegramGroup {
                        if message.author?.id == accountPeerId {
                            attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetUserYou(timeValue).string, font: titleFont, textColor: primaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetGroup(timeValue).string, font: titleFont, textColor: primaryTextColor)
                        }
                    } else if let channel = messagePeer as? TelegramChannel {
                        if message.author?.id == accountPeerId {
                            attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetUserYou(timeValue).string, font: titleFont, textColor: primaryTextColor)
                        } else {
                            if case .group = channel.info {
                                attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetGroup(timeValue).string, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = NSAttributedString(string: strings.Conversation_AutoremoveTimerSetChannel(timeValue).string, font: titleFont, textColor: primaryTextColor)
                            }
                        }
                    } else {
                        if message.author?.id == accountPeerId {
                            attributedString = NSAttributedString(string: strings.Notification_MessageLifetimeChangedOutgoing(timeValue).string, font: titleFont, textColor: primaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Notification_MessageLifetimeChanged(authorString, timeValue).string, font: titleFont, textColor: primaryTextColor)
                        }
                    }
                } else {
                    let string: String
                    if let _ = messagePeer as? TelegramUser {
                        if message.author?.id == accountPeerId {
                            string = strings.Conversation_AutoremoveTimerRemovedUserYou
                        } else {
                            string = strings.Conversation_AutoremoveTimerRemovedUser(authorString).string
                        }
                    } else if let _ = messagePeer as? TelegramGroup {
                        if message.author?.id == accountPeerId {
                            string = strings.Conversation_AutoremoveTimerRemovedUserYou
                        } else {
                            string = strings.Conversation_AutoremoveTimerRemovedGroup
                        }
                    } else if let channel = messagePeer as? TelegramChannel {
                        if case .group = channel.info {
                            if message.author?.id == accountPeerId {
                                string = strings.Conversation_AutoremoveTimerRemovedUserYou
                            } else {
                                string = strings.Conversation_AutoremoveTimerRemovedGroup
                            }
                        } else {
                            string = strings.Conversation_AutoremoveTimerRemovedChannel
                        }
                    } else {
                        if message.author?.id == accountPeerId {
                            string = strings.Notification_MessageLifetimeRemovedOutgoing
                        } else {
                            string = strings.Notification_MessageLifetimeRemoved(authorString).string
                        }
                    }
                    attributedString = NSAttributedString(string: string, font: titleFont, textColor: primaryTextColor)
                }
            case .historyCleared:
                break
            case .historyScreenshot:
                let text: String
                if message._asMessage().effectivelyIncoming(accountPeerId) {
                    text = strings.Notification_SecretChatMessageScreenshot(message.author?.compactDisplayTitle ?? "").string
                } else {
                    text = strings.Notification_SecretChatMessageScreenshotSelf
                }
                attributedString = NSAttributedString(string: text, font: titleFont, textColor: primaryTextColor)
            case let .gameScore(gameId: _, score):
                var gameTitle: String?
                inner: for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        for media in message.media {
                            if let game = media as? TelegramMediaGame {
                                gameTitle = game.title
                                break inner
                            }
                        }
                    }
                }
                
                var baseString: String
                if message.author?.id == accountPeerId {
                    if let _ = gameTitle {
                        baseString = strings.ServiceMessage_GameScoreSelfExtended(score)
                    } else {
                        baseString = strings.ServiceMessage_GameScoreSelfSimple(score)
                    }
                } else {
                    if let _ = gameTitle {
                        baseString = strings.ServiceMessage_GameScoreExtended(score)
                    } else {
                        baseString = strings.ServiceMessage_GameScoreSimple(score)
                    }
                }
                let baseStringValue = baseString as NSString
                var ranges: [(Int, NSRange)] = []
                if baseStringValue.range(of: "{name}").location != NSNotFound {
                    ranges.append((0, baseStringValue.range(of: "{name}")))
                }
                if baseStringValue.range(of: "{game}").location != NSNotFound {
                    ranges.append((1, baseStringValue.range(of: "{game}")))
                }
                ranges.sort(by: { $0.1.location < $1.1.location })
                
                var argumentAttributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                argumentAttributes[1] = MarkdownAttributeSet(font: titleBoldFont, textColor: primaryTextColor, additionalAttributes: [:])
                attributedString = addAttributesToStringWithRanges(formatWithArgumentRanges(baseString, ranges, [authorName, gameTitle ?? ""]), body: bodyAttributes, argumentAttributes: argumentAttributes)
            case let .paymentSent(currency, totalAmount, _, isRecurringInit, isRecurringUsed):
                var invoiceMessage: EngineMessage?
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        invoiceMessage = EngineMessage(message)
                    }
                }
                
                var invoiceTitle: String?
                if let invoiceMessage = invoiceMessage {
                    for media in invoiceMessage.media {
                        if let invoice = media as? TelegramMediaInvoice {
                            invoiceTitle = invoice.title
                        }
                    }
                }
                
                let patternString: String
                if isRecurringInit {
                    if let _ = invoiceTitle {
                        patternString = strings.Notification_PaymentSentRecurringInit
                    } else {
                        patternString = strings.Notification_PaymentSentRecurringInitNoTitle
                    }
                } else if isRecurringUsed {
                    if let _ = invoiceTitle {
                        patternString = strings.Notification_PaymentSentRecurringUsed
                    } else {
                        patternString = strings.Notification_PaymentSentRecurringUsedNoTitle
                    }
                } else {
                    if let _ = invoiceTitle {
                        patternString = strings.Notification_PaymentSent
                    } else {
                        patternString = strings.Notification_PaymentSentNoTitle
                    }
                }
                
                let botString: String
                if let peer = messageMainPeer(message) {
                    botString = peer.compactDisplayTitle
                } else {
                    botString = ""
                }
                let mutableString = NSMutableAttributedString()
                mutableString.append(NSAttributedString(string: patternString, font: titleFont, textColor: primaryTextColor))
                
                var range = NSRange(location: NSNotFound, length: 0)
                
                range = (mutableString.string as NSString).range(of: "{amount}")
                if range.location != NSNotFound {
                    if currency == "XTR" {
                        let amountAttributedString = NSMutableAttributedString(string: "#\(totalAmount)", font: titleBoldFont, textColor: primaryTextColor)
                        if let range = amountAttributedString.string.range(of: "#") {
                            amountAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: true)), range: NSRange(range, in: amountAttributedString.string))
                            amountAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: amountAttributedString.string))
                        }
                        mutableString.replaceCharacters(in: range, with: amountAttributedString)
                    } else {
                        mutableString.replaceCharacters(in: range, with: NSAttributedString(string: formatCurrencyAmount(totalAmount, currency: currency), font: titleBoldFont, textColor: primaryTextColor))
                    }
                }
                range = (mutableString.string as NSString).range(of: "{name}")
                if range.location != NSNotFound {
                    mutableString.replaceCharacters(in: range, with: NSAttributedString(string: botString, font: titleBoldFont, textColor: primaryTextColor))
                }
                if let invoiceTitle = invoiceTitle {
                    range = (mutableString.string as NSString).range(of: "{title}")
                    if range.location != NSNotFound {
                        mutableString.replaceCharacters(in: range, with: NSAttributedString(string: invoiceTitle, font: titleFont, textColor: primaryTextColor))
                    }
                }
                attributedString = mutableString
            case let .phoneCall(_, discardReason, _, _):
                var titleString: String
                let incoming: Bool
                if message.flags.contains(.Incoming) {
                    titleString = strings.Notification_CallIncoming
                    incoming = true
                } else {
                    titleString = strings.Notification_CallOutgoing
                    incoming = false
                }
                if let discardReason = discardReason {
                    switch discardReason {
                    case .disconnect:
                        titleString = strings.Notification_CallCanceled
                    case .missed, .busy:
                        titleString = incoming ? strings.Notification_CallMissed : strings.Notification_CallCanceled
                    case .hangup:
                        break
                    }
                }
                attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
            case let .conferenceCall(conferenceCall):
                var titleString: String
                let incoming = message.flags.contains(.Incoming)
                
                let missedTimeout: Int32 = 30
                let currentTime = Int32(Date().timeIntervalSince1970)
                
                if conferenceCall.flags.contains(.isMissed) {
                    titleString = strings.Chat_CallMessage_DeclinedGroupCall
                } else if conferenceCall.duration == nil && message.timestamp < currentTime - missedTimeout {
                    titleString = strings.Chat_CallMessage_MissedGroupCall
                } else {
                    if incoming {
                        titleString = strings.Chat_CallMessage_IncomingGroupCall
                    } else {
                        titleString = strings.Chat_CallMessage_OutgoingGroupCall
                    }
                }

                attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
            case let .groupPhoneCall(_, _, scheduleDate, duration):
                if let scheduleDate = scheduleDate {
                    if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                        let titleString: PresentationStrings.FormattedString
                        if case let .channel(channel) = message.author, case .broadcast = channel.info {
                            titleString = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: scheduleDate, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(dateFormatString: { strings.Notification_LiveStreamScheduled($0) }, tomorrowFormatString: { strings.Notification_LiveStreamScheduledTomorrow($0) }, todayFormatString: { strings.Notification_LiveStreamScheduledToday($0) }))
                        } else {
                            titleString = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: scheduleDate, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(dateFormatString: { strings.Notification_VoiceChatScheduledChannel($0) }, tomorrowFormatString: { strings.Notification_VoiceChatScheduledTomorrowChannel($0) }, todayFormatString: { strings.Notification_VoiceChatScheduledTodayChannel($0) }))
                        }
                        attributedString = NSAttributedString(string: titleString.string, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let titleString = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: scheduleDate, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(dateFormatString: { strings.Notification_VoiceChatScheduled(authorName, $0) }, tomorrowFormatString: { strings.Notification_VoiceChatScheduledTomorrow(authorName, $0) }, todayFormatString: { strings.Notification_VoiceChatScheduledToday(authorName, $0) }))
                        let attributePeerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                        attributedString = addAttributesToStringWithRanges(titleString._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                } else if let duration = duration {
                    if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                        let titleString: String
                        if case let .channel(channel) = message.author, case .broadcast = channel.info {
                            titleString = strings.Notification_LiveStreamEnded(callDurationString(strings: strings, value: duration)).string
                        } else {
                            titleString = strings.Notification_VoiceChatEnded(callDurationString(strings: strings, value: duration)).string
                        }
                        attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let attributePeerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                        let titleString = strings.Notification_VoiceChatEndedGroup(authorName, callDurationString(strings: strings, value: duration))
                        attributedString = addAttributesToStringWithRanges(titleString._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                } else {
                    if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                        let titleString: String
                        if case let .channel(channel) = message.author, case .broadcast = channel.info {
                            titleString = strings.Notification_LiveStreamStarted
                        } else {
                            titleString = strings.Notification_VoiceChatStartedChannel
                        }
                        attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let attributePeerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                        let titleString = strings.Notification_VoiceChatStarted(authorName)
                        attributedString = addAttributesToStringWithRanges(titleString._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                }
            case let .customText(text, entities, additionalAttributes):
                let mutableAttributedString = NSMutableAttributedString(attributedString: stringWithAppliedEntities(text, entities: entities, baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: titleFont, linkFont: titleBoldFont, boldFont: titleBoldFont, italicFont: titleFont, boldItalicFont: titleBoldFont, fixedFont: titleFont, blockQuoteFont: titleFont, underlineLinks: false, message: message._asMessage()))
                if let additionalAttributes {
                    for (range, key, value) in additionalAttributes.attributes {
                        mutableAttributedString.addAttribute(key, value: value, range: range)
                    }
                }
                attributedString = mutableAttributedString
            case let .botDomainAccessGranted(domain):
                attributedString = NSAttributedString(string: strings.AuthSessions_Message(domain).string, font: titleFont, textColor: primaryTextColor)
            case let .botAppAccessGranted(appName, type):
                let text: String
                if type == .attachMenu {
                    text = strings.Notification_BotWriteAllowedMenu
                } else if type == .request {
                    text = strings.Notification_BotWriteAllowedRequest
                } else {
                    text = strings.AuthSessions_MessageApp(appName ?? "").string
                }
                attributedString = NSAttributedString(string: text, font: titleFont, textColor: primaryTextColor)
            case let .botSentSecureValues(types):
                var typesString = ""
                var hasIdentity = false
                var hasAddress = false
                for type in types {
                    if !typesString.isEmpty {
                        typesString.append(", ")
                    }
                    switch type {
                    case .personalDetails:
                        typesString.append(strings.Notification_PassportValuePersonalDetails)
                    case .passport, .internalPassport, .driversLicense, .idCard:
                        if !hasIdentity {
                            typesString.append(strings.Notification_PassportValueProofOfIdentity)
                            hasIdentity = true
                        }
                    case .address:
                        typesString.append(strings.Notification_PassportValueAddress)
                    case .bankStatement, .utilityBill, .rentalAgreement, .passportRegistration, .temporaryRegistration:
                        if !hasAddress {
                            typesString.append(strings.Notification_PassportValueProofOfAddress)
                            hasAddress = true
                        }
                    case .phone:
                        typesString.append(strings.Notification_PassportValuePhone)
                    case .email:
                        typesString.append(strings.Notification_PassportValueEmail)
                    }
                }
                attributedString = NSAttributedString(string: strings.Notification_PassportValuesSentMessage(message.peers[message.id.peerId].flatMap(EnginePeer.init)?.compactDisplayTitle ?? "", typesString).string, font: titleFont, textColor: primaryTextColor)
            case .peerJoined:
                attributedString = addAttributesToStringWithRanges(strings.Notification_Joined(authorName)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
            case .phoneNumberRequest:
                attributedString = nil
            case let .geoProximityReached(fromId, toId, distance):
                let distanceString = stringForDistance(strings: strings, distance: Double(distance))
                if fromId == accountPeerId {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ProximityYouReached(distanceString, message.peers[toId].flatMap(EnginePeer.init)?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? "")._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(1, toId)]))
                } else if toId == accountPeerId {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ProximityReachedYou(message.peers[fromId].flatMap(EnginePeer.init)?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? "", distanceString)._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, fromId)]))
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ProximityReached(message.peers[fromId].flatMap(EnginePeer.init)?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? "", distanceString, message.peers[toId].flatMap(EnginePeer.init)?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? "")._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, fromId), (2, toId)]))
                }
            case let .inviteToGroupPhoneCall(_, _, peerIds):
                var attributePeerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                let resultTitleString: PresentationStrings.FormattedString
                if peerIds.count == 1 {
                    if peerIds[0] == accountPeerId {
                        attributePeerIds.append((1, peerIds.first))
                        resultTitleString = strings.Notification_VoiceChatInvitationForYou(authorName)
                    } else {
                        attributePeerIds.append((1, peerIds.first))
                        resultTitleString = strings.Notification_VoiceChatInvitation(authorName, peerDisplayTitles(peerIds, message.peers, strings: strings, nameDisplayOrder: nameDisplayOrder))
                    }
                } else {
                    resultTitleString = strings.Notification_VoiceChatInvitation(authorName, peerDisplayTitles(peerIds, message.peers, strings: strings, nameDisplayOrder: nameDisplayOrder))
                }
                
                attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
            case let .setChatTheme(emoji):
                if emoji.isEmpty {
                    if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                        attributedString = NSAttributedString(string: strings.Notification_ChannelDisabledTheme, font: titleFont, textColor: primaryTextColor)
                    } else if message.author?.id == accountPeerId {
                        attributedString = NSAttributedString(string: strings.Notification_YouDisabledTheme, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let attributePeerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                        let resultTitleString = strings.Notification_DisabledTheme(compactAuthorName)
                        attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                } else {
                    if message.author?.id.namespace == Namespaces.Peer.CloudChannel {
                        attributedString = NSAttributedString(string: strings.Notification_ChannelChangedTheme(emoji).string, font: titleFont, textColor: primaryTextColor)
                    } else if message.author?.id == accountPeerId {
                        attributedString = NSAttributedString(string: strings.Notification_YouChangedTheme(emoji).string, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let resultTitleString = strings.Notification_ChangedTheme(compactAuthorName, emoji)
                        attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    }
                }
            case let .webViewData(text):
                attributedString = NSAttributedString(string: strings.Notification_WebAppSentData(text).string, font: titleFont, textColor: primaryTextColor)
            case let .giftPremium(currency, amount, _, _, _, _, _):
                if !forAdditionalServiceMessage {
                    attributedString = NSAttributedString(string: strings.Notification_Gift, font: titleFont, textColor: primaryTextColor)
                } else {
                    let price: String
                    if currency == "XTR" {
                        price = "\(amount) Stars"
                    } else {
                        price = formatCurrencyAmount(amount, currency: currency)
                    }
                    if message.author?.id == accountPeerId {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_PremiumGift_SentYou(price)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    } else {
                        var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                        attributes[1] = boldAttributes
                        attributedString = addAttributesToStringWithRanges(strings.Notification_PremiumGift_Sent(compactAuthorName, price)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                    }
                }
            case let .giftStars(currency, amount, count, _, _, _):
                let _ = count
                if !forAdditionalServiceMessage {
                    attributedString = NSAttributedString(string: strings.Notification_Gift, font: titleFont, textColor: primaryTextColor)
                } else {
                    let price = formatCurrencyAmount(amount, currency: currency)
                    if message.author?.id == accountPeerId {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_SentYou(price)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    } else {
                        var authorName = compactAuthorName
                        var peerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                        if message.id.peerId.namespace == Namespaces.Peer.CloudUser && message.id.peerId.id._internalGetInt64Value() == 777000 {
                            authorName = strings.Notification_StarsGift_UnknownUser
                            peerIds = []
                        }
                        var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                        attributes[1] = boldAttributes
                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Sent(authorName, price)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                    }
                }
            case let .topicCreated(title, iconColor, iconFileId):
                if forForumOverview {
                    let maybeFileId = iconFileId ?? 0
                    attributedString = addAttributesToStringWithRanges(strings.Notification_OverviewTopicCreated(".", title)._tuple, body: bodyAttributes, argumentAttributes: [0: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])])
                } else {
                    attributedString = NSAttributedString(string: strings.Notification_ForumTopicCreated, font: titleFont, textColor: primaryTextColor)
                }
            case let .topicEdited(components):
                if let isHidden = components.compactMap({ item -> Bool? in
                    switch item {
                    case let .isHidden(isHidden):
                        return isHidden
                    default:
                        return nil
                    }
                }).first {
                    if case let .user(user) = message.author {
                        if forForumOverview {
                            var title: String = ""
                            var iconColor: Int32 = 0
                            var maybeFileId: Int64 = 0
                            if let info = message.associatedThreadInfo {
                                iconColor = info.iconColor
                                title = info.title
                                maybeFileId = info.icon ?? 0
                            }
                            if isHidden {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_OverviewTopicHidden(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder), ".", title)._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id), 1: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])])
                            } else {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_OverviewTopicUnhidden(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder), ".", title)._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id), 1: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])])
                            }
                        } else {
                            if isHidden {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicHiddenAuthor(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder))._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id)])
                            } else {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicUnhiddenAuthor(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder))._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id)])
                            }
                        }
                    } else {
                        if isHidden {
                            attributedString = NSAttributedString(string: strings.Notification_ForumTopicHidden, font: titleFont, textColor: primaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Notification_ForumTopicUnhidden, font: titleFont, textColor: primaryTextColor)
                        }
                    }
                } else if let isClosed = components.compactMap({ item -> Bool? in
                    switch item {
                    case let .isClosed(isClosed):
                        return isClosed
                    default:
                        return nil
                    }
                }).first {
                    if case let .user(user) = message.author {
                        if forForumOverview {
                            var title: String = ""
                            var iconColor: Int32 = 0
                            var maybeFileId: Int64 = 0
                            if let info = message.associatedThreadInfo {
                                iconColor = info.iconColor
                                title = info.title
                                maybeFileId = info.icon ?? 0
                            }
                            if isClosed {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_OverviewTopicClosed(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder), ".", title)._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id), 1: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])])
                            } else {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_OverviewTopicReopened(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder), ".", title)._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id), 1: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])])
                            }
                        } else {
                            if isClosed {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicClosedAuthor(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder))._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id)])
                            } else {
                                attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicReopenedAuthor(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder))._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id)])
                            }
                        }
                    } else {
                        if isClosed {
                            attributedString = NSAttributedString(string: strings.Notification_ForumTopicClosed, font: titleFont, textColor: primaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Notification_ForumTopicReopened, font: titleFont, textColor: primaryTextColor)
                        }
                    }
                } else if let maybeFileId = components.compactMap({ item -> Int64? in
                    switch item {
                    case let .iconFileId(id):
                        return id ?? 0
                    default:
                        return nil
                    }
                }).first, let title = components.compactMap({ item -> String? in
                    switch item {
                    case let .title(title):
                        return title
                    default:
                        return nil
                    }
                }).first {
                    if case let .user(user) = message.author {
                        var iconColor: Int32 = 0
                        if let info = message.associatedThreadInfo {
                            iconColor = info.iconColor
                        }
                        attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicRenamedIconChangedAuthor(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder), ".", title)._tuple, body: bodyAttributes, argumentAttributes: [
                            0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id),
                            1: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])
                        ])
                    } else {
                        attributedString = NSAttributedString(string: strings.Notification_ForumTopicRenamed(title).string, font: titleFont, textColor: primaryTextColor)
                    }
                } else if let title = components.compactMap({ item -> String? in
                    switch item {
                    case let .title(title):
                        return title
                    default:
                        return nil
                    }
                }).first {
                    if case let .user(user) = message.author {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicRenamedAuthor(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder), title)._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id)])
                    } else {
                        attributedString = NSAttributedString(string: strings.Notification_ForumTopicRenamed(title).string, font: titleFont, textColor: primaryTextColor)
                    }
                } else if let maybeFileId = components.compactMap({ item -> Int64? in
                    switch item {
                    case let .iconFileId(id):
                        return id ?? 0
                    default:
                        return nil
                    }
                }).first {
                    var title: String = ""
                    var iconColor: Int32 = 0
                    if let info = message.associatedThreadInfo {
                        iconColor = info.iconColor
                        title = info.title
                    }
                    if case let .user(user) = message.author {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicIconChangedAuthor(EnginePeer.user(user).displayTitle(strings: strings, displayOrder: nameDisplayOrder), ".")._tuple, body: bodyAttributes, argumentAttributes: [0: peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: user.id), 1: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])])
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_ForumTopicIconChanged(".")._tuple, body: bodyAttributes, argumentAttributes: [0: MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [ChatTextInputAttributes.customEmoji.rawValue: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: maybeFileId, file: nil, custom: maybeFileId == 0 ? .topic(id: message.threadId ?? 0, info: EngineMessageHistoryThread.Info(title: title, icon: nil, iconColor: iconColor)) : nil)])])
                    }
                }
            case let .suggestedProfilePhoto(image):
                if (image?.videoRepresentations.isEmpty ?? true) {
                    attributedString = NSAttributedString(string: strings.Notification_SuggestedProfilePhoto, font: titleFont, textColor: primaryTextColor)
                } else {
                    attributedString = NSAttributedString(string: strings.Notification_SuggestedProfileVideo, font: titleFont, textColor: primaryTextColor)
                }
            case .attachMenuBotAllowed:
                attributedString = NSAttributedString(string: strings.Notification_BotWriteAllowed, font: titleFont, textColor: primaryTextColor)
            case let .requestedPeer(_, peerIds):
                let botName = message.peers[message.id.peerId].flatMap(EnginePeer.init)?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""
                var attributePeerIds: [(Int, EnginePeer.Id?)] = []
                let resultTitleString: PresentationStrings.FormattedString
                if peerIds.count == 1 {
                    attributePeerIds.append((0, peerIds.first))
                    attributePeerIds.append((1, message.id.peerId))
                    resultTitleString = strings.Notification_RequestedPeer(peerDisplayTitles(peerIds, message.peers, strings: strings, nameDisplayOrder: nameDisplayOrder), botName)
                } else {
                    attributePeerIds.append((1, message.id.peerId))
                    resultTitleString = strings.Notification_RequestedPeerMultiple(peerDisplayTitles(peerIds, message.peers, strings: strings, nameDisplayOrder: nameDisplayOrder), botName)
                }
                attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
            case let .setChatWallpaper(_, forBoth):
                var isGroup = false
                let messagePeer = message.peers[message.id.peerId]
                if let channel = messagePeer as? TelegramChannel, case .group = channel.info {
                    isGroup = true
                }
                if message.author?.id == accountPeerId {
                    if forBoth {
                        let peerName = message.peers[message.id.peerId].flatMap(EnginePeer.init)?.compactDisplayTitle ?? ""
                        let resultTitleString = strings.Notification_YouChangedWallpaperBoth(peerName)
                        attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    } else {
                        attributedString = NSAttributedString(string: isGroup ? strings.Notification_YouChangedGroupWallpaper : strings.Notification_YouChangedWallpaper, font: titleFont, textColor: primaryTextColor)
                    }
                } else {
                    if message.id.peerId.isGroupOrChannel {
                        attributedString = NSAttributedString(string: isGroup ? strings.Notification_GroupChangedWallpaper : strings.Notification_ChannelChangedWallpaper, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let resultTitleString = strings.Notification_ChangedWallpaper(compactAuthorName)
                        attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    }
                }
            case .setSameChatWallpaper:
                if message.author?.id == accountPeerId {
                    attributedString = NSAttributedString(string: strings.Notification_YouChangedToSameWallpaper, font: titleFont, textColor: primaryTextColor)
                } else {
                    let resultTitleString = strings.Notification_ChangedToSameWallpaper(compactAuthorName)
                    attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                }
            case let .giftCode(_, _, _, boostPeerId, _, currency, amount, _, _, text, entities):
                if !forAdditionalServiceMessage, let text {
                    let mutableAttributedString = NSMutableAttributedString(attributedString: stringWithAppliedEntities(text, entities: entities ?? [], baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: titleFont, linkFont: titleBoldFont, boldFont: titleBoldFont, italicFont: titleFont, boldItalicFont: titleBoldFont, fixedFont: titleFont, blockQuoteFont: titleFont, underlineLinks: false, message: message._asMessage()))
                    attributedString = mutableAttributedString
                } else if boostPeerId == nil, let currency, let amount {
                    if !forAdditionalServiceMessage {
                        attributedString = NSAttributedString(string: strings.Notification_Gift, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let price = formatCurrencyAmount(amount, currency: currency)
                        if message.author?.id == accountPeerId {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PremiumGift_SentYou(price)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                        } else {
                            var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                            attributes[1] = boldAttributes
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PremiumGift_Sent(compactAuthorName, price)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                        }
                    }
                } else {
                    attributedString = NSAttributedString(string: strings.Notification_GiftLink, font: titleFont, textColor: primaryTextColor)
                }
            case let .giveawayLaunched(stars):
                var isGroup = false
                let messagePeer = message.peers[message.id.peerId]
                if let channel = messagePeer as? TelegramChannel, case .group = channel.info {
                    isGroup = true
                }
                let resultTitleString: PresentationStrings.FormattedString
                if let stars {
                    let starsString = strings.Notification_StarsGiveawayStarted_Stars(Int32(stars))
                    resultTitleString = isGroup ? strings.Notification_StarsGiveawayStartedGroup(compactAuthorName, starsString) : strings.Notification_StarsGiveawayStarted(compactAuthorName, starsString)
                } else {
                    resultTitleString = isGroup ? strings.Notification_GiveawayStartedGroup(compactAuthorName) : strings.Notification_GiveawayStarted(compactAuthorName)
                }
                attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
            case .joinedChannel:
                attributedString = NSAttributedString(string: strings.Notification_ChannelJoinedByYou, font: titleBoldFont, textColor: primaryTextColor)
            case let .giveawayResults(winners, unclaimed, stars):
                var isGroup = false
                let messagePeer = message.peers[message.id.peerId]
                if let channel = messagePeer as? TelegramChannel, case .group = channel.info {
                    isGroup = true
                }
                if winners == 0 {
                    if stars {
                        attributedString = parseMarkdownIntoAttributedString(isGroup ? strings.Notification_StarsGiveawayResultsNoWinners_Group : strings.Notification_StarsGiveawayResultsNoWinners, attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }))
                    } else {
                        attributedString = parseMarkdownIntoAttributedString(isGroup ? strings.Notification_GiveawayResultsNoWinners_Group(unclaimed) : strings.Notification_GiveawayResultsNoWinners(unclaimed), attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }))
                    }
                } else if unclaimed > 0 {
                    let winnersString = parseMarkdownIntoAttributedString(strings.Notification_GiveawayResultsMixedWinners(winners), attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }))
                    let unclaimedString = parseMarkdownIntoAttributedString(isGroup ? strings.Notification_GiveawayResultsMixedUnclaimed_Group(unclaimed) : strings.Notification_GiveawayResultsMixedUnclaimed(unclaimed), attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }))
                    let combinedString = NSMutableAttributedString(attributedString: winnersString)
                    combinedString.append(NSAttributedString(string: "\n"))
                    combinedString.append(unclaimedString)
                    attributedString = combinedString
                } else {
                    attributedString = parseMarkdownIntoAttributedString(strings.Notification_GiveawayResults(winners), attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }))
                }
            case let .boostsApplied(boosts):
                if message.author?.id == accountPeerId {
                    if boosts == 1 {
                        attributedString = NSAttributedString(string: strings.Notification_Boost_SingleYou, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let boostsString = strings.Notification_Boost_Times(boosts)
                        attributedString = NSAttributedString(string: strings.Notification_Boost_MultipleYou(boostsString).string, font: titleFont, textColor: primaryTextColor)
                    }
                } else {
                    let peerName = message.author?.compactDisplayTitle ?? ""
                    if boosts == 1 {
                        let resultTitleString = strings.Notification_Boost_Single(peerName)
                        attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    } else {
                        let boostsString = strings.Notification_Boost_Times(boosts)
                        let resultTitleString = strings.Notification_Boost_Multiple(peerName, boostsString)
                        attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    }
                }
            case let .paymentRefunded(peerId, currency, totalAmount, _, _):
                let patternString = strings.Notification_Refund
                
                let mutableString = NSMutableAttributedString()
                mutableString.append(NSAttributedString(string: patternString, font: titleFont, textColor: primaryTextColor))
                
                var range = NSRange(location: NSNotFound, length: 0)
                range = (mutableString.string as NSString).range(of: "{amount}")
                if range.location != NSNotFound {
                    if currency == "XTR" {
                        let amountAttributedString = NSMutableAttributedString(string: "#\(totalAmount)", font: titleBoldFont, textColor: primaryTextColor)
                        if let range = amountAttributedString.string.range(of: "#") {
                            amountAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: true)), range: NSRange(range, in: amountAttributedString.string))
                            amountAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: amountAttributedString.string))
                        }
                        mutableString.replaceCharacters(in: range, with: amountAttributedString)
                    } else {
                        mutableString.replaceCharacters(in: range, with: NSAttributedString(string: formatCurrencyAmount(totalAmount, currency: currency), font: titleBoldFont, textColor: primaryTextColor))
                    }
                }
                range = (mutableString.string as NSString).range(of: "{name}")
                if range.location != NSNotFound {
                    let peerName = message.peers[peerId].flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                    mutableString.replaceCharacters(in: range, with: NSAttributedString(string: peerName, font: titleBoldFont, textColor: primaryTextColor))
                    mutableString.addAttribute(NSAttributedString.Key(TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: peerId, mention: ""), range: NSMakeRange(range.location, (peerName as NSString).length))
                }
                attributedString = mutableString
            case .prizeStars:
                attributedString = NSAttributedString(string: strings.Notification_StarsPrize, font: titleFont, textColor: primaryTextColor)
            case let .starGift(gift, _, text, entities, _, _, _, _, _, upgradeStars, _, _, peerId, senderId, _):
                if !forAdditionalServiceMessage {
                    if let text {
                        let mutableAttributedString = NSMutableAttributedString(attributedString: stringWithAppliedEntities(text, entities: entities ?? [], baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: titleFont, linkFont: titleBoldFont, boldFont: titleBoldFont, italicFont: titleFont, boldItalicFont: titleBoldFont, fixedFont: titleFont, blockQuoteFont: titleFont, underlineLinks: false, message: message._asMessage()))
                        attributedString = mutableAttributedString
                    } else {
                        attributedString = NSAttributedString(string: strings.Notification_Gift, font: titleFont, textColor: primaryTextColor)
                    }
                } else if case let .generic(gift) = gift {
                    var finalPrice = gift.price
                    if let upgradeStars {
                        finalPrice += upgradeStars
                    }
                    let starsPrice = strings.Notification_StarsGift_Stars(Int32(finalPrice))
                    var authorName = compactAuthorName
                    var peerIds: [(Int, EnginePeer.Id?)] = [(0, message.author?.id)]
                    if message.id.peerId.namespace == Namespaces.Peer.CloudUser && message.id.peerId.id._internalGetInt64Value() == 777000 {
                        authorName = strings.Notification_StarsGift_UnknownUser
                        peerIds = []
                    }
                    if message.id.peerId.isTelegramNotifications && senderId == nil {
                        attributedString = NSAttributedString(string: strings.Notification_StarsGift_SentSomeone, font: titleFont, textColor: primaryTextColor)
                    } else if message.id.peerId == accountPeerId {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Self_Bought(starsPrice)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    } else if message.author?.id == accountPeerId {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_SentYou(starsPrice)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    } else if let peerId {
                        peerIds = [(1, peerId)]
                        var peerName = ""
                        if let name = message.peers[peerId].flatMap(EnginePeer.init)?.compactDisplayTitle {
                            peerName = name
                        }
                        if let senderId {
                            peerIds.insert((0, senderId), at: 0)
                            if let name = message.peers[senderId].flatMap(EnginePeer.init)?.compactDisplayTitle {
                                authorName = name
                            }
                        }
                        var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                        attributes[2] = boldAttributes
                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Channel_Sent(authorName, peerName, starsPrice)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                    } else {
                        var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                        attributes[1] = boldAttributes
                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Sent(authorName, starsPrice)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                    }
                }
            case let .starGiftUnique(gift, isUpgrade, _, _, _, _, _, peerId, senderId, _, resaleStars, _, _):
                if case let .unique(gift) = gift {
                    if !forAdditionalServiceMessage && !"".isEmpty {
                        attributedString = NSAttributedString(string: "\(gift.title) #\(presentationStringsFormattedNumber(gift.number, dateTimeFormat.groupingSeparator))", font: titleFont, textColor: primaryTextColor)
                    } else if let messagePeer = message.peers[message.id.peerId] {
                        var peerName = EnginePeer(messagePeer).compactDisplayTitle
                        var peerIds: [(Int, EnginePeer.Id?)] = [(0, messagePeer.id)]
                        if isUpgrade {
                            if message.id.peerId.isTelegramNotifications {
                                attributedString = NSAttributedString(string: strings.Notification_StarsGift_UpgradeChannel, font: titleFont, textColor: primaryTextColor)
                            } else if message.id.peerId == accountPeerId {
                                attributedString = NSAttributedString(string: strings.Notification_StarsGift_UpgradeSelf, font: titleFont, textColor: primaryTextColor)
                            } else if message.author?.id == accountPeerId {
                                let attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                                attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_UpgradeYou(peerName)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                            } else {
                                let attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                                attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Upgrade(peerName)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                            }
                        } else {
                            if message.id.peerId.isTelegramNotifications && senderId == nil {
                                attributedString = NSAttributedString(string: strings.Notification_StarsGift_SentSomeone, font: titleFont, textColor: primaryTextColor)
                            } else if message.author?.id == accountPeerId {
                                if let resaleStars {
                                    let starsString = strings.Notification_StarsGift_Bought_Stars(Int32(resaleStars))
                                    if message.id.peerId == accountPeerId {
                                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_BoughtForYouself(starsString)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                                    } else {
                                        let giftTitle = "\(gift.title) #\(presentationStringsFormattedNumber(gift.number, dateTimeFormat.groupingSeparator))"
                                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_BoughtYou(giftTitle, starsString)._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes, 1: boldAttributes])
                                    }
                                } else {
                                    attributedString = NSAttributedString(string: strings.Notification_StarsGift_TransferYou, font: titleFont, textColor: primaryTextColor)
                                }
                            } else if let senderId, let peer = message.peers[senderId] {
                                if let peerId, let targetPeer = message.peers[peerId] {
                                    if senderId == accountPeerId {
                                        peerName = EnginePeer(targetPeer).compactDisplayTitle
                                        peerIds = [(0, peerId)]
                                        let attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_TransferToChannelYou(peerName)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                                    } else {
                                        let targetPeerName = EnginePeer(targetPeer).compactDisplayTitle
                                        peerName = EnginePeer(peer).compactDisplayTitle
                                        peerIds = [(0, peer.id), (1, targetPeer.id)]
                                        let attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                                        attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_TransferToChannel(peerName, targetPeerName)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                                    }
                                } else {
                                    peerName = EnginePeer(peer).compactDisplayTitle
                                    peerIds = [(0, senderId)]
                                    let attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                                    attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Transfer(peerName)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                                }
                            } else {
                                var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: peerIds)
                                if let resaleStars {
                                    let starsString = strings.Notification_StarsGift_Bought_Stars(Int32(resaleStars))
                                    let giftTitle = "\(gift.title) #\(presentationStringsFormattedNumber(gift.number, dateTimeFormat.groupingSeparator))"
                                    attributes[1] = boldAttributes
                                    attributes[2] = boldAttributes
                                    attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Bought(peerName, giftTitle, starsString)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                                } else {
                                    attributedString = addAttributesToStringWithRanges(strings.Notification_StarsGift_Transfer(peerName)._tuple, body: bodyAttributes, argumentAttributes: attributes)
                                }
                            }
                        }
                    }
                }
            case let .paidMessagesRefunded(_, stars):
                let starsString = strings.Notification_PaidMessageRefund_Stars(Int32(stars))
                if message.author?.id == accountPeerId, let messagePeer = message.peers[message.id.peerId] {
                    let peerName = EnginePeer(messagePeer).compactDisplayTitle
                    var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(1, messagePeer.id)])
                    attributes[0] = boldAttributes
                    let resultString = strings.Notification_PaidMessageRefundYou(starsString, peerName)
                    attributedString = addAttributesToStringWithRanges(resultString._tuple, body: bodyAttributes, argumentAttributes: attributes)
                } else {
                    let peerName = message.author?.compactDisplayTitle ?? ""
                    var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                    attributes[1] = boldAttributes
                    let resultString = strings.Notification_PaidMessageRefund(peerName, starsString)
                    attributedString = addAttributesToStringWithRanges(resultString._tuple, body: bodyAttributes, argumentAttributes: attributes)
                }
            case let .paidMessagesPriceEdited(stars, broadcastMessagesAllowed):
                let starsString = strings.Notification_PaidMessagePriceChanged_Stars(Int32(stars))
                if message.author?.id == accountPeerId {
                    let resultString: PresentationStrings.FormattedString
                    resultString = strings.Notification_PaidMessagePriceChangedYou(starsString)
                    attributedString = addAttributesToStringWithRanges(resultString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                } else {
                    let peerName = message.author?.compactDisplayTitle ?? ""
                    var attributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                    attributes[1] = boldAttributes
                    let resultString: PresentationStrings.FormattedString
                    
                    if broadcastMessagesAllowed {
                        if stars == 0 {
                            resultString = strings.Notification_ChannelMessagePriceZeroChanged(peerName)
                        } else {
                            var rawString = strings.Notification_ChannelMessagePriceChanged(Int32(stars))
                            rawString = rawString.replacingOccurrences(of: "{name}", with: peerName)
                            resultString = PresentationStrings.FormattedString(string: rawString, ranges: [])
                        }
                    } else {
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                            resultString = strings.Notification_ChannelMessageDisabled(peerName)
                        } else {
                            resultString = strings.Notification_PaidMessagePriceChanged(peerName, starsString)
                        }
                    }
                    attributedString = addAttributesToStringWithRanges(resultString._tuple, body: bodyAttributes, argumentAttributes: attributes)
                }
            case .unknown:
                attributedString = nil
            }
            break
        } else if let expiredMedia = media as? TelegramMediaExpiredContent {
            switch expiredMedia.data {
            case .image:
                attributedString = NSAttributedString(string: strings.Message_ImageExpired, font: titleFont, textColor: primaryTextColor)
            case .file:
                attributedString = NSAttributedString(string: strings.Message_VideoExpired, font: titleFont, textColor: primaryTextColor)
            case .videoMessage:
                attributedString = NSAttributedString(string: strings.Message_VideoMessageExpired, font: titleFont, textColor: primaryTextColor)
            case .voiceMessage:
                attributedString = NSAttributedString(string: strings.Message_VoiceMessageExpired, font: titleFont, textColor: primaryTextColor)
            }
        } else if let _ = media as? TelegramMediaStory {
            let compactPeerName = message.peers[message.id.peerId].flatMap(EnginePeer.init)?.compactDisplayTitle ?? ""
            
            let resultTitleString: PresentationStrings.FormattedString
            if message.flags.contains(.Incoming) {
                resultTitleString = PresentationStrings.FormattedString(string: strings.Conversation_StoryExpiredMentionTextIncoming, ranges: [])
            } else {
                resultTitleString = strings.Conversation_StoryExpiredMentionTextOutgoing(compactPeerName)
            }
            attributedString = addAttributesToStringWithRanges(resultTitleString._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
        }
    }
    
    return attributedString
}
