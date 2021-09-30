import Postbox

public enum EnginePeer: Equatable {
    public typealias Id = PeerId

    public struct Presence: Equatable {
        public enum Status: Equatable {
            case present(until: Int32)
            case recently
            case lastWeek
            case lastMonth
            case longTimeAgo
        }

        public var status: Status
        public var lastActivity: Int32

        public init(status: Status, lastActivity: Int32) {
            self.status = status
            self.lastActivity = lastActivity
        }
    }

    case user(TelegramUser)
    case legacyGroup(TelegramGroup)
    case channel(TelegramChannel)
    case secretChat(TelegramSecretChat)

    public static func ==(lhs: EnginePeer, rhs: EnginePeer) -> Bool {
        switch lhs {
        case let .user(user):
            if case .user(user) = rhs {
                return true
            } else {
                return false
            }
        case let .legacyGroup(legacyGroup):
            if case .legacyGroup(legacyGroup) = rhs {
                return true
            } else {
                return false
            }
        case let .channel(channel):
            if case .channel(channel) = rhs {
                return true
            } else {
                return false
            }
        case let .secretChat(secretChat):
            if case .secretChat(secretChat) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public extension EnginePeer.Presence {
    init(_ presence: PeerPresence) {
        if let presence = presence as? TelegramUserPresence {
            let mappedStatus: Status
            switch presence.status {
            case .none:
                mappedStatus = .longTimeAgo
            case let .present(until):
                mappedStatus = .present(until: until)
            case .recently:
                mappedStatus = .recently
            case .lastWeek:
                mappedStatus = .lastWeek
            case .lastMonth:
                mappedStatus = .lastMonth
            }

            self.init(status: mappedStatus, lastActivity: presence.lastActivity)
        } else {
            preconditionFailure()
        }
    }
}

public extension EnginePeer {
    var id: Id {
        return self._asPeer().id
    }

    var addressName: String? {
        return self._asPeer().addressName
    }

    var indexName: PeerIndexNameRepresentation {
        return self._asPeer().indexName
    }

    var debugDisplayTitle: String {
        return self._asPeer().debugDisplayTitle
    }

    func restrictionText(platform: String, contentSettings: ContentSettings) -> String? {
        return self._asPeer().restrictionText(platform: platform, contentSettings: contentSettings)
    }

    var displayLetters: [String] {
        return self._asPeer().displayLetters
    }

    var profileImageRepresentations: [TelegramMediaImageRepresentation] {
        return self._asPeer().profileImageRepresentations
    }

    var smallProfileImage: TelegramMediaImageRepresentation? {
        return self._asPeer().smallProfileImage
    }

    var largeProfileImage: TelegramMediaImageRepresentation? {
        return self._asPeer().largeProfileImage
    }

    var isDeleted: Bool {
        return self._asPeer().isDeleted
    }

    var isScam: Bool {
        return self._asPeer().isScam
    }

    var isFake: Bool {
        return self._asPeer().isFake
    }

    var isVerified: Bool {
        return self._asPeer().isVerified
    }

    var isService: Bool {
        if case let .user(peer) = self {
            if peer.id.isReplies {
                return true
            }
            return (peer.id.namespace == Namespaces.Peer.CloudUser && (peer.id.id._internalGetInt64Value() == 777000 || peer.id.id._internalGetInt64Value() == 333000))
        }
        return false
    }
}

public extension EnginePeer {
    init(_ peer: Peer) {
        switch peer {
        case let user as TelegramUser:
            self = .user(user)
        case let group as TelegramGroup:
            self = .legacyGroup(group)
        case let channel as TelegramChannel:
            self = .channel(channel)
        case let secretChat as TelegramSecretChat:
            self = .secretChat(secretChat)
        default:
            preconditionFailure("Unknown peer type")
        }
    }

    func _asPeer() -> Peer {
        switch self {
        case let .user(user):
            return user
        case let .legacyGroup(legacyGroup):
            return legacyGroup
        case let .channel(channel):
            return channel
        case let .secretChat(secretChat):
            return secretChat
        }
    }
}

public final class EngineRenderedPeer {
    public let peerId: EnginePeer.Id
    public let peers: [EnginePeer.Id: EnginePeer]

    public init(peerId: EnginePeer.Id, peers: [EnginePeer.Id: EnginePeer]) {
        self.peerId = peerId
        self.peers = peers
    }

    public init(peer: EnginePeer) {
        self.peerId = peer.id
        self.peers = [peer.id: peer]
    }

    public static func ==(lhs: EngineRenderedPeer, rhs: EngineRenderedPeer) -> Bool {
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        return true
    }

    public var peer: EnginePeer? {
        return self.peers[self.peerId]
    }

    public var chatMainPeer: EnginePeer? {
        if let peer = self.peers[self.peerId] {
            if case let .secretChat(secretChat) = peer {
                return self.peers[secretChat.regularPeerId]
            } else {
                return peer
            }
        } else {
            return nil
        }
    }
}

public extension EngineRenderedPeer {
    convenience init(_ renderedPeer: RenderedPeer) {
        var mappedPeers: [EnginePeer.Id: EnginePeer] = [:]
        for (id, peer) in renderedPeer.peers {
            mappedPeers[id] = EnginePeer(peer)
        }
        self.init(peerId: renderedPeer.peerId, peers: mappedPeers)
    }
}
