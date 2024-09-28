import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import CoreLocation
import PresentationDataUtils
import DeviceAccess
import AttachmentUI

public enum LocationPickerMode {
    case share(peer: EnginePeer?, selfPeer: EnginePeer?, hasLiveLocation: Bool)
    case pick
}

class LocationPickerInteraction {
    let sendLocation: (CLLocationCoordinate2D, String?, MapGeoAddress?) -> Void
    let sendLiveLocation: (CLLocationCoordinate2D) -> Void
    let sendVenue: (TelegramMediaMap, Int64?, String?) -> Void
    let toggleMapModeSelection: () -> Void
    let updateMapMode: (LocationMapMode) -> Void
    let goToUserLocation: () -> Void
    let goToCoordinate: (CLLocationCoordinate2D, Bool) -> Void
    let openSearch: () -> Void
    let updateSearchQuery: (String) -> Void
    let dismissSearch: () -> Void
    let dismissInput: () -> Void
    let updateSendActionHighlight: (Bool) -> Void
    let openHomeWorkInfo: () -> Void
    let showPlacesInThisArea: () -> Void
    
    init(sendLocation: @escaping (CLLocationCoordinate2D, String?, MapGeoAddress?) -> Void, sendLiveLocation: @escaping (CLLocationCoordinate2D) -> Void, sendVenue: @escaping (TelegramMediaMap, Int64?, String?) -> Void, toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, goToUserLocation: @escaping () -> Void, goToCoordinate: @escaping (CLLocationCoordinate2D, Bool) -> Void, openSearch: @escaping () -> Void, updateSearchQuery: @escaping (String) -> Void, dismissSearch: @escaping () -> Void, dismissInput: @escaping () -> Void, updateSendActionHighlight: @escaping (Bool) -> Void, openHomeWorkInfo: @escaping () -> Void, showPlacesInThisArea: @escaping ()-> Void) {
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
    public enum Source {
        case generic
        case story
    }
    
    private var controllerNode: LocationPickerControllerNode {
        return self.displayNode as! LocationPickerControllerNode
    }
    
    private let context: AccountContext
    private let mode: LocationPickerMode
    private let source: Source
    let initialLocation: CLLocationCoordinate2D?
    private let completion: (TelegramMediaMap, Int64?, String?, String?, String?) -> Void
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    
    private var searchNavigationContentNode: LocationSearchNavigationContentNode?
    private var isSearchingDisposable = MetaDisposable()
    
    private let locationManager = LocationManager()
    private var permissionDisposable: Disposable?
    
    private var interaction: LocationPickerInteraction?
    
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    public var isMinimized: Bool = false
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mode: LocationPickerMode, source: Source = .generic, initialLocation: CLLocationCoordinate2D? = nil, completion: @escaping (TelegramMediaMap, Int64?, String?, String?, String?) -> Void) {
        self.context = context
        self.mode = mode
        self.source = source
        self.initialLocation = initialLocation
        self.completion = completion
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.updatedPresentationData = updatedPresentationData
        
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
                        
        self.interaction = LocationPickerInteraction(sendLocation: { [weak self] coordinate, name, geoAddress in
            guard let strongSelf = self else {
                return
            }
            strongSelf.completion(
                TelegramMediaMap(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    heading: nil,
                    accuracyRadius: nil,
                    venue: nil,
                    address: geoAddress,
                    liveBroadcastingTimeout: nil,
                    liveProximityNotificationRadius: nil
                ),
                nil,
                nil,
                name,
                geoAddress?.country
            )
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
                var title = strongSelf.presentationData.strings.Map_LiveLocationGroupNewDescription
                if case let .share(peer, _, _) = strongSelf.mode, let peer = peer, case .user = peer {
                    title = strongSelf.presentationData.strings.Map_LiveLocationPrivateNewDescription(peer.compactDisplayTitle).string
                }
                
                let sendLiveLocationImpl: (Int32) -> Void = { [weak self, weak controller] period in
                    controller?.dismissAnimated()
                    guard let self, let controller else {
                        return
                    }
                    controller.dismissAnimated()
                    self.completion(TelegramMediaMap(coordinate: coordinate, liveBroadcastingTimeout: period), nil, nil, nil, nil)
                    self.dismiss()
                }
                
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: title, font: .large, parseMarkdown: true),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationForMinutes(15), color: .accent, action: { sendLiveLocationImpl(15 * 60)
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationForHours(1), color: .accent, action: {
                            sendLiveLocationImpl(60 * 60 - 1)
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationForHours(8), color: .accent, action: {
                            sendLiveLocationImpl(8 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationIndefinite, color: .accent, action: {
                            sendLiveLocationImpl(liveLocationIndefinitePeriod)
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
        }, sendVenue: { [weak self] venue, queryId, resultId in
            guard let strongSelf = self else {
                return
            }
            let venueType = venue.venue?.type ?? ""
            if ["home", "work"].contains(venueType) {
                completion(TelegramMediaMap(latitude: venue.latitude, longitude: venue.longitude, heading: nil, accuracyRadius: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil), nil, nil, nil, nil)
            } else {
                completion(venue, queryId, resultId, venue.venue?.address, nil)
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
        }, goToCoordinate: { [weak self] coordinate, zoomOut in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .location(coordinate, nil, zoomOut)
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
        
        self.displayNode = LocationPickerControllerNode(controller: self, context: self.context, presentationData: self.presentationData, mode: self.mode, source: self.source, interaction: interaction, locationManager: self.locationManager)
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
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return LocationPickerContext()
    }
}

private final class LocationPickerContext: AttachmentMediaPickerContext {
}

public func storyLocationPickerController(
    context: AccountContext,
    location: CLLocationCoordinate2D?,
    dismissed: @escaping () -> Void,
    completion: @escaping (TelegramMediaMap, Int64?, String?, String?, String?) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkColorPresentationTheme)
    let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.requestController = { _, present in
        let locationPickerController = LocationPickerController(context: context, updatedPresentationData: updatedPresentationData, mode: .share(peer: nil, selfPeer: nil, hasLiveLocation: false), source: .story, initialLocation: location, completion: { location, queryId, resultId, address, countryCode in
            completion(location, queryId, resultId, address, countryCode)
        })
        present(locationPickerController, locationPickerController.mediaPickerContext)
    }
    controller.navigationPresentation = .flatModal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    controller.didDismiss = {
        dismissed()
    }
    return controller
}
