import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


public enum RequestMessageSelectPollOptionError {
    case generic
}

func _internal_requestMessageSelectPollOption(account: Account, messageId: MessageId, opaqueIdentifiers: [Data]) -> Signal<TelegramMediaPoll?, RequestMessageSelectPollOptionError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> castError(RequestMessageSelectPollOptionError.self)
    |> mapToSignal { peer in
        if let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.sendVote(peer: inputPeer, msgId: messageId.id, options: opaqueIdentifiers.map { Buffer(data: $0) }))
            |> mapError { _ -> RequestMessageSelectPollOptionError in
                return .generic
            }
            |> mapToSignal { result -> Signal<TelegramMediaPoll?, RequestMessageSelectPollOptionError> in
                return account.postbox.transaction { transaction -> TelegramMediaPoll? in
                    var resultPoll: TelegramMediaPoll?
                    switch result {
                    case let .updates(updates, _, _, _, _):
                        for update in updates {
                            switch update {
                            case let .updateMessagePoll(_, id, poll, results):
                                let pollId = MediaId(namespace: Namespaces.Media.CloudPoll, id: id)
                                resultPoll = transaction.getMedia(pollId) as? TelegramMediaPoll
                                if let poll = poll {
                                    switch poll {
                                    case let .poll(id, flags, question, answers, closePeriod, _):
                                        let publicity: TelegramMediaPollPublicity
                                        if (flags & (1 << 1)) != 0 {
                                            publicity = .public
                                        } else {
                                            publicity = .anonymous
                                        }
                                        let kind: TelegramMediaPollKind
                                        if (flags & (1 << 3)) != 0 {
                                            kind = .quiz
                                        } else {
                                            kind = .poll(multipleAnswers: (flags & (1 << 2)) != 0)
                                        }
                                        resultPoll = TelegramMediaPoll(pollId: pollId, publicity: publicity, kind: kind, text: question, options: answers.map(TelegramMediaPollOption.init(apiOption:)), correctAnswers: nil, results: TelegramMediaPollResults(apiResults: results), isClosed: (flags & (1 << 0)) != 0, deadlineTimeout: closePeriod)
                                    default:
                                        break
                                    }
                                }
                                
                                let resultsMin: Bool
                                switch results {
                                case let .pollResults(pollResults):
                                    resultsMin = (pollResults.flags & (1 << 0)) != 0
                                }
                                resultPoll = resultPoll?.withUpdatedResults(TelegramMediaPollResults(apiResults: results), min: resultsMin)
                                
                                if let resultPoll = resultPoll {
                                    updateMessageMedia(transaction: transaction, id: pollId, media: resultPoll)
                                }
                            default:
                                break
                            }
                        }
                        break
                    default:
                        break
                    }
                    account.stateManager.addUpdates(result)
                    return resultPoll
                }
                |> castError(RequestMessageSelectPollOptionError.self)
            }
        } else {
            return .single(nil)
        }
    }
}

func _internal_requestClosePoll(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> (TelegramMediaPoll, Api.InputPeer)? in
        guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
            return nil
        }
        guard let message = transaction.getMessage(messageId) else {
            return nil
        }
        for media in message.media {
            if let poll = media as? TelegramMediaPoll {
                return (poll, inputPeer)
            }
        }
        return nil
    }
    |> mapToSignal { pollAndInputPeer -> Signal<Void, NoError> in
        guard let (poll, inputPeer) = pollAndInputPeer, poll.pollId.namespace == Namespaces.Media.CloudPoll else {
            return .complete()
        }
        var flags: Int32 = 0
        flags |= 1 << 14
        
        var pollFlags: Int32 = 0
        switch poll.kind {
        case let .poll(multipleAnswers):
            if multipleAnswers {
                pollFlags |= 1 << 2
            }
        case .quiz:
            pollFlags |= 1 << 3
        }
        switch poll.publicity {
        case .anonymous:
            break
        case .public:
            pollFlags |= 1 << 1
        }
        var pollMediaFlags: Int32 = 0
        var correctAnswers: [Buffer]?
        if let correctAnswersValue = poll.correctAnswers {
            pollMediaFlags |= 1 << 0
            correctAnswers = correctAnswersValue.map { Buffer(data: $0) }
        }
        
        pollFlags |= 1 << 0
        
        if poll.deadlineTimeout != nil {
            pollFlags |= 1 << 4
        }
        
        var mappedSolution: String?
        var mappedSolutionEntities: [Api.MessageEntity]?
        if let solution = poll.results.solution {
            mappedSolution = solution.text
            mappedSolutionEntities = apiTextAttributeEntities(TextEntitiesMessageAttribute(entities: solution.entities), associatedPeers: SimpleDictionary())
            pollMediaFlags |= 1 << 1
        }
        
        return network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: nil, media: .inputMediaPoll(flags: pollMediaFlags, poll: .poll(id: poll.pollId.id, flags: pollFlags, question: poll.text, answers: poll.options.map({ $0.apiOption }), closePeriod: poll.deadlineTimeout, closeDate: nil), correctAnswers: correctAnswers, solution: mappedSolution, solutionEntities: mappedSolutionEntities), replyMarkup: nil, entities: nil, scheduleDate: nil))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Void, NoError> in
            if let updates = updates {
                stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }
}

private let cachedPollResultsCollectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 20, highWaterItemCount: 40)

final class CachedPollOptionResult: PostboxCoding {
    let peerIds: [PeerId]
    let count: Int32
    
    public static func key(pollId: MediaId, optionOpaqueIdentifier: Data) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8 + optionOpaqueIdentifier.count)
        key.setInt32(0, value: pollId.namespace)
        key.setInt64(4, value: pollId.id)
        key.setData(4 + 8, value: optionOpaqueIdentifier)
        return key
    }
    
    public init(peerIds: [PeerId], count: Int32) {
        self.peerIds = peerIds
        self.count = count
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerIds = decoder.decodeInt64ArrayForKey("peerIds").map(PeerId.init)
        self.count = decoder.decodeInt32ForKey("count", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64Array(self.peerIds.map { $0.toInt64() }, forKey: "peerIds")
        encoder.encodeInt32(self.count, forKey: "count")
    }
}

private final class PollResultsOptionContext {
    private let queue: Queue
    private let account: Account
    private let pollId: MediaId
    private let messageId: MessageId
    private let opaqueIdentifier: Data
    private let disposable = MetaDisposable()
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var nextOffset: String?
    private var results: [RenderedPeer] = []
    private var count: Int
    private var populateCache: Bool = true
    
    let state = Promise<PollResultsOptionState>()
    
    init(queue: Queue, account: Account, pollId: MediaId, messageId: MessageId, opaqueIdentifier: Data, count: Int) {
        self.queue = queue
        self.account = account
        self.pollId = pollId
        self.messageId = messageId
        self.opaqueIdentifier = opaqueIdentifier
        self.count = count
        
        self.isLoadingMore = true
        self.disposable.set((account.postbox.transaction { transaction -> (peers: [RenderedPeer], canLoadMore: Bool)? in
            let cachedResult = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPollResults, key: CachedPollOptionResult.key(pollId: pollId, optionOpaqueIdentifier: opaqueIdentifier))) as? CachedPollOptionResult
            if let cachedResult = cachedResult, Int(cachedResult.count) == count {
                var result: [RenderedPeer] = []
                for peerId in cachedResult.peerIds {
                    if let peer = transaction.getPeer(peerId) {
                        result.append(RenderedPeer(peer: peer))
                    } else {
                        return nil
                    }
                }
                return (result, Int(cachedResult.count) > result.count)
            } else {
                return nil
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] cachedPeersAndCanLoadMore in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            if let (cachedPeers, canLoadMore) = cachedPeersAndCanLoadMore {
                strongSelf.results = cachedPeers
                strongSelf.hasLoadedOnce = true
                strongSelf.canLoadMore = canLoadMore
            }
            strongSelf.loadMore()
        }))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func loadMore() {
        if self.isLoadingMore {
            return
        }
        self.isLoadingMore = true
        let pollId = self.pollId
        let messageId = self.messageId
        let opaqueIdentifier = self.opaqueIdentifier
        let account = self.account
        let nextOffset = self.nextOffset
        let populateCache = self.populateCache
        self.disposable.set((self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<([RenderedPeer], Int, String?), NoError> in
            if let inputPeer = inputPeer {
                var flags: Int32 = 1 << 0
                if let _ = nextOffset {
                    flags |= (1 << 1)
                }
                let signal = account.network.request(Api.functions.messages.getPollVotes(flags: flags, peer: inputPeer, id: messageId.id, option: Buffer(data: opaqueIdentifier), offset: nextOffset, limit: nextOffset == nil ? 10 : 50))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.VotesList?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([RenderedPeer], Int, String?), NoError> in
                    return account.postbox.transaction { transaction -> ([RenderedPeer], Int, String?) in
                        guard let result = result else {
                            return ([], 0, nil)
                        }
                        switch result {
                        case let .votesList(_, count, votes, users, nextOffset):
                            var peers: [Peer] = []
                            for apiUser in users {
                                peers.append(TelegramUser(user: apiUser))
                            }
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                                return updated
                            })
                            var resultPeers: [RenderedPeer] = []
                            for vote in votes {
                                let peerId: PeerId
                                switch vote {
                                case let .messageUserVote(userId, _, _):
                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                case let .messageUserVoteInputOption(userId, _):
                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                case let .messageUserVoteMultiple(userId, _, _):
                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                }
                                if let peer = transaction.getPeer(peerId) {
                                    resultPeers.append(RenderedPeer(peer: peer))
                                }
                            }
                            if populateCache {
                                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPollResults, key: CachedPollOptionResult.key(pollId: pollId, optionOpaqueIdentifier: opaqueIdentifier)), entry: CachedPollOptionResult(peerIds: resultPeers.map { $0.peerId }, count: count), collectionSpec: cachedPollResultsCollectionSpec)
                            }
                            return (resultPeers, Int(count), nextOffset)
                        }
                    }
                }
                #if DEBUG
                //return signal |> delay(4.0, queue: .concurrentDefaultQueue())
                #endif
                return signal
            } else {
                return .single(([], 0, nil))
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] peers, updatedCount, nextOffset in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.populateCache {
                strongSelf.populateCache = false
                strongSelf.results.removeAll()
            }
            var existingIds = Set(strongSelf.results.map { $0.peerId })
            for peer in peers {
                if !existingIds.contains(peer.peerId) {
                    strongSelf.results.append(peer)
                    existingIds.insert(peer.peerId)
                }
            }
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = nextOffset != nil
            strongSelf.nextOffset = nextOffset
            if strongSelf.canLoadMore {
                strongSelf.count = max(updatedCount, strongSelf.results.count)
            } else {
                strongSelf.count = strongSelf.results.count
            }
            strongSelf.updateState()
        }))
        self.updateState()
    }
    
    func updateState() {
        self.state.set(.single(PollResultsOptionState(peers: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public struct PollResultsOptionState: Equatable {
    public var peers: [RenderedPeer]
    public var isLoadingMore: Bool
    public var hasLoadedOnce: Bool
    public var canLoadMore: Bool
    public var count: Int
}

public struct PollResultsState: Equatable {
    public var options: [Data: PollResultsOptionState]
}

private final class PollResultsContextImpl {
    private let queue: Queue
    
    private var optionContexts: [Data: PollResultsOptionContext] = [:]
    
    let state = Promise<PollResultsState>()
    
    init(queue: Queue, account: Account, messageId: MessageId, poll: TelegramMediaPoll) {
        self.queue = queue
        
        for option in poll.options {
            var count = 0
            if let voters = poll.results.voters {
                for voter in voters {
                    if voter.opaqueIdentifier == option.opaqueIdentifier {
                        count = Int(voter.count)
                    }
                }
            }
            self.optionContexts[option.opaqueIdentifier] = PollResultsOptionContext(queue: self.queue, account: account, pollId: poll.pollId, messageId: messageId, opaqueIdentifier: option.opaqueIdentifier, count: count)
        }
        
        self.state.set(combineLatest(queue: self.queue, self.optionContexts.map { (opaqueIdentifier, context) -> Signal<(Data, PollResultsOptionState), NoError> in
            return context.state.get()
            |> map { state -> (Data, PollResultsOptionState) in
                return (opaqueIdentifier, state)
            }
        })
        |> map { states -> PollResultsState in
            var options: [Data: PollResultsOptionState] = [:]
            for (opaqueIdentifier, state) in states {
                options[opaqueIdentifier] = state
            }
            return PollResultsState(options: options)
        })
        
        for (_, context) in self.optionContexts {
            context.loadMore()
        }
    }
    
    func loadMore(optionOpaqueIdentifier: Data) {
        self.optionContexts[optionOpaqueIdentifier]?.loadMore()
    }
}

public final class PollResultsContext {
    private let queue: Queue = Queue()
    private let impl: QueueLocalObject<PollResultsContextImpl>
    
    public var state: Signal<PollResultsState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    init(account: Account, messageId: MessageId, poll: TelegramMediaPoll) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PollResultsContextImpl(queue: queue, account: account, messageId: messageId, poll: poll)
        })
    }
    
    public func loadMore(optionOpaqueIdentifier: Data) {
        self.impl.with { impl in
            impl.loadMore(optionOpaqueIdentifier: optionOpaqueIdentifier)
        }
    }
}
