import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

final class AccountInitialState {
    let state: AuthorizedAccountState.State
    let peerIds: Set<PeerId>
    let chatStates: [PeerId: PeerChatState]
    let peerNotificationSettings: [PeerId: PeerNotificationSettings]
    let peerIdsWithNewMessages: Set<PeerId>
    let locallyGeneratedMessageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]]
    let cloudReadStates: [PeerId: PeerReadState]
    let channelsToPollExplicitely: Set<PeerId>
    
    init(state: AuthorizedAccountState.State, peerIds: Set<PeerId>, peerIdsWithNewMessages: Set<PeerId>, chatStates: [PeerId: PeerChatState], peerNotificationSettings: [PeerId: PeerNotificationSettings], locallyGeneratedMessageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]], cloudReadStates: [PeerId: PeerReadState], channelsToPollExplicitely: Set<PeerId>) {
        self.state = state
        self.peerIds = peerIds
        self.chatStates = chatStates
        self.peerIdsWithNewMessages = peerIdsWithNewMessages
        self.peerNotificationSettings = peerNotificationSettings
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
}

enum AccountStateMutationOperation {
    case AddMessages([StoreMessage], AddMessagesLocation)
    case DeleteMessagesWithGlobalIds([Int32])
    case DeleteMessages([MessageId])
    case EditMessage(MessageId, StoreMessage)
    case UpdateMedia(MediaId, Media?)
    case ReadInbox(MessageId)
    case ReadOutbox(MessageId)
    case ResetReadState(PeerId, MessageId.Namespace, MessageId.Id, MessageId.Id, MessageId.Id, Int32, Bool?)
    case UpdatePeerChatUnreadMark(PeerId, MessageId.Namespace, Bool)
    case ResetMessageTagSummary(PeerId, MessageId.Namespace, Int32, MessageHistoryTagNamespaceCountValidityRange)
    case ReadGroupFeedInbox(PeerGroupId, MessageIndex)
    case UpdateState(AuthorizedAccountState.State)
    case UpdateChannelState(PeerId, ChannelState)
    case UpdateNotificationSettings(AccountStateNotificationSettingsSubject, PeerNotificationSettings)
    case UpdateGlobalNotificationSettings(AccountStateGlobalNotificationSettingsSubject, MessageNotificationSettings)
    case MergeApiChats([Api.Chat])
    case UpdatePeer(PeerId, (Peer?) -> Peer?)
    case UpdateIsContact(PeerId, Bool)
    case UpdateCachedPeerData(PeerId, (CachedPeerData?) -> CachedPeerData?)
    case MergeApiUsers([Api.User])
    case MergePeerPresences([PeerId: PeerPresence], Bool)
    case UpdateSecretChat(chat: Api.EncryptedChat, timestamp: Int32)
    case AddSecretMessages([Api.EncryptedMessage])
    case ReadSecretOutbox(peerId: PeerId, maxTimestamp: Int32, actionTimestamp: Int32)
    case AddPeerInputActivity(chatPeerId: PeerId, peerId: PeerId?, activity: PeerInputActivity?)
    case UpdatePinnedItemIds(AccountStateUpdatePinnedItemIdsOperation)
    case ReadMessageContents((PeerId?, [Int32]))
    case UpdateMessageImpressionCount(MessageId, Int32)
    case UpdateInstalledStickerPacks(AccountStateUpdateStickerPacksOperation)
    case UpdateRecentGifs
    case UpdateChatInputState(PeerId, SynchronizeableChatInputState?)
    case UpdateCall(Api.PhoneCall)
    case UpdateLangPack(Api.LangPackDifference?)
    case UpdateMinAvailableMessage(MessageId)
}

struct AccountMutableState {
    let initialState: AccountInitialState
    let branchOperationIndex: Int
    
    var operations: [AccountStateMutationOperation] = []
    
    var state: AuthorizedAccountState.State
    var peers: [PeerId: Peer]
    var chatStates: [PeerId: PeerChatState]
    var peerNotificationSettings: [PeerId: PeerNotificationSettings]
    var referencedMessageIds: Set<MessageId>
    var storedMessages: Set<MessageId>
    var readInboxMaxIds: [PeerId: MessageId]
    var namespacesWithHolesFromPreviousState: [PeerId: Set<MessageId.Namespace>]
    
    var storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>]
    var displayAlerts: [String] = []
    
    var insertedPeers: [PeerId: Peer] = [:]
    
    var preCachedResources: [(MediaResource, Data)] = []
    
    init(initialState: AccountInitialState, initialPeers: [PeerId: Peer], initialReferencedMessageIds: Set<MessageId>, initialStoredMessages: Set<MessageId>, initialReadInboxMaxIds: [PeerId: MessageId], storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>]) {
        self.initialState = initialState
        self.state = initialState.state
        self.peers = initialPeers
        self.referencedMessageIds = initialReferencedMessageIds
        self.storedMessages = initialStoredMessages
        self.readInboxMaxIds = initialReadInboxMaxIds
        self.chatStates = initialState.chatStates
        self.peerNotificationSettings = initialState.peerNotificationSettings
        self.storedMessagesByPeerIdAndTimestamp = storedMessagesByPeerIdAndTimestamp
        self.branchOperationIndex = 0
        self.namespacesWithHolesFromPreviousState = [:]
    }
    
    init(initialState: AccountInitialState, operations: [AccountStateMutationOperation], state: AuthorizedAccountState.State, peers: [PeerId: Peer], chatStates: [PeerId: PeerChatState], peerNotificationSettings: [PeerId: PeerNotificationSettings], referencedMessageIds: Set<MessageId>, storedMessages: Set<MessageId>, readInboxMaxIds: [PeerId: MessageId], storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>], namespacesWithHolesFromPreviousState: [PeerId: Set<MessageId.Namespace>], displayAlerts: [String], branchOperationIndex: Int) {
        self.initialState = initialState
        self.operations = operations
        self.state = state
        self.peers = peers
        self.chatStates = chatStates
        self.referencedMessageIds = referencedMessageIds
        self.storedMessages = storedMessages
        self.peerNotificationSettings = peerNotificationSettings
        self.readInboxMaxIds = readInboxMaxIds
        self.storedMessagesByPeerIdAndTimestamp = storedMessagesByPeerIdAndTimestamp
        self.namespacesWithHolesFromPreviousState = namespacesWithHolesFromPreviousState
        self.displayAlerts = displayAlerts
        self.branchOperationIndex = branchOperationIndex
    }
    
    func branch() -> AccountMutableState {
        return AccountMutableState(initialState: self.initialState, operations: self.operations, state: self.state, peers: self.peers, chatStates: self.chatStates, peerNotificationSettings: self.peerNotificationSettings, referencedMessageIds: self.referencedMessageIds, storedMessages: self.storedMessages, readInboxMaxIds: self.readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: self.storedMessagesByPeerIdAndTimestamp, namespacesWithHolesFromPreviousState: self.namespacesWithHolesFromPreviousState, displayAlerts: self.displayAlerts, branchOperationIndex: self.operations.count)
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
        for (peerId, namespaces) in other.namespacesWithHolesFromPreviousState {
            if self.namespacesWithHolesFromPreviousState[peerId] == nil {
                self.self.namespacesWithHolesFromPreviousState[peerId] = Set()
            }
            for namespace in namespaces {
                self.namespacesWithHolesFromPreviousState[peerId]!.insert(namespace)
            }
        }
        self.displayAlerts.append(contentsOf: other.displayAlerts)
    }
    
    mutating func addPreCachedResource(_ resource: MediaResource, data: Data) {
        self.preCachedResources.append((resource, data))
    }
    
    mutating func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) {
        self.addOperation(.AddMessages(messages, location))
    }
    
    mutating func addDisplayAlert(_ text: String) {
        self.displayAlerts.append(text)
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
    
    mutating func updateMedia(_ id: MediaId, media: Media?) {
        self.addOperation(.UpdateMedia(id, media))
    }
    
    mutating func readInbox(_ messageId: MessageId) {
        self.addOperation(.ReadInbox(messageId))
    }
    
    mutating func readOutbox(_ messageId: MessageId) {
        self.addOperation(.ReadOutbox(messageId))
    }
    
    mutating func readGroupFeedInbox(groupId: PeerGroupId, index: MessageIndex) {
        self.addOperation(.ReadGroupFeedInbox(groupId, index))
    }
    
    mutating func resetReadState(_ peerId: PeerId, namespace: MessageId.Namespace, maxIncomingReadId: MessageId.Id, maxOutgoingReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32, markedUnread: Bool?) {
        self.addOperation(.ResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread))
    }
    
    mutating func updatePeerChatUnreadMark(_ peerId: PeerId, namespace: MessageId.Namespace, value: Bool) {
        self.addOperation(.UpdatePeerChatUnreadMark(peerId, namespace, value))
    }
    
    mutating func resetMessageTagSummary(_ peerId: PeerId, namespace: MessageId.Namespace, count: Int32, range: MessageHistoryTagNamespaceCountValidityRange) {
        self.addOperation(.ResetMessageTagSummary(peerId, namespace, count, range))
    }
    
    mutating func updateState(_ state: AuthorizedAccountState.State) {
        self.addOperation(.UpdateState(state))
    }
    
    mutating func updateChannelState(_ peerId: PeerId, state: ChannelState) {
        self.addOperation(.UpdateChannelState(peerId, state))
    }
    
    mutating func updateNotificationSettings(_ subject: AccountStateNotificationSettingsSubject, notificationSettings: PeerNotificationSettings) {
        self.addOperation(.UpdateNotificationSettings(subject, notificationSettings))
    }
    
    mutating func updateGlobalNotificationSettings(_ subject: AccountStateGlobalNotificationSettingsSubject, notificationSettings: MessageNotificationSettings) {
        self.addOperation(.UpdateGlobalNotificationSettings(subject, notificationSettings))
    }
    
    mutating func setNeedsHoleFromPreviousState(peerId: PeerId, namespace: MessageId.Namespace) {
        if self.namespacesWithHolesFromPreviousState[peerId] == nil {
            self.namespacesWithHolesFromPreviousState[peerId] = Set()
        }
        self.namespacesWithHolesFromPreviousState[peerId]!.insert(namespace)
    }
    
    mutating func mergeChats(_ chats: [Api.Chat]) {
        self.addOperation(.MergeApiChats(chats))
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
    
    mutating func updateLangPack(_ difference: Api.LangPackDifference?) {
        self.addOperation(.UpdateLangPack(difference))
    }
    
    mutating func updateMinAvailableMessage(_ id: MessageId) {
        self.addOperation(.UpdateMinAvailableMessage(id))
    }
    
    mutating func mergeUsers(_ users: [Api.User]) {
        self.addOperation(.MergeApiUsers(users))
        
        var presences: [PeerId: PeerPresence] = [:]
        for user in users {
            switch user {
            case let .user(_, id, _, _, _, _, _, _, status, _, _, _, _):
                if let status = status {
                    presences[PeerId(namespace: Namespaces.Peer.CloudUser, id: id)] = TelegramUserPresence(apiStatus: status)
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
    
    mutating func mergePeerPresences(_ presences: [PeerId: PeerPresence], explicit: Bool) {
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
    
    mutating func addPeerInputActivity(chatPeerId: PeerId, peerId: PeerId?, activity: PeerInputActivity?) {
        self.addOperation(.AddPeerInputActivity(chatPeerId: chatPeerId, peerId: peerId, activity: activity))
    }
    
    mutating func addUpdatePinnedItemIds(_ operation: AccountStateUpdatePinnedItemIdsOperation) {
        self.addOperation(.UpdatePinnedItemIds(operation))
    }
    
    mutating func addReadMessagesContents(_ peerIdsAndMessageIds: (PeerId?, [Int32])) {
        self.addOperation(.ReadMessageContents(peerIdsAndMessageIds))
    }
    
    mutating func addUpdateMessageImpressionCount(id: MessageId, count: Int32) {
        self.addOperation(.UpdateMessageImpressionCount(id, count))
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
    
    mutating func addOperation(_ operation: AccountStateMutationOperation) {
        switch operation {
            case .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpdateMedia, .ReadOutbox, .ReadGroupFeedInbox, .MergePeerPresences, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity, .UpdateCachedPeerData, .UpdatePinnedItemIds, .ReadMessageContents, .UpdateMessageImpressionCount, .UpdateInstalledStickerPacks, .UpdateRecentGifs, .UpdateChatInputState, .UpdateCall, .UpdateLangPack, .UpdateMinAvailableMessage, .UpdatePeerChatUnreadMark, .UpdateIsContact:
                break
            case let .AddMessages(messages, _):
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
            case let .UpdateChannelState(peerId, channelState):
                self.chatStates[peerId] = channelState
            case let .UpdateNotificationSettings(subject, notificationSettings):
                if case let .peer(peerId) = subject {
                    self.peerNotificationSettings[peerId] = notificationSettings
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
            case let .ResetMessageTagSummary(peerId, namespace, count, range):
                break
        }
        
        self.operations.append(operation)
    }
}

struct AccountFinalState {
    let state: AccountMutableState
    let shouldPoll: Bool
    let incomplete: Bool
}

struct AccountReplayedFinalState {
    let state: AccountFinalState
    let addedIncomingMessageIds: [MessageId]
    let addedSecretMessageIds: [MessageId]
    let updatedTypingActivities: [PeerId: [PeerId: PeerInputActivity?]]
    let updatedWebpages: [MediaId: TelegramMediaWebpage]
    let updatedCalls: [Api.PhoneCall]
    let isContactUpdates: [(PeerId, Bool)]
    let delayNotificatonsUntil: Int32?
}

struct AccountFinalStateEvents {
    let addedIncomingMessageIds: [MessageId]
    let updatedTypingActivities: [PeerId: [PeerId: PeerInputActivity?]]
    let updatedWebpages: [MediaId: TelegramMediaWebpage]
    let updatedCalls: [Api.PhoneCall]
    let isContactUpdates: [(PeerId, Bool)]
    let displayAlerts: [String]
    let delayNotificatonsUntil: Int32?
    
    var isEmpty: Bool {
        return self.addedIncomingMessageIds.isEmpty && self.updatedTypingActivities.isEmpty && self.updatedWebpages.isEmpty && self.updatedCalls.isEmpty && self.isContactUpdates.isEmpty && self.displayAlerts.isEmpty && delayNotificatonsUntil == nil
    }
    
    init() {
        self.addedIncomingMessageIds = []
        self.updatedTypingActivities = [:]
        self.updatedWebpages = [:]
        self.updatedCalls = []
        self.isContactUpdates = []
        self.displayAlerts = []
        self.delayNotificatonsUntil = nil
    }
    
    init(addedIncomingMessageIds: [MessageId], updatedTypingActivities: [PeerId: [PeerId: PeerInputActivity?]], updatedWebpages: [MediaId: TelegramMediaWebpage], updatedCalls: [Api.PhoneCall], isContactUpdates: [(PeerId, Bool)], displayAlerts: [String], delayNotificatonsUntil: Int32?) {
        self.addedIncomingMessageIds = addedIncomingMessageIds
        self.updatedTypingActivities = updatedTypingActivities
        self.updatedWebpages = updatedWebpages
        self.updatedCalls = updatedCalls
        self.isContactUpdates = isContactUpdates
        self.displayAlerts = displayAlerts
        self.delayNotificatonsUntil = delayNotificatonsUntil
    }
    
    init(state: AccountReplayedFinalState) {
        self.addedIncomingMessageIds = state.addedIncomingMessageIds
        self.updatedTypingActivities = state.updatedTypingActivities
        self.updatedWebpages = state.updatedWebpages
        self.updatedCalls = state.updatedCalls
        self.isContactUpdates = state.isContactUpdates
        self.displayAlerts = state.state.state.displayAlerts
        self.delayNotificatonsUntil = state.delayNotificatonsUntil
    }
    
    func union(with other: AccountFinalStateEvents) -> AccountFinalStateEvents {
        var delayNotificatonsUntil = self.delayNotificatonsUntil
        if let other = self.delayNotificatonsUntil {
            if delayNotificatonsUntil == nil || other > delayNotificatonsUntil! {
                delayNotificatonsUntil = other
            }
        }
        return AccountFinalStateEvents(addedIncomingMessageIds: self.addedIncomingMessageIds + other.addedIncomingMessageIds, updatedTypingActivities: self.updatedTypingActivities, updatedWebpages: self.updatedWebpages, updatedCalls: self.updatedCalls + other.updatedCalls, isContactUpdates: self.isContactUpdates + other.isContactUpdates, displayAlerts: self.displayAlerts + other.displayAlerts, delayNotificatonsUntil: delayNotificatonsUntil)
    }
}
