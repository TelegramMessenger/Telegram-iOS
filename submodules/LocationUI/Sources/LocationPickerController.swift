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
    
    let openSearch: () -> Void
    let updateSearchQuery: (String) -> Void
    let dismissSearch: () -> Void
    
    let dismissInput: () -> Void
    
    init(sendLocation: @escaping (CLLocationCoordinate2D) -> Void, sendLiveLocation: @escaping (CLLocationCoordinate2D) -> Void, sendVenue: @escaping (TelegramMediaMap) -> Void, toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, goToUserLocation: @escaping () -> Void, openSearch: @escaping () -> Void, updateSearchQuery: @escaping (String) -> Void, dismissSearch: @escaping () -> Void, dismissInput: @escaping () -> Void) {
        self.sendLocation = sendLocation
        self.sendLiveLocation = sendLiveLocation
        self.sendVenue = sendVenue
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.goToUserLocation = goToUserLocation
        self.openSearch = openSearch
        self.updateSearchQuery = updateSearchQuery
        self.dismissSearch = dismissSearch
        self.dismissInput = dismissInput
    }
}

public final class LocationPickerController: ViewController {
    private var controllerNode: LocationPickerControllerNode {
        return self.displayNode as! LocationPickerControllerNode
    }
    
    private let context: AccountContext
    private let mode: LocationPickerMode
    private let completion: (TelegramMediaMap, String?) -> Void
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var searchNavigationContentNode: LocationSearchNavigationContentNode?
    
    private var interaction: LocationPickerInteraction?
        
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
        
    public init(context: AccountContext, mode: LocationPickerMode, completion: @escaping (TelegramMediaMap, String?) -> Void) {
        self.context = context
        self.mode = mode
        self.completion = completion
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
                     
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.navigationPresentation = .modal
        
        self.title = self.presentationData.strings.Map_ChooseLocationTitle
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.searchPressed))
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.Common_Search
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, strongSelf.presentationData.theme !== presentationData.theme else {
                return
            }
            strongSelf.presentationData = presentationData
            
            strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: strongSelf.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)))
            strongSelf.searchNavigationContentNode?.updatePresentationData(strongSelf.presentationData)
            strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(strongSelf.presentationData.theme), style: .plain, target: strongSelf, action: #selector(strongSelf.searchPressed))
            
            strongSelf.controllerNode.updatePresentationData(presentationData)
        })
        
        let locationWithTimeout: (CLLocationCoordinate2D, Int32?) -> TelegramMediaMap = { coordinate, timeout in
            return TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: nil, liveBroadcastingTimeout: timeout)
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
            let controller = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
            var title = strongSelf.presentationData.strings.Map_LiveLocationGroupDescription
            if case let .share(peer, _, _) = strongSelf.mode, let receiver = peer {
                title = strongSelf.presentationData.strings.Map_LiveLocationPrivateDescription(receiver.compactDisplayTitle).0
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: title),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor15Minutes, color: .accent, action: { [weak self, weak controller] in
                        controller?.dismissAnimated()
                        if let strongSelf = self {
                            strongSelf.completion(locationWithTimeout(coordinate, 15 * 60), nil)
                            strongSelf.dismiss()
                        }
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor1Hour, color: .accent, action: { [weak self, weak controller] in
                        controller?.dismissAnimated()
                        if let strongSelf = self {
                            strongSelf.completion(locationWithTimeout(coordinate, 60 * 60 - 1), nil)
                            strongSelf.dismiss()
                        }
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Map_LiveLocationFor8Hours, color: .accent, action: { [weak self, weak controller] in
                        controller?.dismissAnimated()
                        if let strongSelf = self {
                            strongSelf.completion(locationWithTimeout(coordinate, 8 * 60 * 60), nil)
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
        }, sendVenue: { [weak self] venue in
            guard let strongSelf = self else {
                return
            }
            completion(venue, nil)
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
            strongSelf.controllerNode.updateState { state in
                var state = state
                state.displayingMapModeOptions = false
                state.selectedLocation = .none
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
            strongSelf.controllerNode.activateSearch(navigationBar: navigationBar)
            contentNode.activate()
        }, updateSearchQuery: { [weak self] query in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.searchContainerNode?.searchTextUpdated(text: query)
        }, dismissSearch: { [weak self] in
            guard let strongSelf = self, let navigationBar = strongSelf.navigationBar else {
                return
            }
            strongSelf.searchNavigationContentNode?.deactivate()
            strongSelf.searchNavigationContentNode = nil
            navigationBar.setContentNode(nil, animated: true)
            strongSelf.controllerNode.deactivateSearch()
        }, dismissInput: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.searchNavigationContentNode?.deactivate()
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
        guard let interaction = self.interaction else {
            return
        }
        
        self.displayNode = LocationPickerControllerNode(context: self.context, presentationData: self.presentationData, mode: self.mode, interaction: interaction)
        self.controllerNode.present = { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }
        self.displayNodeDidLoad()
        
        self._ready.set(.single(true))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func searchPressed() {
        self.interaction?.openSearch()
    }
}
