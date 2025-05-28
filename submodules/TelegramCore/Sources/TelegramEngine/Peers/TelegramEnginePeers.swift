import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
}

public typealias EngineStringIndexTokenTransliteration = StringIndexTokenTransliteration

public final class OpaqueChatInterfaceState {
    public let opaqueData: Data?
    public let historyScrollMessageIndex: MessageIndex?
    public let mediaDraftState: MediaDraftState?
    public let synchronizeableInputState: SynchronizeableChatInputState?

    public init(
        opaqueData: Data?,
        historyScrollMessageIndex: MessageIndex?,
        mediaDraftState: MediaDraftState?,
        synchronizeableInputState: SynchronizeableChatInputState?
    ) {
        self.opaqueData = opaqueData
        self.historyScrollMessageIndex = historyScrollMessageIndex
        self.mediaDraftState = mediaDraftState
        self.synchronizeableInputState = synchronizeableInputState
    }
}

public final class TelegramCollectibleItemInfo: Equatable {
    public enum Subject: Equatable {
        case username(String)
        case phoneNumber(String)
    }
    
    public let subject: Subject
    public let purchaseDate: Int32
    public let currency: String
    public let currencyAmount: Int64
    public let cryptoCurrency: String
    public let cryptoCurrencyAmount: Int64
    public let url: String
    
    public init(subject: Subject, purchaseDate: Int32, currency: String, currencyAmount: Int64, cryptoCurrency: String, cryptoCurrencyAmount: Int64, url: String) {
        self.subject = subject
        self.purchaseDate = purchaseDate
        self.currency = currency
        self.currencyAmount = currencyAmount
        self.cryptoCurrency = cryptoCurrency
        self.cryptoCurrencyAmount = cryptoCurrencyAmount
        self.url = url
    }
    
    public static func ==(lhs: TelegramCollectibleItemInfo, rhs: TelegramCollectibleItemInfo) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.purchaseDate != rhs.purchaseDate {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        if lhs.currencyAmount != rhs.currencyAmount {
            return false
        }
        if lhs.cryptoCurrency != rhs.cryptoCurrency {
            return false
        }
        if lhs.cryptoCurrencyAmount != rhs.cryptoCurrencyAmount {
            return false
        }
        if lhs.url != rhs.url {
            return false
        }
        return true
    }
}

public final class TelegramResolvedMessageLink {
    public let peer: EnginePeer
    public let message: String
    public let entities: [MessageTextEntity]
    
    public init(peer: EnginePeer, message: String, entities: [MessageTextEntity]) {
        self.peer = peer
        self.message = message
        self.entities = entities
    }
}

public enum TelegramPaidReactionPrivacy: Equatable, Codable {
    case `default`
    case anonymous
    case peer(PeerId)
    
    enum CodingKeys: String, CodingKey {
        case `default` = "d"
        case anonymous = "a"
        case peer = "p"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if try container.decodeNil(forKey: .default) {
            self = .default
        } else if try container.decodeNil(forKey: .anonymous) {
            self = .anonymous
        } else {
            let peerId = PeerId(try container.decode(Int64.self, forKey: .peer))
            self = .peer(peerId)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .default:
            try container.encodeNil(forKey: .default)
        case .anonymous:
            try container.encodeNil(forKey: .anonymous)
        case let .peer(peerId):
            try container.encode(peerId.toInt64(), forKey: .peer)
        }
    }
}

public extension TelegramEngine {
    enum NextUnreadChannelLocation: Equatable {
        case same
        case archived
        case unarchived
        case folder(id: Int32, title: ChatFolderTitle)
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
        
        public func deactivateAllAddressNames(peerId: EnginePeer.Id) -> Signal<Never, DeactivateAllAddressNamesError> {
            return _internal_deactivateAllAddressNames(account: self.account, peerId: peerId)
        }
        
        public func toggleAddressNameActive(domain: AddressNameDomain, name: String, active: Bool) -> Signal<Void, ToggleAddressNameActiveError> {
            return _internal_toggleAddressNameActive(account: self.account, domain: domain, name: name, active: active)
        }
        
        public func reorderAddressNames(domain: AddressNameDomain, names: [TelegramPeerUsername]) -> Signal<Void, ReorderAddressNamesError> {
            return _internal_reorderAddressNames(account: self.account, domain: domain, names: names)
        }
        
        public func checkPublicChannelCreationAvailability(location: Bool = false) -> Signal<Bool, NoError> {
            return _internal_checkPublicChannelCreationAvailability(account: self.account, location: location)
        }

        public func adminedPublicChannels(scope: AdminedPublicChannelsScope = .all) -> Signal<[TelegramAdminedPublicChannel], NoError> {
            return _internal_adminedPublicChannels(account: self.account, scope: scope)
        }
        
        public func channelsForStories() -> Signal<[EnginePeer], NoError> {
            return _internal_channelsForStories(account: self.account)
            |> map { peers -> [EnginePeer] in
                return peers.map(EnginePeer.init)
            }
        }
        
        public func channelsForPublicReaction(useLocalCache: Bool) -> Signal<[EnginePeer], NoError> {
            return _internal_channelsForPublicReaction(account: self.account, useLocalCache: useLocalCache)
            |> map { peers -> [EnginePeer] in
                return peers.map(EnginePeer.init)
            }
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
            return _internal_findChannelById(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, channelId: channelId)
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

        public func resolvePeerByName(name: String, referrer: String?, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvePeerResult, NoError> {
            return _internal_resolvePeerByName(account: self.account, name: name, referrer: referrer, ageLimit: ageLimit)
            |> mapToSignal { result -> Signal<ResolvePeerResult, NoError> in
                switch result {
                case .progress:
                    return .single(.progress)
                case let .result(peerId):
                    guard let peerId = peerId else {
                        return .single(.result(nil))
                    }
                    return self.account.postbox.transaction { transaction -> ResolvePeerResult in
                        return .result(transaction.getPeer(peerId).flatMap(EnginePeer.init))
                    }
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
            return _internal_updatedRemotePeer(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, peer: peer)
        }

        public func chatOnlineMembers(peerId: PeerId) -> Signal<Int32, NoError> {
            return _internal_chatOnlineMembers(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func convertGroupToSupergroup(peerId: PeerId, additionalProcessing: ((EnginePeer.Id) -> Signal<Never, NoError>)? = nil) -> Signal<PeerId, ConvertGroupToSupergroupError> {
            return _internal_convertGroupToSupergroup(account: self.account, peerId: peerId, additionalProcessing: additionalProcessing)
        }

        public func createGroup(title: String, peerIds: [PeerId], ttlPeriod: Int32?) -> Signal<CreateGroupResult?, CreateGroupError> {
            return _internal_createGroup(account: self.account, title: title, peerIds: peerIds, ttlPeriod: ttlPeriod)
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
        
        public func setChatMessageAutoremoveTimeouts(peerIds: [EnginePeer.Id], timeout: Int32?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    if peerId.namespace == Namespaces.Peer.SecretChat {
                        _internal_setSecretChatMessageAutoremoveTimeoutInteractively(transaction: transaction, account: self.account, peerId: peerId, timeout: timeout)
                    } else {
                        var canManage = false
                        guard let peer = transaction.getPeer(peerId) else {
                            continue
                        }
                        if let user = peer as? TelegramUser {
                            if user.botInfo == nil {
                                canManage = true
                            }
                        } else if let _ = peer as? TelegramSecretChat {
                            canManage = true
                        } else if let group = peer as? TelegramGroup {
                            canManage = !group.hasBannedPermission(.banChangeInfo)
                        } else if let channel = peer as? TelegramChannel {
                            canManage = channel.hasPermission(.changeInfo)
                        }
                        
                        if !canManage {
                            continue
                        }
                        
                        let cachedData = transaction.getPeerCachedData(peerId: peerId)
                        var currentValue: Int32?
                        if let cachedData = cachedData as? CachedUserData {
                            if case let .known(value) = cachedData.autoremoveTimeout {
                                currentValue = value?.effectiveValue
                            }
                        } else if let cachedData = cachedData as? CachedGroupData {
                            if case let .known(value) = cachedData.autoremoveTimeout {
                                currentValue = value?.effectiveValue
                            }
                        } else if let cachedData = cachedData as? CachedChannelData {
                            if case let .known(value) = cachedData.autoremoveTimeout {
                                currentValue = value?.effectiveValue
                            }
                        }
                        if currentValue != timeout {
                            let _ = _internal_setChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout).start()
                        }
                    }
                }
            }
            |> ignoreValues
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
            return _internal_reportPeerMessages(account: self.account, messageIds: messageIds, reason: reason, message: message)
        }
        
        public func reportPeerStory(peerId: PeerId, storyId: Int32, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerStory(account: self.account, peerId: peerId, storyId: storyId, reason: reason, message: message)
        }
        
        public func reportPeerReaction(authorId: PeerId, messageId: MessageId) -> Signal<Never, NoError> {
            return _internal_reportPeerReaction(account: self.account, authorId: authorId, messageId: messageId)
        }

        public func dismissPeerStatusOptions(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_dismissPeerStatusOptions(account: self.account, peerId: peerId)
        }

        public func reportRepliesMessage(messageId: MessageId, deleteMessage: Bool, deleteHistory: Bool, reportSpam: Bool) -> Signal<Never, NoError> {
            return _internal_reportRepliesMessage(account: self.account, messageId: messageId, deleteMessage: deleteMessage, deleteHistory: deleteHistory, reportSpam: reportSpam)
        }

        public func togglePeerMuted(peerId: PeerId, threadId: Int64?) -> Signal<Void, NoError> {
            return _internal_togglePeerMuted(account: self.account, peerId: peerId, threadId: threadId)
        }
        
        public func togglePeerStoriesMuted(peerId: EnginePeer.Id) -> Signal<Never, NoError> {
            return _internal_togglePeerStoriesMuted(account: self.account, peerId: peerId)
            |> ignoreValues
        }

        public func updatePeerMuteSetting(peerId: PeerId, threadId: Int64?, muteInterval: Int32?) -> Signal<Void, NoError> {
            return _internal_updatePeerMuteSetting(account: self.account, peerId: peerId, threadId: threadId, muteInterval: muteInterval)
        }
        
        public func updateMultiplePeerMuteSettings(peerIds: [EnginePeer.Id], muted: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerMuteSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, muteInterval: muted ? Int32.max : nil)
                }
            }
            |> ignoreValues
        }

        public func updatePeerDisplayPreviewsSetting(peerId: PeerId, threadId: Int64?, displayPreviews: PeerNotificationDisplayPreviews) -> Signal<Void, NoError> {
            return _internal_updatePeerDisplayPreviewsSetting(account: self.account, peerId: peerId, threadId: threadId, displayPreviews: displayPreviews)
        }
        
        public func updatePeerStoriesMutedSetting(peerId: PeerId, mute: PeerStoryNotificationSettings.Mute) -> Signal<Void, NoError> {
            return _internal_updatePeerStoriesMutedSetting(account: self.account, peerId: peerId, mute: mute)
        }
        
        public func updatePeerStoriesHideSenderSetting(peerId: PeerId, hideSender: PeerStoryNotificationSettings.HideSender) -> Signal<Void, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_updatePeerStoriesHideSenderSetting(account: self.account, transaction: transaction, peerId: peerId, hideSender: hideSender)
            }
        }
        
        public func updatePeerStorySoundInteractive(peerId: PeerId, sound: PeerMessageSound) -> Signal<Void, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_updatePeerStoryNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, sound: sound)
            }
        }

        public func updatePeerNotificationSoundInteractive(peerId: PeerId, threadId: Int64?, sound: PeerMessageSound) -> Signal<Void, NoError> {
            return _internal_updatePeerNotificationSoundInteractive(account: self.account, peerId: peerId, threadId: threadId, sound: sound)
        }

        public func removeCustomNotificationSettings(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, sound: .default)
                    _internal_updatePeerMuteSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, muteInterval: nil)
                    _internal_updatePeerDisplayPreviewsSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, displayPreviews: .default)
                }
            }
            |> ignoreValues
        }
        
        public func removeCustomThreadNotificationSettings(peerId: EnginePeer.Id, threadIds: [Int64]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for threadId in threadIds {
                    _internal_updatePeerNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, threadId: threadId, sound: .default)
                    _internal_updatePeerMuteSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: threadId, muteInterval: nil)
                    _internal_updatePeerDisplayPreviewsSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: threadId, displayPreviews: .default)
                }
            }
            |> ignoreValues
        }
        
        public func removeCustomStoryNotificationSettings(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerStoriesMutedSetting(account: self.account, transaction: transaction, peerId: peerId, mute: .default)
                    _internal_updatePeerStoriesHideSenderSetting(account: self.account, transaction: transaction, peerId: peerId, hideSender: .default)
                    _internal_updatePeerStoryNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, sound: .default)
                }
            }
            |> ignoreValues
        }

        public func channelAdminEventLog(peerId: PeerId) -> ChannelAdminEventLogContext {
            return ChannelAdminEventLogContext(postbox: self.account.postbox, network: self.account.network, peerId: peerId, accountPeerId: self.account.peerId)
        }

        public func updateChannelMemberBannedRights(peerId: PeerId, memberId: PeerId, rights: TelegramChatBannedRights?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> {
            return _internal_updateChannelMemberBannedRights(account: self.account, peerId: peerId, memberId: memberId, rights: rights)
        }

        public func updateDefaultChannelMemberBannedRights(peerId: PeerId, rights: TelegramChatBannedRights) -> Signal<Never, NoError> {
            return _internal_updateDefaultChannelMemberBannedRights(account: self.account, peerId: peerId, rights: rights)
        }
        
        public func updateChannelBoostsToUnlockRestrictions(peerId: PeerId, boosts: Int32) -> Signal<Never, NoError> {
            return _internal_updateChannelBoostsToUnlockRestrictions(account: self.account, peerId: peerId, boosts: boosts)
        }

        public func createChannel(title: String, description: String?, username: String? = nil) -> Signal<PeerId, CreateChannelError> {
            return _internal_createChannel(account: self.account, title: title, description: description, username: username)
        }

        public func createSupergroup(title: String, description: String?, username: String? = nil, isForum: Bool = false, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false, ttlPeriod: Int32? = nil) -> Signal<PeerId, CreateChannelError> {
            return _internal_createSupergroup(postbox: self.account.postbox, network: self.account.network, stateManager: account.stateManager, title: title, description: description, username: username, isForum: isForum, location: location, isForHistoryImport: isForHistoryImport, ttlPeriod: ttlPeriod)
        }

        public func deleteChannel(peerId: PeerId) -> Signal<Void, DeleteChannelError> {
            return _internal_deleteChannel(account: self.account, peerId: peerId)
        }

        public func updateChannelHistoryAvailabilitySettingsInteractively(peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, ChannelHistoryAvailabilityError> {
            return _internal_updateChannelHistoryAvailabilitySettingsInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, historyAvailableForNewMembers: historyAvailableForNewMembers)
        }

        public func updateChannelRestrictAdMessages(peerId: PeerId, restricted: Bool) -> Signal<Never, ChannelRestrictAdMessagesError> {
            return _internal_updateChannelRestrictAdMessages(account: self.account, peerId: peerId, restricted: restricted)
        }
        
        public func channelMembers(peerId: PeerId, category: ChannelMembersCategory = .recent(.all), offset: Int32 = 0, limit: Int32 = 64, hash: Int64 = 0) -> Signal<[RenderedChannelParticipant]?, NoError> {
            return _internal_channelMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, category: category, offset: offset, limit: limit, hash: hash)
        }

        public func checkOwnershipTranfserAvailability(memberId: PeerId) -> Signal<Never, ChannelOwnershipTransferError> {
            return _internal_checkOwnershipTranfserAvailability(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, memberId: memberId)
        }

        public func updateChannelOwnership(channelId: PeerId, memberId: PeerId, password: String) -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChannelOwnershipTransferError> {
            return _internal_updateChannelOwnership(account: self.account, channelId: channelId, memberId: memberId, password: password)
        }

        public func searchGroupMembers(peerId: PeerId, query: String) -> Signal<[EnginePeer], NoError> {
            return _internal_searchGroupMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, query: query)
            |> map { peers -> [EnginePeer] in
                return peers.map { EnginePeer($0) }
            }
        }

        public func toggleShouldChannelMessagesSignatures(peerId: PeerId, signaturesEnabled: Bool, profilesEnabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleShouldChannelMessagesSignatures(account: self.account, peerId: peerId, signaturesEnabled: signaturesEnabled, profilesEnabled: profilesEnabled)
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
        
        public func toggleAntiSpamProtection(peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleAntiSpamProtection(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func reportAntiSpamFalsePositive(peerId: PeerId, messageId: MessageId) -> Signal<Bool, NoError> {
            return _internal_reportAntiSpamFalsePositive(account: self.account, peerId: peerId, messageId: messageId)
        }

        public func requestPeerPhotos(peerId: PeerId) -> Signal<[TelegramPeerPhoto], NoError> {
            return _internal_requestPeerPhotos(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func updateGroupSpecificStickerset(peerId: PeerId, info: StickerPackCollectionInfo?) -> Signal<Void, UpdateGroupSpecificStickersetError> {
            return _internal_updateGroupSpecificStickerset(postbox: self.account.postbox, network: self.account.network, peerId: peerId, info: info)
        }
        
        public func updateGroupSpecificEmojiset(peerId: PeerId, info: StickerPackCollectionInfo?) -> Signal<Void, UpdateGroupSpecificEmojisetError> {
            return _internal_updateGroupSpecificEmojiset(postbox: self.account.postbox, network: self.account.network, peerId: peerId, info: info)
        }

        public func joinChannel(peerId: PeerId, hash: String?) -> Signal<RenderedChannelParticipant?, JoinChannelError> {
            return _internal_joinChannel(account: self.account, peerId: peerId, hash: hash)
        }

        public func removePeerMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
            return _internal_removePeerMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func availableGroupsForChannelDiscussion() -> Signal<[EnginePeer], AvailableChannelDiscussionGroupError> {
            return _internal_availableGroupsForChannelDiscussion(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network)
            |> map { peers -> [EnginePeer] in
                return peers.map(EnginePeer.init)
            }
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
        
        public func peerSpecificEmojiPack(peerId: PeerId) -> Signal<PeerSpecificStickerPackData, NoError> {
            return _internal_peerSpecificEmojiPack(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
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

        public func removePeerChats(peerIds: [PeerId], deleteGloballyIfPossible: Bool = false) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_removePeerChat(account: self.account, transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: peerId.namespace == Namespaces.Peer.SecretChat || deleteGloballyIfPossible)
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
        
        public func sendBotRequestedPeer(messageId: MessageId, buttonId: Int32, requestedPeerIds: [PeerId]) -> Signal<Void, SendBotRequestedPeerError> {
            return _internal_sendBotRequestedPeer(account: self.account, peerId: messageId.peerId, messageId: messageId, buttonId: buttonId, requestedPeerIds: requestedPeerIds)
        }

        public func addChannelMembers(peerId: PeerId, memberIds: [PeerId]) -> Signal<TelegramInvitePeersResult, AddChannelMemberError> {
            return _internal_addChannelMembers(account: self.account, peerId: peerId, memberIds: memberIds)
        }

        public func recentPeers() -> Signal<RecentPeers, NoError> {
            return _internal_recentPeers(accountPeerId: self.account.peerId, postbox: self.account.postbox)
        }

        public func managedUpdatedRecentPeers() -> Signal<Void, NoError> {
            return _internal_managedUpdatedRecentPeers(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network)
        }
        
        public func recentApps() -> Signal<[EnginePeer.Id], NoError> {
            return _internal_recentApps(accountPeerId: self.account.peerId, postbox: self.account.postbox)
        }
        
        public func managedUpdatedRecentApps() -> Signal<Void, NoError> {
            return _internal_managedUpdatedRecentApps(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network)
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
        
        public func removeRecentlyUsedApp(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentlyUsedApp(account: self.account, peerId: peerId)
        }

        public func uploadedPeerPhoto(resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
            return _internal_uploadedPeerPhoto(postbox: self.account.postbox, network: self.account.network, resource: resource)
        }

        public func uploadedPeerVideo(resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
            return _internal_uploadedPeerVideo(postbox: self.account.postbox, network: self.account.network, messageMediaPreuploadManager: self.account.messageMediaPreuploadManager, resource: resource)
        }

        public func updatePeerPhoto(peerId: PeerId, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>? = nil, videoStartTimestamp: Double? = nil, markup: UploadPeerPhotoMarkup? = nil, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updatePeerPhoto(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, accountPeerId: self.account.peerId, peerId: peerId, photo: photo, video: video, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
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
        
        public func updateChatListFiltersDisplayTags(isEnabled: Bool) {
            let _ = _internal_updateChatListFiltersDisplayTagsInteractively(postbox: self.account.postbox, displayTags: isEnabled).startStandalone()
        }

        public func updatedChatListFilters() -> Signal<[ChatListFilter], NoError> {
            return _internal_updatedChatListFilters(postbox: self.account.postbox, hiddenIds: self.account.viewTracker.hiddenChatListFilterIds)
        }
        
        public func chatListFiltersAreSynced() -> Signal<Bool, NoError> {
            return _internal_chatListFiltersAreSynced(postbox: self.account.postbox)
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

        public func createPeerExportedInvitation(peerId: PeerId, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool?, subscriptionPricing: StarsSubscriptionPricing?) -> Signal<ExportedInvitation?, CreatePeerExportedInvitationError> {
            return _internal_createPeerExportedInvitation(account: self.account, peerId: peerId, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded, subscriptionPricing: subscriptionPricing)
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
            return combineLatest(
                _internal_notificationExceptionsList(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, isStories: false),
                _internal_notificationExceptionsList(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, isStories: true)
            )
            |> map { lhs, rhs in
                return NotificationExceptionsList(
                    peers: lhs.peers.merging(rhs.peers, uniquingKeysWith: { a, _ in a }),
                    settings: lhs.settings.merging(rhs.settings, uniquingKeysWith: { a, _ in a })
                )
            }
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

        public func joinChatInteractively(with hash: String) -> Signal <EnginePeer?, JoinLinkError> {
            let account = self.account
            return _internal_joinChatInteractively(with: hash, account: self.account)
            |> mapToSignal { id -> Signal <EnginePeer?, JoinLinkError> in
                guard let id = id else {
                    return .single(nil)
                }
                return account.postbox.transaction { transaction -> EnginePeer? in
                    return transaction.getPeer(id).flatMap(EnginePeer.init)
                }
                |> castError(JoinLinkError.self)
            }
        }

        public func joinLinkInformation(_ hash: String) -> Signal<ExternalJoiningChatState, JoinLinkInfoError> {
            return _internal_joinLinkInformation(hash, account: self.account)
        }
        
        public func joinCallLinkInformation(_ hash: String) -> Signal<JoinCallLinkInformation, JoinLinkInfoError> {
            return _internal_joinCallLinkInformation(hash, account: self.account)
        }
        
        public func joinCallInvitationInformation(messageId: EngineMessage.Id) -> Signal<JoinCallLinkInformation, JoinCallLinkInfoError> {
            return _internal_joinCallInvitationInformation(account: self.account, messageId: messageId)
        }

        public func updatePeerTitle(peerId: PeerId, title: String) -> Signal<Void, UpdatePeerTitleError> {
            return _internal_updatePeerTitle(account: self.account, peerId: peerId, title: title)
        }

        public func updatePeerDescription(peerId: PeerId, description: String?) -> Signal<Void, UpdatePeerDescriptionError> {
            return _internal_updatePeerDescription(account: self.account, peerId: peerId, description: description)
        }
        
        public func updateBotName(peerId: PeerId, name: String) -> Signal<Void, UpdateBotInfoError> {
            return _internal_updateBotName(account: self.account, peerId: peerId, name: name)
        }
        
        public func updateBotAbout(peerId: PeerId, about: String) -> Signal<Void, UpdateBotInfoError> {
            return _internal_updateBotAbout(account: self.account, peerId: peerId, about: about)
        }
        
        public func toggleBotEmojiStatusAccess(peerId: PeerId, enabled: Bool) -> Signal<Never, ToggleBotEmojiStatusAccessError> {
            return _internal_toggleBotEmojiStatusAccess(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func updateCustomVerification(botId: PeerId, peerId: PeerId, value: UpdateCustomVerificationValue) -> Signal<Never, UpdateCustomVerificationError> {
            return _internal_updateCustomVerification(account: self.account, botId: botId, peerId: peerId, value: value)
        }
        
        public func updatePeerNameColorAndEmoji(peerId: EnginePeer.Id, nameColor: PeerNameColor, backgroundEmojiId: Int64?, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
            return _internal_updatePeerNameColorAndEmoji(account: self.account, peerId: peerId, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId)
        }
        
        public func updatePeerNameColor(peerId: EnginePeer.Id, nameColor: PeerNameColor, backgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
            return _internal_updatePeerNameColor(account: self.account, peerId: peerId, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId)
        }
        
        public func updatePeerProfileColor(peerId: EnginePeer.Id, profileColor: PeerNameColor?, profileBackgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
            return _internal_updatePeerProfileColor(account: self.account, peerId: peerId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId)
        }
        
        public func updatePeerEmojiStatus(peerId: EnginePeer.Id, fileId: Int64?, expirationDate: Int32?) -> Signal<Never, UpdatePeerEmojiStatusError> {
            return _internal_updatePeerEmojiStatus(account: self.account, peerId: peerId, fileId: fileId, expirationDate: expirationDate)
        }
        
        public func updatePeerStarGiftStatus(peerId: EnginePeer.Id, starGift: StarGift.UniqueGift, expirationDate: Int32?) -> Signal<Never, UpdatePeerEmojiStatusError> {
            return _internal_updatePeerStarGiftStatus(account: self.account, peerId: peerId, starGift: starGift, expirationDate: expirationDate)
        }
        
        public func checkChannelRevenueWithdrawalAvailability() -> Signal<Never, RequestRevenueWithdrawalError> {
            return _internal_checkChannelRevenueWithdrawalAvailability(account: self.account)
        }
        
        public func requestChannelRevenueWithdrawalUrl(peerId: EnginePeer.Id, password: String) -> Signal<String, RequestRevenueWithdrawalError> {
            return _internal_requestChannelRevenueWithdrawalUrl(account: self.account, peerId: peerId, password: password)
        }
        
        public func checkStarsRevenueWithdrawalAvailability() -> Signal<Never, RequestStarsRevenueWithdrawalError> {
            return _internal_checkStarsRevenueWithdrawalAvailability(account: self.account)
        }
        
        public func requestStarsRevenueWithdrawalUrl(peerId: EnginePeer.Id, amount: Int64, password: String) -> Signal<String, RequestStarsRevenueWithdrawalError> {
            return _internal_requestStarsRevenueWithdrawalUrl(account: self.account, peerId: peerId, amount: amount, password: password)
        }
        
        public func requestStarsRevenueAdsAccountlUrl(peerId: EnginePeer.Id) -> Signal<String?, NoError> {
            return _internal_requestStarsRevenueAdsAccountlUrl(account: self.account, peerId: peerId)
        }
        
        public func getChatListPeers(filterPredicate: ChatListFilterPredicate) -> Signal<[EnginePeer], NoError> {
            return self.account.postbox.transaction { transaction -> [EnginePeer] in
                return transaction.getChatListPeers(groupId: .root, filterPredicate: filterPredicate, additionalFilter: nil).map(EnginePeer.init)
            }
        }

        public func getNextUnreadChannel(peerId: PeerId, chatListFilterId: Int32?, getFilterPredicate: @escaping (ChatListFilterData) -> ChatListFilterPredicate) -> Signal<(peer: EnginePeer, unreadCount: Int, location: NextUnreadChannelLocation)?, NoError> {
            let startTime = CFAbsoluteTimeGetCurrent()
            return self.account.postbox.transaction { transaction -> (peer: EnginePeer, unreadCount: Int, location: NextUnreadChannelLocation)? in
                func getForFilter(predicate: ChatListFilterPredicate?, isArchived: Bool) -> (peer: EnginePeer, unreadCount: Int)? {
                    let additionalFilter: (Peer) -> Bool = { peer in
                        if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                            return true
                        } else {
                            return false
                        }
                    }
                    
                    var peerIds: [PeerId] = []
                    if predicate != nil {
                        peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: .root, filterPredicate: predicate, additionalFilter: additionalFilter, stopOnFirstMatch: true))
                        peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: Namespaces.PeerGroup.archive, filterPredicate: predicate, additionalFilter: additionalFilter, stopOnFirstMatch: true))
                    } else {
                        if isArchived {
                            peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: Namespaces.PeerGroup.archive, filterPredicate: nil, additionalFilter: additionalFilter, stopOnFirstMatch: true))
                        } else {
                            peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: .root, filterPredicate: nil, additionalFilter: additionalFilter, stopOnFirstMatch: true))
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
            |> beforeNext { _ in
                let delayTime = CFAbsoluteTimeGetCurrent() - startTime
                if delayTime > 0.3 {
                    //Logger.shared.log("getNextUnreadChannel", "took \(delayTime) s")
                }
            }
        }
        
        public func getNextUnreadForumTopic(peerId: PeerId, topicId: Int32) -> Signal<(id: Int64, data: MessageHistoryThreadData)?, NoError> {
            return self.account.postbox.transaction { transaction -> (id: Int64, data: MessageHistoryThreadData)? in
                var unreadThreads: [(id: Int64, data: MessageHistoryThreadData, index: MessageIndex)] = []
                for item in transaction.getMessageHistoryThreadIndex(peerId: peerId, limit: 100) {
                    if item.threadId == Int64(topicId) {
                        continue
                    }
                    guard let data = item.info.data.get(MessageHistoryThreadData.self) else {
                        continue
                    }
                    if data.incomingUnreadCount <= 0 {
                        continue
                    }
                    guard let messageIndex = transaction.getMessageHistoryThreadTopMessage(peerId: peerId, threadId: item.threadId, namespaces: Set([Namespaces.Message.Cloud])) else {
                        continue
                    }
                    unreadThreads.append((item.threadId, data, messageIndex))
                }
                if let result = unreadThreads.min(by: { $0.index > $1.index }) {
                    return (result.id, result.data)
                } else {
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
                    mediaDraftState: internalState.mediaDraftState,
                    synchronizeableInputState: internalState.synchronizeableInputState
                )
            }
        }

        public func setOpaqueChatInterfaceState(peerId: PeerId, threadId: Int64?, state: OpaqueChatInterfaceState) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                guard let data = try? AdaptedPostboxEncoder().encode(InternalChatInterfaceState(
                    synchronizeableInputState: state.synchronizeableInputState,
                    historyScrollMessageIndex: state.historyScrollMessageIndex,
                    mediaDraftState: state.mediaDraftState,
                    opaqueData: state.opaqueData
                )) else {
                    return
                }

                #if DEBUG
                let _ = try! AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data)
                #endif
                
                var overrideChatTimestamp: Int32?
                if let inputState = state.synchronizeableInputState {
                    overrideChatTimestamp = inputState.timestamp
                }
                
                if let mediaDraftState = state.mediaDraftState {
                    if let current = overrideChatTimestamp, mediaDraftState.timestamp < current {
                    } else {
                        overrideChatTimestamp = mediaDraftState.timestamp
                    }
                }

                let storedState = StoredPeerChatInterfaceState(
                    overrideChatTimestamp: overrideChatTimestamp,
                    historyScrollMessageIndex: state.historyScrollMessageIndex,
                    associatedMessageIds: (state.synchronizeableInputState?.replySubject?.messageId).flatMap({ [$0] }) ?? [],
                    data: data
                )

                if let threadId = threadId {
                    var currentInputState: SynchronizeableChatInputState?
                    if let peerChatInterfaceState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId), let data = peerChatInterfaceState.data {
                        currentInputState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
                    }
                    let updatedInputState = state.synchronizeableInputState

                    if currentInputState != updatedInputState {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                            addSynchronizeChatInputStateOperation(transaction: transaction, peerId: peerId, threadId: threadId)
                        }
                    }
                    transaction.setPeerChatThreadInterfaceState(peerId, threadId: threadId, state: storedState)
                } else {
                    var currentInputState: SynchronizeableChatInputState?
                    if let peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId), let data = peerChatInterfaceState.data {
                        currentInputState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
                    }
                    let updatedInputState = state.synchronizeableInputState

                    if currentInputState != updatedInputState {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                            addSynchronizeChatInputStateOperation(transaction: transaction, peerId: peerId, threadId: nil)
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
        
        public func getPerstistentChatInterfaceState(peerId: EnginePeer.Id) -> Signal<CodableEntry?, NoError> {
            return self.account.postbox.transaction({ transaction -> CodableEntry? in
                return (transaction.getPreferencesEntry(key: PreferencesKeys.persistentChatInterfaceData(peerId: peerId))?.data).flatMap(CodableEntry.init(data:))
            })
        }
        
        public func setPerstistentChatInterfaceState(peerId: EnginePeer.Id, state: CodableEntry?) {
            let _ = self.account.postbox.transaction({ transaction -> Void in
                transaction.setPreferencesEntry(key: PreferencesKeys.persistentChatInterfaceData(peerId: peerId), value: (state?.data).flatMap(PreferencesEntry.init(data:)))
            }).startStandalone()
        }
        
        public func sendAsAvailablePeers(peerId: PeerId) -> Signal<[SendAsPeer], NoError> {
            return _internal_cachedPeerSendAsAvailablePeers(account: self.account, peerId: peerId)
        }
        
        public func updatePeerSendAsPeer(peerId: PeerId, sendAs: PeerId) -> Signal<Never, UpdatePeerSendAsPeerError> {
            return _internal_updatePeerSendAsPeer(account: self.account, peerId: peerId, sendAs: sendAs)
        }
        
        public func updatePeerReactionSettings(peerId: PeerId, reactionSettings: PeerReactionSettings) -> Signal<Never, UpdatePeerAllowedReactionsError> {
            return _internal_updatePeerReactionSettings(account: account, peerId: peerId, reactionSettings: reactionSettings)
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
        
        public func ensurePeerIsLocallyAvailable(peer: EnginePeer) -> Signal<EnginePeer, NoError> {
            return _internal_storedMessageFromSearchPeer(postbox: self.account.postbox, peer: peer._asPeer())
            |> map { result -> EnginePeer in
                return EnginePeer(result)
            }
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
        
        public func setChannelForumMode(id: EnginePeer.Id, isForum: Bool, displayForumAsTabs: Bool) -> Signal<Never, NoError> {
            return _internal_setChannelForumMode(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, peerId: id, isForum: isForum, displayForumAsTabs: displayForumAsTabs)
        }
        
        public func createForumChannelTopic(id: EnginePeer.Id, title: String, iconColor: Int32, iconFileId: Int64?) -> Signal<Int64, CreateForumChannelTopicError> {
            return _internal_createForumChannelTopic(account: self.account, peerId: id, title: title, iconColor: iconColor, iconFileId: iconFileId)
        }
        
        public func fetchForumChannelTopic(id: EnginePeer.Id, threadId: Int64) -> Signal<FetchForumChannelTopicResult, NoError> {
            return _internal_fetchForumChannelTopic(account: self.account, peerId: id, threadId: threadId)
        }
        
        public func editForumChannelTopic(id: EnginePeer.Id, threadId: Int64, title: String, iconFileId: Int64?) -> Signal<Never, EditForumChannelTopicError> {
            return _internal_editForumChannelTopic(account: self.account, peerId: id, threadId: threadId, title: title, iconFileId: iconFileId)
        }
        
        public func setForumChannelTopicClosed(id: EnginePeer.Id, threadId: Int64, isClosed: Bool) -> Signal<Never, EditForumChannelTopicError> {
            return _internal_setForumChannelTopicClosed(account: self.account, id: id, threadId: threadId, isClosed: isClosed)
        }
        
        public func setForumChannelTopicHidden(id: EnginePeer.Id, threadId: Int64, isHidden: Bool) -> Signal<Never, EditForumChannelTopicError> {
            return _internal_setForumChannelTopicHidden(account: self.account, id: id, threadId: threadId, isHidden: isHidden)
        }
        
        public func removeForumChannelThread(id: EnginePeer.Id, threadId: Int64) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                cloudChatAddClearHistoryOperation(transaction: transaction, peerId: id, threadId: threadId, explicitTopMessageId: nil, minTimestamp: nil, maxTimestamp: nil, type: CloudChatClearHistoryType(.forEveryone))
                
                transaction.setMessageHistoryThreadInfo(peerId: id, threadId: threadId, info: nil)
                
                _internal_clearHistory(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: id, threadId: threadId, namespaces: .not(Namespaces.Message.allNonRegular))
            }
            |> ignoreValues
        }
        
        public func removeForumChannelThreads(id: EnginePeer.Id, threadIds: [Int64]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for threadId in threadIds {
                    cloudChatAddClearHistoryOperation(transaction: transaction, peerId: id, threadId: threadId, explicitTopMessageId: nil, minTimestamp: nil, maxTimestamp: nil, type: CloudChatClearHistoryType(.forEveryone))
                    
                    transaction.setMessageHistoryThreadInfo(peerId: id, threadId: threadId, info: nil)
                    
                    _internal_clearHistory(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: id, threadId: threadId, namespaces: .not(Namespaces.Message.allNonRegular))
                }
            }
            |> ignoreValues
        }
        
        public func toggleForumChannelTopicPinned(id: EnginePeer.Id, threadId: Int64) -> Signal<Never, SetForumChannelTopicPinnedError> {
            return self.account.postbox.transaction { transaction -> ([Int64], Int) in
                if id == self.account.peerId {
                    let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                    
                    let accountPeer = transaction.getPeer(self.account.peerId)
                    let limitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: accountPeer?.isPremium ?? false)
                    let limit = limitsConfiguration.maxPinnedSavedChatCount
                    
                    return (transaction.getPeerPinnedThreads(peerId: id), Int(limit))
                } else {
                    var limit = 5
                    let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                    if let data = appConfiguration.data, let value = data["topics_pinned_limit"] as? Double {
                        limit = Int(value)
                    }
                    
                    return (transaction.getPeerPinnedThreads(peerId: id), limit)
                }
            }
            |> castError(SetForumChannelTopicPinnedError.self)
            |> mapToSignal { threadIds, limit -> Signal<Never, SetForumChannelTopicPinnedError> in
                var threadIds = threadIds
                if threadIds.contains(threadId) {
                    threadIds.removeAll(where: { $0 == threadId })
                } else {
                    if threadIds.count + 1 > limit {
                        return .fail(.limitReached(limit))
                    }
                    threadIds.insert(threadId, at: 0)
                }
                
                return _internal_setForumChannelPinnedTopics(account: self.account, id: id, threadIds: threadIds)
            }
        }
        
        public func getForumChannelPinnedTopics(id: EnginePeer.Id) -> Signal<[Int64], NoError> {
            return self.account.postbox.transaction { transcation -> [Int64] in
                return transcation.getPeerPinnedThreads(peerId: id)
            }
        }
        
        public func setForumChannelPinnedTopics(id: EnginePeer.Id, threadIds: [Int64]) -> Signal<Never, SetForumChannelTopicPinnedError> {
            return _internal_setForumChannelPinnedTopics(account: self.account, id: id, threadIds: threadIds)
        }
        
        public func forumChannelTopicNotificationExceptions(id: EnginePeer.Id) -> Signal<[EngineMessageHistoryThread.NotificationException], NoError> {
            return _internal_forumChannelTopicNotificationExceptions(account: self.account, id: id)
        }
        
        public func importContactToken(token: String) -> Signal<EnginePeer?, NoError> {
            return _internal_importContactToken(account: self.account, token: token)
        }
        
        public func exportContactToken() -> Signal<ExportedContactToken?, NoError> {
            return _internal_exportContactToken(account: self.account)
        }
        
        public func updateChannelMembersHidden(peerId: EnginePeer.Id, value: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Api.InputChannel? in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if let current = current as? CachedChannelData {
                        return current.withUpdatedMembersHidden(.known(PeerMembersHidden(value: value)))
                    } else {
                        return current
                    }
                })
                
                return transaction.getPeer(peerId).flatMap(apiInputChannel)
            }
            |> mapToSignal { inputChannel -> Signal<Never, NoError> in
                guard let inputChannel = inputChannel else {
                    return .complete()
                }
                
                return self.account.network.request(Api.functions.channels.toggleParticipantsHidden(channel: inputChannel, enabled: value ? .boolTrue : .boolFalse))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                    return .single(nil)
                }
                |> beforeNext { updates in
                    if let updates = updates {
                        self.account.stateManager.addUpdates(updates)
                    }
                }
                |> ignoreValues
            }
        }
        
        public func updateForumViewAsMessages(peerId: EnginePeer.Id, value: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Api.InputChannel? in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if let current = current as? CachedChannelData {
                        return current.withUpdatedViewForumAsMessages(.known(value))
                    } else {
                        return current
                    }
                })
                
                return transaction.getPeer(peerId).flatMap(apiInputChannel)
            }
            |> mapToSignal { inputChannel -> Signal<Never, NoError> in
                guard let inputChannel = inputChannel else {
                    return .complete()
                }
                
                return self.account.network.request(Api.functions.channels.toggleViewForumAsMessages(channel: inputChannel, enabled: value ? .boolTrue : .boolFalse))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                    return .single(nil)
                }
                |> beforeNext { updates in
                    if let updates = updates {
                        self.account.stateManager.addUpdates(updates)
                    }
                }
                |> ignoreValues
            }
        }
        
        public func exportChatFolder(filterId: Int32, title: String, peerIds: [PeerId]) -> Signal<ExportedChatFolderLink, ExportChatFolderError> {
            return _internal_exportChatFolder(account: self.account, filterId: filterId, title: title, peerIds: peerIds)
        }
        
        public func getExportedChatFolderLinks(id: Int32) -> Signal<[ExportedChatFolderLink]?, NoError> {
            return _internal_getExportedChatFolderLinks(account: self.account, id: id)
        }
        
        public func editChatFolderLink(filterId: Int32, link: ExportedChatFolderLink, title: String?, peerIds: [EnginePeer.Id]?, revoke: Bool) -> Signal<ExportedChatFolderLink, EditChatFolderLinkError> {
            return _internal_editChatFolderLink(account: self.account, filterId: filterId, link: link, title: title, peerIds: peerIds, revoke: revoke)
        }
        
        public func deleteChatFolderLink(filterId: Int32, link: ExportedChatFolderLink) -> Signal<Never, RevokeChatFolderLinkError> {
            return _internal_deleteChatFolderLink(account: self.account, filterId: filterId, link: link)
        }
        
        public func checkChatFolderLink(slug: String) -> Signal<ChatFolderLinkContents, CheckChatFolderLinkError> {
            return _internal_checkChatFolderLink(account: self.account, slug: slug)
        }
        
        public func joinChatFolderLink(slug: String, peerIds: [EnginePeer.Id]) -> Signal<JoinChatFolderResult, JoinChatFolderLinkError> {
            return _internal_joinChatFolderLink(account: self.account, slug: slug, peerIds: peerIds)
        }
        
        public func pollChatFolderUpdates(folderId: Int32) -> Signal<Never, NoError> {
            let signal = _internal_pollChatFolderUpdatesOnce(account: self.account, folderId: folderId)
            return (
                signal
                |> then(
                    Signal<Never, NoError>.complete()
                    |> delay(10.0, queue: .concurrentDefaultQueue())
                )
            )
            |> restart
        }
        
        public func subscribedChatFolderUpdates(folderId: Int32) -> Signal<ChatFolderUpdates?, NoError> {
            return _internal_subscribedChatFolderUpdates(account: self.account, folderId: folderId)
        }

        public func joinAvailableChatsInFolder(updates: ChatFolderUpdates, peerIds: [EnginePeer.Id]) -> Signal<Never, JoinChatFolderLinkError> {
            return _internal_joinAvailableChatsInFolder(account: self.account, updates: updates, peerIds: peerIds)
        }
        
        public func hideChatFolderUpdates(folderId: Int32) -> Signal<Never, NoError> {
            return _internal_hideChatFolderUpdates(account: self.account, folderId: folderId)
        }
        
        public func leaveChatFolder(folderId: Int32, removePeerIds: [EnginePeer.Id]) -> Signal<Never, NoError> {
            return _internal_leaveChatFolder(account: self.account, folderId: folderId, removePeerIds: removePeerIds)
        }
        
        public func requestLeaveChatFolderSuggestions(folderId: Int32) -> Signal<[EnginePeer.Id], NoError> {
            return _internal_requestLeaveChatFolderSuggestions(account: self.account, folderId: folderId)
        }
        
        public func keepPeerUpdated(id: EnginePeer.Id, forceUpdate: Bool) -> Signal<Never, NoError> {
            return self.account.viewTracker.peerView(id, updateData: forceUpdate)
            |> ignoreValues
        }
        
        public func tokenizeSearchString(string: String, transliteration: EngineStringIndexTokenTransliteration) -> [EngineDataBuffer] {
            return stringIndexTokens(string, transliteration: transliteration)
        }
        
        public func updatePeerStoriesHidden(id: PeerId, isHidden: Bool) {
            let _ = _internal_updatePeerStoriesHidden(account: self.account, id: id, isHidden: isHidden).start()
        }
        
        public func getChannelBoostStatus(peerId: EnginePeer.Id) -> Signal<ChannelBoostStatus?, NoError> {
            return _internal_getChannelBoostStatus(account: self.account, peerId: peerId)
        }
        
        public func getMyBoostStatus() -> Signal<MyBoostStatus?, NoError> {
            return _internal_getMyBoostStatus(account: self.account)
        }

        public func applyChannelBoost(peerId: EnginePeer.Id, slots: [Int32]) -> Signal<MyBoostStatus?, NoError> {
            return _internal_applyChannelBoost(account: self.account, peerId: peerId, slots: slots)
        }
        
        public func getPaidMessagesRevenue(peerId: EnginePeer.Id) -> Signal<StarsAmount?, NoError> {
            return _internal_getPaidMessagesRevenue(account: self.account, peerId: peerId)
        }
        
        public func addNoPaidMessagesException(peerId: EnginePeer.Id, refundCharged: Bool) -> Signal<Never, NoError> {
            return _internal_addNoPaidMessagesException(account: self.account, peerId: peerId, refundCharged: refundCharged)
        }
        
        public func updateChannelPaidMessagesStars(peerId: EnginePeer.Id, stars: StarsAmount?, broadcastMessagesAllowed: Bool) -> Signal<Never, NoError> {
            return _internal_updateChannelPaidMessagesStars(account: self.account, peerId: peerId, stars: stars, broadcastMessagesAllowed: broadcastMessagesAllowed)
        }
        
        public func recommendedChannels(peerId: EnginePeer.Id?) -> Signal<RecommendedChannels?, NoError> {
            return _internal_recommendedChannels(account: self.account, peerId: peerId)
        }
        
        public func recommendedChannelPeerIds(peerId: EnginePeer.Id?) -> Signal<[EnginePeer.Id]?, NoError> {
            return _internal_recommendedChannelPeerIds(account: self.account, peerId: peerId)
        }
        
        public func toggleRecommendedChannelsHidden(peerId: EnginePeer.Id, hidden: Bool) -> Signal<Never, NoError> {
            return _internal_toggleRecommendedChannelsHidden(account: self.account, peerId: peerId, hidden: hidden)
        }
        
        public func requestRecommendedChannels(peerId: EnginePeer.Id, forceUpdate: Bool = false) -> Signal<Never, NoError> {
            return _internal_requestRecommendedChannels(account: self.account, peerId: peerId, forceUpdate: forceUpdate)
        }
        
        public func recommendedAppPeerIds() -> Signal<[EnginePeer.Id]?, NoError> {
            return _internal_recommendedAppPeerIds(account: self.account)
        }
        
        public func requestGlobalRecommendedChannelsIfNeeded() -> Signal<Never, NoError> {
            return _internal_requestRecommendedChannels(account: self.account, peerId: nil, forceUpdate: false)
        }
        
        public func requestRecommendedAppsIfNeeded() -> Signal<Never, NoError> {
            return _internal_requestRecommendedApps(account: self.account, forceUpdate: false)
        }

        public func recommendedBots(peerId: EnginePeer.Id) -> Signal<RecommendedBots?, NoError> {
            return _internal_recommendedBots(account: self.account, peerId: peerId)
        }
        
        public func requestRecommendedBots(peerId: EnginePeer.Id, forceUpdate: Bool = false) -> Signal<Never, NoError> {
            return _internal_requestRecommendedBots(account: self.account, peerId: peerId, forceUpdate: forceUpdate)
        }
                
        public func searchAdPeers(query: String) -> Signal<[AdPeer], NoError> {
            return _internal_searchAdPeers(account: self.account, query: query)
        }
                
        public func isPremiumRequiredToContact(_ peerIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id: RequirementToContact], NoError> {
            return _internal_updateIsPremiumRequiredToContact(account: self.account, peerIds: peerIds)
        }
        
        public func subscribeIsPremiumRequiredForMessaging(id: EnginePeer.Id) -> Signal<Bool, NoError> {
            if id.namespace != Namespaces.Peer.CloudUser {
                return .single(false)
            }
            
            return self.account.postbox.combinedView(keys: [
                PostboxViewKey.basicPeer(self.account.peerId),
                PostboxViewKey.basicPeer(id),
                PostboxViewKey.cachedPeerData(peerId: id)
            ])
            |> map { views -> Bool in
                guard let basicAccountPeerView = views.views[PostboxViewKey.basicPeer(self.account.peerId)] as? BasicPeerView else {
                    return false
                }
                guard let accountPeer = basicAccountPeerView.peer else {
                    return false
                }
                if accountPeer.isPremium {
                    return false
                }
                
                guard let basicPeerView = views.views[PostboxViewKey.basicPeer(id)] as? BasicPeerView else {
                    return false
                }
                guard let user = basicPeerView.peer as? TelegramUser else {
                    return false
                }
                guard let cachedDataView = views.views[PostboxViewKey.cachedPeerData(peerId: id)] as? CachedPeerDataView else {
                    return false
                }
                if !user.flags.contains(.requirePremium) {
                    return false
                }
                
                /*#if DEBUG
                if "".isEmpty {
                    return true
                }
                #endif*/
                
                if let cachedData = cachedDataView.cachedPeerData as? CachedUserData {
                    if cachedData.flags.contains(.premiumRequired) {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return true
                }
            }
            |> distinctUntilChanged
            |> mapToSignal { maybeValue -> Signal<Bool, NoError> in
                if !maybeValue {
                    return .single(false)
                }
                
                return self.account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: id, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 44, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: [])
                |> map { view -> Bool in
                    for entry in view.0.entries {
                        if entry.message.flags.contains(.Incoming) {
                            return false
                        }
                    }
                    return true
                }
                |> distinctUntilChanged
            }
        }
        
        public func updateSavedMessagesViewAsTopics(value: Bool) {
            let _ = (self.account.postbox.transaction { transaction -> Void in
                transaction.updatePreferencesEntry(key: PreferencesKeys.displaySavedChatsAsTopics(), { _ in
                    return PreferencesEntry(EngineDisplaySavedChatsAsTopics(value: value))
                })
            }).start()
        }
        
        public func getCollectibleUsernameInfo(username: String) -> Signal<TelegramCollectibleItemInfo?, NoError> {
            return self.account.network.request(Api.functions.fragment.getCollectibleInfo(collectible: .inputCollectibleUsername(username: username)))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.fragment.CollectibleInfo?, NoError> in
                return .single(nil)
            }
            |> map { result -> TelegramCollectibleItemInfo? in
                guard let result else {
                    return nil
                }
                switch result {
                case let .collectibleInfo(purchaseDate, currency, amount, cryptoCurrency, cryptoAmount, url):
                    return TelegramCollectibleItemInfo(
                        subject: .username(username),
                        purchaseDate: purchaseDate,
                        currency: currency,
                        currencyAmount: amount,
                        cryptoCurrency: cryptoCurrency,
                        cryptoCurrencyAmount: cryptoAmount,
                        url: url
                    )
                }
            }
        }
        
        public func getCollectiblePhoneNumberInfo(phoneNumber: String) -> Signal<TelegramCollectibleItemInfo?, NoError> {
            return self.account.network.request(Api.functions.fragment.getCollectibleInfo(collectible: .inputCollectiblePhone(phone: phoneNumber)))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.fragment.CollectibleInfo?, NoError> in
                return .single(nil)
            }
            |> map { result -> TelegramCollectibleItemInfo? in
                guard let result else {
                    return nil
                }
                switch result {
                case let .collectibleInfo(purchaseDate, currency, amount, cryptoCurrency, cryptoAmount, url):
                    return TelegramCollectibleItemInfo(
                        subject: .phoneNumber(phoneNumber),
                        purchaseDate: purchaseDate,
                        currency: currency,
                        currencyAmount: amount,
                        cryptoCurrency: cryptoCurrency,
                        cryptoCurrencyAmount: cryptoAmount,
                        url: url
                    )
                }
            }
        }
        
        public func updateBotBiometricsState(peerId: EnginePeer.Id, update: @escaping (TelegramBotBiometricsState?) -> TelegramBotBiometricsState) {
            let _ = _internal_updateBotBiometricsState(account: self.account, peerId: peerId, update: update).startStandalone()
        }
        
        public func botsWithBiometricState() -> Signal<Set<EnginePeer.Id>, NoError> {
            return _internal_botsWithBiometricState(account: self.account)
        }
        
        public func secureBotStorageUuid() -> Signal<String, NoError> {
            return _internal_secureBotStorageUuid(account: self.account)
        }
        
        public func setBotStorageValue(peerId: EnginePeer.Id, key: String, value: String?) -> Signal<Never, BotStorageError> {
            return _internal_setBotStorageValue(account: self.account, peerId: peerId, key: key, value: value)
        }

        public func clearBotStorage(peerId: EnginePeer.Id) -> Signal<Never, BotStorageError> {
            return _internal_clearBotStorage(account: self.account, peerId: peerId)
        }
        
        public func toggleChatManagingBotIsPaused(chatId: EnginePeer.Id) {
            let _ = _internal_toggleChatManagingBotIsPaused(account: self.account, chatId: chatId).startStandalone()
        }
        
        public func removeChatManagingBot(chatId: EnginePeer.Id) {
            let _ = _internal_removeChatManagingBot(account: self.account, chatId: chatId).startStandalone()
        }
        
        public func toggleAutoTranslation(peerId: EnginePeer.Id, enabled: Bool) -> Signal<Never, NoError> {
            return _internal_toggleAutoTranslation(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func resolveMessageLink(slug: String) -> Signal<TelegramResolvedMessageLink?, NoError> {
            return self.account.network.request(Api.functions.account.resolveBusinessChatLink(slug: slug))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.account.ResolvedBusinessChatLinks?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<TelegramResolvedMessageLink?, NoError> in
                guard let result else {
                    return .single(nil)
                }
                return self.account.postbox.transaction { transaction -> TelegramResolvedMessageLink? in
                    switch result {
                    case let .resolvedBusinessChatLinks(_, peer, message, entities, chats, users):
                        updatePeers(transaction: transaction, accountPeerId: self.account.peerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                        
                        guard let peer = transaction.getPeer(peer.peerId) else {
                            return nil
                        }
                        
                        return TelegramResolvedMessageLink(
                            peer: EnginePeer(peer),
                            message: message,
                            entities: messageTextEntitiesFromApiEntities(entities ?? [])
                        )
                    }
                }
            }
        }
        
        public func setStarsReactionDefaultPrivacy(privacy: TelegramPaidReactionPrivacy) {
            let _ = self.account.postbox.transaction({ transaction in
                _internal_setStarsReactionDefaultPrivacy(privacy: privacy, transaction: transaction)
            }).startStandalone()
        }
        
        public func updateStarRefProgram(id: EnginePeer.Id, program: (commissionPermille: Int32, durationMonths: Int32?)?) -> Signal<Never, NoError> {
            return _internal_updateStarRefProgram(account: self.account, id: id, program: program)
        }
        
        public func connectedStarRefBots(id: EnginePeer.Id) -> EngineConnectedStarRefBotsContext {
            return EngineConnectedStarRefBotsContext(account: self.account, peerId: id)
        }
        
        public func suggestedStarRefBots(id: EnginePeer.Id, sortMode: EngineSuggestedStarRefBotsContext.SortMode) -> EngineSuggestedStarRefBotsContext {
            return EngineSuggestedStarRefBotsContext(account: self.account, peerId: id, sortMode: sortMode)
        }
        
        public func connectStarRefBot(id: EnginePeer.Id, botId: EnginePeer.Id) -> Signal<EngineConnectedStarRefBotsContext.Item, ConnectStarRefBotError> {
            return _internal_connectStarRefBot(account: self.account, id: id, botId: botId)
        }
        
        public func getStarRefBotConnection(id: EnginePeer.Id, targetId: EnginePeer.Id) -> Signal<EngineConnectedStarRefBotsContext.Item?, NoError> {
            return _internal_getStarRefBotConnection(account: self.account, id: id, targetId: targetId)
        }
        
        public func getPossibleStarRefBotTargets() -> Signal<[EnginePeer], NoError> {
            return _internal_getPossibleStarRefBotTargets(account: self.account)
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
        mediaDraftState: internalState.mediaDraftState,
        synchronizeableInputState: internalState.synchronizeableInputState
    )
}
