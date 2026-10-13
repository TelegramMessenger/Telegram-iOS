import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class ManagedSynchronizeChatInputStateOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    var peerMediaNeeds: [PeerId: MediaPreuploadNeeds] = [:]

    private let hasRunningOperations: ValuePromise<Bool>
    
    init(hasRunningOperations: ValuePromise<Bool>) {
        self.hasRunningOperations = hasRunningOperations
    }
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = disposable
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, disposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(disposable)
            }
        }
        
        for mergedIndex in removeMergedIndices {
            self.operationDisposables.removeValue(forKey: mergedIndex)
        }
        
        self.hasRunningOperations.set(!self.operationDisposables.isEmpty)
        
        return (disposeOperations, beginOperations)
    }
    
    func updatePeerMediaNeeds(peerId: PeerId, media: [Media], network: Network, postbox: Postbox, messageMediaPreuploadManager: MessageMediaPreuploadManager) {
        // The DURABLE holder: driven by the PERSISTED draft, so an upload outlives the editor
        // screen, the chat controller, and leaving the chat entirely.
        //
        // Reconciliation itself (add before dispose, so a surviving medium never drops to zero
        // holders) lives in MediaPreuploadNeeds, shared with the editor screens — one
        // implementation, so the durable and transient holders cannot drift apart.
        if media.isEmpty {
            // Dropping the last reference releases every need it held.
            self.peerMediaNeeds.removeValue(forKey: peerId)
            return
        }
        let needs: MediaPreuploadNeeds
        if let existing = self.peerMediaNeeds[peerId] {
            needs = existing
        } else {
            needs = MediaPreuploadNeeds(network: network, postbox: postbox, manager: messageMediaPreuploadManager)
            self.peerMediaNeeds[peerId] = needs
        }
        needs.update(peerId: peerId, media: media.map(EngineMedia.init))
    }

    func reset() -> [Disposable] {
        // Each MediaPreuploadNeeds releases its needs on deinit.
        self.peerMediaNeeds.removeAll()
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeChatInputStateOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
    } |> switchToLatest
}

func managedSynchronizeChatInputStateOperations(postbox: Postbox, network: Network, messageMediaPreuploadManager: MessageMediaPreuploadManager, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<Bool, NoError> {
    return Signal { subscriber in
        let hasRunningOperations = ValuePromise<Bool>(false, ignoreRepeated: true)
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeChatInputStates
        
        let helper = Atomic<ManagedSynchronizeChatInputStateOperationsHelper>(value: ManagedSynchronizeChatInputStateOperationsHelper(hasRunningOperations: hasRunningOperations))
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeChatInputStateOperation {
                            return synchronizeChatInputState(transaction: transaction, postbox: postbox, network: network, messageMediaPreuploadManager: messageMediaPreuploadManager, auxiliaryMethods: auxiliaryMethods, helper: helper, peerId: entry.peerId, threadId: operation.threadId, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                })
                
                disposable.set(signal.start())
            }
        })
        
        let statusDisposable = hasRunningOperations.get().start(next: { value in
            subscriber.putNext(value)
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
            statusDisposable.dispose()
        }
    }
}

private func synchronizeChatInputState(transaction: Transaction, postbox: Postbox, network: Network, messageMediaPreuploadManager: MessageMediaPreuploadManager, auxiliaryMethods: AccountAuxiliaryMethods, helper: Atomic<ManagedSynchronizeChatInputStateOperationsHelper>, peerId: PeerId, threadId: Int64?, operation: SynchronizeChatInputStateOperation) -> Signal<Void, NoError> {
    var inputState: SynchronizeableChatInputState?
    let peerChatInterfaceState: StoredPeerChatInterfaceState?
    if let threadId {
        peerChatInterfaceState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId)
    } else {
        peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId)
    }
    
    if let peerChatInterfaceState = peerChatInterfaceState, let data = peerChatInterfaceState.data {
        inputState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
    }

    var draftMedia: [Media] = []
    if case let .instantPage(page) = inputState?.content {
        for (_, media) in page.media where isPreuploadableMedia(media) {
            draftMedia.append(media)
        }
    }
    helper.with { helperValue in
        helperValue.updatePeerMediaNeeds(peerId: peerId, media: draftMedia, network: network, postbox: postbox, messageMediaPreuploadManager: messageMediaPreuploadManager)
    }

    if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
        var flags: Int32 = 0
        if let inputState = inputState {
            if !inputState.entities.isEmpty {
                flags |= (1 << 3)
            }
        }
        var topMsgId: Int32?
        var monoforumPeerId: Api.InputPeer?
        if let threadId {
            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                monoforumPeerId = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
            } else {
                topMsgId = Int32(clamping: threadId)
            }
        }
        
        var replyTo: Api.InputReplyTo?
        if let replySubject = inputState?.replySubject {
            flags |= 1 << 0
            
            var innerFlags: Int32 = 0
            if topMsgId != nil {
                innerFlags |= 1 << 0
            } else if monoforumPeerId != nil {
                innerFlags |= 1 << 5
            }
            
            var replyToPeer: Api.InputPeer?
            var discard = false
            if outgoingReplyRequiresExplicitPeer(destinationPeer: peer, destinationThreadId: threadId, replyMessageId: replySubject.messageId, replyThreadId: transaction.getMessage(replySubject.messageId)?.threadId) {
                replyToPeer = transaction.getPeer(replySubject.messageId.peerId).flatMap(apiInputPeer)
                if replyToPeer == nil {
                    discard = true
                }
            }
            
            var quoteText: String?
            var quoteEntities: [Api.MessageEntity]?
            var quoteOffset: Int32?
            if let replyQuote = replySubject.quote {
                quoteText = replyQuote.text
                quoteOffset = replyQuote.offset.flatMap { Int32(clamping: $0) }
                
                if !replyQuote.entities.isEmpty {
                    var associatedPeers = SimpleDictionary<PeerId, Peer>()
                    for entity in replyQuote.entities {
                        for associatedPeerId in entity.associatedPeerIds {
                            if associatedPeers[associatedPeerId] == nil {
                                if let associatedPeer = transaction.getPeer(associatedPeerId) {
                                    associatedPeers[associatedPeerId] = associatedPeer
                                }
                            }
                        }
                    }
                    quoteEntities = apiEntitiesFromMessageTextEntities(replyQuote.entities, associatedPeers: associatedPeers)
                }
            }
            
            var replyTodoItemId: Int32?
            var replyPollOption: Buffer?
            switch replySubject.innerSubject {
            case let .todoItem(todoItemId):
                replyTodoItemId = todoItemId
            case let .pollOption(pollOption):
                replyPollOption = Buffer(data: pollOption)
            default:
                break
            }
            
            if replyToPeer != nil {
                innerFlags |= 1 << 1
            }
            if quoteText != nil {
                innerFlags |= 1 << 2
            }
            if quoteEntities != nil {
                innerFlags |= 1 << 3
            }
            if quoteOffset != nil {
                innerFlags |= 1 << 4
            }
            if let _ = replyTodoItemId {
                innerFlags |= 1 << 6
            }
            if let _ = replyPollOption {
                innerFlags |= 1 << 7
            }
            if !discard {
                replyTo = .inputReplyToMessage(.init(flags: innerFlags, replyToMsgId: replySubject.messageId.id, topMsgId: topMsgId, replyToPeerId: replyToPeer, quoteText: quoteText, quoteEntities: quoteEntities, quoteOffset: quoteOffset, monoforumPeerId: monoforumPeerId, todoItemId: replyTodoItemId, pollOption: replyPollOption))
            }
        } else if let topMsgId {
            flags |= 1 << 0
            
            var innerFlags: Int32 = 0
            innerFlags |= 1 << 0
            replyTo = .inputReplyToMessage(.init(flags: innerFlags, replyToMsgId: topMsgId, topMsgId: topMsgId, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: nil, todoItemId: nil, pollOption: nil))
        } else if let monoforumPeerId {
            flags |= 1 << 0
            replyTo = .inputReplyToMonoForum(.init(monoforumPeerId: monoforumPeerId))
        }
        
        let suggestedPost = inputState?.suggestedPost.flatMap { suggestedPost -> Api.SuggestedPost in
            var flags: Int32 = 0
            if suggestedPost.timestamp != nil {
                flags |= 1 << 0
            }
            return .suggestedPost(.init(flags: flags, price: suggestedPost.price?.apiAmount ?? .starsAmount(.init(amount: 0, nanos: 0)), scheduleDate: suggestedPost.timestamp))
        }
        if suggestedPost != nil {
            flags |= 1 << 8
        }

        var richText: RichTextMessageAttribute?
        if case let .instantPage(page) = inputState?.content {
            richText = RichTextMessageAttribute(instantPage: page, fullInstantPage: nil)
        }

        let savedMessage = inputState?.text ?? ""
        let savedEntities = apiEntitiesFromMessageTextEntities(inputState?.entities ?? [], associatedPeers: SimpleDictionary())

        return uploadedRichMessage(network: network, postbox: postbox, auxiliaryMethods: auxiliaryMethods, messageMediaPreuploadManager: messageMediaPreuploadManager, forceReupload: false, peerId: peerId, richText: richText)
        |> mapToSignal { apiRichMessage -> Signal<Void, NoError> in
            var flags = flags
            let requestMessage: String
            let requestEntities: [Api.MessageEntity]
            if apiRichMessage != nil {
                flags |= 1 << 9
                // The rich content (text + structure) is fully carried by `richMessage`; the flat
                // `message`/`entities` would duplicate the text the InstantPage already holds, and the
                // receiver ignores them when `richMessage` is present (AccountStateManagementUtils draft
                // parse builds `.instantPage` purely from `richMessage`). Send them empty + clear the
                // entities flag, mirroring the send path's `.message(text: "", ...)` for rich content.
                flags &= ~(Int32(1) << 3)
                requestMessage = ""
                requestEntities = []
            } else {
                requestMessage = savedMessage
                requestEntities = savedEntities
            }
            return network.request(Api.functions.messages.saveDraft(flags: flags, replyTo: replyTo, peer: inputPeer, message: requestMessage, entities: requestEntities, media: nil, effect: nil, suggestedPost: suggestedPost, richMessage: apiRichMessage))
            |> delay(2.0, queue: Queue.concurrentDefaultQueue())
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        }
    } else {
        return .complete()
    }
}
