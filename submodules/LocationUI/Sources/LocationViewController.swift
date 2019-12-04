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

class LocationViewInteraction {
    let toggleMapModeSelection: () -> Void
    let updateMapMode: (LocationMapMode) -> Void
    let goToUserLocation: () -> Void
    let goToCoordinate: (CLLocationCoordinate2D) -> Void
    let requestDirections: () -> Void
    let share: () -> Void
        
    init(toggleMapModeSelection: @escaping () -> Void, updateMapMode: @escaping (LocationMapMode) -> Void, goToUserLocation: @escaping () -> Void, goToCoordinate: @escaping (CLLocationCoordinate2D) -> Void, requestDirections: @escaping () -> Void, share: @escaping () -> Void) {
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.goToUserLocation = goToUserLocation
        self.goToCoordinate = goToCoordinate
        self.requestDirections = requestDirections
        self.share = share
    }
}

public final class LocationViewController: ViewController {
    private var controllerNode: LocationViewControllerNode {
        return self.displayNode as! LocationViewControllerNode
    }
    private let context: AccountContext
    private var mapMedia: TelegramMediaMap
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
        
    private var interaction: LocationViewInteraction?

    public init(context: AccountContext, mapMedia: TelegramMediaMap, params: LocationViewParams) {
        self.context = context
        self.mapMedia = mapMedia
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
                     
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.navigationPresentation = .modal
        
        self.title = self.presentationData.strings.Map_LocationTitle
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationShareIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.sharePressed))
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.VoiceOver_MessageContextShare
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self, strongSelf.presentationData.theme !== presentationData.theme else {
                return
            }
            strongSelf.presentationData = presentationData
            
            strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: strongSelf.presentationData.theme).withUpdatedSeparatorColor(.clear), strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)))
            
            strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationShareIcon(strongSelf.presentationData.theme), style: .plain, target: strongSelf, action: #selector(strongSelf.sharePressed))
            
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
                state.selectedLocation = .coordinate(coordinate)
                return state
            }
        }, requestDirections: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.present(OpenInActionSheetController(context: context, item: .location(location: mapMedia, withDirections: true), additionalAction: nil, openUrl: params.openUrl), in: .window(.root), with: nil)
        }, share: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let shareAction = OpenInControllerAction(title: strongSelf.presentationData.strings.Conversation_ContextMenuShare, action: {
                strongSelf.present(ShareController(context: context, subject: .mapMedia(mapMedia), externalShare: true), in: .window(.root), with: nil)
            })
            strongSelf.present(OpenInActionSheetController(context: context, item: .location(location: mapMedia, withDirections: false), additionalAction: shareAction, openUrl: params.openUrl), in: .window(.root), with: nil)
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
        
        self.displayNode = LocationViewControllerNode(context: self.context, presentationData: self.presentationData, mapMedia: self.mapMedia, interaction: interaction)
        self.displayNodeDidLoad()
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
        self.dismiss()
    }
}

