import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

final class InstantPageController: ViewController {
    private let account: Account
    private var webPage: TelegramMediaWebpage
    
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
    
    init(account: Account, webPage: TelegramMediaWebpage) {
        self.account = account
        self.presentationData = (account.telegramApplicationContext.currentPresentationData.with { $0 })
        
        self.webPage = webPage
        
        super.init(navigationBarTheme: nil)
        
        self.statusBar.statusBarStyle = .White
        
        self.webpageDisposable = (actualizedWebpage(postbox: self.account.postbox, network: self.account.network, webpage: webPage) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.webPage = result
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.updateWebPage(result)
                }
            }
        })
        
        self.settingsDisposable = (self.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.instantPagePresentationSettings]) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                let settings: InstantPagePresentationSettings
                if let current = view.values[ApplicationSpecificPreferencesKeys.instantPagePresentationSettings] as? InstantPagePresentationSettings {
                    settings = current
                } else {
                    settings = InstantPagePresentationSettings.defaultSettings
                }
                strongSelf.settings = settings
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.update(settings: settings, strings: strongSelf.presentationData.strings)
                }
                strongSelf._ready.set(.single(true))
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
    
    override public func loadDisplayNode() {
        self.displayNode = InstantPageControllerNode(account: self.account, settings: self.settings, strings: self.presentationData.strings, statusBar: self.statusBar, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, openPeer: { [weak self] peerId in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId))
            }
        }, navigateBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        
        self.displayNodeDidLoad()
        
        self.controllerNode.updateWebPage(self.webPage)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
