import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox

class GalleryControllerNode: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var statusBar: StatusBar?
    var navigationBar: NavigationBar?
    let footerNode: GalleryFooterNode
    var currentThumbnailContainerNode: GalleryThumbnailContainerNode?
    var overlayNode: ASDisplayNode?
    var transitionDataForCentralItem: (() -> ((ASDisplayNode, () -> (UIView?, UIView?))?, (UIView) -> Void)?)?
    var dismiss: (() -> Void)?
    
    var containerLayout: (CGFloat, ContainerViewLayout)?
    var backgroundNode: ASDisplayNode
    var scrollView: UIScrollView
    var pager: GalleryPagerNode
    
    var beginCustomDismiss: () -> Void = { }
    var completeCustomDismiss: () -> Void = { }
    var baseNavigationController: () -> NavigationController? = { return nil }
    
    private var presentationState = GalleryControllerPresentationState()
    
    private var isDismissed = false
    
    var areControlsHidden = false
    var isBackgroundExtendedOverNavigationBar = true {
        didSet {
            if let (navigationBarHeight, layout) = self.containerLayout {
                self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - (self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight)))
            }
        }
    }
    
    init(controllerInteraction: GalleryControllerInteraction, pageGap: CGFloat = 20.0) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor.black
        self.scrollView = UIScrollView()
        self.scrollView.delaysContentTouches = false

        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }

        self.pager = GalleryPagerNode(pageGap: pageGap)
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
        
        self.pager.dismiss = { [weak self] in
            if let strongSelf = self {
                var interfaceAnimationCompleted = false
                var contentAnimationCompleted = true
                
                strongSelf.scrollView.isScrollEnabled = false
                let completion = { [weak self] in
                    if interfaceAnimationCompleted && contentAnimationCompleted {
                        if let dismiss = self?.dismiss {
                            self?.scrollView.isScrollEnabled = true
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
                
        self.pager.beginCustomDismiss = { [weak self] in
            if let strongSelf = self {
                strongSelf.beginCustomDismiss()
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
        self.addSubnode(self.footerNode)
        
        var previousIndex: Int?
        self.pager.centralItemIndexOffsetUpdated = { [weak self] itemsIndexAndProgress in
            if let strongSelf = self {
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
                                    strongSelf.pager.transaction(GalleryPagerTransaction(deleteItems: [], insertItems: [], updateItems: [], focusOnItem: pagerIndex))
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
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *), !self.isLayerBacked {
            self.view.accessibilityIgnoresInvertColors = true
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (navigationBarHeight, layout)
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - (self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight))))
        
        transition.updateFrame(node: self.footerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let displayThumbnailPanel = layout.size.width < layout.size.height
        var thumbnailPanelHeight: CGFloat = 0.0
        if let currentThumbnailContainerNode = self.currentThumbnailContainerNode {
            let panelHeight: CGFloat = 52.0
            if displayThumbnailPanel {
                thumbnailPanelHeight = 52.0
            }
            let thumbnailsFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - 40.0 - panelHeight + 4.0 - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width, height: panelHeight - 4.0))
            transition.updateFrame(node: currentThumbnailContainerNode, frame: thumbnailsFrame)
            currentThumbnailContainerNode.updateLayout(size: thumbnailsFrame.size, transition: transition)
            
            self.updateThumbnailContainerNodeAlpha(transition)
        }
        
        self.footerNode.updateLayout(layout, footerContentNode: self.presentationState.footerContentNode, thumbnailPanelHeight: thumbnailPanelHeight, transition: transition)
        
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
    
    func setControlsHidden(_ hidden: Bool, animated: Bool) {
        self.areControlsHidden = hidden
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                let alpha: CGFloat = self.areControlsHidden ? 0.0 : 1.0
                self.navigationBar?.alpha = alpha
                self.statusBar?.alpha = alpha
                self.footerNode.alpha = alpha
                self.updateThumbnailContainerNodeAlpha(.immediate)
            })
        } else {
            let alpha: CGFloat = self.areControlsHidden ? 0.0 : 1.0
            self.navigationBar?.alpha = alpha
            self.statusBar?.alpha = alpha
            self.footerNode.alpha = alpha
            self.updateThumbnailContainerNodeAlpha(.immediate)
        }
    }

    func updateThumbnailContainerNodeAlpha(_ transition: ContainedViewLayoutTransition) {
        if let currentThumbnailContainerNode = self.currentThumbnailContainerNode, let layout = self.containerLayout?.1 {
            let visible = layout.size.width < layout.size.height && !self.areControlsHidden
            transition.updateAlpha(node: currentThumbnailContainerNode, alpha: visible ? 1.0 : 0.0)
        }
    }
    
    func animateIn(animateContent: Bool) {
        self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(0.0)
        self.statusBar?.alpha = 0.0
        self.navigationBar?.alpha = 0.0
        self.footerNode.alpha = 0.0
        self.currentThumbnailContainerNode?.alpha = 0.0
        
        UIView.animate(withDuration: 0.2, animations: {
            self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(1.0)
            if !self.areControlsHidden {
                self.statusBar?.alpha = 1.0
                self.navigationBar?.alpha = 1.0
                self.footerNode.alpha = 1.0
                self.updateThumbnailContainerNodeAlpha(.immediate)
            }
        })
        
        if animateContent {
            self.scrollView.layer.animateBounds(from: self.scrollView.layer.bounds.offsetBy(dx: 0.0, dy: -self.scrollView.layer.bounds.size.height), to: self.scrollView.layer.bounds, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func animateOut(animateContent: Bool, completion: @escaping () -> Void) {
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
            self.backgroundNode.layer.animate(from: backgroundColor.cgColor, to: updatedColor.cgColor, keyPath: "backgroundColor", timingFunction: kCAMediaTimingFunctionLinear, duration: 0.15)
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
            self.scrollView.layer.animateBounds(from: self.scrollView.layer.bounds, to: self.scrollView.layer.bounds.offsetBy(dx: 0.0, dy: -self.scrollView.layer.bounds.size.height), duration: 0.25, timingFunction: kCAMediaTimingFunctionLinear, removeOnCompletion: false, completion: { _ in
                contentAnimationCompleted = true
                intermediateCompletion()
            })
        }
    }
    
    func updateDismissTransition(_ value: CGFloat) {    
    }
    
    func updateDistanceFromEquilibrium(_ value: CGFloat) {
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.isDismissed {
            return
        }
        let distanceFromEquilibrium = scrollView.contentOffset.y - scrollView.contentSize.height / 3.0
        
        let transition = 1.0 - min(1.0, max(0.0, abs(distanceFromEquilibrium) / 50.0))
        let backgroundTransition = 1.0 - min(1.0, max(0.0, abs(distanceFromEquilibrium) / 80.0))
        self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(backgroundTransition)
        
        self.updateThumbnailContainerNodeAlpha(.immediate)
        
        if !self.areControlsHidden {
            self.statusBar?.alpha = transition
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
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        targetContentOffset.pointee = scrollView.contentOffset
        
        let distanceFromEquilibrium = scrollView.contentOffset.y - scrollView.contentSize.height / 3.0
        let minimalDismissDistance = scrollView.contentSize.height / 12.0
        if abs(velocity.y) > 1.0 || abs(distanceFromEquilibrium) > minimalDismissDistance {
            if let backgroundColor = self.backgroundNode.backgroundColor {
                self.backgroundNode.layer.animate(from: backgroundColor, to: UIColor(white: 0.0, alpha: 0.0).cgColor, keyPath: "backgroundColor", timingFunction: kCAMediaTimingFunctionLinear, duration: 0.2, removeOnCompletion: false)
            }
            
            var interfaceAnimationCompleted = false
            var contentAnimationCompleted = true
            
            self.scrollView.isScrollEnabled = false
            let completion = { [weak self] in
                if interfaceAnimationCompleted && contentAnimationCompleted {
                    if let dismiss = self?.dismiss {
                        self?.scrollView.isScrollEnabled = true
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
                self.scrollView.layer.animateBounds(from: self.scrollView.layer.bounds, to: self.scrollView.layer.bounds.offsetBy(dx: 0.0, dy: self.scrollView.layer.bounds.size.height * (velocity.y < 0.0 ? -1.0 : 1.0)), duration: 0.2, timingFunction: kCAMediaTimingFunctionLinear, removeOnCompletion: false, completion: { _ in
                    contentAnimationCompleted = true
                    completion()
                })
            }
        } else {
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: self.scrollView.contentSize.height / 3.0), animated: true)
        }
    }
    
    func updatePresentationState(_ f: (GalleryControllerPresentationState) -> GalleryControllerPresentationState, transition: ContainedViewLayoutTransition) {
        self.presentationState = f(self.presentationState)
        if let (navigationBarHeight, layout) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    @objc func panGesture(_ recognizer: SwipeToDismissGestureRecognizer) {
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
