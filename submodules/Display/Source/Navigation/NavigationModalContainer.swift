import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import UIKitRuntimeUtils

final class NavigationModalContainer: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private var theme: NavigationControllerTheme
    let isFlat: Bool
    
    private let dim: ASDisplayNode
    private let scrollNode: ASScrollNode
    let container: NavigationContainer
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    private(set) var isReady: Bool = false
    private(set) var dismissProgress: CGFloat = 0.0
    var isReadyUpdated: (() -> Void)?
    var updateDismissProgress: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    var interactivelyDismissed: ((Bool) -> Void)?
    
    private var isUpdatingState = false
    private var ignoreScrolling = false
    private var isDismissed = false
    private var isInteractiveDimissEnabled = true
    
    private var validLayout: ContainerViewLayout?
    private var horizontalDismissOffset: CGFloat?
    
    var keyboardViewManager: KeyboardViewManager? {
        didSet {
            if self.keyboardViewManager !== oldValue {
                self.container.keyboardViewManager = self.keyboardViewManager
            }
        }
    }
    
    var canHaveKeyboardFocus: Bool = false {
        didSet {
            self.container.canHaveKeyboardFocus = self.canHaveKeyboardFocus
        }
    }
    
    init(theme: NavigationControllerTheme, isFlat: Bool, controllerRemoved: @escaping (ViewController) -> Void) {
        self.theme = theme
        self.isFlat = isFlat
        
        self.dim = ASDisplayNode()
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
                if !strongSelf.isUpdatingState {
                    strongSelf.isReadyUpdated?()
                }
            }
        }
        
        applySmoothRoundedCorners(self.container.layer)
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
        self.scrollNode.view.clipsToBounds = false
        self.scrollNode.view.delegate = self
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let strongSelf = self, !strongSelf.isDismissed else {
                return []
            }
            return .right
        })
        self.panRecognizer = panRecognizer
        if let layout = self.validLayout {
            switch layout.metrics.widthClass {
            case .compact:
                panRecognizer.isEnabled = true
            case .regular:
                panRecognizer.isEnabled = false
            }
        }
        panRecognizer.delegate = self
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        if !self.isFlat {
            self.view.addGestureRecognizer(panRecognizer)
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return true
        }
        return false
    }
    
    private func checkInteractiveDismissWithControllers() -> Bool {
        if let controller = self.container.controllers.last {
            if !controller.attemptNavigation({
            }) {
                return false
            }
        }
        return true
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.horizontalDismissOffset = 0.0
        case .changed:
            let translation = max(0.0, recognizer.translation(in: self.view).x)
            let progress = translation / self.bounds.width
            self.horizontalDismissOffset = translation
            self.dismissProgress = progress
            self.applyDismissProgress(transition: .immediate, completion: {})
            self.container.updateAdditionalKeyboardLeftEdgeOffset(translation, transition: .immediate)
        case .ended, .cancelled:
            let translation = max(0.0, recognizer.translation(in: self.view).x)
            let progress = translation / self.bounds.width
            let velocity = recognizer.velocity(in: self.view).x
            
            if (velocity > 1000 || progress > 0.2) && self.checkInteractiveDismissWithControllers() {
                self.isDismissed = true
                self.horizontalDismissOffset = self.bounds.width
                self.dismissProgress = 1.0
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(x: self.bounds.width, y: 0.0), size: self.scrollNode.bounds.size))
                self.container.updateAdditionalKeyboardLeftEdgeOffset(self.bounds.width, transition: transition)
                self.applyDismissProgress(transition: transition, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    let hadInputFocus = viewTreeContainsFirstResponder(view: strongSelf.view)
                    strongSelf.keyboardViewManager?.dismissEditingWithoutAnimation(view: strongSelf.view)
                    strongSelf.interactivelyDismissed?(hadInputFocus)
                })
            } else {
                self.horizontalDismissOffset = nil
                self.dismissProgress = 0.0
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.1, curve: .easeInOut)
                self.applyDismissProgress(transition: transition, completion: {})
                self.container.updateAdditionalKeyboardLeftEdgeOffset(0.0, transition: transition)
            }
        default:
            break
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if !self.isDismissed {
                self.dismissWithAnimation()
            }
        }
    }
    
    private func dismissWithAnimation() {
        let scrollView = self.scrollNode.view
        let targetOffset: CGFloat
        let duration = 0.3
        let transition: ContainedViewLayoutTransition
        let dismissProgress: CGFloat
        dismissProgress = 1.0
        targetOffset = 0.0
        transition = .animated(duration: duration, curve: .easeInOut)
        self.isDismissed = true
        self.ignoreScrolling = true
        let deltaY = targetOffset - scrollView.contentOffset.y
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        scrollView.setContentOffset(CGPoint(x: 0.0, y: targetOffset), animated: false)
        transition.animateOffsetAdditive(layer: self.scrollNode.layer, offset: -deltaY, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if targetOffset == 0.0 {
                strongSelf.interactivelyDismissed?(false)
            }
        })
        self.ignoreScrolling = false
        self.dismissProgress = dismissProgress
        
        self.applyDismissProgress(transition: transition, completion: {})
        
        self.view.endEditing(true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrolling || self.isDismissed {
            return
        }
        var progress = (self.bounds.height - scrollView.bounds.origin.y) / self.bounds.height
        progress = max(0.0, min(1.0, progress))
        self.dismissProgress = progress
        self.applyDismissProgress(transition: .immediate, completion: {})
    }
    
    private func applyDismissProgress(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        transition.updateAlpha(node: self.dim, alpha: 1.0 - self.dismissProgress, completion: { _ in
            completion()
        })
        self.updateDismissProgress?(self.dismissProgress, transition)
    }
    
    private var endDraggingVelocity: CGPoint?
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let velocity = self.endDraggingVelocity ?? CGPoint()
        self.endDraggingVelocity = nil
        
        var progress = (self.bounds.height - scrollView.bounds.origin.y) / self.bounds.height
        progress = max(0.0, min(1.0, progress))
        
        let targetOffset: CGFloat
        let velocityFactor: CGFloat = 0.4 / max(1.0, abs(velocity.y))
        let duration = Double(min(0.3, velocityFactor))
        let transition: ContainedViewLayoutTransition
        let dismissProgress: CGFloat
        if (velocity.y < -0.5 || progress >= 0.5) && self.checkInteractiveDismissWithControllers() {
            dismissProgress = 1.0
            targetOffset = 0.0
            transition = .animated(duration: duration, curve: .easeInOut)
            self.isDismissed = true
        } else {
            dismissProgress = 0.0
            targetOffset = self.bounds.height
            transition = .animated(duration: 0.5, curve: .spring)
        }
        self.ignoreScrolling = true
        let deltaY = targetOffset - scrollView.contentOffset.y
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        scrollView.setContentOffset(CGPoint(x: 0.0, y: targetOffset), animated: false)
        transition.animateOffsetAdditive(layer: self.scrollNode.layer, offset: -deltaY, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if targetOffset == 0.0 {
                strongSelf.interactivelyDismissed?(false)
            }
        })
        self.ignoreScrolling = false
        self.dismissProgress = dismissProgress
        
        self.applyDismissProgress(transition: transition, completion: {})
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.endDraggingVelocity = velocity
        targetContentOffset.pointee = scrollView.contentOffset
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        return false
    }
    
    func update(layout: ContainerViewLayout, controllers: [ViewController], coveredByModalTransition: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.isDismissed {
            return
        }
        
        self.isUpdatingState = true
        
        self.validLayout = layout
        
        var isStandaloneModal = false
        if let controller = controllers.first, case .standaloneModal = controller.navigationPresentation {
            isStandaloneModal = true
        }
        
        transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.ignoreScrolling = true
        self.scrollNode.view.isScrollEnabled = (layout.inputHeight == nil || layout.inputHeight == 0.0) && self.isInteractiveDimissEnabled
        let previousBounds = self.scrollNode.bounds
        let scrollNodeFrame = CGRect(origin: CGPoint(x: self.horizontalDismissOffset ?? 0.0, y: 0.0), size: layout.size)
        self.scrollNode.frame = scrollNodeFrame
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: layout.size.height * 2.0)
        if !self.scrollNode.view.isDecelerating && !self.scrollNode.view.isDragging {
            let defaultBounds = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: layout.size)
            if self.scrollNode.bounds != defaultBounds {
                self.scrollNode.bounds = defaultBounds
            }
            if previousBounds.minY != defaultBounds.minY {
                transition.animateOffsetAdditive(node: self.scrollNode, offset: previousBounds.minY - defaultBounds.minY)
            }
        }
        self.ignoreScrolling = false
        
        self.scrollNode.view.isScrollEnabled = !isStandaloneModal
        
        let isLandscape = layout.orientation == .landscape
        let containerLayout: ContainerViewLayout
        let containerFrame: CGRect
        let containerScale: CGFloat
        if layout.metrics.widthClass == .compact || self.isFlat {
            self.panRecognizer?.isEnabled = true
            self.container.clipsToBounds = true
            if self.isFlat {
                self.dim.backgroundColor = .clear
            } else {
                self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            }
            if isStandaloneModal || isLandscape || self.isFlat {
                self.container.cornerRadius = 0.0
            } else {
                self.container.cornerRadius = 10.0
            }
            
            if #available(iOS 11.0, *) {
                if layout.safeInsets.bottom.isZero {
                    self.container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                } else {
                    self.container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                }
            }
            
            var topInset: CGFloat
            if isStandaloneModal || isLandscape {
                topInset = 0.0
                containerLayout = layout
                
                let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: containerLayout.size)
                containerScale = 1.0
                containerFrame = unscaledFrame
            } else {
                topInset = 10.0
                if self.isFlat {
                    topInset = 0.0
                } else if let statusBarHeight = layout.statusBarHeight {
                    topInset += statusBarHeight
                }
                
                let effectiveStatusBarHeight: CGFloat?
                if self.isFlat {
                    effectiveStatusBarHeight = layout.statusBarHeight
                } else {
                    effectiveStatusBarHeight = nil
                }
                
                containerLayout = ContainerViewLayout(size: CGSize(width: layout.size.width, height: layout.size.height - topInset), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: 0.0, left: layout.intrinsicInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.intrinsicInsets.right), safeInsets: UIEdgeInsets(top: 0.0, left: layout.safeInsets.left, bottom: layout.safeInsets.bottom, right: layout.safeInsets.right), additionalInsets: layout.additionalInsets, statusBarHeight: effectiveStatusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
                let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset - coveredByModalTransition * 10.0), size: containerLayout.size)
                let maxScale: CGFloat = (containerLayout.size.width - 16.0 * 2.0) / containerLayout.size.width
                containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                let maxScaledTopInset: CGFloat = topInset - 10.0
                let scaledTopInset: CGFloat = topInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
            }
        } else {
            self.panRecognizer?.isEnabled = false
            if self.isFlat {
                self.dim.backgroundColor = .clear
                self.container.clipsToBounds = true
                self.container.cornerRadius = 0.0
                if #available(iOS 11.0, *) {
                    self.container.layer.maskedCorners = []
                }
            } else {
                self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
                self.container.clipsToBounds = true
                self.container.cornerRadius = 10.0
                if #available(iOS 11.0, *) {
                    self.container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                }
            }
            
            let verticalInset: CGFloat = 44.0
            
            let maxSide = max(layout.size.width, layout.size.height)
            let minSide = min(layout.size.width, layout.size.height)
            let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
            containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            containerScale = 1.0
            
            var inputHeight: CGFloat?
            if let inputHeightValue = layout.inputHeight {
                inputHeight = max(0.0, inputHeightValue - (layout.size.height - containerFrame.maxY))
            }
            
            let effectiveStatusBarHeight: CGFloat?
            if self.isFlat {
                effectiveStatusBarHeight = layout.statusBarHeight
            } else {
                effectiveStatusBarHeight = nil
            }
            
            containerLayout = ContainerViewLayout(size: containerSize, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: effectiveStatusBarHeight, inputHeight: inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
        }
        transition.updateFrameAsPositionAndBounds(node: self.container, frame: containerFrame.offsetBy(dx: 0.0, dy: layout.size.height))
        transition.updateTransformScale(node: self.container, scale: containerScale)
        self.container.update(layout: containerLayout, canBeClosed: true, controllers: controllers, transition: transition)
        
        self.isUpdatingState = false
    }
    
    func animateIn(transition: ContainedViewLayoutTransition) {
        if let controller = self.container.controllers.first, case .standaloneModal = controller.navigationPresentation {
        } else if self.isFlat {
        } else {
            transition.updateAlpha(node: self.dim, alpha: 1.0)
            transition.animatePositionAdditive(node: self.container, offset: CGPoint(x: 0.0, y: self.bounds.height + self.container.bounds.height / 2.0 - (self.container.position.y - self.bounds.height)))
        }
    }
    
    func dismiss(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) -> ContainedViewLayoutTransition {
        for controller in self.container.controllers {
            controller.viewWillDisappear(transition.isAnimated)
        }
        
        if let firstController = self.container.controllers.first, case .standaloneModal = firstController.navigationPresentation {
            for controller in self.container.controllers {
                controller.setIgnoreAppearanceMethodInvocations(true)
                controller.displayNode.removeFromSupernode()
                controller.setIgnoreAppearanceMethodInvocations(false)
                controller.viewDidDisappear(transition.isAnimated)
            }
            completion()
            return transition
        } else {
            if transition.isAnimated && !self.isFlat {
                let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                alphaTransition.updateAlpha(node: self.dim, alpha: 0.0, beginWithCurrentState: true)
                positionTransition.updatePosition(node: self.container, position: CGPoint(x: self.container.position.x, y: self.bounds.height + self.container.bounds.height / 2.0 + self.bounds.height), beginWithCurrentState: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    for controller in strongSelf.container.controllers {
                        controller.viewDidDisappear(transition.isAnimated)
                    }
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if !self.container.bounds.contains(self.view.convert(point, to: self.container.view)) {
            return self.dim.view
        }
        var currentParent: UIView? = result
        var enableScrolling = true
        while true {
            if currentParent == nil {
                break
            }
            if currentParent is UIKeyInput {
                if currentParent?.disablesInteractiveModalDismiss == true {
                    enableScrolling = false
                    break
                }
            } else if let scrollView = currentParent as? UIScrollView {
                if scrollView === self.scrollNode.view {
                    break
                }
                if scrollView.disablesInteractiveModalDismiss {
                    enableScrolling = false
                    break
                } else {
                    if scrollView.isDecelerating && scrollView.contentOffset.y < -scrollView.contentInset.top {
                        return self.scrollNode.view
                    }
                }
            } else if let listView = currentParent as? ListViewBackingView, let listNode = listView.target {
                if listNode.view.disablesInteractiveModalDismiss {
                    enableScrolling = false
                    break
                } else if listNode.scroller.isDecelerating && listNode.scroller.contentOffset.y < listNode.scroller.contentInset.top {
                    return self.scrollNode.view
                }
            }
            currentParent = currentParent?.superview
        }
        if let controller = self.container.controllers.last {
            if controller.view.disablesInteractiveModalDismiss {
                enableScrolling = false
            }
        }
        self.isInteractiveDimissEnabled = enableScrolling
        if let layout = self.validLayout {
            if layout.inputHeight != nil && layout.inputHeight != 0.0 {
                enableScrolling = false
            }
        }
        self.scrollNode.view.isScrollEnabled = enableScrolling
        return result
    }
}
