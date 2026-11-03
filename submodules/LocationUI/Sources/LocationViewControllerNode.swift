import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
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
import ComponentFlow
import GlassControls
import BundleIconComponent
import EdgeEffect
import MultilineTextComponent
import GlassBackgroundComponent
import Weather

func getLocation(from message: EngineMessage) -> TelegramMediaMap? {
    if let poll = message.media.first(where: { $0 is TelegramMediaPoll } ) as? TelegramMediaPoll, let map = poll.attachedMedia as? TelegramMediaMap {
        return map
    } else {
        return message.media.first(where: { $0 is TelegramMediaMap } ) as? TelegramMediaMap
    }
}

private func areMessagesEqual(_ lhsMessage: EngineMessage, _ rhsMessage: EngineMessage) -> Bool {
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
    let animated: Bool
}

public enum LocationViewEntryId: Hashable {
    case info
    case toggleLiveLocation(Bool)
    case liveLocation(UInt32)
}

public enum LocationViewEntry: Comparable, Identifiable {
    case info(PresentationTheme, TelegramMediaMap, String?, Double?, ExpectedTravelTime, ExpectedTravelTime, Bool)
    case toggleLiveLocation(PresentationTheme, String, String, Double?, Double?, Bool, EngineMessage.Id?)
    case liveLocation(PresentationTheme, PresentationDateTimeFormat, PresentationPersonNameOrder, EngineMessage, Double?, ExpectedTravelTime, ExpectedTravelTime, Int)
    
    public var stableId: LocationViewEntryId {
        switch self {
        case .info:
            return .info
        case let .toggleLiveLocation(_, _, _, _, _, additional, _):
            return .toggleLiveLocation(additional)
        case let .liveLocation(_, _, _, message, _, _, _, _):
            return .liveLocation(message.stableId)
        }
    }
    
    public static func ==(lhs: LocationViewEntry, rhs: LocationViewEntry) -> Bool {
        switch lhs {
        case let .info(lhsTheme, lhsLocation, lhsAddress, lhsDistance, lhsDrivingTime, lhsWalkingTime, lhsHasEta):
            if case let .info(rhsTheme, rhsLocation, rhsAddress, rhsDistance, rhsDrivingTime, rhsWalkingTime, rhsHasEta) = rhs, lhsTheme === rhsTheme, lhsLocation.venue?.id == rhsLocation.venue?.id, lhsAddress == rhsAddress, lhsDistance == rhsDistance, lhsDrivingTime == rhsDrivingTime, lhsWalkingTime == rhsWalkingTime, lhsHasEta == rhsHasEta {
                return true
            } else {
                return false
            }
        case let .toggleLiveLocation(lhsTheme, lhsTitle, lhsSubtitle, lhsBeginTimestamp, lhsTimeout, lhsAdditional, lhsMessageId):
            if case let .toggleLiveLocation(rhsTheme, rhsTitle, rhsSubtitle, rhsBeginTimestamp, rhsTimeout, rhsAdditional, rhsMessageId) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsBeginTimestamp == rhsBeginTimestamp, lhsTimeout == rhsTimeout, lhsAdditional == rhsAdditional, lhsMessageId == rhsMessageId {
                return true
            } else {
                return false
            }
        case let .liveLocation(lhsTheme, lhsDateTimeFormat, lhsNameDisplayOrder, lhsMessage, lhsDistance, lhsDrivingTime, lhsWalkingTime, lhsIndex):
            if case let .liveLocation(rhsTheme, rhsDateTimeFormat, rhsNameDisplayOrder, rhsMessage, rhsDistance, rhsDrivingTime, rhsWalkingTime, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameDisplayOrder == rhsNameDisplayOrder, areMessagesEqual(lhsMessage, rhsMessage), lhsDistance == rhsDistance, lhsDrivingTime == rhsDrivingTime, lhsWalkingTime == rhsWalkingTime, lhsIndex == rhsIndex {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func <(lhs: LocationViewEntry, rhs: LocationViewEntry) -> Bool {
        switch lhs {
        case .info:
            switch rhs {
            case .info:
                return false
            case .toggleLiveLocation, .liveLocation:
                return true
            }
        case let .toggleLiveLocation(_, _, _, _, _, lhsAdditional, _):
            switch rhs {
            case .info:
                return false
            case let .toggleLiveLocation(_, _, _, _, _, rhsAdditional, _):
                return !lhsAdditional && rhsAdditional
            case .liveLocation:
                return true
            }
        case let .liveLocation(_, _, _, _, _, _, _, lhsIndex):
            switch rhs {
            case .info, .toggleLiveLocation:
                return false
            case let .liveLocation(_, _, _, _, _, _, _, rhsIndex):
                return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, interaction: LocationViewInteraction?) -> ListViewItem {
        switch self {
        case let .info(_, location, address, distance, drivingTime, walkingTime, hasEta):
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
            return LocationInfoListItem(presentationData: ItemListPresentationData(presentationData), engine: context.engine, location: location, address: addressString, distance: distanceString, drivingTime: drivingTime, walkingTime: walkingTime, hasEta: hasEta, action: {
                interaction?.goToCoordinate(location.coordinate)
            }, drivingAction: {
                interaction?.requestDirections(location, nil, .driving)
            }, walkingAction: {
                interaction?.requestDirections(location, nil, .walking)
            })
        case let .toggleLiveLocation(_, title, subtitle, beginTimstamp, timeout, additional, messageId):
            var beginTimeAndTimeout: (Double, Double)?
            if let beginTimstamp = beginTimstamp, let timeout = timeout {
                beginTimeAndTimeout = (beginTimstamp, timeout)
            } else {
                beginTimeAndTimeout = nil
            }
            
            let icon: LocationActionListItemIcon
            if let timeout, Int32(timeout) != liveLocationIndefinitePeriod, !additional {
                icon = .extendLiveLocation
            } else if beginTimeAndTimeout != nil {
                icon = .stopLiveLocation
            } else {
                icon = .liveLocation
            }
            
            return LocationActionListItem(presentationData: ItemListPresentationData(presentationData), engine: context.engine, title: title, subtitle: subtitle, icon: icon, isOpaque: false, beginTimeAndTimeout: !additional ? beginTimeAndTimeout : nil, action: {
                if beginTimeAndTimeout != nil {
                    if let timeout, Int32(timeout) != liveLocationIndefinitePeriod {
                        if additional {
                            interaction?.stopLiveLocation()
                        } else {
                            interaction?.sendLiveLocation(nil, true, messageId)
                        }
                    } else {
                        interaction?.stopLiveLocation()
                    }
                } else {
                    interaction?.sendLiveLocation(nil, false, nil)
                }
            }, highlighted: { _ in
            })
        case let .liveLocation(_, dateTimeFormat, nameDisplayOrder, message, distance, drivingTime, walkingTime, _):
            var title: String?
            if let author = message.author {
                title = author.displayTitle(strings: presentationData.strings, displayOrder: nameDisplayOrder)
            }
            return LocationLiveListItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: context, message: message, distance: distance, drivingTime: drivingTime, walkingTime: walkingTime, action: {
                if let location = getLocation(from: message) {
                    interaction?.goToCoordinate(location.coordinate)
                }
            }, longTapAction: {}, drivingAction: {
                if let location = getLocation(from: message) {
                    interaction?.requestDirections(location, title, .driving)
                }
            }, walkingAction: {
                if let location = getLocation(from: message) {
                    interaction?.requestDirections(location, title, .walking)
                }
            })
        }
    }
}

private func preparedTransition(from fromEntries: [LocationViewEntry], to toEntries: [LocationViewEntry], context: AccountContext, presentationData: PresentationData, interaction: LocationViewInteraction?, gotTravelTimes: Bool, animated: Bool) -> LocationViewTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return LocationViewTransaction(deletions: deletions, insertions: insertions, updates: updates, gotTravelTimes: gotTravelTimes, count: toEntries.count, animated: animated)
}

enum LocationViewRightBarButton {
    case none
    case share
    case showAll
}

public enum LocationViewLocation: Equatable {
    case initial
    case user
    case coordinate(CLLocationCoordinate2D, Bool)
    case custom
    
    public static func ==(lhs: LocationViewLocation, rhs: LocationViewLocation) -> Bool {
        switch lhs {
        case .initial:
            if case .initial = rhs {
                return true
            } else {
                return false
            }
        case .user:
            if case .user = rhs {
                return true
            } else {
                return false
            }
        case let .coordinate(lhsCoordinate, lhsValue):
            if case let .coordinate(rhsCoordinate, rhsValue) = rhs, locationCoordinatesAreEqual(lhsCoordinate, rhsCoordinate), lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case .custom:
            if case .custom = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public struct LocationViewState {
    public var mapMode: LocationMapMode
    public var displayingMapModeOptions: Bool
    public var selectedLocation: LocationViewLocation
    public var trackingMode: LocationTrackingMode
    public var updatingProximityRadius: Int32?
    public var cancellingProximityRadius: Bool
    
    public init() {
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
    private weak var controller: LocationViewController?
    private var presentationData: PresentationData
    private let presentationDataPromise: Promise<PresentationData>
    private var subject: EngineMessage
    private let interaction: LocationViewInteraction
    private let locationManager: LocationManager
    private let isPreview: Bool
    
    private var rightBarButtonAction: LocationViewRightBarButton = .none
    
    private let topEdgeEffectView = EdgeEffectView()
    private let buttons = ComponentView<Empty>()
    private let sideColumnCloseButton = ComponentView<Empty>()
    private let title = ComponentView<Empty>()
    
    private let listNode: ListView
    let backgroundView = GlassBackgroundView()
    let headerNode: LocationMapHeaderNode
    
    private var enqueuedTransitions: [LocationViewTransaction] = []
    
    private var disposable: Disposable?
    private let weatherDisposable = MetaDisposable()
    private var state: LocationViewState
    private let statePromise: Promise<LocationViewState>
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    private var listOffset: CGFloat?
    
    private var displayedProximityAlertTooltip = false
    
    var reportedAnnotationsReady = false
    var onAnnotationsReady: (() -> Void)?
    
    private let travelDisposables = DisposableSet()
    private var travelTimes: [EngineMessage.Id: (Double, ExpectedTravelTime, ExpectedTravelTime)] = [:] {
        didSet {
            self.travelTimesPromise.set(.single(self.travelTimes))
        }
    }
    private let travelTimesPromise = Promise<[EngineMessage.Id: (Double, ExpectedTravelTime, ExpectedTravelTime)]>([:])

    init(context: AccountContext, controller: LocationViewController, presentationData: PresentationData, subject: EngineMessage, interaction: LocationViewInteraction, locationManager: LocationManager, isPreview: Bool) {
        self.context = context
        self.controller = controller
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(presentationData)
        self.subject = subject
        self.interaction = interaction
        self.locationManager = locationManager
        self.isPreview = isPreview
        
        self.state = LocationViewState()
        self.statePromise = Promise(self.state)
        
        self.listNode = ListViewImpl()
        self.listNode.backgroundColor = .clear
        self.listNode.limitHitTestToNodes = true
        self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        var setupProximityNotificationImpl: ((Bool) -> Void)?
        var weatherPressedImpl: (() -> Void)?
        self.headerNode = LocationMapHeaderNode(
            presentationData: presentationData,
            glass: true,
            isPreview: self.isPreview,
            toggleMapModeSelection: interaction.toggleMapModeSelection,
            updateMapMode: interaction.updateMapMode,
            goToUserLocation: interaction.toggleTrackingMode,
            setupProximityNotification: { reset in
                setupProximityNotificationImpl?(reset)
            },
            weatherPressed: {
                weatherPressedImpl?()
            }
        )
    
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.headerNode)
        if !self.isPreview {
            self.addSubnode(self.listNode)
        }
        
        let userLocation: Signal<CLLocation?, NoError> = .single(nil)
        |> then(
            throttledUserLocation(self.headerNode.mapNode.userLocation)
        )
        
        var eta: Signal<(ExpectedTravelTime, ExpectedTravelTime), NoError> = .single((.calculating, .calculating))
        var address: Signal<String?, NoError> = .single(nil)
        
        let subjectLocation = getLocation(from: subject)
        let isStaticLocationView: Bool
        if let subjectLocation {
            isStaticLocationView = subjectLocation.liveBroadcastingTimeout == nil
        } else {
            isStaticLocationView = false
        }

        let locale = localeWithStrings(presentationData.strings)
        if let location = subjectLocation, isStaticLocationView {
            self.headerNode.mapNode.setMapCenter(coordinate: location.coordinate, span: LocationMapNode.viewMapSpan, animated: false)

            eta = .single((.calculating, .calculating))
            |> then(combineLatest(queue: Queue.mainQueue(), getExpectedTravelTime(coordinate: location.coordinate, transportType: .automobile), getExpectedTravelTime(coordinate: location.coordinate, transportType: .walking))
            |> mapToSignal { drivingTime, walkingTime -> Signal<(ExpectedTravelTime, ExpectedTravelTime), NoError> in
                if case .calculating = drivingTime {
                    return .complete()
                }
                if case .calculating = walkingTime {
                    return .complete()
                }
                
                return .single((drivingTime, walkingTime))
            })
            
            if let venue = location.venue, let venueAddress = venue.address, !venueAddress.isEmpty {
                address = .single(venueAddress)
            } else {
                address = .single(nil)
                |> then(
                    reverseGeocodeLocation(latitude: location.latitude, longitude: location.longitude, locale: locale)
                    |> map { placemark -> String? in
                        return placemark?.compactDisplayAddress ?? ""
                    }
                )
            }
        }
        
        let actualLiveLocations = context.engine.messages.topPeerActiveLiveLocationMessages(peerId: subject.id.peerId)
        |> map { _, messages -> [EngineMessage] in
            return messages
        }
        
        let renderLiveLocations: Signal<[EngineMessage], NoError>
        if isStaticLocationView {
            renderLiveLocations = .single([])
            |> then(actualLiveLocations)
        } else {
            renderLiveLocations = actualLiveLocations
        }

        setupProximityNotificationImpl = { reset in
            let _ = (actualLiveLocations
            |> take(1)
            |> deliverOnMainQueue).start(next: { messages in
                var ownMessageId: EngineMessage.Id?
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
        
        weatherPressedImpl = {
            if let location = subjectLocation {
                context.sharedContext.openExternalUrl(
                    context: context,
                    urlContext: .generic,
                    url: "https://weather.apple.com/?lat=\(location.latitude)&long=\(location.longitude)",
                    forceExternal: true,
                    presentationData: presentationData,
                    navigationController: nil,
                    dismissInput: {}
                )
            }
        }
        
        let previousState = Atomic<LocationViewState?>(value: nil)
        let previousUserAnnotation = Atomic<LocationPinAnnotation?>(value: nil)
        let previousAnnotations = Atomic<[LocationPinAnnotation]>(value: [])
        let previousEntries = Atomic<[LocationViewEntry]?>(value: nil)
        let previousHadTravelTimes = Atomic<Bool>(value: false)
        
        let actualSelfPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        let renderSelfPeer: Signal<EnginePeer?, NoError>
        if isStaticLocationView {
            renderSelfPeer = .single(nil)
            |> then(actualSelfPeer)
        } else {
            renderSelfPeer = actualSelfPeer
        }
                        
        self.disposable = (combineLatest(self.presentationDataPromise.get(), self.statePromise.get(), renderSelfPeer, renderLiveLocations, self.headerNode.mapNode.userLocation, userLocation, address, eta, self.travelTimesPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, state, selfPeer, liveLocations, userLocation, distance, address, eta, travelTimes in
            if let strongSelf = self, let location = getLocation(from: subject) {
                var entries: [LocationViewEntry] = []
                var annotations: [LocationPinAnnotation] = []
                var userAnnotation: LocationPinAnnotation? = nil
                var effectiveLiveLocations: [EngineMessage] = liveLocations
                
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                
                var proximityNotification: Bool? = nil
                var proximityNotificationRadius: Int32?
                var index: Int = 0
                
                var isLocationView = false
                if location.liveBroadcastingTimeout == nil {
                    isLocationView = true
                    
                    let subjectLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let distance = userLocation.flatMap { subjectLocation.distance(from: $0) }
                    
                    entries.append(.info(presentationData.theme, location, address, distance, eta.0, eta.1, true))
                    
                    annotations.append(LocationPinAnnotation(context: context, theme: presentationData.theme, location: location, queryId: nil, resultId: nil, forcedSelection: true))
                } else {
                    var activeOwnLiveLocation: EngineMessage?
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
                    
                    if case let .channel(channel) = subject.author, case .broadcast = channel.info, activeOwnLiveLocation == nil {
                    } else {
                        if let timeout, Int32(timeout) != liveLocationIndefinitePeriod {
                            entries.append(.toggleLiveLocation(presentationData.theme, presentationData.strings.Map_SharingLocation, presentationData.strings.Map_TapToAddTime, beginTime, timeout, false, activeOwnLiveLocation?.id))
                            entries.append(.toggleLiveLocation(presentationData.theme, title, subtitle, beginTime, timeout, true, nil))
                        } else {
                            entries.append(.toggleLiveLocation(presentationData.theme, title, subtitle, beginTime, timeout, false, nil))
                        }
                    }
                    
                    var sortedLiveLocations: [EngineMessage] = []
                    
                    var effectiveSubject: EngineMessage?
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
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info, let threadId = message.threadId, threadId != 1 {
                            continue
                        }
                        
                        var liveBroadcastingTimeout: Int32 = 0
                        if let timeout = location.liveBroadcastingTimeout {
                            liveBroadcastingTimeout = timeout
                        }
                        let remainingTime: Int32
                        if liveBroadcastingTimeout == liveLocationIndefinitePeriod {
                            remainingTime = liveLocationIndefinitePeriod
                        } else {
                            remainingTime = max(0, message.timestamp + liveBroadcastingTimeout - currentTime)
                        }
                        if message.flags.contains(.Incoming) && remainingTime != 0 && proximityNotification == nil {
                            proximityNotification = false
                        }
                        
                        let subjectLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                        let distance = userLocation.flatMap { subjectLocation.distance(from: $0) }
                        
                        let timestamp = CACurrentMediaTime()
                        if message.localTags.contains(.OutgoingLiveLocation), let selfPeer = selfPeer {
                            userAnnotation = LocationPinAnnotation(context: context, theme: presentationData.theme, message: message, selfPeer: selfPeer, isSelf: true, heading: location.heading)
                        } else {
                            var drivingTime: ExpectedTravelTime = .unknown
                            var walkingTime: ExpectedTravelTime = .unknown
                            
                            if !isLocationView && message.author?.id != context.account.peerId {
                                let signal = combineLatest(
                                    queue: Queue.mainQueue(),
                                    getExpectedTravelTime(coordinate: location.coordinate, transportType: .automobile),
                                    getExpectedTravelTime(coordinate: location.coordinate, transportType: .walking)
                                )
                                |> mapToSignal { drivingTime, walkingTime -> Signal<(ExpectedTravelTime, ExpectedTravelTime), NoError> in
                                    if case .calculating = drivingTime {
                                        return .complete()
                                    }
                                    if case .calculating = walkingTime {
                                        return .complete()
                                    }
                                    return .single((drivingTime, walkingTime))
                                }
                                
                                if let (previousTimestamp, maybeDrivingTime, maybeWalkingTime) = travelTimes[message.id] {
                                    drivingTime = maybeDrivingTime
                                    walkingTime = maybeWalkingTime
                                    
                                    if timestamp > previousTimestamp + 60.0 {
                                        strongSelf.travelDisposables.add(signal.start(next: { [weak self] drivingTime, walkingTime in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            let timestamp = CACurrentMediaTime()
                                            var travelTimes = strongSelf.travelTimes
                                            travelTimes[message.id] = (timestamp, drivingTime, walkingTime)
                                            strongSelf.travelTimes = travelTimes
                                        }))
                                    }
                                } else {
                                    drivingTime = .calculating
                                    walkingTime = .calculating
                                    
                                    strongSelf.travelDisposables.add(signal.start(next: { [weak self] drivingTime, walkingTime in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let timestamp = CACurrentMediaTime()
                                        var travelTimes = strongSelf.travelTimes
                                        travelTimes[message.id] = (timestamp, drivingTime, walkingTime)
                                        strongSelf.travelTimes = travelTimes
                                    }))
                                }
                            }
                            
                            annotations.append(LocationPinAnnotation(context: context, theme: presentationData.theme, message: message, selfPeer: selfPeer, isSelf: message.author?.id == context.account.peerId, heading: location.heading))
                            entries.append(.liveLocation(presentationData.theme, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, message, distance, drivingTime, walkingTime, index))
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
                if case let .channel(channel) = subject.author, case .broadcast = channel.info {
                    proximityNotification = nil
                }
                
                let previousEntries = previousEntries.swap(entries)
                let previousState = previousState.swap(state)
                let previousHadTravelTimes = previousHadTravelTimes.swap(!travelTimes.isEmpty)
                
                var animated = false
                var previousActionsCount = 0
                var actionsCount = 0
                if let previousEntries {
                    for entry in previousEntries {
                        if case .toggleLiveLocation = entry {
                            previousActionsCount += 1
                        }
                    }
                }
                for entry in entries {
                    if case .toggleLiveLocation = entry {
                        actionsCount += 1
                    }
                }
                
                if actionsCount < previousActionsCount {
                    animated = true
                }
                
                let transition = preparedTransition(from: previousEntries ?? [], to: entries, context: context, presentationData: presentationData, interaction: strongSelf.interaction, gotTravelTimes: !travelTimes.isEmpty && !previousHadTravelTimes, animated: animated)
                strongSelf.enqueueTransition(transition)
                
                strongSelf.headerNode.updateState(mapMode: state.mapMode, trackingMode: state.trackingMode, displayingMapModeOptions: state.displayingMapModeOptions, displayingPlacesButton: false, proximityNotification: proximityNotification, animated: true)
                
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
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: location.coordinate, span: LocationMapNode.viewMapSpan, animated: previousState != nil)
                        }
                    case let .coordinate(coordinate, defaultSpan):
                        if let previousState = previousState, case let .coordinate(previousCoordinate, _) = previousState.selectedLocation, locationCoordinatesAreEqual(previousCoordinate, coordinate) {
                        } else {
                            strongSelf.headerNode.mapNode.setMapCenter(coordinate: coordinate, span: defaultSpan ? LocationMapNode.defaultMapSpan : LocationMapNode.viewMapSpan, animated: true)
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
                strongSelf.rightBarButtonAction = rightBarButtonAction
                
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
        
        if !isPreview {
            self.listNode.updateFloatingHeaderOffset = { [weak self] offset, listTransition in
                guard let self, self.listNode.scrollEnabled else {
                    return
                }
                self.listOffset = max(0.0, offset)
                self.updateHeader(transition: listTransition)
            }
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

        if !self.isPreview, let location = getLocation(from: subject) {
            self.requestWeatherData(coordinate: location.coordinate)
        }
    }
    
    deinit {
        self.disposable?.dispose()
        self.weatherDisposable.dispose()
        self.travelDisposables.dispose()
        self.locationManager.manager.stopUpdatingHeading()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.insertSubview(self.backgroundView, aboveSubview: self.headerNode.view)
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
        self.listNode.backgroundColor = .clear
        self.headerNode.updatePresentationData(self.presentationData)
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    func updateState(_ f: (LocationViewState) -> LocationViewState) {
        self.state = f(self.state)
        self.statePromise.set(.single(self.state))
    }

    private func requestWeatherData(coordinate: CLLocationCoordinate2D) {
        self.weatherDisposable.set((Weather.requestWeatherData(context: self.context, location: coordinate)
        |> deliverOnMainQueue).start(next: { [weak self] weatherData in
            guard let self else {
                return
            }
            if let weatherData {
                self.headerNode.updateWeatherData(context: self.context, emoji: weatherData.emoji, temperature: stringForTemperature(weatherData.temperature), animated: true)
            } else {
                self.headerNode.clearWeatherData(animated: true)
            }
        }))
    }

    func updateHeader(transition: ContainedViewLayoutTransition) {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height))
        transition.updateFrame(node: self.headerNode, frame: headerFrame)
        
        let headerHeight: CGFloat
        if self.isPreview {
            headerHeight = layout.size.height
        } else if let listOffset = self.listOffset {
            headerHeight = max(0.0, listOffset)
        } else {
            headerHeight = headerFrame.height
        }
        let headerSize = CGSize(width: headerFrame.width, height: headerHeight)
        self.headerNode.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: 0.0, controlsTopPadding: 0.0, controlsBottomPadding: 6.0, offset: 0.0, size: headerSize, transition: transition)

        let backgroundHeight = layout.size.height - headerHeight

        let glassInset: CGFloat = 6.0
        let backgroundSize = CGSize(width: layout.size.width - glassInset * 2.0, height: backgroundHeight)

        let bottomCornerRadius = max(24.0, layout.deviceMetrics.screenCornerRadius) - 2.0
        // iPhone Duo's cover screen: each bottom corner follows its own screen corner (nil where they are uniform).
        let bottomCornerRadii = layout.screenCornerRadii.sheetBottomCornerRadii(inset: 2.0)

        self.backgroundView.update(
            size: backgroundSize,
            cornerRadii: .init(
                topLeft: 38.0,
                topRight: 38.0,
                bottomLeft: bottomCornerRadii?.left ?? bottomCornerRadius,
                bottomRight: bottomCornerRadii?.right ?? bottomCornerRadius
            ),
            isDark: self.presentationData.theme.overallDarkAppearance,
            tintColor: .init(kind: .panel),
            transition: ComponentTransition(transition)
        )
        transition.updateFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: glassInset, y: layout.size.height - backgroundSize.height - glassInset), size: backgroundSize))
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
        
        var options = ListViewDeleteAndInsertOptions()
        if transition.animated {
            options.insert(.AnimateInsertion)
        }
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
    
    func liveLocationActionSourceView(extend: Bool) -> UIView? {
        var result: UIView?
        self.listNode.forEachItemNode { itemNode in
            if result == nil, let itemNode = itemNode as? LocationActionListItemNode {
                result = itemNode.liveLocationContextSourceView(extend: extend)
            }
        }
        return result
    }

    private func displayProximityAlertTooltip() {
        guard let location = self.headerNode.proximityButtonFrame().flatMap({ frame -> CGRect in
            return self.headerNode.view.convert(frame, to: nil)
        }) else {
            return
        }
        
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.subject.id.peerId))
        |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
            if let peer {
                return .single(peer)
            } else {
                return .never()
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }

            var text: String = strongSelf.presentationData.strings.Location_ProximityGroupTip
            if peer.id.namespace == Namespaces.Peer.CloudUser {
                text = strongSelf.presentationData.strings.Location_ProximityTip(peer.compactDisplayTitle).string
            }
            
            strongSelf.interaction.present(TooltipScreen(account: strongSelf.context.account, sharedContext: strongSelf.context.sharedContext, text: .plain(text: text), icon: nil, location: .point(location.offsetBy(dx: -9.0, dy: 0.0), .right), displayDuration: .custom(3.0), shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            }))
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = (layout, navigationHeight)
        
        var actionHeight: CGFloat?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? LocationActionListItemNode {
                if actionHeight == nil {
                    actionHeight = itemNode.frame.height
                }
            }
        }
        
        let overlap: CGFloat = 0.0
        var topInset: CGFloat = layout.size.height - layout.intrinsicInsets.bottom - overlap
        topInset -= 100.0
        
        if let location = getLocation(from: self.subject), location.liveBroadcastingTimeout != nil {
            topInset += 66.0
        }
        
        if self.listOffset == nil {
            self.listOffset = topInset
        }
        self.updateHeader(transition: transition)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        let insets = UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), scrollIndicatorInsets: UIEdgeInsets(top: topInset + 3.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        let listFrame: CGRect = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(node: self.listNode, frame: listFrame)
                
        if !self.isPreview {
            let topEdgeEffectFrame = CGRect(origin: .zero, size: CGSize(width: layout.size.width, height: 80.0))
            transition.updateFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(content: !self.presentationData.theme.overallDarkAppearance ? self.presentationData.theme.list.plainBackgroundColor : .clear, blur: true, alpha: 0.65, rect: topEdgeEffectFrame, edge: .top, edgeSize: topEdgeEffectFrame.height, transition: ComponentTransition(transition))
            if self.topEdgeEffectView.superview == nil {
                self.view.addSubview(self.topEdgeEffectView)
            }
        
            let leftControlItems: [GlassControlGroupComponent.Item] = [
                GlassControlGroupComponent.Item(
                    id: AnyHashable("close"),
                    content: .icon("Navigation/Close"),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.controller?.dismiss()
                    }
                )
            ]
            var rightControlItems: [GlassControlGroupComponent.Item] = []
            switch self.rightBarButtonAction {
            case .none:
                break
            case .share:
                rightControlItems.append(
                    GlassControlGroupComponent.Item(
                        id: AnyHashable("share"),
                        content: .icon("Navigation/Share"),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.interaction.share()
                        }
                    )
                )
            case .showAll:
                rightControlItems.append(
                    GlassControlGroupComponent.Item(
                        id: AnyHashable("share"),
                        content: .text(self.presentationData.strings.Map_LiveLocationShowAll),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.showAll()
                        }
                    )
                )
            }
                
            // iPhone Duo: with a side strip the close leaves the top row for the strip, where a standard bar's close goes
            // (folded landscape shows this screen full screen, and in landscape-right the row's left end is the status block).
            let sideColumnCloseFrame = layout.sideColumnNavigationButtonFrame
            
            let barButtonSideInset: CGFloat = 16.0
            let buttonsSize = self.buttons.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(GlassControlPanelComponent(
                    theme: self.presentationData.theme,
                    leftItem: sideColumnCloseFrame != nil ? nil : GlassControlPanelComponent.Item(
                        items: leftControlItems,
                        background: .panel
                    ),
                    centralItem: nil,
                    rightItem: rightControlItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                        items: rightControlItems,
                        background: .panel
                    ),
                    centerAlignmentIfPossible: true,
                    isDark: self.presentationData.theme.overallDarkAppearance
                )),
                environment: {},
                containerSize: CGSize(width: layout.size.width - barButtonSideInset * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: 44.0)
            )
            let buttonsFrame = CGRect(origin: CGPoint(x: barButtonSideInset + layout.safeInsets.left, y: barButtonSideInset), size: buttonsSize)
            if let view = self.buttons.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                }
                view.bounds = CGRect(origin: .zero, size: buttonsFrame.size)
                view.center = buttonsFrame.center
            }
            
            if let sideColumnCloseFrame {
                let closeButtonSize = self.sideColumnCloseButton.update(
                    transition: ComponentTransition(transition),
                    component: AnyComponent(GlassControlPanelComponent(
                        theme: self.presentationData.theme,
                        leftItem: GlassControlPanelComponent.Item(
                            items: leftControlItems,
                            background: .panel
                        ),
                        centralItem: nil,
                        rightItem: nil,
                        isDark: self.presentationData.theme.overallDarkAppearance
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let closeButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(sideColumnCloseFrame.midX - closeButtonSize.width * 0.5), y: floorToScreenPixels(sideColumnCloseFrame.midY - closeButtonSize.height * 0.5)), size: closeButtonSize)
                if let view = self.sideColumnCloseButton.view {
                    if view.superview == nil {
                        self.view.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: closeButtonFrame.size)
                    view.center = closeButtonFrame.center
                }
            } else if let view = self.sideColumnCloseButton.view {
                view.removeFromSuperview()
            }
            
            let titleSize = self.title.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: self.presentationData.strings.Map_LocationTitle,
                                font: Font.semibold(17.0),
                                textColor: self.headerNode.mapNode.mapMode == .map ? self.presentationData.theme.rootController.navigationBar.primaryTextColor : .white
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 40.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - titleSize.width) / 2.0), y: floorToScreenPixels((navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.view.addSubview(titleView)
                }
                transition.updateFrame(view: titleView, frame: titleFrame)
            }
        }
        
        if isFirstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
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
