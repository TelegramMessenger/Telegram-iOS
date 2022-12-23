import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


enum FetchChatListLocation {
    case general
    case group(PeerGroupId)
}

struct ParsedDialogs {
    let itemIds: [PeerId]
    let peers: [Peer]
    let peerPresences: [PeerId: Api.User]
    
    let notificationSettings: [PeerId: PeerNotificationSettings]
    let readStates: [PeerId: [MessageId.Namespace: PeerReadState]]
    let mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary]
    let reactionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary]
    let channelStates: [PeerId: Int32]
    let topMessageIds: [PeerId: MessageId]
    let storeMessages: [StoreMessage]
    
    let lowerNonPinnedIndex: MessageIndex?
    let referencedFolders: [PeerGroupId: PeerGroupUnreadCountersSummary]
}

private func extractDialogsData(dialogs: Api.messages.Dialogs) -> (apiDialogs: [Api.Dialog], apiMessages: [Api.Message], apiChats: [Api.Chat], apiUsers: [Api.User], apiIsAtLowestBoundary: Bool) {
    switch dialogs {
        case let .dialogs(dialogs, messages, chats, users):
            return (dialogs, messages, chats, users, true)
        case let .dialogsSlice(_, dialogs, messages, chats, users):
            return (dialogs, messages, chats, users, false)
        case .dialogsNotModified:
            assertionFailure()
            return ([], [], [], [], true)
    }
}

private func extractDialogsData(peerDialogs: Api.messages.PeerDialogs) -> (apiDialogs: [Api.Dialog], apiMessages: [Api.Message], apiChats: [Api.Chat], apiUsers: [Api.User], apiIsAtLowestBoundary: Bool) {
    switch peerDialogs {
        case let .peerDialogs(dialogs, messages, chats, users, _):
            return (dialogs, messages, chats, users, false)
    }
}

private func parseDialogs(apiDialogs: [Api.Dialog], apiMessages: [Api.Message], apiChats: [Api.Chat], apiUsers: [Api.User], apiIsAtLowestBoundary: Bool) -> ParsedDialogs {
    var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
    var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
    var mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
    var reactionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
    var channelStates: [PeerId: Int32] = [:]
    var topMessageIds: [PeerId: MessageId] = [:]
    
    var storeMessages: [StoreMessage] = []
    var nonPinnedDialogsTopMessageIds = Set<MessageId>()
    
    var referencedFolders: [PeerGroupId: PeerGroupUnreadCountersSummary] = [:]
    var itemIds: [PeerId] = []
    
    var peers: [PeerId: Peer] = [:]
    var peerPresences: [PeerId: Api.User] = [:]
    for chat in apiChats {
        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
            peers[groupOrChannel.id] = groupOrChannel
        }
    }
    for user in apiUsers {
        let telegramUser = TelegramUser(user: user)
        peers[telegramUser.id] = telegramUser
        peerPresences[telegramUser.id] = user
    }
    
    for dialog in apiDialogs {
        let apiPeer: Api.Peer
        let apiReadInboxMaxId: Int32
        let apiReadOutboxMaxId: Int32
        let apiTopMessage: Int32
        let apiUnreadCount: Int32
        let apiMarkedUnread: Bool
        let apiUnreadMentionsCount: Int32
        let apiUnreadReactionsCount: Int32
        var apiChannelPts: Int32?
        let apiNotificationSettings: Api.PeerNotifySettings
        switch dialog {
            case let .dialog(flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, peerNotificationSettings, pts, _, _):
                if let peer = peers[peer.peerId] {
                    var isExluded = false
                    if let group = peer as? TelegramGroup {
                        if group.flags.contains(.deactivated) {
                            isExluded = true
                        }
                    }
                    if !isExluded {
                        itemIds.append(peer.id)
                    }
                }
                apiPeer = peer
                apiTopMessage = topMessage
                apiReadInboxMaxId = readInboxMaxId
                apiReadOutboxMaxId = readOutboxMaxId
                apiUnreadCount = unreadCount
                apiMarkedUnread = (flags & (1 << 3)) != 0
                apiUnreadMentionsCount = unreadMentionsCount
                apiUnreadReactionsCount = unreadReactionsCount
                apiNotificationSettings = peerNotificationSettings
                apiChannelPts = pts
                let isPinned = (flags & (1 << 2)) != 0
                if !isPinned {
                    nonPinnedDialogsTopMessageIds.insert(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: topMessage))
                }
                let peerId: PeerId
                switch apiPeer {
                    case let .peerUser(userId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                }
                
                if readStates[peerId] == nil {
                    readStates[peerId] = [:]
                }
                readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount, markedUnread: apiMarkedUnread)
                
                if apiTopMessage != 0 {
                    mentionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                    reactionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadReactionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                    topMessageIds[peerId] = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: apiTopMessage)
                }
                
                if let apiChannelPts = apiChannelPts {
                    channelStates[peerId] = apiChannelPts
                }
                
                notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
            case let .dialogFolder(_, folder, _, _, unreadMutedPeersCount, _, unreadMutedMessagesCount, _):
                switch folder {
                    case let .folder(_, id, _, _):
                        referencedFolders[PeerGroupId(rawValue: id)] = PeerGroupUnreadCountersSummary(all: PeerGroupUnreadCounters(messageCount: unreadMutedMessagesCount, chatCount: unreadMutedPeersCount))
                }
        }
    }
    
    var lowerNonPinnedIndex: MessageIndex?
    
    for message in apiMessages {
        if let storeMessage = StoreMessage(apiMessage: message) {
            var updatedStoreMessage = storeMessage
            if case let .Id(id) = storeMessage.id {
                if let channelPts = channelStates[id.peerId] {
                    var updatedAttributes = storeMessage.attributes
                    updatedAttributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                    updatedStoreMessage = updatedStoreMessage.withUpdatedAttributes(updatedAttributes)
                }
                
                if !apiIsAtLowestBoundary, nonPinnedDialogsTopMessageIds.contains(id) {
                    let index = MessageIndex(id: id, timestamp: storeMessage.timestamp)
                    if lowerNonPinnedIndex == nil || lowerNonPinnedIndex! > index {
                        lowerNonPinnedIndex = index
                    }
                }
            }
            storeMessages.append(updatedStoreMessage)
        }
    }
    
    return ParsedDialogs(
        itemIds: itemIds,
        peers: Array(peers.values),
        peerPresences: peerPresences,
    
        notificationSettings: notificationSettings,
        readStates: readStates,
        mentionTagSummaries: mentionTagSummaries,
        reactionTagSummaries: reactionTagSummaries,
        channelStates: channelStates,
        topMessageIds: topMessageIds,
        storeMessages: storeMessages,
    
        lowerNonPinnedIndex: lowerNonPinnedIndex,
        referencedFolders: referencedFolders
    )
}

struct FetchedChatList {
    var chatPeerIds: [PeerId]
    var peers: [Peer]
    var peerPresences: [PeerId: Api.User]
    var notificationSettings: [PeerId: PeerNotificationSettings]
    var readStates: [PeerId: [MessageId.Namespace: PeerReadState]]
    var mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary]
    var reactionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary]
    var channelStates: [PeerId: Int32]
    var storeMessages: [StoreMessage]
    var topMessageIds: [PeerId: MessageId]
    
    var lowerNonPinnedIndex: MessageIndex?
    
    var pinnedItemIds: [PeerId]?
    var folderSummaries: [PeerGroupId: PeerGroupUnreadCountersSummary]
    var peerGroupIds: [PeerId: PeerGroupId]
    var threadInfos: [MessageId: StoreMessageHistoryThreadData]
}

func fetchChatList(postbox: Postbox, network: Network, location: FetchChatListLocation, upperBound: MessageIndex, hash: Int64, limit: Int32) -> Signal<FetchedChatList?, NoError> {
    return postbox.stateView()
    |> mapToSignal { view -> Signal<AuthorizedAccountState, NoError> in
        if let state = view.state as? AuthorizedAccountState {
            return .single(state)
        } else {
            return .complete()
        }
    }
    |> take(1)
    |> mapToSignal { _ -> Signal<FetchedChatList?, NoError> in
        let offset: Signal<(Int32, Int32, Api.InputPeer), NoError>
        if upperBound.id.peerId.namespace == Namespaces.Peer.Empty {
            offset = single((0, 0, Api.InputPeer.inputPeerEmpty), NoError.self)
        } else {
            offset = postbox.loadedPeerWithId(upperBound.id.peerId)
            |> take(1)
            |> map { peer in
                return (upperBound.timestamp, upperBound.id.id, apiInputPeer(peer) ?? .inputPeerEmpty)
            }
        }
        
        return offset
        |> mapToSignal { (timestamp, id, peer) -> Signal<FetchedChatList?, NoError> in
            let additionalPinnedChats: Signal<Api.messages.PeerDialogs?, NoError>
            if case .inputPeerEmpty = peer, timestamp == 0 {
                let folderId: Int32
                switch location {
                    case .general:
                        folderId = 0
                    case let .group(groupId):
                        folderId = groupId.rawValue
                }
                additionalPinnedChats = network.request(Api.functions.messages.getPinnedDialogs(folderId: folderId))
                |> retryRequest
                |> map(Optional.init)
            } else {
                additionalPinnedChats = .single(nil)
            }
            
            var flags: Int32 = 1 << 1
            let requestFolderId: Int32
            
            switch location {
                case .general:
                    requestFolderId = 0
                case let .group(groupId):
                    flags |= 1 << 0
                    requestFolderId = groupId.rawValue
            }
            let requestChats = network.request(Api.functions.messages.getDialogs(flags: flags, folderId: requestFolderId, offsetDate: timestamp, offsetId: id, offsetPeer: peer, limit: limit, hash: hash))
            |> retryRequest
            
            return combineLatest(requestChats, additionalPinnedChats)
            |> mapToSignal { remoteChats, pinnedChats -> Signal<FetchedChatList?, NoError> in
                if case .dialogsNotModified = remoteChats {
                    return .single(nil)
                }
                let extractedRemoteDialogs = extractDialogsData(dialogs: remoteChats)
                let parsedRemoteChats = parseDialogs(apiDialogs: extractedRemoteDialogs.apiDialogs, apiMessages: extractedRemoteDialogs.apiMessages, apiChats: extractedRemoteDialogs.apiChats, apiUsers: extractedRemoteDialogs.apiUsers, apiIsAtLowestBoundary: extractedRemoteDialogs.apiIsAtLowestBoundary)
                var parsedPinnedChats: ParsedDialogs?
                if let pinnedChats = pinnedChats {
                    let extractedPinnedChats = extractDialogsData(peerDialogs: pinnedChats)
                    parsedPinnedChats = parseDialogs(apiDialogs: extractedPinnedChats.apiDialogs, apiMessages: extractedPinnedChats.apiMessages, apiChats: extractedPinnedChats.apiChats, apiUsers: extractedPinnedChats.apiUsers, apiIsAtLowestBoundary: extractedPinnedChats.apiIsAtLowestBoundary)
                }
                
                var combinedReferencedFolders = Set<PeerGroupId>()
                combinedReferencedFolders.formUnion(parsedRemoteChats.referencedFolders.keys)
                if let parsedPinnedChats = parsedPinnedChats {
                    combinedReferencedFolders.formUnion(Set(parsedPinnedChats.referencedFolders.keys))
                }
                
                var folderSignals: [Signal<(PeerGroupId, ParsedDialogs), NoError>] = []
                if case .general = location {
                    for groupId in combinedReferencedFolders {
                        let flags: Int32 = 1 << 1
                        let requestFeed = network.request(Api.functions.messages.getDialogs(flags: flags, folderId: groupId.rawValue, offsetDate: 0, offsetId: 0, offsetPeer: .inputPeerEmpty, limit: 32, hash: 0))
                        |> retryRequest
                        |> map { result -> (PeerGroupId, ParsedDialogs) in
                            let extractedData = extractDialogsData(dialogs: result)
                            let parsedChats = parseDialogs(apiDialogs: extractedData.apiDialogs, apiMessages: extractedData.apiMessages, apiChats: extractedData.apiChats, apiUsers: extractedData.apiUsers, apiIsAtLowestBoundary: extractedData.apiIsAtLowestBoundary)
                            return (groupId, parsedChats)
                        }
                        folderSignals.append(requestFeed)
                    }
                }
                
                return combineLatest(folderSignals)
                |> mapToSignal { folders -> Signal<FetchedChatList?, NoError> in
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: Api.User] = [:]
                    var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
                    var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
                    var mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
                    var reactionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
                    var channelStates: [PeerId: Int32] = [:]
                    var storeMessages: [StoreMessage] = []
                    var topMessageIds: [PeerId: MessageId] = [:]
                    
                    peers.append(contentsOf: parsedRemoteChats.peers)
                    peerPresences.merge(parsedRemoteChats.peerPresences, uniquingKeysWith: { _, updated in updated })
                    notificationSettings.merge(parsedRemoteChats.notificationSettings, uniquingKeysWith: { _, updated in updated })
                    readStates.merge(parsedRemoteChats.readStates, uniquingKeysWith: { _, updated in updated })
                    mentionTagSummaries.merge(parsedRemoteChats.mentionTagSummaries, uniquingKeysWith: { _, updated in updated })
                    reactionTagSummaries.merge(parsedRemoteChats.reactionTagSummaries, uniquingKeysWith: { _, updated in updated })
                    channelStates.merge(parsedRemoteChats.channelStates, uniquingKeysWith: { _, updated in updated })
                    storeMessages.append(contentsOf: parsedRemoteChats.storeMessages)
                    topMessageIds.merge(parsedRemoteChats.topMessageIds, uniquingKeysWith: { _, updated in updated })
                    
                    if let parsedPinnedChats = parsedPinnedChats {
                        peers.append(contentsOf: parsedPinnedChats.peers)
                        peerPresences.merge(parsedPinnedChats.peerPresences, uniquingKeysWith: { _, updated in updated })
                        notificationSettings.merge(parsedPinnedChats.notificationSettings, uniquingKeysWith: { _, updated in updated })
                        readStates.merge(parsedPinnedChats.readStates, uniquingKeysWith: { _, updated in updated })
                        mentionTagSummaries.merge(parsedPinnedChats.mentionTagSummaries, uniquingKeysWith: { _, updated in updated })
                        reactionTagSummaries.merge(parsedPinnedChats.reactionTagSummaries, uniquingKeysWith: { _, updated in updated })
                        channelStates.merge(parsedPinnedChats.channelStates, uniquingKeysWith: { _, updated in updated })
                        storeMessages.append(contentsOf: parsedPinnedChats.storeMessages)
                        topMessageIds.merge(parsedPinnedChats.topMessageIds, uniquingKeysWith: { _, updated in updated })
                    }
                    
                    var peerGroupIds: [PeerId: PeerGroupId] = [:]
                    
                    if case let .group(groupId) = location {
                        for peerId in parsedRemoteChats.itemIds {
                            peerGroupIds[peerId] = groupId
                        }
                    }
                    
                    for (groupId, folderChats) in folders {
                        for peerId in folderChats.itemIds {
                            peerGroupIds[peerId] = groupId
                        }
                        peers.append(contentsOf: folderChats.peers)
                        peerPresences.merge(folderChats.peerPresences, uniquingKeysWith: { _, updated in updated })
                        notificationSettings.merge(folderChats.notificationSettings, uniquingKeysWith: { _, updated in updated })
                        readStates.merge(folderChats.readStates, uniquingKeysWith: { _, updated in updated })
                        mentionTagSummaries.merge(folderChats.mentionTagSummaries, uniquingKeysWith: { _, updated in updated })
                        reactionTagSummaries.merge(folderChats.reactionTagSummaries, uniquingKeysWith: { _, updated in updated })
                        channelStates.merge(folderChats.channelStates, uniquingKeysWith: { _, updated in updated })
                        storeMessages.append(contentsOf: folderChats.storeMessages)
                    }
                    
                    var pinnedItemIds: [PeerId]?
                    if let parsedPinnedChats = parsedPinnedChats {
                        var array: [PeerId] = []
                        for peerId in parsedPinnedChats.itemIds {
                            if case let .group(groupId) = location {
                                peerGroupIds[peerId] = groupId
                            }
                            array.append(peerId)
                        }
                        pinnedItemIds = array
                    }
                    
                    var folderSummaries: [PeerGroupId: PeerGroupUnreadCountersSummary] = [:]
                    for (groupId, summary) in parsedRemoteChats.referencedFolders {
                        folderSummaries[groupId] = summary
                    }
                    if let parsedPinnedChats = parsedPinnedChats {
                        for (groupId, summary) in parsedPinnedChats.referencedFolders {
                            folderSummaries[groupId] = summary
                        }
                    }
                    
                    let result: FetchedChatList? = FetchedChatList(
                        chatPeerIds: parsedRemoteChats.itemIds + (pinnedItemIds ?? []),
                        peers: peers,
                        peerPresences: peerPresences,
                        notificationSettings: notificationSettings,
                        readStates: readStates,
                        mentionTagSummaries: mentionTagSummaries,
                        reactionTagSummaries: reactionTagSummaries,
                        channelStates: channelStates,
                        storeMessages: storeMessages,
                        topMessageIds: topMessageIds,
                    
                        lowerNonPinnedIndex: parsedRemoteChats.lowerNonPinnedIndex,
                    
                        pinnedItemIds: pinnedItemIds,
                        folderSummaries: folderSummaries,
                        peerGroupIds: peerGroupIds,
                        threadInfos: [:]
                    )
                    return resolveUnknownEmojiFiles(postbox: postbox, source: .network(network), messages: storeMessages, reactions: [], result: result)
                    |> mapToSignal { result in
                        if let result = result {
                            return resolveForumThreads(postbox: postbox, network: network, fetchedChatList: result)
                            |> map(Optional.init)
                        } else {
                            return .single(result)
                        }
                    }
                }
            }
        }
    }
}
