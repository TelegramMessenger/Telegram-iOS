import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import SwipeToDismissGesture

open class GalleryControllerNode: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public var statusBar: StatusBar?
    public var navigationBar: NavigationBar? {
        didSet {
            
        }
    }
    public let footerNode: GalleryFooterNode
    public var currentThumbnailContainerNode: GalleryThumbnailContainerNode?
    public var overlayNode: ASDisplayNode?
    public var transitionDataForCentralItem: (() -> ((ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, (UIView) -> Void)?)?
    public var dismiss: (() -> Void)?
    
    public var containerLayout: (CGFloat, ContainerViewLayout)?
    public var backgroundNode: ASDisplayNode
    public var scrollView: UIScrollView
    public var pager: GalleryPagerNode
    
    public var beginCustomDismiss: (Bool) -> Void = { _ in }
    public var completeCustomDismiss: () -> Void = { }
    public var baseNavigationController: () -> NavigationController? = { return nil }
    public var galleryController: () -> ViewController? = { return nil }
    
    private var presentationState = GalleryControllerPresentationState()
    
    private var isDismissed = false
    
    public var areControlsHidden = false
    public var controlsVisibilityChanged: ((Bool) -> Void)?
    
    public var animateAlpha = true
    
    public var updateOrientation: ((UIInterfaceOrientation) -> Void)?
    
    public var isBackgroundExtendedOverNavigationBar = true {
        didSet {
            if let (navigationBarHeight, layout) = self.containerLayout {
                self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - (self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight)))
            }
        }
    }
    
    public init(controllerInteraction: GalleryControllerInteraction, pageGap: CGFloat = 20.0, disableTapNavigation: Bool = false) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor.black
        self.scrollView = UIScrollView()
        self.scrollView.delaysContentTouches = false

        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }

        self.pager = GalleryPagerNode(pageGap: pageGap, disableTapNavigation: disableTapNavigation)
        self.footerNode = GalleryFooterNode(controllerInteraction: controllerInteraction)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.pager.toggleControlsVisibility = { [weak self] in
            if let strongSelf = self {
                strongSelf.setControlsHidden(!strongSelf.areControlsHidden, animated: true)
            }
        }
        
        self.pager.updateControlsVisibility = { [weak self] visible in
            if let strongSelf = self {
                strongSelf.setControlsHidden(!visible, animated: true)
            }
        }
        
        self.pager.updateOrientation = { [weak self] orientation in
            if let strongSelf = self {
                strongSelf.updateOrientation?(orientation)
            }
        }
        
        self.pager.dismiss = { [weak self] in
            if let strongSelf = self {
                var interfaceAnimationCompleted = false
                var contentAnimationCompleted = true
                
                strongSelf.scrollView.isScrollEnabled = false
                let completion = { [weak self] in
                    if interfaceAnimationCompleted && contentAnimationCompleted {
                        if let dismiss = self?.dismiss {
                            dismiss()
                        }
                    }
                }
                
                if let centralItemNode = strongSelf.pager.centralItemNode(), let (transitionNodeForCentralItem, addToTransitionSurface) = strongSelf.transitionDataForCentralItem?(), let node = transitionNodeForCentralItem {
                    contentAnimationCompleted = false
                    centralItemNode.animateOut(to: node, addToTransitionSurface: addToTransitionSurface, completion: {
                        contentAnimationCompleted = true
                        completion()
                    })
                }
                strongSelf.animateOut(animateContent: false, completion: {
                    interfaceAnimationCompleted = true
                    completion()
                })
            }
        }
                
        self.pager.beginCustomDismiss = { [weak self] simpleAnimation in
            if let strongSelf = self {
                strongSelf.beginCustomDismiss(simpleAnimation)
            }
        }
        
        self.pager.completeCustomDismiss = { [weak self] in
            if let strongSelf = self {
                strongSelf.completeCustomDismiss()
            }
        }
        
        self.pager.baseNavigationController = { [weak self] in
            return self?.baseNavigationController()
        }
        self.pager.galleryController = { [weak self] in
            return self?.galleryController()
        }
        
        self.addSubnode(self.backgroundNode)
        
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.clipsToBounds = false
        self.scrollView.delegate = self
        self.scrollView.scrollsToTop = false
        self.view.addSubview(self.scrollView)
        
        self.scrollView.addSubview(self.pager.view)
        
        var previousIndex: Int?
        self.pager.centralItemIndexOffsetUpdated = { [weak self] itemsIndexAndProgress in
            if let strongSelf = self {
                if abs(strongSelf.scrollView.contentOffset.y - strongSelf.scrollView.contentSize.height / 3.0) > 0.1 {
                    strongSelf.scrollView.setContentOffset(CGPoint(x: 0.0, y: strongSelf.scrollView.contentSize.height / 3.0), animated: true)
                }
                
                var node: GalleryThumbnailContainerNode?
                var thumbnailContainerVisible = false
                if let layout = strongSelf.containerLayout?.1, layout.size.width < layout.size.height {
                    thumbnailContainerVisible = !strongSelf.areControlsHidden
                }
                if let (updatedItems, index, progress) = itemsIndexAndProgress {
                    if let (centralId, centralItem) = strongSelf.pager.items[index].thumbnailItem() {
                        var items: [GalleryThumbnailItem]
                        var indexes: [Int]
                        
                        if updatedItems != nil || strongSelf.currentThumbnailContainerNode == nil {
                            items = [centralItem]
                            indexes = [index]
                            for i in (0 ..< index).reversed() {
                                if let (id, item) = strongSelf.pager.items[i].thumbnailItem(), id == centralId {
                                    items.insert(item, at: 0)
                                    indexes.insert(i, at: 0)
                                } else {
                                    break
                                }
                            }
                            for i in (index + 1) ..< strongSelf.pager.items.count {
                                if let (id, item) = strongSelf.pager.items[i].thumbnailItem(), id == centralId {
                                    items.append(item)
                                    indexes.append(i)
                                } else {
                                    break
                                }
                            }
                        } else if let currentThumbnailContainerNode = strongSelf.currentThumbnailContainerNode {
                            items = currentThumbnailContainerNode.items
                            indexes = currentThumbnailContainerNode.indexes
                        } else {
                            items = []
                            indexes = []
                            assertionFailure()
                        }
                        
                        var convertedIndex: Int?
                        if let firstIndex = indexes.first {
                            convertedIndex = index - firstIndex
                        }
                        
                        if let convertedIndex = convertedIndex {
                            if strongSelf.currentThumbnailContainerNode?.groupId != centralId {
                                if items.count > 1 {
                                    node = GalleryThumbnailContainerNode(groupId: centralId)
                                }
                            } else {
                                node = strongSelf.currentThumbnailContainerNode
                            }
                            node?.alpha = thumbnailContainerVisible ? 1.0 : 0.0
                            node?.updateItems(items, indexes: indexes, centralIndex: convertedIndex, progress: progress)
                            node?.itemChanged = { [weak self] index in
                                if let strongSelf = self {
                                    let pagerIndex = indexes[index]
                                    strongSelf.pager.transaction(GalleryPagerTransaction(deleteItems: [], insertItems: [], updateItems: [], focusOnItem: pagerIndex, synchronous: false))
                                }
                            }
                        }
                    }
                }
                let previous = previousIndex
                previousIndex = itemsIndexAndProgress?.1
                if node !== strongSelf.currentThumbnailContainerNode {
                    let fromLeft: Bool
                    if let previous = previous, let index = itemsIndexAndProgress?.1 {
                        fromLeft = index > previous
                    } else {
                        fromLeft = true
                    }
                    if let current = strongSelf.currentThumbnailContainerNode {
                        if thumbnailContainerVisible {
                            current.animateOut(toRight: fromLeft)
                            current.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak current] _ in
                                current?.removeFromSupernode()
                            })
                        }
                    }
                    strongSelf.currentThumbnailContainerNode = node
                    if let node = node {
                        strongSelf.insertSubnode(node, aboveSubnode: strongSelf.footerNode)
                        if let (navigationHeight, layout) = strongSelf.containerLayout, thumbnailContainerVisible {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                            node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            node.animateIn(fromLeft: fromLeft)
                        }
                    }
                }
            }
        }
    }
    
    override open func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *), !self.isLayerBacked {
            self.view.accessibilityIgnoresInvertColors = true
        }
    }
    
    open func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (navigationBarHeight, layout)
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - (self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight))))
        
        transition.updateFrame(node: self.footerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        if let navigationBar = self.navigationBar {
            transition.updateFrame(node: navigationBar, frame: CGRect(origin: CGPoint(x: 0.0, y: self.areControlsHidden ? -navigationBarHeight : 0.0), size: CGSize(width: layout.size.width, height: navigationBarHeight)))
            if self.footerNode.supernode == nil {
                self.addSubnode(self.footerNode)
            }
        }
            
        var thumbnailPanelHeight: CGFloat = 0.0
        if let currentThumbnailContainerNode = self.currentThumbnailContainerNode {
            let panelHeight: CGFloat = 52.0
            thumbnailPanelHeight = panelHeight
            
            let thumbnailsFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - 40.0 - panelHeight + 4.0 - layout.intrinsicInsets.bottom + (self.areControlsHidden ? 106.0 : 0.0)), size: CGSize(width: layout.size.width, height: panelHeight - 4.0))
            transition.updateFrame(node: currentThumbnailContainerNode, frame: thumbnailsFrame)
            currentThumbnailContainerNode.updateLayout(size: thumbnailsFrame.size, transition: transition)
            
            self.updateThumbnailContainerNodeAlpha(transition)
        }
        
        self.footerNode.updateLayout(layout, navigationBarHeight: navigationBarHeight, footerContentNode: self.presentationState.footerContentNode, overlayContentNode: self.presentationState.overlayContentNode, thumbnailPanelHeight: thumbnailPanelHeight, isHidden: self.areControlsHidden, transition: transition)
    
        let previousContentHeight = self.scrollView.contentSize.height
        let previousVerticalOffset = self.scrollView.contentOffset.y
        
        self.scrollView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollView.contentSize = CGSize(width: 0.0, height: layout.size.height * 3.0)
        
        if previousContentHeight.isEqual(to: 0.0) {
            self.scrollView.contentOffset = CGPoint(x: 0.0, y: self.scrollView.contentSize.height / 3.0)
        } else {
            self.scrollView.contentOffset = CGPoint(x: 0.0, y: previousVerticalOffset * self.scrollView.contentSize.height / previousContentHeight)
        }
        
        self.pager.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: layout.size)

        self.pager.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    open func setControlsHidden(_ hidden: Bool, animated: Bool) {
        guard self.areControlsHidden != hidden && (!self.isDismissed || hidden) else {
            return
        }
        self.areControlsHidden = hidden
        self.controlsVisibilityChanged?(!hidden)
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                let alpha: CGFloat = self.areControlsHidden ? 0.0 : 1.0
                self.navigationBar?.alpha = alpha
                self.statusBar?.updateAlpha(alpha, transition: .animated(duration: 0.3, curve: .easeInOut))
                self.footerNode.setVisibilityAlpha(alpha, animated: animated)
                self.updateThumbnailContainerNodeAlpha(.immediate)
            })
            
            if let (navigationBarHeight, layout) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        } else {
            let alpha: CGFloat = self.areControlsHidden ? 0.0 : 1.0
            self.navigationBar?.alpha = alpha
            self.statusBar?.updateAlpha(alpha, transition: .immediate)
            self.footerNode.setVisibilityAlpha(alpha, animated: animated)
            self.updateThumbnailContainerNodeAlpha(.immediate)
            
            if let (navigationBarHeight, layout) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
    }

    open func updateThumbnailContainerNodeAlpha(_ transition: ContainedViewLayoutTransition) {
        if let currentThumbnailContainerNode = self.currentThumbnailContainerNode, let layout = self.containerLayout?.1 {
            let visible = layout.size.width < layout.size.height && !self.areControlsHidden
            transition.updateAlpha(node: currentThumbnailContainerNode, alpha: visible ? 1.0 : 0.0)
        }
    }
    
    open func animateIn(animateContent: Bool, useSimpleAnimation: Bool) {
        let duration: Double = animateContent ? 0.2 : 0.3
        
        let backgroundColor = self.backgroundNode.backgroundColor ?? .black
        
        self.statusBar?.alpha = 0.0
        self.navigationBar?.alpha = 0.0
        self.footerNode.alpha = 0.0
        self.currentThumbnailContainerNode?.alpha = 0.0
        
        self.backgroundNode.layer.animate(from: backgroundColor.withAlphaComponent(0.0).cgColor, to: backgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.15)
        
        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.curveLinear], animations: {
            if !self.areControlsHidden {
                self.statusBar?.alpha = 1.0
                self.navigationBar?.alpha = 1.0
                self.footerNode.alpha = 1.0
                self.updateThumbnailContainerNodeAlpha(.immediate)
            }
        })
        
        if animateContent {
            self.scrollView.layer.animateBounds(from: self.scrollView.layer.bounds.offsetBy(dx: 0.0, dy: -self.scrollView.layer.bounds.size.height), to: self.scrollView.layer.bounds, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        } else if useSimpleAnimation {
            self.scrollView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
    }
    
    open func animateOut(animateContent: Bool, completion: @escaping () -> Void) {
        self.isDismissed = true
        
        self.pager.isScrollEnabled = false
        
        var contentAnimationCompleted = true
        var interfaceAnimationCompleted = false
        
        let intermediateCompletion = {
            if contentAnimationCompleted && interfaceAnimationCompleted {
                completion()
            }
        }
        
        if let backgroundColor = self.backgroundNode.backgroundColor {
            let updatedColor = backgroundColor.withAlphaComponent(0.0)
            self.backgroundNode.backgroundColor = updatedColor
            self.backgroundNode.layer.animate(from: backgroundColor.cgColor, to: updatedColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.15)
        }
        UIView.animate(withDuration: 0.25, animations: {
            self.statusBar?.alpha = 0.0
            self.navigationBar?.alpha = 0.0
            self.footerNode.alpha = 0.0
            self.currentThumbnailContainerNode?.alpha = 0.0
        }, completion: { _ in
            interfaceAnimationCompleted = true
            intermediateCompletion()
        })
        
        if animateContent {
            contentAnimationCompleted = false
            self.scrollView.layer.animateBounds(from: self.scrollView.layer.bounds, to: self.scrollView.layer.bounds.offsetBy(dx: 0.0, dy: -self.scrollView.layer.bounds.size.height), duration: 0.25, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { _ in
                contentAnimationCompleted = true
                intermediateCompletion()
            })
        } else if self.animateAlpha {
            self.scrollView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                contentAnimationCompleted = true
                intermediateCompletion()
            })
        }
    }
    
    open func updateDismissTransition(_ value: CGFloat) {
    }
    
    open func updateDistanceFromEquilibrium(_ value: CGFloat) {
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.isDismissed {
            return
        }
        let distanceFromEquilibrium = scrollView.contentOffset.y - scrollView.contentSize.height / 3.0
        
        let transition = 1.0 - min(1.0, max(0.0, abs(distanceFromEquilibrium) / 50.0))
        let backgroundTransition = 1.0 - min(1.0, max(0.0, abs(distanceFromEquilibrium) / 80.0))
        self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(backgroundTransition)
        
        self.updateThumbnailContainerNodeAlpha(.immediate)
        
        if !self.areControlsHidden {
            if transition < 0.5 {
                self.statusBar?.statusBarStyle = .Ignore
            } else {
                self.statusBar?.statusBarStyle = .White
            }
            self.navigationBar?.alpha = transition
            self.footerNode.alpha = transition
            
            if let currentThumbnailContainerNode = self.currentThumbnailContainerNode, let layout = self.containerLayout?.1, layout.size.width < layout.size.height {
                currentThumbnailContainerNode.alpha = transition
            }
        }
        
        self.updateDismissTransition(transition)
        self.updateDistanceFromEquilibrium(distanceFromEquilibrium)
        
        if let overlayNode = self.overlayNode {
            overlayNode.alpha = transition
        }
    }
    
    open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        targetContentOffset.pointee = scrollView.contentOffset
        
        let distanceFromEquilibrium = scrollView.contentOffset.y - scrollView.contentSize.height / 3.0
        let minimalDismissDistance = scrollView.contentSize.height / 12.0
        if abs(velocity.y) > 1.0 || abs(distanceFromEquilibrium) > minimalDismissDistance {
            if let backgroundColor = self.backgroundNode.backgroundColor {
                self.backgroundNode.layer.animate(from: backgroundColor, to: UIColor(white: 0.0, alpha: 0.0).cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2, removeOnCompletion: false)
            }
            
            var interfaceAnimationCompleted = false
            var contentAnimationCompleted = true
            
            self.scrollView.isScrollEnabled = false
            let completion = { [weak self] in
                if interfaceAnimationCompleted && contentAnimationCompleted {
                    if let dismiss = self?.dismiss {
                        dismiss()
                    }
                }
            }
            
            if let centralItemNode = self.pager.centralItemNode(), let (transitionNodeForCentralItem, addToTransitionSurface) = self.transitionDataForCentralItem?(), let node = transitionNodeForCentralItem {
                contentAnimationCompleted = false
                centralItemNode.animateOut(to: node, addToTransitionSurface: addToTransitionSurface, completion: {
                    contentAnimationCompleted = true
                    completion()
                })
            }
            
            self.animateOut(animateContent: false, completion: {
                interfaceAnimationCompleted = true
                completion()
            })
            
            if contentAnimationCompleted {
                contentAnimationCompleted = false
                self.scrollView.layer.animateBounds(from: self.scrollView.layer.bounds, to: self.scrollView.layer.bounds.offsetBy(dx: 0.0, dy: self.scrollView.layer.bounds.size.height * (velocity.y < 0.0 ? -1.0 : 1.0)), duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { _ in
                    contentAnimationCompleted = true
                    completion()
                })
            }
        } else {
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: self.scrollView.contentSize.height / 3.0), animated: true)
        }
    }
    
    open func updatePresentationState(_ f: (GalleryControllerPresentationState) -> GalleryControllerPresentationState, transition: ContainedViewLayoutTransition) {
        self.presentationState = f(self.presentationState)
        if let (navigationBarHeight, layout) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    @objc private func panGesture(_ recognizer: SwipeToDismissGestureRecognizer) {
        switch recognizer.state {
            case .began:
                break
            case .changed:
                break
            case .ended:
                break
            case .cancelled:
                break
            default:
                break
        }
    }
}
