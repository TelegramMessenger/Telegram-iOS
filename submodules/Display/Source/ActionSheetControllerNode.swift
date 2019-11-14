import UIKit
import AsyncDisplayKit

private let containerInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)

final class ActionSheetControllerNode: ASDisplayNode, UIScrollViewDelegate {
    var theme: ActionSheetControllerTheme {
        didSet {
            self.itemGroupsContainerNode.theme = self.theme
            self.updateTheme()
        }
    }
    
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
    
    init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
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
        
        self.validLayout = layout
        
        self.scrollView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.dismissTapView.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        self.itemGroupsContainerNode.measure(CGSize(width: layout.size.width - containerInsets.left - containerInsets.right - insets.left - insets.right, height: layout.size.height - containerInsets.top - containerInsets.bottom - insets.top - insets.bottom))
        self.itemGroupsContainerNode.frame = CGRect(origin: CGPoint(x: insets.left + containerInsets.left, y: layout.size.height - insets.bottom - containerInsets.bottom - self.itemGroupsContainerNode.calculatedSize.height), size: self.itemGroupsContainerNode.calculatedSize)
        self.itemGroupsContainerNode.layout()
        
        self.updateScrollDimViews(size: layout.size, insets: insets)
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
        if case .ended = recognizer.state {
            self.animateOut(cancelled: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let layout = self.validLayout {
            var insets = layout.insets(options: [.statusBar])
            
            let containerWidth = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
            
            insets.left = floor((layout.size.width - containerWidth) / 2.0)
            insets.right = insets.left
            
            self.updateScrollDimViews(size: layout.size, insets: insets)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = self.scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.animateOut(cancelled: true)
        }
    }
    
    func updateScrollDimViews(size: CGSize, insets: UIEdgeInsets) {
        let additionalTopHeight = max(0.0, -self.scrollView.contentOffset.y)
        let additionalBottomHeight = -min(0.0, -self.scrollView.contentOffset.y)
        
        self.topDimView.frame = CGRect(x: containerInsets.left + insets.left, y: -additionalTopHeight, width: size.width - containerInsets.left - containerInsets.right - insets.left - insets.right, height: max(0.0, self.itemGroupsContainerNode.frame.minY + additionalTopHeight))
        self.bottomDimView.frame = CGRect(x: containerInsets.left + insets.left, y: self.itemGroupsContainerNode.frame.maxY, width: size.width - containerInsets.left - containerInsets.right - insets.left - insets.right, height: max(0.0, size.height - self.itemGroupsContainerNode.frame.maxY + additionalBottomHeight))
        
        self.leftDimView.frame = CGRect(x: 0.0, y: -additionalTopHeight, width: containerInsets.left + insets.left, height: size.height + additionalTopHeight + additionalBottomHeight)
        self.rightDimView.frame = CGRect(x: size.width - containerInsets.right - insets.right, y: -additionalTopHeight, width: containerInsets.right + insets.right, height: size.height + additionalTopHeight + additionalBottomHeight)
    }
    
    func setGroups(_ groups: [ActionSheetItemGroup]) {
        self.itemGroupsContainerNode.setGroups(groups)
    }
    
    public func updateItem(groupIndex: Int, itemIndex: Int, _ f: (ActionSheetItem) -> ActionSheetItem) {
        self.itemGroupsContainerNode.updateItem(groupIndex: groupIndex, itemIndex: itemIndex, f)
    }
}
