import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Messages outside the channel pts sequence (common-box, ephemeral, secret, scheduled and quick-reply
/// messages, service notifications, and the message id a sent message was given) and what hangs off a
/// message: web pages, polls, reactions, views, extended media, transcriptions, drafts, and a channel's
/// available-messages bound.
extension UpdateInterpreter {
    mutating func applyChannelAvailableMessages(_ updateChannelAvailableMessagesData: Api.Update.Cons_updateChannelAvailableMessages) {
        let (channelId, minId) = (updateChannelAvailableMessagesData.channelId, updateChannelAvailableMessagesData.availableMinId)
        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
        updatedState.updateMinAvailableMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: minId))
    }
    
    mutating func applyDeleteMessages(_ updateDeleteMessagesData: Api.Update.Cons_updateDeleteMessages) {
        updatedState.deleteMessagesWithGlobalIds(updateDeleteMessagesData.messages)
    }
    
    mutating func applyPinnedMessages(_ updatePinnedMessagesData: Api.Update.Cons_updatePinnedMessages) {
        let (flags, peer, messages) = (updatePinnedMessagesData.flags, updatePinnedMessagesData.peer, updatePinnedMessagesData.messages)
        let peerId = peer.peerId
        updatedState.updateMessagesPinned(ids: messages.map { id in
            MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
        }, pinned: (flags & (1 << 0)) != 0)
    }
    
    mutating func applyEditMessage(_ updateEditMessageData: Api.Update.Cons_updateEditMessage) {
        let apiMessage = updateEditMessageData.message
        var peerIsForum = false
        if let peerId = apiMessage.peerId {
            peerIsForum = updatedState.isPeerForum(peerId: peerId)
        }
        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum), case let .Id(messageId) = message.id {
            if let preCachedResources = apiMessage.preCachedResources {
                for (resource, data) in preCachedResources {
                    updatedState.addPreCachedResource(resource, data: data)
                }
            }
            if let preCachedStories = apiMessage.preCachedStories {
                for (id, story) in preCachedStories {
                    updatedState.addPreCachedStory(id: id, story: story)
                }
            }
            updatedState.editMessage(messageId, message: message)
            for media in message.media {
                if let media = media as? TelegramMediaAction {
                    if case .historyCleared = media.action {
                        updatedState.readInbox(messageId)
                    }
                }
            }
        }
    }
    
    mutating func applyNewMessage(_ updateNewMessageData: Api.Update.Cons_updateNewMessage) {
        let apiMessage = updateNewMessageData.message
        var peerIsForum = false
        if let peerId = apiMessage.peerId {
            peerIsForum = updatedState.isPeerForum(peerId: peerId)
        }
        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
            if let preCachedResources = apiMessage.preCachedResources {
                for (resource, data) in preCachedResources {
                    updatedState.addPreCachedResource(resource, data: data)
                }
            }
            if let preCachedStories = apiMessage.preCachedStories {
                for (id, story) in preCachedStories {
                    updatedState.addPreCachedStory(id: id, story: story)
                }
            }
            updatedState.addMessages([message], location: .UpperHistoryBlock)

            if let reportDeliveryAttribute = message.attributes.first(where: { $0 is ReportDeliveryMessageAttribute }) as? ReportDeliveryMessageAttribute, case let .Id(id) = message.id, reportDeliveryAttribute.untilDate > currentTime {
                updatedState.addReportMessageDelivery(messageIds: [id])
            }
        }
    }
    
    mutating func applyNewEphemeralMessage(_ updateNewEphemeralMessageData: Api.Update.Cons_updateNewEphemeralMessage) {
        let apiMessage = updateNewEphemeralMessageData.message
        if let message = StoreMessage(apiEphemeralMessage: apiMessage) {
            if let attribute = message.attributes.first(where: { $0 is EphemeralMessageAttribute }) as? EphemeralMessageAttribute, let anchorMessageId = attribute.anchorMessageId {
                updatedState.upsertEphemeralReplacement(anchorId: anchorMessageId, message: message)
            } else {
                if let preCachedResources = apiMessage.preCachedResources {
                    for (resource, data) in preCachedResources {
                        updatedState.addPreCachedResource(resource, data: data)
                    }
                }
                if let preCachedStories = apiMessage.preCachedStories {
                    for (id, story) in preCachedStories {
                        updatedState.addPreCachedStory(id: id, story: story)
                    }
                }
                updatedState.addMessages([message], location: .Random)
            }
        }
    }
    
    mutating func applyEditEphemeralMessage(_ updateEditEphemeralMessageData: Api.Update.Cons_updateEditEphemeralMessage) {
        let apiMessage = updateEditEphemeralMessageData.message
        if let message = StoreMessage(apiEphemeralMessage: apiMessage) {
            if let attribute = message.attributes.first(where: { $0 is EphemeralMessageAttribute }) as? EphemeralMessageAttribute, let anchorMessageId = attribute.anchorMessageId {
                updatedState.upsertEphemeralReplacement(anchorId: anchorMessageId, message: message)
            } else {
                if let preCachedResources = apiMessage.preCachedResources {
                    for (resource, data) in preCachedResources {
                        updatedState.addPreCachedResource(resource, data: data)
                    }
                }
                if let preCachedStories = apiMessage.preCachedStories {
                    for (id, story) in preCachedStories {
                        updatedState.addPreCachedStory(id: id, story: story)
                    }
                }
                if case let .Id(messageId) = message.id {
                    updatedState.editMessage(messageId, message: message)
                }
            }
        }
    }
    
    mutating func applyDeleteEphemeralMessages(_ updateDeleteEphemeralMessagesData: Api.Update.Cons_updateDeleteEphemeralMessages) {
        updatedState.deleteEphemeralMessages(peerId: updateDeleteEphemeralMessagesData.peer.peerId, ids: updateDeleteEphemeralMessagesData.ids)
    }
    
    mutating func applyServiceNotification(_ updateServiceNotificationData: Api.Update.Cons_updateServiceNotification) {
        let (flags, date, type, text, media, entities) = (updateServiceNotificationData.flags, updateServiceNotificationData.inboxDate, updateServiceNotificationData.type, updateServiceNotificationData.message, updateServiceNotificationData.media, updateServiceNotificationData.entities)
        let popup = (flags & (1 << 0)) != 0
        if popup {
            updatedState.addDisplayAlert(text, isDropAuth: type.hasPrefix("AUTH_KEY_DROP_"))
        } else if let date = date {
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))

            if updatedState.peers[peerId] == nil {
                updatedState.updatePeer(peerId, { peer in
                    if peer == nil {
                        return TelegramUser(id: peerId, accessHash: nil, firstName: "Telegram Notifications", lastName: nil, username: nil, phone: nil, photo: [], botInfo: BotUserInfo(flags: [], inlinePlaceholder: nil), restrictionInfo: nil, flags: [.isVerified], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                    } else {
                        return peer
                    }
                })
            }

            var alreadyStored = false
            if let storedMessages = updatedState.storedMessagesByPeerIdAndTimestamp[peerId] {
                for index in storedMessages {
                    if index.timestamp == date {
                        alreadyStored = true
                        break
                    }
                }
            }

            if alreadyStored {
                Logger.shared.log("State", "skipping message at \(date) for \(peerId): already stored")
            } else {
                var attributes: [MessageAttribute] = []
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: messageTextEntitiesFromApiEntities(entities)))
                }
                let messageText = text
                var medias: [Media] = []

                let (mediaValue, expirationTimer, nonPremium, hasSpoiler, webpageAttributes, videoTimestamp) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                if let mediaValue = mediaValue {
                    medias.append(mediaValue)

                    if mediaValue is TelegramMediaWebpage {
                        if let webpageAttributes = webpageAttributes {
                            attributes.append(WebpagePreviewMessageAttribute(leadingPreview: false, forceLargeMedia: webpageAttributes.forceLargeMedia, isManuallyAdded: webpageAttributes.isManuallyAdded, isSafe: webpageAttributes.isSafe))
                        }
                    }
                }
                if let expirationTimer = expirationTimer {
                    attributes.append(AutoclearTimeoutMessageAttribute(timeout: expirationTimer, countdownBeginTime: nil))
                }
                if let videoTimestamp {
                    attributes.append(ForwardVideoTimestampAttribute(timestamp: videoTimestamp))
                }

                if let nonPremium = nonPremium, nonPremium {
                    attributes.append(NonPremiumMessageAttribute())
                }

                if let hasSpoiler = hasSpoiler, hasSpoiler {
                    attributes.append(MediaSpoilerMessageAttribute())
                }

                if type.hasPrefix("auth") {
                    updatedState.authorizationListUpdated = true
                    let string = type.dropFirst(4).components(separatedBy: "_")
                    if string.count == 2, let hash = Int64(string[0]), let timestamp = Int32(string[1]) {
                        attributes.append(AuthSessionInfoAttribute(hash: hash, timestamp: timestamp))
                    }
                }

                let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: messageText, attributes: attributes, media: medias)
                updatedState.addMessages([message], location: .UpperHistoryBlock)
            }
        }
    }
    
    mutating func applyWebPage(_ updateWebPageData: Api.Update.Cons_updateWebPage) {
        switch updateWebPageData.webpage {
            case let .webPageEmpty(webPageEmptyData):
                let (flags, id, url) = (webPageEmptyData.flags, webPageEmptyData.id, webPageEmptyData.url)
                let _ = flags
                let _ = url
                updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
            default:
                if let webpage = telegramMediaWebpageFromApiWebpage(updateWebPageData.webpage) {
                    updatedState.updateMedia(webpage.webpageId, media: webpage)
                }
        }
    }
    
    mutating func applyTranscribedAudio(_ updateTranscribedAudioData: Api.Update.Cons_updateTranscribedAudio) {
        let (flags, peer, msgId, transcriptionId, text) = (updateTranscribedAudioData.flags, updateTranscribedAudioData.peer, updateTranscribedAudioData.msgId, updateTranscribedAudioData.transcriptionId, updateTranscribedAudioData.text)
        let isPending = (flags & (1 << 0)) != 0
        updatedState.updateAudioTranscription(messageId: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), id: transcriptionId, isPending: isPending, text: text)
    }
    
    mutating func applyNewEncryptedMessage(_ updateNewEncryptedMessageData: Api.Update.Cons_updateNewEncryptedMessage) {
        updatedState.addSecretMessages([updateNewEncryptedMessageData.message])
    }
    
    mutating func applyChannelMessageViews(_ updateChannelMessageViewsData: Api.Update.Cons_updateChannelMessageViews) {
        updatedState.addUpdateMessageImpressionCount(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateChannelMessageViewsData.channelId)), namespace: Namespaces.Message.Cloud, id: updateChannelMessageViewsData.id), count: updateChannelMessageViewsData.views)
    }
    
    mutating func applyDraftMessage(_ updateDraftMessageData: Api.Update.Cons_updateDraftMessage) {
        let (peer, topMsgId, savedPeerId, draft) = (updateDraftMessageData.peer, updateDraftMessageData.topMsgId, updateDraftMessageData.savedPeerId, updateDraftMessageData.draft)
        let inputState = _internal_synchronizeableChatInputState(accountPeerId: accountPeerId, peerId: peer.peerId, apiDraft: draft)
        var threadId: Int64?
        if let savedPeerId {
            threadId = savedPeerId.peerId.toInt64()
        } else if let topMsgId {
            threadId = Int64(topMsgId)
        }
        updatedState.addUpdateChatInputState(peerId: peer.peerId, threadId: threadId, state: inputState)
    }
    
    mutating func applyMessagePoll(_ updateMessagePollData: Api.Update.Cons_updateMessagePoll) {
        updatedState.updateMessagePoll(MediaId(namespace: Namespaces.Media.CloudPoll, id: updateMessagePollData.pollId), poll: updateMessagePollData.poll, results: updateMessagePollData.results)
    }
    
    mutating func applyNewScheduledMessage(_ updateNewScheduledMessageData: Api.Update.Cons_updateNewScheduledMessage) {
        var peerIsForum = false
        if let peerId = updateNewScheduledMessageData.message.peerId {
            peerIsForum = updatedState.isPeerForum(peerId: peerId)
        }
        if let message = StoreMessage(apiMessage: updateNewScheduledMessageData.message, accountPeerId: accountPeerId, peerIsForum: peerIsForum, namespace: Namespaces.Message.ScheduledCloud) {
            updatedState.addScheduledMessages([message])
        }
    }
    
    mutating func applyQuickReplyMessage(_ updateQuickReplyMessageData: Api.Update.Cons_updateQuickReplyMessage) {
        var peerIsForum = false
        if let peerId = updateQuickReplyMessageData.message.peerId {
            peerIsForum = updatedState.isPeerForum(peerId: peerId)
        }
        if let message = StoreMessage(apiMessage: updateQuickReplyMessageData.message, accountPeerId: accountPeerId, peerIsForum: peerIsForum, namespace: Namespaces.Message.QuickReplyCloud) {
            updatedState.addQuickReplyMessages([message])
        }
    }
    
    mutating func applyDeleteScheduledMessages(_ updateDeleteScheduledMessagesData: Api.Update.Cons_updateDeleteScheduledMessages) {
        let (peer, messages, sentMessages) = (updateDeleteScheduledMessagesData.peer, updateDeleteScheduledMessagesData.messages, updateDeleteScheduledMessagesData.sentMessages)
        var messageIds: [MessageId] = []
        var sentMessageIds: [MessageId] = []
        for message in messages {
            messageIds.append(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.ScheduledCloud, id: message))
        }
        if let sentMessages {
            for message in sentMessages {
                sentMessageIds.append(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: message))
            }
        }
        updatedState.deleteMessages(messageIds)
        updatedState.addSentScheduledMessageIds(sentMessageIds)
    }
    
    mutating func applyDeleteQuickReplyMessages(_ updateDeleteQuickReplyMessagesData: Api.Update.Cons_updateDeleteQuickReplyMessages) {
        var messageIds: [MessageId] = []
        for message in updateDeleteQuickReplyMessagesData.messages {
            messageIds.append(MessageId(peerId: accountPeerId, namespace: Namespaces.Message.QuickReplyCloud, id: message))
        }
        updatedState.deleteMessages(messageIds)
    }
    
    mutating func applyMessageID(_ updateMessageIDData: Api.Update.Cons_updateMessageID) {
        updatedState.updatedOutgoingUniqueMessageIds[updateMessageIDData.randomId] = updateMessageIDData.id
    }
    
    mutating func applyMessageReactions(_ updateMessageReactionsData: Api.Update.Cons_updateMessageReactions) {
        let (peer, msgId, topMsgId, savedPeerId, reactions) = (updateMessageReactionsData.peer, updateMessageReactionsData.msgId, updateMessageReactionsData.topMsgId, updateMessageReactionsData.savedPeerId, updateMessageReactionsData.reactions)
        var threadId: Int64?
        if let savedPeerId {
            threadId = savedPeerId.peerId.toInt64()
        } else if let topMsgId {
            threadId = Int64(topMsgId)
        }

        updatedState.updateMessageReactions(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), threadId: threadId, reactions: reactions, eventTimestamp: updatesDate)
    }
    
    mutating func applyMessageExtendedMedia(_ updateMessageExtendedMediaData: Api.Update.Cons_updateMessageExtendedMedia) {
        let (peer, msgId, extendedMedia) = (updateMessageExtendedMediaData.peer, updateMessageExtendedMediaData.msgId, updateMessageExtendedMediaData.extendedMedia)
        updatedState.updateExtendedMedia(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), extendedMedia: extendedMedia)
    }

    /// widget-sandbox v0.2: the bot's edit of a message widget's state, in a private chat or basic group (a supergroup's
    /// comes as an ordinary channel edit). Each field: absent unchanged, empty cleared.
    mutating func applyMessageWidgetData(_ updateMessageWidgetDataData: Api.Update.Cons_updateMessageWidgetData) {
        let (peer, msgId) = (updateMessageWidgetDataData.peer, updateMessageWidgetDataData.msgId)
        updatedState.updateMessageWidgetData(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), chatData: messageWidgetDataChange(updateMessageWidgetDataData.chatData), publicData: messageWidgetDataChange(updateMessageWidgetDataData.publicData), publicDataHash: updateMessageWidgetDataData.publicDataHash)
    }
}
