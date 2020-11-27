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
    
    public init(
        id: Int64,
        accessHash: Int64,
        participantCount: Int,
        clientParams: String?
    ) {
        self.id = id
        self.accessHash = accessHash
        self.participantCount = participantCount
        self.clientParams = clientParams
    }
}

public struct GroupCallSummary: Equatable {
    public var info: GroupCallInfo
    public var topParticipants: [GroupCallParticipantsContext.Participant]
}

private extension GroupCallInfo {
    init?(_ call: Api.GroupCall) {
        switch call {
        case let .groupCall(_, id, accessHash, participantCount, params, _):
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
                clientParams: clientParams
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
        case let .groupCall(call, participants, _, users):
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
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
                var parsedParticipants: [GroupCallParticipantsContext.Participant] = []
                
                loop: for participant in participants {
                    switch participant {
                    case let .groupCallParticipant(flags, userId, date, activeDate, source):
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                        let ssrc = UInt32(bitPattern: source)
                        guard let peer = transaction.getPeer(peerId) else {
                            continue loop
                        }
                        var muteState: GroupCallParticipantsContext.Participant.MuteState?
                        if (flags & (1 << 0)) != 0 {
                            let canUnmute = (flags & (1 << 2)) != 0
                            muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canUnmute)
                        }
                        parsedParticipants.append(GroupCallParticipantsContext.Participant(
                            peer: peer,
                            ssrc: ssrc,
                            joinTimestamp: date,
                            muteState: muteState
                        ))
                    }
                }
                
                return GroupCallSummary(
                    info: info,
                    topParticipants: parsedParticipants
                )
            }
            |> mapError { _ -> GetCurrentGroupCallError in
                return .generic
            }
        }
    }
}

public enum CreateGroupCallError {
    case generic
}

public func createGroupCall(account: Account, peerId: PeerId) -> Signal<GroupCallInfo, CreateGroupCallError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(CreateGroupCallError.self)
    |> mapToSignal { inputPeer -> Signal<GroupCallInfo, CreateGroupCallError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        
        return account.network.request(Api.functions.phone.createGroupCall(channel: inputPeer, randomId: Int32.random(in: Int32.min ... Int32.max)))
        |> mapError { _ -> CreateGroupCallError in
            return .generic
        }
        |> mapToSignal { result -> Signal<GroupCallInfo, CreateGroupCallError> in
            var parsedCall: GroupCallInfo?
            loop: for update in result.allUpdates {
                switch update {
                case let .updateGroupCall(call):
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

public func getGroupCallParticipants(account: Account, callId: Int64, accessHash: Int64, offset: String, limit: Int32) -> Signal<GroupCallParticipantsContext.State, GetGroupCallParticipantsError> {
    return account.network.request(Api.functions.phone.getGroupParticipants(call: .inputGroupCall(id: callId, accessHash: accessHash), ids: [], sources: [], offset: offset, limit: limit))
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
            case let .groupParticipants(count, participants, nextOffset, users, apiVersion):
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
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
                loop: for participant in participants {
                    switch participant {
                    case let .groupCallParticipant(flags, userId, date, activeDate, source):
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                        let ssrc = UInt32(bitPattern: source)
                        guard let peer = transaction.getPeer(peerId) else {
                            continue loop
                        }
                        var muteState: GroupCallParticipantsContext.Participant.MuteState?
                        if (flags & (1 << 0)) != 0 {
                            let canUnmute = (flags & (1 << 2)) != 0
                            muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canUnmute)
                        }
                        parsedParticipants.append(GroupCallParticipantsContext.Participant(
                            peer: peer,
                            ssrc: ssrc,
                            joinTimestamp: date,
                            activityTimestamp: activeDate,
                            muteState: muteState
                        ))
                    }
                }
            }
            
            return GroupCallParticipantsContext.State(
                participants: parsedParticipants,
                nextParticipantsFetchOffset: nextParticipantsFetchOffset,
                adminIds: Set(),
                isCreator: false,
                totalCount: totalCount,
                version: version
            )
        }
        |> castError(GetGroupCallParticipantsError.self)
    }
}

public enum JoinGroupCallError {
    case generic
}

public struct JoinGroupCallResult {
    public var callInfo: GroupCallInfo
    public var state: GroupCallParticipantsContext.State
}

public func joinGroupCall(account: Account, peerId: PeerId, callId: Int64, accessHash: Int64, preferMuted: Bool, joinPayload: String) -> Signal<JoinGroupCallResult, JoinGroupCallError> {
    var flags: Int32 = 0
    if preferMuted {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.phone.joinGroupCall(flags: flags, call: .inputGroupCall(id: callId, accessHash: accessHash), params: .dataJSON(data: joinPayload)))
    |> mapError { _ -> JoinGroupCallError in
        return .generic
    }
    |> mapToSignal { updates -> Signal<JoinGroupCallResult, JoinGroupCallError> in
        let admins = account.postbox.transaction { transaction -> Api.InputChannel? in
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
        
        let channel = account.postbox.transaction { transaction -> TelegramChannel? in
            return transaction.getPeer(peerId) as? TelegramChannel
        }
        |> castError(JoinGroupCallError.self)
        
        return combineLatest(
            account.network.request(Api.functions.phone.getGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
            |> mapError { _ -> JoinGroupCallError in
                return .generic
            },
            getGroupCallParticipants(account: account, callId: callId, accessHash: accessHash, offset: "", limit: 100)
            |> mapError { _ -> JoinGroupCallError in
                return .generic
            },
            admins,
            channel
        )
        |> mapToSignal { result, state, admins, channel -> Signal<JoinGroupCallResult, JoinGroupCallError> in
            guard let channel = channel else {
                return .fail(.generic)
            }
            
            var state = state
            state.isCreator = channel.flags.contains(.isCreator)
            
            account.stateManager.addUpdates(updates)
            
            var maybeParsedCall: GroupCallInfo?
            loop: for update in updates.allUpdates {
                switch update {
                case let .updateGroupCall(call):
                    maybeParsedCall = GroupCallInfo(call)
                    break loop
                default:
                    break
                }
            }
            
            guard let parsedCall = maybeParsedCall else {
                return .fail(.generic)
            }
            
            var apiUsers: [Api.User] = []
            var adminIds = Set<PeerId>()
            
            switch admins {
            case let .channelParticipants(_, participants, users):
                apiUsers.append(contentsOf: users)
                
                for participant in participants {
                    let parsedParticipant = ChannelParticipant(apiParticipant: participant)
                    switch parsedParticipant {
                    case .creator:
                        adminIds.insert(parsedParticipant.peerId)
                    case let .member(_, _, adminInfo, _, _):
                        if let adminInfo = adminInfo, adminInfo.rights.flags.contains(.canManageCalls) {
                            adminIds.insert(parsedParticipant.peerId)
                        }
                    }
                }
            default:
                break
            }
            
            state.adminIds = adminIds
            
            switch result {
            case let .groupCall(call, _, _, users):
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
                } else {
                    return cachedData
                }
            })
            
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
    public struct Participant: Equatable {
        public struct MuteState: Equatable {
            public var canUnmute: Bool
            
            public init(canUnmute: Bool) {
                self.canUnmute = canUnmute
            }
        }
        
        public var peer: Peer
        public var ssrc: UInt32
        public var joinTimestamp: Int32
        public var activityTimestamp: Int32?
        public var muteState: MuteState?
        
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
            if lhs.muteState != rhs.muteState {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var participants: [Participant]
        public var nextParticipantsFetchOffset: String?
        public var adminIds: Set<PeerId>
        public var isCreator: Bool
        public var totalCount: Int
        public var version: Int32
    }
    
    private struct OverlayState: Equatable {
        struct MuteStateChange: Equatable {
            var state: Participant.MuteState?
            var disposable: Disposable
            
            static func ==(lhs: MuteStateChange, rhs: MuteStateChange) -> Bool {
                if lhs.state != rhs.state {
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
    
    public struct StateUpdate {
        public struct ParticipantUpdate {
            public var peerId: PeerId
            public var ssrc: UInt32
            public var joinTimestamp: Int32
            public var activityTimestamp: Int32?
            public var muteState: Participant.MuteState?
            public var isRemoved: Bool
        }
        
        public var participantUpdates: [ParticipantUpdate]
        public var version: Int32
        
        public var removePendingMuteStates: Set<PeerId>
    }
    
    private let account: Account
    private let id: Int64
    private let accessHash: Int64
    
    private var stateValue: InternalState {
        didSet {
            self.statePromise.set(self.stateValue)
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
                }
            }
            return publicState
        }
    }
    
    private var numberOfActiveSpeakersValue: Int = 0 {
        didSet {
            if self.numberOfActiveSpeakersValue != oldValue {
                self.numberOfActiveSpeakersPromise.set(self.numberOfActiveSpeakersValue)
            }
        }
    }
    private let numberOfActiveSpeakersPromise = ValuePromise<Int>(0)
    public var numberOfActiveSpeakers: Signal<Int, NoError> {
        return self.numberOfActiveSpeakersPromise.get()
    }
    
    private var updateQueue: [StateUpdate] = []
    private var isProcessingUpdate: Bool = false
    private let disposable = MetaDisposable()
    
    private let updatesDisposable = MetaDisposable()
    private var activitiesDisposable: Disposable?
    
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
            var filteredUpdates: [StateUpdate] = []
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
        
            strongSelf.numberOfActiveSpeakersValue = activities.count
        })
    }
    
    deinit {
        self.disposable.dispose()
        self.updatesDisposable.dispose()
        self.activitiesDisposable?.dispose()
    }
    
    public func addUpdates(updates: [StateUpdate]) {
        self.updateQueue.append(contentsOf: updates)
        self.beginProcessingUpdatesIfNeeded()
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
    
    private func processUpdate(update: StateUpdate) {
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
            
            var updatedParticipants = Array(strongSelf.stateValue.state.participants.reversed())
            var updatedTotalCount = strongSelf.stateValue.state.totalCount
            
            for participantUpdate in update.participantUpdates {
                if participantUpdate.isRemoved {
                    if let index = updatedParticipants.firstIndex(where: { $0.peer.id == participantUpdate.peerId }) {
                        updatedParticipants.remove(at: index)
                        updatedTotalCount = max(0, updatedTotalCount - 1)
                    } else if isVersionUpdate {
                        updatedTotalCount = max(0, updatedTotalCount - 1)
                    }
                } else {
                    guard let peer = peers[participantUpdate.peerId] else {
                        assertionFailure()
                        continue
                    }
                    if let index = updatedParticipants.firstIndex(where: { $0.peer.id == participantUpdate.peerId }) {
                        updatedParticipants.remove(at: index)
                    } else {
                        updatedTotalCount += 1
                    }
                    
                    let participant = Participant(
                        peer: peer,
                        ssrc: participantUpdate.ssrc,
                        joinTimestamp: participantUpdate.joinTimestamp,
                        muteState: participantUpdate.muteState
                    )
                    let index = binaryInsertionIndex(updatedParticipants, searchItem: participant.joinTimestamp)
                    updatedParticipants.insert(participant, at: index)
                }
            }
            
            var updatedOverlayState = strongSelf.stateValue.overlayState
            for peerId in update.removePendingMuteStates {
                updatedOverlayState.pendingMuteStateChanges.removeValue(forKey: peerId)
            }
            
            let nextParticipantsFetchOffset = strongSelf.stateValue.state.nextParticipantsFetchOffset
            let adminIds = strongSelf.stateValue.state.adminIds
            let isCreator = strongSelf.stateValue.state.isCreator
            
            strongSelf.stateValue = InternalState(
                state: State(
                    participants: Array(updatedParticipants.reversed()),
                    nextParticipantsFetchOffset: nextParticipantsFetchOffset,
                    adminIds: adminIds,
                    isCreator: isCreator,
                    totalCount: updatedTotalCount,
                    version: update.version
                ),
                overlayState: updatedOverlayState
            )
            
            strongSelf.endedProcessingUpdate()
        })
    }
    
    private func resetStateFromServer() {
        self.updateQueue.removeAll()
        
        self.disposable.set((getGroupCallParticipants(account: self.account, callId: self.id, accessHash: self.accessHash, offset: "", limit: 100)
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.stateValue.state = state
            strongSelf.endedProcessingUpdate()
        }))
    }
    
    public func updateMuteState(peerId: PeerId, muteState: Participant.MuteState?) {
        if let current = self.stateValue.overlayState.pendingMuteStateChanges[peerId] {
            if current.state == muteState {
                return
            }
            current.disposable.dispose()
            self.stateValue.overlayState.pendingMuteStateChanges.removeValue(forKey: peerId)
        }
        
        let disposable = MetaDisposable()
        self.stateValue.overlayState.pendingMuteStateChanges[peerId] = OverlayState.MuteStateChange(
            state: muteState,
            disposable: disposable
        )
        
        let account = self.account
        let id = self.id
        let accessHash = self.accessHash
        
        let signal: Signal<Api.Updates?, NoError> = self.account.postbox.transaction { transaction -> Api.InputUser? in
            return transaction.getPeer(peerId).flatMap(apiInputUser)
        }
        |> mapToSignal { inputUser -> Signal<Api.Updates?, NoError> in
            guard let inputUser = inputUser else {
                return .single(nil)
            }
            var flags: Int32 = 0
            if let muteState = muteState, !muteState.canUnmute {
                flags |= 1 << 0
            }
            
            return account.network.request(Api.functions.phone.editGroupCallMember(flags: flags, call: .inputGroupCall(id: id, accessHash: accessHash), userId: inputUser))
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
                var stateUpdates: [GroupCallParticipantsContext.StateUpdate] = []
                
                loop: for update in updates.allUpdates {
                    switch update {
                    case let .updateGroupCallParticipants(call, participants, version):
                        switch call {
                        case let .inputGroupCall(updateCallId, _):
                            if updateCallId != id {
                                continue loop
                            }
                        }
                        stateUpdates.append(GroupCallParticipantsContext.StateUpdate(participants: participants, version: version, removePendingMuteStates: [peerId]))
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
}

extension GroupCallParticipantsContext.StateUpdate {
    init(participants: [Api.GroupCallParticipant], version: Int32, removePendingMuteStates: Set<PeerId> = Set()) {
        var participantUpdates: [GroupCallParticipantsContext.StateUpdate.ParticipantUpdate] = []
        for participant in participants {
            switch participant {
            case let .groupCallParticipant(flags, userId, date, activeDate, source):
                let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                let ssrc = UInt32(bitPattern: source)
                var muteState: GroupCallParticipantsContext.Participant.MuteState?
                if (flags & (1 << 0)) != 0 {
                    let canUnmute = (flags & (1 << 2)) != 0
                    muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canUnmute)
                }
                let isRemoved = (flags & (1 << 1)) != 0
                participantUpdates.append(GroupCallParticipantsContext.StateUpdate.ParticipantUpdate(
                    peerId: peerId,
                    ssrc: ssrc,
                    joinTimestamp: date,
                    activityTimestamp: activeDate,
                    muteState: muteState,
                    isRemoved: isRemoved
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
        
        return account.network.request(Api.functions.phone.inviteToGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash), userId: apiUser))
        |> mapError { _ -> InviteToGroupCallError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, InviteToGroupCallError> in
            account.stateManager.addUpdates(result)
            
            return .complete()
        }
    }
}
