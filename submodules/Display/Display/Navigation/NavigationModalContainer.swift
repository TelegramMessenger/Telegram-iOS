import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

final class NavigationModalContainer: ASDisplayNode, UIScrollViewDelegate {
    private var theme: NavigationControllerTheme
    
    private let dim: ASDisplayNode
    private let scrollNode: ASScrollNode
    let container: NavigationContainer
    
    private(set) var isReady: Bool = false
    private(set) var dismissProgress: CGFloat = 0.0
    var isReadyUpdated: (() -> Void)?
    var updateDismissProgress: ((CGFloat) -> Void)?
    var interactivelyDismissed: (() -> Void)?
    
    private var ignoreScrolling = false
    private var animator: DisplayLinkAnimator?
    
    init(theme: NavigationControllerTheme, controllerRemoved: @escaping (ViewController) -> Void) {
        self.theme = theme
        
        self.dim = ASDisplayNode()
        self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        self.dim.alpha = 0.0
        
        self.scrollNode = ASScrollNode()
        
        self.container = NavigationContainer(controllerRemoved: controllerRemoved)
        self.container.clipsToBounds = true
        
        super.init()
        
        self.addSubnode(self.dim)
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.container)
        
        self.isReady = self.container.isReady
        self.container.isReadyUpdated = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isReady {
                strongSelf.isReady = true
                strongSelf.isReadyUpdated?()
            }
        }
    }
    
    deinit {
        self.animator?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.alwaysBounceHorizontal = false
        self.scrollNode.view.bounces = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.delegate = self
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrolling {
            return
        }
        var progress = (self.bounds.height - scrollView.bounds.origin.y) / self.bounds.height
        progress = max(0.0, min(1.0, progress))
        self.dismissProgress = progress
        self.dim.alpha = 1.0 - progress
        self.updateDismissProgress?(progress)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        var progress = (self.bounds.height - scrollView.bounds.origin.y) / self.bounds.height
        progress = max(0.0, min(1.0, progress))
        
        self.ignoreScrolling = true
        targetContentOffset.pointee = scrollView.contentOffset
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        self.ignoreScrolling = false
        self.animator?.invalidate()
        let targetOffset: CGFloat
        if velocity.y < -0.5 || progress >= 0.5 {
            targetOffset = 0.0
        } else {
            targetOffset = self.bounds.height
        }
        let velocityFactor: CGFloat = 0.4 / max(1.0, abs(velocity.y))
        self.animator = DisplayLinkAnimator(duration: Double(min(0.3, velocityFactor)), from: scrollView.contentOffset.y, to: targetOffset, update: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: value)
        }, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.animator = nil
            if targetOffset == 0.0 {
                strongSelf.interactivelyDismissed?()
            }
        })
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    }
    
    func update(layout: ContainerViewLayout, controllers: [ViewController], transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: layout.size.height * 2.0)
        if !self.scrollNode.view.isDecelerating && !self.scrollNode.view.isDragging && self.animator == nil {
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: layout.size))
        }
        
        let containerLayout: ContainerViewLayout
        let containerFrame: CGRect
        switch layout.metrics.widthClass {
        case .compact:
            self.dim.isHidden = true
            self.container.clipsToBounds = true
            self.container.cornerRadius = 10.0
            if #available(iOS 11.0, *) {
                self.container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            }
            
            var topInset: CGFloat = 10.0
            if let statusBarHeight = layout.statusBarHeight {
                topInset += statusBarHeight
            }
            
            containerLayout = ContainerViewLayout(size: CGSize(width: layout.size.width, height: layout.size.height - topInset), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: 0.0, left: layout.intrinsicInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.intrinsicInsets.right), safeInsets: UIEdgeInsets(top: 0.0, left: layout.safeInsets.left, bottom: layout.safeInsets.bottom, right: layout.safeInsets.right), statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
            containerFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: containerLayout.size)
        case .regular:
            self.dim.isHidden = false
            self.container.clipsToBounds = true
            self.container.cornerRadius = 10.0
            if #available(iOS 11.0, *) {
                self.container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            }
            
            let verticalInset: CGFloat = 44.0
            
            let maxSide = max(layout.size.width, layout.size.height)
            let containerSize = CGSize(width: max(layout.size.width - 20.0, floor(maxSide / 2.0)), height: layout.size.height - verticalInset * 2.0)
            containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            
            var inputHeight: CGFloat?
            if let inputHeightValue = layout.inputHeight {
                inputHeight = max(0.0, inputHeightValue - (layout.size.height - containerFrame.maxY))
            }
            containerLayout = ContainerViewLayout(size: containerSize, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
        }
        transition.updateFrame(node: self.container, frame: containerFrame.offsetBy(dx: 0.0, dy: layout.size.height))
        self.container.update(layout: containerLayout, canBeClosed: true, controllers: controllers, transition: transition)
    }
    
    func animateIn(transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.dim, alpha: 1.0)
        transition.animatePositionAdditive(node: self.container, offset: CGPoint(x: 0.0, y: self.bounds.height + self.container.bounds.height / 2.0 - (self.container.position.y - self.bounds.height)))
    }
    
    func dismiss(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) -> ContainedViewLayoutTransition {
        for controller in self.container.controllers {
            controller.viewWillDisappear(transition.isAnimated)
        }
        
        if transition.isAnimated {
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0, beginWithCurrentState: true)
            positionTransition.updatePosition(node: self.container, position: CGPoint(x: self.container.position.x, y: self.bounds.height + self.container.bounds.height / 2.0 + self.bounds.height), beginWithCurrentState: true, completion: { [weak self] _ in
                completion()
            })
            return positionTransition
        } else {
            for controller in self.container.controllers {
                controller.setIgnoreAppearanceMethodInvocations(true)
                controller.displayNode.removeFromSupernode()
                controller.setIgnoreAppearanceMethodInvocations(false)
                controller.viewDidDisappear(transition.isAnimated)
            }
            completion()
            return transition
        }
    }
}
