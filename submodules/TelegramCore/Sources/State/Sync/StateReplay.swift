import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

func reactionGeneratedEvent(_ previousReactions: ReactionsMessageAttribute?, _ updatedReactions: ReactionsMessageAttribute?, message: Message, transaction: Transaction) -> (reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)? {
    if let updatedReactions = updatedReactions, !message.flags.contains(.Incoming), message.id.peerId.namespace == Namespaces.Peer.CloudUser {
        let prev = previousReactions?.reactions ?? []
        
        let updated = updatedReactions.reactions.filter { value in
            return !prev.contains(where: {
                $0.value == value.value && $0.count == value.count
            })
        }
        let myUpdated = updatedReactions.reactions.filter { value in
            return value.chosenOrder != nil
        }.first
        let myPrevious = prev.filter { value in
            return value.chosenOrder != nil
        }.first
        
        let previousCount = prev.reduce(0, {
            $0 + $1.count
        })
        let updatedCount = updatedReactions.reactions.reduce(0, {
            $0 + $1.count
        })
        
        let newReaction = updated.filter {
            $0.chosenOrder == nil
        }.first?.value
        
        if !updated.isEmpty && myUpdated == myPrevious, updatedCount >= previousCount, let value = newReaction {
            if let reactionAuthor = transaction.getPeer(message.id.peerId) {
                return (reactionAuthor: reactionAuthor, reaction: value, message: message, timestamp: Int32(Date().timeIntervalSince1970))
            }
        }
    }
    return nil
}

func recordPeerActivityTimestamp(peerId: PeerId, timestamp: Int32, into timestamps: inout [PeerId: Int32]) {
    if let current = timestamps[peerId] {
        if current < timestamp {
            timestamps[peerId] = timestamp
        }
    } else {
        timestamps[peerId] = timestamp
    }
}

func upsertEphemeralReplacement(transaction: Transaction, anchorMessageId: MessageId, message: StoreMessage) {
    guard anchorMessageId.namespace == Namespaces.Message.Cloud, let anchorMessage = transaction.getMessage(anchorMessageId) else {
        return
    }
    guard case let .Id(replacementMessageId) = message.id, replacementMessageId.peerId == anchorMessageId.peerId, replacementMessageId.namespace == Namespaces.Message.EphemeralAnchored else {
        return
    }
    guard let ephemeralAttribute = message.attributes.first(where: { $0 is EphemeralMessageAttribute }) as? EphemeralMessageAttribute else {
        return
    }

    let currentAttribute = anchorMessage.attributes.first(where: { $0 is EphemeralReplacementMessageAttribute }) as? EphemeralReplacementMessageAttribute
    if let currentAttribute, currentAttribute.state == .reverted, currentAttribute.replacementMessageId == replacementMessageId {
        return
    }

    if let currentAttribute, currentAttribute.state == .active, currentAttribute.replacementMessageId != replacementMessageId {
        transaction.deleteMessages([currentAttribute.replacementMessageId], forEachMedia: nil)
    }

    if transaction.getMessage(replacementMessageId) != nil {
        transaction.updateMessage(replacementMessageId, update: { _ in
            return .update(message)
        })
    } else {
        let _ = transaction.addMessages([message], location: .Random)
    }

    transaction.updateMessage(anchorMessageId, update: { currentMessage in
        var attributes = currentMessage.attributes.filter { !($0 is EphemeralReplacementMessageAttribute) }
        attributes.append(EphemeralReplacementMessageAttribute(state: .active, replacementMessageId: replacementMessageId, receiverId: ephemeralAttribute.receiverId))
        let message = StoreMessage(updating: currentMessage, attributes: attributes, tags: currentMessage.tags)
        return .update(message)
    })
}

func deleteEphemeralMessages(transaction: Transaction, peerId: PeerId, ids: [Int32]) {
    let idSet = Set(ids)
    var activeReplacements: [(MessageId, EphemeralReplacementMessageAttribute)] = []
    transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, { message in
        if let attribute = message.attributes.first(where: { $0 is EphemeralReplacementMessageAttribute }) as? EphemeralReplacementMessageAttribute, attribute.state == .active, attribute.replacementMessageId.peerId == peerId, attribute.replacementMessageId.namespace == Namespaces.Message.EphemeralAnchored, idSet.contains(attribute.replacementMessageId.id) {
            activeReplacements.append((message.id, attribute))
        }
        return true
    })
    for (anchorMessageId, attribute) in activeReplacements {
        transaction.updateMessage(anchorMessageId, update: { currentMessage in
            var attributes = currentMessage.attributes.filter { !($0 is EphemeralReplacementMessageAttribute) }
            attributes.append(EphemeralReplacementMessageAttribute(state: .reverted, replacementMessageId: attribute.replacementMessageId, receiverId: attribute.receiverId))
            let message = StoreMessage(updating: currentMessage, attributes: attributes, tags: currentMessage.tags)
            return .update(message)
        })
    }

    var messageIds: [MessageId] = []
    for id in ids {
        messageIds.append(MessageId(peerId: peerId, namespace: Namespaces.Message.EphemeralLocal, id: id))
        messageIds.append(MessageId(peerId: peerId, namespace: Namespaces.Message.EphemeralAnchored, id: id))
    }
    transaction.deleteMessages(messageIds, forEachMedia: nil)
}

/// Adds one replayed media update to the web-page events that `AccountStateManager.updatedWebpage`
/// delivers. A nil media for a web page is a `webPageEmpty` from `updateWebPage` or
/// `updateChannelWebPage`: the server found no preview for the URL, which a composer showing that
/// page as pending must hear to stop waiting.
func recordUpdatedWebpage(_ id: MediaId, media: Media?, into updatedWebpages: inout [MediaId: TelegramMediaWebpage?]) {
    if let webpage = media as? TelegramMediaWebpage {
        updatedWebpages[id] = webpage
    } else if media == nil && id.namespace == Namespaces.Media.CloudWebpage {
        // Assigning nil through the subscript would delete the key instead of storing the removal.
        updatedWebpages.updateValue(nil, forKey: id)
    }
}

/// Replays `finalState` inside `transaction`, in phases: `ReplayRejection.verify` when `policy` verifies (a rejection
/// returns nil and writes nothing), `ReplayPrepass.prepare`, the content operations
/// (`ReplayContext.applyContentOperations`, batched by `batchContentAndDeferStateOperations`), the account and channel
/// state they advance (`applyStateAdvance`), the steps after them (`finalize`) and the result (`buildResult`).
/// `auxiliaryMethods` is not read. Every caller goes through `FinalStateReplayer.applyReplay`.
func replayFinalState(
    accountManager: AccountManager<TelegramAccountManagerTypes>,
    postbox: Postbox,
    accountPeerId: PeerId,
    mediaBox: MediaBox,
    encryptionProvider: EncryptionProvider,
    transaction: Transaction,
    auxiliaryMethods: AccountAuxiliaryMethods,
    finalState: AccountFinalState,
    removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId],
    policy: ReplayPolicy,
    storyReactionContext: StoryReactionContext? = nil,
    storyRefreshContext: StoryRefreshContext? = nil,
    storyViewRefreshContext: StoryViewRefreshContext? = nil
) -> AccountReplayedFinalState? {
    if policy.verifiesTransaction, ReplayRejection.verify(transaction, finalState: finalState.state) != nil {
        Logger.shared.log("State", "failed to verify final state")
        return nil
    }

    let prepass = ReplayPrepass.prepare(transaction: transaction, finalState: finalState)
    let context = ReplayContext(accountManager: accountManager, postbox: postbox, accountPeerId: accountPeerId, mediaBox: mediaBox, encryptionProvider: encryptionProvider, transaction: transaction, finalState: finalState, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, policy: policy, prepass: prepass, storyReactionContext: storyReactionContext, storyRefreshContext: storyRefreshContext, storyViewRefreshContext: storyViewRefreshContext)
    let operations = batchContentAndDeferStateOperations(finalState.state.operations)
    context.applyContentOperations(operations.content)
    context.applyStateAdvance(operations.stateAdvance)
    context.finalize()
    return context.buildResult()
}

/// One replay of a final state, inside one Postbox transaction (`replayFinalState`). It holds the replay's inputs,
/// what the prepass found (`ReplayPrepass`) and every accumulator the operations fill: `finalize` persists some of
/// them and `buildResult` hands the rest on as events. Its stored properties were the locals of `replayFinalState`;
/// each says who reads it.
///
/// A class, not a struct: an operation's closure that escapes (`_internal_deleteMessages`' thread-stats callback, an
/// optional and therefore escaping parameter) updates an accumulator, which a `mutating` struct method cannot allow.
/// The two closures that outlive the transaction (`finalize`'s account-manager transactions) capture copies of the
/// values they read, never the context, so nothing keeps it, or its transaction, after `replayFinalState` returns.
/// Used once, synchronously, inside the transaction.
final class ReplayContext {
    // MARK: - Inputs
    /// Input. `finalize` starts its language-pack and theme transactions on it.
    let accountManager: AccountManager<TelegramAccountManagerTypes>
    /// Input. The language-pack fallback transaction and the possibly-delivered deletions use it.
    let postbox: Postbox
    /// Input. The account's own peer, which several operations and steps treat apart.
    let accountPeerId: PeerId
    /// Input. Deletions remove cached resources from it; secret chats store media in it.
    let mediaBox: MediaBox
    /// Input. Secret chats only: updating one and decrypting its added messages.
    let encryptionProvider: EncryptionProvider
    /// Input. The one Postbox transaction every read and write of the replay goes through.
    let transaction: Transaction
    /// Input. The replayed final state: operations, side tables read by cases and steps, and the result's state.
    let finalState: AccountFinalState
    /// Input. Read by `finalize`: confirmed outgoing messages to delete if possibly delivered.
    let removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId]
    /// Input. `.UpdateState` keeps the stored date when it says so (`keepsStoredDate`).
    let policy: ReplayPolicy
    /// Input. The story replays consult the pending reactions and invalidate the story refreshes they supersede.
    let storyReactionContext: StoryReactionContext?
    let storyRefreshContext: StoryRefreshContext?
    let storyViewRefreshContext: StoryViewRefreshContext?

    // MARK: - From the prepass
    /// Prepass, then `.ReadOutbox`. Persisted by `finalize` as the peers' last activity.
    var peerActivityTimestamps: [PeerId: Int32]
    /// Prepass. Persisted by `finalize`: where each previous-state hole starts.
    let holesFromPreviousStateMessageIds: [MessageId]
    /// Prepass. Consulted by `.AddMessages`: a thread's unread count moves only above a known read maximum.
    let readInboxCloudMessageIds: [PeerId: Int32]
    /// Prepass. Event: the added incoming messages that invite to a conference call.
    let addedConferenceInvitationMessagesIds: [MessageId]
    /// Prepass. Event: sent scheduled messages that were not stored before the replay.
    let wasScheduledMessageIds: [MessageId]
    /// Prepass, then `finalize` (decrypted secret messages). Event: incoming messages new to Postbox.
    var addedIncomingMessageIds: [MessageId]
    /// Prepass. Persisted by `finalize`: the pending wallet transfers to reconcile.
    let mappedWalletMessageIds: [MessageId]

    // MARK: - Accumulators
    /// Persisted by `finalize`: the secret chats whose queued encrypted messages it decrypts.
    var peerIdsWithAddedSecretMessages = Set<PeerId>()
    /// Event: typing activity. `finalize` adds the secret chats' typing and clears their authors'.
    var updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]] = [:]
    /// Event: each thread's highest incoming read id.
    var updatedIncomingThreadReadStates: [PeerAndBoundThreadId: MessageId.Id] = [:]
    /// Event: each thread's highest outgoing read id.
    var updatedOutgoingThreadReadStates: [PeerAndBoundThreadId: MessageId.Id] = [:]
    /// Turned into typing activities by `finalize`, which reads each secret chat's peer.
    var updatedSecretChatTypingActivities = Set<PeerId>()
    /// Event: web pages updated, or resolved to empty (a nil value).
    var updatedWebpages: [MediaId: TelegramMediaWebpage?] = [:]
    /// Event.
    var updatedCalls: [Api.PhoneCall] = []
    /// Event.
    var addedCallSignalingData: [(Int64, Data)] = []
    /// Event.
    var updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)] = []
    /// Event.
    var groupCallMessageUpdates: [GroupCallMessageUpdate] = []
    /// Event. Also read by `finalize`: an added story may queue its peer's stories for sync.
    var storyUpdates: [InternalStoryUpdate] = []
    /// Persisted by `finalize`, in order, or as a sync of the namespaces it cannot apply.
    var stickerPackOperations: [AccountStateUpdateStickerPacksOperation] = []
    /// Persisted by `finalize`: the recent stickers; each keeps its latest message.
    var recentlyUsedStickers: [MediaId: (MessageIndex, TelegramMediaFile)] = [:]
    /// Persisted by `finalize`: until when each slow-mode group allows the next message.
    var slowModeLastMessageTimeouts:[PeerId : Int32] = [:]
    /// Persisted by `finalize`: the recent GIFs, unless `syncRecentGifs`.
    var recentlyUsedGifs: [MediaId: (MessageIndex, TelegramMediaFile)] = [:]
    /// Persisted by `finalize`: a saved-GIFs sync instead of adding to the recent GIFs.
    var syncRecentGifs = false
    /// Applied by `finalize` in an account-manager transaction (fire-and-forget), unless a pack is polled.
    var langPackDifferences: [String: [Api.LangPackDifference]] = [:]
    /// Read by `finalize`: any entry queues a localization sync instead of applying the differences.
    var pollLangPacks = Set<String>()
    /// Persisted by `finalize`, and the current theme in an account-manager transaction (fire-and-forget).
    var updatedThemes: [Int64: TelegramTheme] = [:]
    /// Persisted by `finalize`: each peer's wallpaper in its cached data.
    var updatedWallpapers: [PeerId: TelegramWallpaper?] = [:]
    /// Event: the account's own presence delays notifications until then.
    var delayNotificatonsUntil: Int32?
    /// Consulted by later chat-folder operations, which stop applying; `finalize` then requests a sync.
    var syncChatListFilters = false
    /// Event, also recorded by `FinalStateReplayer.applyReplay` in `messagesRemovedContext`.
    var deletedMessageIds: [DeletedMessageId] = []
    /// Event.
    var updateConfig = false
    /// Event.
    var updatedStarsBalance: [PeerId: StarsAmount] = [:]
    /// Event.
    var updatedTonBalance: [PeerId: StarsAmount] = [:]
    /// Event, mapped to `WalletTransferUpdate`s by `buildResult`.
    var walletTransferApiUpdates: [Api.Update] = []
    /// Event: what `walletTonConnectEvents(operation:)` finds in every operation.
    var walletTonConnectEventBatch: [WalletTonConnectEvent] = []
    /// Event.
    var updatedWalletState: Api.WalletState?
    /// Event.
    var updatedAgentSettings: EngineAgentSettings?
    /// Event.
    var updatedStarsRevenueStatus: [PeerId: StarsRevenueStats.Balances] = [:]
    /// Persisted by `finalize`.
    var updatedStarsReactionsDefaultPrivacy: TelegramPaidReactionPrivacy?
    /// Event.
    var reportMessageDelivery = Set<MessageId>()
    /// Event.
    var updatedStarGiftAuctionState: [Int64: GiftAuctionContext.State.AuctionState] = [:]
    /// Event.
    var updatedStarGiftAuctionMyState: [Int64: GiftAuctionContext.State.MyState] = [:]
    /// Event.
    var updatedEmojiGameInfo: EmojiGameInfo?
    /// Persisted by `finalize` as recently used inline bots.
    var recentlyUsedGuestChatBots = Set<PeerId>()
    /// Persisted by `finalize`, applied in order to the web browser settings.
    var webBrowserSettingsUpdates: [(AccountWebBrowserSettings) -> AccountWebBrowserSettings] = []
    /// Consulted by later `.AddMessages` (a message cancels its draft); persisted by `finalize`.
    var liveTypingDraftUpdates: [PeerAndThreadId: [LiveTypingDraftUpdate]] = [:]
    /// Event: new reactions to the account's messages in private chats.
    var addedReactionEvents: [(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)] = []
    /// Persisted by `finalize`: the peer groups whose message stats are synchronized again.
    var invalidateGroupStats = Set<PeerGroupId>()
    /// Read by `finalize`: each previous-state hole ends below the batch's top message there.
    var topUpperHistoryBlockMessages: [PeerIdAndMessageNamespace: MessageId.Id] = [:]
    /// Persisted by `finalize`: each thread's reply-count change (`addMessageThreadStatsDifference`).
    var messageThreadStatsDifferences: [MessageThreadKey: MessageThreadStatsRecord] = [:]
    /// Event.
    var isPremiumUpdated = false
    /// Filled by `finalize`'s decryption; added to `addedIncomingMessageIds`.
    var addedSecretMessageIds: [MessageId] = []
    /// Filled by `finalize`'s decryption; each author's typing is cleared.
    var addedSecretMessageAuthorIds: [PeerId: PeerId] = [:]

    // MARK: - Local types
    enum LiveTypingDraftUpdate {
        struct Update {
            var id: Int64
            var threadId: Int64?
            var authorId: PeerId
            var timestamp: Int32
            var canStop: Bool
            var keepOnStop: Bool
            var content: PeerLiveTypingDraftUpdateContent

            init(id: Int64, threadId: Int64?, authorId: PeerId, timestamp: Int32, canStop: Bool, keepOnStop: Bool, content: PeerLiveTypingDraftUpdateContent) {
                self.id = id
                self.threadId = threadId
                self.authorId = authorId
                self.timestamp = timestamp
                self.canStop = canStop
                self.keepOnStop = keepOnStop
                self.content = content
            }
        }

        case update(Update)
        case stop(randomId: Int64, timestamp: Int32)
        case cancel(updatedTimestamp: Int32)
    }

    struct PeerIdAndMessageNamespace: Hashable {
        let peerId: PeerId
        let namespace: MessageId.Namespace
    }

    final class MessageThreadStatsRecord {
        var removedCount: Int = 0
        var peers: [ReplyThreadUserMessage] = []
    }

    /// Takes the replay's inputs and the prepass's results; every accumulator starts empty.
    init(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, accountPeerId: PeerId, mediaBox: MediaBox, encryptionProvider: EncryptionProvider, transaction: Transaction, finalState: AccountFinalState, removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId], policy: ReplayPolicy, prepass: ReplayPrepass, storyReactionContext: StoryReactionContext?, storyRefreshContext: StoryRefreshContext?, storyViewRefreshContext: StoryViewRefreshContext?) {
        self.accountManager = accountManager
        self.postbox = postbox
        self.accountPeerId = accountPeerId
        self.mediaBox = mediaBox
        self.encryptionProvider = encryptionProvider
        self.transaction = transaction
        self.finalState = finalState
        self.removePossiblyDeliveredMessagesUniqueIds = removePossiblyDeliveredMessagesUniqueIds
        self.policy = policy
        self.storyReactionContext = storyReactionContext
        self.storyRefreshContext = storyRefreshContext
        self.storyViewRefreshContext = storyViewRefreshContext
        self.peerActivityTimestamps = prepass.peerActivityTimestamps
        self.holesFromPreviousStateMessageIds = prepass.holesFromPreviousStateMessageIds
        self.readInboxCloudMessageIds = prepass.readInboxCloudMessageIds
        self.addedConferenceInvitationMessagesIds = prepass.addedConferenceInvitationMessagesIds
        self.wasScheduledMessageIds = prepass.wasScheduledMessageIds
        self.addedIncomingMessageIds = prepass.addedIncomingMessageIds
        self.mappedWalletMessageIds = prepass.mappedWalletMessageIds
    }

    func addMessageThreadStatsDifference(threadKey: MessageThreadKey, remove: Int, addedMessagePeer: PeerId?, addedMessageId: MessageId?, isOutgoing: Bool) {
        if let value = messageThreadStatsDifferences[threadKey] {
            value.removedCount += remove
            if let addedMessagePeer = addedMessagePeer, let addedMessageId = addedMessageId {
                value.peers.append(ReplyThreadUserMessage(id: addedMessagePeer, messageId: addedMessageId, isOutgoing: isOutgoing))
            }
        } else {
            let value = MessageThreadStatsRecord()
            messageThreadStatsDifferences[threadKey] = value
            value.removedCount = remove
            if let addedMessagePeer = addedMessagePeer, let addedMessageId = addedMessageId {
                value.peers.append(ReplyThreadUserMessage(id: addedMessagePeer, messageId: addedMessageId, isOutgoing: isOutgoing))
            }
        }
    }

    /// Applies the content operations, in order: each case calls its method in `StateReplay+<Family>.swift`, and the
    /// cases keep the order of the switch they come from. The two cases whose body does nothing stay here:
    /// `.UpdateAttachMenuBots`, and `.UpdateWalletTonConnectEvent`, whose event the line above the switch has already
    /// collected. That line, `walletTonConnectEvents(operation:)`, runs for every content operation first; it finds
    /// nothing in the four state operations, which `applyStateAdvance` applies afterwards. Next, a read-state operation
    /// for a channel the account is not a member of is skipped (`readStateOperationTargetsNonMember`), judged by the peer
    /// stored when it comes up, so a join merged earlier in the same replay counts.
    func applyContentOperations(_ operations: [AccountStateMutationOperation]) {
        for operation in operations {
            walletTonConnectEventBatch.append(contentsOf: walletTonConnectEvents(operation: operation))
            // The server's read state for a channel the account is not a member of is not kept
            // (NonMemberChannelReadState.swift). A join earlier in this replay is already stored.
            if readStateOperationTargetsNonMember(operation, getPeer: { transaction.getPeer($0) }) {
                continue
            }
            switch operation {
                case let .AddMessages(messages, location):
                    self.applyAddMessages(messages, location)
                case let .AddScheduledMessages(messages):
                    self.applyAddScheduledMessages(messages)
                case let .AddQuickReplyMessages(messages):
                    self.applyAddQuickReplyMessages(messages)
                case let .UpsertEphemeralReplacement(anchorMessageId, message):
                    self.applyUpsertEphemeralReplacement(anchorMessageId, message)
                case let .DeleteEphemeralMessages(peerId, ids):
                    self.applyDeleteEphemeralMessages(peerId, ids)
                case let .DeleteMessagesWithGlobalIds(ids):
                    self.applyDeleteMessagesWithGlobalIds(ids)
                case let .DeleteMessages(ids):
                    self.applyDeleteMessages(ids)
                case let .UpdateMinAvailableMessage(id):
                    self.applyUpdateMinAvailableMessage(id)
                case let .UpdatePeerChatInclusion(peerId, groupId, changedGroup):
                    self.applyUpdatePeerChatInclusion(peerId, groupId, changedGroup)
                case let .EditMessage(id, message):
                    self.applyEditMessage(id, message)
                case let .UpdateMessagePoll(pollId, apiPoll, results):
                    self.applyUpdateMessagePoll(pollId, apiPoll, results)
                case let .UpdateMedia(id, media):
                    self.applyUpdateMedia(id, media)
                case let .ReadInbox(messageId):
                    self.applyReadInbox(messageId)
                case let .ReadOutbox(messageId, timestamp):
                    self.applyReadOutbox(messageId, timestamp)
                case let .UpdateReadThread(peerId, threadId, readMaxId, isIncoming, mainChannelMessage):
                    self.applyUpdateReadThread(peerId, threadId, readMaxId, isIncoming, mainChannelMessage)
                case let .ResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread):
                    self.applyResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread)
                case let .ResetIncomingReadState(groupId, peerId, namespace, maxIncomingReadId, count, pts):
                    self.applyResetIncomingReadState(groupId, peerId, namespace, maxIncomingReadId, count, pts)
                case let .UpdatePeerChatUnreadMark(peerId, threadId, namespace, value):
                    self.applyUpdatePeerChatUnreadMark(peerId, threadId, namespace, value)
                case let .ResetMessageTagSummary(peerId, tag, namespace, count, range):
                    self.applyResetMessageTagSummary(peerId, tag, namespace, count, range)
                // Never reached: batchContentAndDeferStateOperations keeps the four state operations out of the content
                // operations, and applyStateAdvance applies them. The cases keep the switch exhaustive.
                case let .UpdateState(innerState):
                    self.applyUpdateState(innerState)
                case let .UpdateChannelState(peerId, pts):
                    self.applyUpdateChannelState(peerId, pts)
                case let .UpdateChannelInvalidationPts(peerId, pts):
                    self.applyUpdateChannelInvalidationPts(peerId, pts)
                case let .UpdateChannelSynchronizedUntilMessage(peerId, id):
                    self.applyUpdateChannelSynchronizedUntilMessage(peerId, id)
                case let .UpdateNotificationSettings(subject, notificationSettings):
                    self.applyUpdateNotificationSettings(subject, notificationSettings)
                case let .UpdateGlobalNotificationSettings(subject, notificationSettings):
                    self.applyUpdateGlobalNotificationSettings(subject, notificationSettings)
                case let .MergeApiChats(chats):
                    self.applyMergeApiChats(chats)
                case let .MergeApiUsers(users):
                    self.applyMergeApiUsers(users)
                case let .UpdatePeer(id, f):
                    self.applyUpdatePeer(id, f)
                case let .UpdateCachedPeerData(id, f):
                    self.applyUpdateCachedPeerData(id, f)
                case let .UpdateMessagesPinned(messageIds, pinned):
                    self.applyUpdateMessagesPinned(messageIds, pinned)
                case let .MergePeerPresences(statuses, explicit):
                    self.applyMergePeerPresences(statuses, explicit)
                case let .UpdateSecretChat(chat, _):
                    self.applyUpdateSecretChat(chat)
                case let .AddSecretMessages(messages):
                    self.applyAddSecretMessages(messages)
                case let .ReadSecretOutbox(peerId, maxTimestamp, actionTimestamp):
                    self.applyReadSecretOutbox(peerId, maxTimestamp, actionTimestamp)
                case let .AddPeerInputActivity(chatPeerId, peerId, activity):
                    self.applyAddPeerInputActivity(chatPeerId, peerId, activity)
                case let .AddPeerLiveTypingDraftUpdate(peerAndThreadId, id, timestamp, authorId, canStop, keepOnStop, content):
                    self.applyAddPeerLiveTypingDraftUpdate(peerAndThreadId, id, timestamp, authorId, canStop, keepOnStop, content)
                case let .AddPeerLiveTypingDraftStop(peerAndThreadId, randomId, timestamp):
                    self.applyAddPeerLiveTypingDraftStop(peerAndThreadId, randomId, timestamp)
                case let .UpdatePinnedItemIds(groupId, pinnedOperation):
                    self.applyUpdatePinnedItemIds(groupId, pinnedOperation)
                case let .UpdatePinnedSavedItemIds(pinnedOperation):
                    self.applyUpdatePinnedSavedItemIds(pinnedOperation)
                case let .UpdatePinnedTopic(peerId, threadId, isPinned):
                    self.applyUpdatePinnedTopic(peerId, threadId, isPinned)
                case let .UpdatePinnedTopicOrder(peerId, threadIds):
                    self.applyUpdatePinnedTopicOrder(peerId, threadIds)
                case let .EditForumTopic(peerId, threadId, components):
                    self.applyEditForumTopic(peerId, threadId, components)
                case let .ReadMessageContents(peerIdAndMessageIds, date):
                    self.applyReadMessageContents(peerIdAndMessageIds, date)
                case let .UpdateMessageImpressionCount(id, count):
                    self.applyUpdateMessageImpressionCount(id, count)
                case let .UpdateInstalledStickerPacks(operation):
                    self.applyUpdateInstalledStickerPacks(operation)
                case .UpdateRecentGifs:
                    self.applyUpdateRecentGifs()
                case let .UpdateChatInputState(peerId, threadId, inputState):
                    self.applyUpdateChatInputState(peerId, threadId, inputState)
                case let .UpdateCall(call):
                    self.applyUpdateCall(call)
                case let .AddCallSignalingData(callId, data):
                    self.applyAddCallSignalingData(callId, data)
                case let .UpdateGroupCallParticipants(callId, _, participants, version):
                    self.applyUpdateGroupCallParticipants(callId, participants, version)
                case let .UpdateGroupCallMessage(callId, authorId, isFromAdmin, messageId, text, date, paidMessageStars):
                    self.applyUpdateGroupCallMessage(callId, authorId, isFromAdmin, messageId, text, date, paidMessageStars)
                case let .UpdateGroupCallOpaqueMessage(callId, authorId, data):
                    self.applyUpdateGroupCallOpaqueMessage(callId, authorId, data)
                case let .UpdateGroupCall(peerId, call):
                    self.applyUpdateGroupCall(peerId, call)
                case let .UpdateGroupCallChainBlocks(id, _, subChainId, blocks, nextOffset):
                    self.applyUpdateGroupCallChainBlocks(id, subChainId, blocks, nextOffset)
                case let .UpdateAutoremoveTimeout(peer, autoremoveValue):
                    self.applyUpdateAutoremoveTimeout(peer, autoremoveValue)
                case let .UpdateLangPack(langCode, difference):
                    self.applyUpdateLangPack(langCode, difference)
                case let .UpdateTheme(theme):
                    self.applyUpdateTheme(theme)
                case let .UpdateWallpaper(peerId, wallpaper):
                    self.applyUpdateWallpaper(peerId, wallpaper)
                case .SyncChatListFilters:
                    self.applySyncChatListFilters()
                case let .UpdateChatListFilterOrder(order):
                    self.applyUpdateChatListFilterOrder(order)
                case let .UpdateChatListFilter(id, filter):
                    self.applyUpdateChatListFilter(id, filter)
                case let .UpdateMessageReactions(messageId, _, reactions, _):
                    self.applyUpdateMessageReactions(messageId, reactions)
                case .UpdateAttachMenuBots:
                    // No replay effect: the operation exists as a batching barrier between AddMessages runs (see
                    // batchContentAndDeferStateOperations).
                    break
                case let .UpdateAudioTranscription(messageId, id, isPending, text):
                    self.applyUpdateAudioTranscription(messageId, id, isPending, text)
                case .UpdateConfig:
                    self.applyUpdateConfig()
                case let .UpdateExtendedMedia(messageId, apiExtendedMedia):
                    self.applyUpdateExtendedMedia(messageId, apiExtendedMedia)
                case let .UpdateMessageWidgetData(messageId, chatData, publicData, publicDataHash):
                    self.applyUpdateMessageWidgetData(messageId, chatData: chatData, publicData: publicData, publicDataHash: publicDataHash)
                case let .ResetForumTopic(topicId, data, _):
                    self.applyResetForumTopic(topicId, data)
                case let .UpdateStory(peerId, story):
                    self.applyUpdateStory(peerId, story)
                case let .UpdateReadStories(peerId, maxId):
                    self.applyUpdateReadStories(peerId, maxId)
                case let .UpdateStoryStealthMode(data):
                    self.applyUpdateStoryStealthMode(data)
                case let .UpdateStorySentReaction(peerId, id, reaction):
                    self.applyUpdateStorySentReaction(peerId, id, reaction)
                case let .UpdateNewAuthorization(isUnconfirmed, hash, date, device, location):
                    self.applyUpdateNewAuthorization(isUnconfirmed, hash, date, device, location)
                case let .UpdateNewBotConnection(confirmed, botId, date, device, location):
                    self.applyUpdateNewBotConnection(confirmed, botId, date, device, location)
                case let .UpdateWebBrowserSettings(openExternalBrowser):
                    self.applyUpdateWebBrowserSettings(openExternalBrowser)
                case let .UpdateWebBrowserException(openExternalBrowser, delete, exception):
                    self.applyUpdateWebBrowserException(openExternalBrowser, delete, exception)
                case let .UpdateStarsBalance(peerId, currency, balance):
                    self.applyUpdateStarsBalance(peerId, currency, balance)
                case let .UpdateWalletTransfer(update):
                    self.applyUpdateWalletTransfer(update)
                case .UpdateWalletTonConnectEvent:
                    // Nothing to do here: `walletTonConnectEvents(operation:)` above the switch collected the event.
                    break
                case let .UpdateWalletState(state):
                    self.applyUpdateWalletState(state)
                case let .UpdateAgentSettings(settings):
                    self.applyUpdateAgentSettings(settings)
                case let .UpdateStarsRevenueStatus(peerId, status):
                    self.applyUpdateStarsRevenueStatus(peerId, status)
                case let .UpdateStarsReactionsDefaultPrivacy(value):
                    self.applyUpdateStarsReactionsDefaultPrivacy(value)
                case let .ReportMessageDelivery(messageIds):
                    self.applyReportMessageDelivery(messageIds)
                case let .UpdateMonoForumNoPaidException(peerId, threadId, isFree):
                    self.applyUpdateMonoForumNoPaidException(peerId, threadId, isFree)
                case let .UpdateReadFeed(filterId, maxPosition):
                    self.applyUpdateReadFeed(filterId, maxPosition)
                case let .UpdateStarGiftAuctionState(giftId, state):
                    self.applyUpdateStarGiftAuctionState(giftId, state)
                case let .UpdateStarGiftAuctionMyState(giftId, state):
                    self.applyUpdateStarGiftAuctionMyState(giftId, state)
                case let .UpdateEmojiGameInfo(info):
                    self.applyUpdateEmojiGameInfo(info)
            }
        }
    }

    /// The steps after every operation, in the order they ran as the tail of `replayFinalState`; each is a method in
    /// `StateReplay+Finalize.swift`.
    ///
    /// Fire-and-forget: work that the replay starts inside its transaction and that runs on another queue, so it can
    /// overlap the rest of the transaction, and is never waited for. Here, `applyLangPackDifferences` and
    /// `applyUpdatedThemes` start an account-manager transaction each, on the account manager's own queue (the first
    /// may queue a Postbox transaction from there), and `processAddedSecretMessages` stores the resource data of the
    /// decrypted messages (`MediaBox.storeResourceData`). `MediaBox.removeCachedResources` can be started, among the
    /// content operations, by `applyDeleteMessagesWithGlobalIds` and `applyUpdateMinAvailableMessage`, and, for secret
    /// chats, through `_internal_deleteMessages` or `_internal_clearHistory`: by `applyDeleteMessages`, by
    /// `applyUpdateSecretChat` (a discarded chat whose history is removed) and, here, by `processAddedSecretMessages`
    /// (a decrypted deletion or history clear).
    func finalize() {
        self.addHolesFromPreviousState()
        self.applyForumTopicListResets()
        self.applyMessageThreadStatsDifferences()
        self.applyPeerActivityTimestamps()
        self.applyStickerPackOperations()
        self.addRecentlyUsedStickers()
        self.applySlowModeTimeouts()
        self.applyRecentGifs()
        self.addRecentlyUsedGuestChatBots()
        self.invalidatePeerGroupStats()
        self.addSecretChatTypingActivities()
        self.processAddedSecretMessages()
        self.clearTypingOfSecretMessageAuthors()
        // Fire-and-forget: each may start an account-manager transaction, which runs on the account manager's own
        // queue and can overlap this one.
        self.applyLangPackDifferences()
        self.applyUpdatedThemes()
        self.applyWebBrowserSettingsUpdates()
        self.applyUpdatedWallpapers()
        self.addSecretMessagesToIncomingIds()
        self.reconcileWalletTransferMessages()
        self.deletePossiblyDeliveredMessages()
        self.requestChatListFiltersSyncIfNeeded()
        self.synchronizeStoriesOfFeedPeers()
        self.applyStarsReactionsDefaultPrivacy()
        self.applyLiveTypingDraftUpdates()
    }

    /// The replay's result: the final state and the events that the operations and `finalize` collected. Built last,
    /// inside the transaction: its wallet transfer events read it (`WalletTransaction(apiTransaction:transaction:)`).
    func buildResult() -> AccountReplayedFinalState {
        return AccountReplayedFinalState(
            state: finalState,
            addedIncomingMessageIds: addedIncomingMessageIds,
            addedReactionEvents: addedReactionEvents,
            wasScheduledMessageIds: wasScheduledMessageIds,
            deletedMessageIds: deletedMessageIds,
            updatedTypingActivities: updatedTypingActivities,
            updatedWebpages: updatedWebpages,
            updatedCalls: updatedCalls,
            addedCallSignalingData: addedCallSignalingData,
            updatedGroupCallParticipants: updatedGroupCallParticipants,
            groupCallMessageUpdates: groupCallMessageUpdates,
            storyUpdates: storyUpdates,
            delayNotificatonsUntil: delayNotificatonsUntil,
            updatedIncomingThreadReadStates: updatedIncomingThreadReadStates,
            updatedOutgoingThreadReadStates: updatedOutgoingThreadReadStates,
            updateConfig: updateConfig,
            isPremiumUpdated: isPremiumUpdated,
            updatedStarsBalance: updatedStarsBalance,
            updatedTonBalance: updatedTonBalance,
            walletTransferUpdates: walletTransferApiUpdates.compactMap { update in
                switch update {
                case let .updateSentWalletTransaction(data):
                    guard !data.msgHash.isEmpty else { return nil }
                    return .sentTransaction(WalletSentTransfer(apiTransfer: data), data.transaction.map {
                        WalletTransaction(apiTransaction: $0, transaction: transaction)
                    })
                case let .updateWalletGaslessInfo(data):
                    return .gaslessInfo(WalletGaslessInfo(apiInfo: data))
                default:
                    return nil
                }
            },
            walletTonConnectEvents: walletTonConnectEventBatch,
            updatedWalletState: updatedWalletState,
            updatedAgentSettings: updatedAgentSettings,
            updatedStarsRevenueStatus: updatedStarsRevenueStatus,
            sentScheduledMessageIds: finalState.state.sentScheduledMessageIds,
            reportMessageDelivery: reportMessageDelivery,
            addedConferenceInvitationMessagesIds: addedConferenceInvitationMessagesIds,
            updatedStarGiftAuctionState: updatedStarGiftAuctionState,
            updatedStarGiftAuctionMyState: updatedStarGiftAuctionMyState,
            updatedEmojiGameInfo: updatedEmojiGameInfo
        )
    }
}
