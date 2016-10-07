import Foundation
import UIKit
import AsyncDisplayKit

final class ContextMenuNode: ASDisplayNode {
    private let actions: [ContextMenuAction]
    private let dismiss: () -> Void
    
    private let containerNode: ContextMenuContainerNode
    private let actionNodes: [ContextMenuActionNode]
    
    var sourceRect: CGRect?
    var arrowOnBottom: Bool = true
    
    private var dismissedByTouchOutside = false
    
    init(actions: [ContextMenuAction], dismiss: @escaping () -> Void) {
        self.actions = actions
        self.dismiss = dismiss
        
        self.containerNode = ContextMenuContainerNode()
        
        self.actionNodes = actions.map { action in
            return ContextMenuActionNode(action: action)
        }
        
        super.init()
        
        self.addSubnode(self.containerNode)
        let dismissNode = { [weak self] in
            dismiss()
        }
        for actionNode in self.actionNodes {
            actionNode.dismiss = dismissNode
            self.containerNode.addSubnode(actionNode)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var actionsWidth: CGFloat = 0.0
        let actionSeparatorWidth: CGFloat = UIScreenPixel
        for actionNode in self.actionNodes {
            if !actionsWidth.isZero {
                actionsWidth += actionSeparatorWidth
            }
            let actionSize = actionNode.measure(CGSize(width: layout.size.width, height: 54.0))
            actionNode.frame = CGRect(origin: CGPoint(x: actionsWidth, y: 0.0), size: actionSize)
            actionsWidth += actionSize.width
        }
        
        let sourceRect: CGRect = self.sourceRect ?? CGRect(origin: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0), size: CGSize())
        
        let insets = layout.insets(options: [.statusBar, .input])
        
        let verticalOrigin: CGFloat
        var arrowOnBottom = true
        if sourceRect.minY - 54.0 > insets.top {
            verticalOrigin = sourceRect.minY - 54.0
        } else {
            verticalOrigin = min(layout.size.height - insets.bottom - 54.0, sourceRect.maxY)
            arrowOnBottom = false
        }
        self.arrowOnBottom = arrowOnBottom
        
        let horizontalOrigin: CGFloat = floor(min(max(8.0, sourceRect.midX - actionsWidth / 2.0), layout.size.width - actionsWidth - 8.0))
        
        self.containerNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin), size: CGSize(width: actionsWidth, height: 54.0))
        self.containerNode.relativeArrowPosition = (sourceRect.midX - horizontalOrigin, arrowOnBottom)
        
        self.containerNode.layout()
    }
    
    func animateIn() {
        self.containerNode.layer.animateSpring(from: NSNumber(value: Float(0.2)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.4)
        
        let containerPosition = self.containerNode.layer.position
        self.containerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: containerPosition.x, y: containerPosition.y + (self.arrowOnBottom ? 1.0 : -1.0) * self.containerNode.bounds.size.height / 2.0)), to: NSValue(cgPoint: containerPosition), keyPath: "position", duration: 0.4)
        
        self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event = event {
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                if !self.containerNode.frame.contains(point) {
                    if !self.dismissedByTouchOutside {
                        self.dismissedByTouchOutside = true
                        self.dismiss()
                    }
                    return nil
                }
            }
        }
        return super.hitTest(point, with: event)
    }
}
