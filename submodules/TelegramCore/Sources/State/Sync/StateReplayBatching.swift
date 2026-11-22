import Foundation
import Postbox

/// The account and channel state a final state advances, as `batchContentAndDeferStateOperations` collects it from
/// the state operations: for each kind, and each channel, the last value wins. `ReplayContext.applyStateAdvance`
/// applies it after every content operation, one kind at a time: the account state, then every channel's pts, then
/// every channel's invalidated pts, then every channel's synchronized-until message id, each dictionary iterated once.
struct StateAdvance {
    /// The last `.UpdateState`'s account state; nil when the final state moves none.
    var accountState: AuthorizedAccountState.State?
    /// Each channel's last `.UpdateChannelState` pts.
    var channelStates: [PeerId: AccountStateChannelState] = [:]
    /// Each channel's last `.UpdateChannelInvalidationPts`.
    var invalidatedChannelPts: [PeerId: Int32] = [:]
    /// Each channel's last `.UpdateChannelSynchronizedUntilMessage`.
    var channelSynchronizedUntilMessageIds: [PeerId: MessageId.Id] = [:]
}

/// A final state's operations as `replayFinalState` applies them: `content` first, in order, then `stateAdvance`.
struct BatchedReplayOperations {
    /// Every operation but the four state operations, in order and batched (`batchContentAndDeferStateOperations`).
    let content: [AccountStateMutationOperation]
    let stateAdvance: StateAdvance
}

private final class PendingMessageBatch {
    var messages: [StoreMessage]
    var location: AddMessagesLocation

    init(messages: [StoreMessage], location: AddMessagesLocation) {
        self.messages = messages
        self.location = location
    }
}

/// Splits a final state's operations into the content operations, in order (`content`), and the account and channel
/// state they advance (`stateAdvance`), which `replayFinalState` applies after every content operation. Adjacent
/// `.AddMessages` at one location are merged into one, and so are the `.AddScheduledMessages` and the
/// `.AddQuickReplyMessages` of each run between two other content operations: any other content operation first ends
/// the three pending batches, emitted (when not empty) as `.AddMessages`, `.AddScheduledMessages` and
/// `.AddQuickReplyMessages`, in that order; a state operation ends none of them. The batches still pending at the end
/// close `content`, in the same order.
func batchContentAndDeferStateOperations(_ operations: [AccountStateMutationOperation]) -> BatchedReplayOperations {
    var result: [AccountStateMutationOperation] = []

    var stateAdvance = StateAdvance()

    var currentAddMessages: PendingMessageBatch?
    var currentAddScheduledMessages: PendingMessageBatch?
    var currentAddQuickReplyMessages: PendingMessageBatch?
    for operation in operations {
        switch operation {
        case .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpsertEphemeralReplacement, .DeleteEphemeralMessages, .UpdateMessagePoll, .UpdateMessageReactions, .UpdateMedia, .MergeApiChats, .MergeApiUsers, .MergePeerPresences, .UpdatePeer, .ReadInbox, .ReadOutbox, .ResetReadState, .ResetIncomingReadState, .UpdatePeerChatUnreadMark, .ResetMessageTagSummary, .UpdateNotificationSettings, .UpdateGlobalNotificationSettings, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity, .AddPeerLiveTypingDraftUpdate, .AddPeerLiveTypingDraftStop, .UpdateCachedPeerData, .UpdatePinnedItemIds, .UpdatePinnedSavedItemIds, .UpdatePinnedTopic, .UpdatePinnedTopicOrder, .EditForumTopic, .ReadMessageContents, .UpdateMessageImpressionCount, .UpdateInstalledStickerPacks, .UpdateRecentGifs, .UpdateChatInputState, .UpdateCall, .AddCallSignalingData, .UpdateLangPack, .UpdateMinAvailableMessage, .UpdatePeerChatInclusion, .UpdateTheme, .SyncChatListFilters, .UpdateChatListFilter, .UpdateChatListFilterOrder, .UpdateReadThread, .UpdateMessagesPinned, .UpdateGroupCallParticipants, .UpdateGroupCall, .UpdateGroupCallChainBlocks, .UpdateGroupCallMessage, .UpdateGroupCallOpaqueMessage, .UpdateAutoremoveTimeout, .UpdateAttachMenuBots, .UpdateAudioTranscription, .UpdateConfig, .UpdateMessageWidgetData, .UpdateExtendedMedia, .ResetForumTopic, .UpdateStory, .UpdateReadStories, .UpdateStoryStealthMode, .UpdateStorySentReaction, .UpdateNewAuthorization, .UpdateNewBotConnection, .UpdateWebBrowserSettings, .UpdateWebBrowserException, .UpdateWallpaper, .UpdateStarsBalance, .UpdateStarsRevenueStatus, .UpdateStarsReactionsDefaultPrivacy, .ReportMessageDelivery, .UpdateMonoForumNoPaidException, .UpdateReadFeed, .UpdateStarGiftAuctionState, .UpdateStarGiftAuctionMyState, .UpdateEmojiGameInfo, .UpdateWalletState, .UpdateAgentSettings, .UpdateWalletTransfer, .UpdateWalletTonConnectEvent:
                if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
                    result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
                }
                if let currentAddScheduledMessages = currentAddScheduledMessages, !currentAddScheduledMessages.messages.isEmpty {
                    result.append(.AddScheduledMessages(currentAddScheduledMessages.messages))
                }
                if let currentAddQuickReplyMessages = currentAddQuickReplyMessages, !currentAddQuickReplyMessages.messages.isEmpty {
                    result.append(.AddQuickReplyMessages(currentAddQuickReplyMessages.messages))
                }
                currentAddMessages = nil
                currentAddScheduledMessages = nil
                currentAddQuickReplyMessages = nil
                result.append(operation)
            case let .UpdateState(state):
                stateAdvance.accountState = state
            case let .UpdateChannelState(peerId, pts):
                stateAdvance.channelStates[peerId] = AccountStateChannelState(pts: pts)
            case let .UpdateChannelInvalidationPts(peerId, pts):
                stateAdvance.invalidatedChannelPts[peerId] = pts
            case let .UpdateChannelSynchronizedUntilMessage(peerId, id):
                stateAdvance.channelSynchronizedUntilMessageIds[peerId] = id
            case let .AddMessages(messages, location):
                if let currentAddMessages = currentAddMessages, currentAddMessages.location == location {
                    currentAddMessages.messages.append(contentsOf: messages)
                } else {
                    if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
                        result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
                    }
                    currentAddMessages = PendingMessageBatch(messages: messages, location: location)
                }
            case let .AddScheduledMessages(messages):
                if let currentAddScheduledMessages = currentAddScheduledMessages {
                    currentAddScheduledMessages.messages.append(contentsOf: messages)
                } else {
                    currentAddScheduledMessages = PendingMessageBatch(messages: messages, location: .Random)
                }
            case let .AddQuickReplyMessages(messages):
                if let currentAddQuickReplyMessages = currentAddQuickReplyMessages {
                    currentAddQuickReplyMessages.messages.append(contentsOf: messages)
                } else {
                    currentAddQuickReplyMessages = PendingMessageBatch(messages: messages, location: .Random)
                }
        }
    }
    if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
        result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
    }

    if let currentAddScheduledMessages = currentAddScheduledMessages, !currentAddScheduledMessages.messages.isEmpty {
        result.append(.AddScheduledMessages(currentAddScheduledMessages.messages))
    }

    if let currentAddQuickReplyMessages = currentAddQuickReplyMessages, !currentAddQuickReplyMessages.messages.isEmpty {
        result.append(.AddQuickReplyMessages(currentAddQuickReplyMessages.messages))
    }

    return BatchedReplayOperations(content: result, stateAdvance: stateAdvance)
}
