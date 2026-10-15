import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import SideColumnLayout

/// The navigation bar's 44pt row and iPhone Duo side column: title, back, left and right buttons in glass
/// capsules, and the in-bar slide between a primary and a secondary content. Hosts own the backdrop, where the
/// row sits, and the container the column hangs in (`sideColumnView`).
/// One right pill of the row, index 0 outermost: the bar-level items container (it holds each content's items for this
/// pill) and its glass. Pills are kept (without glass) when the row has fewer, so a content's items keep their host.
final class NavigationBarRightPill {
    let itemsContainer: UIView
    var background: GlassContextExtractableContainer?
    /// The tint the last layout gave the glass.
    var appliedTint: NavigationBarComponent.Button.Tint = .generic

    init() {
        self.itemsContainer = UIView()
        // As the bar's single right container was: a width change keeps the pill's trailing edge.
        self.itemsContainer.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
    }
}

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
        private(set) var leftButtonsBackgroundContainer: GlassContextExtractableContainer?
        /// The row's right pills, outermost first (see `NavigationBarRightPill`).
        private(set) var rightPills: [NavigationBarRightPill] = []

        /// Pill `index`, made on first use.
        func rightPill(at index: Int) -> NavigationBarRightPill {
            while self.rightPills.count <= index {
                self.rightPills.append(NavigationBarRightPill())
            }
            return self.rightPills[index]
        }

        func rightPillBackgroundContainer(at index: Int) -> GlassContextExtractableContainer? {
            return index < self.rightPills.count ? self.rightPills[index].background : nil
        }

        func appliedRightPillTint(at index: Int) -> NavigationBarComponent.Button.Tint {
            return index < self.rightPills.count ? self.rightPills[index].appliedTint : .generic
        }

        private var rightBackgroundContainers: [GlassContextExtractableContainer] {
            return self.rightPills.compactMap(\.background)
        }
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
                        var leftScale = self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
                        var rightScales = self.rightPills.map { $0.background.flatMap(navigationBarCapsulePressScale) ?? 1.0 }
                        // A press UIKit has already taken off (the touch just ended) is in the last sample.
                        if let sample = self.lastPressSample, now - sample.time < 0.1 {
                            if abs(leftScale - 1.0) < 0.0005 {
                                leftScale = sample.left
                            }
                            for index in rightScales.indices where abs(rightScales[index] - 1.0) < 0.0005 && index < sample.right.count {
                                rightScales[index] = sample.right[index]
                            }
                        }
                        self.lastPressSample = nil
                        self.detachedLeftPressScale = leftScale
                        self.detachedRightPressScales = rightScales
                        // A glow is always there with a press: when the glow layer cannot be found (a UIKit change), a
                        // press alone stands for a full one. A press passes 1.03 within ~20 ms, so 1.01 tells it from a
                        // reading that is merely not exactly 1.
                        func glow(_ container: GlassContextExtractableContainer?, press: CGFloat) -> CGFloat {
                            if let container, let glow = navigationBarCapsulePressGlow(container) {
                                return glow
                            }
                            return press > 1.01 ? 1.0 : 0.0
                        }
                        self.detachedLeftPressGlow = glow(self.leftButtonsBackgroundContainer, press: leftScale)
                        self.detachedRightPressGlows = zip(self.rightPills, rightScales).map { glow($0.background, press: $1) }
                    } else {
                        self.detachedLeftPressScale = 1.0
                        self.detachedLeftPressGlow = 0.0
                        self.detachedRightPressScales = []
                        self.detachedRightPressGlows = []
                    }
                    self.applyPlattersDetached()
                }
            }
        }

        /// The press UIKit was drawing on the left capsule when the platters were detached (1: none, or not detached), and
        /// its glow (0: none).
        public private(set) var detachedLeftPressScale: CGFloat = 1.0
        public private(set) var detachedLeftPressGlow: CGFloat = 0.0
        /// The press UIKit was drawing on each right pill (index from the edge) when the platters were detached, and its
        /// glow; empty while not detached.
        public private(set) var detachedRightPressScales: [CGFloat] = []
        public private(set) var detachedRightPressGlows: [CGFloat] = []

        /// UIKit draws a capsule's press (on a short tap) only as a running animation on its glass, which it takes off
        /// when the touch ends, before the button's action runs (measured 2026-10-14): when that action starts a
        /// transition there is nothing left to read. So while a touch is in a capsule the press is sampled every frame,
        /// and detaching takes the last pressed sample.
        private var pressSamplerLink: SharedDisplayLinkDriver.Link?
        private var pressSamplerDeadline: Double = 0.0
        private var lastPressSample: (left: CGFloat, right: [CGFloat], time: Double)?
        /// The press sampler's clock (tests replace it).
        var pressSamplerClock: () -> Double = {
            return CACurrentMediaTime()
        }

        private func samplePress() {
            let now = self.pressSamplerClock()
            let left = self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
            let right = self.rightPills.map { $0.background.flatMap(navigationBarCapsulePressScale) ?? 1.0 }
            if abs(left - 1.0) < 0.0005 && right.allSatisfy({ abs($0 - 1.0) < 0.0005 }) {
                if let sample = self.lastPressSample, now - sample.time < 0.1 {
                    // The press was just taken off: keep the last pressed sample for the hand-over.
                    return
                }
            } else {
                // A press held past the first window: its end is what the hand-over needs.
                self.pressSamplerDeadline = max(self.pressSamplerDeadline, now + 0.5)
            }
            self.lastPressSample = (left, right, now)
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

        private func applyPlattersDetached() {
            let containers: [UIView] = ([self.leftButtonsBackgroundContainer].compactMap { $0 } as [UIView]) + self.rightBackgroundContainers
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
            return navigationBarRightButtonsExtent(navigationBarRightPillMetrics(widths: contentView.rightPillWidths))
        }

        /// Whether the primary content's row leaves a title pill a right platter slot in a transition: fewer than two right
        /// platters (an accent circle and a capsule take both).
        public var primaryHasRoomForTitlePill: Bool {
            guard let contentView = self.primaryContentView else {
                return true
            }
            return contentView.rightPillWidths.count < 2
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
            for container in contentView.rightPillContainers {
                container.layer.animateAlpha(from: 0.0, to: container.alpha, duration: duration)
            }
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
            for container in self.rightBackgroundContainers where sourceView.isDescendant(of: container) {
                return container
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
                        } else if self.rightBackgroundContainers.contains(where: { result.isDescendant(of: $0) }) {
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
            var inPlaceRight = Set<Int>()
            if let previousPrimary = previousComponent?.primaryContent, let primary = component.primaryContent, component.secondaryContent == nil, previousComponent?.secondaryContent == nil, component.sideColumnLength == nil, previousComponent?.sideColumnLength == nil, !self.plattersDetached {
                if !transition.animation.isImmediate {
                    inPlaceLeft = previousPrimary.back != primary.back || navigationBarCapsuleItemsDiffer(previousPrimary.leftButton.map { [$0] } ?? [], primary.leftButton.map { [$0] } ?? [])
                    // UIKit's sections change apart, compared by index from the edge.
                    let previousSections = navigationBarButtonPlacement(leftButton: previousPrimary.leftButton, rightButtons: previousPrimary.rightButtons, hasBack: previousPrimary.back != nil, columnLength: nil).rowRightSections
                    let sections = navigationBarButtonPlacement(leftButton: primary.leftButton, rightButtons: primary.rightButtons, hasBack: primary.back != nil, columnLength: nil).rowRightSections
                    for index in 0 ..< max(previousSections.count, sections.count) {
                        let previous = index < previousSections.count ? previousSections[index] : []
                        let current = index < sections.count ? sections[index] : []
                        if navigationBarCapsuleItemsDiffer(previous, current) {
                            inPlaceRight.insert(index)
                        }
                    }
                }
            } else {
                // Another kind of change (a secondary content, iPhone Duo's column) lays the capsules out.
                self.finishInPlaceAnimations()
            }
            // The items leaving, as they are now.
            let leavingLeft = inPlaceLeft ? self.inPlaceLeavingItems(slot: .left) : nil
            var leavingRight: [Int: NavigationBarInPlaceCapsule.Items] = [:]
            for index in inPlaceRight {
                leavingRight[index] = self.inPlaceLeavingItems(slot: .right(index))
            }
            // The items swap at once inside their capsules, which animate the change (`startInPlaceChange`).
            let itemsTransition: ComponentTransition = (inPlaceLeft || !inPlaceRight.isEmpty) ? .immediate : transition

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
                for container in primaryContentView.rightPillContainers {
                    container.removeFromSuperview()
                }
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
                        for container in secondaryContentView?.rightPillContainers ?? [] {
                            container.removeFromSuperview()
                        }
                        secondaryContentView?.columnBackContainer.removeFromSuperview()
                        secondaryContentView?.columnButtonsContainer.removeFromSuperview()
                        secondaryContentView?.columnTrailingContainer.removeFromSuperview()
                        secondaryContentView?.removeFromSuperview()
                    })
                } else {
                    secondaryContentView.leftButtonsContainer.removeFromSuperview()
                    for container in secondaryContentView.rightPillContainers {
                        container.removeFromSuperview()
                    }
                    secondaryContentView.columnBackContainer.removeFromSuperview()
                    secondaryContentView.columnButtonsContainer.removeFromSuperview()
                    secondaryContentView.columnTrailingContainer.removeFromSuperview()
                    secondaryContentView.removeFromSuperview()
                }
            }

            // From here to the end of the function: `ChatListHeaderComponent.swift:1341-1439` at c8b4277abe, copied
            // verbatim (component.theme.overallDarkAppearance now reads NavigationBarTheme's field of the same name).
            var leftButtonsEffectiveWidth: CGFloat = 0.0
            if let primaryContentView = self.primaryContentView, let secondaryContentView = self.secondaryContentView {

                leftButtonsEffectiveWidth = primaryContentView.leftButtonsWidth * (1.0 - component.secondaryTransition) + secondaryContentView.leftButtonsWidth * component.secondaryTransition

                primaryContentTransition.setFrame(view: primaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.leftButtonsWidth), height: 44.0)))
                secondaryContentTransition.setFrame(view: secondaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, secondaryContentView.leftButtonsWidth), height: 44.0)))

            } else if let primaryContentView = self.primaryContentView {
                leftButtonsEffectiveWidth = primaryContentView.leftButtonsWidth

                let primaryItemsTransition = primaryContentTransition.animation.isImmediate ? primaryContentTransition : itemsTransition
                primaryItemsTransition.setFrame(view: primaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.leftButtonsWidth), height: 44.0)))
            }

            var visibleContentViews: [NavigationBarContentView] = []
            if let primaryContentView = self.primaryContentView, self.secondaryContentView == nil || component.secondaryTransition < 1.0 {
                visibleContentViews.append(primaryContentView)
            }
            if let secondaryContentView = self.secondaryContentView, component.secondaryTransition > 0.0 {
                visibleContentViews.append(secondaryContentView)
            }
            let leftButtonCount = visibleContentViews.reduce(0, { $0 + $1.leftButtonCount })

            let leftCapsuleTintColor = navigationBarGlassTintColor(self.effectiveContentView?.leftCapsuleTint ?? .generic, theme: component.theme)

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

            // The right pills. While two contents slide (an inline forum over Chats) their pills are paired from the
            // inner end, so today's slide is kept (spec, structure).
            let primaryPills = self.primaryContentView.map { navigationBarRightPillMetrics(widths: $0.rightPillWidths) } ?? []
            let secondaryPills = self.secondaryContentView.map { navigationBarRightPillMetrics(widths: $0.rightPillWidths) }
            let rightPillMetrics: [NavigationBarRightPillMetrics]
            let rightPillSlots: [(primary: Int?, secondary: Int?)]
            if let secondaryPills {
                rightPillMetrics = navigationBarInterpolatedRightPills(primary: primaryPills, secondary: secondaryPills, fraction: component.secondaryTransition)
                rightPillSlots = navigationBarRightPillSlots(primaryCount: primaryPills.count, secondaryCount: secondaryPills.count)
            } else {
                rightPillMetrics = primaryPills
                rightPillSlots = primaryPills.indices.map { ($0, nil) }
            }
            let rightEdge = availableSize.width - component.rightInset - component.trailingButtonsInset
            let isDark = component.theme.overallDarkAppearance
            var outerExtent: CGFloat = 0.0
            for (slot, metrics) in rightPillMetrics.enumerated() {
                let pill = self.rightPill(at: slot)
                let frame = CGRect(x: rightEdge - outerExtent - metrics.width, y: 0.0, width: metrics.width, height: 44.0)
                outerExtent += metrics.extent
                let owners = rightPillSlots[slot]

                // Each content's items for this pill, right-aligned in it.
                var buttonCount = 0
                var primaryWeight: CGFloat = 0.0
                var secondaryWeight: CGFloat = 0.0
                var primaryTint: NavigationBarComponent.Button.Tint = .generic
                var secondaryTint: NavigationBarComponent.Button.Tint = .generic
                if let index = owners.primary, let contentView = self.primaryContentView {
                    let container = contentView.rightPillContainer(at: index)
                    if container.superview !== pill.itemsContainer {
                        pill.itemsContainer.addSubview(container)
                    }
                    let width = contentView.rightPillWidths[index]
                    let itemsFrame = CGRect(x: metrics.width - width, y: 0.0, width: width, height: 44.0)
                    if secondaryPills == nil {
                        (primaryContentTransition.animation.isImmediate ? primaryContentTransition : itemsTransition).setFrame(view: container, frame: itemsFrame)
                    } else {
                        primaryContentTransition.setFrame(view: container, frame: itemsFrame)
                    }
                    if self.secondaryContentView == nil || component.secondaryTransition < 1.0 {
                        buttonCount += contentView.rightPillButtonCounts[index]
                    }
                    primaryWeight = width * (secondaryPills == nil ? 1.0 : 1.0 - component.secondaryTransition)
                    primaryTint = contentView.rightPillTints[index]
                }
                if let index = owners.secondary, let contentView = self.secondaryContentView {
                    let container = contentView.rightPillContainer(at: index)
                    let width = contentView.rightPillWidths[index]
                    let itemsFrame = CGRect(x: metrics.width - width, y: 0.0, width: width, height: 44.0)
                    if container.superview !== pill.itemsContainer {
                        pill.itemsContainer.addSubview(container)
                        container.frame = itemsFrame
                    }
                    if secondaryContentIsAnimatingIn {
                        container.frame = CGRect(x: pill.itemsContainer.bounds.width - width, y: 0.0, width: width, height: 44.0)
                    }
                    transition.setFrame(view: container, frame: itemsFrame)
                    if component.secondaryTransition > 0.0 {
                        buttonCount += contentView.rightPillButtonCounts[index]
                    }
                    secondaryWeight = width * component.secondaryTransition
                    secondaryTint = contentView.rightPillTints[index]
                }
                // The tint of the content the pill mostly belongs to (a forum sliding over Chats has no compose circle,
                // so Chats' keeps its accent glass while it narrows).
                let tint = secondaryWeight > primaryWeight ? secondaryTint : primaryTint
                pill.appliedTint = tint
                let tintColor = navigationBarGlassTintColor(tint, theme: component.theme)

                guard metrics.width != 0.0 else {
                    self.removeRightPillGlass(pill, slot: slot, inPlace: inPlaceRight.contains(slot), leaving: leavingRight[slot], tintColor: tintColor, isDark: isDark, transition: transition)
                    continue
                }
                let background: GlassContextExtractableContainer
                var backgroundTransition = transition
                var isNew = false
                if let current = pill.background {
                    background = current
                } else {
                    isNew = true
                    backgroundTransition = backgroundTransition.withAnimation(.none)
                    background = GlassContextExtractableContainer()
                    pill.background = background
                    self.addSubview(background)
                    background.contentView.addSubview(pill.itemsContainer)
                    background.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: false, transition: .immediate)
                }
                if inPlaceRight.contains(slot) {
                    self.startInPlaceChange(container: background, slot: .right(slot), isNew: isNew, frame: frame, tintColor: tintColor, isDark: isDark, leaving: leavingRight[slot])
                } else if let inPlace = self.inPlaceCapsule(for: background) {
                    self.retargetInPlace(inPlace, frame: frame, tintColor: tintColor, isDark: isDark, transition: transition)
                } else {
                    backgroundTransition.setFrame(view: background, frame: frame)
                    background.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, transition: transition)
                    backgroundTransition.setFrame(view: pill.itemsContainer, frame: CGRect(origin: CGPoint(), size: frame.size))
                }
                background.morphsIntoContextMenu = buttonCount == 1
            }
            // Pills the row no longer has.
            for slot in rightPillMetrics.count ..< self.rightPills.count {
                let pill = self.rightPills[slot]
                self.removeRightPillGlass(pill, slot: slot, inPlace: inPlaceRight.contains(slot), leaving: leavingRight[slot], tintColor: navigationBarGlassTintColor(pill.appliedTint, theme: component.theme), isDark: isDark, transition: transition)
            }
            // A secondary content sliding out: its items fade where they are, right-aligned in the pill they leave.
            if let removedSecondaryContentView {
                for (index, container) in removedSecondaryContentView.rightPillContainers.enumerated() where index < removedSecondaryContentView.rightPillWidths.count {
                    if let slot = self.rightPills.firstIndex(where: { $0.itemsContainer === container.superview }), slot < rightPillMetrics.count {
                        let width = removedSecondaryContentView.rightPillWidths[index]
                        transition.setFrame(view: container, frame: CGRect(x: rightPillMetrics[slot].width - width, y: 0.0, width: width, height: 44.0))
                    }
                }
            }

            self.updateSideColumn(component: component, transition: transition)
            if self.plattersDetached {
                // Capsules this layout created stay out too.
                self.applyPlattersDetached()
            }
            
            return availableSize
        }

        /// A right pill's glass goes: dematerializing in place for an in-place change, else fading out with the layout.
        private func removeRightPillGlass(_ pill: NavigationBarRightPill, slot: Int, inPlace: Bool, leaving: NavigationBarInPlaceCapsule.Items?, tintColor: GlassBackgroundView.TintColor, isDark: Bool, transition: ComponentTransition) {
            guard let background = pill.background else {
                return
            }
            pill.background = nil
            if inPlace {
                self.startInPlaceRemoval(container: background, slot: .right(slot), tintColor: tintColor, isDark: isDark, leaving: leaving)
            } else {
                background.update(size: background.bounds.size, cornerRadius: background.bounds.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: false, transition: transition)
                transition.attachAnimation(view: background, id: "remove", completion: { [weak background] _ in
                    background?.removeFromSuperview()
                })
            }
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
