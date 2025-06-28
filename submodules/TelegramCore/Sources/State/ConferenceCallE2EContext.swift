import Foundation
import SwiftSignalKit

public protocol ConferenceCallE2EContextState: AnyObject {
    func getEmojiState() -> Data?
    func getParticipantIds() -> [Int64]
    func getParticipants() -> [ConferenceCallE2EContext.BlockchainParticipant]
    func getParticipantLatencies() -> [Int64: Double]

    func applyBlock(block: Data)
    func applyBroadcastBlock(block: Data)
    
    func generateRemoveParticipantsBlock(participantIds: [Int64]) -> Data?

    func takeOutgoingBroadcastBlocks() -> [Data]

    func encrypt(message: Data, channelId: Int32, plaintextPrefixLength: Int) -> Data?
    func decrypt(message: Data, userId: Int64) -> Data?
}

public final class ConferenceCallE2EContext {
    public final class ContextStateHolder {
        public var state: ConferenceCallE2EContextState?
        public var pendingIncomingBroadcastBlocks: [Data] = []
        
        public init() {
        }
    }
    
    public struct BlockchainParticipant: Equatable {
        public let userId: Int64
        public let internalId: String
        
        public init(userId: Int64, internalId: String) {
            self.userId = userId
            self.internalId = internalId
        }
    }
    
    private final class Impl {
        private let queue: Queue

        private let engine: TelegramEngine
        private let callId: Int64
        private let accessHash: Int64
        private let userId: Int64
        private let reference: InternalGroupCallReference
        private let state: Atomic<ContextStateHolder>
        private let initializeState: (TelegramKeyPair, Int64, Data) -> ConferenceCallE2EContextState?
        private let keyPair: TelegramKeyPair

        let e2eEncryptionKeyHashValue = ValuePromise<Data?>(nil)
        let blockchainParticipantsValue = ValuePromise<[BlockchainParticipant]>([])

        private var e2ePoll0Offset: Int?
        private var e2ePoll0Timer: Foundation.Timer?
        private var e2ePoll0Disposable: Disposable?
        
        private var e2ePoll1Offset: Int?
        private var e2ePoll1Timer: Foundation.Timer?
        private var e2ePoll1Disposable: Disposable?

        private var isSynchronizingRemovedParticipants: Bool = false
        private var scheduledSynchronizeRemovedParticipants: Bool = false
        private var scheduledSynchronizeRemovedParticipantsAfterPoll: Bool = false
        private var synchronizeRemovedParticipantsDisposable: Disposable?
        private var synchronizeRemovedParticipantsTimer: Foundation.Timer?
        
        private var pendingKickPeers: [EnginePeer.Id] = []

        init(queue: Queue, engine: TelegramEngine, callId: Int64, accessHash: Int64, userId: Int64, reference: InternalGroupCallReference, state: Atomic<ContextStateHolder>, initializeState: @escaping (TelegramKeyPair, Int64, Data) -> ConferenceCallE2EContextState?, keyPair: TelegramKeyPair) {
            precondition(queue.isCurrent())
            precondition(Queue.mainQueue().isCurrent())

            self.queue = queue
            self.engine = engine
            self.callId = callId
            self.accessHash = accessHash
            self.userId = userId
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
            self.synchronizeRemovedParticipantsDisposable?.dispose()
            self.synchronizeRemovedParticipantsTimer?.invalidate()
        }

        func begin(initialState: JoinGroupCallResult.E2EState?) {
            self.scheduledSynchronizeRemovedParticipantsAfterPoll = true
            self.synchronizeRemovedParticipantsTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true, block: { [weak self] _ in
                guard let self else {
                    return
                }
                self.synchronizeRemovedParticipants()
            })
            
            if let initialState {
                self.e2ePoll0Offset = initialState.subChain0.offset
                self.e2ePoll1Offset = initialState.subChain1.offset
                self.addE2EBlocks(blocks: initialState.subChain0.blocks, subChainId: 0)
                self.addE2EBlocks(blocks: initialState.subChain1.blocks, subChainId: 1)
            }
            
            self.e2ePoll(subChainId: 0)
            self.e2ePoll(subChainId: 1)
        }

        func addChainBlocksUpdate(subChainId: Int, blocks: [Data], nextOffset: Int) {
            let updateBaseOffset = nextOffset - blocks.count
            var blocksToProcess: [Data] = []
            var shouldPoll = false
            for i in 0 ..< blocks.count {
                let blockOffset = updateBaseOffset + i
                if subChainId == 0 {
                    if var e2ePoll0Offset = self.e2ePoll0Offset {
                        if blockOffset == e2ePoll0Offset {
                            e2ePoll0Offset += 1
                            self.e2ePoll0Offset = e2ePoll0Offset
                            blocksToProcess.append(blocks[i])
                        }  else if blockOffset > e2ePoll0Offset {
                            shouldPoll = true
                        }
                    }
                } else if subChainId == 1 {
                    if var e2ePoll1Offset = self.e2ePoll1Offset {
                        if blockOffset == e2ePoll1Offset {
                            e2ePoll1Offset += 1
                            self.e2ePoll1Offset = e2ePoll1Offset
                            blocksToProcess.append(blocks[i])
                        } else if blockOffset > e2ePoll1Offset {
                            shouldPoll = true
                        }
                    }
                }
            }
            
            if !blocksToProcess.isEmpty {
                if subChainId == 0 {
                    if self.e2ePoll0Disposable != nil {
                        self.e2ePoll0Disposable?.dispose()
                        self.e2ePoll0Disposable = nil
                        shouldPoll = true
                    }
                } else if subChainId == 1 {
                    if self.e2ePoll1Disposable != nil {
                        self.e2ePoll1Disposable?.dispose()
                        self.e2ePoll1Disposable = nil
                        shouldPoll = true
                    }
                }
                self.addE2EBlocks(blocks: blocksToProcess, subChainId: subChainId)
            }
            
            if shouldPoll {
                self.e2ePoll(subChainId: subChainId)
            }
        }

        private func addE2EBlocks(blocks: [Data], subChainId: Int) {
            let keyPair = self.keyPair
            let userId = self.userId
            let initializeState = self.initializeState
            let (outBlocks, outEmoji, outBlockchainParticipants, participantLatencies) = self.state.with({ callState -> ([Data], Data, [BlockchainParticipant], [Int64: Double]) in
                if let state = callState.state {
                    for block in blocks {
                        if subChainId == 0 {
                            state.applyBlock(block: block)
                        } else if subChainId == 1 {
                            state.applyBroadcastBlock(block: block)
                        }
                    }
                    return (state.takeOutgoingBroadcastBlocks(), state.getEmojiState() ?? Data(), state.getParticipants(), state.getParticipantLatencies())
                } else {
                    if subChainId == 0 {
                        guard let block = blocks.last else {
                            return ([], Data(), [], [:])
                        }
                        guard let state = initializeState(keyPair, userId, block) else {
                            return ([], Data(), [], [:])
                        }
                        callState.state = state
                        for block in callState.pendingIncomingBroadcastBlocks {
                            state.applyBroadcastBlock(block: block)
                        }
                        callState.pendingIncomingBroadcastBlocks.removeAll()
                        return (state.takeOutgoingBroadcastBlocks(), state.getEmojiState() ?? Data(), state.getParticipants(), state.getParticipantLatencies())
                    } else if subChainId == 1 {
                        callState.pendingIncomingBroadcastBlocks.append(contentsOf: blocks)
                        return ([], Data(), [], [:])
                    } else {
                        return ([], Data(), [], [:])
                    }
                }
            })
            self.e2eEncryptionKeyHashValue.set(outEmoji.isEmpty ? nil : outEmoji)
            self.blockchainParticipantsValue.set(outBlockchainParticipants)
            
            for outBlock in outBlocks {
                let _ = self.engine.calls.sendConferenceCallBroadcast(callId: self.callId, accessHash: self.accessHash, block: outBlock).startStandalone()
            }
            
            #if DEBUG
            print("Latencies: \(participantLatencies)")
            #endif
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

                if subChainId == 0 {
                    self.e2ePoll0Disposable?.dispose()
                    self.e2ePoll0Disposable = nil
                } else if subChainId == 1 {
                    self.e2ePoll1Disposable?.dispose()
                    self.e2ePoll1Disposable = nil
                }
                
                var delayPoll = true
                if let result {
                    if subChainId == 0 {
                        if let e2ePoll0Offset = self.e2ePoll0Offset, e2ePoll0Offset < result.nextOffset {
                            self.e2ePoll0Offset = result.nextOffset
                            delayPoll = false
                        }
                    } else if subChainId == 1 {
                        if let e2ePoll1Offset = self.e2ePoll1Offset, e2ePoll1Offset < result.nextOffset {
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

                    if self.scheduledSynchronizeRemovedParticipantsAfterPoll {
                        self.scheduledSynchronizeRemovedParticipantsAfterPoll = false
                        self.synchronizeRemovedParticipants()
                    }
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
            if self.isSynchronizingRemovedParticipants {
                self.scheduledSynchronizeRemovedParticipants = true
                return
            }

            self.isSynchronizingRemovedParticipants = true

            let engine = self.engine
            let state = self.state
            let callId = self.callId
            let accessHash = self.accessHash
            let accountPeerId = engine.account.peerId
            
            if !self.pendingKickPeers.isEmpty {
                let pendingKickPeers = self.pendingKickPeers
                self.pendingKickPeers.removeAll()
                
                self.synchronizeRemovedParticipantsDisposable?.dispose()
                
                let removeBlock = state.with({ state -> Data? in
                    guard let state = state.state else {
                        return nil
                    }
                    let currentIds = state.getParticipantIds()
                    let remainingIds = pendingKickPeers.filter({ currentIds.contains($0.id._internalGetInt64Value()) })
                    if remainingIds.isEmpty {
                        return nil
                    }
                    
                    return state.generateRemoveParticipantsBlock(participantIds: remainingIds.map { $0.id._internalGetInt64Value() })
                })
                if let removeBlock {
                    self.synchronizeRemovedParticipantsDisposable = (engine.calls.removeGroupCallBlockchainParticipants(callId: callId, accessHash: accessHash, mode: .kick, participantIds: pendingKickPeers.map { $0.id._internalGetInt64Value() }, block: removeBlock)
                    |> map { result -> Bool in
                        switch result {
                        case .success:
                            return true
                        case .pollBlocksAndRetry:
                            return false
                        }
                    }
                    |> deliverOnMainQueue).startStrict(next: { [weak self] shouldRetry in
                        guard let self else {
                            return
                        }
                        
                        if shouldRetry {
                            for id in pendingKickPeers {
                                if !self.pendingKickPeers.contains(id) {
                                    self.pendingKickPeers.append(id)
                                }
                            }
                        }
                        
                        self.isSynchronizingRemovedParticipants = false
                        if self.scheduledSynchronizeRemovedParticipants {
                            self.scheduledSynchronizeRemovedParticipants = false
                            self.synchronizeRemovedParticipants()
                        } else if shouldRetry && !self.scheduledSynchronizeRemovedParticipantsAfterPoll {
                            self.scheduledSynchronizeRemovedParticipantsAfterPoll = true
                            self.e2ePoll(subChainId: 0)
                        }
                    })
                } else {
                    self.isSynchronizingRemovedParticipants = false
                    if self.scheduledSynchronizeRemovedParticipants {
                        self.scheduledSynchronizeRemovedParticipants = false
                        self.synchronizeRemovedParticipants()
                    }
                }
            } else {
                self.synchronizeRemovedParticipantsDisposable?.dispose()
                self.synchronizeRemovedParticipantsDisposable = (_internal_getGroupCallParticipants(
                    account: self.engine.account,
                    reference: self.reference,
                    offset: "",
                    ssrcs: [],
                    limit: 100,
                    sortAscending: true
                )
                |> map(Optional.init)
                |> `catch` { _ -> Signal<GroupCallParticipantsContext.State?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Bool, NoError> in
                    guard let result else {
                        return .single(false)
                    }
                    
                    let blockchainPeerIds = state.with { state -> [Int64] in
                        guard let state = state.state else {
                            return []
                        }
                        return state.getParticipantIds()
                    }
                    
                    // Peer ids that are in the blockchain but not in the server list
                    var removedPeerIds = blockchainPeerIds.filter { blockchainPeerId in
                        return !result.participants.contains(where: { participant in
                            if case let .peer(id) = participant.id, id.namespace == Namespaces.Peer.CloudUser, id.id._internalGetInt64Value() == blockchainPeerId {
                                return true
                            } else {
                                return false
                            }
                        })
                    }
                    removedPeerIds.removeAll(where: { $0 == accountPeerId.id._internalGetInt64Value() })
                    
                    if removedPeerIds.isEmpty {
                        return .single(false)
                    }
                    guard let removeBlock = state.with({ state -> Data? in
                        guard let state = state.state else {
                            return nil
                        }
                        return state.generateRemoveParticipantsBlock(participantIds: removedPeerIds)
                    }) else {
                        return .single(false)
                    }
                    
                    return engine.calls.removeGroupCallBlockchainParticipants(callId: callId, accessHash: accessHash, mode: .cleanup, participantIds: removedPeerIds, block: removeBlock)
                    |> map { result -> Bool in
                        switch result {
                        case .success:
                            return true
                        case .pollBlocksAndRetry:
                            return false
                        }
                    }
                }
                |> deliverOn(self.queue)).startStrict(next: { [weak self] shouldRetry in
                    guard let self else {
                        return
                    }
                    self.isSynchronizingRemovedParticipants = false
                    if self.scheduledSynchronizeRemovedParticipants {
                        self.scheduledSynchronizeRemovedParticipants = false
                        self.synchronizeRemovedParticipants()
                    } else if shouldRetry && !self.scheduledSynchronizeRemovedParticipantsAfterPoll {
                        self.scheduledSynchronizeRemovedParticipantsAfterPoll = true
                        self.e2ePoll(subChainId: 0)
                    }
                })
            }
        }
        
        func kickPeer(id: EnginePeer.Id) {
            if !self.pendingKickPeers.contains(id) {
                self.pendingKickPeers.append(id)
                
                self.synchronizeRemovedParticipants()
            }
        }
    }

    public let state: Atomic<ContextStateHolder> = Atomic(value: ContextStateHolder())
    private let impl: QueueLocalObject<Impl>

    public var e2eEncryptionKeyHash: Signal<Data?, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.e2eEncryptionKeyHashValue.get().start(next: subscriber.putNext)
        }
    }
    
    public var blockchainParticipants: Signal<[BlockchainParticipant], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.blockchainParticipantsValue.get().start(next: subscriber.putNext)
        }
    }

    public init(engine: TelegramEngine, callId: Int64, accessHash: Int64, userId: Int64, reference: InternalGroupCallReference, keyPair: TelegramKeyPair, initializeState: @escaping (TelegramKeyPair, Int64, Data) -> ConferenceCallE2EContextState?) {
        let queue = Queue.mainQueue()
        let state = self.state
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, engine: engine, callId: callId, accessHash: accessHash, userId: userId, reference: reference, state: state, initializeState: initializeState, keyPair: keyPair)
        })
    }

    public func begin(initialState: JoinGroupCallResult.E2EState?) {
        self.impl.with { impl in
            impl.begin(initialState: initialState)
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
    
    public func kickPeer(id: EnginePeer.Id) {
        self.impl.with { impl in
            impl.kickPeer(id: id)
        }
    }
}
