import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

private final class NotificationContainerControllerNodeView: UITracingLayerView {
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.hitTestImpl?(point, event)
    }
}

final class NotificationContainerControllerNode: ASDisplayNode {
    private var validLayout: ContainerViewLayout?
    private var topItemAndNode: (NotificationItem, NotificationItemContainerNode)?
    
    var displayingItemsUpdated: ((Bool) -> Void)?
    
    private var timeoutTimer: SwiftSignalKit.Timer?
    
    override init() {
        super.init(viewBlock: {
            return NotificationContainerControllerNodeView()
        }, didLoad: nil)
        
        self.backgroundColor = nil
        self.isOpaque = false
    }
    
    override func didLoad() {
        super.didLoad()
        
        (self.view as! NotificationContainerControllerNodeView).hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let (_, topItemNode) = self.topItemAndNode {
            return topItemNode.hitTest(point, with: event)
        }
        return nil
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        if let (_, topItemNode) = self.topItemAndNode {
            topItemNode.updateLayout(layout: layout, transition: transition)
        }
    }
    
    func removeItemsWithGroupingKey(_ key: AnyHashable) {
        if let (item, topItemNode) = self.topItemAndNode {
            if item.groupingKey == key {
                self.topItemAndNode = nil
                topItemNode.animateOut(completion: { [weak self, weak topItemNode] in
                    topItemNode?.removeFromSupernode()
                    
                    if let strongSelf = self, strongSelf.topItemAndNode == nil {
                        strongSelf.displayingItemsUpdated?(false)
                    }
                })
            }
        }
    }
    
    func enqueue(_ item: NotificationItem) {
        var updatedDisplayingItems = false
        if let (_, topItemNode) = self.topItemAndNode {
            topItemNode.animateOut(completion: { [weak self, weak topItemNode] in
                topItemNode?.removeFromSupernode()
                
                if let strongSelf = self, strongSelf.topItemAndNode == nil {
                    strongSelf.displayingItemsUpdated?(false)
                }
            })
        } else {
            updatedDisplayingItems = true
        }
        
        let itemNode = item.node()
        let containerNode = NotificationItemContainerNode()
        containerNode.item = item
        containerNode.contentNode = itemNode
        containerNode.dismissed = { [weak self] item in
            if let strongSelf = self {
                if let (topItem, topItemNode) = strongSelf.topItemAndNode, topItem.groupingKey != nil && topItem.groupingKey == item.groupingKey {
                    topItemNode.removeFromSupernode()
                    
                    if let strongSelf = self, strongSelf.topItemAndNode == nil {
                        strongSelf.displayingItemsUpdated?(false)
                    }
                }
            }
        }
        self.topItemAndNode = (item, containerNode)
        self.addSubnode(containerNode)
        
        if let validLayout = self.validLayout {
            containerNode.updateLayout(layout: validLayout, transition: .immediate)
            containerNode.animateIn()
        }
        
        if updatedDisplayingItems {
            self.displayingItemsUpdated?(true)
        }
        
        self.timeoutTimer?.invalidate()
        let timeoutTimer = SwiftSignalKit.Timer(timeout: 5.0, repeat: false, completion: { [weak self] in
            if let strongSelf = self {
                if let (_, topItemNode) = strongSelf.topItemAndNode {
                    strongSelf.topItemAndNode = nil
                    topItemNode.animateOut(completion: { [weak topItemNode] in
                        topItemNode?.removeFromSupernode()
                        
                        if let strongSelf = self, strongSelf.topItemAndNode == nil {
                            strongSelf.displayingItemsUpdated?(false)
                        }
                    })
                }
            }
        }, queue: Queue.mainQueue())
        self.timeoutTimer = timeoutTimer
        timeoutTimer.start()
    }
}
