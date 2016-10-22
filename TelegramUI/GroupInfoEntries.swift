import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private let addMemberPlusIcon = UIImage(bundleImageName: "Peer Info/PeerItemPlusIcon")?.precomposed()

private enum GroupInfoSection: UInt32, PeerInfoSection {
    case info
    case about
    case sharedMediaAndNotifications
    case members
    case leave
    
    func isEqual(to: PeerInfoSection) -> Bool {
        guard let section = to as? GroupInfoSection else {
            return false
        }
        return section == self
    }
    
    func isOrderedBefore(_ section: PeerInfoSection) -> Bool {
        guard let section = section as? GroupInfoSection else {
            return false
        }
        return self.rawValue < section.rawValue
    }
}

enum GroupInfoMemberStatus {
    case member
    case admin
}

private struct GroupPeerEntryStableId: PeerInfoEntryStableId {
    let peerId: PeerId
    
    func isEqual(to: PeerInfoEntryStableId) -> Bool {
        if let to = to as? GroupPeerEntryStableId, to.peerId == self.peerId {
            return true
        } else {
            return false
        }
    }
    
    var hashValue: Int {
        return self.peerId.hashValue
    }
}

enum GroupInfoEntry: PeerInfoEntry {
    case info(peer: Peer?, cachedData: CachedPeerData?)
    case setGroupPhoto
    case aboutHeader
    case about(text: String)
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case usersHeader
    case addMember
    case member(index: Int, peerId: PeerId, peer: Peer?, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus)
    case leave
    
    var section: PeerInfoSection {
        switch self {
            case .info, .setGroupPhoto:
                return GroupInfoSection.info
            case .aboutHeader, .about:
                return GroupInfoSection.about
            case .sharedMedia, .notifications:
                return GroupInfoSection.sharedMediaAndNotifications
            case .usersHeader, .addMember, .member:
                return GroupInfoSection.members
            case .leave:
                return GroupInfoSection.leave
        }
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? GroupInfoEntry else {
            return false
        }
        
        switch self {
            case let .info(lhsPeer, lhsCachedData):
                switch entry {
                case let .info(rhsPeer, rhsCachedData):
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer == nil) != (rhsPeer != nil) {
                        return false
                    }
                    if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                        if !lhsCachedData.isEqual(to: rhsCachedData) {
                            return false
                        }
                    } else if (rhsCachedData == nil) != (rhsCachedData != nil) {
                        return false
                    }
                    return true
                default:
                    return false
                }
            case .setGroupPhoto:
                if case .setGroupPhoto = entry {
                    return true
                } else {
                    return false
                }
            case .aboutHeader:
                if case .aboutHeader = entry {
                    return true
                } else {
                    return false
                }
            case let .about(lhsText):
                switch entry {
                case let .about(lhsText):
                    return true
                default:
                    return false
                }
            case .sharedMedia:
                switch entry {
                case .sharedMedia:
                    return true
                default:
                    return false
                }
            case let .notifications(lhsSettings):
                switch entry {
                case let .notifications(rhsSettings):
                    if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                        return lhsSettings.isEqual(to: rhsSettings)
                    } else if (lhsSettings != nil) != (rhsSettings != nil) {
                        return false
                    }
                    return true
                default:
                    return false
                }
            case .usersHeader:
                if case .usersHeader = entry {
                    return true
                } else {
                    return false
                }
            case .addMember:
                if case .addMember = entry {
                    return true
                } else {
                    return false
                }
            case let .member(lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsMemberStatus):
                if case let .member(rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsMemberStatus) = entry {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsMemberStatus != rhsMemberStatus {
                        return false
                    }
                    if lhsPeerId != rhsPeerId {
                        return false
                    }
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer != nil) != (rhsPeer != nil) {
                        return false
                    }
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if !lhsPresence.isEqual(to: rhsPresence) {
                            return false
                        }
                    } else if (lhsPresence != nil) != (rhsPresence != nil) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case .leave:
                if case .leave = entry {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        switch self {
            case let .member(_, peerId, _, _, _):
                return GroupPeerEntryStableId(peerId: peerId)
            default:
                return IntPeerInfoEntryStableId(value: self.sortIndex)
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .setGroupPhoto:
                return 1
            case .aboutHeader:
                return 2
            case .about:
                return 3
            case .notifications:
                return 4
            case .sharedMedia:
                return 5
            case .usersHeader:
                return 6
            case .addMember:
                return 7
            case let .member(index, _, _, _, _):
                return 10 + index
            case .leave:
                return 1000000
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let other = entry as? GroupInfoEntry else {
            return false
        }
        
        return self.sortIndex < other.sortIndex
    }
    
    func item(account: Account, interaction: PeerInfoControllerInteraction) -> ListViewItem {
        switch self {
            case let .info(peer, cachedData):
                return PeerInfoAvatarAndNameItem(account: account, peer: peer, cachedData: cachedData, editingState: nil, sectionId: self.section.rawValue, style: .blocks)
            case .setGroupPhoto:
                return PeerInfoActionItem(title: "Set Group Photo", kind: .generic, alignment: .natural, sectionId: self.section.rawValue, style: .blocks, action: {
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return PeerInfoDisclosureItem(title: "Notifications", label: label, sectionId: self.section.rawValue, style: .blocks, action: {
                    interaction.changeNotificationMuteSettings()
                })
            case .sharedMedia:
                return PeerInfoDisclosureItem(title: "Shared Media", label: "", sectionId: self.section.rawValue, style: .blocks, action: {
                    interaction.openSharedMedia()
                })
            case .addMember:
                return PeerInfoPeerActionItem(icon: addMemberPlusIcon, title: "Add Member", sectionId: self.section.rawValue, action: {
                    
                })
            case let .member(_, _, peer, presence, memberStatus):
                let label: String?
                switch memberStatus {
                    case .admin:
                        label = "admin"
                    case .member:
                        label = nil
                }
                return PeerInfoPeerItem(account: account, peer: peer, presence: presence, label: label, sectionId: self.section.rawValue, action: {
                    if let peer = peer {
                        interaction.openPeerInfo(peer.id)
                    }
                })
            case .leave:
                return PeerInfoActionItem(title: "Delete and Exit", kind: .destructive, alignment: .center, sectionId: self.section.rawValue, style: .blocks, action: {
                })
            default:
                preconditionFailure()
        }
    }
}

func groupInfoEntries(view: PeerView) -> PeerInfoEntries {
    var entries: [PeerInfoEntry] = []
    entries.append(GroupInfoEntry.info(peer: view.peers[view.peerId], cachedData: view.cachedData))
    
    var highlightAdmins = false
    var canManageGroup = false
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if group.flags.contains(.adminsEnabled) {
            highlightAdmins = true
            switch group.role {
                case .admin, .creator:
                    canManageGroup = true
                case .member:
                    break
            }
        } else {
            canManageGroup = true
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        highlightAdmins = true
        switch channel.role {
            case .creator:
                canManageGroup = true
            case .editor, .moderator, .member:
                break
        }
    }
    
    if canManageGroup {
        entries.append(GroupInfoEntry.setGroupPhoto)
    }
    
    entries.append(GroupInfoEntry.notifications(settings: view.notificationSettings))
    entries.append(GroupInfoEntry.sharedMedia)
    
    if canManageGroup {
        entries.append(GroupInfoEntry.addMember)
    }
    
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        let sortedParticipants = participants.participants.sorted(by: { lhs, rhs in
            let lhsPresence = view.peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = view.peerPresences[rhs.peerId] as? TelegramUserPresence
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if lhsPresence.status < rhsPresence.status {
                    return false
                } else if lhsPresence.status > rhsPresence.status {
                    return true
                }
            } else if let _ = lhsPresence {
                return true
            } else if let _ = rhsPresence {
                return false
            }
            
            switch lhs {
                case .creator:
                    return false
                case let .admin(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .admin(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
                case let .member(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .admin(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
            }
            return false
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = view.peers[sortedParticipants[i].peerId] {
                let memberStatus: GroupInfoMemberStatus
                if highlightAdmins {
                    switch sortedParticipants[i] {
                        case .admin, .creator:
                            memberStatus = .admin
                        case .member:
                            memberStatus = .member
                    }
                } else {
                    memberStatus = .member
                }
                entries.append(GroupInfoEntry.member(index: i, peerId: peer.id, peer: peer, presence: view.peerPresences[peer.id], memberStatus: memberStatus))
            }
        }
    }
    
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .Member = group.membership {
            entries.append(GroupInfoEntry.leave)
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        if case .member = channel.participationStatus {
            entries.append(GroupInfoEntry.leave)
        }
    }

    return PeerInfoEntries(entries: entries, leftNavigationButton: nil, rightNavigationButton: nil)
}
