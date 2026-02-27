import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public enum StarGiftAuctionReference: Equatable {
    case giftId(Int64)
    case slug(String)
    
    var apiAuction: Api.InputStarGiftAuction {
        switch self {
        case let .giftId(giftId):
            return .inputStarGiftAuction(.init(giftId: giftId))
        case let .slug(slug):
            return .inputStarGiftAuctionSlug(.init(slug: slug))
        }
    }
}

private func _internal_getStarGiftAuctionState(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id, reference: StarGiftAuctionReference, version: Int32) -> Signal<(gift: StarGift, state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)?, NoError> {
    return network.request(Api.functions.payments.getStarGiftAuctionState(auction: reference.apiAuction, version: version))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.StarGiftAuctionState?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<(gift: StarGift, state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)?, NoError> in
        guard let result else {
            return .single(nil)
        }
        return postbox.transaction { transaction -> (gift: StarGift, state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)? in
            switch result {
            case let .starGiftAuctionState(starGiftAuctionStateData):
                let (apiGift, state, userState, timeout, users, chats) = (starGiftAuctionStateData.gift, starGiftAuctionStateData.state, starGiftAuctionStateData.userState, starGiftAuctionStateData.timeout, starGiftAuctionStateData.users, starGiftAuctionStateData.chats)
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(chats: chats, users: users))
                guard let gift = StarGift(apiStarGift: apiGift) else {
                    return nil
                }
                return (
                    gift: gift,
                    state: GiftAuctionContext.State.AuctionState(apiAuctionState: state, transaction: transaction),
                    myState: GiftAuctionContext.State.MyState(apiAuctionUserState: userState),
                    timeout: timeout
                )
            }
        }
    }
}

public final class GiftAuctionContext {
    public struct State: Equatable {
        public struct BidLevel: Equatable {
            public var position: Int32
            public var amount: Int64
            public var date: Int32
        }
        
        public enum Round: Equatable {
            case generic(num: Int32, duration: Int32)
            case extendable(num: Int32, duration: Int32, extendTop: Int32, extendWindow: Int32)
            
            public var num: Int32 {
                switch self {
                case let .generic(num, _), let .extendable(num, _, _, _):
                    return num
                }
            }
            
            public var duration: Int32 {
                switch self {
                case let .generic(_, duration), let .extendable(_, duration, _, _):
                    return duration
                }
            }
        }
        
        public enum AuctionState: Equatable {
            case ongoing(version: Int32, startDate: Int32, endDate: Int32, minBidAmount: Int64, bidLevels: [BidLevel], topBidders: [EnginePeer], nextRoundDate: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32, rounds: [Round], lastGiftNumber: Int32)
            case finished(startDate: Int32, endDate: Int32, averagePrice: Int64, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?)
        }
        
        public struct MyState: Equatable {
            public var isReturned: Bool
            public var bidAmount: Int64?
            public var bidDate: Int32?
            public var minBidAmount: Int64?
            public var bidPeerId: EnginePeer.Id?
            public var acquiredCount: Int32
        }
        
        public var gift: StarGift
        public var auctionState: AuctionState
        public var myState: MyState
    }
    
    private let queue: Queue = .mainQueue()
    private let account: Account
    public let gift: StarGift
    
    public var isActive: Bool {
        if case .finished = auctionState {
            return false
        } else {
            return myState?.bidAmount != nil
        }
    }
    
    private let disposable = MetaDisposable()
    
    private var auctionState: State.AuctionState?
    private var myState: State.MyState?
    private var timeout: Int32?
    
    private var updateTimer: SwiftSignalKit.Timer?
    
    private let stateValue = Promise<State?>()
    public var state: Signal<State?, NoError> {
        return self.stateValue.get()
    }
    
    public var currentBidPeerId: EnginePeer.Id? {
        if self.myState?.bidAmount != nil, case .ongoing = self.auctionState {
            return self.myState?.bidPeerId
        } else {
            return nil
        }
    }
    
    public var isFinished: Bool {
        if case .finished = self.auctionState {
            return true
        } else {
            return false
        }
    }
    
    public var isUpcoming: Bool {
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        if case let .ongoing(_, startTime, _, _, _, _, _, _, _, _, _, _) = self.auctionState {
            return currentTime < startTime
        } else {
            return false
        }
    }
    
    public convenience init(account: Account, gift: StarGift) {
        self.init(account: account, gift: gift, initialAuctionState: nil, initialMyState: nil, initialTimeout: nil)
    }
    
    init(account: Account, gift: StarGift, initialAuctionState: State.AuctionState?, initialMyState: State.MyState?, initialTimeout: Int32?) {
        self.account = account
        self.gift = gift
        
        self.auctionState = initialAuctionState
        self.myState = initialMyState
        self.timeout = initialTimeout
        
        self.load()
    }
    
    deinit {
        self.updateTimer?.invalidate()
        self.disposable.dispose()
    }
    
    private var currentVersion: Int32 {
        var currentVersion: Int32 = 0
        if case let .ongoing(version, _, _, _, _, _, _, _, _, _, _, _) = self.auctionState {
            currentVersion = version
        }
        return currentVersion
    }
        
    public func load() {
        self.pushState()

        self.disposable.set((_internal_getStarGiftAuctionState(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, reference: .giftId(self.gift.giftId), version: self.currentVersion)
        |> deliverOn(self.queue)).start(next: { [weak self] data in
            guard let self else {
                return
            }
            guard let (_, auctionState, myState, timeout) = data else {
                return
            }
            
            if case let .ongoing(version, _, _, _, _, _, _, _, _, _, _, _) = auctionState, version < self.currentVersion {
            } else if let auctionState {
                self.auctionState = auctionState
            }
            self.myState = myState
            self.timeout = timeout
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            var effectiveTimeout = timeout
            if case let .ongoing(_, _, _, _, _, _, nextRoundDate, _, _, _, _, _) = auctionState {
                let delta = nextRoundDate - currentTime
                if delta > 0 && delta < timeout {
                    effectiveTimeout = delta
                }
            }
            
            self.pushState()
            
            self.updateTimer?.invalidate()
            self.updateTimer = SwiftSignalKit.Timer(timeout: Double(effectiveTimeout), repeat: false, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.load()
            }, queue: Queue.mainQueue())
            self.updateTimer?.start()
        }))
    }
        
    func updateAuctionState(_ auctionState: GiftAuctionContext.State.AuctionState) {
        if case let .ongoing(version, _, _, _, _, _, _, _, _, _, _, _) = auctionState, version < self.currentVersion {
        } else {
            self.auctionState = auctionState
        }
        self.pushState()
    }
    
    func updateMyState(_ myState: GiftAuctionContext.State.MyState) {
        self.myState = myState
        self.pushState()
    }
    
    private func pushState() {
        if let auctionState = self.auctionState, let myState = self.myState {
            self.stateValue.set(
                .single(State(
                    gift: self.gift,
                    auctionState: auctionState,
                    myState: myState
                ))
            )
        } else {
            self.stateValue.set(.single(nil))
        }
    }
}

extension GiftAuctionContext.State.BidLevel {
    init(apiBidLevel: Api.AuctionBidLevel) {
        switch apiBidLevel {
        case let .auctionBidLevel(auctionBidLevelData):
            let (pos, amount, date) = (auctionBidLevelData.pos, auctionBidLevelData.amount, auctionBidLevelData.date)
            self.position = pos
            self.amount = amount
            self.date = date
        }
    }
}

extension GiftAuctionContext.State.AuctionState {
    init?(apiAuctionState: Api.StarGiftAuctionState, peers: [PeerId: Peer]) {
        switch apiAuctionState {
        case let .starGiftAuctionState(starGiftAuctionStateData):
            let (version, startDate, endDate, minBidAmount, bidLevels, topBiddersPeerIds, nextRoundAt, lastGiftNumber, giftsLeft, currentRound, totalRounds, apiRounds) = (starGiftAuctionStateData.version, starGiftAuctionStateData.startDate, starGiftAuctionStateData.endDate, starGiftAuctionStateData.minBidAmount, starGiftAuctionStateData.bidLevels, starGiftAuctionStateData.topBidders, starGiftAuctionStateData.nextRoundAt, starGiftAuctionStateData.lastGiftNum, starGiftAuctionStateData.giftsLeft, starGiftAuctionStateData.currentRound, starGiftAuctionStateData.totalRounds, starGiftAuctionStateData.rounds)
            var topBidders: [EnginePeer] = []
            for peerId in topBiddersPeerIds {
                if let peer = peers[PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(peerId))] {
                    topBidders.append(EnginePeer(peer))
                }
            }
            var rounds: [GiftAuctionContext.State.Round] = []
            for apiRound in apiRounds {
                switch apiRound {
                case let .starGiftAuctionRound(starGiftAuctionRoundData):
                    let (num, duration) = (starGiftAuctionRoundData.num, starGiftAuctionRoundData.duration)
                    rounds.append(.generic(num: num, duration: duration))
                case let .starGiftAuctionRoundExtendable(starGiftAuctionRoundExtendableData):
                    let (num, duration, extendTop, extendWindow) = (starGiftAuctionRoundExtendableData.num, starGiftAuctionRoundExtendableData.duration, starGiftAuctionRoundExtendableData.extendTop, starGiftAuctionRoundExtendableData.extendWindow)
                    rounds.append(.extendable(num: num, duration: duration, extendTop: extendTop, extendWindow: extendWindow))
                }
            }
            self = .ongoing(
                version: version,
                startDate: startDate,
                endDate: endDate,
                minBidAmount: minBidAmount,
                bidLevels: bidLevels.map(GiftAuctionContext.State.BidLevel.init(apiBidLevel:)),
                topBidders: topBidders,
                nextRoundDate: nextRoundAt,
                giftsLeft: giftsLeft,
                currentRound: currentRound,
                totalRounds: totalRounds,
                rounds: rounds,
                lastGiftNumber: lastGiftNumber
            )
        case let .starGiftAuctionStateFinished(starGiftAuctionStateFinishedData):
            let (startDate, endDate, averagePrice, listedCount, fragmentListedCount, fragmentListedUrl) = (starGiftAuctionStateFinishedData.startDate, starGiftAuctionStateFinishedData.endDate, starGiftAuctionStateFinishedData.averagePrice, starGiftAuctionStateFinishedData.listedCount, starGiftAuctionStateFinishedData.fragmentListedCount, starGiftAuctionStateFinishedData.fragmentListedUrl)
            self = .finished(
                startDate: startDate,
                endDate: endDate,
                averagePrice: averagePrice,
                listedCount: listedCount,
                fragmentListedCount: fragmentListedCount,
                fragmentListedUrl: fragmentListedUrl
            )
        case .starGiftAuctionStateNotModified:
            return nil
        }
    }

    init?(apiAuctionState: Api.StarGiftAuctionState, transaction: Transaction) {
        switch apiAuctionState {
        case let .starGiftAuctionState(starGiftAuctionStateData):
            let (version, startDate, endDate, minBidAmount, bidLevels, topBiddersPeerIds, nextRoundAt, lastGiftNumber, giftsLeft, currentRound, totalRounds, apiRounds) = (starGiftAuctionStateData.version, starGiftAuctionStateData.startDate, starGiftAuctionStateData.endDate, starGiftAuctionStateData.minBidAmount, starGiftAuctionStateData.bidLevels, starGiftAuctionStateData.topBidders, starGiftAuctionStateData.nextRoundAt, starGiftAuctionStateData.lastGiftNum, starGiftAuctionStateData.giftsLeft, starGiftAuctionStateData.currentRound, starGiftAuctionStateData.totalRounds, starGiftAuctionStateData.rounds)
            var topBidders: [EnginePeer] = []
            for peerId in topBiddersPeerIds {
                if let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(peerId))) {
                    topBidders.append(EnginePeer(peer))
                }
            }
            var rounds: [GiftAuctionContext.State.Round] = []
            for apiRound in apiRounds {
                switch apiRound {
                case let .starGiftAuctionRound(starGiftAuctionRoundData):
                    let (num, duration) = (starGiftAuctionRoundData.num, starGiftAuctionRoundData.duration)
                    rounds.append(.generic(num: num, duration: duration))
                case let .starGiftAuctionRoundExtendable(starGiftAuctionRoundExtendableData):
                    let (num, duration, extendTop, extendWindow) = (starGiftAuctionRoundExtendableData.num, starGiftAuctionRoundExtendableData.duration, starGiftAuctionRoundExtendableData.extendTop, starGiftAuctionRoundExtendableData.extendWindow)
                    rounds.append(.extendable(num: num, duration: duration, extendTop: extendTop, extendWindow: extendWindow))
                }
            }
            self = .ongoing(
                version: version,
                startDate: startDate,
                endDate: endDate,
                minBidAmount: minBidAmount,
                bidLevels: bidLevels.map(GiftAuctionContext.State.BidLevel.init(apiBidLevel:)),
                topBidders: topBidders,
                nextRoundDate: nextRoundAt,
                giftsLeft: giftsLeft,
                currentRound: currentRound,
                totalRounds: totalRounds,
                rounds: rounds,
                lastGiftNumber: lastGiftNumber
            )
        case let .starGiftAuctionStateFinished(starGiftAuctionStateFinishedData):
            let (startDate, endDate, averagePrice, listedCount, fragmentListedCount, fragmentListedUrl) = (starGiftAuctionStateFinishedData.startDate, starGiftAuctionStateFinishedData.endDate, starGiftAuctionStateFinishedData.averagePrice, starGiftAuctionStateFinishedData.listedCount, starGiftAuctionStateFinishedData.fragmentListedCount, starGiftAuctionStateFinishedData.fragmentListedUrl)
            self = .finished(
                startDate: startDate,
                endDate: endDate,
                averagePrice: averagePrice,
                listedCount: listedCount,
                fragmentListedCount: fragmentListedCount,
                fragmentListedUrl: fragmentListedUrl
            )
        case .starGiftAuctionStateNotModified:
            return nil
        }
    }
}

extension GiftAuctionContext.State.MyState {
    init(apiAuctionUserState: Api.StarGiftAuctionUserState) {
        switch apiAuctionUserState {
        case let .starGiftAuctionUserState(starGiftAuctionUserStateData):
            let (flags, bidAmount, bidDate, minBidAmount, bidPeerId, acquiredCount) = (starGiftAuctionUserStateData.flags, starGiftAuctionUserStateData.bidAmount, starGiftAuctionUserStateData.bidDate, starGiftAuctionUserStateData.minBidAmount, starGiftAuctionUserStateData.bidPeer, starGiftAuctionUserStateData.acquiredCount)
            self.isReturned = (flags & (1 << 1)) != 0
            self.bidAmount = bidAmount
            self.bidDate = bidDate
            self.minBidAmount = minBidAmount
            self.bidPeerId = bidPeerId?.peerId
            self.acquiredCount = acquiredCount
        }
    }
}

public struct GiftAuctionAcquiredGift: Equatable {
    public var nameHidden: Bool
    public let peer: EnginePeer
    public let date: Int32
    public let bidAmount: Int64
    public let round: Int32
    public let position: Int32
    public let text: String?
    public let entities: [MessageTextEntity]?
    public let number: Int32?
}

func _internal_getGiftAuctionAcquiredGifts(account: Account, giftId: Int64) -> Signal<[GiftAuctionAcquiredGift], NoError> {
    return account.network.request(Api.functions.payments.getStarGiftAuctionAcquiredGifts(giftId: giftId))
    |> map(Optional.init)
    |> `catch` { _ in
        return .single(nil)
    }
    |> mapToSignal { result in
        guard let result else {
            return .single([])
        }
        return account.postbox.transaction { transaction -> [GiftAuctionAcquiredGift] in
            switch result {
            case let .starGiftAuctionAcquiredGifts(starGiftAuctionAcquiredGiftsData):
                let (gifts, users, chats) = (starGiftAuctionAcquiredGiftsData.gifts, starGiftAuctionAcquiredGiftsData.users, starGiftAuctionAcquiredGiftsData.chats)
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                
                var mappedGifts: [GiftAuctionAcquiredGift] = []
                for gift in gifts {
                    switch gift {
                    case let .starGiftAuctionAcquiredGift(starGiftAuctionAcquiredGiftData):
                        let (flags, peerId, date, bidAmount, round, pos, message, number) = (starGiftAuctionAcquiredGiftData.flags, starGiftAuctionAcquiredGiftData.peer, starGiftAuctionAcquiredGiftData.date, starGiftAuctionAcquiredGiftData.bidAmount, starGiftAuctionAcquiredGiftData.round, starGiftAuctionAcquiredGiftData.pos, starGiftAuctionAcquiredGiftData.message, starGiftAuctionAcquiredGiftData.giftNum)
                        if let peer = transaction.getPeer(peerId.peerId) {
                            var text: String?
                            var entities: [MessageTextEntity]?
                            switch message {
                            case let .textWithEntities(textWithEntitiesData):
                                let (textValue, entitiesValue) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                                text = textValue
                                entities = messageTextEntitiesFromApiEntities(entitiesValue)
                            default:
                                break
                            }
                            mappedGifts.append(GiftAuctionAcquiredGift(
                                nameHidden: (flags & (1 << 0)) != 0,
                                peer: EnginePeer(peer),
                                date: date,
                                bidAmount: bidAmount,
                                round: round,
                                position: pos,
                                text: text,
                                entities: entities,
                                number: number
                            ))
                        }
                    }
                }
                return mappedGifts
            }
        }
    }
}

func _internal_getActiveGiftAuctions(account: Account, hash: Int64) -> Signal<[GiftAuctionContext]?, NoError> {
    return account.network.request(Api.functions.payments.getStarGiftActiveAuctions(hash: hash))
    |> retryRequest
    |> mapToSignal { result in
        return account.postbox.transaction { transaction -> [GiftAuctionContext]? in
            switch result {
            case let .starGiftActiveAuctions(starGiftActiveAuctionsData):
                let (auctions, users, chats) = (starGiftActiveAuctionsData.auctions, starGiftActiveAuctionsData.users, starGiftActiveAuctionsData.chats)
                let parsedPeers = AccumulatedPeers(chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                
                var auctionContexts: [GiftAuctionContext] = []
                for auction in auctions {
                    switch auction {
                    case let .starGiftActiveAuctionState(starGiftActiveAuctionStateData):
                        let (apiGift, auctionState, userState) = (starGiftActiveAuctionStateData.gift, starGiftActiveAuctionStateData.state, starGiftActiveAuctionStateData.userState)
                        guard let gift = StarGift(apiStarGift: apiGift) else {
                            continue
                        }
                        auctionContexts.append(GiftAuctionContext(
                            account: account,
                            gift: gift,
                            initialAuctionState: GiftAuctionContext.State.AuctionState(apiAuctionState: auctionState, transaction: transaction),
                            initialMyState: GiftAuctionContext.State.MyState(apiAuctionUserState: userState),
                            initialTimeout: nil
                        ))
                    }
                }

                return auctionContexts
            case .starGiftActiveAuctionsNotModified:
                return nil
            }
        }
    }
}

public class GiftAuctionsManager {
    private let account: Account
    private var auctionContexts: [Int64 : GiftAuctionContext] = [:]
    
    private let disposable = MetaDisposable()
    private var updateAuctionStateDisposable: Disposable?
    private var updateMyStateDisposable: Disposable?
        
    private let statePromise = Promise<[GiftAuctionContext.State]>([])
    public var state: Signal<[GiftAuctionContext.State], NoError> {
        return self.statePromise.get()
    }
    
    public init(account: Account) {
        self.account = account
        
        self.updateAuctionStateDisposable = (self.account.stateManager.updatedStarGiftAuctionState()
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let self else {
                return
            }
            var reload = false
            for (giftId, update) in updates {
                if let auctionContext = self.auctionContexts[giftId] {
                    auctionContext.updateAuctionState(update)
                } else if case .ongoing = update {
                    reload = true
                    break
                }
            }
            if reload {
                self.reload()
            }
        })
        
        self.updateMyStateDisposable = (self.account.stateManager.updatedStarGiftAuctionMyState()
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let self else {
                return
            }
            var reload = false
            for (giftId, update) in updates {
                if let auctionContext = self.auctionContexts[giftId] {
                    auctionContext.updateMyState(update)
                } else {
                    reload = true
                    break
                }
            }
            if reload {
                self.reload()
            }
        })
        
        self.reload()
    }
    
    deinit {
        self.disposable.dispose()
        self.updateAuctionStateDisposable?.dispose()
        self.updateMyStateDisposable?.dispose()
    }
    
    public func reload() {
        self.disposable.set((_internal_getActiveGiftAuctions(account: self.account, hash: 0)
        |> deliverOnMainQueue).startStrict(next: { [weak self] activeAuctions in
            guard let self, let activeAuctions else {
                return
            }
            for auction in activeAuctions {
                if self.auctionContexts[auction.gift.giftId] == nil {
                    self.auctionContexts[auction.gift.giftId] = auction
                }
            }
            self.updateState()
        }))
    }
    
    public func auctionContext(for reference: StarGiftAuctionReference) -> Signal<GiftAuctionContext?, NoError> {
        if case let .giftId(id) = reference, let current = self.auctionContexts[id] {
            return .single(current)
        } else {
            return _internal_getStarGiftAuctionState(
                postbox: self.account.postbox,
                network: self.account.network,
                accountPeerId: self.account.peerId,
                reference: reference,
                version: 0
            ) |> mapToSignal { [weak self] result in
                if let self, let result {
                    let auctionContext = GiftAuctionContext(account: self.account, gift: result.gift, initialAuctionState: result.state, initialMyState: result.myState, initialTimeout: result.timeout)
                    self.auctionContexts[result.gift.giftId] = auctionContext
                    self.updateState()
                    return .single(auctionContext)
                } else {
                    return .single(nil)
                }
            }
        }
    }

    public func storeAuctionContext(auctionContext: GiftAuctionContext) {
        self.auctionContexts[auctionContext.gift.giftId] = auctionContext
        self.updateState()
    }
    
    private func updateState() {
        var signals: [Signal<GiftAuctionContext.State?, NoError>] = []
        for auction in self.auctionContexts.values.sorted(by: { $0.gift.giftId < $1.gift.giftId }) {
            signals.append(auction.state)
        }
        self.statePromise.set(combineLatest(signals)
        |> map { states -> [GiftAuctionContext.State] in
            var filteredStates: [GiftAuctionContext.State] = []
            for state in states {
                if let state, case .ongoing = state.auctionState, state.myState.bidAmount != nil {
                    filteredStates.append(state)
                }
            }
            return filteredStates
        })
    }
}

public extension GiftAuctionContext.State {
    func getPlace(myBid: Int64?, myBidDate: Int32?) -> (place: Int32, isApproximate: Bool)? {
        guard case let .ongoing(_, _, _, _, bidLevels, _, _, _, _, _, _, _) = self.auctionState else {
            return nil
        }
        guard let myBid = myBid ?? self.myState.bidAmount else {
            return nil
        }
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        let myBidDate = self.myState.bidDate ?? currentTime
        
        let levels = bidLevels
        guard !levels.isEmpty else {
            return (1, false)
        }
        
        func isWorse(than level: GiftAuctionContext.State.BidLevel) -> Bool {
            if myBid < level.amount {
                return true
            }
            if myBid == level.amount, myBidDate > level.date {
                return true
            }
            return false
        }
        
        var lowerIndex: Int = -1
        for (i, level) in levels.enumerated() {
            if isWorse(than: level) {
                lowerIndex = i
            } else {
                break
            }
        }
        if lowerIndex == -1 {
            return (1, false)
        }
        
        let lowerPosition = levels[lowerIndex].position
        let nextPosition: Int32
        let nextIndex = lowerIndex + 1
        if nextIndex < levels.count {
            nextPosition = levels[nextIndex].position
        } else {
            nextPosition = lowerPosition
        }
        if nextPosition == lowerPosition + 1 {
            return (lowerPosition + 1, false)
        } else {
            return (lowerPosition, true)
        }
    }
    
    var place: Int32? {
        return self.getPlace(myBid: nil, myBidDate: nil)?.place
    }
    
    var startDate: Int32 {
        switch self.auctionState {
        case let .ongoing(_, startDate, _, _, _, _, _, _, _, _, _, _):
            return startDate
        case let .finished(startDate, _, _, _, _, _):
            return startDate
        }
    }
    
    var endDate: Int32 {
        switch self.auctionState {
        case let .ongoing(_, _, endDate, _, _, _, _, _, _, _, _, _):
            return endDate
        case let .finished(_, endDate, _, _, _, _):
            return endDate
        }
    }
}
