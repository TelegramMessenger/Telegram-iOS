import Foundation
import Postbox


// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public func canSendMessagesToPeer(_ peer: EnginePeer, ignoreDefault: Bool = false) -> Bool {
    if case let .user(user) = peer, user.addressName == "replies" {
        return false
    }
    switch peer {
    case .user, .legacyGroup:
        return !peer.isDeleted
    case let .secretChat(secretChat):
        return secretChat.embeddedState == .active
    case let .channel(channel):
        return channel.hasPermission(.sendSomething, ignoreDefault: ignoreDefault)
    case .community:
        return false
    }
}

public func canSendReactionsToPeer(_ peer: EnginePeer, ignoreDefault: Bool = false) -> Bool {
    switch peer {
    case .user:
        return !peer.isDeleted
    case let .legacyGroup(group):
        switch group.role {
        case .creator, .admin:
            return !peer.isDeleted
        case .member:
            if let defaultBannedRights = group.defaultBannedRights, defaultBannedRights.flags.contains(.banSendReactions) && !ignoreDefault {
                return false
            }
            return !peer.isDeleted
        }
    case let .secretChat(secretChat):
        return secretChat.embeddedState == .active
    case let .channel(channel):
        return channel.hasBannedPermission(.banSendReactions, ignoreDefault: ignoreDefault) == nil
    case .community:
        return false
    }
}
