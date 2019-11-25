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
import ActivityIndicator
import TelegramPresentationData
import AccountContext
import AppBundle
import CoreLocation
import Geocoding

private struct LocationPickerTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isLoading: Bool
}

private enum LocationPickerEntryId: Hashable {
    case location
    case liveLocation
    case header
    case venue(String)
    case attribution
}

private enum LocationPickerEntry: Comparable, Identifiable {
    case location(PresentationTheme, String, String, TelegramMediaMap?, CLLocationCoordinate2D?)
    case liveLocation(PresentationTheme, String, String, CLLocationCoordinate2D?)
    case header(PresentationTheme, String)
    case venue(PresentationTheme, TelegramMediaMap, Int)
    case attribution(PresentationTheme)
    
    var stableId: LocationPickerEntryId {
        switch self {
            case .location:
                return .location
            case .liveLocation:
                return .liveLocation
            case .header:
                return .header
            case let .venue(_, venue, _):
                return .venue(venue.venue?.id ?? "")
            case .attribution:
                return .attribution
        }
    }
    
    static func ==(lhs: LocationPickerEntry, rhs: LocationPickerEntry) -> Bool {
        switch lhs {
            case let .location(lhsTheme, lhsTitle, lhsSubtitle, lhsVenue, lhsCoordinate):
                if case let .location(rhsTheme, rhsTitle, rhsSubtitle, rhsVenue, rhsCoordinate) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsVenue?.venue?.id == rhsVenue?.venue?.id, lhsCoordinate == rhsCoordinate {
                    return true
                } else {
                    return false
                }
            case let .liveLocation(lhsTheme, lhsTitle, lhsSubtitle, lhsCoordinate):
                if case let .liveLocation(rhsTheme, rhsTitle, rhsSubtitle, rhsCoordinate) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsCoordinate == rhsCoordinate {
                    return true
                } else {
                    return false
                }
            case let .header(lhsTheme, lhsTitle):
                if case let .header(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .venue(lhsTheme, lhsVenue, lhsIndex):
                if case let .venue(rhsTheme, rhsVenue, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsVenue.venue?.id == rhsVenue.venue?.id, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .attribution(lhsTheme):
                if case let .attribution(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: LocationPickerEntry, rhs: LocationPickerEntry) -> Bool {
        switch lhs {
            case .location:
                switch rhs {
                    case .location:
                        return false
                    case .liveLocation, .header, .venue, .attribution:
                        return true
                }
            case .liveLocation:
                switch rhs {
                    case .location, .liveLocation:
                        return false
                    case .header, .venue, .attribution:
                        return true
            }
            case .header:
                switch rhs {
                    case .location, .liveLocation, .header:
                        return false
                    case .venue, .attribution:
                        return true
            }
            case let .venue(_, _, lhsIndex):
                switch rhs {
                    case .location, .liveLocation, .header:
                        return false
                    case let .venue(_, _, rhsIndex):
                        return lhsIndex < rhsIndex
                    case .attribution:
                        return true
                }
            case .attribution:
                return false
        }
    }
    
    func item(account: Account, presentationData: PresentationData, interaction: LocationPickerInteraction?) -> ListViewItem {
        switch self {
            case let .location(theme, title, subtitle, venue, coordinate):
                let icon: LocationActionListItemIcon
                if let venue = venue {
                    icon = .venue(venue)
                } else {
                    icon = .location
                }
                return LocationActionListItem(presentationData: ItemListPresentationData(presentationData), account: account, title: title, subtitle: subtitle, icon: icon, action: {
                    if let coordinate = coordinate {
                        interaction?.sendLocation(coordinate)
                    }
                }, highlighted: { highlighted in
                    interaction?.updateSendActionHighlight(highlighted)
                })
            case let .liveLocation(theme, title, subtitle, coordinate):
                return LocationActionListItem(presentationData: ItemListPresentationData(presentationData), account: account, title: title, subtitle: subtitle, icon: .liveLocation, action: {
                    if let coordinate = coordinate {
                        interaction?.sendLiveLocation(coordinate)
                    }
                })
            case let .header(theme, title):
                return LocationSectionHeaderItem(presentationData: ItemListPresentationData(presentationData), title: title)
            case let .venue(theme, venue, _):
                return ItemListVenueItem(presentationData: ItemListPresentationData(presentationData), account: account, venue: venue, sectionId: 0, style: .plain, action: {
                    interaction?.sendVenue(venue)
                })
            case let .attribution(theme):
                return LocationAttributionItem(presentationData: ItemListPresentationData(presentationData))
        }
    }
}

private func preparedTransition(from fromEntries: [LocationPickerEntry], to toEntries: [LocationPickerEntry], isLoading: Bool, account: Account, presentationData: PresentationData, interaction: LocationPickerInteraction?) -> LocationPickerTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return LocationPickerTransaction(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading)
}

enum LocationPickerLocation {
    case none
    case selecting
    case location(CLLocationCoordinate2D, String?)
    case venue(TelegramMediaMap)
    
    var isCustom: Bool {
        switch self {
            case .none:
                return false
            default:
                return true
        }
    }
}

struct LocationPickerState {
    var mapMode: LocationMapMode
    var displayingMapModeOptions: Bool
    var selectedLocation: LocationPickerLocation
    
    init() {
        self.mapMode = .map
        self.displayingMapModeOptions = false
        self.selectedLocation = .none
    }
}

final class LocationPickerControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let presentationDataPromise: Promise<PresentationData>
    private let mode: LocationPickerMode
    private let interaction: LocationPickerInteraction
    
    private let listNode: ListView
    private let headerNode: LocationMapHeaderNode
    private let activityIndicator: ActivityIndicator
    
    private let optionsNode: LocationOptionsNode
    private(set) var searchContainerNode: LocationSearchContainerNode?
    
    private var enqueuedTransitions: [(LocationPickerTransaction, Bool)] = []
    
    private var disposable: Disposable?
    private var state: LocationPickerState
    private let statePromise: Promise<LocationPickerState>
    private var geocodingDisposable = MetaDisposable()
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    private var listOffset: CGFloat?
        
    init(context: AccountContext, presentationData: PresentationData, mode: LocationPickerMode, interaction: LocationPickerInteraction) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(presentationData)
        self.mode = mode
        self.interaction = interaction
        
        self.state = LocationPickerState()
        self.statePromise = Promise(self.state)
        
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
        
        self.headerNode = LocationMapHeaderNode(presentationData: presentationData, interaction: interaction)
        self.headerNode.mapNode.isRotateEnabled = false
        
        self.optionsNode = LocationOptionsNode(presentationData: presentationData, interaction: interaction)
        
        self.activityIndicator = ActivityIndicator(type: .custom(self.presentationData.theme.list.itemSecondaryTextColor, 22.0, 1.0, false))
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.headerNode)
        self.addSubnode(self.optionsNode)
        self.listNode.addSubnode(self.activityIndicator)
        
        let userLocation: Signal<CLLocation?, NoError> = self.headerNode.mapNode.userLocation
        let filteredUserLocation: Signal<CLLocation?, NoError> = userLocation
        |> reduceLeft(value: nil) { current, updated, emit -> CLLocation? in
            if let current = current {
                if let updated = updated {
                    if updated.distance(from: current) > 250 || (updated.horizontalAccuracy < 50.0 && updated.horizontalAccuracy < current.horizontalAccuracy) {
                        emit(updated)
                        return updated
                    } else {
                        return current
                    }
                } else {
                    return current
                }
            } else {
                if let updated = updated, updated.horizontalAccuracy > 0.0 {
                    emit(updated)
                    return updated
                } else {
                    return nil
                }
            }
        }
        let venues: Signal<[TelegramMediaMap]?, NoError> = .single(nil)
        |> then(
            filteredUserLocation
            |> mapToSignal { location -> Signal<[TelegramMediaMap]?, NoError> in
                if let location = location, location.horizontalAccuracy > 0 {
                    return nearbyVenues(account: context.account, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                    |> map(Optional.init)
                } else {
                    return .single(nil)
                }
            }
        )
        
        let previousState = Atomic<LocationPickerState>(value: self.state)
        let previousUserLocation = Atomic<CLLocation?>(value: nil)
        let previousAnnotations = Atomic<[LocationPinAnnotation]>(value: [])
        let previousEntries = Atomic<[LocationPickerEntry]?>(value: nil)
        
        self.disposable = (combineLatest(self.presentationDataPromise.get(), self.statePromise.get(), userLocation, venues)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, userLocation, venues in
            if let strongSelf = self {
                var entries: [LocationPickerEntry] = []
                
                switch state.selectedLocation {
                    case let .location(coordinate, address):
                        entries.append(.location(presentationData.theme, presentationData.strings.Map_SendThisLocation, address ?? presentationData.strings.Map_Locating, nil, coordinate))
                    case .selecting:
                        entries.append(.location(presentationData.theme, presentationData.strings.Map_SendThisLocation, presentationData.strings.Map_Locating, nil, nil))
                    case let .venue(venue):
                        entries.append(.location(presentationData.theme, presentationData.strings.Map_SendThisPlace, venue.venue?.title ?? "", venue, venue.coordinate))
                    case .none:
                        let title: String
                        switch strongSelf.mode {
                            case .share:
                                title = presentationData.strings.Map_SendMyCurrentLocation
                            case .pick:
                                title = presentationData.strings.Map_SetThisLocation
                        }
                        entries.append(.location(presentationData.theme, title, (userLocation?.horizontalAccuracy).flatMap { presentationData.strings.Map_AccurateTo(stringForDistance(strings: presentationData.strings, distance: $0)).0 } ?? presentationData.strings.Map_Locating, nil, userLocation?.coordinate))
                }
                
                if case .share(_, _, true) = mode {
                    entries.append(.liveLocation(presentationData.theme, presentationData.strings.Map_ShareLiveLocation, presentationData.strings.Map_ShareLiveLocationHelp, userLocation?.coordinate))
                }
                
                entries.append(.header(presentationData.theme, presentationData.strings.Map_ChooseAPlace.uppercased()))
                
                if let venues = venues {
                    var index: Int = 0
                    for venue in venues {
                        entries.append(.venue(presentationData.theme, venue, index))
                        index += 1
                    }
                    if !venues.isEmpty {
                        entries.append(.attribution(presentationData.theme))
                    }
                }
                let previousEntries = previousEntries.swap(entries)
                let transition = preparedTransition(from: previousEntries ?? [], to: entries, isLoading: venues == nil, account: context.account, presentationData: presentationData, interaction: strongSelf.interaction)
                strongSelf.enqueueTransition(transition, firstTime: false)
                
                strongSelf.headerNode.updateState(state)
                
                let previousUserLocation = previousUserLocation.swap(userLocation)
                switch state.selectedLocation {
                    case .none:
                        if let userLocation = userLocation {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: userLocation.coordinate, animated: previousUserLocation != nil)
                        }
                        strongSelf.headerNode.mapNode.resetAnnotationSelection()
                    case .selecting:
                        strongSelf.headerNode.mapNode.resetAnnotationSelection()
                    case let .venue(venue):
                        strongSelf.headerNode.mapNode.setMapCenter(coordinate: venue.coordinate, animated: true)
                    default:
                        break
                }
                
                let annotations: [LocationPinAnnotation]
                if let venues = venues {
                    annotations = venues.compactMap { LocationPinAnnotation(account: context.account, theme: presentationData.theme, location: $0) }
                } else {
                    annotations = []
                }
                let previousAnnotations = previousAnnotations.swap(annotations)
                if annotations != previousAnnotations {
                    strongSelf.headerNode.mapNode.annotations = annotations
                }
                
                let previousState = previousState.swap(state)
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    var updateLayout = false
                    var transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
                    
                    if previousState.displayingMapModeOptions != state.displayingMapModeOptions {
                        updateLayout = true
                    } else if previousState.selectedLocation.isCustom != state.selectedLocation.isCustom {
                        updateLayout = true
                    }
                    
                    if updateLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationHeight: navigationBarHeight, transition: transition)
                    }
                }
                
                if case let .location(coordinate, address) = state.selectedLocation, address == nil {
                    strongSelf.geocodingDisposable.set((reverseGeocodeLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    |> deliverOnMainQueue).start(next: { [weak self] placemark in
                        if let strongSelf = self {
                            strongSelf.updateState { state in
                                var state = state
                                state.selectedLocation = .location(coordinate, placemark?.fullAddress)
                                return state
                            }
                        }
                    }))
                } else {
                    strongSelf.geocodingDisposable.set(nil)
                }
            }
        })
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, listTransition in
            guard let strongSelf = self, let (layout, navigationBarHeight) = strongSelf.validLayout else {
                return
            }
            
            let overlap: CGFloat = 6.0
            strongSelf.listOffset = max(0.0, offset)
            let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: max(0.0, offset + overlap)))
            listTransition.updateFrame(node: strongSelf.headerNode, frame: headerFrame)
            strongSelf.headerNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, padding: strongSelf.state.displayingMapModeOptions ? 38.0 : 0.0, size: headerFrame.size, transition: listTransition)
            strongSelf.layoutActivityIndicator(transition: listTransition)
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
                state.selectedLocation = .selecting
                return state
            }
        }
        
        self.headerNode.mapNode.endedInteractiveDragging = { [weak self] coordinate in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateState { state in
                var state = state
                if case .selecting = state.selectedLocation {
                    state.selectedLocation = .location(coordinate, nil)
                }
                return state
            }
        }
        
        self.headerNode.mapNode.annotationSelected = { [weak self] annotation in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = annotation.flatMap { .venue($0.location) } ?? .none
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
        self.headerNode.updatePresentationData(self.presentationData)
        self.optionsNode.updatePresentationData(self.presentationData)
        self.searchContainerNode?.updatePresentationData(self.presentationData)
    }
    
    func updateState(_ f: (LocationPickerState) -> LocationPickerState) {
        self.state = f(self.state)
        self.statePromise.set(.single(self.state))
    }
    
    private func enqueueTransition(_ transition: LocationPickerTransaction, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        guard let layout = self.validLayout, let (transition, firstTime) = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.PreferSynchronousDrawing)
        } else {
            options.insert(.AnimateCrossfade)
        }
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.activityIndicator.isHidden = !transition.isLoading
            }
        })
    }
    
    func activateSearch(navigationBar: NavigationBar) {
        guard let (layout, navigationBarHeight) = self.validLayout, self.searchContainerNode == nil, let coordinate = self.headerNode.mapNode.mapCenterCoordinate else {
            return
        }
        
        let searchContainerNode = LocationSearchContainerNode(context: self.context, coordinate: coordinate, interaction: self.interaction)
        self.insertSubnode(searchContainerNode, belowSubnode: navigationBar)
        self.searchContainerNode = searchContainerNode
        
        searchContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        self.containerLayoutUpdated(layout, navigationHeight: navigationBarHeight, transition: .immediate)
    }
    
    func deactivateSearch() {
        guard let searchContainerNode = self.searchContainerNode else {
            return
        }
        searchContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak searchContainerNode] _ in
            searchContainerNode?.removeFromSupernode()
        })
        self.searchContainerNode = nil
    }
    
    func scrollToTop() {
        if let searchContainerNode = self.searchContainerNode {
            searchContainerNode.scrollToTop()
        } else {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    private func layoutActivityIndicator(transition: ContainedViewLayoutTransition) {
        guard let (layout, navigationHeight) = self.validLayout else {
            return
        }
        
        let topInset: CGFloat = floor((layout.size.height - navigationHeight) / 2.0 + navigationHeight)
        let headerHeight: CGFloat
        if let listOffset = self.listOffset {
            headerHeight = max(0.0, listOffset)
        } else {
            headerHeight = topInset
        }
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - indicatorSize.width) / 2.0), y: headerHeight + 140.0 + floor((layout.size.height - headerHeight - 140.0 - 50.0) / 2.0)), size: indicatorSize))
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = (layout, navigationHeight)
        
        let optionsHeight: CGFloat = 38.0
        
        let topInset: CGFloat = floor((layout.size.height - navigationHeight) / 2.0 + navigationHeight)
        let overlap: CGFloat = 6.0
        let headerHeight: CGFloat
        if let listOffset = self.listOffset {
            headerHeight = max(0.0, listOffset + overlap)
        } else {
            headerHeight = topInset + overlap
        }
        let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: headerHeight))
        transition.updateFrame(node: self.headerNode, frame: headerFrame)
        self.headerNode.updateLayout(layout: layout, navigationBarHeight: navigationHeight, padding: self.state.displayingMapModeOptions ? optionsHeight : 0.0, size: headerFrame.size, transition: transition)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var insets = layout.insets(options: [.input])
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), headerInsets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), scrollIndicatorInsets: UIEdgeInsets(top: topInset + 3.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.listNode.scrollEnabled = !self.state.selectedLocation.isCustom
        
        self.layoutActivityIndicator(transition: transition)
        
        if isFirstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        let optionsOffset: CGFloat = self.state.displayingMapModeOptions ? navigationHeight : navigationHeight - optionsHeight
        let optionsFrame = CGRect(x: 0.0, y: optionsOffset, width: layout.size.width, height: optionsHeight)
        transition.updateFrame(node: self.optionsNode, frame: optionsFrame)
        self.optionsNode.updateLayout(size: optionsFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
        
        if let searchContainerNode = self.searchContainerNode {
            searchContainerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
            searchContainerNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: layout.safeInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationHeight, transition: transition)
        }
    }
    
    func updateSendActionHighlight(_ highlighted: Bool) {
        self.headerNode.updateHighlight(highlighted)
    }
}
