import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import AccountContext

public class ListMessageNode: ListViewItemNode {
    var item: ListMessageItem?
    var interaction: ListMessageItemInteraction?
    
    required init() {
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    func setupItem(_ item: ListMessageItem) {
        self.item = item
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
    }
    
    public func asyncLayout() -> (_ item: ListMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { _, params, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 1.0), insets: UIEdgeInsets()), { _ in
                
            })
        }
    }
    
    public func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    public func updateHiddenMedia() {
    }
    
    public func updateSelectionState(animated: Bool) {
    }
}
