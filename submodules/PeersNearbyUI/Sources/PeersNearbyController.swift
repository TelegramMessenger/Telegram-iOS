import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import MapKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import DeviceLocationManager
import AccountContext
import AlertUI
import PresentationDataUtils
import ItemListPeerItem
import TelegramPermissionsUI
import ItemListPeerActionItem
import Geocoding
import AppBundle

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
    let openCreateGroup: (Double, Double, String?) -> Void
    
    init(context: AccountContext, openChat: @escaping (Peer) -> Void, openCreateGroup: @escaping (Double, Double, String?) -> Void) {
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
   
    case usersHeader(PresentationTheme, String, Bool)
    case empty(PresentationTheme, String)
    case user(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    
    case groupsHeader(PresentationTheme, String, Bool)
    case createGroup(PresentationTheme, String, Double?, Double?, String?)
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
            case let .usersHeader(lhsTheme, lhsText, lhsLoading):
                if case let .usersHeader(rhsTheme, rhsText, rhsLoading) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsLoading == rhsLoading {
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
            case let .groupsHeader(lhsTheme, lhsText, lhsLoading):
                if case let .groupsHeader(rhsTheme, rhsText, rhsLoading) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsLoading == rhsLoading {
                    return true
                } else {
                    return false
                }
            case let .createGroup(lhsTheme, lhsText, lhsLatitude, lhsLongitude, lhsAddress):
                if case let .createGroup(rhsTheme, rhsText, rhsLatitude, rhsLongitude, rhsAddress) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsLatitude == rhsLatitude && lhsLongitude == rhsLongitude && lhsAddress == rhsAddress {
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PeersNearbyControllerArguments
        switch self {
            case let .header(theme, text):
                return PeersNearbyHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .usersHeader(theme, text, loading):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, activityIndicator: loading ? .left : .none, sectionId: self.section)
            case let .empty(theme, text):
                return ItemListPlaceholderItem(theme: theme, text: text, sectionId: self.section, style: .blocks)
            case let .user(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer.peer.0, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: .text(strings.Map_DistanceAway(stringForDistance(peer.distance)).0), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer.0)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopGroupInset: false, tag: nil)
            case let .groupsHeader(theme, text, loading):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, activityIndicator: loading ? .left : .none, sectionId: self.section)
            case let .createGroup(theme, title, latitude, longitude, address):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.createGroupIcon(theme), title: title, alwaysPlain: false, sectionId: self.section, editing: false, action: {
                    if let latitude = latitude, let longitude = longitude {
                        arguments.openCreateGroup(latitude, longitude, address)
                    }
                })
            case let .group(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                var text: ItemListPeerItemText
                if let cachedData = peer.peer.1 as? CachedChannelData, let memberCount = cachedData.participantsSummary.memberCount {
                    text = .text("\(strings.Map_DistanceAway(stringForDistance(peer.distance)).0), \(memberCount > 0 ? strings.Conversation_StatusMembers(memberCount) : strings.PeopleNearby_NoMembers)")
                } else {
                    text = .text(strings.Map_DistanceAway(stringForDistance(peer.distance)).0)
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer.peer.0, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: text, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer.0)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopGroupInset: false, tag: nil)
            case let .channelsHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .channel(_, theme, strings, dateTimeFormat, nameDisplayOrder, peer):
                var text: ItemListPeerItemText
                if let cachedData = peer.peer.1 as? CachedChannelData, let memberCount = cachedData.participantsSummary.memberCount {
                    text = .text("\(strings.Map_DistanceAway(stringForDistance(peer.distance)).0), \(strings.Conversation_StatusSubscribers(memberCount))")
                } else {
                    text = .text(strings.Map_DistanceAway(stringForDistance(peer.distance)).0)
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer.peer.0, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: text, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer.0)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, hasTopGroupInset: false, tag: nil)
        }
    }
}

private struct PeersNearbyData: Equatable {
    let latitude: Double
    let longitude: Double
    let address: String?
    let users: [PeerNearbyEntry]
    let groups: [PeerNearbyEntry]
    let channels: [PeerNearbyEntry]
    
    init(latitude: Double, longitude: Double, address: String?, users: [PeerNearbyEntry], groups: [PeerNearbyEntry], channels: [PeerNearbyEntry]) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.users = users
        self.groups = groups
        self.channels = channels
    }
    
    static func ==(lhs: PeersNearbyData, rhs: PeersNearbyData) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && lhs.address == rhs.address && arePeerNearbyArraysEqual(lhs.users, rhs.users) && arePeerNearbyArraysEqual(lhs.groups, rhs.groups) && arePeerNearbyArraysEqual(lhs.channels, rhs.channels)
    }
}

private func peersNearbyControllerEntries(data: PeersNearbyData?, presentationData: PresentationData, displayLoading: Bool) -> [PeersNearbyEntry] {
    var entries: [PeersNearbyEntry] = []
    
    entries.append(.header(presentationData.theme, presentationData.strings.PeopleNearby_Description))
    entries.append(.usersHeader(presentationData.theme, presentationData.strings.PeopleNearby_Users.uppercased(), displayLoading && data == nil))
    if let data = data, !data.users.isEmpty {
        var i: Int32 = 0
        for user in data.users {
            entries.append(.user(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, user))
            i += 1
        }
    } else {
        entries.append(.empty(presentationData.theme, presentationData.strings.PeopleNearby_UsersEmpty))
    }
    
    entries.append(.groupsHeader(presentationData.theme, presentationData.strings.PeopleNearby_Groups.uppercased(), displayLoading && data == nil))
    entries.append(.createGroup(presentationData.theme, presentationData.strings.PeopleNearby_CreateGroup, data?.latitude, data?.longitude, data?.address))
    if let data = data, !data.groups.isEmpty {
        var i: Int32 = 0
        for group in data.groups {
            entries.append(.group(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, group))
            i += 1
        }
    }

    if let data = data, !data.channels.isEmpty {
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
    var replaceAllButRootControllerImpl: ((ViewController, Bool) -> Void)?
    var replaceTopControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var navigateToChatImpl: ((Peer) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let checkCreationAvailabilityDisposable = MetaDisposable()
    actionsDisposable.add(checkCreationAvailabilityDisposable)
    
    let dataPromise = Promise<PeersNearbyData?>(nil)
    let addressPromise = Promise<String?>(nil)
    
    let arguments = PeersNearbyControllerArguments(context: context, openChat: { peer in
        navigateToChatImpl?(peer)
    }, openCreateGroup: { latitude, longitude, address in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        var cancelImpl: (() -> Void)?
        let progressSignal = Signal<Never, NoError> { subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                cancelImpl?()
            }))
            presentControllerImpl?(controller, nil)
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.5, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        cancelImpl = {
            checkCreationAvailabilityDisposable.set(nil)
        }
        checkCreationAvailabilityDisposable.set((checkPublicChannelCreationAvailability(account: context.account, location: true)
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(next: { available in
            if available {
                let controller = PermissionController(context: context, splashScreen: true)
                controller.setState(.custom(icon: PermissionControllerCustomIcon(light: UIImage(bundleImageName: "Location/LocalGroupLightIcon"), dark: UIImage(bundleImageName: "Location/LocalGroupDarkIcon")), title: presentationData.strings.LocalGroup_Title, subtitle: address, text: presentationData.strings.LocalGroup_Text, buttonTitle: presentationData.strings.LocalGroup_ButtonTitle, footerText: presentationData.strings.LocalGroup_IrrelevantWarning), animated: false)
                controller.proceed = { result in
                    replaceTopControllerImpl?(context.sharedContext.makeCreateGroupController(context: context, peerIds: [], initialTitle: nil, mode: .locatedGroup(latitude: latitude, longitude: longitude, address: address), completion: nil))
                }
                pushControllerImpl?(controller)
            } else {
                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.CreateGroup_ErrorLocatedGroupsTooMuch, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        }))
    })
    
    let dataSignal: Signal<PeersNearbyData?, NoError> = currentLocationManagerCoordinate(manager: context.sharedContext.locationManager!, timeout: 5.0)
    |> mapToSignal { coordinate -> Signal<PeersNearbyData?, NoError> in
        guard let coordinate = coordinate else {
            return .single(nil)
        }
        
        return Signal { subscriber in
            let peersNearbyContext = PeersNearbyContext(network: context.account.network, accountStateManager: context.account.stateManager, coordinate: (latitude: coordinate.latitude, longitude: coordinate.longitude))
            
            let peersNearby: Signal<PeersNearbyData?, NoError> = combineLatest(peersNearbyContext.get(), addressPromise.get())
            |> mapToSignal { peersNearby, address -> Signal<([PeerNearby]?, String?), NoError> in
                if let address = address {
                    return .single((peersNearby, address))
                } else {
                    return reverseGeocodeLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    |> map { placemark in
                        return (peersNearby, placemark?.fullAddress)
                    }
                }
            }
            |> mapToSignal { peersNearby, address -> Signal<PeersNearbyData?, NoError> in
                guard let peersNearby = peersNearby else {
                    return .single(nil)
                }
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
                    return PeersNearbyData(latitude: coordinate.latitude, longitude: coordinate.longitude, address: address, users: users, groups: groups, channels: [])
                }
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
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    let previousData = Atomic<PeersNearbyData?>(value: nil)
    let displayLoading: Signal<Bool, NoError> = .single(false)
    |> then(
        .single(true)
        |> delay(1.0, queue: Queue.mainQueue())
    )
    
    let signal = combineLatest(context.sharedContext.presentationData, dataPromise.get(), displayLoading)
    |> deliverOnMainQueue
    |> map { presentationData, data, displayLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        
        var crossfade = false
        if (data?.users.isEmpty ?? true) != (previous?.users.isEmpty ?? true) {
            crossfade = true
        }
        if (data?.groups.isEmpty ?? true) != (previous?.groups.isEmpty ?? true) {
            crossfade = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PeopleNearby_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: peersNearbyControllerEntries(data: data, presentationData: presentationData, displayLoading: displayLoading), style: .blocks, emptyStateItem: nil, crossfadeState: crossfade, animateChanges: !crossfade)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    navigateToChatImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer.id), keepStack: .always, purposefulAction: { [weak navigationController] in
                if let navigationController = navigationController, let chatController = navigationController.viewControllers.last as? ChatController {
                    replaceAllButRootControllerImpl?(chatController, false)
                }
            }))
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c, animated: true)
        }
    }
    replaceAllButRootControllerImpl = { [weak controller] c, a in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.replaceAllButRootController(c, animated: a)
        }
    }
    replaceTopControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.replaceTopController(c, animated: true)
        }
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    
    return controller
}
