import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Stars, the wallet, paid reactions and paid messages, gift auctions and the emoji game.
extension UpdateInterpreter {
    mutating func applyStarsBalance(_ updateStarsBalanceData: Api.Update.Cons_updateStarsBalance) {
        let amount = CurrencyAmount(apiAmount: updateStarsBalanceData.balance)
        updatedState.updateStarsBalance(peerId: accountPeerId, currency: amount.currency, balance: amount.amount)
    }
    
    /// Only `updateSentWalletTransaction` and `updateWalletGaslessInfo` come here (`apply` has one case for
    /// both). The update is kept as it is (`.UpdateWalletTransfer`), and the replay (`buildResult`) turns
    /// those two constructors into `WalletTransferUpdate`s; it drops an `updateSentWalletTransaction` with an
    /// empty `msgHash`, and any other constructor.
    mutating func applyWalletTransferUpdate(_ update: Api.Update) {
        updatedState.addWalletTransferUpdate(update)
    }
    
    mutating func applyWalletTonConnectSession(_ data: Api.Update.Cons_updateWalletTonConnectSession) {
        updatedState.addWalletTonConnectEvent(.session(WalletTonConnectSession(apiSession: data.session)))
    }
    
    mutating func applyWalletTonConnectPendingDisconnect(_ data: Api.Update.Cons_updateWalletTonConnectPendingDisconnect) {
        updatedState.addWalletTonConnectEvent(.pendingDisconnect(sessionIds: data.sessionIds))
    }
    
    mutating func applyWalletState(_ updateWalletStateData: Api.Update.Cons_updateWalletState) {
        updatedState.updateWalletState(updateWalletStateData.state)
    }

#if TELEGRAM_AGENT_API
    mutating func applyAgentSettings(_ updateAgentSettingsData: Api.Update.Cons_updateAgentSettings) {
        updatedState.updateAgentSettings(EngineAgentSettings(apiSettings: updateAgentSettingsData.settings))
    }
#endif
    
    mutating func applyStarsRevenueStatus(_ updateStarsRevenueStatusData: Api.Update.Cons_updateStarsRevenueStatus) {
        updatedState.updateStarsRevenueStatus(peerId: updateStarsRevenueStatusData.peer.peerId, status: StarsRevenueStats.Balances(apiStarsRevenueStatus: updateStarsRevenueStatusData.status))
    }
    
    mutating func applyPaidReactionPrivacy(_ updatePaidReactionPrivacyData: Api.Update.Cons_updatePaidReactionPrivacy) {
        let mappedPrivacy: TelegramPaidReactionPrivacy
        switch updatePaidReactionPrivacyData.private {
        case .paidReactionPrivacyDefault:
            mappedPrivacy = .default
        case .paidReactionPrivacyAnonymous:
            mappedPrivacy = .anonymous
        case let .paidReactionPrivacyPeer(paidReactionPrivacyPeerData):
            let peer = paidReactionPrivacyPeerData.peer
            let peerId: PeerId
            switch peer {
            case let .inputPeerChannel(inputPeerChannelData):
                let channelId = inputPeerChannelData.channelId
                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            case let .inputPeerChannelFromMessage(inputPeerChannelFromMessageData):
                let channelId = inputPeerChannelFromMessageData.channelId
                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            case let .inputPeerChat(inputPeerChatData):
                let chatId = inputPeerChatData.chatId
                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
            case .inputPeerEmpty:
                peerId = accountPeerId
            case .inputPeerSelf:
                peerId = accountPeerId
            case let .inputPeerUser(inputPeerUserData):
                let userId = inputPeerUserData.userId
                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            case let .inputPeerUserFromMessage(inputPeerUserFromMessageData):
                let userId = inputPeerUserFromMessageData.userId
                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            }
            mappedPrivacy = .peer(peerId)
        }
        updatedState.updateStarsReactionsDefaultPrivacy(privacy: mappedPrivacy)
    }
    
    mutating func applyMonoForumNoPaidException(_ updateMonoForumNoPaidExceptionData: Api.Update.Cons_updateMonoForumNoPaidException) {
        let (flags, channelId, savedPeerId) = (updateMonoForumNoPaidExceptionData.flags, updateMonoForumNoPaidExceptionData.channelId, updateMonoForumNoPaidExceptionData.savedPeerId)
        updatedState.updateMonoForumNoPaidException(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), threadId: savedPeerId.peerId.toInt64(), isFree: (flags & (1 << 0)) != 0)
    }
    
    mutating func applyStarGiftAuctionState(_ updateStarGiftAuctionStateData: Api.Update.Cons_updateStarGiftAuctionState) {
        let (giftId, state) = (updateStarGiftAuctionStateData.giftId, updateStarGiftAuctionStateData.state)
        if let state = GiftAuctionContext.State.AuctionState(apiAuctionState: state, peers: updatedState.peers) {
            updatedState.updateStarGiftAuctionState(giftId: giftId, state: state)
        }
    }
    
    mutating func applyStarGiftAuctionUserState(_ updateStarGiftAuctionUserStateData: Api.Update.Cons_updateStarGiftAuctionUserState) {
        let (giftId, userState) = (updateStarGiftAuctionUserStateData.giftId, updateStarGiftAuctionUserStateData.userState)
        updatedState.updateStarGiftAuctionMyState(giftId: giftId, state: GiftAuctionContext.State.MyState(apiAuctionUserState: userState))
    }
    
    mutating func applyEmojiGameInfo(_ updateEmojiGameInfoData: Api.Update.Cons_updateEmojiGameInfo) {
        updatedState.updateEmojiGameInfo(info: EmojiGameInfo(apiEmojiGameInfo: updateEmojiGameInfoData.info))
    }
}
