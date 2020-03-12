import UIKit
import AsyncDisplayKit

final class ActionSheetItemGroupNode: ASDisplayNode, UIScrollViewDelegate {
    private let theme: ActionSheetControllerTheme
    
    private let centerDimView: UIImageView
    private let topDimView: UIView
    private let bottomDimView: UIView
    let trailingDimView: UIView
    
    private let clippingNode: ASDisplayNode
    private let backgroundEffectView: UIVisualEffectView
    private let scrollNode: ASScrollNode
    
    private var itemNodes: [ActionSheetItemNode] = []
    private var leadingVisibleNodeCount: CGFloat = 100.0
    
    var respectInputHeight = true
    
    init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.centerDimView = UIImageView()
        self.centerDimView.image = generateStretchableFilledCircleImage(radius: 16.0, color: nil, backgroundColor: self.theme.dimColor)
        
        self.topDimView = UIView()
        self.topDimView.backgroundColor = self.theme.dimColor
        self.topDimView.isUserInteractionEnabled = false
        
        self.bottomDimView = UIView()
        self.bottomDimView.backgroundColor = self.theme.dimColor
        self.bottomDimView.isUserInteractionEnabled = false
        
        self.trailingDimView = UIView()
        self.trailingDimView.backgroundColor = self.theme.dimColor
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        self.clippingNode.cornerRadius = 16.0
        
        self.backgroundEffectView = UIVisualEffectView(effect: UIBlurEffect(style: self.theme.backgroundType == .light ? .light : .dark))
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.canCancelAllTouchesInViews = true
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        
        super.init()
        
        self.view.addSubview(self.centerDimView)
        self.view.addSubview(self.topDimView)
        self.view.addSubview(self.bottomDimView)
        self.view.addSubview(self.trailingDimView)
        
        self.scrollNode.view.delegate = self
        
        self.clippingNode.view.addSubview(self.backgroundEffectView)
        self.clippingNode.addSubnode(self.scrollNode)
        
        self.addSubnode(self.clippingNode)
    }
    
    func updateItemNodes(_ nodes: [ActionSheetItemNode], leadingVisibleNodeCount: CGFloat = 1000.0) {
        for node in self.itemNodes {
            if !nodes.contains(where: { $0 === node }) {
                node.removeFromSupernode()
            }
        }
        
        for node in nodes {
            if !self.itemNodes.contains(where: { $0 === node }) {
                self.scrollNode.addSubnode(node)
            }
        }
        
        self.itemNodes = nodes
        self.leadingVisibleNodeCount = leadingVisibleNodeCount
        self.invalidateCalculatedLayout()
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        var itemNodesHeight: CGFloat = 0.0
        var leadingVisibleNodeSize: CGFloat = 0.0
        
        var i = 0
        for node in self.itemNodes {
            if CGFloat(0.0).isLess(than: itemNodesHeight) {
                itemNodesHeight += UIScreenPixel
            }
            let size = node.measure(constrainedSize)
            itemNodesHeight += size.height
            
            if ceil(CGFloat(i)).isLessThanOrEqualTo(leadingVisibleNodeCount) {
                if CGFloat(0.0).isLess(than: leadingVisibleNodeSize) {
                    leadingVisibleNodeSize += UIScreenPixel
                }
                let factor: CGFloat = min(1.0, leadingVisibleNodeCount - CGFloat(i))
                leadingVisibleNodeSize += size.height * factor
            }
            i += 1
        }
        
        return CGSize(width: constrainedSize.width, height: min(floorToScreenPixels(itemNodesHeight), constrainedSize.height))
    }
    
    override func layout() {
        let scrollViewFrame = CGRect(origin: CGPoint(), size: self.calculatedSize)
        var updateOffset = false
        if !self.scrollNode.frame.equalTo(scrollViewFrame) {
            self.scrollNode.frame = scrollViewFrame
            updateOffset = true
        }
        
        let backgroundEffectViewFrame = CGRect(origin: CGPoint(), size: self.calculatedSize)
        if !self.backgroundEffectView.frame.equalTo(backgroundEffectViewFrame) {
            self.backgroundEffectView.frame = backgroundEffectViewFrame
        }
        
        var itemNodesHeight: CGFloat = 0.0
        var leadingVisibleNodeSize: CGFloat = 0.0
        
        var i = 0
        for node in self.itemNodes {
            if CGFloat(0.0).isLess(than: itemNodesHeight) {
                itemNodesHeight += UIScreenPixel
            }
            node.frame = CGRect(origin: CGPoint(x: 0.0, y: itemNodesHeight), size: node.calculatedSize)
            itemNodesHeight += node.calculatedSize.height
            
            if CGFloat(i).isLessThanOrEqualTo(leadingVisibleNodeCount) {
                if CGFloat(0.0).isLess(than: leadingVisibleNodeSize) {
                    leadingVisibleNodeSize += UIScreenPixel
                }
                let factor: CGFloat = min(1.0, leadingVisibleNodeCount - CGFloat(i))
                leadingVisibleNodeSize += node.calculatedSize.height * factor
            }
            i += 1
        }
        
        let scrollViewContentSize = CGSize(width: self.calculatedSize.width, height: itemNodesHeight)
        if !self.scrollNode.view.contentSize.equalTo(scrollViewContentSize) {
            self.scrollNode.view.contentSize = scrollViewContentSize
        }
        let scrollViewContentInsets = UIEdgeInsets(top: max(0.0, self.calculatedSize.height - leadingVisibleNodeSize), left: 0.0, bottom: 0.0, right: 0.0)
        
        if self.scrollNode.view.contentInset != scrollViewContentInsets {
            self.scrollNode.view.contentInset = scrollViewContentInsets
        }
        
        if updateOffset {
            self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: -scrollViewContentInsets.top)
        }
        
        self.updateOverscroll()
    }
    
    private func currentVerticalOverscroll() -> CGFloat {
        var verticalOverscroll: CGFloat = 0.0
        if scrollNode.view.contentOffset.y < 0.0 {
            verticalOverscroll = scrollNode.view.contentOffset.y
        } else if scrollNode.view.contentOffset.y > scrollNode.view.contentSize.height - scrollNode.view.bounds.size.height {
            verticalOverscroll = scrollNode.view.contentOffset.y - (scrollNode.view.contentSize.height - scrollNode.view.bounds.size.height)
        }
        return verticalOverscroll
    }
    
    private func currentRealVerticalOverscroll() -> CGFloat {
        var verticalOverscroll: CGFloat = 0.0
        if scrollNode.view.contentOffset.y < 0.0 {
            verticalOverscroll = scrollNode.view.contentOffset.y
        } else if scrollNode.view.contentOffset.y > scrollNode.view.contentSize.height - scrollNode.view.bounds.size.height {
            verticalOverscroll = scrollNode.view.contentOffset.y - (scrollNode.view.contentSize.height - scrollNode.view.bounds.size.height)
        }
        return verticalOverscroll
    }
    
    private func updateOverscroll() {
        let verticalOverscroll = self.currentVerticalOverscroll()
        
        self.clippingNode.layer.sublayerTransform = CATransform3DMakeTranslation(0.0, min(0.0, verticalOverscroll), 0.0)
        let clippingNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, -verticalOverscroll)), size: CGSize(width: self.calculatedSize.width, height: self.calculatedSize.height - abs(verticalOverscroll)))
        if !self.clippingNode.frame.equalTo(clippingNodeFrame) {
            self.clippingNode.frame = clippingNodeFrame
            
            self.centerDimView.frame = clippingNodeFrame
            self.topDimView.frame = CGRect(x: 0.0, y: 0.0, width: clippingNodeFrame.size.width, height: max(0.0, clippingNodeFrame.minY))
            self.bottomDimView.frame = CGRect(x: 0.0, y: clippingNodeFrame.maxY, width: clippingNodeFrame.size.width, height: max(0.0, self.bounds.size.height - clippingNodeFrame.maxY))
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateOverscroll()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.clippingNode.frame.contains(point) {
            return super.hitTest(point, with: event)
        } else {
            return nil
        }
    }
    
    func animateDimViewsAlpha(from: CGFloat, to: CGFloat, duration: Double) {
        for node in [self.centerDimView, self.topDimView, self.bottomDimView] {
            node.layer.animateAlpha(from: from, to: to, duration: duration)
        }
    }
    
    func itemNode(at index: Int) -> ActionSheetItemNode {
        return self.itemNodes[index]
    }
}
