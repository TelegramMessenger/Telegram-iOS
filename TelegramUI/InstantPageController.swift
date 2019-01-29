import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

final class InstantPageController: ViewController {
    private let context: AccountContext
    private var webPage: TelegramMediaWebpage
    private let anchor: String?
    
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    var controllerNode: InstantPageControllerNode {
        return self.displayNode as! InstantPageControllerNode
    }
    
    private var webpageDisposable: Disposable?
    
    private var settings: InstantPagePresentationSettings?
    private var settingsDisposable: Disposable?
    
    init(context: AccountContext, webPage: TelegramMediaWebpage, anchor: String? = nil) {
        self.context = context
        self.presentationData = context.currentPresentationData.with { $0 }
        
        self.webPage = webPage
        self.anchor = anchor
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .White
        
        self.webpageDisposable = (actualizedWebpage(postbox: self.context.account.postbox, network: self.context.account.network, webpage: webPage) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.webPage = result
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.updateWebPage(result, anchor: strongSelf.anchor)
                }
            }
        })
        
        self.settingsDisposable = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.instantPagePresentationSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                let settings: InstantPagePresentationSettings
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.instantPagePresentationSettings] as? InstantPagePresentationSettings {
                    settings = current
                } else {
                    settings = InstantPagePresentationSettings.defaultSettings
                }
                strongSelf.settings = settings
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.update(settings: settings, strings: strongSelf.presentationData.strings)
                }
            }
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.webpageDisposable?.dispose()
        self.settingsDisposable?.dispose()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let _ = updateInstantPageStoredStateInteractively(postbox: self.context.account.postbox, webPage: self.webPage, state: self.controllerNode.currentState).start()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = InstantPageControllerNode(context: self.context, settings: self.settings, presentationTheme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, statusBar: self.statusBar, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, pushController: { [weak self] c in
            (self?.navigationController as? NavigationController)?.pushViewController(c)
        }, openPeer: { [weak self] peerId in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(context: strongSelf.context, chatLocation: .peer(peerId)))
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
        
        let _ = (instantPageStoredState(postbox: self.context.account.postbox, webPage: self.webPage)
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
