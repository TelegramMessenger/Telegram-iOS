import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

private enum CustomOperationEvent<T, E> {
    case Next(T)
    case Error(E)
    case Completion
}

public enum DeletedMessageId: Hashable {
    case global(Int32)
    case messageId(MessageId)
}

final class MessagesRemovedContext {
    private var messagesRemovedInteractively = Set<DeletedMessageId>()
    private var messagesRemovedRemotely = Set<DeletedMessageId>()
    private var messagesRemovedInteractivelyLock = NSLock()
    
    func synchronouslyIsMessageDeletedInteractively(ids: [MessageId]) -> [EngineMessage.Id] {
        var result: [EngineMessage.Id] = []
        
        self.messagesRemovedInteractivelyLock.lock()
        for id in ids {
            let mappedId: DeletedMessageId
            if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
                mappedId = .global(id.id)
            } else {
                mappedId = .messageId(id)
            }
            if self.messagesRemovedInteractively.contains(mappedId) {
                result.append(id)
            }
        }
        self.messagesRemovedInteractivelyLock.unlock()
        
        return result
    }
    
    func synchronouslyIsMessageDeletedRemotely(ids: [MessageId]) -> [EngineMessage.Id] {
        var result: [EngineMessage.Id] = []
        
        self.messagesRemovedInteractivelyLock.lock()
        for id in ids {
            let mappedId: DeletedMessageId
            if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
                mappedId = .global(id.id)
            } else {
                mappedId = .messageId(id)
            }
            if self.messagesRemovedRemotely.contains(mappedId) {
                result.append(id)
            }
        }
        self.messagesRemovedInteractivelyLock.unlock()
        
        return result
    }
    
    func addIsMessagesDeletedInteractively(ids: [DeletedMessageId]) {
        if ids.isEmpty {
            return
        }
        
        self.messagesRemovedInteractivelyLock.lock()
        self.messagesRemovedInteractively.formUnion(ids)
        self.messagesRemovedInteractivelyLock.unlock()
    }
    
    func addIsMessagesDeletedRemotely(ids: [DeletedMessageId]) {
        if ids.isEmpty {
            return
        }
        
        self.messagesRemovedInteractivelyLock.lock()
        self.messagesRemovedRemotely.formUnion(ids)
        self.messagesRemovedInteractivelyLock.unlock()
    }
}

public final class AccountStateManager {
    /// How long a pushed batch with a common pts/qts/seq hole waits before the getDifference that fills it (the
    /// `gapWait` operation queued by `processBatch`) when `init` is not given another `gapWaitTimeout`;
    /// `Tests/StateSync` passes a shorter one. Production: 2 s.
    static let defaultGapWaitTimeout: Double = 2.0

    /// How long the poll waits before the `n`-th differenceTooLong reset in a row of one poll cycle (`n` from
    /// 1; the count starts over after a poll that needed no reset). The first reset runs at once, then 1 s,
    /// doubling up to 60 s (MTContext's reconnect curve), so a server that keeps answering differenceTooLong,
    /// or a reset that keeps getting messages.dialogsNotModified, cannot make the cycle a hot loop. The cycle
    /// never gives up. `Tests/StateSync` replaces it.
    static var consecutiveResetDelay: (Int) -> Double = { n in
        if n <= 1 {
            return 0.0
        }
        return min(60.0, Double(1 << min(n - 2, 6)))
    }

    public final class IncomingCallUpdate {
        public let callId: Int64
        public let callAccessHash: Int64
        public let timestamp: Int32
        public let peer: EnginePeer
        public let isVideo: Bool
        public let isConference: Bool
        
        init(
            callId: Int64,
            callAccessHash: Int64,
            timestamp: Int32,
            peer: EnginePeer,
            isVideo: Bool,
            isConference: Bool
        ) {
            self.callId = callId
            self.callAccessHash = callAccessHash
            self.timestamp = timestamp
            self.peer = peer
            self.isVideo = isVideo
            self.isConference = isConference
        }
    }
    
    final class Impl {
        let queue: Queue
        public let accountPeerId: PeerId
        private let accountManager: AccountManager<TelegramAccountManagerTypes>
        public let postbox: Postbox
        public let network: Network
        private let callSessionManager: CallSessionManager?
        private let shouldKeepOnlinePresence: Signal<Bool, NoError>
        
        let auxiliaryMethods: AccountAuxiliaryMethods
        private let ignoresShortSentMessages: Bool
        
        private var updateService: UpdateMessageService?
        private let updateServiceDisposable = MetaDisposable()
        
        /// The operation queue (Sync/StateOperationQueue.swift), which decides where each operation goes. Only its head
        /// runs, started by `startFirstOperation()`.
        private var operations_ = StateOperationQueue()
        var operations: StateOperationQueue {
            get {
                assert(self.queue.isCurrent())
                return self.operations_
            } set(value) {
                assert(self.queue.isCurrent())
                self.operations_ = value
            }
        }
        var operationTimer: SwiftSignalKit.Timer?
        /// How long a `gapWait` waits (`AccountStateManager.defaultGapWaitTimeout`, unless the manager was built with
        /// another).
        let gapWaitTimeout: Double
        
        /// The asynchronous channel resets of the running poll cycle (ChannelResetCoordinator.swift, state-sync spec
        /// 3.5). Built on first use, which is on the queue like every use, from the constants above and `replayer`;
        /// only this Impl holds it, and it holds this Impl only weakly (`cycleEnded`).
        private lazy var channelResetCoordinator: ChannelResetCoordinator = ChannelResetCoordinator(
            queue: self.queue,
            accountPeerId: self.accountPeerId,
            postbox: self.postbox,
            network: self.network,
            currentValidityMarker: self.currentValidityMarker,
            replayer: self.replayer,
            cycleEnded: { [weak self] events, startsFirstOperation in
                self?.channelResetsEnded(events: events, startsFirstOperation: startsFirstOperation)
            }
        )

        /// differenceTooLong resets in a row in the running poll cycle, for
        /// `AccountStateManager.consecutiveResetDelay`; a poll that needed no reset sets it back to 0.
        var consecutiveResetCount: Int = 0

        /// The differenceTooLong reset of the running poll, its wait on `consecutiveResetDelay` included. Disposed
        /// only in `deinit`: a reset still waiting (up to 60 s) when the account's manager goes is cancelled
        /// instead of resetting a torn-down account's storage. `reset()` leaves it running, because it keeps the
        /// running poll at the head of the queue and only the reset's completion removes that poll.
        let accountResetDisposable = MetaDisposable()

        /// The getDifference chain being logged (DifferenceChainLog.swift); nil between poll cycles.
        var differenceChainLog: DifferenceChainLog?
        
        var removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId] = [:]
        
        private let currentValidityMarker: Int64 = Int64.random(in: Int64.min ... Int64.max)
        
        private var nextId: Int32 = 0
        func getNextId() -> Int32 {
            self.nextId += 1
            return self.nextId
        }
        
        private let isUpdatingValue = ValuePromise<Bool>(true)
        /// Whether a getDifference cycle is running (`isUpdating`). It starts true, is set true when a
        /// `fetchDifference` operation starts, and is set false only in `finishPollCycle`, the cycle's end (spec 3.6).
        var currentIsUpdatingValue = true {
            didSet {
                if self.currentIsUpdatingValue != oldValue {
                    self.isUpdatingValue.set(self.currentIsUpdatingValue)
                }
            }
        }
        public var isUpdating: Signal<Bool, NoError> {
            return self.isUpdatingValue.get()
        }
        
        /// The account's event outputs (state-sync spec 3.4, AccountStateEventHub.swift): the pipes, promises and
        /// subscriber contexts every accessor below forwards to, unchanged, and the fan-out of a `dispatchEvents`
        /// operation. Built in `init` and held only here, so it lives exactly as long as this Impl.
        let eventHub: AccountStateEventHub
        
        public var notificationMessages: Signal<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)], NoError> {
            return self.eventHub.notificationMessages
        }
        
        public var reactionNotifications: Signal<[(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)], NoError> {
            return self.eventHub.reactionNotifications
        }
        
        public var displayAlerts: Signal<[(text: String, isDropAuth: Bool)], NoError> {
            return self.eventHub.displayAlerts
        }
        
        public var dismissBotWebViews: Signal<[Int64], NoError> {
            return self.eventHub.dismissBotWebViews
        }

        public var joinChatWebViewDecisions: Signal<[JoinChatWebViewDecision], NoError> {
            return self.eventHub.joinChatWebViewDecisions
        }
        
        var externallyUpdatedPeerIds: Signal<[PeerId], NoError> {
            return self.eventHub.externallyUpdatedPeerIds
        }
        
        public var termsOfServiceUpdate: Signal<TermsOfServiceUpdate?, NoError> {
            return self.eventHub.termsOfServiceUpdate
        }
        
        public var appUpdateInfo: Signal<AppUpdateInfo?, NoError> {
            return self.eventHub.appUpdateInfo
        }
        
        public var contactBirthdays: Signal<[EnginePeer.Id: TelegramBirthday], NoError> {
            return self.eventHub.contactBirthdays
        }
        
        public var appliedIncomingReadMessages: Signal<[MessageId], NoError> {
            return self.eventHub.appliedIncomingReadMessages
        }
        
        var significantStateUpdateCompleted: Signal<Void, NoError> {
            return self.eventHub.significantStateUpdateCompleted
        }
        
        var authorizationListUpdates: Signal<Void, NoError> {
            return self.eventHub.authorizationListUpdates
        }
        
        var threadReadStateUpdates: Signal<(incoming: [PeerAndBoundThreadId: MessageId.Id], outgoing: [PeerAndBoundThreadId: MessageId.Id]), NoError> {
            return self.eventHub.threadReadStateUpdates
        }
        
        public var groupCallParticipantUpdates: Signal<[(Int64, GroupCallParticipantsContext.Update)], NoError> {
            return self.eventHub.groupCallParticipantUpdates
        }
        
        public var groupCallMessageUpdates: Signal<[GroupCallMessageUpdate], NoError> {
            return self.eventHub.groupCallMessageUpdates
        }
        
        public var deletedMessages: Signal<[DeletedMessageId], NoError> {
            return self.eventHub.deletedMessages
        }
        
        let messagesRemovedContext: MessagesRemovedContext
        let storyReactionContext: StoryReactionContext
        let storyRefreshContext: StoryRefreshContext
        let storyViewRefreshContext: StoryViewRefreshContext

        /// What every replay of this account's final states needs (seam 5, `FinalStateReplayer.applyReplay`). Built
        /// from the constants above, so it is the same value whenever and wherever it is read.
        var replayer: FinalStateReplayer {
            return FinalStateReplayer(accountManager: self.accountManager, postbox: self.postbox, accountPeerId: self.accountPeerId, encryptionProvider: self.network.encryptionProvider, auxiliaryMethods: self.auxiliaryMethods, messagesRemovedContext: self.messagesRemovedContext, storyReactionContext: self.storyReactionContext, storyRefreshContext: self.storyRefreshContext, storyViewRefreshContext: self.storyViewRefreshContext)
        }
        
        fileprivate var storyUpdatesPipe: ValuePipe<[InternalStoryUpdate]> {
            return self.eventHub.storyUpdatesPipe
        }
        public var storyUpdates: Signal<[InternalStoryUpdate], NoError> {
            return self.eventHub.storyUpdates
        }

        fileprivate var walletTransferUpdatesPipe: ValuePipe<[WalletTransferUpdate]> {
            return self.eventHub.walletTransferUpdatesPipe
        }
        fileprivate var walletTonConnectUpdatesPipe: ValuePipe<[WalletTonConnectEvent]> {
            return self.eventHub.walletTonConnectUpdatesPipe
        }

        var walletStateUpdates: Signal<Api.WalletState, NoError> {
            return self.eventHub.walletStateUpdates
        }

        var agentSettingsUpdates: Signal<EngineAgentSettings, NoError> {
            return self.eventHub.agentSettingsUpdates
        }
        
        fileprivate var botPreviewUpdatesPipe: ValuePipe<[InternalBotPreviewUpdate]> {
            return self.eventHub.botPreviewUpdatesPipe
        }
        public var botPreviewUpdates: Signal<[InternalBotPreviewUpdate], NoError> {
            return self.eventHub.botPreviewUpdates
        }
        
        fileprivate var forceSendPendingStarsReactionPipe: ValuePipe<MessageId> {
            return self.eventHub.forceSendPendingStarsReactionPipe
        }
        public var forceSendPendingStarsReaction: Signal<MessageId, NoError> {
            return self.eventHub.forceSendPendingStarsReaction
        }
        
        fileprivate var forceSendPendingPaidMessagePipe: ValuePipe<PeerId> {
            return self.eventHub.forceSendPendingPaidMessagePipe
        }
        public var forceSendPendingPaidMessage: Signal<PeerId, NoError> {
            return self.eventHub.forceSendPendingPaidMessage
        }
        
        fileprivate var commitSendPendingPaidMessagePipe: ValuePipe<MessageId> {
            return self.eventHub.commitSendPendingPaidMessagePipe
        }
        public var commitSendPendingPaidMessage: Signal<MessageId, NoError> {
            return self.eventHub.commitSendPendingPaidMessage
        }
        
        public var sentScheduledMessageIds: Signal<Set<MessageId>, NoError> {
            return self.eventHub.sentScheduledMessageIds
        }
        
        fileprivate var starRefBotConnectionEventsPipe: ValuePipe<StarRefBotConnectionEvent> {
            return self.eventHub.starRefBotConnectionEventsPipe
        }
        public var starRefBotConnectionEvents: Signal<StarRefBotConnectionEvent, NoError> {
            return self.eventHub.starRefBotConnectionEvents
        }
        
        fileprivate var installedStickerPacksArchivedEventsPipe: ValuePipe<Int> {
            return self.eventHub.installedStickerPacksArchivedEventsPipe
        }
        var installedStickerPacksArchivedEvents: Signal<Int, NoError> {
            return self.eventHub.installedStickerPacksArchivedEvents
        }
        
        let appliedQtsPromise = Promise<Int32?>(nil)
        private let appliedQtsDisposable = MetaDisposable()
        
        init(
            queue: Queue,
            gapWaitTimeout: Double,
            accountPeerId: PeerId,
            accountManager: AccountManager<TelegramAccountManagerTypes>,
            postbox: Postbox,
            network: Network,
            callSessionManager: CallSessionManager?,
            shouldKeepOnlinePresence: Signal<Bool, NoError>,
            peerInputActivityManager: PeerInputActivityManager?,
            auxiliaryMethods: AccountAuxiliaryMethods,
            ignoresShortSentMessages: Bool,
            updateConfigRequested: (() -> Void)?,
            isPremiumUpdated: (() -> Void)?,
            messagesRemovedContext: MessagesRemovedContext,
            storyReactionContext: StoryReactionContext,
            storyRefreshContext: StoryRefreshContext,
            storyViewRefreshContext: StoryViewRefreshContext
        ) {
            self.queue = queue
            self.gapWaitTimeout = gapWaitTimeout
            self.accountPeerId = accountPeerId
            self.accountManager = accountManager
            self.postbox = postbox
            self.network = network
            self.callSessionManager = callSessionManager
            self.shouldKeepOnlinePresence = shouldKeepOnlinePresence
            self.auxiliaryMethods = auxiliaryMethods
            self.ignoresShortSentMessages = ignoresShortSentMessages
            self.messagesRemovedContext = messagesRemovedContext
            self.storyReactionContext = storyReactionContext
            self.storyRefreshContext = storyRefreshContext
            self.storyViewRefreshContext = storyViewRefreshContext
            self.eventHub = AccountStateEventHub(
                queue: queue,
                postbox: postbox,
                network: network,
                callSessionManager: callSessionManager,
                peerInputActivityManager: peerInputActivityManager,
                updateConfigRequested: updateConfigRequested,
                isPremiumUpdated: isPremiumUpdated
            )
        }
        
        deinit {
            self.updateServiceDisposable.dispose()
            self.appliedQtsDisposable.dispose()
            self.accountResetDisposable.dispose()
        }
        
        public func reset() {
            self.queue.async { [self] in
                if self.updateService == nil {
                    self.updateService = UpdateMessageService(peerId: self.accountPeerId, ignoresShortSentMessages: self.ignoresShortSentMessages)
                    self.updateServiceDisposable.set(self.updateService!.pipe.signal().start(next: { [weak self] groups in
                        if let strongSelf = self {
                            strongSelf.addUpdateGroups(groups)
                        }
                    }))
                    self.network.addUpdateSink(self.updateService!)
                }
                self.replaceOperations(with: .fetchDifference(self.getNextId(), AccountFinalStateEvents()))
                self.startFirstOperation()
                
                let network = self.network
                self.appliedQtsDisposable.set((combineLatest(queue: self.queue, self.shouldKeepOnlinePresence, self.appliedQtsPromise.get())
                |> mapToSignal { shouldKeepOnlinePresence, value -> Signal<Int32, NoError> in
                    guard let value = value else {
                        return .complete()
                    }
                    if !shouldKeepOnlinePresence {
                        return .complete()
                    }
                    return .single(value)
                }
                |> distinctUntilChanged
                |> mapToSignal { value -> Signal<Never, NoError> in
                    if value == 0 {
                        return .complete()
                    } else {
                        return network.request(Api.functions.messages.receivedQueue(maxQts: value))
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                    }
                }).start())
            }
        }
        
        func addUpdates(_ updates: Api.Updates) {
            self.queue.async {
                self.updateService?.addUpdates(updates)
            }
        }
        
        func addUpdateGroups(_ groups: [UpdateGroup]) {
            self.queue.async {
                if self.operations.absorbUpdateGroups(groups) {
                    self.startFirstOperation()
                } else {
                    self.addOperation(.batchUpdates(groups), position: .last)
                }
            }
        }
        
        func addReplayAsynchronouslyBuiltFinalState(_ finalState: AccountFinalState) -> Signal<Bool, NoError> {
            return Signal { subscriber in
                self.queue.async {
                    self.addOperation(.replayPrebuilt(finalState, {
                        subscriber.putNext(true)
                        subscriber.putCompletion()
                    }), position: .last)
                }
                return EmptyDisposable
            }
        }
        
        func addCustomOperation<T, E>(_ f: Signal<T, E>) -> Signal<T, E> {
            let pipe = ValuePipe<CustomOperationEvent<T, E>>()
            return Signal<T, E> { subscriber in
                let disposable = pipe.signal().start(next: { event in
                    switch event {
                    case let .Next(next):
                        subscriber.putNext(next)
                    case let .Error(error):
                        subscriber.putError(error)
                    case .Completion:
                        subscriber.putCompletion()
                    }
                })
                
                let signal = Signal<Void, NoError> { subscriber in
                    return f.start(next: { next in
                        pipe.putNext(.Next(next))
                    }, error: { error in
                        pipe.putNext(.Error(error))
                        subscriber.putCompletion()
                    }, completed: {
                        pipe.putNext(.Completion)
                        subscriber.putCompletion()
                    })
                }
                
                self.addOperation(.custom(self.getNextId(), signal), position: .last)
                
                return disposable
            } |> runOn(self.queue)
        }
        
        func replaceOperations(with content: StateOperation) {
            self.operations.replace(with: content, nextId: { self.getNextId() })
        }
        
        /// Adds `content` and starts the head when the queue says it must. Every caller runs on `queue`: the ingress
        /// blocks after their hop (`addUpdateGroups`, `addReplayAsynchronouslyBuiltFinalState`, `addCustomOperation`),
        /// `addPollCompletion` and `postponeStateBarrier`, and runner completions that run on the queue (after
        /// `deliverOn(queue)`, in `handleResult`'s hop, or on a queue timer). The direct call keeps the order a slice
        /// continuation and a reset follow-up depend on: their next attempt is queued first and started before update
        /// groups whose ingress block is already waiting on the queue.
        func addOperation(_ content: StateOperation, position: StateOperationQueue.Position) {
            assert(self.queue.isCurrent())
            if self.operations.add(content, at: position) {
                self.startFirstOperation()
            }
        }
        
        private func addAsyncResetChannels(peers: [(peer: Peer, pts: Int32?)]) {
            //TODO:pts
            guard let operation = self.operations.first, case .fetchDifference = operation.content else {
                assertionFailure("Invalid state")
                return
            }
            self.channelResetCoordinator.addAsyncResetChannels(peers: peers)
        }
        
        /// The end of a poll cycle whose difference chain ended into pending channel resets
        /// (`ChannelResetCoordinator.cycleEnded`), after the coordinator dropped its context: `events` (the cycle's,
        /// with the resets' replay merged in; nil when the replay returned nothing) end the cycle through
        /// `finishPollCycle`, which finds no context and so queues them, clears isUpdating and fires
        /// significantStateUpdateCompleted. After an asynchronous replay nothing else starts the queue, which may be
        /// idle (Q12), so `startFirstOperation` is true; a context with nothing to replay ends inside the
        /// `finishPollCycle` that handed it the chain's events, whose caller starts the queue.
        private func channelResetsEnded(events: AccountFinalStateEvents?, startsFirstOperation: Bool) {
            self.finishPollCycle(events: events ?? AccountFinalStateEvents())
            if startsFirstOperation {
                self.startFirstOperation()
            }
        }
        
        /// Ends a getDifference cycle, however its chain ended, and is the only place isUpdating goes false (spec 3.6).
        /// A pending channel-reset context takes the events (`ChannelResetCoordinator.endDifferenceChain`); once its
        /// resets are done (replayed, or none were asked for) the coordinator drops it and the cycle ends here after
        /// all (`channelResetsEnded`). Without a context the events are queued, isUpdating goes false and
        /// significantStateUpdateCompleted fires.
        func finishPollCycle(events: AccountFinalStateEvents) {
            if !self.channelResetCoordinator.endDifferenceChain(events: events) {
                if !events.isEmpty {
                    self.insertDispatchEvents(events)
                }
                self.currentIsUpdatingValue = false
                self.eventHub.notifySignificantStateUpdateCompleted()
            }
        }
        
        /// Takes the running poll off the head of the queue once an attempt ended without a differenceTooLong reset,
        /// so the next differenceTooLong is a first one again (`consecutiveResetCount`). Returns false when the head
        /// was not a poll (the count is reset all the same); the caller then acts on nothing it popped, as every
        /// completion does on such a mismatch.
        func removeFinishedPoll() -> Bool {
            self.consecutiveResetCount = 0
            return self.operations.popFetchDifference()
        }
        
        /// Starts the operation at the head of the queue unless it is running already: the one place an operation
        /// starts. Each kind runs in its own `run<Kind>` (AccountStateManager+<Kind>.swift), and every run ends the
        /// same way, on the queue: it takes the operation off the head and checks that it is the one that ran (on a
        /// mismatch it starts nothing, and most kinds assert), does what the outcome asks, and calls this again for the
        /// next one. The state barrier's first step does so at once; every other run ends in the completion of what it
        /// waits for. Two runs differ: a barrier with entries behind it steps aside without a check
        /// (`barrierStepsAside`), and `runReplayPrebuilt` calls `completion()` after a mismatch too.
        func startFirstOperation() {
            guard let operation = self.operations.startHead() else {
                return
            }
            switch operation.content {
            case let .fetchDifference(_, currentEvents):
                self.runFetchDifference(currentEvents: currentEvents)
            case .batchUpdates:
                self.runBatchUpdates()
            case .gapWait:
                self.runGapWait()
            case let .processBatch(groups):
                self.runProcessBatch(groups: groups)
            case let .custom(operationId, signal):
                self.runCustom(operationId: operationId, signal: signal)
            case let .dispatchEvents(operationId, events):
                self.runDispatchEvents(operationId: operationId, events: events)
            case let .stateBarrier(pollId, preMessageIds, preSubscribers):
                self.runStateBarrier(pollId: pollId, preMessageIds: preMessageIds, preSubscribers: preSubscribers)
            case let .replayPrebuilt(finalState, completion):
                self.runReplayPrebuilt(finalState: finalState, completion: completion)
            }
        }
        
        func standaloneReplayAsynchronouslyBuiltFinalState(finalState: AccountFinalState) -> Signal<Never, NoError> {
            if !finalState.state.preCachedResources.isEmpty {
                for (resource, data) in finalState.state.preCachedResources {
                    self.postbox.mediaBox.storeResourceData(resource.id, data: data)
                }
            }
            
            let replayer = self.replayer
            let removePossiblyDeliveredMessagesUniqueIds = self.removePossiblyDeliveredMessagesUniqueIds
            
            let signal = self.postbox.transaction { transaction -> AccountReplayedFinalState? in
                return replayer.applyReplay(finalState, policy: .verified, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, transaction: transaction)
            }
            |> deliverOn(self.queue)
            
            return signal
            |> ignoreValues
        }
        
        /// One getDifference attempt for either poller (spec 3.3; `DifferencePolicy` lists what differs): reads the
        /// stored state, requests the difference from it and replays the answer (`applyDifferenceAnswer`), to one
        /// `DifferenceOutcome`. The stored state and the request are built per policy because their Signal shapes
        /// differ: the app reads its state in one transaction and hops to `queue`, and its `pts_total_limit` is fixed
        /// for the attempt; the extension reads `stateView` once without a hop, and reads the limit again before every
        /// try of the request. The caller delivers the outcome and makes its own hop to `queue` for it (Q13). Called
        /// on `queue`; nothing runs until the returned signal is started.
        func fetchAndApplyDifference(policy: DifferencePolicy) -> Signal<DifferenceOutcome, NoError> {
            let queue = self.queue
            let postbox = self.postbox
            let network = self.network
            let accountPeerId = self.accountPeerId
            let replayer = self.replayer

            switch policy {
            case .mainApp:
                let currentValidityMarker = self.currentValidityMarker

                // The pts_total_limit this poll sends (audit Q14). The state transaction below reads it beside the
                // other app-configuration switches, and the getDifference request it starts sends it.
                let ptsTotalLimitBox = Atomic<Int32?>(value: nil)

                return postbox.transaction { transaction -> (AuthorizedAccountState?, [(peer: Peer, pts: Int32?)], Bool) in
                    let state = transaction.getState() as? AuthorizedAccountState

                    var disableParallelChannelReset = false
                    if let appConfig = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self), let data = appConfig.data {
                        if let _ = data["ios_disable_parallel_channel_reset_v2"] {
                            disableParallelChannelReset = true
                        }
                    }

                    let _ = ptsTotalLimitBox.swap(currentPtsTotalLimit(transaction: transaction))

                    var invalidatedChannels: [(peer: Peer, pts: Int32?)] = []
                    if let state = state, !disableParallelChannelReset {
                        for record in state.invalidatedChannels {
                            if record.validityMarker != currentValidityMarker {
                                if let peer = transaction.getPeer(record.peerId) {
                                    invalidatedChannels.append((peer, record.pts))
                                }
                            }
                        }
                    }

                    return (state, invalidatedChannels, disableParallelChannelReset)
                }
                |> deliverOn(self.queue)
                |> mapToSignal { [weak self] state, invalidatedChannels, disableParallelChannelReset -> Signal<DifferenceOutcome, NoError> in
                    if let state = state, let authorizedState = state.state {
                        // pts_total_limit (audit Q14) goes with every getDifference, slices included: a gap larger than the
                        // limit answers differenceTooLong on the first call (`requestDifference` sends it with flags.0).
                        let ptsTotalLimit: Int32? = ptsTotalLimitBox.with { $0 }

                        if let strongSelf = self {
                            if strongSelf.differenceChainLog == nil {
                                strongSelf.differenceChainLog = DifferenceChainLog(startPts: authorizedState.pts, startTime: CFAbsoluteTimeGetCurrent())
                            }
                            strongSelf.differenceChainLog?.noteRequest(pts: authorizedState.pts)
                            if !invalidatedChannels.isEmpty {
                                strongSelf.addAsyncResetChannels(peers: invalidatedChannels)
                            }
                        }
                        // The wall time of this request, for the State log.
                        let requestStartTime = CFAbsoluteTimeGetCurrent()

                        let request = retryingDifferenceRequest(requestDifference(network: network, from: authorizedState, ptsTotalLimit: ptsTotalLimit, policy: policy))

                        return request
                        |> mapToSignal { answer -> Signal<DifferenceOutcome, NoError> in
                            if let difference = answer {
                                logDifferenceAnswer(difference, requestPts: authorizedState.pts, requestStartTime: requestStartTime)
                            }
                            return applyDifferenceAnswer(answer, requestedFrom: authorizedState, policy: policy, accountPeerId: accountPeerId, postbox: postbox, network: network, queue: queue, replayer: replayer, asyncResetChannels: disableParallelChannelReset ? nil : { peers in
                                queue.async {
                                    self?.addAsyncResetChannels(peers: peers)
                                }
                            }, possiblyDeliveredMessagesUniqueIds: {
                                return self?.removePossiblyDeliveredMessagesUniqueIds ?? Dictionary()
                            })
                        }
                    } else {
                        let appliedState = network.request(Api.functions.updates.getState())
                        |> retryRequest
                        |> mapToSignal { state in
                            return postbox.transaction { transaction -> DifferenceOutcome in
                                if let currentState = transaction.getState() as? AuthorizedAccountState {
                                    switch state {
                                    case let .state(stateData):
                                        let (pts, qts, date, seq) = (stateData.pts, stateData.qts, stateData.date, stateData.seq)
                                        transaction.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq)))
                                    }
                                }
                                return .noInnerState
                            }
                        }
                        return appliedState
                    }
                }
            case .notificationExtension:
                return postbox.stateView()
                |> mapToSignal { view -> Signal<AuthorizedAccountState, NoError> in
                    if let state = view.state as? AuthorizedAccountState {
                        return .single(state)
                    } else {
                        return .complete()
                    }
                }
                |> take(1)
                |> mapToSignal { [weak self] state -> Signal<DifferenceOutcome, NoError> in
                    if let authorizedState = state.state {
                        // pts_total_limit (audit Q14): the value the app sends, read before each request. A gap larger than the
                        // limit answers differenceTooLong, which the extension leaves to the app (Q3).
                        let request = retryingDifferenceRequest(postbox.transaction { transaction -> Int32? in
                            return currentPtsTotalLimit(transaction: transaction)
                        }
                        |> castError(MTRpcError.self)
                        |> mapToSignal { ptsTotalLimit -> Signal<Api.updates.Difference, MTRpcError> in
                            return requestDifference(network: network, from: authorizedState, ptsTotalLimit: ptsTotalLimit, policy: policy)
                        })

                        return request
                        |> mapToSignal { answer -> Signal<DifferenceOutcome, NoError> in
                            if let difference = answer, case .differenceTooLong = difference {
                                // Q3: the extension leaves the account reset to the app, whose next poll gets
                                // this answer again because nothing here changes the stored state. Reported as
                                // done, so the extension goes on with the push's own content instead of asking
                                // again until its time budget runs out.
                                Logger.shared.log("State", "standalonePollDifference: differenceTooLong, leaving the reset to the app")
                            }
                            return applyDifferenceAnswer(answer, requestedFrom: authorizedState, policy: policy, accountPeerId: accountPeerId, postbox: postbox, network: network, queue: queue, replayer: replayer, asyncResetChannels: nil, possiblyDeliveredMessagesUniqueIds: {
                                return self?.removePossiblyDeliveredMessagesUniqueIds ?? Dictionary()
                            })
                        }
                    } else {
                        // No inner state: the extension does not bootstrap it (the app's poll does) and reports done.
                        return .single(.noInnerState)
                    }
                }
            }
        }

        public func standalonePollDifference() -> Signal<Bool, NoError> {
            let queue = self.queue

            return self.fetchAndApplyDifference(policy: .notificationExtension)
            |> mapToSignal { outcome -> Signal<Bool, NoError> in
                // Done, except after an applied slice: the extension then asks again for the rest of the chain. A
                // differenceTooLong is done here too (Q3).
                let result: Bool
                switch outcome {
                case .applied(_, isSlice: true):
                    result = false
                case .applied(_, isSlice: false), .tooLong, .authKeyDuplicated, .stateChangedMeanwhile, .replayRejected, .noInnerState:
                    result = true
                }
                // Q13: the hop to `queue` is made here, inside the last inner signal, with the value and
                // the completion in one block. A `deliverOn(queue)` in front of this mapToSignal could
                // lose the value: after a replay, the chain can complete inline on `queue` (through the
                // `deliverOn(queue)` after `finalStateWithDifference`) while the result, dispatched there
                // from the Postbox thread, is still waiting, and the completed subscriber drops it; the
                // extension then stops paging a differenceSlice early. Here the outer completion cannot
                // end the signal first, because mapToSignal waits for this inner signal to complete.
                return Signal { subscriber in
                    queue.async {
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
            }
        }
        
        func insertDispatchEvents(_ events: AccountFinalStateEvents) {
            if !events.isEmpty {
                self.operations.insertEvents(id: self.getNextId(), events: events)
            }
        }
        
        func postponeStateBarrier(messageIds: [MessageId], subscribers: [(Int32, ([MessageId]) -> Void)]) {
            self.addOperation(.stateBarrier(self.getNextId(), messageIds, subscribers), position: .last)
            self.operations.assertBarrierIsLast()
        }
        
        private func addPollCompletion(_ f: @escaping ([MessageId]) -> Void) -> Int32 {
            assert(self.queue.isCurrent())
            
            let updatedId: Int32 = self.getNextId()
            
            if self.operations.addBarrierSubscriber(id: updatedId, f) {
                return updatedId
            }
            
            self.addOperation(.stateBarrier(self.getNextId(), [], [(updatedId, f)]), position: .last)
            
            return updatedId
        }
        
        private func removePollCompletion(_ id: Int32) {
            self.operations.removeBarrierSubscriber(id: id)
        }
        
        public func pollStateUpdateCompletion() -> Signal<[MessageId], NoError> {
            return Signal { [weak self] subscriber in
                let disposable = MetaDisposable()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        let id = strongSelf.addPollCompletion({ messageIds in
                            subscriber.putNext(messageIds)
                            subscriber.putCompletion()
                        })
                        
                        disposable.set(ActionDisposable {
                            if let strongSelf = self {
                                strongSelf.queue.async {
                                    strongSelf.removePollCompletion(id)
                                }
                            }
                        })
                    }
                }
                return disposable
            }
        }
        
        public func updatedWebpage(_ webpageId: MediaId) -> Signal<TelegramMediaWebpage?, NoError> {
            return self.eventHub.updatedWebpage(webpageId)
        }
        
        func notifyAppliedIncomingReadMessages(_ ids: [MessageId]) {
            self.eventHub.notifyAppliedIncomingReadMessages(ids)
        }
        
        func modifyTermsOfServiceUpdate(_ f: @escaping (TermsOfServiceUpdate?) -> (TermsOfServiceUpdate?)) {
            self.eventHub.modifyTermsOfServiceUpdate(f)
        }
        
        func modifyAppUpdateInfo(_ f: @escaping (AppUpdateInfo?) -> (AppUpdateInfo?)) {
            self.eventHub.modifyAppUpdateInfo(f)
        }
        
        func modifyContactBirthdays(_ f: @escaping ([EnginePeer.Id: TelegramBirthday]) -> ([EnginePeer.Id: TelegramBirthday])) {
            self.eventHub.modifyContactBirthdays(f)
        }
                
        public func updatedStarsBalance() -> Signal<[PeerId: StarsAmount], NoError> {
            return self.eventHub.updatedStarsBalance()
        }
                
        public func updatedTonBalance() -> Signal<[PeerId: StarsAmount], NoError> {
            return self.eventHub.updatedTonBalance()
        }
        
        public func updatedStarsRevenueStatus() -> Signal<[PeerId: StarsRevenueStats.Balances], NoError> {
            return self.eventHub.updatedStarsRevenueStatus()
        }
        
        public func updatedStarGiftAuctionState() -> Signal<[Int64: GiftAuctionContext.State.AuctionState], NoError> {
            return self.eventHub.updatedStarGiftAuctionState()
        }
        
        public func updatedStarGiftAuctionMyState() -> Signal<[Int64: GiftAuctionContext.State.MyState], NoError> {
            return self.eventHub.updatedStarGiftAuctionMyState()
        }
                
        func notifyDeletedMessages(messageIds: [MessageId]) {
            self.eventHub.notifyDeletedMessages(messageIds: messageIds)
        }

        func notifyConfirmedDeletions(_ ids: [DeletedMessageId]) {
            self.eventHub.notifyConfirmedDeletions(ids)
        }
        
        public func processIncomingCallUpdate(data: Data, completion: @escaping ((CallSessionRingingState, CallSession)?) -> Void) {
            var rawData = data
            let reader = BufferReader(Buffer(data: data))
            if let signature = reader.readInt32(), signature == 0x3072cfa1 {
                if let compressedData = parseBytes(reader) {
                    if let decompressedData = MTGzip.decompress(compressedData.makeData()) {
                        rawData = decompressedData
                    }
                }
            }
            
            if let updates = Api.parse(Buffer(data: rawData)) as? Api.Updates {
                switch updates {
                case let .updates(updatesData):
                    let updates = updatesData.updates
                    for update in updates {
                        switch update {
                        case let .updatePhoneCall(updatePhoneCallData):
                            let phoneCall = updatePhoneCallData.phoneCall
                            if let callSessionManager = self.callSessionManager {
                                callSessionManager.updateSession(phoneCall, completion: { result in
                                    completion(result)
                                })
                            } else {
                                completion(nil)
                            }
                            return
                        default:
                            break
                        }
                    }
                default:
                    break
                }
            }
            completion(nil)
        }
        
        func removePossiblyDeliveredMessages(uniqueIds: [Int64: PeerId]) {
            self.queue.async {
                self.removePossiblyDeliveredMessagesUniqueIds.merge(uniqueIds, uniquingKeysWith: { _, rhs in rhs })
            }
        }
        
        func addStarRefBotConnectionEvent(event: StarRefBotConnectionEvent) {
            self.eventHub.addStarRefBotConnectionEvent(event: event)
        }
    }
    
    private let impl: QueueLocalObject<Impl>
    
    public let accountPeerId: PeerId
    public let postbox: Postbox
    public let network: Network
    let auxiliaryMethods: AccountAuxiliaryMethods
    
    public var isUpdating: Signal<Bool, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.isUpdating.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var notificationMessages: Signal<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.notificationMessages.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var reactionNotifications: Signal<[(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.reactionNotifications.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var displayAlerts: Signal<[(text: String, isDropAuth: Bool)], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.displayAlerts.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var dismissBotWebViews: Signal<[Int64], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.dismissBotWebViews.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var joinChatWebViewDecisions: Signal<[JoinChatWebViewDecision], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.joinChatWebViewDecisions.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }

    var externallyUpdatedPeerIds: Signal<[PeerId], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.externallyUpdatedPeerIds.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var termsOfServiceUpdate: Signal<TermsOfServiceUpdate?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.termsOfServiceUpdate.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var appUpdateInfo: Signal<AppUpdateInfo?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.appUpdateInfo.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var contactBirthdays: Signal<[EnginePeer.Id: TelegramBirthday], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.contactBirthdays.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var appliedIncomingReadMessages: Signal<[MessageId], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.appliedIncomingReadMessages.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    var significantStateUpdateCompleted: Signal<Void, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.significantStateUpdateCompleted.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    var authorizationListUpdates: Signal<Void, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.authorizationListUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    var threadReadStateUpdates: Signal<(incoming: [PeerAndBoundThreadId: MessageId.Id], outgoing: [PeerAndBoundThreadId: MessageId.Id]), NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.threadReadStateUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var groupCallParticipantUpdates: Signal<[(Int64, GroupCallParticipantsContext.Update)], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.groupCallParticipantUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    var groupCallMessageUpdates: Signal<[GroupCallMessageUpdate], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.groupCallMessageUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var deletedMessages: Signal<[DeletedMessageId], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.deletedMessages.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    var storyUpdates: Signal<[InternalStoryUpdate], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.storyUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func injectStoryUpdates(updates: [InternalStoryUpdate]) {
        self.impl.with { impl in
            impl.storyUpdatesPipe.putNext(updates)
        }
    }
    
    public var installedStickerPacksArchivedEvents: Signal<Int, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.installedStickerPacksArchivedEvents.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func installedStickerPacksArchived(count: Int) {
        self.impl.with { impl in
            impl.installedStickerPacksArchivedEventsPipe.putNext(count)
        }
    }
    
    var botPreviewUpdates: Signal<[InternalBotPreviewUpdate], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.botPreviewUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func injectBotPreviewUpdates(updates: [InternalBotPreviewUpdate]) {
        self.impl.with { impl in
            impl.botPreviewUpdatesPipe.putNext(updates)
        }
    }
    
    var forceSendPendingStarsReaction: Signal<MessageId, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.forceSendPendingStarsReaction.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    var forceSendPendingPaidMessage: Signal<PeerId, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.forceSendPendingPaidMessage.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    var commitSendPendingPaidMessage: Signal<MessageId, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.commitSendPendingPaidMessage.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public var sentScheduledMessageIds: Signal<Set<MessageId>, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.sentScheduledMessageIds.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func forceSendPendingStarsReaction(messageId: MessageId) {
        self.impl.with { impl in
            impl.forceSendPendingStarsReactionPipe.putNext(messageId)
        }
    }
    
    
    func forceSendPendingPaidMessage(peerId: PeerId) {
        self.impl.with { impl in
            impl.forceSendPendingPaidMessagePipe.putNext(peerId)
        }
    }
    
    func commitSendPendingPaidMessage(messageId: MessageId) {
        self.impl.with { impl in
            impl.commitSendPendingPaidMessagePipe.putNext(messageId)
        }
    }
    
    var updateConfigRequested: (() -> Void)?
    var isPremiumUpdated: (() -> Void)?
    
    let messagesRemovedContext = MessagesRemovedContext()
    let storyReactionContext = StoryReactionContext()
    let storyRefreshContext = StoryRefreshContext()
    let storyViewRefreshContext = StoryViewRefreshContext()

    /// This manager's registration with `StoredMessageConfirmationDeletionReporters` (owner decision D1),
    /// disposed in `deinit`.
    private var storedMessageConfirmationDeletionsRegistration: Disposable?
    
    public weak var starsContext: StarsContext?
    public weak var tonContext: StarsContext?
    
    init(
        accountPeerId: PeerId,
        accountManager: AccountManager<TelegramAccountManagerTypes>,
        postbox: Postbox,
        network: Network,
        callSessionManager: CallSessionManager?,
        shouldKeepOnlinePresence: Signal<Bool, NoError>,
        peerInputActivityManager: PeerInputActivityManager?,
        auxiliaryMethods: AccountAuxiliaryMethods,
        ignoresShortSentMessages: Bool,
        gapWaitTimeout: Double = AccountStateManager.defaultGapWaitTimeout
    ) {
        let queue = Queue(name: "AccountStateManager")
        
        self.accountPeerId = accountPeerId
        self.postbox = postbox
        self.network = network
        self.auxiliaryMethods = auxiliaryMethods
        
        let messagesRemovedContext = self.messagesRemovedContext
        let storyReactionContext = self.storyReactionContext
        let storyRefreshContext = self.storyRefreshContext
        let storyViewRefreshContext = self.storyViewRefreshContext
        
        var updateConfigRequestedImpl: (() -> Void)?
        var isPremiumUpdatedImpl: (() -> Void)?
        
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(
                queue: queue,
                gapWaitTimeout: gapWaitTimeout,
                accountPeerId: accountPeerId,
                accountManager: accountManager,
                postbox: postbox,
                network: network,
                callSessionManager: callSessionManager,
                shouldKeepOnlinePresence: shouldKeepOnlinePresence,
                peerInputActivityManager: peerInputActivityManager,
                auxiliaryMethods: auxiliaryMethods,
                ignoresShortSentMessages: ignoresShortSentMessages,
                updateConfigRequested: {
                    updateConfigRequestedImpl?()
                },
                isPremiumUpdated: {
                    isPremiumUpdatedImpl?()
                },
                messagesRemovedContext: messagesRemovedContext,
                storyReactionContext: storyReactionContext,
                storyRefreshContext: storyRefreshContext,
                storyViewRefreshContext: storyViewRefreshContext
            )
        })
        
        updateConfigRequestedImpl = { [weak self] in
            self?.updateConfigRequested?()
        }
        isPremiumUpdatedImpl = { [weak self] in
            self?.isPremiumUpdated?()
        }

        // Owner decision D1: the messages a stored-message confirmation of this account deletes fire this manager's
        // deletion events. Every confirmation is applied with the account Postbox's media box.
        self.storedMessageConfirmationDeletionsRegistration = StoredMessageConfirmationDeletionReporters.shared.register(mediaBox: postbox.mediaBox, report: { [weak self] ids, transaction in
            self?.noteStoredMessageConfirmationDeletions(ids, transaction: transaction)
        })
    }

    deinit {
        self.storedMessageConfirmationDeletionsRegistration?.dispose()
    }
    
    func reset() {
        self.impl.with { impl in
            impl.reset()
        }
    }
    
    func addUpdates(_ updates: Api.Updates) {
        self.impl.with { impl in
            impl.addUpdates(updates)
        }
    }
    
    func addUpdateGroups(_ groups: [UpdateGroup]) {
        self.impl.with { impl in
            impl.addUpdateGroups(groups)
        }
    }
    
    func addReplayAsynchronouslyBuiltFinalState(_ finalState: AccountFinalState) -> Signal<Bool, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.addReplayAsynchronouslyBuiltFinalState(finalState).start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func standaloneReplayAsynchronouslyBuiltFinalState(finalState: AccountFinalState) -> Signal<Never, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.standaloneReplayAsynchronouslyBuiltFinalState(finalState: finalState).start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func notifyAppliedIncomingReadMessages(_ ids: [MessageId]) {
        self.impl.with { impl in
            impl.notifyAppliedIncomingReadMessages(ids)
        }
    }
    
    func modifyAppUpdateInfo(_ f: @escaping (AppUpdateInfo?) -> (AppUpdateInfo?)) {
        self.impl.with { impl in
            impl.modifyAppUpdateInfo(f)
        }
    }
    
    func modifyContactBirthdays(_ f: @escaping ([EnginePeer.Id: TelegramBirthday]) -> ([EnginePeer.Id: TelegramBirthday])) {
        self.impl.with { impl in
            impl.modifyContactBirthdays(f)
        }
    }
    
    public func pollStateUpdateCompletion() -> Signal<[MessageId], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.pollStateUpdateCompletion().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func notifyDeletedMessages(messageIds: [MessageId]) {
        self.impl.with { impl in
            impl.notifyDeletedMessages(messageIds: messageIds)
        }
    }

    /// Owner decision D1: messages `deleteStoredMessagesAsReceivedDeletion` deleted (the account reset's ghost tail,
    /// what a history fill's confirmation found missing) fire the events a received deletion fires, under the names
    /// the replay gives its deletions (`DeletedMessageId(receivedDeletionOf:)`).
    /// `messagesRemovedContext` gets them at once, inside the deleting `transaction`, as the replay adds its
    /// deletions inside its own, so a history view updated by that transaction already finds them there.
    /// `deletedMessages` gets them once that transaction has committed (`afterCommit`), from this manager's queue,
    /// so no receiver hears of a deletion it cannot read yet; a fill is not part of a poll cycle whose events they
    /// could join. Called on the Postbox queue.
    private func noteStoredMessageConfirmationDeletions(_ ids: [MessageId], transaction: Transaction) {
        let deletedIds = ids.map(DeletedMessageId.init(receivedDeletionOf:))
        self.messagesRemovedContext.addIsMessagesDeletedInteractively(ids: deletedIds)
        self.messagesRemovedContext.addIsMessagesDeletedRemotely(ids: deletedIds)
        let impl = self.impl
        transaction.afterCommit {
            impl.with { impl in
                impl.notifyConfirmedDeletions(deletedIds)
            }
        }
    }
    
    func removePossiblyDeliveredMessages(uniqueIds: [Int64: PeerId]) {
        self.impl.with { impl in
            impl.removePossiblyDeliveredMessages(uniqueIds: uniqueIds)
        }
    }
    
    public func updatedStarsBalance() -> Signal<[PeerId: StarsAmount], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.updatedStarsBalance().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public func updatedTonBalance() -> Signal<[PeerId: StarsAmount], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.updatedTonBalance().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }

    func walletTransferUpdates() -> Signal<[WalletTransferUpdate], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.walletTransferUpdatesPipe.signal().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }

    func walletTonConnectUpdates() -> Signal<[WalletTonConnectEvent], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.walletTonConnectUpdatesPipe.signal().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }

    func walletStateUpdates() -> Signal<Api.WalletState, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.walletStateUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }

    func agentSettingsUpdates() -> Signal<EngineAgentSettings, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.agentSettingsUpdates.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public func updatedStarsRevenueStatus() -> Signal<[PeerId: StarsRevenueStats.Balances], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.updatedStarsRevenueStatus().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public func updatedStarGiftAuctionState() -> Signal<[Int64: GiftAuctionContext.State.AuctionState], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.updatedStarGiftAuctionState().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public func updatedStarGiftAuctionMyState() -> Signal<[Int64: GiftAuctionContext.State.MyState], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.updatedStarGiftAuctionMyState().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func addCustomOperation<T, E>(_ f: Signal<T, E>) -> Signal<T, E> {
        return self.impl.signalWith { impl, subscriber in
            return impl.addCustomOperation(f).start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    func modifyTermsOfServiceUpdate(_ f: @escaping (TermsOfServiceUpdate?) -> (TermsOfServiceUpdate?)) {
        self.impl.with { impl in
            impl.modifyTermsOfServiceUpdate(f)
        }
    }
    
    /// The web page's states as they arrive from the update stream; nil when the server resolved
    /// it to `webPageEmpty`, i.e. no preview exists for its URL.
    public func updatedWebpage(_ webpageId: MediaId) -> Signal<TelegramMediaWebpage?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.updatedWebpage(webpageId).start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public func processIncomingCallUpdate(data: Data, completion: @escaping ((CallSessionRingingState, CallSession)?) -> Void) {
        self.impl.with { impl in
            impl.processIncomingCallUpdate(data: data, completion: completion)
        }
    }
    
    public func standalonePollDifference() -> Signal<Bool, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.standalonePollDifference().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }
    
    public static func extractIncomingCallUpdate(data: Data) -> IncomingCallUpdate? {
        var rawData = data
        let reader = BufferReader(Buffer(data: data))
        if let signature = reader.readInt32(), signature == 0x3072cfa1 {
            if let compressedData = parseBytes(reader) {
                if let decompressedData = MTGzip.decompress(compressedData.makeData()) {
                    rawData = decompressedData
                }
            }
        }
        
        guard let updates = Api.parse(Buffer(data: rawData)) as? Api.Updates else {
            return nil
        }
        switch updates {
        case let .updates(updatesData):
            let (updates, users) = (updatesData.updates, updatesData.users)
            var peers: [Peer] = []
            for user in users {
                peers.append(TelegramUser(user: user))
            }

            for update in updates {
                switch update {
                case let .updatePhoneCall(updatePhoneCallData):
                    let phoneCall = updatePhoneCallData.phoneCall
                    switch phoneCall {
                    case let .phoneCallRequested(phoneCallRequestedData):
                        let (flags, id, accessHash, date, adminId) = (phoneCallRequestedData.flags, phoneCallRequestedData.id, phoneCallRequestedData.accessHash, phoneCallRequestedData.date, phoneCallRequestedData.adminId)
                        guard let peer = peers.first(where: { $0.id == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(adminId)) }) else {
                            return nil
                        }
                        return IncomingCallUpdate(
                            callId: id,
                            callAccessHash: accessHash,
                            timestamp: date,
                            peer: EnginePeer(peer),
                            isVideo: (flags & (1 << 6)) != 0,
                            isConference: false
                        )
                    default:
                        break
                    }
                default:
                    break
                }
            }
            
            return nil
        default:
            return nil
        }
    }
    
    public func synchronouslyIsMessageDeletedInteractively(ids: [EngineMessage.Id]) -> [EngineMessage.Id] {
        return self.messagesRemovedContext.synchronouslyIsMessageDeletedInteractively(ids: ids)
    }
    
    public func synchronouslyIsMessageDeletedRemotely(ids: [EngineMessage.Id]) -> [EngineMessage.Id] {
        return self.messagesRemovedContext.synchronouslyIsMessageDeletedRemotely(ids: ids)
    }
    
    func starRefBotConnectionEvents() -> Signal<StarRefBotConnectionEvent, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.starRefBotConnectionEventsPipe.signal().start(next: subscriber.putNext)
        }
    }
    
    func addStarRefBotConnectionEvent(event: StarRefBotConnectionEvent) {
        self.impl.with { impl in
            impl.addStarRefBotConnectionEvent(event: event)
        }
    }
}

func resolveNotificationSettings(list: [TelegramPeerNotificationSettings], defaultSettings: MessageNotificationSettings) -> (sound: PeerMessageSound, notify: Bool, displayContents: Bool) {
    var sound: PeerMessageSound = defaultSettings.sound
    
    var notify = defaultSettings.enabled
    var displayContents = defaultSettings.displayPreviews
    
    for item in list.reversed() {
        if case .default = item.messageSound {
        } else {
            sound = item.messageSound
        }
        
        switch item.displayPreviews {
        case .default:
            break
        case .show:
            displayContents = true
        case .hide:
            displayContents = false
        }
        
        switch item.muteState {
        case .default:
            break
        case .unmuted:
            notify = true
        case let .muted(deadline):
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            if deadline > timestamp {
                notify = false
            } else {
                notify = true
            }
        }
    }
    
    if case .default = sound {
        sound = defaultCloudPeerNotificationSound
    }
    
    return (sound, notify, displayContents)
}

public func messagesForNotification(transaction: Transaction, id: MessageId, alwaysReturnMessage: Bool) -> (messages: [Message], notify: Bool, sound: PeerMessageSound, displayContents: Bool, threadData: MessageHistoryThreadData?) {
    if id.namespace == Namespaces.Message.EphemeralLocal || Namespaces.Message.allWelcomeMessages.contains(id.namespace) {
        return ([], false, defaultCloudPeerNotificationSound, false, nil)
    }

    guard let message = transaction.getMessage(id) else {
        Logger.shared.log("AccountStateManager", "notification message doesn't exist")
        return ([], false, defaultCloudPeerNotificationSound, false, nil)
    }

    var notify = true
    var muted = false
    var displayContents = true
    var threadData: MessageHistoryThreadData?
    
    for attribute in message.attributes {
        if let attribute = attribute as? NotificationInfoMessageAttribute {
            if attribute.flags.contains(.muted) {
                muted = true
            }
        }
        if let attribute = attribute as? ReplyMessageAttribute {
            if let threadId = attribute.threadMessageId {
                threadData = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: Int64(threadId.id))?.data.get(MessageHistoryThreadData.self)
            }
        }
    }
    if threadData == nil, let threadId = message.threadId {
        threadData = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self)
    }
    
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            switch action.action {
                case .groupMigratedToChannel, .channelMigratedFromGroup:
                    notify = false
                default:
                    break
            }
        }
    }
    
    var notificationPeerId = id.peerId
    let peer = transaction.getPeer(id.peerId)
    if let peer, peer is TelegramSecretChat, let associatedPeerId = peer.associatedPeerId {
        notificationPeerId = associatedPeerId
    }
    if message.personal, let author = message.author {
        notificationPeerId = author.id
    }
    
    var notificationSettingsStack: [TelegramPeerNotificationSettings] = []
    
    if let peer = peer as? TelegramChannel, peer.isMonoForum {
    } else if let threadId = message.threadId, let threadData = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
        notificationSettingsStack.append(threadData.notificationSettings)
    }
    
    if let notificationSettings = transaction.getPeerNotificationSettings(id: notificationPeerId) as? TelegramPeerNotificationSettings {
        notificationSettingsStack.append(notificationSettings)
    }
    
    let globalNotificationSettings = transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications)?.get(GlobalNotificationSettings.self) ?? GlobalNotificationSettings.defaultSettings
    
    let defaultNotificationSettings: MessageNotificationSettings
    if id.peerId.namespace == Namespaces.Peer.CloudUser {
        defaultNotificationSettings = globalNotificationSettings.effective.privateChats
    } else if id.peerId.namespace == Namespaces.Peer.SecretChat {
        defaultNotificationSettings = globalNotificationSettings.effective.privateChats
        displayContents = false
    } else if id.peerId.namespace == Namespaces.Peer.CloudChannel, let peer = peer as? TelegramChannel, case .broadcast = peer.info {
        defaultNotificationSettings = globalNotificationSettings.effective.channels
    } else {
        defaultNotificationSettings = globalNotificationSettings.effective.groupChats
    }
    
    let (resolvedSound, resolvedNotify, resolvedDisplayContents) = resolveNotificationSettings(list: notificationSettingsStack, defaultSettings: defaultNotificationSettings)
    
    var sound = resolvedSound
    if !resolvedNotify {
        notify = false
    }
    if !resolvedDisplayContents {
        displayContents = false
    }
    
    if muted {
        sound = .none
    }
    
    if let channel = message.peers[message.id.peerId] as? TelegramChannel {
        if !channel.flags.contains(.isForum) {
            threadData = nil
        }
        switch channel.participationStatus {
        case .kicked, .left:
            return ([], false, sound, false, threadData)
        case .member:
            break
        }
    }
    
    var foundReadState = false
    var isUnread = true
    if let readState = transaction.getCombinedPeerReadState(id.peerId) {
        if readState.isIncomingMessageIndexRead(message.index) {
            isUnread = false
        }
        foundReadState = true
    }
    
    if !foundReadState {
        Logger.shared.log("AccountStateManager", "read state for \(id.peerId) is undefined")
    }
    
    var resultMessages: [Message] = [message]
    
    var messageGroup: [Message]?
    if message.forwardInfo != nil && message.sourceReference == nil {
        messageGroup = transaction.getMessageForwardedGroup(message.id)
    } else if message.groupingKey != nil {
        messageGroup = transaction.getMessageGroup(message.id)
    }
    if let messageGroup = messageGroup {
        resultMessages.append(contentsOf: messageGroup.filter({ $0.id != message.id }))
    }
    
    if notify {
        return (resultMessages, isUnread, sound, displayContents, threadData)
    } else {
        return (alwaysReturnMessage ? resultMessages : [], false, sound, displayContents, threadData)
    }
}
