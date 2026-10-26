import Foundation
import Postbox
internal import TelegramApi

func _internal_synchronizeableChatInputState(accountPeerId: PeerId, peerId: PeerId, apiDraft: Api.DraftMessage) -> SynchronizeableChatInputState? {
    switch apiDraft {
    case .draftMessageEmpty:
        return nil
    case let .draftMessage(draftMessageData):
        let (replyToMsgHeader, message, entities, media, date, messageEffectId, suggestedPost) = (draftMessageData.replyTo, draftMessageData.message, draftMessageData.entities, draftMessageData.media, draftMessageData.date, draftMessageData.effect, draftMessageData.suggestedPost)
        let _ = media
        var replySubject: EngineMessageReplySubject?
        var parsedSuggestedPost: SynchronizeableChatInputState.SuggestedPost?
        if let suggestedPost {
            switch suggestedPost {
            case let .suggestedPost(suggestedPostData):
                parsedSuggestedPost = SynchronizeableChatInputState.SuggestedPost(price: suggestedPostData.price.flatMap(CurrencyAmount.init(apiAmount:)), timestamp: suggestedPostData.scheduleDate)
            }
        }
        if let replyToMsgHeader {
            switch replyToMsgHeader {
            case let .inputReplyToMessage(inputReplyToMessageData):
                let (replyToMsgId, topMsgId, replyToPeerId, quoteText, quoteEntities, quoteOffset, monoforumPeerId, todoItemId, pollOption, quoteRich) = (inputReplyToMessageData.replyToMsgId, inputReplyToMessageData.topMsgId, inputReplyToMessageData.replyToPeerId, inputReplyToMessageData.quoteText, inputReplyToMessageData.quoteEntities, inputReplyToMessageData.quoteOffset, inputReplyToMessageData.monoforumPeerId, inputReplyToMessageData.todoItemId, inputReplyToMessageData.pollOption, inputReplyToMessageData.quoteRich)
                let _ = topMsgId
                let _ = monoforumPeerId

                // A draft keeps `quote_rich` as it was saved; the server validates it only on send.
                let quote = engineReplyQuote(text: quoteText, entities: quoteEntities, offset: quoteOffset, rich: quoteRich, media: nil)

                var parsedReplyToPeerId: PeerId?
                switch replyToPeerId {
                case let .inputPeerChannel(inputPeerChannelData):
                    let channelId = inputPeerChannelData.channelId
                    parsedReplyToPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                case let .inputPeerChannelFromMessage(inputPeerChannelFromMessageData):
                    let channelId = inputPeerChannelFromMessageData.channelId
                    parsedReplyToPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                case let .inputPeerChat(inputPeerChatData):
                    let chatId = inputPeerChatData.chatId
                    parsedReplyToPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                case .inputPeerEmpty:
                    break
                case .inputPeerSelf:
                    parsedReplyToPeerId = accountPeerId
                case let .inputPeerUser(inputPeerUserData):
                    let userId = inputPeerUserData.userId
                    parsedReplyToPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                case let .inputPeerUserFromMessage(inputPeerUserFromMessageData):
                    let userId = inputPeerUserFromMessageData.userId
                    parsedReplyToPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                case .none:
                    break
                }

                var innerSubject: EngineMessageReplyInnerSubject?
                if let todoItemId {
                    innerSubject = .todoItem(todoItemId)
                } else if let pollOption {
                    innerSubject = .pollOption(pollOption.makeData())
                }

                replySubject = EngineMessageReplySubject(
                    messageId: MessageId(peerId: parsedReplyToPeerId ?? peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId),
                    quote: quote,
                    innerSubject: innerSubject
                )
            case .inputReplyToStory:
                break
            case .inputReplyToMonoForum:
                break
            case .inputReplyToEphemeralMessage(_):
                break
            }
        }
        let syncContent: SynchronizeableChatInputState.Content
        if let apiRichMessage = draftMessageData.richMessage {
            syncContent = .instantPage(RichTextMessageAttribute(apiRichMessage: apiRichMessage).instantPage)
        } else {
            syncContent = .textEntities(text: message, entities: messageTextEntitiesFromApiEntities(entities ?? []))
        }
        return SynchronizeableChatInputState(replySubject: replySubject, content: syncContent, timestamp: date, textSelection: nil, messageEffectId: messageEffectId, suggestedPost: parsedSuggestedPost)
    }
}

// Applies drafts fetched via fetchChatList (regular dialogs, threadId nil) with a newer-wins guard:
// a fetched draft is written only when the peer has no local draft, or the fetched draft's `date` is
// strictly newer than the local draft's timestamp. So a fresh login restores everything, and a live-session
// hole-fill never clobbers a newer local edit. Only non-empty `.draftMessage` drafts are passed in, so a
// fetch never clears a draft (clearing stays with the real-time updateDraftMessage path).
func _internal_applyFetchedChatInputStates(transaction: Transaction, accountPeerId: PeerId, inputStates: [(PeerId, Api.DraftMessage)]) {
    for (peerId, apiDraft) in inputStates {
        guard let parsed = _internal_synchronizeableChatInputState(accountPeerId: accountPeerId, peerId: peerId, apiDraft: apiDraft) else {
            continue
        }
        var localTimestamp: Int32?
        if let peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId), let data = peerChatInterfaceState.data {
            localTimestamp = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState?.timestamp
        }
        if let localTimestamp, parsed.timestamp <= localTimestamp {
            continue
        }
        _internal_updateChatInputState(transaction: transaction, peerId: peerId, threadId: nil, inputState: parsed)
    }
}
