import Foundation
import UIKit
import Display
import AsyncDisplayKit

class ListController: ViewController {
    var items: [ListControllerItem] = []
    
    var listDisplayNode: ListControllerNode {
        get {
            return super.displayNode as! ListControllerNode
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ListControllerNode()
        
        self.displayNode.backgroundColor = UIColor(0xefeff4)
        
        self.listDisplayNode.listView.deleteAndInsertItems(deleteIndices: [], insertIndicesAndItems: (0 ..< self.items.count).map({ ListViewInsertItem(index: $0, previousIndex: nil, item: self.items[$0], directionHint: .Down) }), updateIndicesAndItems: [], options: [])
        
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.listDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
}
