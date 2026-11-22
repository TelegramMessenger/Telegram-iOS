import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

private final class UpdatedWebpageSubscriberContext {
    let subscribers = Bag<(TelegramMediaWebpage?) -> Void>()
}

private final class UpdatedStarsBalanceSubscriberContext {
    let subscribers = Bag<([PeerId: StarsAmount]) -> Void>()
}

private final class UpdatedStarsRevenueStatusSubscriberContext {
    let subscribers = Bag<([PeerId: StarsRevenueStats.Balances]) -> Void>()
}

private final class UpdatedStarGiftAuctionStateSubscriberContext {
    let subscribers = Bag<([Int64: GiftAuctionContext.State.AuctionState]) -> Void>()
}

private final class UpdatedStarGiftAuctionMyStateSubscriberContext {
    let subscribers = Bag<([Int64: GiftAuctionContext.State.MyState]) -> Void>()
}

/// Where `AccountStateManager`'s events leave it (state-sync spec 3.4): the pipes, promises and per-subscriber
/// contexts it hands out, and what a `dispatchEvents` operation does with one batch of `AccountFinalStateEvents`.
/// `AccountStateManager.Impl` builds the hub in its `init`, is its only owner and forwards every accessor to it
/// unchanged; the operation queue, isUpdating and the qts acknowledgement (`appliedQtsPromise`) stay in the Impl.
/// The hub holds no reference to the Impl and nothing else holds the hub, so it lives exactly as long as the Impl:
/// each `[weak self]` here (the notification read, the subscriber registrations) is nil exactly when the Impl has
/// gone, as a `[weak self]` on the Impl would be.
///
/// Everything runs on the manager's queue: the Impl calls in from there, and every pipe and subscriber fires
/// there. The subscription signals (`updatedWebpage(_:)`, `updatedStarsBalance()`, ...) and the `modify...`
/// methods hop to the queue themselves, which is inline when they are called there, as they are.
///
/// A `dispatchEvents` operation runs in three phases, in this order:
/// 1. `dispatch(_:completed:)` starts the Postbox transaction that reads the notification messages (it never runs
///    inline: the result arrives on the queue later);
/// 2. it then hands the events that need no storage read to their pipes, before returning: reactions (always,
///    even when there are none), alerts, dismissed bot web views, join-chat decisions, externally updated peers,
///    the authorization list, deleted messages, then the config and premium callbacks;
/// 3. on the queue, once the transaction is done: `notificationMessages`, then the operation's completion, which
///    takes the operation off the queue and calls `dispatchAfterNotificationMessages(_:)` (typing, web pages,
///    balances, wallet, auctions, emoji game, calls, group calls, stories, thread read states, scheduled
///    messages, delivery reports, conference invitations) before the Impl's own steps (the applied qts, the
///    barrier's message ids, the next operation).
final class AccountStateEventHub {
    private let queue: Queue
    private let postbox: Postbox
    private let network: Network
    private let callSessionManager: CallSessionManager?
    private let peerInputActivityManager: PeerInputActivityManager?
    private let updateConfigRequested: (() -> Void)?
    private let isPremiumUpdated: (() -> Void)?

    private let notificationMessagesPipe = ValuePipe<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)]>()
    var notificationMessages: Signal<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)], NoError> {
        return self.notificationMessagesPipe.signal()
    }

    private let reactionNotificationsPipe = ValuePipe<[(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)]>()
    var reactionNotifications: Signal<[(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)], NoError> {
        return self.reactionNotificationsPipe.signal()
    }

    private let displayAlertsPipe = ValuePipe<[(text: String, isDropAuth: Bool)]>()
    var displayAlerts: Signal<[(text: String, isDropAuth: Bool)], NoError> {
        return self.displayAlertsPipe.signal()
    }

    private let dismissBotWebViewsPipe = ValuePipe<[Int64]>()
    var dismissBotWebViews: Signal<[Int64], NoError> {
        return self.dismissBotWebViewsPipe.signal()
    }

    private let joinChatWebViewDecisionsPipe = ValuePipe<[JoinChatWebViewDecision]>()
    var joinChatWebViewDecisions: Signal<[JoinChatWebViewDecision], NoError> {
        return self.joinChatWebViewDecisionsPipe.signal()
    }

    private let externallyUpdatedPeerIdsPipe = ValuePipe<[PeerId]>()
    var externallyUpdatedPeerIds: Signal<[PeerId], NoError> {
        return self.externallyUpdatedPeerIdsPipe.signal()
    }

    private let termsOfServiceUpdateValue = Atomic<TermsOfServiceUpdate?>(value: nil)
    private let termsOfServiceUpdatePromise = Promise<TermsOfServiceUpdate?>(nil)
    var termsOfServiceUpdate: Signal<TermsOfServiceUpdate?, NoError> {
        return self.termsOfServiceUpdatePromise.get()
    }

    private let appUpdateInfoValue = Atomic<AppUpdateInfo?>(value: nil)
    private let appUpdateInfoPromise = Promise<AppUpdateInfo?>(nil)
    var appUpdateInfo: Signal<AppUpdateInfo?, NoError> {
        return self.appUpdateInfoPromise.get()
    }

    private let contactBirthdaysValue = Atomic<[EnginePeer.Id: TelegramBirthday]>(value: [:])
    private let contactBirthdaysPromise = Promise<[EnginePeer.Id: TelegramBirthday]>([:])
    var contactBirthdays: Signal<[EnginePeer.Id: TelegramBirthday], NoError> {
        return self.contactBirthdaysPromise.get()
    }

    private let appliedIncomingReadMessagesPipe = ValuePipe<[MessageId]>()
    var appliedIncomingReadMessages: Signal<[MessageId], NoError> {
        return self.appliedIncomingReadMessagesPipe.signal()
    }

    private let significantStateUpdateCompletedPipe = ValuePipe<Void>()
    var significantStateUpdateCompleted: Signal<Void, NoError> {
        return self.significantStateUpdateCompletedPipe.signal()
    }

    private let authorizationListUpdatesPipe = ValuePipe<Void>()
    var authorizationListUpdates: Signal<Void, NoError> {
        return self.authorizationListUpdatesPipe.signal()
    }

    private let threadReadStateUpdatesPipe = ValuePipe<(incoming: [PeerAndBoundThreadId: MessageId.Id], outgoing: [PeerAndBoundThreadId: MessageId.Id])>()
    var threadReadStateUpdates: Signal<(incoming: [PeerAndBoundThreadId: MessageId.Id], outgoing: [PeerAndBoundThreadId: MessageId.Id]), NoError> {
        return self.threadReadStateUpdatesPipe.signal()
    }

    private let groupCallParticipantUpdatesPipe = ValuePipe<[(Int64, GroupCallParticipantsContext.Update)]>()
    var groupCallParticipantUpdates: Signal<[(Int64, GroupCallParticipantsContext.Update)], NoError> {
        return self.groupCallParticipantUpdatesPipe.signal()
    }

    private let groupCallMessageUpdatesPipe = ValuePipe<[GroupCallMessageUpdate]>()
    var groupCallMessageUpdates: Signal<[GroupCallMessageUpdate], NoError> {
        return self.groupCallMessageUpdatesPipe.signal()
    }

    private let deletedMessagesPipe = ValuePipe<[DeletedMessageId]>()
    var deletedMessages: Signal<[DeletedMessageId], NoError> {
        return self.deletedMessagesPipe.signal()
    }

    let storyUpdatesPipe = ValuePipe<[InternalStoryUpdate]>()
    var storyUpdates: Signal<[InternalStoryUpdate], NoError> {
        return self.storyUpdatesPipe.signal()
    }

    let walletTransferUpdatesPipe = ValuePipe<[WalletTransferUpdate]>()
    let walletTonConnectUpdatesPipe = ValuePipe<[WalletTonConnectEvent]>()

    private let walletStateUpdatesPipe = ValuePipe<Api.WalletState>()
    var walletStateUpdates: Signal<Api.WalletState, NoError> {
        return self.walletStateUpdatesPipe.signal()
    }

    private let agentSettingsUpdatesPipe = ValuePipe<EngineAgentSettings>()
    var agentSettingsUpdates: Signal<EngineAgentSettings, NoError> {
        return self.agentSettingsUpdatesPipe.signal()
    }

    let botPreviewUpdatesPipe = ValuePipe<[InternalBotPreviewUpdate]>()
    var botPreviewUpdates: Signal<[InternalBotPreviewUpdate], NoError> {
        return self.botPreviewUpdatesPipe.signal()
    }

    let forceSendPendingStarsReactionPipe = ValuePipe<MessageId>()
    var forceSendPendingStarsReaction: Signal<MessageId, NoError> {
        return self.forceSendPendingStarsReactionPipe.signal()
    }

    let forceSendPendingPaidMessagePipe = ValuePipe<PeerId>()
    var forceSendPendingPaidMessage: Signal<PeerId, NoError> {
        return self.forceSendPendingPaidMessagePipe.signal()
    }

    let commitSendPendingPaidMessagePipe = ValuePipe<MessageId>()
    var commitSendPendingPaidMessage: Signal<MessageId, NoError> {
        return self.commitSendPendingPaidMessagePipe.signal()
    }

    private let sentScheduledMessageIdsPipe = ValuePipe<Set<MessageId>>()
    var sentScheduledMessageIds: Signal<Set<MessageId>, NoError> {
        return self.sentScheduledMessageIdsPipe.signal()
    }

    let starRefBotConnectionEventsPipe = ValuePipe<StarRefBotConnectionEvent>()
    var starRefBotConnectionEvents: Signal<StarRefBotConnectionEvent, NoError> {
        return self.starRefBotConnectionEventsPipe.signal()
    }

    let installedStickerPacksArchivedEventsPipe = ValuePipe<Int>()
    var installedStickerPacksArchivedEvents: Signal<Int, NoError> {
        return self.installedStickerPacksArchivedEventsPipe.signal()
    }

    private var updatedWebpageContexts: [MediaId: UpdatedWebpageSubscriberContext] = [:]
    private var updatedStarsBalanceContext = UpdatedStarsBalanceSubscriberContext()
    private var updatedTonBalanceContext = UpdatedStarsBalanceSubscriberContext()
    private var updatedStarsRevenueStatusContext = UpdatedStarsRevenueStatusSubscriberContext()
    private var updatedStarGiftAuctionStateContext = UpdatedStarGiftAuctionStateSubscriberContext()
    private var updatedStarGiftAuctionMyStateContext = UpdatedStarGiftAuctionMyStateSubscriberContext()

    private let reportMessageDeliveryDisposable = DisposableSet()
    private let updateEmojiGameInfoDisposable = MetaDisposable()

    init(queue: Queue, postbox: Postbox, network: Network, callSessionManager: CallSessionManager?, peerInputActivityManager: PeerInputActivityManager?, updateConfigRequested: (() -> Void)?, isPremiumUpdated: (() -> Void)?) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
        self.callSessionManager = callSessionManager
        self.peerInputActivityManager = peerInputActivityManager
        self.updateConfigRequested = updateConfigRequested
        self.isPremiumUpdated = isPremiumUpdated
    }

    /// Runs when the Impl releases the hub, right after the Impl's own `deinit`: the delivery reports and the
    /// emoji game write still in flight are cancelled, as the Impl's `deinit` cancelled them before.
    deinit {
        self.reportMessageDeliveryDisposable.dispose()
        self.updateEmojiGameInfoDisposable.dispose()
    }

    /// The end of a poll cycle. Called only by `finishPollCycle`, where a cycle whose channel resets were pending
    /// ends too, once they are done.
    func notifySignificantStateUpdateCompleted() {
        self.significantStateUpdateCompletedPipe.putNext(Void())
    }

    /// Phases 1 and 2 of a `dispatchEvents` operation (see the type's doc): starts the notification read, whose
    /// result reaches `notificationMessages` on the queue and is followed there by `completed`, then hands the
    /// events that need no storage read to their pipes.
    func dispatch(_ events: AccountFinalStateEvents, completed: @escaping () -> Void) {
        let signal = self.postbox.transaction { transaction -> [([Message], PeerGroupId, Bool, MessageHistoryThreadData?)] in
            var messageList: [([Message], PeerGroupId, Bool, MessageHistoryThreadData?)] = []

            for id in events.addedIncomingMessageIds {
                let (messages, notify, _, _, threadData) = messagesForNotification(transaction: transaction, id: id, alwaysReturnMessage: false)
                if !messages.isEmpty {
                    messageList.append((messages, .root, notify, threadData))
                }
            }
            var wasScheduledMessages: [Message] = []
            for id in events.wasScheduledMessageIds {
                if let message = transaction.getMessage(id) {
                    wasScheduledMessages.append(message)
                }
            }
            if !wasScheduledMessages.isEmpty {
                var threadData: MessageHistoryThreadData?
                let first = wasScheduledMessages[0]
                for attr in first.attributes {
                    if let attribute = attr as? ReplyMessageAttribute {
                        if let threadId = attribute.threadMessageId {
                            threadData = transaction.getMessageHistoryThreadInfo(peerId: first.id.peerId, threadId: Int64(threadId.id))?.data.get(MessageHistoryThreadData.self)
                        }
                    }
                }
                messageList.append((wasScheduledMessages, .root, true, threadData))
            }
            return messageList
        }

        let _ = (signal
        |> deliverOn(self.queue)).start(next: { [weak self] messages in
            if let strongSelf = self {
                strongSelf.notificationMessagesPipe.putNext(messages)
            }
        }, completed: {
            completed()
        })

        let timestamp = Int32(Date().timeIntervalSince1970)
        let minReactionTimestamp = timestamp - 20
        let reactionEvents = events.addedReactionEvents.compactMap { event -> (reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)? in
            if event.timestamp >= minReactionTimestamp {
                return (event.reactionAuthor, event.reaction, event.message, event.timestamp)
            } else {
                return nil
            }
        }
        self.reactionNotificationsPipe.putNext(reactionEvents)

        if !events.displayAlerts.isEmpty {
            self.displayAlertsPipe.putNext(events.displayAlerts)
        }

        if !events.dismissBotWebViews.isEmpty {
            self.dismissBotWebViewsPipe.putNext(events.dismissBotWebViews)
        }

        if !events.joinChatWebViewDecisions.isEmpty {
            self.joinChatWebViewDecisionsPipe.putNext(events.joinChatWebViewDecisions)
        }

        if !events.externallyUpdatedPeerId.isEmpty {
            self.externallyUpdatedPeerIdsPipe.putNext(Array(events.externallyUpdatedPeerId))
        }

        if events.authorizationListUpdated {
            self.authorizationListUpdatesPipe.putNext(Void())
        }

        if !events.deletedMessageIds.isEmpty {
            self.deletedMessagesPipe.putNext(events.deletedMessageIds)
        }

        if events.updateConfig {
            self.updateConfigRequested?()
        }

        if events.isPremiumUpdated {
            self.isPremiumUpdated?()
        }
    }

    /// Phase 3's fan-out (see the type's doc), called by the operation's completion once `notificationMessages`
    /// has fired and the operation was taken off the queue.
    func dispatchAfterNotificationMessages(_ events: AccountFinalStateEvents) {
        if !events.updatedTypingActivities.isEmpty {
            self.peerInputActivityManager?.transaction { manager in
                for (chatPeerId, peerActivities) in events.updatedTypingActivities {
                    for (peerId, activity) in peerActivities {
                        if let activity = activity {
                            manager.addActivity(chatPeerId: chatPeerId, peerId: peerId, activity: activity)
                        } else {
                            manager.removeAllActivities(chatPeerId: chatPeerId, peerId: peerId)
                        }
                    }
                }
            }
        }
        if !events.updatedWebpages.isEmpty {
            self.notifyUpdatedWebpages(events.updatedWebpages)
        }
        if !events.updatedStarsBalance.isEmpty {
            self.notifyUpdatedStarsBalance(events.updatedStarsBalance)
        }
        if !events.updatedTonBalance.isEmpty {
            self.notifyUpdatedTonBalance(events.updatedTonBalance)
        }
        if !events.walletTransferUpdates.isEmpty {
            self.walletTransferUpdatesPipe.putNext(events.walletTransferUpdates)
        }
        if !events.walletTonConnectEvents.isEmpty {
            self.walletTonConnectUpdatesPipe.putNext(events.walletTonConnectEvents)
        }
        if let updatedWalletState = events.updatedWalletState {
            self.walletStateUpdatesPipe.putNext(updatedWalletState)
        }
        if let updatedAgentSettings = events.updatedAgentSettings {
            self.agentSettingsUpdatesPipe.putNext(updatedAgentSettings)
        }
        if !events.updatedStarsRevenueStatus.isEmpty {
            self.notifyUpdatedStarsRevenueStatus(events.updatedStarsRevenueStatus)
        }
        if !events.updatedStarGiftAuctionState.isEmpty {
            self.notifyUpdatedStarGiftAuctionState(events.updatedStarGiftAuctionState)
        }
        if !events.updatedStarGiftAuctionMyState.isEmpty {
            self.notifyUpdatedStarGiftAuctionMyState(events.updatedStarGiftAuctionMyState)
        }
        if let updatedEmojiGameInfo = events.updatedEmojiGameInfo {
            self.updateEmojiGameInfoDisposable.set(self.postbox.transaction({ transaction in
                updateEmojiGameInfo(transaction: transaction, { _ in return updatedEmojiGameInfo })
            }).start())
        }
        if !events.updatedCalls.isEmpty {
            for call in events.updatedCalls {
                self.callSessionManager?.updateSession(call, completion: { _ in })
            }
        }
        if !events.addedCallSignalingData.isEmpty {
            for (id, data) in events.addedCallSignalingData {
                self.callSessionManager?.addCallSignalingData(id: id, data: data)
            }
        }
        if !events.updatedGroupCallParticipants.isEmpty {
            self.groupCallParticipantUpdatesPipe.putNext(events.updatedGroupCallParticipants)
        }
        if !events.groupCallMessageUpdates.isEmpty {
            self.groupCallMessageUpdatesPipe.putNext(events.groupCallMessageUpdates)
        }
        if !events.storyUpdates.isEmpty {
            self.storyUpdatesPipe.putNext(events.storyUpdates)
        }
        if !events.updatedIncomingThreadReadStates.isEmpty || !events.updatedOutgoingThreadReadStates.isEmpty {
            self.threadReadStateUpdatesPipe.putNext((events.updatedIncomingThreadReadStates, events.updatedOutgoingThreadReadStates))
        }
        if !events.sentScheduledMessageIds.isEmpty {
            self.sentScheduledMessageIdsPipe.putNext(events.sentScheduledMessageIds)
        }
        if !events.reportMessageDelivery.isEmpty {
            self.reportMessageDeliveryDisposable.add(_internal_reportMessageDelivery(postbox: self.postbox, network: self.network, messageIds: Array(events.reportMessageDelivery), fromPushNotification: false).start())
        }
        if !events.addedConferenceInvitationMessagesIds.isEmpty {
            self.callSessionManager?.addConferenceInvitationMessages(ids: events.addedConferenceInvitationMessagesIds.map { ($0, nil) })
        }
    }

    func updatedWebpage(_ webpageId: MediaId) -> Signal<TelegramMediaWebpage?, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let context: UpdatedWebpageSubscriberContext
                    if let current = strongSelf.updatedWebpageContexts[webpageId] {
                        context = current
                    } else {
                        context = UpdatedWebpageSubscriberContext()
                        strongSelf.updatedWebpageContexts[webpageId] = context
                    }

                    let index = context.subscribers.add({ media in
                        subscriber.putNext(media)
                    })

                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            if let context = strongSelf.updatedWebpageContexts[webpageId] {
                                context.subscribers.remove(index)
                                if context.subscribers.isEmpty {
                                    strongSelf.updatedWebpageContexts.removeValue(forKey: webpageId)
                                }
                            }
                        }
                    })
                }
            }
            return disposable
        }
    }

    private func notifyUpdatedWebpages(_ updatedWebpages: [MediaId: TelegramMediaWebpage?]) {
        for (id, context) in self.updatedWebpageContexts {
            // Unwraps the lookup only: a key holding nil is a removal and is delivered.
            if let media = updatedWebpages[id] {
                for subscriber in context.subscribers.copyItems() {
                    subscriber(media)
                }
            }
        }
    }

    func notifyAppliedIncomingReadMessages(_ ids: [MessageId]) {
        self.appliedIncomingReadMessagesPipe.putNext(ids)
    }

    func modifyTermsOfServiceUpdate(_ f: @escaping (TermsOfServiceUpdate?) -> (TermsOfServiceUpdate?)) {
        self.queue.async {
            let current = self.termsOfServiceUpdateValue.with { $0 }
            let updated = f(current)
            if (current != updated) {
                let _ = self.termsOfServiceUpdateValue.swap(updated)
                self.termsOfServiceUpdatePromise.set(.single(updated))
            }
        }
    }

    func modifyAppUpdateInfo(_ f: @escaping (AppUpdateInfo?) -> (AppUpdateInfo?)) {
        self.queue.async {
            let current = self.appUpdateInfoValue.with { $0 }
            let updated = f(current)
            if (current != updated) {
                let _ = self.appUpdateInfoValue.swap(updated)
                self.appUpdateInfoPromise.set(.single(updated))
            }
        }
    }

    func modifyContactBirthdays(_ f: @escaping ([EnginePeer.Id: TelegramBirthday]) -> ([EnginePeer.Id: TelegramBirthday])) {
        self.queue.async {
            let current = self.contactBirthdaysValue.with { $0 }
            let updated = f(current)
            if (current != updated) {
                let _ = self.contactBirthdaysValue.swap(updated)
                self.contactBirthdaysPromise.set(.single(updated))
            }
        }
    }

    func updatedStarsBalance() -> Signal<[PeerId: StarsAmount], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.updatedStarsBalanceContext.subscribers.add({ starsBalance in
                        subscriber.putNext(starsBalance)
                    })

                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            strongSelf.updatedStarsBalanceContext.subscribers.remove(index)
                        }
                    })
                }
            }
            return disposable
        }
    }

    private func notifyUpdatedStarsBalance(_ updatedStarsBalance: [PeerId: StarsAmount]) {
        for subscriber in self.updatedStarsBalanceContext.subscribers.copyItems() {
            subscriber(updatedStarsBalance)
        }
    }

    func updatedTonBalance() -> Signal<[PeerId: StarsAmount], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.updatedTonBalanceContext.subscribers.add({ starsBalance in
                        subscriber.putNext(starsBalance)
                    })

                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            strongSelf.updatedTonBalanceContext.subscribers.remove(index)
                        }
                    })
                }
            }
            return disposable
        }
    }

    private func notifyUpdatedTonBalance(_ updatedTonBalance: [PeerId: StarsAmount]) {
        for subscriber in self.updatedTonBalanceContext.subscribers.copyItems() {
            subscriber(updatedTonBalance)
        }
    }

    func updatedStarsRevenueStatus() -> Signal<[PeerId: StarsRevenueStats.Balances], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.updatedStarsRevenueStatusContext.subscribers.add({ revenueBalances in
                        subscriber.putNext(revenueBalances)
                    })

                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            strongSelf.updatedStarsRevenueStatusContext.subscribers.remove(index)
                        }
                    })
                }
            }
            return disposable
        }
    }

    private func notifyUpdatedStarsRevenueStatus(_ updatedStarsRevenueStatus: [PeerId: StarsRevenueStats.Balances]) {
        for subscriber in self.updatedStarsRevenueStatusContext.subscribers.copyItems() {
            subscriber(updatedStarsRevenueStatus)
        }
    }

    func updatedStarGiftAuctionState() -> Signal<[Int64: GiftAuctionContext.State.AuctionState], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.updatedStarGiftAuctionStateContext.subscribers.add({ starsBalance in
                        subscriber.putNext(starsBalance)
                    })

                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            strongSelf.updatedStarGiftAuctionStateContext.subscribers.remove(index)
                        }
                    })
                }
            }
            return disposable
        }
    }

    private func notifyUpdatedStarGiftAuctionState(_ updatedStarGiftAuctionState: [Int64: GiftAuctionContext.State.AuctionState]) {
        for subscriber in self.updatedStarGiftAuctionStateContext.subscribers.copyItems() {
            subscriber(updatedStarGiftAuctionState)
        }
    }

    func updatedStarGiftAuctionMyState() -> Signal<[Int64: GiftAuctionContext.State.MyState], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.updatedStarGiftAuctionMyStateContext.subscribers.add({ starsBalance in
                        subscriber.putNext(starsBalance)
                    })

                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            strongSelf.updatedStarGiftAuctionMyStateContext.subscribers.remove(index)
                        }
                    })
                }
            }
            return disposable
        }
    }

    private func notifyUpdatedStarGiftAuctionMyState(_ updatedStarGiftAuctionMyState: [Int64: GiftAuctionContext.State.MyState]) {
        for subscriber in self.updatedStarGiftAuctionMyStateContext.subscribers.copyItems() {
            subscriber(updatedStarGiftAuctionMyState)
        }
    }

    func notifyDeletedMessages(messageIds: [MessageId]) {
        self.deletedMessagesPipe.putNext(messageIds.map { .messageId($0) })
    }

    /// Messages a stored-message confirmation deleted (`AccountStateManager.noteStoredMessageConfirmationDeletions`),
    /// already named as the replay names its deletions.
    func notifyConfirmedDeletions(_ ids: [DeletedMessageId]) {
        if !ids.isEmpty {
            self.deletedMessagesPipe.putNext(ids)
        }
    }

    func addStarRefBotConnectionEvent(event: StarRefBotConnectionEvent) {
        self.starRefBotConnectionEventsPipe.putNext(event)
    }
}
