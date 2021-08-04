import SwiftSignalKit
import Postbox

public extension TelegramEngine.EngineData.Item {
    enum Peer {
        public struct Peer: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EnginePeer>

            fileprivate var id: EnginePeer.Id

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

        public struct ParticipantCount: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Optional<Int>

            fileprivate var id: EnginePeer.Id

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
    }
}
