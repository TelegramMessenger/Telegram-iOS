import Foundation
import UIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

public final class InstantPageController: ViewController {
    private let context: AccountContext
    private var webPage: TelegramMediaWebpage
    private let sourcePeerType: MediaAutoDownloadPeerType
    private let anchor: String?
    
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var controllerNode: InstantPageControllerNode {
        return self.displayNode as! InstantPageControllerNode
    }
    
    private var webpageDisposable: Disposable?
    private var storedStateDisposable: Disposable?
    
    private var settings: InstantPagePresentationSettings?
    private var settingsDisposable: Disposable?
    private var themeSettings: PresentationThemeSettings?
    
    public init(context: AccountContext, webPage: TelegramMediaWebpage, sourcePeerType: MediaAutoDownloadPeerType, anchor: String? = nil) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.webPage = webPage
        self.anchor = anchor
        self.sourcePeerType = sourcePeerType
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .modalInLargeLayout
        
        self.statusBar.statusBarStyle = .White
        
        self.webpageDisposable = (actualizedWebpage(postbox: self.context.account.postbox, network: self.context.account.network, webpage: webPage) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.webPage = result
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.updateWebPage(result, anchor: strongSelf.anchor)
                }
            }
        })
        
        self.settingsDisposable = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.instantPagePresentationSettings, ApplicationSpecificSharedDataKeys.presentationThemeSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                let settings: InstantPagePresentationSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.instantPagePresentationSettings] as? InstantPagePresentationSettings {
                    settings = current
                } else {
                    settings = InstantPagePresentationSettings.defaultSettings
                }
                let themeSettings: PresentationThemeSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings {
                    themeSettings = current
                } else {
                    themeSettings = PresentationThemeSettings.defaultSettings
                }
                
                strongSelf.settings = settings
                strongSelf.themeSettings = themeSettings
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.update(settings: settings, themeSettings: themeSettings, strings: strongSelf.presentationData.strings)
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.webpageDisposable?.dispose()
        self.storedStateDisposable?.dispose()
        self.settingsDisposable?.dispose()
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        let _ = updateInstantPageStoredStateInteractively(postbox: self.context.account.postbox, webPage: self.webPage, state: self.controllerNode.currentState).start()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = InstantPageControllerNode(context: self.context, settings: self.settings, themeSettings: self.themeSettings, presentationTheme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, autoNightModeTriggered: self.presentationData.autoNightModeTriggered, statusBar: self.statusBar, sourcePeerType: self.sourcePeerType, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, pushController: { [weak self] c in
            (self?.navigationController as? NavigationController)?.pushViewController(c)
        }, openPeer: { [weak self] peerId in
            if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), animated: true))
            }
        }, navigateBack: { [weak self] in
            if let strongSelf = self, let controllers = strongSelf.navigationController?.viewControllers.reversed() {
                for controller in controllers {
                    if !(controller is InstantPageController) {
                        strongSelf.navigationController?.popToViewController(controller, animated: true)
                        return
                    }
                }
                strongSelf.navigationController?.popViewController(animated: true)
            }
        })
        
        self.storedStateDisposable = (instantPageStoredState(postbox: self.context.account.postbox, webPage: self.webPage)
        |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.controllerNode.updateWebPage(strongSelf.webPage, anchor: strongSelf.anchor, state: state)
                strongSelf._ready.set(.single(true))
            }
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
