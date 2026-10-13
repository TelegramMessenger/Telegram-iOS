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
    public let inputHeight: CGFloat
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
        inputHeight: CGFloat,
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
        self.inputHeight = inputHeight
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
        if lhs.inputHeight != rhs.inputHeight {
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
        fileprivate var trackedScrollViewUpdated: ((UIScrollView?) -> Void)?

        public init() {
            self.contentHeight = 0.0
        }

        public func setTrackedScrollView(_ scrollView: UIScrollView?) {
            self.trackedScrollViewUpdated?(scrollView)
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
    public let bottomEdgeEffectExtension: CGFloat
    public let backgroundColor: BackgroundColor
    public let clipsContent: Bool
    public let isFullscreen: Bool
    public let allowsExpansion: Bool
    public let centeredSize: CGSize?
    public let defaultHeight: CGFloat?
    public let externalState: ExternalState?
    public let animateOut: ActionSlot<Action<()>>

    public init(
        content: AnyComponent<ChildEnvironmentType>,
        titleItem: AnyComponent<Empty>? = nil,
        leftItem: AnyComponent<Empty>? = nil,
        rightItem: AnyComponent<Empty>? = nil,
        hasTopEdgeEffect: Bool = true,
        bottomItem: AnyComponent<Empty>? = nil,
        bottomEdgeEffectExtension: CGFloat = 0.0,
        backgroundColor: BackgroundColor,
        clipsContent: Bool = false,
        isFullscreen: Bool = false,
        allowsExpansion: Bool = true,
        centeredSize: CGSize? = nil,
        defaultHeight: CGFloat? = nil,
        externalState: ExternalState? = nil,
        animateOut: ActionSlot<Action<()>>,
    ) {
        self.content = content
        self.titleItem = titleItem
        self.leftItem = leftItem
        self.rightItem = rightItem
        self.hasTopEdgeEffect = hasTopEdgeEffect
        self.bottomItem = bottomItem
        self.bottomEdgeEffectExtension = bottomEdgeEffectExtension
        self.backgroundColor = backgroundColor
        self.clipsContent = clipsContent
        self.isFullscreen = isFullscreen
        self.allowsExpansion = allowsExpansion
        self.centeredSize = centeredSize
        self.defaultHeight = defaultHeight
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
        if lhs.bottomEdgeEffectExtension != rhs.bottomEdgeEffectExtension {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.clipsContent != rhs.clipsContent {
            return false
        }
        if lhs.isFullscreen != rhs.isFullscreen {
            return false
        }
        if lhs.allowsExpansion != rhs.allowsExpansion || lhs.centeredSize != rhs.centeredSize {
            return false
        }
        if lhs.defaultHeight != rhs.defaultHeight {
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
        let isCentered: Bool

        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, bottomInset: CGFloat, topInset: CGFloat, fillingSize: CGFloat, isTablet: Bool, isCentered: Bool) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.fillingSize = fillingSize
            self.isTablet = isTablet
            self.isCentered = isCentered
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
        
        public var contentViewValue: UIView? {
            return self.contentView.view
        }

        private let dimView: UIView
        public let containerView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let bottomContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView

        private let topEdgeEffectView: EdgeEffectView
        private let bottomEdgeEffectView: EdgeEffectView
        private let bottomEdgeEffectFillView: UIView
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
        private var registeredExternalState: ExternalState?
        private weak var trackedScrollView: UIScrollView?
        private var trackedScrollViewWasAtTopOnGestureBegan = false

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
            self.topEdgeEffectView.isUserInteractionEnabled = false

            self.bottomEdgeEffectView = EdgeEffectView()
            self.bottomEdgeEffectView.clipsToBounds = true
            self.bottomEdgeEffectView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.bottomEdgeEffectView.layer.cornerRadius = 40.0
            self.bottomEdgeEffectView.isUserInteractionEnabled = false

            self.bottomEdgeEffectFillView = UIView()
            self.bottomEdgeEffectFillView.isUserInteractionEnabled = false
            
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

        deinit {
            self.registeredExternalState?.trackedScrollViewUpdated = nil
            self.setTrackedScrollView(nil)
        }

        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }

        public func scrollToBottom(transition: ComponentTransition) {
            guard let component = self.component, !component.isFullscreen else {
                return
            }
            let bottomOffset = max(
                -self.scrollView.adjustedContentInset.top,
                self.scrollView.contentSize.height + self.scrollView.adjustedContentInset.bottom - self.scrollView.bounds.height
            )
            guard self.scrollView.bounds.minY != bottomOffset else {
                return
            }
            self.ignoreScrolling = true
            transition.setBoundsOrigin(view: self.scrollView, origin: CGPoint(x: self.scrollView.bounds.minX, y: bottomOffset))
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
        }

        public var expansionFraction: CGFloat {
            guard let itemLayout = self.itemLayout, itemLayout.topInset > 0.0 else {
                return 0.0
            }
            return max(0.0, min(1.0, self.scrollView.bounds.minY / itemLayout.topInset))
        }

        public func setExpansionFraction(_ fraction: CGFloat, transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout, let component = self.component, !component.isFullscreen, !itemLayout.isCentered else {
                return
            }
            self.ignoreScrolling = true
            transition.setBoundsOrigin(view: self.scrollView, origin: CGPoint(x: 0.0, y: itemLayout.topInset * max(0.0, min(1.0, fraction))))
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
        }

        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(self.convert(point, to: self.containerView)) {
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
                if self.itemLayout?.isCentered == true {
                    return false
                }
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
                if otherGestureRecognizer === self.trackedScrollView?.panGestureRecognizer {
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
                let trackedScrollViewIsAtTop = self.trackedScrollView.map { $0.contentOffset.y <= self.trackedScrollViewTopOffset($0) + 0.5 } ?? true
                let shouldStartDismiss = self.scrollView.contentOffset.y <= 0.0 && trackedScrollViewIsAtTop && translation.y > 0.0
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
                    self.scrollView.isScrollEnabled = !component.isFullscreen && component.allowsExpansion

                    if shouldDismiss {
                        let animateOffset = self.bounds.height - self.containerView.convert(self.backgroundLayer.frame, to: self).minY
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

        private func trackedScrollViewTopOffset(_ scrollView: UIScrollView) -> CGFloat {
            return -scrollView.contentInset.top
        }

        private func isSheetFullyExpanded(itemLayout: ItemLayout) -> Bool {
            return itemLayout.topInset <= 0.5 || self.scrollView.contentOffset.y >= itemLayout.topInset - 0.5
        }

        private func pinTrackedScrollViewToTop(_ scrollView: UIScrollView) {
            let topOffset = self.trackedScrollViewTopOffset(scrollView)
            if abs(scrollView.contentOffset.y - topOffset) > 0.5 {
                scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: topOffset)
            }
        }

        private func updateTrackedScrollViewLock() {
            guard let component = self.component, let itemLayout = self.itemLayout, let trackedScrollView = self.trackedScrollView else {
                return
            }
            trackedScrollView.isScrollEnabled = true
            if component.isFullscreen || itemLayout.isCentered {
                return
            }
            if !self.isSheetFullyExpanded(itemLayout: itemLayout) || self.isDismissingInteractively {
                self.pinTrackedScrollViewToTop(trackedScrollView)
            }
        }

        private func setTrackedScrollView(_ scrollView: UIScrollView?) {
            if self.trackedScrollView === scrollView {
                self.updateTrackedScrollViewLock()
                return
            }

            if let trackedScrollView = self.trackedScrollView {
                trackedScrollView.panGestureRecognizer.removeTarget(self, action: #selector(self.trackedScrollViewPanGesture(_:)))
                trackedScrollView.isScrollEnabled = true
            }

            self.trackedScrollView = scrollView

            if let scrollView = scrollView {
                scrollView.panGestureRecognizer.addTarget(self, action: #selector(self.trackedScrollViewPanGesture(_:)))
            }

            self.trackedScrollViewWasAtTopOnGestureBegan = false
            self.updateTrackedScrollViewLock()
        }

        @objc private func trackedScrollViewPanGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let component = self.component, let itemLayout = self.itemLayout, let trackedScrollView = recognizer.view as? UIScrollView else {
                return
            }
            guard !component.isFullscreen, component.allowsExpansion, !itemLayout.isCentered, itemLayout.topInset > 0.5 else {
                return
            }

            let topOffset = self.trackedScrollViewTopOffset(trackedScrollView)
            let isAtTop = trackedScrollView.contentOffset.y <= topOffset + 8.0

            switch recognizer.state {
            case .began, .changed:
                if recognizer.state == .began {
                    self.trackedScrollViewWasAtTopOnGestureBegan = isAtTop
                }
                let translation = recognizer.translation(in: trackedScrollView)
                let currentSheetOffset = min(max(0.0, self.scrollView.contentOffset.y), itemLayout.topInset)
                let shouldExpandSheet = self.trackedScrollViewWasAtTopOnGestureBegan && currentSheetOffset < itemLayout.topInset - 0.5

                if translation.y < 0.0 && shouldExpandSheet {
                    let consumedOffset = min(itemLayout.topInset - currentSheetOffset, -translation.y)
                    if consumedOffset > 0.0 {
                        self.scrollView.contentOffset = CGPoint(x: self.scrollView.contentOffset.x, y: currentSheetOffset + consumedOffset)
                        self.pinTrackedScrollViewToTop(trackedScrollView)
                        recognizer.setTranslation(.zero, in: trackedScrollView)
                    }
                } else if translation.y > 0.0 && isAtTop && currentSheetOffset > 0.5 {
                    let consumedOffset = min(currentSheetOffset, translation.y)
                    if consumedOffset > 0.0 {
                        self.scrollView.contentOffset = CGPoint(x: self.scrollView.contentOffset.x, y: currentSheetOffset - consumedOffset)
                        self.pinTrackedScrollViewToTop(trackedScrollView)
                        recognizer.setTranslation(.zero, in: trackedScrollView)
                    }
                } else if self.isDismissingInteractively || (translation.y > 0.0 && isAtTop && currentSheetOffset <= 0.5) {
                    self.pinTrackedScrollViewToTop(trackedScrollView)
                }
            case .ended, .cancelled, .failed:
                self.trackedScrollViewWasAtTopOnGestureBegan = false
                if !self.isSheetFullyExpanded(itemLayout: itemLayout) || self.isDismissingInteractively {
                    self.pinTrackedScrollViewToTop(trackedScrollView)
                }
            default:
                break
            }
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout, let component = self.component, let environment = self.environment else {
                return
            }
            if component.isFullscreen || !component.allowsExpansion || itemLayout.isCentered {
                self.ignoreScrolling = true
                transition.setBounds(view: self.scrollView, bounds: CGRect(origin: .zero, size: self.scrollView.bounds.size))
                self.ignoreScrolling = false
                self.scrollView.isScrollEnabled = false
            } else {
                self.scrollView.isScrollEnabled = !self.isDismissingInteractively
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))

            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))

            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))

            if component.isFullscreen || itemLayout.isCentered || environment.inputHeight > 0.0 {
                topOffsetFraction = 1.0
            }
            
//            #if DEBUG && true
//            if "".isEmpty {
//                topOffsetFraction = 1.0
//            }
//            #endif

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

            var bounds = self.scrollView.bounds
            bounds.size.width = itemLayout.fillingSize
            self.environment?.boundsUpdated.invoke(ResizableSheetComponentEnvironment.BoundsUpdate(bounds: bounds, isInteractive: self.scrollView.isTracking))
            self.updateTrackedScrollViewLock()
        }

        private var didPlayAppearanceAnimation = false
        func animateIn() {
            self.didPlayAppearanceAnimation = true

            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.containerView.convert(self.backgroundLayer.frame, to: self).minY
            self.containerView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }

        public func animateOut(initialVelocity: CGFloat? = nil, completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.containerView.convert(self.backgroundLayer.frame, to: self).minY

            self.dimView.layer.animateAlpha(from: self.dimView.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false)
            if let initialVelocity = initialVelocity {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.35, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                transition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.layer.position.x, y: self.containerView.layer.position.y + animateOffset), completion: { _ in
                    completion()
                })
            } else {
                let duration: Double = 0.25
                self.containerView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                    completion()
                })
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
                self.endEditing(true)
                self.animateOut {
                    completion(Void())
                }
            }

            let screenSize = availableSize
            let isCentered = component.centeredSize != nil
            let layoutSize: CGSize
            if let centeredSize = component.centeredSize {
                layoutSize = CGSize(width: min(screenSize.width, centeredSize.width), height: min(screenSize.height, centeredSize.height))
            } else {
                layoutSize = screenSize
            }

            let resetScrolling = self.scrollView.bounds.width != layoutSize.width

            let fillingSize: CGFloat
            if isCentered {
                fillingSize = layoutSize.width
            } else if case .regular = sheetEnvironment.metrics.widthClass {
                fillingSize = min(layoutSize.width, 414.0) - sheetEnvironment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, availableSize.height) - sheetEnvironment.safeInsets.left * 2.0
            }
            let rawSideInset: CGFloat = floor((layoutSize.width - fillingSize) * 0.5)

            self.component = component
            self.state = state
            self.environment = sheetEnvironment

            if self.registeredExternalState !== component.externalState {
                self.registeredExternalState?.trackedScrollViewUpdated = nil
                self.registeredExternalState = component.externalState
                if let externalState = component.externalState {
                    externalState.trackedScrollViewUpdated = { [weak self] scrollView in
                        self?.setTrackedScrollView(scrollView)
                    }
                } else {
                    self.setTrackedScrollView(nil)
                }
            }

            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)

            let backgroundColor: UIColor
            switch component.backgroundColor {
            case let .color(color):
                backgroundColor = color
                self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            }

            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: screenSize))

            let containerSize = CGSize(width: fillingSize, height: isCentered ? layoutSize.height : .greatestFiniteMagnitude)

            var containerInset: CGFloat = sheetEnvironment.statusBarHeight + 10.0
            if component.isFullscreen || isCentered {
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
                contentView.clipsToBounds = component.clipsContent
                contentView.layer.cornerRadius = 40.0
                
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: contentViewSize))
            }

            let contentHeight = contentViewSize.height
            let initialContentHeight: CGFloat
            if component.isFullscreen || isCentered || sheetEnvironment.inputHeight > 0.0 {
                initialContentHeight = contentHeight
            } else if let defaultHeight = component.defaultHeight {
                initialContentHeight = min(contentHeight, max(0.0, defaultHeight))
            } else {
                initialContentHeight = contentHeight
            }

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
                    containerSize: CGSize(width: containerSize.width - 72.0 * 2.0, height: 66.0)
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
                let rightItemFrame = CGRect(origin: CGPoint(x: layoutSize.width - rawSideInset - 16.0 - rightItemSize.width, y: 16.0), size: rightItemSize)
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

            var bottomInsets = ContainerViewLayout.concentricInsets(bottomInset: isCentered ? 0.0 : sheetEnvironment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            if sheetEnvironment.inputHeight > 0.0 {
                bottomInsets.left = 16.0
                bottomInsets.right = 16.0
                bottomInsets.bottom = sheetEnvironment.inputHeight + 8.0
            }

            var bottomEdgeEffectHeight = edgeEffectHeight
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

                let bottomItemSize = bottomItemView.update(
                    transition: bottomItemTransition,
                    component: bottomItem,
                    environment: {},
                    containerSize: CGSize(width: containerSize.width - bottomInsets.left - bottomInsets.right, height: 52.0)
                )
                let bottomItemFrame = CGRect(origin: CGPoint(x: rawSideInset + floorToScreenPixels((containerSize.width - bottomItemSize.width)) / 2.0, y: layoutSize.height - bottomItemSize.height - bottomInsets.bottom), size: bottomItemSize)
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
                bottomEdgeEffectHeight = bottomItemSize.height + 36.0
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

            let bottomEdgeEffectExtension = max(0.0, component.bottomEdgeEffectExtension)
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: layoutSize.height - bottomInsets.bottom - bottomEdgeEffectHeight - bottomEdgeEffectExtension), size: CGSize(width: fillingSize, height: bottomEdgeEffectHeight + bottomInsets.bottom))
            transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            transition.setCornerRadius(layer: self.bottomEdgeEffectView.layer, cornerRadius: bottomEdgeEffectExtension > 0.0 ? 0.0 : 40.0)
            self.bottomEdgeEffectView.update(content: backgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectHeight, transition: transition)
            if self.bottomEdgeEffectView.superview == nil {
                self.bottomContainer.insertSubview(self.bottomEdgeEffectView, at: 0)
            }

            let bottomEdgeEffectFillFrame = CGRect(origin: CGPoint(x: rawSideInset, y: bottomEdgeEffectFrame.maxY), size: CGSize(width: fillingSize, height: bottomEdgeEffectExtension))
            transition.setFrame(view: self.bottomEdgeEffectFillView, frame: bottomEdgeEffectFillFrame)
            transition.setBackgroundColor(view: self.bottomEdgeEffectFillView, color: backgroundColor)
            if self.bottomEdgeEffectFillView.superview == nil {
                self.bottomContainer.insertSubview(self.bottomEdgeEffectFillView, at: 0)
            }
            transition.setAlpha(view: self.bottomContainer, alpha: component.bottomItem != nil ? 1.0 : 0.0)


            clippingY = layoutSize.height
            
            var topInset: CGFloat = max(0.0, layoutSize.height - containerInset - initialContentHeight - sheetEnvironment.inputHeight)
            if component.isFullscreen || isCentered {
                topInset = 0.0
            }
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset + sheetEnvironment.inputHeight, layoutSize.height - containerInset)

            self.scrollContentClippingView.layer.cornerRadius = 40.0

            let containerCornerRadius: CGFloat = isCentered ? 40.0 : max(22.0, sheetEnvironment.deviceMetrics.screenCornerRadius)
            self.containerView.layer.maskedCorners = isCentered ? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner] : [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.itemLayout = ItemLayout(containerSize: layoutSize, containerInset: containerInset, containerCornerRadius: containerCornerRadius, bottomInset: sheetEnvironment.safeInsets.bottom, topInset: topInset, fillingSize: fillingSize, isTablet: sheetEnvironment.metrics.isTablet, isCentered: isCentered)

            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: layoutSize.width, height: contentHeight)))

            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: layoutSize.width / 2.0, y: layoutSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: fillingSize, height: layoutSize.height)))

            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: layoutSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))

            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layoutSize.width, height: layoutSize.height)))
            let contentSize = CGSize(width: layoutSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layoutSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)

            transition.setPosition(view: self.containerView, position: CGRect(origin: CGPoint(), size: screenSize).center)
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: layoutSize))

            if sheetEnvironment.isDisplaying && !self.didPlayAppearanceAnimation {
                self.animateIn()
            }

            return screenSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
