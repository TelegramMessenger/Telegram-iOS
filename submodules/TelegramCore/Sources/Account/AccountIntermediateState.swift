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
    case sync
}

enum AccountStateNotificationSettingsSubject {
    case peer(PeerId)
}

enum AccountStateGlobalNotificationSettingsSubject {
    case privateChats
    case groups
    case channels
}

enum AccountStateMutationOperation {
    case AddMessages([StoreMessage], AddMessagesLocation)
    case AddScheduledMessages([StoreMessage])
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
    case UpdateNotificationSettings(AccountStateNotificationSettingsSubject, PeerNotificationSettings)
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
    case ReadMessageContents((PeerId?, [Int32]))
    case UpdateMessageImpressionCount(MessageId, Int32)
    case UpdateMessageForwardsCount(MessageId, Int32)
    case UpdateInstalledStickerPacks(AccountStateUpdateStickerPacksOperation)
    case UpdateRecentGifs
    case UpdateChatInputState(PeerId, SynchronizeableChatInputState?)
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
    case UpdateGroupCall(peerId: PeerId, call: Api.GroupCall)
    case UpdateAutoremoveTimeout(peer: Api.Peer, value: CachedPeerAutoremoveTimeout.Value?)
    case UpdateAttachMenuBots
    case UpdateAudioTranscription(messageId: MessageId, id: Int64, isPending: Bool, text: String)
    case UpdateConfig
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

struct AccountMutableState {
    let initialState: AccountInitialState
    let branchOperationIndex: Int
    
    var operations: [AccountStateMutationOperation] = []
    
    var state: AuthorizedAccountState.State
    var peers: [PeerId: Peer]
    var channelStates: [PeerId: AccountStateChannelState]
    var peerChatInfos: [PeerId: PeerChatInfo]
    var referencedMessageIds: Set<MessageId>
    var storedMessages: Set<MessageId>
    var readInboxMaxIds: [PeerId: MessageId]
    var namespacesWithHolesFromPreviousState: [PeerId: [MessageId.Namespace: HoleFromPreviousState]]
    var updatedOutgoingUniqueMessageIds: [Int64: Int32]
    
    var storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>]
    var displayAlerts: [(text: String, isDropAuth: Bool)] = []
    var dismissBotWebViews: [Int64] = []
    
    var insertedPeers: [PeerId: Peer] = [:]
    
    var preCachedResources: [(MediaResource, Data)] = []
    
    var updatedMaxMessageId: Int32?
    var updatedQts: Int32?
    
    var externallyUpdatedPeerId = Set<PeerId>()
    
    var authorizationListUpdated: Bool = false
    
    init(initialState: AccountInitialState, initialPeers: [PeerId: Peer], initialReferencedMessageIds: Set<MessageId>, initialStoredMessages: Set<MessageId>, initialReadInboxMaxIds: [PeerId: MessageId], storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>]) {
        self.initialState = initialState
        self.state = initialState.state
        self.peers = initialPeers
        self.referencedMessageIds = initialReferencedMessageIds
        self.storedMessages = initialStoredMessages
        self.readInboxMaxIds = initialReadInboxMaxIds
        self.channelStates = initialState.channelStates
        self.peerChatInfos = initialState.peerChatInfos
        self.storedMessagesByPeerIdAndTimestamp = storedMessagesByPeerIdAndTimestamp
        self.branchOperationIndex = 0
        self.namespacesWithHolesFromPreviousState = [:]
        self.updatedOutgoingUniqueMessageIds = [:]
    }
    
    init(initialState: AccountInitialState, operations: [AccountStateMutationOperation], state: AuthorizedAccountState.State, peers: [PeerId: Peer], channelStates: [PeerId: AccountStateChannelState], peerChatInfos: [PeerId: PeerChatInfo], referencedMessageIds: Set<MessageId>, storedMessages: Set<MessageId>, readInboxMaxIds: [PeerId: MessageId], storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>], namespacesWithHolesFromPreviousState: [PeerId: [MessageId.Namespace: HoleFromPreviousState]], updatedOutgoingUniqueMessageIds: [Int64: Int32], displayAlerts: [(text: String, isDropAuth: Bool)], dismissBotWebViews: [Int64], branchOperationIndex: Int) {
        self.initialState = initialState
        self.operations = operations
        self.state = state
        self.peers = peers
        self.channelStates = channelStates
        self.referencedMessageIds = referencedMessageIds
        self.storedMessages = storedMessages
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
        return AccountMutableState(initialState: self.initialState, operations: self.operations, state: self.state, peers: self.peers, channelStates: self.channelStates, peerChatInfos: self.peerChatInfos, referencedMessageIds: self.referencedMessageIds, storedMessages: self.storedMessages, readInboxMaxIds: self.readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: self.storedMessagesByPeerIdAndTimestamp, namespacesWithHolesFromPreviousState: self.namespacesWithHolesFromPreviousState, updatedOutgoingUniqueMessageIds: self.updatedOutgoingUniqueMessageIds, displayAlerts: self.displayAlerts, dismissBotWebViews: self.dismissBotWebViews, branchOperationIndex: self.operations.count)
    }
    
    mutating func merge(_ other: AccountMutableState) {
        self.referencedMessageIds.formUnion(other.referencedMessageIds)
        for i in other.branchOperationIndex ..< other.operations.count {
            self.addOperation(other.operations[i])
        }
        for (_, peer) in other.insertedPeers {
            self.peers[peer.id] = peer
        }
        self.preCachedResources.append(contentsOf: other.preCachedResources)
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
    }
    
    mutating func addPreCachedResource(_ resource: MediaResource, data: Data) {
        self.preCachedResources.append((resource, data))
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
    
    mutating func updateGroupCall(peerId: PeerId, call: Api.GroupCall) {
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
    
    mutating func updateNotificationSettings(_ subject: AccountStateNotificationSettingsSubject, notificationSettings: PeerNotificationSettings) {
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
    
    mutating func mergeChats(_ chats: [Api.Chat]) {
        self.addOperation(.MergeApiChats(chats))
        
        for chat in chats {
            switch chat {
                case let .channel(_, _, _, _, _, _, _, _, _, _, _, participantsCount):
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
    
    mutating func mergeUsers(_ users: [Api.User]) {
        self.addOperation(.MergeApiUsers(users))
        
        var presences: [PeerId: Api.UserStatus] = [:]
        for user in users {
            switch user {
                case let .user(_, id, _, _, _, _, _, _, status, _, _, _, _):
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
    
    mutating func addReadMessagesContents(_ peerIdsAndMessageIds: (PeerId?, [Int32])) {
        self.addOperation(.ReadMessageContents(peerIdsAndMessageIds))
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
    
    mutating func addUpdateChatInputState(peerId: PeerId, state: SynchronizeableChatInputState?) {
        self.addOperation(.UpdateChatInputState(peerId, state))
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
    
    mutating func addOperation(_ operation: AccountStateMutationOperation) {
        switch operation {
        case .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpdateMessagePoll, .UpdateMessageReactions, .UpdateMedia, .ReadOutbox, .ReadGroupFeedInbox, .MergePeerPresences, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity, .UpdateCachedPeerData, .UpdatePinnedItemIds, .ReadMessageContents, .UpdateMessageImpressionCount, .UpdateMessageForwardsCount, .UpdateInstalledStickerPacks, .UpdateRecentGifs, .UpdateChatInputState, .UpdateCall, .AddCallSignalingData, .UpdateLangPack, .UpdateMinAvailableMessage, .UpdatePeerChatUnreadMark, .UpdateIsContact, .UpdatePeerChatInclusion, .UpdatePeersNearby, .UpdateTheme, .SyncChatListFilters, .UpdateChatListFilterOrder, .UpdateChatListFilter, .UpdateReadThread, .UpdateGroupCallParticipants, .UpdateGroupCall, .UpdateMessagesPinned, .UpdateAutoremoveTimeout, .UpdateAttachMenuBots, .UpdateAudioTranscription, .UpdateConfig:
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
                    }
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            self.referencedMessageIds.insert(attribute.messageId)
                            break inner
                        }
                    }
                }
            case let .AddScheduledMessages(messages):
                for message in messages {
                    if case let .Id(id) = message.id {
                        self.storedMessages.insert(id)
                    }
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            self.referencedMessageIds.insert(attribute.messageId)
                            break inner
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
                if case let .peer(peerId) = subject {
                    if var currentInfo = self.peerChatInfos[peerId] {
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
    let addedReactionEvents: [(reactionAuthor: Peer, reaction: String, message: Message, timestamp: Int32)]
    let wasScheduledMessageIds: [MessageId]
    let addedSecretMessageIds: [MessageId]
    let deletedMessageIds: [DeletedMessageId]
    let updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]]
    let updatedWebpages: [MediaId: TelegramMediaWebpage]
    let updatedCalls: [Api.PhoneCall]
    let addedCallSignalingData: [(Int64, Data)]
    let updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)]
    let updatedPeersNearby: [PeerNearby]?
    let isContactUpdates: [(PeerId, Bool)]
    let delayNotificatonsUntil: Int32?
    let updatedIncomingThreadReadStates: [MessageId: MessageId.Id]
    let updatedOutgoingThreadReadStates: [MessageId: MessageId.Id]
    let updateConfig: Bool
}

struct AccountFinalStateEvents {
    let addedIncomingMessageIds: [MessageId]
    let addedReactionEvents: [(reactionAuthor: Peer, reaction: String, message: Message, timestamp: Int32)]
    let wasScheduledMessageIds:[MessageId]
    let deletedMessageIds: [DeletedMessageId]
    let updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]]
    let updatedWebpages: [MediaId: TelegramMediaWebpage]
    let updatedCalls: [Api.PhoneCall]
    let addedCallSignalingData: [(Int64, Data)]
    let updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)]
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
    
    var isEmpty: Bool {
        return self.addedIncomingMessageIds.isEmpty && self.addedReactionEvents.isEmpty && self.wasScheduledMessageIds.isEmpty && self.deletedMessageIds.isEmpty && self.updatedTypingActivities.isEmpty && self.updatedWebpages.isEmpty && self.updatedCalls.isEmpty && self.addedCallSignalingData.isEmpty && self.updatedGroupCallParticipants.isEmpty && self.updatedPeersNearby?.isEmpty ?? true && self.isContactUpdates.isEmpty && self.displayAlerts.isEmpty && self.dismissBotWebViews.isEmpty && self.delayNotificatonsUntil == nil && self.updatedMaxMessageId == nil && self.updatedQts == nil && self.externallyUpdatedPeerId.isEmpty && !authorizationListUpdated && self.updatedIncomingThreadReadStates.isEmpty && self.updatedOutgoingThreadReadStates.isEmpty && !self.updateConfig
    }
    
    init(addedIncomingMessageIds: [MessageId] = [], addedReactionEvents: [(reactionAuthor: Peer, reaction: String, message: Message, timestamp: Int32)] = [], wasScheduledMessageIds: [MessageId] = [], deletedMessageIds: [DeletedMessageId] = [], updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]] = [:], updatedWebpages: [MediaId: TelegramMediaWebpage] = [:], updatedCalls: [Api.PhoneCall] = [], addedCallSignalingData: [(Int64, Data)] = [], updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)] = [], updatedPeersNearby: [PeerNearby]? = nil, isContactUpdates: [(PeerId, Bool)] = [], displayAlerts: [(text: String, isDropAuth: Bool)] = [], dismissBotWebViews: [Int64] = [], delayNotificatonsUntil: Int32? = nil, updatedMaxMessageId: Int32? = nil, updatedQts: Int32? = nil, externallyUpdatedPeerId: Set<PeerId> = Set(), authorizationListUpdated: Bool = false, updatedIncomingThreadReadStates: [MessageId: MessageId.Id] = [:], updatedOutgoingThreadReadStates: [MessageId: MessageId.Id] = [:], updateConfig: Bool = false) {
        self.addedIncomingMessageIds = addedIncomingMessageIds
        self.addedReactionEvents = addedReactionEvents
        self.wasScheduledMessageIds = wasScheduledMessageIds
        self.deletedMessageIds = deletedMessageIds
        self.updatedTypingActivities = updatedTypingActivities
        self.updatedWebpages = updatedWebpages
        self.updatedCalls = updatedCalls
        self.addedCallSignalingData = addedCallSignalingData
        self.updatedGroupCallParticipants = updatedGroupCallParticipants
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
        
        return AccountFinalStateEvents(addedIncomingMessageIds: self.addedIncomingMessageIds + other.addedIncomingMessageIds, addedReactionEvents: self.addedReactionEvents + other.addedReactionEvents, wasScheduledMessageIds: self.wasScheduledMessageIds + other.wasScheduledMessageIds, deletedMessageIds: self.deletedMessageIds + other.deletedMessageIds, updatedTypingActivities: self.updatedTypingActivities, updatedWebpages: self.updatedWebpages, updatedCalls: self.updatedCalls + other.updatedCalls, addedCallSignalingData: self.addedCallSignalingData + other.addedCallSignalingData, updatedGroupCallParticipants: self.updatedGroupCallParticipants + other.updatedGroupCallParticipants, isContactUpdates: self.isContactUpdates + other.isContactUpdates, displayAlerts: self.displayAlerts + other.displayAlerts, dismissBotWebViews: self.dismissBotWebViews + other.dismissBotWebViews, delayNotificatonsUntil: delayNotificatonsUntil, updatedMaxMessageId: updatedMaxMessageId, updatedQts: updatedQts, externallyUpdatedPeerId: externallyUpdatedPeerId, authorizationListUpdated: authorizationListUpdated, updatedIncomingThreadReadStates: self.updatedIncomingThreadReadStates.merging(other.updatedIncomingThreadReadStates, uniquingKeysWith: { lhs, _ in lhs }), updateConfig: updateConfig)
    }
}
