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

private enum Event<T, E> {
    case Next(T)
    case Error(E)
    case Completion
}

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
        case let .differenceTooLong(pts):
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
    
    for peerId in peerIdsWithNewMessages {
        if let notificationSettings = modifier.getPeerNotificationSettings(peerId) {
            peerNotificationSettings[peerId] = notificationSettings
        }
        if let readStates = modifier.getPeerReadStates(peerId) {
            for (namespace, state) in readStates {
                if namespace == Namespaces.Message.Cloud {
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
    
    return AccountMutableState(initialState: AccountInitialState(state: (modifier.getState() as? AuthorizedAccountState)!.state!, peerIds: peerIds, messageIds: associatedMessageIds, peerIdsWithNewMessages: peerIdsWithNewMessages, channelStates: channelStates, peerNotificationSettings: peerNotificationSettings, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestamps), initialPeers: peers, initialStoredMessages: storedMessages, initialReadInboxMaxIds: readInboxMaxIds, storedMessagesByPeerIdAndTimestamp: storedMessagesByPeerIdAndTimestamp)
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
    
    return finalStateWithUpdates(account: account, state: updatedState, updates: collectedUpdates, shouldPoll: hadReset, missingUpdates: !ptsUpdatesAfterHole.isEmpty || !qtsUpdatesAfterHole.isEmpty || !seqGroupsAfterHole.isEmpty)
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
    
    return finalStateWithUpdates(account: account, state: updatedState, updates: updates, shouldPoll: false, missingUpdates: false)
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

private func finalStateWithUpdates(account: Account, state: AccountMutableState, updates: [Api.Update], shouldPoll: Bool, missingUpdates: Bool) -> Signal<AccountFinalState, NoError> {
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
                        updatedState.updateChannelState(peerId, state: previousState.setPts(pts))
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
                            updatedState.editMessage(messageId, message: message)
                            updatedState.updateChannelState(peerId, state: previousState.setPts(pts))
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
                        
                        updatedState.updateChannelState(peerId, state: previousState.setPts(pts))
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
                            updatedState.addMessages([message], location: .UpperHistoryBlock)
                            updatedState.updateChannelState(message.id.peerId, state: previousState.setPts(pts))
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
                if let date = date {
                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
                    
                    if updatedState.peers[peerId] == nil {
                        updatedState.updatePeer(peerId, { peer in
                            if peer == nil {
                                return TelegramUser(id: peerId, accessHash: nil, firstName: "Telegram Notifications", lastName: nil, username: nil, phone: nil, photo: [], botInfo: BotUserInfo(flags: [], inlinePlaceholder: nil))
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
                        
                        let (mediaText, mediaValue) = textAndMediaFromApiMedia(media)
                        if let mediaText = mediaText {
                            messageText = mediaText
                        }
                        if let mediaValue = mediaValue {
                            medias.append(mediaValue)
                        }
                        
                        let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: nil, timestamp: date, flags: [.Incoming], tags: [], forwardInfo: nil, authorId: peerId, text: messageText, attributes: attributes, media: [])
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
                let notificationSettings = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                switch apiPeer {
                    case let .notifyPeer(peer):
                        updatedState.updatePeerNotificationSettings(peer.peerId, notificationSettings: notificationSettings)
                        break
                    default:
                        break
                }
            case let .updateChatParticipants(participants):
                break
            case let .updateChatParticipantAdd(chatId, userId, inviterId, date, version):
                break
            case let .updateChatParticipantDelete(chatId, userId, version):
                break
            case let .updateChatParticipantAdmin(chatId, userId, isAdmin, version):
                break
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
            case let .updateUserStatus(userId, status):
                updatedState.mergePeerPresences([PeerId(namespace: Namespaces.Peer.CloudUser, id: userId): TelegramUserPresence(apiStatus: status)])
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
            case let .updateEncryptedChatTyping(chatId):
                updatedState.addPeerInputActivity(chatPeerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: chatId), peerId: nil, activity: .typingText)
            default:
                    break
        }
    }
    
    var pollChannelSignals: [Signal<(AccountMutableState, Bool), NoError>] = []
    for peerId in channelsToPoll {
        if let peer = updatedState.peers[peerId] {
            pollChannelSignals.append(pollChannel(account, peer: peer, state: updatedState.branch()))
        } else {
            Logger.shared.log("State", "can't poll channel \(peerId): no peer found")
        }
    }
    
    return combineLatest(pollChannelSignals) |> mapToSignal { states -> Signal<AccountFinalState, NoError> in
        var finalState = updatedState
        var hadError = false
        for (state, success) in states {
            finalState.merge(state)
            if !success {
                hadError = true
            }
        }
        return resolveAssociatedMessages(account: account, state: finalState)
            |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                return resolveMissingPeerNotificationSettings(account: account, state: resultingState)
                    |> map { resultingState -> AccountFinalState in
                        return AccountFinalState(state: resultingState, shouldPoll: shouldPoll || hadError, incomplete: missingUpdates)
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
                        updatedState.updatePeerNotificationSettings(peerId, notificationSettings: settings)
                    }
                }
                return updatedState
            }
    }
}

private func pollChannel(_ account: Account, peer: Peer, state: AccountMutableState) -> Signal<(AccountMutableState, Bool), NoError> {
    if let inputChannel = apiInputChannel(peer) {
        return (account.network.request(Api.functions.updates.getChannelDifference(flags: 0, channel: inputChannel, filter: .channelMessagesFilterEmpty, pts: state.channelStates[peer.id]?.pts ?? 1, limit: 20))
            |> map { Optional($0) }
            |> `catch` { error -> Signal<Api.updates.ChannelDifference?, MTRpcError> in
                if error.errorDescription == "CHANNEL_PRIVATE" {
                    return .single(nil)
                } else {
                    return .fail(error)
                }
            })
            |> retryRequest
            |> map { difference -> (AccountMutableState, Bool) in
                var updatedState = state
                if let difference = difference {
                    switch difference {
                        case let .channelDifference(_, pts, _, newMessages, otherUpdates, chats, users):
                            let channelState: ChannelState
                            if let previousState = updatedState.channelStates[peer.id] {
                                channelState = previousState.setPts(pts)
                            } else {
                                channelState = ChannelState(pts: pts)
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
                                    default:
                                        break
                                }
                            }
                        case let .channelDifferenceEmpty(_, pts, _):
                            let channelState: ChannelState
                            if let previousState = updatedState.channelStates[peer.id] {
                                channelState = previousState.setPts(pts)
                            } else {
                                channelState = ChannelState(pts: pts)
                            }
                            updatedState.updateChannelState(peer.id, state: channelState)
                        case let .channelDifferenceTooLong(_, pts, _, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, messages, chats, users):
                            let channelState: ChannelState
                            if let previousState = updatedState.channelStates[peer.id] {
                                channelState = previousState.setPts(pts)
                            } else {
                                channelState = ChannelState(pts: pts)
                            }
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
                    }
                }
                return (updatedState, difference != nil)
            }
    } else {
        Logger.shared.log("State", "can't poll channel \(peer.id): can't create inputChannel")
        return single((state, true), NoError.self)
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
            Logger.shared.log("State", ".UpdateChannelState for \(peerId), previous state \(previousState) doesn't match current state \(String(describing: currentState))")
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
            case .AddHole, .DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage, .UpdateMedia, .MergeApiChats, .MergeApiUsers, .MergePeerPresences, .UpdatePeer, .ReadInbox, .ReadOutbox, .ResetReadState, .UpdatePeerNotificationSettings, .UpdateSecretChat, .AddSecretMessages, .ReadSecretOutbox, .AddPeerInputActivity:
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

func replayFinalState(mediaBox: MediaBox, modifier: Modifier, finalState: AccountFinalState) -> AccountReplayedFinalState? {
    let verified = verifyTransaction(modifier, finalState: finalState.state)
    if !verified { 
        return nil
    }
    
    var peerIdsWithAddedSecretMessages = Set<PeerId>()
    
    var updatedTypingActivities: [PeerId: [PeerId: PeerInputActivity?]] = [:]
    var updatedSecretChatTypingActivities = Set<PeerId>()
    
    for operation in optimizedOperations(finalState.state.operations) {
        switch operation {
            case let .AddMessages(messages, location):
                modifier.addMessages(messages, location: location)
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
            case let .EditMessage(id, message):
                modifier.updateMessage(id, update: { _ in message })
            case let .UpdateMedia(id, media):
                modifier.updateMedia(id, update: media)
            case let .ReadInbox(messageId):
                modifier.applyIncomingReadMaxId(messageId)
            case let .ReadOutbox(messageId):
                modifier.applyOutgoingReadMaxId(messageId)
            case let .ResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count):
                modifier.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count)]])
            case let .UpdateState(state):
                let currentState = modifier.getState() as! AuthorizedAccountState
                modifier.setState(currentState.changedState(state))
            case let .UpdateChannelState(peerId, channelState):
                modifier.setPeerChatState(peerId, state: channelState)
            case let .UpdatePeerNotificationSettings(peerId, notificationSettings):
                modifier.updatePeerNotificationSettings([peerId: notificationSettings])
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
            case let .MergePeerPresences(presences):
                modifier.updatePeerPresences(presences)
            case let .UpdateSecretChat(chat, timestamp):
                let currentPeer = modifier.getPeer(chat.peerId) as? TelegramSecretChat
                let currentState = modifier.getPeerChatState(chat.peerId) as? SecretChatState
                assert((currentPeer == nil) == (currentState == nil))
                switch chat {
                    case let .encryptedChat(_, accessHash, date, adminId, participantId, gAOrB, keyFingerprint):
                        break
                    case .encryptedChatDiscarded(_):
                        if let currentPeer = currentPeer, let currentState = currentState {
                            let state = currentState.withUpdatedEmbeddedState(.terminated)
                            let peer = currentPeer.withUpdatedEmbeddedState(state.embeddedState.peerState)
                            updatePeers(modifier: modifier, peers: [peer], update: { _, updated in return updated })
                            modifier.setPeerChatState(peer.id, state: state)
                            modifier.operationLogRemoveAllEntries(peerId: peer.id, tag: OperationLogTags.SecretOutgoing)
                        } else {
                            Logger.shared.log("State", "got encryptedChatDiscarded, but peer doesn't exist")
                        }
                    case .encryptedChatEmpty(_):
                        break
                    case let .encryptedChatRequested(_, accessHash, date, adminId, participantId, gA):
                        if currentPeer == nil {
                            let state = SecretChatState(role: .participant, embeddedState: .handshake, keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
                            let peer = TelegramSecretChat(id: chat.peerId, creationDate: date, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: adminId), accessHash: accessHash, embeddedState: state.embeddedState.peerState, messageAutoremoveTimeout: nil)
                            updatePeers(modifier: modifier, peers: [peer], update: { _, updated in return updated })
                            modifier.resetIncomingReadStates([peer.id: [
                                Namespaces.Message.SecretIncoming: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0),
                                Namespaces.Message.Local: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peer.id), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peer.id), count: 0)
                                ]
                            ])
                            let bBytes = malloc(256)!
                            let randomStatus = SecRandomCopyBytes(nil, 256, bBytes.assumingMemoryBound(to: UInt8.self))
                            let b = MemoryBuffer(memory: bBytes, capacity: 256, length: 256, freeWhenDone: true)
                            if randomStatus == 0 {
                                let updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: peer.id, operation: .initialHandshakeAccept(gA: MemoryBuffer(gA), accessHash: accessHash, b: b), state: state)
                                modifier.setPeerChatState(peer.id, state: state)
                            } else {
                                assertionFailure()
                            }
                        } else {
                            Logger.shared.log("State", "got encryptedChatRequested, but peer already exists")
                        }
                    case let .encryptedChatWaiting(_, accessHash, date, adminId, participantId):
                        break
                }
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
    
    return AccountReplayedFinalState(state: finalState, addedSecretMessageIds: addedSecretMessageIds, updatedTypingActivities: updatedTypingActivities)
}
