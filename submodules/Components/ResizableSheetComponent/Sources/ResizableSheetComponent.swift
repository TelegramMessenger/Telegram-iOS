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
        public let contentBounds: CGRect
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

    public static func bottomItemSideInset(inputHeight: CGFloat) -> CGFloat {
        return inputHeight > 0.0 ? 16.0 : 30.0
    }

    public let content: AnyComponent<ChildEnvironmentType>
    public let titleItem: AnyComponent<Empty>?
    public let leftItem: AnyComponent<Empty>?
    public let rightItem: AnyComponent<Empty>?
    public let hasTopEdgeEffect: Bool
    public let hasBottomEdgeEffect: Bool
    public let bottomEdgeEffectColor: UIColor?
    public let bottomItem: AnyComponent<Empty>?
    public let bottomEdgeEffectExtension: CGFloat
    public let backgroundColor: BackgroundColor
    public let delaysContentTouches: Bool
    public let clipsContent: Bool
    public let isFullscreen: Bool
    /// Fills an external presentation host without sheet insets, dismissal gestures or presentation animations.
    /// Content remains scrollable; the host owns presentation and dismissal.
    public let isEmbedded: Bool
    public let allowsExpansion: Bool
    public let locksExpansion: Bool
    public let slidesOutBottomItem: Bool
    public let animatesAppearance: Bool
    public let scrollsContentWhenCentered: Bool
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
        hasBottomEdgeEffect: Bool = true,
        bottomEdgeEffectColor: UIColor? = nil,
        bottomItem: AnyComponent<Empty>? = nil,
        bottomEdgeEffectExtension: CGFloat = 0.0,
        backgroundColor: BackgroundColor,
        clipsContent: Bool = false,
        delaysContentTouches: Bool = true,
        isFullscreen: Bool = false,
        isEmbedded: Bool = false,
        allowsExpansion: Bool = true,
        locksExpansion: Bool = false,
        slidesOutBottomItem: Bool = false,
        animatesAppearance: Bool = true,
        scrollsContentWhenCentered: Bool = false,
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
        self.hasBottomEdgeEffect = hasBottomEdgeEffect
        self.bottomEdgeEffectColor = bottomEdgeEffectColor
        self.bottomItem = bottomItem
        self.bottomEdgeEffectExtension = bottomEdgeEffectExtension
        self.backgroundColor = backgroundColor
        self.clipsContent = clipsContent
        self.delaysContentTouches = delaysContentTouches
        self.isFullscreen = isFullscreen
        self.isEmbedded = isEmbedded
        self.allowsExpansion = allowsExpansion
        self.locksExpansion = locksExpansion
        self.slidesOutBottomItem = slidesOutBottomItem
        self.animatesAppearance = animatesAppearance
        self.scrollsContentWhenCentered = scrollsContentWhenCentered
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
        if lhs.hasBottomEdgeEffect != rhs.hasBottomEdgeEffect {
            return false
        }
        if lhs.bottomEdgeEffectColor != rhs.bottomEdgeEffectColor {
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
        if lhs.delaysContentTouches != rhs.delaysContentTouches {
            return false
        }
        if lhs.clipsContent != rhs.clipsContent {
            return false
        }
        if lhs.isFullscreen != rhs.isFullscreen {
            return false
        }
        if lhs.isEmbedded != rhs.isEmbedded {
            return false
        }
        if lhs.allowsExpansion != rhs.allowsExpansion || lhs.locksExpansion != rhs.locksExpansion || lhs.slidesOutBottomItem != rhs.slidesOutBottomItem || lhs.animatesAppearance != rhs.animatesAppearance || lhs.scrollsContentWhenCentered != rhs.scrollsContentWhenCentered || lhs.centeredSize != rhs.centeredSize {
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
        /// The container's bottom corners where they differ (iPhone Duo's cover screen, each its own screen corner);
        /// nil elsewhere, where `containerCornerRadius` rounds both.
        var containerBottomCornerRadii: CornerRadii?
        var bottomInset: CGFloat
        var topInset: CGFloat
        var fillingSize: CGFloat
        let isTablet: Bool
        let isCentered: Bool

        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, containerBottomCornerRadii: CornerRadii? = nil, bottomInset: CGFloat, topInset: CGFloat, fillingSize: CGFloat, isTablet: Bool, isCentered: Bool) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.containerBottomCornerRadii = containerBottomCornerRadii
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.fillingSize = fillingSize
            self.isTablet = isTablet
            self.isCentered = isCentered
        }
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            if !self.delaysContentTouches {
                return true
            }
            return super.touchesShouldCancel(in: view)
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === self.panGestureRecognizer {
                let velocity = self.panGestureRecognizer.velocity(in: self)
                if abs(velocity.x) > abs(velocity.y) {
                    return false
                }
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
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
        /// Beside iPhone Duo's status island (unfolded portrait): the header's title and right item as laid out at the
        /// sheet's edge, and the island they slide clear of as the sheet's top rises beside it (see `updateScrolling`).
        private var headerIslandLayout: HeaderIslandLayout?
        private var headerIslandShift: CGFloat = 0.0

        private struct HeaderIslandLayout {
            var islandHeight: CGFloat
            var inset: CGFloat
            var titleMinX: CGFloat
            var titleMaxX: CGFloat
            var titleFrame: CGRect?
            var rightItemFrame: CGRect?

            /// The title and right item moved `shift` clear of the island: the right item by all of it, the title only as far
            /// as it needs to stay left of the right item, while it stays centered where it fits.
            func frames(shift: CGFloat) -> (title: CGRect?, rightItem: CGRect?) {
                let titleFrame = self.titleFrame.map { frame -> CGRect in
                    var x = min(frame.minX, self.titleMaxX - shift - frame.width)
                    x = max(x, self.titleMinX)
                    return CGRect(origin: CGPoint(x: x, y: frame.minY), size: frame.size)
                }
                return (titleFrame, self.rightItemFrame?.offsetBy(dx: -shift, dy: 0.0))
            }

            /// The header row the island shift is measured against (in the navigation bar container's coordinates).
            var rowFrame: CGRect {
                if let rightItemFrame = self.rightItemFrame {
                    return rightItemFrame
                }
                return self.titleFrame ?? CGRect(x: 0.0, y: 16.0, width: 0.0, height: 44.0)
            }
        }

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
        private var containerUsesCornerRadii = false
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

        public var contentScrollOffset: CGFloat {
            return self.scrollView.bounds.minY - (self.itemLayout?.topInset ?? 0.0)
        }

        public func setContentScrollOffset(_ offset: CGFloat, transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout else { return }
            let maximum = max(0.0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
            let y = min(maximum, max(0.0, itemLayout.topInset + offset))
            self.ignoreScrolling = true
            transition.setBoundsOrigin(view: self.scrollView, origin: CGPoint(x: 0.0, y: y))
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
                if self.itemLayout?.isCentered == true || self.component?.isEmbedded == true {
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

        private func updateExpansionLock() {
            guard let itemLayout = self.itemLayout, let component = self.component else {
                return
            }
            var topContentInset: CGFloat = 0.0
            if component.locksExpansion && !itemLayout.isCentered && !component.isFullscreen {
                if self.scrollView.contentInset.top < 0.0 || self.scrollView.bounds.minY >= itemLayout.topInset - 0.5 {
                    topContentInset = -itemLayout.topInset
                }
            }
            if self.scrollView.contentInset.top != topContentInset {
                self.ignoreScrolling = true
                self.scrollView.contentInset.top = topContentInset
                self.ignoreScrolling = false
            }
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout, let component = self.component, let environment = self.environment else {
                return
            }
            self.updateExpansionLock()
            let scrollsCenteredContent = itemLayout.isCentered && component.scrollsContentWhenCentered
            if component.isFullscreen || !component.allowsExpansion || (itemLayout.isCentered && !scrollsCenteredContent) {
                self.ignoreScrolling = true
                transition.setBounds(view: self.scrollView, bounds: CGRect(origin: .zero, size: self.scrollView.bounds.size))
                self.ignoreScrolling = false
                self.scrollView.isScrollEnabled = false
            } else {
                self.scrollView.isScrollEnabled = !self.isDismissingInteractively
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = component.isEmbedded || scrollsCenteredContent ? 0.0 : max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))

            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            if let islandLayout = self.headerIslandLayout {
                // Slides clear of the status island as the sheet's top rises beside it.
                let rowFrame = islandLayout.rowFrame
                let shift = statusIslandTrailingShift(rowMinY: topOffset + itemLayout.containerInset + rowFrame.minY, rowHeight: rowFrame.height, islandHeight: islandLayout.islandHeight, inset: islandLayout.inset)
                self.headerIslandShift = shift
                let frames = islandLayout.frames(shift: shift)
                if let titleFrame = frames.title, let view = self.titleItemView?.view {
                    transition.setPosition(view: view, position: titleFrame.center)
                }
                if let rightItemFrame = frames.rightItem, let view = self.rightItemView?.view {
                    transition.setPosition(view: view, position: rightItemFrame.center)
                }
            }

            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))

            if component.isFullscreen || component.isEmbedded || itemLayout.isCentered || environment.inputHeight > 0.0 {
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
            if let bottomCornerRadii = itemLayout.containerBottomCornerRadii, CALayer.cornerRadiiSupported {
                self.containerUsesCornerRadii = true
                self.containerView.layer.setCornerRadii(bottomCornerRadii)
            } else {
                let cornerRadius = itemLayout.containerBottomCornerRadii.map { max($0.bottomLeft, $0.bottomRight) } ?? scaledCornerRadius
                if self.containerUsesCornerRadii {
                    self.containerUsesCornerRadii = false
                    self.containerView.layer.setCornerRadii(CornerRadii(uniform: cornerRadius))
                }
                transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: cornerRadius)
            }

            var bounds = self.scrollView.bounds
            bounds.size.width = itemLayout.fillingSize
            self.environment?.boundsUpdated.invoke(ResizableSheetComponentEnvironment.BoundsUpdate(bounds: bounds, contentBounds: CGRect(x: 0.0, y: bounds.minY - itemLayout.topInset, width: itemLayout.fillingSize, height: bounds.height - itemLayout.containerInset), isInteractive: self.scrollView.isTracking))
            self.updateTrackedScrollViewLock()
        }

        private var didPlayAppearanceAnimation = false
        func animateIn() {
            self.didPlayAppearanceAnimation = true
            guard self.component?.isEmbedded != true else { return }

            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.containerView.convert(self.backgroundLayer.frame, to: self).minY
            self.containerView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }

        public func animateOut(initialVelocity: CGFloat? = nil, completion: @escaping () -> Void) {
            if self.component?.isEmbedded == true {
                completion()
                return
            }
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
            self.scrollView.delaysContentTouches = component.delaysContentTouches
            self.dismissPanGesture?.isEnabled = !component.isEmbedded
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
            // iPhone Duo's cover screen: the bottom corners of the container (each its own screen corner, see below);
            // the clips inside it keep their bottom corners within those. Nil where the screen's corners are uniform.
            var screenBottomCornerRadii: (left: CGFloat, right: CGFloat)?
            if !isCentered, let controllerEnvironment = environment[ChildEnvironmentType.self].value as? ViewControllerComponentContainer.Environment {
                screenBottomCornerRadii = controllerEnvironment.screenCornerRadii.sheetBottomCornerRadii(inset: 0.0)
            }
            func clipCornerRadii(_ radius: CGFloat) -> CornerRadii? {
                return screenBottomCornerRadii.map { CornerRadii(topLeft: radius, topRight: radius, bottomLeft: min(radius, $0.left), bottomRight: min(radius, $0.right)) }
            }
            let layoutSize: CGSize
            if let centeredSize = component.centeredSize {
                layoutSize = CGSize(width: min(screenSize.width, centeredSize.width), height: min(screenSize.height, centeredSize.height))
            } else {
                layoutSize = screenSize
            }

            let resetScrolling = self.scrollView.bounds.width != layoutSize.width

            let fillingSize: CGFloat
            // The sheet's distance from each side of the screen. Equal (the sheet centered on the screen) unless
            // it keeps to the band beside iPhone Duo's side strip.
            let rawSideInset: CGFloat
            let rawRightSideInset: CGFloat
            // The content's environment, with side insets relative to the sheet rather than the screen: in the
            // band the sheet is clear of the strip, so its content has no strip to avoid.
            let contentEnvironment: ChildEnvironmentType
            if isCentered || component.isEmbedded {
                fillingSize = layoutSize.width
                rawSideInset = 0.0
                rawRightSideInset = 0.0
                contentEnvironment = environment[ChildEnvironmentType.self].value
            } else {
                var maxWidth: CGFloat?
                if case .regular = sheetEnvironment.metrics.widthClass {
                    maxWidth = 414.0
                }
                let placement = resizableSheetHorizontalPlacement(containerSize: layoutSize, safeInsets: sheetEnvironment.safeInsets, maxWidth: maxWidth)
                fillingSize = placement.width
                rawSideInset = placement.minX
                if sheetEnvironment.safeInsets.left != sheetEnvironment.safeInsets.right {
                    rawRightSideInset = layoutSize.width - placement.minX - placement.width
                    if let controllerEnvironment = environment[ChildEnvironmentType.self].value as? ViewControllerComponentContainer.Environment, let adjusted = controllerEnvironment.withSideSafeInsets(left: placement.contentSideInsets.left, right: placement.contentSideInsets.right) as? ChildEnvironmentType {
                        contentEnvironment = adjusted
                    } else {
                        contentEnvironment = environment[ChildEnvironmentType.self].value
                    }
                } else {
                    rawRightSideInset = rawSideInset
                    contentEnvironment = environment[ChildEnvironmentType.self].value
                }
            }
            // The background is centered on the screen unless the sheet keeps to a band.
            let backgroundCenterX: CGFloat = rawSideInset == rawRightSideInset ? layoutSize.width / 2.0 : rawSideInset + fillingSize / 2.0

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

            self.dimView.backgroundColor = component.isEmbedded ? .clear : UIColor(white: 0.0, alpha: 0.4)

            let backgroundColor: UIColor
            switch component.backgroundColor {
            case let .color(color):
                backgroundColor = color
                self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            }

            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: screenSize))

            let containerSize = CGSize(width: fillingSize, height: isCentered ? layoutSize.height : .greatestFiniteMagnitude)

            var containerInset: CGFloat = sheetEnvironment.statusBarHeight + 10.0
            if component.isFullscreen || component.isEmbedded || isCentered {
                containerInset = 0.0
            }
            let clippingY: CGFloat

            self.contentView.parentState = state
            let contentViewSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    contentEnvironment
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
                let _ = contentView.layer.applyCornerRadiiIfNeeded(clipCornerRadii(40.0))
                
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

            // A tall sheet's header can rise under a top corner block (iPhone Duo's status corner, folded
            // portrait), so its controls keep clear of it; a short sheet's header never reaches it.
            var headerCornerInsets = UIEdgeInsets()
            if !isCentered, let controllerEnvironment = environment[ChildEnvironmentType.self].value as? ViewControllerComponentContainer.Environment {
                let sheetMinY = component.isFullscreen ? 0.0 : containerInset + max(0.0, layoutSize.height - containerInset - contentHeight - sheetEnvironment.inputHeight)
                headerCornerInsets = sheetHeaderCornerInsets(containerWidth: layoutSize.width, sheetMinX: rawSideInset, sheetWidth: fillingSize, sheetMinY: sheetMinY, reservedCorners: controllerEnvironment.reservedCorners)
            }
            // Beside a status island (iPhone Duo, unfolded portrait) the sheet can be low, with nothing to avoid, or risen
            // beside the island: the right item and the title are laid out at the edge and slide clear of the island by the
            // sheet's current top in `updateScrolling` (the title is measured to fit the risen row).
            var islandHeaderInset: CGFloat = 0.0
            var islandHeight: CGFloat = 0.0
            if !isCentered, !component.isFullscreen, let controllerEnvironment = environment[ChildEnvironmentType.self].value as? ViewControllerComponentContainer.Environment, controllerEnvironment.navigationBarTrailingButtonsInset > 0.0, let island = controllerEnvironment.reservedCorners.topRight, headerCornerInsets.right > 0.0 {
                islandHeaderInset = headerCornerInsets.right
                islandHeight = island.height
            }
            var islandHeaderLayout: HeaderIslandLayout?
            if islandHeaderInset > 0.0 {
                islandHeaderLayout = HeaderIslandLayout(
                    islandHeight: islandHeight,
                    inset: islandHeaderInset,
                    titleMinX: rawSideInset + headerCornerInsets.left + 72.0,
                    titleMaxX: layoutSize.width - rawRightSideInset - (headerCornerInsets.right - islandHeaderInset) - 72.0,
                    titleFrame: nil,
                    rightItemFrame: nil
                )
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
                var titleItemTransition = transition
                let titleItemView: ComponentView<Empty>
                if let current = self.titleItemView {
                    titleItemView = current
                } else {
                    titleItemTransition = .immediate
                    titleItemView = ComponentView<Empty>()
                    self.titleItemView = titleItemView
                }

                let titleItemSize = titleItemView.update(
                    transition: titleItemTransition,
                    component: titleItem,
                    environment: {},
                    containerSize: CGSize(width: containerSize.width - 72.0 * 2.0 - headerCornerInsets.left - headerCornerInsets.right, height: 66.0)
                )
                let titleCenteringRightInset = headerCornerInsets.right - islandHeaderInset
                var titleItemFrame = CGRect(origin: CGPoint(x: rawSideInset + headerCornerInsets.left + floorToScreenPixels((containerSize.width - headerCornerInsets.left - titleCenteringRightInset - titleItemSize.width)) / 2.0, y: floorToScreenPixels(38.0 - titleItemSize.height * 0.5)), size: titleItemSize)
                if islandHeaderLayout != nil {
                    islandHeaderLayout?.titleFrame = titleItemFrame
                    if let shifted = islandHeaderLayout?.frames(shift: self.headerIslandShift).title {
                        titleItemFrame = shifted
                    }
                }
                if let view = titleItemView.view {
                    if view.superview == nil {
                        self.navigationBarContainer.addSubview(view)
                    }
                    titleItemTransition.setFrame(view: view, frame: titleItemFrame)
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
                let leftItemFrame = CGRect(origin: CGPoint(x: rawSideInset + 16.0 + headerCornerInsets.left, y: 16.0), size: leftItemSize)
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
                var rightItemFrame = CGRect(origin: CGPoint(x: layoutSize.width - rawRightSideInset - 16.0 - (headerCornerInsets.right - islandHeaderInset) - rightItemSize.width, y: 16.0), size: rightItemSize)
                if islandHeaderLayout != nil {
                    islandHeaderLayout?.rightItemFrame = rightItemFrame
                    if let shifted = islandHeaderLayout?.frames(shift: self.headerIslandShift).rightItem {
                        rightItemFrame = shifted
                    }
                }
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

            self.headerIslandLayout = islandHeaderLayout
            if islandHeaderLayout == nil {
                self.headerIslandShift = 0.0
            }

            var bottomInsets = ContainerViewLayout.concentricInsets(bottomInset: isCentered ? 0.0 : sheetEnvironment.safeInsets.bottom, innerDiameter: 52.0, sideInset: ResizableSheetComponent.bottomItemSideInset(inputHeight: 0.0))
            if sheetEnvironment.inputHeight > 0.0 {
                let sideInset = ResizableSheetComponent.bottomItemSideInset(inputHeight: sheetEnvironment.inputHeight)
                bottomInsets.left = sideInset
                bottomInsets.right = sideInset
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

                bottomItemView.parentState = state
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
                if case let .curve(duration, curve) = transition.animation, component.slidesOutBottomItem, let view = bottomItemView.view {
                    let offset = layoutSize.height - view.frame.minY
                    view.layer.animate(from: CGPoint.zero as NSValue, to: CGPoint(x: 0.0, y: offset) as NSValue, keyPath: "position", duration: duration, delay: 0.0, curve: curve, removeOnCompletion: false, additive: true, completion: { _ in
                        view.removeFromSuperview()
                    })
                } else if !transition.animation.isImmediate {
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
            if !self.bottomEdgeEffectView.layer.applyCornerRadiiIfNeeded(bottomEdgeEffectExtension > 0.0 ? nil : clipCornerRadii(40.0).map { CornerRadii(topLeft: 0.0, topRight: 0.0, bottomLeft: $0.bottomLeft, bottomRight: $0.bottomRight) }) {
                transition.setCornerRadius(layer: self.bottomEdgeEffectView.layer, cornerRadius: bottomEdgeEffectExtension > 0.0 ? 0.0 : 40.0)
            }
            self.bottomEdgeEffectView.update(content: component.bottomEdgeEffectColor ?? backgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectHeight, transition: transition)
            if self.bottomEdgeEffectView.superview == nil {
                self.bottomContainer.insertSubview(self.bottomEdgeEffectView, at: 0)
            }

            transition.setAlpha(view: self.bottomEdgeEffectView, alpha: component.hasBottomEdgeEffect ? 1.0 : 0.0)

            let bottomEdgeEffectFillFrame = CGRect(origin: CGPoint(x: rawSideInset, y: bottomEdgeEffectFrame.maxY), size: CGSize(width: fillingSize, height: bottomEdgeEffectExtension))
            transition.setFrame(view: self.bottomEdgeEffectFillView, frame: bottomEdgeEffectFillFrame)
            transition.setBackgroundColor(view: self.bottomEdgeEffectFillView, color: component.bottomEdgeEffectColor ?? backgroundColor)
            if self.bottomEdgeEffectFillView.superview == nil {
                self.bottomContainer.insertSubview(self.bottomEdgeEffectFillView, at: 0)
            }
            transition.setAlpha(view: self.bottomEdgeEffectFillView, alpha: component.hasBottomEdgeEffect ? 1.0 : 0.0)
            transition.setAlpha(view: self.bottomContainer, alpha: component.bottomItem != nil ? 1.0 : 0.0)


            clippingY = layoutSize.height
            
            var topInset: CGFloat = max(0.0, layoutSize.height - containerInset - initialContentHeight - sheetEnvironment.inputHeight)
            if component.isFullscreen || component.isEmbedded || isCentered {
                topInset = 0.0
            }
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset + sheetEnvironment.inputHeight, layoutSize.height - containerInset)

            self.scrollContentClippingView.layer.cornerRadius = 40.0
            let _ = self.scrollContentClippingView.layer.applyCornerRadiiIfNeeded(clipCornerRadii(40.0))

            let containerCornerRadius: CGFloat = isCentered ? 40.0 : max(22.0, sheetEnvironment.deviceMetrics.screenCornerRadius)
            // iPhone Duo's cover screen: the container's bottom corners, which reach the screen's, follow each screen
            // corner (8pt on the hinge side, 59pt outside) instead of one radius. Nil where the corners are uniform.
            let containerBottomCornerRadii: CornerRadii? = screenBottomCornerRadii.map { CornerRadii(topLeft: 0.0, topRight: 0.0, bottomLeft: $0.left, bottomRight: $0.right) }
            self.containerView.layer.maskedCorners = isCentered ? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner] : [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.itemLayout = ItemLayout(containerSize: layoutSize, containerInset: containerInset, containerCornerRadius: containerCornerRadius, containerBottomCornerRadii: containerBottomCornerRadii, bottomInset: sheetEnvironment.safeInsets.bottom, topInset: topInset, fillingSize: fillingSize, isTablet: sheetEnvironment.metrics.isTablet, isCentered: isCentered)

            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: layoutSize.width, height: contentHeight)))

            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: backgroundCenterX, y: layoutSize.height / 2.0))
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
                if component.animatesAppearance {
                    self.animateIn()
                } else {
                    self.didPlayAppearanceAnimation = true
                }
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
