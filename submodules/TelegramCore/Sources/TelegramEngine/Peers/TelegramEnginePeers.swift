import Foundation
import SwiftSignalKit
import Postbox

public enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
}

public final class OpaqueChatInterfaceState {
    public let opaqueData: Data?
    public let historyScrollMessageIndex: MessageIndex?
    public let synchronizeableInputState: SynchronizeableChatInputState?

    public init(
        opaqueData: Data?,
        historyScrollMessageIndex: MessageIndex?,
        synchronizeableInputState: SynchronizeableChatInputState?
    ) {
        self.opaqueData = opaqueData
        self.historyScrollMessageIndex = historyScrollMessageIndex
        self.synchronizeableInputState = synchronizeableInputState
    }
}

public extension TelegramEngine {
    enum NextUnreadChannelLocation: Equatable {
        case same
        case archived
        case unarchived
        case folder(id: Int32, title: String)
    }

    final class Peers {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func addressNameAvailability(domain: AddressNameDomain, name: String) -> Signal<AddressNameAvailability, NoError> {
            return _internal_addressNameAvailability(account: self.account, domain: domain, name: name)
        }

        public func updateAddressName(domain: AddressNameDomain, name: String?) -> Signal<Void, UpdateAddressNameError> {
            return _internal_updateAddressName(account: self.account, domain: domain, name: name)
        }

        public func checkPublicChannelCreationAvailability(location: Bool = false) -> Signal<Bool, NoError> {
            return _internal_checkPublicChannelCreationAvailability(account: self.account, location: location)
        }

        public func adminedPublicChannels(scope: AdminedPublicChannelsScope = .all) -> Signal<[Peer], NoError> {
            return _internal_adminedPublicChannels(account: self.account, scope: scope)
        }

        public func channelAddressNameAssignmentAvailability(peerId: PeerId?) -> Signal<ChannelAddressNameAssignmentAvailability, NoError> {
            return _internal_channelAddressNameAssignmentAvailability(account: self.account, peerId: peerId)
        }

        public func validateAddressNameInteractive(domain: AddressNameDomain, name: String) -> Signal<AddressNameValidationStatus, NoError> {
            if let error = _internal_checkAddressNameFormat(name) {
                return .single(.invalidFormat(error))
            } else {
                return .single(.checking)
                |> then(
                    self.addressNameAvailability(domain: domain, name: name)
                    |> delay(0.3, queue: Queue.concurrentDefaultQueue())
                    |> map { result -> AddressNameValidationStatus in
                        .availability(result)
                    }
                )
            }
        }

        public func findChannelById(channelId: Int64) -> Signal<EnginePeer?, NoError> {
            return _internal_findChannelById(postbox: self.account.postbox, network: self.account.network, channelId: channelId)
            |> map { peer in
                return peer.flatMap(EnginePeer.init)
            }
        }

        public func supportPeerId() -> Signal<PeerId?, NoError> {
            return _internal_supportPeerId(account: self.account)
        }

        public func inactiveChannelList() -> Signal<[InactiveChannel], NoError> {
            return _internal_inactiveChannelList(network: self.account.network)
        }

        public func resolvePeerByName(name: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<EnginePeer?, NoError> {
            return _internal_resolvePeerByName(account: self.account, name: name, ageLimit: ageLimit)
            |> mapToSignal { peerId -> Signal<EnginePeer?, NoError> in
                guard let peerId = peerId else {
                    return .single(nil)
                }
                return self.account.postbox.transaction { transaction -> EnginePeer? in
                    return transaction.getPeer(peerId).flatMap(EnginePeer.init)
                }
            }
        }
        
        public func resolvePeerByPhone(phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<EnginePeer?, NoError> {
            return _internal_resolvePeerByPhone(account: self.account, phone: phone, ageLimit: ageLimit)
            |> mapToSignal { peerId -> Signal<EnginePeer?, NoError> in
                guard let peerId = peerId else {
                    return .single(nil)
                }
                return self.account.postbox.transaction { transaction -> EnginePeer? in
                    return transaction.getPeer(peerId).flatMap(EnginePeer.init)
                }
            }
        }

        public func updatedRemotePeer(peer: PeerReference) -> Signal<Peer, UpdatedRemotePeerError> {
            return _internal_updatedRemotePeer(postbox: self.account.postbox, network: self.account.network, peer: peer)
        }

        public func chatOnlineMembers(peerId: PeerId) -> Signal<Int32, NoError> {
            return _internal_chatOnlineMembers(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func convertGroupToSupergroup(peerId: PeerId) -> Signal<PeerId, ConvertGroupToSupergroupError> {
            return _internal_convertGroupToSupergroup(account: self.account, peerId: peerId)
        }

        public func createGroup(title: String, peerIds: [PeerId]) -> Signal<PeerId?, CreateGroupError> {
            return _internal_createGroup(account: self.account, title: title, peerIds: peerIds)
        }

        public func createSecretChat(peerId: PeerId) -> Signal<PeerId, CreateSecretChatError> {
            return _internal_createSecretChat(account: self.account, peerId: peerId)
        }

        public func setChatMessageAutoremoveTimeoutInteractively(peerId: PeerId, timeout: Int32?) -> Signal<Never, SetChatMessageAutoremoveTimeoutError> {
            if peerId.namespace == Namespaces.Peer.SecretChat {
                return _internal_setSecretChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout)
                |> ignoreValues
                    |> castError(SetChatMessageAutoremoveTimeoutError.self)
            } else {
                return _internal_setChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout)
            }
        }

        public func updateChannelSlowModeInteractively(peerId: PeerId, timeout: Int32?) -> Signal<Void, UpdateChannelSlowModeError> {
            return _internal_updateChannelSlowModeInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, timeout: timeout)
        }

        public func reportPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_reportPeer(account: self.account, peerId: peerId)
        }

        public func reportPeer(peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeer(account: self.account, peerId: peerId, reason: reason, message: message)
        }

        public func reportPeerPhoto(peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerPhoto(account: self.account, peerId: peerId, reason: reason, message: message)
        }

        public func reportPeerMessages(messageIds: [MessageId], reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerMessages(account: account, messageIds: messageIds, reason: reason, message: message)
        }

        public func dismissPeerStatusOptions(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_dismissPeerStatusOptions(account: self.account, peerId: peerId)
        }

        public func reportRepliesMessage(messageId: MessageId, deleteMessage: Bool, deleteHistory: Bool, reportSpam: Bool) -> Signal<Never, NoError> {
            return _internal_reportRepliesMessage(account: self.account, messageId: messageId, deleteMessage: deleteMessage, deleteHistory: deleteHistory, reportSpam: reportSpam)
        }

        public func togglePeerMuted(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_togglePeerMuted(account: self.account, peerId: peerId)
        }

        public func updatePeerMuteSetting(peerId: PeerId, muteInterval: Int32?) -> Signal<Void, NoError> {
            return _internal_updatePeerMuteSetting(account: self.account, peerId: peerId, muteInterval: muteInterval)
        }

        public func updatePeerDisplayPreviewsSetting(peerId: PeerId, displayPreviews: PeerNotificationDisplayPreviews) -> Signal<Void, NoError> {
            return _internal_updatePeerDisplayPreviewsSetting(account: self.account, peerId: peerId, displayPreviews: displayPreviews)
        }

        public func updatePeerNotificationSoundInteractive(peerId: PeerId, sound: PeerMessageSound) -> Signal<Void, NoError> {
            return _internal_updatePeerNotificationSoundInteractive(account: self.account, peerId: peerId, sound: sound)
        }

        public func removeCustomNotificationSettings(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    TelegramCore.updatePeerNotificationSoundInteractive(transaction: transaction, peerId: peerId, sound: .default)
                    TelegramCore.updatePeerMuteSetting(transaction: transaction, peerId: peerId, muteInterval: nil)
                    TelegramCore.updatePeerDisplayPreviewsSetting(transaction: transaction, peerId: peerId, displayPreviews: .default)
                }
            }
            |> ignoreValues
        }

        public func channelAdminEventLog(peerId: PeerId) -> ChannelAdminEventLogContext {
            return ChannelAdminEventLogContext(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func updateChannelMemberBannedRights(peerId: PeerId, memberId: PeerId, rights: TelegramChatBannedRights?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> {
            return _internal_updateChannelMemberBannedRights(account: self.account, peerId: peerId, memberId: memberId, rights: rights)
        }

        public func updateDefaultChannelMemberBannedRights(peerId: PeerId, rights: TelegramChatBannedRights) -> Signal<Never, NoError> {
            return _internal_updateDefaultChannelMemberBannedRights(account: self.account, peerId: peerId, rights: rights)
        }

        public func createChannel(title: String, description: String?) -> Signal<PeerId, CreateChannelError> {
            return _internal_createChannel(account: self.account, title: title, description: description)
        }

        public func createSupergroup(title: String, description: String?, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false) -> Signal<PeerId, CreateChannelError> {
            return _internal_createSupergroup(account: self.account, title: title, description: description, location: location, isForHistoryImport: isForHistoryImport)
        }

        public func deleteChannel(peerId: PeerId) -> Signal<Void, DeleteChannelError> {
            return _internal_deleteChannel(account: self.account, peerId: peerId)
        }

        public func updateChannelHistoryAvailabilitySettingsInteractively(peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, ChannelHistoryAvailabilityError> {
            return _internal_updateChannelHistoryAvailabilitySettingsInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, historyAvailableForNewMembers: historyAvailableForNewMembers)
        }

        public func channelMembers(peerId: PeerId, category: ChannelMembersCategory = .recent(.all), offset: Int32 = 0, limit: Int32 = 64, hash: Int64 = 0) -> Signal<[RenderedChannelParticipant]?, NoError> {
            return _internal_channelMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, category: category, offset: offset, limit: limit, hash: hash)
        }

        public func checkOwnershipTranfserAvailability(memberId: PeerId) -> Signal<Never, ChannelOwnershipTransferError> {
            return _internal_checkOwnershipTranfserAvailability(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, memberId: memberId)
        }

        public func updateChannelOwnership(channelId: PeerId, memberId: PeerId, password: String) -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChannelOwnershipTransferError> {
            return _internal_updateChannelOwnership(account: self.account, accountStateManager: self.account.stateManager, channelId: channelId, memberId: memberId, password: password)
        }

        public func searchGroupMembers(peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
            return _internal_searchGroupMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, query: query)
        }

        public func toggleShouldChannelMessagesSignatures(peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleShouldChannelMessagesSignatures(account: self.account, peerId: peerId, enabled: enabled)
        }

        public func toggleMessageCopyProtection(peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleMessageCopyProtection(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func toggleChannelJoinToSend(peerId: PeerId, enabled: Bool) -> Signal<Never, UpdateChannelJoinToSendError> {
            return _internal_toggleChannelJoinToSend(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, enabled: enabled)
        }
        
        public func toggleChannelJoinRequest(peerId: PeerId, enabled: Bool) -> Signal<Never, UpdateChannelJoinRequestError> {
            return _internal_toggleChannelJoinRequest(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, enabled: enabled)
        }

        public func requestPeerPhotos(peerId: PeerId) -> Signal<[TelegramPeerPhoto], NoError> {
            return _internal_requestPeerPhotos(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func updateGroupSpecificStickerset(peerId: PeerId, info: StickerPackCollectionInfo?) -> Signal<Void, UpdateGroupSpecificStickersetError> {
            return _internal_updateGroupSpecificStickerset(postbox: self.account.postbox, network: self.account.network, peerId: peerId, info: info)
        }

        public func joinChannel(peerId: PeerId, hash: String?) -> Signal<RenderedChannelParticipant?, JoinChannelError> {
            return _internal_joinChannel(account: self.account, peerId: peerId, hash: hash)
        }

        public func removePeerMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
            return _internal_removePeerMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func availableGroupsForChannelDiscussion() -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
            return _internal_availableGroupsForChannelDiscussion(postbox: self.account.postbox, network: self.account.network)
        }

        public func updateGroupDiscussionForChannel(channelId: PeerId?, groupId: PeerId?) -> Signal<Bool, ChannelDiscussionGroupError> {
            return _internal_updateGroupDiscussionForChannel(network: self.account.network, postbox: self.account.postbox, channelId: channelId, groupId: groupId)
        }

        public func peerCommands(id: PeerId) -> Signal<PeerCommands, NoError> {
            return _internal_peerCommands(account: self.account, id: id)
        }

        public func addGroupAdmin(peerId: PeerId, adminId: PeerId) -> Signal<Void, AddGroupAdminError> {
            return _internal_addGroupAdmin(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func removeGroupAdmin(peerId: PeerId, adminId: PeerId) -> Signal<Void, RemoveGroupAdminError> {
            return _internal_removeGroupAdmin(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func fetchChannelParticipant(peerId: PeerId, participantId: PeerId) -> Signal<ChannelParticipant?, NoError> {
            return _internal_fetchChannelParticipant(account: self.account, peerId: peerId, participantId: participantId)
        }

        public func updateChannelAdminRights(peerId: PeerId, adminId: PeerId, rights: TelegramChatAdminRights?, rank: String?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), UpdateChannelAdminRightsError> {
            return _internal_updateChannelAdminRights(account: self.account, peerId: peerId, adminId: adminId, rights: rights, rank: rank)
        }

        public func peerSpecificStickerPack(peerId: PeerId) -> Signal<PeerSpecificStickerPackData, NoError> {
            return _internal_peerSpecificStickerPack(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func addRecentlySearchedPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_addRecentlySearchedPeer(postbox: self.account.postbox, peerId: peerId)
        }

        public func removeRecentlySearchedPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentlySearchedPeer(postbox: self.account.postbox, peerId: peerId)
        }

        public func clearRecentlySearchedPeers() -> Signal<Void, NoError> {
            return _internal_clearRecentlySearchedPeers(postbox: self.account.postbox)
        }

        public func recentlySearchedPeers() -> Signal<[RecentlySearchedPeer], NoError> {
            return _internal_recentlySearchedPeers(postbox: self.account.postbox)
        }

        public func removePeerChat(peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool = false) -> Signal<Void, NoError> {
            return _internal_removePeerChat(account: self.account, peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible)
        }

        public func removePeerChats(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_removePeerChat(account: self.account, transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: peerId.namespace == Namespaces.Peer.SecretChat)
                }
            }
            |> ignoreValues
        }

        public func terminateSecretChat(peerId: PeerId, requestRemoteHistoryRemoval: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_terminateSecretChat(transaction: transaction, peerId: peerId, requestRemoteHistoryRemoval: requestRemoteHistoryRemoval)
            }
            |> ignoreValues
        }

        public func addGroupMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, AddGroupMemberError> {
            return _internal_addGroupMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func addChannelMember(peerId: PeerId, memberId: PeerId) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> {
            return _internal_addChannelMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func addChannelMembers(peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, AddChannelMemberError> {
            return _internal_addChannelMembers(account: self.account, peerId: peerId, memberIds: memberIds)
        }

        public func recentPeers() -> Signal<RecentPeers, NoError> {
            return _internal_recentPeers(account: self.account)
        }

        public func managedUpdatedRecentPeers() -> Signal<Void, NoError> {
            return _internal_managedUpdatedRecentPeers(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network)
        }

        public func removeRecentPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentPeer(account: self.account, peerId: peerId)
        }

        public func updateRecentPeersEnabled(enabled: Bool) -> Signal<Void, NoError> {
            return _internal_updateRecentPeersEnabled(postbox: self.account.postbox, network: self.account.network, enabled: enabled)
        }

        public func addRecentlyUsedInlineBot(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_addRecentlyUsedInlineBot(postbox: self.account.postbox, peerId: peerId)
        }

        public func recentlyUsedInlineBots() -> Signal<[(EnginePeer, Double)], NoError> {
            return _internal_recentlyUsedInlineBots(postbox: self.account.postbox)
            |> map { list -> [(EnginePeer, Double)] in
                return list.map { peer, rating in
                    return (EnginePeer(peer), rating)
                }
            }
        }

        public func removeRecentlyUsedInlineBot(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentlyUsedInlineBot(account: self.account, peerId: peerId)
        }

        public func uploadedPeerPhoto(resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
            return _internal_uploadedPeerPhoto(postbox: self.account.postbox, network: self.account.network, resource: resource)
        }

        public func uploadedPeerVideo(resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
            return _internal_uploadedPeerVideo(postbox: self.account.postbox, network: self.account.network, messageMediaPreuploadManager: self.account.messageMediaPreuploadManager, resource: resource)
        }

        public func updatePeerPhoto(peerId: PeerId, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>? = nil, videoStartTimestamp: Double? = nil, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updatePeerPhoto(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, accountPeerId: self.account.peerId, peerId: peerId, photo: photo, video: video, videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
        }

        public func requestUpdateChatListFilter(id: Int32, filter: ChatListFilter?) -> Signal<Never, RequestUpdateChatListFilterError> {
            return _internal_requestUpdateChatListFilter(postbox: self.account.postbox, network: self.account.network, id: id, filter: filter)
        }

        public func requestUpdateChatListFilterOrder(ids: [Int32]) -> Signal<Never, RequestUpdateChatListFilterOrderError> {
            return _internal_requestUpdateChatListFilterOrder(account: self.account, ids: ids)
        }

        public func generateNewChatListFilterId(filters: [ChatListFilter]) -> Int32 {
            return _internal_generateNewChatListFilterId(filters: filters)
        }

        public func updateChatListFiltersInteractively(_ f: @escaping ([ChatListFilter]) -> [ChatListFilter]) -> Signal<[ChatListFilter], NoError> {
            return _internal_updateChatListFiltersInteractively(postbox: self.account.postbox, f)
        }

        public func updatedChatListFilters() -> Signal<[ChatListFilter], NoError> {
            return _internal_updatedChatListFilters(postbox: self.account.postbox)
        }

        public func updatedChatListFiltersInfo() -> Signal<(filters: [ChatListFilter], synchronized: Bool), NoError> {
            return _internal_updatedChatListFiltersInfo(postbox: self.account.postbox)
        }

        public func currentChatListFilters() -> Signal<[ChatListFilter], NoError> {
            return _internal_currentChatListFilters(postbox: self.account.postbox)
        }

        public func markChatListFeaturedFiltersAsSeen() -> Signal<Never, NoError> {
            return _internal_markChatListFeaturedFiltersAsSeen(postbox: self.account.postbox)
        }

        public func updateChatListFeaturedFilters() -> Signal<Never, NoError> {
            return _internal_updateChatListFeaturedFilters(postbox: self.account.postbox, network: self.account.network)
        }

        public func unmarkChatListFeaturedFiltersAsSeen() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction in
                _internal_unmarkChatListFeaturedFiltersAsSeen(transaction: transaction)
            }
            |> ignoreValues
        }

        public func checkPeerChatServiceActions(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_checkPeerChatServiceActions(postbox: self.account.postbox, peerId: peerId)
        }

        public func createPeerExportedInvitation(peerId: PeerId, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool?) -> Signal<ExportedInvitation?, CreatePeerExportedInvitationError> {
            return _internal_createPeerExportedInvitation(account: self.account, peerId: peerId, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded)
        }

        public func editPeerExportedInvitation(peerId: PeerId, link: String, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool?) -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> {
            return _internal_editPeerExportedInvitation(account: self.account, peerId: peerId, link: link, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded)
        }

        public func revokePeerExportedInvitation(peerId: PeerId, link: String) -> Signal<RevokeExportedInvitationResult?, RevokePeerExportedInvitationError> {
            return _internal_revokePeerExportedInvitation(account: self.account, peerId: peerId, link: link)
        }

        public func deletePeerExportedInvitation(peerId: PeerId, link: String) -> Signal<Never, DeletePeerExportedInvitationError> {
            return _internal_deletePeerExportedInvitation(account: self.account, peerId: peerId, link: link)
        }

        public func deleteAllRevokedPeerExportedInvitations(peerId: PeerId, adminId: PeerId) -> Signal<Never, NoError> {
            return _internal_deleteAllRevokedPeerExportedInvitations(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func peerExportedInvitationsCreators(peerId: PeerId) -> Signal<[ExportedInvitationCreator], NoError> {
            return _internal_peerExportedInvitationsCreators(account: self.account, peerId: peerId)
        }
        public func direct_peerExportedInvitations(peerId: PeerId, revoked: Bool, adminId: PeerId? = nil, offsetLink: ExportedInvitation? = nil) -> Signal<ExportedInvitations?, NoError> {
            return _internal_peerExportedInvitations(account: self.account, peerId: peerId, revoked: revoked, adminId: adminId, offsetLink: offsetLink)
        }

        public func peerExportedInvitations(peerId: PeerId, adminId: PeerId?, revoked: Bool, forceUpdate: Bool) -> PeerExportedInvitationsContext {
            return PeerExportedInvitationsContext(account: self.account, peerId: peerId, adminId: adminId, revoked: revoked, forceUpdate: forceUpdate)
        }
        
        public func revokePersistentPeerExportedInvitation(peerId: PeerId) -> Signal<ExportedInvitation?, NoError> {
            return _internal_revokePersistentPeerExportedInvitation(account: self.account, peerId: peerId)
        }

        public func peerInvitationImporters(peerId: PeerId, subject: PeerInvitationImportersContext.Subject) -> PeerInvitationImportersContext {
            return PeerInvitationImportersContext(account: self.account, peerId: peerId, subject: subject)
        }

        public func notificationExceptionsList() -> Signal<NotificationExceptionsList, NoError> {
            return _internal_notificationExceptionsList(postbox: self.account.postbox, network: self.account.network)
        }

        public func fetchAndUpdateCachedPeerData(peerId: PeerId) -> Signal<Bool, NoError> {
            return _internal_fetchAndUpdateCachedPeerData(accountPeerId: self.account.peerId, peerId: peerId, network: self.account.network, postbox: self.account.postbox)
        }

        public func toggleItemPinned(location: TogglePeerChatPinnedLocation, itemId: PinnedItemId) -> Signal<TogglePeerChatPinnedResult, NoError> {
            return _internal_toggleItemPinned(postbox: self.account.postbox, accountPeerId: self.account.peerId, location: location, itemId: itemId)
        }

        public func getPinnedItemIds(location: TogglePeerChatPinnedLocation) -> Signal<[PinnedItemId], NoError> {
            return self.account.postbox.transaction { transaction -> [PinnedItemId] in
                return _internal_getPinnedItemIds(transaction: transaction, location: location)
            }
        }

        public func reorderPinnedItemIds(location: TogglePeerChatPinnedLocation, itemIds: [PinnedItemId]) -> Signal<Bool, NoError> {
            return self.account.postbox.transaction { transaction -> Bool in
                return _internal_reorderPinnedItemIds(transaction: transaction, location: location, itemIds: itemIds)
            }
        }

        public func joinChatInteractively(with hash: String) -> Signal <PeerId?, JoinLinkError> {
            return _internal_joinChatInteractively(with: hash, account: self.account)
        }

        public func joinLinkInformation(_ hash: String) -> Signal<ExternalJoiningChatState, JoinLinkInfoError> {
            return _internal_joinLinkInformation(hash, account: self.account)
        }

        public func updatePeerTitle(peerId: PeerId, title: String) -> Signal<Void, UpdatePeerTitleError> {
            return _internal_updatePeerTitle(account: self.account, peerId: peerId, title: title)
        }

        public func updatePeerDescription(peerId: PeerId, description: String?) -> Signal<Void, UpdatePeerDescriptionError> {
            return _internal_updatePeerDescription(account: self.account, peerId: peerId, description: description)
        }

        public func getNextUnreadChannel(peerId: PeerId, chatListFilterId: Int32?, getFilterPredicate: @escaping (ChatListFilterData) -> ChatListFilterPredicate) -> Signal<(peer: EnginePeer, unreadCount: Int, location: NextUnreadChannelLocation)?, NoError> {
            return self.account.postbox.transaction { transaction -> (peer: EnginePeer, unreadCount: Int, location: NextUnreadChannelLocation)? in
                func getForFilter(predicate: ChatListFilterPredicate?, isArchived: Bool) -> (peer: EnginePeer, unreadCount: Int)? {
                    var peerIds: [PeerId] = []
                    if predicate != nil {
                        peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: .root, filterPredicate: predicate))
                        peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: Namespaces.PeerGroup.archive, filterPredicate: predicate))
                    } else {
                        if isArchived {
                            peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: Namespaces.PeerGroup.archive, filterPredicate: nil))
                        } else {
                            peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: .root, filterPredicate: nil))
                        }
                    }

                    var results: [(EnginePeer, PeerGroupId, ChatListIndex)] = []

                    for listId in peerIds {
                        guard let peer = transaction.getPeer(listId) else {
                            continue
                        }
                        guard let channel = peer as? TelegramChannel, case .broadcast = channel.info else {
                            continue
                        }
                        if channel.id == peerId {
                            continue
                        }
                        guard let readState = transaction.getCombinedPeerReadState(channel.id), readState.count != 0 else {
                            continue
                        }
                        guard let (groupId, index) = transaction.getPeerChatListIndex(channel.id) else {
                            continue
                        }

                        results.append((EnginePeer(channel), groupId, index))
                    }

                    results.sort(by: { $0.2 > $1.2 })

                    if let peer = results.first?.0 {
                        let unreadCount: Int32 = transaction.getCombinedPeerReadState(peer.id)?.count ?? 0
                        return (peer: peer, unreadCount: Int(unreadCount))
                    } else {
                        return nil
                    }
                }

                let peerGroupId: PeerGroupId
                if let peerGroupIdValue = transaction.getPeerChatListIndex(peerId)?.0 {
                    peerGroupId = peerGroupIdValue
                } else {
                    peerGroupId = .root
                }

                if let filterId = chatListFilterId {
                    let filters = _internal_currentChatListFilters(transaction: transaction)
                    guard let index = filters.firstIndex(where: { $0.id == filterId }) else {
                        return nil
                    }
                    var sortedFilters: [ChatListFilter] = []
                    sortedFilters.append(contentsOf: filters[index...])
                    sortedFilters.append(contentsOf: filters[0 ..< index])
                    for i in 0 ..< sortedFilters.count {
                        if case let .filter(id, title, _, data) = sortedFilters[i] {
                            if let value = getForFilter(predicate: getFilterPredicate(data), isArchived: false) {
                                return (peer: value.peer, unreadCount: value.unreadCount, location: i == 0 ? .same : .folder(id: id, title: title))
                            }
                        }
                    }
                    return nil
                } else {
                    let folderOrder: [(PeerGroupId, NextUnreadChannelLocation)]
                    if peerGroupId == .root {
                        folderOrder = [
                            (.root, .same),
                            (Namespaces.PeerGroup.archive, .archived),
                        ]
                    } else {
                        folderOrder = [
                            (Namespaces.PeerGroup.archive, .same),
                            (.root, .unarchived),
                        ]
                    }

                    for (groupId, location) in folderOrder {
                        if let value = getForFilter(predicate: nil, isArchived: groupId != .root) {
                            return (peer: value.peer, unreadCount: value.unreadCount, location: location)
                        }
                    }
                    return nil
                }
            }
        }

        public func getOpaqueChatInterfaceState(peerId: PeerId, threadId: Int64?) -> Signal<OpaqueChatInterfaceState?, NoError> {
            return self.account.postbox.transaction { transaction -> OpaqueChatInterfaceState? in
                let storedState: StoredPeerChatInterfaceState?
                if let threadId = threadId {
                    storedState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId)
                } else {
                    storedState = transaction.getPeerChatInterfaceState(peerId)
                }

                guard let state = storedState, let data = state.data else {
                    return nil
                }
                guard let internalState = try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data) else {
                    return nil
                }
                return OpaqueChatInterfaceState(
                    opaqueData: internalState.opaqueData,
                    historyScrollMessageIndex: internalState.historyScrollMessageIndex,
                    synchronizeableInputState: internalState.synchronizeableInputState
                )
            }
        }

        public func setOpaqueChatInterfaceState(peerId: PeerId, threadId: Int64?, state: OpaqueChatInterfaceState) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                guard let data = try? AdaptedPostboxEncoder().encode(InternalChatInterfaceState(
                    synchronizeableInputState: state.synchronizeableInputState,
                    historyScrollMessageIndex: state.historyScrollMessageIndex,
                    opaqueData: state.opaqueData
                )) else {
                    return
                }

                #if DEBUG
                let _ = try! AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data)
                #endif

                let storedState = StoredPeerChatInterfaceState(
                    overrideChatTimestamp: state.synchronizeableInputState?.timestamp,
                    historyScrollMessageIndex: state.historyScrollMessageIndex,
                    associatedMessageIds: (state.synchronizeableInputState?.replyToMessageId).flatMap({ [$0] }) ?? [],
                    data: data
                )

                if let threadId = threadId {
                    transaction.setPeerChatThreadInterfaceState(peerId, threadId: threadId, state: storedState)
                } else {
                    var currentInputState: SynchronizeableChatInputState?
                    if let peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId), let data = peerChatInterfaceState.data {
                        currentInputState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
                    }
                    let updatedInputState = state.synchronizeableInputState

                    if currentInputState != updatedInputState {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                            addSynchronizeChatInputStateOperation(transaction: transaction, peerId: peerId)
                        }
                    }
                    transaction.setPeerChatInterfaceState(
                        peerId,
                        state: storedState
                    )
                }
            }
            |> ignoreValues
        }
        
        public func sendAsAvailablePeers(peerId: PeerId) -> Signal<[FoundPeer], NoError> {
            return _internal_cachedPeerSendAsAvailablePeers(account: self.account, peerId: peerId)
        }
        
        public func updatePeerSendAsPeer(peerId: PeerId, sendAs: PeerId) -> Signal<Never, UpdatePeerSendAsPeerError> {
            return _internal_updatePeerSendAsPeer(account: self.account, peerId: peerId, sendAs: sendAs)
        }
        
        public func updatePeerAllowedReactions(peerId: PeerId, allowedReactions: [String]) -> Signal<Never, UpdatePeerAllowedReactionsError> {
            return _internal_updatePeerAllowedReactions(account: account, peerId: peerId, allowedReactions: allowedReactions)
        }
        
        public func notificationSoundList() -> Signal<NotificationSoundList?, NoError> {
            let key = PostboxViewKey.cachedItem(_internal_cachedNotificationSoundListCacheKey())
            return self.account.postbox.combinedView(keys: [key])
            |> map { views -> NotificationSoundList? in
                guard let view = views.views[key] as? CachedItemView else {
                    return nil
                }
                return view.value?.get(NotificationSoundList.self)
            }
        }
        
        public func saveNotificationSound(file: FileMediaReference) -> Signal<Never, UploadNotificationSoundError> {
            return _internal_saveNotificationSound(account: self.account, file: file)
        }
        public func removeNotificationSound(file: FileMediaReference) -> Signal<Never, UploadNotificationSoundError> {
            return _internal_saveNotificationSound(account: self.account, file: file, unsave: true)
        }
        
        public func uploadNotificationSound(title: String, data: Data) -> Signal<NotificationSoundList.NotificationSound, UploadNotificationSoundError> {
            return _internal_uploadNotificationSound(account: self.account, title: title, data: data)
        }
        
        public func deleteNotificationSound(fileId: Int64) -> Signal<Never, DeleteNotificationSoundError> {
            return _internal_deleteNotificationSound(account: self.account, fileId: fileId)
        }
        
        public func ensurePeerIsLocallyAvailable(peer: EnginePeer) -> Signal<EnginePeer.Id, NoError> {
            return _internal_storedMessageFromSearchPeer(account: self.account, peer: peer._asPeer())
        }
        
        public func ensurePeersAreLocallyAvailable(peers: [EnginePeer]) -> Signal<Never, NoError> {
            return _internal_storedMessageFromSearchPeers(account: self.account, peers: peers.map { $0._asPeer() })
        }
        
        public func mostRecentSecretChat(id: EnginePeer.Id) -> Signal<EnginePeer.Id?, NoError> {
            return self.account.postbox.transaction { transaction -> EnginePeer.Id? in
                let filteredPeerIds = Array(transaction.getAssociatedPeerIds(id)).filter { $0.namespace == Namespaces.Peer.SecretChat }
                var activeIndices: [ChatListIndex] = []
                for associatedId in filteredPeerIds {
                    if let state = (transaction.getPeer(associatedId) as? TelegramSecretChat)?.embeddedState {
                        switch state {
                        case .active, .handshake:
                            if let (_, index) = transaction.getPeerChatListIndex(associatedId) {
                                activeIndices.append(index)
                            }
                        default:
                            break
                        }
                    }
                }
                activeIndices.sort()
                if let index = activeIndices.last {
                    return index.messageIndex.id.peerId
                } else {
                    return nil
                }
            }
        }
        
        public func updatePeersGroupIdInteractively(peerIds: [EnginePeer.Id], groupId: EngineChatList.Group) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerGroupIdInteractively(transaction: transaction, peerId: peerId, groupId: groupId._asGroup())
                }
            }
            |> ignoreValues
        }
        
        public func resetAllPeerNotificationSettings() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.resetAllPeerNotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
            }
            |> ignoreValues
        }
    }
}

public func _internal_decodeStoredChatInterfaceState(state: StoredPeerChatInterfaceState) -> OpaqueChatInterfaceState? {
    guard let data = state.data else {
        return nil
    }
    guard let internalState = try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data) else {
        return nil
    }
    return OpaqueChatInterfaceState(
        opaqueData: internalState.opaqueData,
        historyScrollMessageIndex: internalState.historyScrollMessageIndex,
        synchronizeableInputState: internalState.synchronizeableInputState
    )
}
