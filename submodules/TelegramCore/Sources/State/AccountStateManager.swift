import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private enum AccountStateManagerOperationContent {
    case pollDifference(AccountFinalStateEvents)
    case collectUpdateGroups([UpdateGroup], Double)
    case processUpdateGroups([UpdateGroup])
    case custom(Int32, Signal<Void, NoError>)
    case pollCompletion(Int32, [MessageId], [(Int32, ([MessageId]) -> Void)])
    case processEvents(Int32, AccountFinalStateEvents)
    case replayAsynchronouslyBuiltFinalState(AccountFinalState, () -> Void)
}

private final class AccountStateManagerOperation {
    var isRunning: Bool = false
    let content: AccountStateManagerOperationContent
    
    init(content: AccountStateManagerOperationContent) {
        self.content = content
    }
}

private enum AccountStateManagerAddOperationPosition {
    case first
    case last
}

private typealias SignalKitTimer = SwiftSignalKit.Timer

private enum CustomOperationEvent<T, E> {
    case Next(T)
    case Error(E)
    case Completion
}

private final class UpdatedWebpageSubscriberContext {
    let subscribers = Bag<(TelegramMediaWebpage) -> Void>()
}

private final class UpdatedPeersNearbySubscriberContext {
    let subscribers = Bag<([PeerNearby]) -> Void>()
}

public enum DeletedMessageId: Hashable {
    case global(Int32)
    case messageId(MessageId)
}

public final class AccountStateManager {
    private let queue = Queue()
    public let accountPeerId: PeerId
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    public let postbox: Postbox
    public let network: Network
    private let callSessionManager: CallSessionManager?
    private let addIsContactUpdates: ([(PeerId, Bool)]) -> Void
    private let shouldKeepOnlinePresence: Signal<Bool, NoError>
    
    private let peerInputActivityManager: PeerInputActivityManager?
    let auxiliaryMethods: AccountAuxiliaryMethods
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia?
    
    private var updateService: UpdateMessageService?
    private let updateServiceDisposable = MetaDisposable()
    
    private var operations_: [AccountStateManagerOperation] = []
    private var operations: [AccountStateManagerOperation] {
        get {
            assert(self.queue.isCurrent())
            return self.operations_
        } set(value) {
            assert(self.queue.isCurrent())
            self.operations_ = value
        }
    }
    private let operationDisposable = MetaDisposable()
    private var operationTimer: SignalKitTimer?
    
    private var removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId] = [:]
    
    private var nextId: Int32 = 0
    private func getNextId() -> Int32 {
        self.nextId += 1
        return self.nextId
    }
    
    private let isUpdatingValue = ValuePromise<Bool>(false)
    private var currentIsUpdatingValue = false {
        didSet {
            if self.currentIsUpdatingValue != oldValue {
                self.isUpdatingValue.set(self.currentIsUpdatingValue)
            }
        }
    }
    public var isUpdating: Signal<Bool, NoError> {
        return self.isUpdatingValue.get()
    }
    
    private let notificationMessagesPipe = ValuePipe<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)]>()
    public var notificationMessages: Signal<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)], NoError> {
        return self.notificationMessagesPipe.signal()
    }
    
    private let reactionNotificationsPipe = ValuePipe<[(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)]>()
    public var reactionNotifications: Signal<[(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)], NoError> {
        return self.reactionNotificationsPipe.signal()
    }
    
    private let displayAlertsPipe = ValuePipe<[(text: String, isDropAuth: Bool)]>()
    public var displayAlerts: Signal<[(text: String, isDropAuth: Bool)], NoError> {
        return self.displayAlertsPipe.signal()
    }
    
    private let dismissBotWebViewsPipe = ValuePipe<[Int64]>()
    public var dismissBotWebViews: Signal<[Int64], NoError> {
        return self.dismissBotWebViewsPipe.signal()
    }
    
    private let externallyUpdatedPeerIdsPipe = ValuePipe<[PeerId]>()
    var externallyUpdatedPeerIds: Signal<[PeerId], NoError> {
        return self.externallyUpdatedPeerIdsPipe.signal()
    }
    
    private let termsOfServiceUpdateValue = Atomic<TermsOfServiceUpdate?>(value: nil)
    private let termsOfServiceUpdatePromise = Promise<TermsOfServiceUpdate?>(nil)
    public var termsOfServiceUpdate: Signal<TermsOfServiceUpdate?, NoError> {
        return self.termsOfServiceUpdatePromise.get()
    }
    
    private let appUpdateInfoValue = Atomic<AppUpdateInfo?>(value: nil)
    private let appUpdateInfoPromise = Promise<AppUpdateInfo?>(nil)
    public var appUpdateInfo: Signal<AppUpdateInfo?, NoError> {
        return self.appUpdateInfoPromise.get()
    }
    
    private let appliedIncomingReadMessagesPipe = ValuePipe<[MessageId]>()
    public var appliedIncomingReadMessages: Signal<[MessageId], NoError> {
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
    
    private let threadReadStateUpdatesPipe = ValuePipe<(incoming: [MessageId: MessageId.Id], outgoing: [MessageId: MessageId.Id])>()
    var threadReadStateUpdates: Signal<(incoming: [MessageId: MessageId.Id], outgoing: [MessageId: MessageId.Id]), NoError> {
        return self.threadReadStateUpdatesPipe.signal()
    }
    
    private let groupCallParticipantUpdatesPipe = ValuePipe<[(Int64, GroupCallParticipantsContext.Update)]>()
    public var groupCallParticipantUpdates: Signal<[(Int64, GroupCallParticipantsContext.Update)], NoError> {
        return self.groupCallParticipantUpdatesPipe.signal()
    }
    
    private let deletedMessagesPipe = ValuePipe<[DeletedMessageId]>()
    public var deletedMessages: Signal<[DeletedMessageId], NoError> {
        return self.deletedMessagesPipe.signal()
    }
    
    private var updatedWebpageContexts: [MediaId: UpdatedWebpageSubscriberContext] = [:]
    private var updatedPeersNearbyContext = UpdatedPeersNearbySubscriberContext()
    
    private let delayNotificatonsUntil = Atomic<Int32?>(value: nil)
    private let appliedMaxMessageIdPromise = Promise<Int32?>(nil)
    private let appliedMaxMessageIdDisposable = MetaDisposable()
    private let appliedQtsPromise = Promise<Int32?>(nil)
    private let appliedQtsDisposable = MetaDisposable()
    
    var updateConfigRequested: (() -> Void)?
    var isPremiumUpdated: (() -> Void)?
    
    init(
        accountPeerId: PeerId,
        accountManager: AccountManager<TelegramAccountManagerTypes>,
        postbox: Postbox,
        network: Network,
        callSessionManager: CallSessionManager?,
        addIsContactUpdates: @escaping ([(PeerId, Bool)]) -> Void,
        shouldKeepOnlinePresence: Signal<Bool, NoError>,
        peerInputActivityManager: PeerInputActivityManager?,
        auxiliaryMethods: AccountAuxiliaryMethods
    ) {
        self.accountPeerId = accountPeerId
        self.accountManager = accountManager
        self.postbox = postbox
        self.network = network
        self.callSessionManager = callSessionManager
        self.addIsContactUpdates = addIsContactUpdates
        self.shouldKeepOnlinePresence = shouldKeepOnlinePresence
        self.peerInputActivityManager = peerInputActivityManager
        self.auxiliaryMethods = auxiliaryMethods
    }
    
    deinit {
        self.updateServiceDisposable.dispose()
        self.operationDisposable.dispose()
        self.appliedMaxMessageIdDisposable.dispose()
        self.appliedQtsDisposable.dispose()
    }
    
    public func reset() {
        self.queue.async {
            if self.updateService == nil {
                self.updateService = UpdateMessageService(peerId: self.accountPeerId)
                self.updateServiceDisposable.set(self.updateService!.pipe.signal().start(next: { [weak self] groups in
                    if let strongSelf = self {
                        strongSelf.addUpdateGroups(groups)
                    }
                }))
                self.network.mtProto.add(self.updateService)
            }
            self.operationDisposable.set(nil)
            self.replaceOperations(with: .pollDifference(AccountFinalStateEvents()))
            self.startFirstOperation()
            
            let appliedValues: [(MetaDisposable, Signal<Int32?, NoError>, Bool)] = [
                (self.appliedMaxMessageIdDisposable, self.appliedMaxMessageIdPromise.get(), true),
                (self.appliedQtsDisposable, self.appliedQtsPromise.get(), false)
            ]
            
            for (disposable, value, isMaxMessageId) in appliedValues {
                let network = self.network
                disposable.set((combineLatest(queue: self.queue, self.shouldKeepOnlinePresence, value)
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
                    if isMaxMessageId {
                        return network.request(Api.functions.messages.receivedMessages(maxId: value))
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                    } else {
                        if value == 0 {
                            return .complete()
                        } else {
                            return network.request(Api.functions.messages.receivedQueue(maxQts: value))
                            |> ignoreValues
                            |> `catch` { _ -> Signal<Never, NoError> in
                                return .complete()
                            }
                        }
                    }
                }).start())
            }
        }
    }
    
    func addUpdates(_ updates: Api.Updates) {
        self.queue.async {
            self.updateService?.addUpdates(updates)
        }
    }
    
    func addUpdateGroups(_ groups: [UpdateGroup]) {
        self.queue.async {
            if let last = self.operations.last {
                switch last.content {
                    case .pollDifference, .processUpdateGroups, .custom, .pollCompletion, .processEvents, .replayAsynchronouslyBuiltFinalState:
                        self.addOperation(.collectUpdateGroups(groups, 0.0), position: .last)
                    case let .collectUpdateGroups(currentGroups, timeout):
                        let operation = AccountStateManagerOperation(content: .collectUpdateGroups(currentGroups + groups, timeout))
                        operation.isRunning = last.isRunning
                        self.operations[self.operations.count - 1] = operation
                        self.startFirstOperation()
                }
            } else {
                self.addOperation(.collectUpdateGroups(groups, 0.0), position: .last)
            }
        }
    }
    
    func addReplayAsynchronouslyBuiltFinalState(_ finalState: AccountFinalState) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            self.queue.async {
                self.addOperation(.replayAsynchronouslyBuiltFinalState(finalState, {
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
    
    private func replaceOperations(with content: AccountStateManagerOperationContent) {
        var collectedProcessUpdateGroups: [AccountStateManagerOperationContent] = []
        var collectedMessageIds: [MessageId] = []
        var collectedPollCompletionSubscribers: [(Int32, ([MessageId]) -> Void)] = []
        var collectedReplayAsynchronouslyBuiltFinalState: [(AccountFinalState, () -> Void)] = []
        var processEvents: [(Int32, AccountFinalStateEvents)] = []
        var customOperations: [(Int32, Signal<Void, NoError>)] = []
        
        var replacedOperations: [AccountStateManagerOperation] = []
        
        for i in 0 ..< self.operations.count {
            if self.operations[i].isRunning {
                replacedOperations.append(self.operations[i])
            } else {
                switch self.operations[i].content {
                    case .processUpdateGroups:
                        collectedProcessUpdateGroups.append(self.operations[i].content)
                    case let .pollCompletion(_, messageIds, subscribers):
                        collectedMessageIds.append(contentsOf: messageIds)
                        collectedPollCompletionSubscribers.append(contentsOf: subscribers)
                    case let .replayAsynchronouslyBuiltFinalState(finalState, completion):
                        collectedReplayAsynchronouslyBuiltFinalState.append((finalState, completion))
                    case let .processEvents(operationId, events):
                        processEvents.append((operationId, events))
                    case let .custom(operationId, customSignal):
                        customOperations.append((operationId, customSignal))
                    default:
                        break
                }
            }
        }
        
        replacedOperations.append(contentsOf: collectedProcessUpdateGroups.map { AccountStateManagerOperation(content: $0) })
        
        replacedOperations.append(AccountStateManagerOperation(content: content))
        
        if !collectedPollCompletionSubscribers.isEmpty || !collectedMessageIds.isEmpty {
            replacedOperations.append(AccountStateManagerOperation(content: .pollCompletion(self.getNextId(), collectedMessageIds, collectedPollCompletionSubscribers)))
        }
        
        for (finalState, completion) in collectedReplayAsynchronouslyBuiltFinalState {
            replacedOperations.append(AccountStateManagerOperation(content: .replayAsynchronouslyBuiltFinalState(finalState, completion)))
        }
        
        for (operationId, events) in processEvents {
            replacedOperations.append(AccountStateManagerOperation(content: .processEvents(operationId, events)))
        }
        
        for (operationId, customSignal) in customOperations {
            replacedOperations.append(AccountStateManagerOperation(content: .custom(operationId, customSignal)))
        }
        
        self.operations.removeAll()
        self.operations.append(contentsOf: replacedOperations)
    }
    
    private func addOperation(_ content: AccountStateManagerOperationContent, position: AccountStateManagerAddOperationPosition) {
        self.queue.async {
            let operation = AccountStateManagerOperation(content: content)
            switch position {
                case .first:
                    if self.operations.isEmpty || !self.operations[0].isRunning {
                        self.operations.insert(operation, at: 0)
                        self.startFirstOperation()
                    } else {
                        self.operations.insert(operation, at: 1)
                    }
                case .last:
                    let begin = self.operations.isEmpty
                    self.operations.append(operation)
                    if begin {
                        self.startFirstOperation()
                    }
            }
        }
    }
    
    private func startFirstOperation() {
        guard let operation = self.operations.first else {
            return
        }
        guard !operation.isRunning else {
            return
        }
        operation.isRunning = true
        switch operation.content {
            case let .pollDifference(currentEvents):
                self.operationTimer?.invalidate()
                self.currentIsUpdatingValue = true
                let queue = self.queue
                let accountManager = self.accountManager
                let postbox = self.postbox
                let network = self.network
                let mediaBox = postbox.mediaBox
                let accountPeerId = self.accountPeerId
                let auxiliaryMethods = self.auxiliaryMethods
                let signal = postbox.stateView()
                |> mapToSignal { view -> Signal<AuthorizedAccountState, NoError> in
                    if let state = view.state as? AuthorizedAccountState {
                        return .single(state)
                    } else {
                        return .complete()
                    }
                }
                |> take(1)
                |> mapToSignal { [weak self] state -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
                    if let authorizedState = state.state {
                        let flags: Int32 = 0
                        let ptsTotalLimit: Int32? = nil
                        
                        let request = network.request(Api.functions.updates.getDifference(flags: flags, pts: authorizedState.pts, ptsTotalLimit: ptsTotalLimit, date: authorizedState.date, qts: authorizedState.qts))
                        |> map(Optional.init)
                        |> `catch` { error -> Signal<Api.updates.Difference?, MTRpcError> in
                            if error.errorCode == 406 && error.errorDescription == "AUTH_KEY_DUPLICATED" {
                                return .single(nil)
                            } else {
                                return .fail(error)
                            }
                        }
                        |> retryRequest
                        
                        return request
                        |> mapToSignal { difference -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
                            guard let difference = difference else {
                                return .single((nil, nil, true))
                            }
                            switch difference {
                                case .differenceTooLong:
                                    preconditionFailure()
                                default:
                                    return initialStateWithDifference(postbox: postbox, difference: difference)
                                    |> mapToSignal { state -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
                                        if state.initialState.state != authorizedState {
                                            Logger.shared.log("State", "pollDifference initial state \(authorizedState) != current state \(state.initialState.state)")
                                            return .single((nil, nil, false))
                                        } else {
                                            return finalStateWithDifference(accountPeerId: accountPeerId, postbox: postbox, network: network, state: state, difference: difference)
                                                |> deliverOn(queue)
                                                |> mapToSignal { finalState -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
                                                    if !finalState.state.preCachedResources.isEmpty {
                                                        for (resource, data) in finalState.state.preCachedResources {
                                                            mediaBox.storeResourceData(resource.id, data: data)
                                                        }
                                                    }
                                                    let removePossiblyDeliveredMessagesUniqueIds = self?.removePossiblyDeliveredMessagesUniqueIds ?? Dictionary()
                                                    return postbox.transaction { transaction -> (difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool) in
                                                        let startTime = CFAbsoluteTimeGetCurrent()
                                                        let replayedState = replayFinalState(accountManager: accountManager, postbox: postbox, accountPeerId: accountPeerId, mediaBox: mediaBox, encryptionProvider: network.encryptionProvider, transaction: transaction, auxiliaryMethods: auxiliaryMethods, finalState: finalState, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, ignoreDate: false)
                                                        let deltaTime = CFAbsoluteTimeGetCurrent() - startTime
                                                        if deltaTime > 1.0 {
                                                            Logger.shared.log("State", "replayFinalState took \(deltaTime)s")
                                                        }
                                                        
                                                        if let replayedState = replayedState {
                                                            return (difference, replayedState, false)
                                                        } else {
                                                            return (nil, nil, false)
                                                        }
                                                    }
                                            }
                                        }
                                    }
                            }
                        }
                    } else {
                        let appliedState = network.request(Api.functions.updates.getState())
                        |> retryRequest
                        |> mapToSignal { state in
                            return postbox.transaction { transaction -> (difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool) in
                                if let currentState = transaction.getState() as? AuthorizedAccountState {
                                    switch state {
                                        case let .state(pts, qts, date, seq, _):
                                            transaction.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq)))
                                    }
                                }
                                return (nil, nil, false)
                            }
                        }
                        return appliedState
                    }
                }
                |> deliverOn(self.queue)
                let _ = signal.start(next: { [weak self] difference, finalState, skipBecauseOfError in
                    if let strongSelf = self {
                        if case .pollDifference = strongSelf.operations.removeFirst().content {
                            let events: AccountFinalStateEvents
                            if let finalState = finalState {
                                events = currentEvents.union(with: AccountFinalStateEvents(state: finalState))
                            } else {
                                events = currentEvents
                            }
                            if let difference = difference {
                                switch difference {
                                    case .differenceSlice:
                                        strongSelf.addOperation(.pollDifference(events), position: .first)
                                    default:
                                        if !events.isEmpty {
                                            strongSelf.insertProcessEvents(events)
                                        }
                                        strongSelf.currentIsUpdatingValue = false
                                    strongSelf.significantStateUpdateCompletedPipe.putNext(Void())
                                }
                            } else if skipBecauseOfError {
                                if !events.isEmpty {
                                    strongSelf.insertProcessEvents(events)
                                }
                            } else {
                                if !events.isEmpty {
                                    strongSelf.insertProcessEvents(events)
                                }
                                strongSelf.replaceOperations(with: .pollDifference(AccountFinalStateEvents()))
                            }
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                })
            case let .collectUpdateGroups(_, timeout):
                self.operationTimer?.invalidate()
                let operationTimer = SignalKitTimer(timeout: timeout, repeat: false, completion: { [weak self] in
                    if let strongSelf = self {
                        let firstOperation = strongSelf.operations.removeFirst()
                        if case let .collectUpdateGroups(groups, _) = firstOperation.content {
                            if timeout.isEqual(to: 0.0) {
                                strongSelf.addOperation(.processUpdateGroups(groups), position: .first)
                            } else {
                                Logger.shared.log("AccountStateManager", "timeout while waiting for updates")
                                strongSelf.replaceOperations(with: .pollDifference(AccountFinalStateEvents()))
                            }
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                }, queue: self.queue)
                self.operationTimer = operationTimer
                operationTimer.start()
            case let .processUpdateGroups(groups):
                self.operationTimer?.invalidate()
                let accountManager = self.accountManager
                let postbox = self.postbox
                let network = self.network
                let auxiliaryMethods = self.auxiliaryMethods
                let accountPeerId = self.accountPeerId
                let mediaBox = postbox.mediaBox
                let queue = self.queue
                let signal = initialStateWithUpdateGroups(postbox: postbox, groups: groups)
                |> mapToSignal { [weak self] state -> Signal<(AccountReplayedFinalState?, AccountFinalState), NoError> in
                    return finalStateWithUpdateGroups(accountPeerId: accountPeerId, postbox: postbox, network: network, state: state, groups: groups)
                    |> deliverOn(queue)
                    |> mapToSignal { finalState in
                        if !finalState.discard && !finalState.state.preCachedResources.isEmpty {
                            for (resource, data) in finalState.state.preCachedResources {
                                postbox.mediaBox.storeResourceData(resource.id, data: data)
                            }
                        }
                        
                        let removePossiblyDeliveredMessagesUniqueIds = self?.removePossiblyDeliveredMessagesUniqueIds ?? Dictionary()
                        
                        return postbox.transaction { transaction -> AccountReplayedFinalState? in
                            if finalState.discard {
                                return nil
                            } else {
                                let startTime = CFAbsoluteTimeGetCurrent()
                                let result = replayFinalState(accountManager: accountManager, postbox: postbox, accountPeerId: accountPeerId, mediaBox: mediaBox, encryptionProvider: network.encryptionProvider, transaction: transaction, auxiliaryMethods: auxiliaryMethods, finalState: finalState, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, ignoreDate: false)
                                let deltaTime = CFAbsoluteTimeGetCurrent() - startTime
                                if deltaTime > 1.0 {
                                    Logger.shared.log("State", "replayFinalState took \(deltaTime)s")
                                }
                                return result
                            }
                        }
                        |> map({ ($0, finalState) })
                        |> deliverOn(queue)
                    }
                }
                let _ = signal.start(next: { [weak self] replayedState, finalState in
                    if let strongSelf = self {
                        if case let .processUpdateGroups(groups) = strongSelf.operations.removeFirst().content {
                            if let replayedState = replayedState, !finalState.shouldPoll {
                                let events = AccountFinalStateEvents(state: replayedState)
                                if !events.isEmpty {
                                    strongSelf.insertProcessEvents(events)
                                }
                                if finalState.incomplete || !finalState.missingUpdatesFromChannels.isEmpty {
                                    strongSelf.addOperation(.collectUpdateGroups(groups, 2.0), position: .last)
                                }
                            } else {
                                if let replayedState = replayedState {
                                    let events = AccountFinalStateEvents(state: replayedState)
                                    if !events.displayAlerts.isEmpty {
                                        strongSelf.insertProcessEvents(AccountFinalStateEvents(displayAlerts: events.displayAlerts))
                                    }
                                }
                                strongSelf.replaceOperations(with: .pollDifference(AccountFinalStateEvents()))
                            }
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                })
            case let .custom(operationId, signal):
                self.operationTimer?.invalidate()
                let completed: () -> Void = { [weak self] in
                    if let strongSelf = self {
                        let topOperation = strongSelf.operations.removeFirst()
                        if case .custom(operationId, _) = topOperation.content {
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                }
                let _ = (signal |> deliverOn(self.queue)).start(completed: {
                    completed()
                })
            case let .processEvents(operationId, events):
                self.operationTimer?.invalidate()
                let completed: () -> Void = { [weak self] in
                    if let strongSelf = self {
                        let topOperation = strongSelf.operations.removeFirst()
                        if case .processEvents(operationId, _) = topOperation.content {
                            if !events.updatedTypingActivities.isEmpty {
                                strongSelf.peerInputActivityManager?.transaction { manager in
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
                                strongSelf.notifyUpdatedWebpages(events.updatedWebpages)
                            }
                            if let updatedPeersNearby = events.updatedPeersNearby {
                                strongSelf.notifyUpdatedPeersNearby(updatedPeersNearby)
                            }
                            if !events.updatedCalls.isEmpty {
                                for call in events.updatedCalls {
                                    strongSelf.callSessionManager?.updateSession(call, completion: { _ in })
                                }
                            }
                            if !events.addedCallSignalingData.isEmpty {
                                for (id, data) in events.addedCallSignalingData {
                                    strongSelf.callSessionManager?.addCallSignalingData(id: id, data: data)
                                }
                            }
                            if !events.updatedGroupCallParticipants.isEmpty {
                                strongSelf.groupCallParticipantUpdatesPipe.putNext(events.updatedGroupCallParticipants)
                            }
                            if !events.updatedIncomingThreadReadStates.isEmpty || !events.updatedOutgoingThreadReadStates.isEmpty {
                                strongSelf.threadReadStateUpdatesPipe.putNext((events.updatedIncomingThreadReadStates, events.updatedOutgoingThreadReadStates))
                            }
                            if !events.isContactUpdates.isEmpty {
                                strongSelf.addIsContactUpdates(events.isContactUpdates)
                            }
                            if let updatedMaxMessageId = events.updatedMaxMessageId {
                                strongSelf.appliedMaxMessageIdPromise.set(.single(updatedMaxMessageId))
                            }
                            if let updatedQts = events.updatedQts {
                                strongSelf.appliedQtsPromise.set(.single(updatedQts))
                            }
                            var pollCount = 0
                            for i in 0 ..< strongSelf.operations.count {
                                if case let .pollCompletion(pollId, messageIds, subscribers) = strongSelf.operations[i].content {
                                    pollCount += 1
                                    var updatedMessageIds = messageIds
                                    updatedMessageIds.append(contentsOf: events.addedIncomingMessageIds)
                                    let operation = AccountStateManagerOperation(content: .pollCompletion(pollId, updatedMessageIds, subscribers))
                                    operation.isRunning = strongSelf.operations[i].isRunning
                                    strongSelf.operations[i] = operation
                                }
                            }
                            assert(pollCount <= 1)
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                }
                
                if events.delayNotificatonsUntil != nil {
                    let _ = self.delayNotificatonsUntil.swap(events.delayNotificatonsUntil)
                }
                
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
                                    threadData = transaction.getMessageHistoryThreadInfo(peerId: first.id.peerId, threadId: makeMessageThreadId(threadId))?.data.get(MessageHistoryThreadData.self)
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
            case let .pollCompletion(pollId, preMessageIds, preSubscribers):
                if self.operations.count > 1 {
                    self.operations.removeFirst()
                    self.postponePollCompletionOperation(messageIds: preMessageIds, subscribers: preSubscribers)
                    self.startFirstOperation()
                } else {
                    self.operationTimer?.invalidate()
                    let signal = self.network.request(Api.functions.help.test())
                    |> deliverOn(self.queue)
                    let completed: () -> Void = { [weak self] in
                        if let strongSelf = self {
                            let topOperation = strongSelf.operations.removeFirst()
                            if case let .pollCompletion(topPollId, messageIds, subscribers) = topOperation.content {
                                assert(topPollId == pollId)
                                
                                if strongSelf.operations.isEmpty {
                                    for (_, f) in subscribers {
                                        f(messageIds)
                                    }
                                } else {
                                    strongSelf.postponePollCompletionOperation(messageIds: messageIds, subscribers: subscribers)
                                }
                                strongSelf.startFirstOperation()
                            } else {
                                assertionFailure()
                            }
                        }
                    }
                    let _ = (signal |> deliverOn(self.queue)).start(error: { _ in
                        completed()
                    }, completed: {
                        completed()
                    })
                }
            case let .replayAsynchronouslyBuiltFinalState(finalState, completion):
                if !finalState.state.preCachedResources.isEmpty {
                    for (resource, data) in finalState.state.preCachedResources {
                        self.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    }
                }
                
                let accountPeerId = self.accountPeerId
                let accountManager = self.accountManager
                let postbox = self.postbox
                let mediaBox = self.postbox.mediaBox
                let network = self.network
                let auxiliaryMethods = self.auxiliaryMethods
                let removePossiblyDeliveredMessagesUniqueIds = self.removePossiblyDeliveredMessagesUniqueIds
                let signal = self.postbox.transaction { transaction -> AccountReplayedFinalState? in
                    let startTime = CFAbsoluteTimeGetCurrent()
                    let result = replayFinalState(accountManager: accountManager, postbox: postbox, accountPeerId: accountPeerId, mediaBox: mediaBox, encryptionProvider: network.encryptionProvider, transaction: transaction, auxiliaryMethods: auxiliaryMethods, finalState: finalState, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, ignoreDate: false)
                    let deltaTime = CFAbsoluteTimeGetCurrent() - startTime
                    if deltaTime > 1.0 {
                        Logger.shared.log("State", "replayFinalState took \(deltaTime)s")
                    }
                    return result
                }
                |> map({ ($0, finalState) })
                |> deliverOn(self.queue)
                
                let _ = signal.start(next: { [weak self] replayedState, finalState in
                    if let strongSelf = self {
                        if case .replayAsynchronouslyBuiltFinalState = strongSelf.operations.removeFirst().content {
                            if let replayedState = replayedState {
                                let events = AccountFinalStateEvents(state: replayedState)
                                if !events.isEmpty {
                                    strongSelf.insertProcessEvents(events)
                                }
                            }
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                        completion()
                    }
                })
        }
    }

    func standaloneReplayAsynchronouslyBuiltFinalState(finalState: AccountFinalState) -> Signal<Never, NoError> {
        if !finalState.state.preCachedResources.isEmpty {
            for (resource, data) in finalState.state.preCachedResources {
                self.postbox.mediaBox.storeResourceData(resource.id, data: data)
            }
        }

        let accountPeerId = self.accountPeerId
        let accountManager = self.accountManager
        let postbox = self.postbox
        let mediaBox = self.postbox.mediaBox
        let network = self.network
        let auxiliaryMethods = self.auxiliaryMethods
        let removePossiblyDeliveredMessagesUniqueIds = self.removePossiblyDeliveredMessagesUniqueIds
        let signal = self.postbox.transaction { transaction -> AccountReplayedFinalState? in
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = replayFinalState(accountManager: accountManager, postbox: postbox, accountPeerId: accountPeerId, mediaBox: mediaBox, encryptionProvider: network.encryptionProvider, transaction: transaction, auxiliaryMethods: auxiliaryMethods, finalState: finalState, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, ignoreDate: false)
            let deltaTime = CFAbsoluteTimeGetCurrent() - startTime
            if deltaTime > 1.0 {
                Logger.shared.log("State", "replayFinalState took \(deltaTime)s")
            }
            return result
        }
        |> map({ ($0, finalState) })
        |> deliverOn(self.queue)

        return signal
        |> ignoreValues
    }

    public func standalonePollDifference() -> Signal<Bool, NoError> {
        let queue = self.queue
        let accountManager = self.accountManager
        let postbox = self.postbox
        let network = self.network
        let mediaBox = postbox.mediaBox
        let accountPeerId = self.accountPeerId
        let auxiliaryMethods = self.auxiliaryMethods

        let signal = postbox.stateView()
        |> mapToSignal { view -> Signal<AuthorizedAccountState, NoError> in
            if let state = view.state as? AuthorizedAccountState {
                return .single(state)
            } else {
                return .complete()
            }
        }
        |> take(1)
        |> mapToSignal { [weak self] state -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
            if let authorizedState = state.state {
                let flags: Int32 = 0
                let ptsTotalLimit: Int32? = nil

                let request = network.request(Api.functions.updates.getDifference(flags: flags, pts: authorizedState.pts, ptsTotalLimit: ptsTotalLimit, date: Int32.max, qts: authorizedState.qts))
                |> map(Optional.init)
                |> `catch` { error -> Signal<Api.updates.Difference?, MTRpcError> in
                    if error.errorCode == 406 && error.errorDescription == "AUTH_KEY_DUPLICATED" {
                        return .single(nil)
                    } else {
                        return .fail(error)
                    }
                }
                |> retryRequest

                return request
                |> mapToSignal { difference -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
                    guard let difference = difference else {
                        return .single((nil, nil, true))
                    }
                    switch difference {
                    case .differenceTooLong:
                        preconditionFailure()
                    default:
                        return initialStateWithDifference(postbox: postbox, difference: difference)
                        |> mapToSignal { state -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
                            if state.initialState.state != authorizedState {
                                Logger.shared.log("State", "pollDifference initial state \(authorizedState) != current state \(state.initialState.state)")
                                return .single((nil, nil, false))
                            } else {
                                return finalStateWithDifference(accountPeerId: accountPeerId, postbox: postbox, network: network, state: state, difference: difference)
                                |> deliverOn(queue)
                                |> mapToSignal { finalState -> Signal<(difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool), NoError> in
                                    if !finalState.state.preCachedResources.isEmpty {
                                        for (resource, data) in finalState.state.preCachedResources {
                                            mediaBox.storeResourceData(resource.id, data: data)
                                        }
                                    }
                                    let removePossiblyDeliveredMessagesUniqueIds = self?.removePossiblyDeliveredMessagesUniqueIds ?? Dictionary()
                                    return postbox.transaction { transaction -> (difference: Api.updates.Difference?, finalStatte: AccountReplayedFinalState?, skipBecauseOfError: Bool) in
                                        let startTime = CFAbsoluteTimeGetCurrent()
                                        let replayedState = replayFinalState(
                                            accountManager: accountManager,
                                            postbox: postbox,
                                            accountPeerId: accountPeerId,
                                            mediaBox: mediaBox,
                                            encryptionProvider: network.encryptionProvider,
                                            transaction: transaction,
                                            auxiliaryMethods: auxiliaryMethods,
                                            finalState: finalState,
                                            removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds,
                                            ignoreDate: true
                                        )
                                        let deltaTime = CFAbsoluteTimeGetCurrent() - startTime
                                        if deltaTime > 1.0 {
                                            Logger.shared.log("State", "replayFinalState took \(deltaTime)s")
                                        }

                                        if let replayedState = replayedState {
                                            return (difference, replayedState, false)
                                        } else {
                                            return (nil, nil, false)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                return .single((nil, nil, false))
            }
        }
        |> deliverOn(self.queue)

        return signal
        |> mapToSignal { difference, _, _ -> Signal<Bool, NoError> in
            if let difference = difference {
                switch difference {
                case .differenceSlice:
                    return .single(false)
                default:
                    return .single(true)
                }
            } else {
                return .single(true)
            }
        }
    }
    
    private func insertProcessEvents(_ events: AccountFinalStateEvents) {
        if !events.isEmpty {
            let operation = AccountStateManagerOperation(content: .processEvents(self.getNextId(), events))
            var inserted = false
            for i in 0 ..< self.operations.count {
                if self.operations[i].isRunning {
                    continue
                }
                if case .processEvents = self.operations[i].content {
                    continue
                }
                self.operations.insert(operation, at: i)
                inserted = true
                break
            }
            if !inserted {
                self.operations.append(operation)
            }
        }
    }
    
    private func postponePollCompletionOperation(messageIds: [MessageId], subscribers: [(Int32, ([MessageId]) -> Void)]) {
        self.addOperation(.pollCompletion(self.getNextId(), messageIds, subscribers), position: .last)
        
        for i in 0 ..< self.operations.count {
            if case .pollCompletion = self.operations[i].content {
                if i != self.operations.count - 1 {
                    assertionFailure()
                }
            }
        }
    }
    
    private func addPollCompletion(_ f: @escaping ([MessageId]) -> Void) -> Int32 {
        assert(self.queue.isCurrent())
        
        let updatedId: Int32 = self.getNextId()
        
        for i in 0 ..< self.operations.count {
            if case let .pollCompletion(pollId, messageIds, subscribers) = self.operations[i].content {
                var subscribers = subscribers
                subscribers.append((updatedId, f))
                let operation = AccountStateManagerOperation(content: .pollCompletion(pollId, messageIds, subscribers))
                operation.isRunning = self.operations[i].isRunning
                self.operations[i] = operation
                return updatedId
            }
        }
        
        self.addOperation(.pollCompletion(self.getNextId(), [], [(updatedId, f)]), position: .last)
        
        return updatedId
    }
    
    private func removePollCompletion(_ id: Int32) {
        for i in 0 ..< self.operations.count {
            if case let .pollCompletion(pollId, messages, subscribers) = self.operations[i].content {
                for j in 0 ..< subscribers.count {
                    if subscribers[j].0 == id {
                        var subscribers = subscribers
                        subscribers.remove(at: j)
                        let operation = AccountStateManagerOperation(content: .pollCompletion(pollId, messages, subscribers))
                        operation.isRunning = self.operations[i].isRunning
                        self.operations[i] = operation
                        break
                    }
                }
            }
        }
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
    
    public func updatedWebpage(_ webpageId: MediaId) -> Signal<TelegramMediaWebpage, NoError> {
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
    
    private func notifyUpdatedWebpages(_ updatedWebpages: [MediaId: TelegramMediaWebpage]) {
        for (id, context) in self.updatedWebpageContexts {
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
    
    public func getDelayNotificatonsUntil() -> Int32? {
        return self.delayNotificatonsUntil.with { $0 }
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
    
    public func updatedPeersNearby() -> Signal<[PeerNearby], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let index = strongSelf.updatedPeersNearbyContext.subscribers.add({ peersNearby in
                        subscriber.putNext(peersNearby)
                    })
                    
                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            strongSelf.updatedPeersNearbyContext.subscribers.remove(index)
                        }
                    })
                }
            }
            return disposable
        }
    }
    
    private func notifyUpdatedPeersNearby(_ updatedPeersNearby: [PeerNearby]) {
        for subscriber in self.updatedPeersNearbyContext.subscribers.copyItems() {
            subscriber(updatedPeersNearby)
        }
    }
    
    func notifyDeletedMessages(messageIds: [MessageId]) {
        self.deletedMessagesPipe.putNext(messageIds.map { .messageId($0) })
    }

    public final class IncomingCallUpdate {
        public let callId: Int64
        public let callAccessHash: Int64
        public let timestamp: Int32
        public let peer: EnginePeer

        init(
            callId: Int64,
            callAccessHash: Int64,
            timestamp: Int32,
            peer: EnginePeer
        ) {
            self.callId = callId
            self.callAccessHash = callAccessHash
            self.timestamp = timestamp
            self.peer = peer
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
        case let .updates(updates, users, _, _, _):
            var peers: [Peer] = []
            for user in users {
                peers.append(TelegramUser(user: user))
            }

            for update in updates {
                switch update {
                case let .updatePhoneCall(phoneCall):
                    switch phoneCall {
                    case let .phoneCallRequested(_, id, accessHash, date, adminId, _, _, _):
                        guard let peer = peers.first(where: { $0.id == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(adminId)) }) else {
                            return nil
                        }
                        return IncomingCallUpdate(
                            callId: id,
                            callAccessHash: accessHash,
                            timestamp: date,
                            peer: EnginePeer(peer)
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
            case let .updates(updates, _, _, _, _):
                for update in updates {
                    switch update {
                    case let .updatePhoneCall(phoneCall):
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
                threadData = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: makeMessageThreadId(threadId))?.data.get(MessageHistoryThreadData.self)
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
    if let peer = peer, let associatedPeerId = peer.associatedPeerId {
        notificationPeerId = associatedPeerId
    }
    if message.personal, let author = message.author {
        notificationPeerId = author.id
    }
    
    var notificationSettingsStack: [TelegramPeerNotificationSettings] = []
    
    if let threadId = message.threadId, let threadData = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
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
