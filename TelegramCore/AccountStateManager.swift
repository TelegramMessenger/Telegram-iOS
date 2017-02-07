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

private enum AccountStateManagerOperation {
    case pollDifference(AccountFinalStateEvents)
    case collectUpdateGroups([UpdateGroup], Double)
    case processUpdateGroups([UpdateGroup])
    case custom(Int32, Signal<Void, NoError>)
    case pollCompletion(Int32, [(Int32, () -> Void)])
    case processEvents(Int32, AccountFinalStateEvents)
}

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private enum CustomOperationEvent<T, E> {
    case Next(T)
    case Error(E)
    case Completion
}

public final class AccountStateManager {
    private let queue = Queue()
    private let account: Account
    private let peerInputActivityManager: PeerInputActivityManager
    
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
    
    private let notificationMessagesPipe = ValuePipe<[Message]>()
    public var notificationMessages: Signal<[Message], NoError> {
        return self.notificationMessagesPipe.signal()
    }
    
    init(account: Account, peerInputActivityManager: PeerInputActivityManager) {
        self.account = account
        self.peerInputActivityManager = peerInputActivityManager
    }
    
    deinit {
        self.updateServiceDisposable.dispose()
        self.operationDisposable.dispose()
    }
    
    public func reset() {
        self.queue.async {
            if self.updateService == nil {
                self.updateService = UpdateMessageService(peerId: self.account.peerId)
                self.updateServiceDisposable.set(self.updateService!.pipe.signal().start(next: { [weak self] groups in
                    if let strongSelf = self {
                        strongSelf.addUpdateGroups(groups)
                    }
                }))
                self.account.network.mtProto.add(self.updateService)
            }
            self.operationDisposable.set(nil)
            self.replaceOperations(with: .pollDifference(AccountFinalStateEvents()))
            self.startFirstOperation()
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
                switch last {
                    case .pollDifference, .processUpdateGroups, .custom, .pollCompletion, .processEvents:
                        self.operations.append(.collectUpdateGroups(groups, 0.0))
                    case let .collectUpdateGroups(currentGroups, timestamp):
                        if timestamp.isEqual(to: 0.0) {
                            self.operations[self.operations.count - 1] = .collectUpdateGroups(currentGroups + groups, timestamp)
                        } else {
                            self.operations[self.operations.count - 1] = .processUpdateGroups(currentGroups + groups)
                            self.startFirstOperation()
                    }
                }
            } else {
                self.operations.append(.collectUpdateGroups(groups, 0.0))
                self.startFirstOperation()
            }
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
            
            self.addOperation(.custom(self.getNextId(), signal))
            
            return disposable
        } |> runOn(self.queue)
    }
    
    private func replaceOperations(with operation: AccountStateManagerOperation) {
        var collectedPollCompletionSubscribers: [(Int32, () -> Void)] = []
        
        if !self.operations.isEmpty {
            for operation in self.operations {
                if case let .pollCompletion(_, subscribers) = operation {
                    collectedPollCompletionSubscribers.append(contentsOf: subscribers)
                }
            }
        }
        
        self.operations.removeAll()
        self.operations.append(operation)
        for (id, f) in collectedPollCompletionSubscribers {
            let _ = self.addPollCompletion(f, id: id)
        }
    }
    
    private func addOperation(_ operation: AccountStateManagerOperation) {
        self.queue.async {
            let begin = self.operations.isEmpty
            self.operations.append(operation)
            if begin {
                self.startFirstOperation()
            }
        }
    }
    
    private func startFirstOperation() {
        guard let operation = self.operations.first else {
            return
        }
        switch operation {
            case let .pollDifference(currentEvents):
                self.operationTimer?.invalidate()
                self.currentIsUpdatingValue = true
                let account = self.account
                let mediaBox = account.postbox.mediaBox
                let signal = account.postbox.stateView()
                    |> mapToSignal { view -> Signal<AuthorizedAccountState, NoError> in
                        if let state = view.state as? AuthorizedAccountState {
                            return .single(state)
                        } else {
                            return .complete()
                        }
                    }
                    |> take(1)
                    |> mapToSignal { state -> Signal<(Api.updates.Difference?, AccountReplayedFinalState?), NoError> in
                        if let authorizedState = state.state {
                            let request = account.network.request(Api.functions.updates.getDifference(flags: 0, pts: authorizedState.pts, ptsTotalLimit: nil, date: authorizedState.date, qts: authorizedState.qts))
                                |> retryRequest
                            return request |> mapToSignal { difference -> Signal<(Api.updates.Difference?, AccountReplayedFinalState?), NoError> in
                                return initialStateWithDifference(account, difference: difference)
                                    |> mapToSignal { state -> Signal<(Api.updates.Difference?, AccountReplayedFinalState?), NoError> in
                                        if state.initialState.state != authorizedState {
                                            trace("State", what: "pollDifference initial state \(authorizedState) != current state \(state.initialState.state)")
                                            return .single((nil, nil))
                                        } else {
                                            return finalStateWithDifference(account: account, state: state, difference: difference)
                                                |> mapToSignal { finalState -> Signal<(Api.updates.Difference?, AccountReplayedFinalState?), NoError> in
                                                    if !finalState.state.preCachedResources.isEmpty {
                                                        for (resource, data) in finalState.state.preCachedResources {
                                                            account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                                                        }
                                                    }
                                                    return account.postbox.modify { modifier -> (Api.updates.Difference?, AccountReplayedFinalState?) in
                                                        if let replayedState = replayFinalState(mediaBox: mediaBox, modifier: modifier, finalState: finalState) {
                                                            return (difference, replayedState)
                                                        } else {
                                                            return (nil, nil)
                                                        }
                                                    }
                                            }
                                        }
                                }
                            }
                        } else {
                            let appliedState = account.network.request(Api.functions.updates.getState())
                                |> retryRequest
                                |> mapToSignal { state in
                                    return account.postbox.modify { modifier -> (Api.updates.Difference?, AccountReplayedFinalState?) in
                                        if let currentState = modifier.getState() as? AuthorizedAccountState {
                                            switch state {
                                                case let .state(pts, qts, date, seq, _):
                                                    modifier.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq)))
                                            }
                                        }
                                        return (nil, nil)
                                    }
                            }
                            return appliedState
                        }
                    }
                    |> deliverOn(self.queue)
                let _ = signal.start(next: { [weak self] difference, finalState in
                    if let strongSelf = self {
                        if case .pollDifference = strongSelf.operations.removeFirst() {
                            let events: AccountFinalStateEvents
                            if let finalState = finalState {
                                events = currentEvents.union(with: AccountFinalStateEvents(state: finalState))
                            } else {
                                events = currentEvents
                            }
                            if let difference = difference {
                                switch difference {
                                    case .differenceSlice:
                                        strongSelf.operations.insert(.pollDifference(events), at: 0)
                                    default:
                                        if !events.isEmpty {
                                            strongSelf.insertProcessEvents(events)
                                        }
                                        strongSelf.currentIsUpdatingValue = false
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
                }, error: { _ in
                    assertionFailure()
                    trace("AccountStateManager", what: "processUpdateGroups signal completed with error")
                })
            case let .collectUpdateGroups(_, timeout):
                self.operationTimer?.invalidate()
                let operationTimer = SignalKitTimer(timeout: timeout, repeat: false, completion: { [weak self] in
                    if let strongSelf = self {
                        if let firstOperation = strongSelf.operations.first, case let .collectUpdateGroups(groups, _) = firstOperation {
                            if timeout.isEqual(to: 0.0) {
                                strongSelf.operations[0] = .processUpdateGroups(groups)
                            } else {
                                trace("AccountStateManager", what: "timeout while waiting for updates")
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
                let account = self.account
                let mediaBox = account.postbox.mediaBox
                let queue = self.queue
                let signal = initialStateWithUpdateGroups(account, groups: groups)
                    |> mapToSignal { state -> Signal<(AccountReplayedFinalState?, AccountFinalState), NoError> in
                        return finalStateWithUpdateGroups(account, state: state, groups: groups)
                            |> mapToSignal { finalState in
                                if !finalState.state.preCachedResources.isEmpty {
                                    for (resource, data) in finalState.state.preCachedResources {
                                        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                                    }
                                }
                                
                                return account.postbox.modify { modifier -> AccountReplayedFinalState? in
                                    return replayFinalState(mediaBox: mediaBox, modifier: modifier, finalState: finalState)
                                }
                                |> map({ ($0, finalState) })
                                |> deliverOn(queue)
                            }
                    }
                let _ = signal.start(next: { [weak self] replayedState, finalState in
                    if let strongSelf = self {
                        if case let .processUpdateGroups(groups) = strongSelf.operations.removeFirst() {
                            if let replayedState = replayedState, !finalState.shouldPoll {
                                let events = AccountFinalStateEvents(state: replayedState)
                                if !events.isEmpty {
                                    strongSelf.insertProcessEvents(events)
                                }
                                if finalState.incomplete {
                                    strongSelf.operations.insert(.collectUpdateGroups(groups, 2.0), at: 0)
                                }
                            } else {
                                strongSelf.replaceOperations(with: .pollDifference(AccountFinalStateEvents()))
                            }
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                }, error: { _ in
                    assertionFailure()
                    trace("AccountStateManager", what: "processUpdateGroups signal completed with error")
                })
            case let .custom(operationId, signal):
                self.operationTimer?.invalidate()
                let completed: () -> Void = { [weak self] in
                    if let strongSelf = self {
                        if let topOperation = strongSelf.operations.first, case .custom(operationId, _) = topOperation {
                            strongSelf.operations.removeFirst()
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
            case let .processEvents(operationId, events):
                self.operationTimer?.invalidate()
                let completed: () -> Void = { [weak self] in
                    if let strongSelf = self {
                        if let topOperation = strongSelf.operations.first, case .processEvents(operationId, _) = topOperation {
                            if !events.updatedTypingActivities.isEmpty {
                                strongSelf.peerInputActivityManager.transaction { manager in
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
                            strongSelf.operations.removeFirst()
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                }
                
                let signal = self.account.postbox.modify { modifier -> [Message] in
                    let timestamp = Int32(self.account.network.context.globalTime())
                    var messages: [Message] = []
                    for id in events.addedIncomingMessageIds {
                        var notify = true
                        
                        if let notificationSettings = modifier.getPeerNotificationSettings(id.peerId) as? TelegramPeerNotificationSettings {
                            switch notificationSettings.muteState {
                            case let .muted(until):
                                if until >= timestamp {
                                    notify = false
                                }
                            case .unmuted:
                                break
                            }
                        } else {
                            trace("AccountStateManager", what: "notification settings for \(id.peerId) are undefined")
                        }
                        
                        if notify {
                            if let message = modifier.getMessage(id) {
                                var foundReadState = false
                                var isUnread = true
                                if let readState = modifier.getCombinedPeerReadState(id.peerId) {
                                    if readState.isIncomingMessageIndexRead(MessageIndex(message)) {
                                        isUnread = false
                                    }
                                    foundReadState = true
                                }
                                
                                if !foundReadState {
                                    trace("AccountStateManager", what: "read state for \(id.peerId) is undefined")
                                }
                                
                                if isUnread {
                                    messages.append(message)
                                }
                            } else {
                                trace("AccountStateManager", what: "notification message doesn't exist")
                            }
                        }
                    }
                    return messages
                }
                
                let _ = (signal |> deliverOn(self.queue)).start(next: { [weak self] messages in
                    if let strongSelf = self {
                        for message in messages {
                            print("notify: \(String(describing: messageMainPeer(message)?.displayTitle)): \(message.id)")
                        }
                        
                        strongSelf.notificationMessagesPipe.putNext(messages)
                    }
                }, error: { _ in
                    completed()
                }, completed: {
                    completed()
                })
            case let .pollCompletion(pollId, preSubscribers):
                if self.operations.count > 1 {
                    self.operations.removeFirst()
                    for (id, f) in preSubscribers {
                        let _ = self.addPollCompletion(f, id: id)
                    }
                    self.startFirstOperation()
                } else {
                    self.operationTimer?.invalidate()
                    let signal = self.account.network.request(Api.functions.help.test())
                        |> deliverOn(self.queue)
                    let completed: () -> Void = { [weak self] in
                        if let strongSelf = self {
                            if let topOperation = strongSelf.operations.first, case let .pollCompletion(topPollId, subscribers) = topOperation {
                                assert(topPollId == pollId)
                                
                                strongSelf.operations.removeFirst()
                                if strongSelf.operations.isEmpty {
                                    for (_, f) in subscribers {
                                        f()
                                    }
                                } else {
                                    for (id, f) in subscribers {
                                        let _ = strongSelf.addPollCompletion(f, id: id)
                                    }
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
        }
    }
    
    private func insertProcessEvents(_ events: AccountFinalStateEvents) {
        if !events.isEmpty {
            var index = 0
            if !self.operations.isEmpty {
                while case .processEvents = self.operations[index] {
                    index += 1
                }
            }
            self.operations.insert(.processEvents(self.getNextId(), events), at: 0)
        }
    }
    
    private func addPollCompletion(_ f: @escaping () -> Void, id: Int32?) -> Int32 {
        assert(self.queue.isCurrent())
        
        let updatedId: Int32
        if let id = id {
            updatedId = id
        } else {
            updatedId = self.getNextId()
        }
        
        if !self.operations.isEmpty {
            for i in 1 ..< self.operations.count {
                if case let .pollCompletion(pollId, subscribers) = self.operations[i] {
                    var subscribers = subscribers
                    subscribers.append((updatedId, f))
                    self.operations[i] = .pollCompletion(pollId, subscribers)
                    return updatedId
                }
            }
        }
        
        let beginFirst = self.operations.isEmpty
        self.operations.append(.pollCompletion(self.getNextId(), [(updatedId, f)]))
        if beginFirst {
            self.startFirstOperation()
        }
        
        return updatedId
    }
    
    private func removePollCompletion(_ id: Int32) {
        for i in 0 ..< self.operations.count {
            if case let .pollCompletion(pollId, subscribers) = self.operations[i] {
                for j in 0 ..< subscribers.count {
                    if subscribers[j].0 == id {
                        var subscribers = subscribers
                        subscribers.remove(at: j)
                        self.operations[i] = .pollCompletion(pollId, subscribers)
                        break
                    }
                }
            }
        }
    }
    
    public func wakeup() -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            if let strongSelf = self {
                strongSelf.queue.async {
                    let id = strongSelf.addPollCompletion({
                        subscriber.putCompletion()
                    }, id: nil)
                    
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
}
