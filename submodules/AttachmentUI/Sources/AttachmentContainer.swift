import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import UIKitRuntimeUtils
import Display
import DirectionalPanGesture
import TelegramPresentationData
import MapKit
import WebKit

private let overflowInset: CGFloat = 0.0

public func attachmentDefaultTopInset(layout: ContainerViewLayout?) -> CGFloat {
    guard let layout = layout else {
        return 210.0
    }
    if case .compact = layout.metrics.widthClass {
        var factor: CGFloat = 0.2488
        if layout.size.width <= 320.0 {
            factor = 0.15
        }
        return floor(max(layout.size.width, layout.size.height) * factor)
    } else {
        return 210.0
    }
}

final class AttachmentContainer: ASDisplayNode, ASGestureRecognizerDelegate {
    let wrappingNode: ASDisplayNode
    let clipNode: ASDisplayNode
    let container: NavigationContainer
        
    private(set) var isReady: Bool = false
    private(set) var dismissProgress: CGFloat = 0.0
    var isReadyUpdated: (() -> Void)?
    var updateDismissProgress: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    var interactivelyDismissed: ((CGFloat) -> Bool)?
    var controllerRemoved: ((ViewController) -> Void)?
    
    var shouldCancelPanGesture: (() -> Bool)?
    var requestDismiss: (() -> Void)?
    
    var updateModalProgress: ((CGFloat, CGFloat, CGRect, ContainedViewLayoutTransition) -> Void)?
    
    private var isUpdatingState = false
    private var isDismissed = false
    private var isInteractiveDimissEnabled = true
    
    private let isFullSize: Bool
    public private(set) var isExpanded = false
    
    private var validLayout: (layout: ContainerViewLayout, controllers: [AttachmentContainable], coveredByModalTransition: CGFloat)?
    
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
    
    private var panGestureRecognizer: UIPanGestureRecognizer?
    
    var isPanningUpdated: (Bool) -> Void = { _ in }
    var isExpandedUpdated: (Bool) -> Void = { _ in }
    var isPanGestureEnabled: (() -> Bool)?
    var isInnerPanGestureEnabled: (() -> Bool)?
    var onExpandAnimationCompleted: () -> Void = {}
    
    init(isFullSize: Bool) {
        self.isFullSize = isFullSize
        if isFullSize {
            self.isExpanded = true
        }
        
        self.wrappingNode = ASDisplayNode()
        self.clipNode = ASDisplayNode()
        
        var controllerRemovedImpl: ((ViewController) -> Void)?
        self.container = NavigationContainer(isFlat: false, controllerRemoved: { c in
            controllerRemovedImpl?(c)
        })
        self.container.clipsToBounds = true
        self.container.overflowInset = overflowInset
        self.container.shouldAnimateDisappearance = true
        
        super.init()
        
        self.addSubnode(self.wrappingNode)
        self.wrappingNode.addSubnode(self.clipNode)
        self.clipNode.addSubnode(self.container)
        
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
        
        controllerRemovedImpl = { [weak self] c in
            self?.controllerRemoved?(c)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.panGestureRecognizer = panRecognizer
        self.wrappingNode.view.addGestureRecognizer(panRecognizer)
    }
    
    func cancelPanGesture() {
        if let panGestureRecognizer = self.panGestureRecognizer, panGestureRecognizer.isEnabled {
            self.panGestureArguments = nil
            panGestureRecognizer.isEnabled = false
            panGestureRecognizer.isEnabled = true
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let (layout, _, _) = self.validLayout {
            if case .regular = layout.metrics.widthClass {
                return false
            }
            
            if let isPanGestureEnabled = self.isPanGestureEnabled {
                if !isPanGestureEnabled() {
                    return false
                }
            }
            if let isInnerPanGestureEnabled = self.isInnerPanGestureEnabled, !isInnerPanGestureEnabled() {
                func findWebViewAncestor(view: UIView?) -> WKWebView? {
                    guard let view else {
                        return nil
                    }
                    if let view = view as? WKWebView {
                        return view
                    } else if view != self.view {
                        return findWebViewAncestor(view: view.superview)
                    } else {
                        return nil
                    }
                }
                if let otherView = self.hitTest(gestureRecognizer.location(in: self.view), with: nil), let _ = findWebViewAncestor(view: otherView) {
                    return false
                }
            }
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = gestureRecognizer as? UIPanGestureRecognizer, otherGestureRecognizer is UIPanGestureRecognizer {
            if let _ = otherGestureRecognizer.view?.superview as? MKMapView {
                return false
            }
            if let view = otherGestureRecognizer.view, view.description.contains("WKChildScroll") {
                return false
            }
            if let _ = otherGestureRecognizer.view?.asyncdisplaykit_node as? CollectionIndexNode {
                return false
            }
            return true
        }
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer {
            return true
        }
        return false
    }
    
    var isTracking: Bool {
        return self.panGestureArguments != nil
    }
    
    private var isAnimating = false
    var isPanning: Bool {
        return self.panGestureArguments != nil || self.isAnimating
    }
    
    private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let (layout, controllers, coveredByModalTransition) = self.validLayout, let lastController = controllers.last else {
            return
        }
        
        let isLandscape = layout.orientation == .landscape
        let edgeTopInset = isLandscape ? 0.0 : attachmentDefaultTopInset(layout: layout)
    
        let completion = {
            self.isAnimating = false
            guard self.panGestureArguments == nil else {
                return
            }
            self.isPanningUpdated(false)
        }
        
        switch recognizer.state {
            case .began:
                let point = recognizer.location(in: self.view)
                let currentHitView = self.hitTest(point, with: nil)
                
                var scrollViewAndListNode = self.findScrollView(view: currentHitView)
                if scrollViewAndListNode?.0.frame.height == self.frame.width || scrollViewAndListNode?.0.isDescendant(of: self.view) == false {
                    scrollViewAndListNode = nil
                }
                let scrollView = scrollViewAndListNode?.0
                let listNode = scrollViewAndListNode?.1
            
                let topInset: CGFloat
                if self.isExpanded {
                    topInset = 0.0
                } else {
                    topInset = edgeTopInset
                }
                
                self.panGestureArguments = (topInset, 0.0, scrollView, listNode)
            case .changed:
                guard let (topInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                    return
                }
                let visibleContentOffset = listNode?.visibleContentOffset()
                let contentOffset = scrollView?.contentOffset.y ?? 0.0
            
                var translation = recognizer.translation(in: self.view).y

                var currentOffset = topInset + translation
            
                let epsilon = 1.0
                if case let .known(value) = visibleContentOffset, value <= epsilon {
                    if let scrollView = scrollView {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0.0), animated: false)
                    }
                } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                    scrollView.bounces = false
                    scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -scrollView.contentInset.top), animated: false)
                } else if let scrollView = scrollView {
                    translation = panOffset
                    currentOffset = topInset + translation
                    if self.isExpanded {
                        recognizer.setTranslation(CGPoint(), in: self.view)
                    } else if currentOffset > 0.0 {
                        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -scrollView.contentInset.top), animated: false)
                    }
                }
                
                self.panGestureArguments = (topInset, translation, scrollView, listNode)
                
                if !self.isExpanded {
                    if currentOffset > 0.0, let scrollView = scrollView {
                        scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                    }
                }
            
                if !self.isExpanded || self.isFullSize, translation > 40.0, let shouldCancelPanGesture = self.shouldCancelPanGesture, shouldCancelPanGesture() {
                    if lastController.isMinimizable {
                        
                    } else {
                        self.cancelPanGesture()
                        self.requestDismiss?()
                        return
                    }
                }
            
                var bounds = self.bounds
                if self.isExpanded && !self.isFullSize {
                    bounds.origin.y = -max(0.0, translation - edgeTopInset)
                } else {
                    bounds.origin.y = -translation
                }
                bounds.origin.y = min(0.0, bounds.origin.y)
                self.bounds = bounds
            
                self.update(layout: layout, controllers: controllers, coveredByModalTransition: coveredByModalTransition, transition: .immediate)
            case .ended:
                guard let (currentTopInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                    return
                }
                self.panGestureArguments = nil
            
                let visibleContentOffset = listNode?.visibleContentOffset()
                let contentOffset = scrollView?.contentOffset.y ?? 0.0
            
                let translation = recognizer.translation(in: self.view).y
                var velocity = recognizer.velocity(in: self.view)
                
                if self.isExpanded {
                    if case let .known(value) = visibleContentOffset, value > 0.1 {
                        velocity = CGPoint()
                    } else if case .unknown = visibleContentOffset {
                        velocity = CGPoint()
                    } else if contentOffset > 0.1 {
                        velocity = CGPoint()
                    }
                }
            
                var bounds = self.bounds
                if self.isExpanded && !self.isFullSize {
                    bounds.origin.y = -max(0.0, translation - edgeTopInset)
                } else {
                    bounds.origin.y = -translation
                }
                bounds.origin.y = min(0.0, bounds.origin.y)
            
                scrollView?.bounces = true
            
                let offset = currentTopInset + panOffset
                let topInset: CGFloat = edgeTopInset
            
                var ignoreDismiss = false
                if let shouldCancelPanGesture = self.shouldCancelPanGesture, shouldCancelPanGesture() {
                    if lastController.isMinimizable {
                        
                    } else {
                        ignoreDismiss = true
                    }
                }
            
                var minimizing = false
                var dismissing = false
            
                let thresholdOffset: CGFloat
                if self.isFullSize {
                    thresholdOffset = -180.0
                } else {
                    thresholdOffset = -60.0
                }
            
                if (bounds.minY < thresholdOffset || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0)) && !ignoreDismiss {
                    if self.interactivelyDismissed?(velocity.y) == true {
                        dismissing = true
                    } else {
                        minimizing = true
                    }
                } else if self.isExpanded {
                    if (velocity.y > 300.0 || offset > topInset / 2.0) && !self.isFullSize {
                        self.isExpanded = false
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -scrollView.contentInset.top), animated: false)
                        }
                    
                        let distance = topInset - offset
                        let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        
                        self.isAnimating = true
                        self.update(layout: layout, controllers: controllers, coveredByModalTransition: coveredByModalTransition, transition: transition, completion: completion)
                    } else {
                        self.isExpanded = true
                        
                        self.isAnimating = true
                        self.update(layout: layout, controllers: controllers, coveredByModalTransition: coveredByModalTransition, transition: .animated(duration: 0.3, curve: .easeInOut), completion: completion)
                    }
                } else if (velocity.y < -300.0 || offset < topInset / 2.0) {
                    if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                        DispatchQueue.main.async {
                            listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                        }
                    }
                                                
                    self.isExpanded = true
                   
                    let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                    self.isAnimating = true
                    self.update(layout: layout, controllers: controllers, coveredByModalTransition: coveredByModalTransition, transition: .animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity)), completion: completion)
                } else {
                    if let listNode = listNode {
                        listNode.scroller.setContentOffset(CGPoint(), animated: false)
                    } else if let scrollView = scrollView {
                        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -scrollView.contentInset.top), animated: false)
                        Queue.mainQueue().after(0.01, {
                            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -scrollView.contentInset.top), animated: false)
                        })
                    }
                    
                    self.isAnimating = true
                    self.update(layout: layout, controllers: controllers, coveredByModalTransition: coveredByModalTransition, transition: .animated(duration: 0.3, curve: .easeInOut), completion: completion)
                }
                
                if !dismissing {
                    var bounds = self.bounds
                    let previousBounds = bounds
                    bounds.origin.y = 0.0
                    self.bounds = bounds
                    if !minimizing {
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                }
            case .cancelled:
                self.panGestureArguments = nil
                
                self.isAnimating = true
                self.update(layout: layout, controllers: controllers, coveredByModalTransition: coveredByModalTransition, transition: .animated(duration: 0.3, curve: .easeInOut), completion: completion)
              
                var bounds = self.bounds
                let previousBounds = bounds
                bounds.origin.y = 0.0
                self.bounds = bounds
                self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
            default:
                break
        }
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
    
    func update(isExpanded: Bool, force: Bool = false, transition: ContainedViewLayoutTransition) {
        guard isExpanded != self.isExpanded || force else {
            return
        }
        self.isExpanded = isExpanded
        
        guard let (layout, controllers, coveredByModalTransition) = self.validLayout else {
            return
        }
        self.update(layout: layout, controllers: controllers, coveredByModalTransition: coveredByModalTransition, transition: transition)
    }
                
    func update(layout: ContainerViewLayout, controllers: [AttachmentContainable], coveredByModalTransition: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) {
        if self.isDismissed {
            return
        }
        self.isUpdatingState = true
        
        let isFirstTime = self.validLayout == nil
        self.validLayout = (layout, controllers, coveredByModalTransition)
                
        self.panGestureRecognizer?.isEnabled = (layout.inputHeight == nil || layout.inputHeight == 0.0)

        let defaultTopInset = attachmentDefaultTopInset(layout: layout)
        let isLandscape = layout.orientation == .landscape
        let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
        var effectiveExpanded = self.isExpanded
        if case .regular = layout.metrics.widthClass {
            effectiveExpanded = true
        }
        
        let topInset: CGFloat
        if !self.isFullSize, let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
            if effectiveExpanded {
                topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
            } else {
                topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
            }
        } else {
            topInset = effectiveExpanded ? 0.0 : edgeTopInset
        }
        transition.updateFrame(node: self.wrappingNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: { _ in
            completion()
        })
        
        let modalProgress: CGFloat
        if isLandscape {
            modalProgress = 0.0
        } else {
            if self.isFullSize, self.panGestureArguments != nil {
                modalProgress = 1.0 - min(1.0, max(0.0, -1.0 * self.bounds.minY / defaultTopInset))
            } else {
                modalProgress = 1.0 - topInset / defaultTopInset
            }
        }
        
        if isFirstTime {
            Queue.mainQueue().justDispatch {
                var transition = transition
                if modalProgress == 1.0 {
                    transition = .animated(duration: 0.4, curve: .spring)
                }
                self.updateModalProgress?(modalProgress, topInset, self.bounds, transition)
            }
        } else {
            self.updateModalProgress?(modalProgress, topInset, self.bounds, transition)
        }
        
        let containerLayout: ContainerViewLayout
        let containerFrame: CGRect
        let clipFrame: CGRect
        let containerScale: CGFloat
        
        let isFullscreen = controllers.last?.isFullscreen == true
        if case .compact = layout.metrics.widthClass {
            self.clipNode.clipsToBounds = true
            
            if isLandscape {
                self.clipNode.cornerRadius = 0.0
            } else {
                self.clipNode.cornerRadius = 10.0
            }
            
            if #available(iOS 11.0, *) {
                if layout.safeInsets.bottom.isZero {
                    self.wrappingNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                } else {
                    self.wrappingNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                }
            }
            
            var containerTopInset: CGFloat
            if isLandscape || isFullscreen {
                containerTopInset = 0.0
                
                var safeInsets = layout.safeInsets
                safeInsets.top = isFullscreen ? 0.000001 : 0.0
                containerLayout = layout.withUpdatedSafeInsets(safeInsets)
                
                let unscaledFrame = CGRect(origin: CGPoint(), size: containerLayout.size)
                containerScale = 1.0
                containerFrame = unscaledFrame
                clipFrame = unscaledFrame
            } else {
                containerTopInset = 10.0
                if let statusBarHeight = layout.statusBarHeight {
                    containerTopInset += statusBarHeight
                }
                                
                var safeInsets = layout.safeInsets
                safeInsets.left += overflowInset
                safeInsets.right += overflowInset
                
                var intrinsicInsets = layout.intrinsicInsets
                intrinsicInsets.left += overflowInset
                intrinsicInsets.right += overflowInset
                
                var additionalInsets = layout.additionalInsets
                additionalInsets.bottom = topInset
                                
                containerLayout = ContainerViewLayout(size: CGSize(width: layout.size.width + overflowInset * 2.0, height: layout.size.height - containerTopInset), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: 0.0, left: intrinsicInsets.left, bottom: intrinsicInsets.bottom, right: intrinsicInsets.right), safeInsets: UIEdgeInsets(top: 0.0, left: safeInsets.left, bottom: safeInsets.bottom, right: safeInsets.right), additionalInsets: additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
                let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: containerLayout.size)
                let maxScale: CGFloat = (containerLayout.size.width - 16.0 * 2.0) / containerLayout.size.width
                containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                containerFrame = unscaledFrame.offsetBy(dx: -overflowInset, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                
                clipFrame = CGRect(x: containerFrame.minX + overflowInset, y: containerFrame.minY, width: containerFrame.width - overflowInset * 2.0, height: containerFrame.height)
            }
        } else {
            containerLayout = ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: isFullscreen ? layout.statusBarHeight : nil, inputHeight: isFullscreen ? layout.inputHeight : nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: layout.inVoiceOver)
            
            let unscaledFrame = CGRect(origin: CGPoint(), size: containerLayout.size)
            containerScale = 1.0
            containerFrame = unscaledFrame
            clipFrame = unscaledFrame
        }
        transition.updateFrameAsPositionAndBounds(node: self.clipNode, frame: clipFrame)
        transition.updateFrameAsPositionAndBounds(node: self.container, frame: CGRect(origin: CGPoint(x: containerFrame.minX, y: 0.0), size: containerFrame.size))
        transition.updateTransformScale(node: self.container, scale: containerScale)
        self.container.update(layout: containerLayout, canBeClosed: true, controllers: controllers, transition: transition)
        
        self.isUpdatingState = false
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
            if transition.isAnimated {
                let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
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
                if let (layout, _, coveredByModalTransition) = self.validLayout {
                    self.update(layout: layout, controllers: [], coveredByModalTransition: coveredByModalTransition, transition: .immediate)
                }
                completion()
                
                var bounds = self.bounds
                bounds.origin.y = 0.0
                self.bounds = bounds
                
                return transition
            }
        }
    }
    
    private func findScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
        if let view = view {
            if let view = view as? UIScrollView {
                if view.description.contains("WKChildScroll") {
                    return nil
                } else {
                    return (view, nil)
                }
            }
            if let node = view.asyncdisplaykit_node as? ListView {
                return (node.scroller, node)
            }
            return findScrollView(view: view.superview)
        } else {
            return nil
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let convertedPoint = self.view.convert(point, to: self.container.view)
        if !self.container.frame.contains(convertedPoint) {
            return false
        }
        return super.point(inside: point, with: event)
    }
}
