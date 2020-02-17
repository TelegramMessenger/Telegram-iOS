import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import MergeLists
import ItemListUI
import ItemListVenueItem
import TelegramPresentationData
import AccountContext
import AppBundle
import CoreLocation
import Geocoding

private func areMessagesEqual(_ lhsMessage: Message, _ rhsMessage: Message) -> Bool {
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags {
        return false
    }
    return true
}

private struct LocationViewTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private enum LocationViewEntryId: Hashable {
    case info
    case toggleLiveLocation
    case liveLocation(PeerId)
}

private enum LocationViewEntry: Comparable, Identifiable {
    case info(PresentationTheme, TelegramMediaMap, String?, Double?, Double?)
    case toggleLiveLocation(PresentationTheme, String, String)
    case liveLocation(PresentationTheme, Message, Int)
    
    var stableId: LocationViewEntryId {
        switch self {
            case .info:
                return .info
            case .toggleLiveLocation:
                return .toggleLiveLocation
            case let .liveLocation(_, message, _):
                return .liveLocation(message.id.peerId)
        }
    }
    
    static func ==(lhs: LocationViewEntry, rhs: LocationViewEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsLocation, lhsAddress, lhsDistance, lhsTime):
                if case let .info(rhsTheme, rhsLocation, rhsAddress, rhsDistance, rhsTime) = rhs, lhsTheme === rhsTheme, lhsLocation.venue?.id == rhsLocation.venue?.id, lhsAddress == rhsAddress, lhsDistance == rhsDistance, lhsTime == rhsTime {
                    return true
                } else {
                    return false
                }
            case let .toggleLiveLocation(lhsTheme, lhsTitle, lhsSubtitle):
                if case let .toggleLiveLocation(rhsTheme, rhsTitle, rhsSubtitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle {
                    return true
                } else {
                    return false
                }
            case let .liveLocation(lhsTheme, lhsMessage, lhsIndex):
                if case let .liveLocation(rhsTheme, rhsMessage, rhsIndex) = rhs, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage), lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: LocationViewEntry, rhs: LocationViewEntry) -> Bool {
        switch lhs {
            case .info:
                switch rhs {
                    case .info:
                        return false
                    case .toggleLiveLocation, .liveLocation:
                        return true
                }
            case .toggleLiveLocation:
                switch rhs {
                    case .info, .toggleLiveLocation:
                        return false
                    case .liveLocation:
                        return true
            }
            case let .liveLocation(_, _, lhsIndex):
                switch rhs {
                    case .info, .toggleLiveLocation:
                        return false
                    case let .liveLocation(_, _, rhsIndex):
                        return lhsIndex < rhsIndex
                }
        }
    }
    
    func item(account: Account, presentationData: PresentationData, interaction: LocationViewInteraction?) -> ListViewItem {
        switch self {
            case let .info(theme, location, address, distance, time):
                let addressString: String?
                if let address = address {
                    addressString = address
                } else {
                    addressString = presentationData.strings.Map_Locating
                }
                let distanceString: String?
                if let distance = distance {
                    distanceString = distance < 10 ? presentationData.strings.Map_YouAreHere : presentationData.strings.Map_DistanceAway(stringForDistance(strings: presentationData.strings, distance: distance)).0
                } else {
                    distanceString = nil
                }
                let eta = time.flatMap { stringForEstimatedDuration(strings: presentationData.strings, eta: $0) }
                return LocationInfoListItem(presentationData: ItemListPresentationData(presentationData), account: account, location: location, address: addressString, distance: distanceString, eta: eta, action: {
                    interaction?.goToCoordinate(location.coordinate)
                }, getDirections: {
                    interaction?.requestDirections()
                })
            case let .toggleLiveLocation(theme, title, subtitle):
                return LocationActionListItem(presentationData: ItemListPresentationData(presentationData), account: account, title: title, subtitle: subtitle, icon: .liveLocation, action: {
//                    if let coordinate = coordinate {
//                        interaction?.sendLiveLocation(coordinate)
//                    }
                })
            case let .liveLocation(theme, message, _):
                return ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(""), sectionId: 0)
        }
    }
}

private func preparedTransition(from fromEntries: [LocationViewEntry], to toEntries: [LocationViewEntry], account: Account, presentationData: PresentationData, interaction: LocationViewInteraction?) -> LocationViewTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return LocationViewTransaction(deletions: deletions, insertions: insertions, updates: updates)
}

enum LocationViewLocation: Equatable {
    case initial
    case user
    case coordinate(CLLocationCoordinate2D)
    case custom
}

struct LocationViewState {
    var mapMode: LocationMapMode
    var displayingMapModeOptions: Bool
    var selectedLocation: LocationViewLocation
    
    init() {
        self.mapMode = .map
        self.displayingMapModeOptions = false
        self.selectedLocation = .initial
    }
}

final class LocationViewControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let presentationDataPromise: Promise<PresentationData>
    private var mapMedia: TelegramMediaMap
    private let interaction: LocationViewInteraction
    
    private let listNode: ListView
    private let headerNode: LocationMapHeaderNode
    private let optionsNode: LocationOptionsNode
    
    private var enqueuedTransitions: [LocationViewTransaction] = []
    
    private var disposable: Disposable?
    private var state: LocationViewState
    private let statePromise: Promise<LocationViewState>
    private var geocodingDisposable = MetaDisposable()
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    private var listOffset: CGFloat?

    init(context: AccountContext, presentationData: PresentationData, mapMedia: TelegramMediaMap, interaction: LocationViewInteraction) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(presentationData)
        self.mapMedia = mapMedia
        self.interaction = interaction
        
        self.state = LocationViewState()
        self.statePromise = Promise(self.state)
        
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
        
        self.headerNode = LocationMapHeaderNode(presentationData: presentationData, toggleMapModeSelection: interaction.toggleMapModeSelection, goToUserLocation: interaction.goToUserLocation)
        self.headerNode.mapNode.isRotateEnabled = false
        
        self.optionsNode = LocationOptionsNode(presentationData: presentationData, updateMapMode: interaction.updateMapMode)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.headerNode)
        self.addSubnode(self.optionsNode)
        
        let distance: Signal<Double?, NoError> = .single(nil)
        |> then(
            throttledUserLocation(self.headerNode.mapNode.userLocation)
            |> map { userLocation -> Double? in
                let location = CLLocation(latitude: mapMedia.latitude, longitude: mapMedia.longitude)
                return userLocation.flatMap { location.distance(from: $0) }
            }
        )
        let address: Signal<String?, NoError>
        var eta: Signal<Double?, NoError> = .single(nil)
        |> then(
            driveEta(coordinate: mapMedia.coordinate)
        )
        if let venue = mapMedia.venue, let venueAddress = venue.address, !venueAddress.isEmpty {
            address = .single(venueAddress)
        } else if mapMedia.liveBroadcastingTimeout == nil {
            address = .single(nil)
            |> then(
                reverseGeocodeLocation(latitude: mapMedia.latitude, longitude: mapMedia.longitude)
                |> map { placemark -> String? in
                    return placemark?.compactDisplayAddress ?? ""
                }
            )
        } else {
            address = .single(nil)
            eta = .single(nil)
        }
        
        let previousState = Atomic<LocationViewState?>(value: nil)
        let previousAnnotations = Atomic<[LocationPinAnnotation]>(value: [])
        let previousEntries = Atomic<[LocationViewEntry]?>(value: nil)
        
        self.disposable = (combineLatest(self.presentationDataPromise.get(), self.statePromise.get(), self.headerNode.mapNode.userLocation, distance, address, eta)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, userLocation, distance, address, eta in
            if let strongSelf = self {
                var entries: [LocationViewEntry] = []

                entries.append(.info(presentationData.theme, mapMedia, address, distance, eta))
                
                let previousEntries = previousEntries.swap(entries)
                let previousState = previousState.swap(state)
                        
                let transition = preparedTransition(from: previousEntries ?? [], to: entries, account: context.account, presentationData: presentationData, interaction: strongSelf.interaction)
                strongSelf.enqueueTransition(transition)
                
                strongSelf.headerNode.updateState(mapMode: state.mapMode, displayingMapModeOptions: state.displayingMapModeOptions, displayingPlacesButton: false, animated: false)
                
                switch state.selectedLocation {
                    case .initial:
                        if previousState?.selectedLocation != .initial {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: mapMedia.coordinate, span: viewMapSpan, animated: previousState != nil)
                        }
                    case let .coordinate(coordinate):
                        if let previousState = previousState, case let .coordinate(previousCoordinate) = previousState.selectedLocation, previousCoordinate == coordinate {
                        } else {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: coordinate, span: viewMapSpan, animated: true)
                        }
                    case .user:
                        if previousState?.selectedLocation != .user, let userLocation = userLocation {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: userLocation.coordinate, isUserLocation: true, animated: true)
                        }
                    case .custom:
                        break
                }
                
                let annotations: [LocationPinAnnotation] = [LocationPinAnnotation(context: context, theme: presentationData.theme, location: mapMedia, forcedSelection: true)]

                let previousAnnotations = previousAnnotations.swap(annotations)
                if annotations != previousAnnotations {
                    strongSelf.headerNode.mapNode.annotations = annotations
                }
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    var updateLayout = false
                    var transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
                    
                    if previousState?.displayingMapModeOptions != state.displayingMapModeOptions {
                        updateLayout = true
                    }
                    
                    if updateLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationBarHeight, transition: transition)
                    }
                }
            }
        })
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, listTransition in
            guard let strongSelf = self, let (layout, navigationBarHeight) = strongSelf.validLayout, strongSelf.listNode.scrollEnabled else {
                return
            }
            let overlap: CGFloat = 6.0
            strongSelf.listOffset = max(0.0, offset)
            let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: max(0.0, offset + overlap)))
            listTransition.updateFrame(node: strongSelf.headerNode, frame: headerFrame)
            strongSelf.headerNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: strongSelf.state.displayingMapModeOptions ? 38.0 : 0.0, offset: 0.0, size: headerFrame.size, transition: listTransition)
        }
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                return state
            }
        }
        
        self.headerNode.mapNode.beganInteractiveDragging = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .custom
                return state
            }
        }
    }
    
    deinit {
        self.disposable?.dispose()
        self.geocodingDisposable.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationDataPromise.set(.single(presentationData))
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.headerNode.updatePresentationData(self.presentationData)
        self.optionsNode.updatePresentationData(self.presentationData)
    }
    
    func updateState(_ f: (LocationViewState) -> LocationViewState) {
        self.state = f(self.state)
        self.statePromise.set(.single(self.state))
    }
    
    private func enqueueTransition(_ transition: LocationViewTransaction) {
        self.enqueuedTransitions.append(transition)
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        guard let layout = self.validLayout, let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()

        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
        })
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = (layout, navigationHeight)
        
        let optionsHeight: CGFloat = 38.0
        var actionHeight: CGFloat?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? LocationActionListItemNode {
                if actionHeight == nil {
                    actionHeight = itemNode.frame.height
                }
            }
        }
        
        let overlap: CGFloat = 6.0
        let topInset: CGFloat = layout.size.height - layout.intrinsicInsets.bottom - 126.0 - overlap
        let headerHeight: CGFloat
        if let listOffset = self.listOffset {
            headerHeight = max(0.0, listOffset + overlap)
        } else {
            headerHeight = topInset + overlap
        }
        let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: headerHeight))
        transition.updateFrame(node: self.headerNode, frame: headerFrame)
        
        self.headerNode.updateLayout(layout: layout, navigationBarHeight: navigationHeight, topPadding: self.state.displayingMapModeOptions ? optionsHeight : 0.0, offset: 0.0, size: headerFrame.size, transition: transition)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        let insets = UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), scrollIndicatorInsets: UIEdgeInsets(top: topInset + 3.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        let listFrame: CGRect = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(node: self.listNode, frame: listFrame)
        
        if isFirstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        let optionsOffset: CGFloat = self.state.displayingMapModeOptions ? navigationHeight : navigationHeight - optionsHeight
        let optionsFrame = CGRect(x: 0.0, y: optionsOffset, width: layout.size.width, height: optionsHeight)
        transition.updateFrame(node: self.optionsNode, frame: optionsFrame)
        self.optionsNode.updateLayout(size: optionsFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
    }
}
