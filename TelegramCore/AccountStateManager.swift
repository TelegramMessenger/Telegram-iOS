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
    case custom(Signal<Void, NoError>)
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
    
    private var updateService: UpdateMessageService?
    private let updateServiceDisposable = MetaDisposable()
    
    private var operations: [AccountStateManagerOperation] = []
    private let operationDisposable = MetaDisposable()
    private var operationTimer: SignalKitTimer?
    
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
    
    init(account: Account) {
        self.account = account
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
            self.operations.removeAll()
            self.addOperation(.pollDifference(AccountFinalStateEvents()))
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
                    case .pollDifference, .processUpdateGroups, .custom:
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
            
            self.addOperation(.custom(signal))
            
            return disposable
        } |> runOn(self.queue)
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
                self.currentIsUpdatingValue = true
                let account = self.account
                let queue = self.queue
                let signal = account.postbox.state()
                    |> filter { state in
                        if let _ = state as? AuthorizedAccountState {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> take(1)
                    |> mapToSignal { state -> Signal<(Api.updates.Difference?, AccountFinalState?), NoError> in
                        if let authorizedState = (state as! AuthorizedAccountState).state {
                            let request = account.network.request(Api.functions.updates.getDifference(flags: 0, pts: authorizedState.pts, ptsTotalLimit: nil, date: authorizedState.date, qts: authorizedState.qts))
                                |> retryRequest
                            return request |> mapToSignal { difference -> Signal<(Api.updates.Difference?, AccountFinalState?), NoError> in
                                return initialStateWithDifference(account, difference: difference)
                                    |> mapToSignal { state -> Signal<(Api.updates.Difference?, AccountFinalState?), NoError> in
                                        if state.initialState.state != authorizedState {
                                            trace("State", what: "pollDifference initial state \(authorizedState) != current state \(state.initialState.state)")
                                            return .single((nil, nil))
                                        } else {
                                            return finalStateWithDifference(account: account, state: state, difference: difference)
                                                |> mapToSignal { finalState -> Signal<(Api.updates.Difference?, AccountFinalState?), NoError> in
                                                    if !finalState.state.preCachedResources.isEmpty {
                                                        for (resource, data) in finalState.state.preCachedResources {
                                                            account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                                                        }
                                                    }
                                                    return account.postbox.modify { modifier -> (Api.updates.Difference?, AccountFinalState?) in
                                                        if replayFinalState(modifier, finalState: finalState.state) {
                                                            return (difference, finalState)
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
                                    return account.postbox.modify { modifier -> (Api.updates.Difference?, AccountFinalState?) in
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
                signal.start(next: { [weak self] difference, finalState in
                    if let strongSelf = self {
                        if case let .pollDifference = strongSelf.operations.removeFirst() {
                            let events: AccountFinalStateEvents
                            if let finalState = finalState {
                                events = currentEvents.union(with: AccountFinalStateEvents(state: finalState.state))
                            } else {
                                events = currentEvents
                            }
                            if let difference = difference {
                                switch difference {
                                    case .differenceSlice:
                                        strongSelf.operations.insert(.pollDifference(events), at: 0)
                                    default:
                                        if !events.isEmpty {
                                            strongSelf.addEvents(events)
                                        }
                                        strongSelf.currentIsUpdatingValue = false
                                }
                            } else {
                                if !events.isEmpty {
                                    strongSelf.addEvents(events)
                                }
                                strongSelf.operations.removeAll()
                                strongSelf.operations.append(.pollDifference(AccountFinalStateEvents()))
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
            case let .collectUpdateGroups(groups, timeout):
                self.operationTimer?.invalidate()
                let operationTimer = SignalKitTimer(timeout: timeout, repeat: false, completion: { [weak self] in
                    if let strongSelf = self {
                        if case let .collectUpdateGroups(groups, _) = strongSelf.operations[0] {
                            if timeout.isEqual(to: 0.0) {
                                strongSelf.operations[0] = .processUpdateGroups(groups)
                            } else {
                                trace("AccountStateManager", what: "timeout while waiting for updates")
                                strongSelf.operations.removeAll()
                                strongSelf.operations.append(.pollDifference(AccountFinalStateEvents()))
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
                let account = self.account
                let queue = self.queue
                let signal = initialStateWithUpdateGroups(account, groups: groups)
                    |> mapToSignal { [weak self] state -> Signal<(Bool, AccountFinalState), NoError> in
                        return finalStateWithUpdateGroups(account, state: state, groups: groups)
                            |> mapToSignal { finalState in
                                if !finalState.state.preCachedResources.isEmpty {
                                    for (resource, data) in finalState.state.preCachedResources {
                                        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                                    }
                                }
                                
                                return account.postbox.modify { modifier -> Bool in
                                    return replayFinalState(modifier, finalState: finalState.state)
                                }
                                |> map({ ($0, finalState) })
                                |> deliverOn(queue)
                            }
                    }
                signal.start(next: { [weak self] result, finalState in
                    if let strongSelf = self {
                        if case let .processUpdateGroups(groups) = strongSelf.operations.removeFirst() {
                            if result && !finalState.shouldPoll {
                                let events = AccountFinalStateEvents(state: finalState.state)
                                if !events.isEmpty {
                                    strongSelf.addEvents(events)
                                }
                                if finalState.incomplete {
                                    strongSelf.operations.insert(.collectUpdateGroups(groups, 2.0), at: 0)
                                }
                            } else {
                                strongSelf.operations.removeAll()
                                strongSelf.operations.append(.pollDifference(AccountFinalStateEvents()))
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
            case let .custom(signal):
                let completed: () -> Void = { [weak self] in
                    if let strongSelf = self {
                        if case .custom = strongSelf.operations.removeFirst() {
                            strongSelf.startFirstOperation()
                        } else {
                            assertionFailure()
                        }
                    }
                }
                signal.start(error: { _ in
                    completed()
                }, completed: {
                    completed()
                })
        }
    }
    
    private func addEvents(_ events: AccountFinalStateEvents) {
        if !events.addedIncomingMessageIds.isEmpty {
            (self.account.postbox.modify { modifier -> [Message] in
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
                    
                    var foundReadState = false
                    if let readStates = modifier.getPeerReadStates(id.peerId) {
                        for (namespace, readState) in readStates {
                            if namespace == id.namespace {
                                if id.id <= readState.maxIncomingReadId {
                                    notify = false
                                }
                                foundReadState = true
                                break
                            }
                        }
                    }
                    
                    if !foundReadState {
                        trace("AccountStateManager", what: "read state for \(id.peerId) is undefined")
                    }
                    
                    if notify {
                        if let message = modifier.getMessage(id) {
                            messages.append(message)
                        } else {
                            trace("AccountStateManager", what: "notification message doesn't exist")
                        }
                    }
                }
                return messages
            }).start(next: { [weak self] messages in
                if let strongSelf = self {
                    for message in messages {
                        print("notify: \(message.peers[message.id.peerId]?.displayTitle): \(message.text)")
                    }
                    
                    strongSelf.notificationMessagesPipe.putNext(messages)
                }
            })
        }
    }
}
