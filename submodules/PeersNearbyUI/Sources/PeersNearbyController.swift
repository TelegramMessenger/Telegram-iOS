import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
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
import ContextUI
import TelegramNotices
import TelegramStringFormatting

private let maxUsersDisplayedLimit: Int32 = 5

private struct PeerNearbyEntry {
    let peer: EnginePeer
    let memberCount: Int32?
    let expires: Int32
    let distance: Int32
}

private func arePeersNearbyEqual(_ lhs: PeerNearbyEntry?, _ rhs: PeerNearbyEntry?) -> Bool {
    if let lhs = lhs, let rhs = rhs {
        return lhs.peer == rhs.peer && lhs.expires == rhs.expires && lhs.distance == rhs.distance
    } else {
        return (lhs != nil) == (rhs != nil)
    }
}

private func arePeerNearbyArraysEqual(_ lhs: [PeerNearbyEntry], _ rhs: [PeerNearbyEntry]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if lhs[i].peer != rhs[i].peer || lhs[i].expires != rhs[i].expires || lhs[i].distance != rhs[i].distance {
            return false
        }
    }
    return true
}

private final class PeersNearbyControllerArguments {
    let context: AccountContext
    let toggleVisibility: (Bool) -> Void
    let openProfile: (EnginePeer, Int32) -> Void
    let openChat: (EnginePeer) -> Void
    let openCreateGroup: (Double, Double, String?) -> Void
    let contextAction: (EnginePeer, ASDisplayNode, ContextGesture?) -> Void
    let expandUsers: () -> Void
    
    init(context: AccountContext, toggleVisibility: @escaping (Bool) -> Void, openProfile: @escaping (EnginePeer, Int32) -> Void, openChat: @escaping (EnginePeer) -> Void, openCreateGroup: @escaping (Double, Double, String?) -> Void, contextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?) -> Void, expandUsers: @escaping () -> Void) {
        self.context = context
        self.toggleVisibility = toggleVisibility
        self.openProfile = openProfile
        self.openChat = openChat
        self.openCreateGroup = openCreateGroup
        self.contextAction = contextAction
        self.expandUsers = expandUsers
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
    case visibility(PresentationTheme, String, Bool)
    case user(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry)
    case expand(PresentationTheme, String)
    
    case groupsHeader(PresentationTheme, String, Bool)
    case createGroup(PresentationTheme, String, Double?, Double?, String?)
    case group(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry, Bool)
    
    case channelsHeader(PresentationTheme, String)
    case channel(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PeerNearbyEntry, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return PeersNearbySection.header.rawValue
            case .usersHeader, .empty, .visibility, .user, .expand:
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
            case .visibility:
                return 3
            case let .user(index, _, _, _, _, _):
                return 4 + index
            case .expand:
                return 1000
            case .groupsHeader:
                return 1001
            case .createGroup:
                return 1002
            case let .group(index, _, _, _, _, _, _):
                return 1003 + index
            case .channelsHeader:
                return 2000
            case let .channel(index, _, _, _, _, _, _):
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
            case let .visibility(lhsTheme, lhsText, lhsStop):
                if case let .visibility(rhsTheme, rhsText, rhsStop) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsStop == rhsStop {
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
            case let .expand(lhsTheme, lhsText):
                if case let .expand(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .group(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsDisplayOrder, lhsPeer, lhsHighlighted):
                if case let .group(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsDisplayOrder, rhsPeer, rhsHighlighted) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayOrder == rhsDisplayOrder, arePeersNearbyEqual(lhsPeer, rhsPeer), lhsHighlighted == rhsHighlighted {
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
            case let .channel(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsDisplayOrder, lhsPeer, lhsHighlighted):
                if case let .channel(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsDisplayOrder, rhsPeer, rhsHighlighted) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayOrder == rhsDisplayOrder, arePeersNearbyEqual(lhsPeer, rhsPeer), lhsHighlighted == rhsHighlighted {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PeersNearbyEntry, rhs: PeersNearbyEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PeersNearbyControllerArguments
        switch self {
            case let .header(theme, text):
                return PeersNearbyHeaderItem(context: arguments.context, theme: theme, text: text, sectionId: self.section)
            case let .usersHeader(_, text, loading):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, activityIndicator: loading ? .left : .none, sectionId: self.section)
            case let .empty(theme, text):
                return ItemListPlaceholderItem(theme: theme, text: text, sectionId: self.section, style: .blocks)
            case let .visibility(theme, title, stop):
                return ItemListPeerActionItem(presentationData: presentationData, icon: stop ? PresentationResourcesItemList.makeInvisibleIcon(theme) : PresentationResourcesItemList.makeVisibleIcon(theme), title: title, alwaysPlain: false, sectionId: self.section, color: stop ? .destructive : .accent, editing: false, action: {
                    arguments.toggleVisibility(!stop)
                })
            case let .user(_, _, strings, dateTimeFormat, nameDisplayOrder, peer):
                var text = strings.Map_DistanceAway(shortStringForDistance(strings: strings, distance: peer.distance)).string
                let isSelfPeer = peer.peer.id == arguments.context.account.peerId
                if isSelfPeer {
                    text = strings.PeopleNearby_VisibleUntil(humanReadableStringForTimestamp(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: peer.expires).string).string
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer.peer, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: .text(text, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: !isSelfPeer, sectionId: self.section, action: {
                    if !isSelfPeer {
                        arguments.openProfile(peer.peer, peer.distance)
                    }
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, contextAction: nil, hasTopGroupInset: false, tag: nil)
            case let .expand(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.expandUsers()
                })
            case let .groupsHeader(_, text, loading):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, activityIndicator: loading ? .left : .none, sectionId: self.section)
            case let .createGroup(theme, title, latitude, longitude, address):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.createGroupIcon(theme), title: title, alwaysPlain: false, sectionId: self.section, editing: false, action: {
                    if let latitude = latitude, let longitude = longitude {
                        arguments.openCreateGroup(latitude, longitude, address)
                    }
                })
            case let .group(_, _, strings, dateTimeFormat, nameDisplayOrder, peer, highlighted):
                var text: ItemListPeerItemText
                if let memberCount = peer.memberCount {
                    text = .text("\(strings.Map_DistanceAway(shortStringForDistance(strings: strings, distance: peer.distance)).string), \(memberCount > 0 ? strings.Conversation_StatusMembers(memberCount) : strings.PeopleNearby_NoMembers)", .secondary)
                } else {
                    text = .text(strings.Map_DistanceAway(shortStringForDistance(strings: strings, distance: peer.distance)).string, .secondary)
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer.peer, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: text, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, highlighted: highlighted, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, contextAction: { node, gesture in
                    arguments.contextAction(peer.peer, node, gesture)
                }, hasTopGroupInset: false, tag: nil)
            case let .channelsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .channel(_, _, strings, dateTimeFormat, nameDisplayOrder, peer, highlighted):
                var text: ItemListPeerItemText
                if let memberCount = peer.memberCount {
                    text = .text("\(strings.Map_DistanceAway(shortStringForDistance(strings: strings, distance: peer.distance)).string), \(strings.Conversation_StatusSubscribers(memberCount))", .secondary)
                } else {
                    text = .text(strings.Map_DistanceAway(shortStringForDistance(strings: strings, distance: peer.distance)).string, .secondary)
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer.peer, aliasHandling: .standard, nameColor: .primary, nameStyle: .distinctBold, presence: nil, text: text, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, highlighted: highlighted, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(peer.peer)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, toggleUpdated: nil, contextAction: { node, gesture in
                    arguments.contextAction(peer.peer, node, gesture)
                }, hasTopGroupInset: false, tag: nil)
        }
    }
}

private struct PeersNearbyData: Equatable {
    let latitude: Double
    let longitude: Double
    let address: String?
    let visible: Bool
    let accountPeerId: EnginePeer.Id
    let users: [PeerNearbyEntry]
    let groups: [PeerNearbyEntry]
    let channels: [PeerNearbyEntry]
    
    init(latitude: Double, longitude: Double, address: String?, visible: Bool, accountPeerId: EnginePeer.Id, users: [PeerNearbyEntry], groups: [PeerNearbyEntry], channels: [PeerNearbyEntry]) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.visible = visible
        self.accountPeerId = accountPeerId
        self.users = users
        self.groups = groups
        self.channels = channels
    }
    
    static func ==(lhs: PeersNearbyData, rhs: PeersNearbyData) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && lhs.address == rhs.address && lhs.visible == rhs.visible && lhs.accountPeerId == rhs.accountPeerId && arePeerNearbyArraysEqual(lhs.users, rhs.users) && arePeerNearbyArraysEqual(lhs.groups, rhs.groups) && arePeerNearbyArraysEqual(lhs.channels, rhs.channels)
    }
}

private func peersNearbyControllerEntries(data: PeersNearbyData?, state: PeersNearbyState, presentationData: PresentationData, displayLoading: Bool, expanded: Bool, chatLocation: ChatLocation?) -> [PeersNearbyEntry] {
    var entries: [PeersNearbyEntry] = []
    
    entries.append(.header(presentationData.theme, presentationData.strings.PeopleNearby_DiscoverDescription))
    entries.append(.usersHeader(presentationData.theme, presentationData.strings.PeopleNearby_Users.uppercased(), displayLoading && data == nil))
    
    let visible = state.visibilityExpires != nil
    entries.append(.visibility(presentationData.theme, visible ? presentationData.strings.PeopleNearby_MakeInvisible : presentationData.strings.PeopleNearby_MakeVisible, visible))
    
    if let data = data, !data.users.isEmpty {
        var index: Int32 = 0
        var users = data.users.filter { $0.peer.id != data.accountPeerId }
        var effectiveExpanded = expanded
        if users.count > maxUsersDisplayedLimit && !expanded {
            users = Array(users.prefix(Int(maxUsersDisplayedLimit)))
        } else {
            effectiveExpanded = true
        }
        
        for user in users {
            entries.append(.user(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, user))
            index += 1
        }
        
        if !effectiveExpanded {
            entries.append(.expand(presentationData.theme, presentationData.strings.PeopleNearby_ShowMorePeople(Int32(data.users.count) - maxUsersDisplayedLimit)))
        }
    }
    
    var highlightedPeerId: EnginePeer.Id?
    if let chatLocation = chatLocation, case let .peer(peerId) = chatLocation {
        highlightedPeerId = peerId
    }
    
    entries.append(.groupsHeader(presentationData.theme, presentationData.strings.PeopleNearby_Groups.uppercased(), displayLoading && data == nil))
    entries.append(.createGroup(presentationData.theme, presentationData.strings.PeopleNearby_CreateGroup, data?.latitude, data?.longitude, data?.address))
    if let data = data, !data.groups.isEmpty {
        var i: Int32 = 0
        for group in data.groups {
            entries.append(.group(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, group, highlightedPeerId == group.peer.id))
            i += 1
        }
    }

    if let data = data, !data.channels.isEmpty {
        var i: Int32 = 0
        for channel in data.channels {
            entries.append(.channel(i, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, channel, highlightedPeerId == channel.peer.id))
            i += 1
        }
    }
    
    return entries
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

private func peerNearbyContextMenuItems(context: AccountContext, peerId: EnginePeer.Id, present: @escaping (ViewController) -> Void) -> Signal<[ContextMenuItem], NoError> {
    return .single([])
}

private class PeersNearbyControllerImpl: ItemListController {
    fileprivate let chatLocation = Promise<ChatLocation?>(nil)
    
    public override func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.isNodeLoaded {
            self.chatLocation.set(.single(data as? ChatLocation))
        }
    }
}

public func peersNearbyController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var replaceTopControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var navigateToProfileImpl: ((EnginePeer, Int32) -> Void)?
    var navigateToChatImpl: ((EnginePeer) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let checkCreationAvailabilityDisposable = MetaDisposable()
    actionsDisposable.add(checkCreationAvailabilityDisposable)
    
    let dataPromise = Promise<PeersNearbyData?>(nil)
    let addressPromise = Promise<String?>(nil)
    let expandedPromise = ValuePromise<Bool>(false)
    
    let chatLocationPromise = Promise<ChatLocation?>(nil)
    
    let coordinatePromise = Promise<CLLocationCoordinate2D?>(nil)
    coordinatePromise.set(.single(nil) |> then(currentLocationManagerCoordinate(manager: context.sharedContext.locationManager!, timeout: 5.0)))
    
    let arguments = PeersNearbyControllerArguments(context: context, toggleVisibility: { visible in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        if visible {
            presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.PeopleNearby_MakeVisibleTitle, text: presentationData.strings.PeopleNearby_MakeVisibleDescription, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                let _ = (coordinatePromise.get()
                |> deliverOnMainQueue).start(next: { coordinate in
                    if let coordinate = coordinate {
                        let _ = context.engine.peersNearby.updatePeersNearbyVisibility(update: .visible(latitude: coordinate.latitude, longitude: coordinate.longitude), background: false).start()
                    }
                })
            })]), nil)
            
            
        } else {
            let _ = context.engine.peersNearby.updatePeersNearbyVisibility(update: .invisible, background: false).start()
        }
    }, openProfile: { peer, distance in
        navigateToProfileImpl?(peer, distance)
    }, openChat: { peer in
        navigateToChatImpl?(peer)
    }, openCreateGroup: { latitude, longitude, address in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        var cancelImpl: (() -> Void)?
        let progressSignal = Signal<Never, NoError> { subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
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
        checkCreationAvailabilityDisposable.set((context.engine.peers.checkPublicChannelCreationAvailability(location: true)
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(next: { available in
            if available {
                let controller = PermissionController(context: context, splashScreen: true)
                controller.navigationPresentation = .modalInLargeLayout
                controller.setState(.custom(icon: .icon(PermissionControllerCustomIcon(light: UIImage(bundleImageName: "Location/LocalGroupLightIcon"), dark: UIImage(bundleImageName: "Location/LocalGroupDarkIcon"))), title: presentationData.strings.LocalGroup_Title, subtitle: address, text: presentationData.strings.LocalGroup_Text, buttonTitle: presentationData.strings.LocalGroup_ButtonTitle, secondaryButtonTitle: nil, footerText: presentationData.strings.LocalGroup_IrrelevantWarning), animated: false)
                controller.proceed = { result in
                    let controller = context.sharedContext.makeCreateGroupController(context: context, peerIds: [], initialTitle: nil, mode: .locatedGroup(latitude: latitude, longitude: longitude, address: address), completion: nil)
                    controller.navigationPresentation = .modalInLargeLayout
                    replaceTopControllerImpl?(controller)
                }
                pushControllerImpl?(controller)
            } else {
                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.CreateGroup_ErrorLocatedGroupsTooMuch, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        }))
    }, contextAction: { peer, node, gesture in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(previewing: true))
        chatController.canReadHistory.set(false)
        let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: peerNearbyContextMenuItems(context: context, peerId: peer.id, present: { c in
            presentControllerImpl?(c, nil)
        }) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
        presentInGlobalOverlayImpl?(contextController)
    }, expandUsers: {
        expandedPromise.set(true)
    })
    
    let dataSignal: Signal<PeersNearbyData?, NoError> = coordinatePromise.get()
    |> mapToSignal { coordinate -> Signal<PeersNearbyData?, NoError> in
        guard let coordinate = coordinate else {
            return .single(nil)
        }
        
        return Signal { subscriber in
            let peersNearbyContext = PeersNearbyContext(network: context.account.network, stateManager: context.account.stateManager, coordinate: (latitude: coordinate.latitude, longitude: coordinate.longitude))
            
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
                let peerIds = peersNearby.map { entry -> EnginePeer.Id in
                    switch entry {
                    case let .peer(id, _, _):
                        return id
                    case .selfPeer:
                        return context.account.peerId
                    }
                }
                return context.engine.data.get(
                    EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)),
                    EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                )
                |> map { peerMap, participantCountMap -> PeersNearbyData? in
                    var users: [PeerNearbyEntry] = []
                    var groups: [PeerNearbyEntry] = []
                    var visible = false
                    for peerNearby in peersNearby {
                        switch peerNearby {
                        case let .peer(id, expires, distance):
                            if let maybePeer = peerMap[id], let peer = maybePeer {
                                if id.namespace == Namespaces.Peer.CloudUser {
                                    users.append(PeerNearbyEntry(peer: peer, memberCount: nil, expires: expires, distance: distance))
                                } else {
                                    var participantCount: Int32?
                                    if let maybeParticipantCount = participantCountMap[id] {
                                        participantCount = maybeParticipantCount.flatMap(Int32.init)
                                    }
                                    groups.append(PeerNearbyEntry(peer: peer, memberCount: participantCount, expires: expires, distance: distance))
                                }
                            }
                        case let .selfPeer(expires):
                            visible = true
                            if let maybePeer = peerMap[context.account.peerId], let peer = maybePeer {
                                users.append(PeerNearbyEntry(peer: peer, memberCount: nil, expires: expires, distance: 0))
                            }
                        }
                    }
                    return PeersNearbyData(latitude: coordinate.latitude, longitude: coordinate.longitude, address: address, visible: visible, accountPeerId: context.account.peerId, users: users, groups: groups, channels: [])
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
        
    let signal = combineLatest(context.sharedContext.presentationData, dataPromise.get(), chatLocationPromise.get(), displayLoading, expandedPromise.get(), context.account.postbox.preferencesView(keys: [PreferencesKeys.peersNearby]))
    |> deliverOnMainQueue
    |> map { presentationData, data, chatLocation, displayLoading, expanded, view -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        let state = view.values[PreferencesKeys.peersNearby]?.get(PeersNearbyState.self) ?? .default
        
        var crossfade = false
        if (data?.users.isEmpty ?? true) != (previous?.users.isEmpty ?? true) {
            crossfade = true
        }
        if (data?.groups.isEmpty ?? true) != (previous?.groups.isEmpty ?? true) {
            crossfade = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PeopleNearby_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: peersNearbyControllerEntries(data: data, state: state, presentationData: presentationData, displayLoading: displayLoading, expanded: expanded, chatLocation: chatLocation), style: .blocks, emptyStateItem: nil, crossfadeState: crossfade, animateChanges: !crossfade)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = PeersNearbyControllerImpl(context: context, state: signal)
    chatLocationPromise.set(controller.chatLocation.get())
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    navigateToProfileImpl = { [weak controller] peer, distance in
        if let navigationController = controller?.navigationController as? NavigationController, let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .nearbyPeer(distance: distance), avatarInitiallyExpanded: peer.largeProfileImage != nil, fromChat: false, requestsContext: nil) {
            navigationController.pushViewController(controller)
        }
    }
    navigateToChatImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peer.id), keepStack: .always, purposefulAction: {}, peekData: nil))
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c, animated: true)
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
    presentInGlobalOverlayImpl = { [weak controller] c in
        if let controller = controller {
            controller.presentInGlobalOverlay(c)
        }
    }
    return controller
}
