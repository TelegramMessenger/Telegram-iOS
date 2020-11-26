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
        case let .groupCall(call, _, participants, users):
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
                    case let .groupCallParticipant(flags, userId, date, source):
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
            account.stateManager.addUpdates(result)
            
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
            
            if let parsedCall = parsedCall {
                return .single(parsedCall)
            } else {
                return .fail(.generic)
            }
        }
    }
}

public enum GetGroupCallParticipantsError {
    case generic
}

public func getGroupCallParticipants(account: Account, callId: Int64, accessHash: Int64, maxDate: Int32, limit: Int32) -> Signal<GroupCallParticipantsContext.State, GetGroupCallParticipantsError> {
    return account.network.request(Api.functions.phone.getGroupParticipants(call: .inputGroupCall(id: callId, accessHash: accessHash), maxDate: maxDate, limit: limit))
    |> mapError { _ -> GetGroupCallParticipantsError in
        return .generic
    }
    |> mapToSignal { result -> Signal<GroupCallParticipantsContext.State, GetGroupCallParticipantsError> in
        return account.postbox.transaction { transaction -> GroupCallParticipantsContext.State in
            var parsedParticipants: [GroupCallParticipantsContext.Participant] = []
            let totalCount: Int
            let version: Int32
            
            switch result {
            case let .groupParticipants(count, participants, users, apiVersion):
                totalCount = Int(count)
                version = apiVersion
                
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
                    case let .groupCallParticipant(flags, userId, date, source):
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
            }
            
            return GroupCallParticipantsContext.State(
                participants: parsedParticipants,
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

public func joinGroupCall(account: Account, callId: Int64, accessHash: Int64, joinPayload: String) -> Signal<JoinGroupCallResult, JoinGroupCallError> {
    return account.network.request(Api.functions.phone.joinGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash), params: .dataJSON(data: joinPayload)))
    |> mapError { _ -> JoinGroupCallError in
        return .generic
    }
    |> mapToSignal { updates -> Signal<JoinGroupCallResult, JoinGroupCallError> in
        return combineLatest(
            account.network.request(Api.functions.phone.getGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
            |> mapError { _ -> JoinGroupCallError in
                return .generic
            },
            getGroupCallParticipants(account: account, callId: callId, accessHash: accessHash, maxDate: 0, limit: 100)
            |> mapError { _ -> JoinGroupCallError in
                return .generic
            }
        )
        |> mapToSignal { result, state -> Signal<JoinGroupCallResult, JoinGroupCallError> in
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
            
            switch result {
            case let .groupCall(call, sources, _, users):
                guard let _ = GroupCallInfo(call) else {
                    return .fail(.generic)
                }
                return account.postbox.transaction { transaction -> JoinGroupCallResult in
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

public func leaveGroupCall(account: Account, callId: Int64, accessHash: Int64) -> Signal<Never, LeaveGroupCallError> {
    return account.network.request(Api.functions.phone.leaveGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
    |> mapError { _ -> LeaveGroupCallError in
        return .generic
    }
    |> ignoreValues
}

public enum StopGroupCallError {
    case generic
}

public func stopGroupCall(account: Account, callId: Int64, accessHash: Int64) -> Signal<Never, StopGroupCallError> {
    return account.network.request(Api.functions.phone.discardGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
    |> mapError { _ -> StopGroupCallError in
        return .generic
    }
    |> mapToSignal { result -> Signal<Never, StopGroupCallError> in
        account.stateManager.addUpdates(result)
        
        return .complete()
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
            if lhs.muteState != rhs.muteState {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var participants: [Participant]
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
    
    private var updateQueue: [StateUpdate] = []
    private var isProcessingUpdate: Bool = false
    private let disposable = MetaDisposable()
    
    public init(account: Account, id: Int64, accessHash: Int64, state: State) {
        self.account = account
        self.id = id
        self.accessHash = accessHash
        self.stateValue = InternalState(state: state, overlayState: OverlayState())
        self.statePromise = ValuePromise<InternalState>(self.stateValue)
    }
    
    deinit {
        self.disposable.dispose()
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
                        updatedTotalCount -= 1
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
            
            strongSelf.stateValue = InternalState(
                state: State(
                    participants: Array(updatedParticipants.reversed()),
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
        
        self.disposable.set((
            getGroupCallParticipants(account: self.account, callId: self.id, accessHash: self.accessHash, maxDate: 0, limit: 100)
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
            if muteState != nil {
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
            case let .groupCallParticipant(flags, userId, date, source):
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
