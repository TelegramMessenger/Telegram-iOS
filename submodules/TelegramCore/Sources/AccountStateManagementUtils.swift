import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

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
                peerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId))
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
    
    return peerIds
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
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                peerIds.insert(peerId)
            case let .updateFolderPeers(folderPeers, _, _):
                for peer in folderPeers {
                    switch peer {
                        case let .folderPeer(peer, _):
                            peerIds.insert(peer.peerId)
                    }
                }
            case let .updateReadChannelInbox(_, _, channelId, _, _, _):
                peerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId))
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
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
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
        case let .difference(difference):
            chats = difference.chats
        case .differenceEmpty:
            break
        case let .differenceSlice(differenceSlice):
            chats = differenceSlice.chats
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
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
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
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
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
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
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
    var chatStates: [PeerId: PeerChatState] = [:]
    
    var channelsToPollExplicitely = Set<PeerId>()
    
    for peerId in peerIds {
        if let peer = transaction.getPeer(peerId) {
            peers[peerId] = peer
        }
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
                chatStates[peerId] = channelState
            }
        } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
            if let chatState = transaction.getPeerChatState(peerId) as? RegularChatState {
                chatStates[peerId] = chatState
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
    
    return AccountMutableState(initialState: AccountInitialState(state: (transaction.getState() as? AuthorizedAccountState)!.state!, peerIds: peerIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, chatStates: chatStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestamps, cloudReadStates: cloudReadStates, channelsToPollExplicitely: channelsToPollExplicitely), initialPeers: peers, initialReferencedMessageIds: associatedMessageIds, initialStoredMessages: storedMessages, initialReadInboxMaxIds: readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: storedMessagesByPeerIdAndTimestamp)
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
    
    return finalStateWithUpdates(postbox: postbox, network: network, state: updatedState, updates: collectedUpdates, shouldPoll: hadReset, missingUpdates: !ptsUpdatesAfterHole.isEmpty || !qtsUpdatesAfterHole.isEmpty || !seqGroupsAfterHole.isEmpty, shouldResetChannels: true, updatesDate: updatesDate)
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
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateDeleteChannelMessages(channelId, _, _, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
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
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if updatesByChannel[peerId] == nil {
                    updatesByChannel[peerId] = [update]
                } else {
                    updatesByChannel[peerId]!.append(update)
                }
            case let .updateChannelAvailableMessages(channelId, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
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
    
    for update in sortedUpdates(updates) {
        switch update {
            case let .updateChannelTooLong(_, channelId, channelPts):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if !channelsToPoll.contains(peerId) {
                    if let channelPts = channelPts, let channelState = state.chatStates[peerId] as? ChannelState, channelState.pts >= channelPts {
                        Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip updateChannelTooLong by pts")
                    } else {
                        channelsToPoll.insert(peerId)
                    }
                }
            case let .updateDeleteChannelMessages(channelId, messages, pts: pts, ptsCount):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if let previousState = updatedState.chatStates[peerId] as? ChannelState {
                    if previousState.pts >= pts {
                        Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old delete update")
                    } else if previousState.pts + ptsCount == pts {
                        updatedState.deleteMessages(messages.map({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }))
                        updatedState.updateChannelState(peerId, state: previousState.withUpdatedPts(pts))
                    } else {
                        if !channelsToPoll.contains(peerId) {
                            Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) delete pts hole")
                            channelsToPoll.insert(peerId)
                            //updatedMissingUpdates = true
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
                    if let previousState = updatedState.chatStates[peerId] as? ChannelState {
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
                            updatedState.updateChannelState(peerId, state: previousState.withUpdatedPts(pts))
                        } else {
                            if !channelsToPoll.contains(peerId) {
                                Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) edit message pts hole")
                                channelsToPoll.insert(peerId)
                                //updatedMissingUpdates = true
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
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if let previousState = updatedState.chatStates[peerId] as? ChannelState {
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
                        
                        updatedState.updateChannelState(peerId, state: previousState.withUpdatedPts(pts))
                    } else {
                        if !channelsToPoll.contains(peerId) {
                            Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) updateWebPage pts hole")
                            channelsToPoll.insert(peerId)
                        }
                    }
                } else {
                    if !channelsToPoll.contains(peerId) {
                        channelsToPoll.insert(peerId)
                    }
                }
            case let .updateChannelAvailableMessages(channelId, minId):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                updatedState.updateMinAvailableMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: minId))
            case let .updateDeleteMessages(messages, _, _):
                updatedState.deleteMessagesWithGlobalIds(messages)
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
                    if let previousState = updatedState.chatStates[message.id.peerId] as? ChannelState {
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
                            updatedState.updateChannelState(message.id.peerId, state: previousState.withUpdatedPts(pts))
                        } else {
                            if !channelsToPoll.contains(message.id.peerId) {
                                Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) message pts hole")
                                ;
                                channelsToPoll.insert(message.id.peerId)
                                //updatedMissingUpdates = true
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
                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
                    
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
                        
                        let (mediaValue, expirationTimer) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                        if let mediaValue = mediaValue {
                            medias.append(mediaValue)
                        }
                        if let expirationTimer = expirationTimer {
                            attributes.append(AutoremoveTimeoutMessageAttribute(timeout: expirationTimer, countdownBeginTime: nil))
                        }
                        
                        if type.hasPrefix("auth") {
                            updatedState.authorizationListUpdated = true
                        }
                        
                        let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: nil, groupingKey: nil, timestamp: date, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: messageText, attributes: attributes, media: medias)
                        updatedState.addMessages([message], location: .UpperHistoryBlock)
                    }
                }
            case let .updateReadChannelInbox(_, folderId, channelId, maxId, stillUnreadCount, pts):
                updatedState.resetIncomingReadState(groupId: PeerGroupId(rawValue: folderId ?? 0), peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), namespace: Namespaces.Message.Cloud, maxIncomingReadId: maxId, count: stillUnreadCount, pts: pts)
            case let .updateReadChannelOutbox(channelId, maxId):
                updatedState.readOutbox(MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), namespace: Namespaces.Message.Cloud, id: maxId), timestamp: nil)
            case let .updateChannel(channelId):
                updatedState.addExternallyUpdatedPeerId(PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId))
            case let .updateReadHistoryInbox(_, folderId, peer, maxId, stillUnreadCount, pts, _):
                updatedState.resetIncomingReadState(groupId: PeerGroupId(rawValue: folderId ?? 0), peerId: peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: maxId, count: stillUnreadCount, pts: pts)
            case let .updateReadHistoryOutbox(peer, maxId, _, _):
                updatedState.readOutbox(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: maxId), timestamp: updatesDate)
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
                        groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                    case let .chatParticipantsForbidden(_, chatId, _):
                        groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
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
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                let inviterPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId)
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
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
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
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
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
            case let .updateChannelPinnedMessage(channelId, id):
                let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                updatedState.updateCachedPeerData(channelPeerId, { current in
                    let previous: CachedChannelData
                    if let current = current as? CachedChannelData {
                        previous = current
                    } else {
                        previous = CachedChannelData()
                    }
                    return previous.withUpdatedPinnedMessageId(id == 0 ? nil : MessageId(peerId: channelPeerId, namespace: Namespaces.Message.Cloud, id: id))
                })
            case let .updateUserPinnedMessage(userId, id):
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                updatedState.updateCachedPeerData(userPeerId, { current in
                    let previous: CachedUserData
                    if let current = current as? CachedUserData {
                        previous = current
                    } else {
                        previous = CachedUserData()
                    }
                    return previous.withUpdatedPinnedMessageId(id == 0 ? nil : MessageId(peerId: userPeerId, namespace: Namespaces.Message.Cloud, id: id))
                })
            case let .updateChatPinnedMessage(groupId, id, _):
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: groupId)
                updatedState.updateCachedPeerData(groupPeerId, { current in
                    let previous: CachedGroupData
                    if let current = current as? CachedGroupData {
                        previous = current
                    } else {
                        previous = CachedGroupData()
                    }
                    return previous.withUpdatedPinnedMessageId(id == 0 ? nil : MessageId(peerId: groupPeerId, namespace: Namespaces.Message.Cloud, id: id))
                })
            case let .updateUserBlocked(userId, blocked):
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
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
                updatedState.mergePeerPresences([PeerId(namespace: Namespaces.Peer.CloudUser, id: userId): status], explicit: true)
            case let .updateUserName(userId, firstName, lastName, username):
                //TODO add contact checking for apply first and last name
                updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), { peer in
                    if let user = peer as? TelegramUser {
                        return user.withUpdatedUsername(username)
                    } else {
                        return peer
                    }
                })
            case let .updateUserPhoto(userId, _, photo, _):
                updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), { peer in
                    if let user = peer as? TelegramUser {
                        return user.withUpdatedPhoto(parsedTelegramProfilePhoto(photo))
                    } else {
                        return peer
                    }
                })
            case let .updateUserPhone(userId, phone):
                updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), { peer in
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
                updatedState.readSecretOutbox(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: chatId), timestamp: maxDate, actionTimestamp: date)
            case let .updateUserTyping(userId, type):
                if let date = updatesDate, date + 60 > serverTime {
                    updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), activity: PeerInputActivity(apiType: type))
                }
            case let .updateChatUserTyping(chatId, userId, type):
                if let date = updatesDate, date + 60 > serverTime {
                    updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), activity: PeerInputActivity(apiType: type))
                    updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: chatId), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), activity: PeerInputActivity(apiType: type))
                }
            case let .updateEncryptedChatTyping(chatId):
                if let date = updatesDate, date + 60 > serverTime {
                    updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: chatId), peerId: nil, activity: .typingText)
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
                updatedState.addReadMessagesContents((PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), messages))
            case let .updateChannelMessageViews(channelId, id, views):
                updatedState.addUpdateMessageImpressionCount(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), namespace: Namespaces.Message.Cloud, id: id), count: views)
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
                        inputState = SynchronizeableChatInputState(replyToMessageId: replyToMessageId, text: message, entities: messageTextEntitiesFromApiEntities(entities ?? []), timestamp: date)
                }
                updatedState.addUpdateChatInputState(peerId: peer.peerId, state: inputState)
            case let .updatePhoneCall(phoneCall):
                updatedState.addUpdateCall(phoneCall)
            case let .updateLangPackTooLong(langCode):
                updatedState.updateLangPack(langCode: langCode, difference: nil)
            case let .updateLangPack(difference):
                let langCode: String
                switch difference {
                    case let .langPackDifference(langPackDifference):
                        langCode = langPackDifference.langCode
                }
                updatedState.updateLangPack(langCode: langCode, difference: difference)
            case let .updateMessagePoll(_, pollId, poll, results):
                updatedState.updateMessagePoll(MediaId(namespace: Namespaces.Media.CloudPoll, id: pollId), poll: poll, results: results)
            /*case let .updateMessageReactions(peer, msgId, reactions):
                updatedState.updateMessageReactions(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), reactions: reactions)*/
            case let .updateFolderPeers(folderPeers, _, _):
                for folderPeer in folderPeers {
                    switch folderPeer {
                        case let .folderPeer(peer, folderId):
                            updatedState.updatePeerChatInclusion(peerId: peer.peerId, groupId: PeerGroupId(rawValue: folderId), changedGroup: true)
                    }
                }
            case let .updatePeerLocated(peers):
                var peersNearby: [PeerNearby] = []
                for case let .peerLocated(peer, expires, distance) in peers {
                    peersNearby.append(PeerNearby(id: peer.peerId, expires: expires, distance: distance))
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
                if let theme = TelegramTheme(apiTheme: theme) {
                    updatedState.updateTheme(theme)
                }
            case let .updateMessageID(id, randomId):
                updatedState.updatedOutgoingUniqueMessageIds[randomId] = id
            default:
                break
        }
    }
    
    var pollChannelSignals: [Signal<(AccountMutableState, Bool, Int32?), NoError>] = []
    if channelsToPoll.isEmpty {
        pollChannelSignals = []
    } else if shouldResetChannels {
        var channelPeers: [Peer] = []
        for peerId in channelsToPoll {
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
        for peerId in channelsToPoll {
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
                return AccountFinalState(state: resultingState, shouldPoll: shouldPoll || hadError || resolveError, incomplete: missingUpdates, discard: resolveError)
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
                            case let .messagesSlice(_, _, _, messages, chats, users):
                                return (messages, chats, users)
                            case let .channelMessages(_, _, _, messages, chats, users):
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
                case let .peerDialogs(dialogs, messages, chats, users, state):
                    updatedState.mergeChats(chats)
                    updatedState.mergeUsers(users)
                    
                    var topMessageIds = Set<MessageId>()
                    
                    for dialog in dialogs {
                        switch dialog {
                            case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, notifySettings, pts, draft, folderId):
                                let peerId = peer.peerId
                                
                                updatedState.setNeedsHoleFromPreviousState(peerId: peerId, namespace: Namespaces.Message.Cloud)
                                
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
                                updatedState.resetMessageTagSummary(peer.peerId, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                                updatedState.peerChatInfos[peer.peerId] = PeerChatInfo(notificationSettings: notificationSettings)
                                if let pts = pts {
                                    channelStates[peer.peerId] = ChannelState(pts: pts, invalidatedPts: pts)
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

func keepPollingChannel(postbox: Postbox, network: Network, peerId: PeerId, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let accountState = (transaction.getState() as? AuthorizedAccountState)?.state, let peer = transaction.getPeer(peerId) {
            var chatStates: [PeerId: PeerChatState] = [:]
            if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
                chatStates[peerId] = channelState
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
            let initialState = AccountMutableState(initialState: AccountInitialState(state: accountState, peerIds: Set(), peerIdsRequiringLocalChatState: Set(), chatStates: chatStates, peerChatInfos: peerChatInfos, locallyGeneratedMessageTimestamps: [:], cloudReadStates: [:], channelsToPollExplicitely: Set()), initialPeers: initialPeers, initialReferencedMessageIds: Set(), initialStoredMessages: Set(), initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:])
            return pollChannel(network: network, peer: peer, state: initialState)
            |> mapToSignal { (finalState, _, timeout) -> Signal<Void, NoError> in
                return resolveAssociatedMessages(network: network, state: finalState)
                |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                    return resolveMissingPeerChatInfos(network: network, state: resultingState)
                    |> map { resultingState, _ -> AccountFinalState in
                        return AccountFinalState(state: resultingState, shouldPoll: false, incomplete: false, discard: false)
                    }
                }
                |> mapToSignal { finalState -> Signal<Void, NoError> in
                    return stateManager.addReplayAsynchronouslyBuiltFinalState(finalState)
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete() |> delay(Double(timeout ?? 30), queue: Queue.concurrentDefaultQueue())
                    }
                }
            }
        } else {
            return .complete()
            |> delay(30.0, queue: Queue.concurrentDefaultQueue())
        }
    }
    |> switchToLatest
    |> restart
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
        var mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
        var channelStates: [PeerId: ChannelState] = [:]
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
                        var apiChannelPts: Int32?
                        let apiNotificationSettings: Api.PeerNotifySettings
                        let apiMarkedUnread: Bool
                        let groupId: PeerGroupId
                        switch dialog {
                            case let .dialog(flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, peerNotificationSettings, pts, _, folderId):
                                apiPeer = peer
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                                apiMarkedUnread = (flags & (1 << 3)) != 0
                                apiUnreadMentionsCount = unreadMentionsCount
                                apiNotificationSettings = peerNotificationSettings
                                apiChannelPts = pts
                                groupId = PeerGroupId(rawValue: folderId ?? 0)
                            case .dialogFolder:
                                assertionFailure()
                                continue loop
                        }
                        
                        let peerId: PeerId
                        switch apiPeer {
                            case let .peerUser(userId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            case let .peerChat(chatId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                            case let .peerChannel(channelId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        }
                        
                        if readStates[peerId] == nil {
                            readStates[peerId] = [:]
                        }
                        readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount, markedUnread: apiMarkedUnread)
                        
                        if apiTopMessage != 0 {
                            mentionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                        }
                        
                        if let apiChannelPts = apiChannelPts {
                            channelStates[peerId] = ChannelState(pts: apiChannelPts, invalidatedPts: apiChannelPts)
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
                updatedState.setNeedsHoleFromPreviousState(peerId: id.peerId, namespace: id.namespace)
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
            updatedState.resetMessageTagSummary(peerId, namespace: Namespaces.Message.Cloud, count: tagSummary.count, range: tagSummary.range)
        }
        
        for (peerId, channelState) in channelStates {
            updatedState.updateChannelState(peerId, state: channelState)
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
        #if DEBUG
        limit = 1
        #else
        limit = 20
        #endif
        
        let pollPts: Int32
        if let channelState = state.chatStates[peer.id] as? ChannelState {
            pollPts = channelState.pts
        } else {
            pollPts = 1
        }
        return (network.request(Api.functions.updates.getChannelDifference(flags: 0, channel: inputChannel, filter: .channelMessagesFilterEmpty, pts: pollPts, limit: limit))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.updates.ChannelDifference?, MTRpcError> in
            if error.errorDescription == "CHANNEL_PRIVATE" {
                return .single(nil)
            } else {
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
                        let channelState: ChannelState
                        if let previousState = updatedState.chatStates[peer.id] as? ChannelState {
                            channelState = previousState.withUpdatedPts(pts)
                        } else {
                            channelState = ChannelState(pts: pts, invalidatedPts: nil)
                        }
                        updatedState.updateChannelState(peer.id, state: channelState)
                        
                        updatedState.mergeChats(chats)
                        updatedState.mergeUsers(users)
                        
                        for apiMessage in newMessages {
                            if let message = StoreMessage(apiMessage: apiMessage) {
                                if let preCachedResources = apiMessage.preCachedResources {
                                    for (resource, data) in preCachedResources {
                                        updatedState.addPreCachedResource(resource, data: data)
                                    }
                                }
                                updatedState.addMessages([message], location: .UpperHistoryBlock)
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
                                case let .updateChannelPinnedMessage(_, id):
                                    updatedState.updateCachedPeerData(peer.id, { current in
                                        let previous: CachedChannelData
                                        if let current = current as? CachedChannelData {
                                            previous = current
                                        } else {
                                            previous = CachedChannelData()
                                        }
                                        return previous.withUpdatedPinnedMessageId(id == 0 ? nil : MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id))
                                    })
                                case let .updateChannelReadMessagesContents(_, messages):
                                    updatedState.addReadMessagesContents((peer.id, messages))
                                case let .updateChannelMessageViews(_, id, views):
                                    updatedState.addUpdateMessageImpressionCount(id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id), count: views)
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
                        
                        let channelState: ChannelState
                        if let previousState = updatedState.chatStates[peer.id] as? ChannelState {
                            channelState = previousState.withUpdatedPts(pts)
                        } else {
                            channelState = ChannelState(pts: pts, invalidatedPts: nil)
                        }
                        updatedState.updateChannelState(peer.id, state: channelState)
                    case let .channelDifferenceTooLong(_, timeout, dialog, messages, chats, users):
                        apiTimeout = timeout
                        
                        var parameters: (peer: Api.Peer, pts: Int32, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32)?
                        
                        switch dialog {
                            case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, notifySettings, pts, draft, folderId):
                                if let pts = pts {
                                    parameters = (peer, pts, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount)
                                }
                            case .dialogFolder:
                                break
                        }
                        
                        if let (peer, pts, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount) = parameters {
                            let channelState = ChannelState(pts: pts, invalidatedPts: pts)
                            updatedState.updateChannelState(peer.peerId, state: channelState)
                            
                            updatedState.mergeChats(chats)
                            updatedState.mergeUsers(users)
                            
                            updatedState.setNeedsHoleFromPreviousState(peerId: peer.peerId, namespace: Namespaces.Message.Cloud)
                        
                            for apiMessage in messages {
                                if let message = StoreMessage(apiMessage: apiMessage) {
                                    if let preCachedResources = apiMessage.preCachedResources {
                                        for (resource, data) in preCachedResources {
                                            updatedState.addPreCachedResource(resource, data: data)
                                        }
                                    }
                                    
                                    let location: AddMessagesLocation
                                    if case let .Id(id) = message.id, id.id == topMessage {
                                        location = .UpperHistoryBlock
                                    } else {
                                        location = .Random
                                    }
                                    updatedState.addMessages([message], location: location)
                                }
                            }
                        
                            updatedState.resetReadState(peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: nil)
                        
                            updatedState.resetMessageTagSummary(peer.peerId, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
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
        let previousState = finalState.initialState.chatStates[peerId] as? ChannelState
        if let currentState = currentState, let previousState = previousState {
            if currentState.equals(previousState) {
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

private enum ReplayFinalStateIncomplete {
    case MoreDataNeeded
    case PollRequired
}

private enum ReplayFinalStateResult {
    case Completed
    case Incomplete(ReplayFinalStateIncomplete)
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
    var updatedChannelStates: [PeerId: ChannelState] = [:]
    
    var currentAddMessages: OptimizeAddMessagesState?
    var currentAddScheduledMessages: OptimizeAddMessagesState?
    for operation in operations {
        switch operation {
            case .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpdateMessagePoll/*, .UpdateMessageReactions*/, .UpdateMedia, .MergeApiChats, .MergeApiUsers, .MergePeerPresences, .UpdatePeer, .ReadInbox, .ReadOutbox, .ReadGroupFeedInbox, .ResetReadState, .ResetIncomingReadState, .UpdatePeerChatUnreadMark, .ResetMessageTagSummary, .UpdateNotificationSettings, .UpdateGlobalNotificationSettings, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity, .UpdateCachedPeerData, .UpdatePinnedItemIds, .ReadMessageContents, .UpdateMessageImpressionCount, .UpdateInstalledStickerPacks, .UpdateRecentGifs, .UpdateChatInputState, .UpdateCall, .UpdateLangPack, .UpdateMinAvailableMessage, .UpdateIsContact, .UpdatePeerChatInclusion, .UpdatePeersNearby, .UpdateTheme:
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
            case let .UpdateChannelState(peerId, state):
                updatedChannelStates[peerId] = state
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
        result.append(.UpdateChannelState(peerId, state))
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

func replayFinalState(accountManager: AccountManager, postbox: Postbox, accountPeerId: PeerId, mediaBox: MediaBox, encryptionProvider: EncryptionProvider, transaction: Transaction, auxiliaryMethods: AccountAuxiliaryMethods, finalState: AccountFinalState, removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId]) -> AccountReplayedFinalState? {
    let verified = verifyTransaction(transaction, finalState: finalState.state)
    if !verified {
        Logger.shared.log("State", "failed to verify final state")
        return nil
    }
    
    var peerIdsWithAddedSecretMessages = Set<PeerId>()
    
    var updatedTypingActivities: [PeerId: [PeerId: PeerInputActivity?]] = [:]
    var updatedSecretChatTypingActivities = Set<PeerId>()
    var updatedWebpages: [MediaId: TelegramMediaWebpage] = [:]
    var updatedCalls: [Api.PhoneCall] = []
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
    
    var holesFromPreviousStateMessageIds: [MessageId] = []
    
    for (peerId, namespaces) in finalState.state.namespacesWithHolesFromPreviousState {
        for namespace in namespaces {
            if let id = transaction.getTopPeerMessageId(peerId: peerId, namespace: namespace) {
                holesFromPreviousStateMessageIds.append(MessageId(peerId: id.peerId, namespace: id.namespace, id: id.id + 1))
            } else {
                holesFromPreviousStateMessageIds.append(MessageId(peerId: peerId, namespace: namespace, id: 1))
            }
        }
    }
    
    var wasOpearationScheduledMessegeIds: [MessageId] = []
    
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
                                wasOpearationScheduledMessegeIds.append(id)
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
    
    if !wasOpearationScheduledMessegeIds.isEmpty {
        let existingIds = transaction.filterStoredMessageIds(Set(wasOpearationScheduledMessegeIds))
        for id in wasOpearationScheduledMessegeIds {
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
    
    for operation in optimizedOperations(finalState.state.operations) {
        switch operation {
            case let .AddMessages(messages, location):
                let _ = transaction.addMessages(messages, location: location)
                if case .UpperHistoryBlock = location {
                    for message in messages {
                        let chatPeerId = message.id.peerId
                        if let authorId = message.authorId {
                            let activityValue: PeerInputActivity? = nil
                            if updatedTypingActivities[chatPeerId] == nil {
                                updatedTypingActivities[chatPeerId] = [authorId: activityValue]
                            } else {
                                updatedTypingActivities[chatPeerId]![authorId] = activityValue
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
                var resourceIds: [WrappedMediaResourceId] = []
                transaction.deleteMessagesWithGlobalIds(ids, forEachMedia: { media in
                    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                })
                if !resourceIds.isEmpty {
                    let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
                }
            case let .DeleteMessages(ids):
                deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids)
            case let .UpdateMinAvailableMessage(id):
                if let message = transaction.getMessage(id) {
                    updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: id.peerId, minTimestamp: message.timestamp, forceRootGroupIfNotExists: false)
                }
                var resourceIds: [WrappedMediaResourceId] = []
                transaction.deleteMessagesInRange(peerId: id.peerId, namespace: id.namespace, minId: 1, maxId: id.id, forEachMedia: { media in
                    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                })
                if !resourceIds.isEmpty {
                    let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
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
                    return .update(message.withUpdatedLocalTags(updatedLocalTags).withUpdatedFlags(updatedFlags))
                })
            case let .UpdateMessagePoll(pollId, apiPoll, results):
                if let poll = transaction.getMedia(pollId) as? TelegramMediaPoll {
                    var updatedPoll = poll
                    if let apiPoll = apiPoll {
                        switch apiPoll {
                            case let .poll(id, flags, question, answers):
                                updatedPoll = TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: id), text: question, options: answers.map(TelegramMediaPollOption.init(apiOption:)), results: TelegramMediaPollResults(apiResults: results), isClosed: (flags & (1 << 0)) != 0)
                        }
                    }
                    
                    let resultsMin: Bool
                    switch results {
                        case let .pollResults(pollResults):
                            resultsMin = (pollResults.flags & (1 << 0)) != 0
                    }
                    updatedPoll = updatedPoll.withUpdatedResults(TelegramMediaPollResults(apiResults: results), min: resultsMin)
                    updateMessageMedia(transaction: transaction, id: pollId, media: updatedPoll)
                }
            /*case let .UpdateMessageReactions(messageId, reactions):
                transaction.updateMessage(messageId, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                    }
                    var attributes = currentMessage.attributes
                    var found = false
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ReactionsMessageAttribute {
                            attributes[j] = attribute.withUpdatedResults(reactions)
                            found = true
                            break loop
                        }
                    }
                    if !found {
                        attributes.append(ReactionsMessageAttribute(apiReactions: reactions))
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })*/
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
            case let .ReadGroupFeedInbox(groupId, index):
                break
                //transaction.applyGroupFeedReadMaxIndex(groupId: groupId, index: index)
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
                transaction.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnreadValue)]])
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
            case let .ResetMessageTagSummary(peerId, namespace, count, range):
                transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: namespace, count: count, maxId: range.maxId)
                if count == 0 {
                    transaction.removeHole(peerId: peerId, namespace: namespace, space: .tag(.unseenPersonalMessage), range: 1 ... (Int32.max - 1))
                    let ids = transaction.getMessageIndicesWithTag(peerId: peerId, namespace: namespace, tag: .unseenPersonalMessage).map({ $0.id })
                    for id in ids {
                        markUnseenPersonalMessage(transaction: transaction, id: id, addSynchronizeAction: false)
                    }
                }
            case let .UpdateState(state):
                let currentState = transaction.getState() as! AuthorizedAccountState
                transaction.setState(currentState.changedState(state))
                Logger.shared.log("State", "apply state \(state)")
            case let .UpdateChannelState(peerId, channelState):
                transaction.setPeerChatState(peerId, state: channelState)
                Logger.shared.log("State", "apply channel state \(peerId): \(channelState)")
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
                            if let current = current as? GlobalNotificationSettings {
                                updated = current
                            } else {
                                updated = GlobalNotificationSettings.defaultSettings
                            }
                            updated.remote.privateChats = notificationSettings
                            return updated
                        })
                    case .groups:
                        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            var updated: GlobalNotificationSettings
                            if let current = current as? GlobalNotificationSettings {
                                updated = current
                            } else {
                                updated = GlobalNotificationSettings.defaultSettings
                            }
                            updated.remote.groupChats = notificationSettings
                            return updated
                        })
                    case .channels:
                        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            var updated: GlobalNotificationSettings
                            if let current = current as? GlobalNotificationSettings {
                                updated = current
                            } else {
                                updated = GlobalNotificationSettings.defaultSettings
                            }
                            updated.remote.channels = notificationSettings
                            return updated
                        })
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
                updateSecretChat(encryptionProvider: encryptionProvider, accountPeerId: accountPeerId, transaction: transaction, chat: chat, requestData: nil)
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
                } else if chatPeerId.namespace == Namespaces.Peer.SecretChat {
                    updatedSecretChatTypingActivities.insert(chatPeerId)
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
            case let .ReadMessageContents(peerId, messageIds):
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
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                    }
                    var attributes = currentMessage.attributes
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ViewCountMessageAttribute {
                            attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(count)))
                            break loop
                        }
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            case let .UpdateInstalledStickerPacks(operation):
                stickerPackOperations.append(operation)
            case .UpdateRecentGifs:
                syncRecentGifs = true
            case let .UpdateChatInputState(peerId, inputState):
                transaction.updatePeerChatInterfaceState(peerId, update: { current in
                    return auxiliaryMethods.updatePeerChatInputState(current, inputState)
                })
            case let .UpdateCall(call):
                updatedCalls.append(call)
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
            Logger.shared.log("State", "adding hole for peer \(messageId.peerId), \(messageId.id) ... \(upperId)")
        } else {
            Logger.shared.log("State", "not adding hole for peer \(messageId.peerId), \(upperId) >= \(messageId.id) = false")
        }
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
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync)
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync)
        } else {
            var syncStickers = false
            var syncMasks = false
            loop: for operation in stickerPackOperations {
                switch operation {
                    case let .add(apiSet):
                        let namespace: ItemCollectionId.Namespace
                        var items: [ItemCollectionItem] = []
                        let info: StickerPackCollectionInfo
                        switch apiSet {
                            case let .stickerSet(set, packs, documents):
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
                                    case let .stickerSet(flags, _, _, _, _, _, _, _, _, _):
                                        if (flags & (1 << 3)) != 0 {
                                            namespace = Namespaces.ItemCollection.CloudMaskPacks
                                        } else {
                                            namespace = Namespaces.ItemCollection.CloudStickerPacks
                                        }
                                }
                            
                                info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
                        }
                        
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
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync)
            }
            if syncMasks {
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync)
            }
        }
    }
    
    if !recentlyUsedStickers.isEmpty {
        let stickerFiles: [TelegramMediaFile] = recentlyUsedStickers.values.sorted(by: {
            return $0.0 < $1.0
        }).map({ $0.1 })
        for file in stickerFiles {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: RecentMediaItem(file)), removeTailIfCountExceeds: 20)
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
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: RecentMediaItem(file)), removeTailIfCountExceeds: 200)
        }
    }
    
    for groupId in invalidateGroupStats {
        transaction.setNeedsPeerGroupMessageStatsSynchronization(groupId: groupId, namespace: Namespaces.Message.Cloud)
    }
    
    for chatPeerId in updatedSecretChatTypingActivities {
        if let peer = transaction.getPeer(chatPeerId) as? TelegramSecretChat {
            let authorId = peer.regularPeerId
            let activityValue: PeerInputActivity? = .typingText
            if updatedTypingActivities[chatPeerId] == nil {
                updatedTypingActivities[chatPeerId] = [authorId: activityValue]
            } else {
                updatedTypingActivities[chatPeerId]![authorId] = activityValue
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
                            if let notificationSettings = transaction.getPeerNotificationSettings(peer.regularPeerId) as? TelegramPeerNotificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
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
        if updatedTypingActivities[chatPeerId] == nil {
            updatedTypingActivities[chatPeerId] = [authorId: activityValue]
        } else {
            updatedTypingActivities[chatPeerId]![authorId] = activityValue
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
            let theme = entry.contents as! TelegramTheme
            if let updatedTheme = updatedThemes[theme.id] {
                return updatedTheme
            } else {
                return theme
            }
        }
        var updatedEntries: [OrderedItemListEntry] = []
        for theme in themes {
            var intValue = Int32(updatedEntries.count)
            let id = MemoryBuffer(data: Data(bytes: &intValue, count: 4))
            updatedEntries.append(OrderedItemListEntry(id: id, contents: theme))
        }
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudThemes, items: updatedEntries)
        let _ = accountManager.transaction { transaction in
            transaction.updateSharedData(SharedDataKeys.themeSettings, { current in
                if let current = current as? ThemeSettings, let theme = current.currentTheme, let updatedTheme = updatedThemes[theme.id] {
                    return ThemeSettings(currentTheme: updatedTheme)
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
    
    return AccountReplayedFinalState(state: finalState, addedIncomingMessageIds: addedIncomingMessageIds, wasScheduledMessageIds: wasScheduledMessageIds, addedSecretMessageIds: addedSecretMessageIds, updatedTypingActivities: updatedTypingActivities, updatedWebpages: updatedWebpages, updatedCalls: updatedCalls, updatedPeersNearby: updatedPeersNearby, isContactUpdates: isContactUpdates, delayNotificatonsUntil: delayNotificatonsUntil)
}
