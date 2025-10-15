import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit
import Foundation

public struct EngineCallStreamState {
    public struct Channel {
        public var id: Int32
        public var scale: Int32
        public var latestTimestamp: Int64
    }
    
    public var channels: [Channel]
}

public extension TelegramEngine {
    final class Calls {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func rateCall(callId: CallId, starsCount: Int32, comment: String = "", userInitiated: Bool) -> Signal<Void, NoError> {
            return _internal_rateCall(account: self.account, callId: callId, starsCount: starsCount, comment: comment, userInitiated: userInitiated)
        }

        public func saveCallDebugLog(callId: CallId, log: String) -> Signal<SaveCallDebugLogResult, NoError> {
            return _internal_saveCallDebugLog(network: self.account.network, callId: callId, log: log)
        }
        
        public func saveCompleteCallDebugLog(callId: CallId, logPath: String) -> Signal<Never, NoError> {
            return _internal_saveCompleteCallDebugLog(account: self.account, callId: callId, logPath: logPath)
        }

        public func getCurrentGroupCall(reference: InternalGroupCallReference, peerId: PeerId? = nil) -> Signal<GroupCallSummary?, GetCurrentGroupCallError> {
            return _internal_getCurrentGroupCall(account: self.account, reference: reference, peerId: peerId)
        }

        public func createGroupCall(peerId: PeerId, title: String?, scheduleDate: Int32?, isExternalStream: Bool) -> Signal<GroupCallInfo, CreateGroupCallError> {
            return _internal_createGroupCall(account: self.account, peerId: peerId, title: title, scheduleDate: scheduleDate, isExternalStream: isExternalStream)
        }

        public func startScheduledGroupCall(peerId: PeerId, callId: Int64, accessHash: Int64) -> Signal<GroupCallInfo, StartScheduledGroupCallError> {
            return _internal_startScheduledGroupCall(account: self.account, peerId: peerId, callId: callId, accessHash: accessHash)
        }

        public func toggleScheduledGroupCallSubscription(peerId: PeerId, reference: InternalGroupCallReference, subscribe: Bool) -> Signal<Void, ToggleScheduledGroupCallSubscriptionError> {
            return _internal_toggleScheduledGroupCallSubscription(account: self.account, peerId: peerId, reference: reference, subscribe: subscribe)
        }

        public func updateGroupCallJoinAsPeer(peerId: PeerId, joinAs: PeerId) -> Signal<Never, UpdateGroupCallJoinAsPeerError> {
            return _internal_updateGroupCallJoinAsPeer(account: self.account, peerId: peerId, joinAs: joinAs)
        }

        public func getGroupCallParticipants(reference: InternalGroupCallReference, offset: String, ssrcs: [UInt32], limit: Int32, sortAscending: Bool?) -> Signal<GroupCallParticipantsContext.State, GetGroupCallParticipantsError> {
            return _internal_getGroupCallParticipants(account: self.account, reference: reference, offset: offset, ssrcs: ssrcs, limit: limit, sortAscending: sortAscending)
        }

        public func joinGroupCall(peerId: PeerId?, joinAs: PeerId?, callId: Int64, reference: InternalGroupCallReference, preferMuted: Bool, joinPayload: String, peerAdminIds: Signal<[PeerId], NoError>, inviteHash: String? = nil, generateE2E: ((Data?) -> JoinGroupCallE2E?)?) -> Signal<JoinGroupCallResult, JoinGroupCallError> {
            return _internal_joinGroupCall(account: self.account, peerId: peerId, joinAs: joinAs, callId: callId, reference: reference, preferMuted: preferMuted, joinPayload: joinPayload, peerAdminIds: peerAdminIds, inviteHash: inviteHash, generateE2E: generateE2E)
        }

        public func joinGroupCallAsScreencast(callId: Int64, accessHash: Int64, joinPayload: String) -> Signal<JoinGroupCallAsScreencastResult, JoinGroupCallError> {
            return _internal_joinGroupCallAsScreencast(account: self.account, callId: callId, accessHash: accessHash, joinPayload: joinPayload)
        }

        public func leaveGroupCallAsScreencast(callId: Int64, accessHash: Int64) -> Signal<Never, LeaveGroupCallAsScreencastError> {
            return _internal_leaveGroupCallAsScreencast(account: self.account, callId: callId, accessHash: accessHash)
        }

        public func leaveGroupCall(callId: Int64, accessHash: Int64, source: UInt32) -> Signal<Never, LeaveGroupCallError> {
            return _internal_leaveGroupCall(account: self.account, callId: callId, accessHash: accessHash, source: source)
        }

        public func stopGroupCall(peerId: PeerId?, callId: Int64, accessHash: Int64) -> Signal<Never, StopGroupCallError> {
            return _internal_stopGroupCall(account: self.account, peerId: peerId, callId: callId, accessHash: accessHash)
        }

        public func checkGroupCall(callId: Int64, accessHash: Int64, ssrcs: [UInt32]) -> Signal<[UInt32], NoError> {
            return _internal_checkGroupCall(account: account, callId: callId, accessHash: accessHash, ssrcs: ssrcs)
        }

        public func inviteToGroupCall(callId: Int64, accessHash: Int64, peerId: PeerId) -> Signal<Never, InviteToGroupCallError> {
            return _internal_inviteToGroupCall(account: self.account, callId: callId, accessHash: accessHash, peerId: peerId)
        }

        public func groupCallInviteLinks(reference: InternalGroupCallReference, isConference: Bool) -> Signal<GroupCallInviteLinks?, NoError> {
            return _internal_groupCallInviteLinks(account: self.account, reference: reference, isConference: isConference)
        }

        public func editGroupCallTitle(callId: Int64, accessHash: Int64, title: String) -> Signal<Never, EditGroupCallTitleError> {
            return _internal_editGroupCallTitle(account: self.account, callId: callId, accessHash: accessHash, title: title)
        }

        public func createConferenceCall() -> Signal<EngineCreatedGroupCall, CreateConferenceCallError> {
            return _internal_createConferenceCall(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId)
        }

        public func revokeConferenceInviteLink(reference: InternalGroupCallReference, link: String) -> Signal<GroupCallInviteLinks, RevokeConferenceInviteLinkError> {
            return _internal_revokeConferenceInviteLink(account: self.account, reference: reference, link: link)
        }
        
        public func pollConferenceCallBlockchain(reference: InternalGroupCallReference, subChainId: Int, offset: Int, limit: Int) -> Signal<(blocks: [Data], nextOffset: Int)?, NoError> {
            return _internal_pollConferenceCallBlockchain(network: self.account.network, reference: reference, subChainId: subChainId, offset: offset, limit: limit)
        }
        
        public func sendConferenceCallBroadcast(callId: Int64, accessHash: Int64, block: Data) -> Signal<Never, NoError> {
            return _internal_sendConferenceCallBroadcast(account: self.account, callId: callId, accessHash: accessHash, block: block)
        }
        
        public func inviteConferenceCallParticipant(reference: InternalGroupCallReference, peerId: EnginePeer.Id, isVideo: Bool) -> Signal<EngineMessage.Id, InviteConferenceCallParticipantError> {
            return _internal_inviteConferenceCallParticipant(account: self.account, reference: reference, peerId: peerId, isVideo: isVideo)
        }
        
        public func removeGroupCallBlockchainParticipants(callId: Int64, accessHash: Int64, mode: RemoveGroupCallBlockchainParticipantsMode, participantIds: [Int64], block: Data) -> Signal<RemoveGroupCallBlockchainParticipantsResult, NoError> {
            return _internal_removeGroupCallBlockchainParticipants(account: self.account, callId: callId, accessHash: accessHash, mode: mode, participantIds: participantIds, block: block)
        }

        public func clearCachedGroupCallDisplayAsAvailablePeers(peerId: PeerId) -> Signal<Never, NoError> {
            return _internal_clearCachedGroupCallDisplayAsAvailablePeers(account: self.account, peerId: peerId)
        }

        public func cachedGroupCallDisplayAsAvailablePeers(peerId: PeerId) -> Signal<[FoundPeer], NoError> {
            return _internal_cachedGroupCallDisplayAsAvailablePeers(account: self.account, peerId: peerId)
        }

        public func updatedCurrentPeerGroupCall(peerId: PeerId) -> Signal<EngineGroupCallDescription?, NoError> {
            return _internal_updatedCurrentPeerGroupCall(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId)
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

        public func groupCall(peerId: PeerId?, myPeerId: PeerId, id: Int64, reference: InternalGroupCallReference, state: GroupCallParticipantsContext.State, previousServiceState: GroupCallParticipantsContext.ServiceState?, e2eContext: ConferenceCallE2EContext?) -> GroupCallParticipantsContext {
            return GroupCallParticipantsContext(account: self.account, peerId: peerId, myPeerId: myPeerId, id: id, reference: reference, state: state, previousServiceState: previousServiceState, e2eContext: e2eContext)
        }

        public func serverTime() -> Signal<Int64, NoError> {
            return self.account.network.currentGlobalTime
            |> map { value -> Int64 in
                return Int64(value * 1000.0)
            }
            |> take(1)
        }
        
        public func requestStreamState(dataSource: AudioBroadcastDataSource, callId: Int64, accessHash: Int64) -> Signal<EngineCallStreamState?, NoError> {
            return dataSource.download.request(Api.functions.phone.getGroupCallStreamChannels(call: .inputGroupCall(id: callId, accessHash: accessHash)))
            |> mapToSignal { result -> Signal<EngineCallStreamState?, MTRpcError> in
                switch result {
                case let .groupCallStreamChannels(channels):
                    let state = EngineCallStreamState(channels: channels.map { channel -> EngineCallStreamState.Channel in
                        switch channel {
                        case let .groupCallStreamChannel(channel, scale, lastTimestampMs):
                            return EngineCallStreamState.Channel(id: channel, scale: scale, latestTimestamp: lastTimestampMs)
                        }
                    })
                    return .single(state)
                }
            }
            |> `catch` { _ -> Signal<EngineCallStreamState?, NoError> in
                return .single(nil)
            }
        }
        
        public func getGroupCallStreamCredentials(peerId: EnginePeer.Id, revokePreviousCredentials: Bool) -> Signal<GroupCallStreamCredentials, GetGroupCallStreamCredentialsError> {
            return _internal_getGroupCallStreamCredentials(account: self.account, peerId: peerId, revokePreviousCredentials: revokePreviousCredentials)
        }
        
        public func getGroupCallPersistentSettings(callId: Int64) -> Signal<CodableEntry?, NoError> {
            return self.account.postbox.transaction { transaction -> CodableEntry? in
                let key = ValueBoxKey(length: 8)
                key.setInt64(0, value: callId)
                return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.groupCallPersistentSettings, key: key))
            }
        }
        
        public func setGroupCallPersistentSettings(callId: Int64, value: CodableEntry) {
            let _ = self.account.postbox.transaction({ transaction -> Void in
                let key = ValueBoxKey(length: 8)
                key.setInt64(0, value: callId)
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.groupCallPersistentSettings, key: key), entry: value)
            }).startStandalone()
        }
    }
}
