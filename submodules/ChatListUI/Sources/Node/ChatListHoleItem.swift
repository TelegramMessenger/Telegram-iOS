import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramPresentationData

class ChatListHoleItem: ListViewItem {
    let theme: PresentationTheme
    
    let selectable: Bool = false
    
    init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListHoleItemNode()
            node.relativePosition = (first: previousItem == nil, last: nextItem == nil)
            node.insets = ChatListItemNode.insets(first: false, last: false, firstWithHeader: false)
            node.layoutForParams(params, item: self, previousItem: previousItem, nextItem: nextItem)
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListHoleItemNode)
            if let nodeValue = node() as? ChatListHoleItemNode {
            
                let layout = nodeValue.asyncLayout()
                async {
                    let first = previousItem == nil
                    let last = nextItem == nil
                    
                    let (nodeLayout, apply) = layout(self, params, first, last)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

class ChatListHoleItemNode: ListViewItemNode {
    var relativePosition: (first: Bool, last: Bool) = (false, false)
    
    required init() {
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListHoleItem, params, self.relativePosition.first, self.relativePosition.last)
        apply()
    }
    
    func asyncLayout() -> (_ item: ChatListHoleItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, first, last in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 0.0), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.relativePosition = (first, last)
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                }
            })
        }
    }
}
