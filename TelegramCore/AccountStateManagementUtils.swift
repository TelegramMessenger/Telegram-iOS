import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private func peerIdsFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    for group in groups {
        for update in group.updates {
            for peerId in update.peerIds {
                peerIds.insert(peerId)
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

private func peersWithNewMessagesFromUpdateGroups(_ groups: [UpdateGroup]) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    for group in groups {
        for update in group.updates {
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
        case let .difference(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                for peerId in message.peerIds {
                    peerIds.insert(peerId)
                }
            }
            for update in otherUpdates {
                for peerId in update.peerIds {
                    peerIds.insert(peerId)
                }
            }
        case .differenceEmpty:
            break
        case let .differenceSlice(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                for peerId in message.peerIds {
                    peerIds.insert(peerId)
                }
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

private func associatedMessageIdsFromDifference(_ difference: Api.updates.Difference) -> Set<MessageId> {
    var messageIds = Set<MessageId>()
    
    switch difference {
        case let .difference(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                if let associatedMessageIds = message.associatedMessageIds {
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
                if let associatedMessageIds = message.associatedMessageIds {
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

private func peersWithNewMessagesFromDifference(_ difference: Api.updates.Difference) -> Set<PeerId> {
    var peerIds = Set<PeerId>()
    
    switch difference {
        case let .difference(newMessages, _, otherUpdates, _, _, _):
            for message in newMessages {
                if let messageId = message.id {
                    peerIds.insert(messageId.peerId)
                }
            }
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
                if let messageId = message.id {
                    peerIds.insert(messageId.peerId)
                }
            }
            
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

private func initialStateWithPeerIds(_ modifier: Modifier, peerIds: Set<PeerId>, associatedMessageIds: Set<MessageId>, peerIdsWithNewMessages: Set<PeerId>, locallyGeneratedMessageTimestamps: [PeerId: [(MessageId.Namespace, Int32)]]) -> AccountMutableState {
    var peers: [PeerId: Peer] = [:]
    var channelStates: [PeerId: ChannelState] = [:]
    
    for peerId in peerIds {
        if let peer = modifier.getPeer(peerId) {
            peers[peerId] = peer
        }
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            if let channelState = modifier.getPeerChatState(peerId) as? ChannelState {
                channelStates[peerId] = channelState
            }
        }
    }
    
    let storedMessages = modifier.filterStoredMessageIds(associatedMessageIds)
    var storedMessagesByPeerIdAndTimestamp: [PeerId: Set<MessageIndex>] = [:]
    if !locallyGeneratedMessageTimestamps.isEmpty {
        for (peerId, namespacesAndTimestamps) in locallyGeneratedMessageTimestamps {
            for (namespace, timestamp) in namespacesAndTimestamps {
                if let messageId = modifier.storedMessageId(peerId: peerId, namespace: namespace, timestamp: timestamp) {
                    if storedMessagesByPeerIdAndTimestamp[peerId] == nil {
                        storedMessagesByPeerIdAndTimestamp[peerId] = Set([MessageIndex(id: messageId, timestamp: timestamp)])
                    } else {
                        storedMessagesByPeerIdAndTimestamp[peerId]!.insert(MessageIndex(id: messageId, timestamp: timestamp))
                    }
                }
            }
        }
    }
    
    var peerNotificationSettings: [PeerId: PeerNotificationSettings] = [:]
    var readInboxMaxIds: [PeerId: MessageId] = [:]
    var cloudReadStates: [PeerId: PeerReadState] = [:]
    
    for peerId in peerIdsWithNewMessages {
        if let notificationSettings = modifier.getPeerNotificationSettings(peerId) {
            peerNotificationSettings[peerId] = notificationSettings
        }
        if let readStates = modifier.getPeerReadStates(peerId) {
            for (namespace, state) in readStates {
                if namespace == Namespaces.Message.Cloud {
                    cloudReadStates[peerId] = state
                    switch state {
                        case let .idBased(maxIncomingReadId, _, _, _):
                            readInboxMaxIds[peerId] = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: maxIncomingReadId)
                        case .indexBased:
                            break
                    }
                    break
                }
            }
        }
    }
    
    return AccountMutableState(initialState: AccountInitialState(state: (modifier.getState() as? AuthorizedAccountState)!.state!, peerIds: peerIds, messageIds: associatedMessageIds, peerIdsWithNewMessages: peerIdsWithNewMessages, channelStates: channelStates, peerNotificationSettings: peerNotificationSettings, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestamps, cloudReadStates: cloudReadStates), initialPeers: peers, initialStoredMessages: storedMessages, initialReadInboxMaxIds: readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: storedMessagesByPeerIdAndTimestamp)
}

func initialStateWithUpdateGroups(_ account: Account, groups: [UpdateGroup]) -> Signal<AccountMutableState, NoError> {
    return account.postbox.modify { modifier -> AccountMutableState in
        let peerIds = peerIdsFromUpdateGroups(groups)
        let associatedMessageIds = associatedMessageIdsFromUpdateGroups(groups)
        let peerIdsWithNewMessages = peersWithNewMessagesFromUpdateGroups(groups)
        
        return initialStateWithPeerIds(modifier, peerIds: peerIds, associatedMessageIds: associatedMessageIds, peerIdsWithNewMessages: peerIdsWithNewMessages, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestampsFromUpdateGroups(groups))
    }
}

func initialStateWithDifference(_ account: Account, difference: Api.updates.Difference) -> Signal<AccountMutableState, NoError> {
    return account.postbox.modify { modifier -> AccountMutableState in
        let peerIds = peerIdsFromDifference(difference)
        let associatedMessageIds = associatedMessageIdsFromDifference(difference)
        let peerIdsWithNewMessages = peersWithNewMessagesFromDifference(difference)
        return initialStateWithPeerIds(modifier, peerIds: peerIds, associatedMessageIds: associatedMessageIds, peerIdsWithNewMessages: peerIdsWithNewMessages, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestampsFromDifference(difference))
    }
}

func finalStateWithUpdateGroups(_ account: Account, state: AccountMutableState, groups: [UpdateGroup]) -> Signal<AccountFinalState, NoError> {
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
            case _:
                return false
            }
        case _:
            return false
        }
    })
    
    for group in currentDateGroups {
        switch group {
        case let .withDate(updates, _, users, chats):
            collectedUpdates.append(contentsOf: updates)
            
            updatedState.mergeChats(chats)
            updatedState.mergeUsers(users)
        case _:
            break
        }
    }
    
    return finalStateWithUpdates(account: account, state: updatedState, updates: collectedUpdates, shouldPoll: hadReset, missingUpdates: !ptsUpdatesAfterHole.isEmpty || !qtsUpdatesAfterHole.isEmpty || !seqGroupsAfterHole.isEmpty, shouldResetChannels: true)
}

func finalStateWithDifference(account: Account, state: AccountMutableState, difference: Api.updates.Difference) -> Signal<AccountFinalState, NoError> {
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
    
    return finalStateWithUpdates(account: account, state: updatedState, updates: updates, shouldPoll: false, missingUpdates: false, shouldResetChannels: true)
}

private func sortedUpdates(_ updates: [Api.Update]) -> [Api.Update] {
    var result: [Api.Update] = []
    
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
                if let peerId = message.peerId {
                    if updatesByChannel[peerId] == nil {
                        updatesByChannel[peerId] = [update]
                    } else {
                        updatesByChannel[peerId]!.append(update)
                    }
                } else {
                    result.append(update)
                }
            case let .updateEditChannelMessage(message, _, _):
                if let peerId = message.peerId {
                    if updatesByChannel[peerId] == nil {
                        updatesByChannel[peerId] = [update]
                    } else {
                        updatesByChannel[peerId]!.append(update)
                    }
                } else {
                    result.append(update)
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
                result.append(update)
        }
    }
    
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
    
    return result
}

private func finalStateWithUpdates(account: Account, state: AccountMutableState, updates: [Api.Update], shouldPoll: Bool, missingUpdates: Bool, shouldResetChannels: Bool) -> Signal<AccountFinalState, NoError> {
    var updatedState = state
    
    var channelsToPoll = Set<PeerId>()
    
    for update in sortedUpdates(updates) {
        switch update {
            case let .updateChannelTooLong(_, channelId, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if !channelsToPoll.contains(peerId) {
                    //Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) updateChannelTooLong")
                    channelsToPoll.insert(peerId)
                }
            case let .updateDeleteChannelMessages(channelId, messages, pts: pts, ptsCount):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if let previousState = updatedState.channelStates[peerId] {
                    if previousState.pts >= pts {
                        //Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old delete update")
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
                    if let previousState = updatedState.channelStates[peerId] {
                        if previousState.pts >= pts {
                            //Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old edit update")
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
                if let previousState = updatedState.channelStates[peerId] {
                    if previousState.pts >= pts {
                    } else if previousState.pts + ptsCount == pts {
                        switch apiWebpage {
                            case let .webPageEmpty(id):
                                updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
                            default:
                                if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage) {
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
                }
            case let .updateNewChannelMessage(apiMessage, pts, ptsCount):
                if let message = StoreMessage(apiMessage: apiMessage) {
                    if let previousState = updatedState.channelStates[message.id.peerId] {
                        if previousState.pts >= pts {
                            //Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) skip old message \(message.id) (\(message.text))")
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
            case let .updateServiceNotification(_, date, type, text, media, entities):
                if let date = date {
                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
                    
                    if updatedState.peers[peerId] == nil {
                        updatedState.updatePeer(peerId, { peer in
                            if peer == nil {
                                return TelegramUser(id: peerId, accessHash: nil, firstName: "Telegram Notifications", lastName: nil, username: nil, phone: nil, photo: [], botInfo: BotUserInfo(flags: [], inlinePlaceholder: nil), flags: [.isVerified])
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
                        var messageText = text
                        var medias: [Media] = []
                        
                        let (mediaText, mediaValue, expirationTimer) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                        if let mediaText = mediaText {
                            messageText = mediaText
                        }
                        if let mediaValue = mediaValue {
                            medias.append(mediaValue)
                        }
                        if let expirationTimer = expirationTimer {
                            attributes.append(AutoremoveTimeoutMessageAttribute(timeout: expirationTimer, countdownBeginTime: nil))
                        }
                        
                        let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: nil, timestamp: date, flags: [.Incoming], tags: [], globalTags: [], forwardInfo: nil, authorId: peerId, text: messageText, attributes: attributes, media: [])
                        updatedState.addMessages([message], location: .UpperHistoryBlock)
                    }
                }
                break
            case let .updateReadChannelInbox(channelId, maxId):
                updatedState.readInbox(MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), namespace: Namespaces.Message.Cloud, id: maxId))
            case let .updateReadChannelOutbox(channelId, maxId):
                updatedState.readOutbox(MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), namespace: Namespaces.Message.Cloud, id: maxId))
            case let .updateReadHistoryInbox(peer, maxId, _, _):
                updatedState.readInbox(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: maxId))
            case let .updateReadHistoryOutbox(peer, maxId, _, _):
                updatedState.readOutbox(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: maxId))
            case let .updateWebPage(apiWebpage, _, _):
                switch apiWebpage {
                    case let .webPageEmpty(id):
                        updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
                    default:
                        if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage) {
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
                    default:
                        break
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
                        if updatedParticipants.index(where: { $0.peerId == userPeerId }) == nil {
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
                        if let index = updatedParticipants.index(where: { $0.peerId == userPeerId }) {
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
                        if let index = updatedParticipants.index(where: { $0.peerId == userPeerId }) {
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
            case let .updateChatAdmins(chatId, enabled, version):
                updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId), { peer in
                    if let group = peer as? TelegramGroup {//, group.version == version - 1 {
                        var flags = group.flags
                        switch enabled {
                            case .boolTrue:
                                flags.insert(.adminsEnabled)
                            case .boolFalse:
                                let _ = flags.remove(.adminsEnabled)
                        }
                        return group.updateFlags(flags: flags, version: max(group.version, Int(version)))
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
            case let .updateUserBlocked(userId, unblocked):
                let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                updatedState.updateCachedPeerData(userPeerId, { current in
                    let previous: CachedUserData
                    if let current = current as? CachedUserData {
                        previous = current
                    } else {
                        previous = CachedUserData()
                    }
                    return previous.withUpdatedIsBlocked(unblocked == .boolFalse)
                })
            case let .updateUserStatus(userId, status):
                updatedState.mergePeerPresences([PeerId(namespace: Namespaces.Peer.CloudUser, id: userId): TelegramUserPresence(apiStatus: status)])
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
                        return user.withUpdatedPhone(phone)
                    } else {
                        return peer
                    }
                })
            case let .updateEncryption(chat, date):
                updatedState.updateSecretChat(chat: chat, timestamp: date)
            case let .updateNewEncryptedMessage(message, _):
                updatedState.addSecretMessages([message])
            case let .updateEncryptedMessagesRead(chatId, maxDate, date):
                updatedState.readSecretOutbox(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: chatId), timestamp: maxDate, actionTimestamp: date)
            case let .updateUserTyping(userId, type):
                updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), activity: PeerInputActivity(apiType: type))
            case let .updateChatUserTyping(chatId, userId, type):
                updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), activity: PeerInputActivity(apiType: type))
                updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: chatId), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), activity: PeerInputActivity(apiType: type))
            case let .updateEncryptedChatTyping(chatId):
                updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: chatId), peerId: nil, activity: .typingText)
            case let .updateDialogPinned(flags, peer):
                if (flags & (1 << 0)) != 0 {
                    updatedState.addUpdatePinnedPeerIds(.pin(peer.peerId))
                } else {
                    updatedState.addUpdatePinnedPeerIds(.unpin(peer.peerId))
                }
            case let .updatePinnedDialogs(_, order):
                if let order = order {
                    updatedState.addUpdatePinnedPeerIds(.reorder(order.map { $0.peerId }))
                } else {
                    updatedState.addUpdatePinnedPeerIds(.sync)
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
                        inputState = SynchronizeableChatInputState(replyToMessageId: replyToMessageId, text: message, timestamp: date)
                }
                updatedState.addUpdateChatInputState(peerId: peer.peerId, state: inputState)
            case let .updatePhoneCall(phoneCall):
                updatedState.addUpdateCall(phoneCall)
            case .updateLangPackTooLong:
                updatedState.updateLangPack(nil)
            case let .updateLangPack(difference):
                updatedState.updateLangPack(difference)
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
            let resetSignal = resetChannels(account, peers: channelPeers, state: updatedState)
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
                pollChannelSignals.append(pollChannel(account, peer: peer, state: updatedState.branch()))
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
        return resolveAssociatedMessages(account: account, state: finalState)
            |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                return resolveMissingPeerNotificationSettings(account: account, state: resultingState)
                    |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                        return resolveMissingPeerCloudReadStates(account: account, state: resultingState)
                            |> map { resultingState -> AccountFinalState in
                                return AccountFinalState(state: resultingState, shouldPoll: shouldPoll || hadError, incomplete: missingUpdates)
                            }
                    }
            }
    }
}


private func resolveAssociatedMessages(account: Account, state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    let missingMessageIds = state.initialState.messageIds.subtracting(state.storedMessages)
    if missingMessageIds.isEmpty {
        return .single(state)
    } else {
        var missingPeers = false
        
        var signals: [Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>] = []
        for (peerId, messageIds) in messagesIdsGroupedByPeerId(missingMessageIds) {
            if let peer = state.peers[peerId] {
                var signal: Signal<Api.messages.Messages, MTRpcError>?
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                    signal = account.network.request(Api.functions.messages.getMessages(id: messageIds.map({ $0.id })))
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let inputChannel = apiInputChannel(peer) {
                        signal = account.network.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map({ $0.id })))
                    }
                }
                if let signal = signal {
                    signals.append(signal |> map { result in
                        switch result {
                            case let .messages(messages, chats, users):
                                return (messages, chats, users)
                            case let .messagesSlice(_, messages, chats, users):
                                return (messages, chats, users)
                            case let .channelMessages(_, _, _, messages, chats, users):
                                return (messages, chats, users)
                        }
                    } |> `catch` { _ in
                        return Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>.single(([], [], []))
                    })
                }
            } else {
                missingPeers = true
            }
        }
        if missingPeers {
            
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

private func resolveMissingPeerNotificationSettings(account: Account, state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    var missingPeers: [PeerId: Api.InputPeer] = [:]
    
    for peerId in state.initialState.peerIdsWithNewMessages {
        if state.peerNotificationSettings[peerId] == nil {
            if let peer = state.peers[peerId], let inputPeer = apiInputPeer(peer) {
                missingPeers[peerId] = inputPeer
            } else {
                Logger.shared.log("State", "can't fetch notification settings for peer \(peerId): can't create inputPeer")
            }
        }
    }
    
    if missingPeers.isEmpty {
        return .single(state)
    } else {
        Logger.shared.log("State", "will fetch notification settings for \(missingPeers.count) peers")
        var signals: [Signal<(PeerId, PeerNotificationSettings)?, NoError>] = []
        for (peerId, peer) in missingPeers {
            let fetchSettings = account.network.request(Api.functions.account.getNotifySettings(peer: .inputNotifyPeer(peer: peer)))
                |> map { settings -> (PeerId, PeerNotificationSettings)? in
                    return (peerId, TelegramPeerNotificationSettings(apiSettings: settings))
                }
                |> `catch` { _ -> Signal<(PeerId, PeerNotificationSettings)?, NoError> in
                    return .single(nil)
                }
            signals.append(fetchSettings)
        }
        return combineLatest(signals)
            |> map { peersAndSettings -> AccountMutableState in
                var updatedState = state
                for pair in peersAndSettings {
                    if let (peerId, settings) = pair {
                        updatedState.updateNotificationSettings(.peer(peerId), notificationSettings: settings)
                    }
                }
                return updatedState
            }
    }
}

private func resolveMissingPeerCloudReadStates(account: Account, state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    var missingPeers: [PeerId: Api.InputPeer] = [:]
    
    for peerId in state.initialState.peerIdsWithNewMessages {
        if state.initialState.cloudReadStates[peerId] == nil && (peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup) {
            if let peer = state.peers[peerId], let inputPeer = apiInputPeer(peer) {
                missingPeers[peerId] = inputPeer
            } else {
                Logger.shared.log("State", "can't fetch notification settings for peer \(peerId): can't create inputPeer")
            }
        }
    }
    
    if missingPeers.isEmpty {
        return .single(state)
    } else {
        Logger.shared.log("State", "will fetch cloud read states for \(missingPeers.count) peers")
        
        var signals: [Signal<(PeerId, PeerReadState)?, NoError>] = []
        for (peerId, inputPeer) in missingPeers {
            let fetchSettings = fetchPeerCloudReadState(network: account.network, postbox: account.postbox, peerId: peerId, inputPeer: inputPeer)
                |> map { state -> (PeerId, PeerReadState)? in
                    return state.flatMap { (peerId, $0) }
                }
            signals.append(fetchSettings)
        }
        return combineLatest(signals)
            |> map { peersAndSettings -> AccountMutableState in
                var updatedState = state
                for pair in peersAndSettings {
                    if let (peerId, state) = pair {
                        if case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count) = state {
                            updatedState.resetReadState(peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count)
                        }
                    }
                }
                return updatedState
        }
    }
}

func keepPollingChannel(account: Account, peerId: PeerId, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let accountState = (modifier.getState() as? AuthorizedAccountState)?.state, let peer = modifier.getPeer(peerId) {
            var channelStates: [PeerId: ChannelState] = [:]
            if let channelState = modifier.getPeerChatState(peerId) as? ChannelState {
                channelStates[peerId] = channelState
            }
            let initialPeers: [PeerId: Peer] = [peerId: peer]
            var peerNotificationSettings: [PeerId: TelegramPeerNotificationSettings] = [:]
            if let notificationSettings = modifier.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings {
                peerNotificationSettings[peerId] = notificationSettings
            }
            let initialState = AccountMutableState(initialState: AccountInitialState(state: accountState, peerIds: Set(), messageIds: Set(), peerIdsWithNewMessages: Set(), channelStates: channelStates, peerNotificationSettings: peerNotificationSettings, locallyGeneratedMessageTimestamps: [:], cloudReadStates: [:]), initialPeers: initialPeers, initialStoredMessages: Set(), initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:])
            return pollChannel(account, peer: peer, state: initialState)
                |> mapToSignal { (finalState, _, timeout) -> Signal<Void, NoError> in
                    return resolveAssociatedMessages(account: account, state: finalState)
                        |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                            return resolveMissingPeerNotificationSettings(account: account, state: resultingState)
                                |> map { resultingState -> AccountFinalState in
                                    return AccountFinalState(state: resultingState, shouldPoll: false, incomplete: false)
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
            return .complete() |> delay(30.0, queue: Queue.concurrentDefaultQueue())
        }
    } |> switchToLatest |> restart
}

private func resetChannels(_ account: Account, peers: [Peer], state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    var inputPeers: [Api.InputPeer] = []
    for peer in peers {
        if let inputPeer = apiInputPeer(peer) {
            inputPeers.append(inputPeer)
        }
    }
    return account.network.request(Api.functions.messages.getPeerDialogs(peers: inputPeers))
        |> retryRequest
        |> map { result -> AccountMutableState in
            var updatedState = state
            
            var dialogsChats: [Api.Chat] = []
            var dialogsUsers: [Api.User] = []
            
            var storeMessages: [StoreMessage] = []
            var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
            var mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
            var channelStates: [PeerId: ChannelState] = [:]
            var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
            
            switch result {
                case let .peerDialogs(dialogs, messages, chats, users, _):
                    dialogsChats.append(contentsOf: chats)
                    dialogsUsers.append(contentsOf: users)
                    
                    for dialog in dialogs {
                        let apiPeer: Api.Peer
                        let apiReadInboxMaxId: Int32
                        let apiReadOutboxMaxId: Int32
                        let apiTopMessage: Int32
                        let apiUnreadCount: Int32
                        let apiUnreadMentionsCount: Int32
                        var apiChannelPts: Int32?
                        let apiNotificationSettings: Api.PeerNotifySettings
                        switch dialog {
                            case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, peerNotificationSettings, pts, _):
                                apiPeer = peer
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                                apiUnreadMentionsCount = unreadMentionsCount
                                apiNotificationSettings = peerNotificationSettings
                                apiChannelPts = pts
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
                        readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount)
                        
                        if apiTopMessage != 0 {
                            mentionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                        }
                        
                        if let apiChannelPts = apiChannelPts {
                            channelStates[peerId] = ChannelState(pts: apiChannelPts, invalidatedPts: apiChannelPts)
                        }
                        
                        notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                    }
                    
                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message) {
                            storeMessages.append(storeMessage)
                        }
                    }
            }
            
            updatedState.mergeChats(dialogsChats)
            updatedState.mergeUsers(dialogsUsers)
            
            for message in storeMessages {
                if case let .Id(id) = message.id {
                    updatedState.addHole(MessageId(peerId: id.peerId, namespace: Namespaces.Message.Cloud, id: Int32.max))
                }
            }
            
            updatedState.addMessages(storeMessages, location: .UpperHistoryBlock)
            
            for (peerId, peerReadStates) in readStates {
                for (namespace, state) in peerReadStates {
                    switch state {
                        case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, count):
                            updatedState.resetReadState(peerId, namespace: namespace, maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count)
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
            
            return updatedState
        }
}

private func pollChannel(_ account: Account, peer: Peer, state: AccountMutableState) -> Signal<(AccountMutableState, Bool, Int32?), NoError> {
    if let inputChannel = apiInputChannel(peer) {
        var limit: Int32 = 20
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            limit = 3
        #endif
        return (account.network.request(Api.functions.updates.getChannelDifference(flags: 0, channel: inputChannel, filter: .channelMessagesFilterEmpty, pts: state.channelStates[peer.id]?.pts ?? 1, limit: limit))
            |> map { Optional($0) }
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
                            if let previousState = updatedState.channelStates[peer.id] {
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
                                                if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage) {
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
                            if let previousState = updatedState.channelStates[peer.id] {
                                channelState = previousState.withUpdatedPts(pts)
                            } else {
                                channelState = ChannelState(pts: pts, invalidatedPts: nil)
                            }
                            updatedState.updateChannelState(peer.id, state: channelState)
                        case let .channelDifferenceTooLong(_, pts, timeout, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, messages, chats, users):
                            apiTimeout = timeout
                            
                            let channelState = ChannelState(pts: pts, invalidatedPts: pts)
                            updatedState.updateChannelState(peer.id, state: channelState)
                            
                            updatedState.mergeChats(chats)
                            updatedState.mergeUsers(users)
                            
                            updatedState.addHole(MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32.max))
                        
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
                        
                            updatedState.resetReadState(peer.id, namespace: Namespaces.Message.Cloud, maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount)
                        
                            updatedState.resetMessageTagSummary(peer.id, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                    }
                }
                return (updatedState, difference != nil, apiTimeout)
            }
    } else {
        Logger.shared.log("State", "can't poll channel \(peer.id): can't create inputChannel")
        return single((state, true, nil), NoError.self)
    }
}

private func verifyTransaction(_ modifier: Modifier, finalState: AccountMutableState) -> Bool {
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
        let currentState = (modifier.getState() as? AuthorizedAccountState)?.state
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
        let currentState = modifier.getPeerChatState(peerId)
        var previousStateMatches = false
        let previousState = finalState.initialState.channelStates[peerId]
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
    for operation in operations {
        switch operation {
            case .AddHole, .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpdateMedia, .MergeApiChats, .MergeApiUsers, .MergePeerPresences, .UpdatePeer, .ReadInbox, .ReadOutbox, .ResetReadState, .ResetMessageTagSummary, .UpdateNotificationSettings, .UpdateGlobalNotificationSettings, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity, .UpdateCachedPeerData, .UpdatePinnedPeerIds, .ReadMessageContents, .UpdateMessageImpressionCount, .UpdateInstalledStickerPacks, .UpdateChatInputState, .UpdateCall, .UpdateLangPack, .UpdateMinAvailableMessage:
                if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
                    result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
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
        }
    }
    if let currentAddMessages = currentAddMessages, !currentAddMessages.messages.isEmpty {
        result.append(.AddMessages(currentAddMessages.messages, currentAddMessages.location))
    }
    
    if let updatedState = updatedState {
        result.append(.UpdateState(updatedState))
    }
    
    for (peerId, state) in updatedChannelStates {
        result.append(.UpdateChannelState(peerId, state))
    }
    
    return result
}

func replayFinalState(accountPeerId: PeerId, mediaBox: MediaBox, modifier: Modifier, auxiliaryMethods: AccountAuxiliaryMethods, finalState: AccountFinalState) -> AccountReplayedFinalState? {
    let verified = verifyTransaction(modifier, finalState: finalState.state)
    if !verified { 
        return nil
    }
    
    var peerIdsWithAddedSecretMessages = Set<PeerId>()
    
    var updatedTypingActivities: [PeerId: [PeerId: PeerInputActivity?]] = [:]
    var updatedSecretChatTypingActivities = Set<PeerId>()
    var updatedWebpages: [MediaId: TelegramMediaWebpage] = [:]
    var updatedCalls: [Api.PhoneCall] = []
    var stickerPackOperations: [AccountStateUpdateStickerPacksOperation] = []
    var langPackDifferences: [Api.LangPackDifference] = []
    var pollLangPack = false
    
    for operation in optimizedOperations(finalState.state.operations) {
        switch operation {
            case let .AddMessages(messages, location):
                let _ = modifier.addMessages(messages, location: location)
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
                    }
                }
            case let .DeleteMessagesWithGlobalIds(ids):
                modifier.deleteMessagesWithGlobalIds(ids)
            case let .DeleteMessages(ids):
                modifier.deleteMessages(ids)
            case let .UpdateMinAvailableMessage(id):
                modifier.deleteMessagesInRange(peerId: id.peerId, namespace: id.namespace, minId: 1, maxId: id.id)
            case let .EditMessage(id, message):
                modifier.updateMessage(id, update: { _ in .update(message) })
            case let .UpdateMedia(id, media):
                modifier.updateMedia(id, update: media)
                if let media = media as? TelegramMediaWebpage {
                    updatedWebpages[id] = media
                }
            case let .ReadInbox(messageId):
                modifier.applyIncomingReadMaxId(messageId)
            case let .ReadOutbox(messageId):
                modifier.applyOutgoingReadMaxId(messageId)
            case let .ResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count):
                modifier.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count)]])
            case let .ResetMessageTagSummary(peerId, namespace, count, range):
                modifier.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: namespace, count: count, maxId: range.maxId)
            case let .UpdateState(state):
                let currentState = modifier.getState() as! AuthorizedAccountState
                modifier.setState(currentState.changedState(state))
            case let .UpdateChannelState(peerId, channelState):
                modifier.setPeerChatState(peerId, state: channelState)
            case let .UpdateNotificationSettings(subject, notificationSettings):
                switch subject {
                    case let .peer(peerId):
                        modifier.updateCurrentPeerNotificationSettings([peerId: notificationSettings])
                }
            case let .UpdateGlobalNotificationSettings(subject, notificationSettings):
                switch subject {
                    case .privateChats:
                        modifier.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            var previous: GlobalNotificationSettings
                            if let current = current as? GlobalNotificationSettings {
                                previous = current
                            } else {
                                previous = GlobalNotificationSettings.defaultSettings
                            }
                            return GlobalNotificationSettings(toBeSynchronized: previous.toBeSynchronized, remote: previous.remote.withUpdatedPrivateChats { _ in
                                return notificationSettings
                            })
                        })
                    case .groups:
                        modifier.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { current in
                            var previous: GlobalNotificationSettings
                            if let current = current as? GlobalNotificationSettings {
                                previous = current
                            } else {
                                previous = GlobalNotificationSettings.defaultSettings
                            }
                            return GlobalNotificationSettings(toBeSynchronized: previous.toBeSynchronized, remote: previous.remote.withUpdatedGroupChats { _ in
                                return notificationSettings
                            })
                        })
                }
            case let .AddHole(messageId):
                modifier.addHole(messageId)
            case let .MergeApiChats(chats):
                var peers: [Peer] = []
                for chat in chats {
                    if let groupOrChannel = mergeGroupOrChannel(lhs: modifier.getPeer(chat.peerId), rhs: chat) {
                        peers.append(groupOrChannel)
                    }
                }
                updatePeers(modifier: modifier, peers: peers, update: { _, updated in
                    return updated
                })
            case let .MergeApiUsers(users):
                var peers: [Peer] = []
                for user in users {
                    if let telegramUser = TelegramUser.merge(modifier.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                        peers.append(telegramUser)
                    }
                }
                updatePeers(modifier: modifier, peers: peers, update: { _, updated in
                    return updated
                })
            case let .UpdatePeer(id, f):
                if let peer = f(modifier.getPeer(id)) {
                    updatePeers(modifier: modifier, peers: [peer], update: { _, updated in
                        return updated
                    })
                }
            case let .UpdateCachedPeerData(id, f):
                modifier.updatePeerCachedData(peerIds: Set([id]), update: { _, current in
                    return f(current)
                })
            case let .MergePeerPresences(presences):
                modifier.updatePeerPresences(presences)
            case let .UpdateSecretChat(chat, _):
                updateSecretChat(accountPeerId: accountPeerId, modifier: modifier, chat: chat, requestData: nil)
            case let .AddSecretMessages(messages):
                for message in messages {
                    let peerId = message.peerId
                    modifier.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingEncrypted, tagLocalIndex: .automatic, tagMergedIndex: .none, contents: SecretChatIncomingEncryptedOperation(message: message))
                    peerIdsWithAddedSecretMessages.insert(peerId)
                }
            case let .ReadSecretOutbox(peerId, maxTimestamp, actionTimestamp):
                applyOutgoingReadMaxIndex(modifier: modifier, index: MessageIndex.upperBound(peerId: peerId, timestamp: maxTimestamp, namespace: Namespaces.Message.Local), beginAt: actionTimestamp)
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
            case let .UpdatePinnedPeerIds(pinnedOperation):
                switch pinnedOperation {
                    case let .pin(peerId):
                        if modifier.getPeer(peerId) == nil || modifier.getPeerChatListInclusion(peerId) == .notSpecified {
                            addSynchronizePinnedChatsOperation(modifier: modifier)
                        } else {
                            var currentPeerIds = modifier.getPinnedPeerIds()
                            if !currentPeerIds.contains(peerId) {
                                currentPeerIds.insert(peerId, at: 0)
                                modifier.setPinnedPeerIds(currentPeerIds)
                            }
                        }
                    case let .unpin(peerId):
                        var currentPeerIds = modifier.getPinnedPeerIds()
                        if let index = currentPeerIds.index(of: peerId) {
                            currentPeerIds.remove(at: index)
                            modifier.setPinnedPeerIds(currentPeerIds)
                        } else {
                            addSynchronizePinnedChatsOperation(modifier: modifier)
                        }
                    case let .reorder(peerIds):
                        let currentPeerIds = modifier.getPinnedPeerIds()
                        if Set(peerIds) == Set(currentPeerIds) {
                            modifier.setPinnedPeerIds(peerIds)
                        } else {
                            addSynchronizePinnedChatsOperation(modifier: modifier)
                        }
                    case .sync:
                        addSynchronizePinnedChatsOperation(modifier: modifier)
                }
            case let .ReadMessageContents(peerId, messageIds):
                if let peerId = peerId {
                    for id in messageIds {
                        markMessageContentAsConsumedRemotely(modifier: modifier, messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id))
                    }
                } else {
                    for messageId in modifier.messageIdsForGlobalIds(messageIds) {
                        markMessageContentAsConsumedRemotely(modifier: modifier, messageId: messageId)
                    }
                }
            case let .UpdateMessageImpressionCount(id, count):
                modifier.updateMessage(id, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                    }
                    var attributes = currentMessage.attributes
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ViewCountMessageAttribute {
                            attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(count)))
                            break loop
                        }
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            case let .UpdateInstalledStickerPacks(operation):
                stickerPackOperations.append(operation)
            case let .UpdateChatInputState(peerId, inputState):
                modifier.updatePeerChatInterfaceState(peerId, update: { current in
                    return auxiliaryMethods.updatePeerChatInputState(current, inputState)
                })
            case let .UpdateCall(call):
                updatedCalls.append(call)
            case let .UpdateLangPack(difference):
                if let difference = difference {
                    langPackDifferences.append(difference)
                } else {
                    pollLangPack = true
                }
        }
    }
    
    if !stickerPackOperations.isEmpty {
        if stickerPackOperations.contains(where: {
            if case .sync = $0 {
                return true
            } else {
                return false
            }
        }) {
            addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: .stickers)
            addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: .masks)
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
                                    case let .stickerSet(flags, _, _, _, _, _, _):
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
                        
                        var updatedInfos = modifier.getItemCollectionsInfos(namespace: info.id.namespace).map { $0.1 as! StickerPackCollectionInfo }
                        if let index = updatedInfos.index(where: { $0.id == info.id }) {
                            let currentInfo = updatedInfos[index]
                            updatedInfos.remove(at: index)
                            updatedInfos.insert(currentInfo, at: 0)
                        } else {
                            updatedInfos.insert(info, at: 0)
                            modifier.replaceItemCollectionItems(collectionId: info.id, items: items)
                        }
                        modifier.replaceItemCollectionInfos(namespace: info.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                    case let .reorder(namespace, ids):
                        let collectionNamespace: ItemCollectionId.Namespace
                        switch namespace {
                            case .stickers:
                                collectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
                            case .masks:
                                collectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
                        }
                        let currentInfos = modifier.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
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
                            modifier.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                        }
                    case .sync:
                        syncStickers = true
                        syncMasks = true
                        break loop
                }
            }
            if syncStickers {
                addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: .stickers)
            }
            if syncMasks {
                addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: .masks)
            }
        }
    }
    
    for chatPeerId in updatedSecretChatTypingActivities {
        if let peer = modifier.getPeer(chatPeerId) as? TelegramSecretChat {
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
        while true {
            let keychain = (modifier.getPeerChatState(peerId) as? SecretChatState)?.keychain
            if processSecretChatIncomingEncryptedOperations(modifier: modifier, peerId: peerId) {
                let processResult = processSecretChatIncomingDecryptedOperations(mediaBox: mediaBox, modifier: modifier, peerId: peerId)
                if !processResult.addedMessages.isEmpty {
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
            let updatedKeychain = (modifier.getPeerChatState(peerId) as? SecretChatState)?.keychain
            if updatedKeychain == keychain {
                break
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
    
    if pollLangPack {
        addSynchronizeLocalizationUpdatesOperation(modifier: modifier)
    } else if !langPackDifferences.isEmpty {
        langPackDifferences.sort(by: { lhs, rhs in
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
        
        for difference in langPackDifferences {
            if !tryApplyingLanguageDifference(modifier: modifier, difference: difference) {
                addSynchronizeLocalizationUpdatesOperation(modifier: modifier)
                break
            }
        }
    }
    
    return AccountReplayedFinalState(state: finalState, addedSecretMessageIds: addedSecretMessageIds, updatedTypingActivities: updatedTypingActivities, updatedWebpages: updatedWebpages, updatedCalls: updatedCalls)
}
