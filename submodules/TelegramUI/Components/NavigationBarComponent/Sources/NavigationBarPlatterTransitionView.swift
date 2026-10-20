import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// The glass capsules of a navigation transition between two bars, animated as iOS 27 does it: SwiftUI's GlassContainer
/// under the bar's v2 platter container, with the toolbar settings (see
/// docs/superpowers/specs/2026-10-13-native-navigation-glass-platters-ios27-re.md).
///
/// Capsules are matched between the two bars by role (leading: back and left button; trailing: the outermost right
/// platter, the accent circle when there is one; trailing inner: the capsule beside it), as UIKit pairs `SectionID`s by
/// index from the edge. iPhone Duo's column shapes pair the same way, by index from the column's top: Chats' story
/// capsule and compose circle become the chat's back circle and avatar capsule in place.
/// - **Present on both bars:** one glass shape that morphs to the new frame on `Spring(0.416, bounce 0.25)`. If the
///   items changed, the old ones shrink away and the new ones grow in (matched items: scale 0.2, transparent, blur 10,
///   on the same spring), the shape gives SwiftUI's scale pulse, and a tint change cross-fades on the one shape.
/// - **Present on one bar:** materializes or dematerializes in place: scale 1.2 (at most 16 pt larger per axis),
///   opacity 0 and blur 10 ↔ identity, on the same `Spring(0.416, bounce 0.25)` (measured, glass RE §2.2; under
///   Reduce Motion without the bounce). Except the capsule beside an accent circle, which collapses into the other bar's
///   outermost right platter after UIKit's minimum delay, or grows out of it at once, with the kick and the `.match`
///   appearance (`startMatchedMorph`). Its glass merges with that platter's meanwhile, as iOS 27's does: the bar's
///   platters are elements of one SDF layer at smoothness 12, and the collapsing one keeps opacity 1 while its frame
///   shrinks into the other (measured). So the two right platters' glass shares one container at that spacing, drawn at
///   its scaled frame, and only the items fade. A title pill never does: without a platter in its slot on the other bar
///   it materializes or dematerializes in place.
///
/// Measured against the native reference app on iOS 27 (`Tests/NativeNavigationReference`): Edit → Done swells the
/// capsule by ~21% (height peak at ~0.11 s, width at ~0.15 s, width undershoot ~5% at ~0.33 s) and cross-fades its
/// tint in ~0.2 s.
///
/// None of this follows the transition's progress: UIKit hands the destination capsules over when a push or pop
/// starts, and the springs run in time. A swipe back is the exception. The outgoing bar's capsules are pulled toward
/// their counterparts by half the progress, on `Spring(0.2, 0)`, and the sets switch only on release or cancel.
public final class NavigationBarPlatterTransitionView: UIView {
    public struct Side {
        public var content: NavigationBarComponent.Content
        public var theme: NavigationBarTheme
        public var strings: NavigationBarStrings
        public var leftInset: CGFloat
        public var rightInset: CGFloat
        public var trailingButtonsInset: CGFloat
        /// The bar's row in this view.
        public var rowFrame: CGRect
        /// The press UIKit was drawing on the leading capsule when the bar gave its capsules to the transition (1: none), as
        /// the bar measured it (`NavigationBarComponent.View.detachedLeftPressScale`).
        public var leadingPressScale: CGFloat
        /// UIKit's press glow on the leading capsule at that moment (its BigGlow's opacity, 0: none), as the bar measured
        /// it (`NavigationBarComponent.View.detachedLeftPressGlow`).
        public var leadingPressGlow: CGFloat
        /// The press and glow on each right platter, index from the edge (`detachedRightPressScales`,
        /// `detachedRightPressGlows`; missing: none).
        public var trailingPressScales: [CGFloat]
        public var trailingPressGlows: [CGFloat]
        /// iPhone Duo: the bar's side column region in this view (its capsules are drawn like the row's); nil without one.
        public var columnFrame: CGRect?
        /// The bar hides its column's buttons (a replacement content, such as an active search).
        public var hidesColumnButtons: Bool
        /// The title's glass pill (the chat header), its frame in this view: the bar's second right platter.
        public var titlePill: NavigationBarTransitionTitlePill?

        public init(content: NavigationBarComponent.Content, theme: NavigationBarTheme, strings: NavigationBarStrings, leftInset: CGFloat, rightInset: CGFloat, trailingButtonsInset: CGFloat, rowFrame: CGRect, leadingPressScale: CGFloat = 1.0, leadingPressGlow: CGFloat = 0.0, trailingPressScales: [CGFloat] = [], trailingPressGlows: [CGFloat] = [], columnFrame: CGRect? = nil, hidesColumnButtons: Bool = false, titlePill: NavigationBarTransitionTitlePill? = nil) {
            self.titlePill = titlePill
            self.content = content
            self.theme = theme
            self.strings = strings
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.trailingButtonsInset = trailingButtonsInset
            self.rowFrame = rowFrame
            self.leadingPressScale = leadingPressScale
            self.leadingPressGlow = leadingPressGlow
            self.trailingPressScales = trailingPressScales
            self.trailingPressGlows = trailingPressGlows
            self.columnFrame = columnFrame
            self.hidesColumnButtons = hidesColumnButtons
        }
    }

    /// A capsule's place: the row's leading capsule, a right platter by index from the edge (UIKit's
    /// `SectionID(index, owner)`: 0 the outermost), and an iPhone Duo column shape by index from the column's top (the
    /// back circle, buttons capsule and trailing circle a bar has, in that order).
    enum Role: Hashable {
        case leading
        case trailing(Int)
        case column(Int)

        /// Every role, with right platters up to `rightCount` and column shapes up to `columnCount`.
        static func all(rightCount: Int, columnCount: Int) -> [Role] {
            return [.leading] + (0 ..< rightCount).map { .trailing($0) } + (0 ..< columnCount).map { .column($0) }
        }

        var rightIndex: Int? {
            if case let .trailing(index) = self {
                return index
            }
            return nil
        }

        var columnIndex: Int? {
            if case let .column(index) = self {
                return index
            }
            return nil
        }
    }

    private enum SideKind {
        case bottom
        case top
    }

    /// One bar's items in a capsule, at the frame they have in that bar.
    private final class Items {
        let side: SideKind
        let view: UIView
        var frame: CGRect
        /// 0: present, 1: dematerialized (transparent, blurred, scaled by `maxScale`).
        var appearance: NavigationSpringCurve
        /// The scale at 1: up to 1.2 for items appearing with their capsule, 0.2 for items swapped in a kept one.
        var maxScale: CGSize
        let blurRadius: CGFloat
        var isLeaving = false

        init(side: SideKind, view: UIView, frame: CGRect, appearance: CGFloat, motion: NavigationBarGlassMotion) {
            self.side = side
            self.view = view
            self.frame = frame
            self.appearance = .constant(appearance, rest: .glass(0.001))
            self.maxScale = motion.materializeScale(size: frame.size)
            self.blurRadius = motion.blurRadius
        }
    }

    private final class Platter {
        let role: Role
        /// The glass. A glass container's own alpha does hide its glass (a shape's does not), so each capsule has its
        /// own container; a tint change adds a second one with the old tint, fading out above it.
        let container: GlassBackgroundContainerView
        let glass: GlassBackgroundView
        var fadingContainer: GlassBackgroundContainerView?
        var fadingGlass: GlassBackgroundView?
        var fadingTint: GlassBackgroundView.TintColor?
        var tintFade = NavigationSpringCurve.constant(0.0, rest: .glass(0.001))
        /// The items, above both glass layers.
        let itemsHost: UIView
        var pulse: NavigationBarGlassPulseCurve?
        /// The press UIKit was drawing when the transition took the capsule, releasing (1: none).
        var press = NavigationSpringCurve.constant(1.0, rest: .glass(0.0005))
        /// UIKit's press glow taken over with the press, fading (0: none), and the view that draws it.
        var glow = NavigationSpringCurve.constant(0.0, rest: .glass(0.001))
        var glowView: NavigationBarPressGlowView?
        var x: NavigationSpringCurve
        var y: NavigationSpringCurve
        var width: NavigationSpringCurve
        var height: NavigationSpringCurve
        /// 0: present, 1: dematerialized (transparent, blurred, scaled up).
        var dematerialization: NavigationSpringCurve
        var maxScale = CGSize(width: 1.0, height: 1.0)
        var blurRadius = NavigationBarGlassSettings.blurRadius
        var tint: GlassBackgroundView.TintColor
        var isDark: Bool
        var items: [Items] = []
        var isLeaving = false
        /// SwiftUI's translation kick of a matched insertion or removal (`startMatchedMorph`).
        var kick: NavigationBarKickCurve?
        /// A matched insertion or removal: it grows out of, or collapses into, its `partner` (the nearest platter of the
        /// other bar nearer the edge), its glass merged with that one's (`mergesGlass`).
        var isMatched = false
        /// The platter a matched one collapses into or grows out of.
        var partner: Role?
        /// It is a bar's title pill (`SideLayout.titlePillRole`), which only morphs with a platter in its own slot.
        var isTitlePill = false

        init(role: Role, frame: CGRect, tint: GlassBackgroundView.TintColor, isDark: Bool) {
            self.role = role
            self.container = GlassBackgroundContainerView()
            self.container.isUserInteractionEnabled = false
            self.glass = GlassBackgroundView()
            self.container.contentView.addSubview(self.glass)
            self.itemsHost = UIView()
            self.itemsHost.isUserInteractionEnabled = false
            self.x = .constant(frame.minX, rest: .glass(0.01))
            self.y = .constant(frame.minY, rest: .glass(0.01))
            self.width = .constant(frame.width, rest: .glass(0.01))
            self.height = .constant(frame.height, rest: .glass(0.01))
            self.dematerialization = .constant(0.0, rest: .glass(0.001))
            self.tint = tint
            self.isDark = isDark
        }

        func frame(at time: Double) -> CGRect {
            let kick = self.kick?.translation(at: time) ?? CGSize()
            return CGRect(x: self.x.value(at: time) + kick.width, y: self.y.value(at: time) + kick.height, width: max(0.0, self.width.value(at: time)), height: max(0.0, self.height.value(at: time)))
        }

        /// The frame the shape draws at: its frame scaled about its centre by its appearance and its press, then about its
        /// pulse's anchor by its pulse.
        func glassFrame(at time: Double) -> CGRect {
            let frame = self.frame(at: time)
            let d = self.dematerialization.value(at: time)
            let press = self.press.value(at: time)
            let base = CGSize(width: frame.width * (1.0 + d * (self.maxScale.width - 1.0)) * press, height: frame.height * (1.0 + d * (self.maxScale.height - 1.0)) * press)
            let pulse = self.pulse?.scale(at: time) ?? CGSize(width: 1.0, height: 1.0)
            let anchor = self.pulse?.anchor ?? CGPoint(x: 0.5, y: 0.5)
            let size = CGSize(width: base.width * pulse.width, height: base.height * pulse.height)
            let fixed = CGPoint(x: frame.midX + (anchor.x - 0.5) * base.width, y: frame.midY + (anchor.y - 0.5) * base.height)
            return CGRect(x: fixed.x - anchor.x * size.width, y: fixed.y - anchor.y * size.height, width: size.width, height: size.height)
        }

        /// The transform that draws the shape's views (laid out at its frame) at `glassFrame`.
        func drawingTransform(at time: Double) -> CGAffineTransform {
            let frame = self.frame(at: time)
            let glassFrame = self.glassFrame(at: time)
            return CGAffineTransform(a: frame.width > 0.0 ? glassFrame.width / frame.width : 1.0, b: 0.0, c: 0.0, d: frame.height > 0.0 ? glassFrame.height / frame.height : 1.0, tx: glassFrame.midX - frame.midX, ty: glassFrame.midY - frame.midY)
        }

        func animateFrame(to frame: CGRect, spring: NavigationTransitionSpring, at time: Double) {
            self.x = self.x.retargeted(at: time, to: frame.minX, spring: spring)
            self.y = self.y.retargeted(at: time, to: frame.minY, spring: spring)
            self.width = self.width.retargeted(at: time, to: frame.width, spring: spring)
            self.height = self.height.retargeted(at: time, to: frame.height, spring: spring)
        }

        /// When every curve of this capsule rests.
        var restTime: Double {
            var result = max(self.x.restTime, self.y.restTime, self.width.restTime, self.height.restTime, self.dematerialization.restTime, self.press.restTime, self.glow.restTime, self.tintFade.restTime)
            if let pulse = self.pulse {
                result = max(result, pulse.restTime)
            }
            if let kick = self.kick {
                result = max(result, kick.restTime)
            }
            for items in self.items {
                result = max(result, items.appearance.restTime)
            }
            return result
        }

        /// Moves every curve onto a clock whose zero is this one's `time` (a new bake's origin).
        func rebase(by time: Double) {
            self.x = self.x.rebased(by: time)
            self.y = self.y.rebased(by: time)
            self.width = self.width.rebased(by: time)
            self.height = self.height.rebased(by: time)
            self.dematerialization = self.dematerialization.rebased(by: time)
            self.press = self.press.rebased(by: time)
            self.glow = self.glow.rebased(by: time)
            self.tintFade = self.tintFade.rebased(by: time)
            self.pulse = self.pulse?.rebased(by: time)
            self.kick = self.kick?.rebased(by: time)
            for items in self.items {
                items.appearance = items.appearance.rebased(by: time)
            }
        }

        /// Every curve at its target (the group has come to rest).
        func settle() {
            func settled(_ curve: NavigationSpringCurve) -> NavigationSpringCurve {
                return .constant(curve.target, rest: curve.rest)
            }
            self.x = settled(self.x)
            self.y = settled(self.y)
            self.width = settled(self.width)
            self.height = settled(self.height)
            self.dematerialization = settled(self.dematerialization)
            self.press = settled(self.press)
            self.glow = settled(self.glow)
            self.tintFade = settled(self.tintFade)
            self.pulse = nil
            self.kick = nil
            for items in self.items {
                items.appearance = settled(items.appearance)
            }
        }

        var views: [UIView] {
            return [self.container, self.fadingContainer, self.itemsHost].compactMap { $0 }
        }

        func removeViews() {
            for view in self.views {
                view.removeFromSuperview()
            }
            // The glass may be in the merged container rather than its own.
            self.glass.removeFromSuperview()
        }
    }

    private struct SideLayout {
        var frames: [Role: CGRect] = [:]
        var itemViews: [Role: UIView] = [:]
        var tints: [Role: GlassBackgroundView.TintColor] = [:]
        var signatures: [Role: [AnyHashable]] = [:]
        var isDark = false
        /// The slot the bar's title pill takes, if it has one there.
        var titlePillRole: Role?
    }

    private let bottomContentView = NavigationBarContentView(backPressed: {})
    private let topContentView = NavigationBarContentView(backPressed: {})
    private var bottomLayout = SideLayout()
    private var topLayout = SideLayout()
    /// iPhone Duo: each bar's column back circle items with the unread badge the bar draws on the circle's corner, so
    /// the badge materializes, morphs and swaps with the circle.
    private var columnBackWrappers: [SideKind: UIView] = [:]
    private var columnBadges: [SideKind: NavigationBarBadgeNode] = [:]
    private var bottomSide: Side?
    private var topSide: Side?
    private var platters: [Role: Platter] = [:]
    /// The container the right platters' glass merges in during a matched morph (`mergesGlass`), at the bar's platter
    /// smoothness: created on first use, below every capsule's own views, spanning this view.
    private var mergedGlassContainer: GlassBackgroundContainerView?
    private var isInteractive = false
    private var hasBegun = false
    private var fromSide: SideKind = .bottom
    private var toSide: SideKind = .top
    /// The time the capsules' curves are evaluated at: the clock's animation time at each entry point, the bake's
    /// end while a bake sets the model.
    private var time: Double = 0.0
    /// The clock the capsules' keyframes run on, their deadline its end.
    private lazy var clock: NavigationAnimationClock = {
        let clock = NavigationAnimationClock(hostView: self)
        clock.ended = { [weak self] in
            self?.clockEnded()
        }
        return clock
    }()
    var clockForTesting: NavigationAnimationClock {
        return self.clock
    }
    var hasDisplayLinkForTesting: Bool {
        return false
    }
    private static let keyPrefix = "navigationGlass."
    /// Called once when the capsules come to rest after animating (not while a swipe holds them); a begin that animates
    /// nothing reports nothing.
    public var onSettled: (() -> Void)?
    private var hasReportedSettled = true
    /// Whether a glass container merges the shapes in it (native glass), read as glass is hosted.
    var glassMergesShapes: () -> Bool = {
        return GlassBackgroundContainerView.mergesShapes
    }
    /// Reduce Motion, read as each animation starts.
    public var isReduceMotionEnabled: () -> Bool = {
        return UIAccessibility.isReduceMotionEnabled
    }
    private var motion: NavigationBarGlassMotion {
        return NavigationBarGlassMotion(reduce: self.isReduceMotionEnabled())
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        // The capsules show the bars' own screen nodes, lent by the transition's renderer.
        self.bottomContentView.borrowsNodes = true
        self.topContentView.borrowsNodes = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays out both bars' capsules. Call when either bar's content changes; capsules on screen follow on their springs.
    public func setSides(bottom: Side, top: Side) {
        // The items a capsule shows are its bar's own button containers, which the layout below updates in place. When
        // they change mid-transition (a list screen applies its buttons just after its push begins), the views they
        // showed leave, handed over live by the content view, while the new ones arrive, as in a kept capsule whose
        // items change.
        var changedItems: [(role: Role, kind: SideKind, leaving: UIView)] = []
        if self.hasBegun {
            self.time = self.now
        }
        if self.hasBegun {
            for (role, platter) in self.platters {
                for items in platter.items where !items.isLeaving {
                    let previous = items.side == .bottom ? self.bottomSide : self.topSide
                    let updated = items.side == .bottom ? bottom : top
                    guard let previous, navigationBarCapsuleSignature(previous.content, role: role, columnLength: previous.columnFrame?.height, hidesColumnButtons: previous.hidesColumnButtons) != navigationBarCapsuleSignature(updated.content, role: role, columnLength: updated.columnFrame?.height, hidesColumnButtons: updated.hidesColumnButtons) else {
                        continue
                    }
                    let contentView = items.side == .bottom ? self.bottomContentView : self.topContentView
                    guard let container = self.itemsContainer(of: items.view, kind: items.side, contentView: contentView) else {
                        continue
                    }
                    changedItems.append((role, items.side, contentView.extractItems(of: container)))
                }
            }
        }
        self.bottomSide = bottom
        self.topSide = top
        self.bottomLayout = self.layout(side: bottom, contentView: self.bottomContentView, kind: .bottom)
        self.topLayout = self.layout(side: top, contentView: self.topContentView, kind: .top)
        for change in changedItems {
            guard let platter = self.platters[change.role], let index = platter.items.firstIndex(where: { !$0.isLeaving && $0.side == change.kind }) else {
                continue
            }
            let current = platter.items[index]
            let motion = self.motion
            let leaving = Items(side: change.kind, view: change.leaving, frame: current.frame, appearance: 0.0, motion: motion)
            leaving.isLeaving = true
            leaving.maxScale = motion.matchScale
            leaving.appearance = leaving.appearance.retargeted(at: self.time, to: 1.0, spring: motion.transition)
            platter.items.insert(leaving, at: index)
            if let frame = self.layout(change.kind).frames[change.role] {
                let arriving = Items(side: change.kind, view: current.view, frame: frame, appearance: 1.0, motion: motion)
                arriving.maxScale = motion.matchScale
                arriving.appearance = arriving.appearance.retargeted(at: self.time, to: 0.0, spring: motion.transition)
                platter.items[index + 1] = arriving
                platter.pulse = motion.pulseCurve(size: frame.size, startTime: self.time)
            }
        }
        var retargeted = !changedItems.isEmpty
        if self.hasBegun && !self.isInteractive {
            // A bar's content changed mid-transition (a list screen applies its buttons just after its push begins):
            // the capsules head for the target bar's new ones. One arriving now materializes now, or takes over the
            // capsule that had begun to leave in its place.
            self.switchTo(self.toSide)
            retargeted = true
        }
        if retargeted {
            self.rebake(continuing: true)
        }
    }

    private func layout(side: Side, contentView: NavigationBarContentView, kind: SideKind) -> SideLayout {
        let size = side.rowFrame.size
        let symmetricInset = min(side.leftInset, side.rightInset)
        let bandSize = CGSize(width: size.width - (side.leftInset - symmetricInset) - (side.rightInset - symmetricInset), height: size.height)
        contentView.update(theme: side.theme, strings: side.strings, content: side.content, leftInset: symmetricInset, rightInset: symmetricInset + side.trailingButtonsInset, size: bandSize, columnLength: side.columnFrame?.height, openOverflow: nil, transition: .immediate)

        var layout = SideLayout()
        layout.isDark = side.theme.overallDarkAppearance
        if contentView.leftButtonsWidth > 0.0 {
            let width = max(44.0, contentView.leftButtonsWidth)
            layout.frames[.leading] = CGRect(x: side.rowFrame.minX + side.leftInset, y: side.rowFrame.minY, width: width, height: 44.0)
            contentView.leftButtonsContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: 44.0))
            layout.itemViews[.leading] = contentView.leftButtonsContainer
            layout.tints[.leading] = navigationBarGlassTintColor(contentView.leftCapsuleTint, theme: side.theme)
            layout.signatures[.leading] = navigationBarCapsuleSignature(side.content, role: .leading, columnLength: side.columnFrame?.height, hidesColumnButtons: side.hidesColumnButtons)
        }
        let rowMaxX = side.rowFrame.minX + size.width - side.rightInset - side.trailingButtonsInset
        // Every pill is a right platter, by UIKit's section index from the edge.
        let rightPills = navigationBarRightPillMetrics(widths: contentView.rightPillWidths)
        var outerExtent: CGFloat = 0.0
        for (index, pill) in rightPills.enumerated() {
            let maxX = rowMaxX - outerExtent
            outerExtent += pill.extent
            let role: Role = .trailing(index)
            layout.frames[role] = CGRect(x: maxX - pill.width, y: side.rowFrame.minY, width: pill.width, height: 44.0)
            let container = contentView.rightPillContainer(at: index)
            container.frame = CGRect(origin: CGPoint(), size: CGSize(width: pill.width, height: 44.0))
            layout.itemViews[role] = container
            layout.tints[role] = navigationBarGlassTintColor(contentView.rightPillTints[index], theme: side.theme)
            layout.signatures[role] = navigationBarCapsuleSignature(side.content, role: role, columnLength: side.columnFrame?.height, hidesColumnButtons: side.hidesColumnButtons)
        }
        if let pill = side.titlePill, layout.frames[.trailing(1)] == nil, layout.frames.keys.filter({ $0.rightIndex != nil }).count <= 1 {
            // The title's glass pill (the chat header) is the bar's second right platter (asked 2026-10-15): it morphs
            // with the other bar's platter at that index, its contents (lent live) as its items.
            layout.frames[.trailing(1)] = pill.frame
            layout.itemViews[.trailing(1)] = pill.lendContent()
            layout.tints[.trailing(1)] = navigationBarGlassTintColor(.generic, theme: side.theme)
            layout.signatures[.trailing(1)] = ["titlePill", pill.signature]
            layout.titlePillRole = .trailing(1)
        }
        if let columnFrame = side.columnFrame, let columnLayout = contentView.columnLayout {
            // Top to bottom (`sideColumnItemsLayout`), each shape the bar has taking the next slot.
            let shapes: [(NavigationBarColumnShape, CGRect?, UIView, GlassBackgroundView.TintColor)] = [
                (.back, columnLayout.backFrame, contentView.columnBackContainer, navigationBarGlassTintColor(.generic, theme: side.theme)),
                (.buttons, side.hidesColumnButtons ? nil : columnLayout.capsuleFrame, contentView.columnButtonsContainer, navigationBarGlassTintColor(.generic, theme: side.theme)),
                (.trailing, side.hidesColumnButtons || contentView.columnTrailingContainer.subviews.isEmpty ? nil : columnLayout.trailingFrame, contentView.columnTrailingContainer, navigationBarGlassTintColor(contentView.trailingCircleTint, theme: side.theme))
            ]
            var slot = 0
            for (shape, frame, container, tint) in shapes {
                guard let frame else {
                    continue
                }
                let role: Role = .column(slot)
                slot += 1
                layout.frames[role] = frame.offsetBy(dx: columnFrame.minX, dy: columnFrame.minY)
                container.frame = CGRect(origin: CGPoint(), size: frame.size)
                layout.itemViews[role] = shape == .back ? self.columnBackItems(kind: kind, container: container, size: frame.size, badge: side.content.badge, theme: side.theme) : container
                layout.tints[role] = tint
                layout.signatures[role] = navigationBarColumnShapeSignature(side.content, shape: shape, columnLength: columnFrame.height, hidesColumnButtons: side.hidesColumnButtons)
            }
        }
        return layout
    }

    /// The column back circle's items: its container and, when the bar shows one, the unread badge on its corner (where
    /// `NavigationBarComponent` puts it).
    private func columnBackItems(kind: SideKind, container: UIView, size: CGSize, badge: String?, theme: NavigationBarTheme) -> UIView {
        let wrapper: UIView
        if let current = self.columnBackWrappers[kind] {
            wrapper = current
        } else {
            wrapper = UIView()
            wrapper.isUserInteractionEnabled = false
            self.columnBackWrappers[kind] = wrapper
        }
        wrapper.frame = CGRect(origin: CGPoint(), size: size)
        if container.superview !== wrapper {
            wrapper.insertSubview(container, at: 0)
        }
        container.frame = CGRect(origin: CGPoint(), size: size)
        if let badge, !badge.isEmpty {
            let badgeNode: NavigationBarBadgeNode
            if let current = self.columnBadges[kind] {
                badgeNode = current
            } else {
                badgeNode = NavigationBarBadgeNode(fillColor: theme.buttonColor, strokeColor: theme.buttonColor, textColor: theme.badgeTextColor)
                badgeNode.isUserInteractionEnabled = false
                self.columnBadges[kind] = badgeNode
                wrapper.addSubnode(badgeNode)
            }
            badgeNode.updateTheme(fillColor: theme.buttonColor, strokeColor: theme.buttonColor, textColor: theme.badgeTextColor)
            badgeNode.text = badge
            let badgeSize = badgeNode.measure(CGSize(width: 200.0, height: 100.0))
            badgeNode.frame = CGRect(origin: CGPoint(x: size.width - badgeSize.width + 4.0, y: -4.0), size: badgeSize)
        } else if let badgeNode = self.columnBadges[kind] {
            self.columnBadges[kind] = nil
            badgeNode.removeFromSupernode()
        }
        return wrapper
    }

    /// The content view's container that a capsule's items view is (or, for iPhone Duo's back circle, wraps).
    private func itemsContainer(of view: UIView, kind: SideKind, contentView: NavigationBarContentView) -> UIView? {
        if view === self.columnBackWrappers[kind] {
            return contentView.columnBackContainer
        }
        for container in [contentView.leftButtonsContainer, contentView.columnButtonsContainer, contentView.columnTrailingContainer] + contentView.rightPillContainers where container === view {
            return container
        }
        return nil
    }

    /// The right platters the two layouts and the current platters hold.
    private var rightRoleCount: Int {
        let indices = [self.bottomLayout, self.topLayout].flatMap { $0.frames.keys.compactMap(\.rightIndex) } + self.platters.keys.compactMap(\.rightIndex)
        return (indices.max() ?? -1) + 1
    }

    /// The column slots the two layouts and the current platters hold.
    private var columnRoleCount: Int {
        let indices = [self.bottomLayout, self.topLayout].flatMap { $0.frames.keys.compactMap(\.columnIndex) } + self.platters.keys.compactMap(\.columnIndex)
        return (indices.max() ?? -1) + 1
    }

    private func layout(_ side: SideKind) -> SideLayout {
        return side == .bottom ? self.bottomLayout : self.topLayout
    }

    /// The transition starts. `toTop`: it ends on the top bar (a push), else on the bottom one (a pop).
    public func beginTransition(isInteractive: Bool, toTop: Bool) {
        self.clock.stop()
        self.time = 0.0
        self.hasBegun = true
        self.isInteractive = isInteractive
        self.fromSide = toTop ? .bottom : .top
        self.toSide = toTop ? .top : .bottom
        for platter in self.platters.values {
            platter.removeViews()
        }
        self.platters = [:]
        // The outgoing bar's capsules, as they are, a press UIKit was drawing on one included: it goes on releasing.
        let from = self.layout(self.fromSide)
        let fromSide = self.fromSide == .bottom ? self.bottomSide : self.topSide
        for role in Role.all(rightCount: self.rightRoleCount, columnCount: self.columnRoleCount) {
            guard let frame = from.frames[role], let itemView = from.itemViews[role], let tint = from.tints[role] else {
                continue
            }
            let platter = Platter(role: role, frame: frame, tint: tint, isDark: from.isDark)
            // The bar measures UIKit's press on its row capsules only; iPhone Duo's column capsules start at rest.
            let pressScale: CGFloat
            let pressGlow: CGFloat
            switch role {
            case .leading:
                pressScale = fromSide?.leadingPressScale ?? 1.0
                pressGlow = fromSide?.leadingPressGlow ?? 0.0
            case let .trailing(index):
                let scales = fromSide?.trailingPressScales ?? []
                let glows = fromSide?.trailingPressGlows ?? []
                pressScale = index < scales.count ? scales[index] : 1.0
                pressGlow = index < glows.count ? glows[index] : 0.0
            case .column:
                pressScale = 1.0
                pressGlow = 0.0
            }
            if abs(pressScale - 1.0) > 0.0005 {
                platter.press = NavigationSpringCurve(startTime: self.time, from: pressScale, target: 1.0, spring: NavigationBarGlassSettings.pressRelease, rest: .glass(0.0005))
            }
            if pressGlow > 0.001, NavigationBarPressGlowView.isAvailable {
                // Inside the glass, as UIKit's glow container is inside the capsule's glass. Without the filter the glow
                // would be a plain white capsule, so then there is none.
                platter.glow = NavigationSpringCurve(startTime: self.time, from: min(1.0, pressGlow), target: 0.0, spring: NavigationBarGlassSettings.pressGlowRelease, rest: .glass(0.001))
                let glowView = NavigationBarPressGlowView(frame: CGRect())
                platter.glass.contentView.addSubview(glowView)
                platter.glowView = glowView
            }
            platter.items = [Items(side: self.fromSide, view: itemView, frame: frame, appearance: 0.0, motion: self.motion)]
            platter.isTitlePill = from.titlePillRole == role
            self.platters[role] = platter
            self.addViews(of: platter)
        }
        if !isInteractive {
            // UIKit hands the destination capsules over as the transition starts.
            self.switchTo(self.toSide)
        }
        // The first bake begins at the commit, with the screens'.
        self.rebake(continuing: false)
    }

    /// A swipe back took over the transition while it ran toward the top bar (a push, or a pop springing back after a
    /// cancelled swipe). A finger dragging does not move the capsules (iOS's do not: measured 2026-10-14), so they carry
    /// on as they were, and a bar change meanwhile does not switch them; the release does.
    public func beginInteraction() {
        guard self.hasBegun else {
            return
        }
        self.isInteractive = true
    }

    /// A swipe was released (`towardTop` false: the pop finishes) or cancelled (true): the capsules switch to that bar's,
    /// and a bar change from here on heads them for that bar's new ones.
    public func endInteraction(towardTop: Bool) {
        self.time = self.now
        self.isInteractive = false
        self.toSide = towardTop ? .top : .bottom
        self.switchTo(self.toSide)
        self.rebake(continuing: true)
    }

    private func switchTo(_ side: SideKind) {
        let target = self.layout(side)
        let motion = self.motion
        let rowFrame = (side == .bottom ? self.bottomSide : self.topSide)?.rowFrame ?? self.bounds
        let containerWidth = rowFrame.width
        // What an inserted right platter can grow out of: the other bar's right platters, not ones this switch creates
        // (UIKit matches an inserted entry to an old one only).
        let oldRight: [(role: Role, platter: Platter)] = self.platters.compactMap { role, platter in
            return role.rightIndex != nil && !platter.isLeaving ? (role, platter) : nil
        }
        let targetRight: [(role: Role, frame: CGRect)] = target.frames.compactMap { role, frame in
            return role.rightIndex != nil ? (role, frame) : nil
        }
        for role in Role.all(rightCount: self.rightRoleCount, columnCount: self.columnRoleCount) {
            let existing = self.platters[role]
            if let frame = target.frames[role], let itemView = target.itemViews[role], let tint = target.tints[role] {
                if let platter = existing {
                    // The same capsule on both bars: one shape morphing to the new frame. One that had begun to leave
                    // (this bar's capsule arrived late) is taken over, as SwiftUI's resolver reuses a removed entry
                    // matching an insertion (`Resolver.updateInsertion` -> `reuseEntry`).
                    platter.isLeaving = false
                    platter.isTitlePill = target.titlePillRole == role
                    platter.animateFrame(to: frame, spring: motion.transition, at: self.time)
                    platter.dematerialization = platter.dematerialization.retargeted(at: self.time, to: 0.0, spring: motion.transition)
                    platter.isDark = target.isDark
                    let otherSignature = self.layout(side == .bottom ? .top : .bottom).signatures[role]
                    let currentItems = platter.items.first(where: { !$0.isLeaving })
                    if currentItems?.side != side {
                        if otherSignature == target.signatures[role], let currentItems {
                            // The same items: swap to this bar's identical copies.
                            currentItems.view.removeFromSuperview()
                            platter.items.removeAll(where: { $0 === currentItems })
                            platter.items.append(Items(side: side, view: itemView, frame: frame, appearance: 0.0, motion: motion))
                        } else {
                            // New items: the old ones shrink away, the new ones grow in (matched items, glass RE §2.3,
                            // on the transition spring as measured), the shape pulses.
                            for items in platter.items where !items.isLeaving {
                                items.isLeaving = true
                                items.maxScale = motion.matchScale
                                items.appearance = items.appearance.retargeted(at: self.time, to: 1.0, spring: motion.transition)
                            }
                            if let returning = platter.items.first(where: { $0.side == side }) {
                                returning.isLeaving = false
                                returning.maxScale = motion.matchScale
                                returning.appearance = returning.appearance.retargeted(at: self.time, to: 0.0, spring: motion.transition)
                            } else {
                                let items = Items(side: side, view: itemView, frame: frame, appearance: 1.0, motion: motion)
                                items.maxScale = motion.matchScale
                                items.appearance = items.appearance.retargeted(at: self.time, to: 0.0, spring: motion.transition)
                                platter.items.append(items)
                            }
                            platter.pulse = motion.pulseCurve(size: frame.size, startTime: self.time)
                        }
                    }
                    if platter.tint != tint {
                        // One shape whose tint cross-fades: the old tint fades out above the new one.
                        self.startTintFade(platter, from: platter.tint)
                        platter.tint = tint
                    }
                } else {
                    // Only this bar has it: it materializes in place, on the transition spring (bouncy; measured on
                    // iOS 27, glass RE §2.2: not the critically damped `.materialize` resolution).
                    let platter = Platter(role: role, frame: frame, tint: tint, isDark: target.isDark)
                    platter.isTitlePill = target.titlePillRole == role
                    let oldPartners = oldRight.filter { ($0.role.rightIndex ?? 0) < (role.rightIndex ?? 0) }
                    if role.rightIndex != nil, !motion.reduce, !platter.isTitlePill, let partnerIndex = navigationBarNearestPartner(of: frame, among: oldPartners.map { $0.platter.frame(at: self.time) }) {
                        // Grows out of the other bar's nearest platter nearer the edge, as UIKit's inserted section matched
                        // to an old one (UIKit's sections are contiguous, so an inserted one's partners are all nearer the
                        // edge). Not a title pill: with no platter in its slot to morph from (Contacts has only its "+"),
                        // it materializes in place (asked 2026-10-18).
                        let partner = oldPartners[partnerIndex]
                        let partnerTarget = target.frames[partner.role] ?? partner.platter.frame(at: self.time)
                        let start = self.startMatchedMorph(platter, source: partner.platter.frame(at: self.time), target: frame, appearing: true, containerWidth: containerWidth)
                        platter.partner = partner.role
                        self.pulseMatchedPair(platter, ownSize: frame.size, start: start, partner: partner.platter, partnerFrame: partnerTarget, rowFrame: rowFrame)
                    } else {
                        platter.maxScale = motion.materializeScale(size: frame.size)
                        platter.blurRadius = motion.blurRadius
                        platter.dematerialization = NavigationSpringCurve(startTime: self.time, from: 1.0, target: 0.0, spring: motion.transition, rest: .glass(0.001))
                    }
                    platter.items = [Items(side: side, view: itemView, frame: frame, appearance: 0.0, motion: motion)]
                    self.platters[role] = platter
                    self.addViews(of: platter)
                }
            } else if let platter = existing, !platter.isLeaving {
                let targetPartners = targetRight.filter { ($0.role.rightIndex ?? 0) < (role.rightIndex ?? 0) }
                if role.rightIndex != nil, !motion.reduce, !platter.isTitlePill, let partnerIndex = navigationBarNearestPartner(of: platter.frame(at: self.time), among: targetPartners.map(\.frame)) {
                    // Collapses into this bar's nearest platter nearer the edge, as UIKit's removed section matched to a
                    // new one. A title pill dematerializes in place instead, as it materializes.
                    let partner = targetPartners[partnerIndex]
                    let own = platter.frame(at: self.time)
                    let start = self.startMatchedMorph(platter, source: own, target: partner.frame, appearing: false, containerWidth: containerWidth)
                    platter.partner = partner.role
                    if let partnerPlatter = self.platters[partner.role] {
                        self.pulseMatchedPair(platter, ownSize: own.size, start: start, partner: partnerPlatter, partnerFrame: partner.frame, rowFrame: rowFrame)
                    }
                } else {
                    // Only the other bar has it: it dematerializes in place, on the transition spring as well.
                    platter.isMatched = false
                    platter.partner = nil
                    platter.isLeaving = true
                    platter.maxScale = motion.materializeScale(size: platter.frame(at: self.time).size)
                    platter.blurRadius = motion.blurRadius
                    platter.dematerialization = platter.dematerialization.retargeted(at: self.time, to: 1.0, spring: motion.transition)
                }
            }
        }
    }

    /// SwiftUI's matched insertion or removal (`Resolver.adjustMatchedEntry`, glass RE §1, §S2; sampled on iOS 27): after
    /// the delay (`minDelay` for a removal, none for an insertion: `resolvedMatchedOffset`) the shape springs from
    /// `source` to `target` on the transition spring with the kick, its items appearing from, or leaving into, the
    /// `.match` appearance (scale 0.2, transparent, blurred) while its glass only scales (`mergesGlass`).
    /// Returns when the shape starts moving.
    @discardableResult
    private func startMatchedMorph(_ platter: Platter, source: CGRect, target: CGRect, appearing: Bool, containerWidth: CGFloat) -> Double {
        let motion = self.motion
        // SwiftUI's offset is the entry's own centre minus its partner's (`partner.geometryResult(to: entry)`, SwiftUICore
        // 27 0x1c6ea58fc and 0x1c717dcb0): the kick pushes a collapsing platter away from its partner, a growing one out.
        let own = appearing ? target : source
        let partner = appearing ? source : target
        let delta = CGSize(width: own.midX - partner.midX, height: own.midY - partner.midY)
        let disjoint = !source.intersects(target)
        let resolvedOffset = NavigationBarGlassSettings.resolvedMatchedOffset(disjoint ? delta : nil, isRemoval: !appearing)
        let start = self.time + (resolvedOffset.map { NavigationBarGlassSettings.matchedDelay(offset: $0, containerWidth: containerWidth) } ?? 0.0)
        func curve(from: CGFloat, to: CGFloat, rest: NavigationSpringRest) -> NavigationSpringCurve {
            return NavigationSpringCurve(startTime: start, from: from, target: to, spring: motion.transition, rest: rest)
        }
        platter.x = curve(from: source.minX, to: target.minX, rest: .glass(0.01))
        platter.y = curve(from: source.minY, to: target.minY, rest: .glass(0.01))
        platter.width = curve(from: source.width, to: target.width, rest: .glass(0.01))
        platter.height = curve(from: source.height, to: target.height, rest: .glass(0.01))
        platter.maxScale = motion.matchScale
        platter.blurRadius = motion.blurRadius
        let current = platter.dematerialization.value(at: self.time)
        platter.dematerialization = curve(from: appearing ? 1.0 : current, to: appearing ? 0.0 : 1.0, rest: .glass(0.001))
        platter.isLeaving = !appearing
        platter.isMatched = true
        platter.kick = disjoint ? NavigationBarKickCurve(offset: CGSize(width: delta.width / NavigationBarGlassSettings.kickFactor, height: delta.height / NavigationBarGlassSettings.kickFactor), startTime: start) : nil
        return start
    }

    /// Whether `platter`'s glass is drawn in the merged container: a matched platter's and its partner's are while the
    /// first collapses into, or grows out of, the second, unless the partner fades in place, which only a container of
    /// its own can draw (a glass shape's own opacity does not hide it). Without native glass nothing merges, so the
    /// matched one keeps its own container and fades with it.
    private func mergesGlass(_ platter: Platter) -> Bool {
        guard self.glassMergesShapes(), platter.role.rightIndex != nil else {
            return false
        }
        func materialized(_ partner: Platter) -> Bool {
            return !partner.isLeaving && partner.dematerialization.target == 0.0 && partner.dematerialization.value(at: self.time) < 0.001
        }
        if platter.isMatched, let role = platter.partner, let partner = self.platters[role] {
            return materialized(partner)
        }
        // The partner of a matched platter, while that one merges with it.
        return materialized(platter) && self.platters.values.contains(where: { $0.isMatched && $0.partner == platter.role })
    }

    /// Puts `platter`'s glass into the merged container or its own, as `mergesGlass` decides.
    private func hostGlass(_ platter: Platter) {
        let host: UIView
        if self.mergesGlass(platter) {
            let container: GlassBackgroundContainerView
            if let current = self.mergedGlassContainer {
                container = current
            } else {
                container = GlassBackgroundContainerView(spacing: NavigationBarGlassSettings.platterSmoothness)
                container.isUserInteractionEnabled = false
                self.mergedGlassContainer = container
                self.insertSubview(container, at: 0)
            }
            container.frame = self.bounds
            container.update(size: self.bounds.size, isDark: platter.isDark, transition: .immediate)
            host = container.contentView
        } else {
            host = platter.container.contentView
        }
        if platter.glass.superview !== host {
            host.addSubview(platter.glass)
        }
    }

    private func isGlassMerged(_ platter: Platter) -> Bool {
        return self.mergedGlassContainer.map { platter.glass.superview === $0.contentView } ?? false
    }

    /// SwiftUI's pulses of a matched insertion or removal: the entry and its partner each get a scale pulse
    /// (`adjustMatchedEntry` writes one to the entry's state at 0x1c6ea2848 and one to its partner's at 0x1c6ea3568),
    /// about the pair's `transitionAnchor`. The partner's starts now, replacing the centred pulse of its own item change;
    /// the entry's starts with its morph (on a push its capsule holds still through the delay: filmed on iOS 27).
    private func pulseMatchedPair(_ platter: Platter, ownSize: CGSize, start: Double, partner: Platter, partnerFrame: CGRect, rowFrame: CGRect) {
        let motion = self.motion
        let anchor = NavigationBarGlassSettings.transitionAnchor(partner: partnerFrame, container: rowFrame)
        partner.pulse = motion.pulseCurve(size: partnerFrame.size, startTime: self.time, anchor: anchor)
        platter.pulse = motion.pulseCurve(size: ownSize, startTime: start, anchor: anchor)
    }

    private func addViews(of platter: Platter) {
        self.addSubview(platter.container)
        self.addSubview(platter.itemsHost)
    }

    private func startTintFade(_ platter: Platter, from tint: GlassBackgroundView.TintColor) {
        let container: GlassBackgroundContainerView
        let glass: GlassBackgroundView
        if let currentContainer = platter.fadingContainer, let currentGlass = platter.fadingGlass {
            container = currentContainer
            glass = currentGlass
        } else {
            container = GlassBackgroundContainerView()
            container.isUserInteractionEnabled = false
            glass = GlassBackgroundView()
            container.contentView.addSubview(glass)
            platter.fadingContainer = container
            platter.fadingGlass = glass
            self.insertSubview(container, aboveSubview: platter.container)
        }
        platter.fadingTint = tint
        platter.tintFade = NavigationSpringCurve(startTime: self.time, from: 1.0, target: 0.0, spring: NavigationBarGlassSettings.tintCrossFade, rest: .glass(0.001))
    }

    /// The animation time now: every change happens at it.
    private var now: Double {
        return self.clock.isRunning ? self.clock.animationTime() : 0.0
    }

    /// Bakes every capsule from the state at `self.time`: the curves are re-based so that it is animation time 0, and
    /// the clock restarts. `continuing` false only for the transition's first bake, which begins at the commit with the
    /// screens'.
    private func rebake(continuing: Bool) {
        let time = self.time
        for platter in self.platters.values {
            platter.rebase(by: time)
        }
        self.time = 0.0
        self.prune()
        let duration = self.platters.values.map { $0.restTime }.max() ?? 0.0
        guard duration > 0.0 else {
            self.clock.stop()
            self.applyAll()
            self.reportSettledIfNeeded()
            return
        }
        self.hasReportedSettled = false
        let timing = self.clock.start(duration: duration, continuing: continuing)
        for platter in self.platters.values {
            self.bake(platter, timing: timing)
        }
    }

    /// The last curve has rested on both clocks: every curve is at its target, what has left goes, and the view
    /// reports settled.
    private func clockEnded() {
        for platter in self.platters.values {
            platter.settle()
        }
        self.time = 0.0
        self.prune()
        self.applyAll()
        self.reportSettledIfNeeded()
    }

    /// One capsule's curves sampled at `timing` and installed as keyframes on its views; the model is the last sample.
    private func bake(_ platter: Platter, timing: NavigationKeyframeTiming) {
        let times = timing.sampleTimes
        let time = self.time
        self.time = timing.duration
        self.attachItems(platter)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.apply(platter)
        CATransaction.commit()
        self.time = time

        func add(_ layer: CALayer, _ keyPath: String, _ values: [Any]) {
            addNavigationKeyframes(to: layer, key: NavigationBarPlatterTransitionView.keyPrefix + keyPath, keyPath: keyPath, values: values, timing: timing)
        }
        let frames = times.map { platter.frame(at: $0) }
        let dematerializations = times.map { max(0.0, min(1.0, platter.dematerialization.value(at: $0))) }
        let centers = frames.map { NSValue(cgPoint: CGPoint(x: $0.midX, y: $0.midY)) }
        let bounds = frames.map { NSValue(cgRect: CGRect(origin: CGPoint(), size: $0.size)) }
        let glassCenters = frames.map { NSValue(cgPoint: CGPoint(x: $0.width * 0.5, y: $0.height * 0.5)) }
        let transforms: [Any] = times.map { time -> NSValue in
            return NSValue(caTransform3D: CATransform3DMakeAffineTransform(platter.drawingTransform(at: time)))
        }
        for view in platter.views {
            add(view.layer, "position", centers)
            add(view.layer, "bounds", bounds)
            add(view.layer, "transform", transforms)
        }
        let presence = dematerializations.map { NSNumber(value: Float(1.0 - $0)) }
        add(platter.container.layer, "opacity", presence)
        add(platter.itemsHost.layer, "opacity", presence)
        self.addBlurKeyframes(to: platter.itemsHost.layer, radii: dematerializations.map { platter.blurRadius * $0 }, timing: timing)

        platter.container.animateSize(width: platter.width, height: platter.height, timing: timing, isDark: platter.isDark)
        // Merged glass draws its scaled frame as its own geometry in this view's space (a transform would scale the
        // other platter's shape with it); its own container's transform scales the rest.
        let isMerged = self.isGlassMerged(platter)
        let glassFrames = isMerged ? times.map { platter.glassFrame(at: $0) } : frames
        if isMerged {
            add(platter.glass.layer, "position", glassFrames.map { NSValue(cgPoint: CGPoint(x: $0.midX, y: $0.midY)) })
            add(platter.glass.layer, "bounds", glassFrames.map { NSValue(cgRect: CGRect(origin: CGPoint(), size: $0.size)) })
        } else {
            add(platter.glass.layer, "position", glassCenters)
            add(platter.glass.layer, "bounds", bounds)
        }
        platter.glass.animateShape(sizes: glassFrames.map { CGSize(width: max(0.0, $0.width), height: max(0.0, $0.height)) }, timing: timing, isDark: platter.isDark, tintColor: platter.tint)
        if let fadingContainer = platter.fadingContainer, let fadingGlass = platter.fadingGlass, let fadingTint = platter.fadingTint {
            add(fadingContainer.layer, "opacity", zip(times, dematerializations).map { NSNumber(value: Float(max(0.0, min(1.0, platter.tintFade.value(at: $0.0))) * (1.0 - $0.1))) })
            fadingContainer.animateSize(width: platter.width, height: platter.height, timing: timing, isDark: platter.isDark)
            add(fadingGlass.layer, "position", glassCenters)
            add(fadingGlass.layer, "bounds", bounds)
            fadingGlass.animateShape(width: platter.width, height: platter.height, timing: timing, isDark: platter.isDark, tintColor: fadingTint)
        }
        if let glowView = platter.glowView {
            glowView.animate(sizes: glassFrames.map { $0.size }, glows: times.map { platter.glow.value(at: $0) }, timing: timing, isDark: platter.isDark)
        }
        for items in platter.items {
            // Each bar's items stay where that bar has them while the shape morphs around them.
            let appearances = times.map { max(0.0, min(1.0, items.appearance.value(at: $0))) }
            let scales = times.map { items.appearance.value(at: $0) }
            add(items.view.layer, "position", frames.map { NSValue(cgPoint: CGPoint(x: items.frame.midX - $0.minX, y: items.frame.midY - $0.minY)) })
            add(items.view.layer, "transform", scales.map { a in NSValue(caTransform3D: CATransform3DMakeScale(1.0 + a * (items.maxScale.width - 1.0), 1.0 + a * (items.maxScale.height - 1.0), 1.0)) })
            add(items.view.layer, "opacity", appearances.map { NSNumber(value: Float(1.0 - $0)) })
            self.addBlurKeyframes(to: items.view.layer, radii: appearances.map { items.blurRadius * $0 }, timing: timing)
        }
    }

    /// Blur keyframes (`filters.gaussianBlur.inputRadius`, the key path `ComponentTransition.setBlur` animates): the
    /// filter stays installed while any sample blurs, at the last sample's radius in the model.
    private func addBlurKeyframes(to layer: CALayer, radii: [CGFloat], timing: NavigationKeyframeTiming) {
        let key = NavigationBarPlatterTransitionView.keyPrefix + "blur"
        guard radii.contains(where: { $0 > 0.0 }) else {
            layer.removeAnimation(forKey: key)
            return
        }
        let final = radii.last ?? 0.0
        if (layer.filters ?? []).contains(where: { ($0 as? NSObject)?.description.contains("gaussianBlur") == true }) {
            layer.setValue(final as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
        } else if let filter = CALayer.blur() {
            filter.setValue(final as NSNumber, forKey: "inputRadius")
            layer.filters = [filter]
        }
        addNavigationKeyframes(to: layer, key: key, keyPath: "filters.gaussianBlur.inputRadius", values: radii.map { NSNumber(value: Double($0)) }, timing: timing)
    }

    /// Takes away what has come to rest: leaving items and capsules, a faded glow, a finished tint fade, a done pulse.
    private func prune() {
        for (role, platter) in self.platters {
            if platter.glowView != nil && self.time >= platter.glow.restTime && platter.glow.target == 0.0 {
                platter.glowView?.removeFromSuperview()
                platter.glowView = nil
            }
            if let pulse = platter.pulse, self.time >= pulse.restTime {
                platter.pulse = nil
            }
            if platter.fadingContainer != nil && self.time >= platter.tintFade.restTime {
                platter.fadingContainer?.removeFromSuperview()
                platter.fadingContainer = nil
                platter.fadingGlass = nil
                platter.fadingTint = nil
            }
            for items in platter.items where items.isLeaving && self.time >= items.appearance.restTime {
                items.view.removeFromSuperview()
            }
            platter.items.removeAll(where: { $0.isLeaving && self.time >= $0.appearance.restTime })
            if platter.isLeaving && self.time >= platter.dematerialization.restTime {
                platter.removeViews()
                self.platters[role] = nil
            }
        }
    }

    /// Whether the capsules are still animating: their clock runs until the last curve rests.
    public var isAnimating: Bool {
        return self.clock.isRunning
    }

    private func reportSettledIfNeeded() {
        if !self.isInteractive && !self.hasReportedSettled {
            self.hasReportedSettled = true
            self.onSettled?()
        }
    }

    private func applyAll() {
        for platter in self.platters.values {
            self.attachItems(platter)
            self.apply(platter)
        }
    }

    /// Takes a capsule's items into its host where Core Animation tells their layers they are on screen (`onOrderIn`),
    /// which it skips while actions are disabled. Lent live contents heard they left (`onOrderOut`) when their bar
    /// handed them over, and an animated emoji status (`InlineStickerItemLayer`) plays only between the two: in a
    /// disabled-actions transaction it stood still until it was given back.
    private func attachItems(_ platter: Platter) {
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        for items in platter.items where items.view.superview !== platter.itemsHost {
            platter.itemsHost.addSubview(items.view)
        }
        CATransaction.commit()
    }

    private func apply(_ platter: Platter) {
        let frame = platter.frame(at: self.time)
        let d = max(0.0, min(1.0, platter.dematerialization.value(at: self.time)))
        let bounds = CGRect(origin: CGPoint(), size: frame.size)
        let transform = platter.drawingTransform(at: self.time)
        for view in platter.views {
            view.bounds = bounds
            view.center = CGPoint(x: frame.midX, y: frame.midY)
            view.transform = transform
        }
        // The glass containers' opacity goes on their layers, not through `UIView.alpha`: a view alpha below 1 makes
        // UIKit stop drawing the glass inside at once, whatever keyframes run on top (measured on iOS 27, spec §6
        // results), while a layer opacity is followed by the glass as it animates.
        platter.container.layer.opacity = Float(1.0 - d)
        platter.container.update(size: frame.size, isDark: platter.isDark, transition: .immediate)
        self.hostGlass(platter)
        let glassFrame: CGRect
        if self.isGlassMerged(platter) {
            glassFrame = platter.glassFrame(at: self.time)
            platter.glass.frame = glassFrame
        } else {
            glassFrame = frame
            platter.glass.frame = bounds
        }
        platter.glass.update(size: glassFrame.size, cornerRadius: min(glassFrame.width, glassFrame.height) * 0.5, isDark: platter.isDark, tintColor: platter.tint, isInteractive: false, transition: .immediate)
        if let fadingContainer = platter.fadingContainer, let fadingGlass = platter.fadingGlass, let fadingTint = platter.fadingTint {
            fadingContainer.layer.opacity = Float(max(0.0, min(1.0, platter.tintFade.value(at: self.time))) * (1.0 - d))
            fadingContainer.update(size: frame.size, isDark: platter.isDark, transition: .immediate)
            fadingGlass.frame = bounds
            fadingGlass.update(size: frame.size, cornerRadius: min(frame.width, frame.height) * 0.5, isDark: platter.isDark, tintColor: fadingTint, isInteractive: false, transition: .immediate)
        }
        platter.itemsHost.alpha = 1.0 - d
        if let glowView = platter.glowView {
            glowView.frame = CGRect(origin: CGPoint(), size: glassFrame.size)
            glowView.update(size: glassFrame.size, glow: platter.glow.value(at: self.time), isDark: platter.isDark)
        }
        ComponentTransition.immediate.setBlur(layer: platter.itemsHost.layer, radius: platter.blurRadius * d)
        for items in platter.items {
            // Each bar's items stay where that bar has them while the shape morphs around them.
            let a = max(0.0, min(1.0, items.appearance.value(at: self.time)))
            items.view.bounds = CGRect(origin: CGPoint(), size: items.frame.size)
            items.view.center = CGPoint(x: items.frame.midX - frame.minX, y: items.frame.midY - frame.minY)
            items.view.transform = CGAffineTransform(scaleX: 1.0 + items.appearance.value(at: self.time) * (items.maxScale.width - 1.0), y: 1.0 + items.appearance.value(at: self.time) * (items.maxScale.height - 1.0))
            items.view.alpha = 1.0 - a
            ComponentTransition.immediate.setBlur(layer: items.view.layer, radius: items.blurRadius * a)
        }
    }


    struct PlatterState {
        var frame: CGRect
        /// The entry's presence: its items' opacity.
        var opacity: CGFloat
        /// The glass's own opacity, and the frame it draws at (the shape's frame scaled by its appearance, pulse and press).
        var glassOpacity: CGFloat
        var glassFrame: CGRect
        var scale: CGSize
        var blur: CGFloat
        var pulse: CGSize
        var press: CGFloat
        var glow: CGFloat
        var fadingTintAlpha: CGFloat?
        /// The translation kick's offset now.
        var kick: CGSize
    }

    func platterStateForTesting(_ role: Role) -> PlatterState? {
        guard let platter = self.platters[role] else {
            return nil
        }
        let time = self.now
        let d = platter.dematerialization.value(at: time)
        return PlatterState(
            frame: platter.frame(at: time),
            opacity: 1.0 - max(0.0, min(1.0, d)),
            glassOpacity: self.isGlassMerged(platter) ? 1.0 : 1.0 - max(0.0, min(1.0, d)),
            glassFrame: platter.glassFrame(at: time),
            scale: CGSize(width: 1.0 + d * (platter.maxScale.width - 1.0), height: 1.0 + d * (platter.maxScale.height - 1.0)),
            blur: platter.blurRadius * max(0.0, min(1.0, d)),
            pulse: platter.pulse?.scale(at: time) ?? CGSize(width: 1.0, height: 1.0),
            press: platter.press.value(at: time),
            glow: platter.glow.value(at: time),
            fadingTintAlpha: platter.fadingContainer != nil ? platter.tintFade.value(at: time) : nil,
            kick: platter.kick?.translation(at: time) ?? CGSize()
        )
    }

    func leavingItemsViewsForTesting(_ role: Role) -> [UIView] {
        return (self.platters[role]?.items ?? []).filter { $0.isLeaving }.map { $0.view }
    }

    /// The unread badge drawn among `role`'s current items.
    func badgeNodeForTesting(_ role: Role) -> NavigationBarBadgeNode? {
        guard let platter = self.platters[role] else {
            return nil
        }
        return self.columnBadges.values.first(where: { badge in platter.items.contains(where: { badge.view.superview === $0.view }) })
    }

    func containerViewForTesting(_ role: Role) -> UIView? {
        return self.platters[role]?.container
    }

    /// The glass view of `role`'s shape, and the container it merges in.
    func glassViewForTesting(_ role: Role) -> UIView? {
        return self.platters[role]?.glass
    }

    func glassContainerForTesting(_ role: Role) -> GlassBackgroundContainerView? {
        var view = self.platters[role]?.glass.superview
        while let current = view {
            if let container = current as? GlassBackgroundContainerView {
                return container
            }
            view = current.superview
        }
        return nil
    }

    func platterIdentityForTesting(_ role: Role) -> ObjectIdentifier? {
        return self.platters[role].map { ObjectIdentifier($0) }
    }

    struct ItemsState {
        var isTop: Bool
        var opacity: CGFloat
        var scale: CGSize
        var blur: CGFloat
    }

    func itemsStateForTesting(_ role: Role) -> [ItemsState] {
        let time = self.now
        return (self.platters[role]?.items ?? []).map { items in
            let a = items.appearance.value(at: time)
            return ItemsState(isTop: items.side == .top, opacity: 1.0 - max(0.0, min(1.0, a)), scale: CGSize(width: 1.0 + a * (items.maxScale.width - 1.0), height: 1.0 + a * (items.maxScale.height - 1.0)), blur: items.blurRadius * max(0.0, min(1.0, a)))
        }
    }
}

/// What a capsule shows, to tell a change of its items, from where the bar places its buttons: the back button (with
/// its badge) and the row's left button for the leading capsule, the row's right buttons for the trailing one; nil when
/// the bar has no such capsule. A column slot is signed by the shape that takes it (`navigationBarColumnShapeSignature`).
private func navigationBarCapsuleSignature(_ content: NavigationBarComponent.Content, role: NavigationBarPlatterTransitionView.Role, columnLength: CGFloat?, hidesColumnButtons: Bool) -> [AnyHashable]? {
    let placement = navigationBarButtonPlacement(leftButton: content.leftButton, rightButtons: content.rightButtons, hasBack: content.back != nil, columnLength: columnLength)
    let backInColumn = content.back != nil && placement.columnLayout?.backFrame != nil
    let backSignature: AnyHashable? = content.back.map { AnyHashable("\($0)-\(content.badge ?? "")") }
    switch role {
    case .leading:
        var signature: [AnyHashable] = []
        if let backSignature, !backInColumn {
            signature.append(backSignature)
        }
        if let leftButton = placement.rowLeftButton {
            signature.append(leftButton.id)
        }
        return signature.isEmpty ? nil : signature
    case let .trailing(index):
        return index < placement.rowRightSections.count ? placement.rowRightSections[index].map { $0.id } : nil
    case .column:
        return nil
    }
}

/// iPhone Duo's column shapes, top to bottom (`sideColumnItemsLayout`).
private enum NavigationBarColumnShape {
    case back
    case buttons
    case trailing
}

/// What a column shape shows: the back circle's back button (with its badge), the capsule's visible items (with the
/// ellipsis when some overflow), the trailing circle's button; nil when the bar has no such shape.
private func navigationBarColumnShapeSignature(_ content: NavigationBarComponent.Content, shape: NavigationBarColumnShape, columnLength: CGFloat?, hidesColumnButtons: Bool) -> [AnyHashable]? {
    let placement = navigationBarButtonPlacement(leftButton: content.leftButton, rightButtons: content.rightButtons, hasBack: content.back != nil, columnLength: columnLength)
    switch shape {
    case .back:
        guard let back = content.back, placement.columnLayout?.backFrame != nil else {
            return nil
        }
        return [AnyHashable("\(back)-\(content.badge ?? "")")]
    case .buttons:
        guard !hidesColumnButtons, let columnLayout = placement.columnLayout, columnLayout.capsuleFrame != nil else {
            return nil
        }
        var signature: [AnyHashable] = columnLayout.visibleItems.map { placement.columnItems[$0].id }
        if !columnLayout.overflowItems.isEmpty {
            signature.append("ellipsis")
        }
        return signature
    case .trailing:
        guard !hidesColumnButtons, let item = placement.trailingCircleItem, placement.columnLayout?.trailingFrame != nil else {
            return nil
        }
        return [item.id]
    }
}

private func lerpRect(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
    return CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t, width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
}
