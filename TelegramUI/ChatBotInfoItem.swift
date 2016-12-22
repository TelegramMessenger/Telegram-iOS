import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

final class ChatBotInfoItem: ListViewItem {
    fileprivate let controllerInteraction: ChatControllerInteraction
    
    init(controllerInteraction: ChatControllerInteraction) {
        self.controllerInteraction = controllerInteraction
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        let configure = {
            let node = ChatBotInfoItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, width)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(.None) })
            })
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ChatBotInfoItemNode {
            Queue.mainQueue().async {
                let nodeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = nodeLayout(self, width)
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
}

final class ChatBotInfoItemNode: ListViewItemNode {
    var controllerInteraction: ChatControllerInteraction?
    
    init() {
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)
        
        self.backgroundColor = .blue
    }
    
    func asyncLayout() -> (_ item: ChatBotInfoItem, _ width: CGFloat) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { [weak self] item, width in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 128.0), insets: UIEdgeInsets()), { _ in
                if let strongSelf = self {
                    
                }
            })
        }
    }
}
