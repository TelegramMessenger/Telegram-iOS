import Foundation
import Display

class ListControllerSpacerItem: ListControllerItem {
    private let height: CGFloat
    
    init(height: CGFloat) {
        self.height = height
    }
    
    func mergesBackgroundWithItem(other: ListControllerItem) -> Bool {
        return false
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = ListControllerSpacerItemNode()
            node.height = self.height
            node.layoutForWidth(width, item: self, previousItem: previousItem, nextItem: nextItem)
            completion(node, {})
        }
    }
}

class ListControllerSpacerItemNode: ListViewItemNode {
    var height: CGFloat = 0.0
    
    init() {
        super.init(layerBacked: true, dynamicBounce: false)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: self.height))
    }
}
