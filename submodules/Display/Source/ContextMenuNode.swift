import Foundation
import UIKit
import AsyncDisplayKit

private func generateShadowImage() -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 1.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setShadow(offset: CGSize(), blur: 10.0, color: UIColor(white: 0.18, alpha: 1.0).cgColor)
        context.setFillColor(UIColor(white: 0.18, alpha: 1.0).cgColor)
        context.fill(CGRect(origin: CGPoint(x: -15.0, y: 0.0), size: CGSize(width: 30.0, height: 1.0)))
    })
}

private final class ContextMenuContentScrollNode: ASDisplayNode {
    var contentWidth: CGFloat = 0.0
    
    private var initialOffset: CGFloat = 0.0
    
    private let leftShadow: ASImageNode
    private let rightShadow: ASImageNode
    private let leftOverscrollNode: ASDisplayNode
    private let rightOverscrollNode: ASDisplayNode
    let contentNode: ASDisplayNode
    
    override init() {
        self.contentNode = ASDisplayNode()
        
        let shadowImage = generateShadowImage()
        
        self.leftShadow = ASImageNode()
        self.leftShadow.displaysAsynchronously = false
        self.leftShadow.image = shadowImage
        self.rightShadow = ASImageNode()
        self.rightShadow.displaysAsynchronously = false
        self.rightShadow.image = shadowImage
        self.rightShadow.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        
        self.leftOverscrollNode = ASDisplayNode()
        //self.leftOverscrollNode.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        self.rightOverscrollNode = ASDisplayNode()
        //self.rightOverscrollNode.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        
        super.init()
        
        self.contentNode.addSubnode(self.leftOverscrollNode)
        self.contentNode.addSubnode(self.rightOverscrollNode)
        self.addSubnode(self.contentNode)
        
        self.addSubnode(self.leftShadow)
        self.addSubnode(self.rightShadow)
    }
    
    override func didLoad() {
        super.didLoad()
        
        //let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        //self.view.addGestureRecognizer(panRecognizer)
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                self.initialOffset = self.contentNode.bounds.origin.x
            case .changed:
                var bounds = self.contentNode.bounds
                bounds.origin.x = self.initialOffset - recognizer.translation(in: self.view).x
                if bounds.origin.x > self.contentWidth - bounds.size.width {
                    let delta = bounds.origin.x - (self.contentWidth - bounds.size.width)
                    bounds.origin.x = self.contentWidth - bounds.size.width + ((1.0 - (1.0 / (((delta) * 0.55 / (50.0)) + 1.0))) * 50.0)
                }
                if bounds.origin.x < 0.0 {
                    let delta = -bounds.origin.x
                    bounds.origin.x = -((1.0 - (1.0 / (((delta) * 0.55 / (50.0)) + 1.0))) * 50.0)
                }
                self.contentNode.bounds = bounds
                self.updateShadows(.immediate)
            case .ended, .cancelled:
                var bounds = self.contentNode.bounds
                bounds.origin.x = self.initialOffset - recognizer.translation(in: self.view).x
                
                var duration = 0.4
                
                if abs(bounds.origin.x - self.initialOffset) > 10.0 || abs(recognizer.velocity(in: self.view).x) > 100.0 {
                    duration = 0.2
                    if bounds.origin.x < self.initialOffset {
                        bounds.origin.x = 0.0
                    } else {
                        bounds.origin.x = self.contentWidth - bounds.size.width
                    }
                } else {
                    bounds.origin.x = self.initialOffset
                }
                
                if bounds.origin.x > self.contentWidth - bounds.size.width {
                    bounds.origin.x = self.contentWidth - bounds.size.width
                }
                if bounds.origin.x < 0.0 {
                   bounds.origin.x = 0.0
                }
                let previousBounds = self.contentNode.bounds
                self.contentNode.bounds = bounds
                self.contentNode.layer.animateBounds(from: previousBounds, to: bounds, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                self.updateShadows(.animated(duration: duration, curve: .spring))
            default:
                break
        }
    }
    
    override func layout() {
        let bounds = self.bounds
        self.contentNode.frame = bounds
        self.leftShadow.frame = CGRect(origin: CGPoint(), size: CGSize(width: 30.0, height: bounds.height))
        self.rightShadow.frame = CGRect(origin: CGPoint(x: bounds.size.width - 30.0, y: 0.0), size: CGSize(width: 30.0, height: bounds.height))
        self.leftOverscrollNode.frame = bounds.offsetBy(dx: -bounds.width, dy: 0.0)
        self.rightOverscrollNode.frame = bounds.offsetBy(dx: self.contentWidth, dy: 0.0)
        self.updateShadows(.immediate)
    }
    
    private func updateShadows(_ transition: ContainedViewLayoutTransition) {
        let bounds = self.contentNode.bounds
        
        let leftAlpha = max(0.0, min(1.0, bounds.minX / 20.0))
        transition.updateAlpha(node: self.leftShadow, alpha: leftAlpha)
        
        let rightAlpha = max(0.0, min(1.0, (self.contentWidth - bounds.maxX) / 20.0))
        transition.updateAlpha(node: self.rightShadow, alpha: rightAlpha)
    }
}

final class ContextMenuNode: ASDisplayNode {
    private let actions: [ContextMenuAction]
    private let dismiss: () -> Void
    
    private let containerNode: ContextMenuContainerNode
    private let scrollNode: ContextMenuContentScrollNode
    private let actionNodes: [ContextMenuActionNode]
    
    var sourceRect: CGRect?
    var containerRect: CGRect?
    var arrowOnBottom: Bool = true
    
    private var dismissedByTouchOutside = false
    private let catchTapsOutside: Bool
    
    private let feedback: HapticFeedback?
    
    init(actions: [ContextMenuAction], dismiss: @escaping () -> Void, catchTapsOutside: Bool, hasHapticFeedback: Bool = false) {
        self.actions = actions
        self.dismiss = dismiss
        self.catchTapsOutside = catchTapsOutside
        
        self.containerNode = ContextMenuContainerNode()
        self.scrollNode = ContextMenuContentScrollNode()
        
        self.actionNodes = actions.map { action in
            return ContextMenuActionNode(action: action)
        }
        
        if hasHapticFeedback {
            self.feedback = HapticFeedback()
            self.feedback?.prepareImpact(.light)
        } else {
            self.feedback = nil
        }
        
        super.init()
        
        self.containerNode.addSubnode(self.scrollNode)
        
        self.addSubnode(self.containerNode)
        let dismissNode = {
            dismiss()
        }
        for actionNode in self.actionNodes {
            actionNode.dismiss = dismissNode
            self.scrollNode.contentNode.addSubnode(actionNode)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var unboundActionsWidth: CGFloat = 0.0
        let actionSeparatorWidth: CGFloat = UIScreenPixel
        for actionNode in self.actionNodes {
            if !unboundActionsWidth.isZero {
                unboundActionsWidth += actionSeparatorWidth
            }
            let actionSize = actionNode.measure(CGSize(width: layout.size.width, height: 54.0))
            actionNode.frame = CGRect(origin: CGPoint(x: unboundActionsWidth, y: 0.0), size: actionSize)
            unboundActionsWidth += actionSize.width
        }
        
        let maxActionsWidth = layout.size.width - 20.0
        let actionsWidth = min(unboundActionsWidth, maxActionsWidth)
        
        let sourceRect: CGRect = self.sourceRect ?? CGRect(origin: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0), size: CGSize())
        let containerRect: CGRect = self.containerRect ?? self.bounds
        
        let insets = layout.insets(options: [.statusBar, .input])
        
        let verticalOrigin: CGFloat
        var arrowOnBottom = true
        if sourceRect.minY - 54.0 > containerRect.minY + insets.top {
            verticalOrigin = sourceRect.minY - 54.0
        } else {
            verticalOrigin = min(containerRect.maxY - insets.bottom - 54.0, sourceRect.maxY)
            arrowOnBottom = false
        }
        self.arrowOnBottom = arrowOnBottom
        
        let horizontalOrigin: CGFloat = floor(max(8.0, min(max(sourceRect.minX + 8.0, sourceRect.midX - actionsWidth / 2.0), layout.size.width - actionsWidth - 8.0)))
        
        self.containerNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin), size: CGSize(width: actionsWidth, height: 54.0))
        self.containerNode.relativeArrowPosition = (sourceRect.midX - horizontalOrigin, arrowOnBottom)
        
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: actionsWidth, height: 54.0))
        self.scrollNode.contentWidth = unboundActionsWidth
        
        self.containerNode.layout()
        self.scrollNode.layout()
    }
    
    func animateIn(bounce: Bool) {
        if bounce {
            self.containerNode.layer.animateSpring(from: NSNumber(value: Float(0.2)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.4)
            let containerPosition = self.containerNode.layer.position
            self.containerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: containerPosition.x, y: containerPosition.y + (self.arrowOnBottom ? 1.0 : -1.0) * self.containerNode.bounds.size.height / 2.0)), to: NSValue(cgPoint: containerPosition), keyPath: "position", duration: 0.4)
        }
        
        self.allowsGroupOpacity = true
        self.layer.rasterizationScale = UIScreen.main.scale
        self.layer.shouldRasterize = true
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { [weak self] _ in
            self?.allowsGroupOpacity = false
            self?.layer.shouldRasterize = false
        })
        
        if let feedback = self.feedback {
            feedback.impact(.light)
        }
    }
    
    func animateOut(bounce: Bool, completion: @escaping () -> Void) {
        self.allowsGroupOpacity = true
        self.layer.rasterizationScale = UIScreen.main.scale
        self.layer.shouldRasterize = true
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?.allowsGroupOpacity = false
            self?.layer.shouldRasterize = false
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event = event {
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                if !self.containerNode.frame.contains(point) {
                    if !self.dismissedByTouchOutside {
                        self.dismissedByTouchOutside = true
                        self.dismiss()
                    }
                    if self.catchTapsOutside {
                        return self.view
                    }
                    return nil
                }
            }
        }
        return super.hitTest(point, with: event)
    }
}
