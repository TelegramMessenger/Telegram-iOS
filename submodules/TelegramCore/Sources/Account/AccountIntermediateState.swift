import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


struct PeerChatInfo {
    var notificationSettings: PeerNotificationSettings
}

struct AccountStateChannelState: Equatable {
    var pts: Int32
}

final class AccountInitialState {
    let state: AuthorizedAccountState.State
    let peerIds: Set<PeerId>
    let channelStates: [PeerId: AccountStateChannelState]
    let peerChatInfos: [PeerId: PeerChatInfo]
    let peerIdsRequiringLocalChatState: Set<PeerId>
    let locallyGeneratedMessageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]]
    let cloudReadStates: [PeerId: PeerReadState]
    let channelsToPollExplicitely: Set<PeerId>
    
    init(state: AuthorizedAccountState.State, peerIds: Set<PeerId>, peerIdsRequiringLocalChatState: Set<PeerId>, channelStates: [PeerId: AccountStateChannelState], peerChatInfos: [PeerId: PeerChatInfo], locallyGeneratedMessageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]], cloudReadStates: [PeerId: PeerReadState], channelsToPollExplicitely: Set<PeerId>) {
        self.state = state
        self.peerIds = peerIds
        self.channelStates = channelStates
        self.peerIdsRequiringLocalChatState = peerIdsRequiringLocalChatState
        self.peerChatInfos = peerChatInfos
        self.locallyGeneratedMessageTimestamps = locallyGeneratedMessageTimestamps
        self.cloudReadStates = cloudReadStates
        self.channelsToPollExplicitely = channelsToPollExplicitely
    }
}

enum AccountStateUpdatePinnedItemIdsOperation {
    case pin(PinnedItemId)
    case unpin(PinnedItemId)
    case reorder([PinnedItemId])
    case sync
}

enum AccountStateUpdateStickerPacksOperation {
    case add(Api.messages.StickerSet)
    case reorder(SynchronizeInstalledStickerPacksOperationNamespace, [Int64])
    case reorderToTop(SynchronizeInstalledStickerPacksOperationNamespace, [Int64])
    case sync
}

enum AccountStateNotificationSettingsSubject {
    case peer(peerId: PeerId, threadId: Int64?)
}

enum AccountStateGlobalNotificationSettingsSubject {
    case privateChats
    case groups
    case channels
}

enum AccountStateMutationOperation {
    case AddMessages([StoreMessage], AddMessagesLocation)
    case AddScheduledMessages([StoreMessage])
    case AddQuickReplyMessages([StoreMessage])
    case DeleteMessagesWithGlobalIds([Int32])
    case DeleteMessages([MessageId])
    case EditMessage(MessageId, StoreMessage)
    case UpdateMessagePoll(MediaId, Api.Poll?, Api.PollResults)
    case UpdateMessageReactions(MessageId, Api.MessageReactions, Int32?)
    case UpdateMedia(MediaId, Media?)
    case ReadInbox(MessageId)
    case ReadOutbox(MessageId, Int32?)
    case ResetReadState(peerId: PeerId, namespace: MessageId.Namespace, maxIncomingReadId: MessageId.Id, maxOutgoingReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32, markedUnread: Bool?)
    case ResetIncomingReadState(groupId: PeerGroupId, peerId: PeerId, namespace: MessageId.Namespace, maxIncomingReadId: MessageId.Id, count: Int32, pts: Int32)
    case UpdatePeerChatUnreadMark(PeerId, MessageId.Namespace, Bool)
    case ResetMessageTagSummary(PeerId, MessageTags, MessageId.Namespace, Int32, MessageHistoryTagNamespaceCountValidityRange)
    case ReadGroupFeedInbox(PeerGroupId, MessageIndex)
    case UpdateState(AuthorizedAccountState.State)
    case UpdateChannelState(PeerId, Int32)
    case UpdateChannelInvalidationPts(PeerId, Int32)
    case UpdateChannelSynchronizedUntilMessage(PeerId, MessageId.Id)
    case UpdateNotificationSettings(AccountStateNotificationSettingsSubject, TelegramPeerNotificationSettings)
    case UpdateGlobalNotificationSettings(AccountStateGlobalNotificationSettingsSubject, MessageNotificationSettings)
    case MergeApiChats([Api.Chat])
    case UpdatePeer(PeerId, (Peer?) -> Peer?)
    case UpdateIsContact(PeerId, Bool)
    case UpdateCachedPeerData(PeerId, (CachedPeerData?) -> CachedPeerData?)
    case UpdateMessagesPinned([MessageId], Bool)
    case MergeApiUsers([Api.User])
    case MergePeerPresences([PeerId: Api.UserStatus], Bool)
    case UpdateSecretChat(chat: Api.EncryptedChat, timestamp: Int32)
    case AddSecretMessages([Api.EncryptedMessage])
    case ReadSecretOutbox(peerId: PeerId, maxTimestamp: Int32, actionTimestamp: Int32)
    case AddPeerInputActivity(chatPeerId: PeerActivitySpace, peerId: PeerId?, activity: PeerInputActivity?)
    case UpdatePinnedItemIds(PeerGroupId, AccountStateUpdatePinnedItemIdsOperation)
    case UpdatePinnedSavedItemIds(AccountStateUpdatePinnedItemIdsOperation)
    case UpdatePinnedTopic(peerId: PeerId, threadId: Int64, isPinned: Bool)
    case UpdatePinnedTopicOrder(peerId: PeerId, threadIds: [Int64])
    case ReadMessageContents(peerIdsAndMessageIds: (PeerId?, [Int32]), date: Int32?)
    case UpdateMessageImpressionCount(MessageId, Int32)
    case UpdateMessageForwardsCount(MessageId, Int32)
    case UpdateInstalledStickerPacks(AccountStateUpdateStickerPacksOperation)
    case UpdateRecentGifs
    case UpdateChatInputState(PeerId, Int64?, SynchronizeableChatInputState?)
    case UpdateCall(Api.PhoneCall)
    case AddCallSignalingData(Int64, Data)
    case UpdateLangPack(String, Api.LangPackDifference?)
    case UpdateMinAvailableMessage(MessageId)
    case UpdatePeerChatInclusion(peerId: PeerId, groupId: PeerGroupId, changedGroup: Bool)
    case UpdatePeersNearby([PeerNearby])
    case UpdateTheme(TelegramTheme)
    case SyncChatListFilters
    case UpdateChatListFilterOrder(order: [Int32])
    case UpdateChatListFilter(id: Int32, filter: Api.DialogFilter?)
    case UpdateReadThread(threadMessageId: MessageId, readMaxId: Int32, isIncoming: Bool, mainChannelMessage: MessageId?)
    case UpdateGroupCallParticipants(id: Int64, accessHash: Int64, participants: [Api.GroupCallParticipant], version: Int32)
    case UpdateGroupCall(peerId: PeerId?, call: Api.GroupCall)
    case UpdateAutoremoveTimeout(peer: Api.Peer, value: CachedPeerAutoremoveTimeout.Value?)
    case UpdateAttachMenuBots
    case UpdateAudioTranscription(messageId: MessageId, id: Int64, isPending: Bool, text: String)
    case UpdateConfig
    case UpdateExtendedMedia(MessageId, [Api.MessageExtendedMedia])
    case ResetForumTopic(topicId: MessageId, data: StoreMessageHistoryThreadData, pts: Int32)
    case UpdateStory(peerId: PeerId, story: Api.StoryItem)
    case UpdateReadStories(peerId: PeerId, maxId: Int32)
    case UpdateStoryStealthMode(data: Api.StoriesStealthMode)
    case UpdateStorySentReaction(peerId: PeerId, id: Int32, reaction: Api.Reaction)
    case UpdateNewAuthorization(isUnconfirmed: Bool, hash: Int64, date: Int32, device: String, location: String)
    case UpdateWallpaper(peerId: PeerId, wallpaper: TelegramWallpaper?)
    case UpdateRevenueBalances(peerId: PeerId, balances: RevenueStats.Balances)
    case UpdateStarsBalance(peerId: PeerId, balance: Api.StarsAmount)
    case UpdateStarsRevenueStatus(peerId: PeerId, status: StarsRevenueStats.Balances)
    case UpdateStarsReactionsDefaultPrivacy(privacy: TelegramPaidReactionPrivacy)
    case ReportMessageDelivery([MessageId])
}

struct HoleFromPreviousState {
    var validateChannelPts: Int32?
    
    func mergedWith(_ other: HoleFromPreviousState) -> HoleFromPreviousState {
        var result = self
        if let pts = self.validateChannelPts, let otherPts = other.validateChannelPts {
            result.validateChannelPts = max(pts, otherPts)
        } else if let pts = self.validateChannelPts {
            result.validateChannelPts = pts
        } else if let otherPts = other.validateChannelPts {
            result.validateChannelPts = otherPts
        }
        return result
    }
}

enum StateResetForumTopics {
    case result(LoadMessageHistoryThreadsResult)
    case error(PeerId)
}

struct ReferencedReplyMessageIds {
    var targetIdsBySourceId: [MessageId: MessageId] = [:]
    
    var isEmpty: Bool {
        return self.targetIdsBySourceId.isEmpty
    }
    
    mutating func add(sourceId: MessageId, targetId: MessageId) {
        if self.targetIdsBySourceId[targetId] == nil {
            self.targetIdsBySourceId[targetId] = sourceId
        }
    }
    
    mutating func formUnion(_ other: ReferencedReplyMessageIds) {
        for (targetId, sourceId) in other.targetIdsBySourceId {
            if self.targetIdsBySourceId[targetId] == nil {
                self.targetIdsBySourceId[targetId] = sourceId
            }
        }
    }
    
    func subtractingStoredIds(_ ids: Set<MessageId>) -> ReferencedReplyMessageIds {
        var result = ReferencedReplyMessageIds()
        for (targetId, sourceId) in self.targetIdsBySourceId {
            if !ids.contains(targetId) {
                result.add(sourceId: sourceId, targetId: targetId)
            }
        }
        return result
    }
}

enum UpdatesStoredStory {
    case item(Stories.Item)
    case placeholder(Stories.Placeholder)
    case deleted
}

struct AccountMutableState {
    let initialState: AccountInitialState
    let branchOperationIndex: Int
    
    var operations: [AccountStateMutationOperation] = []
    
    var state: AuthorizedAccountState.State
    var peers: [PeerId: Peer]
    var apiChats: [PeerId: Api.Chat]
    var channelStates: [PeerId: AccountStateChannelState]
    var peerChatInfos: [PeerId: PeerChatInfo]
    var referencedReplyMessageIds: ReferencedReplyMessageIds
    var referencedStoryIds = Set<StoryId>()
    var referencedGeneralMessageIds: Set<MessageId>
    var storedMessages: Set<MessageId>
    var readInboxMaxIds: [PeerId: MessageId]
    var namespacesWithHolesFromPreviousState: [PeerId: [MessageId.Namespace: HoleFromPreviousState]]
    var updatedOutgoingUniqueMessageIds: [Int64: Int32]
    var storedStories: [StoryId: UpdatesStoredStory]
    var sentScheduledMessageIds: Set<MessageId>
    
    var resetForumTopicLists: [PeerId: StateResetForumTopics] = [:]
    
    var storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>]
    var displayAlerts: [(text: String, isDropAuth: Bool)] = []
    var dismissBotWebViews: [Int64] = []
    
    var insertedPeers: [PeerId: Peer] = [:]
    
    var preCachedResources: [(MediaResource, Data)] = []
    var preCachedStories: [StoryId: Api.StoryItem] = [:]
    
    var updatedMaxMessageId: Int32?
    var updatedQts: Int32?
    
    var externallyUpdatedPeerId = Set<PeerId>()
    
    var authorizationListUpdated: Bool = false
    
    init(initialState: AccountInitialState, initialPeers: [PeerId: Peer], initialReferencedReplyMessageIds: ReferencedReplyMessageIds, initialReferencedGeneralMessageIds: Set<MessageId>, initialStoredMessages: Set<MessageId>, initialStoredStories: [StoryId: UpdatesStoredStory], initialReadInboxMaxIds: [PeerId: MessageId], storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>], initialSentScheduledMessageIds: Set<MessageId>) {
        self.initialState = initialState
        self.state = initialState.state
        self.peers = initialPeers
        self.apiChats = [:]
        self.referencedReplyMessageIds = initialReferencedReplyMessageIds
        self.referencedGeneralMessageIds = initialReferencedGeneralMessageIds
        self.storedMessages = initialStoredMessages
        self.storedStories = initialStoredStories
        self.sentScheduledMessageIds = initialSentScheduledMessageIds
        self.readInboxMaxIds = initialReadInboxMaxIds
        self.channelStates = initialState.channelStates
        self.peerChatInfos = initialState.peerChatInfos
        self.storedMessagesByPeerIdAndTimestamp = storedMessagesByPeerIdAndTimestamp
        self.branchOperationIndex = 0
        self.namespacesWithHolesFromPreviousState = [:]
        self.updatedOutgoingUniqueMessageIds = [:]
    }
    
    init(initialState: AccountInitialState, operations: [AccountStateMutationOperation], state: AuthorizedAccountState.State, peers: [PeerId: Peer], apiChats: [PeerId: Api.Chat], channelStates: [PeerId: AccountStateChannelState], peerChatInfos: [PeerId: PeerChatInfo], referencedReplyMessageIds: ReferencedReplyMessageIds, referencedGeneralMessageIds: Set<MessageId>, storedMessages: Set<MessageId>, storedStories: [StoryId: UpdatesStoredStory], sentScheduledMessageIds: Set<MessageId>, readInboxMaxIds: [PeerId: MessageId], storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>], namespacesWithHolesFromPreviousState: [PeerId: [MessageId.Namespace: HoleFromPreviousState]], updatedOutgoingUniqueMessageIds: [Int64: Int32], displayAlerts: [(text: String, isDropAuth: Bool)], dismissBotWebViews: [Int64], branchOperationIndex: Int) {
        self.initialState = initialState
        self.operations = operations
        self.state = state
        self.peers = peers
        self.apiChats = apiChats
        self.channelStates = channelStates
        self.referencedReplyMessageIds = referencedReplyMessageIds
        self.referencedGeneralMessageIds = referencedGeneralMessageIds
        self.storedMessages = storedMessages
        self.storedStories = storedStories
        self.sentScheduledMessageIds = sentScheduledMessageIds
        self.peerChatInfos = peerChatInfos
        self.readInboxMaxIds = readInboxMaxIds
        self.storedMessagesByPeerIdAndTimestamp = storedMessagesByPeerIdAndTimestamp
        self.namespacesWithHolesFromPreviousState = namespacesWithHolesFromPreviousState
        self.updatedOutgoingUniqueMessageIds = updatedOutgoingUniqueMessageIds
        self.displayAlerts = displayAlerts
        self.dismissBotWebViews = dismissBotWebViews
        self.branchOperationIndex = branchOperationIndex
    }
    
    func branch() -> AccountMutableState {
        return AccountMutableState(initialState: self.initialState, operations: self.operations, state: self.state, peers: self.peers, apiChats: self.apiChats, channelStates: self.channelStates, peerChatInfos: self.peerChatInfos, referencedReplyMessageIds: self.referencedReplyMessageIds, referencedGeneralMessageIds: self.referencedGeneralMessageIds, storedMessages: self.storedMessages, storedStories: self.storedStories, sentScheduledMessageIds: self.sentScheduledMessageIds, readInboxMaxIds: self.readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: self.storedMessagesByPeerIdAndTimestamp, namespacesWithHolesFromPreviousState: self.namespacesWithHolesFromPreviousState, updatedOutgoingUniqueMessageIds: self.updatedOutgoingUniqueMessageIds, displayAlerts: self.displayAlerts, dismissBotWebViews: self.dismissBotWebViews, branchOperationIndex: self.operations.count)
    }
    
    mutating func merge(_ other: AccountMutableState) {
        self.referencedReplyMessageIds.formUnion(other.referencedReplyMessageIds)
        self.referencedGeneralMessageIds.formUnion(other.referencedGeneralMessageIds)
        
        for (id, story) in other.storedStories {
            self.storedStories[id] = story
        }
        
        self.sentScheduledMessageIds.formUnion(other.sentScheduledMessageIds)
        
        for i in other.branchOperationIndex ..< other.operations.count {
            self.addOperation(other.operations[i])
        }
        for (_, peer) in other.insertedPeers {
            self.peers[peer.id] = peer
        }
        for (_, chat) in other.apiChats {
            self.apiChats[chat.peerId] = chat
        }
        self.preCachedResources.append(contentsOf: other.preCachedResources)
        
        for (id, story) in other.preCachedStories {
            self.preCachedStories[id] = story
        }
        
        self.externallyUpdatedPeerId.formUnion(other.externallyUpdatedPeerId)
        for (peerId, namespaces) in other.namespacesWithHolesFromPreviousState {
            if self.namespacesWithHolesFromPreviousState[peerId] == nil {
                self.namespacesWithHolesFromPreviousState[peerId] = [:]
            }
            for (namespace, namespaceState) in namespaces {
                if self.namespacesWithHolesFromPreviousState[peerId]![namespace] == nil {
                    self.namespacesWithHolesFromPreviousState[peerId]![namespace] = namespaceState
                } else {
                    self.namespacesWithHolesFromPreviousState[peerId]![namespace] = self.namespacesWithHolesFromPreviousState[peerId]![namespace]!.mergedWith(namespaceState)
                }
            }
        }
        self.updatedOutgoingUniqueMessageIds.merge(other.updatedOutgoingUniqueMessageIds, uniquingKeysWith: { lhs, _ in lhs })
        self.displayAlerts.append(contentsOf: other.displayAlerts)
        self.dismissBotWebViews.append(contentsOf: other.dismissBotWebViews)
        
        self.resetForumTopicLists.merge(other.resetForumTopicLists, uniquingKeysWith: { lhs, _ in lhs })
    }
    
    mutating func addPreCachedResource(_ resource: MediaResource, data: Data) {
        self.preCachedResources.append((resource, data))
    }
    
    mutating func addPreCachedStory(id: StoryId, story: Api.StoryItem) {
        self.preCachedStories[id] = story
    }
    
    mutating func addExternallyUpdatedPeerId(_ peerId: PeerId) {
        self.externallyUpdatedPeerId.insert(peerId)
    }
    
    mutating func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) {
        self.addOperation(.AddMessages(messages, location))
    }
    
    mutating func addScheduledMessages(_ messages: [StoreMessage]) {
        self.addOperation(.AddScheduledMessages(messages))
    }
    
    mutating func addQuickReplyMessages(_ messages: [StoreMessage]) {
        self.addOperation(.AddQuickReplyMessages(messages))
    }
    
    mutating func addDisplayAlert(_ text: String, isDropAuth: Bool) {
        self.displayAlerts.append((text: text, isDropAuth: isDropAuth))
    }

    mutating func addDismissWebView(_ queryId: Int64) {
        self.dismissBotWebViews.append(queryId)
    }

    mutating func deleteMessagesWithGlobalIds(_ globalIds: [Int32]) {
        self.addOperation(.DeleteMessagesWithGlobalIds(globalIds))
    }
    
    mutating func deleteMessages(_ messageIds: [MessageId]) {
        self.addOperation(.DeleteMessages(messageIds))
    }
    
    mutating func addSentScheduledMessageIds(_ messageIds: [MessageId]) {
        self.sentScheduledMessageIds.formUnion(messageIds)
    }
    
    mutating func editMessage(_ id: MessageId, message: StoreMessage) {
        self.addOperation(.EditMessage(id, message))
    }
    
    mutating func updateMessagePoll(_ id: MediaId, poll: Api.Poll?, results: Api.PollResults) {
        self.addOperation(.UpdateMessagePoll(id, poll, results))
    }
    
    mutating func updateMessageReactions(_ messageId: MessageId, reactions: Api.MessageReactions, eventTimestamp: Int32?) {
        self.addOperation(.UpdateMessageReactions(messageId, reactions, eventTimestamp))
    }
        
    mutating func updateMedia(_ id: MediaId, media: Media?) {
        self.addOperation(.UpdateMedia(id, media))
    }
    
    mutating func readInbox(_ messageId: MessageId) {
        self.addOperation(.ReadInbox(messageId))
    }
    
    mutating func readOutbox(_ messageId: MessageId, timestamp: Int32?) {
        self.addOperation(.ReadOutbox(messageId, timestamp))
    }
    
    mutating func readThread(threadMessageId: MessageId, readMaxId: Int32, isIncoming: Bool, mainChannelMessage: MessageId?) {
        self.addOperation(.UpdateReadThread(threadMessageId: threadMessageId, readMaxId: readMaxId, isIncoming: isIncoming, mainChannelMessage: mainChannelMessage))
    }
    
    mutating func updateGroupCallParticipants(id: Int64, accessHash: Int64, participants: [Api.GroupCallParticipant], version: Int32) {
        self.addOperation(.UpdateGroupCallParticipants(id: id, accessHash: accessHash, participants: participants, version: version))
    }
    
    mutating func updateGroupCall(peerId: PeerId?, call: Api.GroupCall) {
        self.addOperation(.UpdateGroupCall(peerId: peerId, call: call))
    }
    
    mutating func updateAutoremoveTimeout(peer: Api.Peer, value: CachedPeerAutoremoveTimeout.Value?) {
        self.addOperation(.UpdateAutoremoveTimeout(peer: peer, value: value))
    }
    
    mutating func readGroupFeedInbox(groupId: PeerGroupId, index: MessageIndex) {
        self.addOperation(.ReadGroupFeedInbox(groupId, index))
    }
    
    mutating func resetReadState(_ peerId: PeerId, namespace: MessageId.Namespace, maxIncomingReadId: MessageId.Id, maxOutgoingReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32, markedUnread: Bool?) {
        self.addOperation(.ResetReadState(peerId: peerId, namespace: namespace, maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnread))
    }
    
    mutating func resetIncomingReadState(groupId: PeerGroupId, peerId: PeerId, namespace: MessageId.Namespace, maxIncomingReadId: MessageId.Id, count: Int32, pts: Int32) {
        self.addOperation(.ResetIncomingReadState(groupId: groupId, peerId: peerId, namespace: namespace, maxIncomingReadId: maxIncomingReadId, count: count, pts: pts))
    }
    
    mutating func updatePeerChatUnreadMark(_ peerId: PeerId, namespace: MessageId.Namespace, value: Bool) {
        self.addOperation(.UpdatePeerChatUnreadMark(peerId, namespace, value))
    }
    
    mutating func resetMessageTagSummary(_ peerId: PeerId, tag: MessageTags, namespace: MessageId.Namespace, count: Int32, range: MessageHistoryTagNamespaceCountValidityRange) {
        self.addOperation(.ResetMessageTagSummary(peerId, tag, namespace, count, range))
    }
    
    mutating func updateState(_ state: AuthorizedAccountState.State) {
        if self.initialState.state.seq != state.qts {
            self.updatedQts = state.qts
        }
        self.addOperation(.UpdateState(state))
    }
    
    mutating func updateChannelState(_ peerId: PeerId, pts: Int32) {
        self.addOperation(.UpdateChannelState(peerId, pts))
    }
    
    mutating func updateChannelInvalidationPts(_ peerId: PeerId, invalidationPts: Int32) {
        self.addOperation(.UpdateChannelInvalidationPts(peerId, invalidationPts))
    }
    
    mutating func updateChannelSynchronizedUntilMessage(_ peerId: PeerId, id: MessageId.Id) {
        self.addOperation(.UpdateChannelSynchronizedUntilMessage(peerId, id))
    }
    
    mutating func updateNotificationSettings(_ subject: AccountStateNotificationSettingsSubject, notificationSettings: TelegramPeerNotificationSettings) {
        self.addOperation(.UpdateNotificationSettings(subject, notificationSettings))
    }
    
    mutating func updateGlobalNotificationSettings(_ subject: AccountStateGlobalNotificationSettingsSubject, notificationSettings: MessageNotificationSettings) {
        self.addOperation(.UpdateGlobalNotificationSettings(subject, notificationSettings))
    }
    
    mutating func setNeedsHoleFromPreviousState(peerId: PeerId, namespace: MessageId.Namespace, validateChannelPts: Int32?) {
        if self.namespacesWithHolesFromPreviousState[peerId] == nil {
            self.namespacesWithHolesFromPreviousState[peerId] = [:]
        }
        let namespaceState = HoleFromPreviousState(validateChannelPts: validateChannelPts)
        if self.namespacesWithHolesFromPreviousState[peerId]![namespace] == nil {
            self.namespacesWithHolesFromPreviousState[peerId]![namespace] = namespaceState
        } else {
            self.namespacesWithHolesFromPreviousState[peerId]![namespace] = self.namespacesWithHolesFromPreviousState[peerId]![namespace]!.mergedWith(namespaceState)
        }
    }
    
    func isPeerForum(peerId: PeerId) -> Bool {
        if let peer = self.peers[peerId] {
            return peer.isForum
        } else if let chat = self.apiChats[peerId] {
            if let channel = parseTelegramGroupOrChannel(chat: chat) {
                return channel.isForum
            } else {
                return false
            }
        } else {
            Logger.shared.log("AccountIntermediateState", "isPeerForum undefinded for \(peerId)")
            return false
        }
    }
    
    mutating func mergeChats(_ chats: [Api.Chat]) {
        self.addOperation(.MergeApiChats(chats))
        for chat in chats {
            self.apiChats[chat.peerId] = chat
        }
        
        for chat in chats {
            switch chat {
                case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _, _, _, _, _, _, _, _, _):
                    if let participantsCount = participantsCount {
                        self.addOperation(.UpdateCachedPeerData(chat.peerId, { current in
                            var previous: CachedChannelData
                            if let current = current as? CachedChannelData {
                                previous = current
                            } else {
                                previous = CachedChannelData()
                            }
                            return previous.withUpdatedParticipantsSummary(previous.participantsSummary.withUpdatedMemberCount(participantsCount))
                        }))
                    }
                default:
                    break
            }
        }
    }
    
    mutating func updatePeer(_ id: PeerId, _ f: @escaping (Peer?) -> Peer?) {
        self.addOperation(.UpdatePeer(id, f))
    }
    
    mutating func updatePeerIsContact(_ id: PeerId, isContact: Bool) {
        self.addOperation(.UpdateIsContact(id, isContact))
    }
    
    mutating func updateCachedPeerData(_ id: PeerId, _ f: @escaping (CachedPeerData?) -> CachedPeerData?) {
        self.addOperation(.UpdateCachedPeerData(id, f))
    }
    
    mutating func updateMessagesPinned(ids: [MessageId], pinned: Bool) {
        self.addOperation(.UpdateMessagesPinned(ids, pinned))
    }
    
    mutating func updateLangPack(langCode: String, difference: Api.LangPackDifference?) {
        self.addOperation(.UpdateLangPack(langCode, difference))
    }
    
    mutating func updateMinAvailableMessage(_ id: MessageId) {
        self.addOperation(.UpdateMinAvailableMessage(id))
    }
    
    mutating func updatePeerChatInclusion(peerId: PeerId, groupId: PeerGroupId, changedGroup: Bool) {
        self.addOperation(.UpdatePeerChatInclusion(peerId: peerId, groupId: groupId, changedGroup: changedGroup))
    }
    
    mutating func updatePeersNearby(_ peersNearby: [PeerNearby]) {
        self.addOperation(.UpdatePeersNearby(peersNearby))
    }
        
    mutating func updateTheme(_ theme: TelegramTheme) {
        self.addOperation(.UpdateTheme(theme))
    }
    
    mutating func updateWallpaper(peerId: PeerId, wallpaper: TelegramWallpaper?) {
        self.addOperation(.UpdateWallpaper(peerId: peerId, wallpaper: wallpaper))
    }
    
    mutating func mergeUsers(_ users: [Api.User]) {
        self.addOperation(.MergeApiUsers(users))
        
        var presences: [PeerId: Api.UserStatus] = [:]
        for user in users {
            switch user {
                case let .user(_, _, id, _, _, _, _, _, _, status, _, _, _, _, _, _, _, _, _, _, _, _):
                    if let status = status {
                        presences[PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))] = status
                    }
                    break
                case .userEmpty:
                    break
            }
        }
        if !presences.isEmpty {
            self.addOperation(.MergePeerPresences(presences, false))
        }
    }
    
    mutating func mergePeerPresences(_ presences: [PeerId: Api.UserStatus], explicit: Bool) {
        self.addOperation(.MergePeerPresences(presences, explicit))
    }
    
    mutating func updateSecretChat(chat: Api.EncryptedChat, timestamp: Int32) {
        self.addOperation(.UpdateSecretChat(chat: chat, timestamp: timestamp))
    }
    
    mutating func addSecretMessages(_ messages: [Api.EncryptedMessage]) {
        self.addOperation(.AddSecretMessages(messages))
    }
    
    mutating func readSecretOutbox(peerId: PeerId, timestamp: Int32, actionTimestamp: Int32) {
        self.addOperation(.ReadSecretOutbox(peerId: peerId, maxTimestamp: timestamp, actionTimestamp: actionTimestamp))
    }
    
    mutating func addPeerInputActivity(chatPeerId: PeerActivitySpace, peerId: PeerId?, activity: PeerInputActivity?) {
        self.addOperation(.AddPeerInputActivity(chatPeerId: chatPeerId, peerId: peerId, activity: activity))
    }
    
    mutating func addUpdatePinnedItemIds(groupId: PeerGroupId, operation: AccountStateUpdatePinnedItemIdsOperation) {
        self.addOperation(.UpdatePinnedItemIds(groupId, operation))
    }
    
    mutating func addUpdatePinnedSavedItemIds(operation: AccountStateUpdatePinnedItemIdsOperation) {
        self.addOperation(.UpdatePinnedSavedItemIds(operation))
    }
    
    mutating func addUpdatePinnedTopic(peerId: PeerId, threadId: Int64, isPinned: Bool) {
        self.addOperation(.UpdatePinnedTopic(peerId: peerId, threadId: threadId, isPinned: isPinned))
    }
    
    mutating func addUpdatePinnedTopicOrder(peerId: PeerId, threadIds: [Int64]) {
        self.addOperation(.UpdatePinnedTopicOrder(peerId: peerId, threadIds: threadIds))
    }
    
    mutating func addReadMessagesContents(_ peerIdsAndMessageIds: (PeerId?, [Int32]), date: Int32?) {
        self.addOperation(.ReadMessageContents(peerIdsAndMessageIds: peerIdsAndMessageIds, date: date))
    }
    
    mutating func addUpdateMessageImpressionCount(id: MessageId, count: Int32) {
        self.addOperation(.UpdateMessageImpressionCount(id, count))
    }
    
    mutating func addUpdateMessageForwardsCount(id: MessageId, count: Int32) {
        self.addOperation(.UpdateMessageForwardsCount(id, count))
    }
    
    mutating func addUpdateInstalledStickerPacks(_ operation: AccountStateUpdateStickerPacksOperation) {
        self.addOperation(.UpdateInstalledStickerPacks(operation))
    }
    
    mutating func addUpdateRecentGifs() {
        self.addOperation(.UpdateRecentGifs)
    }
    
    mutating func addUpdateChatInputState(peerId: PeerId, threadId: Int64?, state: SynchronizeableChatInputState?) {
        self.addOperation(.UpdateChatInputState(peerId, threadId, state))
    }
    
    mutating func addUpdateCall(_ call: Api.PhoneCall) {
        self.addOperation(.UpdateCall(call))
    }
    
    mutating func addCallSignalingData(callId: Int64, data: Data) {
        self.addOperation(.AddCallSignalingData(callId, data))
    }
    
    mutating func addSyncChatListFilters() {
        self.addOperation(.SyncChatListFilters)
    }
    
    mutating func addUpdateChatListFilterOrder(order: [Int32]) {
        self.addOperation(.UpdateChatListFilterOrder(order: order))
    }
    
    mutating func addUpdateChatListFilter(id: Int32, filter: Api.DialogFilter?) {
        self.addOperation(.UpdateChatListFilter(id: id, filter: filter))
    }
    
    mutating func addUpdateAttachMenuBots() {
        self.addOperation(.UpdateAttachMenuBots)
    }
    
    mutating func updateAudioTranscription(messageId: MessageId, id: Int64, isPending: Bool, text: String) {
        self.addOperation(.UpdateAudioTranscription(messageId: messageId, id: id, isPending: isPending, text: text))
    }
    
    mutating func addDismissedWebView(queryId: Int64) {
        self.addOperation(.UpdateAttachMenuBots)
    }
    
    mutating func reloadConfig() {
        self.addOperation(.UpdateConfig)
    }
    
    mutating func updateExtendedMedia(_ messageId: MessageId, extendedMedia: [Api.MessageExtendedMedia]) {
        self.addOperation(.UpdateExtendedMedia(messageId, extendedMedia))
    }
    
    mutating func updateStory(peerId: PeerId, story: Api.StoryItem) {
        self.addOperation(.UpdateStory(peerId: peerId, story: story))
    }
    
    mutating func readStories(peerId: PeerId, maxId: Int32) {
        self.addOperation(.UpdateReadStories(peerId: peerId, maxId: maxId))
    }
    
    mutating func updateStoryStealthMode(_ data: Api.StoriesStealthMode) {
        self.addOperation(.UpdateStoryStealthMode(data: data))
    }
    
    mutating func updateStorySentReaction(peerId: PeerId, id: Int32, reaction: Api.Reaction) {
        self.addOperation(.UpdateStorySentReaction(peerId: peerId, id: id, reaction: reaction))
    }
    
    mutating func updateNewAuthorization(isUnconfirmed: Bool, hash: Int64, date: Int32, device: String, location: String) {
        self.addOperation(.UpdateNewAuthorization(isUnconfirmed: isUnconfirmed, hash: hash, date: date, device: device, location: location))
    }
    
    mutating func updateRevenueBalances(peerId: PeerId, balances: RevenueStats.Balances) {
        self.addOperation(.UpdateRevenueBalances(peerId: peerId, balances: balances))
    }
    
    mutating func updateStarsBalance(peerId: PeerId, balance: Api.StarsAmount) {
        self.addOperation(.UpdateStarsBalance(peerId: peerId, balance: balance))
    }
    
    mutating func updateStarsRevenueStatus(peerId: PeerId, status: StarsRevenueStats.Balances) {
        self.addOperation(.UpdateStarsRevenueStatus(peerId: peerId, status: status))
    }
    
    mutating func updateStarsReactionsDefaultPrivacy(privacy: TelegramPaidReactionPrivacy) {
        self.addOperation(.UpdateStarsReactionsDefaultPrivacy(privacy: privacy))
    }
    
    mutating func addReportMessageDelivery(messageIds: [MessageId]) {
        self.addOperation(.ReportMessageDelivery(messageIds))
    }
    
    mutating func addOperation(_ operation: AccountStateMutationOperation) {
        switch operation {
        case .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpdateMessagePoll, .UpdateMessageReactions, .UpdateMedia, .ReadOutbox, .ReadGroupFeedInbox, .MergePeerPresences, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity, .UpdateCachedPeerData, .UpdatePinnedItemIds, .UpdatePinnedSavedItemIds, .UpdatePinnedTopic, .UpdatePinnedTopicOrder, .ReadMessageContents, .UpdateMessageImpressionCount, .UpdateMessageForwardsCount, .UpdateInstalledStickerPacks, .UpdateRecentGifs, .UpdateChatInputState, .UpdateCall, .AddCallSignalingData, .UpdateLangPack, .UpdateMinAvailableMessage, .UpdatePeerChatUnreadMark, .UpdateIsContact, .UpdatePeerChatInclusion, .UpdatePeersNearby, .UpdateTheme, .UpdateWallpaper, .SyncChatListFilters, .UpdateChatListFilterOrder, .UpdateChatListFilter, .UpdateReadThread, .UpdateGroupCallParticipants, .UpdateGroupCall, .UpdateMessagesPinned, .UpdateAutoremoveTimeout, .UpdateAttachMenuBots, .UpdateAudioTranscription, .UpdateConfig, .UpdateExtendedMedia, .ResetForumTopic, .UpdateStory, .UpdateReadStories, .UpdateStoryStealthMode, .UpdateStorySentReaction, .UpdateNewAuthorization, .UpdateRevenueBalances, .UpdateStarsBalance, .UpdateStarsRevenueStatus, .UpdateStarsReactionsDefaultPrivacy, .ReportMessageDelivery:
                break
            case let .AddMessages(messages, location):
                for message in messages {
                    if case let .Id(id) = message.id {
                        self.storedMessages.insert(id)
                        if case .UpperHistoryBlock = location {
                            if (id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup) && id.namespace == Namespaces.Message.Cloud {
                                if let updatedMaxMessageId = self.updatedMaxMessageId {
                                    if updatedMaxMessageId < id.id {
                                        self.updatedMaxMessageId = id.id
                                    }
                                } else {
                                    self.updatedMaxMessageId = id.id
                                }
                            }
                        }
                        inner: for attribute in message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                self.referencedReplyMessageIds.add(sourceId: id, targetId: attribute.messageId)
                            } else if let attribute = attribute as? ReplyStoryAttribute {
                                self.referencedStoryIds.insert(attribute.storyId)
                            }
                        }
                    }
                }
            case let .AddScheduledMessages(messages):
                for message in messages {
                    if case let .Id(id) = message.id {
                        self.storedMessages.insert(id)
                        inner: for attribute in message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                self.referencedReplyMessageIds.add(sourceId: id, targetId: attribute.messageId)
                            } else if let attribute = attribute as? ReplyStoryAttribute {
                                self.referencedStoryIds.insert(attribute.storyId)
                            }
                        }
                    }
                }
            case let .AddQuickReplyMessages(messages):
                for message in messages {
                    if case let .Id(id) = message.id {
                        self.storedMessages.insert(id)
                        inner: for attribute in message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                self.referencedReplyMessageIds.add(sourceId: id, targetId: attribute.messageId)
                            } else if let attribute = attribute as? ReplyStoryAttribute {
                                self.referencedStoryIds.insert(attribute.storyId)
                            }
                        }
                    }
                }
            case let .UpdateState(state):
                self.state = state
            case let .UpdateChannelState(peerId, pts):
                self.channelStates[peerId] = AccountStateChannelState(pts: pts)
            case .UpdateChannelInvalidationPts:
                break
            case .UpdateChannelSynchronizedUntilMessage:
                break
            case let .UpdateNotificationSettings(subject, notificationSettings):
                if case let .peer(peerId, threadId) = subject {
                    if threadId == nil, var currentInfo = self.peerChatInfos[peerId] {
                        currentInfo.notificationSettings = notificationSettings
                        self.peerChatInfos[peerId] = currentInfo
                    }
                }
            case .UpdateGlobalNotificationSettings:
                break
            case let .MergeApiChats(chats):
                for chat in chats {
                    if let groupOrChannel = mergeGroupOrChannel(lhs: peers[chat.peerId], rhs: chat) {
                        peers[groupOrChannel.id] = groupOrChannel
                        insertedPeers[groupOrChannel.id] = groupOrChannel
                    }
                }
            case let .MergeApiUsers(users):
                for apiUser in users {
                    if let user = TelegramUser.merge(peers[apiUser.peerId] as? TelegramUser, rhs: apiUser) {
                        peers[user.id] = user
                        insertedPeers[user.id] = user
                    }
                }
            case let .UpdatePeer(id, f):
                let peer = self.peers[id]
                if let updatedPeer = f(peer) {
                    peers[id] = updatedPeer
                    insertedPeers[id] = updatedPeer
                }
            case let .ReadInbox(messageId):
                let current = self.readInboxMaxIds[messageId.peerId]
                if current == nil || current! < messageId {
                    self.readInboxMaxIds[messageId.peerId] = messageId
                }
            case let .ResetReadState(peerId, namespace, maxIncomingReadId, _, _, _, _):
                let current = self.readInboxMaxIds[peerId]
                if namespace == Namespaces.Message.Cloud {
                    if current == nil || current!.id < maxIncomingReadId {
                        self.readInboxMaxIds[peerId] = MessageId(peerId: peerId, namespace: namespace, id: maxIncomingReadId)
                    }
                }
            case let .ResetIncomingReadState(_, peerId, namespace, maxIncomingReadId, _, _):
                let current = self.readInboxMaxIds[peerId]
                if namespace == Namespaces.Message.Cloud {
                    if current == nil || current!.id < maxIncomingReadId {
                        self.readInboxMaxIds[peerId] = MessageId(peerId: peerId, namespace: namespace, id: maxIncomingReadId)
                    }
                }
            case .ResetMessageTagSummary:
                break
        }
        
        self.operations.append(operation)
    }
}

struct AccountFinalState {
    var state: AccountMutableState
    var shouldPoll: Bool
    var incomplete: Bool
    var missingUpdatesFromChannels: Set<PeerId>
    var discard: Bool
}

struct AccountReplayedFinalState {
    let state: AccountFinalState
    let addedIncomingMessageIds: [MessageId]
    let addedReactionEvents: [(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)]
    let wasScheduledMessageIds: [MessageId]
    let addedSecretMessageIds: [MessageId]
    let deletedMessageIds: [DeletedMessageId]
    let updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]]
    let updatedWebpages: [MediaId: TelegramMediaWebpage]
    let updatedCalls: [Api.PhoneCall]
    let addedCallSignalingData: [(Int64, Data)]
    let updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)]
    let storyUpdates: [InternalStoryUpdate]
    let updatedPeersNearby: [PeerNearby]?
    let isContactUpdates: [(PeerId, Bool)]
    let delayNotificatonsUntil: Int32?
    let updatedIncomingThreadReadStates: [MessageId: MessageId.Id]
    let updatedOutgoingThreadReadStates: [MessageId: MessageId.Id]
    let updateConfig: Bool
    let isPremiumUpdated: Bool
    let updatedRevenueBalances: [PeerId: RevenueStats.Balances]
    let updatedStarsBalance: [PeerId: StarsAmount]
    let updatedStarsRevenueStatus: [PeerId: StarsRevenueStats.Balances]
    let sentScheduledMessageIds: Set<MessageId>
    let reportMessageDelivery: Set<MessageId>
}

struct AccountFinalStateEvents {
    let addedIncomingMessageIds: [MessageId]
    let addedReactionEvents: [(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)]
    let wasScheduledMessageIds: [MessageId]
    let deletedMessageIds: [DeletedMessageId]
    let sentScheduledMessageIds: Set<MessageId>
    let updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]]
    let updatedWebpages: [MediaId: TelegramMediaWebpage]
    let updatedCalls: [Api.PhoneCall]
    let addedCallSignalingData: [(Int64, Data)]
    let updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)]
    let storyUpdates: [InternalStoryUpdate]
    let updatedPeersNearby: [PeerNearby]?
    let isContactUpdates: [(PeerId, Bool)]
    let displayAlerts: [(text: String, isDropAuth: Bool)]
    let dismissBotWebViews: [Int64]
    let delayNotificatonsUntil: Int32?
    let updatedMaxMessageId: Int32?
    let updatedQts: Int32?
    let externallyUpdatedPeerId: Set<PeerId>
    let authorizationListUpdated: Bool
    let updatedIncomingThreadReadStates: [MessageId: MessageId.Id]
    let updatedOutgoingThreadReadStates: [MessageId: MessageId.Id]
    let updateConfig: Bool
    let isPremiumUpdated: Bool
    let updatedRevenueBalances: [PeerId: RevenueStats.Balances]
    let updatedStarsBalance: [PeerId: StarsAmount]
    let updatedStarsRevenueStatus: [PeerId: StarsRevenueStats.Balances]
    let reportMessageDelivery: Set<MessageId>
    
    var isEmpty: Bool {
        return self.addedIncomingMessageIds.isEmpty && self.addedReactionEvents.isEmpty && self.wasScheduledMessageIds.isEmpty && self.deletedMessageIds.isEmpty && self.sentScheduledMessageIds.isEmpty && self.updatedTypingActivities.isEmpty && self.updatedWebpages.isEmpty && self.updatedCalls.isEmpty && self.addedCallSignalingData.isEmpty && self.updatedGroupCallParticipants.isEmpty && self.storyUpdates.isEmpty && self.updatedPeersNearby?.isEmpty ?? true && self.isContactUpdates.isEmpty && self.displayAlerts.isEmpty && self.dismissBotWebViews.isEmpty && self.delayNotificatonsUntil == nil && self.updatedMaxMessageId == nil && self.updatedQts == nil && self.externallyUpdatedPeerId.isEmpty && !authorizationListUpdated && self.updatedIncomingThreadReadStates.isEmpty && self.updatedOutgoingThreadReadStates.isEmpty && !self.updateConfig && !self.isPremiumUpdated && self.updatedRevenueBalances.isEmpty && self.updatedStarsBalance.isEmpty && self.updatedStarsRevenueStatus.isEmpty && self.reportMessageDelivery.isEmpty
    }
    
    init(addedIncomingMessageIds: [MessageId] = [], addedReactionEvents: [(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)] = [], wasScheduledMessageIds: [MessageId] = [], deletedMessageIds: [DeletedMessageId] = [], updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]] = [:], updatedWebpages: [MediaId: TelegramMediaWebpage] = [:], updatedCalls: [Api.PhoneCall] = [], addedCallSignalingData: [(Int64, Data)] = [], updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)] = [], storyUpdates: [InternalStoryUpdate] = [], updatedPeersNearby: [PeerNearby]? = nil, isContactUpdates: [(PeerId, Bool)] = [], displayAlerts: [(text: String, isDropAuth: Bool)] = [], dismissBotWebViews: [Int64] = [], delayNotificatonsUntil: Int32? = nil, updatedMaxMessageId: Int32? = nil, updatedQts: Int32? = nil, externallyUpdatedPeerId: Set<PeerId> = Set(), authorizationListUpdated: Bool = false, updatedIncomingThreadReadStates: [MessageId: MessageId.Id] = [:], updatedOutgoingThreadReadStates: [MessageId: MessageId.Id] = [:], updateConfig: Bool = false, isPremiumUpdated: Bool = false, updatedRevenueBalances: [PeerId: RevenueStats.Balances] = [:], updatedStarsBalance: [PeerId: StarsAmount] = [:], updatedStarsRevenueStatus: [PeerId: StarsRevenueStats.Balances] = [:], sentScheduledMessageIds: Set<MessageId> = Set(), reportMessageDelivery: Set<MessageId> = Set()) {
        self.addedIncomingMessageIds = addedIncomingMessageIds
        self.addedReactionEvents = addedReactionEvents
        self.wasScheduledMessageIds = wasScheduledMessageIds
        self.deletedMessageIds = deletedMessageIds
        self.updatedTypingActivities = updatedTypingActivities
        self.updatedWebpages = updatedWebpages
        self.updatedCalls = updatedCalls
        self.addedCallSignalingData = addedCallSignalingData
        self.updatedGroupCallParticipants = updatedGroupCallParticipants
        self.storyUpdates = storyUpdates
        self.updatedPeersNearby = updatedPeersNearby
        self.isContactUpdates = isContactUpdates
        self.displayAlerts = displayAlerts
        self.dismissBotWebViews = dismissBotWebViews
        self.delayNotificatonsUntil = delayNotificatonsUntil
        self.updatedMaxMessageId = updatedMaxMessageId
        self.updatedQts = updatedQts
        self.externallyUpdatedPeerId = externallyUpdatedPeerId
        self.authorizationListUpdated = authorizationListUpdated
        self.updatedIncomingThreadReadStates = updatedIncomingThreadReadStates
        self.updatedOutgoingThreadReadStates = updatedOutgoingThreadReadStates
        self.updateConfig = updateConfig
        self.isPremiumUpdated = isPremiumUpdated
        self.updatedRevenueBalances = updatedRevenueBalances
        self.updatedStarsBalance = updatedStarsBalance
        self.updatedStarsRevenueStatus = updatedStarsRevenueStatus
        self.sentScheduledMessageIds = sentScheduledMessageIds
        self.reportMessageDelivery = reportMessageDelivery
    }
    
    init(state: AccountReplayedFinalState) {
        self.addedIncomingMessageIds = state.addedIncomingMessageIds
        self.addedReactionEvents = state.addedReactionEvents
        self.wasScheduledMessageIds = state.wasScheduledMessageIds
        self.deletedMessageIds = state.deletedMessageIds
        self.updatedTypingActivities = state.updatedTypingActivities
        self.updatedWebpages = state.updatedWebpages
        self.updatedCalls = state.updatedCalls
        self.addedCallSignalingData = state.addedCallSignalingData
        self.updatedGroupCallParticipants = state.updatedGroupCallParticipants
        self.storyUpdates = state.storyUpdates
        self.updatedPeersNearby = state.updatedPeersNearby
        self.isContactUpdates = state.isContactUpdates
        self.displayAlerts = state.state.state.displayAlerts
        self.dismissBotWebViews = state.state.state.dismissBotWebViews
        self.delayNotificatonsUntil = state.delayNotificatonsUntil
        self.updatedMaxMessageId = state.state.state.updatedMaxMessageId
        self.updatedQts = state.state.state.updatedQts
        self.externallyUpdatedPeerId = state.state.state.externallyUpdatedPeerId
        self.authorizationListUpdated = state.state.state.authorizationListUpdated
        self.updatedIncomingThreadReadStates = state.updatedIncomingThreadReadStates
        self.updatedOutgoingThreadReadStates = state.updatedOutgoingThreadReadStates
        self.updateConfig = state.updateConfig
        self.isPremiumUpdated = state.isPremiumUpdated
        self.updatedRevenueBalances = state.updatedRevenueBalances
        self.updatedStarsBalance = state.updatedStarsBalance
        self.updatedStarsRevenueStatus = state.updatedStarsRevenueStatus
        self.sentScheduledMessageIds = state.sentScheduledMessageIds
        self.reportMessageDelivery = state.reportMessageDelivery
    }
    
    func union(with other: AccountFinalStateEvents) -> AccountFinalStateEvents {
        var delayNotificatonsUntil = self.delayNotificatonsUntil
        if let other = self.delayNotificatonsUntil {
            if delayNotificatonsUntil == nil || other > delayNotificatonsUntil! {
                delayNotificatonsUntil = other
            }
        }
        var updatedMaxMessageId: Int32?
        var updatedQts: Int32?
        if let lhsMaxMessageId = self.updatedMaxMessageId, let rhsMaxMessageId = other.updatedMaxMessageId {
            updatedMaxMessageId = max(lhsMaxMessageId, rhsMaxMessageId)
        } else {
            updatedMaxMessageId = self.updatedMaxMessageId ?? other.updatedMaxMessageId
        }
        if let lhsQts = self.updatedQts, let rhsQts = other.updatedQts {
            updatedQts = max(lhsQts, rhsQts)
        } else {
            updatedQts = self.updatedQts ?? other.updatedQts
        }
        
        let externallyUpdatedPeerId = self.externallyUpdatedPeerId.union(other.externallyUpdatedPeerId)
        let authorizationListUpdated = self.authorizationListUpdated || other.authorizationListUpdated
        
        let updateConfig = self.updateConfig || other.updateConfig
        
        let isPremiumUpdated = self.isPremiumUpdated || other.isPremiumUpdated
        
        var sentScheduledMessageIds = self.sentScheduledMessageIds
        sentScheduledMessageIds.formUnion(other.sentScheduledMessageIds)
        
        var reportMessageDelivery = self.reportMessageDelivery
        reportMessageDelivery.formUnion(other.reportMessageDelivery)
        
        return AccountFinalStateEvents(addedIncomingMessageIds: self.addedIncomingMessageIds + other.addedIncomingMessageIds, addedReactionEvents: self.addedReactionEvents + other.addedReactionEvents, wasScheduledMessageIds: self.wasScheduledMessageIds + other.wasScheduledMessageIds, deletedMessageIds: self.deletedMessageIds + other.deletedMessageIds, updatedTypingActivities: self.updatedTypingActivities, updatedWebpages: self.updatedWebpages, updatedCalls: self.updatedCalls + other.updatedCalls, addedCallSignalingData: self.addedCallSignalingData + other.addedCallSignalingData, updatedGroupCallParticipants: self.updatedGroupCallParticipants + other.updatedGroupCallParticipants, storyUpdates: self.storyUpdates + other.storyUpdates, isContactUpdates: self.isContactUpdates + other.isContactUpdates, displayAlerts: self.displayAlerts + other.displayAlerts, dismissBotWebViews: self.dismissBotWebViews + other.dismissBotWebViews, delayNotificatonsUntil: delayNotificatonsUntil, updatedMaxMessageId: updatedMaxMessageId, updatedQts: updatedQts, externallyUpdatedPeerId: externallyUpdatedPeerId, authorizationListUpdated: authorizationListUpdated, updatedIncomingThreadReadStates: self.updatedIncomingThreadReadStates.merging(other.updatedIncomingThreadReadStates, uniquingKeysWith: { lhs, _ in lhs }), updateConfig: updateConfig, isPremiumUpdated: isPremiumUpdated, updatedRevenueBalances: self.updatedRevenueBalances.merging(other.updatedRevenueBalances, uniquingKeysWith: { lhs, _ in lhs }), updatedStarsBalance: self.updatedStarsBalance.merging(other.updatedStarsBalance, uniquingKeysWith: { lhs, _ in lhs }), updatedStarsRevenueStatus: self.updatedStarsRevenueStatus.merging(other.updatedStarsRevenueStatus, uniquingKeysWith: { lhs, _ in lhs }), sentScheduledMessageIds: sentScheduledMessageIds, reportMessageDelivery: reportMessageDelivery)
    }
}
