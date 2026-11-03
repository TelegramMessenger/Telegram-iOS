import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import AppBundle
import CoreLocation
import PresentationDataUtils
import OpenInExternalAppUI
import DeviceAccess
import UndoUI
import MapKit

public class LocationViewParams {
    let sendLiveLocation: (TelegramMediaMap) -> Void
    let stopLiveLocation: (EngineMessage.Id?) -> Void
    let openUrl: (String) -> Void
    let openPeer: (EnginePeer) -> Void
    let showAll: Bool
        
    public init(sendLiveLocation: @escaping (TelegramMediaMap) -> Void, stopLiveLocation: @escaping (EngineMessage.Id?) -> Void, openUrl: @escaping (String) -> Void, openPeer: @escaping (EnginePeer) -> Void, showAll: Bool = false) {
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.openUrl = openUrl
        self.openPeer = openPeer
        self.showAll = showAll
    }
}

final class LocationViewInteraction {
    let toggleMapModeSelection: () -> Void
    let updateMapMode: (LocationMapMode) -> Void
    let toggleTrackingMode: () -> Void
    let goToCoordinate: (CLLocationCoordinate2D) -> Void
    let requestDirections: (TelegramMediaMap, String?, OpenInLocationDirections) -> Void
    let share: () -> Void
    let setupProximityNotification: (Bool, EngineMessage.Id?) -> Void
    let sendLiveLocation: (Int32?, Bool, EngineMessage.Id?) -> Void
    let stopLiveLocation: () -> Void
    let present: (ViewController) -> Void
    
    init(toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, toggleTrackingMode: @escaping () -> Void, goToCoordinate: @escaping (CLLocationCoordinate2D) -> Void, requestDirections: @escaping (TelegramMediaMap, String?, OpenInLocationDirections) -> Void, share: @escaping () -> Void, setupProximityNotification: @escaping (Bool, EngineMessage.Id?) -> Void, sendLiveLocation: @escaping (Int32?, Bool, EngineMessage.Id?) -> Void, stopLiveLocation: @escaping () -> Void, present: @escaping (ViewController) -> Void) {
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.toggleTrackingMode = toggleTrackingMode
        self.goToCoordinate = goToCoordinate
        self.requestDirections = requestDirections
        self.share = share
        self.setupProximityNotification = setupProximityNotification
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.present = present
    }
}

public final class LocationViewController: ViewController {
    private var controllerNode: LocationViewControllerNode {
        return self.displayNode as! LocationViewControllerNode
    }
    private let context: AccountContext
    public var subject: EngineMessage
    private var basePresentationData: PresentationData
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var currentMapMode: LocationMapMode = .map
    private var showAll: Bool
    private let isPreview: Bool
    
    private let locationManager = LocationManager()
    
    private var interaction: LocationViewInteraction?
        
    public var dismissed: () -> Void = {}

    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        subject: EngineMessage,
        isPreview: Bool = false,
        params: LocationViewParams
    ) {
        self.context = context
        self.subject = subject
        self.showAll = params.showAll
        self.isPreview = isPreview
        
        let initialPresentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.basePresentationData = initialPresentationData
        self.presentationData = LocationViewController.effectivePresentationData(initialPresentationData, mapMode: .map)
                     
        super.init(navigationBarPresentationData: nil)
        
        self._hasGlassStyle = true
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationPresentation = .modal
                
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, strongSelf.basePresentationData.theme !== presentationData.theme else {
                return
            }
            strongSelf.basePresentationData = presentationData
            strongSelf.updateEffectivePresentationData(animated: true)
        })
                
        self.interaction = LocationViewInteraction(toggleMapModeSelection: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = !state.displayingMapModeOptions
                return state
            }
        }, updateMapMode: { [weak self] mode in
            guard let strongSelf = self else {
                return
            }
            strongSelf.currentMapMode = mode
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.mapMode = mode
                state.displayingMapModeOptions = false
                return state
            }
            strongSelf.updateEffectivePresentationData(animated: true)
        }, toggleTrackingMode: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                switch state.trackingMode {
                    case .none:
                        state.trackingMode = .follow
                    case .follow:
                        state.trackingMode = .followWithHeading
                    case .followWithHeading:
                        state.trackingMode = .none
                }
                return state
            }
        }, goToCoordinate: { [weak self] coordinate in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .coordinate(coordinate, false)
                return state
            }
        }, requestDirections: { [weak self] location, peerName, directions in
            guard let strongSelf = self else {
                return
            }
            let item: OpenInItem = .location(location: location, directions: directions)
            let openInOptions = availableOpenInOptions(context: context, item: item)
            if openInOptions.count == 1, let action = openInOptions.first?.action() {
                if case let .openLocation(latitude, longitude, directions) = action {
                    let placemark = MKPlacemark(coordinate: CLLocationCoordinate2DMake(latitude, longitude), addressDictionary: [:])
                    let mapItem = MKMapItem(placemark: placemark)
                    if let title = location.venue?.title {
                        mapItem.name = title
                    } else if let peerName = peerName {
                        mapItem.name = peerName
                    }
                    
                    if let directions = directions {
                        let options = [ MKLaunchOptionsDirectionsModeKey: directions.launchOptions ]
                        MKMapItem.openMaps(with: [MKMapItem.forCurrentLocation(), mapItem], launchOptions: options)
                    } else {
                        mapItem.openInMaps(launchOptions: nil)
                    }
                }
            } else {
                strongSelf.push(OpenInOptionsScreen(context: context, updatedPresentationData: updatedPresentationData, item: .location(location: location, directions: directions), additionalAction: nil, openUrl: params.openUrl))
            }
        }, share: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let location = getLocation(from: strongSelf.subject) {
                let shareAction = OpenInControllerAction(title: strongSelf.presentationData.strings.Conversation_ContextMenuShare, action: {
                    strongSelf.present(context.sharedContext.makeShareScreen(context: context, params: ShareControllerParams(subject: .mapMedia(location), externalShare: true)), in: .window(.root), with: nil)
                })
                strongSelf.push(OpenInOptionsScreen(context: context, updatedPresentationData: updatedPresentationData, item: .location(location: location, directions: nil), additionalAction: shareAction, openUrl: params.openUrl))
            }
        }, setupProximityNotification: { [weak self] reset, messageId in
            guard let strongSelf = self else {
                return
            }
            
            if reset {
                if let messageId = messageId {
                    strongSelf.controllerNode.updateState { state in
                        var state = state
                        state.cancellingProximityRadius = true
                        return state
                    }
                    
                    let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: 0, extendPeriod: nil).start(completed: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        Queue.mainQueue().after(0.5) {
                            strongSelf.controllerNode.updateState { state in
                                var state = state
                                state.cancellingProximityRadius = false
                                return state
                            }
                        }
                    })
                    
                    strongSelf.dismissAllTooltips()
                    strongSelf.present(
                        UndoOverlayController(
                            presentationData: strongSelf.presentationData,
                            content: .setProximityAlert(
                                title: strongSelf.presentationData.strings.Location_ProximityAlertCancelled,
                                text: "",
                                cancelled: true
                            ),
                            elevatedLayout: false,
                            action: { action in
                                return true
                            }
                        ),
                        in: .current
                    )
                }
            } else {
                DeviceAccess.authorizeAccess(to: .location(.live), locationManager: strongSelf.locationManager, presentationData: strongSelf.presentationData, present: { c, a in
                    strongSelf.present(c, in: .window(.root), with: a)
                }, openSettings: {
                    context.sharedContext.applicationBindings.openSettings()
                }, { [weak self] authorized in
                    guard let strongSelf = self, authorized else {
                        return
                    }
                    strongSelf.controllerNode.setProximityIndicator(radius: 0)
                    
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.subject.id.peerId))
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

                        var compactDisplayTitle: String?
                        if case .user = peer {
                            compactDisplayTitle = peer.compactDisplayTitle
                        }

                        let controller = LocationDistancePickerScreen(context: context, style: .default, compactDisplayTitle: compactDisplayTitle, distances: strongSelf.controllerNode.headerNode.mapNode.distancesToAllAnnotations, updated: { [weak self] distance in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.controllerNode.setProximityIndicator(radius: distance)
                        }, completion: { [weak self] distance, completion in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let messageId = messageId {
                                strongSelf.controllerNode.updateState { state in
                                    var state = state
                                    state.updatingProximityRadius = distance
                                    return state
                                }
                                
                                let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: distance, extendPeriod: nil).start(completed: { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    Queue.mainQueue().after(0.5) {
                                        strongSelf.controllerNode.updateState { state in
                                            var state = state
                                            state.updatingProximityRadius = nil
                                            return state
                                        }
                                    }
                                })
                                
                                var text: String
                                let distanceString = shortStringForDistance(strings: strongSelf.presentationData.strings, distance: distance)
                                if let compactDisplayTitle = compactDisplayTitle {
                                    text = strongSelf.presentationData.strings.Location_ProximityAlertSetText(compactDisplayTitle, distanceString).string
                                } else {
                                    text = strongSelf.presentationData.strings.Location_ProximityAlertSetTextGroup(distanceString).string
                                }
                                
                                strongSelf.dismissAllTooltips()
                                strongSelf.present(
                                    UndoOverlayController(
                                        presentationData: strongSelf.presentationData,
                                        content: .setProximityAlert(
                                            title: strongSelf.presentationData.strings.Location_ProximityAlertSetTitle,
                                            text: text,
                                            cancelled: false
                                        ),
                                        elevatedLayout: false,
                                        action: { action in
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            } else {
                                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: updatedPresentationData, title: strongSelf.presentationData.strings.Location_LiveLocationRequired_Title, text: strongSelf.presentationData.strings.Location_LiveLocationRequired_Description, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Location_LiveLocationRequired_ShareLocation, action: {
                                    completion()
                                    strongSelf.interaction?.sendLiveLocation(distance, false, nil)
                                }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})], actionLayout: .vertical), in: .window(.root))
                            }
                            completion()
                        }, willDismiss: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.controllerNode.setProximityIndicator(radius: nil)
                            }
                        })
                        strongSelf.present(controller, in: .window(.root))
                    })
                })
            }
        }, sendLiveLocation: { [weak self] distance, extend, messageId in
            guard let strongSelf = self else {
                return
            }
            DeviceAccess.authorizeAccess(to: .location(.live), locationManager: strongSelf.locationManager, presentationData: strongSelf.presentationData, present: { c, a in
                strongSelf.present(c, in: .window(.root), with: a)
            }, openSettings: {
                context.sharedContext.applicationBindings.openSettings()
            }, { [weak self] authorized in
                guard let strongSelf = self, authorized else {
                    return
                }
                
                if let distance = distance {
                    let _ = (strongSelf.controllerNode.coordinate
                    |> deliverOnMainQueue).start(next: { coordinate in
                        params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 30 * 60, proximityNotificationRadius: distance))
                    })
                    
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.subject.id.peerId))
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

                        var compactDisplayTitle: String?
                        if case .user = peer {
                            compactDisplayTitle = peer.compactDisplayTitle
                        }

                        var text: String
                        let distanceString = shortStringForDistance(strings: strongSelf.presentationData.strings, distance: distance)
                        if let compactDisplayTitle = compactDisplayTitle {
                            text = strongSelf.presentationData.strings.Location_ProximityAlertSetText(compactDisplayTitle, distanceString).string
                        } else {
                            text = strongSelf.presentationData.strings.Location_ProximityAlertSetTextGroup(distanceString).string
                        }
                        
                        strongSelf.dismissAllTooltips()
                        strongSelf.present(
                            UndoOverlayController(
                                presentationData: strongSelf.presentationData,
                                content: .setProximityAlert(
                                    title: strongSelf.presentationData.strings.Location_ProximityAlertSetTitle,
                                    text: text,
                                    cancelled: false
                                ),
                                elevatedLayout: false,
                                action: { action in
                                    return true
                                }
                            ),
                            in: .current
                        )
                    })
                } else {
                    let _  = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: subject.id.peerId))
                    |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
                        if let peer {
                            return .single(peer)
                        } else {
                            return .never()
                        }
                    }
                    |> deliverOnMainQueue).start(next: { peer in
                        var title: String
                        if extend {
                            title = strongSelf.presentationData.strings.Map_LiveLocationExtendDescription
                        } else {
                            title = strongSelf.presentationData.strings.Map_LiveLocationGroupNewDescription
                            if case .user = peer {
                                title = strongSelf.presentationData.strings.Map_LiveLocationPrivateNewDescription(peer.compactDisplayTitle).string
                            }
                        }

                        let sourceView = strongSelf.controllerNode.liveLocationActionSourceView(extend: extend) ?? strongSelf.view
                        let controller = makeLiveLocationDurationContextController(
                            presentationData: strongSelf.presentationData,
                            sourceView: sourceView!,
                            title: title,
                            selectPeriod: { [weak self] period in
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                if extend {
                                    if let messageId {
                                        let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: nil, extendPeriod: period).start()
                                    }
                                } else {
                                    let _ = (strongSelf.controllerNode.coordinate
                                    |> deliverOnMainQueue).start(next: { coordinate in
                                        params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: period))
                                    })
                                    
                                    strongSelf.controllerNode.showAll()
                                }
                            }
                        )
                        strongSelf.presentInGlobalOverlay(controller)
                    })
                }
            })
        }, stopLiveLocation: { [weak self] in
            params.stopLiveLocation(nil)
            self?.dismiss()
        }, present: { [weak self] c in
            if let strongSelf = self {
                strongSelf.present(c, in: .window(.root))
            }
        })
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }

    private static func effectivePresentationData(_ presentationData: PresentationData, mapMode: LocationMapMode) -> PresentationData {
        switch mapMode {
        case .satellite, .hybrid:
            if presentationData.theme.overallDarkAppearance {
                return presentationData
            }
            let darkTheme = customizeDefaultDarkPresentationTheme(
                theme: defaultDarkPresentationTheme,
                editing: false,
                title: nil,
                accentColor: presentationData.theme.list.itemAccentColor,
                backgroundColors: [],
                bubbleColors: [],
                animateBubbleColors: false,
                wallpaper: nil,
                baseColor: nil
            )
            return presentationData.withUpdated(theme: darkTheme)
        case .map:
            return presentationData
        }
    }

    private func updateEffectivePresentationData(animated: Bool) {
        let presentationData = LocationViewController.effectivePresentationData(self.basePresentationData, mapMode: self.currentMapMode)
        self.presentationData = presentationData
        self.statusBar.updateStatusBarStyle(presentationData.theme.rootController.statusBarStyle.style, animated: animated)

        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(presentationData)
        }
    }

    public func goToUserLocation(visibleRadius: Double? = nil) {
        
    }
    
    private func dismissAllTooltips() {
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    override public func loadDisplayNode() {
        super.loadDisplayNode()
        guard let interaction = self.interaction else {
            return
        }
        
        self.displayNode = LocationViewControllerNode(context: self.context, controller: self, presentationData: self.presentationData, subject: self.subject, interaction: interaction, locationManager: self.locationManager, isPreview: self.isPreview)
        self.displayNodeDidLoad()
        
        self.controllerNode.onAnnotationsReady = { [weak self] in
            guard let strongSelf = self, strongSelf.showAll else {
                return
            }
            strongSelf.controllerNode.showAll()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
            
    private var didDismiss = false
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !self.didDismiss {
            self.didDismiss = true
            self.dismissed()
        }
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        super.dismiss(completion: completion)
    }
}
