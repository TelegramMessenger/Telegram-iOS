import Foundation
import Postbox

public extension Peer {
    var debugDisplayTitle: String {
        switch self {
        case let user as TelegramUser:
            return user.nameOrPhone
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        default:
            return ""
        }
    }
    
    func restrictionText(platform: String, contentSettings: ContentSettings) -> String? {
        var restrictionInfo: PeerAccessRestrictionInfo?
        switch self {
        case let user as TelegramUser:
            restrictionInfo = user.restrictionInfo
        case let channel as TelegramChannel:
            restrictionInfo = channel.restrictionInfo
        default:
            break
        }
        
        if let restrictionInfo = restrictionInfo {
            for rule in restrictionInfo.rules {
                if rule.platform == "all" || rule.platform == platform {
                    if !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                        return rule.text
                    }
                }
            }
            return nil
        } else {
            return nil
        }
    }
    
    var addressName: String? {
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
    
    var displayLetters: [String] {
        switch self {
        case let user as TelegramUser:
            if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty && !lastName.isEmpty {
                return [
                    String(firstName[..<firstName.index(after: firstName.startIndex)].uppercased()),
                    String(lastName[..<lastName.index(after: lastName.startIndex)].uppercased()),
                ]
            } else if let firstName = user.firstName, !firstName.isEmpty {
                return [
                    String(firstName[..<firstName.index(after: firstName.startIndex)].uppercased())
                ]
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return [
                    String(lastName[..<lastName.index(after: lastName.startIndex)].uppercased()),
                ]
            }
            
            return []
        case let group as TelegramGroup:
            if group.title.startIndex != group.title.endIndex {
                return [
                    String(group.title[..<group.title.index(after: group.title.startIndex)].uppercased()),
                ]
            } else {
                return []
            }
        case let channel as TelegramChannel:
            if channel.title.startIndex != channel.title.endIndex {
                return [
                    String(channel.title[..<channel.title.index(after: channel.title.startIndex)].uppercased()),
                ]
            } else {
                return []
            }
        default:
            return []
        }
    }
    
    var profileImageRepresentations: [TelegramMediaImageRepresentation] {
        if let user = self as? TelegramUser {
            return user.photo
        } else if let group = self as? TelegramGroup {
            return group.photo
        } else if let channel = self as? TelegramChannel {
            return channel.photo
        }
        return []
    }
    
    var smallProfileImage: TelegramMediaImageRepresentation? {
        return smallestImageRepresentation(self.profileImageRepresentations)
    }
    
    var largeProfileImage: TelegramMediaImageRepresentation? {
        return largestImageRepresentation(self.profileImageRepresentations)
    }
    
    var isDeleted: Bool {
        switch self {
        case let user as TelegramUser:
            return user.firstName == nil && user.lastName == nil && user.phone == nil
        default:
            return false
        }
    }
    
    var isScam: Bool {
        switch self {
        case let user as TelegramUser:
            return user.flags.contains(.isScam)
        case let channel as TelegramChannel:
            return channel.flags.contains(.isScam)
        default:
            return false
        }
    }
    
    var isFake: Bool {
        switch self {
        case let user as TelegramUser:
            return user.flags.contains(.isFake)
        case let channel as TelegramChannel:
            return channel.flags.contains(.isFake)
        default:
            return false
        }
    }
        
    var isVerified: Bool {
        switch self {
        case let user as TelegramUser:
            return user.flags.contains(.isVerified)
        case let channel as TelegramChannel:
            return channel.flags.contains(.isVerified)
        default:
            return false
        }
    }
    
    var isPremium: Bool {
        switch self {
        case let user as TelegramUser:
            return user.flags.contains(.isPremium)
        default:
            return false
        }
    }
    
    var isCopyProtectionEnabled: Bool {
        switch self {
        case let group as TelegramGroup:
            return group.flags.contains(.copyProtectionEnabled)
        case let channel as TelegramChannel:
            return channel.flags.contains(.copyProtectionEnabled)
        default:
            return false
        }
    }
}

public extension PeerId {
    var isGroupOrChannel: Bool {
        switch self.namespace {
        case Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
            return true
        default:
            return false
        }
    }
}

public func peerDebugDisplayTitles(_ peerIds: [PeerId], _ dict: SimpleDictionary<PeerId, Peer>) -> String {
    var peers: [Peer] = []
    for id in peerIds {
        if let peer = dict[id] {
            peers.append(peer)
        }
    }
    return peerDebugDisplayTitles(peers)
}

public func peerDebugDisplayTitles(_ peers: [Peer]) -> String {
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
            string.append(peer.debugDisplayTitle)
        }
        return string
    }
}

public func messageMainPeer(_ message: EngineMessage) -> EnginePeer? {
    if let peer = message.peers[message.id.peerId] {
        if let peer = peer as? TelegramSecretChat {
            return message.peers[peer.regularPeerId].flatMap(EnginePeer.init)
        } else {
            return EnginePeer(peer)
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
    convenience init(message: Message) {
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
    
    var chatMainPeer: Peer? {
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

public func isServicePeer(_ peer: Peer) -> Bool {
    if let peer = peer as? TelegramUser {
        if peer.id.isReplies {
            return true
        }
        return (peer.id.namespace == Namespaces.Peer.CloudUser && (peer.id.id._internalGetInt64Value() == 777000 || peer.id.id._internalGetInt64Value() == 333000))
    }
    return false
}

public extension PeerId {
    var isReplies: Bool {
        if self.namespace == Namespaces.Peer.CloudUser {
            if self.id._internalGetInt64Value() == 708513 || self.id._internalGetInt64Value() == 1271266957 {
                return true
            }
        }
        return false
    }
    
    func isRepliesOrSavedMessages(accountPeerId: PeerId) -> Bool {
        if accountPeerId == self {
            return true
        } else if self.isReplies {
            return true
        } else {
            return false
        }
    }
    
    var isImport: Bool {
        if self.namespace == Namespaces.Peer.CloudUser {
            if self.id._internalGetInt64Value() == 225079 {
                return true
            }
        }
        return false
    }
}
