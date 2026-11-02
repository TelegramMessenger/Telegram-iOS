import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Messages: added (to a history, scheduled, quick replies), edited and deleted, and ephemeral replacements; what hangs
/// off a message: polls, media and web pages, pins, views, reactions, transcriptions, extended media; drafts and
/// delivery reports.
extension ReplayContext {
    func applyAddMessages(_ messages: [StoreMessage], _ location: AddMessagesLocation) {
        if case .UpperHistoryBlock = location {
            for message in messages {
                if case let .Id(id) = message.id {
                    if let threadId = message.threadId {
                        for media in message.media {
                            if let action = media as? TelegramMediaAction {
                                switch action.action {
                                case .topicCreated:
                                    transaction.removeHole(peerId: id.peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... id.id)
                                case let .topicEdited(components):
                                    self.applyEditForumTopic(id.peerId, threadId, components)
                                default:
                                    break
                                }
                            }
                        }

                        if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                            if !transaction.messageExists(id: id) {
                                addMessageThreadStatsDifference(threadKey: MessageThreadKey(peerId: message.id.peerId, threadId: threadId), remove: 0, addedMessagePeer: message.authorId, addedMessageId: id, isOutgoing: !message.flags.contains(.Incoming))
                            }
                        }

                        if message.flags.contains(.Incoming) {
                            if var data = transaction.getMessageHistoryThreadInfo(peerId: id.peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                                var combinedMaxIncomingReadId = data.maxIncomingReadId
                                if let maxId = readInboxCloudMessageIds[id.peerId] {
                                    combinedMaxIncomingReadId = max(combinedMaxIncomingReadId, maxId)
                                } else if let groupReadState = transaction.getCombinedPeerReadState(id.peerId), let state = groupReadState.states.first(where: { $0.0 == Namespaces.Message.Cloud })?.1, case let .idBased(maxIncomingReadId, _, _, _, _) = state {
                                    combinedMaxIncomingReadId = max(combinedMaxIncomingReadId, maxIncomingReadId)
                                }

                                if combinedMaxIncomingReadId != 0 && id.id >= data.maxKnownMessageId {
                                    data.maxKnownMessageId = id.id
                                    data.incomingUnreadCount += 1

                                    if let entry = StoredMessageHistoryThreadInfo(data) {
                                        transaction.setMessageHistoryThreadInfo(peerId: id.peerId, threadId: threadId, info: entry)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        var messages = messages

        if case .UpperHistoryBlock = location {
            for i in 0 ..< messages.count {
                let message = messages[i]
                let chatPeerId = message.id.peerId
                let key = PeerAndThreadId(peerId: chatPeerId, threadId: message.threadId)
                let allKey = PeerAndThreadId(peerId: chatPeerId, threadId: nil)

                if liveTypingDraftUpdates[key] != nil {
                    liveTypingDraftUpdates[key] = [.cancel(updatedTimestamp: message.timestamp)]
                    liveTypingDraftUpdates[allKey] = [.cancel(updatedTimestamp: message.timestamp)]
                } else if let currentDraft = transaction.getCurrentTypingDraft(location: key) {
                    liveTypingDraftUpdates[key] = [.cancel(updatedTimestamp: message.timestamp)]
                    liveTypingDraftUpdates[allKey] = [.cancel(updatedTimestamp: message.timestamp)]
                    messages[i] = messages[i].withUpdatedCustomStableId(currentDraft.stableId)
                }
            }
        }

        let _ = transaction.addMessages(messages, location: location)
        if case .UpperHistoryBlock = location {
            for message in messages {
                let chatPeerId = message.id.peerId
                if let authorId = message.authorId {
                    let activityValue: PeerInputActivity? = nil
                    if updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] == nil {
                        updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] = [authorId: activityValue]
                    } else {
                        updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)]![authorId] = activityValue
                    }
                    if let threadId = message.threadId {
                        if updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .thread(threadId))] == nil {
                            updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .thread(threadId))] = [authorId: activityValue]
                        } else {
                            updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .thread(threadId))]![authorId] = activityValue
                        }

                    }
                }

                if case let .Id(id) = message.id {
                    let peerIdAndMessageNamespace = PeerIdAndMessageNamespace(peerId: id.peerId, namespace: id.namespace)

                    if let currentId = topUpperHistoryBlockMessages[peerIdAndMessageNamespace] {
                        if currentId < id.id {
                            topUpperHistoryBlockMessages[peerIdAndMessageNamespace] = id.id
                        }
                    } else {
                        topUpperHistoryBlockMessages[peerIdAndMessageNamespace] = id.id
                    }

                    for media in message.media {
                        if let action = media as? TelegramMediaAction {
                            if message.id.peerId.namespace == Namespaces.Peer.CloudGroup, case let .groupMigratedToChannel(channelId) = action.action {
                                transaction.updatePeerCachedData(peerIds: [channelId], update: { peerId, current in
                                    var current = current as? CachedChannelData ?? CachedChannelData()
                                    if current.associatedHistoryMessageId == nil {
                                        current = current.withUpdatedMigrationReference(ChannelMigrationReference(maxMessageId: id))
                                    }
                                    return current
                                })
                            }
                            switch action.action {
                            case let .setChatTheme(chatTheme):
                                transaction.updatePeerCachedData(peerIds: [message.id.peerId], update: { peerId, current in
                                    var current = current
                                    if current == nil {
                                        if peerId.namespace == Namespaces.Peer.CloudUser {
                                            current = CachedUserData()
                                        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                                            current = CachedGroupData()
                                        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                                            current = CachedChannelData()
                                        }
                                    }
                                    if let cachedData = current as? CachedUserData {
                                        return cachedData.withUpdatedChatTheme(!chatTheme.isEmpty ? chatTheme : nil)
                                    } else if let cachedData = current as? CachedGroupData {
                                        return cachedData.withUpdatedChatTheme(!chatTheme.isEmpty ? chatTheme : nil)
                                    } else if let cachedData = current as? CachedChannelData {
                                        return cachedData.withUpdatedChatTheme(!chatTheme.isEmpty ? chatTheme : nil)
                                    } else {
                                        return current
                                    }
                                })
                            case .groupCreated, .channelMigratedFromGroup:
                                let holesAtHistoryStart = transaction.getHole(containing: MessageId(peerId: chatPeerId, namespace: Namespaces.Message.Cloud, id: id.id - 1))
                                for (space, _) in holesAtHistoryStart {
                                    transaction.removeHole(peerId: chatPeerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: MessageHistoryHoleOperationSpace(space), range: 1 ... id.id)
                                }
                            case let .setChatWallpaper(wallpaper, _):
                                if message.authorId == accountPeerId {
                                    transaction.updatePeerCachedData(peerIds: [message.id.peerId], update: { peerId, current in
                                        var current = current
                                        if current == nil {
                                            if peerId.namespace == Namespaces.Peer.CloudUser {
                                                current = CachedUserData()
                                            }
                                        }
                                        if let cachedData = current as? CachedUserData {
                                            return cachedData.withUpdatedWallpaper(wallpaper)
                                        } else {
                                            return current
                                        }
                                    })
                                }
                            case let .copyProtectionToggle(_, newValue):
                                transaction.updatePeerCachedData(peerIds: [message.id.peerId], update: { peerId, current in
                                    if let previous = current as? CachedUserData {
                                        var updatedFlags = previous.flags
                                        if newValue {
                                            updatedFlags.insert(.copyProtectionEnabled)
                                        } else {
                                            updatedFlags.remove(.copyProtectionEnabled)
                                        }
                                        return previous.withUpdatedFlags(updatedFlags)
                                    }
                                    return current
                                })
                            default:
                                break
                            }
                        }
                    }

                    if message.flags.contains(.Incoming), let authorId = message.authorId {
                        for attribute in message.attributes {
                            if let attribute = attribute as? GuestChatMessageAttribute, attribute.peerId == accountPeerId {
                                recentlyUsedGuestChatBots.insert(authorId)
                                break
                            }
                        }
                    }
                }
                if !message.flags.contains(.Incoming) && !message.flags.contains(.Unsent) {
                    if message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        slowModeLastMessageTimeouts[message.id.peerId] = max(slowModeLastMessageTimeouts[message.id.peerId] ?? 0, message.timestamp)
                    }
                }

                if !message.flags.contains(.Incoming), message.forwardInfo == nil {
                    if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(message.id.peerId.namespace), let peer = transaction.getPeer(message.id.peerId), peer.isCopyProtectionEnabled {

                    } else if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let cachedUserData = transaction.getPeerCachedData(peerId: message.id.peerId) as? CachedUserData, cachedUserData.flags.contains(.copyProtectionEnabled) || cachedUserData.flags.contains(.myCopyProtectionEnabled) {

                    } else {
                        inner: for media in message.media {
                            if let file = media as? TelegramMediaFile {
                                for attribute in file.attributes {
                                    switch attribute {
                                        case let .Sticker(_, packReference, _):
                                            if let index = message.index, packReference != nil {
                                                if let (currentIndex, _) = recentlyUsedStickers[file.fileId] {
                                                    if currentIndex < index {
                                                        recentlyUsedStickers[file.fileId] = (index, file)
                                                    }
                                                } else {
                                                    recentlyUsedStickers[file.fileId] = (index, file)
                                                }
                                            }
                                        case .Animated:
                                            if let index = message.index {
                                                if let (currentIndex, _) = recentlyUsedGifs[file.fileId] {
                                                    if currentIndex < index {
                                                        recentlyUsedGifs[file.fileId] = (index, file)
                                                    }
                                                } else {
                                                    recentlyUsedGifs[file.fileId] = (index, file)
                                                }
                                            }
                                        default:
                                            break
                                    }
                                }
                                break inner
                            }
                        }
                    }
                }
            }
        }
    }
    
    func applyAddScheduledMessages(_ messages: [StoreMessage]) {
        for message in messages {
            if case let .Id(id) = message.id, let _ = transaction.getMessage(id) {
                transaction.updateMessage(id) { _ -> PostboxUpdateMessage in
                    return .update(message)
                }
            } else {
                let _ = transaction.addMessages(messages, location: .Random)
            }
        }
    }
    
    func applyAddQuickReplyMessages(_ messages: [StoreMessage]) {
        for message in messages {
            if case let .Id(id) = message.id, let _ = transaction.getMessage(id) {
                transaction.updateMessage(id) { _ -> PostboxUpdateMessage in
                    return .update(message)
                }
            } else {
                let _ = transaction.addMessages(messages, location: .Random)
            }
        }
    }
    
    func applyUpsertEphemeralReplacement(_ anchorMessageId: MessageId, _ message: StoreMessage) {
        upsertEphemeralReplacement(transaction: transaction, anchorMessageId: anchorMessageId, message: message)
    }
    
    func applyDeleteEphemeralMessages(_ peerId: PeerId, _ ids: [Int32]) {
        deleteEphemeralMessages(transaction: transaction, peerId: peerId, ids: ids)
    }
    
    func applyDeleteMessagesWithGlobalIds(_ ids: [Int32]) {
        var resourceIds: [MediaResourceId] = []
        transaction.deleteMessagesWithGlobalIds(ids, forEachMedia: { media in
            addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
        }
        deletedMessageIds.append(contentsOf: ids.map { .global($0) })
    }
    
    func applyDeleteMessages(_ ids: [MessageId]) {
        _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, manualAddMessageThreadStatsDifference: { id, add, remove in
            self.addMessageThreadStatsDifference(threadKey: id, remove: remove, addedMessagePeer: nil, addedMessageId: nil, isOutgoing: false)
        })
        deletedMessageIds.append(contentsOf: ids.map { .messageId($0) })
    }
    
    func applyUpdateMinAvailableMessage(_ id: MessageId) {
        if let message = transaction.getMessage(id) {
            updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: id.peerId, minTimestamp: message.timestamp, forceRootGroupIfNotExists: false)
        }
        var resourceIds: [MediaResourceId] = []
        transaction.deleteMessagesInRange(peerId: id.peerId, namespace: id.namespace, minId: 1, maxId: id.id, forEachMedia: { media in
            addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
        }
    }
    
    func applyEditMessage(_ id: MessageId, _ message: StoreMessage) {
        var generatedEvent: (reactionAuthor: Peer, reaction: MessageReaction.Reaction, message: Message, timestamp: Int32)?
        transaction.updateMessage(id, update: { previousMessage in
            let peers: [PeerId:Peer] = previousMessage.peers.reduce([:], { current, value in
                var current = current
                current[value.0] = value.1
                return current
            })

            if let message = locallyRenderedMessage(message: message, peers: peers) {
                generatedEvent = reactionGeneratedEvent(previousMessage.reactionsAttribute, message.reactionsAttribute, message: message, transaction: transaction)
            }

            return .update(mergedServerMessageUpdate(previous: previousMessage, updated: message))
        })
        // A fetch in flight may be bringing the message with its old content, over the edited one or, with none stored
        // here, instead of it; it stores this edit in its place (Postbox's record of recent edits,
        // `fetchedMessagesWithRecentEdits`; owner decision 2026-10-25).
        transaction.recordMessageEdit(message)
        if let generatedEvent = generatedEvent {
            addedReactionEvents.append(generatedEvent)
        }
    }
    
    func applyUpdateMessagePoll(_ pollId: MediaId, _ apiPoll: Api.Poll?, _ results: Api.PollResults) {
        if let poll = transaction.getMedia(pollId) as? TelegramMediaPoll {
            var updatedPoll = poll
            let resultsMin: Bool
            switch results {
            case let .pollResults(pollResultsData):
                let flags = pollResultsData.flags
                resultsMin = (flags & (1 << 0)) != 0
            }
            if let apiPoll = apiPoll {
                switch apiPoll {
                case let .poll(pollData):
                    let (id, flags, question, answers, closePeriod, closeDate, pollHash, countries) = (pollData.id, pollData.flags, pollData.question, pollData.answers, pollData.closePeriod, pollData.closeDate, pollData.hash, pollData.countriesIso2)
                    let publicity: TelegramMediaPollPublicity
                    if (flags & (1 << 1)) != 0 {
                        publicity = .public
                    } else {
                        publicity = .anonymous
                    }
                    let kind: TelegramMediaPollKind
                    if (flags & (1 << 3)) != 0 {
                        kind = .quiz(multipleAnswers: (flags & (1 << 2)) != 0)
                    } else {
                        kind = .poll(multipleAnswers: (flags & (1 << 2)) != 0)
                    }
                    let openAnswers = (flags & (1 << 6)) != 0
                    let revotingDisabled = (flags & (1 << 7)) != 0
                    let shuffleAnswers = (flags & (1 << 8)) != 0
                    let hideResultsUntilClose = (flags & (1 << 9)) != 0
                    let isCreator = (flags & (1 << 10)) != 0
                    let restrictToSubscribers = (flags & (1 << 11)) != 0

                    let questionText: String
                    let questionEntities: [MessageTextEntity]
                    switch question {
                    case let .textWithEntities(textWithEntitiesData):
                        let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                        questionText = text
                        questionEntities = messageTextEntitiesFromApiEntities(entities)
                    }

                    updatedPoll = TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: id), publicity: publicity, kind: kind, text: questionText, textEntities: questionEntities, options: answers.map(TelegramMediaPollOption.init(apiOption:)), correctAnswers: nil, results: poll.results, isClosed: (flags & (1 << 0)) != 0, deadlineTimeout: closePeriod, deadlineDate: closeDate, pollHash: pollHash, openAnswers: openAnswers, revotingDisabled: revotingDisabled, shuffleAnswers: shuffleAnswers, hideResultsUntilClose: hideResultsUntilClose, isCreator: isCreator, attachedMedia: poll.attachedMedia, restrictToSubscribers: restrictToSubscribers, countries: countries ?? [])
                }
            }
            updatedPoll = updatedPoll.withUpdatedResults(TelegramMediaPollResults(apiResults: results), min: resultsMin)
            updateMessageMedia(transaction: transaction, id: pollId, media: updatedPoll)
        }
    }
    
    func applyUpdateMedia(_ id: MediaId, _ media: Media?) {
        recordUpdatedWebpage(id, media: media, into: &updatedWebpages)
        updateMessageMedia(transaction: transaction, id: id, media: media)
    }
    
    func applyUpdateMessagesPinned(_ messageIds: [MessageId], _ pinned: Bool) {
        for id in messageIds {
            transaction.updateMessage(id, update: { currentMessage in
                var tags = currentMessage.tags
                let attributes = currentMessage.attributes
                if pinned {
                    tags.insert(.pinned)
                } else {
                    tags.remove(.pinned)
                }

                if tags == currentMessage.tags {
                    return .skip
                }

                return .update(StoreMessage(updating: currentMessage, attributes: attributes, tags: tags))
            })
        }
    }
    
    func applyUpdateMessageImpressionCount(_ id: MessageId, _ count: Int32) {
        transaction.updateMessage(id, update: { currentMessage in
            var attributes = currentMessage.attributes
            loop: for j in 0 ..< attributes.count {
                if let attribute = attributes[j] as? ViewCountMessageAttribute {
                    attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(count)))
                    break loop
                }
            }
            return .update(StoreMessage(updating: currentMessage, attributes: attributes, tags: currentMessage.tags))
        })
    }
    
    func applyUpdateChatInputState(_ peerId: PeerId, _ threadId: Int64?, _ inputState: SynchronizeableChatInputState?) {
        _internal_updateChatInputState(transaction: transaction, peerId: peerId, threadId: threadId, inputState: inputState)
    }
    
    func applyUpdateMessageReactions(_ messageId: MessageId, _ reactions: Api.MessageReactions) {
        transaction.updateMessage(messageId, update: { currentMessage in
            var updatedReactions = ReactionsMessageAttribute(apiReactions: reactions)

            var attributes = currentMessage.attributes
            var added = false
            loop: for j in 0 ..< attributes.count {
                if let attribute = attributes[j] as? ReactionsMessageAttribute {
                    added = true
                    updatedReactions = attribute.withUpdatedResults(reactions)

                    if updatedReactions == attribute {
                        return .skip
                    }
                    attributes[j] = updatedReactions
                    break loop
                }
            }
            if !added {
                attributes.append(updatedReactions)
            }

            var tags = currentMessage.tags
            if updatedReactions.hasUnseen {
                tags.insert(.unseenReaction)
            } else {
                tags.remove(.unseenReaction)
            }

            return .update(StoreMessage(updating: currentMessage, attributes: attributes, tags: tags))
        })
    }
    
    func applyUpdateAudioTranscription(_ messageId: MessageId, _ id: Int64, _ isPending: Bool, _ text: String) {
        transaction.updateMessage(messageId, update: { currentMessage in
            var attributes = currentMessage.attributes
            var found = false
            loop: for j in 0 ..< attributes.count {
                if let attribute = attributes[j] as? AudioTranscriptionMessageAttribute {
                    attributes[j] = AudioTranscriptionMessageAttribute(id: id, text: text, isPending: isPending, didRate: attribute.didRate, error: nil)
                    found = true
                    break loop
                }
            }
            if !found {
                attributes.append(AudioTranscriptionMessageAttribute(id: id, text: text, isPending: isPending, didRate: false, error: nil))
            }

            return .update(StoreMessage(updating: currentMessage, attributes: attributes, tags: currentMessage.tags))
        })
    }
    
    func applyUpdateExtendedMedia(_ messageId: MessageId, _ apiExtendedMedia: [Api.MessageExtendedMedia]) {
        transaction.updateMessage(messageId, update: { currentMessage in
            var media = currentMessage.media
            let invoice = media.first(where: { $0 is TelegramMediaInvoice }) as? TelegramMediaInvoice
            let paidContent = media.first(where: { $0 is TelegramMediaPaidContent }) as? TelegramMediaPaidContent

            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }

            let updatedExtendedMedia = apiExtendedMedia.compactMap { TelegramExtendedMedia(apiExtendedMedia: $0, peerId: messageId.peerId) }

            if let first = updatedExtendedMedia.first, case .full = first {
                if var invoice = invoice {
                    media = media.filter { !($0 is TelegramMediaInvoice) }
                    invoice = invoice.withUpdatedExtendedMedia(first)
                    media.append(invoice)
                }
                if var paidContent = paidContent {
                    media = media.filter { !($0 is TelegramMediaPaidContent) }
                    paidContent = paidContent.withUpdatedExtendedMedia(updatedExtendedMedia)
                    media.append(paidContent)
                }
            }

            // A full rebuild: the media changes, and StoreMessage(updating:attributes:tags:) keeps the stored media.
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: media))
        })
    }
    
    /// widget-sandbox v0.2: the bot's edit of a stored message widget's state, nothing else of the message changed. The
    /// edit is recorded (`recordMessageEdit`), so a fill already in flight stores it in its older answer's place, as an
    /// `updateEditMessage` is. A message not stored, without a widget, or left as it was changes nothing.
    func applyUpdateMessageWidgetData(_ messageId: MessageId, chatData: MessageWidgetDataChange, publicData: MessageWidgetDataChange, publicDataHash: Int64?) {
        var edited: StoreMessage?
        transaction.updateMessage(messageId, update: { currentMessage in
            guard let widget = currentMessage.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget else {
                return .skip
            }
            let updated = widget.withUpdatedState(chatData: chatData, publicData: publicData, publicDataHash: publicDataHash)
            if updated.isEqual(to: widget) {
                return .skip
            }
            let message = storeMessageReplacingWidget(currentMessage, widget: updated)
            edited = message
            return .update(message)
        })
        if let edited {
            transaction.recordMessageEdit(edited)
        }
    }

    func applyReportMessageDelivery(_ messageIds: [MessageId]) {
        reportMessageDelivery = Set(messageIds)
    }
}
