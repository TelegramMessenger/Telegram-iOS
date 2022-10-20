import Foundation
import UIKit
import AsyncDisplayKit
import Display
import LegacyComponents
import TelegramCore
import Postbox
import SwiftSignalKit
import MergeLists
import ItemListUI
import ItemListVenueItem
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import AppBundle
import CoreLocation
import Geocoding
import PhoneNumberFormat
import DeviceAccess

private struct LocationPickerTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isLoading: Bool
    let isEmpty: Bool
    let crossFade: Bool
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
    case venue(PresentationTheme, TelegramMediaMap?, Int)
    case attribution(PresentationTheme, LocationAttribution)
    
    var stableId: LocationPickerEntryId {
        switch self {
            case .location:
                return .location
            case .liveLocation:
                return .liveLocation
            case .header:
                return .header
            case let .venue(_, venue, index):
                return .venue(venue?.venue?.id ?? "\(index)")
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
                if case let .venue(rhsTheme, rhsVenue, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsVenue?.venue?.id == rhsVenue?.venue?.id, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .attribution(lhsTheme, lhsAttribution):
                if case let .attribution(rhsTheme, rhsAttribution) = rhs, lhsTheme === rhsTheme, lhsAttribution == rhsAttribution {
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
    
    func item(engine: TelegramEngine, presentationData: PresentationData, interaction: LocationPickerInteraction?) -> ListViewItem {
        switch self {
            case let .location(_, title, subtitle, venue, coordinate):
                let icon: LocationActionListItemIcon
                if let venue = venue {
                    icon = .venue(venue)
                } else {
                    icon = .location
                }
                return LocationActionListItem(presentationData: ItemListPresentationData(presentationData), engine: engine, title: title, subtitle: subtitle, icon: icon, beginTimeAndTimeout: nil, action: {
                    if let venue = venue {
                        interaction?.sendVenue(venue)
                    } else if let coordinate = coordinate {
                        interaction?.sendLocation(coordinate)
                    }
                }, highlighted: { highlighted in
                    interaction?.updateSendActionHighlight(highlighted)
                })
            case let .liveLocation(_, title, subtitle, coordinate):
                return LocationActionListItem(presentationData: ItemListPresentationData(presentationData), engine: engine, title: title, subtitle: subtitle, icon: .liveLocation, beginTimeAndTimeout: nil, action: {
                    if let coordinate = coordinate {
                        interaction?.sendLiveLocation(coordinate)
                    }
                })
            case let .header(_, title):
                return LocationSectionHeaderItem(presentationData: ItemListPresentationData(presentationData), title: title)
            case let .venue(_, venue, _):
                let venueType = venue?.venue?.type ?? ""
                return ItemListVenueItem(presentationData: ItemListPresentationData(presentationData), engine: engine, venue: venue, style: .plain, action: venue.flatMap { venue in
                    return { interaction?.sendVenue(venue) }
                }, infoAction: ["home", "work"].contains(venueType) ? {
                    interaction?.openHomeWorkInfo()
                    } : nil)
            case let .attribution(_, attribution):
                return LocationAttributionItem(presentationData: ItemListPresentationData(presentationData), attribution: attribution)
        }
    }
}

private func preparedTransition(from fromEntries: [LocationPickerEntry], to toEntries: [LocationPickerEntry], isLoading: Bool, isEmpty: Bool, crossFade: Bool, engine: TelegramEngine, presentationData: PresentationData, interaction: LocationPickerInteraction?) -> LocationPickerTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(engine: engine, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(engine: engine, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return LocationPickerTransaction(deletions: deletions, insertions: insertions, updates: updates, isLoading: isLoading, isEmpty: isEmpty, crossFade: crossFade)
}

enum LocationPickerLocation: Equatable {
    case none
    case selecting
    case location(CLLocationCoordinate2D, String?)
    case venue(TelegramMediaMap)
    
    var isCustom: Bool {
        switch self {
            case .selecting, .location:
                return true
            default:
                return false
        }
    }
    
    public static func ==(lhs: LocationPickerLocation, rhs: LocationPickerLocation) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case .selecting:
                if case .selecting = rhs {
                    return true
                } else {
                    return false
                }
            case let .location(lhsCoordinate, lhsAddress):
                if case let .location(rhsCoordinate, rhsAddress) = rhs, lhsCoordinate == rhsCoordinate, lhsAddress == rhsAddress {
                    return true
                } else {
                    return false
                }
            case let .venue(lhsVenue):
                if case let .venue(rhsVenue) = rhs, lhsVenue.venue?.id == rhsVenue.venue?.id {
                    return true
                } else {
                    return false
                }
            
        }
    }
}

struct LocationPickerState {
    var mapMode: LocationMapMode
    var displayingMapModeOptions: Bool
    var selectedLocation: LocationPickerLocation
    var forceSelection: Bool
    var searchingVenuesAround: Bool
    
    init() {
        self.mapMode = .map
        self.displayingMapModeOptions = false
        self.selectedLocation = .none
        self.forceSelection = false
        self.searchingVenuesAround = false
    }
}

private class LocationContext: NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    
    private let accessSink = ValuePipe<CLAuthorizationStatus>()
    
    override init() {
        self.locationManager = CLLocationManager()
        
        super.init()
        
        self.locationManager.delegate = self
    }
    
    func locationAccess() -> Signal<CLAuthorizationStatus, NoError> {
        let initialStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            initialStatus = self.locationManager.authorizationStatus
        } else {
            initialStatus = CLLocationManager.authorizationStatus()
        }
        return .single(initialStatus)
        |> then(
            self.accessSink.signal()
        )
    }
    
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.accessSink.putNext(manager.authorizationStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.accessSink.putNext(status)
    }
}

final class LocationPickerControllerNode: ViewControllerTracingNode, CLLocationManagerDelegate {
    private weak var controller: LocationPickerController?
    private let context: AccountContext
    private var presentationData: PresentationData
    private let presentationDataPromise: Promise<PresentationData>
    private let mode: LocationPickerMode
    private let interaction: LocationPickerInteraction
    private let locationManager: LocationManager
    
    private let locationContext: LocationContext
    
    private let listNode: ListView
    private let emptyResultsTextNode: ImmediateTextNode
    private let headerNode: LocationMapHeaderNode
    private let shadeNode: ASDisplayNode
    private let innerShadeNode: ASDisplayNode
    
    private let optionsNode: LocationOptionsNode
    private(set) var searchContainerNode: LocationSearchContainerNode?
    
    private var placeholderBackgroundNode: NavigationBackgroundNode?
    private var placeholderNode: LocationPlaceholderNode?
    private var locationAccessDenied = false
    
    private var enqueuedTransitions: [LocationPickerTransaction] = []
    
    private var disposable: Disposable?
    private var state: LocationPickerState
    private let statePromise: Promise<LocationPickerState>
    private var geocodingDisposable = MetaDisposable()
    
    private let searchVenuesPromise = Promise<CLLocationCoordinate2D?>()
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    private var listOffset: CGFloat?
        
    var beganInteractiveDragging: () -> Void = {}
    var locationAccessDeniedUpdated: (Bool) -> Void = { _ in }
    
    init(controller: LocationPickerController, context: AccountContext, presentationData: PresentationData, mode: LocationPickerMode, interaction: LocationPickerInteraction, locationManager: LocationManager) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(presentationData)
        self.mode = mode
        self.interaction = interaction
        self.locationManager = locationManager
        
        self.locationContext = LocationContext()
        
        self.state = LocationPickerState()
        self.statePromise = Promise(self.state)
        
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
        
        self.headerNode = LocationMapHeaderNode(presentationData: presentationData, toggleMapModeSelection: interaction.toggleMapModeSelection, goToUserLocation: interaction.goToUserLocation, showPlacesInThisArea: interaction.showPlacesInThisArea)
        self.headerNode.mapNode.isRotateEnabled = false
        
        self.optionsNode = LocationOptionsNode(presentationData: presentationData, updateMapMode: interaction.updateMapMode)
        
        self.shadeNode = ASDisplayNode()
        self.shadeNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.shadeNode.alpha = 0.0
        self.innerShadeNode = ASDisplayNode()
        self.innerShadeNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.headerNode)
        self.addSubnode(self.optionsNode)
        self.listNode.addSubnode(self.emptyResultsTextNode)
        self.shadeNode.addSubnode(self.innerShadeNode)
        self.addSubnode(self.shadeNode)
        
        let userLocation: Signal<CLLocation?, NoError> = self.headerNode.mapNode.userLocation
        
        let personalAddresses = self.context.account.postbox.peerView(id: self.context.account.peerId)
        |> mapToSignal { view -> Signal<(DeviceContactAddressData?, DeviceContactAddressData?)?, NoError> in
            if let user = peerViewMainPeer(view) as? TelegramUser, let phoneNumber = user.phone {
                return ((context.sharedContext.contactDataManager?.basicData() ?? .single([:])) |> take(1))
                |> mapToSignal { basicData -> Signal<DeviceContactExtendedData?, NoError> in
                    var stableId: String?
                    let queryPhoneNumber = formatPhoneNumber(phoneNumber)
                    outer: for (id, data) in basicData {
                        for phoneNumber in data.phoneNumbers {
                            if formatPhoneNumber(phoneNumber.value) == queryPhoneNumber {
                                stableId = id
                                break outer
                            }
                        }
                    }
                    if let stableId = stableId {
                        return (context.sharedContext.contactDataManager?.extendedData(stableId: stableId) ?? .single(nil))
                        |> take(1)
                        |> map { extendedData -> DeviceContactExtendedData? in
                            return extendedData
                        }
                    } else {
                        return .single(nil)
                    }
                }
                |> map { extendedData -> (DeviceContactAddressData?, DeviceContactAddressData?)? in
                    if let extendedData = extendedData {
                        var homeAddress: DeviceContactAddressData?
                        var workAddress: DeviceContactAddressData?
                        for address in extendedData.addresses {
                            if address.label == "_$!<Home>!$_" {
                                homeAddress = address
                            } else if address.label == "_$!<Work>!$_" {
                                workAddress = address
                            }
                        }
                        return (homeAddress, workAddress)
                    } else {
                        return nil
                    }
                }
            } else {
                return .single(nil)
            }
        }
        
        let personalVenues: Signal<[TelegramMediaMap]?, NoError> = .single(nil)
        |> then(
            personalAddresses
            |> mapToSignal { homeAndWorkAddresses -> Signal<[TelegramMediaMap]?, NoError> in
                if let (homeAddress, workAddress) = homeAndWorkAddresses {
                    let home: Signal<(Double, Double)?, NoError>
                    let work: Signal<(Double, Double)?, NoError>
                    if let address = homeAddress {
                        home = geocodeAddress(engine: context.engine, address: address)
                    } else {
                        home = .single(nil)
                    }
                    if let address = workAddress {
                        work = geocodeAddress(engine: context.engine, address: address)
                    } else {
                        work = .single(nil)
                    }
                    return combineLatest(home, work)
                    |> map { homeCoordinate, workCoordinate -> [TelegramMediaMap]? in
                        var venues: [TelegramMediaMap] = []
                        if let (latitude, longitude) = homeCoordinate, let address = homeAddress {
                            venues.append(TelegramMediaMap(latitude: latitude, longitude: longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: MapVenue(title: presentationData.strings.Map_Home, address: address.displayString, provider: nil, id: "home", type: "home"), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                        }
                        if let (latitude, longitude) = workCoordinate, let address = workAddress {
                            venues.append(TelegramMediaMap(latitude: latitude, longitude: longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: MapVenue(title: presentationData.strings.Map_Work, address: address.displayString, provider: nil, id: "work", type: "work"), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                        }
                        return venues
                    }
                } else {
                    return .single(nil)
                }
            }
        )
        
        let venues: Signal<[TelegramMediaMap]?, NoError> = .single(nil)
        |> then(
            throttledUserLocation(userLocation)
            |> mapToSignal { location -> Signal<[TelegramMediaMap]?, NoError> in
                if let location = location, location.horizontalAccuracy > 0 {
                    return combineLatest(nearbyVenues(context: context, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), personalVenues)
                    |> map { nearbyVenues, personalVenues -> [TelegramMediaMap]? in
                        var resultVenues: [TelegramMediaMap] = []
                        if let personalVenues = personalVenues {
                            for venue in personalVenues {
                                let venueLocation = CLLocation(latitude: venue.latitude, longitude: venue.longitude)
                                if venueLocation.distance(from: location) <= 1000 {
                                    resultVenues.append(venue)
                                }
                            }
                        }
                        resultVenues.append(contentsOf: nearbyVenues)
                        return resultVenues
                    }
                } else {
                    return .single(nil)
                }
            }
        )
        
        let foundVenues: Signal<([TelegramMediaMap], CLLocation)?, NoError> = .single(nil)
        |> then(
            self.searchVenuesPromise.get()
            |> distinctUntilChanged
            |> mapToSignal { coordinate -> Signal<([TelegramMediaMap], CLLocation)?, NoError> in
                if let coordinate = coordinate {
                    return (.single(nil)
                    |> then(
                        nearbyVenues(context: context, latitude: coordinate.latitude, longitude: coordinate.longitude)
                        |> map { venues -> ([TelegramMediaMap], CLLocation)? in
                            return (venues, CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                        }
                    ))
                } else {
                    return .single(nil)
                }
            }
        )
        
        let previousState = Atomic<LocationPickerState>(value: self.state)
        let previousUserLocation = Atomic<CLLocation?>(value: nil)
        let previousAnnotations = Atomic<[LocationPinAnnotation]>(value: [])
        let previousEntries = Atomic<[LocationPickerEntry]?>(value: nil)
        
        self.disposable = (combineLatest(self.presentationDataPromise.get(), self.statePromise.get(), userLocation, venues, foundVenues, self.locationContext.locationAccess())
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, userLocation, venues, foundVenuesAndLocation, access in
            if let strongSelf = self {
                let (foundVenues, foundVenuesLocation) = foundVenuesAndLocation ?? (nil, nil)
                
                var entries: [LocationPickerEntry] = []
                switch state.selectedLocation {
                    case let .location(coordinate, address):
                        let title: String
                        switch strongSelf.mode {
                            case .share:
                                title = presentationData.strings.Map_SendThisLocation
                            case .pick:
                                title = presentationData.strings.Map_SetThisLocation
                        }
                        entries.append(.location(presentationData.theme, title, address ?? presentationData.strings.Map_Locating, nil, coordinate))
                    case .selecting:
                        let title: String
                        switch strongSelf.mode {
                            case .share:
                                title = presentationData.strings.Map_SendThisLocation
                            case .pick:
                                title = presentationData.strings.Map_SetThisLocation
                        }
                        entries.append(.location(presentationData.theme, title, presentationData.strings.Map_Locating, nil, nil))
                    case let .venue(venue):
                        let title: String
                        switch strongSelf.mode {
                            case .share:
                                title = presentationData.strings.Map_SendThisPlace
                            case .pick:
                                title = presentationData.strings.Map_SetThisPlace
                        }
                        entries.append(.location(presentationData.theme, title, venue.venue?.title ?? "", venue, venue.coordinate))
                    case .none:
                        let title: String
                        switch strongSelf.mode {
                            case .share:
                                title = presentationData.strings.Map_SendMyCurrentLocation
                            case .pick:
                                title = presentationData.strings.Map_SetThisLocation
                        }
                        entries.append(.location(presentationData.theme, title, (userLocation?.horizontalAccuracy).flatMap { presentationData.strings.Map_AccurateTo(stringForDistance(strings: presentationData.strings, distance: $0)).string } ?? presentationData.strings.Map_Locating, nil, userLocation?.coordinate))
                }
                
                if case .share(_, _, true) = mode {
                    entries.append(.liveLocation(presentationData.theme, presentationData.strings.Map_ShareLiveLocation, presentationData.strings.Map_ShareLiveLocationHelp, userLocation?.coordinate))
                }
                
                entries.append(.header(presentationData.theme, presentationData.strings.Map_ChooseAPlace.uppercased()))
                
                let displayedVenues = foundVenues != nil || state.searchingVenuesAround ? foundVenues : venues
                var index: Int = 0
                if let venues = displayedVenues {
                    var attribution: LocationAttribution?
                    for venue in venues {
                        if venue.venue?.provider == "foursquare" {
                            attribution = .foursquare
                        } else if venue.venue?.provider == "gplaces" {
                            attribution = .google
                        }
                        entries.append(.venue(presentationData.theme, venue, index))
                        index += 1
                    }
                    if let attribution = attribution {
                        entries.append(.attribution(presentationData.theme, attribution))
                    }
                } else {
                    for _ in 0 ..< 8 {
                        entries.append(.venue(presentationData.theme, nil, index))
                        index += 1
                    }
                }
                let previousEntries = previousEntries.swap(entries)
                let previousState = previousState.swap(state)
                
                var crossFade = false
                if previousEntries?.count != entries.count || previousState.selectedLocation != state.selectedLocation {
                    crossFade = true
                }
                
                let transition = preparedTransition(from: previousEntries ?? [], to: entries, isLoading: displayedVenues == nil, isEmpty: displayedVenues?.isEmpty ?? false, crossFade: crossFade, engine: context.engine, presentationData: presentationData, interaction: strongSelf.interaction)
                strongSelf.enqueueTransition(transition)
                      
                var displayingPlacesButton = false
                let previousUserLocation = previousUserLocation.swap(userLocation)
                switch state.selectedLocation {
                    case .none:
                        if let userLocation = userLocation {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: userLocation.coordinate, isUserLocation: true, animated: previousUserLocation != nil)
                        }
                        strongSelf.headerNode.mapNode.resetAnnotationSelection()
                    case .selecting:
                        strongSelf.headerNode.mapNode.resetAnnotationSelection()
                    case let .location(coordinate, address):
                        var updateMap = false
                        switch previousState.selectedLocation {
                            case .none, .venue:
                                updateMap = true
                            case let .location(previousCoordinate, _):
                                if previousCoordinate != coordinate {
                                    updateMap = true
                                }
                            default:
                                break
                        }
                        if updateMap {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: coordinate, isUserLocation: false, hidePicker: false, animated: true)
                            strongSelf.headerNode.mapNode.switchToPicking(animated: false)
                        }
                    
                        if address != nil {
                            if foundVenues == nil && !state.searchingVenuesAround {
                                displayingPlacesButton = true
                            } else if let previousLocation = foundVenuesLocation {
                                let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                if currentLocation.distance(from: previousLocation) > 300 {
                                    displayingPlacesButton = true
                                }
                            }
                        }
                    case let .venue(venue):
                        strongSelf.headerNode.mapNode.setMapCenter(coordinate: venue.coordinate, hidePicker: true, animated: true)
                }
                
                strongSelf.headerNode.updateState(mapMode: state.mapMode, trackingMode: .none, displayingMapModeOptions: state.displayingMapModeOptions, displayingPlacesButton: displayingPlacesButton, proximityNotification: nil, animated: true)
                
                let annotations: [LocationPinAnnotation]
                if let venues = displayedVenues {
                    annotations = venues.compactMap { LocationPinAnnotation(context: context, theme: presentationData.theme, location: $0) }
                } else {
                    annotations = []
                }
                let previousAnnotations = previousAnnotations.swap(annotations)
                if annotations != previousAnnotations {
                    strongSelf.headerNode.mapNode.annotations = annotations
                }
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    var updateLayout = false
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
                
                    if [.denied, .restricted].contains(access) {
                        if !strongSelf.locationAccessDenied {
                            strongSelf.locationAccessDenied = true
                            strongSelf.locationAccessDeniedUpdated(true)
                            updateLayout = true
                        }
                    } else {
                        if strongSelf.locationAccessDenied {
                            strongSelf.locationAccessDenied = false
                            strongSelf.locationAccessDeniedUpdated(false)
                            updateLayout = true
                        }
                    }
                    
                    if previousState.displayingMapModeOptions != state.displayingMapModeOptions {
                        updateLayout = true
                    } else if previousState.selectedLocation.isCustom != state.selectedLocation.isCustom {
                        updateLayout = true
                    } else if previousState.searchingVenuesAround != state.searchingVenuesAround {
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
                            var address = placemark?.fullAddress ?? ""
                            if address.isEmpty {
                                address = presentationData.strings.Map_Unknown
                            }
                            strongSelf.updateState { state in
                                var state = state
                                state.selectedLocation = .location(coordinate, address)
                                return state
                            }
                        }
                    }))
                } else {
                    strongSelf.geocodingDisposable.set(nil)
                }
            }
        })
        
        if case let .share(_, selfPeer, _) = self.mode, let peer = selfPeer {
            self.headerNode.mapNode.userLocationAnnotation = LocationPinAnnotation(context: context, theme: self.presentationData.theme, peer: peer)
            self.headerNode.mapNode.hasPickerAnnotation = true
        }
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, listTransition in
            guard let strongSelf = self, let (layout, navigationBarHeight) = strongSelf.validLayout, strongSelf.listNode.scrollEnabled else {
                return
            }
            let overlap: CGFloat = 6.0
            strongSelf.listOffset = max(0.0, offset)
            let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: max(0.0, offset + overlap)))
            listTransition.updateFrame(node: strongSelf.headerNode, frame: headerFrame)
            strongSelf.headerNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: strongSelf.state.displayingMapModeOptions ? 38.0 : 0.0, offset: 0.0, size: headerFrame.size, transition: listTransition)
            strongSelf.layoutEmptyResultsPlaceholder(transition: listTransition)
        }
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
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
            strongSelf.beganInteractiveDragging()
            strongSelf.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .selecting
                state.searchingVenuesAround = false
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
                    state.searchingVenuesAround = false
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
                state.selectedLocation = annotation?.location.flatMap { .venue($0) } ?? .none
                if annotation == nil {
                    state.searchingVenuesAround = false
                }
                return state
            }
        }
        
        self.headerNode.mapNode.userLocationAnnotationSelected = { [weak self] in
            if let strongSelf = self {
                strongSelf.goToUserLocation()
            }
        }
        
        self.locationManager.manager.startUpdatingHeading()
        self.locationManager.manager.delegate = self
    }
    
    deinit {
        self.disposable?.dispose()
        self.geocodingDisposable.dispose()
        
        self.locationManager.manager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.headerNode.mapNode.userHeading = CGFloat(newHeading.magneticHeading)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationDataPromise.set(.single(presentationData))
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.headerNode.updatePresentationData(self.presentationData)
        self.optionsNode.updatePresentationData(self.presentationData)
        self.shadeNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.innerShadeNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.searchContainerNode?.updatePresentationData(self.presentationData)
    }
    
    func updateState(_ f: (LocationPickerState) -> LocationPickerState) {
        self.state = f(self.state)
        self.statePromise.set(.single(self.state))
    }
    
    private func enqueueTransition(_ transition: LocationPickerTransaction) {
        self.enqueuedTransitions.append(transition)
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        guard let _ = self.validLayout, let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if transition.crossFade {
            options.insert(.AnimateCrossfade)
        }
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.emptyResultsTextNode.isHidden = transition.isLoading || !transition.isEmpty
                
                strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.Map_NoPlacesNearby, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                
                strongSelf.layoutEmptyResultsPlaceholder(transition: .immediate)
            }
        })
    }
    
    func activateSearch(navigationBar: NavigationBar) -> Signal<Bool, NoError> {
        guard let (layout, navigationBarHeight) = self.validLayout, self.searchContainerNode == nil, let coordinate = self.headerNode.mapNode.mapCenterCoordinate else {
            return .complete()
        }
        
        let searchContainerNode = LocationSearchContainerNode(context: self.context, coordinate: coordinate, interaction: self.interaction)
        self.insertSubnode(searchContainerNode, belowSubnode: navigationBar)
        self.searchContainerNode = searchContainerNode
        
        searchContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        self.containerLayoutUpdated(layout, navigationHeight: navigationBarHeight, transition: .immediate)
        
        return searchContainerNode.isSearching
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
    
    private func layoutEmptyResultsPlaceholder(transition: ContainedViewLayoutTransition) {
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
        
        let actionsInset: CGFloat = 148.0
        let padding: CGFloat = 16.0
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - emptyTextSize.width) / 2.0), y: headerHeight + actionsInset + floor((layout.size.height - headerHeight - actionsInset - emptyTextSize.height - layout.intrinsicInsets.bottom) / 2.0)), size: emptyTextSize))
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = (layout, navigationHeight)
        
        let isPickingLocation = (self.state.selectedLocation.isCustom || self.state.forceSelection) && !self.state.searchingVenuesAround
        let optionsHeight: CGFloat = 38.0
        var actionHeight: CGFloat?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? LocationActionListItemNode {
                if actionHeight == nil {
                    actionHeight = itemNode.frame.height
                }
            }
        }
        
//        let topInset: CGFloat = floor((layout.size.height - navigationHeight) / 2.0 + navigationHeight)
        let topInset: CGFloat = 240.0
        let overlap: CGFloat = 6.0
        let headerHeight: CGFloat
        if isPickingLocation, let actionHeight = actionHeight {
            self.listOffset = topInset
            headerHeight = layout.size.height - actionHeight - layout.intrinsicInsets.bottom + overlap - 2.0
        } else if let listOffset = self.listOffset {
            headerHeight = max(0.0, listOffset + overlap)
        } else {
            headerHeight = topInset + overlap
        }
        let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: headerHeight))
        transition.updateFrame(node: self.headerNode, frame: headerFrame)
        
        self.headerNode.updateLayout(layout: layout, navigationBarHeight: navigationHeight, topPadding: self.state.displayingMapModeOptions ? optionsHeight : 0.0, offset: 0.0, size: headerFrame.size, transition: transition)
            
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let scrollToItem: ListViewScrollToItem?
        if isPickingLocation {
            scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: curve, directionHint: .Up)
        } else {
            scrollToItem = nil
        }
        
        let insets = UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), scrollIndicatorInsets: UIEdgeInsets(top: topInset + 3.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.listNode.scrollEnabled = !isPickingLocation
        
        var listFrame: CGRect = CGRect(origin: CGPoint(), size: layout.size)
        if isPickingLocation {
            listFrame.origin.y = headerHeight - topInset - overlap
        }
        transition.updateFrame(node: self.listNode, frame: listFrame)
        transition.updateAlpha(node: self.shadeNode, alpha: isPickingLocation ? 1.0 : 0.0)
        transition.updateFrame(node: self.shadeNode, frame: CGRect(x: 0.0, y: listFrame.minY + topInset + (actionHeight ?? 0.0) - 3.0, width: layout.size.width, height: 10000.0))
        self.shadeNode.isUserInteractionEnabled = isPickingLocation
        self.innerShadeNode.frame = CGRect(x: 0.0, y: 4.0, width: layout.size.width, height: 10000.0)
        self.innerShadeNode.alpha = layout.intrinsicInsets.bottom > 0.0 ? 1.0 : 0.0
        
        self.layoutEmptyResultsPlaceholder(transition: transition)
        
        if isFirstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        let optionsOffset: CGFloat = self.state.displayingMapModeOptions ? navigationHeight : navigationHeight - optionsHeight
        let optionsFrame = CGRect(x: 0.0, y: optionsOffset, width: layout.size.width, height: optionsHeight)
        transition.updateFrame(node: self.optionsNode, frame: optionsFrame)
        self.optionsNode.updateLayout(size: optionsFrame.size, leftInset: insets.left, rightInset: insets.right, transition: transition)
        self.optionsNode.isUserInteractionEnabled = self.state.displayingMapModeOptions
        
        if let searchContainerNode = self.searchContainerNode {
            searchContainerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
            searchContainerNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationHeight, transition: transition)
        }
        
        if self.locationAccessDenied {
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
            Queue.mainQueue().after(0.25) {
                self.controller?.updateTabBarAlpha(0.0, .immediate)
            }
            
            var placeholderTransition = transition
            let placeholderNode: LocationPlaceholderNode
            let backgroundNode: NavigationBackgroundNode
            if let current = self.placeholderNode, let background = self.placeholderBackgroundNode {
                placeholderNode = current
                backgroundNode = background
                
                backgroundNode.updateColor(color: self.presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
            } else {
                backgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.tabBar.backgroundColor)
                if let navigationBar = self.controller?.navigationBar {
                    self.insertSubnode(backgroundNode, belowSubnode: navigationBar)
                } else {
                    self.addSubnode(backgroundNode)
                }
                self.placeholderBackgroundNode = backgroundNode
                
                placeholderNode = LocationPlaceholderNode(content: .intro)
                placeholderNode.settingsPressed = { [weak self] in
                    self?.context.sharedContext.applicationBindings.openSettings()
                }
                self.insertSubnode(placeholderNode, aboveSubnode: backgroundNode)
                self.placeholderNode = placeholderNode
                
                placeholderTransition = .immediate
            }
            placeholderNode.update(layout: layout, theme: self.presentationData.theme, strings: self.presentationData.strings, transition: placeholderTransition)
            placeholderTransition.updateFrame(node: placeholderNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            let placeholderFrame = CGRect(origin: CGPoint(), size: layout.size)
            backgroundNode.update(size: placeholderFrame.size, transition: placeholderTransition)
            placeholderTransition.updateFrame(node: placeholderNode, frame: placeholderFrame)
        } else {
            if let placeholderNode = self.placeholderNode {
                self.placeholderNode = nil
                placeholderNode.removeFromSupernode()
            }
            if let placeholderBackgroundNode = self.placeholderBackgroundNode {
                self.placeholderBackgroundNode = nil
                placeholderBackgroundNode.removeFromSupernode()
            }
            
            self.controller?.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
            self.controller?.updateTabBarAlpha(1.0, .immediate)
        }
        
    }
    
    func updateSendActionHighlight(_ highlighted: Bool) {
        self.headerNode.updateHighlight(highlighted)
        self.shadeNode.backgroundColor = highlighted ? self.presentationData.theme.list.itemHighlightedBackgroundColor : self.presentationData.theme.list.plainBackgroundColor
    }
    
    func goToUserLocation() {
        self.searchVenuesPromise.set(.single(nil))
        self.updateState { state in
            var state = state
            state.displayingMapModeOptions = false
            state.selectedLocation = .none
            state.searchingVenuesAround = false
            return state
        }
    }
    
    func requestPlacesAtSelectedLocation() {
        if case let .location(coordinate, _) = self.state.selectedLocation {
            self.headerNode.mapNode.setMapCenter(coordinate: coordinate, animated: true)
            self.searchVenuesPromise.set(.single(coordinate))
            self.updateState { state in
                 var state = state
                 state.searchingVenuesAround = true
                 return state
             }
        }
    }
}
