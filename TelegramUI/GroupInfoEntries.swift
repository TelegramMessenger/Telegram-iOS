import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private let addMemberPlusIcon = UIImage(bundleImageName: "Peer Info/PeerItemPlusIcon")?.precomposed()

private enum GroupInfoSection: ItemListSectionId {
    case info
    case about
    case sharedMediaAndNotifications
    case infoManagement
    case memberManagement
    case members
    case leave
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
    case info(peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState)
    case setGroupPhoto
    case aboutHeader
    case about(text: String)
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case groupTypeSetup(isPublic: Bool)
    case groupDescriptionSetup(text: String)
    case groupManagementInfoLabel(text: String)
    case membersAdmins(count: Int)
    case membersBlacklist(count: Int)
    case usersHeader
    case addMember
    case member(index: Int, peerId: PeerId, peer: Peer?, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus)
    case leave
    
    var section: ItemListSectionId {
        switch self {
            case .info, .setGroupPhoto:
                return GroupInfoSection.info.rawValue
            case .aboutHeader, .about:
                return GroupInfoSection.about.rawValue
            case .sharedMedia, .notifications:
                return GroupInfoSection.sharedMediaAndNotifications.rawValue
            case .groupTypeSetup, .groupDescriptionSetup, .groupManagementInfoLabel:
                return GroupInfoSection.infoManagement.rawValue
            case .membersAdmins, .membersBlacklist:
                return GroupInfoSection.memberManagement.rawValue
            case .usersHeader, .addMember, .member:
                return GroupInfoSection.members.rawValue
            case .leave:
                return GroupInfoSection.leave.rawValue
        }
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? GroupInfoEntry else {
            return false
        }
        
        switch self {
            case let .info(lhsPeer, lhsCachedData, lhsState):
                    if case let .info(rhsPeer, rhsCachedData, rhsState) = entry {
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
                        } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                            return false
                        }
                        if lhsState != rhsState {
                            return false
                        }
                        return true
                    } else {
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
                    case .about(lhsText):
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
            case let .groupTypeSetup(isPublic):
                if case .groupTypeSetup(isPublic) = entry {
                    return true
                } else {
                    return false
                }
            case let .groupDescriptionSetup(text):
                if case .groupDescriptionSetup(text) = entry {
                    return true
                } else {
                    return false
                }
            case let .groupManagementInfoLabel(text):
                if case .groupManagementInfoLabel(text) = entry {
                    return true
                } else {
                    return false
                }
            case let .membersAdmins(lhsCount):
                if case let .membersAdmins(rhsCount) = entry, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .membersBlacklist(lhsCount):
                if case let .membersBlacklist(rhsCount) = entry, lhsCount == rhsCount {
                    return true
                } else {
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
            case .groupTypeSetup:
                return 6
            case .groupDescriptionSetup:
                return 7
            case .groupManagementInfoLabel:
                return 8
            case .membersAdmins:
                return 9
            case .membersBlacklist:
                return 10
            case .usersHeader:
                return 11
            case .addMember:
                return 12
            case let .member(index, _, _, _, _):
                return 20 + index
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
            case let .info(peer, cachedData, state):
                return ItemListAvatarAndNameInfoItem(account: account, peer: peer, presence: nil, cachedData: cachedData, state: state, sectionId: self.section, style: .blocks, editingNameUpdated: { editingName in
                    
                })
            case .setGroupPhoto:
                return ItemListActionItem(title: "Set Group Photo", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return ItemListDisclosureItem(title: "Notifications", label: label, sectionId: self.section, style: .blocks, action: {
                    interaction.changeNotificationMuteSettings()
                })
            case .sharedMedia:
                return ItemListDisclosureItem(title: "Shared Media", label: "", sectionId: self.section, style: .blocks, action: {
                    interaction.openSharedMedia()
                })
            case .addMember:
                return ItemListPeerActionItem(icon: addMemberPlusIcon, title: "Add Member", sectionId: self.section, action: {
                    
                })
            case let .groupTypeSetup(isPublic):
                return ItemListDisclosureItem(title: "Group Type", label: isPublic ? "Public" : "Private", sectionId: self.section, style: .blocks, action: {
                    
                })
            case let .groupDescriptionSetup(text):
                return ItemListMultilineInputItem(text: text, sectionId: self.section, textUpdated: { updatedText in
                    interaction.updateState { state in
                        if let state = state as? GroupInfoState, let editingState = state.editingState {
                            return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(updatedText))
                        }
                        return state
                    }
                }, action: {
                    
                })
            case let .membersAdmins(count):
                return ItemListDisclosureItem(title: "Admins", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                    
                })
            case let .membersBlacklist(count):
                return ItemListDisclosureItem(title: "Blacklist", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                    
                })
            case let .member(_, _, peer, presence, memberStatus):
                let label: String?
                switch memberStatus {
                    case .admin:
                        label = "admin"
                    case .member:
                        label = nil
                }
                return ItemListPeerItem(account: account, peer: peer, presence: presence, label: label, sectionId: self.section, action: {
                    if let peer = peer {
                        interaction.openPeerInfo(peer.id)
                    }
                })
            case .leave:
                return ItemListActionItem(title: "Delete and Exit", kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                })
            default:
                preconditionFailure()
        }
    }
}

private struct GroupInfoState: PeerInfoState {
    let editingState: GroupInfoEditingState?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? GroupInfoState {
            if self.editingState != to.editingState {
                return false
            }
            if self.updatingName != to.updatingName {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func withUpdatedEditingState(_ editingState: GroupInfoEditingState?) -> GroupInfoState {
        return GroupInfoState(editingState: editingState, updatingName: self.updatingName)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: updatingName)
    }
}

private struct GroupInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    let editingDescriptionText: String
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> GroupInfoEditingState {
        return GroupInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
    
    static func ==(lhs: GroupInfoEditingState, rhs: GroupInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}

func groupInfoEntries(view: PeerView, state: PeerInfoState?) -> PeerInfoEntries {
    var entries: [PeerInfoEntry] = []
    if let peer = peerViewMainPeer(view) {
        let infoState = ItemListAvatarAndNameInfoItemState(editingName: (state as? GroupInfoState)?.editingState?.editingName, updatingName: (state as? GroupInfoState)?.updatingName)
        entries.append(GroupInfoEntry.info(peer: peer, cachedData: view.cachedData, state: infoState))
    }
    
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
    
    if let editingState = (state as? GroupInfoState)?.editingState {
        if let cachedChannelData = view.cachedData as? CachedChannelData {
            entries.append(GroupInfoEntry.groupTypeSetup(isPublic: cachedChannelData.exportedInvitation != nil))
            entries.append(GroupInfoEntry.groupDescriptionSetup(text: editingState.editingDescriptionText))
            
            if let adminCount = cachedChannelData.participantsSummary.adminCount {
                entries.append(GroupInfoEntry.membersAdmins(count: adminCount))
            }
            if let bannedCount = cachedChannelData.participantsSummary.bannedCount {
                entries.append(GroupInfoEntry.membersBlacklist(count: bannedCount))
            }
        }
    } else {
        entries.append(GroupInfoEntry.notifications(settings: view.notificationSettings))
        entries.append(GroupInfoEntry.sharedMedia)
    }
    
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
    } else if let cachedChannelData = view.cachedData as? CachedChannelData, let participants = cachedChannelData.topParticipants {
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
                case let .moderator(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .moderator(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .editor(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                    }
                case let .editor(lhsId, _, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .moderator(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .editor(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                        return lhsInvitedAt > rhsInvitedAt
                    }
                case let .member(lhsId, lhsInvitedAt):
                    switch rhs {
                        case .creator:
                            return true
                        case let .moderator(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .editor(rhsId, _, rhsInvitedAt):
                            if lhsInvitedAt == rhsInvitedAt {
                                return lhsId.id < rhsId.id
                            }
                            return lhsInvitedAt > rhsInvitedAt
                        case let .member(rhsId, rhsInvitedAt):
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
                        case .moderator, .editor, .creator:
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
    
    var leftNavigationButton: PeerInfoNavigationButton?
    var rightNavigationButton: PeerInfoNavigationButton?
    if canManageGroup {
        if let state = state as? GroupInfoState, let _ = state.editingState {
            leftNavigationButton = PeerInfoNavigationButton(title: "Cancel", action: { state in
                if state == nil {
                    return GroupInfoState(editingState: nil, updatingName: nil)
                } else if let state = state as? GroupInfoState {
                    return state.withUpdatedEditingState(nil)
                } else {
                    return state
                }
            })
            rightNavigationButton = PeerInfoNavigationButton(title: "Done", action: { state in
                if state == nil {
                    return GroupInfoState(editingState: nil, updatingName: nil)
                } else if let state = state as? GroupInfoState {
                    return state.withUpdatedEditingState(nil)
                } else {
                    return state
                }
            })
        } else {
            var editingName: ItemListAvatarAndNameInfoItemName?
            if let peer = peerViewMainPeer(view) {
                editingName = ItemListAvatarAndNameInfoItemName(peer.indexName)
            }
            let editingDescriptionText: String
            if let cachedChannelData = view.cachedData as? CachedChannelData, let about = cachedChannelData.about {
                editingDescriptionText = about
            } else {
                editingDescriptionText = ""
            }
            rightNavigationButton = PeerInfoNavigationButton(title: "Edit", action: { state in
                if state == nil {
                    return GroupInfoState(editingState: GroupInfoEditingState(editingName: editingName, editingDescriptionText: editingDescriptionText), updatingName: nil)
                } else if let state = state as? GroupInfoState {
                    return state.withUpdatedEditingState(GroupInfoEditingState(editingName: editingName, editingDescriptionText: editingDescriptionText))
                } else {
                    return state
                }
            })
        }
    }


    return PeerInfoEntries(entries: entries, leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton)
}
