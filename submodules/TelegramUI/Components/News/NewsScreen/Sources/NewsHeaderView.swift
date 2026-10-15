import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import SearchUI
import ChatListHeaderComponent
import NavigationBarComponent
import GlassBackgroundComponent
import EdgeEffect
import NewsFeedSupport

/// The top row's content. It spans the header, above the search block, so its children keep the header's coordinates;
/// it takes no touch of its own, so a touch it does not give a child reaches the search block under it.
private final class NewsHeaderRowContentView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}

/// The News header, one instance over both pages (Feed2 FeedScreen.swift:203-272). Back to front:
/// - the search block, which scrolls with the active list (above everything while search is open);
/// - the tab-switch shutter;
/// - the soft scroll edge (blur and whitening, shown once content scrolls under the header);
/// - the mockup's static header gradient;
/// - the top row (the tabs island and "…"), which never moves.
///
/// The view covers the screen and takes only its children's touches. In a navigation transition the top row is the
/// bar: it is lifted above both screens, its "…" capsule drawn by the transition's glass and its island taking part as
/// the bar's title pill (it morphs with the other screen's, a chat's header), while the search block, the shutter and
/// the edges ride this screen.
final class NewsHeaderView: UIView, NavigationBarComponentTransitionSource {
    struct Params {
        let context: AccountContext
        let theme: PresentationTheme
        let strings: PresentationStrings
        let layout: ContainerViewLayout
        let isSearchActive: Bool
        let selectedSegment: Int
        let tabSwitchFraction: CGFloat
        let isSwitchingByDragging: Bool
    }

    /// The mockup's header gradient, as written (FeedScreen.swift:260-269): list background 0.92 → 0.6 at 55 % →
    /// clear, from the screen top to 22 pt below the header. Always shown; at rest it barely touches the search
    /// (0.13 at the capsule's top edge, as on the mockup).
    private static let staticGradient: [EdgeEffectView.GradientStop] = [
        EdgeEffectView.GradientStop(location: 0.0, alpha: 0.92),
        EdgeEffectView.GradientStop(location: 0.55, alpha: 0.6),
        EdgeEffectView.GradientStop(location: 1.0, alpha: 0.0)
    ]
    /// The system soft scroll edge the mockup's gradient lies over: blur plus whitening, absent at rest and shown
    /// once content scrolls under the header (`newsHeaderSoftEdgeAlpha`). With the static gradient over it, these
    /// stops give the combined whitening measured on K1 with content scrolled under the mockup's header (the
    /// darkest content pixel at each height over 12 scroll positions: y 48: 246, 72: 238, 96: 196, 108: 154,
    /// 120: 105, 132: 45, 144: 8), less what the blur adds.
    private static let softEdgeGradient: [EdgeEffectView.GradientStop] = [
        EdgeEffectView.GradientStop(location: 0.0, alpha: 0.625),
        EdgeEffectView.GradientStop(location: 0.32, alpha: 0.72),
        EdgeEffectView.GradientStop(location: 0.56, alpha: 0.714),
        EdgeEffectView.GradientStop(location: 0.64, alpha: 0.54),
        EdgeEffectView.GradientStop(location: 0.72, alpha: 0.394),
        EdgeEffectView.GradientStop(location: 0.80, alpha: 0.265),
        EdgeEffectView.GradientStop(location: 0.88, alpha: 0.126),
        EdgeEffectView.GradientStop(location: 0.96, alpha: 0.03),
        EdgeEffectView.GradientStop(location: 1.0, alpha: 0.0)
    ]
    /// How far the soft edge reaches past the static gradient (measured: whitening ends ~150 pt, the gradient at
    /// 136 on the reference device).
    private static let softEdgeExtension: CGFloat = 14.0

    let segmentNode = NewsSegmentNode()
    let shutterView = UIView()
    private let softEdgeView = EdgeEffectView()
    private let gradientView = EdgeEffectView()
    /// The top row's content: what a navigation transition lifts.
    private let rowContentView = NewsHeaderRowContentView()
    private let buttonsContainer = GlassBackgroundContainerView()
    private let buttons = ComponentView<Empty>()
    private var isContentLifted = false
    private var transitionRole: NavigationBarTransitionRole?
    private let glassHold = NavigationBarGlassHold()
    /// The island's tabs lent to the transition that draws the island (`NewsSegmentNode.lendTabs`), in a wrapper the
    /// transition animates.
    private var lentIslandContent: UIView?
    var transitionContentFrameUpdated: ((CGRect) -> Void)?
    private(set) var searchContentNode: NavigationBarSearchContentNode?
    private(set) var geometry: NewsHeaderGeometry?
    private(set) var blockOffset: CGFloat = 0.0
    private var params: Params?
    private var searchTheme: PresentationTheme?
    private var searchStrings: PresentationStrings?

    var activateSearch: (() -> Void)?
    var openMoreMenu: ((UIView) -> Void)?
    var selectSegment: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.shutterView.isUserInteractionEnabled = false
        self.shutterView.alpha = 0.0
        self.addSubview(self.shutterView)
        self.softEdgeView.isUserInteractionEnabled = false
        self.softEdgeView.alpha = 0.0
        self.addSubview(self.softEdgeView)
        self.gradientView.isUserInteractionEnabled = false
        self.addSubview(self.gradientView)
        self.addSubview(self.rowContentView)
        self.buttonsContainer.layer.anchorPoint = CGPoint()
        self.rowContentView.addSubview(self.buttonsContainer)
        self.rowContentView.addSubview(self.segmentNode.view)
        self.glassHold.changed = { [weak self] in
            self?.applyGlassVisibility()
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.glassHold.isHeld, event.flatMap({ $0.type == .touches }) ?? true, let geometry = self.geometry, newsHeaderTopBandContains(y: point.y, geometry: geometry) {
            // A touch on the top row while the transition's glass finishes above it: it hands over now, so the touch
            // finds the row's own capsule.
            self.glassHold.interrupt()
        }
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if let geometry = self.geometry, let params = self.params, !params.isSearchActive, newsHeaderTopBandContains(y: point.y, geometry: geometry) {
            // The top row's band takes its own touches, as a navigation bar does: its controls get them, and
            // the search scrolled under it or the rows beneath do not.
            if result.isDescendant(of: self.segmentNode.view) || result.isDescendant(of: self.buttonsContainer) {
                return result
            }
            return self
        }
        if result === self || result === self.shutterView || result === self.softEdgeView || result === self.gradientView {
            return nil
        }
        return result
    }

    /// The bar height search results are laid out under while search is active (as `ChatListNavigationBar`).
    var activeSearchNavigationHeight: CGFloat {
        let statusBarHeight = self.params?.layout.navigationBarStatusBarHeight ?? 0.0
        return statusBarHeight + NewsHeaderMetrics.activeSearchBarExtra + navigationBarSearchContentHeight
    }

    /// The header's bottom edge now: the search field's bottom, or the top row's once the field is under it.
    var currentBottom: CGFloat {
        guard let geometry = self.geometry else {
            return 0.0
        }
        return geometry.listTopInset - self.blockOffset
    }

    func update(params: Params, transition: ComponentTransition) -> NewsHeaderGeometry {
        let previousParams = self.params
        self.params = params
        let layout = params.layout
        let theme = params.theme
        let width = layout.size.width
        let statusBarHeight = layout.navigationBarStatusBarHeight ?? 0.0

        // The search block: the chat list's own search node, so it looks and activates as before.
        let searchContentNode: NavigationBarSearchContentNode
        if let current = self.searchContentNode {
            searchContentNode = current
            if self.searchTheme !== theme || self.searchStrings !== params.strings {
                searchContentNode.updateThemeAndPlaceholder(theme: theme, placeholder: params.strings.Common_Search, compactPlaceholder: params.strings.Common_Search)
            }
        } else {
            searchContentNode = NavigationBarSearchContentNode(theme: theme, placeholder: params.strings.Common_Search, compactPlaceholder: params.strings.Common_Search, activate: { [weak self] in
                self?.activateSearch?()
            })
            searchContentNode.view.layer.anchorPoint = CGPoint()
            // Under the shutter, so a tab switch whitens it with the lists (the mockup's search is a list row).
            self.insertSubview(searchContentNode.view, belowSubview: self.shutterView)
            self.searchContentNode = searchContentNode
        }
        self.searchTheme = theme
        self.searchStrings = params.strings
        // An active search takes the top row, so it ends left of a status island like the row's buttons (as in
        // ChatListNavigationBar).
        let searchRightInset = layout.safeInsets.right + (params.isSearchActive ? layout.navigationBarTrailingButtonsInset : 0.0)
        let _ = searchContentNode.updateLayout(size: CGSize(width: width, height: navigationBarSearchContentHeight), leftInset: layout.safeInsets.left, rightInset: searchRightInset, transition: transition.containedViewLayoutTransition)

        // The "…" button, laid out by the chat list's header component exactly as before (where it sits, its glass,
        // its morph into the menu).
        let rightInset = layout.safeInsets.right + 16.0
        let buttonsSize = self.buttons.update(
            transition: transition,
            component: AnyComponent(ChatListHeaderComponent(
                leftInset: layout.safeInsets.left + 16.0,
                rightInset: rightInset,
                trailingButtonsInset: layout.navigationBarTrailingButtonsInset,
                primaryContent: ChatListHeaderComponent.Content(
                    title: "",
                    titleComponent: nil,
                    chatListTitle: nil,
                    leftButton: nil,
                    rightButtons: [
                        NavigationBarComponent.Button(
                            id: "more",
                            content: .more,
                            action: { [weak self] sourceView in
                                self?.openMoreMenu?(sourceView)
                            }
                        )
                    ],
                    backPressed: nil
                ),
                secondaryContent: nil,
                secondaryTransition: 0.0,
                storySubscriptions: nil,
                storiesIncludeHidden: true,
                storiesFraction: 0.0,
                storiesUnlocked: false,
                uploadProgress: [:],
                context: params.context,
                theme: theme,
                strings: params.strings,
                openStatusSetup: { _ in
                },
                toggleIsLocked: {
                }
            )),
            environment: {},
            containerSize: CGSize(width: width, height: NewsHeaderMetrics.topRowHeight)
        )
        // ChatListHeaderComponent puts its right buttons this far from the right edge.
        let moreButtonMinX = width - rightInset - layout.navigationBarTrailingButtonsInset - 44.0

        let geometry = newsHeaderGeometry(
            width: width,
            statusBarHeight: statusBarHeight,
            islandFittingWidth: self.segmentNode.fittingWidth(context: params.context, theme: theme, strings: params.strings),
            moreButtonMinX: moreButtonMinX,
            searchNodeHeight: navigationBarSearchContentHeight,
            searchFieldFrameInNode: searchContentNode.placeholderNode.frame
        )
        self.geometry = geometry

        self.shutterView.backgroundColor = theme.list.plainBackgroundColor
        transition.setFrame(view: self.shutterView, frame: CGRect(origin: CGPoint(), size: layout.size))

        // With search open the edge ends where the results begin, under the field, so it does not lie over them;
        // the mockup's header gradient belongs to the resting header and fades out with its row.
        let softEdgeHeight = params.isSearchActive ? self.activeSearchNavigationHeight : geometry.edgeEffectHeight + NewsHeaderView.softEdgeExtension
        let softEdgeFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: softEdgeHeight))
        transition.setFrame(view: self.softEdgeView, frame: softEdgeFrame)
        self.softEdgeView.update(content: theme.list.plainBackgroundColor, blur: true, alpha: 1.0, contentGradient: NewsHeaderView.softEdgeGradient, rect: softEdgeFrame, edge: .top, edgeSize: softEdgeFrame.height, transition: transition)
        let gradientFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: geometry.edgeEffectHeight))
        transition.setFrame(view: self.gradientView, frame: gradientFrame)
        self.gradientView.update(content: theme.list.plainBackgroundColor, blur: false, alpha: 1.0, contentGradient: NewsHeaderView.staticGradient, rect: gradientFrame, edge: .top, edgeSize: gradientFrame.height, transition: transition)
        transition.setAlpha(view: self.gradientView, alpha: params.isSearchActive ? 0.0 : 1.0)

        // An open search field takes the top row and is drawn above the edge, as the bar's own content is; at
        // rest the search block is content and passes under it (and under the tab-switch shutter).
        if params.isSearchActive {
            if searchContentNode.view.superview === self, self.subviews.last !== searchContentNode.view {
                self.bringSubviewToFront(searchContentNode.view)
            }
        } else if let index = self.subviews.firstIndex(of: searchContentNode.view), let shutterIndex = self.subviews.firstIndex(of: self.shutterView), index > shutterIndex {
            self.insertSubview(searchContentNode.view, belowSubview: self.shutterView)
        }

        // Search takes the top row, as in the chat list: the row's content leaves upwards.
        let rowY = params.isSearchActive ? -geometry.topRow.height : geometry.topRow.minY
        let buttonsFrame = CGRect(origin: CGPoint(x: 0.0, y: rowY), size: buttonsSize)
        transition.setFrameWithAdditivePosition(view: self.buttonsContainer, frame: buttonsFrame)
        self.buttonsContainer.update(size: buttonsFrame.size, isDark: theme.overallDarkAppearance, transition: transition)
        if let buttonsView = self.buttons.view {
            if buttonsView.superview == nil {
                buttonsView.layer.anchorPoint = CGPoint()
                self.buttonsContainer.contentView.addSubview(buttonsView)
            }
            transition.setFrameWithAdditivePosition(view: buttonsView, frame: CGRect(origin: CGPoint(), size: buttonsFrame.size))
        }

        let islandFrame = geometry.island.offsetBy(dx: 0.0, dy: rowY - geometry.topRow.minY)
        transition.setFrame(view: self.segmentNode.view, frame: islandFrame)
        self.segmentNode.update(context: params.context, size: islandFrame.size, theme: theme, strings: params.strings, selectedIndex: params.selectedSegment, tabSwitchFraction: params.tabSwitchFraction, isSwitchingByDragging: params.isSwitchingByDragging, liftWhileSwitching: layout.deviceMetrics.type != .tablet, action: { [weak self] index in
            self?.selectSegment?(index)
        }, transition: transition)

        let rowAlpha: CGFloat = params.isSearchActive ? 0.0 : 1.0
        for view in [self.buttonsContainer, self.segmentNode.view] where view.alpha != rowAlpha {
            view.alpha = rowAlpha
            if previousParams != nil && !transition.animation.isImmediate {
                // ChatListNavigationBar's timing: out in 0.14 s, back in 0.3 s.
                view.layer.animateAlpha(from: 1.0 - rowAlpha, to: rowAlpha, duration: params.isSearchActive ? 0.14 : 0.3)
            }
        }

        // The top row's content spans the view, so its children keep this view's coordinates. While a transition holds
        // it, the transition places it and is told where it now goes.
        let rowContentFrame = CGRect(origin: CGPoint(), size: layout.size)
        if self.isContentLifted {
            self.transitionContentFrameUpdated?(rowContentFrame)
        } else {
            self.rowContentView.frame = rowContentFrame
        }
        self.glassHold.barLaidOut(content: self.transitionContent, rowFrame: self.transitionRowFrame)
        self.applyGlassVisibility()

        return geometry
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window == nil {
            self.glassHold.barLeftHierarchy()
        } else {
            self.glassHold.barEnteredHierarchy()
        }
    }

    // MARK: Navigation transitions

    private var headerComponentView: ChatListHeaderComponent.View? {
        return self.buttons.view as? ChatListHeaderComponent.View
    }

    private var transitionContent: NavigationBarComponent.Content? {
        return self.headerComponentView?.transitionContent
    }

    /// The "…" row's frame in the top row's content.
    private var transitionRowFrame: CGRect {
        guard let barView = self.headerComponentView?.navigationBarComponentView else {
            return CGRect()
        }
        return barView.convert(barView.bounds, to: self.rowContentView)
    }

    func takeView() -> NavigationBarTransitionTakeViewInfo? {
        guard !self.isContentLifted, self.params != nil, self.alpha >= 1.0, !self.isHidden, self.rowContentView.superview === self else {
            return nil
        }
        self.isContentLifted = true
        return NavigationBarTransitionTakeViewInfo(containingView: self, contentView: self.rowContentView)
    }

    func putBack() {
        guard self.isContentLifted else {
            return
        }
        self.isContentLifted = false
        self.transitionContentFrameUpdated = nil
        self.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        self.insertSubview(self.rowContentView, aboveSubview: self.gradientView)
        self.rowContentView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        // An open search field stays above the row, as `update` puts it.
        if let params = self.params, params.isSearchActive, let searchContentNode = self.searchContentNode, searchContentNode.view.superview === self {
            self.bringSubviewToFront(searchContentNode.view)
        }
    }

    func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        // In a role the transition draws the "…" capsule and the island.
        self.transitionRole = role
        self.applyGlassVisibility()
    }

    func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool {
        self.glassHold.hold(held, interrupted: interrupted, content: self.transitionContent, rowFrame: self.transitionRowFrame)
        self.applyGlassVisibility()
        return true
    }

    private func applyGlassVisibility() {
        let detached = self.transitionRole != nil || self.glassHold.isHeld
        self.headerComponentView?.navigationBarComponentView?.plattersDetached = detached
        self.segmentNode.isIslandDetached = detached && self.transitionTitlePill != nil
        if !detached {
            self.segmentNode.reclaimTabs()
            self.lentIslandContent = nil
        }
    }

    /// The island as the bar's title pill, in the top row's content; none while an open search hides the row.
    private var transitionTitlePill: NavigationBarTransitionTitlePill? {
        guard self.params != nil, self.buttonsContainer.alpha >= 0.5, self.segmentNode.view.superview === self.rowContentView else {
            return nil
        }
        let frame = self.segmentNode.view.convert(self.segmentNode.islandFrame, to: self.rowContentView)
        guard !frame.isEmpty else {
            return nil
        }
        return NavigationBarTransitionTitlePill(frame: frame, signature: ObjectIdentifier(self.segmentNode), lendContent: { [weak self] in
            // The live tabs, lent for as long as the transition draws the island (one wrapper per transition).
            guard let self, self.transitionRole != nil || self.glassHold.isHeld else {
                return UIView()
            }
            if let current = self.lentIslandContent {
                return current
            }
            let view = UIView(frame: CGRect(origin: CGPoint(), size: frame.size))
            view.isUserInteractionEnabled = false
            self.segmentNode.lendTabs(to: view)
            self.lentIslandContent = view
            return view
        })
    }

    var componentTransitionState: NavigationBarComponentTransitionState? {
        guard let params = self.params, let geometry = self.geometry, let headerView = self.headerComponentView, let content = headerView.transitionContent, let theme = headerView.navigationBarThemeValue, let strings = headerView.navigationBarStringsValue, let barView = headerView.navigationBarComponentView else {
            return nil
        }
        let layout = params.layout
        // The header's edges ride its screen with the search block, so it hands the transition no backdrop; an open
        // search hides the row (no capsules then).
        return NavigationBarComponentTransitionState(
            content: content,
            theme: theme,
            strings: strings,
            rowFrame: self.transitionRowFrame,
            rowAlpha: self.buttonsContainer.alpha,
            leftInset: layout.safeInsets.left + 16.0,
            rightInset: layout.safeInsets.right + 16.0,
            trailingButtonsInset: layout.navigationBarTrailingButtonsInset,
            sideColumnFrame: nil,
            hidesSideColumnButtons: false,
            backdropHeight: max(0.0, geometry.edgeEffectHeight - 24.0),
            backdropColor: nil,
            backdropAlpha: 0.0,
            backdropExtension: 0.0,
            leadingPressScale: barView.detachedLeftPressScale,
            leadingPressGlow: barView.detachedLeftPressGlow,
            trailingPressScales: barView.detachedRightPressScales,
            trailingPressGlows: barView.detachedRightPressGlows,
            titlePill: self.transitionTitlePill
        )
    }

    /// Moves the search block for the list's scroll offset (0 at rest, positive scrolled, negative overscrolled).
    func applyScroll(listOffset: CGFloat, transition: ComponentTransition) {
        guard let geometry = self.geometry, let params = self.params, let searchContentNode = self.searchContentNode else {
            return
        }
        transition.setAlpha(view: self.softEdgeView, alpha: newsHeaderSoftEdgeAlpha(listOffset: listOffset, isSearchActive: params.isSearchActive))
        let frame: CGRect
        if params.isSearchActive {
            self.blockOffset = 0.0
            let statusBarHeight = params.layout.navigationBarStatusBarHeight ?? 0.0
            frame = CGRect(origin: CGPoint(x: 0.0, y: statusBarHeight + NewsHeaderMetrics.activeSearchNodeOffset), size: geometry.searchNodeAtRest.size)
        } else {
            self.blockOffset = newsHeaderBlockOffset(listOffset: listOffset, blockHeight: geometry.blockHeight)
            frame = geometry.searchNodeAtRest.offsetBy(dx: 0.0, dy: -newsHeaderSearchTravel(listOffset: listOffset, geometry: geometry))
        }
        transition.setFrameWithAdditivePosition(view: searchContentNode.view, frame: frame)
    }
}
