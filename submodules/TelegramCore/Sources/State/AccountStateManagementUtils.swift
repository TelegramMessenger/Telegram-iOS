import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

private func reactionGeneratedEvent(_ previousReactions: ReactionsMessageAttribute?, _ updatedReactions: ReactionsMessageAttribute?, message: Message, transaction: Transaction) -> (reactionAuthor: Peer, reaction: String, message: Message, timestamp: Int32)? {
    
    if let updatedReactions = updatedReactions, !message.flags.contains(.Incoming), message.id.peerId.namespace == Namespaces.Peer.CloudUser {
        let prev = previousReactions?.reactions ?? []
        
        let updated = updatedReactions.reactions.filter { value in
            return !prev.contains(where: {
                $0.value == value.value && $0.count == value.count
            })
        }
        let myUpdated = updatedReactions.reactions.filter { value in
            return value.isSelected
        }.first
        let myPrevious = prev.filter { value in
            return value.isSelected
        }.first
        
        let previousCount = prev.reduce(0, {
            $0 + $1.count
        })
        let updatedCount = updatedReactions.reactions.reduce(0, {
            $0 + $1.count
        })
        
        let newReaction = updated.filter {
            !$0.isSelected
        }.first?.value
        
        if !updated.isEmpty && myUpdated == myPrevious, updatedCount >= previousCount, let value = newReaction {
            if let reactionAuthor = transaction.getPeer(message.id.peerId) {
                return (reactionAuthor: reactionAuthor, reaction: value, message: message, timestamp: Int32(Date().timeIntervalSince1970))
            }
        }
    }
    return nil
}


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
                        if channel.participationStatus == .member {
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

private func associatedMessageIdsFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<MessageId> {
    var messageIds = Set<MessageId>()
    
    for group in groups {
        for update in group.updates {
            if let associatedMessageIds = update.associatedMessageIds {
                for messageId in associatedMessageIds {
                    messageIds.insert(messageId)
                }
            }
        }
    }
    
    return messageIds
}

private func peerIdsRequiringLocalChatStateFromUpdates(_ updates: [Api.Update]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    for update in updates {
        if let messageId = update.messageId {
            peerIds.insert(messageId.peerId)
        }
        switch update {
            case let .updateChannelTooLong(_, channelId, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                peerIds.insert(peerId)
            case let .updateFolderPeers(folderPeers, _, _):
                for peer in folderPeers {
                    switch peer {
                        case let .folderPeer(peer, _):
                            peerIds.insert(peer.peerId)
                    }
                }
            case let .updateReadChannelInbox(_, _, channelId, _, _, _):
                peerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)))
            case let .updateReadHistoryInbox(_, _, peer, _, _, _, _):
                peerIds.insert(peer.peerId)
            case let .updateDraftMessage(peer, draft):
                switch draft {
                    case .draftMessage:
                        peerIds.insert(peer.peerId)
                    case .draftMessageEmpty:
                        break
                }
            default:
                break
        }
    }
    return peerIds
}

private func peerIdsRequiringLocalChatStateFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    for group in groups {
        peerIds.formUnion(peerIdsRequiringLocalChatStateFromUpdates(group.updates))

        var channelUpdates = Set<PeerId>()
        for update in group.updates {
            switch update {
            case let .updateChannel(channelId):
                channelUpdates.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)))
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
                case let .updateServiceNotification(_, date, _, _, _, _):
                    if let date = date {
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
        case let .difference(newMessages, _, otherUpdates, chats, users, _):
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
        case let .differenceSlice(newMessages, _, otherUpdates, chats, users, _):
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
        case let .difference(_, _, _, differenceChats, _, _):
            chats = differenceChats
        case .differenceEmpty:
            break
        case let .differenceSlice(_, _, _, differenceChats, _, _):
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

private func associatedMessageIdsFromDifference(_ difference: Api.updates.Difference) -> Set<MessageId> {
    var messageIds = Set<MessageId>()
    
    switch difference {
        case let .difference(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                if let associatedMessageIds = apiMessageAssociatedMessageIds(message) {
                    for messageId in associatedMessageIds {
                        messageIds.insert(messageId)
                    }
                }
            }
            for update in otherUpdates {
                if let associatedMessageIds = update.associatedMessageIds {
                    for messageId in associatedMessageIds {
                        messageIds.insert(messageId)
                    }
                }
            }
        case .differenceEmpty:
            break
        case let .differenceSlice(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                if let associatedMessageIds = apiMessageAssociatedMessageIds(message) {
                    for messageId in associatedMessageIds {
                        messageIds.insert(messageId)
                    }
                }
            }
            
            for update in otherUpdates {
                if let associatedMessageIds = update.associatedMessageIds {
                    for messageId in associatedMessageIds {
                        messageIds.insert(messageId)
                    }
                }
            }
        case .differenceTooLong:
            break
    }
    
    return messageIds
}

private func peerIdsRequiringLocalChatStateFromDifference(_ difference: Api.updates.Difference) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    switch difference {
        case let .difference(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                if let messageId = message.id() {
                    peerIds.insert(messageId.peerId)
                }
            }
            peerIds.formUnion(peerIdsRequiringLocalChatStateFromUpdates(otherUpdates))
            for update in otherUpdates {
                if let messageId = update.messageId {
                    peerIds.insert(messageId.peerId)
                }
                switch update {
                    case let .updateChannelTooLong(_, channelId, _):
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        peerIds.insert(peerId)
                    default:
                        break
                }
            }
        case .differenceEmpty:
            break
        case let .differenceSlice(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                if let messageId = message.id() {
                    peerIds.insert(messageId.peerId)
                }
            }
            
            peerIds.formUnion(peerIdsRequiringLocalChatStateFromUpdates(otherUpdates))
            for update in otherUpdates {
                if let messageId = update.messageId {
                    peerIds.insert(messageId.peerId)
                }
                switch update {
                    case let .updateChannelTooLong(_, channelId, _):
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        peerIds.insert(peerId)
                    default:
                        break
                }
            }
        case .differenceTooLong:
            break
    }
    
    return peerIds
}

private func locallyGeneratedMessageTimestampsFromDifference(_ difference: Api.updates.Difference) -> [PeerId: [(MessageId.Namespace, Int32)]] {
    var messageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]] = [:]
    
    var otherUpdates: [Api.Update]?
    switch difference {
        case let .difference(_, _, apiOtherUpdates, _, _, _):
            otherUpdates = apiOtherUpdates
        case .differenceEmpty:
            break
        case let .differenceSlice(_, _, apiOtherUpdates, _, _, _):
            otherUpdates = apiOtherUpdates
        case .differenceTooLong:
            break
    }
    
    if let otherUpdates = otherUpdates {
        for update in otherUpdates {
            switch update {
                case let .updateServiceNotification(_, date, _, _, _, _):
                    if let date = date {
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

private func initialStateWithPeerIds(_ transaction: Transaction, peerIds: Set<PeerId>, activeChannelIds: Set<PeerId>, associatedMessageIds: Set<MessageId>, peerIdsRequiringLocalChatState: Set<PeerId>, locallyGeneratedMessageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]]) -> AccountMutableState {
    var peers: [PeerId: Peer] = [:]
    var channelStates: [PeerId: AccountStateChannelState] = [:]
    
    var channelsToPollExplicitely = Set<PeerId>()
    
    for peerId in peerIds {
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
    
    let storedMessages = transaction.filterStoredMessageIds(associatedMessageIds)
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
    var cloudReadStates: [PeerId: PeerReadState] = [:]
    
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
            if let notificationSettings = transaction.getPeerNotificationSettings(peerId) {
                peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
            }
        } else {
            if let peer = transaction.getPeer(peerId) {
                if let channel = peer as? TelegramChannel, channel.participationStatus != .member {
                    if let notificationSettings = transaction.getPeerNotificationSettings(peerId) {
                        peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
                        Logger.shared.log("State", "Peer \(peerId) (\(peer.debugDisplayTitle) has no stored inclusion, using synthesized one")
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
                    cloudReadStates[peerId] = state
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
    
    let state = AccountMutableState(initialState: AccountInitialState(state: (transaction.getState() as? AuthorizedAccountState)!.state!, peerIds: peerIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, channelStates: channelStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestamps, cloudReadStates: cloudReadStates, channelsToPollExplicitely: channelsToPollExplicitely), initialPeers: peers, initialReferencedMessageIds: associatedMessageIds, initialStoredMessages: storedMessages, initialReadInboxMaxIds: readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: storedMessagesByPeerIdAndTimestamp)
    return state
}

func initialStateWithUpdateGroups(postbox: Postbox, groups: [UpdateGroup]) -> Signal<AccountMutableState, NoError> {
    return postbox.transaction { transaction -> AccountMutableState in
        let peerIds = peerIdsFromUpdateGroups(groups)
        let activeChannelIds = activeChannelsFromUpdateGroups(groups)
        let associatedMessageIds = associatedMessageIdsFromUpdateGroups(groups)
        let peerIdsRequiringLocalChatState = peerIdsRequiringLocalChatStateFromUpdateGroups(groups)
        
        return initialStateWithPeerIds(transaction, peerIds: peerIds, activeChannelIds: activeChannelIds, associatedMessageIds: associatedMessageIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestampsFromUpdateGroups(groups))
    }
}

func initialStateWithDifference(postbox: Postbox, difference: Api.updates.Difference) -> Signal<AccountMutableState, NoError> {
    return postbox.transaction { transaction -> AccountMutableState in
        let peerIds = peerIdsFromDifference(difference)
        let activeChannelIds = activeChannelsFromDifference(difference)
        let associatedMessageIds = associatedMessageIdsFromDifference(difference)
        let peerIdsRequiringLocalChatState = peerIdsRequiringLocalChatStateFromDifference(difference)
        return initialStateWithPeerIds(transaction, peerIds: peerIds, activeChannelIds: activeChannelIds, associatedMessageIds: associatedMessageIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestampsFromDifference(difference))
    }
}

func finalStateWithUpdateGroups(postbox: Postbox, network: Network, state: AccountMutableState, groups: [UpdateGroup]) -> Signal<AccountFinalState, NoError> {
    var updatedState = state
    
    var hadReset = false
    var ptsUpdatesAfterHole: [PtsUpdate] = []
    var qtsUpdatesAfterHole: [QtsUpdate] = []
    var seqGroupsAfterHole: [SeqUpdates] = []
    
    for case .reset in groups {
        hadReset = true
        break
    }
    
    var currentPtsUpdates = ptsUpdates(groups)
    currentPtsUpdates.sort(by: { $0.ptsRange.0 < $1.ptsRange.0 })
    
    var currentQtsUpdates = qtsUpdates(groups)
    currentQtsUpdates.sort(by: { $0.qtsRange.0 < $1.qtsRange.0 })
    
    var currentSeqGroups = seqGroups(groups)
    currentSeqGroups.sort(by: { $0.seqRange.0 < $1.seqRange.0 })
    
    var collectedUpdates: [Api.Update] = []
    
    for update in currentPtsUpdates {
        if updatedState.state.pts >= update.ptsRange.0 {
            if let update = update.update, case .updateWebPage = update {
                collectedUpdates.append(update)
            }
            //skip old update
        }
        else if ptsUpdatesAfterHole.count == 0 && updatedState.state.pts == update.ptsRange.0 - update.ptsRange.1 {
            //TODO: apply pts update
            
            updatedState.mergeChats(update.chats)
            updatedState.mergeUsers(update.users)
            
            if let ptsUpdate = update.update {
                collectedUpdates.append(ptsUpdate)
            }
            
            updatedState.updateState(AuthorizedAccountState.State(pts: update.ptsRange.0, qts: updatedState.state.qts, date: updatedState.state.date, seq: updatedState.state.seq))
        } else {
            if ptsUpdatesAfterHole.count == 0 {
                Logger.shared.log("State", "update pts hole: \(update.ptsRange.0) != \(updatedState.state.pts) + \(update.ptsRange.1)")
            }
            ptsUpdatesAfterHole.append(update)
        }
    }
    
    for update in currentQtsUpdates {
        if updatedState.state.qts >= update.qtsRange.0 + update.qtsRange.1 {
            //skip old update
        } else if qtsUpdatesAfterHole.count == 0 && updatedState.state.qts == update.qtsRange.0 - update.qtsRange.1 {
            //TODO apply qts update
            
            updatedState.mergeChats(update.chats)
            updatedState.mergeUsers(update.users)
            
            collectedUpdates.append(update.update)
            
            updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: update.qtsRange.0, date: updatedState.state.date, seq: updatedState.state.seq))
        } else {
            if qtsUpdatesAfterHole.count == 0 {
                Logger.shared.log("State", "update qts hole: \(update.qtsRange.0) != \(updatedState.state.qts) + \(update.qtsRange.1)")
            }
            qtsUpdatesAfterHole.append(update)
        }
    }
    
    for group in currentSeqGroups {
        if updatedState.state.seq >= group.seqRange.0 + group.seqRange.1 {
            //skip old update
        } else if seqGroupsAfterHole.count == 0 && updatedState.state.seq == group.seqRange.0 - group.seqRange.1 {
            collectedUpdates.append(contentsOf: group.updates)
            
            updatedState.mergeChats(group.chats)
            updatedState.mergeUsers(group.users)
            
            updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: updatedState.state.qts, date: group.date, seq: group.seqRange.0))
        } else {
            if seqGroupsAfterHole.count == 0 {
                Logger.shared.log("State", "update seq hole: \(group.seqRange.0) != \(updatedState.state.seq) + \(group.seqRange.1)")
            }
            seqGroupsAfterHole.append(group)
        }
    }
    
    var currentDateGroups = dateGroups(groups)
    currentDateGroups.sort(by: { group1, group2 -> Bool in
        switch group1 {
            case let .withDate(_, date1, _, _):
                switch group2 {
                    case let .withDate(_, date2, _, _):
                        return date1 < date2
                    default:
                        return false
                }
            default:
                return false
        }
    })
    
    var updatesDate: Int32?
    
    for group in currentDateGroups {
        switch group {
            case let .withDate(updates, date, users, chats):
                collectedUpdates.append(contentsOf: updates)
                
                updatedState.mergeChats(chats)
                updatedState.mergeUsers(users)
                if updatesDate == nil {
                    updatesDate = date
                }
            default:
                break
        }
    }
    
    for case let .updateChannelPts(channelId, pts, ptsCount) in groups {
        collectedUpdates.append(Api.Update.updateDeleteChannelMessages(channelId: channelId, messages: [], pts: pts, ptsCount: ptsCount))
    }
    
    return finalStateWithUpdates(postbox: postbox, network: network, state: updatedState, updates: collectedUpdates, shouldPoll: hadReset, missingUpdates: !ptsUpdatesAfterHole.isEmpty || !qtsUpdatesAfterHole.isEmpty || !seqGroupsAfterHole.isEmpty, shouldResetChannels: false, updatesDate: updatesDate)
}

func finalStateWithDifference(postbox: Postbox, network: Network, state: AccountMutableState, difference: Api.updates.Difference) -> Signal<AccountFinalState, NoError> {
    var updatedState = state
    
    var messages: [Api.Message] = []
    var encryptedMessages: [Api.EncryptedMessage] = []
    var updates: [Api.Update] = []
    var chats: [Api.Chat] = []
    var users: [Api.User] = []
    
    switch difference {
        case let .difference(newMessages, newEncryptedMessages, otherUpdates, apiChats, apiUsers, apiState):
            messages = newMessages
            encryptedMessages = newEncryptedMessages
            updates = otherUpdates
            chats = apiChats
            users = apiUsers
            switch apiState {
                case let .state(pts, qts, date, seq, _):
                    updatedState.updateState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq))
            }
        case let .differenceEmpty(date, seq):
            updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: updatedState.state.qts, date: date, seq: seq))
        case let .differenceSlice(newMessages, newEncryptedMessages, otherUpdates, apiChats, apiUsers, apiState):
            messages = newMessages
            encryptedMessages = newEncryptedMessages
            updates = otherUpdates
            chats = apiChats
            users = apiUsers
            switch apiState {
                case let .state(pts, qts, date, seq, _):
                    updatedState.updateState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq))
            }
        case .differenceTooLong:
            assertionFailure()
            break
    }
    
    updatedState.mergeChats(chats)
    updatedState.mergeUsers(users)
    
    for message in messages {
        if let preCachedResources = message.preCachedResources {
            for (resource, data) in preCachedResources {
                updatedState.addPreCachedResource(resource, data: data)
            }
        }
        if let message = StoreMessage(apiMessage: message) {
            updatedState.addMessages([message], location: .UpperHistoryBlock)
        }
    }
    
    if !encryptedMessages.isEmpty {
        updatedState.addSecretMessages(encryptedMessages)
    }
    
    return finalStateWithUpdates(postbox: postbox, network: network, state: updatedState, updates: updates, shouldPoll: false, missingUpdates: false, shouldResetChannels: true, updatesDate: nil)
}

private func sortedUpdates(_ updates: [Api.Update]) -> [Api.Update] {
    var otherUpdates: [Api.Update] = []
    var updatesByChannel: [PeerId: [Api.Update]] = [:]
    
    for update in updates {
        switch update {
            case let .updateChannelTooLong(_, channelId, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateDeleteChannelMessages(channelId, _, _, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updatePinnedChannelMessages(_, channelId, _, _, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateNewChannelMessage(message, _, _):
                if let peerId = apiMessagePeerId(message) {
                    if updatesByChannel[peerId] == nil {
                        updatesByChannel[peerId] = [update]
                    } else {
                        updatesByChannel[peerId]!.append(update)
                    }
                } else {
                    otherUpdates.append(update)
                }
            case let .updateEditChannelMessage(message, _, _):
                if let peerId = apiMessagePeerId(message) {
                    if updatesByChannel[peerId] == nil {
                        updatesByChannel[peerId] = [update]
                    } else {
                        updatesByChannel[peerId]!.append(update)
                    }
                } else {
                    otherUpdates.append(update)
                }
            case let .updateChannelWebPage(channelId, _, _, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateChannelAvailableMessages(channelId, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
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
                case let .updateDeleteChannelMessages(_, _, pts, _):
                    lhsPts = pts
                case let .updateNewChannelMessage(_, pts, _):
                    lhsPts = pts
                case let .updateChannelWebPage(_, _, pts, _):
                    lhsPts = pts
                case let .updateEditChannelMessage(_, pts, _):
                    lhsPts = pts
                case let .updatePinnedChannelMessages(_, _, _, pts, _):
                    lhsPts = pts
                default:
                    break
            }
            
            switch rhs {
                case let .updateDeleteChannelMessages(_, _, pts, _):
                    rhsPts = pts
                case let .updateNewChannelMessage(_, pts, _):
                    rhsPts = pts
                case let .updateChannelWebPage(_, _, pts, _):
                    rhsPts = pts
                case let .updateEditChannelMessage(_, pts, _):
                    rhsPts = pts
                case let .updatePinnedChannelMessages(_, _, _, pts, _):
                    rhsPts = pts
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

private func finalStateWithUpdates(postbox: Postbox, network: Network, state: AccountMutableState, updates: [Api.Update], shouldPoll: Bool, missingUpdates: Bool, shouldResetChannels: Bool, updatesDate: Int32?) -> Signal<AccountFinalState, NoError> {
    return network.currentGlobalTime
    |> take(1)
    |> mapToSignal { serverTime -> Signal<AccountFinalState, NoError> in
        return finalStateWithUpdatesAndServerTime(postbox: postbox, network: network, state: state, updates: updates, shouldPoll: shouldPoll, missingUpdates: missingUpdates, shouldResetChannels: shouldResetChannels, updatesDate: updatesDate, serverTime: Int32(serverTime))
    }
}
    
private func finalStateWithUpdatesAndServerTime(postbox: Postbox, network: Network, state: AccountMutableState, updates: [Api.Update], shouldPoll: Bool, missingUpdates: Bool, shouldResetChannels: Bool, updatesDate: Int32?, serverTime: Int32) -> Signal<AccountFinalState, NoError> {
    var updatedState = state
    
    var channelsToPoll = Set<PeerId>()
    
    if !updatedState.initialState.channelsToPollExplicitely.isEmpty {
        channelsToPoll.formUnion(updatedState.initialState.channelsToPollExplicitely)
    }
    
    var missingUpdatesFromChannels = Set<PeerId>()
    
    for update in sortedUpdates(updates) {
        switch update {
            case let .updateChannelTooLong(_, channelId, channelPts):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if !channelsToPoll.contains(peerId) {
                    if let channelPts = channelPts, let channelState = state.channelStates[peerId], channelState.pts >= channelPts {
                        Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip updateChannelTooLong by pts")
                    } else {
                        channelsToPoll.insert(peerId)
                    }
                }
            case let .updateDeleteChannelMessages(channelId, messages, pts: pts, ptsCount):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if let previousState = updatedState.channelStates[peerId] {
                    if previousState.pts >= pts {
                        Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old delete update")
                    } else if previousState.pts + ptsCount == pts {
                        updatedState.deleteMessages(messages.map({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }))
                        updatedState.updateChannelState(peerId, pts: pts)
                    } else {
                        if !missingUpdatesFromChannels.contains(peerId) {
                            Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) delete pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                            missingUpdatesFromChannels.insert(peerId)
                        }
                    }
                } else {
                    if !channelsToPoll.contains(peerId) {
                        //Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) state unknown")
                        channelsToPoll.insert(peerId)
                    }
                }
            case let .updateEditChannelMessage(apiMessage, pts, ptsCount):
                if let message = StoreMessage(apiMessage: apiMessage), case let .Id(messageId) = message.id {
                    let peerId = messageId.peerId
                    if let previousState = updatedState.channelStates[peerId] {
                        if previousState.pts >= pts {
                            Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old edit update")
                        } else if previousState.pts + ptsCount == pts {
                            if let preCachedResources = apiMessage.preCachedResources {
                                for (resource, data) in preCachedResources {
                                    updatedState.addPreCachedResource(resource, data: data)
                                }
                            }
                            var attributes = message.attributes
                            attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                            updatedState.editMessage(messageId, message: message.withUpdatedAttributes(attributes))
                            updatedState.updateChannelState(peerId, pts: pts)
                        } else {
                            if !missingUpdatesFromChannels.contains(peerId) {
                                Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) edit message pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                                missingUpdatesFromChannels.insert(peerId)
                            }
                        }
                    } else {
                        if !channelsToPoll.contains(peerId) {
                            //Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) state unknown")
                            channelsToPoll.insert(peerId)
                        }
                    }
                } else {
                    Logger.shared.log("State", "Invalid updateEditChannelMessage")
                }
            case let .updateChannelWebPage(channelId, apiWebpage, pts, ptsCount):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if let previousState = updatedState.channelStates[peerId] {
                    if previousState.pts >= pts {
                    } else if previousState.pts + ptsCount == pts {
                        switch apiWebpage {
                            case let .webPageEmpty(id):
                                updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
                            default:
                                if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage, url: nil) {
                                    updatedState.updateMedia(webpage.webpageId, media: webpage)
                                }
                        }
                        
                        updatedState.updateChannelState(peerId, pts: pts)
                    } else {
                        if !channelsToPoll.contains(peerId) {
                            Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) updateWebPage pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                            channelsToPoll.insert(peerId)
                        }
                    }
                } else {
                    if !channelsToPoll.contains(peerId) {
                        channelsToPoll.insert(peerId)
                    }
                }
            case let .updateChannelAvailableMessages(channelId, minId):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                updatedState.updateMinAvailableMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: minId))
            case let .updateDeleteMessages(messages, _, _):
                updatedState.deleteMessagesWithGlobalIds(messages)
            case let .updatePinnedMessages(flags, peer, messages, _, _):
                let peerId = peer.peerId
                updatedState.updateMessagesPinned(ids: messages.map { id in
                    MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
                }, pinned: (flags & (1 << 0)) != 0)
            case let .updateEditMessage(apiMessage, _, _):
                if let message = StoreMessage(apiMessage: apiMessage), case let .Id(messageId) = message.id {
                    if let preCachedResources = apiMessage.preCachedResources {
                        for (resource, data) in preCachedResources {
                            updatedState.addPreCachedResource(resource, data: data)
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
            case let .updateNewChannelMessage(apiMessage, pts, ptsCount):
                if let message = StoreMessage(apiMessage: apiMessage) {
                    if let previousState = updatedState.channelStates[message.id.peerId] {
                        if previousState.pts >= pts {
                            let messageText: String
                            if Logger.shared.redactSensitiveData {
                                messageText = "[[redacted]]"
                            } else {
                                messageText = message.text
                            }
                        Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) skip old message \(message.id) (\(messageText))")
                        } else if previousState.pts + ptsCount == pts {
                            if let preCachedResources = apiMessage.preCachedResources {
                                for (resource, data) in preCachedResources {
                                    updatedState.addPreCachedResource(resource, data: data)
                                }
                            }
                            var attributes = message.attributes
                            attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                            updatedState.addMessages([message.withUpdatedAttributes(attributes)], location: .UpperHistoryBlock)
                            updatedState.updateChannelState(message.id.peerId, pts: pts)
                            if case let .Id(id) = message.id {
                                updatedState.updateChannelSynchronizedUntilMessage(id.peerId, id: id.id)
                            }
                        } else {
                            if !missingUpdatesFromChannels.contains(message.id.peerId) {
                                Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) message pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                                ;
                                missingUpdatesFromChannels.insert(message.id.peerId)
                            }
                        }
                    } else {
                        if !channelsToPoll.contains(message.id.peerId) {
                            Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) state unknown")
                            channelsToPoll.insert(message.id.peerId)
                        }
                    }
                }
            case let .updateNewMessage(apiMessage, _, _):
                if let message = StoreMessage(apiMessage: apiMessage) {
                    if let preCachedResources = apiMessage.preCachedResources {
                        for (resource, data) in preCachedResources {
                            updatedState.addPreCachedResource(resource, data: data)
                        }
                    }
                    updatedState.addMessages([message], location: .UpperHistoryBlock)
                }
            case let .updateServiceNotification(flags, date, type, text, media, entities):
                let popup = (flags & (1 << 0)) != 0
                if popup {
                    updatedState.addDisplayAlert(text, isDropAuth: type.hasPrefix("AUTH_KEY_DROP_"))
                } else if let date = date {
                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
                    
                    if updatedState.peers[peerId] == nil {
                        updatedState.updatePeer(peerId, { peer in
                            if peer == nil {
                                return TelegramUser(id: peerId, accessHash: nil, firstName: "Telegram Notifications", lastName: nil, username: nil, phone: nil, photo: [], botInfo: BotUserInfo(flags: [], inlinePlaceholder: nil), restrictionInfo: nil, flags: [.isVerified])
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
                        
                        let (mediaValue, expirationTimer, nonPremium) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                        if let mediaValue = mediaValue {
                            medias.append(mediaValue)
                        }
                        if let expirationTimer = expirationTimer {
                            attributes.append(AutoclearTimeoutMessageAttribute(timeout: expirationTimer, countdownBeginTime: nil))
                        }
                        
                        if let nonPremium = nonPremium, nonPremium {
                            attributes.append(NonPremiumMessageAttribute())
                        }
                        
                        if type.hasPrefix("auth") {
                            updatedState.authorizationListUpdated = true
                        }
                        
                        let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: messageText, attributes: attributes, media: medias)
                        updatedState.addMessages([message], location: .UpperHistoryBlock)
                    }
                }
            case let .updateReadChannelInbox(_, folderId, channelId, maxId, stillUnreadCount, pts):
                updatedState.resetIncomingReadState(groupId: PeerGroupId(rawValue: folderId ?? 0), peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, maxIncomingReadId: maxId, count: stillUnreadCount, pts: pts)
            case let .updateReadChannelOutbox(channelId, maxId):
                updatedState.readOutbox(MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: maxId), timestamp: nil)
            case let .updateChannel(channelId):
                updatedState.addExternallyUpdatedPeerId(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)))
            case let .updateChat(chatId):
                updatedState.addExternallyUpdatedPeerId(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)))
            case let .updateReadHistoryInbox(_, folderId, peer, maxId, stillUnreadCount, pts, _):
                updatedState.resetIncomingReadState(groupId: PeerGroupId(rawValue: folderId ?? 0), peerId: peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: maxId, count: stillUnreadCount, pts: pts)
            case let .updateReadHistoryOutbox(peer, maxId, _, _):
                updatedState.readOutbox(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: maxId), timestamp: updatesDate)
            case let .updateReadChannelDiscussionInbox(_, channelId, topMsgId, readMaxId, mainChannelId, mainChannelPost):
                var mainChannelMessage: MessageId?
                if let mainChannelId = mainChannelId, let mainChannelPost = mainChannelPost {
                    mainChannelMessage = MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(mainChannelId)), namespace: Namespaces.Message.Cloud, id: mainChannelPost)
                }
                updatedState.readThread(threadMessageId: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: topMsgId), readMaxId: readMaxId, isIncoming: true, mainChannelMessage: mainChannelMessage)
            case let .updateReadChannelDiscussionOutbox(channelId, topMsgId, readMaxId):
                updatedState.readThread(threadMessageId: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: topMsgId), readMaxId: readMaxId, isIncoming: false, mainChannelMessage: nil)
            case let .updateDialogUnreadMark(flags, peer):
                switch peer {
                    case let .dialogPeer(peer):
                        let peerId = peer.peerId
                        updatedState.updatePeerChatUnreadMark(peerId, namespace: Namespaces.Message.Cloud, value: (flags & (1 << 0)) != 0)
                    case .dialogPeerFolder:
                        break
                }
            case let .updateWebPage(apiWebpage, _, _):
                switch apiWebpage {
                    case let .webPageEmpty(id):
                        updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
                    default:
                        if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage, url: nil) {
                            updatedState.updateMedia(webpage.webpageId, media: webpage)
                        }
                }
            case let .updateTranscribedAudio(flags, peer, msgId, transcriptionId, text):
                let isPending = (flags & (1 << 0)) != 0
                updatedState.updateAudioTranscription(messageId: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), id: transcriptionId, isPending: isPending, text: text)
            case let .updateNotifySettings(apiPeer, apiNotificationSettings):
                switch apiPeer {
                    case let .notifyPeer(peer):
                        let notificationSettings = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                        updatedState.updateNotificationSettings(.peer(peer.peerId), notificationSettings: notificationSettings)
                    case .notifyUsers:
                        updatedState.updateGlobalNotificationSettings(.privateChats, notificationSettings: MessageNotificationSettings(apiSettings: apiNotificationSettings))
                    case .notifyChats:
                        updatedState.updateGlobalNotificationSettings(.groups, notificationSettings: MessageNotificationSettings(apiSettings: apiNotificationSettings))
                    case .notifyBroadcasts:
                        updatedState.updateGlobalNotificationSettings(.channels, notificationSettings: MessageNotificationSettings(apiSettings: apiNotificationSettings))
                }
            case let .updateChatParticipants(participants):
                let groupPeerId: PeerId
                switch participants {
                    case let .chatParticipants(chatId, _, _):
                        groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                    case let .chatParticipantsForbidden(_, chatId, _):
                        groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                }
                updatedState.updateCachedPeerData(groupPeerId, { current in
                    let previous: CachedGroupData
                    if let current = current as? CachedGroupData {
                        previous = current
                    } else {
                        previous = CachedGroupData()
                    }
                    return previous.withUpdatedParticipants(CachedGroupParticipants(apiParticipants: participants))
                })
            case let .updateChatParticipantAdd(chatId, userId, inviterId, date, _):
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                let inviterPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId))
                updatedState.updateCachedPeerData(groupPeerId, { current in
                    if let current = current as? CachedGroupData, let participants = current.participants {
                        var updatedParticipants = participants.participants
                        if updatedParticipants.firstIndex(where: { $0.peerId == userPeerId }) == nil {
                            updatedParticipants.append(.member(id: userPeerId, invitedBy: inviterPeerId, invitedAt: date))
                        }
                        return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
                    } else {
                        return current
                    }
                })
            case let .updateChatParticipantDelete(chatId, userId, _):
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                updatedState.updateCachedPeerData(groupPeerId, { current in
                    if let current = current as? CachedGroupData, let participants = current.participants {
                        var updatedParticipants = participants.participants
                        if let index = updatedParticipants.firstIndex(where: { $0.peerId == userPeerId }) {
                            updatedParticipants.remove(at: index)
                        }
                        return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
                    } else {
                        return current
                    }
                })
            case let .updateChatParticipantAdmin(chatId, userId, isAdmin, _):
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                updatedState.updateCachedPeerData(groupPeerId, { current in
                    if let current = current as? CachedGroupData, let participants = current.participants {
                        var updatedParticipants = participants.participants
                        if let index = updatedParticipants.firstIndex(where: { $0.peerId == userPeerId }) {
                            if isAdmin == .boolTrue {
                                if case let .member(id, invitedBy, invitedAt) = updatedParticipants[index] {
                                    updatedParticipants[index] = .admin(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
                                }
                            } else {
                                if case let .admin(id, invitedBy, invitedAt) = updatedParticipants[index] {
                                    updatedParticipants[index] = .member(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
                                }
                            }
                        }
                        return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
                    } else {
                        return current
                    }
                })
            case let .updateChatDefaultBannedRights(peer, defaultBannedRights, version):
                updatedState.updatePeer(peer.peerId, { peer in
                    if let group = peer as? TelegramGroup {//, group.version == version - 1 {
                        return group.updateDefaultBannedRights(TelegramChatBannedRights(apiBannedRights: defaultBannedRights), version: max(group.version, Int(version)))
                    } else if let channel = peer as? TelegramChannel {//, group.version == version - 1 {
                        return channel.withUpdatedDefaultBannedRights(TelegramChatBannedRights(apiBannedRights: defaultBannedRights))
                    } else {
                        return peer
                    }
                })
            case let .updatePinnedChannelMessages(flags, channelId, messages, pts, ptsCount):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                if let previousState = updatedState.channelStates[peerId] {
                    if previousState.pts >= pts {
                        Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old pinned messages update")
                    } else if previousState.pts + ptsCount == pts {
                        let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        updatedState.updateMessagesPinned(ids: messages.map { id in
                            MessageId(peerId: channelPeerId, namespace: Namespaces.Message.Cloud, id: id)
                        }, pinned: (flags & (1 << 0)) != 0)
                        updatedState.updateChannelState(peerId, pts: pts)
                    } else {
                        if !missingUpdatesFromChannels.contains(peerId) {
                            Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) pinned messages pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                            missingUpdatesFromChannels.insert(peerId)
                        }
                    }
                } else {
                    if !channelsToPoll.contains(peerId) {
                        //Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) state unknown")
                        channelsToPoll.insert(peerId)
                    }
                }
            case let .updatePeerBlocked(peerId, blocked):
                let userPeerId = peerId.peerId
                updatedState.updateCachedPeerData(userPeerId, { current in
                    let previous: CachedUserData
                    if let current = current as? CachedUserData {
                        previous = current
                    } else {
                        previous = CachedUserData()
                    }
                    return previous.withUpdatedIsBlocked(blocked == .boolTrue)
                })
            case let .updateUserStatus(userId, status):
                updatedState.mergePeerPresences([PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)): status], explicit: true)
            case let .updateUserName(userId, _, _, username):
                //TODO add contact checking for apply first and last name
                updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), { peer in
                    if let user = peer as? TelegramUser {
                        return user.withUpdatedUsername(username)
                    } else {
                        return peer
                    }
                })
            case let .updateUserPhoto(userId, _, photo, _):
                updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), { peer in
                    if let user = peer as? TelegramUser {
                        return user.withUpdatedPhoto(parsedTelegramProfilePhoto(photo))
                    } else {
                        return peer
                    }
                })
            case let .updateUserPhone(userId, phone):
                updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), { peer in
                    if let user = peer as? TelegramUser {
                        return user.withUpdatedPhone(phone.isEmpty ? nil : phone)
                    } else {
                        return peer
                    }
                })
            case let .updatePeerSettings(peer, settings):
                let peerStatusSettings = PeerStatusSettings(apiSettings: settings)
                updatedState.updateCachedPeerData(peer.peerId, { current in
                    if peer.peerId.namespace == Namespaces.Peer.CloudUser {
                        let previous: CachedUserData
                        if let current = current as? CachedUserData {
                            previous = current
                        } else {
                            previous = CachedUserData()
                        }
                        return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
                    } else if peer.peerId.namespace == Namespaces.Peer.CloudGroup {
                        let previous: CachedGroupData
                        if let current = current as? CachedGroupData {
                            previous = current
                        } else {
                            previous = CachedGroupData()
                        }
                        return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
                    } else if peer.peerId.namespace == Namespaces.Peer.CloudChannel {
                        let previous: CachedChannelData
                        if let current = current as? CachedChannelData {
                            previous = current
                        } else {
                            previous = CachedChannelData()
                        }
                        return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
                    } else {
                        return current
                    }
                })
            case let .updateEncryption(chat, date):
                updatedState.updateSecretChat(chat: chat, timestamp: date)
            case let .updateNewEncryptedMessage(message, _):
                updatedState.addSecretMessages([message])
            case let .updateEncryptedMessagesRead(chatId, maxDate, date):
                updatedState.readSecretOutbox(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId))), timestamp: maxDate, actionTimestamp: date)
            case let .updateUserTyping(userId, type):
                if let date = updatesDate, date + 60 > serverTime {
                    let activity = PeerInputActivity(apiType: type, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), timestamp: date)
                    var category: PeerActivitySpace.Category = .global
                    if case .speakingInGroupCall = activity {
                        category = .voiceChat
                    }
                    
                    updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), category: category), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), activity: activity)
                }
            case let .updateChatUserTyping(chatId, userId, type):
                if let date = updatesDate, date + 60 > serverTime {
                    let activity = PeerInputActivity(apiType: type, peerId: nil, timestamp: date)
                    var category: PeerActivitySpace.Category = .global
                    if case .speakingInGroupCall = activity {
                        category = .voiceChat
                    }
                    
                    updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), category: category), peerId: userId.peerId, activity: activity)
                }
            case let .updateChannelUserTyping(_, channelId, topMsgId, userId, type):
                if let date = updatesDate, date + 60 > serverTime {
                    let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                    let threadId = topMsgId.flatMap { makeMessageThreadId(MessageId(peerId: channelPeerId, namespace: Namespaces.Message.Cloud, id: $0)) }
                    
                    let activity = PeerInputActivity(apiType: type, peerId: nil, timestamp: date)
                    var category: PeerActivitySpace.Category = .global
                    if case .speakingInGroupCall = activity {
                        category = .voiceChat
                    } else if let threadId = threadId {
                        category = .thread(threadId)
                    }
                    
                    updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: channelPeerId, category: category), peerId: userId.peerId, activity: activity)
                }
            case let .updateEncryptedChatTyping(chatId):
                if let date = updatesDate, date + 60 > serverTime {
                    updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId))), category: .global), peerId: nil, activity: .typingText)
                }
            case let .updateDialogPinned(flags, folderId, peer):
                let groupId: PeerGroupId = folderId.flatMap(PeerGroupId.init(rawValue:)) ?? .root
                let item: PinnedItemId
                switch peer {
                    case let .dialogPeer(peer):
                        item = .peer(peer.peerId)
                    case .dialogPeerFolder:
                        preconditionFailure()
                }
                if (flags & (1 << 0)) != 0 {
                    updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .pin(item))
                } else {
                    updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .unpin(item))
                }
            case let .updatePinnedDialogs(_, folderId, order):
                let groupId: PeerGroupId = folderId.flatMap(PeerGroupId.init(rawValue:)) ?? .root
                if let order = order {
                    updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .reorder(order.map {
                        let item: PinnedItemId
                        switch $0 {
                            case let .dialogPeer(peer):
                                item = .peer(peer.peerId)
                            case .dialogPeerFolder:
                                preconditionFailure()
                        }
                        return item
                    }))
                } else {
                    updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .sync)
                }
            case let .updateReadMessagesContents(messages, _, _):
                updatedState.addReadMessagesContents((nil, messages))
            case let .updateChannelReadMessagesContents(channelId, messages):
                updatedState.addReadMessagesContents((PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), messages))
            case let .updateChannelMessageViews(channelId, id, views):
                updatedState.addUpdateMessageImpressionCount(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: id), count: views)
            /*case let .updateChannelMessageForwards(channelId, id, forwards):
                updatedState.addUpdateMessageForwardsCount(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), namespace: Namespaces.Message.Cloud, id: id), count: forwards)*/
            case let .updateNewStickerSet(stickerset):
                updatedState.addUpdateInstalledStickerPacks(.add(stickerset))
            case let .updateStickerSetsOrder(flags, order):
                let namespace: SynchronizeInstalledStickerPacksOperationNamespace
                if (flags & (1 << 0)) != 0 {
                    namespace = .masks
                } else {
                    namespace = .stickers
                }
                updatedState.addUpdateInstalledStickerPacks(.reorder(namespace, order))
            case .updateStickerSets:
                updatedState.addUpdateInstalledStickerPacks(.sync)
            case .updateSavedGifs:
                updatedState.addUpdateRecentGifs()
            case let .updateDraftMessage(peer, draft):
                let inputState: SynchronizeableChatInputState?
                switch draft {
                    case .draftMessageEmpty:
                        inputState = nil
                    case let .draftMessage(_, replyToMsgId, message, entities, date):
                        var replyToMessageId: MessageId?
                        if let replyToMsgId = replyToMsgId {
                            replyToMessageId = MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                        }
                        inputState = SynchronizeableChatInputState(replyToMessageId: replyToMessageId, text: message, entities: messageTextEntitiesFromApiEntities(entities ?? []), timestamp: date, textSelection: nil)
                }
                updatedState.addUpdateChatInputState(peerId: peer.peerId, state: inputState)
            case let .updatePhoneCall(phoneCall):
                updatedState.addUpdateCall(phoneCall)
            case let .updatePhoneCallSignalingData(phoneCallId, data):
                updatedState.addCallSignalingData(callId: phoneCallId, data: data.makeData())
            case let .updateGroupCallParticipants(call, participants, version):
                switch call {
                case let .inputGroupCall(id, accessHash):
                    updatedState.updateGroupCallParticipants(id: id, accessHash: accessHash, participants: participants, version: version)
                }
            case let .updateGroupCall(channelId, call):
                updatedState.updateGroupCall(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), call: call)
                updatedState.updateGroupCall(peerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(channelId)), call: call)
            case let .updatePeerHistoryTTL(_, peer, ttl):
                updatedState.updateAutoremoveTimeout(peer: peer, value: CachedPeerAutoremoveTimeout.Value(ttl))
            case let .updateLangPackTooLong(langCode):
                updatedState.updateLangPack(langCode: langCode, difference: nil)
            case let .updateLangPack(difference):
                let langCode: String
                switch difference {
                    case let .langPackDifference(langCodeValue, _, _, _):
                        langCode = langCodeValue
                }
                updatedState.updateLangPack(langCode: langCode, difference: difference)
            case let .updateMessagePoll(_, pollId, poll, results):
                updatedState.updateMessagePoll(MediaId(namespace: Namespaces.Media.CloudPoll, id: pollId), poll: poll, results: results)
            case let .updateFolderPeers(folderPeers, _, _):
                for folderPeer in folderPeers {
                    switch folderPeer {
                        case let .folderPeer(peer, folderId):
                            updatedState.updatePeerChatInclusion(peerId: peer.peerId, groupId: PeerGroupId(rawValue: folderId), changedGroup: true)
                    }
                }
            case let .updatePeerLocated(peers):
                var peersNearby: [PeerNearby] = []
                for peer in peers {
                    switch peer {
                        case let .peerLocated(peer, expires, distance):
                            peersNearby.append(.peer(id: peer.peerId, expires: expires, distance: distance))
                        case let .peerSelfLocated(expires):
                            peersNearby.append(.selfPeer(expires: expires))
                    }
                }
                updatedState.updatePeersNearby(peersNearby)
            case let .updateNewScheduledMessage(apiMessage):
                if let message = StoreMessage(apiMessage: apiMessage, namespace: Namespaces.Message.ScheduledCloud) {
                    updatedState.addScheduledMessages([message])
                }
            case let .updateDeleteScheduledMessages(peer, messages):
                var messageIds: [MessageId] = []
                for message in messages {
                    messageIds.append(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.ScheduledCloud, id: message))
                }
                updatedState.deleteMessages(messageIds)
            case let .updateTheme(theme):
                updatedState.updateTheme(TelegramTheme(apiTheme: theme))
            case let .updateMessageID(id, randomId):
                updatedState.updatedOutgoingUniqueMessageIds[randomId] = id
            case .updateDialogFilters:
                updatedState.addSyncChatListFilters()
            case let .updateDialogFilterOrder(order):
                updatedState.addUpdateChatListFilterOrder(order: order)
            case let .updateDialogFilter(_, id, filter):
                updatedState.addUpdateChatListFilter(id: id, filter: filter)
            case let .updateBotCommands(peer, botId, apiCommands):
                let botPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))
                let commands: [BotCommand] = apiCommands.map { command in
                    switch command {
                    case let .botCommand(command, description):
                        return BotCommand(text: command, description: description)
                    }
                }
                updatedState.updateCachedPeerData(peer.peerId, { current in
                    if peer.peerId.namespace == Namespaces.Peer.CloudUser, let previous = current as? CachedUserData {
                        if let botInfo = previous.botInfo {
                            return previous.withUpdatedBotInfo(BotInfo(description: botInfo.description, photo: botInfo.photo, video: botInfo.video, commands: commands, menuButton: botInfo.menuButton))
                        }
                    } else if peer.peerId.namespace == Namespaces.Peer.CloudGroup, let previous = current as? CachedGroupData {
                        if let index = previous.botInfos.firstIndex(where: { $0.peerId == botPeerId }) {
                            var updatedBotInfos = previous.botInfos
                            let previousBotInfo = updatedBotInfos[index]
                            updatedBotInfos.remove(at: index)
                            updatedBotInfos.insert(CachedPeerBotInfo(peerId: botPeerId, botInfo: BotInfo(description: previousBotInfo.botInfo.description, photo: previousBotInfo.botInfo.photo, video: previousBotInfo.botInfo.video, commands: commands, menuButton: previousBotInfo.botInfo.menuButton)), at: index)
                            return previous.withUpdatedBotInfos(updatedBotInfos)
                        }
                    } else if peer.peerId.namespace == Namespaces.Peer.CloudChannel, let previous = current as? CachedChannelData {
                        if let index = previous.botInfos.firstIndex(where: { $0.peerId == botPeerId }) {
                            var updatedBotInfos = previous.botInfos
                            let previousBotInfo = updatedBotInfos[index]
                            updatedBotInfos.remove(at: index)
                            updatedBotInfos.insert(CachedPeerBotInfo(peerId: botPeerId, botInfo: BotInfo(description: previousBotInfo.botInfo.description, photo: previousBotInfo.botInfo.photo, video: previousBotInfo.botInfo.video, commands: commands, menuButton: previousBotInfo.botInfo.menuButton)), at: index)
                            return previous.withUpdatedBotInfos(updatedBotInfos)
                        }
                    }
                    return current
                })
            case let .updateBotMenuButton(botId, button):
                let botPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))
                let menuButton = BotMenuButton(apiBotMenuButton: button)
                updatedState.updateCachedPeerData(botPeerId, { current in
                    if let previous = current as? CachedUserData {
                        if let botInfo = previous.botInfo {
                            return previous.withUpdatedBotInfo(BotInfo(description: botInfo.description, photo: botInfo.photo, video: botInfo.video, commands: botInfo.commands, menuButton: menuButton))
                        }
                    }
                    return current
                })
            case let .updatePendingJoinRequests(peer, requestsPending, _):
                updatedState.updateCachedPeerData(peer.peerId, { current in
                    if peer.peerId.namespace == Namespaces.Peer.CloudGroup {
                        let previous: CachedGroupData
                        if let current = current as? CachedGroupData {
                            previous = current
                        } else {
                            previous = CachedGroupData()
                        }
                        return previous.withUpdatedInviteRequestsPending(requestsPending)
                    } else if peer.peerId.namespace == Namespaces.Peer.CloudChannel {
                        let previous: CachedChannelData
                        if let current = current as? CachedChannelData {
                            previous = current
                        } else {
                            previous = CachedChannelData()
                        }
                        return previous.withUpdatedInviteRequestsPending(requestsPending)
                    } else {
                        return current
                    }
                })
            case let .updateMessageReactions(peer, msgId, reactions):
                updatedState.updateMessageReactions(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), reactions: reactions, eventTimestamp: updatesDate)
            case .updateAttachMenuBots:
                updatedState.addUpdateAttachMenuBots()
            case let .updateWebViewResultSent(queryId):
                updatedState.addDismissWebView(queryId)
            case .updateConfig:
                updatedState.reloadConfig()
            default:
                break
        }
    }
    
    var pollChannelSignals: [Signal<(AccountMutableState, Bool, Int32?), NoError>] = []
    if channelsToPoll.isEmpty && missingUpdatesFromChannels.isEmpty {
        pollChannelSignals = []
    } else if shouldResetChannels {
        var channelPeers: [Peer] = []
        for peerId in channelsToPoll.union(missingUpdatesFromChannels) {
            if let peer = updatedState.peers[peerId] {
                channelPeers.append(peer)
            } else {
                Logger.shared.log("State", "can't reset channel \(peerId): no peer found")
            }
        }
        if !channelPeers.isEmpty {
            let resetSignal = resetChannels(network: network, peers: channelPeers, state: updatedState)
            |> map { resultState -> (AccountMutableState, Bool, Int32?) in
                return (resultState, true, nil)
            }
            pollChannelSignals = [resetSignal]
        } else {
            pollChannelSignals = []
        }
    } else {
        for peerId in channelsToPoll.union(missingUpdatesFromChannels) {
            if let peer = updatedState.peers[peerId] {
                pollChannelSignals.append(pollChannel(network: network, peer: peer, state: updatedState.branch()))
            } else {
                Logger.shared.log("State", "can't poll channel \(peerId): no peer found")
            }
        }
    }
    
    return combineLatest(pollChannelSignals) |> mapToSignal { states -> Signal<AccountFinalState, NoError> in
        var finalState: AccountMutableState = updatedState
        var hadError = false
        
        if shouldResetChannels && states.count != 0 {
            assert(states.count == 1)
            finalState = states[0].0
        } else {
            for (state, success, _) in states {
                finalState.merge(state)
                if !success {
                    hadError = true
                }
            }
        }
        return resolveAssociatedMessages(network: network, state: finalState)
        |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
            return resolveMissingPeerChatInfos(network: network, state: resultingState)
            |> map { resultingState, resolveError -> AccountFinalState in
                return AccountFinalState(state: resultingState, shouldPoll: shouldPoll || hadError || resolveError, incomplete: missingUpdates, missingUpdatesFromChannels: Set(), discard: resolveError)
            }
        }
    }
}


private func resolveAssociatedMessages(network: Network, state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    let missingMessageIds = state.referencedMessageIds.subtracting(state.storedMessages)
    if missingMessageIds.isEmpty {
        return .single(state)
    } else {
        var missingPeers = false
        let _ = missingPeers
        
        var signals: [Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>] = []
        for (peerId, messageIds) in messagesIdsGroupedByPeerId(missingMessageIds) {
            if let peer = state.peers[peerId] {
                var signal: Signal<Api.messages.Messages, MTRpcError>?
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                    signal = network.request(Api.functions.messages.getMessages(id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let inputChannel = apiInputChannel(peer) {
                        signal = network.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                    }
                }
                if let signal = signal {
                    signals.append(signal |> map { result in
                        switch result {
                            case let .messages(messages, chats, users):
                                return (messages, chats, users)
                            case let .messagesSlice(_, _, _, _, messages, chats, users):
                                return (messages, chats, users)
                            case let .channelMessages(_, _, _, _, messages, chats, users):
                                return (messages, chats, users)
                            case .messagesNotModified:
                                return ([], [], [])
                        }
                    } |> `catch` { _ in
                        return Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>.single(([], [], []))
                    })
                }
            } else {
                missingPeers = true
            }
        }
        
        let fetchMessages = combineLatest(signals)
        
        return fetchMessages |> map { results in
            var updatedState = state
            for (messages, chats, users) in results {
                if !messages.isEmpty {
                    var storeMessages: [StoreMessage] = []
                    for message in messages {
                        if let message = StoreMessage(apiMessage: message) {
                            storeMessages.append(message)
                        }
                    }
                    updatedState.addMessages(storeMessages, location: .Random)
                }
                if !chats.isEmpty {
                    updatedState.mergeChats(chats)
                }
                if !users.isEmpty {
                    updatedState.mergeUsers(users)
                }
            }
            return updatedState
        }
    }
}

private func resolveMissingPeerChatInfos(network: Network, state: AccountMutableState) -> Signal<(AccountMutableState, Bool), NoError> {
    var missingPeers: [PeerId: Api.InputPeer] = [:]
    var hadError = false
    
    for peerId in state.initialState.peerIdsRequiringLocalChatState {
        if state.peerChatInfos[peerId] == nil {
            if let peer = state.peers[peerId], let inputPeer = apiInputPeer(peer) {
                missingPeers[peerId] = inputPeer
            } else {
                hadError = true
                Logger.shared.log("State", "can't fetch chat info for peer \(peerId): can't create inputPeer")
            }
        }
    }
    
    if missingPeers.isEmpty {
        return .single((state, hadError))
    } else {
        Logger.shared.log("State", "will fetch chat info for \(missingPeers.count) peers")
        let signal = network.request(Api.functions.messages.getPeerDialogs(peers: missingPeers.values.map(Api.InputDialogPeer.inputDialogPeer(peer:))))
        |> map(Optional.init)
        
        return signal
        |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
            return .single(nil)
        }
        |> map { result -> (AccountMutableState, Bool) in
            guard let result = result else {
                return (state, hadError)
            }
            
            var channelStates: [PeerId: ChannelState] = [:]
            
            var updatedState = state
            switch result {
                case let .peerDialogs(dialogs, messages, chats, users, _):
                    updatedState.mergeChats(chats)
                    updatedState.mergeUsers(users)
                    
                    var topMessageIds = Set<MessageId>()
                    
                    for dialog in dialogs {
                        switch dialog {
                            case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, notifySettings, pts, _, folderId):
                                let peerId = peer.peerId
                                
                                updatedState.setNeedsHoleFromPreviousState(peerId: peerId, namespace: Namespaces.Message.Cloud, validateChannelPts: pts)
                                
                                if topMessage != 0 {
                                    topMessageIds.insert(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: topMessage))
                                }
                                
                                var isExcludedFromChatList = false
                                for chat in chats {
                                    if chat.peerId == peerId {
                                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                            if let group = groupOrChannel as? TelegramGroup {
                                                if group.flags.contains(.deactivated) {
                                                    isExcludedFromChatList = true
                                                } else {
                                                    switch group.membership {
                                                        case .Member:
                                                            break
                                                        default:
                                                            isExcludedFromChatList = true
                                                    }
                                                }
                                            } else if let channel = groupOrChannel as? TelegramChannel {
                                                switch channel.participationStatus {
                                                    case .member:
                                                        break
                                                    default:
                                                        isExcludedFromChatList = true
                                                }
                                            }
                                        }
                                        break
                                    }
                                }
                                
                                if !isExcludedFromChatList {
                                    updatedState.updatePeerChatInclusion(peerId: peerId, groupId: PeerGroupId(rawValue: folderId ?? 0), changedGroup: false)
                                }
                                
                                let notificationSettings = TelegramPeerNotificationSettings(apiSettings: notifySettings)
                                updatedState.updateNotificationSettings(.peer(peer.peerId), notificationSettings: notificationSettings)
                                
                                updatedState.resetReadState(peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: nil)
                                updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                                updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenReaction, namespace: Namespaces.Message.Cloud, count: unreadReactionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                                updatedState.peerChatInfos[peer.peerId] = PeerChatInfo(notificationSettings: notificationSettings)
                                if let pts = pts {
                                    channelStates[peer.peerId] = ChannelState(pts: pts, invalidatedPts: pts, synchronizedUntilMessageId: nil)
                                }
                            case .dialogFolder:
                                assertionFailure()
                                break
                        }
                    }
                    
                    var storeMessages: [StoreMessage] = []
                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message) {
                            var updatedStoreMessage = storeMessage
                            if case let .Id(id) = storeMessage.id {
                                if let channelState = channelStates[id.peerId] {
                                    var updatedAttributes = storeMessage.attributes
                                    updatedAttributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                    updatedStoreMessage = updatedStoreMessage.withUpdatedAttributes(updatedAttributes)
                                }
                            }
                            storeMessages.append(updatedStoreMessage)
                        }
                    }
                
                    for message in storeMessages {
                        if case let .Id(id) = message.id {
                            updatedState.addMessages([message], location: topMessageIds.contains(id) ? .UpperHistoryBlock : .Random)
                        }
                    }
            }
            return (updatedState, hadError)
        }
    }
}

func pollChannelOnce(postbox: Postbox, network: Network, peerId: PeerId, stateManager: AccountStateManager, delayCompletion: Bool) -> Signal<Int32, NoError> {
    return postbox.transaction { transaction -> Signal<Int32, NoError> in
        guard let accountState = (transaction.getState() as? AuthorizedAccountState)?.state, let peer = transaction.getPeer(peerId) else {
            if delayCompletion {
                return .complete()
                |> delay(30.0, queue: Queue.concurrentDefaultQueue())
            } else {
                return .complete()
            }
        }

        var channelStates: [PeerId: AccountStateChannelState] = [:]
        if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
            channelStates[peerId] = AccountStateChannelState(pts: channelState.pts)
        }
        let initialPeers: [PeerId: Peer] = [peerId: peer]
        var peerChatInfos: [PeerId: PeerChatInfo] = [:]
        let inclusion = transaction.getPeerChatListInclusion(peerId)
        var hasValidInclusion = false
        switch inclusion {
            case .ifHasMessagesOrOneOf:
                hasValidInclusion = true
            case .notIncluded:
                hasValidInclusion = false
        }
        if hasValidInclusion {
            if let notificationSettings = transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings {
                peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
            }
        }
        let initialState = AccountMutableState(initialState: AccountInitialState(state: accountState, peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: channelStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: [:], cloudReadStates: [:], channelsToPollExplicitely: Set()), initialPeers: initialPeers, initialReferencedMessageIds: Set(), initialStoredMessages: Set(), initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:])
        return pollChannel(network: network, peer: peer, state: initialState)
        |> mapToSignal { (finalState, _, timeout) -> Signal<Int32, NoError> in
            return resolveAssociatedMessages(network: network, state: finalState)
            |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                return resolveMissingPeerChatInfos(network: network, state: resultingState)
                |> map { resultingState, _ -> AccountFinalState in
                    return AccountFinalState(state: resultingState, shouldPoll: false, incomplete: false, missingUpdatesFromChannels: Set(), discard: false)
                }
            }
            |> mapToSignal { finalState -> Signal<Int32, NoError> in
                return stateManager.addReplayAsynchronouslyBuiltFinalState(finalState)
                |> mapToSignal { _ -> Signal<Int32, NoError> in
                    if delayCompletion {
                        return .single(timeout ?? 30)
                        |> then(
                            .complete()
                            |> delay(Double(timeout ?? 30), queue: Queue.concurrentDefaultQueue())
                        )
                    } else {
                        return .single(timeout ?? 30)
                    }
                }
            }
        }
    }
    |> switchToLatest
}

public func standalonePollChannelOnce(postbox: Postbox, network: Network, peerId: PeerId, stateManager: AccountStateManager) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        guard let accountState = (transaction.getState() as? AuthorizedAccountState)?.state, let peer = transaction.getPeer(peerId) else {
            return .complete()
        }

        var channelStates: [PeerId: AccountStateChannelState] = [:]
        if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
            channelStates[peerId] = AccountStateChannelState(pts: channelState.pts)
        }
        let initialPeers: [PeerId: Peer] = [peerId: peer]
        var peerChatInfos: [PeerId: PeerChatInfo] = [:]
        let inclusion = transaction.getPeerChatListInclusion(peerId)
        var hasValidInclusion = false
        switch inclusion {
        case .ifHasMessagesOrOneOf:
            hasValidInclusion = true
        case .notIncluded:
            hasValidInclusion = false
        }
        if hasValidInclusion {
            if let notificationSettings = transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings {
                peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
            }
        }
        let initialState = AccountMutableState(initialState: AccountInitialState(state: accountState, peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: channelStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: [:], cloudReadStates: [:], channelsToPollExplicitely: Set()), initialPeers: initialPeers, initialReferencedMessageIds: Set(), initialStoredMessages: Set(), initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:])
        return pollChannel(network: network, peer: peer, state: initialState)
        |> mapToSignal { (finalState, _, timeout) -> Signal<Never, NoError> in
            return resolveAssociatedMessages(network: network, state: finalState)
            |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                return resolveMissingPeerChatInfos(network: network, state: resultingState)
                |> map { resultingState, _ -> AccountFinalState in
                    return AccountFinalState(state: resultingState, shouldPoll: false, incomplete: false, missingUpdatesFromChannels: Set(), discard: false)
                }
            }
            |> mapToSignal { finalState -> Signal<Never, NoError> in
                return stateManager.standaloneReplayAsynchronouslyBuiltFinalState(finalState: finalState)
            }
        }
    }
    |> switchToLatest
}

func keepPollingChannel(postbox: Postbox, network: Network, peerId: PeerId, stateManager: AccountStateManager) -> Signal<Int32, NoError> {
    return pollChannelOnce(postbox: postbox, network: network, peerId: peerId, stateManager: stateManager, delayCompletion: true)
    |> restart
    |> delay(1.0, queue: .concurrentDefaultQueue())
}

private func resetChannels(network: Network, peers: [Peer], state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    var inputPeers: [Api.InputDialogPeer] = []
    for peer in peers {
        if let inputPeer = apiInputPeer(peer) {
            inputPeers.append(.inputDialogPeer(peer: inputPeer))
        }
    }
    return network.request(Api.functions.messages.getPeerDialogs(peers: inputPeers))
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.messages.PeerDialogs?, NoError> in
        if error.errorDescription == "CHANNEL_PRIVATE" && inputPeers.count == 1 {
            return .single(nil)
        } else {
            return .single(nil)
        }
    }
    |> mapToSignal { result -> Signal<AccountMutableState, NoError> in
        var updatedState = state
        
        var dialogsChats: [Api.Chat] = []
        var dialogsUsers: [Api.User] = []
        
        var storeMessages: [StoreMessage] = []
        var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
        var mentionTagSummaries: [PeerId: (tag: MessageTags, summary: MessageHistoryTagNamespaceSummary)] = [:]
        var channelStates: [PeerId: AccountStateChannelState] = [:]
        var invalidateChannelStates: [PeerId: Int32] = [:]
        var channelSynchronizedUntilMessage: [PeerId: MessageId.Id] = [:]
        var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
        
        if let result = result {
            switch result {
                case let .peerDialogs(dialogs, messages, chats, users, _):
                    dialogsChats.append(contentsOf: chats)
                    dialogsUsers.append(contentsOf: users)
                    
                    loop: for dialog in dialogs {
                        let apiPeer: Api.Peer
                        let apiReadInboxMaxId: Int32
                        let apiReadOutboxMaxId: Int32
                        let apiTopMessage: Int32
                        let apiUnreadCount: Int32
                        let apiUnreadMentionsCount: Int32
                        let apiUnreadReactionsCount: Int32
                        var apiChannelPts: Int32?
                        let apiNotificationSettings: Api.PeerNotifySettings
                        let apiMarkedUnread: Bool
                        let groupId: PeerGroupId
                        switch dialog {
                            case let .dialog(flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, peerNotificationSettings, pts, _, folderId):
                                apiPeer = peer
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                                apiMarkedUnread = (flags & (1 << 3)) != 0
                                apiUnreadMentionsCount = unreadMentionsCount
                                apiUnreadReactionsCount = unreadReactionsCount
                                apiNotificationSettings = peerNotificationSettings
                                apiChannelPts = pts
                                groupId = PeerGroupId(rawValue: folderId ?? 0)
                            case .dialogFolder:
                                assertionFailure()
                                continue loop
                        }
                        
                        let peerId: PeerId = apiPeer.peerId
                        
                        if readStates[peerId] == nil {
                            readStates[peerId] = [:]
                        }
                        readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount, markedUnread: apiMarkedUnread)
                        
                        if apiTopMessage != 0 {
                            mentionTagSummaries[peerId] = (MessageTags.unseenPersonalMessage, MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage)))
                            mentionTagSummaries[peerId] = (MessageTags.unseenReaction, MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadReactionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage)))
                        }
                        
                        if let apiChannelPts = apiChannelPts {
                            channelStates[peerId] = AccountStateChannelState(pts: apiChannelPts)
                            invalidateChannelStates[peerId] = apiChannelPts
                        }
                        
                        notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                        
                        updatedState.updatePeerChatInclusion(peerId: peerId, groupId: groupId, changedGroup: false)
                    }
                    
                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message) {
                            var updatedStoreMessage = storeMessage
                            if case let .Id(id) = storeMessage.id {
                                if let channelState = channelStates[id.peerId] {
                                    var updatedAttributes = storeMessage.attributes
                                    updatedAttributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                    updatedStoreMessage = updatedStoreMessage.withUpdatedAttributes(updatedAttributes)
                                }
                            }
                            storeMessages.append(updatedStoreMessage)
                        }
                    }
            }
        }
        
        updatedState.mergeChats(dialogsChats)
        updatedState.mergeUsers(dialogsUsers)
        
        for message in storeMessages {
            if case let .Id(id) = message.id, id.namespace == Namespaces.Message.Cloud {
                var channelPts: Int32?
                if let state = channelStates[id.peerId] {
                    channelPts = state.pts
                }
                updatedState.setNeedsHoleFromPreviousState(peerId: id.peerId, namespace: id.namespace, validateChannelPts: channelPts)
                channelSynchronizedUntilMessage[id.peerId] = id.id
            }
        }
        
        updatedState.addMessages(storeMessages, location: .UpperHistoryBlock)
        
        for (peerId, peerReadStates) in readStates {
            for (namespace, state) in peerReadStates {
                switch state {
                    case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread):
                        updatedState.resetReadState(peerId, namespace: namespace, maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnread)
                    default:
                        assertionFailure()
                        break
                }
            }
        }
        
        for (peerId, tagSummary) in mentionTagSummaries {
            updatedState.resetMessageTagSummary(peerId, tag: tagSummary.tag, namespace: Namespaces.Message.Cloud, count: tagSummary.summary.count, range: tagSummary.summary.range)
        }
        
        for (peerId, channelState) in channelStates {
            updatedState.updateChannelState(peerId, pts: channelState.pts)
        }
        for (peerId, pts) in invalidateChannelStates {
            updatedState.updateChannelInvalidationPts(peerId, invalidationPts: pts)
        }
        for (peerId, id) in channelSynchronizedUntilMessage {
            updatedState.updateChannelSynchronizedUntilMessage(peerId, id: id)
        }
        
        for (peerId, settings) in notificationSettings {
            updatedState.updateNotificationSettings(.peer(peerId), notificationSettings: settings)
        }
        
        // TODO: delete messages later than top
        
        return resolveAssociatedMessages(network: network, state: updatedState)
        |> mapToSignal { resultingState -> Signal<AccountMutableState, NoError> in
            return .single(resultingState)
        }
    }
}

private func pollChannel(network: Network, peer: Peer, state: AccountMutableState) -> Signal<(AccountMutableState, Bool, Int32?), NoError> {
    if let inputChannel = apiInputChannel(peer) {
        let limit: Int32
        limit = 100
        
        let pollPts: Int32
        if let channelState = state.channelStates[peer.id] {
            pollPts = channelState.pts
        } else {
            pollPts = 1
        }
        return (network.request(Api.functions.updates.getChannelDifference(flags: 0, channel: inputChannel, filter: .channelMessagesFilterEmpty, pts: max(pollPts, 1), limit: limit))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.updates.ChannelDifference?, MTRpcError> in
            switch error.errorDescription {
            case "CHANNEL_PRIVATE", "CHANNEL_INVALID":
                return .single(nil)
            default:
                return .fail(error)
            }
        })
        |> retryRequest
        |> map { difference -> (AccountMutableState, Bool, Int32?) in
            var updatedState = state
            var apiTimeout: Int32?
            if let difference = difference {
                switch difference {
                    case let .channelDifference(_, pts, timeout, newMessages, otherUpdates, chats, users):
                        apiTimeout = timeout
                        let channelPts: Int32
                        if let _ = updatedState.channelStates[peer.id] {
                            channelPts = pts
                        } else {
                            channelPts = pts
                        }
                        updatedState.updateChannelState(peer.id, pts: channelPts)
                        
                        updatedState.mergeChats(chats)
                        updatedState.mergeUsers(users)
                        
                        for apiMessage in newMessages {
                            if var message = StoreMessage(apiMessage: apiMessage) {
                                var attributes = message.attributes
                                attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                                message = message.withUpdatedAttributes(attributes)
                                
                                if let preCachedResources = apiMessage.preCachedResources {
                                    for (resource, data) in preCachedResources {
                                        updatedState.addPreCachedResource(resource, data: data)
                                    }
                                }
                                updatedState.addMessages([message], location: .UpperHistoryBlock)
                                if case let .Id(id) = message.id {
                                    updatedState.updateChannelSynchronizedUntilMessage(id.peerId, id: id.id)
                                }
                            }
                        }
                        for update in otherUpdates {
                            switch update {
                                case let .updateDeleteChannelMessages(_, messages, _, _):
                                    let peerId = peer.id
                                    updatedState.deleteMessages(messages.map({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }))
                                case let .updateEditChannelMessage(apiMessage, _, _):
                                    if let message = StoreMessage(apiMessage: apiMessage), case let .Id(messageId) = message.id, messageId.peerId == peer.id {
                                        if let preCachedResources = apiMessage.preCachedResources {
                                            for (resource, data) in preCachedResources {
                                                updatedState.addPreCachedResource(resource, data: data)
                                            }
                                        }
                                        var attributes = message.attributes
                                        attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                                        updatedState.editMessage(messageId, message: message.withUpdatedAttributes(attributes))
                                    } else {
                                        Logger.shared.log("State", "Invalid updateEditChannelMessage")
                                    }
                                case let .updatePinnedChannelMessages(flags, channelId, messages, _, _):
                                    let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                                    updatedState.updateMessagesPinned(ids: messages.map { id in
                                        MessageId(peerId: channelPeerId, namespace: Namespaces.Message.Cloud, id: id)
                                    }, pinned: (flags & (1 << 0)) != 0)
                                case let .updateChannelReadMessagesContents(_, messages):
                                    updatedState.addReadMessagesContents((peer.id, messages))
                                case let .updateChannelMessageViews(_, id, views):
                                    updatedState.addUpdateMessageImpressionCount(id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id), count: views)
                                /*case let .updateChannelMessageForwards(_, id, views):
                                    updatedState.addUpdateMessageForwardsCount(id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id), count: views)*/
                                case let .updateChannelWebPage(_, apiWebpage, _, _):
                                    switch apiWebpage {
                                        case let .webPageEmpty(id):
                                            updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
                                        default:
                                            if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage, url: nil) {
                                                updatedState.updateMedia(webpage.webpageId, media: webpage)
                                            }
                                    }
                                case let .updateChannelAvailableMessages(_, minId):
                                    let messageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: minId)
                                    updatedState.updateMinAvailableMessage(messageId)
                                    updatedState.updateCachedPeerData(peer.id, { current in
                                        let previous: CachedChannelData
                                        if let current = current as? CachedChannelData {
                                            previous = current
                                        } else {
                                            previous = CachedChannelData()
                                        }
                                        return previous.withUpdatedMinAvailableMessageId(messageId)
                                    })
                                default:
                                    break
                            }
                        }
                    case let .channelDifferenceEmpty(_, pts, timeout):
                        apiTimeout = timeout
                        
                        let channelPts: Int32
                        if let _ = updatedState.channelStates[peer.id] {
                            channelPts = pts
                        } else {
                            channelPts = pts
                        }
                        updatedState.updateChannelState(peer.id, pts: channelPts)
                    case let .channelDifferenceTooLong(_, timeout, dialog, messages, chats, users):
                        apiTimeout = timeout
                        
                    var parameters: (peer: Api.Peer, pts: Int32, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32)?
                        
                        switch dialog {
                            case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, _, pts, _, _):
                                if let pts = pts {
                                    parameters = (peer, pts, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount)
                                }
                            case .dialogFolder:
                                break
                        }
                        
                        if let (peer, pts, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount) = parameters {
                            updatedState.updateChannelState(peer.peerId, pts: pts)
                            updatedState.updateChannelInvalidationPts(peer.peerId, invalidationPts: pts)
                            
                            updatedState.mergeChats(chats)
                            updatedState.mergeUsers(users)
                            
                            updatedState.setNeedsHoleFromPreviousState(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, validateChannelPts: pts)
                        
                            for apiMessage in messages {
                                if var message = StoreMessage(apiMessage: apiMessage) {
                                    var attributes = message.attributes
                                    attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                                    message = message.withUpdatedAttributes(attributes)
                                    
                                    if let preCachedResources = apiMessage.preCachedResources {
                                        for (resource, data) in preCachedResources {
                                            updatedState.addPreCachedResource(resource, data: data)
                                        }
                                    }
                                    
                                    let location: AddMessagesLocation
                                    if case let .Id(id) = message.id, id.id == topMessage {
                                        location = .UpperHistoryBlock
                                        updatedState.updateChannelSynchronizedUntilMessage(id.peerId, id: id.id)
                                    } else {
                                        location = .Random
                                    }
                                    updatedState.addMessages([message], location: location)
                                }
                            }
                        
                            updatedState.resetReadState(peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: nil)
                        
                            updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                            updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenReaction, namespace: Namespaces.Message.Cloud, count: unreadReactionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                        } else {
                            assertionFailure()
                        }
                }
            }
            return (updatedState, difference != nil, apiTimeout)
        }
    } else {
        Logger.shared.log("State", "can't poll channel \(peer.id): can't create inputChannel")
        return single((state, true, nil), NoError.self)
    }
}

private func verifyTransaction(_ transaction: Transaction, finalState: AccountMutableState) -> Bool {
    var hadUpdateState = false
    var channelsWithUpdatedStates = Set<PeerId>()
    
    var missingPeerIds: [PeerId] = []
    for peerId in finalState.initialState.peerIds {
        if finalState.peers[peerId] == nil {
            missingPeerIds.append(peerId)
        }
    }
    
    if !missingPeerIds.isEmpty {
        Logger.shared.log("State", "missing peers \(missingPeerIds)")
        return false
    }
    
    for operation in finalState.operations {
        switch operation {
            case let .UpdateChannelState(peerId, _):
                channelsWithUpdatedStates.insert(peerId)
            case .UpdateState:
                hadUpdateState = true
            default:
                break
        }
    }
    
    var failed = false
    
    if hadUpdateState {
        var previousStateMatches = false
        let currentState = (transaction.getState() as? AuthorizedAccountState)?.state
        let previousState = finalState.initialState.state
        if let currentState = currentState {
            previousStateMatches = previousState == currentState
        } else {
            previousStateMatches = false
        }
        
        if !previousStateMatches {
            Logger.shared.log("State", ".UpdateState previous state \(previousState) doesn't match current state \(String(describing: currentState))")
            failed = true
        }
    }
    
    for peerId in channelsWithUpdatedStates {
        let currentState = transaction.getPeerChatState(peerId)
        var previousStateMatches = false
        let previousState = finalState.initialState.channelStates[peerId]
        if let currentState = currentState as? ChannelState, let previousState = previousState {
            if currentState.pts == previousState.pts {
                previousStateMatches = true
            }
        } else if currentState == nil && previousState == nil {
            previousStateMatches = true
        }
        if !previousStateMatches {
            Logger.shared.log("State", ".UpdateChannelState for \(peerId), previous state \(String(describing: previousState)) doesn't match current state \(String(describing: currentState))")
            failed = true
        }
    }
    
    return !failed
}

private final class OptimizeAddMessagesState {
    var messages: [StoreMessage]
    var location: AddMessagesLocation
    
    init(messages: [StoreMessage], location: AddMessagesLocation) {
        self.messages = messages
        self.location = location
    }
}

private func optimizedOperations(_ operations: [AccountStateMutationOperation]) -> [AccountStateMutationOperation] {
    var result: [AccountStateMutationOperation] = []
    
    var updatedState: AuthorizedAccountState.State?
    var updatedChannelStates: [PeerId: AccountStateChannelState] = [:]
    var invalidateChannelPts: [PeerId: Int32] = [:]
    var updateChannelSynchronizedUntilMessage: [PeerId: MessageId.Id] = [:]
    
    var currentAddMessages: OptimizeAddMessagesState?
    var currentAddScheduledMessages: OptimizeAddMessagesState?
    for operation in operations {
        switch operation {
        case .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpdateMessagePoll, .UpdateMessageReactions, .UpdateMedia, .MergeApiChats, .MergeApiUsers, .MergePeerPresences, .UpdatePeer, .ReadInbox, .ReadOutbox, .ReadGroupFeedInbox, .ResetReadState, .ResetIncomingReadState, .UpdatePeerChatUnreadMark, .ResetMessageTagSummary, .UpdateNotificationSettings, .UpdateGlobalNotificationSettings, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity, .UpdateCachedPeerData, .UpdatePinnedItemIds, .ReadMessageContents, .UpdateMessageImpressionCount, .UpdateMessageForwardsCount, .UpdateInstalledStickerPacks, .UpdateRecentGifs, .UpdateChatInputState, .UpdateCall, .AddCallSignalingData, .UpdateLangPack, .UpdateMinAvailableMessage, .UpdateIsContact, .UpdatePeerChatInclusion, .UpdatePeersNearby, .UpdateTheme, .SyncChatListFilters, .UpdateChatListFilter, .UpdateChatListFilterOrder, .UpdateReadThread, .UpdateMessagesPinned, .UpdateGroupCallParticipants, .UpdateGroupCall, .UpdateAutoremoveTimeout, .UpdateAttachMenuBots, .UpdateAudioTranscription, .UpdateConfig:
                if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
                    result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
                }
                if let currentAddScheduledMessages = currentAddScheduledMessages, !currentAddScheduledMessages.messages.isEmpty {
                    result.append(.AddScheduledMessages(currentAddScheduledMessages.messages))
                }
                currentAddMessages = nil
                result.append(operation)
            case let .UpdateState(state):
                updatedState = state
            case let .UpdateChannelState(peerId, pts):
                updatedChannelStates[peerId] = AccountStateChannelState(pts: pts)
            case let .UpdateChannelInvalidationPts(peerId, pts):
                invalidateChannelPts[peerId] = pts
            case let .UpdateChannelSynchronizedUntilMessage(peerId, id):
                updateChannelSynchronizedUntilMessage[peerId] = id
            case let .AddMessages(messages, location):
                if let currentAddMessages = currentAddMessages, currentAddMessages.location == location {
                    currentAddMessages.messages.append(contentsOf: messages)
                } else {
                    if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
                        result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
                    }
                    currentAddMessages = OptimizeAddMessagesState(messages: messages, location: location)
                }
            case let .AddScheduledMessages(messages):
                if let currentAddScheduledMessages = currentAddScheduledMessages {
                    currentAddScheduledMessages.messages.append(contentsOf: messages)
                } else {
                    currentAddScheduledMessages = OptimizeAddMessagesState(messages: messages, location: .Random)
                }
        }
    }
    if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
        result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
    }
    
    if let currentAddScheduledMessages = currentAddScheduledMessages, !currentAddScheduledMessages.messages.isEmpty {
        result.append(.AddScheduledMessages(currentAddScheduledMessages.messages))
    }
    
    if let updatedState = updatedState {
        result.append(.UpdateState(updatedState))
    }
    
    for (peerId, state) in updatedChannelStates {
        result.append(.UpdateChannelState(peerId, state.pts))
    }
    
    for (peerId, pts) in invalidateChannelPts {
        result.append(.UpdateChannelInvalidationPts(peerId, pts))
    }
    
    for (peerId, id) in updateChannelSynchronizedUntilMessage {
        result.append(.UpdateChannelSynchronizedUntilMessage(peerId, id))
    }
    
    return result
}

private func recordPeerActivityTimestamp(peerId: PeerId, timestamp: Int32, into timestamps: inout [PeerId: Int32]) {
    if let current = timestamps[peerId] {
        if current < timestamp {
            timestamps[peerId] = timestamp
        }
    } else {
        timestamps[peerId] = timestamp
    }
}

func replayFinalState(
    accountManager: AccountManager<TelegramAccountManagerTypes>,
    postbox: Postbox,
    accountPeerId: PeerId,
    mediaBox: MediaBox,
    encryptionProvider: EncryptionProvider,
    transaction: Transaction,
    auxiliaryMethods: AccountAuxiliaryMethods,
    finalState: AccountFinalState,
    removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId],
    ignoreDate: Bool
) -> AccountReplayedFinalState? {
    let verified = verifyTransaction(transaction, finalState: finalState.state)
    if !verified {
        Logger.shared.log("State", "failed to verify final state")
        return nil
    }
    
    var peerIdsWithAddedSecretMessages = Set<PeerId>()
    
    var updatedTypingActivities: [PeerActivitySpace: [PeerId: PeerInputActivity?]] = [:]
    var updatedIncomingThreadReadStates: [MessageId: MessageId.Id] = [:]
    var updatedOutgoingThreadReadStates: [MessageId: MessageId.Id] = [:]
    var updatedSecretChatTypingActivities = Set<PeerId>()
    var updatedWebpages: [MediaId: TelegramMediaWebpage] = [:]
    var updatedCalls: [Api.PhoneCall] = []
    var addedCallSignalingData: [(Int64, Data)] = []
    var updatedGroupCallParticipants: [(Int64, GroupCallParticipantsContext.Update)] = []
    var updatedPeersNearby: [PeerNearby]?
    var isContactUpdates: [(PeerId, Bool)] = []
    var stickerPackOperations: [AccountStateUpdateStickerPacksOperation] = []
    var recentlyUsedStickers: [MediaId: (MessageIndex, TelegramMediaFile)] = [:]
    var slowModeLastMessageTimeouts:[PeerId : Int32] = [:]
    var recentlyUsedGifs: [MediaId: (MessageIndex, TelegramMediaFile)] = [:]
    var syncRecentGifs = false
    var langPackDifferences: [String: [Api.LangPackDifference]] = [:]
    var pollLangPacks = Set<String>()
    var updatedThemes: [Int64: TelegramTheme] = [:]
    var delayNotificatonsUntil: Int32?
    var peerActivityTimestamps: [PeerId: Int32] = [:]
    var syncChatListFilters = false
    var deletedMessageIds: [DeletedMessageId] = []
    var syncAttachMenuBots = false
    var updateConfig = false
    
    var holesFromPreviousStateMessageIds: [MessageId] = []
    var clearHolesFromPreviousStateForChannelMessagesWithPts: [PeerIdAndMessageNamespace: Int32] = [:]
    
    for (peerId, namespaces) in finalState.state.namespacesWithHolesFromPreviousState {
        for (namespace, namespaceState) in namespaces {
            if let pts = namespaceState.validateChannelPts {
                clearHolesFromPreviousStateForChannelMessagesWithPts[PeerIdAndMessageNamespace(peerId: peerId, namespace: namespace)] = pts
            }
            
            var topId: Int32?
            if namespace == Namespaces.Message.Cloud, let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
                if let synchronizedUntilMessageId = channelState.synchronizedUntilMessageId {
                    topId = synchronizedUntilMessageId
                }
            }
            if topId == nil {
                topId = transaction.getTopPeerMessageId(peerId: peerId, namespace: namespace)?.id
            }
            
            if let id = topId {
                holesFromPreviousStateMessageIds.append(MessageId(peerId: peerId, namespace: namespace, id: id + 1))
            } else {
                holesFromPreviousStateMessageIds.append(MessageId(peerId: peerId, namespace: namespace, id: 1))
            }
        }
    }
    
    var wasOperationScheduledMessageIds: [MessageId] = []
    
    var addedOperationIncomingMessageIds: [MessageId] = []
    for operation in finalState.state.operations {
        switch operation {
            case let .AddMessages(messages, location):
                if case .UpperHistoryBlock = location {
                    for message in messages {
                        if case let .Id(id) = message.id {
                            if message.flags.contains(.Incoming) {
                                addedOperationIncomingMessageIds.append(id)
                                if let authorId = message.authorId {
                                    recordPeerActivityTimestamp(peerId: authorId, timestamp: message.timestamp, into: &peerActivityTimestamps)
                                }
                            }
                            if message.flags.contains(.WasScheduled) {
                                wasOperationScheduledMessageIds.append(id)
                            }
                        }
                    }
                }
            default:
                break
        }
    }
    var wasScheduledMessageIds:[MessageId] = []
    var addedIncomingMessageIds: [MessageId] = []
    var addedReactionEvents: [(reactionAuthor: Peer, reaction: String, message: Message, timestamp: Int32)] = []
    
    if !wasOperationScheduledMessageIds.isEmpty {
        let existingIds = transaction.filterStoredMessageIds(Set(wasOperationScheduledMessageIds))
        for id in wasOperationScheduledMessageIds {
            if !existingIds.contains(id) {
                wasScheduledMessageIds.append(id)
            }
        }
    }
    if !addedOperationIncomingMessageIds.isEmpty {
        let existingIds = transaction.filterStoredMessageIds(Set(addedOperationIncomingMessageIds))
        for id in addedOperationIncomingMessageIds {
            if !existingIds.contains(id) {
                addedIncomingMessageIds.append(id)
            }
        }
    }
    
    var invalidateGroupStats = Set<PeerGroupId>()
    
    struct PeerIdAndMessageNamespace: Hashable {
        let peerId: PeerId
        let namespace: MessageId.Namespace
    }
    
    var topUpperHistoryBlockMessages: [PeerIdAndMessageNamespace: MessageId.Id] = [:]
    
    final class MessageThreadStatsRecord {
        var removedCount: Int = 0
        var peers: [ReplyThreadUserMessage] = []
    }
    var messageThreadStatsDifferences: [MessageId: MessageThreadStatsRecord] = [:]
    func addMessageThreadStatsDifference(threadMessageId: MessageId, remove: Int, addedMessagePeer: PeerId?, addedMessageId: MessageId?, isOutgoing: Bool) {
        if let value = messageThreadStatsDifferences[threadMessageId] {
            value.removedCount += remove
            if let addedMessagePeer = addedMessagePeer, let addedMessageId = addedMessageId {
                value.peers.append(ReplyThreadUserMessage(id: addedMessagePeer, messageId: addedMessageId, isOutgoing: isOutgoing))
            }
        } else {
            let value = MessageThreadStatsRecord()
            messageThreadStatsDifferences[threadMessageId] = value
            value.removedCount = remove
            if let addedMessagePeer = addedMessagePeer, let addedMessageId = addedMessageId {
                value.peers.append(ReplyThreadUserMessage(id: addedMessagePeer, messageId: addedMessageId, isOutgoing: isOutgoing))
            }
        }
    }
    
    for operation in optimizedOperations(finalState.state.operations) {
        switch operation {
            case let .AddMessages(messages, location):
                if case .UpperHistoryBlock = location {
                    for message in messages {
                        if case let .Id(id) = message.id {
                            if let threadId = message.threadId {
                                let messageThreadId = makeThreadIdMessageId(peerId: message.id.peerId, threadId: threadId)
                                if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                                    if !transaction.messageExists(id: id) {
                                        addMessageThreadStatsDifference(threadMessageId: messageThreadId, remove: 0, addedMessagePeer: message.authorId, addedMessageId: id, isOutgoing: !message.flags.contains(.Incoming))
                                    }
                                }
                            }
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
                                        case let .setChatTheme(emoticon):
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
                                                    return cachedData.withUpdatedThemeEmoticon(!emoticon.isEmpty ? emoticon : nil)
                                                } else if let cachedData = current as? CachedGroupData {
                                                    return cachedData.withUpdatedThemeEmoticon(!emoticon.isEmpty ? emoticon : nil)
                                                } else if let cachedData = current as? CachedChannelData {
                                                    return cachedData.withUpdatedThemeEmoticon(!emoticon.isEmpty ? emoticon : nil)
                                                } else {
                                                    return current
                                                }
                                            })
                                        case .groupCreated, .channelMigratedFromGroup:
                                            let holesAtHistoryStart = transaction.getHole(containing: MessageId(peerId: chatPeerId, namespace: Namespaces.Message.Cloud, id: id.id - 1))
                                            for (space, _) in holesAtHistoryStart {
                                                transaction.removeHole(peerId: chatPeerId, namespace: Namespaces.Message.Cloud, space: space, range: 1 ... id.id)
                                            }
                                        default:
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
            case let .AddScheduledMessages(messages):
                for message in messages {
                    if case let .Id(id) = message.id, let _ = transaction.getMessage(id) {
                        transaction.updateMessage(id) { _ -> PostboxUpdateMessage in
                            return .update(message)
                        }
                    } else {
                        let _ = transaction.addMessages(messages, location: .Random)
                    }
                }
            case let .DeleteMessagesWithGlobalIds(ids):
                var resourceIds: [MediaResourceId] = []
                transaction.deleteMessagesWithGlobalIds(ids, forEachMedia: { media in
                    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                })
                if !resourceIds.isEmpty {
                    let _ = mediaBox.removeCachedResources(Set(resourceIds), force: true).start()
                }
                deletedMessageIds.append(contentsOf: ids.map { .global($0) })
            case let .DeleteMessages(ids):
                _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, manualAddMessageThreadStatsDifference: { id, add, remove in
                    addMessageThreadStatsDifference(threadMessageId: id, remove: remove, addedMessagePeer: nil, addedMessageId: nil, isOutgoing: false)
                })
                deletedMessageIds.append(contentsOf: ids.map { .messageId($0) })
            case let .UpdateMinAvailableMessage(id):
                if let message = transaction.getMessage(id) {
                    updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: id.peerId, minTimestamp: message.timestamp, forceRootGroupIfNotExists: false)
                }
                var resourceIds: [MediaResourceId] = []
                transaction.deleteMessagesInRange(peerId: id.peerId, namespace: id.namespace, minId: 1, maxId: id.id, forEachMedia: { media in
                    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                })
                if !resourceIds.isEmpty {
                    let _ = mediaBox.removeCachedResources(Set(resourceIds), force: true).start()
                }
            case let .UpdatePeerChatInclusion(peerId, groupId, changedGroup):
                let currentInclusion = transaction.getPeerChatListInclusion(peerId)
                var currentPinningIndex: UInt16?
                var currentMinTimestamp: Int32?
                switch currentInclusion {
                    case let .ifHasMessagesOrOneOf(currentGroupId, pinningIndex, minTimestamp):
                        if currentGroupId == groupId {
                            currentPinningIndex = pinningIndex
                        }
                        currentMinTimestamp = minTimestamp
                    default:
                        break
                }
                transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: currentPinningIndex, minTimestamp: currentMinTimestamp))
                if changedGroup {
                    invalidateGroupStats.insert(Namespaces.PeerGroup.archive)
                }
            case let .EditMessage(id, message):
                var generatedEvent: (reactionAuthor: Peer, reaction: String, message: Message, timestamp: Int32)?
                transaction.updateMessage(id, update: { previousMessage in
                    var updatedFlags = message.flags
                    var updatedLocalTags = message.localTags
                    if previousMessage.localTags.contains(.OutgoingLiveLocation) {
                        updatedLocalTags.insert(.OutgoingLiveLocation)
                    }
                    if previousMessage.flags.contains(.Incoming) {
                        updatedFlags.insert(.Incoming)
                    } else {
                        updatedFlags.remove(.Incoming)
                    }
                    
                    let peers: [PeerId:Peer] = previousMessage.peers.reduce([:], { current, value in
                        var current = current
                        current[value.0] = value.1
                        return current
                    })
                    
                    if let message = locallyRenderedMessage(message: message, peers: peers) {
                        generatedEvent = reactionGeneratedEvent(previousMessage.reactionsAttribute, message.reactionsAttribute, message: message, transaction: transaction)
                    }
                    return .update(message.withUpdatedLocalTags(updatedLocalTags).withUpdatedFlags(updatedFlags))
                })
                if let generatedEvent = generatedEvent {
                    addedReactionEvents.append(generatedEvent)
                }
            case let .UpdateMessagePoll(pollId, apiPoll, results):
                if let poll = transaction.getMedia(pollId) as? TelegramMediaPoll {
                    var updatedPoll = poll
                    let resultsMin: Bool
                    switch results {
                    case let .pollResults(flags, _, _, _, _, _):
                        resultsMin = (flags & (1 << 0)) != 0
                    }
                    if let apiPoll = apiPoll {
                        switch apiPoll {
                        case let .poll(id, flags, question, answers, closePeriod, _):
                            let publicity: TelegramMediaPollPublicity
                            if (flags & (1 << 1)) != 0 {
                                publicity = .public
                            } else {
                                publicity = .anonymous
                            }
                            let kind: TelegramMediaPollKind
                            if (flags & (1 << 3)) != 0 {
                                kind = .quiz
                            } else {
                                kind = .poll(multipleAnswers: (flags & (1 << 2)) != 0)
                            }
                            updatedPoll = TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: id), publicity: publicity, kind: kind, text: question, options: answers.map(TelegramMediaPollOption.init(apiOption:)), correctAnswers: nil, results: poll.results, isClosed: (flags & (1 << 0)) != 0, deadlineTimeout: closePeriod)
                        }
                    }
                    updatedPoll = updatedPoll.withUpdatedResults(TelegramMediaPollResults(apiResults: results), min: resultsMin)
                    updateMessageMedia(transaction: transaction, id: pollId, media: updatedPoll)
                }
            case let .UpdateMedia(id, media):
                if let media = media as? TelegramMediaWebpage {
                    updatedWebpages[id] = media
                }
                updateMessageMedia(transaction: transaction, id: id, media: media)
            case let .ReadInbox(messageId):
                transaction.applyIncomingReadMaxId(messageId)
            case let .ReadOutbox(messageId, timestamp):
                transaction.applyOutgoingReadMaxId(messageId)
                if messageId.peerId != accountPeerId, messageId.peerId.namespace == Namespaces.Peer.CloudUser, let timestamp = timestamp {
                    recordPeerActivityTimestamp(peerId: messageId.peerId, timestamp: timestamp, into: &peerActivityTimestamps)
                }
            case .ReadGroupFeedInbox:
                break
                //transaction.applyGroupFeedReadMaxIndex(groupId: groupId, index: index)
            case let .UpdateReadThread(threadMessageId, readMaxId, isIncoming, mainChannelMessage):
                if isIncoming {
                    if let currentId = updatedIncomingThreadReadStates[threadMessageId] {
                        if currentId < readMaxId {
                            updatedIncomingThreadReadStates[threadMessageId] = readMaxId
                        }
                    } else {
                        updatedIncomingThreadReadStates[threadMessageId] = readMaxId
                    }
                    if let mainChannelMessage = mainChannelMessage {
                        transaction.updateMessage(mainChannelMessage, update: { currentMessage in
                            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                            var attributes = currentMessage.attributes
                            loop: for j in 0 ..< attributes.count {
                                if let attribute = attributes[j] as? ReplyThreadMessageAttribute {
                                    if let maxReadMessageId = attribute.maxReadMessageId, maxReadMessageId > readMaxId {
                                        return .skip
                                    }
                                    attributes[j] = ReplyThreadMessageAttribute(count: attribute.count, latestUsers: attribute.latestUsers, commentsPeerId: attribute.commentsPeerId, maxMessageId: attribute.maxMessageId, maxReadMessageId: readMaxId)
                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                }
                            }
                            return .skip
                        })
                    }
                } else {
                    if let currentId = updatedOutgoingThreadReadStates[threadMessageId] {
                        if currentId < readMaxId {
                            updatedOutgoingThreadReadStates[threadMessageId] = readMaxId
                        }
                    } else {
                        updatedOutgoingThreadReadStates[threadMessageId] = readMaxId
                    }
                }
            case let .ResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count, markedUnread):
                var markedUnreadValue: Bool = false
                if let markedUnread = markedUnread {
                    markedUnreadValue = markedUnread
                } else if let states = transaction.getPeerReadStates(peerId) {
                    inner: for (stateNamespace, stateValue) in states {
                        if stateNamespace == namespace {
                            markedUnreadValue = stateValue.markedUnread
                            break inner
                        }
                    }
                }
                
                var ignore = false
                if let currentReadState = transaction.getCombinedPeerReadState(peerId) {
                    loop: for (currentNamespace, currentState) in currentReadState.states {
                        if namespace == currentNamespace {
                            switch currentState {
                            case let .idBased(localMaxIncomingReadId, _, _, localCount, localMarkedUnread):
                                if count != 0 || markedUnreadValue {
                                    if localMaxIncomingReadId > maxIncomingReadId {
                                        transaction.setNeedsIncomingReadStateSynchronization(peerId)
                                        
                                        transaction.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: localMaxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: localCount, markedUnread: localMarkedUnread)]])
                                        
                                        Logger.shared.log("State", "not applying incoming read state for \(peerId): \(localMaxIncomingReadId) > \(maxIncomingReadId)")
                                        ignore = true
                                    }
                                }
                            default:
                                break
                            }
                            break loop
                        }
                    }
                }
                if !ignore {
                    transaction.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnreadValue)]])
                }
            case let .ResetIncomingReadState(groupId, peerId, namespace, maxIncomingReadId, count, pts):
                var ptsMatchesState = false
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                    if let state = transaction.getState() as? AuthorizedAccountState {
                        if state.state?.pts == pts {
                            ptsMatchesState = true
                        }
                    }
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let state = transaction.getPeerChatState(peerId) as? ChannelState {
                        if state.pts == pts {
                            ptsMatchesState = true
                        }
                    }
                }
                
                if ptsMatchesState {
                    var updatedStates: [(MessageId.Namespace, PeerReadState)] = transaction.getPeerReadStates(peerId) ?? []
                    var foundState = false
                    for i in 0 ..< updatedStates.count {
                        if updatedStates[i].0 == namespace {
                            switch updatedStates[i].1 {
                                case let .idBased(currentMaxIncomingReadId, maxOutgoingReadId, maxKnownId, _, markedUnread):
                                    updatedStates[i].1 = .idBased(maxIncomingReadId: max(currentMaxIncomingReadId, maxIncomingReadId), maxOutgoingReadId: maxOutgoingReadId, maxKnownId: max(maxKnownId, maxIncomingReadId), count: count, markedUnread: markedUnread)
                                    foundState = true
                                case .indexBased:
                                    assertionFailure()
                                    break
                            }
                            break
                        }
                    }
                    if !foundState {
                        updatedStates.append((namespace, .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxIncomingReadId, maxKnownId: maxIncomingReadId, count: count, markedUnread: false)))
                        invalidateGroupStats.insert(groupId)
                    }
                    let stateDict = Dictionary(updatedStates, uniquingKeysWith: { lhs, _ in lhs })
                    transaction.resetIncomingReadStates([peerId: stateDict])
                } else {
                    transaction.applyIncomingReadMaxId(MessageId(peerId: peerId, namespace: namespace, id: maxIncomingReadId))
                    transaction.setNeedsIncomingReadStateSynchronization(peerId)
                    invalidateGroupStats.insert(groupId)
                }
            case let .UpdatePeerChatUnreadMark(peerId, namespace, value):
                transaction.applyMarkUnread(peerId: peerId, namespace: namespace, value: value, interactive: false)
            case let .ResetMessageTagSummary(peerId, tag, namespace, count, range):
                transaction.replaceMessageTagSummary(peerId: peerId, tagMask: tag, namespace: namespace, count: count, maxId: range.maxId)
                if count == 0 {
                    transaction.removeHole(peerId: peerId, namespace: namespace, space: .tag(tag), range: 1 ... (Int32.max - 1))
                    if tag == .unseenPersonalMessage {
                        let ids = transaction.getMessageIndicesWithTag(peerId: peerId, namespace: namespace, tag: tag).map({ $0.id })
                        Logger.shared.log("State", "will call markUnseenPersonalMessage for \(ids.count) messages")
                        for id in ids {
                            markUnseenPersonalMessage(transaction: transaction, id: id, addSynchronizeAction: false)
                        }
                    }
                }
            case let .UpdateState(innerState):
                let currentState = transaction.getState() as! AuthorizedAccountState
                var updatedInnerState = innerState
                if ignoreDate, let previousInnerState = currentState.state {
                    updatedInnerState = AuthorizedAccountState.State(pts: updatedInnerState.pts, qts: updatedInnerState.qts, date: previousInnerState.date, seq: updatedInnerState.seq)
                }
                transaction.setState(currentState.changedState(updatedInnerState))
                Logger.shared.log("State", "apply state \(updatedInnerState)")
            case let .UpdateChannelState(peerId, pts):
                var state = (transaction.getPeerChatState(peerId) as? ChannelState) ?? ChannelState(pts: pts, invalidatedPts: nil, synchronizedUntilMessageId: nil)
                state = state.withUpdatedPts(pts)
                transaction.setPeerChatState(peerId, state: state)
                Logger.shared.log("State", "apply channel state \(peerId): \(state)")
            case let .UpdateChannelInvalidationPts(peerId, pts):
                var state = (transaction.getPeerChatState(peerId) as? ChannelState) ?? ChannelState(pts: 0, invalidatedPts: pts, synchronizedUntilMessageId: nil)
                state = state.withUpdatedInvalidatedPts(pts)
                transaction.setPeerChatState(peerId, state: state)
                Logger.shared.log("State", "apply channel invalidation pts \(peerId): \(state)")
            case let .UpdateChannelSynchronizedUntilMessage(peerId, id):
                var state = (transaction.getPeerChatState(peerId) as? ChannelState) ?? ChannelState(pts: 0, invalidatedPts: nil, synchronizedUntilMessageId: id)
                state = state.withUpdatedSynchronizedUntilMessageId(id)
                transaction.setPeerChatState(peerId, state: state)
                Logger.shared.log("State", "apply channel synchronized until message \(peerId): \(state)")
            case let .UpdateNotificationSettings(subject, notificationSettings):
                switch subject {
                    case let .peer(peerId):
                        transaction.updateCurrentPeerNotificationSettings([peerId: notificationSettings])
                }
            case let .UpdateGlobalNotificationSettings(subject, notificationSettings):
                switch subject {
                    case .privateChats:
                        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            var updated: GlobalNotificationSettings
                            if let current = current?.get(GlobalNotificationSettings.self) {
                                updated = current
                            } else {
                                updated = GlobalNotificationSettings.defaultSettings
                            }
                            updated.remote.privateChats = notificationSettings
                            return PreferencesEntry(updated)
                        })
                        transaction.globalNotificationSettingsUpdated()
                    case .groups:
                        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            var updated: GlobalNotificationSettings
                            if let current = current?.get(GlobalNotificationSettings.self) {
                                updated = current
                            } else {
                                updated = GlobalNotificationSettings.defaultSettings
                            }
                            updated.remote.groupChats = notificationSettings
                            return PreferencesEntry(updated)
                        })
                        transaction.globalNotificationSettingsUpdated()
                    case .channels:
                        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            var updated: GlobalNotificationSettings
                            if let current = current?.get(GlobalNotificationSettings.self) {
                                updated = current
                            } else {
                                updated = GlobalNotificationSettings.defaultSettings
                            }
                            updated.remote.channels = notificationSettings
                            return PreferencesEntry(updated)
                        })
                        transaction.globalNotificationSettingsUpdated()
                }
            case let .MergeApiChats(chats):
                var peers: [Peer] = []
                for chat in chats {
                    if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                        peers.append(groupOrChannel)
                    }
                }
                updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                    return updated
                })
            case let .MergeApiUsers(users):
                var peers: [Peer] = []
                for user in users {
                    if let telegramUser = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                        peers.append(telegramUser)
                    }
                }
                updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                    return updated
                })
                updateContacts(transaction: transaction, apiUsers: users)
            case let .UpdatePeer(id, f):
                if let peer = f(transaction.getPeer(id)) {
                    updatePeers(transaction: transaction, peers: [peer], update: { _, updated in
                        return updated
                    })
                }
            case let .UpdateCachedPeerData(id, f):
                transaction.updatePeerCachedData(peerIds: Set([id]), update: { _, current in
                    return f(current)
                })
            case let .UpdateMessagesPinned(messageIds, pinned):
                for id in messageIds {
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(forwardInfo)
                        }
                        
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
                        
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                }
            case let .MergePeerPresences(statuses, explicit):
                var presences: [PeerId: PeerPresence] = [:]
                for (peerId, status) in statuses {
                    if peerId == accountPeerId {
                        if explicit {
                            switch status {
                                case let .userStatusOnline(timestamp):
                                    delayNotificatonsUntil = timestamp + 30
                                case let .userStatusOffline(timestamp):
                                    delayNotificatonsUntil = timestamp
                                default:
                                    break
                            }
                        }
                    } else {
                        let presence = TelegramUserPresence(apiStatus: status)
                        presences[peerId] = presence
                    }
                    
                }
                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: presences)
            case let .UpdateSecretChat(chat, _):
                updateSecretChat(encryptionProvider: encryptionProvider, accountPeerId: accountPeerId, transaction: transaction, mediaBox: mediaBox, chat: chat, requestData: nil)
            case let .AddSecretMessages(messages):
                for message in messages {
                    let peerId = message.peerId
                    transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingEncrypted, tagLocalIndex: .automatic, tagMergedIndex: .none, contents: SecretChatIncomingEncryptedOperation(message: message))
                    peerIdsWithAddedSecretMessages.insert(peerId)
                }
            case let .ReadSecretOutbox(peerId, maxTimestamp, actionTimestamp):
                applyOutgoingReadMaxIndex(transaction: transaction, index: MessageIndex.upperBound(peerId: peerId, timestamp: maxTimestamp, namespace: Namespaces.Message.Local), beginCountdownAt: actionTimestamp)
            case let .AddPeerInputActivity(chatPeerId, peerId, activity):
                if let peerId = peerId {
                    if updatedTypingActivities[chatPeerId] == nil {
                        updatedTypingActivities[chatPeerId] = [peerId: activity]
                    } else {
                        updatedTypingActivities[chatPeerId]![peerId] = activity
                    }
                } else if chatPeerId.peerId.namespace == Namespaces.Peer.SecretChat {
                    updatedSecretChatTypingActivities.insert(chatPeerId.peerId)
                }
            case let .UpdatePinnedItemIds(groupId, pinnedOperation):
                switch pinnedOperation {
                    case let .pin(itemId):
                        switch itemId {
                            case let .peer(peerId):
                                if transaction.getPeer(peerId) == nil || transaction.getPeerChatListInclusion(peerId) == .notIncluded {
                                    addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                                } else {
                                    var currentItemIds = transaction.getPinnedItemIds(groupId: groupId)
                                    if !currentItemIds.contains(.peer(peerId)) {
                                        currentItemIds.insert(.peer(peerId), at: 0)
                                        transaction.setPinnedItemIds(groupId: groupId, itemIds: currentItemIds)
                                    }
                                }
                        }
                    case let .unpin(itemId):
                        switch itemId {
                            case let .peer(peerId):
                                var currentItemIds = transaction.getPinnedItemIds(groupId: groupId)
                                if let index = currentItemIds.firstIndex(of: .peer(peerId)) {
                                    currentItemIds.remove(at: index)
                                    transaction.setPinnedItemIds(groupId: groupId, itemIds: currentItemIds)
                                } else {
                                    addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                                }
                        }
                    case let .reorder(itemIds):
                        let currentItemIds = transaction.getPinnedItemIds(groupId: groupId)
                        if Set(itemIds) == Set(currentItemIds) {
                            transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
                        } else {
                            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                        }
                    case .sync:
                        addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                }
            case let .ReadMessageContents(peerIdAndMessageIds):
                let (peerId, messageIds) = peerIdAndMessageIds

                if let peerId = peerId {
                    for id in messageIds {
                        markMessageContentAsConsumedRemotely(transaction: transaction, messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id))
                    }
                } else {
                    for messageId in transaction.messageIdsForGlobalIds(messageIds) {
                        markMessageContentAsConsumedRemotely(transaction: transaction, messageId: messageId)
                    }
                }
            case let .UpdateMessageImpressionCount(id, count):
                transaction.updateMessage(id, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    var attributes = currentMessage.attributes
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ViewCountMessageAttribute {
                            attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(count)))
                            break loop
                        }
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            case let .UpdateMessageForwardsCount(id, count):
                transaction.updateMessage(id, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    var attributes = currentMessage.attributes
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ForwardCountMessageAttribute {
                            attributes[j] = ForwardCountMessageAttribute(count: max(attribute.count, Int(count)))
                            break loop
                        }
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            case let .UpdateInstalledStickerPacks(operation):
                stickerPackOperations.append(operation)
            case .UpdateRecentGifs:
                syncRecentGifs = true
            case let .UpdateChatInputState(peerId, inputState):
                _internal_updateChatInputState(transaction: transaction, peerId: peerId, inputState: inputState)
            case let .UpdateCall(call):
                updatedCalls.append(call)
            case let .AddCallSignalingData(callId, data):
                addedCallSignalingData.append((callId, data))
            case let .UpdateGroupCallParticipants(callId, _, participants, version):
                updatedGroupCallParticipants.append((
                    callId,
                    .state(update: GroupCallParticipantsContext.Update.StateUpdate(participants: participants, version: version))
                ))
            case let .UpdateGroupCall(peerId, call):
                switch call {
                case .groupCall:
                    if let info = GroupCallInfo(call) {
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedChannelData {
                                return current.withUpdatedActiveCall(CachedChannelData.ActiveCall(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled, isStream: info.isStream))
                            } else if let current = current as? CachedGroupData {
                                return current.withUpdatedActiveCall(CachedChannelData.ActiveCall(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled, isStream: info.isStream))
                            } else {
                                return current
                            }
                        })
                        
                        switch call {
                        case let .groupCall(flags, _, _, participantsCount, title, _, recordStartDate, scheduleDate, _, _, _):
                            let isMuted = (flags & (1 << 1)) != 0
                            let canChange = (flags & (1 << 2)) != 0
                            let isVideoEnabled = (flags & (1 << 9)) != 0
                            let defaultParticipantsAreMuted = GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: isMuted, canChange: canChange)
                            updatedGroupCallParticipants.append((
                                info.id,
                                .call(isTerminated: false, defaultParticipantsAreMuted: defaultParticipantsAreMuted, title: title, recordingStartTimestamp: recordStartDate, scheduleTimestamp: scheduleDate, isVideoEnabled: isVideoEnabled, participantCount: Int(participantsCount))
                            ))
                        default:
                            break
                        }
                    }
                case let .groupCallDiscarded(callId, _, _):
                    updatedGroupCallParticipants.append((
                        callId,
                        .call(isTerminated: true, defaultParticipantsAreMuted: GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: false, canChange: false), title: nil, recordingStartTimestamp: nil, scheduleTimestamp: nil, isVideoEnabled: false, participantCount: nil)
                    ))
                    
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if let current = current as? CachedChannelData {
                            if let activeCall = current.activeCall, activeCall.id == callId {
                                return current.withUpdatedActiveCall(nil)
                            } else {
                                return current
                            }
                        } else if let current = current as? CachedGroupData {
                            if let activeCall = current.activeCall, activeCall.id == callId {
                                return current.withUpdatedActiveCall(nil)
                            } else {
                                return current
                            }
                        } else {
                            return current
                        }
                    })
                }
            case let .UpdateAutoremoveTimeout(peer, value):
                transaction.updatePeerCachedData(peerIds: Set([peer.peerId]), update: { _, current in
                    if let current = current as? CachedUserData {
                        return current.withUpdatedAutoremoveTimeout(.known(value))
                    } else if let current = current as? CachedGroupData {
                        return current.withUpdatedAutoremoveTimeout(.known(value))
                    } else if let current = current as? CachedChannelData {
                        return current.withUpdatedAutoremoveTimeout(.known(value))
                    } else {
                        return current
                    }
                })
            case let .UpdateLangPack(langCode, difference):
                if let difference = difference {
                    if langPackDifferences[langCode] == nil {
                        langPackDifferences[langCode] = []
                    }
                    langPackDifferences[langCode]!.append(difference)
                } else {
                    pollLangPacks.insert(langCode)
                }
            case let .UpdateIsContact(peerId, value):
                isContactUpdates.append((peerId, value))
            case let .UpdatePeersNearby(peersNearby):
                updatedPeersNearby = peersNearby
            case let .UpdateTheme(theme):
                updatedThemes[theme.id] = theme
            case .SyncChatListFilters:
                syncChatListFilters = true
            case let .UpdateChatListFilterOrder(order):
                if !syncChatListFilters {
                    let _ = updateChatListFiltersState(transaction: transaction, { state in
                        var state = state
                        if Set(state.filters.map { $0.id }) == Set(order) {
                            var updatedFilters: [ChatListFilter] = []
                            for id in order {
                                if let filter = state.filters.first(where: { $0.id == id }) {
                                    updatedFilters.append(filter)
                                } else {
                                    assertionFailure()
                                }
                            }
                            state.filters = updatedFilters
                            state.remoteFilters = state.filters
                        } else {
                            syncChatListFilters = true
                        }
                        return state
                    })
                }
            case let .UpdateChatListFilter(id, filter):
                if !syncChatListFilters {
                    let _ = updateChatListFiltersState(transaction: transaction, { state in
                        var state = state
                        if let index = state.filters.firstIndex(where: { $0.id == id }) {
                            if let filter = filter {
                                state.filters[index] = ChatListFilter(apiFilter: filter)
                            } else {
                                state.filters.remove(at: index)
                            }
                            state.remoteFilters = state.filters
                        } else {
                            syncChatListFilters = true
                        }
                        return state
                    })
                }
            case let .UpdateMessageReactions(messageId, reactions, _):
                transaction.updateMessage(messageId, update: { currentMessage in
                    var updatedReactions = ReactionsMessageAttribute(apiReactions: reactions)
                    
                    let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                    var attributes = currentMessage.attributes
                    var previousReactions: ReactionsMessageAttribute?
                    let _ = previousReactions
                    var added = false
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ReactionsMessageAttribute {
                            added = true
                            previousReactions = attribute
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
                    
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            case .UpdateAttachMenuBots:
                syncAttachMenuBots = true
            case let .UpdateAudioTranscription(messageId, id, isPending, text):
                transaction.updateMessage(messageId, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
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
                    
                    return .update(StoreMessage(
                        id: currentMessage.id,
                        globallyUniqueId: currentMessage.globallyUniqueId,
                        groupingKey: currentMessage.groupingKey,
                        threadId: currentMessage.threadId,
                        timestamp: currentMessage.timestamp,
                        flags: StoreMessageFlags(currentMessage.flags),
                        tags: currentMessage.tags,
                        globalTags: currentMessage.globalTags,
                        localTags: currentMessage.localTags,
                        forwardInfo: storeForwardInfo,
                        authorId: currentMessage.author?.id,
                        text: currentMessage.text,
                        attributes: attributes,
                        media: currentMessage.media
                    ))
                })
            case .UpdateConfig:
                updateConfig = true
        }
    }
    
    for messageId in holesFromPreviousStateMessageIds {
        let upperId: MessageId.Id
        if let value = topUpperHistoryBlockMessages[PeerIdAndMessageNamespace(peerId: messageId.peerId, namespace: messageId.namespace)], value < Int32.max {
            upperId = value - 1
        } else {
            upperId = Int32.max
        }
        if upperId >= messageId.id {
            transaction.addHole(peerId: messageId.peerId, namespace: messageId.namespace, space: .everywhere, range: messageId.id ... upperId)
            
            transaction.addHole(peerId: messageId.peerId, namespace: messageId.namespace, space: .tag(.pinned), range: 1 ... upperId)
            
            Logger.shared.log("State", "adding hole for peer \(messageId.peerId), \(messageId.id) ... \(upperId)")
        } else {
            Logger.shared.log("State", "not adding hole for peer \(messageId.peerId), \(upperId) >= \(messageId.id) = false")
        }
    }
//TODO Please do not forget fix holes space.
    
    // could be the reason for unbounded slowdown, needs investigation
//    for (peerIdAndNamespace, pts) in clearHolesFromPreviousStateForChannelMessagesWithPts {
//        var upperMessageId: Int32?
//        var lowerMessageId: Int32?
//        transaction.scanMessageAttributes(peerId: peerIdAndNamespace.peerId, namespace: peerIdAndNamespace.namespace, limit: 200, { id, attributes in
//            for attribute in attributes {
//                if let attribute = attribute as? ChannelMessageStateVersionAttribute {
//                    if attribute.pts >= pts {
//                        if upperMessageId == nil {
//                            upperMessageId = id.id
//                        }
//                        if let lowerMessageIdValue = lowerMessageId {
//                            lowerMessageId = min(id.id, lowerMessageIdValue)
//                        } else {
//                            lowerMessageId = id.id
//                        }
//                        return true
//                    } else {
//                        return false
//                    }
//                }
//            }
//            return false
//        })
//        if let upperMessageId = upperMessageId, let lowerMessageId = lowerMessageId {
//            if upperMessageId != lowerMessageId {
//                transaction.removeHole(peerId: peerIdAndNamespace.peerId, namespace: peerIdAndNamespace.namespace, space: .everywhere, range: lowerMessageId ... upperMessageId)
//            }
//        }
//    }
    
    for (threadMessageId, difference) in messageThreadStatsDifferences {
        updateMessageThreadStats(transaction: transaction, threadMessageId: threadMessageId, removedCount: difference.removedCount, addedMessagePeers: difference.peers)
    }
    
    if !peerActivityTimestamps.isEmpty {
        updatePeerPresenceLastActivities(transaction: transaction, accountPeerId: accountPeerId, activities: peerActivityTimestamps)
    }
    
    if !stickerPackOperations.isEmpty {
        if stickerPackOperations.contains(where: {
            if case .sync = $0 {
                return true
            } else {
                return false
            }
        }) {
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync, noDelay: false)
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync, noDelay: false)
        } else {
            var syncStickers = false
            var syncMasks = false
            loop: for operation in stickerPackOperations {
                switch operation {
                    case let .add(apiSet):
                        let namespace: ItemCollectionId.Namespace
                        var items: [ItemCollectionItem] = []
                        let info: StickerPackCollectionInfo
                        if case let .stickerSet(set, packs, documents) = apiSet {
                            var indexKeysByFile: [MediaId: [MemoryBuffer]] = [:]
                            for pack in packs {
                                switch pack {
                                case let .stickerPack(text, fileIds):
                                    let key = ValueBoxKey(text).toMemoryBuffer()
                                    for fileId in fileIds {
                                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                        if indexKeysByFile[mediaId] == nil {
                                            indexKeysByFile[mediaId] = [key]
                                        } else {
                                            indexKeysByFile[mediaId]!.append(key)
                                        }
                                    }
                                    break
                                }
                            }
                            
                            for apiDocument in documents {
                                if let file = telegramMediaFileFromApiDocument(apiDocument), let id = file.id {
                                    let fileIndexKeys: [MemoryBuffer]
                                    if let indexKeys = indexKeysByFile[id] {
                                        fileIndexKeys = indexKeys
                                    } else {
                                        fileIndexKeys = []
                                    }
                                    items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file, indexKeys: fileIndexKeys))
                                }
                            }
                            switch set {
                                case let .stickerSet(flags, _, _, _, _, _, _, _, _, _, _):
                                    if (flags & (1 << 3)) != 0 {
                                        namespace = Namespaces.ItemCollection.CloudMaskPacks
                                    } else {
                                        namespace = Namespaces.ItemCollection.CloudStickerPacks
                                    }
                            }
                            
                            info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
                        
                            if namespace == Namespaces.ItemCollection.CloudMaskPacks && syncMasks {
                                continue loop
                            } else if namespace == Namespaces.ItemCollection.CloudStickerPacks && syncStickers {
                                continue loop
                            }
                            
                            var updatedInfos = transaction.getItemCollectionsInfos(namespace: info.id.namespace).map { $0.1 as! StickerPackCollectionInfo }
                            if let index = updatedInfos.firstIndex(where: { $0.id == info.id }) {
                                let currentInfo = updatedInfos[index]
                                updatedInfos.remove(at: index)
                                updatedInfos.insert(currentInfo, at: 0)
                            } else {
                                updatedInfos.insert(info, at: 0)
                                transaction.replaceItemCollectionItems(collectionId: info.id, items: items)
                            }
                            transaction.replaceItemCollectionInfos(namespace: info.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                        }
                    case let .reorder(namespace, ids):
                        let collectionNamespace: ItemCollectionId.Namespace
                        switch namespace {
                            case .stickers:
                                collectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
                            case .masks:
                                collectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
                        }
                        let currentInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
                        if Set(currentInfos.map { $0.id.id }) != Set(ids) {
                            switch namespace {
                                case .stickers:
                                    syncStickers = true
                                case .masks:
                                    syncMasks = true
                            }
                        } else {
                            var currentDict: [ItemCollectionId: StickerPackCollectionInfo] = [:]
                            for info in currentInfos {
                                currentDict[info.id] = info
                            }
                            var updatedInfos: [StickerPackCollectionInfo] = []
                            for id in ids {
                                let currentInfo = currentDict[ItemCollectionId(namespace: collectionNamespace, id: id)]!
                                updatedInfos.append(currentInfo)
                            }
                            transaction.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                        }
                    case .sync:
                        syncStickers = true
                        syncMasks = true
                        break loop
                }
            }
            if syncStickers {
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync, noDelay: false)
            }
            if syncMasks {
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync, noDelay: false)
            }
        }
    }
    
    if !recentlyUsedStickers.isEmpty {
        let stickerFiles: [TelegramMediaFile] = recentlyUsedStickers.values.sorted(by: {
            return $0.0 < $1.0
        }).map({ $0.1 })
        for file in stickerFiles {
            if let entry = CodableEntry(RecentMediaItem(file)) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 20)
            }
        }
    }
    
    if !slowModeLastMessageTimeouts.isEmpty {
        var peerIds:Set<PeerId> = Set()
        var cachedDatas:[PeerId : CachedChannelData] = [:]
        for (peerId, timeout) in slowModeLastMessageTimeouts {
            if let peer = transaction.getPeer(peerId) {
                if let peer = peer as? TelegramChannel {
                    inner: switch peer.info {
                    case let .group(info):
                        if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator)  {
                            var cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData ?? CachedChannelData()
                            if let slowModeTimeout = cachedData.slowModeTimeout {
                                cachedData = cachedData.withUpdatedSlowModeValidUntilTimestamp(timeout + slowModeTimeout)
                                peerIds.insert(peerId)
                                cachedDatas[peerId] = cachedData
                            }
                        }
                    default:
                        break inner
                    }
                }
            }
        }
        transaction.updatePeerCachedData(peerIds: peerIds, update: { peerId, current in
            return cachedDatas[peerId] ?? current
        })
    }
    
    if syncRecentGifs {
        addSynchronizeSavedGifsOperation(transaction: transaction, operation: .sync)
    } else {
        let gifFiles: [TelegramMediaFile] = recentlyUsedGifs.values.sorted(by: {
            return $0.0 < $1.0
        }).map({ $0.1 })
        for file in gifFiles {
            if !file.hasLinkedStickers {
                if let entry = CodableEntry(RecentMediaItem(file)) {
                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 200)
                }
            }
        }
    }
    
    if syncAttachMenuBots {
//        addSynchronizeAttachMenuBotsOperation(transaction: transaction)
    }
    
    for groupId in invalidateGroupStats {
        transaction.setNeedsPeerGroupMessageStatsSynchronization(groupId: groupId, namespace: Namespaces.Message.Cloud)
    }
    
    for chatPeerId in updatedSecretChatTypingActivities {
        if let peer = transaction.getPeer(chatPeerId) as? TelegramSecretChat {
            let authorId = peer.regularPeerId
            let activityValue: PeerInputActivity? = .typingText
            if updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] == nil {
                updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] = [authorId: activityValue]
            } else {
                updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)]![authorId] = activityValue
            }
        }
    }
    
    var addedSecretMessageIds: [MessageId] = []
    var addedSecretMessageAuthorIds: [PeerId: PeerId] = [:]
    
    for peerId in peerIdsWithAddedSecretMessages {
        inner: while true {
            let keychain = (transaction.getPeerChatState(peerId) as? SecretChatState)?.keychain
            if processSecretChatIncomingEncryptedOperations(transaction: transaction, peerId: peerId) {
                let processResult = processSecretChatIncomingDecryptedOperations(encryptionProvider: encryptionProvider, mediaBox: mediaBox, transaction: transaction, peerId: peerId)
                if !processResult.addedMessages.isEmpty {
                    let currentInclusion = transaction.getPeerChatListInclusion(peerId)
                    if let groupId = currentInclusion.groupId, groupId == Namespaces.PeerGroup.archive {
                        if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                            let isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: transaction.getGlobalNotificationSettings(), peer: peer, peerSettings: transaction.getPeerNotificationSettings(peer.regularPeerId))
                            
                            if !isRemovedFromTotalUnreadCount {
                                transaction.updatePeerChatListInclusion(peerId, inclusion: currentInclusion.withGroupId(groupId: .root))
                            }
                        }
                    }
                    for message in processResult.addedMessages {
                        if case let .Id(id) = message.id {
                            addedSecretMessageIds.append(id)
                            if let authorId = message.authorId {
                                if addedSecretMessageAuthorIds[peerId] == nil {
                                    addedSecretMessageAuthorIds[peerId] = authorId
                                }
                            }
                        }
                    }
                }
            }
            let updatedKeychain = (transaction.getPeerChatState(peerId) as? SecretChatState)?.keychain
            if updatedKeychain == keychain {
                break inner
            }
        }
    }
    
    for (chatPeerId, authorId) in addedSecretMessageAuthorIds {
        let activityValue: PeerInputActivity? = nil
        if updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] == nil {
            updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] = [authorId: activityValue]
        } else {
            updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)]![authorId] = activityValue
        }
    }
    
    if !pollLangPacks.isEmpty {
        addSynchronizeLocalizationUpdatesOperation(transaction: transaction)
    } else {
        let _ = (accountManager.transaction { transaction -> Void in
            outer: for (langCode, langPackDifference) in langPackDifferences {
                if !langPackDifference.isEmpty {
                    let sortedLangPackDifference = langPackDifference.sorted(by: { lhs, rhs in
                        let lhsVersion: Int32
                        switch lhs {
                            case let .langPackDifference(_, fromVersion, _, _):
                                lhsVersion = fromVersion
                        }
                        let rhsVersion: Int32
                        switch rhs {
                            case let .langPackDifference(_, fromVersion, _, _):
                                rhsVersion = fromVersion
                        }
                        return lhsVersion < rhsVersion
                    })
                
                    for difference in sortedLangPackDifference {
                        if !tryApplyingLanguageDifference(transaction: transaction, langCode: langCode, difference: difference) {
                            let _ = (postbox.transaction { transaction -> Void in
                                addSynchronizeLocalizationUpdatesOperation(transaction: transaction)
                            }).start()
                            break outer
                        }
                    }
                }
            }
        }).start()
    }
    
    if !updatedThemes.isEmpty {
        let entries = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudThemes)
        let themes = entries.map { entry -> TelegramTheme in
            let theme = entry.contents.get(TelegramThemeNativeCodable.self)!
            if let updatedTheme = updatedThemes[theme.value.id] {
                return updatedTheme
            } else {
                return theme.value
            }
        }
        var updatedEntries: [OrderedItemListEntry] = []
        for theme in themes {
            var intValue = Int32(updatedEntries.count)
            let id = MemoryBuffer(data: Data(bytes: &intValue, count: 4))
            if let entry = CodableEntry(TelegramThemeNativeCodable(theme)) {
                updatedEntries.append(OrderedItemListEntry(id: id, contents: entry))
            }
        }
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudThemes, items: updatedEntries)
        let _ = accountManager.transaction { transaction in
            transaction.updateSharedData(SharedDataKeys.themeSettings, { current in
                if let current = current?.get(ThemeSettings.self), let theme = current.currentTheme, let updatedTheme = updatedThemes[theme.id] {
                    return PreferencesEntry(ThemeSettings(currentTheme: updatedTheme))
                }
                return current
            })
        }.start()
    }
    
    addedIncomingMessageIds.append(contentsOf: addedSecretMessageIds)
    
    for (uniqueId, messageIdValue) in finalState.state.updatedOutgoingUniqueMessageIds {
        if let peerId = removePossiblyDeliveredMessagesUniqueIds[uniqueId] {
            let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageIdValue)
            deleteMessagesInteractively(transaction: transaction, stateManager: nil, postbox: postbox, messageIds: [messageId], type: .forEveryone, deleteAllInGroup: false, removeIfPossiblyDelivered: false)
        }
    }
    
    if syncChatListFilters {
        requestChatListFiltersSync(transaction: transaction)
    }
    
    return AccountReplayedFinalState(state: finalState, addedIncomingMessageIds: addedIncomingMessageIds, addedReactionEvents: addedReactionEvents, wasScheduledMessageIds: wasScheduledMessageIds, addedSecretMessageIds: addedSecretMessageIds, deletedMessageIds: deletedMessageIds, updatedTypingActivities: updatedTypingActivities, updatedWebpages: updatedWebpages, updatedCalls: updatedCalls, addedCallSignalingData: addedCallSignalingData, updatedGroupCallParticipants: updatedGroupCallParticipants, updatedPeersNearby: updatedPeersNearby, isContactUpdates: isContactUpdates, delayNotificatonsUntil: delayNotificatonsUntil, updatedIncomingThreadReadStates: updatedIncomingThreadReadStates, updatedOutgoingThreadReadStates: updatedOutgoingThreadReadStates, updateConfig: updateConfig)
}
