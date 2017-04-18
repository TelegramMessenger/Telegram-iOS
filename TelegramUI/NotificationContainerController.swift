import Foundation
import Display
import AsyncDisplayKit

public final class NotificationContainerController: ViewController {
    private var controllerNode: NotificationContainerControllerNode {
        return self.displayNode as! NotificationContainerControllerNode
    }
    
    public init() {
        super.init(navigationBar: NavigationBar())
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadView() {
        super.loadView()
        
        self.navigationBar.removeFromSupernode()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = NotificationContainerControllerNode()
        self.displayNodeDidLoad()
        
        self.controllerNode.displayingItemsUpdated = { [weak self] value in
            if let strongSelf = self {
                strongSelf.statusBar.statusBarStyle = value ? .Hide : .Ignore
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    public func removeItemsWithGroupingKey(_ key: AnyHashable) {
        self.controllerNode.removeItemsWithGroupingKey(key)
    }
    
    public func enqueue(_ item: NotificationItem) {
        self.controllerNode.enqueue(item)
    }
}
