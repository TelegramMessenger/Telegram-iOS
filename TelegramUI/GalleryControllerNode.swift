import Foundation
import AsyncDisplayKit
import Display

class GalleryControllerNode: ASDisplayNode, UIScrollViewDelegate {
    var statusBar: StatusBar?
    var navigationBar: NavigationBar?
    var transitionNodeForCentralItem: (() -> ASDisplayNode?)?
    var dismiss: (() -> Void)?
    
    var containerLayout: (CGFloat, ContainerViewLayout)?
    var backgroundNode: ASDisplayNode
    var scrollView: UIScrollView
    var pager: GalleryPagerNode
    
    var areControlsHidden = false
    var isBackgroundExtendedOverNavigationBar = true {
        didSet {
            if let (navigationBarHeight, layout) = self.containerLayout {
                self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - (self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight)))
            }
        }
    }
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor.black
        self.scrollView = UIScrollView()
        self.pager = GalleryPagerNode()
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.pager.toggleControlsVisibility = { [weak self] in
            if let strongSelf = self {
                strongSelf.areControlsHidden = !strongSelf.areControlsHidden
                UIView.animate(withDuration: 0.3, animations: {
                    let alpha: CGFloat = strongSelf.areControlsHidden ? 0.0 : 1.0
                    strongSelf.navigationBar?.alpha = alpha
                    strongSelf.statusBar?.alpha = alpha
                })
            }
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
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (navigationBarHeight, layout)
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - (self.isBackgroundExtendedOverNavigationBar ? 0.0 : navigationBarHeight))))
        
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
    
    func animateIn(animateContent: Bool) {
        self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(0.0)
        self.statusBar?.alpha = 0.0
        self.navigationBar?.alpha = 0.0
        UIView.animate(withDuration: 0.2, animations: {
            self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(1.0)
            self.statusBar?.alpha = 1.0
            self.navigationBar?.alpha = 1.0
        })
        
        if animateContent {
            self.scrollView.layer.animateBounds(from: self.scrollView.layer.bounds.offsetBy(dx: 0.0, dy: -self.scrollView.layer.bounds.size.height), to: self.scrollView.layer.bounds, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func animateOut(animateContent: Bool, completion: @escaping () -> Void) {
        var contentAnimationCompleted = true
        var interfaceAnimationCompleted = false
        
        let intermediateCompletion = {
            if contentAnimationCompleted && interfaceAnimationCompleted {
                completion()
            }
        }
        
        UIView.animate(withDuration: 0.25, animations: {
            self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(0.0)
            self.statusBar?.alpha = 0.0
            self.navigationBar?.alpha = 0.0
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let distanceFromEquilibrium = scrollView.contentOffset.y - scrollView.contentSize.height / 3.0
        
        let transition = 1.0 - min(1.0, max(0.0, abs(distanceFromEquilibrium) / 50.0))
        let backgroundTransition = 1.0 - min(1.0, max(0.0, abs(distanceFromEquilibrium) / 80.0))
        self.backgroundNode.backgroundColor = self.backgroundNode.backgroundColor?.withAlphaComponent(backgroundTransition)
        
        if !self.areControlsHidden {
            self.statusBar?.alpha = transition
            self.navigationBar?.alpha = transition
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        targetContentOffset.pointee = scrollView.contentOffset
        
        if abs(velocity.y) > 1.0 {
            self.backgroundNode.layer.animate(from: self.backgroundNode.backgroundColor!, to: UIColor(white: 0.0, alpha: 0.0).cgColor, keyPath: "backgroundColor", timingFunction: kCAMediaTimingFunctionLinear, duration: 0.2, removeOnCompletion: false)
            
            var interfaceAnimationCompleted = false
            var contentAnimationCompleted = true
            
            let completion = { [weak self] in
                if interfaceAnimationCompleted && contentAnimationCompleted {
                    if let dismiss = self?.dismiss {
                        dismiss()
                    }
                }
            }
            
            if let centralItemNode = self.pager.centralItemNode(), let transitionNodeForCentralItem = self.transitionNodeForCentralItem, let node = transitionNodeForCentralItem() {
                contentAnimationCompleted = false
                centralItemNode.animateOut(to: node, completion: {
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
}
