import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import TemporaryCachedPeerDataManager
import AlertUI
import PresentationDataUtils
import UndoUI
import ItemListPeerItem
import ItemListPeerActionItem

private final class ChannelAdminsControllerArguments {
    let context: AccountContext
    
    let openRecentActions: () -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let removeAdmin: (EnginePeer.Id) -> Void
    let addAdmin: () -> Void
    let openAdmin: (ChannelParticipant) -> Void
    let updateAntiSpamEnabled: (Bool) -> Void
    
    init(context: AccountContext, openRecentActions: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, removeAdmin: @escaping (EnginePeer.Id) -> Void, addAdmin: @escaping () -> Void, openAdmin: @escaping (ChannelParticipant) -> Void, updateAntiSpamEnabled: @escaping (Bool) -> Void) {
        self.context = context
        self.openRecentActions = openRecentActions
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removeAdmin = removeAdmin
        self.addAdmin = addAdmin
        self.openAdmin = openAdmin
        self.updateAntiSpamEnabled = updateAntiSpamEnabled
    }
}

private enum ChannelAdminsSection: Int32 {
    case administration
    case admins
}

private enum ChannelAdminsEntryStableId: Hashable {
    case index(Int32)
    case peer(EnginePeer.Id)
}

private enum ChannelAdminsEntry: ItemListNodeEntry {
    case recentActions(PresentationTheme, String)
    case antiSpam(PresentationTheme, String, Bool)
    case antiSpamInfo(PresentationTheme, String)
    
    case adminsHeader(PresentationTheme, String)
    case adminPeerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Bool, Int32, RenderedChannelParticipant, ItemListPeerItemEditing, Bool, Bool)
    case addAdmin(PresentationTheme, String, Bool)
    case adminsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .recentActions, .antiSpam, .antiSpamInfo:
                return ChannelAdminsSection.administration.rawValue
            case .adminsHeader, .adminPeerItem, .addAdmin, .adminsInfo:
                return ChannelAdminsSection.admins.rawValue
        }
    }
    
    var stableId: ChannelAdminsEntryStableId {
        switch self {
            case .recentActions:
                return .index(0)
            case .antiSpam:
                return .index(1)
            case .antiSpamInfo:
                return .index(2)
            case .adminsHeader:
                return .index(3)
            case .addAdmin:
                return .index(4)
            case .adminsInfo:
                return .index(5)
            case let .adminPeerItem(_, _, _, _, _, _, participant, _, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        switch lhs {
            case let .recentActions(lhsTheme, lhsText):
                if case let .recentActions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .antiSpam(lhsTheme, lhsText, lhsValue):
                if case let .antiSpam(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .antiSpamInfo(lhsTheme, lhsText):
                if case let .antiSpamInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adminsHeader(lhsTheme, lhsText):
                if case let .adminsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adminPeerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsIsGroup, lhsIndex, lhsParticipant, lhsEditing, lhsEnabled, lhsHasAction):
                if case let .adminPeerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsIsGroup, rhsIndex, rhsParticipant, rhsEditing, rhsEnabled, rhsHasAction) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameOrder != rhsNameOrder {
                        return false
                    }
                    if lhsIsGroup != rhsIsGroup {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsParticipant != rhsParticipant {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    if lhsHasAction != rhsHasAction {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .adminsInfo(lhsTheme, lhsText):
                if case let .adminsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addAdmin(lhsTheme, lhsText, lhsEditing):
                if case let .addAdmin(rhsTheme, rhsText, rhsEditing) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        switch lhs {
            case .recentActions:
                return true
            case .antiSpam:
                switch rhs {
                    case .recentActions:
                        return false
                    default:
                        return true
                }
            case .antiSpamInfo:
                switch rhs {
                    case .recentActions, .antiSpam:
                        return false
                    default:
                        return true
                }
            case .adminsHeader:
                switch rhs {
                    case .recentActions, .antiSpam, .antiSpamInfo:
                        return false
                    default:
                        return true
                }
            case let .adminPeerItem(_, _, _, _, _, index, _, _, _, _):
                switch rhs {
                    case .recentActions, .antiSpam, .antiSpamInfo, .adminsHeader, .addAdmin:
                        return false
                    case let .adminPeerItem(_, _, _, _, _, rhsIndex, _, _, _, _):
                        return index < rhsIndex
                    default:
                        return true
                }
            case .addAdmin:
                switch rhs {
                    case .recentActions, .antiSpam, .antiSpamInfo, .adminsHeader, .addAdmin:
                        return false
                    default:
                        return true
                }
            case .adminsInfo:
                return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelAdminsControllerArguments
        switch self {
            case let .recentActions(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Chat/Info/RecentActionsIcon")?.precomposed(), title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openRecentActions()
                })
            case let .antiSpam(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Chat/Info/AntiSpam")?.precomposed(), title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateAntiSpamEnabled(value)
                })
            case let .antiSpamInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .adminsHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .adminPeerItem(_, strings, dateTimeFormat, nameDisplayOrder, _, _, participant, editing, enabled, hasAction):
                let peerText: String
                var action: (() -> Void)?
                switch participant.participant {
                    case .creator:
                        peerText = strings.Channel_Management_LabelOwner
                    case let .member(_, _, adminInfo, _, _):
                        if let adminInfo = adminInfo {
                            if let peer = participant.peers[adminInfo.promotedBy] {
                                if peer.id == participant.peer.id {
                                    peerText = strings.Channel_Management_LabelAdministrator
                                } else {
                                    peerText = strings.Channel_Management_PromotedBy(EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder)).string
                                }
                            } else {
                                peerText = ""
                            }
                        } else {
                            peerText = ""
                        }
                }
                if hasAction {
                    action = {
                        arguments.openAdmin(participant.participant)
                    }
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(participant.peer), presence: nil, text: .text(peerText, .secondary), label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: true, sectionId: self.section, action: action, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removeAdmin(peerId)
                })
            case let .addAdmin(theme, text, editing):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addPersonIcon(theme), title: text, sectionId: self.section, editing: editing, action: {
                    arguments.addAdmin()
                })
            case let .adminsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct ChannelAdminsControllerState: Equatable {
    let editing: Bool
    let peerIdWithRevealedOptions: EnginePeer.Id?
    let removingPeerId: EnginePeer.Id?
    let removedPeerIds: Set<EnginePeer.Id>
    let temporaryAdmins: [RenderedChannelParticipant]
    let searchingMembers: Bool

    init() {
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
        self.removedPeerIds = Set()
        self.temporaryAdmins = []
        self.searchingMembers = false
    }
    
    init(editing: Bool, peerIdWithRevealedOptions: EnginePeer.Id?, removingPeerId: EnginePeer.Id?, removedPeerIds: Set<EnginePeer.Id>, temporaryAdmins: [RenderedChannelParticipant], searchingMembers: Bool) {
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
        self.removedPeerIds = removedPeerIds
        self.temporaryAdmins = temporaryAdmins
        self.searchingMembers = searchingMembers
    }
    
    static func ==(lhs: ChannelAdminsControllerState, rhs: ChannelAdminsControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        if lhs.removedPeerIds != rhs.removedPeerIds {
            return false
        }
        if lhs.temporaryAdmins != rhs.temporaryAdmins {
            return false
        }
        if lhs.searchingMembers != rhs.searchingMembers {
            return false
        }
        
        return true
    }
    
    func withUpdatedSearchingMembers(_ searchingMembers: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: searchingMembers)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: EnginePeer.Id?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: EnginePeer.Id?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovedPeerIds(_ removedPeerIds: Set<EnginePeer.Id>) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: removedPeerIds, temporaryAdmins: self.temporaryAdmins, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedTemporaryAdmins(_ temporaryAdmins: [RenderedChannelParticipant]) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: temporaryAdmins, searchingMembers: self.searchingMembers)
    }
}

private func channelAdminsControllerEntries(presentationData: PresentationData, accountPeerId: EnginePeer.Id, peer: EnginePeer?, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?, antiSpamAvailable: Bool, antiSpamEnabled: Bool) -> [ChannelAdminsEntry] {
    if participants == nil || participants?.count == nil {
        return []
    }
    
    var entries: [ChannelAdminsEntry] = []
    if case let .channel(peer) = peer {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
        }
        //entries.append(.recentActions(presentationData.theme, presentationData.strings.Group_Info_AdminLog))
        
        if isGroup && peer.hasPermission(.deleteAllMessages) && (antiSpamAvailable || antiSpamEnabled) {
            entries.append(.antiSpam(presentationData.theme, presentationData.strings.Group_Management_AntiSpam, antiSpamEnabled))
            entries.append(.antiSpamInfo(presentationData.theme, presentationData.strings.Group_Management_AntiSpamInfo))
        }
        
        if let participants = participants {
            entries.append(.adminsHeader(presentationData.theme, isGroup ? presentationData.strings.ChannelMembers_GroupAdminsTitle : presentationData.strings.ChannelMembers_ChannelAdminsTitle))
            
            if peer.hasPermission(.addAdmins) {
                entries.append(.addAdmin(presentationData.theme, presentationData.strings.Channel_Management_AddModerator, state.editing))
            }
            
            var combinedParticipants: [RenderedChannelParticipant] = participants
            var existingParticipantIds = Set<EnginePeer.Id>()
            for participant in participants {
                existingParticipantIds.insert(participant.peer.id)
            }
            
            for participant in state.temporaryAdmins {
                if !existingParticipantIds.contains(participant.peer.id) {
                    combinedParticipants.append(participant)
                }
            }
            
            var index: Int32 = 0
            for participant in combinedParticipants.sorted(by: { lhs, rhs in
                let lhsInvitedAt: Int32
                switch lhs.participant {
                    case .creator:
                        lhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        lhsInvitedAt = invitedAt
                }
                let rhsInvitedAt: Int32
                switch rhs.participant {
                    case .creator:
                        rhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        rhsInvitedAt = invitedAt
                }
                return lhsInvitedAt < rhsInvitedAt
            }) {
                if !state.removedPeerIds.contains(participant.peer.id) {
                    var canEdit = true
                    var canOpen = true
                    switch participant.participant {
                        case .creator:
                            canEdit = false
                            canOpen = isGroup && peer.flags.contains(.isCreator)
                        case let .member(id, _, adminInfo, _, _):
                            if id == accountPeerId {
                                canEdit = false
                            } else if let adminInfo = adminInfo {
                                if peer.flags.contains(.isCreator) {
                                    canEdit = true
                                    canOpen = true
                                } else if adminInfo.promotedBy == accountPeerId {
                                    canEdit = true
                                    if let adminRights = peer.adminRights {
                                        if adminRights.rights.isEmpty {
                                            canOpen = false
                                        }
                                    }
                                } else {
                                    canEdit = false
                                }
                            } else {
                                canEdit = false
                            }
                    }
                    entries.append(.adminPeerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, isGroup, index, participant, ItemListPeerItemEditing(editable: canEdit, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id && existingParticipantIds.contains(participant.peer.id), canOpen))
                    index += 1
                }
            }
            
            if peer.hasPermission(.addAdmins) {
                let info = isGroup ? presentationData.strings.Group_Management_AddModeratorHelp : presentationData.strings.Channel_Management_AddModeratorHelp
                entries.append(.adminsInfo(presentationData.theme, info))
            }
        }
    } else if case let .legacyGroup(peer) = peer {
        let isGroup = true
        //entries.append(.recentActions(presentationData.theme, presentationData.strings.Group_Info_AdminLog))
        
        if let participants = participants {
            entries.append(.adminsHeader(presentationData.theme, presentationData.strings.ChannelMembers_GroupAdminsTitle))
            
            if case .creator = peer.role {
                entries.append(.addAdmin(presentationData.theme, presentationData.strings.Channel_Management_AddModerator, state.editing))
            }
            
            var combinedParticipants: [RenderedChannelParticipant] = participants
            var existingParticipantIds = Set<EnginePeer.Id>()
            for participant in participants {
                existingParticipantIds.insert(participant.peer.id)
            }
            
            for participant in state.temporaryAdmins {
                if !existingParticipantIds.contains(participant.peer.id) {
                    combinedParticipants.append(participant)
                }
            }
            
            var index: Int32 = 0
            for participant in combinedParticipants.sorted(by: { lhs, rhs in
                let lhsInvitedAt: Int32
                switch lhs.participant {
                    case .creator:
                        lhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        lhsInvitedAt = invitedAt
                }
                let rhsInvitedAt: Int32
                switch rhs.participant {
                    case .creator:
                        rhsInvitedAt = Int32.min
                    case let .member(_, invitedAt, _, _, _):
                        rhsInvitedAt = invitedAt
                }
                return lhsInvitedAt < rhsInvitedAt
            }) {
                if !state.removedPeerIds.contains(participant.peer.id) {
                    var editable = true
                    var canEdit = true
                    switch participant.participant {
                        case .creator:
                            editable = false
                            if case .creator = peer.role {
                            } else {
                                canEdit = false
                            }
                        case let .member(id, _, adminInfo, _, _):
                            if id == accountPeerId {
                                editable = false
                            } else if let adminInfo = adminInfo {
                                if case .creator = peer.role {
                                    editable = true
                                } else if adminInfo.promotedBy == accountPeerId {
                                    editable = true
                                } else {
                                    editable = false
                                }
                            } else {
                                editable = false
                            }
                    }
                    entries.append(.adminPeerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, isGroup, index, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id && existingParticipantIds.contains(participant.peer.id), canEdit))
                    index += 1
                }
            }
            
            if case .creator = peer.role {
                let info = presentationData.strings.Group_Management_AddModeratorHelp
                entries.append(.adminsInfo(presentationData.theme, info))
            }
        }
    }
    
    return entries
}

public func channelAdminsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId initialPeerId: EnginePeer.Id, loadCompleted: @escaping () -> Void = {}) -> ViewController {
    let statePromise = ValuePromise(ChannelAdminsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelAdminsControllerState())
    let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissInputImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()

    let removeAdminDisposable = MetaDisposable()
    actionsDisposable.add(removeAdminDisposable)
    
    let addAdminDisposable = MetaDisposable()
    actionsDisposable.add(addAdminDisposable)
    
    let upgradeDisposable = MetaDisposable()
    actionsDisposable.add(upgradeDisposable)
    
    let updateAntiSpamDisposable = MetaDisposable()
    actionsDisposable.add(updateAntiSpamDisposable)
    
    let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)
        
    let antiSpamConfiguration = AntiSpamBotConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    let resolveAntiSpamPeerDisposable = MetaDisposable()
    if let antiSpamBotId = antiSpamConfiguration.antiSpamBotId {
        resolveAntiSpamPeerDisposable.set(
            (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: antiSpamBotId))
            |> mapToSignal { peer -> Signal<Never, NoError> in
                if let _ = peer {
                    return .never()
                } else {
                    return context.engine.peers.updatedRemotePeer(peer: .user(id: antiSpamBotId.id._internalGetInt64Value(), accessHash: 0))
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, NoError> in
                        return .never()
                    }
                }
            }).start()
        )
    }
    
    var upgradedToSupergroupImpl: ((EnginePeer.Id, @escaping () -> Void) -> Void)?
    
    let currentPeerId = ValuePromise<EnginePeer.Id>(initialPeerId)
    
    let upgradedToSupergroup: (EnginePeer.Id, @escaping () -> Void) -> Void = { upgradedPeerId, f in
        currentPeerId.set(upgradedPeerId)
        upgradedToSupergroupImpl?(upgradedPeerId, f)
    }
    
    let transferedOwnership: (EnginePeer.Id) -> Void = { memberId in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (currentPeerId.get()
        |> take(1)
        |> mapToSignal { peerId in
            return context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.Peer(id: memberId)
            )
        }
        |> deliverOnMainQueue).start(next: { peer, user in
            guard let peer = peer, let user = user else {
                return
            }
            presentControllerImpl?(UndoOverlayController(presentationData: context.sharedContext.currentPresentationData.with { $0 }, content: .succeed(text: presentationData.strings.Channel_OwnershipTransfer_TransferCompleted(user.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string, timeout: nil), elevatedLayout: false, action: { _ in return false }), nil)
        })
    }
    
    actionsDisposable.add((currentPeerId.get()
    |> mapToSignal { peerId in
        return context.engine.peers.keepPeerUpdated(id: peerId, forceUpdate: false)
    }).start())
    
    struct PeerData: Equatable {
        var peerId: EnginePeer.Id
        var peer: EnginePeer?
        var participantCount: Int?
        
        init(
            peerId: EnginePeer.Id,
            peer: EnginePeer?,
            participantCount: Int?
        ) {
            self.peerId = peerId
            self.peer = peer
            self.participantCount = participantCount
        }
    }
    
    let peerView = Promise<PeerData>()
    peerView.set(currentPeerId.get()
    |> mapToSignal { peerId in
        return context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId)
        )
        |> map { peer, participantCount -> PeerData in
            return PeerData(
                peerId: peerId,
                peer: peer,
                participantCount: participantCount
            )
        }
    })
    
    let arguments = ChannelAdminsControllerArguments(context: context, openRecentActions: {
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer else {
                    return
                }
                if case .legacyGroup = peer {
                } else {
                    pushControllerImpl?(context.sharedContext.makeChatRecentActionsController(context: context, peer: peer._asPeer(), adminPeerId: nil))
                }
            })
        })
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, removeAdmin: { adminId in
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            updateState {
                return $0.withUpdatedRemovingPeerId(adminId)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                removeAdminDisposable.set((context.engine.peers.removeGroupAdmin(peerId: peerId, adminId: adminId)
                |> deliverOnMainQueue).start(completed: {
                    updateState {
                        return $0.withUpdatedRemovingPeerId(nil)
                    }
                }))
            } else {
                removeAdminDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(engine: context.engine, peerId: peerId, memberId: adminId, adminRights: nil, rank: nil)
                |> deliverOnMainQueue).start(completed: {
                    updateState {
                        return $0.withUpdatedRemovingPeerId(nil)
                    }
                }))
            }
        })
    }, addAdmin: {
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            let _ = (peerView.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { peerView in
                updateState { current in
                    var dismissController: (() -> Void)?
                    let controller = ChannelMembersSearchController(context: context, peerId: peerId, mode: .promote, filters: [], openPeer: { peer, participant in
                        dismissController?()
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        if peer.id == context.account.peerId {
                            return
                        }
                        if let participant = participant {
                            switch participant.participant {
                            case .creator:
                                return
                            case let .member(_, _, _, banInfo, _):
                                if let banInfo = banInfo {
                                    var canUnban = false
                                    if banInfo.restrictedBy != context.account.peerId {
                                        canUnban = true
                                    }
                                    if case let .channel(channel) = peerView.peer {
                                        if channel.hasPermission(.banMembers) {
                                            canUnban = true
                                        }
                                    }
                                    if !canUnban {
                                        presentControllerImpl?(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_Members_AddAdminErrorBlacklisted, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                        return
                                    }
                                }
                            }
                        }
                        pushControllerImpl?(channelAdminController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, adminId: peer.id, initialParticipant: participant?.participant, updated: { _ in
                        }, upgradedToSupergroup: upgradedToSupergroup, transferedOwnership: transferedOwnership))
                    })
                    dismissController = { [weak controller] in
                        controller?.dismiss()
                    }
                    pushControllerImpl?(controller)
                    
                    return current
                }
            })
        })
    }, openAdmin: { participant in
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            pushControllerImpl?(channelAdminController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, adminId: participant.peerId, initialParticipant: participant, updated: { _ in
            }, upgradedToSupergroup: upgradedToSupergroup, transferedOwnership: transferedOwnership))
        })
    }, updateAntiSpamEnabled: { value in
        let _ = (currentPeerId.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peerId in
            updateAntiSpamDisposable.set(context.engine.peers.toggleAntiSpamProtection(peerId: peerId, enabled: value).start())
        })
    })
    
    let membersAndLoadMoreControlValue = Atomic<(Disposable, PeerChannelMemberCategoryControl?)?>(value: nil)
    
    let membersDisposableValue = MetaDisposable()
    actionsDisposable.add(membersDisposableValue)
    
    actionsDisposable.add((currentPeerId.get()
    |> deliverOnMainQueue).start(next: { peerId in
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            var didReportLoadCompleted = false
            let membersAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?) = context.peerChannelMemberCategoriesContextsManager.admins(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId) { membersState in
                if case .loading = membersState.loadingState, membersState.list.isEmpty {
                    adminsPromise.set(.single(nil))
                } else {
                    adminsPromise.set(.single(membersState.list))
                    if !didReportLoadCompleted {
                        didReportLoadCompleted = true
                        loadCompleted()
                    }
                }
            }
            let _ = membersAndLoadMoreControlValue.swap(membersAndLoadMoreControl)
            membersDisposableValue.set(membersAndLoadMoreControl.0)
        } else {
            loadCompleted()
            let membersDisposable = (currentPeerId.get()
            |> mapToSignal { peerId -> Signal<[RenderedChannelParticipant]?, NoError> in
                return context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.LegacyGroupParticipants(id: peerId)
                )
                |> mapToSignal { participants -> Signal<[(EngineLegacyGroupParticipant, EnginePeer?)]?, NoError> in
                    guard case let .known(participants) = participants else {
                        return .single(nil)
                    }
                    
                    return context.engine.data.subscribe(
                        EngineDataMap(participants.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0.peerId) })
                    )
                    |> map { peers -> [(EngineLegacyGroupParticipant, EnginePeer?)]? in
                        var result: [(EngineLegacyGroupParticipant, EnginePeer?)] = []
                        for participant in participants {
                            var peer: EnginePeer?
                            if let peerValue = peers[participant.peerId] {
                                peer = peerValue
                            }
                            result.append((participant, peer))
                        }
                        return result
                    }
                }
                |> map { participants -> [RenderedChannelParticipant]? in
                    guard let participants else {
                        return nil
                    }
                    
                    var result: [RenderedChannelParticipant] = []
                    var creatorPeer: EnginePeer?
                    for (participant, peer) in participants {
                        if let peer {
                            switch participant {
                            case .creator:
                                creatorPeer = peer
                            default:
                                break
                            }
                        }
                    }
                    guard let creator = creatorPeer else {
                        return nil
                    }
                    for (participant, peer) in participants {
                        if let peer {
                            switch participant {
                            case .creator:
                                result.append(RenderedChannelParticipant(participant: .creator(id: peer.id, adminInfo: nil, rank: nil), peer: peer._asPeer()))
                            case .admin:
                                var peers: [EnginePeer.Id: EnginePeer] = [:]
                                peers[creator.id] = creator
                                peers[peer.id] = peer
                                result.append(RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: .internal_groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil, rank: nil), peer: peer._asPeer(), peers: peers.mapValues({ $0._asPeer() })))
                            case .member:
                                break
                            }
                        }
                    }
                    return result
                }
            }).start(next: { members in
                adminsPromise.set(.single(members))
            })
            let membersAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?) = (membersDisposable, nil)
            let _ = membersAndLoadMoreControlValue.swap(membersAndLoadMoreControl)
            membersDisposableValue.set(membersAndLoadMoreControl.0)
        }
    }))
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(
        queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        peerView.get(),
        adminsPromise.get(),
        currentPeerId.get()
        |> mapToSignal { peerId -> Signal<Bool, NoError> in
            return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.AntiSpamEnabled(id: peerId))
        }
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, view, admins, antiSpamEnabled -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let peerId = view.peerId
        
        var antiSpamAvailable = false
        if case .channel = view.peer, let participantCount = view.participantCount, participantCount >= antiSpamConfiguration.minimumGroupParticipants {
            antiSpamAvailable = true
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        var secondaryRightNavigationButton: ItemListNavigationButton?
        if let admins = admins, admins.count > 1 {
            if state.editing {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(false)
                    }
                })
            } else if case let .channel(peer) = view.peer, peer.flags.contains(.isCreator) {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(true)
                    }
                })
            }
            
            if !state.editing && peerId.namespace == Namespaces.Peer.CloudChannel {
                if rightNavigationButton == nil {
                    rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedSearchingMembers(true)
                        }
                    })
                } else {
                    secondaryRightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedSearchingMembers(true)
                        }
                    })
                }
            }
        }
        
        let previous = previousPeers
        previousPeers = admins
        
        var isGroup = true
        if case let .channel(peer) = view.peer, case .broadcast = peer.info {
            isGroup = false
        } else if case .legacyGroup = view.peer {
            isGroup = true
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers {
            searchItem = ChannelMembersSearchItem(context: context, peerId: peerId, searchContext: nil, searchMode: .searchAdmins, cancel: {
                updateState { state in
                    return state.withUpdatedSearchingMembers(false)
                }
            }, openPeer: { _, participant in
                if let participant = participant?.participant, case .member = participant {
                    pushControllerImpl?(channelAdminController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, adminId: participant.peerId, initialParticipant: participant, updated: { _ in
                        updateState { state in
                            return state.withUpdatedSearchingMembers(false)
                        }
                    }, upgradedToSupergroup: upgradedToSupergroup, transferedOwnership: transferedOwnership))
                }
            }, pushController: { c in
                pushControllerImpl?(c)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if admins == nil || admins?.count == 0 {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(isGroup ? presentationData.strings.ChatAdmins_Title : presentationData.strings.Channel_Management_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelAdminsControllerEntries(presentationData: presentationData, accountPeerId: context.account.peerId, peer: view.peer, state: state, participants: admins, antiSpamAvailable: antiSpamAvailable, antiSpamEnabled: antiSpamEnabled), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && admins != nil && previous!.count >= admins!.count)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
            controller.view.endEditing(true)
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    upgradedToSupergroupImpl = { [weak controller] upgradedPeerId, f in
        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }

        rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController, replace: { c in
            if c === controller {
                return channelAdminsController(context: context, peerId: upgradedPeerId, loadCompleted: {
                })
            } else {
                return c
            }
        })
        f()
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
            let _ = (currentPeerId.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { peerId in
                if let loadMoreControl = membersAndLoadMoreControlValue.with({ $0?.1 }) {
                    context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
                }
            })
        }
    }
    return controller
}

public func rebuildControllerStackAfterSupergroupUpgrade(controller: ViewController, navigationController: NavigationController, replace: ((UIViewController) -> UIViewController)? = nil) {
    var controllers = navigationController.viewControllers
    for i in 0 ..< controllers.count {
        if controllers[i] === controller {
            for j in 0 ..< i {
                if controllers[j] is ChatController {
                    if j + 1 <= i - 1 {
                        controllers.removeSubrange(j + 1 ... i - 1)
                    }
                    break
                }
            }
            break
        }
    }
    for i in 0 ..< controllers.count {
        if let replace = replace {
            controllers[i] = replace(controllers[i])
        }
    }
    navigationController.setViewControllers(controllers, animated: false)
}
