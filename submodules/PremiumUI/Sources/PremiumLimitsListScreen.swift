import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent

private final class PremimLimitsListScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let expand: () -> Void
    
    init(context: AccountContext, expand: @escaping () -> Void) {
        self.context = context
        self.expand = expand
    }
    
    static func ==(lhs: PremimLimitsListScreenComponent, rhs: PremimLimitsListScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
                
        init(context: AccountContext) {
            self.context = context
          
            super.init()
            
        }
    }
    
    func makeState() -> State {
        return State(context: self.context)
    }
    
    static var body: Body {
        return { context in
//            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
//            let state = context.state
//            let theme = environment.theme
//            let strings = environment.strings
//            return CGSize(width: context.availableSize.width, height: environment.navigationHeight + image.size.height + environment.safeInsets.bottom)
            return context.availableSize
        }
    }
}

public class PremimLimitsListScreen: ViewController {
    final class Node: ViewControllerTracingNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: PremimLimitsListScreen?
        
        private let component: AnyComponent<ViewControllerComponentContainer.Environment>
        private let theme: PresentationTheme?
        
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        let scrollView: UIScrollView
        let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        fileprivate var temporaryDismiss = false
        
        init(context: AccountContext, controller: PremimLimitsListScreen, component: AnyComponent<ViewControllerComponentContainer.Environment>, theme: PresentationTheme?) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            self.theme = theme
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.scrollView = UIScrollView()
            self.hostView = ComponentHostView()
            
            super.init()
            
            self.scrollView.delegate = self
            self.scrollView.showsVerticalScrollIndicator = false
            
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.scrollView)
            self.scrollView.addSubview(self.hostView)
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let (layout, _) = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = self.scrollView.contentOffset.y
            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            if !self.temporaryDismiss {
                self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
            }
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: Transition) {
            self.currentLayout = (layout, navigationHeight)
            
            if let controller = self.controller, let navigationBar = controller.navigationBar, navigationBar.view.superview !== self.wrappingView {
                self.containerView.addSubview(navigationBar.view)
            }
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            let modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            
            let clipFrame: CGRect
            if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    var containerTopInset: CGFloat = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
                
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: clipFrame.size), completion: nil)
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                isVisible: self.currentIsVisible,
                theme: self.theme ?? self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            var contentSize = self.hostView.update(
                transition: transition,
                component: self.component,
                environment: {
                    environment
                },
                forceUpdate: true,
                containerSize: CGSize(width: clipFrame.size.width, height: 10000.0)
            )
            contentSize.height = max(layout.size.height - navigationHeight, contentSize.height)
            transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            
            self.scrollView.contentSize = contentSize
        }
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var defaultTopInset: CGFloat {
            guard let (layout, _) = self.currentLayout else{
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
        
        private func findScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? UIScrollView {
                    return (view, nil)
                }
                if let node = view.asyncdisplaykit_node as? ListView {
                    return (node.scroller, node)
                }
                return findScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollViewAndListNode = self.findScrollView(view: currentHitView)
                    if scrollViewAndListNode?.0.frame.height == self.frame.width {
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
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                        }
                    } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView, listNode)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
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
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let listNode = listNode {
                                listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            } else if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if (velocity.y < -300.0 || offset < topInset / 2.0) {
                        if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                            DispatchQueue.main.async {
                                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            }
                        }
                                                    
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.isExpanded = isExpanded
            
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let theme: PresentationTheme?
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    private var isInitiallyExpanded = false
    
    private var currentLayout: ContainerViewLayout?
        
    public convenience init(context: AccountContext) {
        var expandImpl: (() -> Void)?
        self.init(context: context, component: PremimLimitsListScreenComponent(context: context, expand: {
            expandImpl?()
        }))
                        
        self.title = "Doubled Limits"
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        let rightBarButtonNode = ASImageNode()
        rightBarButtonNode.image = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0xededed), foregroundColor: UIColor(rgb: 0x7f8084))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: rightBarButtonNode)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
                
        expandImpl = { [weak self] in
            self?.node.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
            if let currentLayout = self?.currentLayout {
                self?.containerLayoutUpdated(currentLayout, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
    }
    
    private init<C: Component>(context: AccountContext, component: C, theme: PresentationTheme? = nil) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        self.theme = nil
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: context.sharedContext.currentPresentationData.with { $0 }))
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, component: self.component, theme: self.theme)
        if self.isInitiallyExpanded {
            (self.displayNode as! Node).update(isExpanded: true, transition: .immediate)
        }
        self.displayNodeDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
    
    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var navigationLayout = self.navigationLayout(layout: layout)
        var navigationFrame = navigationLayout.navigationFrame
        
        var layout = layout
        if case .regular = layout.metrics.widthClass {
            let verticalInset: CGFloat = 44.0
            let maxSide = max(layout.size.width, layout.size.height)
            let minSide = min(layout.size.width, layout.size.height)
            let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
            let clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            navigationFrame.size.width = clipFrame.width
            layout.size = clipFrame.size
        }
        
        navigationFrame.size.height = 56.0
        navigationLayout.navigationFrame = navigationFrame
        navigationLayout.defaultContentHeight = 56.0
        
        layout.statusBarHeight = nil
        
        self.applyNavigationBarLayout(layout, navigationLayout: navigationLayout, additionalBackgroundHeight: 0.0, transition: transition)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight: CGFloat = 56.0
        
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
    }
}


//import Foundation
//import UIKit
//import Display
//import AsyncDisplayKit
//import Postbox
//import TelegramCore
//import SwiftSignalKit
//import AccountContext
//import TelegramPresentationData
//import PresentationDataUtils
//import ComponentFlow
//import ViewControllerComponent
//import SheetComponent
//import MultilineTextComponent
//import BundleIconComponent
//import SolidRoundedButtonComponent
//import Markdown
//
//private final class PremiumLimitsListContent: CombinedComponent {
//    typealias EnvironmentType = ViewControllerComponentContainer.Environment
//    
//    let context: AccountContext
//    let subject: PremiumDemoScreen.Subject
//    let source: PremiumDemoScreen.Source
//    let action: () -> Void
//    let dismiss: () -> Void
//    
//    init(context: AccountContext, action: @escaping () -> Void, dismiss: @escaping () -> Void) {
//        self.context = context
//        self.action = action
//        self.dismiss = dismiss
//    }
//    
//    static func ==(lhs: PremiumLimitsListContent, rhs: PremiumLimitsListContent) -> Bool {
//        if lhs.context !== rhs.context {
//            return false
//        }
//        return true
//    }
//    
//    final class State: ComponentState {
//        private let context: AccountContext
//        var cachedCloseImage: UIImage?
//        
//        var limits: EngineConfiguration.UserLimits = .defaultValue
//        var premiumLimits: EngineConfiguration.UserLimits = .defaultValue
//        var disposable: Disposable?
//        
//        init(context: AccountContext) {
//            self.context = context
//            
//            super.init()
//            
//            self.disposable = (self.context.engine.data.get(
//                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
//                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
//            )
//            |> deliverOnMainQueue).start(next: { [weak self] limits, premiumLimits in
//                guard let strongSelf = self else {
//                    return
//                }
//                strongSelf.limits = limits
//                strongSelf.premiumLimits = premiumLimits
//                strongSelf.updated(transition: .immediate)
//            })
//        }
//        
//        deinit {
//            self.disposable?.dispose()
//        }
//    }
//    
//    func makeState() -> State {
//        return State(context: self.context)
//    }
//    
//    static var body: Body {
//        let closeButton = Child(Button.self)
//        let button = Child(SolidRoundedButtonComponent.self)
//        
//        return { context in
//            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
//            let component = context.component
////            let theme = environment.theme
//            let strings = environment.strings
//            
//            let state = context.state
//            
//            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
//                                
//            let closeImage: UIImage
//            if let image = state.cachedCloseImage {
//                closeImage = image
//            } else {
//                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.1), foregroundColor: UIColor(rgb: 0xffffff))!
//                state.cachedCloseImage = closeImage
//            }
//            
//            let closeButton = closeButton.update(
//                component: Button(
//                    content: AnyComponent(Image(image: closeImage)),
//                    action: { [weak component] in
//                        component?.dismiss()
//                    }
//                ),
//                availableSize: CGSize(width: 30.0, height: 30.0),
//                transition: .immediate
//            )
//            context.add(closeButton
//                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
//            )
//                         
//            let buttonText: String
//            switch component.source {
//                case let .intro(price):
//                    buttonText = strings.Premium_SubscribeFor(price ?? "–").string
//                case .other:
//                    buttonText = strings.Premium_MoreAboutPremium
//            }
//            
//            let button = button.update(
//                component: SolidRoundedButtonComponent(
//                    title: buttonText,
//                    theme: SolidRoundedButtonComponent.Theme(
//                        backgroundColor: .black,
//                        backgroundColors: [
//                            UIColor(rgb: 0x0077ff),
//                            UIColor(rgb: 0x6b93ff),
//                            UIColor(rgb: 0x8878ff),
//                            UIColor(rgb: 0xe46ace)
//                        ],
//                        foregroundColor: .white
//                    ),
//                    font: .bold,
//                    fontSize: 17.0,
//                    height: 50.0,
//                    cornerRadius: 10.0,
//                    gloss: true,
//                    iconPosition: .right,
//                    action: { [weak component] in
//                        guard let component = component else {
//                            return
//                        }
//                        component.dismiss()
//                        component.action()
//                    }
//                ),
//                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
//                transition: context.transition
//            )
//              
//            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: context.availableSize.width + 154.0 + 20.0), size: button.size)
//            context.add(button
//                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
//            )
//            
//            let contentSize = CGSize(width: context.availableSize.width, height: buttonFrame.maxY + 5.0 + environment.safeInsets.bottom)
//            
//            return contentSize
//        }
//    }
//}
//
//
//private final class PremiumLimitsListComponent: CombinedComponent {
//    typealias EnvironmentType = ViewControllerComponentContainer.Environment
//    
//    let context: AccountContext
//    let action: () -> Void
//    
//    init(context: AccountContext, action: @escaping () -> Void) {
//        self.context = context
//        self.action = action
//    }
//    
//    static func ==(lhs: PremiumLimitsListComponent, rhs: PremiumLimitsListComponent) -> Bool {
//        if lhs.context !== rhs.context {
//            return false
//        }
//        
//        return true
//    }
//    
//    static var body: Body {
//        let sheet = Child(SheetComponent<EnvironmentType>.self)
//        let animateOut = StoredActionSlot(Action<Void>.self)
//        
//        return { context in
//            let environment = context.environment[EnvironmentType.self]
//            
//            let controller = environment.controller
//            
//            let sheet = sheet.update(
//                component: SheetComponent<EnvironmentType>(
//                    content: AnyComponent<EnvironmentType>(PremiumLimitsListContent(
//                        context: context.component.context,
//                        action: context.component.action,
//                        dismiss: {
//                            animateOut.invoke(Action { _ in
//                                if let controller = controller() {
//                                    controller.dismiss(completion: nil)
//                                }
//                            })
//                        }
//                    )),
//                    backgroundColor: environment.theme.actionSheet.opaqueItemBackgroundColor,
//                    animateOut: animateOut
//                ),
//                environment: {
//                    environment
//                    SheetComponentEnvironment(
//                        isDisplaying: environment.value.isVisible,
//                        dismiss: {
//                            animateOut.invoke(Action { _ in
//                                if let controller = controller() {
//                                    controller.dismiss(completion: nil)
//                                }
//                            })
//                        }
//                    )
//                },
//                availableSize: context.availableSize,
//                transition: context.transition
//            )
//            
//            context.add(sheet
//                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
//            )
//            
//            return context.availableSize
//        }
//    }
//}
//
//public class PremiumLimitsListScreen: ViewControllerComponentContainer {
//    var disposed: () -> Void = {}
//    
//    public init(context: AccountContext, action: @escaping () -> Void) {
//        super.init(context: context, component: PremiumLimitsListComponent(context: context, action: action), navigationBarAppearance: .none)
//        
//        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
//        
//        self.navigationPresentation = .flatModal
//    }
//    
//    required public init(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    deinit {
//        self.disposed()
//    }
//    
//    public override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        self.view.disablesInteractiveModalDismiss = true
//    }
//}
//
//
//
//
//
//public final class ExpandingSheetEnvironment: Equatable {
//    public let isDisplaying: Bool
//    public let dismiss: () -> Void
//    
//    public init(isDisplaying: Bool, dismiss: @escaping () -> Void) {
//        self.isDisplaying = isDisplaying
//        self.dismiss = dismiss
//    }
//    
//    public static func ==(lhs: ExpandingSheetEnvironment, rhs: ExpandingSheetEnvironment) -> Bool {
//        if lhs.isDisplaying != rhs.isDisplaying {
//            return false
//        }
//        return true
//    }
//}
//
//public final class ExpandingSheetComponent<ChildEnvironmentType: Equatable>: Component {
//    public typealias EnvironmentType = (ChildEnvironmentType, SheetComponentEnvironment)
//    
//    public let content: AnyComponent<ChildEnvironmentType>
//    public let backgroundColor: UIColor
//    public let animateOut: ActionSlot<Action<()>>
//    
//    public init(content: AnyComponent<ChildEnvironmentType>, backgroundColor: UIColor, animateOut: ActionSlot<Action<()>>) {
//        self.content = content
//        self.backgroundColor = backgroundColor
//        self.animateOut = animateOut
//    }
//    
//    public static func ==(lhs: ExpandingSheetComponent, rhs: ExpandingSheetComponent) -> Bool {
//        if lhs.content != rhs.content {
//            return false
//        }
//        if lhs.backgroundColor != rhs.backgroundColor {
//            return false
//        }
//        if lhs.animateOut != rhs.animateOut {
//            return false
//        }
//        
//        return true
//    }
//    
//    public final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
//        private let dimView: UIView
//        private let wrappingView: UIView
//        private let containerView: UIView
//        private let scrollView: UIScrollView
//        private let contentView: ComponentHostView<ChildEnvironmentType>
//        
//        private(set) var isExpanded = false
//        private var panGestureRecognizer: UIPanGestureRecognizer?
//        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
//        
//        private var previousIsDisplaying: Bool = false
//        private var dismiss: (() -> Void)?
//        
//        override init(frame: CGRect) {
//            self.dimView = UIView()
//            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
//            
//            self.wrappingView = UIView()
//            self.containerView = UIView()
//            self.scrollView = UIScrollView()
//            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
//                self.scrollView.contentInsetAdjustmentBehavior = .never
//            }
//            
//            self.contentView = ComponentHostView<ChildEnvironmentType>()
//            
//            super.init(frame: frame)
//            
//            self.addSubview(self.dimView)
//            
//            self.scrollView.delegate = self
//            self.scrollView.showsVerticalScrollIndicator = false
//            
//            self.containerView.clipsToBounds = true
//            
//            self.addSubview(self.wrappingView)
//            self.wrappingView.addSubview(self.containerView)
//            self.containerView.addSubview(self.scrollView)
//            self.scrollView.addSubview(self.contentView)
//            
//            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimViewTapGesture(_:))))
//            
//            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
//            panRecognizer.delegate = self
//            panRecognizer.delaysTouchesBegan = false
//            panRecognizer.cancelsTouchesInView = true
//            self.panGestureRecognizer = panRecognizer
//            self.wrappingView.addGestureRecognizer(panRecognizer)
//        }
//        
//        required init?(coder: NSCoder) {
//            fatalError("init(coder:) has not been implemented")
//        }
//        
//        @objc private func dimViewTapGesture(_ recognizer: UITapGestureRecognizer) {
//            if case .ended = recognizer.state {
//                self.dismiss?()
//            }
//        }
//        
//        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//            if let (layout, _) = self.currentLayout {
//                if case .regular = layout.metrics.widthClass {
//                    return false
//                }
//            }
//            return true
//        }
//        
//        func scrollViewDidScroll(_ scrollView: UIScrollView) {
//            let contentOffset = self.scrollView.contentOffset.y
//            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
//        }
//        
//        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
//                return true
//            }
//            return false
//        }
//        
//      
//        
//        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
//            if !self.backgroundView.bounds.contains(self.convert(point, to: self.backgroundView)) {
//                return self.dimView
//            }
//            
//            return super.hitTest(point, with: event)
//        }
//        
//        private func animateOut(completion: @escaping () -> Void) {
//            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
//            self.scrollView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.bounds.height - self.scrollView.contentInset.top), duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
//                completion()
//            })
//        }
//        
//        func update(component: ExpandingSheetComponent<ChildEnvironmentType>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
//            component.animateOut.connect { [weak self] completion in
//                guard let strongSelf = self else {
//                    return
//                }
//                strongSelf.animateOut {
//                    completion(Void())
//                }
//            }
//            
//            if self.backgroundView.backgroundColor != component.backgroundColor {
//                self.backgroundView.backgroundColor = component.backgroundColor
//            }
//            
//            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
//            
//            let contentSize = self.contentView.update(
//                transition: transition,
//                component: component.content,
//                environment: {
//                    environment[ChildEnvironmentType.self]
//                },
//                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
//            )
//            
//            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
//            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height + 1000.0)), completion: nil)
//            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
//            self.scrollView.contentSize = contentSize
//            self.scrollView.contentInset = UIEdgeInsets(top: max(0.0, availableSize.height - contentSize.height), left: 0.0, bottom: 0.0, right: 0.0)
//            
//            if environment[SheetComponentEnvironment.self].value.isDisplaying, !self.previousIsDisplaying, let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
//                self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
//                self.scrollView.layer.animatePosition(from: CGPoint(x: 0.0, y: availableSize.height - self.scrollView.contentInset.top), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true, completion: nil)
//            } else if !environment[SheetComponentEnvironment.self].value.isDisplaying, self.previousIsDisplaying, let _ = transition.userData(ViewControllerComponentContainer.AnimateOutTransition.self) {
//                self.animateOut(completion: {})
//            }
//            self.previousIsDisplaying = environment[SheetComponentEnvironment.self].value.isDisplaying
//            
//            self.dismiss = environment[SheetComponentEnvironment.self].value.dismiss
//            
//            return availableSize
//        }
//    }
//    
//    public func makeView() -> View {
//        return View(frame: CGRect())
//    }
//    
//    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
//        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
//    }
//}
