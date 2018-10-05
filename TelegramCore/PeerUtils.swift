import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public extension Peer {
    public var displayTitle: String {
        switch self {
            case let user as TelegramUser:
                return user.name
            case let group as TelegramGroup:
                return group.title
            case let channel as TelegramChannel:
                return channel.title
            default:
                return ""
        }
    }
    
    public var compactDisplayTitle: String {
        switch self {
            case let user as TelegramUser:
                if let firstName = user.firstName {
                    return firstName
                } else if let lastName = user.lastName {
                    return lastName
                } else {
                    return ""
                }
            case let group as TelegramGroup:
                return group.title
            case let channel as TelegramChannel:
                return channel.title
            default:
                return ""
        }
    }
    
    public var restrictionText: String? {
        switch self {
            case let user as TelegramUser:
                return user.restrictionInfo?.reason
            case let channel as TelegramChannel:
                return channel.restrictionInfo?.reason
            default:
                return nil
        }
    }
    
    public var addressName: String? {
        switch self {
            case let user as TelegramUser:
                return user.username
            case _ as TelegramGroup:
                return nil
            case let channel as TelegramChannel:
                return channel.username
            default:
                return nil
        }
    }
    
    public var displayLetters: [String] {
        switch self {
            case let user as TelegramUser:
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty && !lastName.isEmpty {
                    return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased(), lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()]
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    return [lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
                }
                
                return []
            case let group as TelegramGroup:
                if group.title.startIndex != group.title.endIndex {
                    return [group.title.substring(to: group.title.index(after: group.title.startIndex)).uppercased()]
                } else {
                    return []
                }
            case let channel as TelegramChannel:
                if channel.title.startIndex != channel.title.endIndex {
                    return [channel.title.substring(to: channel.title.index(after: channel.title.startIndex)).uppercased()]
                } else {
                    return []
                }
            default:
                return []
        }
    }
    
    public var profileImageRepresentations: [TelegramMediaImageRepresentation] {
        if let user = self as? TelegramUser {
            return user.photo
        } else if let group = self as? TelegramGroup {
            return group.photo
        } else if let channel = self as? TelegramChannel {
            return channel.photo
        }
        return []
    }
    
    public var smallProfileImage: TelegramMediaImageRepresentation? {
        return smallestImageRepresentation(self.profileImageRepresentations)
    }
    
    public var largeProfileImage: TelegramMediaImageRepresentation? {
        return largestImageRepresentation(self.profileImageRepresentations)
    }
    
    public var isDeleted: Bool {
        switch self {
            case let user as TelegramUser:
                return user.firstName == nil && user.lastName == nil
            default:
                return false
        }
    }
}

public extension PeerId {
    public var isGroupOrChannel: Bool {
        switch self.namespace {
            case Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
                return true
            default:
                return false
        }
    }
}

public func peerDisplayTitles(_ peerIds: [PeerId], _ dict: SimpleDictionary<PeerId, Peer>) -> String {
    var peers: [Peer] = []
    for id in peerIds {
        if let peer = dict[id] {
            peers.append(peer)
        }
    }
    return peerDisplayTitles(peers)
}

public func peerDisplayTitles(_ peers: [Peer]) -> String {
    if peers.count == 0 {
        return ""
    } else {
        var string = ""
        var first = true
        for peer in peers {
            if first {
                first = false
            } else {
                string.append(", ")
            }
            string.append(peer.displayTitle)
        }
        return string
    }
}

public func messageMainPeer(_ message: Message) -> Peer? {
    if let peer = message.peers[message.id.peerId] {
        if let peer = peer as? TelegramSecretChat {
            return message.peers[peer.regularPeerId]
        } else {
            return peer
        }
    } else {
        return nil
    }
}

public func peerViewMainPeer(_ view: PeerView) -> Peer? {
    if let peer = view.peers[view.peerId] {
        if let peer = peer as? TelegramSecretChat {
            return view.peers[peer.regularPeerId]
        } else {
            return peer
        }
    } else {
        return nil
    }
}

public extension RenderedPeer {
    public convenience init(message: Message) {
        var peers = SimpleDictionary<PeerId, Peer>()
        let peerId = message.id.peerId
        if let peer = message.peers[peerId] {
            peers[peer.id] = peer
            if let peer = peer as? TelegramSecretChat {
                if let regularPeer = message.peers[peer.regularPeerId] {
                    peers[regularPeer.id] = regularPeer
                }
            }
        }
        self.init(peerId: message.id.peerId, peers: peers)
    }
    
    public var chatMainPeer: Peer? {
        if let peer = self.peers[self.peerId] {
            if let peer = peer as? TelegramSecretChat {
                return self.peers[peer.regularPeerId]
            } else {
                return peer
            }
        } else {
            return nil
        }
    }
}

