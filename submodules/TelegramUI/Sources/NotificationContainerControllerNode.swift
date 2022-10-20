import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

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
    
    private var presentationData: PresentationData
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        super.init()
        
        self.setViewBlock({
            return NotificationContainerControllerNodeView()
        })
        
        self.backgroundColor = nil
        self.isOpaque = false
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
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
            transition.updateFrame(node: topItemNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            topItemNode.updateLayout(layout: layout, transition: transition)
        }
    }
    
    func removeItemsWithGroupingKey(_ key: AnyHashable) {
        if let (item, topItemNode) = self.topItemAndNode {
            if item.groupingKey == key {
                self.topItemAndNode = nil
                self.displayingItemsUpdated?(false)
                topItemNode.animateOut(completion: { [weak topItemNode] in
                    topItemNode?.removeFromSupernode()
                })
            }
        }
    }
    
    func enqueue(_ item: NotificationItem) {
        if let (_, topItemNode) = self.topItemAndNode {
            topItemNode.animateOut(completion: { [weak topItemNode] in
                topItemNode?.removeFromSupernode()
            })
        }
        
        var useCompactLayout = false
        if let validLayout = self.validLayout {
            useCompactLayout = min(validLayout.size.width, validLayout.size.height) < 375.0
        }
        
        let itemNode = item.node(compact: useCompactLayout)
        let containerNode = NotificationItemContainerNode(theme: self.presentationData.theme)
        containerNode.item = item
        containerNode.contentNode = itemNode
        containerNode.dismissed = { [weak self] item in
            if let strongSelf = self {
                if let (topItem, topItemNode) = strongSelf.topItemAndNode, topItem.groupingKey != nil && topItem.groupingKey == item.groupingKey {
                    topItemNode.removeFromSupernode()
                    strongSelf.topItemAndNode = nil
                    
                    if let strongSelf = self, strongSelf.topItemAndNode == nil {
                        strongSelf.displayingItemsUpdated?(false)
                    }
                }
            }
        }
        containerNode.cancelTimeout = { [weak self] item in
            if let strongSelf = self {
                if let (topItem, _) = strongSelf.topItemAndNode, topItem.groupingKey != nil && topItem.groupingKey == item.groupingKey {
                    strongSelf.timeoutTimer?.invalidate()
                    strongSelf.timeoutTimer = nil
                }
            }
        }
        containerNode.resumeTimeout = { [weak self] item in
            if let strongSelf = self {
                if let (topItem, _) = strongSelf.topItemAndNode, topItem.groupingKey != nil && topItem.groupingKey == item.groupingKey {
                    strongSelf.resetTimeoutTimer()
                }
            }
        }
        self.topItemAndNode = (item, containerNode)
        self.addSubnode(containerNode)
        
        if let validLayout = self.validLayout {
            containerNode.updateLayout(layout: validLayout, transition: .immediate)
            containerNode.frame = CGRect(origin: CGPoint(), size: validLayout.size)
            containerNode.animateIn()
        }
        
        self.displayingItemsUpdated?(true)
        
        self.resetTimeoutTimer()
    }
    
    func removeItems(_ f: (NotificationItem) -> Bool) {
        if let (topItem, topItemNode) = self.topItemAndNode {
            if f(topItem) {
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
    
    private func resetTimeoutTimer() {
        self.timeoutTimer?.invalidate()
        let timeout: Double
        #if DEBUG
            timeout = 6.0
        #else
            timeout = 5.0
        #endif
        let timeoutTimer = SwiftSignalKit.Timer(timeout: 5.0, repeat: false, completion: { [weak self] in
            if let strongSelf = self {
                if let (_, topItemNode) = strongSelf.topItemAndNode {
                    strongSelf.topItemAndNode = nil
                    strongSelf.displayingItemsUpdated?(false)
                    topItemNode.animateOut(completion: { [weak topItemNode] in
                        topItemNode?.removeFromSupernode()
                    })
                }
            }
        }, queue: Queue.mainQueue())
        self.timeoutTimer = timeoutTimer
        timeoutTimer.start()
    }
}
