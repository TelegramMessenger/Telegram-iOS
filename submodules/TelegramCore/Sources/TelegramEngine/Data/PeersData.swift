import SwiftSignalKit
import Postbox

public typealias EngineExportedPeerInvitation = ExportedInvitation
public typealias EngineSecretChatKeyFingerprint = SecretChatKeyFingerprint


public enum EnginePeerCachedInfoItem<T> {
    case known(T)
    case unknown
    
    public var knownValue: T? {
        switch self {
        case let .known(value):
            return value
        case .unknown:
            return nil
        }
    }
}

public struct EngineDisplaySavedChatsAsTopics: Codable, Equatable {
    public var value: Bool
    
    public init(value: Bool) {
        self.value = value
    }
}

extension EnginePeerCachedInfoItem: Equatable where T: Equatable {
    public static func ==(lhs: EnginePeerCachedInfoItem<T>, rhs: EnginePeerCachedInfoItem<T>) -> Bool {
        switch lhs {
        case let .known(value):
            if case .known(value) = rhs {
                return true
            } else {
                return false
            }
        case .unknown:
            if case .unknown = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public enum EngineChannelParticipant: Equatable {
    case creator(id: EnginePeer.Id, adminInfo: ChannelParticipantAdminInfo?, rank: String?)
    case member(id: EnginePeer.Id, invitedAt: Int32, adminInfo: ChannelParticipantAdminInfo?, banInfo: ChannelParticipantBannedInfo?, rank: String?, subscriptionUntilDate: Int32?)
    
    public var peerId: EnginePeer.Id {
        switch self {
        case let .creator(id, _, _):
            return id
        case let .member(id, _, _, _, _, _):
            return id
        }
    }
}

public extension EngineChannelParticipant {
    init(_ participant: ChannelParticipant) {
        switch participant {
        case let .creator(id, adminInfo, rank):
            self = .creator(id: id, adminInfo: adminInfo, rank: rank)
        case let .member(id, invitedAt, adminInfo, banInfo, rank, subscriptionUntilDate):
            self = .member(id: id, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: banInfo, rank: rank, subscriptionUntilDate: subscriptionUntilDate)
        }
    }
    
    func _asParticipant() -> ChannelParticipant {
        switch self {
        case let .creator(id, adminInfo, rank):
            return .creator(id: id, adminInfo: adminInfo, rank: rank)
        case let .member(id, invitedAt, adminInfo, banInfo, rank, subscriptionUntilDate):
            return .member(id: id, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: banInfo, rank: rank, subscriptionUntilDate: subscriptionUntilDate)
        }
    }
}

public enum EngineLegacyGroupParticipant: Equatable {
    case member(id: EnginePeer.Id, invitedBy: EnginePeer.Id, invitedAt: Int32)
    case creator(id: EnginePeer.Id)
    case admin(id: EnginePeer.Id, invitedBy: EnginePeer.Id, invitedAt: Int32)
    
    public var peerId: EnginePeer.Id {
        switch self {
        case let .member(id, _, _):
            return id
        case let .creator(id):
            return id
        case let .admin(id, _, _):
            return id
        }
    }
}

public extension EngineLegacyGroupParticipant {
    init(_ participant: GroupParticipant) {
        switch participant {
        case let .member(id, invitedBy, invitedAt):
            self = .member(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
        case let .creator(id):
            self = .creator(id: id)
        case let .admin(id, invitedBy, invitedAt):
            self = .admin(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
        }
    }
    
    func _asParticipant() -> GroupParticipant {
        switch self {
        case let .member(id, invitedBy, invitedAt):
            return .member(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
        case let .creator(id):
            return .creator(id: id)
        case let .admin(id, invitedBy, invitedAt):
            return .admin(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
        }
    }
}

public extension TelegramEngine.EngineData.Item {
    enum NotificationSettings {
        public struct Global: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineGlobalNotificationSettings

            public init() {
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.globalNotifications]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let notificationSettings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) else {
                    return EngineGlobalNotificationSettings(GlobalNotificationSettings.defaultSettings.effective)
                }
                return EngineGlobalNotificationSettings(notificationSettings.effective)
            }
        }
    }
    
    enum Peer {
        public struct Peer: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EnginePeer>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .basicPeer(self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? BasicPeerView else {
                    preconditionFailure()
                }
                guard let peer = view.peer else {
                    return nil
                }
                return EnginePeer(peer)
            }
        }

        public struct RenderedPeer: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EngineRenderedPeer>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .peer(peerId: self.id, components: [])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PeerView else {
                    preconditionFailure()
                }
                var peers: [EnginePeer.Id: EnginePeer] = [:]
                guard let peer = view.peers[self.id] else {
                    return nil
                }
                peers[peer.id] = EnginePeer(peer)

                if let secretChat = peer as? TelegramSecretChat {
                    guard let mainPeer = view.peers[secretChat.regularPeerId] else {
                        return nil
                    }
                    peers[mainPeer.id] = EnginePeer(mainPeer)
                }

                return EngineRenderedPeer(peerId: self.id, peers: peers, associatedMedia: view.media)
            }
        }

        public struct Presence: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EnginePeer.Presence>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .peer(peerId: self.id, components: [])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PeerView else {
                    preconditionFailure()
                }
                var presencePeerId = self.id
                if let secretChat = view.peers[self.id] as? TelegramSecretChat {
                    presencePeerId = secretChat.regularPeerId
                }
                guard let presence = view.peerPresences[presencePeerId] else {
                    return nil
                }
                return EnginePeer.Presence(presence)
            }
        }

        public struct NotificationSettings: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeer.NotificationSettings

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .peer(peerId: self.id, components: [])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PeerView else {
                    preconditionFailure()
                }
                guard let notificationSettings = view.notificationSettings as? TelegramPeerNotificationSettings else {
                    return EnginePeer.NotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
                }
                return EnginePeer.NotificationSettings(notificationSettings)
            }
        }
        
        public struct ThreadNotificationSettings: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeer.NotificationSettings

            fileprivate var id: EnginePeer.Id
            fileprivate var threadId: Int64

            public init(id: EnginePeer.Id, threadId: Int64) {
                self.id = id
                self.threadId = threadId
            }

            var key: PostboxViewKey {
                return .messageHistoryThreadInfo(peerId: self.id, threadId: self.threadId)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessageHistoryThreadInfoView else {
                    preconditionFailure()
                }
                guard let data = view.info?.data.get(MessageHistoryThreadData.self) else {
                    return EnginePeer.NotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
                }
                return EnginePeer.NotificationSettings(data.notificationSettings)
            }
        }

        public struct ParticipantCount: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<Int>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedPeerData = view.cachedPeerData else {
                    return nil
                }
                switch cachedPeerData {
                case let channel as CachedChannelData:
                    return channel.participantsSummary.memberCount.flatMap(Int.init)
                case let group as CachedGroupData:
                    return group.participants?.participants.count
                default:
                    return nil
                }
            }
        }
        
        public struct Wallpaper: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<TelegramWallpaper>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedPeerData = view.cachedPeerData else {
                    return nil
                }
                switch cachedPeerData {
                case let user as CachedUserData:
                    return user.wallpaper
                case let channel as CachedChannelData:
                    return channel.wallpaper
                default:
                    return nil
                }
            }
        }
        
        public struct SendPaidMessageStars: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<StarsAmount>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .peer(peerId: self.id, components: [.cachedData])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PeerView else {
                    preconditionFailure()
                }
                if let cachedPeerData = view.cachedData as? CachedUserData {
                    return cachedPeerData.sendPaidMessageStars
                } else if let channel = peerViewMainPeer(view) as? TelegramChannel {
                    return channel.sendPaidMessageStars
                } else {
                    return nil
                }
            }
        }

        public struct GroupCallDescription: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EngineGroupCallDescription>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedPeerData = view.cachedPeerData else {
                    return nil
                }
                switch cachedPeerData {
                case let channel as CachedChannelData:
                    return channel.activeCall.flatMap(EngineGroupCallDescription.init)
                case let group as CachedGroupData:
                    return group.activeCall.flatMap(EngineGroupCallDescription.init)
                default:
                    return nil
                }
            }
        }

        public struct ExportedInvitation: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EngineExportedPeerInvitation>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedPeerData = view.cachedPeerData else {
                    return nil
                }
                switch cachedPeerData {
                case let channel as CachedChannelData:
                    return channel.exportedInvitation
                case let group as CachedGroupData:
                    return group.exportedInvitation
                default:
                    return nil
                }
            }
        }
        
        public struct StatsDatacenterId: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<Int32>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedPeerData = view.cachedPeerData else {
                    return nil
                }
                switch cachedPeerData {
                case let channel as CachedChannelData:
                    return channel.statsDatacenterId
                default:
                    return nil
                }
            }
        }
        
        public struct ThemeEmoticon: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<String>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedPeerData = view.cachedPeerData else {
                    return nil
                }
                if let cachedData = cachedPeerData as? CachedUserData {
                    return cachedData.themeEmoticon
                } else if let cachedData = cachedPeerData as? CachedGroupData {
                    return cachedData.themeEmoticon
                } else if let cachedData = cachedPeerData as? CachedChannelData {
                    return cachedData.themeEmoticon
                } else {
                    return nil
                }
            }
        }
        
        public struct IsContact: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .isContact(id: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? IsContactView else {
                    preconditionFailure()
                }
                return view.isContact
            }
        }
        
        public struct CanSetStickerPack: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.canSetStickerSet)
                } else {
                    return false
                }
            }
        }
        
        public struct StickerPack: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = StickerPackCollectionInfo?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedData = view.cachedPeerData as? CachedChannelData else {
                    return nil
                }
                return cachedData.stickerPack
            }
        }
        
        public struct EmojiPack: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = StickerPackCollectionInfo?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                guard let cachedData = view.cachedPeerData as? CachedChannelData else {
                    return nil
                }
                return cachedData.emojiPack
            }
        }
        
        public struct AllowedReactions: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<PeerAllowedReactions>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    switch cachedData.reactionSettings {
                    case let .known(value):
                        return .known(value.allowedReactions)
                    case .unknown:
                        return .unknown
                    }
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    switch cachedData.reactionSettings {
                    case let .known(value):
                        return .known(value.allowedReactions)
                    case .unknown:
                        return .unknown
                    }
                } else {
                    return .unknown
                }
            }
        }
        
        public struct ReactionSettings: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<PeerReactionSettings>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.reactionSettings
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return cachedData.reactionSettings
                } else {
                    return .unknown
                }
            }
        }
        
        public struct CallJoinAsPeerId: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeer.Id?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.callJoinPeerId
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return cachedData.callJoinPeerId
                } else {
                    return nil
                }
            }
        }
        
        public struct CommonGroupCount: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int32?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.commonGroupCount
                }  else {
                    return nil
                }
            }
        }
        
        public struct StarGiftsCount: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int32?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.starGiftsCount
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.starGiftsCount
                }
                return nil
                
            }
        }
                
        public struct LinkedDiscussionPeerId: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<EnginePeer.Id?>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    switch cachedData.linkedDiscussionPeerId {
                    case let .known(value):
                        return .known(value)
                    case .unknown:
                        return .unknown
                    }
                } else {
                    return .unknown
                }
            }
        }
        
        public struct StatusSettings: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeer.StatusSettings?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.peerStatusSettings.flatMap(EnginePeer.StatusSettings.init)
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.peerStatusSettings.flatMap(EnginePeer.StatusSettings.init)
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return cachedData.peerStatusSettings.flatMap(EnginePeer.StatusSettings.init)
                } else {
                    return nil
                }
            }
        }
        
        public struct PeerSettings: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<PeerStatusSettings>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.peerStatusSettings
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.peerStatusSettings
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return cachedData.peerStatusSettings
                } else {
                    return nil
                }
            }
        }
        
        public struct AreVideoCallsAvailable: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.videoCallsAvailable
                } else {
                    return false
                }
            }
        }
        
        public struct AreVoiceCallsAvailable: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return !cachedData.callsPrivate
                } else {
                    return true
                }
            }
        }
        
        public struct AreVoiceMessagesAvailable: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.voiceMessagesAvailable
                } else {
                    return true
                }
            }
        }
        
        public struct AboutText: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<String?>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return .known(cachedData.about)
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return .known(cachedData.about)
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return .known(cachedData.about)
                } else {
                    return .unknown
                }
            }
        }
        
        public struct Photo: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<TelegramMediaImage?>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    if case let .known(value) = cachedData.photo {
                        return .known(value)
                    } else {
                        return .unknown
                    }
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return .known(cachedData.photo)
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return .known(cachedData.photo)
                } else {
                    return .unknown
                }
            }
        }
        
        public struct PersonalPhoto: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<TelegramMediaImage?>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    if case let .known(value) = cachedData.personalPhoto {
                        return .known(value)
                    } else {
                        return .unknown
                    }
                } else {
                    return .unknown
                }
            }
        }
        
        public struct PublicPhoto: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<TelegramMediaImage?>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    if case let .known(value) = cachedData.fallbackPhoto {
                        return .known(value)
                    } else {
                        return .unknown
                    }
                } else {
                    return .unknown
                }
            }
        }
        
        public struct Birthday: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramBirthday?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.birthday
                } else {
                    return nil
                }
            }
        }
        
        public struct CanViewStats: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.canViewStats)
                } else {
                    return false
                }
            }
        }
        
        public struct CanViewRevenue: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.flags.contains(.canViewRevenue)
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.canViewRevenue)
                } else {
                    return false
                }
            }
        }
        
        public struct CanManageEmojiStatus: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.flags.contains(.botCanManageEmojiStatus)
                } else {
                    return false
                }
            }
        }
        
        public struct CanViewStarsRevenue: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.canViewStarsRevenue)
                } else {
                    return false
                }
            }
        }
        
        
        public struct StarGiftsAvailable: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.starGiftsAvailable)
                } else {
                    return false
                }
            }
        }
        
        public struct PaidMediaAllowed: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.paidMediaAllowed)
                } else {
                    return false
                }
            }
        }
        
        public struct BoostsToUnrestrict: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int32?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.boostsToUnrestrict
                } else {
                    return nil
                }
            }
        }
        
        public struct AppliedBoosts: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int32?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.appliedBoosts
                } else {
                    return nil
                }
            }
        }
        
        public struct MessageReadStatsAreHidden: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                
                if self.id.namespace == Namespaces.Peer.CloudUser {
                    if let cachedData = view.cachedPeerData as? CachedUserData, cachedData.flags.contains(.readDatesPrivate) {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }
        }

        
        public struct CanDeleteHistory: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.canDeleteHistory)
                } else {
                    return false
                }
            }
        }
        
        public struct AntiSpamEnabled: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.antiSpamEnabled)
                } else {
                    return false
                }
            }
        }
        
        public struct IsBlocked: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<Bool>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return .known(cachedData.isBlocked)
                } else {
                    return .unknown
                }
            }
        }
        
        public struct IsBlockedFromStories: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<Bool>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return .known(cachedData.flags.contains(.isBlockedFromStories))
                } else {
                    return .unknown
                }
            }
        }
        
        public struct TranslationHidden: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.flags.contains(.translationHidden)
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return cachedData.flags.contains(.translationHidden)
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.translationHidden)
                } else {
                    return false
                }
            }
        }
        
        public struct SlowmodeTimeout: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int32?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.slowModeTimeout
                } else {
                    return nil
                }
            }
        }
        public struct SlowmodeValidUntilTimeout: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int32?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.slowModeValidUntilTimestamp
                }
                return nil
            }
        }
        
        public struct CanAvoidGroupRestrictions: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    if let boostsToUnrestrict = cachedData.boostsToUnrestrict {
                        let appliedBoosts = cachedData.appliedBoosts ?? 0
                        return boostsToUnrestrict <= appliedBoosts
                    }
                }
                return true
            }
        }

        
        public struct IsPremiumRequiredForMessaging: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, AnyPostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            func keys(data: TelegramEngine.EngineData) -> [PostboxViewKey] {
                return [
                    .cachedPeerData(peerId: self.id),
                    .basicPeer(data.accountPeerId),
                    .basicPeer(self.id)
                ]
            }

            func _extract(data: TelegramEngine.EngineData, views: [PostboxViewKey: PostboxView]) -> Any {
                guard let basicPeerView = views[.basicPeer(data.accountPeerId)] as? BasicPeerView else {
                    assertionFailure()
                    return false
                }
                guard let basicTargetPeerView = views[.basicPeer(self.id)] as? BasicPeerView else {
                    assertionFailure()
                    return false
                }
                guard let view = views[.cachedPeerData(peerId: self.id)] as? CachedPeerDataView else {
                    assertionFailure()
                    return false
                }
                
                if let peer = basicPeerView.peer, peer.isPremium {
                    return false
                }
                
                guard let targetPeer = basicTargetPeerView.peer as? TelegramUser else {
                    return false
                }
                if !targetPeer.flags.contains(.requirePremium) {
                    return false
                }
                
                if self.id.namespace == Namespaces.Peer.CloudUser {
                    if let cachedData = view.cachedPeerData as? CachedUserData {
                        return cachedData.flags.contains(.premiumRequired)
                    } else {
                        return true
                    }
                } else {
                    return false
                }
            }
        }
        
        public struct LegacyGroupParticipants: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerCachedInfoItem<[EngineLegacyGroupParticipant]>

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedGroupData {
                    if let participants = cachedData.participants {
                        return .known(participants.participants.map(EngineLegacyGroupParticipant.init))
                    } else {
                        return .unknown
                    }
                } else {
                    return .unknown
                }
            }
        }
        
        public struct SecretChatKeyFingerprint: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EngineSecretChatKeyFingerprint?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .peerChatState(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PeerChatStateView else {
                    preconditionFailure()
                }
                
                if let peerChatState = view.chatState?.getLegacy() as? SecretChatState {
                    return peerChatState.keyFingerprint
                } else {
                    return nil
                }
            }
        }
        
        public struct SecretChatLayer: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .peerChatState(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PeerChatStateView else {
                    preconditionFailure()
                }
                
                if let peerChatState = view.chatState?.getLegacy() as? SecretChatState {
                    switch peerChatState.embeddedState {
                    case .terminated:
                        return nil
                    case .handshake:
                        return nil
                    case .basicLayer:
                        return 7
                    case let .sequenceBasedLayer(secretChatSequenceBasedLayerState):
                        return Int(secretChatSequenceBasedLayerState.layerNegotiationState.activeLayer.rawValue)
                    }
                } else {
                    return nil
                }
            }
        }
        
        public struct ThreadData: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public struct Key: Hashable {
                public var id: EnginePeer.Id
                public var threadId: Int64
                
                public init(id: EnginePeer.Id, threadId: Int64) {
                    self.id = id
                    self.threadId = threadId
                }
            }
            
            public typealias Result = MessageHistoryThreadData?

            fileprivate var id: EnginePeer.Id
            fileprivate var threadId: Int64
            
            public var mapKey: Key {
                return Key(id: self.id, threadId: self.threadId)
            }

            public init(id: EnginePeer.Id, threadId: Int64) {
                self.id = id
                self.threadId = threadId
            }

            var key: PostboxViewKey {
                return .messageHistoryThreadInfo(peerId: self.id, threadId: self.threadId)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessageHistoryThreadInfoView else {
                    preconditionFailure()
                }
                
                return view.info?.data.get(MessageHistoryThreadData.self)
            }
        }
        
        public struct StoryStats: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = PeerStoryStats?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .peerStoryStats(peerIds: Set([self.id]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PeerStoryStatsView else {
                    preconditionFailure()
                }
                
                if let result = view.storyStats[self.id] {
                    return result
                } else {
                    return nil
                }
            }
        }
        
        public struct DisplaySavedChatsAsTopics: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            public init() {
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.displaySavedChatsAsTopics()]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                
                if let value = view.values[PreferencesKeys.displaySavedChatsAsTopics()]?.get(EngineDisplaySavedChatsAsTopics.self) {
                    return value.value
                } else {
                    return false
                }
            }
        }
        
        public struct BusinessHours: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramBusinessHours?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.businessHours
                } else {
                    return nil
                }
            }
        }

        public struct BusinessLocation: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramBusinessLocation?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.businessLocation
                } else {
                    return nil
                }
            }
        }
        
        public struct BusinessGreetingMessage: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramBusinessGreetingMessage?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.greetingMessage
                } else {
                    return nil
                }
            }
        }
        
        public struct BusinessAwayMessage: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramBusinessAwayMessage?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.awayMessage
                } else {
                    return nil
                }
            }
        }
        
        public struct BusinessIntro: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = CachedTelegramBusinessIntro

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.businessIntro
                } else {
                    return .unknown
                }
            }
        }
        
        public struct BusinessConnectedBot: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramAccountConnectedBot?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.connectedBot
                } else {
                    return nil
                }
            }
        }
        
        public struct ChatManagingBot: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = PeerStatusSettings.ManagingBot?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.peerStatusSettings?.managingBot
                } else {
                    return nil
                }
            }
        }
        
        public struct BotBiometricsState: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramBotBiometricsState?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.botBiometricsState(peerId: self.id)]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                if let state = view.values[PreferencesKeys.botBiometricsState(peerId: self.id)]?.get(TelegramBotBiometricsState.self) {
                    return state
                } else {
                    return nil
                }
            }
        }
        
        public struct BusinessChatLinks: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = TelegramBusinessChatLinks?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.businessLinks()]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                return view.values[PreferencesKeys.businessLinks()]?.get(TelegramBusinessChatLinks.self)
            }
        }
        
        public struct PersonalChannel: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = CachedTelegramPersonalChannel

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.personalChannel
                } else {
                    return .unknown
                }
            }
        }
        
        public struct AdsRestricted: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.flags.contains(.adsRestricted)
                } else {
                    return false
                }
            }
        }
        
        public struct AdsEnabled: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Bool

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.flags.contains(.adsEnabled)
                } else {
                    return false
                }
            }
        }
        
        public struct BotPreview: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = CachedUserData.BotPreview?

            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.botPreview
                } else {
                    return nil
                }
            }
        }

        public struct BotMenu: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<BotMenuButton>
            
            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }
            
            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.botInfo?.menuButton
                } else {
                    return nil
                }
            }
        }
        
        public struct BotAppSettings: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<TelegramCore.BotAppSettings>
            
            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }
            
            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.botInfo?.appSettings
                } else {
                    return nil
                }
            }
        }
        
        public struct BotCommands: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<[BotCommand]>
            
            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }
            
            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.botInfo?.commands
                } else {
                    return nil
                }
            }
        }
        
        public struct BotPrivacyPolicyUrl: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<String>
            
            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }
            
            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.botInfo?.privacyPolicyUrl
                } else {
                    return nil
                }
            }
        }
        
        public struct StarsReactionDefaultPrivacy: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = TelegramPaidReactionPrivacy
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .cachedItem(ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.starsReactionDefaultToPrivate, key: StarsReactionDefaultToPrivateData.key()))
            }
            
            func extract(view: PostboxView) -> Result {
                if let value = (view as? CachedItemView)?.value?.get(StarsReactionDefaultToPrivateData.self) {
                    return value.privacy
                } else {
                    return .default
                }
            }
        }
        
        public struct StarRefProgram: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = TelegramStarRefProgram?
            
            public let id: EnginePeer.Id
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }
            
            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.starRefProgram
                } else {
                    return nil
                }
            }
        }
        
        public struct Verification: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = PeerVerification?
            
            public let id: EnginePeer.Id
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }
            
            var key: PostboxViewKey {
                return .cachedPeerData(peerId: self.id)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? CachedPeerDataView else {
                    preconditionFailure()
                }
                if let cachedData = view.cachedPeerData as? CachedUserData {
                    return cachedData.verification
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return cachedData.verification
                } else {
                    return nil
                }
            }
        }
    }
}
