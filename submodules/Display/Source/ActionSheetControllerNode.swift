import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private let containerInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)

final class ActionSheetControllerNode: ASDisplayNode, UIScrollViewDelegate {
    var theme: ActionSheetControllerTheme {
        didSet {
            self.itemGroupsContainerNode.theme = self.theme
            self.updateTheme()
        }
    }
    
    private var allowInputInset: Bool
    
    private let dismissTapView: UIView
    
    private let leftDimView: UIView
    private let rightDimView: UIView
    private let topDimView: UIView
    private let bottomDimView: UIView
    
    private let itemGroupsContainerNode: ActionSheetItemGroupsContainerNode
    
    private let scrollNode: ASScrollNode
    private let scrollView: UIScrollView
    
    var dismiss: (Bool) -> Void = { _ in }
    
    private var validLayout: ContainerViewLayout?
    
    init(theme: ActionSheetControllerTheme, allowInputInset: Bool) {
        self.theme = theme
        self.allowInputInset = allowInputInset
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.canCancelAllTouchesInViews = true
        self.scrollView = self.scrollNode.view
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.delaysContentTouches = false
        self.scrollView.canCancelContentTouches = true
        
        self.dismissTapView = UIView()
        
        self.leftDimView = UIView()
        self.leftDimView.isUserInteractionEnabled = false
        
        self.rightDimView = UIView()
        self.rightDimView.isUserInteractionEnabled = false
        
        self.topDimView = UIView()
        self.topDimView.isUserInteractionEnabled = false
        
        self.bottomDimView = UIView()
        self.bottomDimView.isUserInteractionEnabled = false

        self.itemGroupsContainerNode = ActionSheetItemGroupsContainerNode(theme: self.theme)
        self.itemGroupsContainerNode.isUserInteractionEnabled = false
        
        super.init()
                
        self.scrollView.delegate = self
        
        self.addSubnode(self.scrollNode)
        
        self.scrollView.addSubview(self.dismissTapView)
        
        self.scrollView.addSubview(self.leftDimView)
        self.scrollView.addSubview(self.rightDimView)
        self.scrollView.addSubview(self.topDimView)
        self.scrollView.addSubview(self.bottomDimView)
        
        self.dismissTapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTap(_:))))
        
        self.scrollNode.addSubnode(self.itemGroupsContainerNode)
        
        self.updateTheme()
        
        self.itemGroupsContainerNode.requestLayout = { [weak self] in
            if let strongSelf = self, let layout = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }
    }
    
    func updateTheme() {
        self.leftDimView.backgroundColor = self.theme.dimColor
        self.rightDimView.backgroundColor = self.theme.dimColor
        self.topDimView.backgroundColor = self.theme.dimColor
        self.bottomDimView.backgroundColor = self.theme.dimColor
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.statusBar])
        
        let containerWidth = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
        
        insets.left = floor((layout.size.width - containerWidth) / 2.0)
        insets.right = insets.left
        if !insets.bottom.isZero {
            insets.bottom -= 12.0
        }
        
        if self.allowInputInset, let inputInset = layout.inputHeight, inputInset > 0.0 {
            insets.bottom = inputInset
        }
        
        self.validLayout = layout
        
        self.scrollView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.dismissTapView.frame = CGRect(origin: CGPoint(), size: layout.size)
                
        let itemGroupsContainerSize = self.itemGroupsContainerNode.updateLayout(constrainedSize: CGSize(width: layout.size.width - containerInsets.left - containerInsets.right - insets.left - insets.right, height: layout.size.height - containerInsets.top - containerInsets.bottom - insets.top - insets.bottom), transition: transition)
        
        if self.allowInputInset, let inputHeight = layout.inputHeight, inputHeight > 0.0, self.itemGroupsContainerNode.groupNodes.count > 1, let lastGroupHeight = self.itemGroupsContainerNode.groupNodes.last?.frame.height {
            insets.bottom -= lastGroupHeight + containerInsets.bottom
        }
        
        var transition = transition
        if !self.allowInputInset {
            transition = .immediate
        }
        transition.updateFrame(node: self.itemGroupsContainerNode, frame: CGRect(origin: CGPoint(x: insets.left + containerInsets.left, y: layout.size.height - insets.bottom - containerInsets.bottom - itemGroupsContainerSize.height), size: itemGroupsContainerSize))
        
        self.updateScrollDimViews(size: layout.size, insets: insets, transition: transition)
    }
    
    
    func animateIn(completion: @escaping () -> Void) {
        let tempDimView = UIView()
        tempDimView.backgroundColor = self.theme.dimColor
        tempDimView.frame = self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height)
        self.view.addSubview(tempDimView)
        
        for node in [tempDimView, self.topDimView, self.leftDimView, self.rightDimView, self.bottomDimView] {
            node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        }
        
        self.itemGroupsContainerNode.animateDimViewsAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        self.layer.animateBounds(from: self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height), to: self.bounds, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak tempDimView] _ in
            tempDimView?.removeFromSuperview()
            completion()
        })
        
        Queue.mainQueue().after(0.3, {
            self.itemGroupsContainerNode.isUserInteractionEnabled = true
        })
    }
    
    func animateOut(cancelled: Bool) {
        let tempDimView = UIView()
        tempDimView.backgroundColor = self.theme.dimColor
        tempDimView.frame = self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height)
        self.view.addSubview(tempDimView)
        
        for node in [tempDimView, self.topDimView, self.leftDimView, self.rightDimView, self.bottomDimView] {
            node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        }
        self.itemGroupsContainerNode.animateDimViewsAlpha(from: 1.0, to: 0.0, duration: 0.3)
        
        self.layer.animateBounds(from: self.bounds, to: self.bounds.offsetBy(dx: 0.0, dy: -self.bounds.size.height), duration: 0.35, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self, weak tempDimView] _ in
            tempDimView?.removeFromSuperview()
            
            self?.dismiss(cancelled)
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result
    }
    
    @objc func dimNodeTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, self.itemGroupsContainerNode.isUserInteractionEnabled {
            self.view.window?.endEditing(true)
            self.animateOut(cancelled: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let layout = self.validLayout {
            var insets = layout.insets(options: [.statusBar])
            
            let containerWidth = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
            
            insets.left = floor((layout.size.width - containerWidth) / 2.0)
            insets.right = insets.left
            
            self.updateScrollDimViews(size: layout.size, insets: insets, transition: .immediate)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = self.scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.animateOut(cancelled: true)
        }
    }
    
    func updateScrollDimViews(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        let additionalTopHeight = max(0.0, -self.scrollView.contentOffset.y)
        let additionalBottomHeight = -min(0.0, -self.scrollView.contentOffset.y)
        
        transition.updateFrame(view: self.topDimView, frame: CGRect(x: containerInsets.left + insets.left, y: -additionalTopHeight, width: size.width - containerInsets.left - containerInsets.right - insets.left - insets.right, height: max(0.0, self.itemGroupsContainerNode.frame.minY + additionalTopHeight)))
        transition.updateFrame(view: self.bottomDimView, frame: CGRect(x: containerInsets.left + insets.left, y: self.itemGroupsContainerNode.frame.maxY, width: size.width - containerInsets.left - containerInsets.right - insets.left - insets.right, height: max(0.0, size.height - self.itemGroupsContainerNode.frame.maxY + additionalBottomHeight)))
        transition.updateFrame(view: self.leftDimView, frame: CGRect(x: 0.0, y: -additionalTopHeight, width: containerInsets.left + insets.left, height: size.height + additionalTopHeight + additionalBottomHeight))
        transition.updateFrame(view: self.rightDimView, frame: CGRect(x: size.width - containerInsets.right - insets.right, y: -additionalTopHeight, width: containerInsets.right + insets.right, height: size.height + additionalTopHeight + additionalBottomHeight))
    }
    
    func setGroups(_ groups: [ActionSheetItemGroup]) {
        self.itemGroupsContainerNode.setGroups(groups)
    }
    
    func updateItem(groupIndex: Int, itemIndex: Int, _ f: (ActionSheetItem) -> ActionSheetItem) {
        self.itemGroupsContainerNode.updateItem(groupIndex: groupIndex, itemIndex: itemIndex, f)
    }
    
    func setItemGroupOverlayNode(groupIndex: Int, node: ActionSheetGroupOverlayNode) {
        self.itemGroupsContainerNode.setItemGroupOverlayNode(groupIndex: groupIndex, node: node)
    }
}
