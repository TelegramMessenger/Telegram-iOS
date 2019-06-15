import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import MapKit
import TelegramPresentationData
import TelegramUIPreferences

private struct PeerNearbyEntry {
    let peer: Peer
    let expires: Int32
    let distance: Int32
}

private func arePeersNearbyEqual(_ lhs: PeerNearbyEntry?, _ rhs: PeerNearbyEntry?) -> Bool {
    if let lhs = lhs, let rhs = rhs {
        return lhs.peer.isEqual(rhs.peer) && lhs.expires == rhs.expires && lhs.distance == rhs.distance
    } else {
        return (lhs != nil) == (rhs != nil)
    }
}

private func arePeerNearbyArraysEqual(_ lhs: [PeerNearbyEntry], _ rhs: [PeerNearbyEntry]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if !lhs[i].peer.isEqual(rhs[i].peer) || lhs[i].expires != rhs[i].expires || lhs[i].distance != rhs[i].distance {
            return false
        }
    }
    return true
}

private final class PeopleNearbyControllerArguments {
    let context: AccountContext
    let openChat: (Peer) -> Void
    let openCreateGroup: () -> Void
    
    init(context: AccountContext, openChat: @escaping (Peer) -> Void, openCreateGroup: @escaping () -> Void) {
        self.context = context
        self.openChat = openChat
        self.openCreateGroup = openCreateGroup
    }
}

private enum PeopleNearbySection: Int32 {
    case header
    case users
    case groups
    case channels
}

private enum PeopleNearbyEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
   
    case usersHeader(PresentationTheme, String)
    case empty(PresentationTheme, String)
    case user(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    
    case groupsHeader(PresentationTheme, String)
    case createGroup(PresentationTheme, String)
    case group(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    
    case channelsHeader(PresentationTheme, String)
    case channel(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return PeopleNearbySection.header.rawValue
            case .usersHeader, .empty, .user:
                return PeopleNearbySection.users.rawValue
            case .groupsHeader, .createGroup, .group:
                return PeopleNearbySection.groups.rawValue
            case .channelsHeader, .channel:
                return PeopleNearbySection.channels.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .header:
                return 0
            case .usersHeader:
                return 1
            case .empty:
                return 2
            case let .user(index, _, _, _, _, _):
                return 3 + index
            case .groupsHeader:
                return 1000
            case .createGroup:
                return 1001
            case let .group(index, _, _, _, _, _):
                return 1002 + index
            case .channelsHeader:
                return 2000
            case let .channel(index, _, _, _, _, _):
                return 2001 + index
        }
    }
    
    static func ==(lhs: PeopleNearbyEntry, rhs: PeopleNearbyEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsText):
                if case let .header(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .usersHeader(lhsTheme, lhsText):
                if case let .usersHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .empty(lhsTheme, lhsText):
                if case let .empty(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .user(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsDisplayOrder, lhsPeer):
                if case let .user(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsDisplayOrder, rhsPeer) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayOrder == rhsDisplayOrder, arePeersNearbyEqual(lhsPeer, rhsPeer) {
                    return true
                } else {
                    return false
                }
            case let .groupsHeader(lhsTheme, lhsText):
                if case let .groupsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .createGroup(lhsTheme, lhsText):
                if case let .createGroup(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .group(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsDisplayOrder, lhsPeer):
                if case let .group(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsDisplayOrder, rhsPeer) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayOrder == rhsDisplayOrder, arePeersNearbyEqual(lhsPeer, rhsPeer) {
                    return true
                } else {
                    return false
                }
            case let .channelsHeader(lhsTheme, lhsText):
                if case let .channelsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .channel(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsDisplayOrder, lhsPeer):
                if case let .channel(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsDisplayOrder, rhsPeer) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayOrder == rhsDisplayOrder, arePeersNearbyEqual(lhsPeer, rhsPeer) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PeopleNearbyEntry, rhs: PeopleNearbyEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: PeopleNearbyControllerArguments) -> ListViewItem {
        switch self {
            case let .header(theme, text):
                return PeopleNearbyHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .usersHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .empty(theme, text):
                return ItemListPlaceholderItem(theme: theme, text: text, sectionId: self.section, style: .blocks)
            case let .user(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                func distance(_ distance: Int32) -> String {
                    var distance = max(1, distance)
                    let formatter = MKDistanceFormatter()
                    formatter.unitStyle = .abbreviated
                    return formatter.string(fromDistance: Double(distance))
                }
                
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.context.account, peer: peer.peer, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: .text(distance(peer.distance)), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopStripe: false, hasTopGroupInset: false, tag: nil)
            case let .groupsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .createGroup(theme, title):
                return ContactListActionItem(theme: theme, title: title, icon: .generic(UIImage(bundleImageName: "Contact List/CreateGroupActionIcon")!), header: nil, action: {
                    arguments.openCreateGroup()
                })
            case let .group(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.context.account, peer: peer.peer, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: .text("10 members"), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopStripe: false, hasTopGroupInset: false, tag: nil)
            case let .channelsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .channel(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.context.account, peer: peer.peer, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: .text("10 members"), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopStripe: false, hasTopGroupInset: false, tag: nil)
        }
    }
}

private struct PeopleNearbyControllerState: Equatable {
    static func ==(lhs: PeopleNearbyControllerState, rhs: PeopleNearbyControllerState) -> Bool {
        return true
    }
}

private struct PeopleNearbyData: Equatable {
    let users: [PeerNearbyEntry]
    let groups: [PeerNearbyEntry]
    let channels: [PeerNearbyEntry]
    
    init(users: [PeerNearbyEntry], groups: [PeerNearbyEntry], channels: [PeerNearbyEntry]) {
        self.users = users
        self.groups = groups
        self.channels = channels
    }
    
    static func ==(lhs: PeopleNearbyData, rhs: PeopleNearbyData) -> Bool {
        return arePeerNearbyArraysEqual(lhs.users, rhs.users) && arePeerNearbyArraysEqual(lhs.groups, rhs.groups) && arePeerNearbyArraysEqual(lhs.channels, rhs.channels)
    }
}

private func peopleNearbyControllerEntries(state: PeopleNearbyControllerState, data: PeopleNearbyData?, presentationData: PresentationData) -> [PeopleNearbyEntry] {
    var entries: [PeopleNearbyEntry] = []
    
    entries.append(.header(presentationData.theme, presentationData.strings.PeopleNearby_Description))
    entries.append(.usersHeader(presentationData.theme, presentationData.strings.PeopleNearby_Users.uppercased()))
    if let data = data, !data.users.isEmpty {
        var i: Int32 = 0
        for user in data.users {
            entries.append(.user(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, user))
            i += 1
        }
    } else {
        entries.append(.empty(presentationData.theme, presentationData.strings.PeopleNearby_UsersEmpty))
    }
    
//    entries.append(.groupsHeader(presentationData.theme, presentationData.strings.PeopleNearby_Groups.uppercased()))
//    entries.append(.createGroup(presentationData.theme, presentationData.strings.PeopleNearby_CreateGroup))
//    if let data = data, !data.groups.isEmpty {
//        var i: Int32 = 0
//        for group in data.groups {
//            entries.append(.group(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, group))
//            i += 1
//        }
//    }
//    
//    if let data = data, !data.channels.isEmpty {
//        var i: Int32 = 0
//        for channel in data.channels {
//            entries.append(.channel(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, channel))
//            i += 1
//        }
//    }
    
    return entries
}

public func peopleNearbyController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(PeopleNearbyControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PeopleNearbyControllerState())
    let updateState: ((PeopleNearbyControllerState) -> PeopleNearbyControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var navigateToChatImpl: ((Peer) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let dataPromise = Promise<PeopleNearbyData?>(nil)
    
    let arguments = PeopleNearbyControllerArguments(context: context, openChat: { peer in
        navigateToChatImpl?(peer)
    }, openCreateGroup: {
        
    })
    
    let dataSignal: Signal<PeopleNearbyData?, NoError> = currentLocationManagerCoordinate(manager: context.sharedContext.locationManager!, timeout: 5.0)
    |> mapToSignal { coordinate -> Signal<PeopleNearbyData?, NoError> in
        guard let coordinate = coordinate else {
            return .single(nil)
        }
        let poll = peersNearby(network: context.account.network, accountStateManager: context.account.stateManager, coordinate: (latitude: coordinate.latitude, longitude: coordinate.longitude), radius: 100)
        |> mapToSignal { peersNearby -> Signal<PeopleNearbyData?, NoError> in
            return context.account.postbox.transaction { transaction -> PeopleNearbyData? in
                var result: [PeerNearbyEntry] = []
                for peerNearby in peersNearby {
                    if peerNearby.id != context.account.peerId, let peer = transaction.getPeer(peerNearby.id) {
                        result.append(PeerNearbyEntry(peer: peer, expires: peerNearby.expires, distance: peerNearby.distance))
                    }
                }
                return PeopleNearbyData(users: result, groups: [], channels: [])
            }
        }
        return (poll |> then(.complete() |> suspendAwareDelay(25.0, queue: Queue.concurrentDefaultQueue()))) |> restart
    }

    dataPromise.set(dataSignal)
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), dataPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state, data -> (ItemListControllerState, (ItemListNodeState<PeopleNearbyEntry>, PeopleNearbyEntry.ItemGenerationArguments)) in
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.PeopleNearby_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(entries: peopleNearbyControllerEntries(state: state, data: data, presentationData: presentationData), style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: true, userInteractionEnabled: true)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    navigateToChatImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigateToChatController(navigationController: navigationController, context: context, chatLocation: .peer(peer.id), keepStack: .always)
        }
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    
    return controller
}
