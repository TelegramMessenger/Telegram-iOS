import Foundation
import UIKit
import Display
import AsyncDisplayKit

public class ListController: ViewController {
    public var items: [ListControllerItem] = []
    
    public var listDisplayNode: ListControllerNode {
        get {
            return super.displayNode as! ListControllerNode
        }
    }
    
    override public init(navigationBar: NavigationBar = NavigationBar()) {
        super.init(navigationBar: navigationBar)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ListControllerNode()
        
        self.displayNode.backgroundColor = UIColor(0xefeff4)
        
        if !self.items.isEmpty {
            self.listDisplayNode.listView.transaction(deleteIndices: [], insertIndicesAndItems: (0 ..< self.items.count).map({ ListViewInsertItem(index: $0, previousIndex: nil, item: self.items[$0], directionHint: .Down) }), updateIndicesAndItems: [], options: [.LowLatency, .Synchronous], updateOpaqueState: nil)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.listDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
