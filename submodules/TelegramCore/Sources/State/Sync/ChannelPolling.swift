import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

func pollChannelOnce(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: PeerId, stateManager: AccountStateManager, delayCompletion: Bool) -> Signal<Int32, NoError> {
    return postbox.transaction { transaction -> Signal<Int32, NoError> in
        guard let accountState = (transaction.getState() as? AuthorizedAccountState)?.state, let peer = transaction.getPeer(peerId) else {
            if delayCompletion {
                return .complete()
                |> delay(30.0, queue: Queue.concurrentDefaultQueue())
            } else {
                return .complete()
            }
        }

        var channelStates: [PeerId: AccountStateChannelState] = [:]
        if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
            channelStates[peerId] = AccountStateChannelState(pts: channelState.pts)
        }
        let initialPeers: [PeerId: Peer] = [peerId: peer]
        var peerChatInfos: [PeerId: PeerChatInfo] = [:]
        let inclusion = transaction.getPeerChatListInclusion(peerId)
        var hasValidInclusion = false
        switch inclusion {
            case .ifHasMessagesOrOneOf:
                hasValidInclusion = true
            case .notIncluded:
                hasValidInclusion = false
        }
        if hasValidInclusion {
            if let notificationSettings = transaction.getPeerNotificationSettings(id: peerId) as? TelegramPeerNotificationSettings {
                peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
            }
        }
        let initialState = AccountMutableState(initialState: AccountInitialState(state: accountState, peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: channelStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set()), initialPeers: initialPeers, initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        return pollChannel(accountPeerId: accountPeerId, postbox: postbox, network: network, peer: peer, state: initialState)
        |> mapToSignal { outcome -> Signal<Int32, NoError> in
            let finalState = outcome.state
            let timeout = outcome.timeout
            return resolveAssociatedMessages(accountPeerId: accountPeerId, postbox: postbox, network: network, state: finalState)
            |> mapToSignal { resultingState -> Signal<AccountMutableState, NoError> in
                return resolveAssociatedStories(postbox: postbox, network: network, accountPeerId: accountPeerId, state: resultingState)
            }
            |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                return resolveMissingPeerChatInfos(accountPeerId: accountPeerId, network: network, state: resultingState)
                |> map { resultingState, _ -> AccountFinalState in
                    return AccountFinalState(state: resultingState, shouldPoll: false, incomplete: false, discard: false)
                }
            }
            |> mapToSignal { finalState -> Signal<Int32, NoError> in
                return stateManager.addReplayAsynchronouslyBuiltFinalState(finalState)
                |> mapToSignal { _ -> Signal<Int32, NoError> in
                    if delayCompletion {
                        return .single(timeout ?? 30)
                        |> then(
                            .complete()
                            |> delay(Double(timeout ?? 30), queue: Queue.concurrentDefaultQueue())
                        )
                    } else {
                        return .single(timeout ?? 30)
                    }
                }
            }
        }
    }
    |> switchToLatest
}

public func standalonePollChannelOnce(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: PeerId, stateManager: AccountStateManager) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        guard let accountState = (transaction.getState() as? AuthorizedAccountState)?.state, let peer = transaction.getPeer(peerId) else {
            return .complete()
        }

        var channelStates: [PeerId: AccountStateChannelState] = [:]
        if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
            channelStates[peerId] = AccountStateChannelState(pts: channelState.pts)
        }
        let initialPeers: [PeerId: Peer] = [peerId: peer]
        var peerChatInfos: [PeerId: PeerChatInfo] = [:]
        let inclusion = transaction.getPeerChatListInclusion(peerId)
        var hasValidInclusion = false
        switch inclusion {
        case .ifHasMessagesOrOneOf:
            hasValidInclusion = true
        case .notIncluded:
            hasValidInclusion = false
        }
        if hasValidInclusion {
            if let notificationSettings = transaction.getPeerNotificationSettings(id: peerId) as? TelegramPeerNotificationSettings {
                peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
            }
        }
        let initialState = AccountMutableState(initialState: AccountInitialState(state: accountState, peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: channelStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set()), initialPeers: initialPeers, initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        return pollChannel(accountPeerId: accountPeerId, postbox: postbox, network: network, peer: peer, state: initialState)
        |> mapToSignal { outcome -> Signal<Never, NoError> in
            let finalState = outcome.state
            return resolveAssociatedMessages(accountPeerId: accountPeerId, postbox: postbox, network: network, state: finalState)
            |> mapToSignal { resultingState -> Signal<AccountMutableState, NoError> in
                return resolveAssociatedStories(postbox: postbox, network: network, accountPeerId: accountPeerId, state: resultingState)
            }
            |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                return resolveMissingPeerChatInfos(accountPeerId: accountPeerId, network: network, state: resultingState)
                |> map { resultingState, _ -> AccountFinalState in
                    return AccountFinalState(state: resultingState, shouldPoll: false, incomplete: false, discard: false)
                }
            }
            |> mapToSignal { finalState -> Signal<Never, NoError> in
                return stateManager.standaloneReplayAsynchronouslyBuiltFinalState(finalState: finalState)
            }
        }
    }
    |> switchToLatest
}

func keepPollingChannel(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: PeerId, stateManager: AccountStateManager) -> Signal<Int32, NoError> {
    return pollChannelOnce(accountPeerId: accountPeerId, postbox: postbox, network: network, peerId: peerId, stateManager: stateManager, delayCompletion: true)
    |> restart
    |> delay(1.0, queue: .concurrentDefaultQueue())
}

func resetChannels(accountPeerId: PeerId, postbox: Postbox, network: Network, peers: [Peer], state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    var inputPeers: [Api.InputDialogPeer] = []
    for peer in peers {
        if let inputDialogPeer = apiInputDialogPeer(peer) {
            inputPeers.append(inputDialogPeer)
        }
    }
    return network.request(Api.functions.messages.getPeerDialogs(peers: inputPeers))
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.messages.PeerDialogs?, NoError> in
        if error.errorDescription == "CHANNEL_PRIVATE" && inputPeers.count == 1 {
            return .single(nil)
        } else {
            return .single(nil)
        }
    }
    |> mapToSignal { result -> Signal<AccountMutableState, NoError> in
        var updatedState = state
        
        var dialogsChats: [Api.Chat] = []
        var dialogsUsers: [Api.User] = []
        
        var storeMessages: [StoreMessage] = []
        var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
        var mentionTagSummaries: [PeerId: [(tag: MessageTags, summary: MessageHistoryTagNamespaceSummary)]] = [:]
        var channelStates: [PeerId: AccountStateChannelState] = [:]
        var invalidateChannelStates: [PeerId: Int32] = [:]
        var channelSynchronizedUntilMessage: [PeerId: MessageId.Id] = [:]
        var notificationSettings: [PeerId: TelegramPeerNotificationSettings] = [:]
        
        var resetForumTopics = Set<PeerId>()
        
        if let result = result {
            switch result {
                case let .peerDialogs(peerDialogsData):
                    let (dialogs, messages, chats, users) = (peerDialogsData.dialogs, peerDialogsData.messages, peerDialogsData.chats, peerDialogsData.users)
                    dialogsChats.append(contentsOf: chats)
                    dialogsUsers.append(contentsOf: users)
                    
                    loop: for dialog in dialogs {
                        let apiPeer: Api.Peer
                        let apiReadInboxMaxId: Int32
                        let apiReadOutboxMaxId: Int32
                        let apiTopMessage: Int32
                        let apiUnreadCount: Int32
                        let apiUnreadMentionsCount: Int32
                        let apiUnreadReactionsCount: Int32
                        let apiUnreadPollVoteCount: Int32
                        var apiChannelPts: Int32?
                        let apiNotificationSettings: Api.PeerNotifySettings
                        let apiMarkedUnread: Bool
                        let groupId: PeerGroupId
                        let apiTtlPeriod: Int32?
                        switch dialog {
                            case let .dialog(dialogData):
                                let (flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, peerNotificationSettings, pts, folderId, ttlPeriod) = (dialogData.flags, dialogData.peer, dialogData.topMessage, dialogData.readInboxMaxId, dialogData.readOutboxMaxId, dialogData.unreadCount, dialogData.unreadMentionsCount, dialogData.unreadReactionsCount, dialogData.unreadPollVotesCount, dialogData.notifySettings, dialogData.pts, dialogData.folderId, dialogData.ttlPeriod)
                                apiPeer = peer
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                                apiMarkedUnread = (flags & (1 << 3)) != 0
                                apiUnreadMentionsCount = unreadMentionsCount
                                apiUnreadReactionsCount = unreadReactionsCount
                                apiUnreadPollVoteCount = unreadPollVoteCount
                                apiNotificationSettings = peerNotificationSettings
                                apiChannelPts = pts
                                groupId = PeerGroupId(rawValue: folderId ?? 0)
                                apiTtlPeriod = ttlPeriod
                            case let .dialogCommunity(dialogCommunityData):
                                let peerId = peerIdFromApiCommunityId(dialogCommunityData.communityId)
                                notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: dialogCommunityData.notifySettings)
                                continue loop
                            case .dialogFolder:
                                assertionFailure()
                                continue loop
                        }
                        
                        let peerId: PeerId = apiPeer.peerId
                        
                        if readStates[peerId] == nil {
                            readStates[peerId] = [:]
                        }
                        readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount, markedUnread: apiMarkedUnread)
                        
                        if apiTopMessage != 0 {
                            mentionTagSummaries[peerId] = [
                                (MessageTags.unseenPersonalMessage, MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))),
                                (MessageTags.unseenReaction, MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadReactionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))),
                                (MessageTags.unseenPollVote, MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadPollVoteCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage)))
                            ]
                        }
                        
                        if let apiChannelPts = apiChannelPts {
                            channelStates[peerId] = AccountStateChannelState(pts: apiChannelPts)
                            invalidateChannelStates[peerId] = apiChannelPts
                        }
                        
                        notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                        
                        updatedState.updatePeerChatInclusion(peerId: peerId, groupId: groupId, changedGroup: false)
                        
                        updatedState.updateAutoremoveTimeout(peer: apiPeer, value: apiTtlPeriod.flatMap(CachedPeerAutoremoveTimeout.Value.init(peerValue:)))
                        
                        resetForumTopics.insert(peerId)
                    }

                    for message in messages {
                        var peerIsForum = false
                        if let peerId = message.peerId {
                            peerIsForum = updatedState.isPeerForum(peerId: peerId)
                        }
                        if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                            var updatedStoreMessage = storeMessage
                            if case let .Id(id) = storeMessage.id {
                                if let channelState = channelStates[id.peerId] {
                                    var updatedAttributes = storeMessage.attributes
                                    updatedAttributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                    updatedStoreMessage = updatedStoreMessage.withUpdatedAttributes(updatedAttributes)
                                }
                            }
                            storeMessages.append(updatedStoreMessage)
                        }
                    }
            }
        }
        
        updatedState.mergeChats(dialogsChats)
        updatedState.mergeUsers(dialogsUsers)
        
        for message in storeMessages {
            if case let .Id(id) = message.id, id.namespace == Namespaces.Message.Cloud {
                updatedState.setNeedsHoleFromPreviousState(peerId: id.peerId, namespace: id.namespace)
                channelSynchronizedUntilMessage[id.peerId] = id.id
            }
        }
        
        updatedState.addMessages(storeMessages, location: .UpperHistoryBlock)
        
        for (peerId, peerReadStates) in readStates {
            for (namespace, state) in peerReadStates {
                switch state {
                    case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread):
                        updatedState.resetReadState(peerId, namespace: namespace, maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnread)
                    default:
                        assertionFailure()
                        break
                }
            }
        }
        
        for (peerId, tagSummaries) in mentionTagSummaries {
            for tagSummary in tagSummaries {
                updatedState.resetMessageTagSummary(peerId, tag: tagSummary.tag, namespace: Namespaces.Message.Cloud, count: tagSummary.summary.count, range: tagSummary.summary.range)
            }
        }
        
        for (peerId, channelState) in channelStates {
            updatedState.updateChannelState(peerId, pts: channelState.pts)
        }
        for (peerId, pts) in invalidateChannelStates {
            updatedState.updateChannelInvalidationPts(peerId, invalidationPts: pts)
        }
        for (peerId, id) in channelSynchronizedUntilMessage {
            updatedState.updateChannelSynchronizedUntilMessage(peerId, id: id)
        }
        
        for (peerId, settings) in notificationSettings {
            updatedState.updateNotificationSettings(.peer(peerId: peerId, threadId: nil), notificationSettings: settings)
        }
        
        var resetTopicsSignals: [Signal<StateResetForumTopics, NoError>] = []
        for resetForumTopicPeerId in resetForumTopics {
            resetTopicsSignals.append(_internal_requestMessageHistoryThreads(accountPeerId: accountPeerId, postbox: postbox, network: network, peerId: resetForumTopicPeerId, query: nil, offsetIndex: nil, limit: 20)
            |> map(StateResetForumTopics.result)
            |> `catch` { _ -> Signal<StateResetForumTopics, NoError> in
                return .single(.error(resetForumTopicPeerId))
            })
        }
        return combineLatest(resetTopicsSignals)
        |> mapToSignal { results -> Signal<AccountMutableState, NoError> in
            var updatedState = updatedState
            
            for result in results {
                let peerId: PeerId
                switch result {
                case let .result(item):
                    peerId = item.peerId
                case let .error(peerIdValue):
                    peerId = peerIdValue
                }
                updatedState.resetForumTopicLists[peerId] = result
            }
            
            // TODO: delete messages later than top
            return resolveAssociatedMessages(accountPeerId: accountPeerId, postbox: postbox, network: network, state: updatedState)
            |> mapToSignal { resultingState -> Signal<AccountMutableState, NoError> in
                return resolveAssociatedStories(postbox: postbox, network: network, accountPeerId: accountPeerId, state: resultingState)
            }
        }
    }
}

/// What `pollChannel` gives back for one channel (state-sync seam 6; it replaced an `(AccountMutableState, Bool, Int32?)`
/// whose `Bool` was false only for an unavailable channel and whose `Int32?` was the answer's timeout).
enum ChannelPollOutcome {
    /// getChannelDifference answered (`channelDifference`, `channelDifferenceEmpty` or `channelDifferenceTooLong`): the
    /// state carries what the answer applied, and `timeout` is the answer's, after which a view's poll repeats
    /// (`pollChannelOnce`, 30 s when nil). The synchronous channel reset's state rides the same list in
    /// SyncChannelRecovery as `.applied(_, timeout: nil)`.
    case applied(AccountMutableState, timeout: Int32?)
    /// CHANNEL_PRIVATE or CHANNEL_INVALID: the state comes back as it was given, and a pushed batch that polled the
    /// channel asks for a getDifference afterwards (`AccountFinalState.shouldPoll`).
    case channelUnavailable(AccountMutableState)
    /// No input channel could be made for the peer, so nothing was requested: the state comes back as it was given.
    case noInputChannel(AccountMutableState)

    /// The state to merge, to replace the batch's with (the synchronous channel reset) or to replay, whatever the
    /// outcome.
    var state: AccountMutableState {
        switch self {
        case let .applied(state, _), let .channelUnavailable(state), let .noInputChannel(state):
            return state
        }
    }

    /// The answer's timeout; nil unless `.applied`.
    var timeout: Int32? {
        switch self {
        case let .applied(_, timeout):
            return timeout
        case .channelUnavailable, .noInputChannel:
            return nil
        }
    }
}

func pollChannel(accountPeerId: PeerId, postbox: Postbox, network: Network, peer: Peer, state: AccountMutableState) -> Signal<ChannelPollOutcome, NoError> {
    if let inputChannel = apiInputChannel(peer) {
        let limit: Int32
        #if DEBUG
        limit = 2
        #else
        limit = 100
        #endif
        
        let pollPts: Int32
        if let channelState = state.channelStates[peer.id] {
            pollPts = channelState.pts
        } else {
            pollPts = 1
        }
        return (network.request(Api.functions.updates.getChannelDifference(flags: 0, channel: inputChannel, filter: .channelMessagesFilterEmpty, pts: max(pollPts, 1), limit: limit))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.updates.ChannelDifference?, MTRpcError> in
            switch error.errorDescription {
            case "CHANNEL_PRIVATE", "CHANNEL_INVALID":
                return .single(nil)
            default:
                return .fail(error)
            }
        })
        |> retryRequest
        |> mapToSignal { difference -> Signal<ChannelPollOutcome, NoError> in
            guard let difference = difference else {
                return .single(.channelUnavailable(state))
            }
            
            switch difference {
            case let .channelDifference(channelDifferenceData):
                let (_, pts, timeout, newMessages, otherUpdates, chats, users) = (channelDifferenceData.flags, channelDifferenceData.pts, channelDifferenceData.timeout, channelDifferenceData.newMessages, channelDifferenceData.otherUpdates, channelDifferenceData.chats, channelDifferenceData.users)
                var updatedState = state
                var apiTimeout: Int32?
                
                apiTimeout = timeout
                updatedState.updateChannelState(peer.id, pts: pts)
                
                updatedState.mergeChats(chats)
                updatedState.mergeUsers(users)
                
                var forumThreadIds = Set<MessageId>()
                
                for apiMessage in newMessages {
                    var peerIsForum = peer.isForum
                    if let peerId = apiMessage.peerId, updatedState.isPeerForum(peerId: peerId) {
                        peerIsForum = true
                    }
                    if var message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                        var attributes = message.attributes
                        attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                        message = message.withUpdatedAttributes(attributes)
                        
                        if let preCachedResources = apiMessage.preCachedResources {
                            for (resource, data) in preCachedResources {
                                updatedState.addPreCachedResource(resource, data: data)
                            }
                        }
                        if let preCachedStories = apiMessage.preCachedStories {
                            for (id, story) in preCachedStories {
                                updatedState.addPreCachedStory(id: id, story: story)
                            }
                        }
                        updatedState.addMessages([message], location: .UpperHistoryBlock)
                        if case let .Id(id) = message.id {
                            updatedState.updateChannelSynchronizedUntilMessage(id.peerId, id: id.id)
                            
                            if let threadId = message.threadId {
                                if let channel = updatedState.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info, channel.flags.contains(.isForum) {
                                    forumThreadIds.insert(MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: Int32(clamping: threadId)))
                                } else if let user = updatedState.peers[message.id.peerId] as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum) {
                                    forumThreadIds.insert(MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: Int32(clamping: threadId)))
                                }
                            }
                        }
                    }
                }
                
                for update in otherUpdates {
                    switch update {
                    case let .updateDeleteChannelMessages(updateDeleteChannelMessagesData):
                        let peerId = peer.id
                        updatedState.deleteMessages(updateDeleteChannelMessagesData.messages.map({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }))
                    case let .updateEditChannelMessage(updateEditChannelMessageData):
                        let apiMessage = updateEditChannelMessageData.message
                        var peerIsForum = peer.isForum
                        if let peerId = apiMessage.peerId, updatedState.isPeerForum(peerId: peerId) {
                            peerIsForum = true
                        }
                        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum), case let .Id(messageId) = message.id, messageId.peerId == peer.id {
                            if let preCachedResources = apiMessage.preCachedResources {
                                for (resource, data) in preCachedResources {
                                    updatedState.addPreCachedResource(resource, data: data)
                                }
                            }
                            if let preCachedStories = apiMessage.preCachedStories {
                                for (id, story) in preCachedStories {
                                    updatedState.addPreCachedStory(id: id, story: story)
                                }
                            }
                            var attributes = message.attributes
                            attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                            updatedState.editMessage(messageId, message: message.withUpdatedAttributes(attributes))
                            
                            if let threadId = message.threadId {
                                if let channel = updatedState.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info, channel.flags.contains(.isForum) {
                                    forumThreadIds.insert(MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: Int32(clamping: threadId)))
                                } else if let user = updatedState.peers[message.id.peerId] as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum) {
                                    forumThreadIds.insert(MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: Int32(clamping: threadId)))
                                }
                            }
                        } else {
                            Logger.shared.log("State", "Invalid updateEditChannelMessage")
                        }
                    case let .updatePinnedChannelMessages(updatePinnedChannelMessagesData):
                        let (flags, channelId, messages) = (updatePinnedChannelMessagesData.flags, updatePinnedChannelMessagesData.channelId, updatePinnedChannelMessagesData.messages)
                        let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        updatedState.updateMessagesPinned(ids: messages.map { id in
                            MessageId(peerId: channelPeerId, namespace: Namespaces.Message.Cloud, id: id)
                        }, pinned: (flags & (1 << 0)) != 0)
                    case let .updateChannelReadMessagesContents(updateChannelReadMessagesContentsData):
                        let (topMsgId, savedPeerId, messages) = (updateChannelReadMessagesContentsData.topMsgId, updateChannelReadMessagesContentsData.savedPeerId, updateChannelReadMessagesContentsData.messages)
                        var threadId: Int64?
                        if let savedPeerId {
                            threadId = savedPeerId.peerId.toInt64()
                        } else if let topMsgId {
                            threadId = Int64(topMsgId)
                        }
                        updatedState.addReadMessagesContents((peer.id, threadId, messages), date: nil)
                    case let .updateChannelMessageViews(updateChannelMessageViewsData):
                        updatedState.addUpdateMessageImpressionCount(id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: updateChannelMessageViewsData.id), count: updateChannelMessageViewsData.views)
                    case let .updateChannelWebPage(updateChannelWebPageData):
                        let apiWebpage = updateChannelWebPageData.webpage
                        switch apiWebpage {
                        case let .webPageEmpty(webPageEmptyData):
                            let (flags, id, url) = (webPageEmptyData.flags, webPageEmptyData.id, webPageEmptyData.url)
                            let _ = flags
                            let _ = url
                            updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
                        default:
                            if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage) {
                                updatedState.updateMedia(webpage.webpageId, media: webpage)
                            }
                        }
                    case let .updateChannelAvailableMessages(updateChannelAvailableMessagesData):
                        let minId = updateChannelAvailableMessagesData.availableMinId
                        let messageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: minId)
                        updatedState.updateMinAvailableMessage(messageId)
                        updatedState.updateCachedPeerData(peer.id, { current in
                            let previous: CachedChannelData
                            if let current = current as? CachedChannelData {
                                previous = current
                            } else {
                                previous = CachedChannelData()
                            }
                            return previous.withUpdatedMinAvailableMessageId(messageId)
                        })
                    default:
                        break
                    }
                }
                
                return resolveForumThreads(accountPeerId: accountPeerId, postbox: postbox, source: .network(network), state: updatedState)
                |> mapToSignal { updatedState in
                    return resolveAssociatedStories(postbox: postbox, network: network, accountPeerId: accountPeerId, state: updatedState)
                    |> map { updatedState -> ChannelPollOutcome in
                        return .applied(updatedState, timeout: apiTimeout)
                    }
                }
            case let .channelDifferenceEmpty(channelDifferenceEmptyData):
                let (_, pts, timeout) = (channelDifferenceEmptyData.flags, channelDifferenceEmptyData.pts, channelDifferenceEmptyData.timeout)
                var updatedState = state
                var apiTimeout: Int32?

                apiTimeout = timeout

                updatedState.updateChannelState(peer.id, pts: pts)

                return .single(.applied(updatedState, timeout: apiTimeout))
            case let .channelDifferenceTooLong(channelDifferenceTooLongData):
                let (_, timeout, dialog, messages, chats, users) = (channelDifferenceTooLongData.flags, channelDifferenceTooLongData.timeout, channelDifferenceTooLongData.dialog, channelDifferenceTooLongData.messages, channelDifferenceTooLongData.chats, channelDifferenceTooLongData.users)
                var updatedState = state
                var apiTimeout: Int32?
                
                apiTimeout = timeout
                
                var parameters: (peer: Api.Peer, pts: Int32, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, unreadPollVoteCount: Int32, ttlPeriod: Int32?)?
                
                switch dialog {
                case let .dialog(dialogData):
                    let (peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, pts, ttlPeriod) = (dialogData.peer, dialogData.topMessage, dialogData.readInboxMaxId, dialogData.readOutboxMaxId, dialogData.unreadCount, dialogData.unreadMentionsCount, dialogData.unreadReactionsCount, dialogData.unreadPollVotesCount, dialogData.pts, dialogData.ttlPeriod)
                    if let pts = pts {
                        parameters = (peer, pts, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, ttlPeriod)
                    }
                case .dialogCommunity:
                    break
                case .dialogFolder:
                    break
                }
                
                var resetForumTopics = Set<PeerId>()
                
                var peerIsForum = peer.isForum
                if updatedState.isPeerForum(peerId: peer.id) {
                    peerIsForum = true
                }
                
                if let (peer, pts, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, ttlPeriod) = parameters {
                    updatedState.updateChannelState(peer.peerId, pts: pts)
                    updatedState.updateChannelInvalidationPts(peer.peerId, invalidationPts: pts)
                    
                    updatedState.updateAutoremoveTimeout(peer: peer, value: ttlPeriod.flatMap(CachedPeerAutoremoveTimeout.Value.init(peerValue:)))
                    
                    updatedState.mergeChats(chats)
                    updatedState.mergeUsers(users)
                    
                    updatedState.setNeedsHoleFromPreviousState(peerId: peer.peerId, namespace: Namespaces.Message.Cloud)
                    resetForumTopics.insert(peer.peerId)
                    
                    for apiMessage in messages {
                        if var message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                            var attributes = message.attributes
                            attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                            message = message.withUpdatedAttributes(attributes)
                            
                            if let preCachedResources = apiMessage.preCachedResources {
                                for (resource, data) in preCachedResources {
                                    updatedState.addPreCachedResource(resource, data: data)
                                }
                            }
                            if let preCachedStories = apiMessage.preCachedStories {
                                for (id, story) in preCachedStories {
                                    updatedState.addPreCachedStory(id: id, story: story)
                                }
                            }
                            
                            let location: AddMessagesLocation
                            if case let .Id(id) = message.id, id.id == topMessage {
                                location = .UpperHistoryBlock
                                updatedState.updateChannelSynchronizedUntilMessage(id.peerId, id: id.id)
                            } else {
                                location = .Random
                            }
                            updatedState.addMessages([message], location: location)
                        }
                    }
                    
                    updatedState.resetReadState(peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: nil)
                    
                    updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                    updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenReaction, namespace: Namespaces.Message.Cloud, count: unreadReactionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                    updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenPollVote, namespace: Namespaces.Message.Cloud, count: unreadPollVoteCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                } else {
                    assertionFailure()
                }
                
                var resetTopicsSignals: [Signal<StateResetForumTopics, NoError>] = []
                for resetForumTopicPeerId in resetForumTopics {
                    resetTopicsSignals.append(_internal_requestMessageHistoryThreads(accountPeerId: accountPeerId, postbox: postbox, network: network, peerId: resetForumTopicPeerId, query: nil, offsetIndex: nil, limit: 20)
                    |> map(StateResetForumTopics.result)
                    |> `catch` { _ -> Signal<StateResetForumTopics, NoError> in
                        return .single(.error(resetForumTopicPeerId))
                    })
                }
                return combineLatest(resetTopicsSignals)
                |> mapToSignal { results -> Signal<ChannelPollOutcome, NoError> in
                    var updatedState = updatedState
                    
                    for result in results {
                        let peerId: PeerId
                        switch result {
                        case let .result(item):
                            peerId = item.peerId
                        case let .error(peerIdValue):
                            peerId = peerIdValue
                        }
                        updatedState.resetForumTopicLists[peerId] = result
                    }
                    
                    return .single(.applied(updatedState, timeout: apiTimeout))
                }
            }
        }
    } else {
        Logger.shared.log("State", "can't poll channel \(peer.id): can't create inputChannel")
        return single(ChannelPollOutcome.noInputChannel(state), NoError.self)
    }
}
