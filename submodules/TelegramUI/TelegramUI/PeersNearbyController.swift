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
    let peer: (Peer, CachedPeerData?)
    let expires: Int32
    let distance: Int32
}

private func arePeersNearbyEqual(_ lhs: PeerNearbyEntry?, _ rhs: PeerNearbyEntry?) -> Bool {
    if let lhs = lhs, let rhs = rhs {
        return lhs.peer.0.isEqual(rhs.peer.0) && lhs.expires == rhs.expires && lhs.distance == rhs.distance
    } else {
        return (lhs != nil) == (rhs != nil)
    }
}

private func arePeerNearbyArraysEqual(_ lhs: [PeerNearbyEntry], _ rhs: [PeerNearbyEntry]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if !lhs[i].peer.0.isEqual(rhs[i].peer.0) || lhs[i].expires != rhs[i].expires || lhs[i].distance != rhs[i].distance {
            return false
        }
    }
    return true
}

private final class PeersNearbyControllerArguments {
    let context: AccountContext
    let openChat: (Peer) -> Void
    let openCreateGroup: (Double, Double) -> Void
    
    init(context: AccountContext, openChat: @escaping (Peer) -> Void, openCreateGroup: @escaping (Double, Double) -> Void) {
        self.context = context
        self.openChat = openChat
        self.openCreateGroup = openCreateGroup
    }
}

private enum PeersNearbySection: Int32 {
    case header
    case users
    case groups
    case channels
}

private enum PeersNearbyEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
   
    case usersHeader(PresentationTheme, String)
    case empty(PresentationTheme, String, Bool)
    case user(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    
    case groupsHeader(PresentationTheme, String)
    case createGroup(PresentationTheme, String, Double?, Double?)
    case group(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    
    case channelsHeader(PresentationTheme, String)
    case channel(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return PeersNearbySection.header.rawValue
            case .usersHeader, .empty, .user:
                return PeersNearbySection.users.rawValue
            case .groupsHeader, .createGroup, .group:
                return PeersNearbySection.groups.rawValue
            case .channelsHeader, .channel:
                return PeersNearbySection.channels.rawValue
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
    
    static func ==(lhs: PeersNearbyEntry, rhs: PeersNearbyEntry) -> Bool {
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
            case let .empty(lhsTheme, lhsText, lhsLoading):
                if case let .empty(rhsTheme, rhsText, rhsLoading) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsLoading == rhsLoading {
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
            case let .createGroup(lhsTheme, lhsText, lhsLatitude, lhsLongitude):
                if case let .createGroup(rhsTheme, rhsText, rhsLatitude, rhsLongitude) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsLatitude == rhsLatitude && lhsLongitude == rhsLongitude {
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
    
    static func <(lhs: PeersNearbyEntry, rhs: PeersNearbyEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    private func stringForDistance(_ distance: Int32) -> String {
        let distance = max(1, distance)
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        var result = formatter.string(fromDistance: Double(distance))
        if result.hasPrefix("0 ") {
            result = result.replacingOccurrences(of: "0 ", with: "1 ")
        }
        return result
    }
    
    func item(_ arguments: PeersNearbyControllerArguments) -> ListViewItem {
        switch self {
            case let .header(theme, text):
                return PeersNearbyHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .usersHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .empty(theme, text, loading):
                return ItemListPlaceholderItem(theme: theme, text: text, sectionId: self.section, style: .blocks)
            case let .user(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.context.account, peer: peer.peer.0, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: .text(strings.Map_DistanceAway(stringForDistance(peer.distance)).0), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer.0)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopGroupInset: false, tag: nil)
            case let .groupsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .createGroup(theme, title, latitude, longitude):
                return ItemListPeerActionItem(theme: theme, icon: PresentationResourcesItemList.createGroupIcon(theme), title: title, alwaysPlain: false, sectionId: self.section, editing: false, action: {
                    if let latitude = latitude, let longitude = longitude {
                        arguments.openCreateGroup(latitude, longitude)
                    }
                })
            case let .group(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                var text: ItemListPeerItemText
                if let cachedData = peer.peer.1 as? CachedChannelData, let memberCount = cachedData.participantsSummary.memberCount {
                    text = .text("\(strings.Map_DistanceAway(stringForDistance(peer.distance)).0), \(strings.Conversation_StatusMembers(memberCount))")
                } else {
                    text = .text(strings.Map_DistanceAway(stringForDistance(peer.distance)).0)
                }
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.context.account, peer: peer.peer.0, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: text, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer.0)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopGroupInset: false, tag: nil)
            case let .channelsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .channel(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                var text: ItemListPeerItemText
                if let cachedData = peer.peer.1 as? CachedChannelData, let memberCount = cachedData.participantsSummary.memberCount {
                    text = .text("\(strings.Map_DistanceAway(stringForDistance(peer.distance)).0), \(strings.Conversation_StatusSubscribers(memberCount))")
                } else {
                    text = .text(strings.Map_DistanceAway(stringForDistance(peer.distance)).0)
                }
                return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, account: arguments.context.account, peer: peer.peer.0, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: text, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer.0)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopGroupInset: false, tag: nil)
        }
    }
}

private struct PeersNearbyData: Equatable {
    let latitude: Double
    let longitude: Double
    let users: [PeerNearbyEntry]
    let groups: [PeerNearbyEntry]
    let channels: [PeerNearbyEntry]
    
    init(latitude: Double, longitude: Double, users: [PeerNearbyEntry], groups: [PeerNearbyEntry], channels: [PeerNearbyEntry]) {
        self.latitude = latitude
        self.longitude = longitude
        self.users = users
        self.groups = groups
        self.channels = channels
    }
    
    static func ==(lhs: PeersNearbyData, rhs: PeersNearbyData) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && arePeerNearbyArraysEqual(lhs.users, rhs.users) && arePeerNearbyArraysEqual(lhs.groups, rhs.groups) && arePeerNearbyArraysEqual(lhs.channels, rhs.channels)
    }
}

private func peersNearbyControllerEntries(data: PeersNearbyData?, presentationData: PresentationData) -> [PeersNearbyEntry] {
    var entries: [PeersNearbyEntry] = []
    
    entries.append(.header(presentationData.theme, presentationData.strings.PeopleNearby_Description))
    entries.append(.usersHeader(presentationData.theme, presentationData.strings.PeopleNearby_Users.uppercased()))
    if let data = data, !data.users.isEmpty {
        var i: Int32 = 0
        for user in data.users {
            entries.append(.user(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, user))
            i += 1
        }
    } else {
        entries.append(.empty(presentationData.theme, presentationData.strings.PeopleNearby_UsersEmpty, data == nil))
    }
    
    entries.append(.groupsHeader(presentationData.theme, presentationData.strings.PeopleNearby_Groups.uppercased()))
    entries.append(.createGroup(presentationData.theme, presentationData.strings.PeopleNearby_CreateGroup, data?.latitude, data?.longitude))
    if let data = data, !data.groups.isEmpty {
        var i: Int32 = 0
        for group in data.groups {
            entries.append(.group(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, group))
            i += 1
        }
    }

    if let data = data, !data.channels.isEmpty {
        entries.append(.channelsHeader(presentationData.theme, presentationData.strings.PeopleNearby_Channels.uppercased()))
        var i: Int32 = 0
        for channel in data.channels {
            entries.append(.channel(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, channel))
            i += 1
        }
    }
    
    return entries
}

public func peersNearbyController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var replaceTopControllerImpl: ((ViewController, Bool) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var navigateToChatImpl: ((Peer) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let dataPromise = Promise<PeersNearbyData?>(nil)
    
    let arguments = PeersNearbyControllerArguments(context: context, openChat: { peer in
        navigateToChatImpl?(peer)
    }, openCreateGroup: { latitude, longitude in
        let controller = createGroupController(context: context, peerIds: [], type: .locatedGroup(latitude: latitude, longitude: longitude))
        pushControllerImpl?(controller)
    })
    
    let dataSignal: Signal<PeersNearbyData?, Void> = currentLocationManagerCoordinate(manager: context.sharedContext.locationManager!, timeout: 5.0)
    |> introduceError(Void.self)
    |> mapToSignal { coordinate -> Signal<PeersNearbyData?, Void> in
        guard let coordinate = coordinate else {
            return .single(nil)
        }
        
        return Signal { subscriber in
            let peersNearbyContext = PeersNearbyContext(network: context.account.network, accountStateManager: context.account.stateManager, coordinate: (latitude: coordinate.latitude, longitude: coordinate.longitude))
            
            let peersNearby: Signal<PeersNearbyData?, Void> = peersNearbyContext.get()
            |> introduceError(Void.self)
            |> mapToSignal { peersNearby -> Signal<PeersNearbyData?, Void> in
                return context.account.postbox.transaction { transaction -> PeersNearbyData? in
                    var users: [PeerNearbyEntry] = []
                    var groups: [PeerNearbyEntry] = []
                    for peerNearby in peersNearby {
                        if peerNearby.id != context.account.peerId, let peer = transaction.getPeer(peerNearby.id) {
                            if peerNearby.id.namespace == Namespaces.Peer.CloudUser {
                                users.append(PeerNearbyEntry(peer: (peer, nil), expires: peerNearby.expires, distance: peerNearby.distance))
                            } else {
                                let cachedData = transaction.getPeerCachedData(peerId: peerNearby.id) as? CachedChannelData
                                groups.append(PeerNearbyEntry(peer: (peer, cachedData), expires: peerNearby.expires, distance: peerNearby.distance))
                            }
                        }
                    }
                    return PeersNearbyData(latitude: coordinate.latitude, longitude: coordinate.longitude, users: users, groups: groups, channels: [])
                }
                |> introduceError(Void.self)
            }
            
            let disposable = peersNearby.start(next: { data in
                subscriber.putNext(data)
            })
            
            return ActionDisposable {
                disposable.dispose()
                let _ = peersNearbyContext.get()
            }
        }
    }
    
    let errorSignal: Signal<Void, Void> = .single(Void()) |> then( Signal.fail(Void()) |> suspendAwareDelay(25.0, queue: Queue.concurrentDefaultQueue()) )
    let combinedSignal = combineLatest(dataSignal, errorSignal) |> map { data, _ -> PeersNearbyData? in
        return data
    }
    |> restartIfError
    |> `catch` { _ -> Signal<PeersNearbyData?, NoError> in
        return .single(nil)
    }
    dataPromise.set(combinedSignal)

    let signal = combineLatest(context.sharedContext.presentationData, dataPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, data -> (ItemListControllerState, (ItemListNodeState<PeersNearbyEntry>, PeersNearbyEntry.ItemGenerationArguments)) in
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.PeopleNearby_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(entries: peersNearbyControllerEntries(data: data, presentationData: presentationData), style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: true, userInteractionEnabled: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    navigateToChatImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigateToChatController(navigationController: navigationController, context: context, chatLocation: .peer(peer.id), keepStack: .always, purposefulAction: { [weak navigationController] in
                if let navigationController = navigationController, let chatController = navigationController.viewControllers.last as? ChatController {
                    replaceTopControllerImpl?(chatController, false)
                }
            })
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c, animated: true)
        }
    }
    replaceTopControllerImpl = { [weak controller] c, a in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.replaceAllButRootController(c, animated: a)
        }
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    
    return controller
}
