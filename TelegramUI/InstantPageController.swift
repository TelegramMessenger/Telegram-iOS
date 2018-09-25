import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

final class InstantPageController: ViewController {
    private let account: Account
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
    
    init(account: Account, webPage: TelegramMediaWebpage, anchor: String? = nil) {
        self.account = account
        self.presentationData = (account.telegramApplicationContext.currentPresentationData.with { $0 })
        
        self.webPage = webPage
        self.anchor = anchor
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .White
        
        self.webpageDisposable = (actualizedWebpage(postbox: self.account.postbox, network: self.account.network, webpage: webPage) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.webPage = result
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.updateWebPage(result, anchor: strongSelf.anchor)
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
        self.displayNode = InstantPageControllerNode(account: self.account, settings: self.settings, presentationTheme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, statusBar: self.statusBar, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
            }, pushController: { [weak self] c in
                (self?.navigationController as? NavigationController)?.pushViewController(c)
            }, openPeer: { [weak self] peerId in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(peerId)))
            }
        }, navigateBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        
        self.displayNodeDidLoad()
        
        self.controllerNode.updateWebPage(self.webPage, anchor: self.anchor)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
