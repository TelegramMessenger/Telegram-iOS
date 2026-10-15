import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import SideColumnLayout

/// The navigation bar's 44pt row and iPhone Duo side column: title, back, left and right buttons in glass
/// capsules, and the in-bar slide between a primary and a secondary content. Hosts own the backdrop, where the
/// row sits, and the container the column hangs in (`sideColumnView`).
public final class NavigationBarComponent: Component {
    public let theme: NavigationBarTheme
    public let strings: NavigationBarStrings
    public let leftInset: CGFloat
    public let rightInset: CGFloat
    /// iPhone Duo: how much further than `rightInset` the right buttons stay from the right edge, to clear the
    /// status island beside the bar (`ContainerViewLayout.navigationBarTrailingButtonsInset`). The title keeps
    /// centering on the bar.
    public let trailingButtonsInset: CGFloat
    public let primaryContent: Content?
    public let secondaryContent: Content?
    /// 0 shows the primary content, 1 the secondary; in between the two slide (the chat list's inline forum).
    public let secondaryTransition: CGFloat
    /// iPhone Duo: the side column's length (`SideColumnRegion.frame.height`); nil lays every button out in the row.
    public let sideColumnLength: CGFloat?
    /// iPhone Duo: hides the column's capsule and trailing circle, keeping its back button (an active search
    /// replaces the row, and the row's buttons go with it).
    public let hidesSideColumnButtons: Bool
    public let openSideColumnOverflow: ((UIView, [OverflowItem]) -> Void)?

    public init(
        theme: NavigationBarTheme,
        strings: NavigationBarStrings,
        leftInset: CGFloat,
        rightInset: CGFloat,
        trailingButtonsInset: CGFloat = 0.0,
        primaryContent: Content?,
        secondaryContent: Content?,
        secondaryTransition: CGFloat,
        sideColumnLength: CGFloat? = nil,
        hidesSideColumnButtons: Bool = false,
        openSideColumnOverflow: ((UIView, [OverflowItem]) -> Void)? = nil
    ) {
        self.theme = theme
        self.strings = strings
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.trailingButtonsInset = trailingButtonsInset
        self.primaryContent = primaryContent
        self.secondaryContent = secondaryContent
        self.secondaryTransition = secondaryTransition
        self.sideColumnLength = sideColumnLength
        self.hidesSideColumnButtons = hidesSideColumnButtons
        self.openSideColumnOverflow = openSideColumnOverflow
    }

    public static func ==(lhs: NavigationBarComponent, rhs: NavigationBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.leftInset != rhs.leftInset {
            return false
        }
        if lhs.rightInset != rhs.rightInset {
            return false
        }
        if lhs.trailingButtonsInset != rhs.trailingButtonsInset {
            return false
        }
        if lhs.primaryContent != rhs.primaryContent {
            return false
        }
        if lhs.secondaryContent != rhs.secondaryContent {
            return false
        }
        if lhs.secondaryTransition != rhs.secondaryTransition {
            return false
        }
        if lhs.sideColumnLength != rhs.sideColumnLength {
            return false
        }
        if lhs.hidesSideColumnButtons != rhs.hidesSideColumnButtons {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: NavigationBarComponent?

        private(set) var primaryContentView: NavigationBarContentView?
        private(set) var secondaryContentView: NavigationBarContentView?

        let leftButtonsContainer: UIView
        let rightButtonsContainer: UIView
        private(set) var leftButtonsBackgroundContainer: GlassContextExtractableContainer?
        private(set) var rightButtonsBackgroundContainer: GlassContextExtractableContainer?
        /// The accent circle outermost on the right (`NavigationBarButtonPlacement.rowCircleItem`) and its glass.
        let rightCircleContainer: UIView
        private(set) var rightCircleBackgroundContainer: GlassContextExtractableContainer?
        /// The tint the last layout gave the circle's glass.
        private(set) var appliedRightCircleTint: NavigationBarComponent.Button.Tint = .generic
        /// Capsules animating an in-place change of their items, as iOS 27's glass does (see `startInPlace…`).
        var inPlaceCapsules: [NavigationBarInPlaceCapsule] = []
        var inPlaceLink: SharedDisplayLinkDriver.Link?
        var inPlaceLastTime: Double?
        /// The animation duration factor (Slow Animations): the in-place springs run this many times slower.
        public var inPlaceDurationFactor: () -> Double = {
            return UIView.animationDurationFactor()
        }
        /// Reduce Motion, read as each in-place change starts.
        public var inPlaceReduceMotion: () -> Bool = {
            return UIAccessibility.isReduceMotionEnabled
        }

        /// While a navigation transition draws this bar's glass above both screens: the capsules are out of the
        /// hierarchy (alpha does not hide native glass) and the title stays where it is.
        public var plattersDetached: Bool = false {
            didSet {
                if self.plattersDetached != oldValue {
                    if self.plattersDetached {
                        // The transition draws the capsules from the bar's layout: settle them there first. A press
                        // UIKit is drawing on one (the button that started the transition) goes on in the transition.
                        self.finishInPlaceAnimations()
                        let now = self.pressSamplerClock()
                        var pressScales = (
                            left: self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0,
                            right: self.rightOuterBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0,
                            rightInner: self.rightInnerBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
                        )
                        // A press UIKit has already taken off (the touch just ended) is in the last sample.
                        if let sample = self.lastPressSample, now - sample.time < 0.1 {
                            if abs(pressScales.left - 1.0) < 0.0005 {
                                pressScales.left = sample.left
                            }
                            if abs(pressScales.right - 1.0) < 0.0005 {
                                pressScales.right = sample.right
                            }
                            if abs(pressScales.rightInner - 1.0) < 0.0005 {
                                pressScales.rightInner = sample.rightInner
                            }
                        }
                        self.lastPressSample = nil
                        self.detachedPressScales = pressScales
                        // A glow is always there with a press: when the glow layer cannot be found (a UIKit change), a
                        // press alone stands for a full one. A press passes 1.03 within ~20 ms, so 1.01 tells it from a
                        // reading that is merely not exactly 1.
                        func glow(_ container: GlassContextExtractableContainer?, press: CGFloat) -> CGFloat {
                            if let container, let glow = navigationBarCapsulePressGlow(container) {
                                return glow
                            }
                            return press > 1.01 ? 1.0 : 0.0
                        }
                        self.detachedPressGlows = (
                            left: glow(self.leftButtonsBackgroundContainer, press: self.detachedPressScales.left),
                            right: glow(self.rightOuterBackgroundContainer, press: self.detachedPressScales.right),
                            rightInner: glow(self.rightInnerBackgroundContainer, press: self.detachedPressScales.rightInner)
                        )
                    } else {
                        self.detachedPressScales = (1.0, 1.0, 1.0)
                        self.detachedPressGlows = (0.0, 0.0, 0.0)
                    }
                    self.applyPlattersDetached()
                }
            }
        }

        private var detachedPressScales: (left: CGFloat, right: CGFloat, rightInner: CGFloat) = (1.0, 1.0, 1.0)

        /// The outermost right platter (the accent circle when there is one) and the capsule beside it.
        private var rightOuterBackgroundContainer: GlassContextExtractableContainer? {
            return self.rightCircleBackgroundContainer ?? self.rightButtonsBackgroundContainer
        }
        private var rightInnerBackgroundContainer: GlassContextExtractableContainer? {
            return self.rightCircleBackgroundContainer != nil ? self.rightButtonsBackgroundContainer : nil
        }

        /// UIKit draws a capsule's press (on a short tap) only as a running animation on its glass, which it takes off
        /// when the touch ends, before the button's action runs (measured 2026-10-14): when that action starts a
        /// transition there is nothing left to read. So while a touch is in a capsule the press is sampled every frame,
        /// and detaching takes the last pressed sample.
        private var pressSamplerLink: SharedDisplayLinkDriver.Link?
        private var pressSamplerDeadline: Double = 0.0
        private var lastPressSample: (left: CGFloat, right: CGFloat, rightInner: CGFloat, time: Double)?
        /// The press sampler's clock (tests replace it).
        var pressSamplerClock: () -> Double = {
            return CACurrentMediaTime()
        }

        private func samplePress() {
            let now = self.pressSamplerClock()
            let left = self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
            let right = self.rightOuterBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
            let rightInner = self.rightInnerBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
            if abs(left - 1.0) < 0.0005 && abs(right - 1.0) < 0.0005 && abs(rightInner - 1.0) < 0.0005 {
                if let sample = self.lastPressSample, now - sample.time < 0.1 {
                    // The press was just taken off: keep the last pressed sample for the hand-over.
                    return
                }
            } else {
                // A press held past the first window: its end is what the hand-over needs.
                self.pressSamplerDeadline = max(self.pressSamplerDeadline, now + 0.5)
            }
            self.lastPressSample = (left, right, rightInner, now)
        }

        private func beginPressSampling() {
            self.pressSamplerDeadline = self.pressSamplerClock() + 1.5
            self.samplePress()
            if self.pressSamplerLink == nil {
                self.pressSamplerLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                    self?.tickPressSampler()
                })
            }
        }

        /// One frame of the press sampler.
        func tickPressSampler() {
            if self.pressSamplerClock() > self.pressSamplerDeadline || self.plattersDetached {
                self.pressSamplerLink?.invalidate()
                self.pressSamplerLink = nil
                return
            }
            self.samplePress()
        }

        /// The press UIKit was drawing on a capsule when the platters were detached (1: none, or not detached); on the right,
        /// the outermost platter's (the accent circle when there is one).
        public func detachedPressScale(isLeft: Bool) -> CGFloat {
            return isLeft ? self.detachedPressScales.left : self.detachedPressScales.right
        }

        private var detachedPressGlows: (left: CGFloat, right: CGFloat, rightInner: CGFloat) = (0.0, 0.0, 0.0)

        /// The press UIKit was drawing on the right capsule beside an accent circle when the platters were detached
        /// (1: none, no circle, or not detached). `detachedPressScale(isLeft: false)` is the outermost right platter's.
        public var detachedInnerPressScale: CGFloat {
            return self.detachedPressScales.rightInner
        }

        /// UIKit's press glow on that capsule when the platters were detached (0: none).
        public var detachedInnerPressGlow: CGFloat {
            return self.detachedPressGlows.rightInner
        }

        /// UIKit's press glow on a capsule when the platters were detached (0: none, or not detached).
        public func detachedPressGlow(isLeft: Bool) -> CGFloat {
            return isLeft ? self.detachedPressGlows.left : self.detachedPressGlows.right
        }

        private func applyPlattersDetached() {
            let containers: [UIView] = [self.leftButtonsBackgroundContainer, self.rightButtonsBackgroundContainer, self.rightCircleBackgroundContainer].compactMap { $0 }
            for container in containers {
                if self.plattersDetached {
                    container.removeFromSuperview()
                } else if container.superview == nil {
                    self.addSubview(container)
                }
            }
        }
        /// iPhone Duo: the side column (back circle and capsule), laid out in its own bounds. The host adds it to
        /// its hierarchy and sets its frame.
        public let sideColumnView: UIView
        private let columnBackContainer: UIView
        private let columnButtonsContainer: UIView
        private(set) var columnBackBackgroundContainer: GlassContextExtractableContainer?
        private(set) var columnBadgeNode: NavigationBarBadgeNode?
        private(set) var columnButtonsBackgroundContainer: GlassContextExtractableContainer?
        private let columnTrailingContainer: UIView
        private(set) var columnTrailingBackgroundContainer: GlassContextExtractableContainer?

        /// A sparse container laid out over the row, above the titles and below the button capsules: where a host
        /// puts row-level content of its own (the chat list's story list).
        public let underButtonsView: UIView
        /// The band centered content is laid out in (see `update`), in this view's coordinates.
        public private(set) var centeredContentFrame: CGRect = CGRect()

        private var effectiveContentView: NavigationBarContentView? {
            return self.secondaryContentView ?? self.primaryContentView
        }

        public var rightButtonViews: [AnyHashable: UIView] {
            return self.effectiveContentView?.rightButtonViews.reduce(into: [:], { result, view in
                result[view.key] = view.value.view
            }) ?? [:]
        }

        /// The primary content's hosted title view (`.custom` or `.component`), if it has one.
        public var primaryTitleView: UIView? {
            return self.primaryContentView?.customTitleView?.view ?? self.primaryContentView?.titleContentView?.view
        }

        /// Where the primary content's buttons end, from each edge of `centeredContentFrame`, plus the chat list's
        /// title margins (`navigationBarCenterContentInsets`).
        public var primaryCenterContentInsets: (left: CGFloat, right: CGFloat) {
            return (self.primaryContentView?.centerContentLeftInset ?? 0.0, self.primaryContentView?.centerContentRightInset ?? 0.0)
        }

        /// The primary content's row buttons, as wide as `NavigationBarImpl` measured them for placing a title view.
        public var primaryLeftButtonsWidth: CGFloat {
            return self.primaryContentView?.leftButtonsWidth ?? 0.0
        }
        /// The primary content's right side: the capsule and, beyond it with UIKit's gap, an accent circle.
        public var primaryRightButtonsWidth: CGFloat {
            guard let contentView = self.primaryContentView else {
                return 0.0
            }
            return navigationBarRightButtonsExtent(capsuleWidth: contentView.rightButtonsWidth, circleWidth: contentView.rightCircleWidth)
        }

        /// Whether the primary content's row leaves a title pill a right platter slot in a transition: fewer than two right
        /// platters (an accent circle and a capsule take both).
        public var primaryHasRoomForTitlePill: Bool {
            guard let contentView = self.primaryContentView else {
                return true
            }
            return contentView.rightCircleWidth == 0.0 || contentView.rightButtonsWidth == 0.0
        }

        /// iPhone Duo: whether the primary content's back (or close) button is in the side column.
        public var isBackInSideColumn: Bool {
            guard let primaryContentView = self.primaryContentView else {
                return false
            }
            return primaryContentView.backButtonView != nil && primaryContentView.columnLayout?.backFrame != nil
        }

        /// Fades the back button and the right buttons in (the chat appearing from a preview).
        public func animateButtonsIn(duration: Double) {
            guard let contentView = self.effectiveContentView else {
                return
            }
            contentView.backButtonView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            contentView.rightButtonsContainer.layer.animateAlpha(from: 0.0, to: contentView.rightButtonsContainer.alpha, duration: duration)
            contentView.rightCircleContainer.layer.animateAlpha(from: 0.0, to: contentView.rightCircleContainer.alpha, duration: duration)
        }

        public var leadingAccessibilityElements: [UIView] {
            guard let contentView = self.effectiveContentView else {
                return []
            }
            var result: [UIView] = []
            if let backButtonView = contentView.backButtonView {
                result.append(backButtonView)
            }
            result.append(contentsOf: contentView.leftButtonViews.values.compactMap(\.view))
            return result
        }

        public var titleAccessibilityElement: UIView? {
            guard let contentView = self.effectiveContentView, contentView.titleTextView.isAccessibilityElement, !contentView.titleTextView.isHidden else {
                return nil
            }
            return contentView.titleTextView
        }

        public var trailingAccessibilityElements: [UIView] {
            guard let contentView = self.effectiveContentView else {
                return []
            }
            return contentView.rightButtonViews.values.compactMap(\.view).sorted(by: { lhs, rhs in
                return lhs.convert(lhs.bounds, to: self).minX < rhs.convert(rhs.bounds, to: self).minX
            })
        }

        override init(frame: CGRect) {
            self.leftButtonsContainer = UIView()
            self.rightButtonsContainer = UIView()
            self.rightButtonsContainer.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
            self.rightCircleContainer = UIView()
            self.sideColumnView = SparseContainerView()
            self.columnBackContainer = UIView()
            self.columnButtonsContainer = UIView()
            self.columnButtonsContainer.clipsToBounds = true
            self.columnTrailingContainer = UIView()
            self.underButtonsView = SparseContainerView()

            super.init(frame: frame)

            self.addSubview(self.underButtonsView)
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer? {
            if let leftButtonsBackgroundContainer = self.leftButtonsBackgroundContainer, sourceView.isDescendant(of: leftButtonsBackgroundContainer) {
                return leftButtonsBackgroundContainer
            }
            if let rightButtonsBackgroundContainer = self.rightButtonsBackgroundContainer, sourceView.isDescendant(of: rightButtonsBackgroundContainer) {
                return rightButtonsBackgroundContainer
            }
            if let rightCircleBackgroundContainer = self.rightCircleBackgroundContainer, sourceView.isDescendant(of: rightCircleBackgroundContainer) {
                return rightCircleBackgroundContainer
            }
            if let columnButtonsBackgroundContainer = self.columnButtonsBackgroundContainer, sourceView.isDescendant(of: columnButtonsBackgroundContainer) {
                return columnButtonsBackgroundContainer
            }
            if let columnBackBackgroundContainer = self.columnBackBackgroundContainer, sourceView.isDescendant(of: columnBackBackgroundContainer) {
                return columnBackBackgroundContainer
            }
            if let columnTrailingBackgroundContainer = self.columnTrailingBackgroundContainer, sourceView.isDescendant(of: columnTrailingBackgroundContainer) {
                return columnTrailingBackgroundContainer
            }
            return nil
        }

        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            for subview in self.subviews.reversed() {
                if !subview.isUserInteractionEnabled || subview.alpha < 0.01 || subview.isHidden {
                    continue
                }
                if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                    // A touch (not a pointer hovering) in a capsule: UIKit may be about to press it.
                    if event.flatMap({ $0.type == .touches }) ?? true {
                        if let left = self.leftButtonsBackgroundContainer, result.isDescendant(of: left) {
                            self.beginPressSampling()
                        } else if let right = self.rightButtonsBackgroundContainer, result.isDescendant(of: right) {
                            self.beginPressSampling()
                        } else if let circle = self.rightCircleBackgroundContainer, result.isDescendant(of: circle) {
                            self.beginPressSampling()
                        }
                    }
                    return result
                }
            }
            return super.hitTest(point, with: event)
        }

        func update(component: NavigationBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component

            // Content centered on the bar (the titles) is laid out in the band between the two insets, so it
            // stays centered in the visible area when the sides differ (iPhone Duo reserves one side for its
            // vertical status bar). Inside the band both sides get the symmetric part of the inset; the button
            // containers below use the full insets. With equal insets the band is the whole bar.
            let symmetricInset = min(component.leftInset, component.rightInset)
            let centeredContentFrame = CGRect(
                x: component.leftInset - symmetricInset,
                y: 0.0,
                width: availableSize.width - (component.leftInset - symmetricInset) - (component.rightInset - symmetricInset),
                height: availableSize.height
            )
            self.centeredContentFrame = centeredContentFrame
            transition.setFrame(view: self.underButtonsView, frame: CGRect(origin: CGPoint(), size: availableSize))

            // An animated change of the capsules' items in place (Edit <-> Done, the back button giving way to edit
            // mode) animates as iOS 27's glass does, on the bar's own capsules: see `startInPlaceChange`.
            // A badge is not an item change: the back button animates its own.
            var inPlaceLeft = false
            var inPlaceRight = false
            var inPlaceCircle = false
            if let previousPrimary = previousComponent?.primaryContent, let primary = component.primaryContent, component.secondaryContent == nil, previousComponent?.secondaryContent == nil, component.sideColumnLength == nil, previousComponent?.sideColumnLength == nil, !self.plattersDetached {
                if !transition.animation.isImmediate {
                    inPlaceLeft = previousPrimary.back != primary.back || navigationBarCapsuleItemsDiffer(previousPrimary.leftButton.map { [$0] } ?? [], primary.leftButton.map { [$0] } ?? [])
                    // UIKit's sections: the capsule's items and the circle's item change apart.
                    let previousPlacement = navigationBarButtonPlacement(leftButton: previousPrimary.leftButton, rightButtons: previousPrimary.rightButtons, hasBack: previousPrimary.back != nil, columnLength: nil)
                    let placement = navigationBarButtonPlacement(leftButton: primary.leftButton, rightButtons: primary.rightButtons, hasBack: primary.back != nil, columnLength: nil)
                    inPlaceRight = navigationBarCapsuleItemsDiffer(previousPlacement.rowRightButtons, placement.rowRightButtons)
                    inPlaceCircle = navigationBarCapsuleItemsDiffer(previousPlacement.rowCircleItem.map { [$0] } ?? [], placement.rowCircleItem.map { [$0] } ?? [])
                }
            } else {
                // Another kind of change (a secondary content, iPhone Duo's column) lays the capsules out.
                self.finishInPlaceAnimations()
            }
            // The items leaving, as they are now.
            let leavingLeft = inPlaceLeft ? self.inPlaceLeavingItems(slot: .left) : nil
            let leavingRight = inPlaceRight ? self.inPlaceLeavingItems(slot: .right) : nil
            let leavingCircle = inPlaceCircle ? self.inPlaceLeavingItems(slot: .rightCircle) : nil
            // The items swap at once inside their capsules, which animate the change (`startInPlaceChange`).
            let itemsTransition: ComponentTransition = (inPlaceLeft || inPlaceRight || inPlaceCircle) ? .immediate : transition

            var primaryContentTransition = transition
            if let primaryContent = component.primaryContent {
                let primaryContentView: NavigationBarContentView
                if let current = self.primaryContentView {
                    primaryContentView = current
                } else {
                    primaryContentTransition = .immediate
                    primaryContentView = NavigationBarContentView(backPressed: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.primaryContent?.backPressed()
                    })
                    self.primaryContentView = primaryContentView
                    self.insertSubview(primaryContentView, belowSubview: self.underButtonsView)
                    self.leftButtonsContainer.addSubview(primaryContentView.leftButtonsContainer)
                    self.rightButtonsContainer.addSubview(primaryContentView.rightButtonsContainer)
                    self.rightCircleContainer.addSubview(primaryContentView.rightCircleContainer)
                    self.columnBackContainer.addSubview(primaryContentView.columnBackContainer)
                    self.columnButtonsContainer.addSubview(primaryContentView.columnButtonsContainer)
                    self.columnTrailingContainer.addSubview(primaryContentView.columnTrailingContainer)
                }

                primaryContentView.update(theme: component.theme, strings: component.strings, content: primaryContent, leftInset: symmetricInset, rightInset: symmetricInset + component.trailingButtonsInset, size: centeredContentFrame.size, columnLength: component.sideColumnLength, openOverflow: component.openSideColumnOverflow, transition: primaryContentTransition, itemsTransition: primaryContentTransition.animation.isImmediate ? nil : itemsTransition)
                primaryContentTransition.setFrame(view: primaryContentView, frame: centeredContentFrame)
            } else if let primaryContentView = self.primaryContentView {
                self.primaryContentView = nil
                primaryContentView.removeFromSuperview()
                primaryContentView.leftButtonsContainer.removeFromSuperview()
                primaryContentView.rightButtonsContainer.removeFromSuperview()
                primaryContentView.rightCircleContainer.removeFromSuperview()
                primaryContentView.columnBackContainer.removeFromSuperview()
                primaryContentView.columnButtonsContainer.removeFromSuperview()
                primaryContentView.columnTrailingContainer.removeFromSuperview()
            }

            var secondaryContentTransition = transition
            var secondaryContentIsAnimatingIn = false
            var removedSecondaryContentView: NavigationBarContentView?
            if let secondaryContent = component.secondaryContent {
                let secondaryContentView: NavigationBarContentView
                if let current = self.secondaryContentView {
                    secondaryContentView = current
                } else {
                    secondaryContentTransition = .immediate
                    secondaryContentIsAnimatingIn = true
                    secondaryContentView = NavigationBarContentView(backPressed: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.secondaryContent?.backPressed()
                    })
                    self.secondaryContentView = secondaryContentView
                    if let primaryContentView = self.primaryContentView {
                        self.insertSubview(secondaryContentView, aboveSubview: primaryContentView)
                    } else {
                        self.insertSubview(secondaryContentView, belowSubview: self.underButtonsView)
                    }
                    self.leftButtonsContainer.addSubview(secondaryContentView.leftButtonsContainer)
                    self.rightButtonsContainer.addSubview(secondaryContentView.rightButtonsContainer)
                    self.rightCircleContainer.addSubview(secondaryContentView.rightCircleContainer)
                    self.columnBackContainer.addSubview(secondaryContentView.columnBackContainer)
                    self.columnButtonsContainer.addSubview(secondaryContentView.columnButtonsContainer)
                    self.columnTrailingContainer.addSubview(secondaryContentView.columnTrailingContainer)
                }
                secondaryContentView.update(theme: component.theme, strings: component.strings, content: secondaryContent, leftInset: symmetricInset, rightInset: symmetricInset + component.trailingButtonsInset, size: centeredContentFrame.size, columnLength: component.sideColumnLength, openOverflow: component.openSideColumnOverflow, transition: secondaryContentTransition)
                secondaryContentTransition.setFrame(view: secondaryContentView, frame: centeredContentFrame)

                if let primaryContentView = self.primaryContentView {
                    if let previousComponent, previousComponent.secondaryContent == nil {
                        primaryContentView.updateTransitionAsPrevious(width: availableSize.width, fraction: 0.0, transition: .immediate, completion: {})
                        secondaryContentView.updateTransitionAsNext(fraction: 0.0, transition: .immediate, completion: {})
                    }

                    primaryContentView.updateTransitionAsPrevious(width: availableSize.width, fraction: component.secondaryTransition, transition: transition, completion: {})
                    secondaryContentView.updateTransitionAsNext(fraction: component.secondaryTransition, transition: transition, completion: {})
                }
            } else if let secondaryContentView = self.secondaryContentView {
                self.secondaryContentView = nil
                removedSecondaryContentView = secondaryContentView

                if let primaryContentView = self.primaryContentView {
                    primaryContentView.updateTransitionAsPrevious(width: availableSize.width, fraction: 0.0, transition: transition, completion: {})
                    secondaryContentView.updateTransitionAsNext(fraction: 0.0, transition: transition, completion: { [weak secondaryContentView] in
                        secondaryContentView?.leftButtonsContainer.removeFromSuperview()
                        secondaryContentView?.rightButtonsContainer.removeFromSuperview()
                        secondaryContentView?.rightCircleContainer.removeFromSuperview()
                        secondaryContentView?.columnBackContainer.removeFromSuperview()
                        secondaryContentView?.columnButtonsContainer.removeFromSuperview()
                        secondaryContentView?.columnTrailingContainer.removeFromSuperview()
                        secondaryContentView?.removeFromSuperview()
                    })
                } else {
                    secondaryContentView.leftButtonsContainer.removeFromSuperview()
                    secondaryContentView.rightButtonsContainer.removeFromSuperview()
                    secondaryContentView.rightCircleContainer.removeFromSuperview()
                    secondaryContentView.columnBackContainer.removeFromSuperview()
                    secondaryContentView.columnButtonsContainer.removeFromSuperview()
                    secondaryContentView.columnTrailingContainer.removeFromSuperview()
                    secondaryContentView.removeFromSuperview()
                }
            }

            // From here to the end of the function: `ChatListHeaderComponent.swift:1341-1439` at c8b4277abe, copied
            // verbatim (component.theme.overallDarkAppearance now reads NavigationBarTheme's field of the same name).
            var leftButtonsEffectiveWidth: CGFloat = 0.0
            var rightButtonsEffectiveWidth: CGFloat = 0.0
            // The accent circle outermost on the right, and how far in it takes the capsule (circle and UIKit's gap).
            var rightCircleEffectiveWidth: CGFloat = 0.0
            var rightCircleEffectiveExtent: CGFloat = 0.0
            if let primaryContentView = self.primaryContentView, let secondaryContentView = self.secondaryContentView {

                leftButtonsEffectiveWidth = primaryContentView.leftButtonsWidth * (1.0 - component.secondaryTransition) + secondaryContentView.leftButtonsWidth * component.secondaryTransition
                rightButtonsEffectiveWidth = primaryContentView.rightButtonsWidth * (1.0 - component.secondaryTransition) + secondaryContentView.rightButtonsWidth * component.secondaryTransition

                primaryContentTransition.setFrame(view: primaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.leftButtonsWidth), height: 44.0)))
                secondaryContentTransition.setFrame(view: secondaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, secondaryContentView.leftButtonsWidth), height: 44.0)))

                primaryContentTransition.setFrame(view: primaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - primaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.rightButtonsWidth), height: 44.0)))

                if secondaryContentIsAnimatingIn {
                    secondaryContentView.rightButtonsContainer.frame = CGRect(origin: CGPoint(x: self.rightButtonsContainer.bounds.width - secondaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, secondaryContentView.rightButtonsWidth), height: 44.0))
                }
                transition.setFrame(view: secondaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - secondaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, secondaryContentView.rightButtonsWidth), height: 44.0)))

                rightCircleEffectiveWidth = primaryContentView.rightCircleWidth * (1.0 - component.secondaryTransition) + secondaryContentView.rightCircleWidth * component.secondaryTransition
                rightCircleEffectiveExtent = navigationBarRightCircleExtent(primaryContentView.rightCircleWidth) * (1.0 - component.secondaryTransition) + navigationBarRightCircleExtent(secondaryContentView.rightCircleWidth) * component.secondaryTransition
                primaryContentTransition.setFrame(view: primaryContentView.rightCircleContainer, frame: CGRect(x: rightCircleEffectiveWidth - primaryContentView.rightCircleWidth, y: 0.0, width: primaryContentView.rightCircleWidth, height: 44.0))
                transition.setFrame(view: secondaryContentView.rightCircleContainer, frame: CGRect(x: rightCircleEffectiveWidth - secondaryContentView.rightCircleWidth, y: 0.0, width: secondaryContentView.rightCircleWidth, height: 44.0))
            } else if let primaryContentView = self.primaryContentView {
                leftButtonsEffectiveWidth = primaryContentView.leftButtonsWidth
                rightButtonsEffectiveWidth = primaryContentView.rightButtonsWidth

                let primaryItemsTransition = primaryContentTransition.animation.isImmediate ? primaryContentTransition : itemsTransition
                primaryItemsTransition.setFrame(view: primaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.leftButtonsWidth), height: 44.0)))
                primaryItemsTransition.setFrame(view: primaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - primaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.rightButtonsWidth), height: 44.0)))

                rightCircleEffectiveWidth = primaryContentView.rightCircleWidth
                rightCircleEffectiveExtent = navigationBarRightCircleExtent(primaryContentView.rightCircleWidth)
                primaryItemsTransition.setFrame(view: primaryContentView.rightCircleContainer, frame: CGRect(x: 0.0, y: 0.0, width: primaryContentView.rightCircleWidth, height: 44.0))

                if let removedSecondaryContentView {
                    transition.setFrame(view: removedSecondaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - removedSecondaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, removedSecondaryContentView.rightButtonsWidth), height: 44.0)))
                }
            }

            var visibleContentViews: [NavigationBarContentView] = []
            if let primaryContentView = self.primaryContentView, self.secondaryContentView == nil || component.secondaryTransition < 1.0 {
                visibleContentViews.append(primaryContentView)
            }
            if let secondaryContentView = self.secondaryContentView, component.secondaryTransition > 0.0 {
                visibleContentViews.append(secondaryContentView)
            }
            let leftButtonCount = visibleContentViews.reduce(0, { $0 + $1.leftButtonCount })
            let rightButtonCount = visibleContentViews.reduce(0, { $0 + $1.rightButtonCount })

            let leftCapsuleTintColor = navigationBarGlassTintColor(self.effectiveContentView?.leftCapsuleTint ?? .generic, theme: component.theme)
            let rightCapsuleTintColor = navigationBarGlassTintColor(self.effectiveContentView?.rightCapsuleTint ?? .generic, theme: component.theme)

            if leftButtonsEffectiveWidth != 0.0 {
                let leftButtonsBackgroundContainer: GlassContextExtractableContainer
                var leftButtonsBackgroundContainerTransition = transition
                var isNewCapsule = false
                if let current = self.leftButtonsBackgroundContainer {
                    leftButtonsBackgroundContainer = current
                } else {
                    isNewCapsule = true
                    leftButtonsBackgroundContainerTransition = leftButtonsBackgroundContainerTransition.withAnimation(.none)
                    leftButtonsBackgroundContainer = GlassContextExtractableContainer()
                    self.leftButtonsBackgroundContainer = leftButtonsBackgroundContainer
                    self.addSubview(leftButtonsBackgroundContainer)
                    leftButtonsBackgroundContainer.contentView.addSubview(self.leftButtonsContainer)
                    if inPlaceLeft {
                        leftButtonsBackgroundContainer.update(size: CGSize(width: max(44.0, leftButtonsEffectiveWidth), height: 44.0), cornerRadius: 22.0, isDark: component.theme.overallDarkAppearance, tintColor: leftCapsuleTintColor, isInteractive: true, isVisible: false, transition: .immediate)
                    }
                }
                let leftButtonsContainerFrame = CGRect(origin: CGPoint(x: component.leftInset, y: 0.0), size: CGSize(width: max(44.0, leftButtonsEffectiveWidth), height: 44.0))
                if inPlaceLeft {
                    self.startInPlaceChange(container: leftButtonsBackgroundContainer, slot: .left, isNew: isNewCapsule, frame: leftButtonsContainerFrame, tintColor: leftCapsuleTintColor, isDark: component.theme.overallDarkAppearance, leaving: leavingLeft)
                } else if let inPlace = self.inPlaceCapsule(for: leftButtonsBackgroundContainer) {
                    self.retargetInPlace(inPlace, frame: leftButtonsContainerFrame, tintColor: leftCapsuleTintColor, isDark: component.theme.overallDarkAppearance, transition: transition)
                } else {
                    leftButtonsBackgroundContainerTransition.setFrame(view: leftButtonsBackgroundContainer, frame: leftButtonsContainerFrame)
                    leftButtonsBackgroundContainer.update(size: leftButtonsContainerFrame.size, cornerRadius: leftButtonsContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: leftCapsuleTintColor, isInteractive: true, transition: leftButtonsBackgroundContainerTransition)
                    leftButtonsBackgroundContainerTransition.setFrame(view: self.leftButtonsContainer, frame: CGRect(origin: CGPoint(), size: leftButtonsContainerFrame.size))
                }
                leftButtonsBackgroundContainer.morphsIntoContextMenu = leftButtonCount == 1
            } else {
                if let leftButtonsBackgroundContainer = self.leftButtonsBackgroundContainer {
                    self.leftButtonsBackgroundContainer = nil
                    if inPlaceLeft {
                        self.startInPlaceRemoval(container: leftButtonsBackgroundContainer, slot: .left, tintColor: leftCapsuleTintColor, isDark: component.theme.overallDarkAppearance, leaving: leavingLeft)
                    } else {
                        transition.setAlpha(view: leftButtonsBackgroundContainer, alpha: 0.0, completion: { [weak leftButtonsBackgroundContainer] _ in
                            leftButtonsBackgroundContainer?.removeFromSuperview()
                        })
                    }
                }
            }

            if rightButtonsEffectiveWidth != 0.0 {
                let rightButtonsBackgroundContainer: GlassContextExtractableContainer
                var rightButtonsBackgroundContainerTransition = transition
                var isNewCapsule = false
                
                let rightEdge = availableSize.width - component.rightInset - component.trailingButtonsInset
                let rightButtonsContainerFrame = CGRect(origin: CGPoint(x: rightEdge - rightCircleEffectiveExtent - max(44.0, rightButtonsEffectiveWidth), y: 0.0), size: CGSize(width: max(44.0, rightButtonsEffectiveWidth), height: 44.0))
                
                if let current = self.rightButtonsBackgroundContainer {
                    rightButtonsBackgroundContainer = current
                } else {
                    isNewCapsule = true
                    rightButtonsBackgroundContainerTransition = rightButtonsBackgroundContainerTransition.withAnimation(.none)
                    rightButtonsBackgroundContainer = GlassContextExtractableContainer()
                    self.rightButtonsBackgroundContainer = rightButtonsBackgroundContainer
                    self.addSubview(rightButtonsBackgroundContainer)
                    rightButtonsBackgroundContainer.contentView.addSubview(self.rightButtonsContainer)
                    
                    rightButtonsBackgroundContainer.update(size: rightButtonsContainerFrame.size, cornerRadius: rightButtonsContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: rightCapsuleTintColor, isInteractive: true, isVisible: false, transition: .immediate)
                }
                if inPlaceRight {
                    self.startInPlaceChange(container: rightButtonsBackgroundContainer, slot: .right, isNew: isNewCapsule, frame: rightButtonsContainerFrame, tintColor: rightCapsuleTintColor, isDark: component.theme.overallDarkAppearance, leaving: leavingRight)
                } else if let inPlace = self.inPlaceCapsule(for: rightButtonsBackgroundContainer) {
                    self.retargetInPlace(inPlace, frame: rightButtonsContainerFrame, tintColor: rightCapsuleTintColor, isDark: component.theme.overallDarkAppearance, transition: transition)
                } else {
                    rightButtonsBackgroundContainerTransition.setFrame(view: rightButtonsBackgroundContainer, frame: rightButtonsContainerFrame)
                    rightButtonsBackgroundContainer.update(size: rightButtonsContainerFrame.size, cornerRadius: rightButtonsContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: rightCapsuleTintColor, isInteractive: true, transition: transition)
                    rightButtonsBackgroundContainerTransition.setFrame(view: self.rightButtonsContainer, frame: CGRect(origin: CGPoint(), size: rightButtonsContainerFrame.size))
                }
                rightButtonsBackgroundContainer.morphsIntoContextMenu = rightButtonCount == 1
            } else {
                if let rightButtonsBackgroundContainer = self.rightButtonsBackgroundContainer {
                    self.rightButtonsBackgroundContainer = nil
                    if inPlaceRight {
                        self.startInPlaceRemoval(container: rightButtonsBackgroundContainer, slot: .right, tintColor: rightCapsuleTintColor, isDark: component.theme.overallDarkAppearance, leaving: leavingRight)
                    } else {
                        rightButtonsBackgroundContainer.update(size: rightButtonsBackgroundContainer.bounds.size, cornerRadius: rightButtonsBackgroundContainer.bounds.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: rightCapsuleTintColor, isInteractive: true, isVisible: false, transition: transition)
                        transition.attachAnimation(view: rightButtonsBackgroundContainer, id: "remove", completion: { [weak rightButtonsBackgroundContainer] _ in
                            rightButtonsBackgroundContainer?.removeFromSuperview()
                        })
                    }
                }
            }
            
            // The circle's tint is its owner's: the content whose circle it mostly is (a forum sliding over Chats has no
            // circle, so Chats' compose circle keeps its accent glass while it narrows).
            let rightCircleTint: NavigationBarComponent.Button.Tint
            if let primaryContentView = self.primaryContentView, let secondaryContentView = self.secondaryContentView {
                let secondaryWeight = secondaryContentView.rightCircleWidth * component.secondaryTransition
                let primaryWeight = primaryContentView.rightCircleWidth * (1.0 - component.secondaryTransition)
                rightCircleTint = secondaryWeight > primaryWeight ? secondaryContentView.rightCircleTint : primaryContentView.rightCircleTint
            } else {
                rightCircleTint = self.effectiveContentView?.rightCircleTint ?? .generic
            }
            self.appliedRightCircleTint = rightCircleTint
            let rightCircleTintColor = navigationBarGlassTintColor(rightCircleTint, theme: component.theme)
            if rightCircleEffectiveWidth != 0.0 {
                let rightEdge = availableSize.width - component.rightInset - component.trailingButtonsInset
                let circleFrame = CGRect(x: rightEdge - rightCircleEffectiveWidth, y: 0.0, width: rightCircleEffectiveWidth, height: 44.0)
                let circleContainer: GlassContextExtractableContainer
                var circleTransition = transition
                var isNewCircle = false
                if let current = self.rightCircleBackgroundContainer {
                    circleContainer = current
                } else {
                    isNewCircle = true
                    circleTransition = circleTransition.withAnimation(.none)
                    circleContainer = GlassContextExtractableContainer()
                    self.rightCircleBackgroundContainer = circleContainer
                    self.addSubview(circleContainer)
                    circleContainer.contentView.addSubview(self.rightCircleContainer)
                    circleContainer.update(size: circleFrame.size, cornerRadius: circleFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: rightCircleTintColor, isInteractive: true, isVisible: false, transition: .immediate)
                }
                if inPlaceCircle {
                    self.startInPlaceChange(container: circleContainer, slot: .rightCircle, isNew: isNewCircle, frame: circleFrame, tintColor: rightCircleTintColor, isDark: component.theme.overallDarkAppearance, leaving: leavingCircle)
                } else if let inPlace = self.inPlaceCapsule(for: circleContainer) {
                    self.retargetInPlace(inPlace, frame: circleFrame, tintColor: rightCircleTintColor, isDark: component.theme.overallDarkAppearance, transition: transition)
                } else {
                    circleTransition.setFrame(view: circleContainer, frame: circleFrame)
                    circleContainer.update(size: circleFrame.size, cornerRadius: circleFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: rightCircleTintColor, isInteractive: true, transition: transition)
                    circleTransition.setFrame(view: self.rightCircleContainer, frame: CGRect(origin: CGPoint(), size: circleFrame.size))
                }
                circleContainer.morphsIntoContextMenu = true
            } else if let circleContainer = self.rightCircleBackgroundContainer {
                self.rightCircleBackgroundContainer = nil
                if inPlaceCircle {
                    self.startInPlaceRemoval(container: circleContainer, slot: .rightCircle, tintColor: rightCircleTintColor, isDark: component.theme.overallDarkAppearance, leaving: leavingCircle)
                } else {
                    circleContainer.update(size: circleContainer.bounds.size, cornerRadius: circleContainer.bounds.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: rightCircleTintColor, isInteractive: true, isVisible: false, transition: transition)
                    transition.attachAnimation(view: circleContainer, id: "remove", completion: { [weak circleContainer] _ in
                        circleContainer?.removeFromSuperview()
                    })
                }
            }

            self.updateSideColumn(component: component, transition: transition)
            if self.plattersDetached {
                // Capsules this layout created stay out too.
                self.applyPlattersDetached()
            }
            
            return availableSize
        }

        /// Lays out the side column from the contents' column layouts: crossfading contents (a forum
        /// opening inline) interpolate the capsule and share the back circle by `secondaryTransition`.
        private func updateSideColumn(component: NavigationBarComponent, transition: ComponentTransition) {
            var contents: [(view: NavigationBarContentView, weight: CGFloat)] = []
            if let primaryContentView = self.primaryContentView {
                contents.append((primaryContentView, self.secondaryContentView == nil ? 1.0 : 1.0 - component.secondaryTransition))
            }
            if let secondaryContentView = self.secondaryContentView {
                contents.append((secondaryContentView, component.secondaryTransition))
            }
            
            var backAlpha: CGFloat = 0.0
            var capsuleAlpha: CGFloat = 0.0
            var capsuleFrame: CGRect?
            var columnBackFrame: CGRect?
            for (contentView, weight) in contents {
                guard let columnLayout = contentView.columnLayout else {
                    continue
                }
                if let layoutBackFrame = columnLayout.backFrame {
                    backAlpha += weight
                    if columnBackFrame == nil {
                        columnBackFrame = layoutBackFrame
                    }
                }
                if let frame = columnLayout.capsuleFrame {
                    capsuleAlpha += weight
                    if let current = capsuleFrame {
                        capsuleFrame = CGRect(x: frame.minX, y: current.minY * (1.0 - weight) + frame.minY * weight, width: frame.width, height: current.height * (1.0 - weight) + frame.height * weight)
                    } else {
                        capsuleFrame = frame
                    }
                }
            }
            let isDark = component.theme.overallDarkAppearance
            let genericTintColor = navigationBarGlassTintColor(.generic, theme: component.theme)
            
            if backAlpha > 0.0, let backFrame = columnBackFrame {
                var backTransition = transition
                let backBackgroundContainer: GlassContextExtractableContainer
                if let current = self.columnBackBackgroundContainer {
                    backBackgroundContainer = current
                } else {
                    backTransition = backTransition.withAnimation(.none)
                    backBackgroundContainer = GlassContextExtractableContainer()
                    self.columnBackBackgroundContainer = backBackgroundContainer
                    self.sideColumnView.addSubview(backBackgroundContainer)
                    backBackgroundContainer.contentView.addSubview(self.columnBackContainer)
                    backBackgroundContainer.alpha = 0.0
                }
                backTransition.setFrame(view: backBackgroundContainer, frame: backFrame)
                backBackgroundContainer.update(size: backFrame.size, cornerRadius: backFrame.height * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, transition: backTransition)
                backTransition.setFrame(view: self.columnBackContainer, frame: backFrame)
                for (contentView, _) in contents {
                    backTransition.setFrame(view: contentView.columnBackContainer, frame: backFrame)
                }
                transition.setAlpha(view: backBackgroundContainer, alpha: backAlpha)
            } else if let backBackgroundContainer = self.columnBackBackgroundContainer {
                self.columnBackBackgroundContainer = nil
                transition.setAlpha(view: backBackgroundContainer, alpha: 0.0, completion: { [weak backBackgroundContainer] _ in
                    backBackgroundContainer?.removeFromSuperview()
                })
            }

            // The unread badge sits on the back circle's corner: the circle is too narrow to widen for it.
            let badgeContent = (self.secondaryContentView != nil && component.secondaryTransition >= 0.5) ? component.secondaryContent : component.primaryContent
            if backAlpha > 0.0, let backFrame = columnBackFrame, let badge = badgeContent?.badge, !badge.isEmpty {
                let badgeNode: NavigationBarBadgeNode
                var badgeTransition = transition
                if let current = self.columnBadgeNode {
                    badgeNode = current
                } else {
                    badgeTransition = badgeTransition.withAnimation(.none)
                    badgeNode = NavigationBarBadgeNode(fillColor: component.theme.buttonColor, strokeColor: component.theme.buttonColor, textColor: component.theme.badgeTextColor)
                    badgeNode.isUserInteractionEnabled = false
                    self.columnBadgeNode = badgeNode
                    self.sideColumnView.addSubnode(badgeNode)
                }
                badgeNode.updateTheme(fillColor: component.theme.buttonColor, strokeColor: component.theme.buttonColor, textColor: component.theme.badgeTextColor)
                badgeNode.text = badge
                let badgeSize = badgeNode.measure(CGSize(width: 200.0, height: 100.0))
                badgeTransition.setFrame(view: badgeNode.view, frame: CGRect(origin: CGPoint(x: backFrame.maxX - badgeSize.width + 4.0, y: backFrame.minY - 4.0), size: badgeSize))
                transition.setAlpha(view: badgeNode.view, alpha: backAlpha)
                self.sideColumnView.bringSubviewToFront(badgeNode.view)
            } else if let badgeNode = self.columnBadgeNode {
                self.columnBadgeNode = nil
                badgeNode.removeFromSupernode()
            }
            
            if let capsuleFrame {
                var capsuleTransition = transition
                let capsuleBackgroundContainer: GlassContextExtractableContainer
                if let current = self.columnButtonsBackgroundContainer {
                    capsuleBackgroundContainer = current
                } else {
                    capsuleTransition = capsuleTransition.withAnimation(.none)
                    capsuleBackgroundContainer = GlassContextExtractableContainer()
                    self.columnButtonsBackgroundContainer = capsuleBackgroundContainer
                    self.sideColumnView.addSubview(capsuleBackgroundContainer)
                    capsuleBackgroundContainer.contentView.addSubview(self.columnButtonsContainer)
                    capsuleBackgroundContainer.alpha = 0.0
                }
                capsuleTransition.setFrame(view: capsuleBackgroundContainer, frame: capsuleFrame)
                capsuleBackgroundContainer.update(size: capsuleFrame.size, cornerRadius: capsuleFrame.width * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, transition: capsuleTransition)
                capsuleBackgroundContainer.morphsIntoContextMenu = self.effectiveContentView?.columnLayout?.cellFrames.count == 1
                capsuleTransition.setFrame(view: self.columnButtonsContainer, frame: CGRect(origin: CGPoint(), size: capsuleFrame.size))
                for (contentView, _) in contents {
                    let size = contentView.columnLayout?.capsuleFrame?.size ?? capsuleFrame.size
                    capsuleTransition.setFrame(view: contentView.columnButtonsContainer, frame: CGRect(origin: CGPoint(), size: size))
                }
                transition.setAlpha(view: capsuleBackgroundContainer, alpha: component.hidesSideColumnButtons ? 0.0 : capsuleAlpha)
                capsuleBackgroundContainer.isUserInteractionEnabled = !component.hidesSideColumnButtons
            } else if let capsuleBackgroundContainer = self.columnButtonsBackgroundContainer {
                self.columnButtonsBackgroundContainer = nil
                transition.setAlpha(view: capsuleBackgroundContainer, alpha: 0.0, completion: { [weak capsuleBackgroundContainer] _ in
                    capsuleBackgroundContainer?.removeFromSuperview()
                })
            }

            var trailingAlpha: CGFloat = 0.0
            var columnTrailingFrame: CGRect?
            var trailingTint: NavigationBarComponent.Button.Tint = .generic
            for (contentView, weight) in contents {
                guard let frame = contentView.columnLayout?.trailingFrame, !contentView.columnTrailingContainer.subviews.isEmpty else {
                    continue
                }
                trailingAlpha += weight
                if columnTrailingFrame == nil {
                    columnTrailingFrame = frame
                    trailingTint = contentView.trailingCircleTint
                }
            }
            if trailingAlpha > 0.0, let trailingFrame = columnTrailingFrame {
                var trailingTransition = transition
                let trailingBackgroundContainer: GlassContextExtractableContainer
                if let current = self.columnTrailingBackgroundContainer {
                    trailingBackgroundContainer = current
                } else {
                    trailingTransition = trailingTransition.withAnimation(.none)
                    trailingBackgroundContainer = GlassContextExtractableContainer()
                    self.columnTrailingBackgroundContainer = trailingBackgroundContainer
                    self.sideColumnView.addSubview(trailingBackgroundContainer)
                    trailingBackgroundContainer.contentView.addSubview(self.columnTrailingContainer)
                    trailingBackgroundContainer.alpha = 0.0
                }
                trailingTransition.setFrame(view: trailingBackgroundContainer, frame: trailingFrame)
                trailingBackgroundContainer.update(size: trailingFrame.size, cornerRadius: trailingFrame.height * 0.5, isDark: isDark, tintColor: navigationBarGlassTintColor(trailingTint, theme: component.theme), isInteractive: true, transition: trailingTransition)
                trailingBackgroundContainer.morphsIntoContextMenu = true
                trailingTransition.setFrame(view: self.columnTrailingContainer, frame: CGRect(origin: CGPoint(), size: trailingFrame.size))
                for (contentView, _) in contents {
                    trailingTransition.setFrame(view: contentView.columnTrailingContainer, frame: CGRect(origin: CGPoint(), size: trailingFrame.size))
                }
                transition.setAlpha(view: trailingBackgroundContainer, alpha: component.hidesSideColumnButtons ? 0.0 : trailingAlpha)
                trailingBackgroundContainer.isUserInteractionEnabled = !component.hidesSideColumnButtons
            } else if let trailingBackgroundContainer = self.columnTrailingBackgroundContainer {
                self.columnTrailingBackgroundContainer = nil
                transition.setAlpha(view: trailingBackgroundContainer, alpha: 0.0, completion: { [weak trailingBackgroundContainer] _ in
                    trailingBackgroundContainer?.removeFromSuperview()
                })
            }
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
