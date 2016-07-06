import UIKit
import AsyncDisplayKit

private let containerInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 8.0, right: 16.0)

private class ActionSheetControllerNodeScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
}

final class ActionSheetControllerNode: ASDisplayNode, UIScrollViewDelegate {
    static let dimColor: UIColor = UIColor(white: 0.0, alpha: 0.4)
    
    private let dismissTapView: UIView
    
    private let leftDimView: UIView
    private let rightDimView: UIView
    private let topDimView: UIView
    private let bottomDimView: UIView
    
    private let itemGroupsContainerNode: ActionSheetItemGroupsContainerNode
    
    private let scrollView: UIScrollView
    
    var dismiss: () -> Void = { }
    
    override init() {
        self.scrollView = ActionSheetControllerNodeScrollView()
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.delaysContentTouches = false
        self.scrollView.canCancelContentTouches = true
        
        self.dismissTapView = UIView()
        
        self.leftDimView = UIView()
        self.leftDimView.backgroundColor = ActionSheetControllerNode.dimColor
        self.leftDimView.isUserInteractionEnabled = false
        
        self.rightDimView = UIView()
        self.rightDimView.backgroundColor = ActionSheetControllerNode.dimColor
        self.rightDimView.isUserInteractionEnabled = false
        
        self.topDimView = UIView()
        self.topDimView.backgroundColor = ActionSheetControllerNode.dimColor
        self.topDimView.isUserInteractionEnabled = false
        
        self.bottomDimView = UIView()
        self.bottomDimView.backgroundColor = ActionSheetControllerNode.dimColor
        self.bottomDimView.isUserInteractionEnabled = false

        self.itemGroupsContainerNode = ActionSheetItemGroupsContainerNode()
        
        super.init()
        
        self.scrollView.delegate = self
        
        self.view.addSubview(self.scrollView)
        
        self.scrollView.addSubview(self.dismissTapView)
        
        self.scrollView.addSubview(self.leftDimView)
        self.scrollView.addSubview(self.rightDimView)
        self.scrollView.addSubview(self.topDimView)
        self.scrollView.addSubview(self.bottomDimView)
        
        self.dismissTapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTap(_:))))
        
        self.scrollView.addSubnode(self.itemGroupsContainerNode)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.statusBar])
        
        self.scrollView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.dismissTapView.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        self.itemGroupsContainerNode.measure(CGSize(width: layout.size.width - containerInsets.left - containerInsets.right - insets.left - insets.right, height: layout.size.height - containerInsets.top - containerInsets.bottom - insets.top - insets.bottom))
        self.itemGroupsContainerNode.frame = CGRect(origin: CGPoint(x: insets.left + containerInsets.left, y: layout.size.height - insets.bottom - containerInsets.bottom - self.itemGroupsContainerNode.calculatedSize.height), size: self.itemGroupsContainerNode.calculatedSize)
        self.itemGroupsContainerNode.layout()
        
        self.updateScrollDimViews(size: layout.size)
    }
    
    func animateIn() {
        let tempDimView = UIView()
        tempDimView.backgroundColor = ActionSheetControllerNode.dimColor
        tempDimView.frame = self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height)
        self.view.addSubview(tempDimView)
        
        for node in [tempDimView, self.topDimView, self.leftDimView, self.rightDimView, self.bottomDimView] {
            node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        }
        
        self.itemGroupsContainerNode.animateDimViewsAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        self.layer.animateBounds(from: self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height), to: self.bounds, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak tempDimView] _ in
            tempDimView?.removeFromSuperview()
        })
    }
    
    func animateOut() {
        let tempDimView = UIView()
        tempDimView.backgroundColor = ActionSheetControllerNode.dimColor
        tempDimView.frame = self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height)
        self.view.addSubview(tempDimView)
        
        for node in [tempDimView, self.topDimView, self.leftDimView, self.rightDimView, self.bottomDimView] {
            node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        }
        self.itemGroupsContainerNode.animateDimViewsAlpha(from: 1.0, to: 0.0, duration: 0.3)
        
        self.layer.animateBounds(from: self.bounds, to: self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height), duration: 0.35, timingFunction: kCAMediaTimingFunctionEaseOut, removeOnCompletion: false, completion: { [weak self, weak tempDimView] _ in
            tempDimView?.removeFromSuperview()
            
            self?.dismiss()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result
    }
    
    @objc func dimNodeTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.animateOut()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrollDimViews(size: self.scrollView.frame.size)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = self.scrollView.contentOffset
        var additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.animateOut()
        }
    }
    
    func updateScrollDimViews(size: CGSize) {
        var additionalTopHeight = max(0.0, -self.scrollView.contentOffset.y)
        var additionalBottomHeight = -min(0.0, -self.scrollView.contentOffset.y)
        
        self.topDimView.frame = CGRect(x: containerInsets.left, y: -additionalTopHeight, width: size.width - containerInsets.left - containerInsets.right, height: max(0.0, self.itemGroupsContainerNode.frame.minY + additionalTopHeight))
        self.bottomDimView.frame = CGRect(x: containerInsets.left, y: self.itemGroupsContainerNode.frame.maxY, width: size.width - containerInsets.left - containerInsets.right, height: max(0.0, size.height - self.itemGroupsContainerNode.frame.maxY + additionalBottomHeight))
        
        self.leftDimView.frame = CGRect(x: 0.0, y: -additionalTopHeight, width: containerInsets.left, height: size.height + additionalTopHeight + additionalBottomHeight)
        self.rightDimView.frame = CGRect(x: size.width - containerInsets.right, y: -additionalTopHeight, width: containerInsets.right, height: size.height + additionalTopHeight + additionalBottomHeight)
    }
    
    func setGroups(_ groups: [ActionSheetItemGroup]) {
        self.itemGroupsContainerNode.setGroups(groups)
    }
}
