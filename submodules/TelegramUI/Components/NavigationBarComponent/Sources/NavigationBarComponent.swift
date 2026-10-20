import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import SideColumnLayout

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

/// The navigation bar's 44pt row and iPhone Duo side column: title, back, left and right buttons in glass
/// capsules, and the in-bar slide between a primary and a secondary content. Hosts own the backdrop, where the
/// row sits, and the container the column hangs in (`sideColumnView`).
public struct NavigationBarLentCapsule {
    public let frame: CGRect
    public let pressScale: CGFloat
    public let tint: GlassBackgroundView.TintColor
    public let isDark: Bool
    public let content: UIView?
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
        /// Whether a glass container merges the shapes in it (native glass), read as each in-place merge starts.
        var glassMergesShapes: () -> Bool = {
            return GlassBackgroundContainerView.mergesShapes
        }
        /// The in-place animator's clock (animation seconds since the bar was made), for its matched morphs' curves.
        var inPlaceTime: Double = 0.0
        /// Where two pills' glass merges during an in-place matched morph, at the bar's platter smoothness; made on first
        /// use, below the pills, spanning the bar.
        var inPlaceMergeContainer: GlassBackgroundContainerView?
        /// The press UIKit was drawing on each capsule as the layout began (by container), read before this layout's own
        /// changes touch the glass, for a merge or a retint to carry on.
        var inPlacePressAtChange: [ObjectIdentifier: NavigationBarCapsulePress] = [:]
        /// Reads UIKit's press on a capsule for an in-place change (tests count the reads).
        var inPlacePressReader: (GlassContextExtractableContainer) -> NavigationBarCapsulePress = { container in
            return navigationBarCapsulePress(container)
        }
        /// Whether this layout's in-place tint changes are cross-faded by the bar rather than by UIKit: in a layout where
        /// pills merge (`NavigationBarInPlaceCapsule.tintFade`).
        var inPlaceTintByHand = false
        /// Capsules animating an in-place change of their items, as iOS 27's glass does (see `startInPlace…`).
        var inPlaceCapsules: [NavigationBarInPlaceCapsule] = []
        var inPlaceLink: SharedDisplayLinkDriver.Link?
        var inPlaceLastTime: Double?
        /// Run when the last capsule animating in place settles (`afterInPlaceAnimations`).
        var inPlaceEndActions: [() -> Void] = []
        /// A capsule appeared in place since the capsules last settled (`glassNeedsReadaptation`).
        var inPlaceCapsuleAppeared = false
        /// Asks the host to make its glass adapt again (`GlassBackgroundContainerView.readaptToBackdrop`). A capsule
        /// whose glass appeared in place (UIKit materializing it, or growing out of a neighbour's) is glass UIKit only
        /// half takes in: a context menu morphing out of it left the capsule's glass on screen behind the menu (the
        /// profile's "…" with its Media tab). Asked once the capsules have settled.
        public var glassNeedsReadaptation: (() -> Void)?
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
                        // UIKit is drawing on one (the button that started the transition) goes on in the transition, and
                        // so does one the bar is continuing on a renewed glass (UIKit's ended with the old glass).
                        let time = self.inPlaceTime
                        let barLeftPress = self.leftButtonsBackgroundContainer.flatMap { self.inPlaceCapsule(for: $0)?.press?.value(at: time) } ?? 1.0
                        let barRightPresses = self.rightPills.map { pill in pill.background.flatMap { self.inPlaceCapsule(for: $0)?.press?.value(at: time) } ?? 1.0 }
                        self.finishInPlaceAnimations()
                        let now = self.pressSamplerClock()
                        var leftScale = self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
                        var rightScales = self.rightPills.map { $0.background.flatMap(navigationBarCapsulePressScale) ?? 1.0 }
                        // A press UIKit has already taken off (the touch just ended) is in the last sample, unless the bar
                        // took that press over when it renewed the glass (then the sample and the bar's press are one).
                        if let sample = self.lastPressSample, now - sample.time < 0.1 {
                            if abs(leftScale - 1.0) < 0.0005 && abs(barLeftPress - 1.0) < 0.0005 {
                                leftScale = sample.left
                            }
                            for index in rightScales.indices where abs(rightScales[index] - 1.0) < 0.0005 && abs(barRightPresses[index] - 1.0) < 0.0005 && index < sample.right.count {
                                rightScales[index] = sample.right[index]
                            }
                        }
                        self.lastPressSample = nil
                        // The glow is UIKit's alone: the bar draws none with the press it continues.
                        self.detachedLeftPressGlow = navigationBarCapsulePressGlow(self.leftButtonsBackgroundContainer, press: leftScale)
                        self.detachedRightPressGlows = zip(self.rightPills, rightScales).map { navigationBarCapsulePressGlow($0.background, press: $1) }
                        self.detachedLeftPressScale = leftScale * barLeftPress
                        self.detachedRightPressScales = zip(rightScales, barRightPresses).map { $0 * $1 }
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

        /// The glass capsule a right button's view sits in (a right pill; on iPhone Duo the side column's capsule, a 48 pt
        /// circle around a single button, or its trailing circle), and the press UIKit draws on it: the one handed to a
        /// transition while the platters are detached, else the live one, else the sampler's while UIKit has only just
        /// taken it off (a tap's press is gone before the button's action runs, and an expansion asks before the bar
        /// detaches).
        public func rightButtonCapsule(containing view: UIView) -> (container: UIView, pressScale: CGFloat)? {
            for (index, pill) in self.rightPills.enumerated() {
                if let background = pill.background, view.isDescendant(of: background) {
                    if self.plattersDetached {
                        return (background, index < self.detachedRightPressScales.count ? self.detachedRightPressScales[index] : 1.0)
                    }
                    return (background, self.pressScale(of: background))
                }
            }
            for container in [self.columnButtonsBackgroundContainer, self.columnTrailingBackgroundContainer].compactMap({ $0 }) where view.isDescendant(of: container) {
                return (container, self.pressScale(of: container))
            }
            return nil
        }

        /// The press UIKit draws on `container`, or the sampler's last one while it is recent (see `rightButtonCapsule`).
        private func pressScale(of container: GlassContextExtractableContainer) -> CGFloat {
            let live = navigationBarCapsulePressScale(container)
            if abs(live - 1.0) >= 0.0005 {
                return live
            }
            if let sample = self.lastPressSample, self.pressSamplerClock() - sample.time < 0.1, let sampled = sample.byContainer[ObjectIdentifier(container)] {
                return sampled
            }
            return 1.0
        }

        /// UIKit draws a capsule's press (on a short tap) only as a running animation on its glass, which it takes off
        /// when the touch ends, before the button's action runs (measured 2026-10-14): when that action starts a
        /// transition there is nothing left to read. So while a touch is in a capsule the press is sampled every frame,
        /// and detaching (and `rightButtonCapsule`, asked before it) takes the last pressed sample.
        private var pressSamplerLink: SharedDisplayLinkDriver.Link?
        private var pressSamplerDeadline: Double = 0.0
        private var lastPressSample: (left: CGFloat, right: [CGFloat], byContainer: [ObjectIdentifier: CGFloat], time: Double)?
        /// The press sampler's clock (tests replace it).
        var pressSamplerClock: () -> Double = {
            return CACurrentMediaTime()
        }

        private func samplePress() {
            let now = self.pressSamplerClock()
            let left = self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
            let right = self.rightPills.map { $0.background.flatMap(navigationBarCapsulePressScale) ?? 1.0 }
            // Every capsule's, by its glass, for `rightButtonCapsule`; the column's (iPhone Duo) are only here.
            var byContainer: [ObjectIdentifier: CGFloat] = [:]
            let containers = ([self.leftButtonsBackgroundContainer, self.columnButtonsBackgroundContainer, self.columnTrailingBackgroundContainer] + self.rightPills.map(\.background)).compactMap { $0 }
            for container in containers {
                byContainer[ObjectIdentifier(container)] = navigationBarCapsulePressScale(container)
            }
            if byContainer.values.allSatisfy({ abs($0 - 1.0) < 0.0005 }) {
                if let sample = self.lastPressSample, now - sample.time < 0.1 {
                    // The press was just taken off: keep the last pressed sample for the hand-over.
                    return
                }
            } else {
                // A press held past the first window: its end is what the hand-over needs.
                self.pressSamplerDeadline = max(self.pressSamplerDeadline, now + 0.5)
            }
            self.lastPressSample = (left, right, byContainer, now)
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

        public private(set) var isLeftCapsuleLent: Bool = false

        private weak var lentColumnButtonView: UIView?

        private func lendColumnLeftButton(in view: UIView, component: NavigationBarComponent) -> NavigationBarLentCapsule? {
            guard let capsule = self.columnButtonsBackgroundContainer, capsule.superview != nil, capsule.alpha > 0.0, let contentView = self.effectiveContentView else {
                return nil
            }
            guard let buttonView = contentView.leftButtonViews.values.compactMap({ $0.view }).first(where: { $0.isDescendant(of: capsule) && !$0.isHidden }) else {
                return nil
            }
            let buttonFrame = buttonView.convert(buttonView.bounds, to: view)
            let capsuleFrame = capsule.convert(capsule.bounds, to: view)
            let side = capsuleFrame.width
            let frame = CGRect(x: capsuleFrame.minX, y: buttonFrame.midY - side * 0.5, width: side, height: side)
            var content: UIView?
            if let snapshot = buttonView.snapshotView(afterScreenUpdates: false) {
                snapshot.frame = buttonFrame
                content = snapshot
            }
            let tint = navigationBarGlassTintColor(.generic, theme: component.theme)
            buttonView.isHidden = true
            self.lentColumnButtonView = buttonView
            self.isLeftCapsuleLent = true
            return NavigationBarLentCapsule(frame: frame, pressScale: 1.0, tint: tint, isDark: component.theme.overallDarkAppearance, content: content)
        }

        public func lendLeftCapsule(in view: UIView) -> NavigationBarLentCapsule? {
            guard !self.isLeftCapsuleLent, let component = self.component else {
                return nil
            }
            guard let container = self.leftButtonsBackgroundContainer, container.superview != nil else {
                return self.lendColumnLeftButton(in: view, component: component)
            }
            let barPress = self.inPlaceCapsule(for: container)?.press?.value(at: self.inPlaceTime) ?? 1.0
            var scale = navigationBarCapsulePressScale(container)
            if abs(scale - 1.0) < 0.0005, abs(barPress - 1.0) < 0.0005, let sample = self.lastPressSample, self.pressSamplerClock() - sample.time < 0.1 {
                scale = sample.left
            }
            let frame = container.convert(container.bounds, to: view)
            var content: UIView?
            if let snapshot = self.leftButtonsContainer.snapshotView(afterScreenUpdates: false) {
                snapshot.frame = self.leftButtonsContainer.convert(self.leftButtonsContainer.bounds, to: view)
                content = snapshot
            }
            let tint = navigationBarGlassTintColor(self.effectiveContentView?.leftCapsuleTint ?? .generic, theme: component.theme)
            self.isLeftCapsuleLent = true
            self.applyPlattersDetached()
            return NavigationBarLentCapsule(frame: frame, pressScale: scale * barPress, tint: tint, isDark: component.theme.overallDarkAppearance, content: content)
        }

        public func returnLeftCapsule() {
            guard self.isLeftCapsuleLent else {
                return
            }
            self.isLeftCapsuleLent = false
            if let buttonView = self.lentColumnButtonView {
                self.lentColumnButtonView = nil
                buttonView.isHidden = false
            }
            self.applyPlattersDetached()
        }

        private func applyPlattersDetached() {
            let containers: [UIView] = ([self.leftButtonsBackgroundContainer].compactMap { $0 } as [UIView]) + self.rightBackgroundContainers
            for container in containers {
                if self.plattersDetached || (self.isLeftCapsuleLent && container === self.leftButtonsBackgroundContainer) {
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

        /// The row's back (or close) button, if it shows one.
        public var backButtonView: UIView? {
            return self.effectiveContentView?.backButtonView
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
        /// The primary content's right side: every right pill and UIKit's gaps between them.
        public var primaryRightButtonsWidth: CGFloat {
            guard let contentView = self.primaryContentView else {
                return 0.0
            }
            return navigationBarRightButtonsExtent(navigationBarRightPillMetrics(widths: contentView.rightPillWidths))
        }

        /// Whether the primary content's row leaves a title pill a right platter slot in a transition: fewer than two right
        /// pills (two take both slots).
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
            if self.inPlaceCapsules.contains(where: { $0.lentGlass != nil }) {
                // A context menu extracts a pill's own glass: a merge in progress ends first.
                self.finishInPlaceAnimations()
            }
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

        /// Hit-tests the side column (`point` in `sideColumnView`), which hangs outside this view and is asked by its host:
        /// a touch in one of its capsules (the chat's avatar) may be about to be pressed by UIKit, as one in a row capsule.
        public func sideColumnHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = self.sideColumnView.hitTest(point, with: event) else {
                return nil
            }
            if event.flatMap({ $0.type == .touches }) ?? true, [self.columnButtonsBackgroundContainer, self.columnTrailingBackgroundContainer].contains(where: { container in
                guard let container else {
                    return false
                }
                return result.isDescendant(of: container) || result.isDescendant(of: container.contentView)
            }) {
                self.beginPressSampling()
            }
            return result
        }

        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            for subview in self.subviews.reversed() {
                if !subview.isUserInteractionEnabled || subview.alpha < 0.01 || subview.isHidden {
                    continue
                }
                if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                    // A touch (not a pointer hovering) in a capsule: UIKit may be about to press it. A pill's content
                    // goes with its glass while the glass is lent to a merge.
                    if event.flatMap({ $0.type == .touches }) ?? true {
                        if let left = self.leftButtonsBackgroundContainer, result.isDescendant(of: left) {
                            self.beginPressSampling()
                        } else if self.rightBackgroundContainers.contains(where: { result.isDescendant(of: $0) || result.isDescendant(of: $0.contentView) }) {
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
            // Whether a right pill comes or goes in place, merging with its neighbour.
            var inPlaceRightPillCountChanges = false
            if let previousPrimary = previousComponent?.primaryContent, let primary = component.primaryContent, component.secondaryContent == nil, previousComponent?.secondaryContent == nil, component.sideColumnLength == nil, previousComponent?.sideColumnLength == nil, !self.plattersDetached {
                if !transition.animation.isImmediate {
                    inPlaceLeft = previousPrimary.back != primary.back || navigationBarCapsuleItemsDiffer(previousPrimary.leftButton.map { [$0] } ?? [], primary.leftButton.map { [$0] } ?? [])
                    // UIKit's sections change apart, compared by index from the edge.
                    let previousSections = navigationBarButtonPlacement(leftButton: previousPrimary.leftButton, rightButtons: previousPrimary.rightButtons, hasBack: previousPrimary.back != nil, columnLength: nil).rowRightSections
                    let sections = navigationBarButtonPlacement(leftButton: primary.leftButton, rightButtons: primary.rightButtons, hasBack: primary.back != nil, columnLength: nil).rowRightSections
                    inPlaceRightPillCountChanges = previousSections.count != sections.count
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
            // Read only for a change in place (reading walks each glass's layers, and a slide lays the bar out every frame); a
            // later retint or merge reads it on demand.
            if inPlaceLeft || !inPlaceRight.isEmpty {
                self.inPlacePressAtChange = Dictionary(([self.leftButtonsBackgroundContainer].compactMap { $0 } + self.rightBackgroundContainers).map { (ObjectIdentifier($0), self.inPlacePressReader($0)) }, uniquingKeysWith: { lhs, _ in lhs })
            }
            self.inPlaceTintByHand = inPlaceRightPillCountChanges && self.glassMergesShapes() && !self.inPlaceReduceMotion()
            // A glass UIKit is pressing keeps its own edge inside a merged shape, so in a layout where pills merge a pressed
            // pill's glass is renewed before the layout touches it; the merge carries the press's scale on
            // (`lendInPlaceGlass`).
            if self.inPlaceTintByHand {
                for container in self.rightBackgroundContainers where self.inPlacePressAtChange[ObjectIdentifier(container)]?.isPressed == true {
                    container.renewGlass()
                }
            }
            defer {
                self.inPlacePressAtChange = [:]
                self.inPlaceTintByHand = false
            }
            // Where each right pill is now and its tint, for a pill that grows out of one of them.
            let previousRightPills: [(frame: CGRect, tint: NavigationBarComponent.Button.Tint)?] = self.rightPills.map { pill in
                guard let background = pill.background else {
                    return nil
                }
                return (self.inPlaceCapsule(for: background)?.frame(at: self.inPlaceTime) ?? background.frame, pill.appliedTint)
            }

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
                // A menu from any of its buttons morphs the whole capsule, as UIKit's does with a section of several items.
                leftButtonsBackgroundContainer.morphsIntoContextMenu = leftButtonCount != 0
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
            var rightPillTargets: [(slot: Int, frame: CGRect, tint: NavigationBarComponent.Button.Tint)] = []
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
                    self.removeRightPillGlass(pill, slot: slot, inPlace: inPlaceRight.contains(slot), leaving: leavingRight[slot], partner: nil, tintColor: tintColor, isDark: isDark, transition: transition)
                    continue
                }
                rightPillTargets.append((slot, frame, tint))
                let background: GlassContextExtractableContainer
                var backgroundTransition = transition
                var isNew = false
                // A pill that was leaving and comes back is the same pill, as SwiftUI's resolver reuses a removed entry.
                let returning = pill.background == nil && inPlaceRight.contains(slot) && !self.inPlaceReduceMotion() ? self.inPlaceCapsules.first(where: { $0.slot == .right(slot) && $0.isRemoved && $0.matched?.partner != nil }) : nil
                if let current = pill.background {
                    background = current
                } else if let returning, let partner = returning.matched?.partner {
                    background = returning.container
                    pill.background = background
                    if pill.itemsContainer.superview !== background.contentView {
                        background.contentView.addSubview(pill.itemsContainer)
                    }
                    let partnerFrame = self.inPlaceCapsule(for: partner)?.frame(at: self.inPlaceTime) ?? partner.frame
                    let partnerSlot = self.rightPills.firstIndex(where: { $0.background === partner })
                    let partnerTint = partnerSlot.map { navigationBarGlassTintColor(self.rightPills[$0].appliedTint, theme: component.theme) } ?? tintColor
                    let partnerMove = (from: partnerSlot.flatMap { $0 < previousRightPills.count ? previousRightPills[$0]?.frame : nil } ?? partnerFrame, to: rightPillTargets.first(where: { $0.slot == partnerSlot })?.frame ?? partnerFrame)
                    self.startInPlaceMatched(container: background, slot: .right(slot), isRemoval: false, frame: frame, source: returning.frame(at: self.inPlaceTime), partner: partner, partnerFrame: partnerFrame, partnerMove: partnerMove, partnerTintColor: partnerTint, tintColor: tintColor, isDark: isDark, leaving: nil)
                    background.morphsIntoContextMenu = buttonCount != 0
                    continue
                } else {
                    isNew = true
                    backgroundTransition = backgroundTransition.withAnimation(.none)
                    background = GlassContextExtractableContainer()
                    pill.background = background
                    self.addSubview(background)
                    background.contentView.addSubview(pill.itemsContainer)
                    background.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: false, transition: .immediate)
                }
                // A pill that comes grows out of the nearest previous pill nearer the edge (UIKit's sections are
                // contiguous, so that is every one).
                let previousPartners: [(slot: Int, frame: CGRect, tint: NavigationBarComponent.Button.Tint)] = previousRightPills.enumerated().compactMap { index, previous in
                    guard let previous, index < slot else {
                        return nil
                    }
                    return (index, previous.frame, previous.tint)
                }
                if isNew, inPlaceRight.contains(slot), !self.inPlaceReduceMotion(), let nearest = navigationBarNearestPartner(of: frame, among: previousPartners.map(\.frame)), let partner = self.rightPillBackgroundContainer(at: previousPartners[nearest].slot) {
                    let partnerFrame = previousPartners[nearest].frame
                    let partnerMove = (from: partnerFrame, to: rightPillTargets.first(where: { $0.slot == previousPartners[nearest].slot })?.frame ?? partnerFrame)
                    self.startInPlaceMatched(container: background, slot: .right(slot), isRemoval: false, frame: frame, partner: partner, partnerFrame: partnerFrame, partnerMove: partnerMove, partnerTintColor: navigationBarGlassTintColor(previousPartners[nearest].tint, theme: component.theme), tintColor: tintColor, isDark: isDark, leaving: nil)
                } else if inPlaceRight.contains(slot) {
                    self.startInPlaceChange(container: background, slot: .right(slot), isNew: isNew, frame: frame, tintColor: tintColor, isDark: isDark, leaving: leavingRight[slot])
                } else if let inPlace = self.inPlaceCapsule(for: background) {
                    self.retargetInPlace(inPlace, frame: frame, tintColor: tintColor, isDark: isDark, transition: transition)
                } else {
                    backgroundTransition.setFrame(view: background, frame: frame)
                    background.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, transition: transition)
                    backgroundTransition.setFrame(view: pill.itemsContainer, frame: CGRect(origin: CGPoint(), size: frame.size))
                }
                // A menu from any of its buttons morphs the whole pill, its other buttons with it, and closes back into it:
                // UIKit's with a section of several items (measured on iOS 27, Saved Messages' [search, …]).
                background.morphsIntoContextMenu = buttonCount != 0
            }
            // Pills the row no longer has.
            for slot in rightPillMetrics.count ..< self.rightPills.count {
                let pill = self.rightPills[slot]
                // A pill that goes collapses into the nearest remaining pill nearer the edge.
                var partner: (container: GlassContextExtractableContainer, frame: CGRect, source: CGRect, tintColor: GlassBackgroundView.TintColor)?
                let ownFrame = slot < previousRightPills.count ? previousRightPills[slot]?.frame : nil
                let candidates = rightPillTargets.filter { $0.slot < slot }
                if let ownFrame, !self.inPlaceReduceMotion(), let nearest = navigationBarNearestPartner(of: ownFrame, among: candidates.map(\.frame)), let container = self.rightPillBackgroundContainer(at: candidates[nearest].slot) {
                    let partnerSlot = candidates[nearest].slot
                    let source = (partnerSlot < previousRightPills.count ? previousRightPills[partnerSlot]?.frame : nil) ?? candidates[nearest].frame
                    partner = (container, candidates[nearest].frame, source, navigationBarGlassTintColor(candidates[nearest].tint, theme: component.theme))
                }
                self.removeRightPillGlass(pill, slot: slot, inPlace: inPlaceRight.contains(slot), leaving: leavingRight[slot], partner: partner, tintColor: navigationBarGlassTintColor(pill.appliedTint, theme: component.theme), isDark: isDark, transition: transition)
            }
            // A pill going into its partner heads for where the partner is now (a relayout mid-merge moves it).
            self.followInPlacePartners(barSize: availableSize, isDark: isDark)
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
            if self.plattersDetached || self.isLeftCapsuleLent {
                // Capsules this layout created stay out too.
                self.applyPlattersDetached()
            }
            
            return availableSize
        }

        /// A right pill's glass goes: dematerializing in place for an in-place change, else fading out with the layout.
        /// A pill going into `partner` heads for its `frame`; the partner is at `source` now.
        private func removeRightPillGlass(_ pill: NavigationBarRightPill, slot: Int, inPlace: Bool, leaving: NavigationBarInPlaceCapsule.Items?, partner: (container: GlassContextExtractableContainer, frame: CGRect, source: CGRect, tintColor: GlassBackgroundView.TintColor)?, tintColor: GlassBackgroundView.TintColor, isDark: Bool, transition: ComponentTransition) {
            guard let background = pill.background else {
                return
            }
            pill.background = nil
            if inPlace, let partner {
                self.startInPlaceMatched(container: background, slot: .right(slot), isRemoval: true, frame: background.frame, partner: partner.container, partnerFrame: partner.frame, partnerMove: (partner.source, partner.frame), partnerTintColor: partner.tintColor, tintColor: tintColor, isDark: isDark, leaving: leaving)
            } else if inPlace {
                self.startInPlaceRemoval(container: background, slot: .right(slot), tintColor: tintColor, isDark: isDark, leaving: leaving)
            } else {
                // Taken away by a layout that does not animate in place: a merge it is in ends here.
                self.finishInPlace(of: background)
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
                    // Alpha does not hide native glass: a new circle materializes through `isVisible`, as the row's pills do.
                    backBackgroundContainer.update(size: backFrame.size, cornerRadius: backFrame.height * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, isVisible: false, transition: .immediate)
                }
                backTransition.setFrame(view: backBackgroundContainer, frame: backFrame)
                backBackgroundContainer.update(size: backFrame.size, cornerRadius: backFrame.height * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, transition: transition)
                backTransition.setFrame(view: self.columnBackContainer, frame: backFrame)
                for (contentView, _) in contents {
                    backTransition.setFrame(view: contentView.columnBackContainer, frame: backFrame)
                }
                transition.setAlpha(view: backBackgroundContainer, alpha: backAlpha)
            } else if let backBackgroundContainer = self.columnBackBackgroundContainer {
                self.columnBackBackgroundContainer = nil
                backBackgroundContainer.update(size: backBackgroundContainer.bounds.size, cornerRadius: backBackgroundContainer.bounds.height * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, isVisible: false, transition: transition)
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
                    capsuleBackgroundContainer.update(size: capsuleFrame.size, cornerRadius: capsuleFrame.width * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, isVisible: false, transition: .immediate)
                }
                capsuleTransition.setFrame(view: capsuleBackgroundContainer, frame: capsuleFrame)
                capsuleBackgroundContainer.update(size: capsuleFrame.size, cornerRadius: capsuleFrame.width * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, isVisible: !component.hidesSideColumnButtons, transition: transition)
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
                capsuleBackgroundContainer.update(size: capsuleBackgroundContainer.bounds.size, cornerRadius: capsuleBackgroundContainer.bounds.width * 0.5, isDark: isDark, tintColor: genericTintColor, isInteractive: true, isVisible: false, transition: transition)
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
                    trailingBackgroundContainer.update(size: trailingFrame.size, cornerRadius: trailingFrame.height * 0.5, isDark: isDark, tintColor: navigationBarGlassTintColor(trailingTint, theme: component.theme), isInteractive: true, isVisible: false, transition: .immediate)
                }
                trailingTransition.setFrame(view: trailingBackgroundContainer, frame: trailingFrame)
                trailingBackgroundContainer.update(size: trailingFrame.size, cornerRadius: trailingFrame.height * 0.5, isDark: isDark, tintColor: navigationBarGlassTintColor(trailingTint, theme: component.theme), isInteractive: true, isVisible: !component.hidesSideColumnButtons, transition: transition)
                trailingBackgroundContainer.morphsIntoContextMenu = true
                trailingTransition.setFrame(view: self.columnTrailingContainer, frame: CGRect(origin: CGPoint(), size: trailingFrame.size))
                for (contentView, _) in contents {
                    trailingTransition.setFrame(view: contentView.columnTrailingContainer, frame: CGRect(origin: CGPoint(), size: trailingFrame.size))
                }
                transition.setAlpha(view: trailingBackgroundContainer, alpha: component.hidesSideColumnButtons ? 0.0 : trailingAlpha)
                trailingBackgroundContainer.isUserInteractionEnabled = !component.hidesSideColumnButtons
            } else if let trailingBackgroundContainer = self.columnTrailingBackgroundContainer {
                self.columnTrailingBackgroundContainer = nil
                trailingBackgroundContainer.update(size: trailingBackgroundContainer.bounds.size, cornerRadius: trailingBackgroundContainer.bounds.height * 0.5, isDark: isDark, tintColor: trailingBackgroundContainer.glassTintColor ?? genericTintColor, isInteractive: true, isVisible: false, transition: transition)
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
