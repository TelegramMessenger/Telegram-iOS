import Foundation
import Display
import AsyncDisplayKit
import Postbox

class ListMessageNode: ListViewItemNode {
    var item: ListMessageItem?
    var controllerInteraction: ChatControllerInteraction?
    
    required init() {
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    func setupItem(_ item: ListMessageItem) {
        self.item = item
    }
    
    override public func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
    }
    
    func asyncLayout() -> (_ item: ListMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { _, width, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 1.0), insets: UIEdgeInsets()), { _ in
                
            })
        }
    }
    
    func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
    
    func updateSelectionState(animated: Bool) {
    }
}
