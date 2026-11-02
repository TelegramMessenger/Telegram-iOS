import Foundation
import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

/// `AccountFinalStateEvents.union(with:)`. `fetchDifference` starts from empty events and unions each
/// difference slice in, and the channel resets replayed after a difference are unioned after it, always
/// as `earlier.union(with: later)`. Pins R1: no field may be dropped, and each has one merge policy.
final class AccountFinalStateEventsUnionTests: XCTestCase {
    private let userA = StateSyncFixture.userPeerId(1)
    private let userB = StateSyncFixture.userPeerId(2)
    private let channel = StateSyncFixture.channelPeerId(3)

    private func messageId(_ id: Int32) -> MessageId {
        return MessageId(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: id)
    }

    private func thread(_ threadId: Int64) -> PeerAndBoundThreadId {
        return PeerAndBoundThreadId(peerId: self.channel, threadId: threadId)
    }

    private var globalSpace: PeerActivitySpace {
        return PeerActivitySpace(peerId: self.channel, category: .global)
    }

    private func threadSpace(_ threadId: Int64) -> PeerActivitySpace {
        return PeerActivitySpace(peerId: self.channel, category: .thread(threadId))
    }

    private func webpageId(_ id: Int64) -> MediaId {
        return MediaId(namespace: Namespaces.Media.CloudWebpage, id: id)
    }

    private func stars(_ value: Int64) -> StarsAmount {
        return StarsAmount(value: value, nanos: 0)
    }

    private func revenue(_ value: Int64) -> StarsRevenueStats.Balances {
        let amount = CurrencyAmount(amount: self.stars(value), currency: .stars)
        return StarsRevenueStats.Balances(currentBalance: amount, availableBalance: amount, overallRevenue: amount, withdrawEnabled: false, nextWithdrawalTimestamp: nil)
    }

    private func auctionState(averagePrice: Int64) -> GiftAuctionContext.State.AuctionState {
        return .finished(startDate: 1, endDate: 2, averagePrice: averagePrice, listedCount: nil, fragmentListedCount: nil, fragmentListedUrl: nil)
    }

    private func auctionMyState(bidAmount: Int64) -> GiftAuctionContext.State.MyState {
        return GiftAuctionContext.State.MyState(isReturned: false, bidAmount: bidAmount, bidDate: nil, minBidAmount: nil, bidPeerId: nil, acquiredCount: 0)
    }

    private func emojiGame(_ gameHash: String) -> EmojiGameInfo {
        return .available(EmojiGameInfo.Info(gameHash: gameHash, previousStake: 0, currentStreak: 0, parameters: [], playsLeft: nil))
    }

    private func gasless(left: Int32) -> WalletTransferUpdate {
        return .gaslessInfo(WalletGaslessInfo(available: true, left: left, resetAt: 0, minAmount: 0, relayerAddress: "relayer"))
    }

    private func reactionEvent(timestamp: Int32) -> (reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32) {
        return (reactionAuthor: StateSyncFixture.makeUser(id: self.userA, firstName: "A"), reaction: .builtin("👍"), message: SparseFixtures.message(self.channel, 1, timestamp: timestamp), timestamp: timestamp)
    }

    private func callIds(_ calls: [Api.PhoneCall]) -> [Int64] {
        return calls.map { call -> Int64 in
            if case let .phoneCallEmpty(data) = call {
                return data.id
            } else {
                return -1
            }
        }
    }

    private func storyReadMaxIds(_ updates: [InternalStoryUpdate]) -> [Int32] {
        return updates.map { update -> Int32 in
            if case let .read(_, maxId) = update {
                return maxId
            } else {
                return -1
            }
        }
    }

    private func agentSettings(_ activeProvider: String) -> EngineAgentSettings {
        return EngineAgentSettings(keys: [], activeProvider: activeProvider)
    }

    private func activeProvider(_ settings: EngineAgentSettings?) -> String? {
        return settings?.activeProvider
    }

    /// Nil when the value is not `walletStateEmpty`.
    private func walletStateEmptyFlags(_ state: Api.WalletState?) -> Int32? {
        if case let .walletStateEmpty(data)? = state {
            return data.flags
        } else {
            return nil
        }
    }

    /// Every field set. Keys and values overlap `later`'s so that each merge policy is observable.
    private var earlier: AccountFinalStateEvents {
        return AccountFinalStateEvents(
            addedIncomingMessageIds: [self.messageId(1)],
            addedReactionEvents: [self.reactionEvent(timestamp: 1)],
            wasScheduledMessageIds: [self.messageId(2)],
            deletedMessageIds: [.global(1)],
            updatedTypingActivities: [
                self.globalSpace: [self.userA: .typingText, self.userB: .typingText],
                self.threadSpace(7): [self.userA: .typingText]
            ],
            updatedWebpages: [self.webpageId(1): nil],
            updatedCalls: [.phoneCallEmpty(.init(id: 1))],
            addedCallSignalingData: [(1, Data([1]))],
            updatedGroupCallParticipants: [(1, .conferenceChainBlocks(subChainId: 0, blocks: [], nextOffset: 1))],
            groupCallMessageUpdates: [GroupCallMessageUpdate(callId: 1, update: .newOpaqueMessage(authorId: self.userA, data: Data([1])))],
            storyUpdates: [.read(peerId: self.userA, maxId: 1)],
            displayAlerts: [(text: "earlier", isDropAuth: false)],
            dismissBotWebViews: [1],
            joinChatWebViewDecisions: [JoinChatWebViewDecision(peerId: self.channel, queryId: 1, result: .approved)],
            delayNotificatonsUntil: 10,
            updatedMaxMessageId: 10,
            updatedQts: 10,
            externallyUpdatedPeerId: [self.userA],
            authorizationListUpdated: true,
            updatedIncomingThreadReadStates: [self.thread(1): 7, self.thread(2): 5, self.thread(3): 4],
            updatedOutgoingThreadReadStates: [self.thread(1): 7, self.thread(2): 5, self.thread(3): 4],
            updateConfig: true,
            isPremiumUpdated: false,
            updatedStarsBalance: [self.userA: self.stars(1), self.userB: self.stars(10)],
            updatedTonBalance: [self.userA: self.stars(1), self.userB: self.stars(10)],
            walletTransferUpdates: [self.gasless(left: 1)],
            walletTonConnectEvents: [.pendingDisconnect(sessionIds: [1])],
            updatedWalletState: .walletStateEmpty(.init(flags: 0)),
            updatedAgentSettings: self.agentSettings("earlier"),
            updatedStarsRevenueStatus: [self.userA: self.revenue(1), self.userB: self.revenue(10)],
            sentScheduledMessageIds: [self.messageId(3)],
            reportMessageDelivery: [self.messageId(4)],
            addedConferenceInvitationMessagesIds: [self.messageId(5)],
            updatedStarGiftAuctionState: [1: self.auctionState(averagePrice: 1), 2: self.auctionState(averagePrice: 10)],
            updatedStarGiftAuctionMyState: [1: self.auctionMyState(bidAmount: 1), 2: self.auctionMyState(bidAmount: 10)],
            updatedEmojiGameInfo: self.emojiGame("earlier")
        )
    }

    /// Every field set.
    private var later: AccountFinalStateEvents {
        return AccountFinalStateEvents(
            addedIncomingMessageIds: [self.messageId(11)],
            addedReactionEvents: [self.reactionEvent(timestamp: 2)],
            wasScheduledMessageIds: [self.messageId(12)],
            deletedMessageIds: [.global(2)],
            updatedTypingActivities: [
                // userA stopped typing: a nil activity, which must survive the merge.
                self.globalSpace: [self.userA: nil],
                self.threadSpace(8): [self.userB: .typingText]
            ],
            updatedWebpages: [self.webpageId(2): nil],
            updatedCalls: [.phoneCallEmpty(.init(id: 2))],
            addedCallSignalingData: [(2, Data([2]))],
            updatedGroupCallParticipants: [(2, .conferenceChainBlocks(subChainId: 0, blocks: [], nextOffset: 2))],
            groupCallMessageUpdates: [GroupCallMessageUpdate(callId: 2, update: .newOpaqueMessage(authorId: self.userB, data: Data([2])))],
            storyUpdates: [.read(peerId: self.userA, maxId: 2)],
            displayAlerts: [(text: "later", isDropAuth: true)],
            dismissBotWebViews: [2],
            joinChatWebViewDecisions: [JoinChatWebViewDecision(peerId: self.channel, queryId: 2, result: .declined)],
            delayNotificatonsUntil: 20,
            updatedMaxMessageId: 5,
            updatedQts: 20,
            externallyUpdatedPeerId: [self.userB],
            authorizationListUpdated: false,
            updatedIncomingThreadReadStates: [self.thread(1): 5, self.thread(2): 7, self.thread(4): 9],
            updatedOutgoingThreadReadStates: [self.thread(1): 5, self.thread(2): 7, self.thread(4): 9],
            updateConfig: false,
            isPremiumUpdated: true,
            updatedStarsBalance: [self.userA: self.stars(2)],
            updatedTonBalance: [self.userA: self.stars(2)],
            walletTransferUpdates: [self.gasless(left: 2)],
            walletTonConnectEvents: [.pendingDisconnect(sessionIds: [2])],
            updatedWalletState: .walletStateEmpty(.init(flags: 1 << 0)),
            updatedAgentSettings: self.agentSettings("later"),
            updatedStarsRevenueStatus: [self.userA: self.revenue(2)],
            sentScheduledMessageIds: [self.messageId(13)],
            reportMessageDelivery: [self.messageId(14)],
            addedConferenceInvitationMessagesIds: [self.messageId(15)],
            updatedStarGiftAuctionState: [1: self.auctionState(averagePrice: 2)],
            updatedStarGiftAuctionMyState: [1: self.auctionMyState(bidAmount: 2)],
            updatedEmojiGameInfo: .unavailable
        )
    }

    /// The shape of every getDifference: the first slice is unioned into empty events. Nothing of the
    /// slice may be lost (R1: typing, the notification delay, outgoing thread read states and emoji game
    /// info were).
    func testUnionIntoEmptyEventsKeepsEveryField() {
        let later = self.later
        let merged = AccountFinalStateEvents().union(with: later)

        XCTAssertEqual(merged.addedIncomingMessageIds, later.addedIncomingMessageIds)
        XCTAssertEqual(merged.addedReactionEvents.map { $0.timestamp }, [2])
        XCTAssertEqual(merged.wasScheduledMessageIds, later.wasScheduledMessageIds)
        XCTAssertEqual(merged.deletedMessageIds, later.deletedMessageIds)
        XCTAssertEqual(merged.sentScheduledMessageIds, later.sentScheduledMessageIds)
        XCTAssertEqual(merged.updatedTypingActivities, later.updatedTypingActivities)
        XCTAssertEqual(Set(merged.updatedWebpages.keys), Set(later.updatedWebpages.keys))
        XCTAssertEqual(self.callIds(merged.updatedCalls), [2])
        XCTAssertEqual(merged.addedCallSignalingData.map { $0.0 }, [2])
        XCTAssertEqual(merged.updatedGroupCallParticipants.map { $0.0 }, [2])
        XCTAssertEqual(merged.groupCallMessageUpdates.map { $0.callId }, [2])
        XCTAssertEqual(self.storyReadMaxIds(merged.storyUpdates), [2])
        XCTAssertEqual(merged.displayAlerts.map { $0.text }, ["later"])
        XCTAssertEqual(merged.dismissBotWebViews, later.dismissBotWebViews)
        XCTAssertEqual(merged.joinChatWebViewDecisions.map { $0.queryId }, [2])
        XCTAssertEqual(merged.delayNotificatonsUntil, later.delayNotificatonsUntil)
        XCTAssertEqual(merged.updatedMaxMessageId, later.updatedMaxMessageId)
        XCTAssertEqual(merged.updatedQts, later.updatedQts)
        XCTAssertEqual(merged.externallyUpdatedPeerId, later.externallyUpdatedPeerId)
        XCTAssertEqual(merged.authorizationListUpdated, later.authorizationListUpdated)
        XCTAssertEqual(merged.updatedIncomingThreadReadStates, later.updatedIncomingThreadReadStates)
        XCTAssertEqual(merged.updatedOutgoingThreadReadStates, later.updatedOutgoingThreadReadStates)
        XCTAssertEqual(merged.updateConfig, later.updateConfig)
        XCTAssertEqual(merged.isPremiumUpdated, later.isPremiumUpdated)
        XCTAssertEqual(merged.updatedStarsBalance, later.updatedStarsBalance)
        XCTAssertEqual(merged.updatedTonBalance, later.updatedTonBalance)
        XCTAssertEqual(merged.walletTransferUpdates, later.walletTransferUpdates)
        XCTAssertEqual(merged.walletTonConnectEvents, later.walletTonConnectEvents)
        XCTAssertEqual(self.walletStateEmptyFlags(merged.updatedWalletState), 1)
        XCTAssertEqual(self.activeProvider(merged.updatedAgentSettings), "later")
        XCTAssertEqual(merged.updatedStarsRevenueStatus, later.updatedStarsRevenueStatus)
        XCTAssertEqual(merged.reportMessageDelivery, later.reportMessageDelivery)
        XCTAssertEqual(merged.addedConferenceInvitationMessagesIds, later.addedConferenceInvitationMessagesIds)
        XCTAssertEqual(merged.updatedStarGiftAuctionState, later.updatedStarGiftAuctionState)
        XCTAssertEqual(merged.updatedStarGiftAuctionMyState, later.updatedStarGiftAuctionMyState)
        XCTAssertEqual(merged.updatedEmojiGameInfo, later.updatedEmojiGameInfo)
        XCTAssertFalse(merged.isEmpty)
    }

    /// The number of stored fields (G-I M1). The compiler makes `init()`, `init(state:)`, `union(with:)` and
    /// `AccountFinalStateEvents.testing(...)` name a new field only when it is a `let` with no initial value whose
    /// memberwise parameter has no default; a `var` with an initial value, an optional `var` or a defaulted
    /// parameter compiles and `union(with:)` drops it. This count fails for a field of any kind.
    func testStoredFieldCountMatchesEveryInitAndUnion() {
        let count = Mirror(reflecting: AccountFinalStateEvents()).children.count
        XCTAssertEqual(count, 36, "AccountFinalStateEvents has \(count) stored fields, not 36: update init(), init(state:) and union(with:) (AccountIntermediateState.swift) and the test helper AccountFinalStateEvents.testing(...) (Tests/StateSync/AccountFinalStateEvents+Testing.swift) for the changed field, then this count")
    }

    /// Lists append in replay order, sets unite, flags OR; current-state values (balances, revenue,
    /// auction states, wallet state, emoji game info, web pages, a peer's typing activity in a chat)
    /// take the later value; read maxima, the max message id, qts and the notification delay take the
    /// maximum.
    func testUnionMergesEachFieldByItsPolicy() {
        let merged = self.earlier.union(with: self.later)

        // Appended, earlier first.
        XCTAssertEqual(merged.addedIncomingMessageIds, [self.messageId(1), self.messageId(11)])
        XCTAssertEqual(merged.addedReactionEvents.map { $0.timestamp }, [1, 2])
        XCTAssertEqual(merged.wasScheduledMessageIds, [self.messageId(2), self.messageId(12)])
        XCTAssertEqual(merged.deletedMessageIds, [.global(1), .global(2)])
        XCTAssertEqual(self.callIds(merged.updatedCalls), [1, 2])
        XCTAssertEqual(merged.addedCallSignalingData.map { $0.0 }, [1, 2])
        XCTAssertEqual(merged.updatedGroupCallParticipants.map { $0.0 }, [1, 2])
        XCTAssertEqual(merged.groupCallMessageUpdates.map { $0.callId }, [1, 2])
        XCTAssertEqual(self.storyReadMaxIds(merged.storyUpdates), [1, 2])
        XCTAssertEqual(merged.displayAlerts.map { $0.text }, ["earlier", "later"])
        XCTAssertEqual(merged.dismissBotWebViews, [1, 2])
        XCTAssertEqual(merged.joinChatWebViewDecisions.map { $0.queryId }, [1, 2])
        XCTAssertEqual(merged.walletTransferUpdates, [self.gasless(left: 1), self.gasless(left: 2)])
        XCTAssertEqual(merged.walletTonConnectEvents, [.pendingDisconnect(sessionIds: [1]), .pendingDisconnect(sessionIds: [2])])
        XCTAssertEqual(merged.addedConferenceInvitationMessagesIds, [self.messageId(5), self.messageId(15)])

        // United.
        XCTAssertEqual(merged.sentScheduledMessageIds, [self.messageId(3), self.messageId(13)])
        XCTAssertEqual(merged.reportMessageDelivery, [self.messageId(4), self.messageId(14)])
        XCTAssertEqual(merged.externallyUpdatedPeerId, [self.userA, self.userB])
        XCTAssertTrue(merged.authorizationListUpdated)
        XCTAssertTrue(merged.updateConfig)
        XCTAssertTrue(merged.isPremiumUpdated)

        // Per chat, then per peer, the later activity winning; userA's stop is kept as a nil activity.
        let expectedTyping: [PeerActivitySpace: [PeerId: PeerInputActivity?]] = [
            self.globalSpace: [self.userA: nil, self.userB: .typingText],
            self.threadSpace(7): [self.userA: .typingText],
            self.threadSpace(8): [self.userB: .typingText]
        ]
        XCTAssertEqual(merged.updatedTypingActivities, expectedTyping)
        XCTAssertEqual(Set(merged.updatedWebpages.keys), [self.webpageId(1), self.webpageId(2)])

        // The maximum per thread, whichever side holds it.
        let expectedReadStates: [PeerAndBoundThreadId: MessageId.Id] = [self.thread(1): 7, self.thread(2): 7, self.thread(3): 4, self.thread(4): 9]
        XCTAssertEqual(merged.updatedIncomingThreadReadStates, expectedReadStates)
        XCTAssertEqual(merged.updatedOutgoingThreadReadStates, expectedReadStates)
        XCTAssertEqual(merged.delayNotificatonsUntil, 20)
        XCTAssertEqual(merged.updatedMaxMessageId, 10)
        XCTAssertEqual(merged.updatedQts, 20)

        // The later value per key; keys only the earlier side has are kept.
        XCTAssertEqual(merged.updatedStarsBalance, [self.userA: self.stars(2), self.userB: self.stars(10)])
        XCTAssertEqual(merged.updatedTonBalance, [self.userA: self.stars(2), self.userB: self.stars(10)])
        XCTAssertEqual(merged.updatedStarsRevenueStatus, [self.userA: self.revenue(2), self.userB: self.revenue(10)])
        XCTAssertEqual(merged.updatedStarGiftAuctionState, [1: self.auctionState(averagePrice: 2), 2: self.auctionState(averagePrice: 10)])
        XCTAssertEqual(merged.updatedStarGiftAuctionMyState, [1: self.auctionMyState(bidAmount: 2), 2: self.auctionMyState(bidAmount: 10)])
        XCTAssertEqual(self.walletStateEmptyFlags(merged.updatedWalletState), 1)
        XCTAssertEqual(self.activeProvider(merged.updatedAgentSettings), "later")
        XCTAssertEqual(merged.updatedEmojiGameInfo, .unavailable)
    }

    /// A value only the earlier side holds is kept, and a maximum is a maximum whichever side holds it.
    func testUnionKeepsTheEarlierValueWhenTheLaterHasNone() {
        let earlier = AccountFinalStateEvents.testing(delayNotificatonsUntil: 30, updatedMaxMessageId: 30, updatedQts: 30, updatedWalletState: .walletStateEmpty(.init(flags: 1 << 0)), updatedAgentSettings: self.agentSettings("earlier"), updatedEmojiGameInfo: self.emojiGame("earlier"))

        let withNothingLater = earlier.union(with: AccountFinalStateEvents())
        XCTAssertEqual(withNothingLater.delayNotificatonsUntil, 30)
        XCTAssertEqual(withNothingLater.updatedMaxMessageId, 30)
        XCTAssertEqual(withNothingLater.updatedQts, 30)
        XCTAssertEqual(self.walletStateEmptyFlags(withNothingLater.updatedWalletState), 1)
        XCTAssertEqual(self.activeProvider(withNothingLater.updatedAgentSettings), "earlier")
        XCTAssertEqual(withNothingLater.updatedEmojiGameInfo, self.emojiGame("earlier"))

        let withSmallerLater = earlier.union(with: AccountFinalStateEvents.testing(delayNotificatonsUntil: 20, updatedMaxMessageId: 20, updatedQts: 20))
        XCTAssertEqual(withSmallerLater.delayNotificatonsUntil, 30)
        XCTAssertEqual(withSmallerLater.updatedMaxMessageId, 30)
        XCTAssertEqual(withSmallerLater.updatedQts, 30)
    }
}
