import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import CoreLocation
import PresentationDataUtils
import OpenInExternalAppUI
import ShareController
import DeviceAccess

public class LocationViewParams {
    let sendLiveLocation: (TelegramMediaMap) -> Void
    let stopLiveLocation: () -> Void
    let openUrl: (String) -> Void
    let openPeer: (Peer) -> Void
        
    public init(sendLiveLocation: @escaping (TelegramMediaMap) -> Void, stopLiveLocation: @escaping () -> Void, openUrl: @escaping (String) -> Void, openPeer: @escaping (Peer) -> Void) {
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.openUrl = openUrl
        self.openPeer = openPeer
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
    let goToUserLocation: () -> Void
    let goToCoordinate: (CLLocationCoordinate2D) -> Void
    let requestDirections: () -> Void
    let share: () -> Void
    let setupProximityNotification: (CLLocationCoordinate2D, Bool) -> Void
    let updateSendActionHighlight: (Bool) -> Void
    let sendLiveLocation: (CLLocationCoordinate2D) -> Void
    let stopLiveLocation: () -> Void
    let updateRightBarButton: (LocationViewRightBarButton) -> Void
    
    init(toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, goToUserLocation: @escaping () -> Void, goToCoordinate: @escaping (CLLocationCoordinate2D) -> Void, requestDirections: @escaping () -> Void, share: @escaping () -> Void, setupProximityNotification: @escaping (CLLocationCoordinate2D, Bool) -> Void, updateSendActionHighlight: @escaping (Bool) -> Void, sendLiveLocation: @escaping (CLLocationCoordinate2D) -> Void, stopLiveLocation: @escaping () -> Void, updateRightBarButton: @escaping (LocationViewRightBarButton) -> Void) {
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.goToUserLocation = goToUserLocation
        self.goToCoordinate = goToCoordinate
        self.requestDirections = requestDirections
        self.share = share
        self.setupProximityNotification = setupProximityNotification
        self.updateSendActionHighlight = updateSendActionHighlight
        self.sendLiveLocation = sendLiveLocation
        self.stopLiveLocation = stopLiveLocation
        self.updateRightBarButton = updateRightBarButton
    }
}

var CURRENT_DISTANCE: Double? = nil

public final class LocationViewController: ViewController {
    private var controllerNode: LocationViewControllerNode {
        return self.displayNode as! LocationViewControllerNode
    }
    private let context: AccountContext
    private var subject: Message
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let locationManager = LocationManager()
    private var permissionDisposable: Disposable?
    
    private var interaction: LocationViewInteraction?
    
    private var rightBarButtonAction: LocationViewRightBarButton = .none

    public init(context: AccountContext, subject: Message, params: LocationViewParams) {
        self.context = context
        self.subject = subject
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
                     
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.navigationPresentation = .modal
        
        self.title = self.presentationData.strings.Map_LocationTitle
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
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
        }, goToUserLocation: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .user
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
        }, requestDirections: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let location = getLocation(from: strongSelf.subject) {
                strongSelf.present(OpenInActionSheetController(context: context, item: .location(location: location, withDirections: true), additionalAction: nil, openUrl: params.openUrl), in: .window(.root), with: nil)
            }
        }, share: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let location = getLocation(from: strongSelf.subject) {
                let shareAction = OpenInControllerAction(title: strongSelf.presentationData.strings.Conversation_ContextMenuShare, action: {
                    strongSelf.present(ShareController(context: context, subject: .mapMedia(location), externalShare: true), in: .window(.root), with: nil)
                })
                strongSelf.present(OpenInActionSheetController(context: context, item: .location(location: location, withDirections: false), additionalAction: shareAction, openUrl: params.openUrl), in: .window(.root), with: nil)
            }
        }, setupProximityNotification: { [weak self] coordinate, reset in
            guard let strongSelf = self else {
                return
            }
            
            if reset {
                strongSelf.controllerNode.setProximityRadius(radius: nil)
                CURRENT_DISTANCE = nil
            } else {
                strongSelf.controllerNode.setProximityIndicator(radius: 0)
                
                let controller = LocationDistancePickerScreen(context: context, style: .default, currentDistance: strongSelf.controllerNode.headerNode.mapNode.distance, updated: { [weak self] distance in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.controllerNode.setProximityIndicator(radius: distance)
                }, completion: { [weak self] distance in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.controllerNode.setProximityIndicator(radius: nil)
                    if let distance = distance {
                        strongSelf.controllerNode.setProximityRadius(radius: distance)
                        
                        let _ = requestProximityNotification(postbox: context.account.postbox, network: context.account.network, messageId: subject.id, distance: distance, coordinate: (coordinate.latitude, longitude: coordinate.longitude, accuracyRadius: nil)).start()
                        
                        CURRENT_DISTANCE = Double(distance)
                    }
                })
                strongSelf.present(controller, in: .window(.root))
            }
        }, updateSendActionHighlight: { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateSendActionHighlight(highlighted)
        }, sendLiveLocation: { [weak self] coordinate in
            guard let strongSelf = self else {
                return
            }
            DeviceAccess.authorizeAccess(to: .location(.live), locationManager: strongSelf.locationManager, presentationData: strongSelf.presentationData, present: { c, a in
                strongSelf.present(c, in: .window(.root), with: a)
            }, openSettings: {
                strongSelf.context.sharedContext.applicationBindings.openSettings()
            }) { [weak self] authorized in
                guard let strongSelf = self, authorized else {
                    return
                }
                let controller = ActionSheetController(presentationData: strongSelf.presentationData)
                var title = strongSelf.presentationData.strings.Map_LiveLocationGroupDescription
                if subject.id.peerId.namespace == Namespaces.Peer.CloudUser {
//                    title = strongSelf.presentationData.strings.Map_LiveLocationPrivateDescription(receiver.compactDisplayTitle).0
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: title),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor15Minutes, color: .accent, action: { [weak self, weak controller] in
                            controller?.dismissAnimated()
                            if let strongSelf = self {
                                params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 15 * 60))
                                strongSelf.dismiss()
                            }
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor1Hour, color: .accent, action: { [weak self, weak controller] in
                            controller?.dismissAnimated()
                            if let strongSelf = self {
                                params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 60 * 60 - 1))
                                strongSelf.dismiss()
                            }
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor8Hours, color: .accent, action: { [weak self, weak controller] in
                            controller?.dismissAnimated()
                            if let strongSelf = self {
                                params.sendLiveLocation(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 8 * 60 * 60))
                                strongSelf.dismiss()
                            }
                        })
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak controller] in
                            controller?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(controller, in: .window(.root))
            }
        }, stopLiveLocation: { [weak self] in
            params.stopLiveLocation()
            self?.dismiss()
        }, updateRightBarButton: { [weak self] action in
            guard let strongSelf = self else {
                return
            }
            
            if action != strongSelf.rightBarButtonAction {
                strongSelf.rightBarButtonAction = action
                strongSelf.updateRightBarButton()
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
    
    override public func loadDisplayNode() {
        super.loadDisplayNode()
        guard let interaction = self.interaction else {
            return
        }
        
        self.displayNode = LocationViewControllerNode(context: self.context, presentationData: self.presentationData, subject: self.subject, interaction: interaction)
        self.displayNodeDidLoad()
        
        self.controllerNode.updateState { state -> LocationViewState in
            var state = state
            state.proximityRadius = CURRENT_DISTANCE
            return state
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
    
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationHeight, transition: transition)
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

