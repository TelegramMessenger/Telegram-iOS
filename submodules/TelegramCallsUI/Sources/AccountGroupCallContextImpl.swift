import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

public final class AccountGroupCallContextImpl: AccountGroupCallContext {
    public final class Proxy {
        public let context: AccountGroupCallContextImpl
        let removed: () -> Void
        
        public init(context: AccountGroupCallContextImpl, removed: @escaping () -> Void) {
            self.context = context
            self.removed = removed
        }
        
        deinit {
            self.removed()
        }
        
        public func keep() {
        }
    }
    
    var disposable: Disposable?
    public var participantsContext: GroupCallParticipantsContext?
    
    private let panelDataPromise = Promise<GroupCallPanelData?>()
    public var panelData: Signal<GroupCallPanelData?, NoError> {
        return self.panelDataPromise.get()
    }
    
    public init(account: Account, engine: TelegramEngine, peerId: EnginePeer.Id?, isChannel: Bool, call: EngineGroupCallDescription) {
        self.panelDataPromise.set(.single(nil))
        let state = engine.calls.getGroupCallParticipants(reference: .id(id: call.id, accessHash: call.accessHash), offset: "", ssrcs: [], limit: 100, sortAscending: nil)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<GroupCallParticipantsContext.State?, NoError> in
            return .single(nil)
        }
        
        let peer: Signal<EnginePeer?, NoError>
        if let peerId {
            peer = engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        } else {
            peer = .single(nil)
        }
        self.disposable = (combineLatest(queue: .mainQueue(),
            state,
            peer
        )
        |> deliverOnMainQueue).start(next: { [weak self] state, peer in
            guard let self, let state = state else {
                return
            }
            let context = engine.calls.groupCall(
                peerId: peerId,
                myPeerId: account.peerId,
                id: call.id,
                reference: .id(id: call.id, accessHash: call.accessHash),
                state: state,
                previousServiceState: nil,
                e2eContext: nil
            )
            
            self.participantsContext = context
            
            if let peerId {
                self.panelDataPromise.set(combineLatest(queue: .mainQueue(),
                    context.state,
                    context.activeSpeakers
                )
                |> map { state, activeSpeakers -> GroupCallPanelData in
                    var topParticipants: [GroupCallParticipantsContext.Participant] = []
                    for participant in state.participants {
                        if topParticipants.count >= 3 {
                            break
                        }
                        topParticipants.append(participant)
                    }
                    
                    var isChannel = false
                    if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                        isChannel = true
                    }
                    
                    return GroupCallPanelData(
                        peerId: peerId,
                        isChannel: isChannel,
                        info: GroupCallInfo(
                            id: call.id,
                            accessHash: call.accessHash,
                            participantCount: state.totalCount,
                            streamDcId: nil,
                            title: state.title,
                            scheduleTimestamp: state.scheduleTimestamp,
                            subscribedToScheduled: state.subscribedToScheduled,
                            recordingStartTimestamp: nil,
                            sortAscending: state.sortAscending,
                            defaultParticipantsAreMuted: state.defaultParticipantsAreMuted,
                            messagesAreEnabled: state.messagesAreEnabled,
                            isVideoEnabled: state.isVideoEnabled,
                            unmutedVideoLimit: state.unmutedVideoLimit,
                            isStream: state.isStream,
                            isCreator: state.isCreator
                        ),
                        topParticipants: topParticipants,
                        participantCount: state.totalCount,
                        activeSpeakers: activeSpeakers,
                        groupCall: nil
                    )
                })
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

public final class AccountGroupCallContextCacheImpl: AccountGroupCallContextCache {
    public class Impl {
        private class Record {
            let context: AccountGroupCallContextImpl
            let subscribers = Bag<Void>()
            var removeTimer: SwiftSignalKit.Timer?
            
            init(context: AccountGroupCallContextImpl) {
                self.context = context
            }
        }
        
        private let queue: Queue
        private var contexts: [Int64: Record] = [:]

        private let leaveDisposables = DisposableSet()
        
        init(queue: Queue) {
            self.queue = queue
        }
        
        public func get(account: Account, engine: TelegramEngine, peerId: EnginePeer.Id, isChannel: Bool, call: EngineGroupCallDescription) -> AccountGroupCallContextImpl.Proxy {
            let result: Record
            if let current = self.contexts[call.id] {
                result = current
            } else {
                let context = AccountGroupCallContextImpl(account: account, engine: engine, peerId: peerId, isChannel: isChannel, call: call)
                result = Record(context: context)
                self.contexts[call.id] = result
            }
            
            let index = result.subscribers.add(Void())
            result.removeTimer?.invalidate()
            result.removeTimer = nil
            return AccountGroupCallContextImpl.Proxy(context: result.context, removed: { [weak self, weak result] in
                Queue.mainQueue().async {
                    if let strongResult = result, let self, self.contexts[call.id] === strongResult {
                        strongResult.subscribers.remove(index)
                        if strongResult.subscribers.isEmpty {
                            let removeTimer = SwiftSignalKit.Timer(timeout: 30, repeat: false, completion: { [weak self] in
                                if let result = result, let self, self.contexts[call.id] === result, result.subscribers.isEmpty {
                                    self.contexts.removeValue(forKey: call.id)
                                }
                            }, queue: .mainQueue())
                            strongResult.removeTimer = removeTimer
                            removeTimer.start()
                        }
                    }
                }
            })
        }

        public func leaveInBackground(engine: TelegramEngine, id: Int64, accessHash: Int64, source: UInt32) {
            let disposable = engine.calls.leaveGroupCall(callId: id, accessHash: accessHash, source: source).start(completed: { [weak self] in
                guard let self else {
                    return
                }
                if let context = self.contexts[id] {
                    context.context.participantsContext?.removeLocalPeerId()
                }
            })
            self.leaveDisposables.add(disposable)
        }
    }
    
    let queue: Queue = .mainQueue()
    public let impl: QueueLocalObject<Impl>
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
}
