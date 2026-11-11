import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

private func sortedUpdates(_ updates: [Api.Update]) -> [Api.Update] {
    var otherUpdates: [Api.Update] = []
    var updatesByChannel: [PeerId: [Api.Update]] = [:]
    
    for update in updates {
        switch update {
            case let .updateChannelTooLong(updateChannelTooLongData):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateChannelTooLongData.channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updatePinnedForumTopic(updatePinnedForumTopicData):
                let peerId = updatePinnedForumTopicData.peer.peerId
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updatePinnedForumTopics(updatePinnedForumTopicsData):
                let peerId = updatePinnedForumTopicsData.peer.peerId
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateDeleteChannelMessages(updateDeleteChannelMessagesData):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateDeleteChannelMessagesData.channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updatePinnedChannelMessages(updatePinnedChannelMessagesData):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updatePinnedChannelMessagesData.channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                if let peerId = apiMessagePeerId(updateNewChannelMessageData.message) {
                    if updatesByChannel[peerId] == nil {
                        updatesByChannel[peerId] = [update]
                    } else {
                        updatesByChannel[peerId]!.append(update)
                    }
                } else {
                    otherUpdates.append(update)
                }
            case let .updateEditChannelMessage(updateEditChannelMessageData):
                if let peerId = apiMessagePeerId(updateEditChannelMessageData.message) {
                    if updatesByChannel[peerId] == nil {
                        updatesByChannel[peerId] = [update]
                    } else {
                        updatesByChannel[peerId]!.append(update)
                    }
                } else {
                    otherUpdates.append(update)
                }
            case let .updateChannelWebPage(updateChannelWebPageData):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateChannelWebPageData.channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateChannelAvailableMessages(updateChannelAvailableMessagesData):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateChannelAvailableMessagesData.channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            default:
                otherUpdates.append(update)
        }
    }
    
    var result: [Api.Update] = []
    
    for (_, updates) in updatesByChannel {
        let sortedUpdates = updates.sorted(by: { lhs, rhs in
            var lhsPts: Int32?
            var rhsPts: Int32?
            
            switch lhs {
                case let .updateDeleteChannelMessages(updateDeleteChannelMessagesData):
                    lhsPts = updateDeleteChannelMessagesData.pts
                case let .updateNewChannelMessage(updateNewChannelMessageData):
                    lhsPts = updateNewChannelMessageData.pts
                case let .updateChannelWebPage(updateChannelWebPageData):
                    lhsPts = updateChannelWebPageData.pts
                case let .updateEditChannelMessage(updateEditChannelMessageData):
                    lhsPts = updateEditChannelMessageData.pts
                case let .updatePinnedChannelMessages(updatePinnedChannelMessagesData):
                    lhsPts = updatePinnedChannelMessagesData.pts
                default:
                    break
            }
            
            switch rhs {
                case let .updateDeleteChannelMessages(updateDeleteChannelMessagesData):
                    rhsPts = updateDeleteChannelMessagesData.pts
                case let .updateNewChannelMessage(updateNewChannelMessageData):
                    rhsPts = updateNewChannelMessageData.pts
                case let .updateChannelWebPage(updateChannelWebPageData):
                    rhsPts = updateChannelWebPageData.pts
                case let .updateEditChannelMessage(updateEditChannelMessageData):
                    rhsPts = updateEditChannelMessageData.pts
                case let .updatePinnedChannelMessages(updatePinnedChannelMessagesData):
                    rhsPts = updatePinnedChannelMessagesData.pts
                default:
                    break
            }
            
            if let lhsPts = lhsPts, let rhsPts = rhsPts {
                return lhsPts < rhsPts
            } else if let _ = lhsPts {
                return true
            } else {
                return false
            }
        })
        result.append(contentsOf: sortedUpdates)
    }
    result.append(contentsOf: otherUpdates)
    
    return result
}

func finalStateWithUpdates(accountPeerId: PeerId, postbox: Postbox, network: Network, state: AccountMutableState, updates: [Api.Update], shouldPoll: Bool, missingUpdates: Bool, shouldResetChannels: Bool, updatesDate: Int32?, asyncResetChannels: (([(peer: Peer, pts: Int32?)]) -> Void)?) -> Signal<AccountFinalState, NoError> {
    return network.currentGlobalTime
    |> take(1)
    |> mapToSignal { serverTime -> Signal<AccountFinalState, NoError> in
        return finalStateWithUpdatesAndServerTime(accountPeerId: accountPeerId, postbox: postbox, network: network, state: state, updates: updates, shouldPoll: shouldPoll, missingUpdates: missingUpdates, shouldResetChannels: shouldResetChannels, updatesDate: updatesDate, serverTime: Int32(serverTime), asyncResetChannels: asyncResetChannels)
    }
}

private func finalStateWithUpdatesAndServerTime(accountPeerId: PeerId, postbox: Postbox, network: Network, state: AccountMutableState, updates: [Api.Update], shouldPoll: Bool, missingUpdates: Bool, shouldResetChannels: Bool, updatesDate: Int32?, serverTime: Int32, asyncResetChannels: (([(peer: Peer, pts: Int32?)]) -> Void)?) -> Signal<AccountFinalState, NoError> {
    var interpreter = UpdateInterpreter(accountPeerId: accountPeerId, state: state, updatesDate: updatesDate, serverTime: serverTime)
    for update in sortedUpdates(updates) {
        interpreter.apply(update)
    }
    let updatedState = interpreter.updatedState
    let channelRecovery = interpreter.channelRecovery
    
    return finalStateWithChannelRecovery(accountPeerId: accountPeerId, postbox: postbox, network: network, state: updatedState, channelRecovery: channelRecovery, shouldPoll: shouldPoll, missingUpdates: missingUpdates, shouldResetChannels: shouldResetChannels, asyncResetChannels: asyncResetChannels)
}

/// One batch of updates (a pushed batch, or the other updates of a difference) interpreted into
/// `updatedState` and `channelRecovery`, one update at a time. `finalStateWithUpdatesAndServerTime`
/// builds one, applies every update in `sortedUpdates` order and hands the two results to
/// `finalStateWithChannelRecovery`. Synchronous: no signal, no queue.
struct UpdateInterpreter {
    let accountPeerId: PeerId
    /// The state the batch started from. `updateChannelTooLong` decides whether to skip by this
    /// state's channel pts, not by `updatedState`'s, which earlier updates of the batch may have advanced.
    let state: AccountMutableState
    /// The date of the pushed batch's first dated group; nil when no group has one, and for a difference.
    let updatesDate: Int32?
    let serverTime: Int32
    /// Taken once, before the first update.
    let currentTime: Int32
    var updatedState: AccountMutableState
    var channelRecovery: ChannelRecoveryRequests

    init(accountPeerId: PeerId, state: AccountMutableState, updatesDate: Int32?, serverTime: Int32) {
        self.accountPeerId = accountPeerId
        self.state = state
        self.updatesDate = updatesDate
        self.serverTime = serverTime

        self.updatedState = state
    
        self.channelRecovery = ChannelRecoveryRequests()
    
        if !updatedState.initialState.channelsToPollExplicitely.isEmpty {
            for peerId in updatedState.initialState.channelsToPollExplicitely {
                channelRecovery.requestPoll(peerId, ptsHint: nil)
            }
        }
    
        self.currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    }

    /// Interprets one update: each case calls its method, in `UpdateInterpreter+<Family>.swift`, and
    /// `default` ignores the updates not handled here. No two cases match the same constructor, so their
    /// order decides nothing.
    mutating func apply(_ update: Api.Update) {
        switch update {
            case let .updateChannelTooLong(updateChannelTooLongData):
                self.applyChannelTooLong(updateChannelTooLongData)
            case let .updatePinnedForumTopics(updatePinnedForumTopicsData):
                self.applyPinnedForumTopics(updatePinnedForumTopicsData)
            case let .updateDeleteChannelMessages(updateDeleteChannelMessagesData):
                self.applyDeleteChannelMessages(updateDeleteChannelMessagesData)
            case let .updateEditChannelMessage(updateEditChannelMessageData):
                self.applyEditChannelMessage(updateEditChannelMessageData)
            case let .updateChannelWebPage(updateChannelWebPageData):
                self.applyChannelWebPage(updateChannelWebPageData)
            case let .updateChannelAvailableMessages(updateChannelAvailableMessagesData):
                self.applyChannelAvailableMessages(updateChannelAvailableMessagesData)
            case let .updateDeleteMessages(updateDeleteMessagesData):
                self.applyDeleteMessages(updateDeleteMessagesData)
            case let .updatePinnedMessages(updatePinnedMessagesData):
                self.applyPinnedMessages(updatePinnedMessagesData)
            case let .updateEditMessage(updateEditMessageData):
                self.applyEditMessage(updateEditMessageData)
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                self.applyNewChannelMessage(updateNewChannelMessageData)
            case let .updateNewMessage(updateNewMessageData):
                self.applyNewMessage(updateNewMessageData)
            case let .updateNewEphemeralMessage(updateNewEphemeralMessageData):
                self.applyNewEphemeralMessage(updateNewEphemeralMessageData)
            case let .updateEditEphemeralMessage(updateEditEphemeralMessageData):
                self.applyEditEphemeralMessage(updateEditEphemeralMessageData)
            case let .updateDeleteEphemeralMessages(updateDeleteEphemeralMessagesData):
                self.applyDeleteEphemeralMessages(updateDeleteEphemeralMessagesData)
            case let .updateServiceNotification(updateServiceNotificationData):
                self.applyServiceNotification(updateServiceNotificationData)
            case let .updateReadChannelInbox(updateReadChannelInboxData):
                self.applyReadChannelInbox(updateReadChannelInboxData)
            case let .updateReadChannelOutbox(updateReadChannelOutboxData):
                self.applyReadChannelOutbox(updateReadChannelOutboxData)
            case let .updateChannel(updateChannelData):
                self.applyChannel(updateChannelData)
            case let .updateChat(updateChatData):
                self.applyChat(updateChatData)
            case let .updateReadHistoryInbox(updateReadHistoryInboxData):
                self.applyReadHistoryInbox(updateReadHistoryInboxData)
            case let .updateReadHistoryOutbox(updateReadHistoryOutboxData):
                self.applyReadHistoryOutbox(updateReadHistoryOutboxData)
            case let .updateReadChannelDiscussionInbox(updateReadChannelDiscussionInboxData):
                self.applyReadChannelDiscussionInbox(updateReadChannelDiscussionInboxData)
            case let .updateReadChannelDiscussionOutbox(updateReadChannelDiscussionOutboxData):
                self.applyReadChannelDiscussionOutbox(updateReadChannelDiscussionOutboxData)
            case let .updateReadMonoForumInbox(updateReadMonoForumInboxData):
                self.applyReadMonoForumInbox(updateReadMonoForumInboxData)
            case let .updateReadMonoForumOutbox(updateReadMonoForumOutboxData):
                self.applyReadMonoForumOutbox(updateReadMonoForumOutboxData)
            case let .updateDialogUnreadMark(updateDialogUnreadMarkData):
                self.applyDialogUnreadMark(updateDialogUnreadMarkData)
            case let .updateWebPage(updateWebPageData):
                self.applyWebPage(updateWebPageData)
            case let .updateTranscribedAudio(updateTranscribedAudioData):
                self.applyTranscribedAudio(updateTranscribedAudioData)
            case let .updateNotifySettings(updateNotifySettingsData):
                self.applyNotifySettings(updateNotifySettingsData)
            case let .updateChatParticipants(updateChatParticipantsData):
                self.applyChatParticipants(updateChatParticipantsData)
            case let .updateChatParticipantAdd(updateChatParticipantAddData):
                self.applyChatParticipantAdd(updateChatParticipantAddData)
            case let .updateChatParticipantDelete(updateChatParticipantDeleteData):
                self.applyChatParticipantDelete(updateChatParticipantDeleteData)
            case let .updateChatParticipantAdmin(updateChatParticipantAdminData):
                self.applyChatParticipantAdmin(updateChatParticipantAdminData)
            case let .updateChatParticipantRank(updateChatParticipantRankData):
                self.applyChatParticipantRank(updateChatParticipantRankData)
            case let .updateChatDefaultBannedRights(updateChatDefaultBannedRightsData):
                self.applyChatDefaultBannedRights(updateChatDefaultBannedRightsData)
            case let .updatePinnedChannelMessages(updatePinnedChannelMessagesData):
                self.applyPinnedChannelMessages(updatePinnedChannelMessagesData)
            case let .updatePeerBlocked(updatePeerBlockedData):
                self.applyPeerBlocked(updatePeerBlockedData)
            case let .updateUserStatus(updateUserStatusData):
                self.applyUserStatus(updateUserStatusData)
            case let .updateUserName(updateUserNameData):
                self.applyUserName(updateUserNameData)
            case let .updateUserPhone(updateUserPhoneData):
                self.applyUserPhone(updateUserPhoneData)
            case let .updateUserEmojiStatus(updateUserEmojiStatusData):
                self.applyUserEmojiStatus(updateUserEmojiStatusData)
            case let .updatePeerSettings(updatePeerSettingsData):
                self.applyPeerSettings(updatePeerSettingsData)
            case let .updateEncryption(updateEncryptionData):
                self.applyEncryption(updateEncryptionData)
            case let .updateNewEncryptedMessage(updateNewEncryptedMessageData):
                self.applyNewEncryptedMessage(updateNewEncryptedMessageData)
            case let .updateEncryptedMessagesRead(updateEncryptedMessagesReadData):
                self.applyEncryptedMessagesRead(updateEncryptedMessagesReadData)
            case let .updateUserTyping(updateUserTypingData):
                self.applyUserTyping(updateUserTypingData)
            case let .updateChatUserTyping(updateChatUserTyping):
                self.applyChatUserTyping(updateChatUserTyping)
            case let .updateChannelUserTyping(updateChannelUserTypingData):
                self.applyChannelUserTyping(updateChannelUserTypingData)
            case let .updateEncryptedChatTyping(updateEncryptedChatTypingData):
                self.applyEncryptedChatTyping(updateEncryptedChatTypingData)
            case let .updateDialogPinned(updateDialogPinnedData):
                self.applyDialogPinned(updateDialogPinnedData)
            case let .updatePinnedDialogs(updatePinnedDialogsData):
                self.applyPinnedDialogs(updatePinnedDialogsData)
            case let .updateSavedDialogPinned(updateSavedDialogPinnedData):
                self.applySavedDialogPinned(updateSavedDialogPinnedData)
            case let .updatePinnedSavedDialogs(updatePinnedSavedDialogsData):
                self.applyPinnedSavedDialogs(updatePinnedSavedDialogsData)
            case let .updatePinnedForumTopic(updatePinnedForumTopicData):
                self.applyPinnedForumTopic(updatePinnedForumTopicData)
            case let .updateEditForumTopic(updateEditForumTopicData):
                self.applyEditForumTopic(updateEditForumTopicData)
            case let .updateReadMessagesContents(updateReadMessagesContentsData):
                self.applyReadMessagesContents(updateReadMessagesContentsData)
            case let .updateChannelReadMessagesContents(updateChannelReadMessagesContentsData):
                self.applyChannelReadMessagesContents(updateChannelReadMessagesContentsData)
            case let .updateChannelMessageViews(updateChannelMessageViewsData):
                self.applyChannelMessageViews(updateChannelMessageViewsData)
            case let .updateNewStickerSet(updateNewStickerSetData):
                self.applyNewStickerSet(updateNewStickerSetData)
            case let .updateStickerSetsOrder(updateStickerSetsOrderData):
                self.applyStickerSetsOrder(updateStickerSetsOrderData)
            case let .updateMoveStickerSetToTop(updateMoveStickerSetToTopData):
                self.applyMoveStickerSetToTop(updateMoveStickerSetToTopData)
            case .updateStickerSets:
                self.applyStickerSets()
            case .updateSavedGifs:
                self.applySavedGifs()
            case let .updateDraftMessage(updateDraftMessageData):
                self.applyDraftMessage(updateDraftMessageData)
            case let .updatePhoneCall(updatePhoneCallData):
                self.applyPhoneCall(updatePhoneCallData)
            case let .updatePhoneCallSignalingData(updatePhoneCallSignalingData):
                self.applyPhoneCallSignalingData(updatePhoneCallSignalingData)
            case let .updateGroupCallParticipants(updateGroupCallParticipantsData):
                self.applyGroupCallParticipants(updateGroupCallParticipantsData)
            case let .updateGroupCall(updateGroupCallData):
                self.applyGroupCall(updateGroupCallData)
            case let .updateGroupCallChainBlocks(updateGroupCallChainBlocksData):
                self.applyGroupCallChainBlocks(updateGroupCallChainBlocksData)
            case let .updateGroupCallMessage(updateGroupCallMessageData):
                self.applyGroupCallMessage(updateGroupCallMessageData)
            case let .updateGroupCallEncryptedMessage(updateGroupCallEncryptedMessageData):
                self.applyGroupCallEncryptedMessage(updateGroupCallEncryptedMessageData)
            case let .updatePeerHistoryTTL(updatePeerHistoryTTLData):
                self.applyPeerHistoryTTL(updatePeerHistoryTTLData)
            case let .updateLangPackTooLong(updateLangPackTooLongData):
                self.applyLangPackTooLong(updateLangPackTooLongData)
            case let .updateLangPack(updateLangPackData):
                self.applyLangPack(updateLangPackData)
            case let .updateMessagePoll(updateMessagePollData):
                self.applyMessagePoll(updateMessagePollData)
            case let .updateFolderPeers(updateFolderPeersData):
                self.applyFolderPeers(updateFolderPeersData)
            case let .updateNewScheduledMessage(updateNewScheduledMessageData):
                self.applyNewScheduledMessage(updateNewScheduledMessageData)
            case let .updateQuickReplyMessage(updateQuickReplyMessageData):
                self.applyQuickReplyMessage(updateQuickReplyMessageData)
            case let .updateDeleteScheduledMessages(updateDeleteScheduledMessagesData):
                self.applyDeleteScheduledMessages(updateDeleteScheduledMessagesData)
            case let .updateDeleteQuickReplyMessages(updateDeleteQuickReplyMessagesData):
                self.applyDeleteQuickReplyMessages(updateDeleteQuickReplyMessagesData)
            case let .updateTheme(updateThemeData):
                self.applyTheme(updateThemeData)
            case let .updateMessageID(updateMessageIDData):
                self.applyMessageID(updateMessageIDData)
            case .updateDialogFilters:
                self.applyDialogFilters()
            case let .updateDialogFilterOrder(updateDialogFilterOrderData):
                self.applyDialogFilterOrder(updateDialogFilterOrderData)
            case let .updateDialogFilter(updateDialogFilterData):
                self.applyDialogFilter(updateDialogFilterData)
            case let .updateBotCommands(updateBotCommandsData):
                self.applyBotCommands(updateBotCommandsData)
            case let .updateBotMenuButton(updateBotMenuButtonData):
                self.applyBotMenuButton(updateBotMenuButtonData)
            case let .updatePendingJoinRequests(updatePendingJoinRequestsData):
                self.applyPendingJoinRequests(updatePendingJoinRequestsData)
            case let .updateMessageReactions(updateMessageReactionsData):
                self.applyMessageReactions(updateMessageReactionsData)
            case .updateAttachMenuBots:
                self.applyAttachMenuBots()
            case let .updateWebViewResultSent(updateWebViewResultSentData):
                self.applyWebViewResultSent(updateWebViewResultSentData)
            case let .updateJoinChatWebViewDecision(updateJoinChatWebViewDecisionData):
                self.applyJoinChatWebViewDecision(updateJoinChatWebViewDecisionData)
            case .updateConfig:
                self.applyConfig()
            case let .updateMessageExtendedMedia(updateMessageExtendedMediaData):
                self.applyMessageExtendedMedia(updateMessageExtendedMediaData)
            case let .updateMessageWidgetData(updateMessageWidgetDataData):
                self.applyMessageWidgetData(updateMessageWidgetDataData)
            case let .updateStory(updateStoryData):
                self.applyStory(updateStoryData)
            case let .updateReadStories(updateReadStoriesData):
                self.applyReadStories(updateReadStoriesData)
            case let .updateStoriesStealthMode(updateStoriesStealthModeData):
                self.applyStoriesStealthMode(updateStoriesStealthModeData)
            case let .updateSentStoryReaction(updateSentStoryReactionData):
                self.applySentStoryReaction(updateSentStoryReactionData)
            case let .updateNewAuthorization(updateNewAuthorizationData):
                self.applyNewAuthorization(updateNewAuthorizationData)
            case let .updateNewBotConnection(updateNewBotConnectionData):
                self.applyNewBotConnection(updateNewBotConnectionData)
            case let .updateWebBrowserSettings(updateWebBrowserSettingsData):
                self.applyWebBrowserSettings(updateWebBrowserSettingsData)
            case let .updateWebBrowserException(updateWebBrowserExceptionData):
                self.applyWebBrowserException(updateWebBrowserExceptionData)
            case let .updatePeerWallpaper(updatePeerWallpaperData):
                self.applyPeerWallpaper(updatePeerWallpaperData)
            case let .updateStarsBalance(updateStarsBalanceData):
                self.applyStarsBalance(updateStarsBalanceData)
            case .updateSentWalletTransaction, .updateWalletGaslessInfo:
                self.applyWalletTransferUpdate(update)
            case let .updateWalletTonConnectSession(data):
                self.applyWalletTonConnectSession(data)
            case let .updateWalletTonConnectPendingDisconnect(data):
                self.applyWalletTonConnectPendingDisconnect(data)
            case let .updateWalletState(updateWalletStateData):
                self.applyWalletState(updateWalletStateData)
#if TELEGRAM_AGENT_API
            case let .updateAgentSettings(updateAgentSettingsData):
                self.applyAgentSettings(updateAgentSettingsData)
#endif
            case let .updateStarsRevenueStatus(updateStarsRevenueStatusData):
                self.applyStarsRevenueStatus(updateStarsRevenueStatusData)
            case let .updatePaidReactionPrivacy(updatePaidReactionPrivacyData):
                self.applyPaidReactionPrivacy(updatePaidReactionPrivacyData)
            case let .updateMonoForumNoPaidException(updateMonoForumNoPaidExceptionData):
                self.applyMonoForumNoPaidException(updateMonoForumNoPaidExceptionData)
            case let .updateStarGiftAuctionState(updateStarGiftAuctionStateData):
                self.applyStarGiftAuctionState(updateStarGiftAuctionStateData)
            case let .updateStarGiftAuctionUserState(updateStarGiftAuctionUserStateData):
                self.applyStarGiftAuctionUserState(updateStarGiftAuctionUserStateData)
            case let .updateEmojiGameInfo(updateEmojiGameInfoData):
                self.applyEmojiGameInfo(updateEmojiGameInfoData)
#if TELEGRAM_NEWS_FEED_API
            case let .updateReadFeed(updateReadFeedData):
                self.applyReadFeed(updateReadFeedData)
#endif
            default:
                break
        }
    }
}
