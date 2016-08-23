import Foundation
import Postbox

public extension Peer {
    public var displayTitle: String {
        if let user = self as? TelegramUser {
            return user.name
        } else if let group = self as? TelegramGroup {
            return group.title
        }
        return ""
    }
    
    public var compactDisplayTitle: String {
        if let user = self as? TelegramUser {
            if let firstName = user.firstName {
                return firstName
            } else if let lastName = user.lastName {
                return lastName
            } else {
                return ""
            }
        } else if let group = self as? TelegramGroup {
            return group.title
        }
        return ""
    }
    
    public var displayLetters: [String] {
        if let user = self as? TelegramUser {
            if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty && !lastName.isEmpty {
                return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased(), lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
            } else if let firstName = user.firstName, !firstName.isEmpty {
                return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()]
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return [lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
            }
            
            return []
        } else if let group = self as? TelegramGroup {
            if group.title.startIndex != group.title.endIndex {
                return [group.title.substring(to: group.title.index(after: group.title.startIndex)).uppercased()]
            }
        }
        return []
    }
}

public extension PeerId {
    public var isGroup: Bool {
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


