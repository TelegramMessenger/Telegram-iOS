import SwiftSignalKit
import Postbox

public typealias EngineExportedPeerInvitation = ExportedInvitation

public extension TelegramEngine.EngineData.Item {
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

        public struct RenderedPeer: TelegramEngineDataItem, PostboxViewDataItem {
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

        public struct Presence: TelegramEngineDataItem, PostboxViewDataItem {
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
            public typealias Result = Optional<EnginePeer.NotificationSettings>

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
                    return nil
                }
                return EnginePeer.NotificationSettings(notificationSettings)
            }
        }

        public struct ParticipantCount: TelegramEngineDataItem, PostboxViewDataItem {
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

        public struct GroupCallDescription: TelegramEngineDataItem, PostboxViewDataItem {
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

        public struct ExportedInvitation: TelegramEngineDataItem, PostboxViewDataItem {
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
    }
}
