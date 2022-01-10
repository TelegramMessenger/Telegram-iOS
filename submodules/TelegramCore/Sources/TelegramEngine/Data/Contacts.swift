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
    }
}
