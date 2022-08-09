import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import CoreLocation
import PresentationDataUtils
import DeviceAccess
import AttachmentUI

public enum LocationPickerMode {
    case share(peer: Peer?, selfPeer: Peer?, hasLiveLocation: Bool)
    case pick
}

class LocationPickerInteraction {
    let sendLocation: (CLLocationCoordinate2D) -> Void
    let sendLiveLocation: (CLLocationCoordinate2D) -> Void
    let sendVenue: (TelegramMediaMap) -> Void
    let toggleMapModeSelection: () -> Void
    let updateMapMode: (LocationMapMode) -> Void
    let goToUserLocation: () -> Void
    let goToCoordinate: (CLLocationCoordinate2D) -> Void
    let openSearch: () -> Void
    let updateSearchQuery: (String) -> Void
    let dismissSearch: () -> Void
    let dismissInput: () -> Void
    let updateSendActionHighlight: (Bool) -> Void
    let openHomeWorkInfo: () -> Void
    let showPlacesInThisArea: () -> Void
    
    init(sendLocation: @escaping (CLLocationCoordinate2D) -> Void, sendLiveLocation: @escaping (CLLocationCoordinate2D) -> Void, sendVenue: @escaping (TelegramMediaMap) -> Void, toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, goToUserLocation: @escaping () -> Void, goToCoordinate: @escaping (CLLocationCoordinate2D) -> Void, openSearch: @escaping () -> Void, updateSearchQuery: @escaping (String) -> Void, dismissSearch: @escaping () -> Void, dismissInput: @escaping () -> Void, updateSendActionHighlight: @escaping (Bool) -> Void, openHomeWorkInfo: @escaping () -> Void, showPlacesInThisArea: @escaping ()-> Void) {
        self.sendLocation = sendLocation
        self.sendLiveLocation = sendLiveLocation
        self.sendVenue = sendVenue
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.goToUserLocation = goToUserLocation
        self.goToCoordinate = goToCoordinate
        self.openSearch = openSearch
        self.updateSearchQuery = updateSearchQuery
        self.dismissSearch = dismissSearch
        self.dismissInput = dismissInput
        self.updateSendActionHighlight = updateSendActionHighlight
        self.openHomeWorkInfo = openHomeWorkInfo
        self.showPlacesInThisArea = showPlacesInThisArea
    }
}

public final class LocationPickerController: ViewController, AttachmentContainable {
    private var controllerNode: LocationPickerControllerNode {
        return self.displayNode as! LocationPickerControllerNode
    }
    
    private let context: AccountContext
    private let mode: LocationPickerMode
    private let completion: (TelegramMediaMap, String?) -> Void
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var searchNavigationContentNode: LocationSearchNavigationContentNode?
    private var isSearchingDisposable = MetaDisposable()
    
    private let locationManager = LocationManager()
    private var permissionDisposable: Disposable?
    
    private var interaction: LocationPickerInteraction?
    
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mode: LocationPickerMode, completion: @escaping (TelegramMediaMap, String?) -> Void) {
        self.context = context
        self.mode = mode
        self.completion = completion
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                     
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.navigationPresentation = .modal
        
        self.title = self.presentationData.strings.Map_ChooseLocationTitle
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.updateBarButtons()
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, strongSelf.presentationData.theme !== presentationData.theme else {
                return
            }
            strongSelf.presentationData = presentationData
            
            strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: strongSelf.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)))
            strongSelf.searchNavigationContentNode?.updatePresentationData(strongSelf.presentationData)
            
            strongSelf.updateBarButtons()
            
            if strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        let locationWithTimeout: (CLLocationCoordinate2D, Int32?) -> TelegramMediaMap = { coordinate, timeout in
            return TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: timeout, liveProximityNotificationRadius: nil)
        }
                
        self.interaction = LocationPickerInteraction(sendLocation: { [weak self] coordinate in
            guard let strongSelf = self else {
                return
            }
            strongSelf.completion(locationWithTimeout(coordinate, nil), nil)
            strongSelf.dismiss()
        }, sendLiveLocation: { [weak self] coordinate in
            guard let strongSelf = self else {
                return
            }
            DeviceAccess.authorizeAccess(to: .location(.live), locationManager: strongSelf.locationManager, presentationData: strongSelf.presentationData, present: { c, a in
                strongSelf.present(c, in: .window(.root), with: a)
            }, openSettings: {
                strongSelf.context.sharedContext.applicationBindings.openSettings()
            }, { [weak self] authorized in
                guard let strongSelf = self, authorized else {
                    return
                }
                let controller = ActionSheetController(presentationData: strongSelf.presentationData)
                var title = strongSelf.presentationData.strings.Map_LiveLocationGroupDescription
                if case let .share(peer, _, _) = strongSelf.mode, let receiver = peer as? TelegramUser {
                    title = strongSelf.presentationData.strings.Map_LiveLocationPrivateDescription(EnginePeer(receiver).compactDisplayTitle).string
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: title),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor15Minutes, color: .accent, action: { [weak self, weak controller] in
                            controller?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.completion(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 15 * 60), nil)
                                strongSelf.dismiss()
                            }
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor1Hour, color: .accent, action: { [weak self, weak controller] in
                            controller?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.completion(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 60 * 60 - 1), nil)
                                strongSelf.dismiss()
                            }
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor8Hours, color: .accent, action: { [weak self, weak controller] in
                            controller?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.completion(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: 8 * 60 * 60), nil)
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
            })
        }, sendVenue: { [weak self] venue in
            guard let strongSelf = self else {
                return
            }
            let venueType = venue.venue?.type ?? ""
            if ["home", "work"].contains(venueType) {
                completion(TelegramMediaMap(latitude: venue.latitude, longitude: venue.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil), nil)
            } else {
                completion(venue, nil)
            }
            strongSelf.dismiss()
        }, toggleMapModeSelection: { [weak self] in
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
            strongSelf.controllerNode.goToUserLocation()
        }, goToCoordinate: { [weak self] coordinate in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .location(coordinate, nil)
                state.searchingVenuesAround = false
                return state
            }
        }, openSearch: { [weak self] in
            guard let strongSelf = self, let interaction = strongSelf.interaction, let navigationBar = strongSelf.navigationBar else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                return state
            }
            let contentNode = LocationSearchNavigationContentNode(presentationData: strongSelf.presentationData, interaction: interaction)
            strongSelf.searchNavigationContentNode = contentNode
            navigationBar.setContentNode(contentNode, animated: true)
            let isSearching = strongSelf.controllerNode.activateSearch(navigationBar: navigationBar)
            contentNode.activate()

            strongSelf.isSearchingDisposable.set((isSearching
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self, let searchNavigationContentNode = strongSelf.searchNavigationContentNode {
                    searchNavigationContentNode.updateActivity(value)
                }
            }))
        }, updateSearchQuery: { [weak self] query in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.searchContainerNode?.searchTextUpdated(text: query)
        }, dismissSearch: { [weak self] in
            guard let strongSelf = self, let navigationBar = strongSelf.navigationBar else {
                return
            }
            strongSelf.isSearchingDisposable.set(nil)
            strongSelf.searchNavigationContentNode?.deactivate()
            strongSelf.searchNavigationContentNode = nil
            navigationBar.setContentNode(nil, animated: true)
            strongSelf.controllerNode.deactivateSearch()
        }, dismissInput: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.searchNavigationContentNode?.deactivate()
        }, updateSendActionHighlight: { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateSendActionHighlight(highlighted)
        }, openHomeWorkInfo: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let controller = textAlertController(context: strongSelf.context, updatedPresentationData: updatedPresentationData, title: strongSelf.presentationData.strings.Map_HomeAndWorkTitle, text: strongSelf.presentationData.strings.Map_HomeAndWorkInfo, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})])
            strongSelf.present(controller, in: .window(.root))
        }, showPlacesInThisArea: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.requestPlacesAtSelectedLocation()
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
        self.permissionDisposable?.dispose()
        self.isSearchingDisposable.dispose()
    }
    
    private var locationAccessDenied = false
    private func updateBarButtons() {
        if self.locationAccessDenied {
            self.navigationItem.rightBarButtonItem = nil
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.searchPressed))
            self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.Common_Search
        }
    }
    
    override public func loadDisplayNode() {
        super.loadDisplayNode()
        guard let interaction = self.interaction else {
            return
        }
        
        self.displayNode = LocationPickerControllerNode(controller: self, context: self.context, presentationData: self.presentationData, mode: self.mode, interaction: interaction, locationManager: self.locationManager)
        self.displayNodeDidLoad()
        self.controllerNode.beganInteractiveDragging = { [weak self] in
            self?.requestAttachmentMenuExpansion()
        }
        self.controllerNode.locationAccessDeniedUpdated = { [weak self] denied in
            self?.locationAccessDenied = denied
            self?.updateBarButtons()
        }
        
        self.permissionDisposable = (DeviceAccess.authorizationStatus(subject: .location(.send))
        |> deliverOnMainQueue).start(next: { [weak self] next in
            guard let strongSelf = self else {
                return
            }
            switch next {
                case .notDetermined:
                    DeviceAccess.authorizeAccess(to: .location(.send), locationManager: strongSelf.locationManager, presentationData: strongSelf.presentationData, present: { c, a in
                        strongSelf.present(c, in: .window(.root), with: a)
                    }, openSettings: {
                        strongSelf.context.sharedContext.applicationBindings.openSettings()
                    })
                case .denied:
                    strongSelf.controllerNode.updateState { state in
                        var state = state
                        state.forceSelection = true
                        return state
                }
                default:
                    break
            }
        })
        
        self.navigationBar?.passthroughTouches = false
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func searchPressed() {
        self.requestAttachmentMenuExpansion()
        
        self.interaction?.openSearch()
    }
    
    public func resetForReuse() {
        self.interaction?.updateMapMode(.map)
        self.interaction?.dismissSearch()
        self.scrollToTop?()
    }
}
