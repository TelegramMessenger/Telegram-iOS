import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import AppBundle
import CoreLocation
import PresentationDataUtils
import OpenInExternalAppUI
import ShareController
import DeviceAccess
import UndoUI
import MapKit

public class LocationViewParams {
    let sendLiveLocation: (TelegramMediaMap) -> Void
    let stopLiveLocation: (MessageId?) -> Void
    let openUrl: (String) -> Void
    let openPeer: (Peer) -> Void
    let showAll: Bool
        
    public init(sendLiveLocation: @escaping (TelegramMediaMap) -> Void, stopLiveLocation: @escaping (MessageId?) -> Void, openUrl: @escaping (String) -> Void, openPeer: @escaping (Peer) -> Void, showAll: Bool = false) {
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.openUrl = openUrl
        self.openPeer = openPeer
        self.showAll = showAll
    }
}

enum LocationViewRightBarButton {
    case none
    case share
    case showAll
}

class LocationViewInteraction {
    let toggleMapModeSelection: () -> Void
    let updateMapMode: (LocationMapMode) -> Void
    let toggleTrackingMode: () -> Void
    let goToCoordinate: (CLLocationCoordinate2D) -> Void
    let requestDirections: (TelegramMediaMap, String?, OpenInLocationDirections) -> Void
    let share: () -> Void
    let setupProximityNotification: (Bool, MessageId?) -> Void
    let updateSendActionHighlight: (Bool) -> Void
    let sendLiveLocation: (Int32?) -> Void
    let stopLiveLocation: () -> Void
    let updateRightBarButton: (LocationViewRightBarButton) -> Void
    let present: (ViewController) -> Void
    
    init(toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, toggleTrackingMode: @escaping () -> Void, goToCoordinate: @escaping (CLLocationCoordinate2D) -> Void, requestDirections: @escaping (TelegramMediaMap, String?, OpenInLocationDirections) -> Void, share: @escaping () -> Void, setupProximityNotification: @escaping (Bool, MessageId?) -> Void, updateSendActionHighlight: @escaping (Bool) -> Void, sendLiveLocation: @escaping (Int32?) -> Void, stopLiveLocation: @escaping () -> Void, updateRightBarButton: @escaping (LocationViewRightBarButton) -> Void, present: @escaping (ViewController) -> Void) {
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.toggleTrackingMode = toggleTrackingMode
        self.goToCoordinate = goToCoordinate
        self.requestDirections = requestDirections
        self.share = share
        self.setupProximityNotification = setupProximityNotification
        self.updateSendActionHighlight = updateSendActionHighlight
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.updateRightBarButton = updateRightBarButton
        self.present = present
    }
}

public final class LocationViewController: ViewController {
    private var controllerNode: LocationViewControllerNode {
        return self.displayNode as! LocationViewControllerNode
    }
    private let context: AccountContext
    public var subject: Message
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var showAll: Bool
    
    private let locationManager = LocationManager()
    private var permissionDisposable: Disposable?
    
    private var interaction: LocationViewInteraction?
    
    private var rightBarButtonAction: LocationViewRightBarButton = .none

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, subject: Message, params: LocationViewParams) {
        self.context = context
        self.subject = subject
        self.showAll = params.showAll
        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                     
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.navigationPresentation = .modal
        
        self.title = self.presentationData.strings.Map_LocationTitle
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, strongSelf.presentationData.theme !== presentationData.theme else {
                return
            }
            strongSelf.presentationData = presentationData
            
            strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: strongSelf.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)))
            
            strongSelf.updateRightBarButton()
            
            if strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
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
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.mapMode = mode
                state.displayingMapModeOptions = false
                return state
            }
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
                strongSelf.present(OpenInActionSheetController(context: context, updatedPresentationData: updatedPresentationData, item: .location(location: location, directions: directions), additionalAction: nil, openUrl: params.openUrl), in: .window(.root), with: nil)
            }
        }, share: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let location = getLocation(from: strongSelf.subject) {
                let shareAction = OpenInControllerAction(title: strongSelf.presentationData.strings.Conversation_ContextMenuShare, action: {
                    strongSelf.present(ShareController(context: context, subject: .mapMedia(location), externalShare: true), in: .window(.root), with: nil)
                })
                strongSelf.present(OpenInActionSheetController(context: context, updatedPresentationData: updatedPresentationData, item: .location(location: location, directions: nil), additionalAction: shareAction, openUrl: params.openUrl), in: .window(.root), with: nil)
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
                    
                    let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: 0).start(completed: { [weak self] in
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
                    
                    let _ = (strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.subject.id.peerId)
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        var compactDisplayTitle: String?
                        if let peer = peer as? TelegramUser {
                            compactDisplayTitle = EnginePeer(peer).compactDisplayTitle
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
                                
                                let _ = context.engine.messages.requestEditLiveLocation(messageId: messageId, stop: false, coordinate: nil, heading: nil, proximityNotificationRadius: distance).start(completed: { [weak self] in
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
                                    strongSelf.interaction?.sendLiveLocation(distance)
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
        }, updateSendActionHighlight: { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateSendActionHighlight(highlighted)
        }, sendLiveLocation: { [weak self] distance in
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
                    
                    let _ = (strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.subject.id.peerId)
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        var compactDisplayTitle: String?
                        if let peer = peer as? TelegramUser {
                            compactDisplayTitle = EnginePeer(peer).compactDisplayTitle
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
                    let _  = (context.account.postbox.loadedPeerWithId(subject.id.peerId)
                    |> deliverOnMainQueue).start(next: { peer in
                        let controller = ActionSheetController(presentationData: strongSelf.presentationData)
                        var title = strongSelf.presentationData.strings.Map_LiveLocationGroupDescription
                        if let user = peer as? TelegramUser {
                            title = strongSelf.presentationData.strings.Map_LiveLocationPrivateDescription(EnginePeer(user).compactDisplayTitle).string
                        }
                        
                        let sendLiveLocationImpl: (Int32) -> Void = { [weak controller] period in
                            controller?.dismissAnimated()
                            
                            let _ = (strongSelf.controllerNode.coordinate
                            |> deliverOnMainQueue).start(next: { coordinate in
                                params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: period))
                            })
                            
                            strongSelf.controllerNode.showAll()
                        }
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetTextItem(title: title),
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor15Minutes, color: .accent, action: {
                                    sendLiveLocationImpl(15 * 60)
                                }),
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor1Hour, color: .accent, action: {
                                    sendLiveLocationImpl(60 * 60 - 1)
                                }),
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor8Hours, color: .accent, action: {
                                    sendLiveLocationImpl(8 * 60 * 60)
                                })
                            ]),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak controller] in
                                    controller?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.present(controller, in: .window(.root))
                    })
                }
            })
        }, stopLiveLocation: { [weak self] in
            params.stopLiveLocation(nil)
            self?.dismiss()
        }, updateRightBarButton: { [weak self] action in
            guard let strongSelf = self else {
                return
            }
            
            if action != strongSelf.rightBarButtonAction {
                strongSelf.rightBarButtonAction = action
                strongSelf.updateRightBarButton()
            }
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
        
        self.displayNode = LocationViewControllerNode(context: self.context, presentationData: self.presentationData, subject: self.subject, interaction: interaction, locationManager: self.locationManager)
        self.displayNodeDidLoad()
        
        self.controllerNode.onAnnotationsReady = { [weak self] in
            guard let strongSelf = self, strongSelf.showAll else {
                return
            }
            strongSelf.controllerNode.showAll()
        }
    }
    
    private func updateRightBarButton() {
        switch self.rightBarButtonAction {
            case .none:
                self.navigationItem.rightBarButtonItem = nil
            case .share:
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationShareIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.sharePressed))
                self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.VoiceOver_MessageContextShare
            case .showAll:
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Map_LiveLocationShowAll, style: .plain, target: self, action: #selector(self.showAllPressed))
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func sharePressed() {
        self.interaction?.share()
    }
    
    @objc private func showAllPressed() {
        self.controllerNode.showAll()
    }
}

