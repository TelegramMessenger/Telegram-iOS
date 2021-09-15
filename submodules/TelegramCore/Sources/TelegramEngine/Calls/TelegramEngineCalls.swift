import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Calls {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func rateCall(callId: CallId, starsCount: Int32, comment: String = "", userInitiated: Bool) -> Signal<Void, NoError> {
            return _internal_rateCall(account: self.account, callId: callId, starsCount: starsCount, comment: comment, userInitiated: userInitiated)
        }

        public func saveCallDebugLog(callId: CallId, log: String) -> Signal<Void, NoError> {
            return _internal_saveCallDebugLog(network: self.account.network, callId: callId, log: log)
        }

        public func getCurrentGroupCall(callId: Int64, accessHash: Int64, peerId: PeerId? = nil) -> Signal<GroupCallSummary?, GetCurrentGroupCallError> {
            return _internal_getCurrentGroupCall(account: self.account, callId: callId, accessHash: accessHash, peerId: peerId)
        }

        public func createGroupCall(peerId: PeerId, title: String?, scheduleDate: Int32?) -> Signal<GroupCallInfo, CreateGroupCallError> {
            return _internal_createGroupCall(account: self.account, peerId: peerId, title: title, scheduleDate: scheduleDate)
        }

        public func startScheduledGroupCall(peerId: PeerId, callId: Int64, accessHash: Int64) -> Signal<GroupCallInfo, StartScheduledGroupCallError> {
            return _internal_startScheduledGroupCall(account: self.account, peerId: peerId, callId: callId, accessHash: accessHash)
        }

        public func toggleScheduledGroupCallSubscription(peerId: PeerId, callId: Int64, accessHash: Int64, subscribe: Bool) -> Signal<Void, ToggleScheduledGroupCallSubscriptionError> {
            return _internal_toggleScheduledGroupCallSubscription(account: self.account, peerId: peerId, callId: callId, accessHash: accessHash, subscribe: subscribe)
        }

        public func updateGroupCallJoinAsPeer(peerId: PeerId, joinAs: PeerId) -> Signal<Never, UpdateGroupCallJoinAsPeerError> {
            return _internal_updateGroupCallJoinAsPeer(account: self.account, peerId: peerId, joinAs: joinAs)
        }

        public func getGroupCallParticipants(callId: Int64, accessHash: Int64, offset: String, ssrcs: [UInt32], limit: Int32, sortAscending: Bool?) -> Signal<GroupCallParticipantsContext.State, GetGroupCallParticipantsError> {
            return _internal_getGroupCallParticipants(account: self.account, callId: callId, accessHash: accessHash, offset: offset, ssrcs: ssrcs, limit: limit, sortAscending: sortAscending)
        }

        public func joinGroupCall(peerId: PeerId, joinAs: PeerId?, callId: Int64, accessHash: Int64, preferMuted: Bool, joinPayload: String, peerAdminIds: Signal<[PeerId], NoError>, inviteHash: String? = nil) -> Signal<JoinGroupCallResult, JoinGroupCallError> {
            return _internal_joinGroupCall(account: self.account, peerId: peerId, joinAs: joinAs, callId: callId, accessHash: accessHash, preferMuted: preferMuted, joinPayload: joinPayload, peerAdminIds: peerAdminIds, inviteHash: inviteHash)
        }

        public func joinGroupCallAsScreencast(peerId: PeerId, callId: Int64, accessHash: Int64, joinPayload: String) -> Signal<JoinGroupCallAsScreencastResult, JoinGroupCallError> {
            return _internal_joinGroupCallAsScreencast(account: self.account, peerId: peerId, callId: callId, accessHash: accessHash, joinPayload: joinPayload)
        }

        public func leaveGroupCallAsScreencast(callId: Int64, accessHash: Int64) -> Signal<Never, LeaveGroupCallAsScreencastError> {
            return _internal_leaveGroupCallAsScreencast(account: self.account, callId: callId, accessHash: accessHash)
        }

        public func leaveGroupCall(callId: Int64, accessHash: Int64, source: UInt32) -> Signal<Never, LeaveGroupCallError> {
            return _internal_leaveGroupCall(account: self.account, callId: callId, accessHash: accessHash, source: source)
        }

        public func stopGroupCall(peerId: PeerId, callId: Int64, accessHash: Int64) -> Signal<Never, StopGroupCallError> {
            return _internal_stopGroupCall(account: self.account, peerId: peerId, callId: callId, accessHash: accessHash)
        }

        public func checkGroupCall(callId: Int64, accessHash: Int64, ssrcs: [UInt32]) -> Signal<[UInt32], NoError> {
            return _internal_checkGroupCall(account: account, callId: callId, accessHash: accessHash, ssrcs: ssrcs)
        }

        public func inviteToGroupCall(callId: Int64, accessHash: Int64, peerId: PeerId) -> Signal<Never, InviteToGroupCallError> {
            return _internal_inviteToGroupCall(account: self.account, callId: callId, accessHash: accessHash, peerId: peerId)
        }

        public func groupCallInviteLinks(callId: Int64, accessHash: Int64) -> Signal<GroupCallInviteLinks?, NoError> {
            return _internal_groupCallInviteLinks(account: self.account, callId: callId, accessHash: accessHash)
        }

        public func editGroupCallTitle(callId: Int64, accessHash: Int64, title: String) -> Signal<Never, EditGroupCallTitleError> {
            return _internal_editGroupCallTitle(account: self.account, callId: callId, accessHash: accessHash, title: title)
        }

        /*public func groupCallDisplayAsAvailablePeers(peerId: PeerId) -> Signal<[FoundPeer], NoError> {
            return _internal_groupCallDisplayAsAvailablePeers(network: self.account.network, postbox: self.account.postbox, peerId: peerId)
        }*/

        public func clearCachedGroupCallDisplayAsAvailablePeers(peerId: PeerId) -> Signal<Never, NoError> {
            return _internal_clearCachedGroupCallDisplayAsAvailablePeers(account: self.account, peerId: peerId)
        }

        public func cachedGroupCallDisplayAsAvailablePeers(peerId: PeerId) -> Signal<[FoundPeer], NoError> {
            return _internal_cachedGroupCallDisplayAsAvailablePeers(account: self.account, peerId: peerId)
        }

        public func updatedCurrentPeerGroupCall(peerId: PeerId) -> Signal<EngineGroupCallDescription?, NoError> {
            return _internal_updatedCurrentPeerGroupCall(account: self.account, peerId: peerId)
            |> map { activeCall -> EngineGroupCallDescription? in
                return activeCall.flatMap(EngineGroupCallDescription.init)
            }
        }

        public func getAudioBroadcastDataSource(callId: Int64, accessHash: Int64) -> Signal<AudioBroadcastDataSource?, NoError> {
            return _internal_getAudioBroadcastDataSource(account: self.account, callId: callId, accessHash: accessHash)
        }

        public func getAudioBroadcastPart(dataSource: AudioBroadcastDataSource, callId: Int64, accessHash: Int64, timestampIdMilliseconds: Int64, durationMilliseconds: Int64) -> Signal<GetAudioBroadcastPartResult, NoError> {
            return _internal_getAudioBroadcastPart(dataSource: dataSource, callId: callId, accessHash: accessHash, timestampIdMilliseconds: timestampIdMilliseconds, durationMilliseconds: durationMilliseconds)
        }

        public func getVideoBroadcastPart(dataSource: AudioBroadcastDataSource, callId: Int64, accessHash: Int64, timestampIdMilliseconds: Int64, durationMilliseconds: Int64, channelId: Int32, quality: Int32) -> Signal<GetAudioBroadcastPartResult, NoError> {
            return _internal_getVideoBroadcastPart(dataSource: dataSource, callId: callId, accessHash: accessHash, timestampIdMilliseconds: timestampIdMilliseconds, durationMilliseconds: durationMilliseconds, channelId: channelId, quality: quality)
        }

        public func groupCall(peerId: PeerId, myPeerId: PeerId, id: Int64, accessHash: Int64, state: GroupCallParticipantsContext.State, previousServiceState: GroupCallParticipantsContext.ServiceState?) -> GroupCallParticipantsContext {
            return GroupCallParticipantsContext(account: self.account, peerId: peerId, myPeerId: myPeerId, id: id, accessHash: accessHash, state: state, previousServiceState: previousServiceState)
        }

        public func serverTime() -> Signal<Int64, NoError> {
            return self.account.network.currentGlobalTime
            |> map { value -> Int64 in
                return Int64(value * 1000.0)
            }
            |> take(1)
        }
    }
}
