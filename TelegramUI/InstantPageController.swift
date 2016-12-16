import Foundation
import TelegramCore
import Display

final class InstantPageController: ViewController {
    private let account: Account
    private let webPage: TelegramMediaWebpage
    
    var controllerNode: InstantPageControllerNode {
        return self.displayNode as! InstantPageControllerNode
    }
    
    init(account: Account, webPage: TelegramMediaWebpage) {
        self.account = account
        self.webPage = webPage
        
        super.init()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = InstantPageControllerNode(account: self.account)
        
        self.navigationBar.isHidden = true
        self.statusBar.alpha = 0.0
        
        self.displayNodeDidLoad()
        
        self.controllerNode.updateWebPage(self.webPage)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
