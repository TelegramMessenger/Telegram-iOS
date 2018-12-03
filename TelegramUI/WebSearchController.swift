import Foundation
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore

final class WebSearchController: ViewController {
    private let account: Account
    
    private var validLayout: ContainerViewLayout?
    
    private var controllerNode: WebSearchControllerNode {
        return self.displayNode as! WebSearchControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var navigationContentNode: WebSearchNavigationContentNode?
    
    init(account: Account) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme).withUpdatedSeparatorColor(self.presentationData.theme.rootController.navigationBar.backgroundColor), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    //strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        let navigationContentNode = WebSearchNavigationContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, cancel: { [weak self] in
            
        })
        self.navigationContentNode = navigationContentNode
        navigationContentNode.setQueryUpdated { [weak self] query in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            //strongSelf.controllerNode.updateSearchQuery(query)
        }
        self.navigationBar?.setContentNode(navigationContentNode, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WebSearchControllerNode(account: self.account, theme: self.presentationData.theme, strings: self.presentationData.strings)
        self._ready.set(.single(true))
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
