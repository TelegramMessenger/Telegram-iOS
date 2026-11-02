import Foundation
import Postbox
import TelegramApi
@testable import TelegramCore

extension AccountFinalStateEvents {
    /// Events with only the named fields set; every other field is empty, as `AccountFinalStateEvents()`
    /// has it. Test target only: production code gives every field (the memberwise init has no default
    /// values, seam 7), which is what keeps `union(with:)` complete when a field is added.
    static func testing(
        addedIncomingMessageIds: [MessageId] = [],
        addedReactionEvents: [(reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)] = [],
        wasScheduledMessageIds: [MessageId] = [],
        deletedMessageIds: [DeletedMessageId] = [],
        updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]] = [:],
        updatedWebpages: [MediaId: TelegramMediaWebpage?] = [:],
        updatedCalls: [Api.PhoneCall] = [],
        addedCallSignalingData: [(Int64, Data)] = [],
        updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)] = [],
        groupCallMessageUpdates: [GroupCallMessageUpdate] = [],
        storyUpdates: [InternalStoryUpdate] = [],
        displayAlerts: [(text: String, isDropAuth: Bool)] = [],
        dismissBotWebViews: [Int64] = [],
        joinChatWebViewDecisions: [JoinChatWebViewDecision] = [],
        delayNotificatonsUntil: Int32? = nil,
        updatedMaxMessageId: Int32? = nil,
        updatedQts: Int32? = nil,
        externallyUpdatedPeerId: Set<PeerId> = Set(),
        authorizationListUpdated: Bool = false,
        updatedIncomingThreadReadStates: [PeerAndBoundThreadId: MessageId.Id] = [:],
        updatedOutgoingThreadReadStates: [PeerAndBoundThreadId: MessageId.Id] = [:],
        updateConfig: Bool = false,
        isPremiumUpdated: Bool = false,
        updatedStarsBalance: [PeerId: StarsAmount] = [:],
        updatedTonBalance: [PeerId: StarsAmount] = [:],
        walletTransferUpdates: [WalletTransferUpdate] = [],
        walletTonConnectEvents: [WalletTonConnectEvent] = [],
        updatedWalletState: Api.WalletState? = nil,
        updatedAgentSettings: EngineAgentSettings? = nil,
        updatedStarsRevenueStatus: [PeerId: StarsRevenueStats.Balances] = [:],
        sentScheduledMessageIds: Set<MessageId> = Set(),
        reportMessageDelivery: Set<MessageId> = Set(),
        addedConferenceInvitationMessagesIds: [MessageId] = [],
        updatedStarGiftAuctionState: [Int64: GiftAuctionContext.State.AuctionState] = [:],
        updatedStarGiftAuctionMyState: [Int64: GiftAuctionContext.State.MyState] = [:],
        updatedEmojiGameInfo: EmojiGameInfo? = nil
    ) -> AccountFinalStateEvents {
        return AccountFinalStateEvents(
            addedIncomingMessageIds: addedIncomingMessageIds,
            addedReactionEvents: addedReactionEvents,
            wasScheduledMessageIds: wasScheduledMessageIds,
            deletedMessageIds: deletedMessageIds,
            updatedTypingActivities: updatedTypingActivities,
            updatedWebpages: updatedWebpages,
            updatedCalls: updatedCalls,
            addedCallSignalingData: addedCallSignalingData,
            updatedGroupCallParticipants: updatedGroupCallParticipants,
            groupCallMessageUpdates: groupCallMessageUpdates,
            storyUpdates: storyUpdates,
            displayAlerts: displayAlerts,
            dismissBotWebViews: dismissBotWebViews,
            joinChatWebViewDecisions: joinChatWebViewDecisions,
            delayNotificatonsUntil: delayNotificatonsUntil,
            updatedMaxMessageId: updatedMaxMessageId,
            updatedQts: updatedQts,
            externallyUpdatedPeerId: externallyUpdatedPeerId,
            authorizationListUpdated: authorizationListUpdated,
            updatedIncomingThreadReadStates: updatedIncomingThreadReadStates,
            updatedOutgoingThreadReadStates: updatedOutgoingThreadReadStates,
            updateConfig: updateConfig,
            isPremiumUpdated: isPremiumUpdated,
            updatedStarsBalance: updatedStarsBalance,
            updatedTonBalance: updatedTonBalance,
            walletTransferUpdates: walletTransferUpdates,
            walletTonConnectEvents: walletTonConnectEvents,
            updatedWalletState: updatedWalletState,
            updatedAgentSettings: updatedAgentSettings,
            updatedStarsRevenueStatus: updatedStarsRevenueStatus,
            sentScheduledMessageIds: sentScheduledMessageIds,
            reportMessageDelivery: reportMessageDelivery,
            addedConferenceInvitationMessagesIds: addedConferenceInvitationMessagesIds,
            updatedStarGiftAuctionState: updatedStarGiftAuctionState,
            updatedStarGiftAuctionMyState: updatedStarGiftAuctionMyState,
            updatedEmojiGameInfo: updatedEmojiGameInfo
        )
    }
}
