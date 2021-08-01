import Postbox

public enum EnginePeer: Equatable {
    public typealias Id = PeerId

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
