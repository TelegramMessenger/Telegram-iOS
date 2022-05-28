import SwiftSignalKit
import Postbox

public typealias EngineExportedPeerInvitation = ExportedInvitation

public enum EnginePeerCachedInfoItem<T> {
    case known(T)
    case unknown
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

                return EngineRenderedPeer(peerId: self.id, peers: peers)
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
        
        public struct AllowedReactions: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = [String]?

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
                    return cachedData.allowedReactions
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return cachedData.allowedReactions
                } else {
                    return nil
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
                    return .known(cachedData.photo)
                } else if let cachedData = view.cachedPeerData as? CachedGroupData {
                    return .known(cachedData.photo)
                } else if let cachedData = view.cachedPeerData as? CachedChannelData {
                    return .known(cachedData.photo)
                } else {
                    return .unknown
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
    }
}
