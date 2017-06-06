import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramLegacyComponents

private let addMemberPlusIcon = UIImage(bundleImageName: "Peer Info/PeerItemPlusIcon")?.precomposed()

private final class GroupInfoArguments {
    let account: Account
    let peerId: PeerId
    
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    let tapAvatarAction: () -> Void
    let changeProfilePhoto: () -> Void
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
    
    init(account: Account, peerId: PeerId, avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext, tapAvatarAction: @escaping () -> Void, changeProfilePhoto: @escaping () -> Void, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, changeNotificationMuteSettings: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openAdminManagement: @escaping () -> Void, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updateEditingDescriptionText: @escaping (String) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, addMember: @escaping () -> Void, removePeer: @escaping (PeerId) -> Void, convertToSupergroup: @escaping () -> Void) {
        self.account = account
        self.peerId = peerId
        self.avatarAndNameInfoContext = avatarAndNameInfoContext
        self.tapAvatarAction = tapAvatarAction
        self.changeProfilePhoto = changeProfilePhoto
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
    case info(PresentationTheme, PresentationStrings, peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, updatingAvatar: TelegramMediaImageRepresentation?)
    case setGroupPhoto(PresentationTheme)
    case about(PresentationTheme, String)
    case link(PresentationTheme, String)
    case sharedMedia(PresentationTheme)
    case notifications(PresentationTheme, settings: PeerNotificationSettings?)
    case adminManagement(PresentationTheme)
    case groupTypeSetup(PresentationTheme, isPublic: Bool)
    case groupDescriptionSetup(PresentationTheme, text: String)
    case groupManagementInfoLabel(PresentationTheme, text: String)
    case membersAdmins(PresentationTheme, count: Int)
    case membersBlacklist(PresentationTheme, count: Int)
    case addMember(PresentationTheme, editing: Bool)
    case member(PresentationTheme, index: Int, peerId: PeerId, peer: Peer, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus, editing: ItemListPeerItemEditing, enabled: Bool)
    case convertToSupergroup(PresentationTheme)
    case leave(PresentationTheme)
    
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
        case let .info(lhsTheme, lhsStrings, lhsPeer, lhsCachedData, lhsState, lhsUpdatingAvatar):
                if case let .info(rhsTheme, rhsStrings, rhsPeer, rhsCachedData, rhsState, rhsUpdatingAvatar) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
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
                    if lhsUpdatingAvatar != rhsUpdatingAvatar {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .setGroupPhoto(lhsTheme):
                if case let .setGroupPhoto(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .sharedMedia(lhsTheme):
                if case let .sharedMedia(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .leave(lhsTheme):
                if case let .leave(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .convertToSupergroup(lhsTheme):
                if case let .convertToSupergroup(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .adminManagement(lhsTheme):
                if case let .adminManagement(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .about(lhsTheme, lhsText):
                if case let .about(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .link(lhsTheme, lhsText):
                if case let .link(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .notifications(lhsTheme, lhsSettings):
                if case let .notifications(rhsTheme, rhsSettings) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                        return lhsSettings.isEqual(to: rhsSettings)
                    } else if (lhsSettings != nil) != (rhsSettings != nil) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .groupTypeSetup(lhsTheme, lhsIsPublic):
                if case let .groupTypeSetup(rhsTheme, rhsIsPublic) = rhs, lhsTheme == rhsTheme, lhsIsPublic == rhsIsPublic {
                    return true
                } else {
                    return false
                }
            case let .groupDescriptionSetup(lhsTheme, lhsText):
                if case let .groupDescriptionSetup(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .groupManagementInfoLabel(lhsTheme, lhsText):
                if case let .groupManagementInfoLabel(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .membersAdmins(lhsTheme, lhsCount):
                if case let .membersAdmins(rhsTheme, rhsCount) = rhs, lhsTheme === rhsTheme, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .membersBlacklist(lhsTheme, lhsCount):
                if case let .membersBlacklist(rhsTheme, rhsCount) = rhs, lhsTheme === rhsTheme, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .addMember(lhsTheme, lhsEditing):
                if case let .addMember(rhsTheme, rhsEditing) = rhs, lhsTheme === rhsTheme, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
            case let .member(lhsTheme, lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsMemberStatus, lhsEditing, lhsEnabled):
                if case let .member(rhsTheme, rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsMemberStatus, rhsEditing, rhsEnabled) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
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
            case let .member(_, _, peerId, _, _, _, _, _):
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
            case let .member(_, index, _, _, _, _, _, _):
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
            case let .info(theme, strings, peer, cachedData, state, updatingAvatar):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, peer: peer, presence: nil, cachedData: cachedData, state: state, sectionId: self.section, style: .blocks(withTopInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.tapAvatarAction()
                }, context: arguments.avatarAndNameInfoContext, updatingImage: updatingAvatar)
            case let .setGroupPhoto(theme):
                return ItemListActionItem(theme: theme, title: "Set Group Photo", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .about(theme, text):
                return ItemListMultilineTextItem(theme: theme, text: text, sectionId: self.section, style: .blocks)
            case let .link(theme, url):
                return ItemListActionItem(theme: theme, title: url, kind: .neutral, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                })
            case let .notifications(theme, settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return ItemListDisclosureItem(theme: theme, title: "Notifications", label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case let .sharedMedia(theme):
                return ItemListDisclosureItem(theme: theme, title: "Shared Media", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openSharedMedia()
                })
            case let .adminManagement(theme):
                return ItemListDisclosureItem(theme: theme, title: "Add Admins", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openAdminManagement()
                })
            case let .addMember(theme, editing):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.plusIconImage(theme), title: "Add Member", sectionId: self.section, editing: editing, action: {
                    arguments.addMember()
                })
            case let .groupTypeSetup(theme, isPublic):
                return ItemListDisclosureItem(theme: theme, title: "Group Type", label: isPublic ? "Public" : "Private", sectionId: self.section, style: .blocks, action: {
                    arguments.presentController(channelVisibilityController(account: arguments.account, peerId: arguments.peerId, mode: .generic), ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                })
            case let .groupDescriptionSetup(theme, text):
                return ItemListMultilineInputItem(theme: theme, text: text, placeholder: "Group Description", sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                }, action: {
                    
                })
            case let .membersAdmins(theme, count):
                return ItemListDisclosureItem(theme: theme, title: "Admins", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(channelAdminsController(account: arguments.account, peerId: arguments.peerId))
                })
            case let .membersBlacklist(theme, count):
                return ItemListDisclosureItem(theme: theme, title: "Blacklist", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(channelBlacklistController(account: arguments.account, peerId: arguments.peerId))
                })
            case let .member(theme, _, _, peer, presence, memberStatus, editing, enabled):
                let label: String?
                switch memberStatus {
                    case .admin:
                        label = "admin"
                    case .member:
                        label = nil
                }
                return ItemListPeerItem(theme: theme, account: arguments.account, peer: peer, presence: presence, text: .presence, label: label == nil ? .none : .text(label!), editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: {
                    if let infoController = peerInfoController(account: arguments.account, peer: peer) {
                        arguments.pushController(infoController)
                    }
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
            case let .convertToSupergroup(theme):
                return ItemListActionItem(theme: theme, title: "Convert to Supergroup", kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.convertToSupergroup()
                })
            case let .leave(theme):
                return ItemListActionItem(theme: theme, title: "Delete and Exit", kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
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
    let updatingAvatar: TelegramMediaImageRepresentation?
    let editingState: GroupInfoEditingState?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    let peerIdWithRevealedOptions: PeerId?
    
    let temporaryParticipants: [TemporaryParticipant]
    let successfullyAddedParticipantIds: Set<PeerId>
    let removingParticipantIds: Set<PeerId>
    
    let savingData: Bool
    
    static func ==(lhs: GroupInfoState, rhs: GroupInfoState) -> Bool {
        if lhs.updatingAvatar != rhs.updatingAvatar {
            return false
        }
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
    
    func withUpdatedUpdatingAvatar(_ updatingAvatar: TelegramMediaImageRepresentation?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedEditingState(_ editingState: GroupInfoEditingState?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedUpdatingName(_ updatingName: ItemListAvatarAndNameInfoItemName?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }

    func withUpdatedTemporaryParticipants(_ temporaryParticipants: [TemporaryParticipant]) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedSuccessfullyAddedParticipantIds(_ successfullyAddedParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedRemovingParticipantIds(_ removingParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: removingParticipantIds, savingData: self.savingData)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> GroupInfoState {
        return GroupInfoState(updatingAvatar: self.updatingAvatar, editingState: self.editingState, updatingName: self.updatingName, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: savingData)
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

private func groupInfoEntries(account: Account, presentationData: PresentationData, view: PeerView, state: GroupInfoState) -> [GroupInfoEntry] {
    var entries: [GroupInfoEntry] = []
    if let peer = peerViewMainPeer(view) {
        let infoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingState?.editingName, updatingName: state.updatingName)
        entries.append(.info(presentationData.theme, presentationData.strings, peer: peer, cachedData: view.cachedData, state: infoState, updatingAvatar: state.updatingAvatar))
    }
    
    var highlightAdmins = false
    var canEditGroupInfo = false
    var canEditMembers = false
    var canAddMembers = false
    var isPublic = false
    var isCreator = false
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .creator = group.role {
            isCreator = true
        }
        if group.flags.contains(.adminsEnabled) {
            highlightAdmins = true
            switch group.role {
                case .admin, .creator:
                    canEditGroupInfo = true
                    canEditMembers = true
                    canAddMembers = true
                case .member:
                    break
            }
        } else {
            canEditGroupInfo = true
            canAddMembers = true
            switch group.role {
                case .admin, .creator:
                    canEditMembers = true
                case .member:
                    break
            }
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        highlightAdmins = true
        isPublic = channel.username != nil
        isCreator = channel.flags.contains(.isCreator)
        if channel.hasAdminRights(.canChangeInfo) {
            canEditGroupInfo = true
        }
        if channel.hasAdminRights(.canBanUsers) {
            canEditMembers = true
        }
        if channel.hasAdminRights(.canInviteUsers) {
            canAddMembers = true
        }
    }
    
    if canEditGroupInfo {
        entries.append(GroupInfoEntry.setGroupPhoto(presentationData.theme))
    }
    
    if let editingState = state.editingState {
        if let group = view.peers[view.peerId] as? TelegramGroup, case .creator = group.role {
            entries.append(.adminManagement(presentationData.theme))
        } else if let cachedChannelData = view.cachedData as? CachedChannelData {
            if isCreator {
                entries.append(GroupInfoEntry.groupTypeSetup(presentationData.theme, isPublic: isPublic))
            }
            if canEditGroupInfo {
                entries.append(GroupInfoEntry.groupDescriptionSetup(presentationData.theme, text: editingState.editingDescriptionText))
            }
            
            if let adminCount = cachedChannelData.participantsSummary.adminCount {
                entries.append(GroupInfoEntry.membersAdmins(presentationData.theme, count: Int(adminCount)))
            }
            if let bannedCount = cachedChannelData.participantsSummary.bannedCount {
                entries.append(GroupInfoEntry.membersBlacklist(presentationData.theme, count: Int(bannedCount)))
            }
        }
    } else {
        if let cachedChannelData = view.cachedData as? CachedChannelData {
            if let about = cachedChannelData.about, !about.isEmpty {
                entries.append(.about(presentationData.theme, about))
            }
            if let peer = view.peers[view.peerId] as? TelegramChannel, let username = peer.username, !username.isEmpty {
                entries.append(.link(presentationData.theme, "t.me/" + username))
            }
        }
        
        entries.append(GroupInfoEntry.notifications(presentationData.theme, settings: view.notificationSettings))
        entries.append(GroupInfoEntry.sharedMedia(presentationData.theme))
    }
    
    var canRemoveAnyMember = false
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        for participant in participants.participants {
            if canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: participant.peerId, invitedBy: participant.invitedBy) {
                canRemoveAnyMember = true
                break
            }
        }
    } else if let cachedChannelData = view.cachedData as? CachedChannelData, let participants = cachedChannelData.topParticipants {
        for participant in participants.participants {
            if canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: participant.peerId, invitedBy: nil) {
                canRemoveAnyMember = true
                break
            }
        }
    }
    
    if canAddMembers {
        entries.append(GroupInfoEntry.addMember(presentationData.theme, editing: state.editingState != nil && canRemoveAnyMember))
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
                entries.append(GroupInfoEntry.member(presentationData.theme, index: i, peerId: peer.id, peer: peer, presence: peerPresences[peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: peer.id, invitedBy: sortedParticipants[i].invitedBy), editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == peer.id), enabled: !disabledPeerIds.contains(peer.id)))
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
                    updatedParticipants.append(.member(id: participant.peer.id, invitedAt: participant.timestamp, adminInfo: nil, banInfo: nil))
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
                case let .member(lhsId, lhsInvitedAt, _, _):
                    switch rhs {
                        case .creator:
                            return true
                        case let .member(rhsId, rhsInvitedAt, _, _):
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
                        case .creator:
                            memberStatus = .admin
                        case let .member(_, _, adminInfo, _):
                            if adminInfo != nil {
                                memberStatus = .admin
                            } else {
                                memberStatus = .member
                            }
                    }
                } else {
                    memberStatus = .member
                }
                entries.append(GroupInfoEntry.member(presentationData.theme, index: i, peerId: peer.id, peer: peer, presence: peerPresences[peer.id], memberStatus: memberStatus, editing: ItemListPeerItemEditing(editable: canRemoveParticipant(account: account, isAdmin: canEditMembers, participantId: peer.id, invitedBy: nil), editing: state.editingState != nil && canRemoveAnyMember, revealed: state.peerIdWithRevealedOptions == peer.id), enabled: !disabledPeerIds.contains(peer.id)))
            }
        }
    }
    
    if let group = view.peers[view.peerId] as? TelegramGroup {
        if case .Member = group.membership {
            if case .creator = group.role, state.editingState != nil {
                entries.append(.convertToSupergroup(presentationData.theme))
            }
            entries.append(.leave(presentationData.theme))
        }
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        if case .member = channel.participationStatus {
            entries.append(.leave(presentationData.theme))
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
    let statePromise = ValuePromise(GroupInfoState(updatingAvatar: nil, editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false), ignoreRepeated: true)
    let stateValue = Atomic(value: GroupInfoState(updatingAvatar: nil, editingState: nil, updatingName: nil, peerIdWithRevealedOptions: nil, temporaryParticipants: [], successfullyAddedParticipantIds: Set(), removingParticipantIds: Set(), savingData: false))
    let updateState: ((GroupInfoState) -> GroupInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
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
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    let updateAvatarDisposable = MetaDisposable()
    actionsDisposable.add(updateAvatarDisposable)
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    
    let arguments = GroupInfoArguments(account: account, peerId: peerId, avatarAndNameInfoContext: avatarAndNameInfoContext, tapAvatarAction: {
        let _ = (account.postbox.loadedPeerWithId(peerId) |> take(1) |> deliverOnMainQueue).start(next: { peer in
            if peer.profileImageRepresentations.isEmpty {
                return
            }
            
            let galleryController = AvatarGalleryController(account: account, peer: peer, replaceRootController: { controller, ready in
                
            })
            hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first
                updateHiddenAvatarImpl?()
            }))
            presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                return avatarGalleryTransitionArguments?(entry)
            }))
        })
    }, changeProfilePhoto: {
        let emptyController = LegacyEmptyController()
        let navigationController = makeLegacyNavigationController(rootController: emptyController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
        
        let legacyController = LegacyController(legacyController: navigationController, presentation: .custom)
        
        presentControllerImpl?(legacyController, nil)
        
        let mixin = TGMediaAvatarMenuMixin(parentController: emptyController, hasDeleteButton: false, personalPhoto: true)!
        mixin.applicationInterface = legacyController.applicationInterface
        let _ = currentAvatarMixin.swap(mixin)
        mixin.didDismiss = { [weak legacyController] in
            legacyController?.dismiss()
        }
        mixin.didFinishWithImage = { image in
            if let image = image {
                if let data = UIImageJPEGRepresentation(image, 0.6) {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    let representation = TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), resource: resource)
                    updateState {
                        $0.withUpdatedUpdatingAvatar(representation)
                    }
                    updateAvatarDisposable.set((updatePeerPhoto(account: account, peerId: peerId, resource: resource) |> deliverOnMainQueue).start(next: { result in
                        switch result {
                            case .complete:
                                updateState {
                                    $0.withUpdatedUpdatingAvatar(nil)
                                }
                            case .progress:
                                break
                        }
                    }))
                }
            }
        }
        mixin.didDismiss = { [weak legacyController] in
            let _ = currentAvatarMixin.swap(nil)
            legacyController?.dismiss()
        }
        mixin.present()
    }, pushController: { controller in
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
        let contactsController = ContactSelectionController(account: account, title: { $0.GroupInfo_AddParticipantTitle }, confirmation: { peerId in
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
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), account.viewTracker.peerView(peerId))
        |> map { presentationData, state, view -> (ItemListControllerState, (ItemListNodeState<GroupInfoEntry>, GroupInfoEntry.ItemGenerationArguments)) in
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
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Info"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: "Back"))
            let listState = ItemListNodeState(entries: groupInfoEntries(account: account, presentationData: presentationData, view: view, state: state), style: .blocks)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window, with: presentationArguments)
    }
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: (ASDisplayNode, CGRect)?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    result = itemNode.avatarTransitionNode()
                }
            }
            if let (node, _) = result {
                return GalleryTransitionArguments(transitionNode: node, transitionContainerNode: controller.displayNode, transitionBackgroundNode: controller.displayNode)
            }
        }
        return nil
    }
    updateHiddenAvatarImpl = { [weak controller] in
        if let controller = controller {
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    itemNode.updateAvatarHidden()
                }
            }
        }
    }
    return controller
}
