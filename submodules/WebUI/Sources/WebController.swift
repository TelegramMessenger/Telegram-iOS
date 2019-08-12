import Foundation
import UIKit
import Display
import SafariServices

public final class WebController: ViewController {
    private let url: URL
    
    private var controllerNode: WebControllerNode {
        return self.displayNode as! WebControllerNode
    }
    
    public init(url: URL) {
        self.url = url
        
        super.init(navigationBarPresentationData: nil)
        
        self.edgesForExtendedLayout = []
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WebControllerNode(url: self.url)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
