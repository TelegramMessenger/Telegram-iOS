import Foundation
import SwiftSignalKit

public protocol ConferenceCallE2EContextState: AnyObject {
    func getEmojiState() -> Data?

    func applyBlock(block: Data)
    func applyBroadcastBlock(block: Data)

    func takeOutgoingBroadcastBlocks() -> [Data]

    func encrypt(message: Data) -> Data?
    func decrypt(message: Data) -> Data?
}

public final class ConferenceCallE2EContext {
    public final class ContextStateHolder {
        public var state: ConferenceCallE2EContextState?
        public var pendingIncomingBroadcastBlocks: [Data] = []
        
        public init() {
        }
    }
    
    private final class Impl {
        private let queue: Queue

        private let engine: TelegramEngine
        private let callId: Int64
        private let accessHash: Int64
        private let reference: InternalGroupCallReference
        private let state: Atomic<ContextStateHolder>
        private let initializeState: (TelegramKeyPair, Data) -> ConferenceCallE2EContextState?
        private let keyPair: TelegramKeyPair

        let e2eEncryptionKeyHashValue = ValuePromise<Data?>(nil)

        private var e2ePoll0Offset: Int?
        private var e2ePoll0Timer: Foundation.Timer?
        private var e2ePoll0Disposable: Disposable?
        
        private var e2ePoll1Offset: Int?
        private var e2ePoll1Timer: Foundation.Timer?
        private var e2ePoll1Disposable: Disposable?

        init(queue: Queue, engine: TelegramEngine, callId: Int64, accessHash: Int64, reference: InternalGroupCallReference, state: Atomic<ContextStateHolder>, initializeState: @escaping (TelegramKeyPair, Data) -> ConferenceCallE2EContextState?, keyPair: TelegramKeyPair) {
            precondition(queue.isCurrent())
            precondition(Queue.mainQueue().isCurrent())

            self.queue = queue
            self.engine = engine
            self.callId = callId
            self.accessHash = accessHash
            self.reference = reference
            self.state = state
            self.initializeState = initializeState
            self.keyPair = keyPair
        }

        deinit {
            self.e2ePoll0Timer?.invalidate()
            self.e2ePoll0Disposable?.dispose()
            self.e2ePoll1Timer?.invalidate()
            self.e2ePoll1Disposable?.dispose()
        }

        func begin() {
            self.e2ePoll(subChainId: 0)
            self.e2ePoll(subChainId: 1)
        }

        func addChainBlocksUpdate(subChainId: Int, blocks: [Data], nextOffset: Int) {
            var processBlock = true
            let updateBaseOffset = nextOffset - blocks.count
            if subChainId == 0 {
                if let e2ePoll0Offset = self.e2ePoll0Offset {
                    if e2ePoll0Offset == updateBaseOffset {
                        self.e2ePoll0Offset = nextOffset
                    } else if e2ePoll0Offset < updateBaseOffset {
                        self.e2ePoll(subChainId: subChainId)
                    } else {
                        processBlock = false
                    }
                } else {
                    processBlock = false
                }
            } else if subChainId == 1 {
                if let e2ePoll1Offset = self.e2ePoll1Offset {
                    if e2ePoll1Offset == updateBaseOffset {
                        self.e2ePoll1Offset = nextOffset
                    } else if e2ePoll1Offset < updateBaseOffset {
                        self.e2ePoll(subChainId: subChainId)
                    } else {
                        processBlock = false
                    }
                } else {
                    processBlock = false
                }
            } else {
                processBlock = false
            }
            if processBlock {
                self.addE2EBlocks(blocks: blocks, subChainId: subChainId)
            }
        }

        private func addE2EBlocks(blocks: [Data], subChainId: Int) {
            let keyPair = self.keyPair
            let initializeState = self.initializeState
            let (outBlocks, outEmoji) = self.state.with({ callState -> ([Data], Data) in
                if let state = callState.state {
                    for block in blocks {
                        if subChainId == 0 {
                            state.applyBlock(block: block)
                        } else if subChainId == 1 {
                            state.applyBroadcastBlock(block: block)
                        }
                    }
                    return (state.takeOutgoingBroadcastBlocks(), state.getEmojiState() ?? Data())
                } else {
                    if subChainId == 0 {
                        guard let block = blocks.last else {
                            return ([], Data())
                        }
                        guard let state = initializeState(keyPair, block) else {
                            return ([], Data())
                        }
                        callState.state = state
                        for block in callState.pendingIncomingBroadcastBlocks {
                            state.applyBroadcastBlock(block: block)
                        }
                        callState.pendingIncomingBroadcastBlocks.removeAll()
                        return (state.takeOutgoingBroadcastBlocks(), state.getEmojiState() ?? Data())
                    } else if subChainId == 1 {
                        callState.pendingIncomingBroadcastBlocks.append(contentsOf: blocks)
                        return ([], Data())
                    } else {
                        return ([], Data())
                    }
                }
            })
            self.e2eEncryptionKeyHashValue.set(outEmoji.isEmpty ? nil : outEmoji)
            
            for outBlock in outBlocks {
                //TODO:release queue
                let _ = self.engine.calls.sendConferenceCallBroadcast(callId: self.callId, accessHash: self.accessHash, block: outBlock).startStandalone()
            }
        }
    
        private func e2ePoll(subChainId: Int) {
            let offset: Int?
            if subChainId == 0 {
                offset = self.e2ePoll0Offset
                self.e2ePoll0Disposable?.dispose()
            } else if subChainId == 1 {
                offset = self.e2ePoll1Offset
                self.e2ePoll1Disposable?.dispose()
            } else {
                return
            }
            
            let disposable = (self.engine.calls.pollConferenceCallBlockchain(reference: self.reference, subChainId: subChainId, offset: offset ?? 0, limit: 10)
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                var delayPoll = true
                if let result {
                    if subChainId == 0 {
                        if self.e2ePoll0Offset != result.nextOffset {
                            self.e2ePoll0Offset = result.nextOffset
                            delayPoll = false
                        }
                    } else if subChainId == 1 {
                        if self.e2ePoll1Offset != result.nextOffset {
                            self.e2ePoll1Offset = result.nextOffset
                            delayPoll = false
                        }
                    }
                    self.addE2EBlocks(blocks: result.blocks, subChainId: subChainId)
                }
                
                if subChainId == 0 {
                    self.e2ePoll0Timer?.invalidate()
                    self.e2ePoll0Timer = Foundation.Timer.scheduledTimer(withTimeInterval: delayPoll ? 1.0 : 0.0, repeats: false, block: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.e2ePoll(subChainId: 0)
                    })
                } else if subChainId == 1 {
                    self.e2ePoll1Timer?.invalidate()
                    self.e2ePoll1Timer = Foundation.Timer.scheduledTimer(withTimeInterval: delayPoll ? 1.0 : 0.0, repeats: false, block: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.e2ePoll(subChainId: 1)
                    })
                }
            })

            if subChainId == 0 {
                self.e2ePoll0Disposable = disposable
            } else if subChainId == 1 {
                self.e2ePoll1Disposable = disposable
            }
        }

        func synchronizeRemovedParticipants() {
            
        }
    }

    public let state: Atomic<ContextStateHolder> = Atomic(value: ContextStateHolder())
    private let impl: QueueLocalObject<Impl>

    public var e2eEncryptionKeyHash: Signal<Data?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.e2eEncryptionKeyHashValue.get().start(next: subscriber.putNext)
        }
    }

    public init(engine: TelegramEngine, callId: Int64, accessHash: Int64, reference: InternalGroupCallReference, keyPair: TelegramKeyPair, initializeState: @escaping (TelegramKeyPair, Data) -> ConferenceCallE2EContextState?) {
        let queue = Queue.mainQueue()
        let state = self.state
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, engine: engine, callId: callId, accessHash: accessHash, reference: reference, state: state, initializeState: initializeState, keyPair: keyPair)
        })
    }

    public func begin() {
        self.impl.with { impl in
            impl.begin()
        }
    }

    public func addChainBlocksUpdate(subChainId: Int, blocks: [Data], nextOffset: Int) {
        self.impl.with { impl in
            impl.addChainBlocksUpdate(subChainId: subChainId, blocks: blocks, nextOffset: nextOffset)
        }
    }

    public func synchronizeRemovedParticipants() {
        self.impl.with { impl in
            impl.synchronizeRemovedParticipants()
        }
    }
}
