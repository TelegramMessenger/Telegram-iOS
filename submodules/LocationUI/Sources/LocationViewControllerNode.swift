import Foundation
import UIKit
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
import TelegramUIPreferences
import TelegramNotices
import AccountContext
import AppBundle
import CoreLocation
import Geocoding
import DeviceAccess
import TooltipUI

func getLocation(from message: Message) -> TelegramMediaMap? {
    return message.media.first(where: { $0 is TelegramMediaMap } ) as? TelegramMediaMap
}

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
    let gotTravelTimes: Bool
    let count: Int
}

private enum LocationViewEntryId: Hashable {
    case info
    case toggleLiveLocation
    case liveLocation(UInt32)
}

private enum LocationViewEntry: Comparable, Identifiable {
    case info(PresentationTheme, TelegramMediaMap, String?, Double?, ExpectedTravelTime, ExpectedTravelTime, ExpectedTravelTime)
    case toggleLiveLocation(PresentationTheme, String, String, Double?, Double?)
    case liveLocation(PresentationTheme, PresentationDateTimeFormat, PresentationPersonNameOrder, Message, Double?, ExpectedTravelTime, ExpectedTravelTime, ExpectedTravelTime, Int)
    
    var stableId: LocationViewEntryId {
        switch self {
            case .info:
                return .info
            case .toggleLiveLocation:
                return .toggleLiveLocation
            case let .liveLocation(_, _, _, message, _, _, _, _, _):
                return .liveLocation(message.stableId)
        }
    }
    
    static func ==(lhs: LocationViewEntry, rhs: LocationViewEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsLocation, lhsAddress, lhsDistance, lhsDrivingTime, lhsTransitTime, lhsWalkingTime):
                if case let .info(rhsTheme, rhsLocation, rhsAddress, rhsDistance, rhsDrivingTime, rhsTransitTime, rhsWalkingTime) = rhs, lhsTheme === rhsTheme, lhsLocation.venue?.id == rhsLocation.venue?.id, lhsAddress == rhsAddress, lhsDistance == rhsDistance, lhsDrivingTime == rhsDrivingTime, lhsTransitTime == rhsTransitTime, lhsWalkingTime == rhsWalkingTime {
                    return true
                } else {
                    return false
                }
            case let .toggleLiveLocation(lhsTheme, lhsTitle, lhsSubtitle, lhsBeginTimestamp, lhsTimeout):
                if case let .toggleLiveLocation(rhsTheme, rhsTitle, rhsSubtitle, rhsBeginTimestamp, rhsTimeout) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsBeginTimestamp == rhsBeginTimestamp, lhsTimeout == rhsTimeout {
                    return true
                } else {
                    return false
                }
            case let .liveLocation(lhsTheme, lhsDateTimeFormat, lhsNameDisplayOrder, lhsMessage, lhsDistance, lhsDrivingTime, lhsTransitTime, lhsWalkingTime, lhsIndex):
                if case let .liveLocation(rhsTheme, rhsDateTimeFormat, rhsNameDisplayOrder, rhsMessage, rhsDistance, rhsDrivingTime, rhsTransitTime, rhsWalkingTime, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameDisplayOrder == rhsNameDisplayOrder, areMessagesEqual(lhsMessage, rhsMessage), lhsDistance == rhsDistance, lhsDrivingTime == rhsDrivingTime, lhsTransitTime == rhsTransitTime, lhsWalkingTime == rhsWalkingTime, lhsIndex == rhsIndex {
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
            case let .liveLocation(_, _, _, _, _, _, _, _, lhsIndex):
                switch rhs {
                    case .info, .toggleLiveLocation:
                        return false
                    case let .liveLocation(_, _, _, _, _, _, _, _, rhsIndex):
                        return lhsIndex < rhsIndex
                }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, interaction: LocationViewInteraction?) -> ListViewItem {
        switch self {
            case let .info(_, location, address, distance, drivingTime, transitTime, walkingTime):
                let addressString: String?
                if let address = address {
                    addressString = address
                } else {
                    addressString = presentationData.strings.Map_Locating
                }
                let distanceString: String?
                if let distance = distance {
                    distanceString = distance < 10 ? presentationData.strings.Map_YouAreHere : presentationData.strings.Map_DistanceAway(stringForDistance(strings: presentationData.strings, distance: distance)).string
                } else {
                    distanceString = nil
                }
                return LocationInfoListItem(presentationData: ItemListPresentationData(presentationData), engine: context.engine, location: location, address: addressString, distance: distanceString, drivingTime: drivingTime, transitTime: transitTime, walkingTime: walkingTime, action: {
                    interaction?.goToCoordinate(location.coordinate)
                }, drivingAction: {
                    interaction?.requestDirections(location, nil, .driving)
                }, transitAction: {
                    interaction?.requestDirections(location, nil, .transit)
                }, walkingAction: {
                    interaction?.requestDirections(location, nil, .walking)
                })
            case let .toggleLiveLocation(_, title, subtitle, beginTimstamp, timeout):
                let beginTimeAndTimeout: (Double, Double)?
                if let beginTimstamp = beginTimstamp, let timeout = timeout {
                    beginTimeAndTimeout = (beginTimstamp, timeout)
                } else {
                    beginTimeAndTimeout = nil
                }
                return LocationActionListItem(presentationData: ItemListPresentationData(presentationData), engine: context.engine, title: title, subtitle: subtitle, icon: beginTimeAndTimeout != nil ? .stopLiveLocation : .liveLocation, beginTimeAndTimeout: beginTimeAndTimeout, action: {
                    if beginTimeAndTimeout != nil {
                        interaction?.stopLiveLocation()
                    } else {
                        interaction?.sendLiveLocation(nil)
                    }
                }, highlighted: { highlight in
                    interaction?.updateSendActionHighlight(highlight)
                })
            case let .liveLocation(_, dateTimeFormat, nameDisplayOrder, message, distance, drivingTime, transitTime, walkingTime, _):
                var title: String?
                if let author = message.author {
                    title = EnginePeer(author).displayTitle(strings: presentationData.strings, displayOrder: nameDisplayOrder)
                }
                return LocationLiveListItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: context, message: message, distance: distance, drivingTime: drivingTime, transitTime: transitTime, walkingTime: walkingTime, action: {
                    if let location = getLocation(from: message) {
                        interaction?.goToCoordinate(location.coordinate)
                    }
                }, longTapAction: {}, drivingAction: {
                    if let location = getLocation(from: message) {
                        interaction?.requestDirections(location, title, .driving)
                    }
                }, transitAction: {
                    if let location = getLocation(from: message) {
                        interaction?.requestDirections(location, title, .transit)
                    }
                }, walkingAction: {
                    if let location = getLocation(from: message) {
                        interaction?.requestDirections(location, title, .walking)
                    }
                })
        }
    }
}

private func preparedTransition(from fromEntries: [LocationViewEntry], to toEntries: [LocationViewEntry], context: AccountContext, presentationData: PresentationData, interaction: LocationViewInteraction?, gotTravelTimes: Bool) -> LocationViewTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return LocationViewTransaction(deletions: deletions, insertions: insertions, updates: updates, gotTravelTimes: gotTravelTimes, count: toEntries.count)
}

enum LocationViewLocation: Equatable {
    case initial
    case user
    case coordinate(CLLocationCoordinate2D, Bool)
    case custom
}

struct LocationViewState {
    var mapMode: LocationMapMode
    var displayingMapModeOptions: Bool
    var selectedLocation: LocationViewLocation
    var trackingMode: LocationTrackingMode
    var updatingProximityRadius: Int32?
    var cancellingProximityRadius: Bool
    
    init() {
        self.mapMode = .map
        self.displayingMapModeOptions = false
        self.selectedLocation = .initial
        self.trackingMode = .none
        self.updatingProximityRadius = nil
        self.cancellingProximityRadius = false
    }
}

final class LocationViewControllerNode: ViewControllerTracingNode, CLLocationManagerDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let presentationDataPromise: Promise<PresentationData>
    private var subject: Message
    private let interaction: LocationViewInteraction
    private let locationManager: LocationManager
    
    private let listNode: ListView
    let headerNode: LocationMapHeaderNode
    private let optionsNode: LocationOptionsNode
    
    private var enqueuedTransitions: [LocationViewTransaction] = []
    
    private var disposable: Disposable?
    private var state: LocationViewState
    private let statePromise: Promise<LocationViewState>
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    private var listOffset: CGFloat?
    
    private var displayedProximityAlertTooltip = false
    
    var reportedAnnotationsReady = false
    var onAnnotationsReady: (() -> Void)?
    
    private let travelDisposables = DisposableSet()
    private var travelTimes: [EngineMessage.Id: (Double, ExpectedTravelTime, ExpectedTravelTime, ExpectedTravelTime)] = [:] {
        didSet {
            self.travelTimesPromise.set(.single(self.travelTimes))
        }
    }
    private let travelTimesPromise = Promise<[EngineMessage.Id: (Double, ExpectedTravelTime, ExpectedTravelTime, ExpectedTravelTime)]>([:])

    init(context: AccountContext, presentationData: PresentationData, subject: Message, interaction: LocationViewInteraction, locationManager: LocationManager) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(presentationData)
        self.subject = subject
        self.interaction = interaction
        self.locationManager = locationManager
        
        self.state = LocationViewState()
        self.statePromise = Promise(self.state)
        
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        var setupProximityNotificationImpl: ((Bool) -> Void)?
        self.headerNode = LocationMapHeaderNode(presentationData: presentationData, toggleMapModeSelection: interaction.toggleMapModeSelection, goToUserLocation: interaction.toggleTrackingMode, setupProximityNotification: { reset in
            setupProximityNotificationImpl?(reset)
        })
        self.headerNode.mapNode.isRotateEnabled = false
        
        self.optionsNode = LocationOptionsNode(presentationData: presentationData, updateMapMode: interaction.updateMapMode)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.headerNode)
        self.addSubnode(self.optionsNode)
        
        let userLocation: Signal<CLLocation?, NoError> = .single(nil)
        |> then(
            throttledUserLocation(self.headerNode.mapNode.userLocation)
        )
        
        var eta: Signal<(ExpectedTravelTime, ExpectedTravelTime, ExpectedTravelTime), NoError> = .single((.calculating, .calculating, .calculating))
        var address: Signal<String?, NoError> = .single(nil)
        
        if let location = getLocation(from: subject), location.liveBroadcastingTimeout == nil {
            eta = .single((.calculating, .calculating, .calculating))
            |> then(combineLatest(queue: Queue.mainQueue(), getExpectedTravelTime(coordinate: location.coordinate, transportType: .automobile), getExpectedTravelTime(coordinate: location.coordinate, transportType: .transit), getExpectedTravelTime(coordinate: location.coordinate, transportType: .walking))
            |> mapToSignal { drivingTime, transitTime, walkingTime -> Signal<(ExpectedTravelTime, ExpectedTravelTime, ExpectedTravelTime), NoError> in
                if case .calculating = drivingTime {
                    return .complete()
                }
                if case .calculating = transitTime {
                    return .complete()
                }
                if case .calculating = walkingTime {
                    return .complete()
                }
                
                return .single((drivingTime, transitTime, walkingTime))
            })
            
            if let venue = location.venue, let venueAddress = venue.address, !venueAddress.isEmpty {
                address = .single(venueAddress)
            } else {
                address = .single(nil)
                |> then(
                    reverseGeocodeLocation(latitude: location.latitude, longitude: location.longitude)
                    |> map { placemark -> String? in
                        return placemark?.compactDisplayAddress ?? ""
                    }
                )
            }
        }
        
        let liveLocations = context.engine.messages.topPeerActiveLiveLocationMessages(peerId: subject.id.peerId)
        |> map { _, messages -> [Message] in
            return messages
        }
        
        setupProximityNotificationImpl = { reset in
            let _ = (liveLocations
            |> take(1)
            |> deliverOnMainQueue).start(next: { messages in
                var ownMessageId: MessageId?
                for message in messages {
                    if message.localTags.contains(.OutgoingLiveLocation) {
                        ownMessageId = message.id
                        break
                    }
                }
                interaction.setupProximityNotification(reset, ownMessageId)
                
                let _ = ApplicationSpecificNotice.incrementLocationProximityAlertTip(accountManager: context.sharedContext.accountManager, count: 4).start()
            })
        }
        
        let previousState = Atomic<LocationViewState?>(value: nil)
        let previousUserAnnotation = Atomic<LocationPinAnnotation?>(value: nil)
        let previousAnnotations = Atomic<[LocationPinAnnotation]>(value: [])
        let previousEntries = Atomic<[LocationViewEntry]?>(value: nil)
        let previousHadTravelTimes = Atomic<Bool>(value: false)
        
        let selfPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        
        self.disposable = (combineLatest(self.presentationDataPromise.get(), self.statePromise.get(), selfPeer, liveLocations, self.headerNode.mapNode.userLocation, userLocation, address, eta, self.travelTimesPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, selfPeer, liveLocations, userLocation, distance, address, eta, travelTimes in
            if let strongSelf = self, let location = getLocation(from: subject) {
                var entries: [LocationViewEntry] = []
                var annotations: [LocationPinAnnotation] = []
                var userAnnotation: LocationPinAnnotation? = nil
                var effectiveLiveLocations: [Message] = liveLocations
                
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                
                var proximityNotification: Bool? = nil
                var proximityNotificationRadius: Int32?
                var index: Int = 0
                
                var isLocationView = false
                if location.liveBroadcastingTimeout == nil {
                    isLocationView = true
                    
                    let subjectLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let distance = userLocation.flatMap { subjectLocation.distance(from: $0) }
                    
                    entries.append(.info(presentationData.theme, location, address, distance, eta.0, eta.1, eta.2))
                    
                    annotations.append(LocationPinAnnotation(context: context, theme: presentationData.theme, location: location, forcedSelection: true))
                } else {
                    var activeOwnLiveLocation: Message?
                    for message in effectiveLiveLocations {
                        if message.localTags.contains(.OutgoingLiveLocation) {
                            activeOwnLiveLocation = message
                            if let location = getLocation(from: message), let radius = location.liveProximityNotificationRadius {
                                proximityNotificationRadius = radius
                                proximityNotification = true
                            }
                            break
                        }
                    }
                                        
                    let title: String
                    let subtitle: String
                    let beginTime: Double?
                    let timeout: Double?
                    
                    if let message = activeOwnLiveLocation {
                        var liveBroadcastingTimeout: Int32 = 0
                        if let location = getLocation(from: message), let timeout = location.liveBroadcastingTimeout {
                            liveBroadcastingTimeout = timeout
                        }
                        title = presentationData.strings.Map_StopLiveLocation
                        
                        var updateTimestamp = message.timestamp
                        for attribute in message.attributes {
                            if let attribute = attribute as? EditedMessageAttribute {
                                updateTimestamp = attribute.date
                                break
                            }
                        }
                        
                        subtitle = stringForRelativeLiveLocationTimestamp(strings: presentationData.strings, relativeTimestamp: updateTimestamp, relativeTo: currentTime, dateTimeFormat: presentationData.dateTimeFormat)
                        beginTime = Double(message.timestamp)
                        timeout = Double(liveBroadcastingTimeout)
                    } else {
                        title = presentationData.strings.Map_ShareLiveLocation
                        subtitle = presentationData.strings.Map_ShareLiveLocationHelp
                        beginTime = nil
                        timeout = nil
                    }
                    
                    if let channel = subject.author as? TelegramChannel, case .broadcast = channel.info, activeOwnLiveLocation == nil {
                    } else {
                        entries.append(.toggleLiveLocation(presentationData.theme, title, subtitle, beginTime, timeout))
                    }
                    
                    var sortedLiveLocations: [Message] = []
                    
                    var effectiveSubject: Message?
                    for message in effectiveLiveLocations {
                        if message.id == subject.id {
                            effectiveSubject = message
                        } else {
                            sortedLiveLocations.append(message)
                        }
                    }
                    if let effectiveSubject = effectiveSubject {
                        sortedLiveLocations.insert(effectiveSubject, at: 0)
                    } else {
                        sortedLiveLocations.insert(subject, at: 0)
                    }
                    effectiveLiveLocations = sortedLiveLocations
                }
                        
                for message in effectiveLiveLocations {
                    if let location = getLocation(from: message) {
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info, message.threadId != nil {
                            continue
                        }
                        
                        var liveBroadcastingTimeout: Int32 = 0
                        if let timeout = location.liveBroadcastingTimeout {
                            liveBroadcastingTimeout = timeout
                        }
                        let remainingTime = max(0, message.timestamp + liveBroadcastingTimeout - currentTime)
                        if message.flags.contains(.Incoming) && remainingTime != 0 && proximityNotification == nil {
                            proximityNotification = false
                        }
                        
                        let subjectLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                        let distance = userLocation.flatMap { subjectLocation.distance(from: $0) }
                        
                        let timestamp = CACurrentMediaTime()
                        if message.localTags.contains(.OutgoingLiveLocation), let selfPeer = selfPeer {
                            userAnnotation = LocationPinAnnotation(context: context, theme: presentationData.theme, message: message, selfPeer: selfPeer._asPeer(), isSelf: true, heading: location.heading)
                        } else {
                            var drivingTime: ExpectedTravelTime = .unknown
                            var transitTime: ExpectedTravelTime = .unknown
                            var walkingTime: ExpectedTravelTime = .unknown
                            
                            if !isLocationView && message.author?.id != context.account.peerId {
                                let signal = combineLatest(queue: Queue.mainQueue(), getExpectedTravelTime(coordinate: location.coordinate, transportType: .automobile), getExpectedTravelTime(coordinate: location.coordinate, transportType: .transit), getExpectedTravelTime(coordinate: location.coordinate, transportType: .walking))
                                |> mapToSignal { drivingTime, transitTime, walkingTime -> Signal<(ExpectedTravelTime, ExpectedTravelTime, ExpectedTravelTime), NoError> in
                                    if case .calculating = drivingTime {
                                        return .complete()
                                    }
                                    if case .calculating = transitTime {
                                        return .complete()
                                    }
                                    if case .calculating = walkingTime {
                                        return .complete()
                                    }
                                    
                                    return .single((drivingTime, transitTime, walkingTime))
                                }
                                
                                if let (previousTimestamp, maybeDrivingTime, maybeTransitTime, maybeWalkingTime) = travelTimes[message.id] {
                                    drivingTime = maybeDrivingTime
                                    transitTime = maybeTransitTime
                                    walkingTime = maybeWalkingTime
                                    
                                    if timestamp > previousTimestamp + 60.0 {
                                        strongSelf.travelDisposables.add(signal.start(next: { [weak self] drivingTime, transitTime, walkingTime in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            let timestamp = CACurrentMediaTime()
                                            var travelTimes = strongSelf.travelTimes
                                            travelTimes[message.id] = (timestamp, drivingTime, transitTime, walkingTime)
                                            strongSelf.travelTimes = travelTimes
                                        }))
                                    }
                                } else {
                                    drivingTime = .calculating
                                    transitTime = .calculating
                                    walkingTime = .calculating
                                    
                                    strongSelf.travelDisposables.add(signal.start(next: { [weak self] drivingTime, transitTime, walkingTime in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let timestamp = CACurrentMediaTime()
                                        var travelTimes = strongSelf.travelTimes
                                        travelTimes[message.id] = (timestamp, drivingTime, transitTime, walkingTime)
                                        strongSelf.travelTimes = travelTimes
                                    }))
                                }
                            }
                            
                            annotations.append(LocationPinAnnotation(context: context, theme: presentationData.theme, message: message, selfPeer: selfPeer?._asPeer(), isSelf: message.author?.id == context.account.peerId, heading: location.heading))
                            entries.append(.liveLocation(presentationData.theme, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, message, distance, drivingTime, transitTime, walkingTime, index))
                        }
                        index += 1
                    }
                }
                
                if let currentProximityNotification = proximityNotification, currentProximityNotification && state.cancellingProximityRadius {
                    proximityNotification = false
                    proximityNotificationRadius = nil
                } else if let radius = state.updatingProximityRadius {
                    proximityNotification = true
                    proximityNotificationRadius = radius
                }
                
                if subject.id.peerId.namespace != Namespaces.Peer.CloudUser, proximityNotification == nil {
                    proximityNotification = false
                }
                if let channel = subject.author as? TelegramChannel, case .broadcast = channel.info {
                    proximityNotification = nil
                }
                
                let previousEntries = previousEntries.swap(entries)
                let previousState = previousState.swap(state)
                let previousHadTravelTimes = previousHadTravelTimes.swap(!travelTimes.isEmpty)
                
                let transition = preparedTransition(from: previousEntries ?? [], to: entries, context: context, presentationData: presentationData, interaction: strongSelf.interaction, gotTravelTimes: !travelTimes.isEmpty && !previousHadTravelTimes)
                strongSelf.enqueueTransition(transition)
                
                strongSelf.headerNode.updateState(mapMode: state.mapMode, trackingMode: state.trackingMode, displayingMapModeOptions: state.displayingMapModeOptions, displayingPlacesButton: false, proximityNotification: proximityNotification, animated: false)
                
                if let proximityNotification = proximityNotification, !proximityNotification && !strongSelf.displayedProximityAlertTooltip {
                    strongSelf.displayedProximityAlertTooltip = true
                    
                    let _ = (ApplicationSpecificNotice.getLocationProximityAlertTip(accountManager: context.sharedContext.accountManager)
                    |> deliverOnMainQueue).start(next: { [weak self] counter in
                        if let strongSelf = self, counter < 3 {
                            let _ = ApplicationSpecificNotice.incrementLocationProximityAlertTip(accountManager: context.sharedContext.accountManager).start()
                            strongSelf.displayProximityAlertTooltip()
                        }
                    })
                }
                
                switch state.selectedLocation {
                    case .initial:
                        if previousState?.selectedLocation != .initial {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: location.coordinate, span: viewMapSpan, animated: previousState != nil)
                        }
                    case let .coordinate(coordinate, defaultSpan):
                        if let previousState = previousState, case let .coordinate(previousCoordinate, _) = previousState.selectedLocation, previousCoordinate == coordinate {
                        } else {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: coordinate, span: defaultSpan ? defaultMapSpan : viewMapSpan, animated: true)
                        }
                    case .user:
                        if previousState?.selectedLocation != .user, let userLocation = userLocation {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: userLocation.coordinate, isUserLocation: true, animated: true)
                        }
                    case .custom:
                        break
                }
                strongSelf.headerNode.mapNode.trackingMode = state.trackingMode
                
                let previousAnnotations = previousAnnotations.swap(annotations)
                let previousUserAnnotation = previousUserAnnotation.swap(userAnnotation)
                if (userAnnotation == nil) != (previousUserAnnotation == nil) {
                    strongSelf.headerNode.mapNode.userLocationAnnotation = userAnnotation
                }
                if annotations != previousAnnotations {
                    strongSelf.headerNode.mapNode.annotations = annotations
                    
                    if !strongSelf.reportedAnnotationsReady {
                        strongSelf.reportedAnnotationsReady = true
                        if annotations.count > 0 {
                            strongSelf.onAnnotationsReady?()
                        }
                    }
                }
                
                if let _ = proximityNotification {
                    strongSelf.headerNode.mapNode.activeProximityRadius = proximityNotificationRadius.flatMap { Double($0)  }
                } else {
                    strongSelf.headerNode.mapNode.activeProximityRadius = nil
                }
                let rightBarButtonAction: LocationViewRightBarButton
                if location.liveBroadcastingTimeout != nil {
                    if annotations.count > 0 {
                        rightBarButtonAction = .showAll
                    } else {
                        rightBarButtonAction = .none
                    }
                } else {
                    rightBarButtonAction = .share
                }
                strongSelf.interaction.updateRightBarButton(rightBarButtonAction)
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    var updateLayout = false
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
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
            strongSelf.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .custom
                state.trackingMode = .none
                return state
            }
        }
        
        self.headerNode.mapNode.annotationSelected = { [weak self] annotation in
            guard let strongSelf = self else {
                return
            }
            if let annotation = annotation {
                strongSelf.interaction.goToCoordinate(annotation.coordinate)
            }
        }
        
        self.headerNode.mapNode.userLocationAnnotationSelected = { [weak self] in
            if let strongSelf = self, let location = strongSelf.headerNode.mapNode.currentUserLocation {
                strongSelf.interaction.goToCoordinate(location.coordinate)
            }
        }
        
        self.locationManager.manager.startUpdatingHeading()
        self.locationManager.manager.delegate = self
    }
    
    deinit {
        self.disposable?.dispose()
        self.travelDisposables.dispose()
        self.locationManager.manager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy < 0.0 {
            self.headerNode.mapNode.userHeading = nil
        }
        if newHeading.trueHeading > 0.0 {
            self.headerNode.mapNode.userHeading = CGFloat(newHeading.trueHeading)
        } else {
            self.headerNode.mapNode.userHeading = CGFloat(newHeading.magneticHeading)
        }
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
    
    func updateSendActionHighlight(_ highlighted: Bool) {
        self.headerNode.updateHighlight(highlighted)
    }
    
    private func enqueueTransition(_ transition: LocationViewTransaction) {
        self.enqueuedTransitions.append(transition)
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    var initialized = false
    private func dequeueTransition() {
        guard let _ = self.validLayout, let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        let scrollToItem: ListViewScrollToItem?
        if (!self.initialized && transition.insertions.count > 0) || transition.gotTravelTimes {
            var index: Int = 0
            var offset: CGFloat = 0.0
            if transition.gotTravelTimes {
                if transition.count > 1 {
                    index = 1
                } else {
                    index = 0
                }
                offset = 0.0
            } else if transition.insertions.count > 2 {
                index = 2
                offset = 40.0
            } else if transition.insertions.count == 2 {
                index = 1
            }
            
            scrollToItem = ListViewScrollToItem(index: index, position: .bottom(offset), animated: transition.gotTravelTimes, curve: .Default(duration: 0.3), directionHint: .Up)
            self.initialized = true
        } else {
            scrollToItem = nil
        }
        
        let options = ListViewDeleteAndInsertOptions()
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    func setProximityIndicator(radius: Int32?) {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        if let radius = radius {
            self.headerNode.forceIsHidden = true
            
            if let coordinate = self.headerNode.mapNode.currentUserLocation?.coordinate {
                self.updateState { state in
                    var state = state
                    state.selectedLocation = .custom
                    state.trackingMode = .none
                    return state
                }
                
                var contentOffset: CGFloat = 0.0
                if case let .known(offset) = self.listNode.visibleContentOffset() {
                    contentOffset = offset
                }
                
                let panelHeight: CGFloat = 349.0 + layout.intrinsicInsets.bottom
                let inset = (layout.size.width - 260.0) / 2.0
                let offset = panelHeight / 2.0 + 60.0 + inset + navigationBarHeight / 2.0
                
                let point = CGPoint(x: layout.size.width / 2.0, y: navigationBarHeight + (layout.size.height - navigationBarHeight - panelHeight) / 2.0)
                let convertedPoint = self.view.convert(point, to: self.headerNode.mapNode.view)
                
                self.headerNode.mapNode.setMapCenter(coordinate: coordinate, radius: Double(radius), insets: UIEdgeInsets(top: navigationBarHeight, left: inset, bottom: offset - contentOffset, right: inset), offset: convertedPoint.y - self.headerNode.mapNode.frame.height / 2.0, animated: true)
            }
            
            self.headerNode.mapNode.proximityIndicatorRadius = Double(radius)
        } else {
            self.headerNode.forceIsHidden = false
            self.headerNode.mapNode.proximityIndicatorRadius = nil
            self.updateState { state in
                var state = state
                state.selectedLocation = .user
                state.trackingMode = .none
                return state
            }
        }
    }
    
    func showAll() {
        self.headerNode.mapNode.showAll()
    }
    
    private func displayProximityAlertTooltip() {
        guard let location = self.headerNode.proximityButtonFrame().flatMap({ frame -> CGRect in
            return self.headerNode.view.convert(frame, to: nil)
        }) else {
            return
        }
        
        let _ = (self.context.account.postbox.loadedPeerWithId(self.subject.id.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
          
            var text: String = strongSelf.presentationData.strings.Location_ProximityGroupTip
            if peer.id.namespace == Namespaces.Peer.CloudUser {
                text = strongSelf.presentationData.strings.Location_ProximityTip(EnginePeer(peer).compactDisplayTitle).string
            }
            
            strongSelf.interaction.present(TooltipScreen(account: strongSelf.context.account, text: text, icon: nil, location: .point(location.offsetBy(dx: -9.0, dy: 0.0), .right), displayDuration: .custom(3.0), shouldDismissOnTouch: { _ in
                return .dismiss(consume: false)
            }))
        })
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
        var topInset: CGFloat = layout.size.height - layout.intrinsicInsets.bottom - 100.0 - overlap
        if let location = getLocation(from: self.subject), location.liveBroadcastingTimeout != nil {
            topInset += 66.0
        }
        
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
        self.optionsNode.isUserInteractionEnabled = self.state.displayingMapModeOptions
    }
    
    var coordinate: Signal<CLLocationCoordinate2D, NoError> {
        return self.headerNode.mapNode.userLocation
        |> filter { location in
            return location != nil
        }
        |> take(1)
        |> map { location -> CLLocationCoordinate2D in
            return location!.coordinate
        }
    }
}
