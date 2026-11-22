import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

private func peerIdsFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    for group in groups {
        for update in group.updates {
            for peerId in update.peerIds {
                peerIds.insert(peerId)
            }
        }
        for user in group.users {
            peerIds.insert(user.peerId)
        }
        for chat in group.chats {
            peerIds.insert(chat.peerId)
        }
        switch group {
            case let .updateChannelPts(channelId, _, _):
                peerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)))
            default:
                break
        }
    }
    
    return peerIds
}

private func activeChannelsFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    for group in groups {
        for chat in group.chats {
            switch chat {
                case .channel:
                    if let channel = parseTelegramGroupOrChannel(chat: chat) as? TelegramChannel {
                        if channel.participationStatus == .member, case .personal = channel.accessHash {
                            peerIds.insert(channel.id)
                        }
                    }
                default:
                    break
            }
        }
    }
    
    return peerIds.intersection(peerIdsRequiringLocalChatStateFromUpdateGroups(groups))
}

private func associatedMessageIdsFromUpdateGroups(_ groups: [UpdateGroup]) -> (replyIds: ReferencedReplyMessageIds, generalIds: Set<MessageId>) {
    var replyIds = ReferencedReplyMessageIds()
    var generalIds = Set<MessageId>()
    
    for group in groups {
        for update in group.updates {
            if let associatedMessageIds = update.associatedMessageIds {
                replyIds.formUnion(associatedMessageIds.replyIds)
                generalIds.formUnion(associatedMessageIds.generalIds)
            }
        }
    }
    
    return (replyIds, generalIds)
}

private func peerIdsRequiringLocalChatStateFromUpdates(_ updates: [Api.Update]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    for update in updates {
        if let messageId = update.messageId {
            peerIds.insert(messageId.peerId)
        }
        switch update {
            case let .updateChannelTooLong(updateChannelTooLongData):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateChannelTooLongData.channelId))
                peerIds.insert(peerId)
            case let .updatePinnedForumTopics(updatePinnedForumTopicsData):
                if updatePinnedForumTopicsData.order == nil {
                    peerIds.insert(updatePinnedForumTopicsData.peer.peerId)
                }
            case let .updateFolderPeers(updateFolderPeersData):
                for peer in updateFolderPeersData.folderPeers {
                    switch peer {
                        case let .folderPeer(folderPeerData):
                            let peer = folderPeerData.peer
                            peerIds.insert(peer.peerId)
                    }
                }
            case let .updateReadChannelInbox(updateReadChannelInboxData):
                peerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateReadChannelInboxData.channelId)))
            case let .updateReadHistoryInbox(updateReadHistoryInboxData):
                peerIds.insert(updateReadHistoryInboxData.peer.peerId)
            case let .updateDraftMessage(updateDraftMessageData):
            switch updateDraftMessageData.draft {
            case .draftMessage:
                peerIds.insert(updateDraftMessageData.peer.peerId)
            case .draftMessageEmpty:
                break
                }
            default:
                break
        }
    }
    return peerIds
}

/// Peers the updates name that the batch's state loads when they are stored, as it loads `peerIds`, but that the
/// replay does not require (`loadOnlyPeerIds` of `initialStateWithPeerIds`). `updatePinnedForumTopics` without an
/// order schedules a poll of its channel (G1), which needs the stored channel's peer and pts in the state even when
/// the container carries no `chats`. A channel that is not stored cannot be polled, and must not make the replay
/// refuse the batch: in `peerIds` it did (`ReplayRejection.verify`, "missing peers"), and on the difference path a
/// refused replay polls again at once, from the same pts, to the same refusal.
private func loadOnlyPeerIdsFromUpdates(_ updates: [Api.Update]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    for update in updates {
        switch update {
        case let .updatePinnedForumTopics(updatePinnedForumTopicsData):
            if updatePinnedForumTopicsData.order == nil {
                peerIds.insert(updatePinnedForumTopicsData.peer.peerId)
            }
        default:
            break
        }
    }
    return peerIds
}

private func loadOnlyPeerIdsFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    for group in groups {
        peerIds.formUnion(loadOnlyPeerIdsFromUpdates(group.updates))
    }
    return peerIds
}

private func loadOnlyPeerIdsFromDifference(_ difference: Api.updates.Difference) -> Set<PeerId> {
    switch difference {
    case let .difference(differenceData):
        return loadOnlyPeerIdsFromUpdates(differenceData.otherUpdates)
    case let .differenceSlice(differenceSliceData):
        return loadOnlyPeerIdsFromUpdates(differenceSliceData.otherUpdates)
    case .differenceEmpty, .differenceTooLong:
        return Set()
    }
}

private func peerIdsRequiringLocalChatStateFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    for group in groups {
        peerIds.formUnion(peerIdsRequiringLocalChatStateFromUpdates(group.updates))

        var channelUpdates = Set<PeerId>()
        for update in group.updates {
            switch update {
            case let .updateChannel(updateChannelData):
                channelUpdates.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateChannelData.channelId)))
            default:
                break
            }
        }
        for chat in group.chats {
            if let channel = parseTelegramGroupOrChannel(chat: chat) as? TelegramChannel, channelUpdates.contains(channel.id) {
                if let accessHash = channel.accessHash, case .personal = accessHash {
                    if case .member = channel.participationStatus {
                        peerIds.insert(channel.id)
                    }
                }
            }
        }
        
        switch group {
        case let .ensurePeerHasLocalState(peerId):
            peerIds.insert(peerId)
        default:
            break
        }
    }
    
    return peerIds
}

private func locallyGeneratedMessageTimestampsFromUpdateGroups(_ groups: [UpdateGroup]) -> [PeerId: [(MessageId.Namespace, Int32)]] {
    var messageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]] = [:]
    for group in groups {
        for update in group.updates {
            switch update {
                case let .updateServiceNotification(updateServiceNotificationData):
                    if let date = updateServiceNotificationData.inboxDate {
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
                        if messageTimestamps[peerId] == nil {
                            messageTimestamps[peerId] = [(Namespaces.Message.Local, date)]
                        } else {
                            messageTimestamps[peerId]!.append((Namespaces.Message.Local, date))
                        }
                    }
                default:
                    break
            }
        }
    }
    
    return messageTimestamps
}

private func peerIdsFromDifference(_ difference: Api.updates.Difference) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    switch difference {
        case let .difference(differenceData):
            let (newMessages, _, otherUpdates, chats, users, _) = (differenceData.newMessages, differenceData.newEncryptedMessages, differenceData.otherUpdates, differenceData.chats, differenceData.users, differenceData.state)
            for message in newMessages {
                for peerId in apiMessagePeerIds(message) {
                    peerIds.insert(peerId)
                }
            }
            for user in users {
                peerIds.insert(user.peerId)
            }
            for chat in chats {
                peerIds.insert(chat.peerId)
            }
            for update in otherUpdates {
                for peerId in update.peerIds {
                    peerIds.insert(peerId)
                }
            }
        case .differenceEmpty:
            break
        case let .differenceSlice(differenceSliceData):
            let (newMessages, _, otherUpdates, chats, users, _) = (differenceSliceData.newMessages, differenceSliceData.newEncryptedMessages, differenceSliceData.otherUpdates, differenceSliceData.chats, differenceSliceData.users, differenceSliceData.intermediateState)
            for message in newMessages {
                for peerId in apiMessagePeerIds(message) {
                    peerIds.insert(peerId)
                }
            }
            for user in users {
                peerIds.insert(user.peerId)
            }
            for chat in chats {
                peerIds.insert(chat.peerId)
            }
            for update in otherUpdates {
                for peerId in update.peerIds {
                    peerIds.insert(peerId)
                }
            }
        case .differenceTooLong:
            assertionFailure()
            break
    }
    
    return peerIds
}

private func activeChannelsFromDifference(_ difference: Api.updates.Difference) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    var chats: [Api.Chat] = []
    switch difference {
        case let .difference(differenceData):
            let (_, _, _, differenceChats, _, _) = (differenceData.newMessages, differenceData.newEncryptedMessages, differenceData.otherUpdates, differenceData.chats, differenceData.users, differenceData.state)
            chats = differenceChats
        case .differenceEmpty:
            break
        case let .differenceSlice(differenceSliceData):
            let (_, _, _, differenceChats, _, _) = (differenceSliceData.newMessages, differenceSliceData.newEncryptedMessages, differenceSliceData.otherUpdates, differenceSliceData.chats, differenceSliceData.users, differenceSliceData.intermediateState)
            chats = differenceChats
        case .differenceTooLong:
            break
    }
    
    for chat in chats {
        switch chat {
            case .channel:
                if let channel = parseTelegramGroupOrChannel(chat: chat) as? TelegramChannel {
                    if channel.participationStatus == .member {
                        peerIds.insert(channel.id)
                    }
                }
            default:
                break
        }
    }
    
    return peerIds
}

private func associatedMessageIdsFromDifference(_ difference: Api.updates.Difference) -> (replyIds: ReferencedReplyMessageIds, generalIds: Set<MessageId>) {
    var replyIds = ReferencedReplyMessageIds()
    var generalIds = Set<MessageId>()
    
    switch difference {
        case let .difference(differenceData):
            let (newMessages, _, otherUpdates, _, _, _) = (differenceData.newMessages, differenceData.newEncryptedMessages, differenceData.otherUpdates, differenceData.chats, differenceData.users, differenceData.state)
            for message in newMessages {
                if let associatedMessageIds = apiMessageAssociatedMessageIds(message) {
                    replyIds.formUnion(associatedMessageIds.replyIds)
                    generalIds.formUnion(associatedMessageIds.generalIds)
                }
            }
            for update in otherUpdates {
                if let associatedMessageIds = update.associatedMessageIds {
                    replyIds.formUnion(associatedMessageIds.replyIds)
                    generalIds.formUnion(associatedMessageIds.generalIds)
                }
            }
        case .differenceEmpty:
            break
        case let .differenceSlice(differenceSliceData):
            let (newMessages, _, otherUpdates, _, _, _) = (differenceSliceData.newMessages, differenceSliceData.newEncryptedMessages, differenceSliceData.otherUpdates, differenceSliceData.chats, differenceSliceData.users, differenceSliceData.intermediateState)
            for message in newMessages {
                if let associatedMessageIds = apiMessageAssociatedMessageIds(message) {
                    replyIds.formUnion(associatedMessageIds.replyIds)
                    generalIds.formUnion(associatedMessageIds.generalIds)
                }
            }

            for update in otherUpdates {
                if let associatedMessageIds = update.associatedMessageIds {
                    replyIds.formUnion(associatedMessageIds.replyIds)
                    generalIds.formUnion(associatedMessageIds.generalIds)
                }
            }
        case .differenceTooLong:
            break
    }

    return (replyIds, generalIds)
}

private func peerIdsRequiringLocalChatStateFromDifference(_ difference: Api.updates.Difference) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    switch difference {
        case let .difference(differenceData):
            let (newMessages, _, otherUpdates, _, _, _) = (differenceData.newMessages, differenceData.newEncryptedMessages, differenceData.otherUpdates, differenceData.chats, differenceData.users, differenceData.state)
            for message in newMessages {
                if let messageId = message.id() {
                    peerIds.insert(messageId.peerId)
                }
            }
            peerIds.formUnion(peerIdsRequiringLocalChatStateFromUpdates(otherUpdates))
        case .differenceEmpty:
            break
        case let .differenceSlice(differenceSliceData):
            let (newMessages, _, otherUpdates, _, _, _) = (differenceSliceData.newMessages, differenceSliceData.newEncryptedMessages, differenceSliceData.otherUpdates, differenceSliceData.chats, differenceSliceData.users, differenceSliceData.intermediateState)
            for message in newMessages {
                if let messageId = message.id() {
                    peerIds.insert(messageId.peerId)
                }
            }

            peerIds.formUnion(peerIdsRequiringLocalChatStateFromUpdates(otherUpdates))
        case .differenceTooLong:
            break
    }
    
    return peerIds
}

private func locallyGeneratedMessageTimestampsFromDifference(_ difference: Api.updates.Difference) -> [PeerId: [(MessageId.Namespace, Int32)]] {
    var messageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]] = [:]
    
    var otherUpdates: [Api.Update]?
    switch difference {
        case let .difference(differenceData):
            let (_, _, apiOtherUpdates, _, _, _) = (differenceData.newMessages, differenceData.newEncryptedMessages, differenceData.otherUpdates, differenceData.chats, differenceData.users, differenceData.state)
            otherUpdates = apiOtherUpdates
        case .differenceEmpty:
            break
        case let .differenceSlice(differenceSliceData):
            let (_, _, apiOtherUpdates, _, _, _) = (differenceSliceData.newMessages, differenceSliceData.newEncryptedMessages, differenceSliceData.otherUpdates, differenceSliceData.chats, differenceSliceData.users, differenceSliceData.intermediateState)
            otherUpdates = apiOtherUpdates
        case .differenceTooLong:
            break
    }
    
    if let otherUpdates = otherUpdates {
        for update in otherUpdates {
            switch update {
                case let .updateServiceNotification(updateServiceNotificationData):
                    if let date = updateServiceNotificationData.inboxDate {
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
                        if messageTimestamps[peerId] == nil {
                            messageTimestamps[peerId] = [(Namespaces.Message.Local, date)]
                        } else {
                            messageTimestamps[peerId]!.append((Namespaces.Message.Local, date))
                        }
                    }
                default:
                    break
            }
        }
    }
    
    return messageTimestamps
}

private func shouldUseStoredPeerChatInfoForPeerWithoutValidInclusion(transaction: Transaction, peerId: PeerId, peer: Peer) -> Bool {
    if let channel = peer as? TelegramChannel, channel.participationStatus != .member {
        return true
    }
    if isPeerHiddenByCollapsedCommunity(transaction: transaction, peerId: peerId, peer: peer) {
        return true
    }
    if let community = peer as? TelegramCommunity, community.participationStatus == .member {
        return shouldExcludePeerFromChatList(transaction: transaction, peerId: peerId, peer: community)
    }
    return false
}

/// `peerIds` are the peers the batch needs: each is loaded when stored, and the replay refuses the batch when one is
/// in neither Postbox nor the batch's own chats and users (`ReplayRejection.verify`, which reads
/// `AccountInitialState.peerIds`). `loadOnlyPeerIds` are loaded the same way, a channel's pts included, but a
/// missing one does not refuse the batch.
func initialStateWithPeerIds(_ transaction: Transaction, peerIds: Set<PeerId>, loadOnlyPeerIds: Set<PeerId> = Set(), activeChannelIds: Set<PeerId>, referencedReplyMessageIds: ReferencedReplyMessageIds, referencedGeneralMessageIds: Set<MessageId>, peerIdsRequiringLocalChatState: Set<PeerId>, locallyGeneratedMessageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]], storedStories: [StoryId: UpdatesStoredStory]) -> AccountMutableState {
    var peers: [PeerId: Peer] = [:]
    var channelStates: [PeerId: AccountStateChannelState] = [:]

    var channelsToPollExplicitely = Set<PeerId>()

    for peerId in peerIds.union(loadOnlyPeerIds) {
        if let peer = transaction.getPeer(peerId) {
            peers[peerId] = peer
        }
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
                channelStates[peerId] = AccountStateChannelState(pts: channelState.pts)
            }
        } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
            if let _ = transaction.getPeerChatState(peerId) as? RegularChatState {
                //chatStates[peerId] = chatState
            }
        }
    }
    
    for peerId in activeChannelIds {
        if transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) == nil {
            channelsToPollExplicitely.insert(peerId)
        } else if let channel = transaction.getPeer(peerId) as? TelegramChannel, channel.participationStatus != .member {
            channelsToPollExplicitely.insert(peerId)
        }
    }
    
    let storedMessages = transaction.filterStoredMessageIds(Set(referencedReplyMessageIds.targetIdsBySourceId.keys).union(referencedGeneralMessageIds))
    
    var storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>] = [:]
    if !locallyGeneratedMessageTimestamps.isEmpty {
        for (peerId, namespacesAndTimestamps) in locallyGeneratedMessageTimestamps {
            for (namespace, timestamp) in namespacesAndTimestamps {
                if let messageId = transaction.storedMessageId(peerId: peerId, namespace: namespace, timestamp: timestamp) {
                    if storedMessagesByPeerIdAndTimestamp[peerId] == nil {
                        storedMessagesByPeerIdAndTimestamp[peerId] = Set([MessageIndex(id: messageId, timestamp: timestamp)])
                    } else {
                        storedMessagesByPeerIdAndTimestamp[peerId]!.insert(MessageIndex(id: messageId, timestamp: timestamp))
                    }
                }
            }
        }
    }
    
    var peerChatInfos: [PeerId: PeerChatInfo] = [:]
    var readInboxMaxIds: [PeerId: MessageId] = [:]
    
    for peerId in peerIdsRequiringLocalChatState {
        let inclusion = transaction.getPeerChatListInclusion(peerId)
        var hasValidInclusion = false
        switch inclusion {
            case .ifHasMessagesOrOneOf:
                hasValidInclusion = true
            case .notIncluded:
                hasValidInclusion = false
        }
        if hasValidInclusion {
            if let notificationSettings = transaction.getPeerNotificationSettings(id: peerId) {
                peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
            }
        } else {
            if let peer = transaction.getPeer(peerId) {
                if shouldUseStoredPeerChatInfoForPeerWithoutValidInclusion(transaction: transaction, peerId: peerId, peer: peer) {
                    if let notificationSettings = transaction.getPeerNotificationSettings(id: peerId) {
                        peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
                        Logger.shared.log("State", "Peer \(peerId) (\(peer.debugDisplayTitle) has no stored inclusion, using synthesized one")
                    } else {
                        Logger.shared.log("State", "Peer \(peerId) has no valid inclusion")
                    }
                } else {
                    Logger.shared.log("State", "Peer \(peerId) has no valid inclusion")
                }
            } else {
                Logger.shared.log("State", "Peer \(peerId) has no valid inclusion")
            }
        }
        if let readStates = transaction.getPeerReadStates(peerId) {
            for (namespace, state) in readStates {
                if namespace == Namespaces.Message.Cloud {
                    switch state {
                        case let .idBased(maxIncomingReadId, _, _, _, _):
                            readInboxMaxIds[peerId] = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: maxIncomingReadId)
                        case .indexBased:
                            break
                    }
                    break
                }
            }
        }
    }
    
    let state = AccountMutableState(initialState: AccountInitialState(state: (transaction.getState() as? AuthorizedAccountState)!.state!, peerIds: peerIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, channelStates: channelStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestamps, channelsToPollExplicitely: channelsToPollExplicitely), initialPeers: peers, initialReferencedReplyMessageIds: referencedReplyMessageIds, initialReferencedGeneralMessageIds: referencedGeneralMessageIds, initialStoredMessages: storedMessages, initialStoredStories: storedStories, initialReadInboxMaxIds: readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: storedMessagesByPeerIdAndTimestamp, initialSentScheduledMessageIds: Set())
    return state
}

func initialStateWithUpdateGroups(postbox: Postbox, groups: [UpdateGroup]) -> Signal<AccountMutableState, NoError> {
    return postbox.transaction { transaction -> AccountMutableState in
        let peerIds = peerIdsFromUpdateGroups(groups)
        let activeChannelIds = activeChannelsFromUpdateGroups(groups)
        let associatedMessageIds = associatedMessageIdsFromUpdateGroups(groups)
        let peerIdsRequiringLocalChatState = peerIdsRequiringLocalChatStateFromUpdateGroups(groups)
        
        return initialStateWithPeerIds(transaction, peerIds: peerIds, loadOnlyPeerIds: loadOnlyPeerIdsFromUpdateGroups(groups), activeChannelIds: activeChannelIds, referencedReplyMessageIds: associatedMessageIds.replyIds, referencedGeneralMessageIds: associatedMessageIds.generalIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestampsFromUpdateGroups(groups), storedStories: [:])
    }
}

func initialStateWithDifference(postbox: Postbox, difference: Api.updates.Difference) -> Signal<AccountMutableState, NoError> {
    return postbox.transaction { transaction -> AccountMutableState in
        let peerIds = peerIdsFromDifference(difference)
        let activeChannelIds = activeChannelsFromDifference(difference)
        let associatedMessageIds = associatedMessageIdsFromDifference(difference)
        let peerIdsRequiringLocalChatState = peerIdsRequiringLocalChatStateFromDifference(difference)
        return initialStateWithPeerIds(transaction, peerIds: peerIds, loadOnlyPeerIds: loadOnlyPeerIdsFromDifference(difference), activeChannelIds: activeChannelIds, referencedReplyMessageIds: associatedMessageIds.replyIds, referencedGeneralMessageIds: associatedMessageIds.generalIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestampsFromDifference(difference), storedStories: [:])
    }
}
