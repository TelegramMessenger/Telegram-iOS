import Foundation
import Postbox

public let anonymousSavedMessagesId: Int64 = 2666000

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
                if rule.reason == "sensitive" {
                    continue
                }
                if rule.platform == "all" || rule.platform == platform || contentSettings.addContentRestrictionReasons.contains(rule.platform) {
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
            return user.usernames.first(where: { $0.isActive }).map { $0.username } ?? user.username
        case _ as TelegramGroup:
            return nil
        case let channel as TelegramChannel:
            return channel.usernames.first(where: { $0.isActive }).map { $0.username } ?? channel.username
        default:
            return nil
        }
    }
    
    var usernames: [TelegramPeerUsername] {
        switch self {
        case let user as TelegramUser:
            return user.usernames
        case _ as TelegramGroup:
            return []
        case let channel as TelegramChannel:
            return channel.usernames
        default:
            return []
        }
    }
    
    var editableUsername: String? {
        switch self {
        case let user as TelegramUser:
            return user.usernames.first(where: { $0.flags.contains(.isEditable) }).map { $0.username } ?? user.username
        case _ as TelegramGroup:
            return nil
        case let channel as TelegramChannel:
            return channel.usernames.first(where: { $0.flags.contains(.isEditable) }).map { $0.username } ?? channel.username
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
            return user.firstName == nil && user.lastName == nil
        default:
            return false
        }
    }
    
    var isGenericUser: Bool {
        switch self {
        case let user as TelegramUser:
            if user.isDeleted {
                return false
            }
            if user.botInfo != nil {
                return false
            }
            if user.id.isRepliesOrVerificationCodes {
                return false
            }
            if user.id.isTelegramNotifications {
                return false
            }
            return true
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
    
    var isSubscription: Bool {
        switch self {
        case let channel as TelegramChannel:
            return channel.subscriptionUntilDate != nil
        default:
            return false
        }
    }
    
    var isCloseFriend: Bool {
        switch self {
        case let user as TelegramUser:
            return user.flags.contains(.isCloseFriend)
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
    
    func hasSensitiveContent(platform: String) -> Bool {
        var restrictionInfo: PeerAccessRestrictionInfo?
        switch self {
        case let user as TelegramUser:
            restrictionInfo = user.restrictionInfo
        case let channel as TelegramChannel:
            restrictionInfo = channel.restrictionInfo
        default:
            break
        }
        
        if let restrictionInfo, let rule = restrictionInfo.rules.first(where: { $0.reason == "sensitive" }) {
            if rule.platform == "all" || rule.platform == platform {
                return true
            }
        }
        return false
    }
    
    var isForum: Bool {
        if let channel = self as? TelegramChannel {
            return channel.flags.contains(.isForum)
        } else {
            return false
        }
    }
    
    var isMonoForum: Bool {
        if let channel = self as? TelegramChannel {
            return channel.flags.contains(.isMonoforum)
        } else {
            return false
        }
    }
    
    var displayForumAsTabs: Bool {
        if let channel = self as? TelegramChannel, isForum {
            return channel.flags.contains(.displayForumAsTabs)
        } else {
            return false
        }
    }
    
    var isForumOrMonoForum: Bool {
        if let channel = self as? TelegramChannel {
            return channel.flags.contains(.isForum) || channel.flags.contains(.isMonoforum)
        } else {
            return false
        }
    }
    
    var nameColor: PeerNameColor? {
        switch self {
        case let user as TelegramUser:
            if let nameColor = user.nameColor {
                return nameColor
            } else {
                return PeerNameColor(rawValue: Int32(self.id.id._internalGetInt64Value() % 7))
            }
        case let channel as TelegramChannel:
            if let nameColor = channel.nameColor {
                return nameColor
            } else {
                return PeerNameColor(rawValue: Int32(self.id.id._internalGetInt64Value() % 7))
            }
        default:
            return nil
        }
    }
    
    var verificationIconFileId: Int64? {
        switch self {
        case let user as TelegramUser:
            return user.verificationIconFileId
        case let channel as TelegramChannel:
            return channel.verificationIconFileId
        default:
            return nil
        }
    }
    
    var profileColor: PeerNameColor? {
        if let emojiStatus {
            switch emojiStatus.content {
            case let .starGift(_, _, _, _, _, _, outerColor, _, _):
                return PeerNameColor.other(outerColor)
            default:
                break
            }
        }
        switch self {
        case let user as TelegramUser:
            return user.profileColor
        case let channel as TelegramChannel:
            return channel.profileColor
        default:
            return nil
        }
    }
    
    var hasCustomNameColor: Bool {
        let defaultNameColor = PeerNameColor(rawValue: Int32(self.id.id._internalGetInt64Value() % 7))
        if self.nameColor != defaultNameColor {
            return true
        }
        return false
    }
    
    var emojiStatus: PeerEmojiStatus? {
        switch self {
        case let user as TelegramUser:
            return user.emojiStatus
        case let channel as TelegramChannel:
            return channel.emojiStatus
        default:
            return nil
        }
    }
    
    var backgroundEmojiId: Int64? {
        switch self {
        case let user as TelegramUser:
            return user.backgroundEmojiId
        case let channel as TelegramChannel:
            return channel.backgroundEmojiId
        default:
            return nil
        }
    }
    
    var profileBackgroundEmojiId: Int64? {
        if let emojiStatus {
            switch emojiStatus.content {
            case let .starGift(_, _, _, _, patternFileId, _, _, _, _):
                return patternFileId
            default:
                break
            }
        }
        switch self {
        case let user as TelegramUser:
            return user.profileBackgroundEmojiId
        case let channel as TelegramChannel:
            return channel.profileBackgroundEmojiId
        default:
            return nil
        }
    }
}

public extension TelegramPeerUsername {
    var isActive: Bool {
        return self.flags.contains(.isActive) || self.flags.contains(.isEditable)
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

public func peerViewMonoforumMainPeer(_ view: PeerView) -> Peer? {
    if let peer = peerViewMainPeer(view) {
        if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum), let linkedMonoforumId = channel.linkedMonoforumId {
            return view.peers[linkedMonoforumId]
        } else {
            return nil
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
            } else if let peer = peer as? TelegramChannel, peer.isMonoForum, let linkedMonoforumId = peer.linkedMonoforumId {
                if let regularPeer = message.peers[linkedMonoforumId] {
                    peers[regularPeer.id] = regularPeer
                }
            }
        }
        self.init(peerId: message.id.peerId, peers: peers, associatedMedia: [:])
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
    
    var chatOrMonoforumMainPeer: Peer? {
        if let channel = self.peer as? TelegramChannel, channel.flags.contains(.isMonoforum), let linkedMonoforumId = channel.linkedMonoforumId {
            return self.peers[linkedMonoforumId]
        } else {
            return self.chatMainPeer
        }
    }
}

public func isServicePeer(_ peer: Peer) -> Bool {
    if let peer = peer as? TelegramUser {
        if peer.id.isReplies {
            return true
        }
        if peer.id.isVerificationCodes {
            return true
        }
        return (peer.id.namespace == Namespaces.Peer.CloudUser && (peer.id.id._internalGetInt64Value() == 777000 || peer.id.id._internalGetInt64Value() == 333000))
    }
    return false
}

public extension PeerId {
    var isTelegramNotifications: Bool {
        if self.namespace == Namespaces.Peer.CloudUser {
            if self.id._internalGetInt64Value() == 777000 {
                return true
            }
        }
        return false
    }
    
    var isReplies: Bool {
        if self.namespace == Namespaces.Peer.CloudUser {
            if self.id._internalGetInt64Value() == 708513 || self.id._internalGetInt64Value() == 1271266957 {
                return true
            }
        }
        return false
    }
    
    var isVerificationCodes: Bool {
        if self.namespace == Namespaces.Peer.CloudUser {
            if self.id._internalGetInt64Value() == 489000 {
                return true
            }
        }
        return false
    }
    
    var isRepliesOrVerificationCodes: Bool {
        return self.isReplies || self.isVerificationCodes
    }
    
    func isRepliesOrSavedMessages(accountPeerId: PeerId) -> Bool {
        if accountPeerId == self {
            return true
        } else if self.isReplies {
            return true
        } else if self.isVerificationCodes {
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
    
    var isAnonymousSavedMessages: Bool {
        if self.namespace == Namespaces.Peer.CloudUser {
            if self.id._internalGetInt64Value() == anonymousSavedMessagesId {
                return true
            }
        }
        return false
    }
    var isSecretChat: Bool {
        return self.namespace == Namespaces.Peer.SecretChat
    }
}
