import Foundation
import Postbox
import TelegramCore
import TemporaryCachedPeerDataManager
import Emoji
import AccountContext
import TelegramPresentationData

func chatHistoryEntriesForView(
    location: ChatLocation,
    view: MessageHistoryView,
    includeUnreadEntry: Bool,
    includeEmptyEntry: Bool,
    includeChatInfoEntry: Bool,
    includeSearchEntry: Bool,
    reverse: Bool,
    groupMessages: Bool,
    selectedMessages: Set<MessageId>?,
    presentationData: ChatPresentationData,
    historyAppearsCleared: Bool,
    pendingUnpinnedAllMessages: Bool,
    pendingRemovedMessages: Set<MessageId>,
    associatedData: ChatMessageItemAssociatedData,
    updatingMedia: [MessageId: ChatUpdatingMessageMedia],
    customChannelDiscussionReadState: MessageId?,
    customThreadOutgoingReadState: MessageId?,
    cachedData: CachedPeerData?,
    adMessages: [Message]
) -> [ChatHistoryEntry] {
    if historyAppearsCleared {
        return []
    }
    var entries: [ChatHistoryEntry] = []
    var adminRanks: [PeerId: CachedChannelAdminRank] = [:]
    var stickersEnabled = true
    var channelPeer: Peer?
    if case let .peer(peerId) = location, peerId.namespace == Namespaces.Peer.CloudChannel {
        for additionalEntry in view.additionalData {
            if case let .cacheEntry(id, data) = additionalEntry {
                if id == cachedChannelAdminRanksEntryId(peerId: peerId), let data = data?.get(CachedChannelAdminRanks.self) {
                    adminRanks = data.ranks
                }
            } else if case let .peer(_, peer) = additionalEntry, let channel = peer as? TelegramChannel, !channel.flags.contains(.isGigagroup) {
                channelPeer = channel
                if let defaultBannedRights = channel.defaultBannedRights, defaultBannedRights.flags.contains(.banSendStickers) {
                    stickersEnabled = false
                }
            }
        }
    }
    
    var joinMessage: Message?
    if case let .peer(peerId) = location, case let cachedData = cachedData as? CachedChannelData, let invitedOn = cachedData?.invitedOn  {
        joinMessage = Message(
            stableId: UInt32.max - 1000,
            stableVersion: 0,
            id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: 0),
            globallyUniqueId: nil,
            groupingKey: nil,
            groupInfo: nil,
            threadId: nil,
            timestamp: invitedOn,
            flags: [.Incoming],
            tags: [],
            globalTags: [],
            localTags: [],
            forwardInfo: nil,
            author: channelPeer,
            text: "",
            attributes: [],
            media: [TelegramMediaAction(action: .joinedByRequest)],
            peers: SimpleDictionary<PeerId, Peer>(),
            associatedMessages: SimpleDictionary<MessageId, Message>(),
            associatedMessageIds: []
        )
    }
        
    var groupBucket: [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes, MessageHistoryEntryLocation?)] = []
    var count = 0
    loop: for entry in view.entries {
        var message = entry.message
        var isRead = entry.isRead
        
        if pendingRemovedMessages.contains(message.id) {
            continue
        }
        
        if let maybeJoinMessage = joinMessage {
            if message.timestamp > maybeJoinMessage.timestamp, (!view.holeEarlier || count > 0) {
                entries.append(.MessageEntry(maybeJoinMessage, presentationData, false, nil, .none, ChatMessageEntryAttributes(rank: nil, isContact: false, contentTypeHint: .generic, updatingMedia: nil, isPlaying: false, isCentered: false)))
                joinMessage = nil
            }
        }
        count += 1
        
        if let customThreadOutgoingReadState = customThreadOutgoingReadState {
            isRead = customThreadOutgoingReadState >= message.id
        }
        
        if let customChannelDiscussionReadState = customChannelDiscussionReadState {
            attibuteLoop: for i in 0 ..< message.attributes.count {
                if let attribute = message.attributes[i] as? ReplyThreadMessageAttribute {
                    if let maxReadMessageId = attribute.maxReadMessageId {
                        if maxReadMessageId < customChannelDiscussionReadState.id {
                            var attributes = message.attributes
                            attributes[i] = ReplyThreadMessageAttribute(count: attribute.count, latestUsers: attribute.latestUsers, commentsPeerId: attribute.commentsPeerId, maxMessageId: attribute.maxMessageId, maxReadMessageId: customChannelDiscussionReadState.id)
                            message = message.withUpdatedAttributes(attributes)
                        }
                    }
                    break attibuteLoop
                }
            }
        }
        
        var contentTypeHint: ChatMessageEntryContentType = .generic
        
        for media in message.media {
            if media is TelegramMediaDice {
                contentTypeHint = .animatedEmoji
            }
            if let action = media as? TelegramMediaAction {
                switch action.action {
                    case .channelMigratedFromGroup, .groupMigratedToChannel, .historyCleared:
                        continue loop
                    default:
                        break
                }
            }
        }
    
        var adminRank: CachedChannelAdminRank?
        if let author = message.author {
            adminRank = adminRanks[author.id]
        }
        
        if presentationData.largeEmoji, message.media.isEmpty {
            if stickersEnabled && message.text.count == 1, let _ = associatedData.animatedEmojiStickers[message.text.basicEmoji.0], (message.textEntitiesAttribute?.entities.isEmpty ?? true) {
                contentTypeHint = .animatedEmoji
            } else if message.text.count < 10 && messageIsElligibleForLargeEmoji(message) {
                contentTypeHint = .largeEmoji
            }
        }
    
        if groupMessages {
            if !groupBucket.isEmpty && message.groupInfo != groupBucket[0].0.groupInfo {
                entries.append(.MessageGroupEntry(groupBucket[0].0.groupInfo!, groupBucket, presentationData))
                groupBucket.removeAll()
            }
            if let _ = message.groupInfo {
                let selection: ChatHistoryMessageSelection
                if let selectedMessages = selectedMessages {
                    selection = .selectable(selected: selectedMessages.contains(message.id))
                } else {
                    selection = .none
                }
                groupBucket.append((message, isRead, selection, ChatMessageEntryAttributes(rank: adminRank, isContact: entry.attributes.authorIsContact, contentTypeHint: contentTypeHint, updatingMedia: updatingMedia[message.id], isPlaying: false, isCentered: false), entry.location))
            } else {
                let selection: ChatHistoryMessageSelection
                if let selectedMessages = selectedMessages {
                    selection = .selectable(selected: selectedMessages.contains(message.id))
                } else {
                    selection = .none
                }
                entries.append(.MessageEntry(message, presentationData, isRead, entry.location, selection, ChatMessageEntryAttributes(rank: adminRank, isContact: entry.attributes.authorIsContact, contentTypeHint: contentTypeHint, updatingMedia: updatingMedia[message.id], isPlaying: message.index == associatedData.currentlyPlayingMessageId, isCentered: false)))
            }
        } else {
            let selection: ChatHistoryMessageSelection
            if let selectedMessages = selectedMessages {
                selection = .selectable(selected: selectedMessages.contains(message.id))
            } else {
                selection = .none
            }
            entries.append(.MessageEntry(message, presentationData, isRead, entry.location, selection, ChatMessageEntryAttributes(rank: adminRank, isContact: entry.attributes.authorIsContact, contentTypeHint: contentTypeHint, updatingMedia: updatingMedia[message.id], isPlaying: message.index == associatedData.currentlyPlayingMessageId, isCentered: false)))
        }
    }
    
    if !groupBucket.isEmpty {
        assert(groupMessages)
        entries.append(.MessageGroupEntry(groupBucket[0].0.groupInfo!, groupBucket, presentationData))
    }
    
    if let maybeJoinMessage = joinMessage, !view.holeLater {
        entries.append(.MessageEntry(maybeJoinMessage, presentationData, false, nil, .none, ChatMessageEntryAttributes(rank: nil, isContact: false, contentTypeHint: .generic, updatingMedia: nil, isPlaying: false, isCentered: false)))
        joinMessage = nil
    }
    
    if let maxReadIndex = view.maxReadIndex, includeUnreadEntry {
        var i = 0
        let unreadEntry: ChatHistoryEntry = .UnreadEntry(maxReadIndex, presentationData)
        for entry in entries {
            if entry > unreadEntry {
                if i != 0 {
                    entries.insert(unreadEntry, at: i)
                }
                break
            }
            i += 1
        }
    }
    
    var addedThreadHead = false
    if case let .replyThread(replyThreadMessage) = location, view.earlierId == nil, !view.holeEarlier, !view.isLoading {
        loop: for entry in view.additionalData {
            switch entry {
            case let .message(id, messages) where id == replyThreadMessage.effectiveTopId:
                if !messages.isEmpty {
                    let selection: ChatHistoryMessageSelection = .none
                    
                    let topMessage = messages[0]
                    
                    var adminRank: CachedChannelAdminRank?
                    if let author = topMessage.author {
                        adminRank = adminRanks[author.id]
                    }
                    
                    var contentTypeHint: ChatMessageEntryContentType = .generic
                    if presentationData.largeEmoji, topMessage.media.isEmpty {
                        if stickersEnabled && topMessage.text.count == 1, let _ = associatedData.animatedEmojiStickers[topMessage.text.basicEmoji.0] {
                            contentTypeHint = .animatedEmoji
                        } else if topMessage.text.count < 10 && messageIsElligibleForLargeEmoji(topMessage) {
                            contentTypeHint = .largeEmoji
                        }
                    }
                    
                    addedThreadHead = true
                    if messages.count > 1, let groupInfo = messages[0].groupInfo {
                        var groupMessages: [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes, MessageHistoryEntryLocation?)] = []
                        for message in messages {
                            groupMessages.append((message, false, .none, ChatMessageEntryAttributes(rank: adminRank, isContact: false, contentTypeHint: contentTypeHint, updatingMedia: updatingMedia[message.id], isPlaying: false, isCentered: false), nil))
                        }
                        entries.insert(.MessageGroupEntry(groupInfo, groupMessages, presentationData), at: 0)
                    } else {
                        entries.insert(.MessageEntry(messages[0], presentationData, false, nil, selection, ChatMessageEntryAttributes(rank: adminRank, isContact: false, contentTypeHint: contentTypeHint, updatingMedia: updatingMedia[messages[0].id], isPlaying: false, isCentered: false)), at: 0)
                    }
                    
                    let replyCount = view.entries.isEmpty ? 0 : 1
                    
                    entries.insert(.ReplyCountEntry(messages[0].index, replyThreadMessage.isChannelPost, replyCount, presentationData), at: 1)
                }
                break loop
            default:
                break
            }
        }
    }
    
    if includeChatInfoEntry {
        if view.earlierId == nil, !view.isLoading {
            var cachedPeerData: CachedPeerData?
            for entry in view.additionalData {
                if case let .cachedPeerData(_, data) = entry {
                    cachedPeerData = data
                    break
                }
            }
            if case let .peer(peerId) = location, peerId.isReplies {
                entries.insert(.ChatInfoEntry("", presentationData.strings.RepliesChat_DescriptionText, nil, nil, presentationData), at: 0)
            } else if let cachedPeerData = cachedPeerData as? CachedUserData, let botInfo = cachedPeerData.botInfo, !botInfo.description.isEmpty {
                entries.insert(.ChatInfoEntry(presentationData.strings.Bot_DescriptionTitle, botInfo.description, botInfo.photo, botInfo.video, presentationData), at: 0)
            } else {
                var isEmpty = true
                if entries.count <= 3 {
                    loop: for entry in view.entries {
                        var isEmptyMedia = false
                        var isPeerJoined = false
                        for media in entry.message.media {
                            if let action = media as? TelegramMediaAction {
                                switch action.action {
                                    case .groupCreated, .photoUpdated, .channelMigratedFromGroup, .groupMigratedToChannel:
                                        isEmptyMedia = true
                                    case .peerJoined:
                                        isPeerJoined = true
                                    default:
                                        break
                                }
                            }
                        }
                        var isCreator = false
                        if let peer = entry.message.peers[entry.message.id.peerId] as? TelegramGroup, case .creator = peer.role {
                            isCreator = true
                        } else if let peer = entry.message.peers[entry.message.id.peerId] as? TelegramChannel, case .group = peer.info, peer.flags.contains(.isCreator) {
                            isCreator = true
                        }
                        if isPeerJoined || (isEmptyMedia && isCreator) {
                        } else {
                            isEmpty = false
                            break loop
                        }
                    }
                } else {
                    isEmpty = false
                }
                if addedThreadHead {
                    isEmpty = false
                }
                if isEmpty {
                    entries.removeAll()
                }
            }
        }

        if view.laterId == nil && !view.isLoading {
            if !entries.isEmpty, case let .MessageEntry(lastMessage, _, _, _, _, _) = entries[entries.count - 1], !adMessages.isEmpty {
                var nextAdMessageId: Int32 = 1
                for message in adMessages {
                    let updatedMessage = Message(
                        stableId: UInt32.max - 1 - UInt32(nextAdMessageId),
                        stableVersion: message.stableVersion,
                        id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: nextAdMessageId),
                        globallyUniqueId: nil,
                        groupingKey: nil,
                        groupInfo: nil,
                        threadId: nil,
                        timestamp: lastMessage.timestamp,
                        flags: message.flags,
                        tags: message.tags,
                        globalTags: message.globalTags,
                        localTags: message.localTags,
                        forwardInfo: message.forwardInfo,
                        author: message.author,
                        text: message.text,
                        attributes: message.attributes,
                        media: message.media,
                        peers: message.peers,
                        associatedMessages: message.associatedMessages,
                        associatedMessageIds: message.associatedMessageIds
                    )
                    nextAdMessageId += 1
                    entries.append(.MessageEntry(updatedMessage, presentationData, false, nil, .none, ChatMessageEntryAttributes(rank: nil, isContact: false, contentTypeHint: .generic, updatingMedia: nil, isPlaying: false, isCentered: false)))
                }
            }
        }
    } else if includeSearchEntry {
        if view.laterId == nil {
            if !view.entries.isEmpty {
                entries.append(.SearchEntry(presentationData.theme.theme, presentationData.strings))
            }
        }
    }
    
    if reverse {
        return entries.reversed()
    } else {
        return entries
    }
}
