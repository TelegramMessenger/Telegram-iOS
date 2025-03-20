import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import MergeLists
import AccountContext
import ChatControllerInteraction
import ChatHistoryEntry
import ChatMessageItem
import ChatMessageItemImpl
import TextFormat

enum ChatRecentActionsEntryContentIndex: Int32 {
    case header = 0
    case content = 1
}

struct ChatRecentActionsEntryId: Hashable, Comparable {
    let eventId: AdminLogEventId
    let contentIndex: ChatRecentActionsEntryContentIndex
    
    static func ==(lhs: ChatRecentActionsEntryId, rhs: ChatRecentActionsEntryId) -> Bool {
        return lhs.eventId == rhs.eventId && lhs.contentIndex == rhs.contentIndex
    }
    
    static func <(lhs: ChatRecentActionsEntryId, rhs: ChatRecentActionsEntryId) -> Bool {
        if lhs.eventId != rhs.eventId {
            return lhs.eventId < rhs.eventId
        } else {
            return lhs.contentIndex.rawValue < rhs.contentIndex.rawValue
        }
    }
}

private func eventNeedsHeader(_ event: AdminLogEvent) -> Bool {
    switch event.action {
        case .changeAbout, .changeUsername, .changeUsernames, .editMessage, .deleteMessage, .pollStopped, .sendMessage:
            return true
        case let .updatePinned(message):
            if message != nil {
                return true
            } else {
                return false
            }
        default:
            return false
    }
}

private func appendAttributedText(text: PresentationStrings.FormattedString, generateEntities: (Int) -> [MessageTextEntityType], to string: inout String, entities: inout [MessageTextEntity]) {
    for rangeItem in text.ranges {
        for type in generateEntities(rangeItem.index) {
            entities.append(MessageTextEntity(range: (string.count + rangeItem.range.lowerBound) ..< (string.count + rangeItem.range.upperBound), type: type))
        }
    }
    string.append(text.string)
}

private func appendAttributedText(text: PresentationStrings.FormattedString, additionalAttributes: inout [(NSRange, NSAttributedString.Key, Any)], generateEntities: (Int) -> ([MessageTextEntityType], [NSAttributedString.Key: Any]), to string: inout String, entities: inout [MessageTextEntity]) {
    let nsString = string as NSString
    for rangeItem in text.ranges {
        let (types, additionalValues) = generateEntities(rangeItem.index)
        for type in types {
            entities.append(MessageTextEntity(range: (nsString.length + rangeItem.range.lowerBound) ..< (nsString.length + rangeItem.range.upperBound), type: type))
        }
        let lowerBound = nsString.length + rangeItem.range.lowerBound
        let range = NSRange(location: lowerBound, length: nsString.length + rangeItem.range.upperBound - lowerBound)
        for (key, value) in additionalValues {
            additionalAttributes.append((range, key, value))
        }
    }
    string.append(text.string)
}

private func appendAttributedText(text: String, withEntities: [MessageTextEntityType], to string: inout String, entities: inout [MessageTextEntity]) {
    for type in withEntities {
        entities.append(MessageTextEntity(range: string.count ..< (string.count + text.count), type: type))
    }
    string.append(text)
}

private func filterOriginalMessageFlags(_ message: Message) -> Message {
    return message.withUpdatedFlags([.Incoming])
}

private func filterMessageChannelPeer(_ peer: Peer) -> Peer {
    if let peer = peer as? TelegramChannel {
        return TelegramChannel(id: peer.id, accessHash: peer.accessHash, title: peer.title, username: peer.username, photo: peer.photo, creationDate: peer.creationDate, version: peer.version, participationStatus: peer.participationStatus, info: .group(TelegramChannelGroupInfo(flags: [])), flags: peer.flags, restrictionInfo: peer.restrictionInfo, adminRights: peer.adminRights, bannedRights: peer.bannedRights, defaultBannedRights: peer.defaultBannedRights, usernames: peer.usernames, storiesHidden: peer.storiesHidden, nameColor: peer.nameColor, backgroundEmojiId: peer.backgroundEmojiId, profileColor: peer.profileColor, profileBackgroundEmojiId: peer.profileBackgroundEmojiId, emojiStatus: peer.emojiStatus, approximateBoostLevel: peer.approximateBoostLevel, subscriptionUntilDate: peer.subscriptionUntilDate, verificationIconFileId: peer.verificationIconFileId, sendPaidMessageStars: peer.sendPaidMessageStars)
    }
    return peer
}

struct ChatRecentActionsEntry: Comparable, Identifiable {
    let id: ChatRecentActionsEntryId
    let presentationData: ChatPresentationData
    let entry: ChannelAdminEventLogEntry
    let subEntries: [ChannelAdminEventLogEntry]
    let isExpanded: Bool?
    
    static func ==(lhs: ChatRecentActionsEntry, rhs: ChatRecentActionsEntry) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.presentationData !== rhs.presentationData {
            return false
        }
        if lhs.entry != rhs.entry {
            return false
        }
        if lhs.subEntries != rhs.subEntries {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
    
    static func <(lhs: ChatRecentActionsEntry, rhs: ChatRecentActionsEntry) -> Bool {
        if lhs.entry.event.date != rhs.entry.event.date {
            return lhs.entry.event.date < rhs.entry.event.date
        } else {
            return lhs.id < rhs.id
        }
    }
    
    var stableId: ChatRecentActionsEntryId {
        return self.id
    }
    
    func item(context: AccountContext, peer: Peer, controllerInteraction: ChatControllerInteraction, chatThemes: [TelegramTheme], availableReactions: AvailableReactions?, availableMessageEffects: AvailableMessageEffects?) -> ListViewItem {
        switch self.entry.event.action {
            case let .changeTitle(_, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = peer
                
                let action = TelegramMediaActionType.titleUpdated(title: new)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .changeAbout(prev, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = peer
                
                switch self.id.contentIndex {
                    case .header:
                        var text: String = ""
                        var entities: [MessageTextEntity] = []
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedChannelAbout(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        } else {
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedGroupAbout(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        }
                        let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        let peers = SimpleDictionary<PeerId, Peer>()
                        let attributes: [MessageAttribute] = []
                        let prevMessage = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: prev, attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        
                        let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: new, attributes: attributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil), additionalContent: !prev.isEmpty ? .eventLogPreviousDescription(prevMessage) : nil)
                }
            case let .changeUsername(prev, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                
                switch self.id.contentIndex {
                    case .header:
                        var text: String = ""
                        var entities: [MessageTextEntity] = []
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedChannelUsername(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        } else {
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedGroupUsername(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        }
                        let action: TelegramMediaActionType = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        var previousAttributes: [MessageAttribute] = []
                        var attributes: [MessageAttribute] = []
                        
                        let prevText = "https://t.me/\(prev)"
                        previousAttributes.append(TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< prevText.count, type: .Url)]))
                        
                        let text: String
                        if !new.isEmpty {
                            text = "https://t.me/\(new)"
                            attributes.append(TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< text.count, type: .Url)]))
                        } else {
                            text = self.presentationData.strings.Channel_AdminLog_EmptyMessageText
                            attributes.append(TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< text.count, type: .Italic)]))
                        }
                        
                        let prevMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: prevText, attributes: previousAttributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: text, attributes: attributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil), additionalContent: !prev.isEmpty ? .eventLogPreviousLink(prevMessage) : nil)
                }
            case let .changeUsernames(prev, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                
                switch self.id.contentIndex {
                    case .header:
                        var text: String = ""
                        var entities: [MessageTextEntity] = []
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedChannelUsernames(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        } else {
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedGroupUsernames(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        }
                        let action: TelegramMediaActionType = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        var previousAttributes: [MessageAttribute] = []
                        var attributes: [MessageAttribute] = []
                    
                        var prevTextEntities: [MessageTextEntity] = []
                        var textEntities: [MessageTextEntity] = []
                    
                        var prevText: String = ""
                        for username in prev {
                            let link = "https://t.me/\(username)"
                            prevTextEntities.append(MessageTextEntity(range: prevText.count ..< prevText.count + link.count, type: .Url))
                            prevText.append(link)
                            prevText.append("\n")
                        }
                        prevText.removeLast()
                        if !prevTextEntities.isEmpty {
                            previousAttributes.append(TextEntitiesMessageAttribute(entities: prevTextEntities))
                        }
                        var text: String = ""
                        if !new.isEmpty {
                            for username in new {
                                let link = "https://t.me/\(username)"
                                textEntities.append(MessageTextEntity(range: text.count ..< text.count + link.count, type: .Url))
                                text.append(link)
                                text.append("\n")
                            }
                            text.removeLast()
                            if !textEntities.isEmpty {
                                attributes.append(TextEntitiesMessageAttribute(entities: prevTextEntities))
                            }
                        } else {
                            text = self.presentationData.strings.Channel_AdminLog_EmptyMessageText
                            attributes.append(TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< text.count, type: .Italic)]))
                        }
                        
                        let prevMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: prevText, attributes: previousAttributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: text, attributes: attributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil), additionalContent: !prev.isEmpty ? .eventLogPreviousLink(prevMessage) : nil)
                }
            case let .changePhoto(_, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = peer
                
                var photo: TelegramMediaImage?
                let (newPhoto, newVideo) = new
                if !newPhoto.isEmpty || !newVideo.isEmpty {
                    photo = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: newPhoto, videoRepresentations: newVideo, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                }
                
                let action = TelegramMediaActionType.photoUpdated(image: photo)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .toggleInvites(value):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                if value {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageToggleInvitesOn(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageToggleInvitesOff(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case .toggleSignatures(let value), .toggleSignatureProfiles(let value):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                if value {
                    let pattern: (String) -> PresentationStrings.FormattedString
                    if case .toggleSignatureProfiles = self.entry.event.action {
                        pattern = self.presentationData.strings.Channel_AdminLog_MessageToggleProfileSignaturesOn
                    } else {
                        pattern = self.presentationData.strings.Channel_AdminLog_MessageToggleSignaturesOn
                    }
                    
                    appendAttributedText(text: pattern(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else {
                    let pattern: (String) -> PresentationStrings.FormattedString
                    if case .toggleSignatureProfiles = self.entry.event.action {
                        pattern = self.presentationData.strings.Channel_AdminLog_MessageToggleProfileSignaturesOff
                    } else {
                        pattern = self.presentationData.strings.Channel_AdminLog_MessageToggleSignaturesOff
                    }
                    
                    appendAttributedText(text: pattern(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .updatePinned(message):
                switch self.id.contentIndex {
                    case .header:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var author: Peer?
                        if self.entry.event.peerId == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(136817688)) {
                            author = message?.effectiveAuthor
                        } else if let peer = self.entry.peers[self.entry.event.peerId] {
                            author = peer
                            peers[peer.id] = peer
                        }
                        var text: String = ""
                        var entities: [MessageTextEntity] = []

                        let textFormat: (String) -> PresentationStrings.FormattedString
                        if let message = message, message.tags.contains(.pinned) {
                            textFormat = self.presentationData.strings.Channel_AdminLog_MessagePinned
                        } else {
                            textFormat = self.presentationData.strings.Channel_AdminLog_MessageUnpinnedExtended
                        }
                        
                        appendAttributedText(text: textFormat(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                        
                        let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        if let message = message {
                            var peers = SimpleDictionary<PeerId, Peer>()
                            var attributes: [MessageAttribute] = []
                            for attribute in message.attributes {
                                if let attribute = attribute as? TextEntitiesMessageAttribute {
                                    attributes.append(attribute)
                                }
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    attributes.append(attribute)
                                }
                            }
                            for attribute in attributes {
                                for peerId in attribute.associatedPeerIds {
                                    if let peer = self.entry.peers[peerId] {
                                        peers[peer.id] = peer
                                    }
                                }
                            }
                            if let peer = self.entry.peers[message.id.peerId] {
                                peers[peer.id] = peer
                            }
                            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: message.effectiveAuthor, text: message.text, attributes: attributes, media: message.media, peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: message.associatedThreadInfo, associatedStories: [:])
                            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                        } else {
                            var peers = SimpleDictionary<PeerId, Peer>()
                            var author: Peer?
                            if let peer = self.entry.peers[self.entry.event.peerId] {
                                author = peer
                                peers[peer.id] = peer
                            }
                            
                            var text: String = ""
                            var entities: [MessageTextEntity] = []
                            
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageUnpinned(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                            
                            let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                            
                            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 0), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                        }
                }
            case let .editMessage(prev, message):
                switch self.id.contentIndex {
                    case .header:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var author: Peer?
                        if let peer = self.entry.peers[self.entry.event.peerId] {
                            author = peer
                            peers[peer.id] = peer
                        }
                        
                        var text: String = ""
                        var entities: [MessageTextEntity] = []
                        
                        var mediaUpdated = false
                        if prev.media.count == message.media.count {
                            for i in 0 ..< prev.media.count {
                                if !prev.media[i].isEqual(to: message.media[i]) {
                                    mediaUpdated = true
                                    break
                                }
                            }
                        } else {
                            mediaUpdated = true
                        }
                        
                        let titleText: PresentationStrings.FormattedString
                        if mediaUpdated || message.media.isEmpty {
                            titleText = self.presentationData.strings.Channel_AdminLog_MessageEdited(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                        } else {
                            titleText = self.presentationData.strings.Channel_AdminLog_CaptionEdited(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                        }
                        
                        appendAttributedText(text: titleText, generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                        
                        let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var attributes: [MessageAttribute] = []
                        for attribute in message.attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                attributes.append(attribute)
                            }
                            if let attribute = attribute as? ReplyMessageAttribute {
                                attributes.append(attribute)
                            }
                        }
                        for attribute in attributes {
                            for peerId in attribute.associatedPeerIds {
                                if let peer = self.entry.peers[peerId] {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        if let peer = self.entry.peers[message.id.peerId] {
                            peers[peer.id] = peer
                        }
                        let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: message.effectiveAuthor, text: message.text, attributes: attributes, media: message.media, peers: peers, associatedMessages: message.associatedMessages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: message.associatedThreadInfo, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: filterOriginalMessageFlags(message), read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil), additionalContent: !prev.text.isEmpty || !message.text.isEmpty ? .eventLogPreviousMessage(filterOriginalMessageFlags(prev)) : nil)
                }
            case let .deleteMessage(message):
                switch self.id.contentIndex {
                    case .header:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var author: Peer?
                        if let peer = self.entry.peers[self.entry.event.peerId] {
                            author = peer
                            peers[peer.id] = peer
                        }
                        peers[peer.id] = peer
                        
                        var text: String = ""
                        var entities: [MessageTextEntity] = []
                    
                        let authorName = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
                    
                        if !self.subEntries.isEmpty {
                            var peers: [EnginePeer] = []
                            var existingPeerIds = Set<EnginePeer.Id>()
                            for entry in self.subEntries {
                                if case let .deleteMessage(message) = entry.event.action, let author = message.author {
                                    guard !existingPeerIds.contains(author.id) else {
                                        continue
                                    }
                                    peers.append(EnginePeer(author))
                                    existingPeerIds.insert(author.id)
                                }
                            }
                            let peerNames = peers.map { $0.compactDisplayTitle }.joined(separator: ", ")
                            let messagesString = self.presentationData.strings.Channel_AdminLog_MessageManyDeleted_Messages(Int32(self.subEntries.count))
                            
                            let fullText: PresentationStrings.FormattedString
                            if let isExpanded = self.isExpanded {
                                let moreText = (isExpanded ? self.presentationData.strings.Channel_AdminLog_MessageManyDeleted_HideAll : self.presentationData.strings.Channel_AdminLog_MessageManyDeleted_ShowAll).replacingOccurrences(of: " ", with: "\u{00A0}")
                                fullText = self.presentationData.strings.Channel_AdminLog_MessageManyDeletedMore(authorName, messagesString, peerNames, moreText)
                            } else {
                                fullText = self.presentationData.strings.Channel_AdminLog_MessageManyDeleted(authorName, messagesString, peerNames)
                            }
                            
                            appendAttributedText(text: fullText, generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                } else if index == 3 {
                                    return [.Custom(type: ApplicationSpecificEntityType.Button)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        } else {
                            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageDeleted(authorName), generateEntities: { index in
                                if index == 0, let author = author {
                                    return [.TextMention(peerId: author.id)]
                                }
                                return []
                            }, to: &text, entities: &entities)
                        }
                        
                        let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var attributes: [MessageAttribute] = []
                        for attribute in message.attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                attributes.append(attribute)
                            }
                            if let attribute = attribute as? ReplyMessageAttribute {
                                attributes.append(attribute)
                            }
                        }
                        for attribute in attributes {
                            for peerId in attribute.associatedPeerIds {
                                if let peer = self.entry.peers[peerId] {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        for media in message.media {
                            for peerId in media.peerIds {
                                if let peer = self.entry.peers[peerId] {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        if let peer = self.entry.peers[self.entry.event.peerId] {
                            peers[peer.id] = peer
                        }
                        if let peer = self.entry.peers[message.id.peerId] {
                            peers[peer.id] = peer
                        }
                    
                        var additionalContent: ChatMessageItemAdditionalContent?
                        if !self.subEntries.isEmpty {
                            var messages: [Message] = []
                            for entry in self.subEntries {
                                if case let .deleteMessage(message) = entry.event.action {
                                    messages.append(message)
                                }
                            }
                            var hasButton = false
                            if let isExpanded = self.isExpanded, !isExpanded {
                                hasButton = true
                            }
                            additionalContent = .eventLogGroupedMessages(messages, hasButton)
                        }
                        
                        let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: message.id.id), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: message.effectiveAuthor, text: message.text, attributes: attributes, media: message.media, peers: peers, associatedMessages: message.associatedMessages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: message.associatedThreadInfo, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil), additionalContent: additionalContent)
                }
            case .participantJoin, .participantLeave:
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = peer
                
                let action: TelegramMediaActionType
                if case .participantJoin = self.entry.event.action {
                    action = TelegramMediaActionType.addedMembers(peerIds: [self.entry.event.peerId])
                } else {
                    action = TelegramMediaActionType.removedMembers(peerIds: [self.entry.event.peerId])
                }
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .participantInvite(participant):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = peer
                for (_, peer) in participant.peers {
                    peers[peer.id] = peer
                }
                peers[participant.peer.id] = participant.peer
                
                let action: TelegramMediaActionType
                action = TelegramMediaActionType.addedMembers(peerIds: [participant.peer.id])
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .participantToggleBan(prev, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var attributes: [MessageAttribute] = []
                
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = filterMessageChannelPeer(peer)
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let isBroadcast: Bool
                if let peer = peer as? TelegramChannel {
                    switch peer.info {
                    case .broadcast:
                        isBroadcast = true
                    case .group:
                        isBroadcast = false
                    }
                } else {
                    isBroadcast = false
                }
                
                if case let .member(_, _, _, prevBanInfo, _, _) = prev.participant {
                    if case let .member(_, _, _, newBanInfo, _, _) = new.participant {
                        let newFlags = newBanInfo?.rights.flags ?? []
                        
                        var addedRights = newBanInfo?.rights.flags ?? []
                        var removedRights:TelegramChatBannedRightsFlags = []
                        if let prevBanInfo = prevBanInfo {
                            addedRights = addedRights.subtracting(prevBanInfo.rights.flags)
                            removedRights = prevBanInfo.rights.flags.subtracting(newBanInfo?.rights.flags ?? [])
                        }
                        
                        if (prevBanInfo == nil || !prevBanInfo!.rights.flags.contains(.banReadMessages)) && newFlags.contains(.banReadMessages) {
                            appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageKickedName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessageKickedNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                var result: [MessageTextEntityType] = []
                                if index == 0 {
                                    result.append(.TextMention(peerId: new.peer.id))
                                } else if index == 1 {
                                    result.append(.Mention)
                                }
                                return result
                            }, to: &text, entities: &entities)
                            text += "\n"
                        } else if isBroadcast, newBanInfo == nil, prevBanInfo != nil {
                            appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageUnkickedName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessageUnkickedNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                var result: [MessageTextEntityType] = []
                                if index == 0 {
                                    result.append(.TextMention(peerId: new.peer.id))
                                } else if index == 1 {
                                    result.append(.Mention)
                                }
                                return result
                            }, to: &text, entities: &entities)
                        } else {
                            appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageRestrictedName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessageRestrictedNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                var result: [MessageTextEntityType] = []
                                if index == 0 {
                                    result.append(.TextMention(peerId: new.peer.id))
                                } else if index == 1 {
                                    result.append(.Mention)
                                }
                                return result
                            }, to: &text, entities: &entities)
                            text += "\n"
                            
                            if let newBanInfo = newBanInfo, newBanInfo.rights.untilDate != 0 && newBanInfo.rights.untilDate != Int32.max {
                                let formatter = DateFormatter()
                                formatter.locale = Locale(identifier: self.presentationData.strings.baseLanguageCode)
                                formatter.dateFormat = "E, d MMM HH:mm"
                                let dateString = formatter.string(from: Date(timeIntervalSince1970: Double(newBanInfo.rights.untilDate)))
                                
                                if prevBanInfo?.rights.flags != newBanInfo.rights.flags {
                                    text += self.presentationData.strings.Channel_AdminLog_MessageRestrictedUntil(dateString).string
                                } else {
                                    text += self.presentationData.strings.Channel_AdminLog_MessageRestrictedNewSetting(dateString).string
                                }
                                text += "\n"
                            } else {
                                if prevBanInfo?.rights.flags != newBanInfo?.rights.flags {
                                    text += self.presentationData.strings.Channel_AdminLog_MessageRestrictedForever
                                } else {
                                    text += self.presentationData.strings.Channel_AdminLog_MessageRestrictedNewSetting(self.presentationData.strings.Channel_AdminLog_MessageRestrictedForever).string
                                }
                                text += "\n"
                            }
                            
                            let order: [(TelegramChatBannedRightsFlags, String)] = [
                                (.banReadMessages, self.presentationData.strings.Channel_AdminLog_BanReadMessages),
                                (.banSendText, self.presentationData.strings.Channel_AdminLog_BanSendMessages),
                                (.banSendMedia, self.presentationData.strings.Channel_AdminLog_BanSendMedia),
                                (.banSendStickers, self.presentationData.strings.Channel_AdminLog_BanSendStickersAndGifs),
                                (.banEmbedLinks, self.presentationData.strings.Channel_AdminLog_BanEmbedLinks),
                                (.banSendPolls, self.presentationData.strings.Channel_AdminLog_SendPolls),
                                (.banAddMembers, self.presentationData.strings.Channel_AdminLog_AddMembers),
                                (.banPinMessages, self.presentationData.strings.Channel_AdminLog_PinMessages),
                                (.banManageTopics, self.presentationData.strings.Channel_AdminLog_ManageTopics),
                                (.banChangeInfo, self.presentationData.strings.Channel_AdminLog_ChangeInfo)
                            ]
                            
                            for (flag, string) in order {
                                if addedRights.contains(flag) {
                                    text += "\n-"
                                    appendAttributedText(text: string, withEntities: [.Italic], to: &text, entities: &entities)
                                }
                                if removedRights.contains(flag) {
                                    text += "\n+"
                                    appendAttributedText(text: string, withEntities: [.Italic], to: &text, entities: &entities)
                                }
                            }
                        }
                    }
                }
                
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
            
                for attribute in attributes {
                    for peerId in attribute.associatedPeerIds {
                        if let peer = self.entry.peers[peerId] {
                            peers[peer.id] = peer
                        }
                    }
                }
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: text, attributes: attributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .participantToggleAdmin(prev, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var attributes: [MessageAttribute] = []
                
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = filterMessageChannelPeer(peer)
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                if case .member = prev.participant, case .creator = new.participant {
                    appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageTransferedName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessageTransferedNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                        var result: [MessageTextEntityType] = []
                        if index == 0 {
                            result.append(.TextMention(peerId: new.peer.id))
                        } else if index == 1 {
                            result.append(.Mention)
                        }
                        return result
                    }, to: &text, entities: &entities)
                } else {
                    var appendedRightsHeader = false
                    
                    if case let .creator(_, prevAdminInfo, prevRank) = prev.participant, case let .creator(_, newAdminInfo, newRank) = new.participant, (prevRank != newRank || prevAdminInfo?.rights.rights.contains(.canBeAnonymous) != newAdminInfo?.rights.rights.contains(.canBeAnonymous)) {
                        if prevRank != newRank {
                            appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageRankName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), newRank ?? "") : self.presentationData.strings.Channel_AdminLog_MessageRankUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!, newRank ?? ""), generateEntities: { index in
                                var result: [MessageTextEntityType] = []
                                if index == 0 {
                                    result.append(.TextMention(peerId: new.peer.id))
                                } else if index == 1 {
                                    result.append(.Mention)
                                } else if index == 2 {
                                    result.append(.Bold)
                                }
                                return result
                            }, to: &text, entities: &entities)
                        }
                        if prevAdminInfo?.rights.rights.contains(.canBeAnonymous) != newAdminInfo?.rights.rights.contains(.canBeAnonymous) {
                            let order: [(TelegramChatAdminRightsFlags, String)]
                            
                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                order = []
                            } else {
                                order = [
                                    (.canBeAnonymous, self.presentationData.strings.Channel_AdminLog_CanBeAnonymous)
                                ]
                            }
                            
                            var appendedRightsHeader = false
                            for (flag, string) in order {
                                if prevAdminInfo?.rights.rights.contains(flag) != newAdminInfo?.rights.rights.contains(flag) {
                                    if !appendedRightsHeader {
                                        appendedRightsHeader = true
                                        appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessagePromotedName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessagePromotedNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                            var result: [MessageTextEntityType] = []
                                            if index == 0 {
                                                result.append(.TextMention(peerId: new.peer.id))
                                            } else if index == 1 {
                                                result.append(.Mention)
                                            } else if index == 2 {
                                                result.append(.Bold)
                                            }
                                            return result
                                        }, to: &text, entities: &entities)
                                        text += "\n"
                                    }
                                    
                                    text += "\n"
                                    if prevAdminInfo?.rights.rights.contains(flag) != true {
                                        text += "+"
                                    } else {
                                        text += "-"
                                    }
                                    appendAttributedText(text: string, withEntities: [.Italic], to: &text, entities: &entities)
                                }
                            }
                        }
                    } else if case let .member(_, _, prevAdminRights, _, prevRank, _) = prev.participant {
                        if case let .member(_, _, newAdminRights, _, newRank, _) = new.participant {
                            var prevFlags = prevAdminRights?.rights.rights ?? []
                            var newFlags = newAdminRights?.rights.rights ?? []
                            
                            let order: [(TelegramChatAdminRightsFlags, String)]
                            
                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                order = [
                                    (.canChangeInfo, self.presentationData.strings.Channel_AdminLog_CanChangeInfo),
                                    (.canPostMessages, self.presentationData.strings.Channel_AdminLog_CanSendMessages),
                                    (.canDeleteMessages, self.presentationData.strings.Channel_AdminLog_CanDeleteMessagesOfOthers),
                                    (.canEditMessages, self.presentationData.strings.Channel_AdminLog_CanEditMessages),
                                    (.canPostStories, self.presentationData.strings.Channel_AdminLog_CanPostStories),
                                    (.canDeleteStories, self.presentationData.strings.Channel_AdminLog_CanDeleteStoriesOfOthers),
                                    (.canEditStories, self.presentationData.strings.Channel_AdminLog_CanEditStoriesOfOthers),
                                    (.canInviteUsers, self.presentationData.strings.Channel_AdminLog_CanInviteUsersViaLink),
                                    (.canPinMessages, self.presentationData.strings.Channel_AdminLog_CanPinMessages),
                                    (.canAddAdmins, self.presentationData.strings.Channel_AdminLog_CanAddAdmins),
                                    (.canManageCalls, self.presentationData.strings.Channel_AdminLog_CanManageLiveStreams)
                                ]
                                prevFlags = prevFlags.intersection(TelegramChatAdminRightsFlags.peerSpecific(peer: EnginePeer(peer)))
                                newFlags = newFlags.intersection(TelegramChatAdminRightsFlags.peerSpecific(peer: EnginePeer(peer)))
                            } else {
                                order = [
                                    (.canChangeInfo, self.presentationData.strings.Channel_AdminLog_CanChangeInfo),
                                    (.canDeleteMessages, self.presentationData.strings.Channel_AdminLog_CanDeleteMessages),
                                    (.canPostStories, self.presentationData.strings.Channel_AdminLog_CanPostStories),
                                    (.canDeleteStories, self.presentationData.strings.Channel_AdminLog_CanDeleteStoriesOfOthers),
                                    (.canEditStories, self.presentationData.strings.Channel_AdminLog_CanEditStoriesOfOthers),
                                    (.canBanUsers, self.presentationData.strings.Channel_AdminLog_CanBanUsers),
                                    (.canInviteUsers, self.presentationData.strings.Channel_AdminLog_CanInviteUsersViaLink),
                                    (.canPinMessages, self.presentationData.strings.Channel_AdminLog_CanPinMessages),
                                    (.canManageTopics, self.presentationData.strings.Channel_AdminLog_CanManageTopics),
                                    (.canBeAnonymous, self.presentationData.strings.Channel_AdminLog_CanBeAnonymous),
                                    (.canAddAdmins, self.presentationData.strings.Channel_AdminLog_CanAddAdmins),
                                    (.canManageCalls, self.presentationData.strings.Channel_AdminLog_CanManageCalls)
                                ]
                                prevFlags = prevFlags.intersection(TelegramChatAdminRightsFlags.peerSpecific(peer: EnginePeer(peer)))
                                newFlags = newFlags.intersection(TelegramChatAdminRightsFlags.peerSpecific(peer: EnginePeer(peer)))
                            }
                            
                            if prevFlags.isEmpty && newFlags.isEmpty && (prevAdminRights != nil) != (newAdminRights != nil) {
                                if !appendedRightsHeader {
                                    appendedRightsHeader = true
                                    if prevAdminRights == nil {
                                        appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageAddedAdminName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessageAddedAdminNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                            var result: [MessageTextEntityType] = []
                                            if index == 0 {
                                                result.append(.TextMention(peerId: new.peer.id))
                                            } else if index == 1 {
                                                result.append(.Mention)
                                            } else if index == 2 {
                                                result.append(.Bold)
                                            }
                                            return result
                                        }, to: &text, entities: &entities)
                                    } else {
                                        appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageRemovedAdminName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessageRemovedAdminNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                            var result: [MessageTextEntityType] = []
                                            if index == 0 {
                                                result.append(.TextMention(peerId: new.peer.id))
                                            } else if index == 1 {
                                                result.append(.Mention)
                                            } else if index == 2 {
                                                result.append(.Bold)
                                            }
                                            return result
                                        }, to: &text, entities: &entities)
                                    }
                                }
                            }
                            
                            if !prevFlags.isEmpty && newFlags.isEmpty {
                                if !appendedRightsHeader {
                                    appendedRightsHeader = true
                                    appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageRemovedAdminName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessageRemovedAdminNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                        var result: [MessageTextEntityType] = []
                                        if index == 0 {
                                            result.append(.TextMention(peerId: new.peer.id))
                                        } else if index == 1 {
                                            result.append(.Mention)
                                        } else if index == 2 {
                                            result.append(.Bold)
                                        }
                                        return result
                                    }, to: &text, entities: &entities)
                                }
                            } else {
                                for (flag, string) in order {
                                    if prevFlags.contains(flag) != newFlags.contains(flag) {
                                        if !appendedRightsHeader {
                                            appendedRightsHeader = true
                                            appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessagePromotedName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)) : self.presentationData.strings.Channel_AdminLog_MessagePromotedNameUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!), generateEntities: { index in
                                                var result: [MessageTextEntityType] = []
                                                if index == 0 {
                                                    result.append(.TextMention(peerId: new.peer.id))
                                                } else if index == 1 {
                                                    result.append(.Mention)
                                                } else if index == 2 {
                                                    result.append(.Bold)
                                                }
                                                return result
                                            }, to: &text, entities: &entities)
                                            text += "\n"
                                        }
                                        
                                        text += "\n"
                                        if !prevFlags.contains(flag) {
                                            text += "+"
                                        } else {
                                            text += "-"
                                        }
                                        appendAttributedText(text: string, withEntities: [.Italic], to: &text, entities: &entities)
                                    }
                                }
                            }
                            
                            if prevRank != newRank {
                                if appendedRightsHeader {
                                    text += "\n\n"
                                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageRank(newRank ?? ""), generateEntities: { index in
                                        var result: [MessageTextEntityType] = []
                                        if index == 0 {
                                            result.append(.Bold)
                                        }
                                        return result
                                    }, to: &text, entities: &entities)
                                } else {
                                    appendAttributedText(text: new.peer.addressName == nil ? self.presentationData.strings.Channel_AdminLog_MessageRankName(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), newRank ?? "") : self.presentationData.strings.Channel_AdminLog_MessageRankUsername(EnginePeer(new.peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), "@" + new.peer.addressName!, newRank ?? ""), generateEntities: { index in
                                        var result: [MessageTextEntityType] = []
                                        if index == 0 {
                                            result.append(.TextMention(peerId: new.peer.id))
                                        } else if index == 1 {
                                            result.append(.Mention)
                                        } else if index == 2 {
                                            result.append(.Bold)
                                        }
                                        return result
                                    }, to: &text, entities: &entities)
                                }
                            }
                        }
                    }
                }
            
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                
                for attribute in attributes {
                    for peerId in attribute.associatedPeerIds {
                        if let peer = self.entry.peers[peerId] {
                            peers[peer.id] = peer
                        }
                    }
                }
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: text, attributes: attributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .changeStickerPack(_, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                if new != nil {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedGroupStickerPack(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageRemovedGroupStickerPack(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .togglePreHistoryHidden(value):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                if !value {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageGroupPreHistoryVisible(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageGroupPreHistoryHidden(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .updateDefaultBannedRights(prev, new):
                var peers = SimpleDictionary<PeerId, Peer>()
                var attributes: [MessageAttribute] = []
                
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                peers[peer.id] = filterMessageChannelPeer(peer)
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                var addedRights = new.flags
                var removedRights: TelegramChatBannedRightsFlags = []
                    addedRights = addedRights.subtracting(prev.flags)
                removedRights = prev.flags.subtracting(new.flags)
        
                text += self.presentationData.strings.Channel_AdminLog_DefaultRestrictionsUpdated
                text += "\n"
        
                let order: [(TelegramChatBannedRightsFlags, String)] = [
                    (.banReadMessages, self.presentationData.strings.Channel_AdminLog_BanReadMessages),
                    (.banSendText, self.presentationData.strings.Channel_AdminLog_BanSendMessages),
                    (.banSendMedia, self.presentationData.strings.Channel_AdminLog_BanSendMedia),
                    (.banSendStickers, self.presentationData.strings.Channel_AdminLog_BanSendStickersAndGifs),
                    (.banEmbedLinks, self.presentationData.strings.Channel_AdminLog_BanEmbedLinks),
                    (.banSendPolls, self.presentationData.strings.Channel_AdminLog_SendPolls),
                    (.banAddMembers, self.presentationData.strings.Channel_AdminLog_AddMembers),
                    (.banPinMessages, self.presentationData.strings.Channel_AdminLog_PinMessages),
                    (.banManageTopics, self.presentationData.strings.Channel_AdminLog_ManageTopics),
                    (.banChangeInfo, self.presentationData.strings.Channel_AdminLog_ChangeInfo)
                ]
        
                for (flag, string) in order {
                    if addedRights.contains(flag) {
                        text += "\n-"
                        appendAttributedText(text: string, withEntities: [.Italic], to: &text, entities: &entities)
                    }
                    if removedRights.contains(flag) {
                        text += "\n+"
                        appendAttributedText(text: string, withEntities: [.Italic], to: &text, entities: &entities)
                    }
                }
                
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                
                for attribute in attributes {
                    for peerId in attribute.associatedPeerIds {
                        if let peer = self.entry.peers[peerId] {
                            peers[peer.id] = peer
                        }
                    }
                }
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: text, attributes: attributes, media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .pollStopped(message):
                switch self.id.contentIndex {
                    case .header:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var author: Peer?
                        if let peer = self.entry.peers[self.entry.event.peerId] {
                            author = peer
                            peers[peer.id] = peer
                        }
                        
                        var text: String = ""
                        var entities: [MessageTextEntity] = []
                        
                        let titleText: PresentationStrings.FormattedString
                        
                        titleText = self.presentationData.strings.Channel_AdminLog_PollStopped(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                        
                        appendAttributedText(text: titleText, generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                        
                        let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var attributes: [MessageAttribute] = []
                        for attribute in message.attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                attributes.append(attribute)
                            }
                            if let attribute = attribute as? ReplyMessageAttribute {
                                attributes.append(attribute)
                            }
                        }
                        for attribute in attributes {
                            for peerId in attribute.associatedPeerIds {
                                if let peer = self.entry.peers[peerId] {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        if let peer = self.entry.peers[message.id.peerId] {
                            peers[peer.id] = peer
                        }
                        let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: message.author, text: message.text, attributes: attributes, media: message.media, peers: peers, associatedMessages: message.associatedMessages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: message.associatedThreadInfo, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: filterOriginalMessageFlags(message), read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil), additionalContent: nil)
                }
            case let .linkedPeerUpdated(previous, updated):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                if let updated = updated {
                    if let peer = peer as? TelegramChannel, case .group = peer.info {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedLinkedChannel(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", EnginePeer(updated).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            } else if index == 1 {
                                return [.TextMention(peerId: updated.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    } else {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedLinkedGroup(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", EnginePeer(updated).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            } else if index == 1 {
                                return [.TextMention(peerId: updated.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    }
                } else {
                    if let peer = peer as? TelegramChannel, case .group = peer.info {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedUnlinkedChannel(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", previous.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            } else if index == 1, let previous = previous {
                                return [.TextMention(peerId: previous.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    } else {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedUnlinkedGroup(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", previous.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            } else if index == 0, let previous = previous {
                                return [.TextMention(peerId: previous.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    }
                }
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .changeGeoLocation(_, updated):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                if let updated = updated {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedGroupGeoLocation(updated.address.replacingOccurrences(of: "\n", with: ", ")), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                    
                    let mediaMap = TelegramMediaMap(latitude: updated.latitude, longitude: updated.longitude, heading: nil, accuracyRadius: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
                    
                    let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: text, attributes: [], media: [mediaMap], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                    return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                } else {                    
                    let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                    
                    let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                    return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                }
            case let .updateSlowmode(_, newValue):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                if let newValue = newValue {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_SetSlowmode(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", shortTimeIntervalString(strings: self.presentationData.strings, value: newValue)), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_DisabledSlowmode(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case .startGroupCall, .endGroupCall:
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString
                if case .startGroupCall = self.entry.event.action {
                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                        rawText = self.presentationData.strings.Channel_AdminLog_StartedLiveStream(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                    } else {
                        rawText = self.presentationData.strings.Channel_AdminLog_StartedVoiceChat(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                    }
                } else {
                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                        rawText = self.presentationData.strings.Channel_AdminLog_EndedLiveStream(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                    } else {
                        rawText = self.presentationData.strings.Channel_AdminLog_EndedVoiceChat(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                    }
                }
                    
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .groupCallUpdateParticipantMuteStatus(participantId, isMuted):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                var participant: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                if let participantPeer = self.entry.peers[participantId] {
                    participant = participantPeer
                    peers[peer.id] = participantPeer
                }
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString
                if isMuted {
                    rawText = self.presentationData.strings.Channel_AdminLog_MutedParticipant(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", participant.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                } else {
                    rawText = self.presentationData.strings.Channel_AdminLog_UnmutedMutedParticipant(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", participant.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                }
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .updateGroupCallSettings(joinMuted):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString
                if joinMuted {
                    rawText = self.presentationData.strings.Channel_AdminLog_MutedNewMembers(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                } else {
                    rawText = self.presentationData.strings.Channel_AdminLog_AllowedNewMembersToSpeak(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                }
                    
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .groupCallUpdateParticipantVolume(participantId, volume):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                var participant: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                if let participantPeer = self.entry.peers[participantId] {
                    participant = participantPeer
                    peers[peer.id] = participantPeer
                }
                
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString = self.presentationData.strings.Channel_AdminLog_UpdatedParticipantVolume(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", participant.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", "\(volume / 100)%")
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .deleteExportedInvitation(invite):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
 
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString = self.presentationData.strings.Channel_AdminLog_DeletedInviteLink(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", invite.link?.replacingOccurrences(of: "https://", with: "") ?? "")
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .revokeExportedInvitation(invite):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
 
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString = self.presentationData.strings.Channel_AdminLog_RevokedInviteLink(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", invite.link?.replacingOccurrences(of: "https://", with: "") ?? "")
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .editExportedInvitation(_, updatedInvite):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
 
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString = self.presentationData.strings.Channel_AdminLog_EditedInviteLink(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", updatedInvite.link?.replacingOccurrences(of: "https://", with: "") ?? "")
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .participantJoinedViaInvite(invite, joinedViaFolderLink):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
 
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString
                if joinedViaFolderLink {
                    rawText = self.presentationData.strings.Channel_AdminLog_JoinedViaFolderInviteLink(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", invite.link?.replacingOccurrences(of: "https://", with: "") ?? "")
                } else {
                    rawText = self.presentationData.strings.Channel_AdminLog_JoinedViaInviteLink(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", invite.link?.replacingOccurrences(of: "https://", with: "") ?? "")
                }
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .changeHistoryTTL(_, updatedValue):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
 
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString
                if let updatedValue = updatedValue {
                    rawText = self.presentationData.strings.Channel_AdminLog_MessageChangedAutoremoveTimeoutSet(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", timeIntervalString(strings: self.presentationData.strings, value: updatedValue))
                } else {
                    rawText = self.presentationData.strings.Channel_AdminLog_MessageChangedAutoremoveTimeoutRemove(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                }
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .changeAvailableReactions(_, updatedValue):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }

                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                switch updatedValue {
                case .all:
                    let rawText = self.presentationData.strings.Channel_AdminLog_ReactionsEnabled(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                    appendAttributedText(text: rawText, generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        } else if index == 1 {
                            return [.Bold]
                        }
                        return []
                    }, to: &text, entities: &entities)
                case let .limited(reactions):
                    let authorTitle = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
                    let rawText = self.presentationData.strings.Channel_AdminLog_AllowedReactionsUpdated(authorTitle, "")
                    var previousIndex = 0
                    let nsText = rawText.string as NSString
                    for range in rawText.ranges.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
                        if range.range.lowerBound > previousIndex {
                            text.append(nsText.substring(with: NSRange(location: previousIndex, length: range.range.lowerBound - previousIndex)))
                        }
                        if range.index == 0 {
                            if let author {
                                entities.append(MessageTextEntity(range: (text as NSString).length ..< (text as NSString).length + (authorTitle as NSString).length, type: .TextMention(peerId: author.id)))
                            }
                            text.append(authorTitle)
                        } else if range.index == 1 {
                            for reaction in reactions {
                                let reactionText: String
                                switch reaction {
                                case let .builtin(value):
                                    reactionText = value
                                    text.append(reactionText)
                                case let .custom(fileId):
                                    reactionText = "."
                                    entities.append(MessageTextEntity(range: (text as NSString).length ..< (text as NSString).length + (reactionText as NSString).length, type: .CustomEmoji(stickerPack: nil, fileId: fileId)))
                                    text.append(reactionText)
                                case .stars:
                                    break
                                }
                            }
                        }
                        previousIndex = range.range.upperBound
                    }
                    if nsText.length > previousIndex {
                        text.append(nsText.substring(with: NSRange(location: previousIndex, length: nsText.length - previousIndex)))
                    }
                case .empty:
                    let rawText = self.presentationData.strings.Channel_AdminLog_ReactionsDisabled(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                    appendAttributedText(text: rawText, generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        } else if index == 1 {
                            return [.Bold]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .changeTheme(_, updatedValue):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
 
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString
                if let updatedValue = updatedValue {
                    rawText = self.presentationData.strings.Channel_AdminLog_MessageChangedThemeSet(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", updatedValue)
                } else {
                    rawText = self.presentationData.strings.Channel_AdminLog_MessageChangedThemeRemove(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                }
                
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .participantJoinByRequest(invite, approvedBy):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                var approver: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                if let peer = self.entry.peers[approvedBy] {
                    approver = peer
                    peers[approvedBy] = approver
                }

                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let rawText: PresentationStrings.FormattedString
                switch invite {
                    case let .link(link, _, _, _, _, _, _, _, _, _, _, _, _):
                        rawText = self.presentationData.strings.Channel_AdminLog_JoinedViaRequest(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", link.replacingOccurrences(of: "https://", with: ""), approver.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                    case .publicJoinRequest:
                        rawText = self.presentationData.strings.Channel_AdminLog_JoinedViaPublicRequest(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", approver.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "")
                }
  
            
                appendAttributedText(text: rawText, generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.Bold]
                    } else if index == 2, let approver = approver {
                        return [.TextMention(peerId: approver.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .toggleCopyProtection(value):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                if value {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageToggleNoForwardsOn(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageToggleNoForwardsOff(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .sendMessage(message):
                switch self.id.contentIndex {
                    case .header:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var author: Peer?
                        if self.entry.event.peerId == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(136817688)) {
                            author = message.effectiveAuthor
                        } else if let peer = self.entry.peers[self.entry.event.peerId] {
                            author = peer
                            peers[peer.id] = peer
                        }
                        var text: String = ""
                        var entities: [MessageTextEntity] = []

                        let textFormat = self.presentationData.strings.Channel_AdminLog_MessageSent
                        appendAttributedText(text: textFormat(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                        
                        let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                        let message = Message(stableId: self.entry.headerStableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
                    case .content:
                        var peers = SimpleDictionary<PeerId, Peer>()
                        var attributes: [MessageAttribute] = []
                        for attribute in message.attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                attributes.append(attribute)
                            }
                            if let attribute = attribute as? ReplyMessageAttribute {
                                attributes.append(attribute)
                            }
                        }
                        for attribute in attributes {
                            for peerId in attribute.associatedPeerIds {
                                if let peer = self.entry.peers[peerId] {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        if let peer = self.entry.peers[message.id.peerId] {
                            peers[peer.id] = peer
                        }
                        let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: message.effectiveAuthor, text: message.text, attributes: attributes, media: message.media, peers: peers, associatedMessages: message.associatedMessages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: message.associatedThreadInfo, associatedStories: [:])
                        return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            }
            case let .createTopic(info):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicCreated(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? "", info.title), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .deleteTopic(info):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
            
                let authorTitle: String = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
                appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicDeleted(authorTitle, info.title), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .editTopic(prevInfo, newInfo):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let authorTitle: String = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
                if prevInfo.isHidden != newInfo.isHidden {
                    appendAttributedText(text: newInfo.isHidden ? self.presentationData.strings.Channel_AdminLog_TopicHidden(authorTitle, newInfo.info.title) : self.presentationData.strings.Channel_AdminLog_TopicUnhidden(authorTitle, newInfo.info.title), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else if prevInfo.isClosed != newInfo.isClosed {
                    appendAttributedText(text: newInfo.isClosed ? self.presentationData.strings.Channel_AdminLog_TopicClosed(authorTitle, newInfo.info.title) : self.presentationData.strings.Channel_AdminLog_TopicReopened(authorTitle, newInfo.info.title), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else if prevInfo.info.title != newInfo.info.title && prevInfo.info.icon != newInfo.info.icon {
                    if let fileId = newInfo.info.icon {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicRenamedWithIcon(authorTitle, prevInfo.info.title, newInfo.info.title, "."), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            } else if index == 3 {
                                return [.CustomEmoji(stickerPack: nil, fileId: fileId)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    } else {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicRenamedWithRemovedIcon(authorTitle, prevInfo.info.title, newInfo.info.title), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    }
                } else if prevInfo.info.icon != newInfo.info.icon {
                    if let fileId = newInfo.info.icon {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicChangedIcon(authorTitle, newInfo.info.title, "."), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            } else if index == 2 {
                                return [.CustomEmoji(stickerPack: nil, fileId: fileId)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    } else {
                        appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicRemovedIcon(authorTitle, newInfo.info.title), generateEntities: { index in
                            if index == 0, let author = author {
                                return [.TextMention(peerId: author.id)]
                            }
                            return []
                        }, to: &text, entities: &entities)
                    }
                } else {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicRenamed(authorTitle, prevInfo.info.title, newInfo.info.title), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .pinTopic(prevInfo, newInfo):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
            
                let authorTitle: String = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
            
                if let newInfo = newInfo {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicPinned(authorTitle, newInfo.title), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else if let prevInfo = prevInfo {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicUnpinned(authorTitle, prevInfo.title), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                } else {
                    appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_TopicUnpinned(authorTitle, ""), generateEntities: { index in
                        if index == 0, let author = author {
                            return [.TextMention(peerId: author.id)]
                        }
                        return []
                    }, to: &text, entities: &entities)
                }
                
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .toggleForum(isForum):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let authorTitle: String = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
                appendAttributedText(text: isForum ? self.presentationData.strings.Channel_AdminLog_TopicsEnabled(authorTitle) : self.presentationData.strings.Channel_AdminLog_TopicsDisabled(authorTitle), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
            
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
            case let .toggleAntiSpam(isEnabled):
                var peers = SimpleDictionary<PeerId, Peer>()
                var author: Peer?
                if let peer = self.entry.peers[self.entry.event.peerId] {
                    author = peer
                    peers[peer.id] = peer
                }
                var text: String = ""
                var entities: [MessageTextEntity] = []
                
                let authorTitle: String = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
                appendAttributedText(text: isEnabled ? self.presentationData.strings.Channel_AdminLog_AntiSpamEnabled(authorTitle) : self.presentationData.strings.Channel_AdminLog_AntiSpamDisabled(authorTitle), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
            
                let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
                let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
        case let .changeNameColor(_, _, updatedColor, updatedIcon):
            var peers = SimpleDictionary<PeerId, Peer>()
            var author: Peer?
            if let peer = self.entry.peers[self.entry.event.peerId] {
                author = peer
                peers[peer.id] = peer
            }
            let authorTitle = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""

            var text: String = ""
            var entities: [MessageTextEntity] = []
            var additionalAttributes: [(NSRange, NSAttributedString.Key, Any)] = []
            
            if let updatedIcon {
                let rawText = self.presentationData.strings.Channel_AdminLog_ChannelChangedNameColorAndIcon(authorTitle, ".", ".")
                
                let colors = context.peerNameColors.get(updatedColor)
                var colorList: [UInt32] = []
                colorList.append(colors.main.argb)
                if let secondary = colors.secondary {
                    colorList.append(secondary.argb)
                }
                if let tertiary = colors.tertiary {
                    colorList.append(tertiary.argb)
                }
                
                appendAttributedText(text: rawText, additionalAttributes: &additionalAttributes, generateEntities: { index in
                    if index == 0, let author = author {
                        return ([.TextMention(peerId: author.id)], [:])
                    } else if index == 1 {
                        return ([], [
                            ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .nameColors(colorList))
                        ])
                    } else if index == 2 {
                        return ([.CustomEmoji(stickerPack: nil, fileId: updatedIcon)], [:])
                    } else {
                        return ([], [:])
                    }
                }, to: &text, entities: &entities)
            } else {
                let rawText = self.presentationData.strings.Channel_AdminLog_ChannelChangedNameColor(authorTitle, ".")
                
                let colors = context.peerNameColors.get(updatedColor)
                var colorList: [UInt32] = []
                colorList.append(colors.main.argb)
                if let secondary = colors.secondary {
                    colorList.append(secondary.argb)
                }
                if let tertiary = colors.tertiary {
                    colorList.append(tertiary.argb)
                }
                
                appendAttributedText(text: rawText, additionalAttributes: &additionalAttributes, generateEntities: { index in
                    if index == 0, let author = author {
                        return ([.TextMention(peerId: author.id)], [:])
                    } else if index == 1 {
                        return ([], [
                            ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .nameColors(colorList))
                        ])
                    } else {
                        return ([], [:])
                    }
                }, to: &text, entities: &entities)
            }
            
            let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: TelegramMediaActionType.CustomTextAttributes(attributes: additionalAttributes))
            
            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
        case let .changeProfileColor(_, _, updatedColor, updatedIcon):
            var peers = SimpleDictionary<PeerId, Peer>()
            var author: Peer?
            if let peer = self.entry.peers[self.entry.event.peerId] {
                author = peer
                peers[peer.id] = peer
            }
            let authorTitle = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""

            var text: String = ""
            var entities: [MessageTextEntity] = []
            var additionalAttributes: [(NSRange, NSAttributedString.Key, Any)] = []
            
            if let updatedColor, let updatedIcon {
                let rawText = self.presentationData.strings.Channel_AdminLog_ChannelChangedProfileColorAndIcon(authorTitle, ".", ".")
                
                let colors = context.peerNameColors.get(updatedColor)
                var colorList: [UInt32] = []
                colorList.append(colors.main.argb)
                if let secondary = colors.secondary {
                    colorList.append(secondary.argb)
                }
                if let tertiary = colors.tertiary {
                    colorList.append(tertiary.argb)
                }
                
                appendAttributedText(text: rawText, additionalAttributes: &additionalAttributes, generateEntities: { index in
                    if index == 0, let author = author {
                        return ([.TextMention(peerId: author.id)], [:])
                    } else if index == 1 {
                        return ([], [
                            ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .nameColors(colorList))
                        ])
                    } else if index == 2 {
                        return ([.CustomEmoji(stickerPack: nil, fileId: updatedIcon)], [:])
                    } else {
                        return ([], [:])
                    }
                }, to: &text, entities: &entities)
            } else if let updatedColor {
                let rawText = self.presentationData.strings.Channel_AdminLog_ChannelChangedProfileColor(authorTitle, ".")
                
                let colors = context.peerNameColors.get(updatedColor)
                var colorList: [UInt32] = []
                colorList.append(colors.main.argb)
                if let secondary = colors.secondary {
                    colorList.append(secondary.argb)
                }
                if let tertiary = colors.tertiary {
                    colorList.append(tertiary.argb)
                }
                
                appendAttributedText(text: rawText, additionalAttributes: &additionalAttributes, generateEntities: { index in
                    if index == 0, let author = author {
                        return ([.TextMention(peerId: author.id)], [:])
                    } else if index == 1 {
                        return ([], [
                            ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .nameColors(colorList))
                        ])
                    } else {
                        return ([], [:])
                    }
                }, to: &text, entities: &entities)
            } else {
                let rawText = self.presentationData.strings.Channel_AdminLog_ChannelRemovedProfileColorAndIcon(authorTitle)
                
                appendAttributedText(text: rawText, additionalAttributes: &additionalAttributes, generateEntities: { index in
                    if index == 0, let author = author {
                        return ([.TextMention(peerId: author.id)], [:])
                    } else {
                        return ([], [:])
                    }
                }, to: &text, entities: &entities)
            }
            
            let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: TelegramMediaActionType.CustomTextAttributes(attributes: additionalAttributes))
            
            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
        case let .changeStatus(_, status):
            var peers = SimpleDictionary<PeerId, Peer>()
            var author: Peer?
            if let peer = self.entry.peers[self.entry.event.peerId] {
                author = peer
                peers[peer.id] = peer
            }
            
            let authorTitle: String = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
            
            var text: String = ""
            var entities: [MessageTextEntity] = []
            
            if let status {
                appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_ChannelUpdatedStatus(authorTitle, "."), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    } else if index == 1 {
                        return [.CustomEmoji(stickerPack: nil, fileId: status.fileId)]
                    }
                    return []
                }, to: &text, entities: &entities)
            } else {
                appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_ChannelRemovedStatus(authorTitle), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
            }
            
            let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
            
            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
        case let .changeWallpaper(_, wallpaper):
            var peers = SimpleDictionary<PeerId, Peer>()
            var author: Peer?
            if let peer = self.entry.peers[self.entry.event.peerId] {
                author = peer
                peers[peer.id] = peer
            }
            
            let authorTitle: String = author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
            
            var text: String = ""
            var entities: [MessageTextEntity] = []
            
            let action: TelegramMediaActionType
            if let wallpaper {
                action = TelegramMediaActionType.setChatWallpaper(wallpaper: wallpaper, forBoth: false)
            } else {
                appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_ChannelRemovedWallpaper(authorTitle), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
                action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
            }
            
            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil, chatThemes: chatThemes), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
        case let .changeEmojiPack(_, new):
            var peers = SimpleDictionary<PeerId, Peer>()
            var author: Peer?
            if let peer = self.entry.peers[self.entry.event.peerId] {
                author = peer
                peers[peer.id] = peer
            }
            var text: String = ""
            var entities: [MessageTextEntity] = []
            
            if new != nil {
                appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageChangedGroupEmojiPack(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
            } else {
                appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageRemovedGroupEmojiPack(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                    if index == 0, let author = author {
                        return [.TextMention(peerId: author.id)]
                    }
                    return []
                }, to: &text, entities: &entities)
            }
            let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
            
            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
        case let .participantSubscriptionExtended(_, new):
            var peers = SimpleDictionary<PeerId, Peer>()
            var author: Peer?
            if let peer = self.entry.peers[self.entry.event.peerId] {
                author = peer
                peers[peer.id] = peer
            }
            peers[peer.id] = peer
            for (_, peer) in new.peers {
                peers[peer.id] = peer
            }
            peers[new.peer.id] = new.peer
            
            var text: String = ""
            var entities: [MessageTextEntity] = []
            appendAttributedText(text: self.presentationData.strings.Channel_AdminLog_MessageParticipantSubscriptionExtended(author.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""), generateEntities: { index in
                if index == 0, let author = author {
                    return [.TextMention(peerId: author.id)]
                }
                return []
            }, to: &text, entities: &entities)
            
            let action = TelegramMediaActionType.customText(text: text, entities: entities, additionalAttributes: nil)
            
            let message = Message(stableId: self.entry.stableId, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(bitPattern: self.entry.stableId)), globallyUniqueId: self.entry.event.id, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: self.entry.event.date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: "", attributes: [], media: [TelegramMediaAction(action: action)], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            return ChatMessageItemImpl(presentationData: self.presentationData, context: context, chatLocation: .peer(id: peer.id), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .channel, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: true, availableReactions: availableReactions, availableMessageEffects: availableMessageEffects, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: nil), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
        }
    }
}

private let deletedMessagesDisplayedLimit = 4

func chatRecentActionsEntries(entries: [ChannelAdminEventLogEntry], presentationData: ChatPresentationData, expandedDeletedMessages: Set<EngineMessage.Id>, currentDeletedHeaderMessages: inout Set<EngineMessage.Id>) -> [ChatRecentActionsEntry] {
    var result: [ChatRecentActionsEntry] = []
    var deleteMessageEntries: [ChannelAdminEventLogEntry] = []
    
    func appendCurrentDeleteEntries() {
        if !deleteMessageEntries.isEmpty, let lastEntry = deleteMessageEntries.last, let lastMessageId = lastEntry.event.action.messageId {
            let isExpandable = deleteMessageEntries.count >= deletedMessagesDisplayedLimit
            let isExpanded = expandedDeletedMessages.contains(lastMessageId) || !isExpandable
            let isGroup = deleteMessageEntries.count > 1
            
            for i in 0 ..< deleteMessageEntries.count {
                let entry = deleteMessageEntries[i]
                let isLast = i == deleteMessageEntries.count - 1
                if isExpanded || isLast {
                    result.append(ChatRecentActionsEntry(id: ChatRecentActionsEntryId(eventId: entry.event.id, contentIndex: .content), presentationData: presentationData, entry: entry, subEntries: isGroup && isExpandable ? deleteMessageEntries : [], isExpanded: isExpandable && isLast ? isExpanded : nil))
                }
            }

            currentDeletedHeaderMessages.insert(lastMessageId)
            result.append(ChatRecentActionsEntry(id: ChatRecentActionsEntryId(eventId: lastEntry.event.id, contentIndex: .header), presentationData: presentationData, entry: lastEntry, subEntries: isGroup ? deleteMessageEntries : [], isExpanded: isExpandable ? isExpanded : nil))
            
            deleteMessageEntries = []
        }
    }
    
    for entry in entries.reversed() {
        let currentDeleteMessageEvent = deleteMessageEntries.first?.event
        var skipAppendingGeneralEntry = false
        if case let .deleteMessage(message) = entry.event.action {
            var skipAppendingDeletionEntry = false
            if currentDeleteMessageEvent == nil || (currentDeleteMessageEvent!.peerId == entry.event.peerId && abs(currentDeleteMessageEvent!.date - entry.event.date) < 5 && !currentDeletedHeaderMessages.contains(message.id)) {
            } else {
                if currentDeletedHeaderMessages.contains(message.id) {
                    deleteMessageEntries.append(entry)
                    skipAppendingDeletionEntry = true
                }
                appendCurrentDeleteEntries()
            }
            if !skipAppendingDeletionEntry {
                deleteMessageEntries.append(entry)
            }
            skipAppendingGeneralEntry = true
        }
        if !skipAppendingGeneralEntry {
            appendCurrentDeleteEntries()
            
            result.append(ChatRecentActionsEntry(id: ChatRecentActionsEntryId(eventId: entry.event.id, contentIndex: .content), presentationData: presentationData, entry: entry, subEntries: [], isExpanded: nil))
            if eventNeedsHeader(entry.event) {
                result.append(ChatRecentActionsEntry(id: ChatRecentActionsEntryId(eventId: entry.event.id, contentIndex: .header), presentationData: presentationData, entry: entry, subEntries: [], isExpanded: nil))
            }
        }
    }
    appendCurrentDeleteEntries()
    
//    assert(result == result.sorted().reversed())
    return result
}

struct ChatRecentActionsHistoryTransition {
    let filteredEntries: [ChatRecentActionsEntry]
    let type: ChannelAdminEventLogUpdateType
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let canLoadEarlier: Bool
    let displayingResults: Bool
    let searchResultsState: (String, [MessageIndex])?
    var synchronous: Bool
    let isEmpty: Bool
}

func chatRecentActionsHistoryPreparedTransition(from fromEntries: [ChatRecentActionsEntry], to toEntries: [ChatRecentActionsEntry], type: ChannelAdminEventLogUpdateType, canLoadEarlier: Bool, displayingResults: Bool, context: AccountContext, peer: Peer, controllerInteraction: ChatControllerInteraction, chatThemes: [TelegramTheme], availableReactions: AvailableReactions?, searchResultsState: (String, [MessageIndex])?, toggledDeletedMessageIds: Set<EngineMessage.Id>) -> ChatRecentActionsHistoryTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdatesReversed(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, peer: peer, controllerInteraction: controllerInteraction, chatThemes: chatThemes, availableReactions: availableReactions, availableMessageEffects: nil), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, peer: peer, controllerInteraction: controllerInteraction, chatThemes: chatThemes, availableReactions: availableReactions, availableMessageEffects: nil), directionHint: nil) }
    
    return ChatRecentActionsHistoryTransition(filteredEntries: toEntries, type: type, deletions: deletions, insertions: insertions, updates: updates, canLoadEarlier: canLoadEarlier, displayingResults: displayingResults, searchResultsState: searchResultsState, synchronous: !toggledDeletedMessageIds.isEmpty, isEmpty: toEntries.isEmpty)
}
