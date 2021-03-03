import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import SyncCore

public struct GroupCallInfo: Equatable {
    public var id: Int64
    public var accessHash: Int64
    public var participantCount: Int
    public var clientParams: String?
    public var streamDcId: Int32?
    public var title: String?
    public var recordingStartTimestamp: Int32?
    
    public init(
        id: Int64,
        accessHash: Int64,
        participantCount: Int,
        clientParams: String?,
        streamDcId: Int32?,
        title: String?,
        recordingStartTimestamp: Int32?
    ) {
        self.id = id
        self.accessHash = accessHash
        self.participantCount = participantCount
        self.clientParams = clientParams
        self.streamDcId = streamDcId
        self.title = title
        self.recordingStartTimestamp = recordingStartTimestamp
    }
}

public struct GroupCallSummary: Equatable {
    public var info: GroupCallInfo
    public var topParticipants: [GroupCallParticipantsContext.Participant]
}

extension GroupCallInfo {
    init?(_ call: Api.GroupCall) {
        switch call {
        case let .groupCall(_, id, accessHash, participantCount, params, title, recordStartDate, streamDcId, _):
            var clientParams: String?
            if let params = params {
                switch params {
                case let .dataJSON(data):
                    clientParams = data
                }
            }
            self.init(
                id: id,
                accessHash: accessHash,
                participantCount: Int(participantCount),
                clientParams: clientParams,
                streamDcId: streamDcId,
                title: title,
                recordingStartTimestamp: recordStartDate
            )
        case .groupCallDiscarded:
            return nil
        }
    }
}

public enum GetCurrentGroupCallError {
    case generic
}

public func getCurrentGroupCall(account: Account, callId: Int64, accessHash: Int64) -> Signal<GroupCallSummary?, GetCurrentGroupCallError> {
    return account.network.request(Api.functions.phone.getGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
    |> mapError { _ -> GetCurrentGroupCallError in
        return .generic
    }
    |> mapToSignal { result -> Signal<GroupCallSummary?, GetCurrentGroupCallError> in
        switch result {
        case let .groupCall(call, participants, _, chats, users):
            return account.postbox.transaction { transaction -> GroupCallSummary? in
                guard let info = GroupCallInfo(call) else {
                    return nil
                }
                
                var peers: [Peer] = []
                var peerPresences: [PeerId: PeerPresence] = [:]
                
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    if let presence = TelegramUserPresence(apiUser: user) {
                        peerPresences[telegramUser.id] = presence
                    }
                }
                
                for chat in chats {
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(peer)
                    }
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
                var parsedParticipants: [GroupCallParticipantsContext.Participant] = []
                
                loop: for participant in participants {
                    switch participant {
                    case let .groupCallParticipant(flags, apiPeerId, date, activeDate, source, volume, about):
                        
                        let peerId: PeerId
                        switch apiPeerId {
                            case let .peerUser(userId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            case let .peerChat(chatId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                            case let .peerChannel(channelId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        }
                        
                        let ssrc = UInt32(bitPattern: source)
                        guard let peer = transaction.getPeer(peerId) else {
                            continue loop
                        }
                        let muted = (flags & (1 << 0)) != 0
                        let mutedByYou = (flags & (1 << 9)) != 0
                        var muteState: GroupCallParticipantsContext.Participant.MuteState?
                        if muted {
                            let canUnmute = (flags & (1 << 2)) != 0
                            muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canUnmute, mutedByYou: mutedByYou)
                        } else if mutedByYou {
                            muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: mutedByYou)
                        }
                        var jsonParams: String?
                        /*if let params = params {
                            switch params {
                            case let .dataJSON(data):
                                jsonParams = data
                            }
                        }*/
                        parsedParticipants.append(GroupCallParticipantsContext.Participant(
                            peer: peer,
                            ssrc: ssrc,
                            jsonParams: jsonParams,
                            joinTimestamp: date,
                            activityTimestamp: activeDate.flatMap(Double.init),
                            activityRank: nil,
                            muteState: muteState,
                            volume: volume,
                            about: about
                        ))
                    }
                }
                
                return GroupCallSummary(
                    info: info,
                    topParticipants: parsedParticipants
                )
            }
            |> mapError { _ -> GetCurrentGroupCallError in
            }
        }
    }
}

public enum CreateGroupCallError {
    case generic
    case anonymousNotAllowed
}

public func createGroupCall(account: Account, peerId: PeerId, joinAs: PeerId?) -> Signal<GroupCallInfo, CreateGroupCallError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer?, Api.InputPeer?) in
        let callPeer = transaction.getPeer(peerId).flatMap(apiInputPeer)
        if let joinAs = joinAs {
            return (callPeer, transaction.getPeer(joinAs).flatMap(apiInputPeer))
        } else {
            return (callPeer, nil)
        }
    }
    |> castError(CreateGroupCallError.self)
    |> mapToSignal { (inputPeer, inputJoinAs) -> Signal<GroupCallInfo, CreateGroupCallError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        
        var flags: Int32 = 0
        if let _ = inputJoinAs {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.phone.createGroupCall(flags: flags, peer: inputPeer, joinAs: inputJoinAs, randomId: Int32.random(in: Int32.min ... Int32.max)))
        |> mapError { error -> CreateGroupCallError in
            if error.errorDescription == "ANONYMOUS_CALLS_DISABLED" {
                return .anonymousNotAllowed
            }
            return .generic
        }
        |> mapToSignal { result -> Signal<GroupCallInfo, CreateGroupCallError> in
            var parsedCall: GroupCallInfo?
            loop: for update in result.allUpdates {
                switch update {
                case let .updateGroupCall(_, call):
                    parsedCall = GroupCallInfo(call)
                    break loop
                default:
                    break
                }
            }
            
            guard let callInfo = parsedCall else {
                return .fail(.generic)
            }
            
            return account.postbox.transaction { transaction -> GroupCallInfo in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                    if let cachedData = cachedData as? CachedChannelData {
                        return cachedData.withUpdatedActiveCall(CachedChannelData.ActiveCall(id: callInfo.id, accessHash: callInfo.accessHash))
                    } else if let cachedData = cachedData as? CachedGroupData {
                        return cachedData.withUpdatedActiveCall(CachedChannelData.ActiveCall(id: callInfo.id, accessHash: callInfo.accessHash))
                    } else {
                        return cachedData
                    }
                })
                
                account.stateManager.addUpdates(result)
                
                return callInfo
            }
            |> castError(CreateGroupCallError.self)
        }
    }
}

public enum GetGroupCallParticipantsError {
    case generic
}

public func getGroupCallParticipants(account: Account, callId: Int64, accessHash: Int64, offset: String, ssrcs: [UInt32], limit: Int32) -> Signal<GroupCallParticipantsContext.State, GetGroupCallParticipantsError> {
    return account.network.request(Api.functions.phone.getGroupParticipants(call: .inputGroupCall(id: callId, accessHash: accessHash), ids: [], sources: ssrcs.map { Int32(bitPattern: $0) }, offset: offset, limit: limit))
    |> mapError { _ -> GetGroupCallParticipantsError in
        return .generic
    }
    |> mapToSignal { result -> Signal<GroupCallParticipantsContext.State, GetGroupCallParticipantsError> in
        return account.postbox.transaction { transaction -> GroupCallParticipantsContext.State in
            var parsedParticipants: [GroupCallParticipantsContext.Participant] = []
            let totalCount: Int
            let version: Int32
            let nextParticipantsFetchOffset: String?
            
            switch result {
            case let .groupParticipants(count, participants, nextOffset, chats, users, apiVersion):
                totalCount = Int(count)
                version = apiVersion
                
                if participants.count != 0 && !nextOffset.isEmpty {
                    nextParticipantsFetchOffset = nextOffset
                } else {
                    nextParticipantsFetchOffset = nil
                }
                
                var peers: [Peer] = []
                var peerPresences: [PeerId: PeerPresence] = [:]
                
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    if let presence = TelegramUserPresence(apiUser: user) {
                        peerPresences[telegramUser.id] = presence
                    }
                }
                
                for chat in chats {
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(peer)
                    }
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
                loop: for participant in participants {
                    switch participant {
                    case let .groupCallParticipant(flags, apiPeerId, date, activeDate, source, volume, about):
                        
                        let peerId: PeerId
                        switch apiPeerId {
                            case let .peerUser(userId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            case let .peerChat(chatId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                            case let .peerChannel(channelId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        }
                        let ssrc = UInt32(bitPattern: source)
                        guard let peer = transaction.getPeer(peerId) else {
                            continue loop
                        }
                        let muted = (flags & (1 << 0)) != 0
                        let mutedByYou = (flags & (1 << 9)) != 0
                        var muteState: GroupCallParticipantsContext.Participant.MuteState?
                        if muted {
                            let canUnmute = (flags & (1 << 2)) != 0
                            muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canUnmute, mutedByYou: mutedByYou)
                        } else if mutedByYou {
                            muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: mutedByYou)
                        }
                        var jsonParams: String?
                        /*if let params = params {
                            switch params {
                            case let .dataJSON(data):
                                jsonParams = data
                            }
                        }*/
                        parsedParticipants.append(GroupCallParticipantsContext.Participant(
                            peer: peer,
                            ssrc: ssrc,
                            jsonParams: jsonParams,
                            joinTimestamp: date,
                            activityTimestamp: activeDate.flatMap(Double.init),
                            activityRank: nil,
                            muteState: muteState,
                            volume: volume,
                            about: about
                        ))
                    }
                }
            }
            
            parsedParticipants.sort()
            
            return GroupCallParticipantsContext.State(
                participants: parsedParticipants,
                nextParticipantsFetchOffset: nextParticipantsFetchOffset,
                adminIds: Set(),
                isCreator: false,
                defaultParticipantsAreMuted: GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: false, canChange: false),
                recordingStartTimestamp: nil,
                title: nil,
                totalCount: totalCount,
                version: version
            )
        }
        |> castError(GetGroupCallParticipantsError.self)
    }
}

public enum JoinGroupCallError {
    case generic
    case anonymousNotAllowed
    case tooManyParticipants
}

public struct JoinGroupCallResult {
    public var callInfo: GroupCallInfo
    public var state: GroupCallParticipantsContext.State
}

public func joinGroupCall(account: Account, peerId: PeerId, joinAs: PeerId?, callId: Int64, accessHash: Int64, preferMuted: Bool, joinPayload: String) -> Signal<JoinGroupCallResult, JoinGroupCallError> {
    
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        if let joinAs = joinAs {
            return transaction.getPeer(joinAs).flatMap(apiInputPeer)
        } else {
            return .inputPeerSelf
        }
    }
    |> castError(JoinGroupCallError.self)
    |> mapToSignal { inputJoinAs in
        
        var flags: Int32 = 0
        if preferMuted {
            flags |= (1 << 0)
        }
        
        if let _ = inputJoinAs {
            flags |= (1 << 1)
        }
        
        return account.network.request(Api.functions.phone.joinGroupCall(flags: flags, call: .inputGroupCall(id: callId, accessHash: accessHash), joinAs: inputJoinAs, params: .dataJSON(data: joinPayload)))
        |> mapError { error -> JoinGroupCallError in
            if error.errorDescription == "GROUPCALL_ANONYMOUS_FORBIDDEN" {
                return .anonymousNotAllowed
            } else if error.errorDescription == "GROUPCALL_PARTICIPANTS_TOO_MUCH" {
                return .tooManyParticipants
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<JoinGroupCallResult, JoinGroupCallError> in
            let admins: Signal<(Set<PeerId>, [Api.User]), JoinGroupCallError>
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                admins = account.postbox.transaction { transaction -> Api.InputChannel? in
                    return transaction.getPeer(peerId).flatMap(apiInputChannel)
                }
                |> castError(JoinGroupCallError.self)
                |> mapToSignal { inputChannel -> Signal<Api.channels.ChannelParticipants, JoinGroupCallError> in
                    guard let inputChannel = inputChannel else {
                        return .fail(.generic)
                    }
                    
                    return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsAdmins, offset: 0, limit: 100, hash: 0))
                    |> mapError { _ -> JoinGroupCallError in
                        return .generic
                    }
                }
                |> map { admins -> (Set<PeerId>, [Api.User]) in
                    var adminIds = Set<PeerId>()
                    var apiUsers: [Api.User] = []
                    
                    switch admins {
                    case let .channelParticipants(_, participants, users):
                        apiUsers.append(contentsOf: users)
                        
                        for participant in participants {
                            let parsedParticipant = ChannelParticipant(apiParticipant: participant)
                            switch parsedParticipant {
                            case .creator:
                                adminIds.insert(parsedParticipant.peerId)
                            case let .member(_, _, adminInfo, _, _):
                                if let adminInfo = adminInfo, adminInfo.rights.rights.contains(.canManageCalls) {
                                    adminIds.insert(parsedParticipant.peerId)
                                }
                            }
                        }
                    default:
                        break
                    }
                    
                    return (adminIds, apiUsers)
                }
            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                admins = account.postbox.transaction { transaction -> (Set<PeerId>, [Api.User]) in
                    var result = Set<PeerId>()
                    if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedGroupData {
                        if let participants = cachedData.participants {
                            for participant in participants.participants {
                                if case .creator = participant {
                                    result.insert(participant.peerId)
                                } else if case .admin = participant {
                                    result.insert(participant.peerId)
                                }
                            }
                        }
                    }
                    return (result, [])
                }
                |> castError(JoinGroupCallError.self)
            } else {
                admins = .fail(.generic)
            }
            
            let peer = account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            |> castError(JoinGroupCallError.self)
            
            return combineLatest(
                account.network.request(Api.functions.phone.getGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
                |> mapError { _ -> JoinGroupCallError in
                    return .generic
                },
                getGroupCallParticipants(account: account, callId: callId, accessHash: accessHash, offset: "", ssrcs: [], limit: 100)
                |> mapError { _ -> JoinGroupCallError in
                    return .generic
                },
                admins,
                peer
            )
            |> mapToSignal { result, state, admins, peer -> Signal<JoinGroupCallResult, JoinGroupCallError> in
                guard let peer = peer else {
                    return .fail(.generic)
                }
                
                var state = state
                if let channel = peer as? TelegramChannel {
                    state.isCreator = channel.flags.contains(.isCreator)
                } else if let group = peer as? TelegramGroup {
                    if case .creator = group.role {
                        state.isCreator = true
                    } else {
                        state.isCreator = false
                    }
                }
                
                account.stateManager.addUpdates(updates)
                
                var maybeParsedCall: GroupCallInfo?
                loop: for update in updates.allUpdates {
                    switch update {
                    case let .updateGroupCall(_, call):
                        maybeParsedCall = GroupCallInfo(call)
                        
                        switch call {
                        case let .groupCall(flags, _, _, _, _, title, streamDcId, recordStartDate, _):
                            let isMuted = (flags & (1 << 1)) != 0
                            let canChange = (flags & (1 << 2)) != 0
                            state.defaultParticipantsAreMuted = GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: isMuted, canChange: canChange)
                            state.title = title
                            state.recordingStartTimestamp = recordStartDate
                        default:
                            break
                        }
                        
                        break loop
                    default:
                        break
                    }
                }
                
                guard let parsedCall = maybeParsedCall else {
                    return .fail(.generic)
                }
                
                var apiUsers: [Api.User] = []
                
                let (adminIds, adminUsers) = admins
                apiUsers.append(contentsOf: adminUsers)
                
                state.adminIds = adminIds
                
                switch result {
                case let .groupCall(call, _, _, chats, users):
                    guard let _ = GroupCallInfo(call) else {
                        return .fail(.generic)
                    }
                    
                    apiUsers.append(contentsOf: users)
                    
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    
                    for user in apiUsers {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
                        }
                    }
                    
                    for chat in chats {
                        if let peer = parseTelegramGroupOrChannel(chat: chat) {
                            peers.append(peer)
                        }
                    }
                    
                    return account.postbox.transaction { transaction -> JoinGroupCallResult in
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                        
                        return JoinGroupCallResult(
                            callInfo: parsedCall,
                            state: state
                        )
                    }
                    |> castError(JoinGroupCallError.self)
                }
            }
        }
    }
    
}

public enum LeaveGroupCallError {
    case generic
}

public func leaveGroupCall(account: Account, callId: Int64, accessHash: Int64, source: UInt32) -> Signal<Never, LeaveGroupCallError> {
    return account.network.request(Api.functions.phone.leaveGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash), source: Int32(bitPattern: source)))
    |> mapError { _ -> LeaveGroupCallError in
        return .generic
    }
    |> mapToSignal { result -> Signal<Never, LeaveGroupCallError> in
        account.stateManager.addUpdates(result)
        
        return .complete()
    }
}

public enum StopGroupCallError {
    case generic
}

public func stopGroupCall(account: Account, peerId: PeerId, callId: Int64, accessHash: Int64) -> Signal<Never, StopGroupCallError> {
    return account.network.request(Api.functions.phone.discardGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
    |> mapError { _ -> StopGroupCallError in
        return .generic
    }
    |> mapToSignal { result -> Signal<Never, StopGroupCallError> in
        return account.postbox.transaction { transaction -> Void in
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.withUpdatedActiveCall(nil)
                } else if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.withUpdatedActiveCall(nil)
                } else {
                    return cachedData
                }
            })
            if var peer = transaction.getPeer(peerId) as? TelegramChannel {
                var flags = peer.flags
                flags.remove(.hasVoiceChat)
                flags.remove(.hasActiveVoiceChat)
                peer = peer.withUpdatedFlags(flags)
                updatePeers(transaction: transaction, peers: [peer], update: { _, updated in
                    return updated
                })
            }
            if var peer = transaction.getPeer(peerId) as? TelegramGroup {
                var flags = peer.flags
                flags.remove(.hasVoiceChat)
                flags.remove(.hasActiveVoiceChat)
                peer = peer.updateFlags(flags: flags, version: peer.version)
                updatePeers(transaction: transaction, peers: [peer], update: { _, updated in
                    return updated
                })
            }
            
            account.stateManager.addUpdates(result)
        }
        |> castError(StopGroupCallError.self)
        |> ignoreValues
    }
}

public enum CheckGroupCallResult {
    case success
    case restart
}

public func checkGroupCall(account: Account, callId: Int64, accessHash: Int64, ssrc: Int32) -> Signal<CheckGroupCallResult, NoError> {
    return account.network.request(Api.functions.phone.checkGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash), source: ssrc))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> map { result -> CheckGroupCallResult in
        switch result {
        case .boolTrue:
            return .success
        case .boolFalse:
            return .restart
        }
    }
}

private func binaryInsertionIndex(_ inputArr: [GroupCallParticipantsContext.Participant], searchItem: Int32) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if inputArr[mid].joinTimestamp < searchItem {
            lo = mid + 1
        } else if searchItem < inputArr[mid].joinTimestamp {
            hi = mid - 1
        } else {
            return mid
        }
    }
    return lo
}

public final class GroupCallParticipantsContext {
    public struct Participant: Equatable, Comparable {
        public struct MuteState: Equatable {
            public var canUnmute: Bool
            public var mutedByYou: Bool
            
            public init(canUnmute: Bool, mutedByYou: Bool) {
                self.canUnmute = canUnmute
                self.mutedByYou = mutedByYou
            }
        }
        
        public var peer: Peer
        public var ssrc: UInt32
        public var jsonParams: String?
        public var joinTimestamp: Int32
        public var activityTimestamp: Double?
        public var activityRank: Int?
        public var muteState: MuteState?
        public var volume: Int32?
        public var about: String?
        public init(
            peer: Peer,
            ssrc: UInt32,
            jsonParams: String?,
            joinTimestamp: Int32,
            activityTimestamp: Double?,
            activityRank: Int?,
            muteState: MuteState?,
            volume: Int32?,
            about: String?
        ) {
            self.peer = peer
            self.ssrc = ssrc
            self.jsonParams = jsonParams
            self.joinTimestamp = joinTimestamp
            self.activityTimestamp = activityTimestamp
            self.activityRank = activityRank
            self.muteState = muteState
            self.volume = volume
            self.about = about
        }
        
        public static func ==(lhs: Participant, rhs: Participant) -> Bool {
            if !lhs.peer.isEqual(rhs.peer) {
                return false
            }
            if lhs.ssrc != rhs.ssrc {
                return false
            }
            if lhs.joinTimestamp != rhs.joinTimestamp {
                return false
            }
            if lhs.activityTimestamp != rhs.activityTimestamp {
                return false
            }
            if lhs.activityRank != rhs.activityRank {
                return false
            }
            if lhs.muteState != rhs.muteState {
                return false
            }
            if lhs.volume != rhs.volume {
                return false
            }
            if lhs.about != rhs.about {
                return false
            }
            return true
        }
        
        public static func <(lhs: Participant, rhs: Participant) -> Bool {
            if let lhsActivityRank = lhs.activityRank, let rhsActivityRank = rhs.activityRank {
                if lhsActivityRank != rhsActivityRank {
                    return lhsActivityRank < rhsActivityRank
                }
            } else if lhs.activityRank != nil {
                return true
            } else if rhs.activityRank != nil {
                return false
            }
            
            if let lhsActivityTimestamp = lhs.activityTimestamp, let rhsActivityTimestamp = rhs.activityTimestamp {
                if lhsActivityTimestamp != rhsActivityTimestamp {
                    return lhsActivityTimestamp > rhsActivityTimestamp
                }
            } else if lhs.activityTimestamp != nil {
                return true
            } else if rhs.activityTimestamp != nil {
                return false
            }
            
            if lhs.joinTimestamp != rhs.joinTimestamp {
                return lhs.joinTimestamp > rhs.joinTimestamp
            }
            
            return lhs.peer.id < rhs.peer.id
        }
    }
    
    public struct State: Equatable {
        public struct DefaultParticipantsAreMuted: Equatable {
            public var isMuted: Bool
            public var canChange: Bool
        }
        
        public var participants: [Participant]
        public var nextParticipantsFetchOffset: String?
        public var adminIds: Set<PeerId>
        public var isCreator: Bool
        public var defaultParticipantsAreMuted: DefaultParticipantsAreMuted
        public var recordingStartTimestamp: Int32?
        public var title: String?
        public var totalCount: Int
        public var version: Int32
    }
    
    private struct OverlayState: Equatable {
        struct MuteStateChange: Equatable {
            var state: Participant.MuteState?
            var volume: Int32?
            var disposable: Disposable
            
            static func ==(lhs: MuteStateChange, rhs: MuteStateChange) -> Bool {
                if lhs.state != rhs.state {
                    return false
                }
                if lhs.volume != rhs.volume {
                    return false
                }
                if lhs.disposable !== rhs.disposable {
                    return false
                }
                return true
            }
        }
        
        var pendingMuteStateChanges: [PeerId: MuteStateChange] = [:]
        
        var isEmpty: Bool {
            if !self.pendingMuteStateChanges.isEmpty {
                return false
            }
            return true
        }
    }
    
    private struct InternalState: Equatable {
        var state: State
        var overlayState: OverlayState
    }
    
    public enum Update {
        public struct StateUpdate {
            public struct ParticipantUpdate {
                public enum ParticipationStatusChange {
                    case none
                    case joined
                    case left
                }
                
                public var peerId: PeerId
                public var ssrc: UInt32
                public var jsonParams: String?
                public var joinTimestamp: Int32
                public var activityTimestamp: Double?
                public var muteState: Participant.MuteState?
                public var participationStatusChange: ParticipationStatusChange
                public var volume: Int32?
                public var about: String?
                init(
                    peerId: PeerId,
                    ssrc: UInt32,
                    jsonParams: String?,
                    joinTimestamp: Int32,
                    activityTimestamp: Double?,
                    muteState: Participant.MuteState?,
                    participationStatusChange: ParticipationStatusChange,
                    volume: Int32?,
                    about: String?
                ) {
                    self.peerId = peerId
                    self.ssrc = ssrc
                    self.jsonParams = jsonParams
                    self.joinTimestamp = joinTimestamp
                    self.activityTimestamp = activityTimestamp
                    self.muteState = muteState
                    self.participationStatusChange = participationStatusChange
                    self.volume = volume
                    self.about = about
                }
            }
            
            public var participantUpdates: [ParticipantUpdate]
            public var version: Int32
            
            public var removePendingMuteStates: Set<PeerId>
        }
        
        case state(update: StateUpdate)
        case call(isTerminated: Bool, defaultParticipantsAreMuted: State.DefaultParticipantsAreMuted, title: String?, recordingStartTimestamp: Int32?)
    }
    
    public final class MemberEvent {
        public let peerId: PeerId
        public let joined: Bool
        
        public init(peerId: PeerId, joined: Bool) {
            self.peerId = peerId
            self.joined = joined
        }
    }
    
    private let account: Account
    private let id: Int64
    private let accessHash: Int64
    
    private var hasReceivedSpeakingParticipantsReport: Bool = false
    
    private var stateValue: InternalState {
        didSet {
            if self.stateValue != oldValue {
                self.statePromise.set(self.stateValue)
            }
        }
    }
    private let statePromise: ValuePromise<InternalState>
    
    public var state: Signal<State, NoError> {
        return self.statePromise.get()
        |> map { state -> State in
            if state.overlayState.isEmpty {
                return state.state
            }
            var publicState = state.state
            for i in 0 ..< publicState.participants.count {
                if let pendingMuteState = state.overlayState.pendingMuteStateChanges[publicState.participants[i].peer.id] {
                    publicState.participants[i].muteState = pendingMuteState.state
                    publicState.participants[i].volume = pendingMuteState.volume
                }
            }
            return publicState
        }
    }
    
    private var activeSpeakersValue: Set<PeerId> = Set() {
        didSet {
            if self.activeSpeakersValue != oldValue {
                self.activeSpeakersPromise.set(self.activeSpeakersValue)
            }
        }
    }
    private let activeSpeakersPromise = ValuePromise<Set<PeerId>>(Set())
    public var activeSpeakers: Signal<Set<PeerId>, NoError> {
        return self.activeSpeakersPromise.get()
    }
    
    private let memberEventsPipe = ValuePipe<MemberEvent>()
    public var memberEvents: Signal<MemberEvent, NoError> {
        return self.memberEventsPipe.signal()
    }
    
    private var updateQueue: [Update.StateUpdate] = []
    private var isProcessingUpdate: Bool = false
    private let disposable = MetaDisposable()
    
    private let updatesDisposable = MetaDisposable()
    private var activitiesDisposable: Disposable?
    
    private var isLoadingMore: Bool = false
    private var shouldResetStateFromServer: Bool = false
    private var missingSsrcs = Set<UInt32>()
    
    private var nextActivityRank: Int = 0
    private var activityRankResetTimer: SwiftSignalKit.Timer?
    
    private let updateDefaultMuteDisposable = MetaDisposable()
    private let updateShouldBeRecordingDisposable = MetaDisposable()
    
    public init(account: Account, peerId: PeerId, id: Int64, accessHash: Int64, state: State) {
        self.account = account
        self.id = id
        self.accessHash = accessHash
        self.stateValue = InternalState(state: state, overlayState: OverlayState())
        self.statePromise = ValuePromise<InternalState>(self.stateValue)
        
        self.updatesDisposable.set((self.account.stateManager.groupCallParticipantUpdates
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let strongSelf = self else {
                return
            }
            var filteredUpdates: [Update] = []
            for (callId, update) in updates {
                if callId == id {
                    filteredUpdates.append(update)
                }
            }
            if !filteredUpdates.isEmpty {
                strongSelf.addUpdates(updates: filteredUpdates)
            }
        }))
        
        let activityCategory: PeerActivitySpace.Category = .voiceChat
        self.activitiesDisposable = (self.account.peerInputActivities(peerId: PeerActivitySpace(peerId: peerId, category: activityCategory))
        |> deliverOnMainQueue).start(next: { [weak self] activities in
            guard let strongSelf = self else {
                return
            }
        
            let peerIds = Set(activities.map { item -> PeerId in
                item.0
            })
            strongSelf.activeSpeakersValue = peerIds
            
            if !strongSelf.hasReceivedSpeakingParticipantsReport {
                var updatedParticipants = strongSelf.stateValue.state.participants
                var indexMap: [PeerId: Int] = [:]
                for i in 0 ..< updatedParticipants.count {
                    indexMap[updatedParticipants[i].peer.id] = i
                }
                var updated = false
                
                for (activityPeerId, activity) in activities {
                    if case let .speakingInGroupCall(intTimestamp) = activity {
                        let timestamp = Double(intTimestamp)
                        
                        if let index = indexMap[activityPeerId] {
                            if let activityTimestamp = updatedParticipants[index].activityTimestamp {
                                if activityTimestamp < timestamp {
                                    updatedParticipants[index].activityTimestamp = timestamp
                                    updated = true
                                }
                            } else {
                                updatedParticipants[index].activityTimestamp = timestamp
                                updated = true
                            }
                        }
                    }
                }
                
                if updated {
                    updatedParticipants.sort()
                    /*for i in 0 ..< updatedParticipants.count {
                        if updatedParticipants[i].peer.id == strongSelf.account.peerId {
                            let member = updatedParticipants[i]
                            updatedParticipants.remove(at: i)
                            updatedParticipants.insert(member, at: 0)
                            break
                        }
                    }*/
                    
                    strongSelf.stateValue = InternalState(
                        state: State(
                            participants: updatedParticipants,
                            nextParticipantsFetchOffset: strongSelf.stateValue.state.nextParticipantsFetchOffset,
                            adminIds: strongSelf.stateValue.state.adminIds,
                            isCreator: strongSelf.stateValue.state.isCreator,
                            defaultParticipantsAreMuted: strongSelf.stateValue.state.defaultParticipantsAreMuted,
                            recordingStartTimestamp: strongSelf.stateValue.state.recordingStartTimestamp,
                            title: strongSelf.stateValue.state.title,
                            totalCount: strongSelf.stateValue.state.totalCount,
                            version: strongSelf.stateValue.state.version
                        ),
                        overlayState: strongSelf.stateValue.overlayState
                    )
                }
            }
        })
        
        self.activityRankResetTimer = SwiftSignalKit.Timer(timeout: 10.0, repeat: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            var updated = false
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            
            for i in 0 ..< strongSelf.stateValue.state.participants.count {
                if strongSelf.stateValue.state.participants[i].activityRank != nil {
                    var clearRank = false
                    if let activityTimestamp = strongSelf.stateValue.state.participants[i].activityTimestamp {
                        if activityTimestamp < timestamp - 60.0 {
                            clearRank = true
                        }
                    } else {
                        clearRank = true
                    }
                    if clearRank {
                        updated = true
                        strongSelf.stateValue.state.participants[i].activityRank = nil
                    }
                }
            }
            if updated {
                strongSelf.stateValue.state.participants.sort()
            }
        }, queue: .mainQueue())
        self.activityRankResetTimer?.start()
    }
    
    deinit {
        self.disposable.dispose()
        self.updatesDisposable.dispose()
        self.activitiesDisposable?.dispose()
        self.updateDefaultMuteDisposable.dispose()
        self.updateShouldBeRecordingDisposable.dispose()
        self.activityRankResetTimer?.invalidate()
    }
    
    public func addUpdates(updates: [Update]) {
        var stateUpdates: [Update.StateUpdate] = []
        for update in updates {
            if case let .state(update) = update {
                stateUpdates.append(update)
            } else if case let .call(_, defaultParticipantsAreMuted, title, recordingStartTimestamp) = update {
                var state = self.stateValue.state
                state.defaultParticipantsAreMuted = defaultParticipantsAreMuted
                state.recordingStartTimestamp = recordingStartTimestamp
                state.title = title
                
                self.stateValue.state = state
            }
        }
        
        if !stateUpdates.isEmpty {
            self.updateQueue.append(contentsOf: stateUpdates)
            self.beginProcessingUpdatesIfNeeded()
        }
    }
    
    private func takeNextActivityRank() -> Int {
        let value = self.nextActivityRank
        self.nextActivityRank += 1
        return value
    }
    
    public func reportSpeakingParticipants(ids: [PeerId: UInt32]) {
        if !ids.isEmpty {
            self.hasReceivedSpeakingParticipantsReport = true
        }
        
        let strongSelf = self
        
        var updatedParticipants = strongSelf.stateValue.state.participants
        var indexMap: [PeerId: Int] = [:]
        for i in 0 ..< updatedParticipants.count {
            indexMap[updatedParticipants[i].peer.id] = i
        }
        var updated = false
        
        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
        
        for (activityPeerId, _) in ids {
            if let index = indexMap[activityPeerId] {
                var updateTimestamp = false
                if let activityTimestamp = updatedParticipants[index].activityTimestamp {
                    if activityTimestamp < timestamp {
                        updateTimestamp = true
                    }
                } else {
                    updateTimestamp = true
                }
                if updateTimestamp {
                    updatedParticipants[index].activityTimestamp = timestamp
                    if updatedParticipants[index].activityRank == nil {
                        updatedParticipants[index].activityRank = self.takeNextActivityRank()
                    }
                    updated = true
                }
            }
        }
        
        if updated {
            updatedParticipants.sort()
            /*for i in 0 ..< updatedParticipants.count {
                if updatedParticipants[i].peer.id == strongSelf.account.peerId {
                    let member = updatedParticipants[i]
                    updatedParticipants.remove(at: i)
                    updatedParticipants.insert(member, at: 0)
                    break
                }
            }*/
            
            strongSelf.stateValue = InternalState(
                state: State(
                    participants: updatedParticipants,
                    nextParticipantsFetchOffset: strongSelf.stateValue.state.nextParticipantsFetchOffset,
                    adminIds: strongSelf.stateValue.state.adminIds,
                    isCreator: strongSelf.stateValue.state.isCreator,
                    defaultParticipantsAreMuted: strongSelf.stateValue.state.defaultParticipantsAreMuted,
                    recordingStartTimestamp: strongSelf.stateValue.state.recordingStartTimestamp,
                    title: strongSelf.stateValue.state.title,
                    totalCount: strongSelf.stateValue.state.totalCount,
                    version: strongSelf.stateValue.state.version
                ),
                overlayState: strongSelf.stateValue.overlayState
            )
        }
        
        self.ensureHaveParticipants(ssrcs: Set(ids.map { $0.1 }))
    }
    
    public func ensureHaveParticipants(ssrcs: Set<UInt32>) {
        var missingSsrcs = Set<UInt32>()
        
        var existingSsrcs = Set<UInt32>()
        for participant in self.stateValue.state.participants {
            existingSsrcs.insert(participant.ssrc)
        }
        
        for ssrc in ssrcs {
            if !existingSsrcs.contains(ssrc) {
                missingSsrcs.insert(ssrc)
            }
        }
        
        if !missingSsrcs.isEmpty {
            self.missingSsrcs.formUnion(missingSsrcs)
            self.loadMissingSsrcs()
        }
    }
    
    private func loadMissingSsrcs() {
        if self.missingSsrcs.isEmpty {
            return
        }
        if self.isLoadingMore {
            return
        }
        self.isLoadingMore = true
        
        let ssrcs = self.missingSsrcs
        
        self.disposable.set((getGroupCallParticipants(account: self.account, callId: self.id, accessHash: self.accessHash, offset: "", ssrcs: Array(ssrcs), limit: 100)
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            
            strongSelf.missingSsrcs.subtract(ssrcs)
            
            var updatedState = strongSelf.stateValue.state
            
            updatedState.participants = mergeAndSortParticipants(current: updatedState.participants, with: state.participants)
            
            updatedState.totalCount = max(updatedState.totalCount, state.totalCount)
            updatedState.version = max(updatedState.version, updatedState.version)
            
            strongSelf.stateValue.state = updatedState
            
            if strongSelf.shouldResetStateFromServer {
                strongSelf.resetStateFromServer()
            } else {
                strongSelf.loadMissingSsrcs()
            }
        }))
    }
    
    private func beginProcessingUpdatesIfNeeded() {
        if self.isProcessingUpdate {
            return
        }
        if self.updateQueue.isEmpty {
            return
        }
        self.isProcessingUpdate = true
        let update = self.updateQueue.removeFirst()
        self.processUpdate(update: update)
    }
    
    private func endedProcessingUpdate() {
        assert(self.isProcessingUpdate)
        self.isProcessingUpdate = false
        self.beginProcessingUpdatesIfNeeded()
    }
    
    private func processUpdate(update: Update.StateUpdate) {
        if update.version < self.stateValue.state.version {
            for peerId in update.removePendingMuteStates {
                self.stateValue.overlayState.pendingMuteStateChanges.removeValue(forKey: peerId)
            }
            self.endedProcessingUpdate()
            return
        }
        
        if update.version > self.stateValue.state.version + 1 {
            for peerId in update.removePendingMuteStates {
                self.stateValue.overlayState.pendingMuteStateChanges.removeValue(forKey: peerId)
            }
            self.resetStateFromServer()
            return
        }
        
        let isVersionUpdate = update.version != self.stateValue.state.version
        
        let _ = (self.account.postbox.transaction { transaction -> [PeerId: Peer] in
            var peers: [PeerId: Peer] = [:]
            
            for participantUpdate in update.participantUpdates {
                if let peer = transaction.getPeer(participantUpdate.peerId) {
                    peers[peer.id] = peer
                }
            }
            
            return peers
        }
        |> deliverOnMainQueue).start(next: { [weak self] peers in
            guard let strongSelf = self else {
                return
            }
            
            var updatedParticipants = strongSelf.stateValue.state.participants
            var updatedTotalCount = strongSelf.stateValue.state.totalCount
            
            for participantUpdate in update.participantUpdates {
                if case .left = participantUpdate.participationStatusChange {
                    if let index = updatedParticipants.firstIndex(where: { $0.peer.id == participantUpdate.peerId }) {
                        updatedParticipants.remove(at: index)
                        updatedTotalCount = max(0, updatedTotalCount - 1)
                        strongSelf.memberEventsPipe.putNext(MemberEvent(peerId: participantUpdate.peerId, joined: false))
                    } else if isVersionUpdate {
                        updatedTotalCount = max(0, updatedTotalCount - 1)
                    }
                } else {
                    guard let peer = peers[participantUpdate.peerId] else {
                        assertionFailure()
                        continue
                    }
                    var previousActivityTimestamp: Double?
                    var previousActivityRank: Int?
                    if let index = updatedParticipants.firstIndex(where: { $0.peer.id == participantUpdate.peerId }) {
                        previousActivityTimestamp = updatedParticipants[index].activityTimestamp
                        previousActivityRank = updatedParticipants[index].activityRank
                        updatedParticipants.remove(at: index)
                    } else if case .joined = participantUpdate.participationStatusChange {
                        updatedTotalCount += 1
                        strongSelf.memberEventsPipe.putNext(MemberEvent(peerId: participantUpdate.peerId, joined: true))
                    }
                    
                    var activityTimestamp: Double?
                    if let previousActivityTimestamp = previousActivityTimestamp, let updatedActivityTimestamp = participantUpdate.activityTimestamp {
                        activityTimestamp = max(updatedActivityTimestamp, previousActivityTimestamp)
                    } else {
                        activityTimestamp = participantUpdate.activityTimestamp ?? previousActivityTimestamp
                    }
                    
                    let participant = Participant(
                        peer: peer,
                        ssrc: participantUpdate.ssrc,
                        jsonParams: participantUpdate.jsonParams,
                        joinTimestamp: participantUpdate.joinTimestamp,
                        activityTimestamp: activityTimestamp,
                        activityRank: previousActivityRank,
                        muteState: participantUpdate.muteState,
                        volume: participantUpdate.volume,
                        about: participantUpdate.about
                    )
                    updatedParticipants.append(participant)
                }
            }
            
            updatedTotalCount = max(updatedTotalCount, updatedParticipants.count)
            
            var updatedOverlayState = strongSelf.stateValue.overlayState
            for peerId in update.removePendingMuteStates {
                updatedOverlayState.pendingMuteStateChanges.removeValue(forKey: peerId)
            }
            
            let nextParticipantsFetchOffset = strongSelf.stateValue.state.nextParticipantsFetchOffset
            let adminIds = strongSelf.stateValue.state.adminIds
            let isCreator = strongSelf.stateValue.state.isCreator
            let defaultParticipantsAreMuted = strongSelf.stateValue.state.defaultParticipantsAreMuted
            let recordingStartTimestamp = strongSelf.stateValue.state.recordingStartTimestamp
            let title = strongSelf.stateValue.state.title
            
            updatedParticipants.sort()
            
            strongSelf.stateValue = InternalState(
                state: State(
                    participants: updatedParticipants,
                    nextParticipantsFetchOffset: nextParticipantsFetchOffset,
                    adminIds: adminIds,
                    isCreator: isCreator,
                    defaultParticipantsAreMuted: defaultParticipantsAreMuted,
                    recordingStartTimestamp: recordingStartTimestamp,
                    title: title,
                    totalCount: updatedTotalCount,
                    version: update.version
                ),
                overlayState: updatedOverlayState
            )
            
            strongSelf.endedProcessingUpdate()
        })
    }
    
    private func resetStateFromServer() {
        if self.isLoadingMore {
            self.shouldResetStateFromServer = true
            return
        }
        
        self.isLoadingMore = true
        
        self.updateQueue.removeAll()
        
        self.disposable.set((getGroupCallParticipants(account: self.account, callId: self.id, accessHash: self.accessHash, offset: "", ssrcs: [], limit: 100)
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            strongSelf.shouldResetStateFromServer = false
            strongSelf.stateValue.state = state
            strongSelf.endedProcessingUpdate()
        }))
    }
    
    public func updateMuteState(peerId: PeerId, muteState: Participant.MuteState?, volume: Int32?) {
        if let current = self.stateValue.overlayState.pendingMuteStateChanges[peerId] {
            if current.state == muteState {
                return
            }
            current.disposable.dispose()
            self.stateValue.overlayState.pendingMuteStateChanges.removeValue(forKey: peerId)
        }
        
        for participant in self.stateValue.state.participants {
            if participant.peer.id == peerId {
                if participant.muteState == muteState && participant.volume == volume {
                    return
                }
            }
        }
        
        let disposable = MetaDisposable()
        self.stateValue.overlayState.pendingMuteStateChanges[peerId] = OverlayState.MuteStateChange(
            state: muteState,
            volume: volume,
            disposable: disposable
        )
        
        let account = self.account
        let id = self.id
        let accessHash = self.accessHash
        
        let signal: Signal<Api.Updates?, NoError> = self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<Api.Updates?, NoError> in
            guard let inputPeer = inputPeer else {
                return .single(nil)
            }
            var flags: Int32 = 0
            if let volume = volume, volume > 0 {
                flags |= 1 << 1
            }
            if let muteState = muteState, (!muteState.canUnmute || peerId == account.peerId || muteState.mutedByYou) {
                flags |= 1 << 0
            }
                        
            return account.network.request(Api.functions.phone.editGroupCallParticipant(flags: flags, call: .inputGroupCall(id: id, accessHash: accessHash), participant: inputPeer, volume: volume))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
        }
        
        disposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let strongSelf = self else {
                return
            }
            
            if let updates = updates {
                var stateUpdates: [GroupCallParticipantsContext.Update] = []
                
                loop: for update in updates.allUpdates {
                    switch update {
                    case let .updateGroupCallParticipants(call, participants, version):
                        switch call {
                        case let .inputGroupCall(updateCallId, _):
                            if updateCallId != id {
                                continue loop
                            }
                        }
                        stateUpdates.append(.state(update: GroupCallParticipantsContext.Update.StateUpdate(participants: participants, version: version, removePendingMuteStates: [peerId])))
                    default:
                        break
                    }
                }
                
                strongSelf.addUpdates(updates: stateUpdates)
                
                strongSelf.account.stateManager.addUpdates(updates)
            } else {
                strongSelf.stateValue.overlayState.pendingMuteStateChanges.removeValue(forKey: peerId)
            }
        }))
    }
    
    public func updateShouldBeRecording(_ shouldBeRecording: Bool) {
        var flags: Int32 = 0
        if shouldBeRecording {
            flags |= 1 << 0
        }
        self.updateShouldBeRecordingDisposable.set((self.account.network.request(Api.functions.phone.toggleGroupCallRecord(flags: flags, call: .inputGroupCall(id: self.id, accessHash: self.accessHash), title: nil))
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let strongSelf = self else {
                return
            }
            strongSelf.account.stateManager.addUpdates(updates)
        }))
    }
    
    public func updateDefaultParticipantsAreMuted(isMuted: Bool) {
        if isMuted == self.stateValue.state.defaultParticipantsAreMuted.isMuted {
            return
        }
        self.stateValue.state.defaultParticipantsAreMuted.isMuted = isMuted
        
        self.updateDefaultMuteDisposable.set((self.account.network.request(Api.functions.phone.toggleGroupCallSettings(flags: 1 << 0, call: .inputGroupCall(id: self.id, accessHash: self.accessHash), joinMuted: isMuted ? .boolTrue : .boolFalse))
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let strongSelf = self else {
                return
            }
            strongSelf.account.stateManager.addUpdates(updates)
        }))
    }
    
    public func loadMore(token: String) {
        if token != self.stateValue.state.nextParticipantsFetchOffset {
            Logger.shared.log("GroupCallParticipantsContext", "loadMore called with an invalid token \(token) (the valid one is \(String(describing: self.stateValue.state.nextParticipantsFetchOffset)))")
            return
        }
        if self.isLoadingMore {
            return
        }
        self.isLoadingMore = true
        
        self.disposable.set((getGroupCallParticipants(account: self.account, callId: self.id, accessHash: self.accessHash, offset: token, ssrcs: [], limit: 100)
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            
            var updatedState = strongSelf.stateValue.state
            
            updatedState.participants = mergeAndSortParticipants(current: updatedState.participants, with: state.participants)
            
            updatedState.nextParticipantsFetchOffset = state.nextParticipantsFetchOffset
            updatedState.totalCount = max(updatedState.totalCount, state.totalCount)
            updatedState.version = max(updatedState.version, updatedState.version)
            
            strongSelf.stateValue.state = updatedState
            
            if strongSelf.shouldResetStateFromServer {
                strongSelf.resetStateFromServer()
            }
        }))
    }
}

extension GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate {
    init(_ apiParticipant: Api.GroupCallParticipant) {
        switch apiParticipant {
        case let .groupCallParticipant(flags, apiPeerId, date, activeDate, source, volume, about):
            let peerId: PeerId
            switch apiPeerId {
                case let .peerUser(userId):
                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                case let .peerChat(chatId):
                    peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                case let .peerChannel(channelId):
                    peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
            }
            let ssrc = UInt32(bitPattern: source)
            let muted = (flags & (1 << 0)) != 0
            let mutedByYou = (flags & (1 << 9)) != 0
            var muteState: GroupCallParticipantsContext.Participant.MuteState?
            if muted {
                let canUnmute = (flags & (1 << 2)) != 0
                muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canUnmute, mutedByYou: mutedByYou)
            } else if mutedByYou {
                muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: mutedByYou)
            }
            let isRemoved = (flags & (1 << 1)) != 0
            let justJoined = (flags & (1 << 4)) != 0
            
            let participationStatusChange: GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate.ParticipationStatusChange
            if isRemoved {
                participationStatusChange = .left
            } else if justJoined {
                participationStatusChange = .joined
            } else {
                participationStatusChange = .none
            }
            
            var jsonParams: String?
            /*if let params = params {
                switch params {
                case let .dataJSON(data):
                    jsonParams = data
                }
            }*/
            
            self.init(
                peerId: peerId,
                ssrc: ssrc,
                jsonParams: jsonParams,
                joinTimestamp: date,
                activityTimestamp: activeDate.flatMap(Double.init),
                muteState: muteState,
                participationStatusChange: participationStatusChange,
                volume: volume,
                about: about
            )
        }
    }
}

extension GroupCallParticipantsContext.Update.StateUpdate {
    init(participants: [Api.GroupCallParticipant], version: Int32, removePendingMuteStates: Set<PeerId> = Set()) {
        var participantUpdates: [GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate] = []
        for participant in participants {
            switch participant {
            case let .groupCallParticipant(flags, apiPeerId, date, activeDate, source, volume, about):
                let peerId: PeerId
                switch apiPeerId {
                    case let .peerUser(userId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                }
                let ssrc = UInt32(bitPattern: source)
                let muted = (flags & (1 << 0)) != 0
                let mutedByYou = (flags & (1 << 9)) != 0
                var muteState: GroupCallParticipantsContext.Participant.MuteState?
                if muted {
                    let canUnmute = (flags & (1 << 2)) != 0
                    muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canUnmute, mutedByYou: mutedByYou)
                } else if mutedByYou {
                    muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: mutedByYou)
                }
                let isRemoved = (flags & (1 << 1)) != 0
                let justJoined = (flags & (1 << 4)) != 0
                
                let participationStatusChange: GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate.ParticipationStatusChange
                if isRemoved {
                    participationStatusChange = .left
                } else if justJoined {
                    participationStatusChange = .joined
                } else {
                    participationStatusChange = .none
                }
                
                var jsonParams: String?
                /*if let params = params {
                    switch params {
                    case let .dataJSON(data):
                        jsonParams = data
                    }
                }*/
                
                participantUpdates.append(GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate(
                    peerId: peerId,
                    ssrc: ssrc,
                    jsonParams: jsonParams,
                    joinTimestamp: date,
                    activityTimestamp: activeDate.flatMap(Double.init),
                    muteState: muteState,
                    participationStatusChange: participationStatusChange,
                    volume: volume,
                    about: about
                ))
            }
        }
        
        self.init(
            participantUpdates: participantUpdates,
            version: version,
            removePendingMuteStates: removePendingMuteStates
        )
    }
}

public enum InviteToGroupCallError {
    case generic
}

public func inviteToGroupCall(account: Account, callId: Int64, accessHash: Int64, peerId: PeerId) -> Signal<Never, InviteToGroupCallError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> castError(InviteToGroupCallError.self)
    |> mapToSignal { user -> Signal<Never, InviteToGroupCallError> in
        guard let user = user else {
            return .fail(.generic)
        }
        guard let apiUser = apiInputUser(user) else {
            return .fail(.generic)
        }
        
        return account.network.request(Api.functions.phone.inviteToGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash), users: [apiUser]))
        |> mapError { _ -> InviteToGroupCallError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, InviteToGroupCallError> in
            account.stateManager.addUpdates(result)
            
            return .complete()
        }
    }
}

public enum EditGroupCallTitleError {
    case generic
}

public func editGroupCallTitle(account: Account, callId: Int64, accessHash: Int64, title: String) -> Signal<Never, EditGroupCallTitleError> {
    return account.network.request(Api.functions.phone.editGroupCallTitle(call: .inputGroupCall(id: callId, accessHash: accessHash), title: title)) |> mapError { _ -> EditGroupCallTitleError in
        return .generic
    }
    |> mapToSignal { result -> Signal<Never, EditGroupCallTitleError> in
        account.stateManager.addUpdates(result)
        return .complete()
    }
}




public func groupCallDisplayAsAvailablePeers(network: Network, postbox: Postbox) -> Signal<[FoundPeer], NoError> {
    return network.request(Api.functions.channels.getAdminedPublicChannels(flags: 1 << 2))
        |> retryRequest
        |> mapToSignal { result in
        
        let chats:[Api.Chat]
        switch result {
        case let .chatsSlice(_, c):
            chats = c
        case let .chats(c):
            chats = c
        }
        var subscribers: [PeerId: Int32] = [:]
        let peers = chats.compactMap(parseTelegramGroupOrChannel)
        for chat in chats {
            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                switch chat {
                    case let .channel(channel):
                        if let participantsCount = channel.participantsCount {
                            subscribers[groupOrChannel.id] = participantsCount
                        }
                case let .chat(chat):
                    subscribers[groupOrChannel.id] = chat.participantsCount
                default:
                    break
                }
            }
        }
            
            
            
        return postbox.transaction { transaction -> [Peer] in
            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                return updated
            })
            return peers
        } |> map { peers -> [FoundPeer] in
            return peers.map { FoundPeer(peer: $0, subscribers: subscribers[$0.id]) }
        }
        
    }
}

public func updatedCurrentPeerGroupCall(account: Account, peerId: PeerId) -> Signal<CachedChannelData.ActiveCall?, NoError> {
    return fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)
    |> mapToSignal { _ -> Signal<CachedChannelData.ActiveCall?, NoError> in
        return account.postbox.transaction { transaction -> CachedChannelData.ActiveCall? in
            return (transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData)?.activeCall
        }
    }
}

private func mergeAndSortParticipants(current currentParticipants: [GroupCallParticipantsContext.Participant], with updatedParticipants: [GroupCallParticipantsContext.Participant]) -> [GroupCallParticipantsContext.Participant] {
    var mergedParticipants = currentParticipants
    
    var existingParticipantIndices: [PeerId: Int] = [:]
    for i in 0 ..< mergedParticipants.count {
        existingParticipantIndices[mergedParticipants[i].peer.id] = i
    }
    for participant in updatedParticipants {
        if let _ = existingParticipantIndices[participant.peer.id] {
        } else {
            existingParticipantIndices[participant.peer.id] = mergedParticipants.count
            mergedParticipants.append(participant)
        }
    }
    
    mergedParticipants.sort()
    
    return mergedParticipants
}

public func getAudioBroadcastPart(account: Account, callId: Int64, accessHash: Int64, datacenterId: Int?, timestampId: Int32) -> Signal<Data?, NoError> {
    return account.network.multiplexedRequestManager.request(to: .main(account.network.datacenterId), consumerId: Int64.random(in: 0 ..< Int64.max), data: Api.functions.upload.getFile(flags: 0, location: .inputGroupCallStream(call: .inputGroupCall(id: callId, accessHash: accessHash), date: timestampId), offset: 0, limit: 128 * 1024), tag: nil, continueInBackground: false, automaticFloodWait: false)
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.upload.File?, NoError> in
        return .single(nil)
    }
    |> map { result -> Data? in
        guard let result = result else {
            return nil
        }
        switch result {
        case let .file(_, _, bytes):
            return bytes.makeData()
        case .fileCdnRedirect:
            return nil
        }
    }
}
