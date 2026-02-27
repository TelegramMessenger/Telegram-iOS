import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import SwiftSignalKit
import DynamicCornerRadiusView
import TelegramPresentationData
import EdgeEffect

public final class ResizableSheetComponentEnvironment: Equatable {
    public struct BoundsUpdate {
        public let bounds: CGRect
        public let isInteractive: Bool
    }
    
    public let theme: PresentationTheme
    public let statusBarHeight: CGFloat
    public let safeInsets: UIEdgeInsets
    public let metrics: LayoutMetrics
    public let deviceMetrics: DeviceMetrics
    public let isDisplaying: Bool
    public let isCentered: Bool
    public let screenSize: CGSize
    public let regularMetricsSize: CGSize?
    public let dismiss: (Bool) -> Void
    public let boundsUpdated: ActionSlot<BoundsUpdate>
    
    public init(
        theme: PresentationTheme,
        statusBarHeight: CGFloat,
        safeInsets: UIEdgeInsets,
        metrics: LayoutMetrics,
        deviceMetrics: DeviceMetrics,
        isDisplaying: Bool,
        isCentered: Bool,
        screenSize: CGSize,
        regularMetricsSize: CGSize?,
        dismiss: @escaping (Bool) -> Void,
        boundsUpdated: ActionSlot<BoundsUpdate> = ActionSlot<BoundsUpdate>()
    ) {
        self.theme = theme
        self.statusBarHeight = statusBarHeight
        self.safeInsets = safeInsets
        self.metrics = metrics
        self.deviceMetrics = deviceMetrics
        self.isDisplaying = isDisplaying
        self.isCentered = isCentered
        self.screenSize = screenSize
        self.regularMetricsSize = regularMetricsSize
        self.dismiss = dismiss
        self.boundsUpdated = boundsUpdated
    }
    
    public static func ==(lhs: ResizableSheetComponentEnvironment, rhs: ResizableSheetComponentEnvironment) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.statusBarHeight != rhs.statusBarHeight {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.isDisplaying != rhs.isDisplaying {
            return false
        }
        if lhs.isCentered != rhs.isCentered {
            return false
        }
        if lhs.screenSize != rhs.screenSize {
            return false
        }
        if lhs.regularMetricsSize != rhs.regularMetricsSize {
            return false
        }
        return true
    }
}

public final class ResizableSheetComponent<ChildEnvironmentType: Sendable & Equatable>: Component {
    public typealias EnvironmentType = (ChildEnvironmentType, ResizableSheetComponentEnvironment)
    
    public class ExternalState {
        public fileprivate(set) var contentHeight: CGFloat
        
        public init() {
            self.contentHeight = 0.0
        }
    }
    
    public enum BackgroundColor: Equatable {
        case color(UIColor)
    }
    
    public let content: AnyComponent<ChildEnvironmentType>
    public let titleItem: AnyComponent<Empty>?
    public let leftItem: AnyComponent<Empty>?
    public let rightItem: AnyComponent<Empty>?
    public let hasTopEdgeEffect: Bool
    public let bottomItem: AnyComponent<Empty>?
    public let backgroundColor: BackgroundColor
    public let isFullscreen: Bool
    public let externalState: ExternalState?
    public let animateOut: ActionSlot<Action<()>>
    
    public init(
        content: AnyComponent<ChildEnvironmentType>,
        titleItem: AnyComponent<Empty>? = nil,
        leftItem: AnyComponent<Empty>? = nil,
        rightItem: AnyComponent<Empty>? = nil,
        hasTopEdgeEffect: Bool = true,
        bottomItem: AnyComponent<Empty>? = nil,
        backgroundColor: BackgroundColor,
        isFullscreen: Bool = false,
        externalState: ExternalState? = nil,
        animateOut: ActionSlot<Action<()>>,
    ) {
        self.content = content
        self.titleItem = titleItem
        self.leftItem = leftItem
        self.rightItem = rightItem
        self.hasTopEdgeEffect = hasTopEdgeEffect
        self.bottomItem = bottomItem
        self.backgroundColor = backgroundColor
        self.isFullscreen = isFullscreen
        self.externalState = externalState
        self.animateOut = animateOut
    }
    
    public static func ==(lhs: ResizableSheetComponent, rhs: ResizableSheetComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.titleItem != rhs.titleItem {
            return false
        }
        if lhs.leftItem != rhs.leftItem {
            return false
        }
        if lhs.rightItem != rhs.rightItem {
            return false
        }
        if lhs.hasTopEdgeEffect != rhs.hasTopEdgeEffect {
            return false
        }
        if lhs.bottomItem != rhs.bottomItem {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.isFullscreen != rhs.isFullscreen {
            return false
        }
        if lhs.animateOut != rhs.animateOut {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var containerCornerRadius: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        var fillingSize: CGFloat
        let isTablet: Bool
        
        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, bottomInset: CGFloat, topInset: CGFloat, fillingSize: CGFloat, isTablet: Bool) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.fillingSize = fillingSize
            self.isTablet = isTablet
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
        
    public final class View: UIView, UIScrollViewDelegate, ComponentTaggedView, UIGestureRecognizerDelegate {
        public final class Tag {
            public init() {
            }
        }
        
        public func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let bottomContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let topEdgeEffectView: EdgeEffectView
        private let bottomEdgeEffectView: EdgeEffectView
        private let contentView: ComponentView<ChildEnvironmentType>
        
        private var titleItemView: ComponentView<Empty>?
        private var leftItemView: ComponentView<Empty>?
        private var rightItemView: ComponentView<Empty>?
        private var bottomItemView: ComponentView<Empty>?
        
        private let backgroundHandleView: UIImageView
        
        private var ignoreScrolling: Bool = false
        private var isDismissingInteractively: Bool = false
        private var dismissTranslation: CGFloat = 0.0
        private var dismissStartTranslation: CGFloat?
        private var dismissPanGesture: UIPanGestureRecognizer?
        
        private var component: ResizableSheetComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var environment: ResizableSheetComponentEnvironment?
        private var itemLayout: ItemLayout?
                
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = UIView()
            
            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 40.0
            self.containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 40.0
                        
            self.backgroundHandleView = UIImageView()
            
            self.navigationBarContainer = SparseContainerView()
            self.bottomContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.topEdgeEffectView = EdgeEffectView()
            self.topEdgeEffectView.clipsToBounds = true
            self.topEdgeEffectView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.topEdgeEffectView.layer.cornerRadius = 40.0

            self.bottomEdgeEffectView = EdgeEffectView()
            self.bottomEdgeEffectView.clipsToBounds = true
            self.bottomEdgeEffectView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.bottomEdgeEffectView.layer.cornerRadius = 40.0
            
            self.contentView = ComponentView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.layer.addSublayer(self.backgroundLayer)
                        
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.containerView.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.containerView.addSubview(self.navigationBarContainer)
            self.containerView.addSubview(self.bottomContainer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            let dismissPanGesture = UIPanGestureRecognizer(target: self, action: #selector(self.dismissPanGesture(_:)))
            dismissPanGesture.maximumNumberOfTouches = 1
            dismissPanGesture.delegate = self
            self.addGestureRecognizer(dismissPanGesture)
            self.dismissPanGesture = dismissPanGesture
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            if let result = self.bottomContainer.hitTest(self.convert(point, to: self.bottomContainer), with: event) {
                return result
            }
            let result = super.hitTest(point, with: event)
            return result
        }
        
        override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === self.dismissPanGesture {
                let pan = gestureRecognizer as! UIPanGestureRecognizer
                let velocity = pan.velocity(in: self)
                if abs(velocity.y) <= abs(velocity.x) {
                    return false
                }
            }
            return true
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === self.dismissPanGesture {
                if otherGestureRecognizer === self.scrollView.panGestureRecognizer {
                    return true
                }
            }
            return false
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.dismissAnimated()
            }
        }
        
        public func dismissAnimated() {
            guard let environment = self.environment else {
                return
            }
            self.endEditing(true)
            environment.dismiss(true)
        }
        
        private func updateDismissTranslation(_ translation: CGFloat) {
            self.dismissTranslation = translation
            self.updateScrolling(transition: .immediate)
            
            let maxAlphaDistance = max(1.0, self.bounds.height * 0.9)
            let alpha = 1.0 - min(1.0, translation / maxAlphaDistance)
            self.dimView.alpha = alpha
        }
        
        private func resetDismissTranslation(animated: Bool) {
            self.dismissTranslation = 0.0
            if animated {
                let transition: ComponentTransition = .easeInOut(duration: 0.2)
                transition.setAlpha(view: self.dimView, alpha: 1.0)
                self.updateScrolling(transition: transition)
            } else {
                self.dimView.alpha = 1.0
                self.updateScrolling(transition: .immediate)
            }
        }
        
        @objc private func dismissPanGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            
            let translation = recognizer.translation(in: self)
            switch recognizer.state {
            case .began:
                self.dismissStartTranslation = nil
            case .changed:
                let shouldStartDismiss = self.scrollView.contentOffset.y <= 0.0 && translation.y > 0.0
                if shouldStartDismiss {
                    if !self.isDismissingInteractively {
                        self.isDismissingInteractively = true
                        self.dismissStartTranslation = translation.y
                        self.scrollView.isScrollEnabled = false
                    }
                    
                    let start = self.dismissStartTranslation ?? translation.y
                    let dismissOffset = max(0.0, translation.y - start)
                    self.scrollView.contentOffset = .zero
                    self.updateDismissTranslation(dismissOffset)
                } else if self.isDismissingInteractively {
                    let start = self.dismissStartTranslation ?? translation.y
                    let dismissOffset = max(0.0, translation.y - start)
                    self.updateDismissTranslation(dismissOffset)
                }
            case .ended, .cancelled:
                if self.isDismissingInteractively {
                    let velocityY = recognizer.velocity(in: self).y
                    let currentOffset = self.dismissTranslation
                    let threshold = min(180.0, self.bounds.height * 0.25)
                    let shouldDismiss = currentOffset > threshold || velocityY > 1000.0
                    
                    self.isDismissingInteractively = false
                    self.scrollView.isScrollEnabled = !component.isFullscreen
                    
                    if shouldDismiss {
                        let animateOffset = self.bounds.height - self.backgroundLayer.frame.minY
                        let initialVelocity = animateOffset > 0.0 ? max(0.0, velocityY) / animateOffset : 0.0
                        self.animateOut(initialVelocity: initialVelocity, completion: { [weak self] in
                            self?.environment?.dismiss(false)
                        })
                    } else {
                        self.resetDismissTranslation(animated: true)
                    }
                }
            default:
                break
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout, let component = self.component else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            if component.isFullscreen {
                topOffsetFraction = 1.0
            }
            
            let minScale: CGFloat = itemLayout.isTablet ? 1.0 : (itemLayout.containerSize.width - 6.0 * 2.0) / itemLayout.containerSize.width
            let minScaledTranslation: CGFloat = itemLayout.isTablet ? 0.0 : (itemLayout.containerSize.height - itemLayout.containerSize.height * minScale) * 0.5 - 6.0
            let minScaledCornerRadius: CGFloat = itemLayout.containerCornerRadius
            
            let scale = minScale * (1.0 - topOffsetFraction) + 1.0 * topOffsetFraction
            let scaledTranslation = minScaledTranslation * (1.0 - topOffsetFraction)
            let scaledCornerRadius = minScaledCornerRadius * (1.0 - topOffsetFraction) + itemLayout.containerCornerRadius * topOffsetFraction
            
            var containerTransform = CATransform3DIdentity
            containerTransform = CATransform3DTranslate(containerTransform, 0.0, scaledTranslation, 0.0)
            containerTransform = CATransform3DScale(containerTransform, scale, scale, scale)
            containerTransform = CATransform3DTranslate(containerTransform, 0.0, self.dismissTranslation, 0.0)
            transition.setTransform(view: self.containerView, transform: containerTransform)
            transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: scaledCornerRadius)
            
            if component.isFullscreen {
                transition.setBounds(view: self.scrollView, bounds: CGRect(origin: .zero, size: self.scrollView.bounds.size))
                self.scrollView.isScrollEnabled = false
            } else {
                self.scrollView.isScrollEnabled = !self.isDismissingInteractively
            }
            
            var bounds = self.scrollView.bounds
            bounds.size.width = itemLayout.fillingSize
            self.environment?.boundsUpdated.invoke(ResizableSheetComponentEnvironment.BoundsUpdate(bounds: bounds, isInteractive: self.scrollView.isTracking))
        }
        
        private var didPlayAppearanceAnimation = false
        func animateIn() {
            self.didPlayAppearanceAnimation = true
            
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(initialVelocity: CGFloat? = nil, completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: self.dimView.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false)
            if let initialVelocity = initialVelocity {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.35, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                
                transition.updatePosition(layer: self.scrollContentClippingView.layer, position: CGPoint(x: self.scrollContentClippingView.layer.position.x, y: self.scrollContentClippingView.layer.position.y + animateOffset), completion: { _ in
                    completion()
                })
                transition.updatePosition(layer: self.backgroundLayer, position: CGPoint(x: self.backgroundLayer.position.x, y: self.backgroundLayer.position.y + animateOffset))
                transition.updatePosition(layer: self.navigationBarContainer.layer, position: CGPoint(x: self.navigationBarContainer.layer.position.x, y: self.navigationBarContainer.layer.position.y + animateOffset))
                transition.updatePosition(layer: self.bottomContainer.layer, position: CGPoint(x: self.bottomContainer.layer.position.x, y: self.bottomContainer.layer.position.y + animateOffset))
            } else {
                let duration: Double = 0.25
                self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                    completion()
                })
                self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
                self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
                self.bottomContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
        }
      
        func update(component: ResizableSheetComponent<ChildEnvironmentType>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let sheetEnvironment = environment[ResizableSheetComponentEnvironment.self].value
            component.animateOut.connect { [weak self] completion in
                guard let self else {
                    return
                }
                self.animateOut {
                    completion(Void())
                }
            }
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let fillingSize: CGFloat
            if case .regular = sheetEnvironment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - sheetEnvironment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, sheetEnvironment.deviceMetrics.screenSize.width) - sheetEnvironment.safeInsets.left * 2.0
            }
            let rawSideInset: CGFloat = floor((availableSize.width - fillingSize) * 0.5)

            self.component = component
            self.state = state
            self.environment = sheetEnvironment
            
            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            
            let backgroundColor: UIColor
            switch component.backgroundColor {
            case let .color(color):
                backgroundColor = color
                self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            }
                        
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
                
            var containerSize: CGSize
            if !"".isEmpty, sheetEnvironment.isCentered {
                let verticalInset: CGFloat = 44.0
                let maxSide = max(availableSize.width, availableSize.height)
                let minSide = min(availableSize.width, availableSize.height)
                containerSize = CGSize(width: min(availableSize.width - 20.0, floor(maxSide / 2.0)), height: min(availableSize.height, minSide) - verticalInset * 2.0)
                if let regularMetricsSize = sheetEnvironment.regularMetricsSize {
                    containerSize = regularMetricsSize
                }
            } else {
                containerSize = CGSize(width: fillingSize, height: .greatestFiniteMagnitude)
            }
            
            var containerInset: CGFloat = sheetEnvironment.statusBarHeight + 10.0
            if component.isFullscreen {
                containerInset = 0.0
            }
            let clippingY: CGFloat
            
            self.contentView.parentState = state
            let contentViewSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    environment[ChildEnvironmentType.self]
                },
                containerSize: containerSize
            )
            component.externalState?.contentHeight = contentViewSize.height
            
            if let contentView = self.contentView.view {
                if contentView.superview == nil {
                    self.scrollContentView.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: contentViewSize))
            }
                             
            let contentHeight = contentViewSize.height
            let initialContentHeight = contentHeight
            
            let edgeEffectHeight: CGFloat = 80.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: CGSize(width: fillingSize, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: edgeEffectFrame)
            self.topEdgeEffectView.update(content: backgroundColor, blur: true, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectFrame.height, transition: transition)
            if self.topEdgeEffectView.superview == nil {
                self.navigationBarContainer.insertSubview(self.topEdgeEffectView, at: 0)
            }
            self.topEdgeEffectView.isHidden = !component.hasTopEdgeEffect
            
            if let titleItem = component.titleItem {
                let titleItemView: ComponentView<Empty>
                if let current = self.titleItemView {
                    titleItemView = current
                } else {
                    titleItemView = ComponentView<Empty>()
                    self.titleItemView = titleItemView
                }
                
                let titleItemSize = titleItemView.update(
                    transition: transition,
                    component: titleItem,
                    environment: {},
                    containerSize: CGSize(width: containerSize.width - 66.0 * 2.0, height: 66.0)
                )
                let titleItemFrame = CGRect(origin: CGPoint(x: rawSideInset + floorToScreenPixels((containerSize.width - titleItemSize.width)) / 2.0, y: floorToScreenPixels(38.0 - titleItemSize.height * 0.5)), size: titleItemSize)
                if let view = titleItemView.view {
                    if view.superview == nil {
                        self.navigationBarContainer.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: titleItemFrame)
                }
            } else if let titleItemView = self.titleItemView {
                self.titleItemView = nil
                titleItemView.view?.removeFromSuperview()
            }
            
            if let leftItem = component.leftItem {
                var leftItemTransition = transition
                let leftItemView: ComponentView<Empty>
                if let current = self.leftItemView {
                    leftItemView = current
                } else {
                    leftItemTransition = .immediate
                    leftItemView = ComponentView<Empty>()
                    self.leftItemView = leftItemView
                }
                
                let leftItemSize = leftItemView.update(
                    transition: leftItemTransition,
                    component: leftItem,
                    environment: {},
                    containerSize: CGSize(width: 66.0, height: 66.0)
                )
                let leftItemFrame = CGRect(origin: CGPoint(x: rawSideInset + 16.0, y: 16.0), size: leftItemSize)
                if let view = leftItemView.view {
                    if view.superview == nil {
                        self.navigationBarContainer.addSubview(view)
                        
                        if !transition.animation.isImmediate {
                            view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    leftItemTransition.setFrame(view: view, frame: leftItemFrame)
                }
            } else if let leftItemView = self.leftItemView {
                self.leftItemView = nil
                if !transition.animation.isImmediate {
                    leftItemView.view?.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                    leftItemView.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        leftItemView.view?.removeFromSuperview()
                    })
                } else {
                    leftItemView.view?.removeFromSuperview()
                }
            }
            
            if let rightItem = component.rightItem {
                var rightItemTransition = transition
                let rightItemView: ComponentView<Empty>
                if let current = self.rightItemView {
                    rightItemView = current
                } else {
                    rightItemTransition = .immediate
                    rightItemView = ComponentView<Empty>()
                    self.rightItemView = rightItemView
                }
                
                let rightItemSize = rightItemView.update(
                    transition: rightItemTransition,
                    component: rightItem,
                    environment: {},
                    containerSize: CGSize(width: 66.0, height: 66.0)
                )
                let rightItemFrame = CGRect(origin: CGPoint(x: availableSize.width - rawSideInset - 16.0 - rightItemSize.width, y: 16.0), size: rightItemSize)
                if let view = rightItemView.view {
                    if view.superview == nil {
                        self.navigationBarContainer.addSubview(view)
                        
                        if !transition.animation.isImmediate {
                            view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    rightItemTransition.setFrame(view: view, frame: rightItemFrame)
                }
            } else if let rightItemView = self.rightItemView {
                self.rightItemView = nil
                if !transition.animation.isImmediate {
                    rightItemView.view?.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                    rightItemView.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        rightItemView.view?.removeFromSuperview()
                    })
                } else {
                    rightItemView.view?.removeFromSuperview()
                }
            }
            
            if let bottomItem = component.bottomItem {
                var bottomItemTransition = transition
                let bottomItemView: ComponentView<Empty>
                if let current = self.bottomItemView {
                    bottomItemView = current
                } else {
                    bottomItemTransition = .immediate
                    bottomItemView = ComponentView<Empty>()
                    self.bottomItemView = bottomItemView
                }
                
                let bottomInsets = ContainerViewLayout.concentricInsets(bottomInset: sheetEnvironment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
                let bottomItemSize = bottomItemView.update(
                    transition: bottomItemTransition,
                    component: bottomItem,
                    environment: {},
                    containerSize: CGSize(width: containerSize.width - bottomInsets.left - bottomInsets.right, height: 52.0)
                )
                let bottomItemFrame = CGRect(origin: CGPoint(x: rawSideInset + floorToScreenPixels((containerSize.width - bottomItemSize.width)) / 2.0, y: availableSize.height - bottomItemSize.height - bottomInsets.bottom), size: bottomItemSize)
                if let view = bottomItemView.view {
                    if view.superview == nil {
                        self.bottomContainer.addSubview(view)
                        
                        if !transition.animation.isImmediate {
                            view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    bottomItemTransition.setFrame(view: view, frame: bottomItemFrame)
                }
            } else if let bottomItemView = self.bottomItemView {
                self.bottomItemView = nil
                if !transition.animation.isImmediate {
                    bottomItemView.view?.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                    bottomItemView.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        bottomItemView.view?.removeFromSuperview()
                    })
                } else {
                    bottomItemView.view?.removeFromSuperview()
                }
            }
            
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: availableSize.height - edgeEffectHeight), size: CGSize(width: fillingSize, height: edgeEffectHeight))
            transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            self.bottomEdgeEffectView.update(content: .clear, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: transition)
            if self.bottomEdgeEffectView.superview == nil {
                self.bottomContainer.insertSubview(self.bottomEdgeEffectView, at: 0)
            }
            transition.setAlpha(view: self.bottomContainer, alpha: component.bottomItem != nil ? 1.0 : 0.0)
            
             
            clippingY = availableSize.height
            
            var topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            if component.isFullscreen {
                topInset = 0.0
            }
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 38.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, containerCornerRadius: sheetEnvironment.deviceMetrics.screenCornerRadius, bottomInset: sheetEnvironment.safeInsets.bottom, topInset: topInset, fillingSize: fillingSize, isTablet: sheetEnvironment.metrics.isTablet)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: fillingSize, height: availableSize.height)))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: availableSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setPosition(view: self.containerView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            if sheetEnvironment.isDisplaying && !self.didPlayAppearanceAnimation {
                self.animateIn()
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
