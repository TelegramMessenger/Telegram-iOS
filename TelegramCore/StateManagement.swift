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

private final class InitialState {
    let state: AuthorizedAccountState.State
    let peerIds: Set<PeerId>
    let messageIds: Set<MessageId>
    let channelStates: [PeerId: ChannelState]
    let peerNotificationSettings: [PeerId: PeerNotificationSettings]
    let peerIdsWithNewMessages: Set<PeerId>
    
    init(state: AuthorizedAccountState.State, peerIds: Set<PeerId>, messageIds: Set<MessageId>, peerIdsWithNewMessages: Set<PeerId>, channelStates: [PeerId: ChannelState], peerNotificationSettings: [PeerId: PeerNotificationSettings]) {
        self.state = state
        self.peerIds = peerIds
        self.messageIds = messageIds
        self.channelStates = channelStates
        self.peerIdsWithNewMessages = peerIdsWithNewMessages
        self.peerNotificationSettings = peerNotificationSettings
    }
}

private enum MutationOperation {
    case AddMessages([StoreMessage], AddMessagesLocation)
    case DeleteMessagesWithGlobalIds([Int32])
    case DeleteMessages([MessageId])
    case UpdateMedia(MediaId, Media?)
    case ReadInbox(MessageId)
    case ReadOutbox(MessageId)
    case ResetReadState(PeerId, MessageId.Namespace, MessageId.Id, MessageId.Id, MessageId.Id, Int32)
    case UpdateState(AuthorizedAccountState.State)
    case UpdateChannelState(PeerId, ChannelState)
    case UpdatePeerNotificationSettings(PeerId, PeerNotificationSettings)
    case AddHole(MessageId)
    case MergeApiChats([Api.Chat])
    case UpdatePeer(PeerId, (Peer) -> Peer)
    case MergeApiUsers([Api.User])
    case MergePeerPresences([PeerId: PeerPresence])
}

private struct MutableState {
    let initialState: InitialState
    let branchOperationIndex: Int
    
    fileprivate var operations: [MutationOperation] = []
    
    fileprivate var state: AuthorizedAccountState.State
    fileprivate var peers: [PeerId: Peer]
    fileprivate var channelStates: [PeerId: ChannelState]
    fileprivate var peerNotificationSettings: [PeerId: PeerNotificationSettings]
    fileprivate var storedMessages: Set<MessageId>
    
    fileprivate var insertedPeers: [PeerId: Peer] = [:]
    
    init(initialState: InitialState, initialPeers: [PeerId: Peer], initialStoredMessages: Set<MessageId>) {
        self.initialState = initialState
        self.state = initialState.state
        self.peers = initialPeers
        self.storedMessages = initialStoredMessages
        self.channelStates = initialState.channelStates
        self.peerNotificationSettings = initialState.peerNotificationSettings
        self.branchOperationIndex = 0
    }
    
    init(initialState: InitialState, operations: [MutationOperation], state: AuthorizedAccountState.State, peers: [PeerId: Peer], channelStates: [PeerId: ChannelState], peerNotificationSettings: [PeerId: PeerNotificationSettings], storedMessages: Set<MessageId>, branchOperationIndex: Int) {
        self.initialState = initialState
        self.operations = operations
        self.state = state
        self.peers = peers
        self.channelStates = channelStates
        self.storedMessages = storedMessages
        self.peerNotificationSettings = peerNotificationSettings
        self.branchOperationIndex = branchOperationIndex
    }
    
    func branch() -> MutableState {
        return MutableState(initialState: self.initialState, operations: self.operations, state: self.state, peers: self.peers, channelStates: self.channelStates, peerNotificationSettings: self.peerNotificationSettings, storedMessages: self.storedMessages, branchOperationIndex: self.operations.count)
    }
    
    mutating func merge(_ other: MutableState) {
        for i in other.branchOperationIndex ..< other.operations.count {
            self.addOperation(other.operations[i])
        }
        for (_, peer) in other.insertedPeers {
            self.peers[peer.id] = peer
        }
    }
    
    mutating func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) {
        self.addOperation(.AddMessages(messages, location))
    }
    
    mutating func deleteMessagesWithGlobalIds(_ globalIds: [Int32]) {
        self.addOperation(.DeleteMessagesWithGlobalIds(globalIds))
    }
    
    mutating func deleteMessages(_ messageIds: [MessageId]) {
        self.addOperation(.DeleteMessages(messageIds))
    }
    
    mutating func updateMedia(_ id: MediaId, media: Media?) {
        self.addOperation(.UpdateMedia(id, media))
    }
    
    mutating func readInbox(_ messageId: MessageId) {
        self.addOperation(.ReadInbox(messageId))
    }
    
    mutating func readOutbox(_ messageId: MessageId) {
        self.addOperation(.ReadOutbox(messageId))
    }
    
    mutating func resetReadState(_ peerId: PeerId, namespace: MessageId.Namespace, maxIncomingReadId: MessageId.Id, maxOutgoingReadId: MessageId.Id, maxKnownId: MessageId.Id, count: Int32) {
        self.addOperation(.ResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count))
    }
    
    mutating func updateState(_ state: AuthorizedAccountState.State) {
        self.addOperation(.UpdateState(state))
    }
    
    mutating func updateChannelState(_ peerId: PeerId, state: ChannelState) {
        self.addOperation(.UpdateChannelState(peerId, state))
    }
    
    mutating func updatePeerNotificationSettings(_ peerId: PeerId, notificationSettings: PeerNotificationSettings) {
        self.addOperation(.UpdatePeerNotificationSettings(peerId, notificationSettings))
    }
    
    mutating func addHole(_ messageId: MessageId) {
        self.addOperation(.AddHole(messageId))
    }
    
    mutating func mergeChats(_ chats: [Api.Chat]) {
        self.addOperation(.MergeApiChats(chats))
    }
    
    mutating func updatePeer(_ id: PeerId, _ f: @escaping (Peer) -> Peer) {
        self.addOperation(.UpdatePeer(id, f))
    }
    
    mutating func mergeUsers(_ users: [Api.User]) {
        self.addOperation(.MergeApiUsers(users))
        
        var presences: [PeerId: PeerPresence] = [:]
        for user in users {
            switch user {
                case let .user(_, id, _, _, _, _, _, _, status, _, _, _):
                    if let status = status {
                        presences[PeerId(namespace: Namespaces.Peer.CloudUser, id: id)] = TelegramUserPresence(apiStatus: status)
                    }
                    break
                case .userEmpty:
                    break
            }
        }
        if !presences.isEmpty {
            self.addOperation(.MergePeerPresences(presences))
        }
    }
    
    mutating func mergePeerPresences(_ presences: [PeerId: PeerPresence]) {
        self.addOperation(.MergePeerPresences(presences))
    }
    
    mutating func addOperation(_ operation: MutationOperation) {
        switch operation {
            case .AddHole, .DeleteMessages, .DeleteMessagesWithGlobalIds, .UpdateMedia, .ReadInbox, .ReadOutbox, .ResetReadState, .MergePeerPresences:
                break
            case let .AddMessages(messages, _):
                for message in messages {
                    if case let .Id(id) = message.id {
                        self.storedMessages.insert(id)
                    }
                }
            case let .UpdateState(state):
                self.state = state
            case let .UpdateChannelState(peerId, channelState):
                self.channelStates[peerId] = channelState
            case let .UpdatePeerNotificationSettings(peerId, notificationSettings):
                self.peerNotificationSettings[peerId] = notificationSettings
            case let .MergeApiChats(chats):
                for chat in chats {
                    if let groupOrChannel = mergeGroupOrChannel(lhs: peers[chat.peerId], rhs: chat) {
                        peers[groupOrChannel.id] = groupOrChannel
                        insertedPeers[groupOrChannel.id] = groupOrChannel
                    }
                }
            case let .MergeApiUsers(users):
                for apiUser in users {
                    if let user = TelegramUser.merge(peers[apiUser.peerId] as? TelegramUser, rhs: apiUser) {
                        peers[user.id] = user
                        insertedPeers[user.id] = user
                    }
                }
            case let .UpdatePeer(id, f):
                if let peer = self.peers[id] {
                    let updatedPeer = f(peer)
                    peers[id] = updatedPeer
                    insertedPeers[id] = updatedPeer
                }
        }
        
        self.operations.append(operation)
    }
}

private struct FinalState {
    let state: MutableState
    let shouldPoll: Bool
    let incomplete: Bool
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
        }
    }
    
    return peerIds
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
            }
    }
    
    return peerIds
}

private func initialStateWithPeerIds(_ modifier: Modifier, peerIds: Set<PeerId>, associatedMessageIds: Set<MessageId>, peerIdsWithNewMessages: Set<PeerId>) -> MutableState {
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
    
    var peerNotificationSettings: [PeerId: PeerNotificationSettings] = [:]
    for peerId in peerIdsWithNewMessages {
        if let notificationSettings = modifier.getPeerNotificationSettings(peerId) {
            peerNotificationSettings[peerId] = notificationSettings
        }
    }
    
    return MutableState(initialState: InitialState(state: (modifier.getState() as? AuthorizedAccountState)!.state!, peerIds: peerIds, messageIds: associatedMessageIds, peerIdsWithNewMessages: peerIdsWithNewMessages, channelStates: channelStates, peerNotificationSettings: peerNotificationSettings), initialPeers: peers, initialStoredMessages: storedMessages)
}

private func initialStateWithUpdateGroups(_ account: Account, groups: [UpdateGroup]) -> Signal<MutableState, NoError> {
    return account.postbox.modify { modifier -> MutableState in
        let peerIds = peerIdsFromUpdateGroups(groups)
        let associatedMessageIds = associatedMessageIdsFromUpdateGroups(groups)
        let peerIdsWithNewMessages = peersWithNewMessagesFromUpdateGroups(groups)
        
        return initialStateWithPeerIds(modifier, peerIds: peerIds, associatedMessageIds: associatedMessageIds, peerIdsWithNewMessages: peerIdsWithNewMessages)
    }
}

private func initialStateWithDifference(_ account: Account, difference: Api.updates.Difference) -> Signal<MutableState, NoError> {
    return account.postbox.modify { modifier -> MutableState in
        let peerIds = peerIdsFromDifference(difference)
        let associatedMessageIds = associatedMessageIdsFromDifference(difference)
        let peerIdsWithNewMessages = peersWithNewMessagesFromDifference(difference)
        return initialStateWithPeerIds(modifier, peerIds: peerIds, associatedMessageIds: associatedMessageIds, peerIdsWithNewMessages: peerIdsWithNewMessages)
    }
}

private func finalStateWithUpdateGroups(_ account: Account, state: MutableState, groups: [UpdateGroup]) -> Signal<FinalState, NoError> {
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
                trace("State", what: "update pts hole: \(update.ptsRange.0) != \(updatedState.state.pts) + \(update.ptsRange.1)")
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
            
            updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: update.qtsRange.1, date: updatedState.state.date, seq: updatedState.state.seq))
        } else {
            if qtsUpdatesAfterHole.count == 0 {
                trace("State", what: "update qts hole: \(update.qtsRange.0) != \(updatedState.state.qts) + \(update.qtsRange.1)")
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
                print("update seq hole: \(group.seqRange.0) != \(updatedState.state.seq) + \(group.seqRange.1)")
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

private func finalStateWithDifference(account: Account, state: MutableState, difference: Api.updates.Difference) -> Signal<FinalState, NoError> {
    var updatedState = state
    
    var messages: [Api.Message] = []
    var updates: [Api.Update] = []
    var chats: [Api.Chat] = []
    var users: [Api.User] = []
    
    switch difference {
        case let .difference(newMessages, _, otherUpdates, apiChats, apiUsers, apiState):
            messages = newMessages
            updates = otherUpdates
            chats = apiChats
            users = apiUsers
            switch apiState {
                case let .state(pts, qts, date, seq, _):
                    updatedState.updateState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq))
            }
        case let .differenceEmpty(date, seq):
            updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: updatedState.state.qts, date: date, seq: seq))
        case let .differenceSlice(newMessages, _, otherUpdates, apiChats, apiUsers, apiState):
            messages = newMessages
            updates = otherUpdates
            chats = apiChats
            users = apiUsers
            switch apiState {
                case let .state(pts, qts, date, seq, _):
                    updatedState.updateState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq))
            }
    }
    
    updatedState.mergeChats(chats)
    updatedState.mergeUsers(users)
    
    for message in messages {
        if let message = StoreMessage(apiMessage: message) {
            updatedState.addMessages([message], location: .UpperHistoryBlock)
        }
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
                default:
                    break
            }
            
            switch rhs {
                case let .updateDeleteChannelMessages(_, _, pts, _):
                    rhsPts = pts
                case let .updateNewChannelMessage(_, pts, _):
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

private func finalStateWithUpdates(account: Account, state: MutableState, updates: [Api.Update], shouldPoll: Bool, missingUpdates: Bool) -> Signal<FinalState, NoError> {
    var updatedState = state
    
    var channelsToPoll = Set<PeerId>()
    
    for update in sortedUpdates(updates) {
        switch update {
            case let .updateChannelTooLong(_, channelId, _):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if !channelsToPoll.contains(peerId) {
                    trace("State", what: "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) updateChannelTooLong")
                    channelsToPoll.insert(peerId)
                }
            case let .updateDeleteChannelMessages(channelId, messages, pts: pts, ptsCount):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                if let previousState = updatedState.channelStates[peerId] {
                    if previousState.pts >= pts {
                        trace("State", what: "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old delete update")
                    } else if previousState.pts + ptsCount == pts {
                        updatedState.deleteMessages(messages.map({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }))
                        updatedState.updateChannelState(peerId, state: previousState.setPts(pts))
                    } else {
                        if !channelsToPoll.contains(peerId) {
                            trace("State", what: "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) delete pts hole")
                            channelsToPoll.insert(peerId)
                            //updatedMissingUpdates = true
                        }
                    }
                } else {
                    if !channelsToPoll.contains(peerId) {
                        trace("State", what: "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) state unknown")
                        channelsToPoll.insert(peerId)
                    }
                }
            case let .updateDeleteMessages(messages, _, _):
                updatedState.deleteMessagesWithGlobalIds(messages)
            case let .updateNewChannelMessage(message, pts, ptsCount):
                if let message = StoreMessage(apiMessage: message) {
                    if let previousState = updatedState.channelStates[message.id.peerId] {
                        if previousState.pts >= pts {
                            trace("State", what: "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) skip old message \(message.id) (\(message.text))")
                        } else if previousState.pts + ptsCount == pts {
                            updatedState.addMessages([message], location: .UpperHistoryBlock)
                            updatedState.updateChannelState(message.id.peerId, state: previousState.setPts(pts))
                        } else {
                            if !channelsToPoll.contains(message.id.peerId) {
                                trace("State", what: "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) message pts hole")
                                ;
                                channelsToPoll.insert(message.id.peerId)
                                //updatedMissingUpdates = true
                            }
                        }
                    } else {
                        if !channelsToPoll.contains(message.id.peerId) {
                            trace("State", what: "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) state unknown")
                            channelsToPoll.insert(message.id.peerId)
                        }
                    }
                }
            case let .updateNewMessage(message, _, _):
                if let message = StoreMessage(apiMessage: message) {
                    updatedState.addMessages([message], location: .UpperHistoryBlock)
                }
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
            default:
                break
        }
    }
    
    var pollChannelSignals: [Signal<MutableState, NoError>] = []
    for peerId in channelsToPoll {
        if let peer = updatedState.peers[peerId] {
            pollChannelSignals.append(pollChannel(account, peer: peer, state: updatedState.branch()))
        } else {
            trace("State", what: "can't poll channel \(peerId): no peer found")
        }
    }
    
    return combineLatest(pollChannelSignals) |> mapToSignal { states -> Signal<FinalState, NoError> in
        var finalState = updatedState
        for state in states {
            finalState.merge(state)
        }
        return resolveAssociatedMessages(account: account, state: finalState)
            |> mapToSignal { resultingState -> Signal<FinalState, NoError> in
                return resolveMissingPeerNotificationSettings(account: account, state: resultingState)
                    |> map { resultingState -> FinalState in
                        return FinalState(state: resultingState, shouldPoll: shouldPoll || missingUpdates, incomplete: missingUpdates)
                    }
            }
    }
}

private func messagesIdsGroupedByPeerId(_ ids: Set<MessageId>) -> [PeerId: [MessageId]] {
    var dict: [PeerId: [MessageId]] = [:]
    
    for id in ids {
        let peerId = id.peerId
        if dict[peerId] == nil {
            dict[peerId] = [id]
        } else {
            dict[peerId]!.append(id)
        }
    }
    
    return dict
}

private func resolveAssociatedMessages(account: Account, state: MutableState) -> Signal<MutableState, NoError> {
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

private func resolveMissingPeerNotificationSettings(account: Account, state: MutableState) -> Signal<MutableState, NoError> {
    var missingPeers: [PeerId: Api.InputPeer] = [:]
    
    for peerId in state.initialState.peerIdsWithNewMessages {
        if state.peerNotificationSettings[peerId] == nil {
            if let peer = state.peers[peerId], let inputPeer = apiInputPeer(peer) {
                missingPeers[peerId] = inputPeer
            } else {
                trace("State", what: "can't fetch notification settings for peer \(peerId): can't create inputPeer")
            }
        }
    }
    
    if missingPeers.isEmpty {
        return .single(state)
    } else {
        trace("State", what: "will fetch notification settings for \(missingPeers.count) peers")
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
            |> map { peersAndSettings -> MutableState in
                var updatedState = state
                for pair in peersAndSettings {
                    if let (peerId, settings) = pair {
                        updatedState.updatePeerNotificationSettings(peerId, notificationSettings: settings)
                    }
                }
                return updatedState
            }
    }
    
    return .single(state)
}

private func pollChannel(_ account: Account, peer: Peer, state: MutableState) -> Signal<MutableState, NoError> {
    if let inputChannel = apiInputChannel(peer) {
        return account.network.request(Api.functions.updates.getChannelDifference(channel: inputChannel, filter: .channelMessagesFilterEmpty, pts: state.channelStates[peer.id]?.pts ?? 1, limit: 20))
            |> retryRequest
            |> map { difference -> MutableState in
                var updatedState = state
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
                        
                        for message in newMessages {
                            if let message = StoreMessage(apiMessage: message) {
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
                    
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message) {
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
                return updatedState
            }
    } else {
        trace("State", what: "can't poll channel \(peer.id): can't create inputChannel")
        return single(state, NoError.self)
    }
}

private func verifyTransaction(_ modifier: Modifier, finalState: MutableState) -> Bool {
    var hadUpdateState = false
    var channelsWithUpdatedStates = Set<PeerId>()
    
    var missingPeerIds: [PeerId] = []
    for peerId in finalState.initialState.peerIds {
        if finalState.peers[peerId] == nil {
            missingPeerIds.append(peerId)
        }
    }
    
    if !missingPeerIds.isEmpty {
        trace("State", what: "missing peers \(missingPeerIds)")
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
            trace("State", what: ".UpdateState previous state \(previousState) doesn't match current state \(currentState)")
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
            trace("State", what: ".UpdateChannelState for \(peerId), previous state \(previousState) doesn't match current state \(currentState)")
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

private func optimizedOperations(_ operations: [MutationOperation]) -> [MutationOperation] {
    var result: [MutationOperation] = []
    
    var updatedState: AuthorizedAccountState.State?
    var updatedChannelStates: [PeerId: ChannelState] = [:]
    
    var currentAddMessages: OptimizeAddMessagesState?
    for operation in operations {
        switch operation {
            case .AddHole, .DeleteMessages, .DeleteMessagesWithGlobalIds, .UpdateMedia, .MergeApiChats, .MergeApiUsers, .MergePeerPresences, .UpdatePeer, .ReadInbox, .ReadOutbox, .ResetReadState, .UpdatePeerNotificationSettings:
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

private func replayFinalState(_ modifier: Modifier, finalState: MutableState) -> Bool {
    let verified = verifyTransaction(modifier, finalState: finalState)
    if !verified { 
        return false
    }
    
    for operation in optimizedOperations(finalState.operations) {
        switch operation {
            case let .AddMessages(messages, location):
                modifier.addMessages(messages, location: location)
            case let .DeleteMessagesWithGlobalIds(ids):
                modifier.deleteMessagesWithGlobalIds(ids)
            case let .DeleteMessages(ids):
                modifier.deleteMessages(ids)
            case let .UpdateMedia(id, media):
                modifier.updateMedia(id, update: media)
            case let .ReadInbox(messageId):
                modifier.applyIncomingReadMaxId(messageId)
            case let .ReadOutbox(messageId):
                modifier.applyOutgoingReadMaxId(messageId)
            case let .ResetReadState(peerId, namespace, maxIncomingReadId, maxOutgoingReadId, maxKnownId, count):
                modifier.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count)]])
            case let .UpdateState(state):
                let currentState = modifier.getState() as! AuthorizedAccountState
                modifier.setState(currentState.changedState(state))
                trace("State", what: "setting state \(state)")
            case let .UpdateChannelState(peerId, channelState):
                modifier.setPeerChatState(peerId, state: channelState)
                trace("State", what: "setting channel \(peerId) \(finalState.peers[peerId]?.displayTitle ?? "nil") state \(channelState)")
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
                modifier.updatePeers(peers, update: { _, updated in
                    return updated
                })
            case let .MergeApiUsers(users):
                var peers: [Peer] = []
                for user in users {
                    if let telegramUser = TelegramUser.merge(modifier.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                        peers.append(telegramUser)
                    }
                }
                modifier.updatePeers(peers, update: { _, updated in
                    return updated
                })
            case let .UpdatePeer(id, f):
                if let peer = modifier.getPeer(id) {
                    modifier.updatePeers([f(peer)], update: { _, updated in
                        return updated
                    })
                }
            case let .MergePeerPresences(presences):
                modifier.updatePeerPresences(presences)
        }
    }
    
    return true
}

private func pollDifference(_ account: Account) -> Signal<Void, NoError> {
    let signal = account.postbox.state()
        |> filter { state in
            if let _ = state as? AuthorizedAccountState {
                return true
            } else {
                return false
            }
        }
        |> take(1)
        |> mapToSignal { state -> Signal<Void, NoError> in
            if let authorizedState = (state as! AuthorizedAccountState).state {
                let request = account.network.request(Api.functions.updates.getDifference(pts: authorizedState.pts, date: authorizedState.date, qts: authorizedState.qts))
                    |> retryRequest
                return request |> mapToSignal { difference -> Signal<Void, NoError> in
                    return initialStateWithDifference(account, difference: difference)
                        |> mapToSignal { state -> Signal<Void, NoError> in
                            if state.initialState.state != authorizedState {
                                trace("State", what: "pollDifference initial state \(authorizedState) != current state \(state.initialState.state)")
                                return pollDifference(account)
                            } else {
                                return finalStateWithDifference(account: account, state: state, difference: difference)
                                    |> mapToSignal { finalState -> Signal<Void, NoError> in
                                        return account.postbox.modify { modifier -> Signal<Void, NoError> in
                                            if replayFinalState(modifier, finalState: finalState.state) {
                                                if case .differenceSlice = difference {
                                                    return pollDifference(account)
                                                } else {
                                                    return complete(Void.self, NoError.self)
                                                }
                                            } else {
                                                return pollDifference(account)
                                            }
                                        } |> switchToLatest
                                    }
                            }
                        }
                }
            } else {
                let appliedState = account.network.request(Api.functions.updates.getState())
                    |> retryRequest
                    |> mapToSignal { state in
                        return account.postbox.modify { modifier in
                            if let currentState = modifier.getState() as? AuthorizedAccountState {
                                switch state {
                                    case let .state(pts, qts, date, seq, _):
                                        modifier.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq)))
                                }
                            }
                        }
                    }
                return appliedState
            }
    }
    return signal
}

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private enum StateManagerState {
    case none
    case pollingDifference
}

private final class StateManagerInternal {
    private let queue = Queue()
    private let account: Account
    
    init(account: Account) {
        self.account = account
    }
    
    
}

public final class StateManager {
    private let stateQueue = Queue()
    
    private let account: Account
    private var updateService: UpdateMessageService?
    
    private let disposable = MetaDisposable()
    private let updatesDisposable = MetaDisposable()
    private let actions = ValuePipe<Signal<Void, NoError>>()
    private var timer: SignalKitTimer?
    
    private var collectingUpdateGroups = false
    private var collectedUpdateGroups: [UpdateGroup] = []
    
    init(account: Account) {
        self.account = account
    }
    
    deinit {
        disposable.dispose()
        self.account.network.mtProto.remove(self.updateService)
        timer?.invalidate()
    }
    
    public func reset() {
        if self.updateService == nil {
            self.updateService = UpdateMessageService(peerId: self.account.peerId)
            updatesDisposable.set(self.updateService!.pipe.signal().start(next: { [weak self] groups in
                if let strongSelf = self {
                    strongSelf.addUpdateGroups(groups)
                }
            }))
            self.account.network.mtProto.add(self.updateService)
        }
        self.collectingUpdateGroups = false
        self.collectedUpdateGroups = []
        self.disposable.set((self.actions.signal() |> queue).start(error: { _ in
            trace("queue error")
        }, completed: {
            trace("queue completed")
        }))
        self.actions.putNext(pollDifference(self.account))
    }
    
    func addUpdates(_ updates: Api.Updates) {
        self.updateService?.addUpdates(updates)
    }
    
    func injectedStateModification<T, E>(_ f: Signal<T, E>) -> Signal<T, E> {
        let pipe = ValuePipe<Event<T, E>>()
        let signal = Signal<Void, NoError> { subscriber in
            return f.start(next: { next in
                pipe.putNext(.Next(next))
            }, error: { error in
                pipe.putNext(.Error(error))
                subscriber.putCompletion()
            }, completed: { 
                pipe.putNext(.Completion)
                subscriber.putCompletion()
            })
        }
        
        return Signal<T, E> { subscriber in
            let disposable = pipe.signal().start(next: { event in
                switch event {
                    case let .Next(next):
                        subscriber.putNext(next)
                    case let .Error(error):
                        subscriber.putError(error)
                    case .Completion:
                        subscriber.putCompletion()
                }
            })
            
            self.actions.putNext(signal)
            
            return disposable
        } |> runOn(self.stateQueue)
    }
    
    private func addUpdateGroups(_ groups: [UpdateGroup]) {
        self.stateQueue.async {
            self.collectedUpdateGroups.append(contentsOf: groups)
            self.scheduleUpdateGroups()
        }
    }
    
    private func beginTimeout() {
        if self.timer == nil {
            self.timer = Timer(timeout: 4.0, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    trace("State", what: "timeout while waiting for updates")
                    strongSelf.reset()
                }
            }, queue: self.stateQueue)
            self.timer?.start()
        }
    }
    
    private func clearTimeout() {
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    private func scheduleUpdateGroups() {
        self.stateQueue.async {
            if !self.collectingUpdateGroups {
                self.collectingUpdateGroups = true
                self.stateQueue.queue.async {
                    self.collectingUpdateGroups = false
                    
                    if self.collectedUpdateGroups.count != 0 {
                        let signal = deferred { [weak self] () -> Signal<Void, NoError> in
                            if let strongSelf = self {
                                let groups = strongSelf.collectedUpdateGroups
                                strongSelf.collectedUpdateGroups = []
                                
                                if groups.count != 0 {
                                    let account = strongSelf.account
                                    let stateQueue = strongSelf.stateQueue
                                    return initialStateWithUpdateGroups(account, groups: groups)
                                        |> mapToSignal { state in
                                            return finalStateWithUpdateGroups(account, state: state, groups: groups)
                                                |> mapToSignal { finalState in
                                                    return account.postbox.modify { modifier -> Bool in
                                                        return replayFinalState(modifier, finalState: finalState.state)
                                                    } |> deliverOn(stateQueue) |> mapToSignal { [weak strongSelf] result in
                                                        if let strongSelf = strongSelf {
                                                            if result && !finalState.shouldPoll {
                                                                if finalState.incomplete {
                                                                    strongSelf.beginTimeout()
                                                                    
                                                                    if !strongSelf.collectedUpdateGroups.isEmpty {
                                                                        var combinedGroups = groups
                                                                        combinedGroups.append(contentsOf: strongSelf.collectedUpdateGroups)
                                                                        strongSelf.collectedUpdateGroups = combinedGroups
                                                                        
                                                                        strongSelf.scheduleUpdateGroups()
                                                                    } else {
                                                                        strongSelf.collectedUpdateGroups = groups
                                                                    }
                                                                } else {
                                                                    strongSelf.clearTimeout()
                                                                }
                                                                return complete(Void.self, NoError.self)
                                                            } else {
                                                                strongSelf.clearTimeout()
                                                                return pollDifference(strongSelf.account)
                                                            }
                                                        }
                                                        return complete(Void.self, NoError.self)
                                                    }
                                                }
                                        }
                                } else {
                                    return complete(Void.self, NoError.self)
                                }
                            } else {
                                return complete(Void.self, NoError.self)
                            }
                        } |> runOn(self.stateQueue)
                    
                        self.actions.putNext(signal)
                    }
                }
            }
        }
    }
}
