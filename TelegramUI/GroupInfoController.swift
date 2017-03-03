import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let addMemberPlusIcon = UIImage(bundleImageName: "Peer Info/PeerItemPlusIcon")?.precomposed()

private final class GroupInfoArguments {
    let account: Account
    let peerId: PeerId
    
    let pushController: (ViewController) -> Void
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    let changeNotificationMuteSettings: () -> Void
    let openSharedMedia: () -> Void
    let openAdminManagement: () -> Void
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateEditingDescriptionText: (String) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let addMember: () -> Void
    let removePeer: (PeerId) -> Void
    let convertToSupergroup: () -> Void
    
    init(account: Account, peerId: PeerId, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, changeNotificationMuteSettings: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openAdminManagement: @escaping () -> Void, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updateEditingDescriptionText: @escaping (String) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addMember: @escaping () -> Void, removePeer: @escaping (PeerId) -> Void, convertToSupergroup: @escaping () -> Void) {
        self.account = account
        self.peerId = peerId
        self.pushController = pushController
        self.presentController = presentController
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openSharedMedia = openSharedMedia
        self.openAdminManagement = openAdminManagement
        self.updateEditingName = updateEditingName
        self.updateEditingDescriptionText = updateEditingDescriptionText
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.addMember = addMember
        self.removePeer = removePeer
        self.convertToSupergroup = convertToSupergroup
    }
}

private enum GroupInfoSection: ItemListSectionId {
    case info
    case about
    case sharedMediaAndNotifications
    case infoManagement
    case memberManagement
    case members
    case leave
}

private enum GroupInfoMemberStatus {
    case member
    case admin
}

private enum GroupEntryStableId: Hashable, Equatable {
    case peer(PeerId)
    case index(Int)
    
    static func ==(lhs: GroupEntryStableId, rhs: GroupEntryStableId) -> Bool {
        switch lhs {
            case let .peer(peerId):
                if case .peer(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .peer(peerId):
                return peerId.hashValue
            case let .index(index):
                return index.hashValue
        }
    }
}

private enum GroupInfoEntry: ItemListNodeEntry {
    case info(peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState)
    case setGroupPhoto
    case about(String)
    case link(String)
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case adminManagement
    case groupTypeSetup(isPublic: Bool)
    case groupDescriptionSetup(text: String)
    case groupManagementInfoLabel(text: String)
    case membersAdmins(count: Int)
    case membersBlacklist(count: Int)
    case addMember(editing: Bool)
    case member(index: Int, peerId: PeerId, peer: Peer, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus, editing: ItemListPeerItemEditing, enabled: Bool)
    case convertToSupergroup
    case leave
    
    var section: ItemListSectionId {
        switch self {
            case .info, .setGroupPhoto:
                return GroupInfoSection.info.rawValue
            case .about, .link:
                return GroupInfoSection.about.rawValue
            case .sharedMedia, .notifications, .adminManagement:
                return GroupInfoSection.sharedMediaAndNotifications.rawValue
            case .groupTypeSetup, .groupDescriptionSetup, .groupManagementInfoLabel:
                return GroupInfoSection.infoManagement.rawValue
            case .membersAdmins, .membersBlacklist:
                return GroupInfoSection.memberManagement.rawValue
            case .addMember, .member:
                return GroupInfoSection.members.rawValue
            case .convertToSupergroup, .leave:
                return GroupInfoSection.leave.rawValue
        }
    }
    
    static func ==(lhs: GroupInfoEntry, rhs: GroupInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsPeer, lhsCachedData, lhsState):
                if case let .info(rhsPeer, rhsCachedData, rhsState) = rhs {
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
            case .setGroupPhoto, .sharedMedia, .leave, .convertToSupergroup, .adminManagement:
                return lhs.sortIndex == rhs.sortIndex
            case let .about(text):
                if case .about(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .link(text):
                if case .link(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .notifications(lhsSettings):
                if case let .notifications(rhsSettings) = rhs {
                    if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                        return lhsSettings.isEqual(to: rhsSettings)
                    } else if (lhsSettings != nil) != (rhsSettings != nil) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .groupTypeSetup(isPublic):
                if case .groupTypeSetup(isPublic) = rhs {
                    return true
                } else {
                    return false
                }
            case let .groupDescriptionSetup(text):
                if case .groupDescriptionSetup(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .groupManagementInfoLabel(text):
                if case .groupManagementInfoLabel(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .membersAdmins(lhsCount):
                if case let .membersAdmins(rhsCount) = rhs, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .membersBlacklist(lhsCount):
                if case let .membersBlacklist(rhsCount) = rhs, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .addMember(editing):
                if case .addMember(editing) = rhs {
                    return true
                } else {
                    return false
                }
            case let .member(lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsMemberStatus, lhsEditing, lhsEnabled):
                if case let .member(rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsMemberStatus, rhsEditing, rhsEnabled) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsMemberStatus != rhsMemberStatus {
                        return false
                    }
                    if lhsPeerId != rhsPeerId {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if !lhsPresence.isEqual(to: rhsPresence) {
                            return false
                        }
                    } else if (lhsPresence != nil) != (rhsPresence != nil) {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    var stableId: GroupEntryStableId {
        switch self {
            case let .member(_, peerId, _, _, _, _, _):
                return .peer(peerId)
            default:
                return .index(self.sortIndex)
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .setGroupPhoto:
                return 1
            case .about:
                return 2
            case .link:
                return 3
            case .notifications:
                return 4
            case .sharedMedia:
                return 5
            case .adminManagement:
                return 6
            case .groupTypeSetup:
                return 7
            case .groupDescriptionSetup:
                return 8
            case .groupManagementInfoLabel:
                return 9
            case .membersAdmins:
                return 10
            case .membersBlacklist:
                return 11
            case .addMember:
                return 12
            case let .member(index, _, _, _, _, _, _):
                return 20 + index
            case .convertToSupergroup:
                return 100000
            case .leave:
                return 100000 + 1
        }
    }
    
    static func <(lhs: GroupInfoEntry, rhs: GroupInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: GroupInfoArguments) -> ListViewItem {
        switch self {
            case let .info(peer, cachedData, state):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, peer: peer, presence: nil, cachedData: cachedData, state: state, sectionId: self.section, style: .blocks, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                })
            case .setGroupPhoto:
                return ItemListActionItem(title: "Set Group Photo", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                })
            case let .about(text):
                return ItemListMultilineTextItem(text: text, sectionId: self.section, style: .blocks)
            case let .link(url):
                return ItemListActionItem(title: url, kind: .neutral, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return ItemListDisclosureItem(title: "Notifications", label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case .sharedMedia:
                return ItemListDisclosureItem(title: "Shared Media", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openSharedMedia()
                })
            case .adminManagement:
                return ItemListDisclosureItem(title: "Add Admins", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openAdminManagement()
                })
            case let .addMember(editing):
                return ItemListPeerActionItem(icon: addMemberPlusIcon, title: "Add Member", sectionId: self.section, editing: editing, action: {
                    arguments.addMember()
                })
            case let .groupTypeSetup(isPublic):
                return ItemListDisclosureItem(title: "Group Type", label: isPublic ? "Public" : "Private", sectionId: self.section, style: .blocks, action: {
                    arguments.presentController(channelVisibilityController(account: arguments.account, peerId: arguments.peerId, mode: .generic), ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                })
            case let .groupDescriptionSetup(text):
                return ItemListMultilineInputItem(text: text, placeholder: "Group Description", sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                }, action: {
                    
                })
            case let .membersAdmins(count):
                return ItemListDisclosureItem(title: "Admins", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(channelAdminsController(account: arguments.account, peerId: arguments.peerId))
                })
            case let .membersBlacklist(count):
                return ItemListDisclosureItem(title: "Blacklist", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(channelBlacklistController(account: arguments.account, peerId: arguments.peerId))
                })
            case let .member(_, _, peer, presence, memberStatus, editing, enabled):
                let label: String?
                switch memberStatus {
                    case .admin:
                        label = "admin"
                    case .member:
                        label = nil
                }
                return ItemListPeerItem(account: arguments.account, peer: peer, presence: presence, text: .presence, label: label, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: {
                    if let infoController = peerInfoController(account: arguments.account, peer: peer) {
                        arguments.pushController(infoController)
                    }
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
            case .convertToSupergroup:
                return ItemListActionItem(title: "Convert to Supergroup", kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.convertToSupergroup()
                })
            case .leave:
                return ItemListActionItem(title: "Delete and Exit", kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                })
            default:
                preconditionFailure()
        }
    }
}

private struct TemporaryParticipant: Equatable {
    let peer: Peer
    let presence: PeerPresence?
    let timestamp: Int32
    
    static func ==(lhs: TemporaryParticipant, rhs: TemporaryParticipant) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            if !lhsPresence.isEqual(to: rhsPresence) {
                return false
            }
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        return true
    }
}

private struct GroupInfoState: Equatable {
    let editingState: GroupInfoEditingState?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    let peerIdWithRevealedOptions: PeerId?
    
    let temporaryParticipants: [TemporaryParticipant]
    let successfullyAddedParticipantIds: Set<PeerId>
    let removingParticipantIds: Set<PeerId>
    
    let savingData: Bool
    
    static func ==(lhs: GroupInfoState, rhs: GroupInfoState) -> Bool {
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.temporaryParticipants != rhs.temporaryParticipants {
            return false
        }
        if lhs.successfullyAddedParticipantIds != rhs.successfullyAddedParticipantIds {
            return false
        }
        if lhs.removingParticipantIds != rhs.removingParticipantIds {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        return true
    }
    
    func withUpdatedEditingState(_ editingState: GroupInfoEditingState?) -> GroupInfoState {
        return GroupInfoState(editingState: editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }

    func withUpdatedTemporaryParticipants(_ temporaryParticipants: [TemporaryParticipant]) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedSuccessfullyAddedParticipantIds(_ successfullyAddedParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedRemovingParticipantIds(_ removingParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: savingData)
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

private func canRemoveParticipant(account: Account, isAdmin: Bool, participantId: PeerId, invitedBy: PeerId?) -> Bool {
    if participantId == account.peerId {
        return false
    }
    
    if account.peerId == invitedBy {
        return true
    }
    
    return isAdmin
}

private func groupInfoEntries(account: Account, view: PeerView, state: GroupInfoState) -> [GroupInfoEntry] {
    var entries: [GroupInfoEntry] = []
    if let peer = peerViewMainPeer(view) {
        let infoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingState?.editingName, updatingName: state.updatingName)
        entries.append(.info(peer: peer, cachedData: view.cachedData, state: infoState))
    }
    
    var highlightAdmins = false
    var canManageGroup = false
    var canManageMembers = false
    var isPublic = false
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if group.flags.contains(.adminsEnabled) {
            highlightAdmins = true
            switch group.role {
                case .admin, .creator:
                    canManageGroup = true
                    canManageMembers = true
                case .member:
                    break
            }
        } else {
            canManageGroup = true
            switch group.role {
                case .admin, .creator:
                    canManageMembers = true
                case .member:
                    break
            }
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        highlightAdmins = true
        isPublic = channel.username != nil
        switch channel.role {
            case .creator:
                canManageGroup = true
                canManageMembers = true
            case .moderator:
                canManageMembers = true
            case .editor, .member:
                break
        }
    }
    
    if canManageGroup {
        entries.append(GroupInfoEntry.setGroupPhoto)
    }
    
    if let editingState = state.editingState {
        if let group = view.peers[view.peerId] as? TelegramGroup, case .creator = group.role {
            entries.append(.adminManagement)
        } else if let cachedChannelData = view.cachedData as? CachedChannelData {
            entries.append(GroupInfoEntry.groupTypeSetup(isPublic: isPublic))
            entries.append(GroupInfoEntry.groupDescriptionSetup(text: editingState.editingDescriptionText))
            
            if let adminCount = cachedChannelData.participantsSummary.adminCount {
                entries.append(GroupInfoEntry.membersAdmins(count: Int(adminCount)))
            }
            if let bannedCount = cachedChannelData.participantsSummary.bannedCount {
                entries.append(GroupInfoEntry.membersBlacklist(count: Int(bannedCount)))
            }
        }
    } else {
        if let cachedChannelData = view.cachedData as? CachedChannelData {
            if let about = cachedChannelData.about, !about.isEmpty {
                entries.append(.about(about))
            }
            if let peer = view.peers[view.peerId] as? TelegramChannel, let username = peer.username, !username.isEmpty {
                entries.append(.link("t.me/" + username))
            }
        }
        
        entries.append(GroupInfoEntry.notifications(settings: view.notificationSettings))
        entries.append(GroupInfoEntry.sharedMedia)
    }
    
    var canRemoveAnyMember = false
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        for participant in participants.participants {
            if canRemoveParticipant(account: account, isAdmin: canManageMembers, participantId: participant.peerId, invitedBy: participant.invitedBy) {
                canRemoveAnyMember = true
                break
            }
        }
    } else if let cachedChannelData = view.cachedData as? CachedChannelData, let participants = cachedChannelData.topParticipants {
        for participant in participants.participants {
            if canRemoveParticipant(account: account, isAdmin: canManageMembers, participantId: participant.peerId, invitedBy: nil) {
                canRemoveAnyMember = true
                break
            }
        }
    }
    
    if canManageGroup {
        entries.append(GroupInfoEntry.addMember(editing: state.editingState != nil && canRemoveAnyMember))
    }
    
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        var updatedParticipants = participants.participants
        let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
        
        var peerPresences: [PeerId: PeerPresence] = view.peerPresences
        var peers: [PeerId: Peer] = view.peers
        var disabledPeerIds = state.removingParticipantIds
        
        if !state.temporaryParticipants.isEmpty {
            for participant in state.temporaryParticipants {
                if !existingParticipantIds.contains(participant.peer.id) {
                    updatedParticipants.append(.member(id: participant.peer.id, invitedBy: account.peerId, invitedAt: participant.timestamp))
                    if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                        peerPresences[participant.peer.id] = presence
                    }
                    if peers[participant.peer.id] == nil {
                        peers[participant.peer.id] = participant.peer
                    }
                    disabledPeerIds.insert(participant.peer.id)
                }
            }
        }
        
        let sortedParticipants = updatedParticipants.sorted(by: { lhs, rhs in
            let lhsPresence = peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = peerPresences[rhs.peerId] as? TelegramUserPresence
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
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = peers[sortedParticipants[i].peerId] {
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
                entries.append(GroupInfoEntry.member(index: i, peerId: peer.id, peer: peer, presence: peerPresences[peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: canRemoveParticipant(account: account, isAdmin: canManageMembers, participantId: peer.id, invitedBy: sortedParticipants[i].invitedBy), editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == peer.id), enabled: !disabledPeerIds.contains(peer.id)))
            }
        }
    } else if let cachedChannelData = view.cachedData as? CachedChannelData, let participants = cachedChannelData.topParticipants {
        var updatedParticipants = participants.participants
        let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
        var peerPresences: [PeerId: PeerPresence] = view.peerPresences
        var peers: [PeerId: Peer] = view.peers
        var disabledPeerIds = state.removingParticipantIds
        
        if !state.temporaryParticipants.isEmpty {
            for participant in state.temporaryParticipants {
                if !existingParticipantIds.contains(participant.peer.id) {
                    updatedParticipants.append(.member(id: participant.peer.id, invitedAt: participant.timestamp))
                    if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                        peerPresences[participant.peer.id] = presence
                    }
                    if peers[participant.peer.id] == nil {
                        peers[participant.peer.id] = participant.peer
                    }
                    disabledPeerIds.insert(participant.peer.id)
                }
            }
        }
        
        let sortedParticipants = updatedParticipants.sorted(by: { lhs, rhs in
            let lhsPresence = peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = peerPresences[rhs.peerId] as? TelegramUserPresence
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
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = peers[sortedParticipants[i].peerId] {
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
                entries.append(GroupInfoEntry.member(index: i, peerId: peer.id, peer: peer, presence: peerPresences[peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: canRemoveParticipant(account: account, isAdmin: canManageMembers, participantId: peer.id, invitedBy: nil), editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == peer.id), enabled: !disabledPeerIds.contains(peer.id)))
            }
        }
    }
    
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .Member = group.membership {
            if case .creator = group.role, state.editingState != nil {
                entries.append(.convertToSupergroup)
            }
            entries.append(.leave)
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        if case .member = channel.participationStatus {
            entries.append(.leave)
        }
    }
    
    return entries
}

private func valuesRequiringUpdate(state: GroupInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramGroup {
        if let editingState = state.editingState {
            if let title = editingState.editingName?.composedTitle, title != peer.title {
                return (title, nil)
            }
        }
        return (nil, nil)
    } else if let peer = view.peers[view.peerId] as? TelegramChannel {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName?.composedTitle, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        
        return (titleValue, descriptionValue)
    } else {
        return (nil, nil)
    }
}

public func groupInfoController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(GroupInfoState(editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false), ignoreRepeated: true)
    let stateValue = Atomic(value: GroupInfoState(editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false))
    let updateState: ((GroupInfoState) -> GroupInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        actionsDisposable.add(account.viewTracker.updatedCachedChannelParticipants(peerId, forceImmediateUpdate: true).start())
    }
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerDescriptionDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerDescriptionDisposable)
    
    let addMemberDisposable = MetaDisposable()
    actionsDisposable.add(addMemberDisposable)
    
    let removeMemberDisposable = MetaDisposable()
    actionsDisposable.add(removeMemberDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let arguments = GroupInfoArguments(account: account, peerId: peerId, pushController: { controller in
        pushControllerImpl?(controller)
    }, presentController: { controller, presentationArguments in
        presentControllerImpl?(controller, presentationArguments)
    }, changeNotificationMuteSettings: {
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let notificationAction: (Int32) -> Void = {  muteUntil in
            let muteState: PeerMuteState
            if muteUntil <= 0 {
                muteState = .unmuted
            } else if muteUntil == Int32.max {
                muteState = .muted(until: Int32.max)
            } else {
                muteState = .muted(until: Int32(Date().timeIntervalSince1970) + muteUntil)
            }
            changeMuteSettingsDisposable.set(changePeerNotificationSettings(account: account, peerId: peerId, settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: PeerMessageSound.bundledModern(id: 0))).start())
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Enable", action: {
                    dismissAction()
                    notificationAction(0)
                }),
                ActionSheetButtonItem(title: "Mute for 1 hour", action: {
                    dismissAction()
                    notificationAction(1 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "Mute for 8 hours", action: {
                    dismissAction()
                    notificationAction(8 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "Mute for 2 days", action: {
                    dismissAction()
                    notificationAction(2 * 24 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "Disable", action: {
                    dismissAction()
                    notificationAction(Int32.max)
                })
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openSharedMedia: {
        if let controller = peerSharedMediaController(account: account, peerId: peerId) {
            pushControllerImpl?(controller)
        }
    }, openAdminManagement: {
        pushControllerImpl?(groupAdminsController(account: account, peerId: peerId))
    }, updateEditingName: { editingName in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(GroupInfoEditingState(editingName: editingName, editingDescriptionText: editingState.editingDescriptionText))
            } else {
                return state
            }
        }
    }, updateEditingDescriptionText: { text in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(text))
            }
            return state
        }
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, addMember: {
        var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
        let contactsController = ContactSelectionController(account: account, title: "Add Member", confirmation: { peerId in
            if let confirmationImpl = confirmationImpl {
                return confirmationImpl(peerId)
            } else {
                return .single(false)
            }
        })
        confirmationImpl = { [weak contactsController] peerId in
            return account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue
            |> mapToSignal { peer in
                let result = ValuePromise<Bool>()
                if let contactsController = contactsController {
                    let alertController = standardTextAlertController(title: nil, text: "Add \(peer.displayTitle)?", actions: [
                        TextAlertAction(type: .genericAction, title: "Cancel", action: {
                            result.set(false)
                        }),
                        TextAlertAction(type: .defaultAction, title: "OK", action: {
                            result.set(true)
                        })
                    ])
                    contactsController.present(alertController, in: .window)
                }
                
                return result.get()
            }
        }
        let addMember = contactsController.result
            |> deliverOnMainQueue
            |> mapToSignal { memberId -> Signal<Void, NoError> in
                if let memberId = memberId {
                    return account.postbox.peerView(id: memberId)
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { view -> Signal<Void, NoError> in
                            if let peer = view.peers[memberId] {
                                updateState { state in
                                    var found = false
                                    for participant in state.temporaryParticipants {
                                        if participant.peer.id == memberId {
                                            found = true
                                            break
                                        }
                                    }
                                    if !found {
                                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                        var temporaryParticipants = state.temporaryParticipants
                                        temporaryParticipants.append(TemporaryParticipant(peer: peer, presence: view.peerPresences[memberId], timestamp: timestamp))
                                        return state.withUpdatedTemporaryParticipants(temporaryParticipants)
                                    } else {
                                        return state
                                    }
                                }
                            }
                            
                            return addPeerMember(account: account, peerId: peerId, memberId: memberId)
                                |> deliverOnMainQueue
                                |> afterCompleted {
                                    updateState { state in
                                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                        successfullyAddedParticipantIds.insert(memberId)
                                        
                                        return state.withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                    }
                                } |> `catch` { _ -> Signal<Void, NoError> in
                                    updateState { state in
                                        var temporaryParticipants = state.temporaryParticipants
                                        for i in 0 ..< temporaryParticipants.count {
                                            if temporaryParticipants[i].peer.id == memberId {
                                                temporaryParticipants.remove(at: i)
                                                break
                                            }
                                        }
                                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                        successfullyAddedParticipantIds.remove(memberId)
                                        
                                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                    }
                                    
                                    return .complete()
                                }
                        }
                } else {
                    return .complete()
                }
            }
        presentControllerImpl?(contactsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        addMemberDisposable.set(addMember.start())
    }, removePeer: { memberId in
        let signal = account.postbox.loadedPeerWithId(memberId)
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Bool, NoError> in
                let result = ValuePromise<Bool>()
                
                let actionSheet = ActionSheetController()
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Remove \(peer.displayTitle)?", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        result.set(true)
                    })
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                
                return result.get()
            }
            |> mapToSignal { value -> Signal<Void, NoError> in
                if value {
                    updateState { state in
                        var temporaryParticipants = state.temporaryParticipants
                        for i in 0 ..< state.temporaryParticipants.count {
                            if state.temporaryParticipants[i].peer.id == memberId {
                                temporaryParticipants.remove(at: i)
                                break
                            }
                        }
                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                        successfullyAddedParticipantIds.remove(memberId)
                        
                        var removingParticipantIds = state.removingParticipantIds
                        removingParticipantIds.insert(memberId)
                        
                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds).withUpdatedRemovingParticipantIds(removingParticipantIds)
                    }
                    
                    return removePeerMember(account: account, peerId: peerId, memberId: memberId)
                        |> deliverOnMainQueue
                        |> afterDisposed {
                            updateState { state in
                                var removingParticipantIds = state.removingParticipantIds
                                removingParticipantIds.remove(memberId)
                                
                                return state.withUpdatedRemovingParticipantIds(removingParticipantIds)
                            }
                    }
                } else {
                    return .complete()
                }
            }
        removeMemberDisposable.set(signal.start())
    }, convertToSupergroup: {
        pushControllerImpl?(convertToSupergroupController(account: account, peerId: peerId))
    })
    
    let signal = combineLatest(statePromise.get(), account.viewTracker.peerView(peerId))
        |> map { state, view -> (ItemListControllerState, (ItemListNodeState<GroupInfoEntry>, GroupInfoEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            let rightNavigationButton: ItemListNavigationButton
            if let editingState = state.editingState {
                var doneEnabled = true
                if let editingName = editingState.editingName, editingName.isEmpty {
                    doneEnabled = false
                }
                if peer is TelegramChannel {
                    if (view.cachedData as? CachedChannelData) == nil {
                        doneEnabled = false
                    }
                }
                
                if state.savingData {
                    rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: doneEnabled, action: {})
                } else {
                    rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: doneEnabled, action: {
                        var updateValues: (title: String?, description: String?) = (nil, nil)
                        updateState { state in
                            updateValues = valuesRequiringUpdate(state: state, view: view)
                            if updateValues.0 != nil || updateValues.1 != nil {
                                return state.withUpdatedSavingData(true)
                            } else {
                                return state.withUpdatedEditingState(nil)
                            }
                        }
                        
                        let updateTitle: Signal<Void, Void>
                        if let titleValue = updateValues.title {
                            updateTitle = updatePeerTitle(account: account, peerId: peerId, title: titleValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateTitle = .complete()
                        }
                        
                        let updateDescription: Signal<Void, Void>
                        if let descriptionValue = updateValues.description {
                            updateDescription = updatePeerDescription(account: account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateDescription = .complete()
                        }
                        
                        let signal = combineLatest(updateTitle, updateDescription)
                        
                        updatePeerNameDisposable.set((signal |> deliverOnMainQueue).start(error: { _ in
                            updateState { state in
                                return state.withUpdatedSavingData(false)
                            }
                        }, completed: {
                            updateState { state in
                                return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                            }
                        }))
                    })
                }
            } else {
                rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                    if let peer = peer as? TelegramGroup {
                        updateState { state in
                            return state.withUpdatedEditingState(GroupInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(peer.indexName), editingDescriptionText: ""))
                        }
                    } else if let channel = peer as? TelegramChannel, case .group = channel.info {
                        var text = ""
                        if let cachedData = view.cachedData as? CachedChannelData, let about = cachedData.about {
                            text = about
                        }
                        updateState { state in
                            return state.withUpdatedEditingState(GroupInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(channel.indexName), editingDescriptionText: text))
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(title: "Info", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: groupInfoEntries(account: account, view: view, state: state), style: .blocks)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window, with: presentationArguments)
    }
    return controller
}
