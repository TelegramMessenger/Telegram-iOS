import Foundation
import AsyncDisplayKit
import Display

private let backgroundImageWithShadow = generateImage(CGSize(width: 30.0 + 8.0 * 2.0, height: 30.0 + 8.0 + 20.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setShadow(offset: CGSize(width: 0.0, height: -4.0), blur: 40.0, color: UIColor(white: 0.0, alpha: 0.3).cgColor)
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 8.0, y: 8.0), size: CGSize(width: 30.0, height: 30.0)))
})?.stretchableImage(withLeftCapWidth: 8 + 15, topCapHeight: 8 + 15)

final class NotificationItemContainerNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    
    private var validLayout: ContainerViewLayout?
    
    var item: NotificationItem?
    
    var contentNode: NotificationItemNode? {
        didSet {
            if self.contentNode !== oldValue {
                oldValue?.removeFromSupernode()
            }
            
            if let contentNode = self.contentNode {
                self.addSubnode(contentNode)
                
                if let validLayout = self.validLayout {
                    self.updateLayout(layout: validLayout, transition: .immediate)
                }
            }
        }
    }
    
    var dismissed: ((NotificationItem) -> Void)?
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = backgroundImageWithShadow
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = false
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: 0.0, y: -100.0), to: CGPoint(), duration: 0.4, additive: true)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -100.0), duration: 0.4, removeOnCompletion: false, additive: true, completion: { _ in
            completion()
        })
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        if let contentNode = self.contentNode {
            let contentInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
            let contentWidth = layout.size.width - contentInsets.left - contentInsets.right
            let contentHeight = contentNode.updateLayout(width: contentWidth, transition: transition)
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: 8.0 + contentHeight + 20.0)))
            
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top), size: CGSize(width: contentWidth, height: contentHeight)))
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let contentNode = self.contentNode, contentNode.frame.contains(point) {
            return self.view
        }
        return nil
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                item.tapped()
            }
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                break
            case .changed:
                let translation = recognizer.translation(in: self.view)
                var bounds = self.bounds
                bounds.origin.y = max(0.0, -translation.y)
                self.bounds = bounds
            case .ended:
                self.animateOut(completion: { [weak self] in
                    if let strongSelf = self, let item = strongSelf.item {
                        strongSelf.dismissed?(item)
                    }
                })
            case .cancelled:
                let previousBounds = self.bounds
                var bounds = self.bounds
                bounds.origin.y = 0.0
                self.bounds = bounds
                self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionEaseInEaseOut)
            default:
                break
        }
    }
}
