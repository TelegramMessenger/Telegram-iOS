import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerItem

private final class ChatRecentActionsFilterControllerArguments {
    let context: AccountContext
    
    let toggleAllActions: (Bool) -> Void
    let toggleAction: ([AdminLogEventsFlags]) -> Void
    let toggleAllAdmins: (Bool) -> Void
    let toggleAdmin: (PeerId) -> Void
    
    init(context: AccountContext, toggleAllActions: @escaping (Bool) -> Void, toggleAction: @escaping ([AdminLogEventsFlags]) -> Void, toggleAllAdmins: @escaping (Bool) -> Void, toggleAdmin: @escaping (PeerId) -> Void) {
        self.context = context
        self.toggleAllActions = toggleAllActions
        self.toggleAction = toggleAction
        self.toggleAllAdmins = toggleAllAdmins
        self.toggleAdmin = toggleAdmin
    }
}

private enum ChatRecentActionsFilterSection: Int32 {
    case actions
    case admins
}

private enum ChatRecentActionsFilterEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
}

private enum ChatRecentActionsFilterEntry: ItemListNodeEntry {
    case actionsTitle(PresentationTheme, String)
    case allActions(PresentationTheme, String, Bool)
    case actionItem(PresentationTheme, Int32, [AdminLogEventsFlags], String, Bool)
    
    case adminsTitle(PresentationTheme, String)
    case allAdmins(PresentationTheme, String, Bool)
    case adminPeerItem(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, Int32, RenderedChannelParticipant, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .actionsTitle, .allActions, .actionItem:
                return ChatRecentActionsFilterSection.actions.rawValue
            case .adminsTitle, .allAdmins, .adminPeerItem:
                return ChatRecentActionsFilterSection.admins.rawValue
        }
    }
    
    var stableId: ChatRecentActionsFilterEntryStableId {
        switch self {
            case .actionsTitle:
                return .index(0)
            case .allActions:
                return .index(1)
            case let .actionItem(_, index, _, _, _):
                return .index(100 + index)
            case .adminsTitle:
                return .index(200)
            case .allAdmins:
                return .index(201)
            case let .adminPeerItem(_, _, _, _, _, participant, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChatRecentActionsFilterEntry, rhs: ChatRecentActionsFilterEntry) -> Bool {
        switch lhs {
            case let .actionsTitle(lhsTheme, lhsText):
                if case let .actionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .allActions(lhsTheme, lhsText, lhsValue):
                if case let .allActions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .actionItem(lhsTheme, lhsIndex, lhsFlags, lhsText, lhsValue):
                if case let .actionItem(rhsTheme, rhsIndex, rhsFlags, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsFlags == rhsFlags, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .adminsTitle(lhsTheme, lhsText):
                if case let .adminsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .allAdmins(lhsTheme, lhsText, lhsValue):
                if case let .allAdmins(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .adminPeerItem(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameDisplayOrder, lhsIndex, lhsParticipant, lhsChecked):
                if case let .adminPeerItem(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameDisplayOrder, rhsIndex, rhsParticipant, rhsChecked) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameDisplayOrder != rhsNameDisplayOrder {
                        return false
                    }
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsParticipant != rhsParticipant {
                        return false
                    }
                    if lhsChecked != rhsChecked {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatRecentActionsFilterEntry, rhs: ChatRecentActionsFilterEntry) -> Bool {
        switch lhs {
            case .actionsTitle:
                return true
            case .allActions:
                switch rhs {
                    case .actionsTitle:
                        return false
                    default:
                        return true
                }
            case let .actionItem(_, lhsIndex, _, _, _):
                switch rhs {
                    case .actionsTitle, .allActions:
                        return false
                    case let .actionItem(_, rhsIndex, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
                }
            case .adminsTitle:
                switch rhs {
                    case .adminPeerItem, .allAdmins:
                        return true
                    default:
                        return false
                }
            case .allAdmins:
                switch rhs {
                    case .adminPeerItem:
                        return true
                    default:
                        return false
                }
            case let .adminPeerItem(_, _, _, _, lhsIndex, _, _):
                switch rhs {
                    case let .adminPeerItem(_, _, _, _, rhsIndex, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return false
                }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatRecentActionsFilterControllerArguments
        switch self {
            case let .actionsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .allActions(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAllActions(value)
                })
            case let .actionItem(_, _, events, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .right, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.toggleAction(events)
                })
            case let .adminsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .allAdmins(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAllAdmins(value)
                })
            case let .adminPeerItem(_, strings, dateTimeFormat, nameDisplayOrder, _, participant, checked):
                let peerText: String
                switch participant.participant {
                    case .creator:
                        peerText = strings.Channel_Management_LabelOwner
                    case .member:
                        peerText = strings.ChatAdmins_AdminLabel.capitalized
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: EnginePeer(participant.peer), presence: nil, text: .text(peerText, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: ItemListPeerItemSwitch(value: checked, style: .check), enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.toggleAdmin(participant.peer.id)
                }, setPeerIdWithRevealedOptions: { _, _ in
                }, removePeer: { _ in })
        }
    }
}

private struct ChatRecentActionsFilterControllerState: Equatable {
    let events: AdminLogEventsFlags
    let adminPeerIds: [PeerId]?
    
    init(events: AdminLogEventsFlags, adminPeerIds: [PeerId]?) {
        self.events = events
        self.adminPeerIds = adminPeerIds
    }
    
    static func ==(lhs: ChatRecentActionsFilterControllerState, rhs: ChatRecentActionsFilterControllerState) -> Bool {
        if lhs.events != rhs.events {
            return false
        }
        if let lhsAdminPeerIds = lhs.adminPeerIds, let rhsAdminPeerIds = rhs.adminPeerIds {
            if lhsAdminPeerIds != rhsAdminPeerIds {
                return false
            }
        } else if (lhs.adminPeerIds != nil) != (rhs.adminPeerIds != nil) {
            return false
        }
        
        return true
    }
    
    func withUpdatedEvents(_ events: AdminLogEventsFlags) -> ChatRecentActionsFilterControllerState {
        return ChatRecentActionsFilterControllerState(events: events, adminPeerIds: self.adminPeerIds)
    }
    
    func withUpdatedAdminPeerIds(_ adminPeerIds: [PeerId]?) -> ChatRecentActionsFilterControllerState {
        return ChatRecentActionsFilterControllerState(events: self.events, adminPeerIds: adminPeerIds)
    }
}

private func channelRecentActionsFilterControllerEntries(presentationData: PresentationData, accountPeerId: PeerId, peer: Peer, state: ChatRecentActionsFilterControllerState, participants: [RenderedChannelParticipant]?) -> [ChatRecentActionsFilterEntry] {
    var isGroup = true
    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
        isGroup = false
    }
    
    var entries: [ChatRecentActionsFilterEntry] = []
    
    let order: [([AdminLogEventsFlags], String)]
    if isGroup {
        order = [
            ([.ban, .unban, .kick, .unkick], presentationData.strings.Channel_AdminLogFilter_EventsRestrictions),
            ([.promote, .demote], presentationData.strings.Channel_AdminLogFilter_EventsAdmins),
            ([.invite, .join], presentationData.strings.Channel_AdminLogFilter_EventsNewMembers),
            ([.info, .settings], isGroup ? presentationData.strings.Channel_AdminLogFilter_EventsInfo : presentationData.strings.Channel_AdminLogFilter_ChannelEventsInfo),
            ([.invites], presentationData.strings.Channel_AdminLogFilter_EventsInviteLinks),
            ([.deleteMessages], presentationData.strings.Channel_AdminLogFilter_EventsDeletedMessages),
            ([.editMessages], presentationData.strings.Channel_AdminLogFilter_EventsEditedMessages),
            ([.pinnedMessages], presentationData.strings.Channel_AdminLogFilter_EventsPinned),
            ([.leave], presentationData.strings.Channel_AdminLogFilter_EventsLeaving),
            ([.calls], presentationData.strings.Channel_AdminLogFilter_EventsCalls)
        ]
    } else {
        order = [
            ([.promote, .demote], presentationData.strings.Channel_AdminLogFilter_EventsAdmins),
            ([.invite, .join], presentationData.strings.Channel_AdminLogFilter_EventsNewMembers),
            ([.info, .settings], isGroup ? presentationData.strings.Channel_AdminLogFilter_EventsInfo : presentationData.strings.Channel_AdminLogFilter_ChannelEventsInfo),
            ([.invites], presentationData.strings.Channel_AdminLogFilter_EventsInviteLinks),
            ([.deleteMessages], presentationData.strings.Channel_AdminLogFilter_EventsDeletedMessages),
            ([.editMessages], presentationData.strings.Channel_AdminLogFilter_EventsEditedMessages),
            ([.pinnedMessages], presentationData.strings.Channel_AdminLogFilter_EventsPinned),
            ([.leave], presentationData.strings.Channel_AdminLogFilter_EventsLeaving),
            ([.calls], presentationData.strings.Channel_AdminLogFilter_EventsLiveStreams)
        ]
    }
    
    var allTypesSelected = true
    outer: for (events, _) in order {
        for event in events {
            if !state.events.contains(event) {
                allTypesSelected = false
                break outer
            }
        }
    }
    
    entries.append(.actionsTitle(presentationData.theme, presentationData.strings.Channel_AdminLogFilter_EventsTitle))
    entries.append(.allActions(presentationData.theme, presentationData.strings.Channel_AdminLogFilter_EventsAll, allTypesSelected))
    
    var index: Int32 = 0
    for (events, text) in order {
        var eventsSelected = true
        inner: for event in events {
            if !state.events.contains(event) {
                eventsSelected = false
                break inner
            }
        }
        entries.append(.actionItem(presentationData.theme, index, events, text, eventsSelected))
        index += 1
    }
    
    if let participants = participants {
        var allAdminsSelected = true
        if let adminPeerIds = state.adminPeerIds {
            for participant in participants {
                if !adminPeerIds.contains(participant.peer.id) {
                    allAdminsSelected = false
                    break
                }
            }
        } else {
            allAdminsSelected = true
        }
        
        entries.append(.adminsTitle(presentationData.theme, presentationData.strings.Channel_AdminLogFilter_AdminsTitle))
        entries.append(.allAdmins(presentationData.theme, presentationData.strings.Channel_AdminLogFilter_AdminsAll, allAdminsSelected))
        
        var index: Int32 = 0
        for participant in participants {
            var adminSelected = true
            if let adminPeerIds = state.adminPeerIds {
                if !adminPeerIds.contains(participant.peer.id) {
                    adminSelected = false
                }
            } else {
                adminSelected = true
            }
            entries.append(.adminPeerItem(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, index, participant, adminSelected))
            index += 1
        }
    }
    
    return entries
}

public func channelRecentActionsFilterController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: Peer, events: AdminLogEventsFlags, adminPeerIds: [PeerId]?, apply: @escaping (_ events: AdminLogEventsFlags, _ adminPeerIds: [PeerId]?) -> Void) -> ViewController {
    let statePromise = ValuePromise(ChatRecentActionsFilterControllerState(events: events, adminPeerIds: adminPeerIds), ignoreRepeated: true)
    let stateValue = Atomic(value: ChatRecentActionsFilterControllerState(events: events, adminPeerIds: adminPeerIds))
    let updateState: ((ChatRecentActionsFilterControllerState) -> ChatRecentActionsFilterControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    
    let adminsPromise = Promise<[RenderedChannelParticipant]?>(nil)
        
    let actionsDisposable = DisposableSet()
    
    let arguments = ChatRecentActionsFilterControllerArguments(context: context, toggleAllActions: { value in
        updateState { current in
            if value {
                return current.withUpdatedEvents(.all)
            } else {
                return current.withUpdatedEvents([])
            }
        }
    }, toggleAction: { events in
        if let first = events.first {
            updateState { current in
                var updatedEvents = current.events
                if updatedEvents.contains(first) {
                    for event in events {
                        updatedEvents.remove(event)
                    }
                } else {
                    for event in events {
                        updatedEvents.insert(event)
                    }
                }
                return current.withUpdatedEvents(updatedEvents)
            }
        }
    }, toggleAllAdmins: { value in
        let _ = (adminsPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { admins in
            if let _ = admins {
                updateState { current in
                    if value {
                        return current.withUpdatedAdminPeerIds(nil)
                    } else {
                        return current.withUpdatedAdminPeerIds([])
                    }
                }
            }
        })
    }, toggleAdmin: { adminId in
        let _ = (adminsPromise.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { admins in
                if let admins = admins {
                    updateState { current in
                        if let adminPeerIds = current.adminPeerIds, let index = adminPeerIds.firstIndex(of: adminId) {
                            var updatedAdminPeerIds = adminPeerIds
                            updatedAdminPeerIds.remove(at: index)
                            return current.withUpdatedAdminPeerIds(updatedAdminPeerIds)
                        } else {
                            var updatedAdminPeerIds = current.adminPeerIds ?? admins.map { $0.peer.id }
                            if updatedAdminPeerIds.contains(adminId), let index = updatedAdminPeerIds.firstIndex(of: adminId) {
                                updatedAdminPeerIds.remove(at: index)
                            } else {
                                updatedAdminPeerIds.append(adminId)
                            }
                            return current.withUpdatedAdminPeerIds(updatedAdminPeerIds)
                        }
                    }
                }
            })
    })
    
    adminsPromise.set(.single(nil))
    
    let (membersDisposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peer.id) { membersState in
        if case .loading = membersState.loadingState, membersState.list.isEmpty {
            adminsPromise.set(.single(nil))
        } else {
            adminsPromise.set(.single(membersState.list))
        }
    }
    actionsDisposable.add(membersDisposable)
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(presentationData, statePromise.get(), adminsPromise.get() |> deliverOnMainQueue)
    |> deliverOnMainQueue
    |> map { presentationData, state, admins -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let doneEnabled = !state.events.isEmpty
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: doneEnabled, action: {
            var resultState: ChatRecentActionsFilterControllerState?
            updateState { current in
                resultState = current
                return current
            }
            if let resultState = resultState {
                apply(resultState.events, resultState.adminPeerIds)
            }
            dismissImpl?()
        })
        
        var sortedAdmins: [RenderedChannelParticipant]?
        if let admins = admins {
            sortedAdmins = admins.filter { $0.peer.id == context.account.peerId } + admins.filter({ $0.peer.id != context.account.peerId })
        } else {
            sortedAdmins = nil
        }
        
        let previous = previousPeers
        previousPeers = sortedAdmins
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChatAdmins_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelRecentActionsFilterControllerEntries(presentationData: presentationData, accountPeerId: context.account.peerId, peer: peer, state: state, participants: sortedAdmins), style: .blocks, animateChanges: previous != nil && admins != nil && previous!.count >= sortedAdmins!.count)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}

