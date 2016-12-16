import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

final class MediaNavigationAccessoryContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    let backgroundNode: ASDisplayNode
    let headerNode: MediaNavigationAccessoryHeaderNode
    let itemListNode: MediaNavigationAccessoryItemListNode
    
    private var currentHeaderHeight: CGFloat = MediaNavigationAccessoryHeaderNode.minimizedHeight
    private var draggingHeaderHeight: CGFloat?
    private var effectiveHeaderHeight: CGFloat {
        if let draggingHeaderHeight = self.draggingHeaderHeight {
            return draggingHeaderHeight
        } else {
            return self.currentHeaderHeight
        }
    }
    
    init(account: Account) {
        self.backgroundNode = ASDisplayNode()
        self.headerNode = MediaNavigationAccessoryHeaderNode()
        self.itemListNode = MediaNavigationAccessoryItemListNode(account: account)
        
        super.init()
        
        self.backgroundNode.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.itemListNode)
        self.addSubnode(self.headerNode)
        
        self.headerNode.expand = { [weak self] in
            if let strongSelf = self, strongSelf.draggingHeaderHeight == nil {
                let middleHeight = MediaNavigationAccessoryHeaderNode.maximizedHeight + MediaNavigationAccessoryItemListNode.minimizedPanelHeight
                strongSelf.currentHeaderHeight = middleHeight
                strongSelf.updateLayout(size: strongSelf.bounds.size, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
        
        self.itemListNode.collapse = { [weak self] in
            if let strongSelf = self, strongSelf.draggingHeaderHeight == nil {
                let middleHeight = MediaNavigationAccessoryHeaderNode.maximizedHeight + MediaNavigationAccessoryItemListNode.minimizedPanelHeight
                if middleHeight.isLess(than: strongSelf.currentHeaderHeight) {
                    strongSelf.currentHeaderHeight = middleHeight
                } else {
                    strongSelf.currentHeaderHeight = strongSelf.bounds.size.height
                }
                strongSelf.updateLayout(size: strongSelf.bounds.size, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.cancelsTouchesInView = true
        panRecognizer.delegate = self
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: self.effectiveHeaderHeight)))
        
        let headerHeight = max(MediaNavigationAccessoryHeaderNode.minimizedHeight, min(MediaNavigationAccessoryHeaderNode.maximizedHeight, self.effectiveHeaderHeight))
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: headerHeight)))
        self.headerNode.updateLayout(size: CGSize(width: size.width, height: headerHeight), transition: transition)
        
        let itemListHeight = max(0.0, self.effectiveHeaderHeight - headerHeight)
        transition.updateFrame(node: self.itemListNode, frame: CGRect(origin: CGPoint(x: 0.0, y: headerHeight), size: CGSize(width: size.width, height: itemListHeight)))
        self.itemListNode.updateLayout(size: CGSize(width: size.width, height: itemListHeight), maximizedHeight: max(10.0, size.height - MediaNavigationAccessoryHeaderNode.maximizedHeight), transition: transition)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let result = self.hitTest(touch.location(in: self.view), with: nil) {
            if result.disablesInteractiveTransitionGestureRecognizer {
                return false
            }
        }
        return true
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        let middleHeight = MediaNavigationAccessoryHeaderNode.maximizedHeight + MediaNavigationAccessoryItemListNode.minimizedPanelHeight
        switch recognizer.state {
            case .began:
                self.draggingHeaderHeight = self.currentHeaderHeight
            case .changed:
                if let draggingHeaderHeight = self.draggingHeaderHeight {
                    let translation = recognizer.translation(in: self.view).y
                    self.draggingHeaderHeight = max(MediaNavigationAccessoryHeaderNode.minimizedHeight, self.currentHeaderHeight + translation)
                    self.updateLayout(size: self.bounds.size, transition: .immediate)
                }
            case .ended:
                if let draggingHeaderHeight = self.draggingHeaderHeight {
                    self.draggingHeaderHeight = nil
                    let velocity = recognizer.velocity(in: self.view).y
                    if abs(velocity) > 500.0 {
                        if draggingHeaderHeight <= middleHeight {
                            if velocity < 0.0 {
                                self.currentHeaderHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
                            } else {
                                self.currentHeaderHeight = middleHeight
                            }
                        } else {
                            if velocity < 0.0 {
                                self.currentHeaderHeight = middleHeight
                            } else {
                                self.currentHeaderHeight = self.bounds.size.height
                            }
                        }
                    } else {
                        if draggingHeaderHeight < MediaNavigationAccessoryHeaderNode.maximizedHeight * 2.0 / 3.0 {
                            self.currentHeaderHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
                        } else if draggingHeaderHeight <= middleHeight + 100.0 {
                            self.currentHeaderHeight = middleHeight
                        } else {
                            self.currentHeaderHeight = self.bounds.size.height
                        }
                    }
                    self.updateLayout(size: self.bounds.size, transition: .animated(duration: 0.3, curve: .spring))
                }
            case .cancelled:
                self.draggingHeaderHeight = nil
                self.updateLayout(size: self.bounds.size, transition: .animated(duration: 0.3, curve: .spring))
            default:
                break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.headerNode.frame.contains(point) && !self.itemListNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
