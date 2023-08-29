import SwiftSignalKit
import Postbox

public final class EngineContactList {
    public let peers: [EnginePeer]
    public let presences: [EnginePeer.Id: EnginePeer.Presence]

    public init(peers: [EnginePeer], presences: [EnginePeer.Id: EnginePeer.Presence]) {
        self.peers = peers
        self.presences = presences
    }
}

public extension TelegramEngine.EngineData.Item {
    enum Contacts {
        public struct List: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineContactList

            private let includePresences: Bool

            public init(includePresences: Bool) {
                self.includePresences = includePresences
            }

            var key: PostboxViewKey {
                return .contacts(accountPeerId: nil, includePresences: self.includePresences)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? ContactPeersView else {
                    preconditionFailure()
                }
                return EngineContactList(peers: view.peers.map(EnginePeer.init), presences: view.peerPresences.mapValues(EnginePeer.Presence.init))
            }
        }
        
        public struct Top: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Array<EnginePeer.Id>
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .cachedItem(cachedRecentPeersEntryId())
            }
            
            func extract(view: PostboxView) -> [EnginePeer.Id] {
                if let value = (view as? CachedItemView)?.value?.get(CachedRecentPeers.self) {
                    if value.enabled {
                        return value.ids
                    } else {
                        return []
                    }
                } else {
                    return []
                }
            }
        }
        
        public struct CloseFriends: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Array<EnginePeer>

            public init() {
            }

            var key: PostboxViewKey {
                return .contacts(accountPeerId: nil, includePresences: false)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? ContactPeersView else {
                    preconditionFailure()
                }
                return view.peers.filter { $0.isCloseFriend }.map(EnginePeer.init)
            }
        }
    }
}
