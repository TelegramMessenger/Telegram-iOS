import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import TelegramPresentationData
import ComponentDisplayAdapters
import SearchUI
import AccountContext
import TelegramCore
import StoryPeerListComponent
import EdgeEffect
import GlassBackgroundComponent
import SideColumnLayout
import NavigationBarComponent

private func searchScrollHeightValue() -> CGFloat {
    return 54.0
}

private func storiesHeightValue() -> CGFloat {
    return 96.0
}

public final class ChatListNavigationBar: Component {
    public final class AnimationHint {
        let disableStoriesAnimations: Bool
        let crossfadeStoryPeers: Bool
        
        public init(disableStoriesAnimations: Bool, crossfadeStoryPeers: Bool) {
            self.disableStoriesAnimations = disableStoriesAnimations
            self.crossfadeStoryPeers = crossfadeStoryPeers
        }
    }

    public struct Search: Equatable {
        public var isEnabled: Bool
        public var placeholder: String?
        public var displayGlassBackgroundWhenInactive: Bool
        public var alignPlaceholderToLeftWhenInactive: Bool

        public init(isEnabled: Bool, placeholder: String? = nil, displayGlassBackgroundWhenInactive: Bool = false, alignPlaceholderToLeftWhenInactive: Bool = false) {
            self.isEnabled = isEnabled
            self.placeholder = placeholder
            self.displayGlassBackgroundWhenInactive = displayGlassBackgroundWhenInactive
            self.alignPlaceholderToLeftWhenInactive = alignPlaceholderToLeftWhenInactive
        }
    }
    
    public struct ActiveSearch: Equatable {
        public var isExternal: Bool
        
        public init(isExternal: Bool) {
            self.isExternal = isExternal
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let statusBarHeight: CGFloat
    public let leftInset: CGFloat
    public let rightInset: CGFloat
    /// iPhone Duo: see `ChatListHeaderComponent.trailingButtonsInset`.
    public let trailingButtonsInset: CGFloat
    public let search: Search?
    public let activeSearch: ActiveSearch?
    public let primaryContent: ChatListHeaderComponent.Content?
    public let secondaryContent: ChatListHeaderComponent.Content?
    public let secondaryTransition: CGFloat
    public let storySubscriptions: EngineStorySubscriptions?
    public let storiesIncludeHidden: Bool
    public let uploadProgress: [EnginePeer.Id: Float]
    public let headerPanels: AnyComponent<Empty>?
    public let tabsNode: ASDisplayNode?
    public let tabsNodeIsSearch: Bool
    public let accessoryPanelContainer: ASDisplayNode?
    public let accessoryPanelContainerHeight: CGFloat
    public let hasEdgeEffect: Bool
    public let edgeEffectColor: UIColor?
    public let hasOwnGlassContainer: Bool
    public let activateSearch: (NavigationBarSearchContentNode) -> Void
    public let openStatusSetup: (UIView) -> Void
    public let allowAutomaticOrder: () -> Void
    /// iPhone Duo: where the header's side column goes, in this bar's coordinates (the bar sits at its
    /// host's origin); nil keeps every button in the row.
    public let sideColumn: SideColumnRegion?
    public let openSideColumnOverflow: ((UIView, [NavigationBarComponent.OverflowItem]) -> Void)?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        statusBarHeight: CGFloat,
        leftInset: CGFloat,
        rightInset: CGFloat,
        trailingButtonsInset: CGFloat = 0.0,
        search: Search?,
        activeSearch: ActiveSearch?,
        primaryContent: ChatListHeaderComponent.Content?,
        secondaryContent: ChatListHeaderComponent.Content?,
        secondaryTransition: CGFloat,
        storySubscriptions: EngineStorySubscriptions?,
        storiesIncludeHidden: Bool,
        uploadProgress: [EnginePeer.Id: Float],
        headerPanels: AnyComponent<Empty>?,
        tabsNode: ASDisplayNode?,
        tabsNodeIsSearch: Bool,
        accessoryPanelContainer: ASDisplayNode?,
        accessoryPanelContainerHeight: CGFloat,
        hasEdgeEffect: Bool = true,
        edgeEffectColor: UIColor? = nil,
        hasOwnGlassContainer: Bool = true,
        activateSearch: @escaping (NavigationBarSearchContentNode) -> Void,
        openStatusSetup: @escaping (UIView) -> Void,
        allowAutomaticOrder: @escaping () -> Void,
        sideColumn: SideColumnRegion? = nil,
        openSideColumnOverflow: ((UIView, [NavigationBarComponent.OverflowItem]) -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.statusBarHeight = statusBarHeight
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.trailingButtonsInset = trailingButtonsInset
        self.search = search
        self.activeSearch = activeSearch
        self.primaryContent = primaryContent
        self.secondaryContent = secondaryContent
        self.secondaryTransition = secondaryTransition
        self.storySubscriptions = storySubscriptions
        self.storiesIncludeHidden = storiesIncludeHidden
        self.uploadProgress = uploadProgress
        self.headerPanels = headerPanels
        self.tabsNode = tabsNode
        self.tabsNodeIsSearch = tabsNodeIsSearch
        self.accessoryPanelContainer = accessoryPanelContainer
        self.accessoryPanelContainerHeight = accessoryPanelContainerHeight
        self.hasEdgeEffect = hasEdgeEffect
        self.edgeEffectColor = edgeEffectColor
        self.hasOwnGlassContainer = hasOwnGlassContainer
        self.activateSearch = activateSearch
        self.openStatusSetup = openStatusSetup
        self.allowAutomaticOrder = allowAutomaticOrder
        self.sideColumn = sideColumn
        self.openSideColumnOverflow = openSideColumnOverflow
    }

    public static func ==(lhs: ChatListNavigationBar, rhs: ChatListNavigationBar) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.statusBarHeight != rhs.statusBarHeight {
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
        if lhs.search != rhs.search {
            return false
        }
        if lhs.activeSearch != rhs.activeSearch {
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
        if lhs.storySubscriptions != rhs.storySubscriptions {
            return false
        }
        if lhs.storiesIncludeHidden != rhs.storiesIncludeHidden {
            return false
        }
        if lhs.uploadProgress != rhs.uploadProgress {
            return false
        }
        if lhs.headerPanels != rhs.headerPanels {
            return false
        }
        if lhs.tabsNode !== rhs.tabsNode {
            return false
        }
        if lhs.tabsNodeIsSearch != rhs.tabsNodeIsSearch {
            return false
        }
        if lhs.accessoryPanelContainer !== rhs.accessoryPanelContainer {
            return false
        }
        if lhs.accessoryPanelContainerHeight != rhs.accessoryPanelContainerHeight {
            return false
        }
        if lhs.hasEdgeEffect != rhs.hasEdgeEffect {
            return false
        }
        if lhs.edgeEffectColor != rhs.edgeEffectColor {
            return false
        }
        if lhs.hasOwnGlassContainer != rhs.hasOwnGlassContainer {
            return false
        }
        if lhs.sideColumn != rhs.sideColumn {
            return false
        }
        return true
    }
    
    private struct CurrentLayout {
        var size: CGSize
        
        init(size: CGSize) {
            self.size = size
        }
    }
    
    public static let searchScrollHeight: CGFloat = searchScrollHeightValue()
    public static let storiesScrollHeight: CGFloat = storiesHeightValue()

    public final class View: UIView {
        private let edgeEffectView: EdgeEffectView

        // Layout remains in navigation bar coordinates when this view is hosted externally.
        public var edgeEffectBackgroundView: UIView {
            return self.edgeEffectView
        }
        
        private var headerBackgroundContainer: UIView
        public let headerContent = ComponentView<Empty>()
        
        public private(set) var searchContentNode: NavigationBarSearchContentNode?
        
        private var component: ChatListNavigationBar?
        private weak var state: EmptyComponentState?
        private var scrollTheme: PresentationTheme?
        private var scrollStrings: PresentationStrings?
        private var scrollSearch: Search?
        private var scrollHasOwnGlassContainer: Bool?
        
        private var currentLayout: CurrentLayout?
        private var rawScrollOffset: CGFloat?
        private var currentAllowAvatarsExpansion: Bool = false
        public private(set) var clippedScrollOffset: CGFloat?
        
        public var deferScrollApplication: Bool = false
        private var hasDeferredScrollOffset: Bool = false
        
        public private(set) var storiesUnlocked: Bool = false
        
        private let bottomContentsContainer: UIView
        
        private var tabsNode: ASDisplayNode?
        private var tabsNodeIsSearch: Bool = false
        private weak var disappearingTabsView: UIView?
        private var disappearingTabsViewSearch: Bool = false
        
        private var headerPanelsView: ComponentView<Empty>?
        private var disappearingHeaderPanels: ComponentView<Empty>?
        public var headerPanels: UIView? {
            return self.headerPanelsView?.view
        }
        
        private var currentHeaderComponent: ChatListHeaderComponent?

        private var currentHeight: CGFloat = 0.0
        private var pinnedFraction: CGFloat = 0.0
        private var sideColumnContainer: GlassBackgroundContainerView?
        private var appliedSideColumn: SideColumnRegion?

        /// The edge effect's tint and gradient length; a navigation transition draws the same backdrop
        /// (`componentTransitionState`).
        fileprivate static let edgeEffectTintAlpha: CGFloat = 0.85
        fileprivate static let edgeEffectEdgeLength: CGFloat = 54.0

        /// Everything the header draws; a navigation transition lifts it (`takeView()`) while the view stays in the
        /// screen.
        fileprivate let contentView = UIView()
        fileprivate var isContentLifted = false
        fileprivate var transitionRole: NavigationBarTransitionRole?
        /// The transition left the edge effect to this header (`updateKeepsOwnBackdrop`).
        fileprivate var keepsOwnBackdrop = false
        fileprivate let glassHold = NavigationBarGlassHold()
        fileprivate var liftedScrollGate = NavigationBarLiftedScrollGate()
        public var transitionContentFrameUpdated: ((CGRect) -> Void)?
        /// Whether the iPhone Duo column is shown (`updateSideColumn`); a transition role or a glass hold hides it on
        /// top of this.
        fileprivate var sideColumnIsVisible = false
        fileprivate var currentEdgeEffectColor: UIColor?
        
        override public init(frame: CGRect) {
            self.edgeEffectView = EdgeEffectView()
            
            self.headerBackgroundContainer = SparseContainerView()
            self.headerBackgroundContainer.layer.anchorPoint = CGPoint()
            
            self.bottomContentsContainer = UIView()
            self.bottomContentsContainer.layer.anchorPoint = CGPoint()
            
            super.init(frame: frame)
            
            self.addSubview(self.contentView)
            self.contentView.addSubview(self.edgeEffectView)
            self.contentView.addSubview(self.bottomContentsContainer)

            self.glassHold.changed = { [weak self] in
                self?.applyGlassVisibility()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.alpha.isZero || self.isContentLifted {
                return nil
            }
            if self.glassHold.isHeld, event.flatMap({ $0.type == .touches }) ?? true {
                var isOnHeader = point.y >= 0.0 && point.y < self.currentHeight
                if !isOnHeader, let sideColumnContainer = self.sideColumnContainer, self.sideColumnIsVisible, let columnView = (self.headerContent.view as? ChatListHeaderComponent.View)?.sideColumnView {
                    isOnHeader = sideColumnContainer.frame.contains(point) && columnView.hitTest(self.convert(point, to: columnView), with: event) != nil
                }
                if isOnHeader {
                    // A touch on the header while the transition's glass finishes above it: it hands over now, so the
                    // touch finds the header's own capsules.
                    self.glassHold.interrupt()
                }
            }
            // iPhone Duo: the side column hangs below the bar. Only its circle and capsule take touches
            // (`sideColumnView` is a sparse container).
            if let sideColumnContainer = self.sideColumnContainer, sideColumnContainer.isUserInteractionEnabled, sideColumnContainer.alpha > 0.0, let headerView = self.headerContent.view as? ChatListHeaderComponent.View, let columnView = headerView.sideColumnView {
                if let result = columnView.hitTest(self.convert(point, to: columnView), with: event) {
                    return result
                }
            }
            if point.y >= self.currentHeight {
                return nil
            }
            for view in self.contentView.subviews.reversed() {
                if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                    return result
                }
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        override public func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil {
                self.glassHold.barLeftHierarchy()
            } else {
                self.glassHold.barEnteredHierarchy()
            }
        }

        /// iPhone Duo: hosts the header's side column at the region in a glass container of its own (the
        /// row's container is only the row's size). It fades during search and does not follow the row up.
        private func updateSideColumn(component: ChatListNavigationBar, transition: ComponentTransition) {
            self.sideColumnIsVisible = component.sideColumn != nil && component.activeSearch == nil
            let change = sideColumnPlacementChange(from: self.appliedSideColumn, to: component.sideColumn)
            self.appliedSideColumn = component.sideColumn
            guard let sideColumnView = (self.headerContent.view as? ChatListHeaderComponent.View)?.sideColumnView else {
                return
            }
            if component.sideColumn == nil && self.sideColumnContainer == nil {
                return
            }
            let container: GlassBackgroundContainerView
            if let current = self.sideColumnContainer {
                container = current
            } else {
                container = GlassBackgroundContainerView()
                container.alpha = 0.0
                self.sideColumnContainer = container
                self.contentView.addSubview(container)
            }
            if sideColumnView.superview !== container.contentView {
                container.contentView.addSubview(sideColumnView)
            }
            if let region = component.sideColumn {
                var frameTransition = transition
                switch change {
                case .appear:
                    frameTransition = .immediate
                case .move:
                    // A rotation or the strip switching sides: fade instead of flying across the list.
                    frameTransition = .immediate
                    if case let .curve(duration, _) = transition.animation, container.alpha > 0.0, let snapshotView = container.snapshotView(afterScreenUpdates: false) {
                        snapshotView.isUserInteractionEnabled = false
                        snapshotView.frame = container.frame
                        self.contentView.insertSubview(snapshotView, aboveSubview: container)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                        container.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5, delay: duration * 0.5)
                    }
                case .none, .disappear, .animate:
                    break
                }
                frameTransition.setFrame(view: container, frame: region.frame)
                container.update(size: region.frame.size, isDark: component.theme.overallDarkAppearance, transition: frameTransition)
                frameTransition.setFrame(view: sideColumnView, frame: CGRect(origin: CGPoint(), size: region.frame.size))
            }
            self.applyGlassVisibility(transition: transition)
        }
        
        public func applyCurrentScroll(transition: ComponentTransition) {
            if let rawScrollOffset = self.rawScrollOffset, self.hasDeferredScrollOffset {
                self.applyScroll(offset: rawScrollOffset, allowAvatarsExpansion: self.currentAllowAvatarsExpansion, transition: transition)
            }
        }
        
        public func applyScroll(offset: CGFloat, allowAvatarsExpansion: Bool, forceUpdate: Bool = false, transition: ComponentTransition) {
            let transition = transition
            
            self.rawScrollOffset = offset
            let allowAvatarsExpansionUpdated = self.currentAllowAvatarsExpansion != allowAvatarsExpansion
            self.currentAllowAvatarsExpansion = allowAvatarsExpansion

            if !self.liftedScrollGate.offer(offset) {
                // Lifted by a navigation transition: the header rides its screen as it was; the latest scroll applies
                // at put-back.
                self.hasDeferredScrollOffset = true
                return
            }
            
            if self.deferScrollApplication && !forceUpdate {
                self.hasDeferredScrollOffset = true
                return
            }
            
            guard let component = self.component, let currentLayout = self.currentLayout else {
                return
            }

            let searchPresentationUpdated = component.theme !== self.scrollTheme
                || component.strings !== self.scrollStrings
                || component.search != self.scrollSearch
                || component.hasOwnGlassContainer != self.scrollHasOwnGlassContainer
            self.scrollTheme = component.theme
            self.scrollStrings = component.strings
            self.scrollSearch = component.search
            self.scrollHasOwnGlassContainer = component.hasOwnGlassContainer
            
            let searchOffsetDistance: CGFloat = ChatListNavigationBar.searchScrollHeight
            
            let minContentOffset: CGFloat
            if component.search != nil {
                minContentOffset = ChatListNavigationBar.searchScrollHeight
            } else {
                minContentOffset = 0.0
            }
            
            let clippedScrollOffset = min(minContentOffset, offset)
            if self.clippedScrollOffset == clippedScrollOffset
                && !self.hasDeferredScrollOffset
                && !forceUpdate
                && !allowAvatarsExpansionUpdated
                && !searchPresentationUpdated {
                return
            }
            self.hasDeferredScrollOffset = false
            self.clippedScrollOffset = clippedScrollOffset
            
            let visibleSize = CGSize(width: currentLayout.size.width, height: max(0.0, currentLayout.size.height - clippedScrollOffset))
            
            let previousHeight = self.currentHeight

            self.currentHeight = visibleSize.height
            
            var embeddedSearchBarExpansionHeight: CGFloat = 0.0
            var searchFrameValue: CGRect?
            if let search = component.search {
                if let searchContentNode = self.searchContentNode, searchContentNode.hasOwnGlassContainer != component.hasOwnGlassContainer {
                    searchContentNode.view.removeFromSuperview()
                    self.searchContentNode = nil
                }
                let searchContentNode: NavigationBarSearchContentNode
                if let current = self.searchContentNode {
                    searchContentNode = current
                    if searchPresentationUpdated {
                        let placeholder = search.placeholder ?? component.strings.Common_Search
                        searchContentNode.updateThemeAndPlaceholder(
                            theme: component.theme,
                            placeholder: placeholder,
                            compactPlaceholder: placeholder,
                            displayGlassBackgroundWhenInactive: search.displayGlassBackgroundWhenInactive,
                            alignPlaceholderToLeftWhenInactive: search.alignPlaceholderToLeftWhenInactive
                        )
                    }
                } else {
                    let placeholder = search.placeholder ?? component.strings.Common_Search
                    
                    searchContentNode = NavigationBarSearchContentNode(
                        theme: component.theme,
                        placeholder: placeholder,
                        compactPlaceholder: placeholder,
                        displayGlassBackgroundWhenInactive: search.displayGlassBackgroundWhenInactive,
                        alignPlaceholderToLeftWhenInactive: search.alignPlaceholderToLeftWhenInactive,
                        hasOwnGlassContainer: component.hasOwnGlassContainer,
                        activate: { [weak self] in
                            guard let self, let component = self.component, let searchContentNode = self.searchContentNode else {
                                return
                            }
                            component.activateSearch(searchContentNode)
                        }
                    )
                    searchContentNode.view.layer.anchorPoint = CGPoint()
                    self.searchContentNode = searchContentNode
                    self.contentView.addSubview(searchContentNode.view)
                }
                
                let searchSize = CGSize(width: currentLayout.size.width, height: navigationBarSearchContentHeight)
                var searchFrame = CGRect(origin: CGPoint(x: 0.0, y: visibleSize.height - searchSize.height - self.bottomContentsContainer.bounds.height - 2.0), size: searchSize)
                if let activeSearch = component.activeSearch, !activeSearch.isExternal {
                    searchFrame.origin.y = component.statusBarHeight + 8.0
                }
                if component.tabsNode != nil {
                    searchFrame.origin.y -= 40.0
                }
                if let activeSearch = component.activeSearch {
                    if !activeSearch.isExternal {
                        searchFrame.origin.y -= component.accessoryPanelContainerHeight
                    }
                } else {
                    searchFrame.origin.y -= component.accessoryPanelContainerHeight
                }
                
                let clippedSearchOffset = max(0.0, min(clippedScrollOffset, searchOffsetDistance))
                let searchOffsetFraction = clippedSearchOffset / searchOffsetDistance
                searchContentNode.expansionProgress = 1.0 - searchOffsetFraction
                embeddedSearchBarExpansionHeight = 60.0 - floorToScreenPixels((1.0 - searchOffsetFraction) * searchSize.height)
                if searchOffsetFraction > 0.0 {
                    searchFrame.origin.y -= (60.0 - 44.0) * 0.5 * searchOffsetFraction
                }
                
                searchFrameValue = searchFrame
                transition.setFrameWithAdditivePosition(view: searchContentNode.view, frame: searchFrame)
                
                // An active search takes the bar's row, so it ends left of a status island like the bar's buttons.
                var searchRightInset = component.rightInset
                if let activeSearch = component.activeSearch, !activeSearch.isExternal {
                    searchRightInset += component.trailingButtonsInset
                }
                let _ = searchContentNode.updateLayout(size: searchSize, leftInset: component.leftInset, rightInset: searchRightInset, transition: transition.containedViewLayoutTransition)
                
                var searchAlpha: CGFloat = search.isEnabled ? 1.0 : 0.5
                if let activeSearch = component.activeSearch, activeSearch.isExternal {
                    searchAlpha = 0.0
                }
                transition.setAlpha(view: searchContentNode.view, alpha: searchAlpha)
                searchContentNode.isUserInteractionEnabled = search.isEnabled
            } else {
                if let searchContentNode = self.searchContentNode {
                    self.searchContentNode = nil
                    searchContentNode.view.removeFromSuperview()
                }
            }
            
            var edgeEffectHeight: CGFloat = currentLayout.size.height + 14.0
            if component.search != nil {
                if component.activeSearch != nil {
                } else {
                    edgeEffectHeight -= embeddedSearchBarExpansionHeight
                }
            } else if component.activeSearch != nil {
            }
            edgeEffectHeight = max(0.0, edgeEffectHeight)
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: currentLayout.size.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: nil, blur: true, alpha: ChatListNavigationBar.View.edgeEffectTintAlpha, rect: edgeEffectFrame, edge: .top, edgeSize: min(ChatListNavigationBar.View.edgeEffectEdgeLength, edgeEffectHeight), transition: transition)
            
            let headerTransition = transition
            
            let storiesOffsetFraction: CGFloat
            let storiesUnlocked: Bool
            if allowAvatarsExpansion {
                storiesOffsetFraction = max(0.0, min(4.0, -offset / ChatListNavigationBar.storiesScrollHeight))
                if offset <= -65.0 {
                    storiesUnlocked = true
                } else if offset >= -61.0 {
                    storiesUnlocked = false
                } else {
                    storiesUnlocked = self.storiesUnlocked
                }
            } else {
                storiesOffsetFraction = 0.0
                storiesUnlocked = false
            }
            
            if allowAvatarsExpansion, transition.animation.isImmediate, let storySubscriptions = component.storySubscriptions, !storySubscriptions.items.isEmpty {
                if self.storiesUnlocked != storiesUnlocked {
                    if storiesUnlocked {
                        HapticFeedback().tap()
                    } else {
                        HapticFeedback().impact(.veryLight)
                    }
                }
            }
            if self.storiesUnlocked != storiesUnlocked, !storiesUnlocked {
                component.allowAutomaticOrder()
            }
            self.storiesUnlocked = storiesUnlocked
            
            let headerComponent = ChatListHeaderComponent(
                leftInset: component.leftInset + 16.0,
                rightInset: component.rightInset + 16.0,
                trailingButtonsInset: component.trailingButtonsInset,
                primaryContent: component.primaryContent,
                secondaryContent: component.secondaryContent,
                secondaryTransition: component.secondaryTransition,
                storySubscriptions: component.storySubscriptions,
                storiesIncludeHidden: component.storiesIncludeHidden,
                storiesFraction: storiesOffsetFraction,
                storiesUnlocked: storiesUnlocked,
                uploadProgress: component.uploadProgress,
                context: component.context,
                theme: component.theme,
                strings: component.strings,
                openStatusSetup: { [weak self] sourceView in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.openStatusSetup(sourceView)
                },
                toggleIsLocked: { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.context.sharedContext.appLockContext.lock()
                },
                sideColumnLength: component.sideColumn?.frame.height,
                openSideColumnOverflow: component.openSideColumnOverflow
            )
            
            let animationHint = transition.userData(AnimationHint.self)
            
            var animationDuration: Double?
            if case let .curve(duration, _) = transition.animation {
                animationDuration = duration
            }
            
            self.currentHeaderComponent = headerComponent
            let headerContentSize = self.headerContent.update(
                transition: headerTransition.withUserData(StoryPeerListComponent.AnimationHint(
                    duration: animationDuration,
                    allowAvatarsExpansionUpdated: allowAvatarsExpansionUpdated && allowAvatarsExpansion,
                    bounce: transition.animation.isImmediate,
                    disableAnimations: animationHint?.disableStoriesAnimations ?? false
                )),
                component: AnyComponent(headerComponent),
                environment: {},
                containerSize: CGSize(width: currentLayout.size.width, height: 44.0)
            )
            let headerContentY: CGFloat
            if component.activeSearch != nil {
                headerContentY = -headerContentSize.height
            } else {
                // Also without a status bar (iPhone landscape), matching the regular navigation bar's
                // 10pt button inset there.
                headerContentY = component.statusBarHeight + 10.0
            }
            let headerContentFrame = CGRect(origin: CGPoint(x: 0.0, y: headerContentY), size: headerContentSize)
            if let headerContentView = self.headerContent.view {
                if component.hasOwnGlassContainer != (self.headerBackgroundContainer is GlassBackgroundContainerView) {
                    let previousContainer = self.headerBackgroundContainer
                    let container: UIView = component.hasOwnGlassContainer ? GlassBackgroundContainerView() : SparseContainerView()
                    container.layer.anchorPoint = CGPoint()
                    container.bounds = previousContainer.bounds
                    container.center = previousContainer.center
                    if let superview = previousContainer.superview {
                        superview.insertSubview(container, aboveSubview: previousContainer)
                    }
                    self.headerBackgroundContainer = container
                    previousContainer.removeFromSuperview()
                }
                if self.headerBackgroundContainer.superview == nil {
                    self.contentView.addSubview(self.headerBackgroundContainer)
                }
                let headerContainerContentView: UIView
                if let glassContainer = self.headerBackgroundContainer as? GlassBackgroundContainerView {
                    headerContainerContentView = glassContainer.contentView
                } else {
                    headerContainerContentView = self.headerBackgroundContainer
                }
                if headerContentView.superview !== headerContainerContentView {
                    headerContentView.layer.anchorPoint = CGPoint()
                    headerContainerContentView.addSubview(headerContentView)
                }
                transition.setFrameWithAdditivePosition(view: self.headerBackgroundContainer, frame: headerContentFrame)
                if let glassContainer = self.headerBackgroundContainer as? GlassBackgroundContainerView {
                    glassContainer.update(size: headerContentFrame.size, isDark: component.theme.overallDarkAppearance, transition: transition)
                }
                transition.setFrameWithAdditivePosition(view: headerContentView, frame: CGRect(origin: CGPoint(), size: headerContentFrame.size))
                
                if (component.activeSearch != nil) != (headerContentView.alpha == 0.0) {
                    headerContentView.alpha = component.activeSearch != nil ? 0.0 : 1.0
                    
                    if !transition.animation.isImmediate {
                        if component.activeSearch != nil {
                            headerContentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.14)
                        } else {
                            headerContentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                    }
                }
            }
            
            self.updateSideColumn(component: component, transition: transition)
            
            let bottomContentsContainerPosition: CGPoint
            if let activeSearch = component.activeSearch {
                if let searchFrameValue, !activeSearch.isExternal {
                    bottomContentsContainerPosition = CGPoint(x: 0.0, y: searchFrameValue.maxY - 8.0)
                } else {
                    bottomContentsContainerPosition = CGPoint(x: 0.0, y: -self.bottomContentsContainer.bounds.height)
                }
            } else {
                bottomContentsContainerPosition = CGPoint(x: 0.0, y: visibleSize.height - self.bottomContentsContainer.bounds.height)
            }
            transition.setPosition(view: self.bottomContentsContainer, position: bottomContentsContainerPosition)
            
            if component.tabsNode !== self.tabsNode {
                if let tabsNode = self.tabsNode {
                    tabsNode.layer.anchorPoint = CGPoint()
                    
                    self.tabsNode = nil
                    let disappearingTabsView = tabsNode.view
                    self.disappearingTabsViewSearch = self.tabsNodeIsSearch
                    self.disappearingTabsView = disappearingTabsView
                    transition.setAlpha(view: tabsNode.view, alpha: 0.0, completion: { [weak self, weak disappearingTabsView] _ in
                        guard let self, let component = self.component, let disappearingTabsView else {
                            return
                        }
                        if disappearingTabsView !== component.tabsNode?.view {
                            disappearingTabsView.removeFromSuperview()
                        }
                    })
                }
            }
            
            var tabsFrame = CGRect(origin: CGPoint(x: 0.0, y: visibleSize.height), size: CGSize(width: visibleSize.width, height: 46.0))
            if component.activeSearch != nil {
            } else {
                tabsFrame.origin.y -= component.accessoryPanelContainerHeight
            }
            if component.tabsNode != nil {
                tabsFrame.origin.y -= 46.0
            }
            
            var accessoryPanelContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: visibleSize.height), size: CGSize(width: visibleSize.width, height: component.accessoryPanelContainerHeight))
            if component.activeSearch != nil {
            } else {
                accessoryPanelContainerFrame.origin.y -= component.accessoryPanelContainerHeight
            }
            
            if let disappearingTabsView = self.disappearingTabsView {
                disappearingTabsView.layer.anchorPoint = CGPoint()
                transition.setFrameWithAdditivePosition(view: disappearingTabsView, frame: tabsFrame.offsetBy(dx: 0.0, dy: self.disappearingTabsViewSearch ? (-currentLayout.size.height + 2.0) : 0.0))
            }
            
            if let tabsNode = component.tabsNode {
                self.tabsNode = tabsNode
                self.tabsNodeIsSearch = component.tabsNodeIsSearch
                
                var tabsNodeTransition = transition
                if tabsNode.view.superview !== self.contentView {
                    tabsNode.view.layer.anchorPoint = CGPoint()
                    tabsNodeTransition = .immediate
                    tabsNode.view.alpha = 1.0
                    self.contentView.addSubview(tabsNode.view)
                    if !transition.animation.isImmediate {
                        tabsNode.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        
                        if component.tabsNodeIsSearch {
                            transition.animatePosition(view: tabsNode.view, from: CGPoint(x: 0.0, y: previousHeight - visibleSize.height + 44.0), to: CGPoint(), additive: true)
                        } else {
                            transition.animatePosition(view: tabsNode.view, from: CGPoint(x: 0.0, y: previousHeight - visibleSize.height), to: CGPoint(), additive: true)
                        }
                    }
                } else {
                    transition.setAlpha(view: tabsNode.view, alpha: 1.0)
                }
                
                tabsNodeTransition.setFrameWithAdditivePosition(view: tabsNode.view, frame: tabsFrame.offsetBy(dx: 0.0, dy: component.tabsNodeIsSearch ? (-currentLayout.size.height + 2.0) : 0.0))
            }
            
            if let accessoryPanelContainer = component.accessoryPanelContainer {
                var tabsNodeTransition = transition
                if accessoryPanelContainer.view.superview !== self.contentView {
                    accessoryPanelContainer.view.layer.anchorPoint = CGPoint()
                    accessoryPanelContainer.clipsToBounds = true
                    tabsNodeTransition = .immediate
                    accessoryPanelContainer.view.alpha = 1.0
                    self.contentView.addSubview(accessoryPanelContainer.view)
                    if !transition.animation.isImmediate {
                        accessoryPanelContainer.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                } else {
                    transition.setAlpha(view: accessoryPanelContainer.view, alpha: 1.0)
                }
                
                tabsNodeTransition.setFrameWithAdditivePosition(view: accessoryPanelContainer.view, frame: accessoryPanelContainerFrame)
            }

            if let headerView = self.headerContent.view as? ChatListHeaderComponent.View {
                // The header changed under the transition's glass: it hands over now.
                self.glassHold.barLaidOut(content: headerView.transitionContent, rowFrame: self.transitionRowFrame)
            }
        }
        
        public func openEmojiStatusSetup() {
            if let headerContentView = self.headerContent.view as? ChatListHeaderComponent.View {
                headerContentView.openEmojiStatusSetup()
            }
        }
        
        public func updateStoryUploadProgress(storyUploadProgress: [EnginePeer.Id: Float]) {
            guard let component = self.component else {
                return
            }
            if component.uploadProgress != storyUploadProgress {
                self.component = ChatListNavigationBar(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    statusBarHeight: component.statusBarHeight,
                    leftInset: component.leftInset,
                    rightInset: component.rightInset,
                    trailingButtonsInset: component.trailingButtonsInset,
                    search: component.search,
                    activeSearch: component.activeSearch,
                    primaryContent: component.primaryContent,
                    secondaryContent: component.secondaryContent,
                    secondaryTransition: component.secondaryTransition,
                    storySubscriptions: component.storySubscriptions,
                    storiesIncludeHidden: component.storiesIncludeHidden,
                    uploadProgress: storyUploadProgress,
                    headerPanels: component.headerPanels,
                    tabsNode: component.tabsNode,
                    tabsNodeIsSearch: component.tabsNodeIsSearch,
                    accessoryPanelContainer: component.accessoryPanelContainer,
                    accessoryPanelContainerHeight: component.accessoryPanelContainerHeight,
                    hasEdgeEffect: component.hasEdgeEffect,
                    edgeEffectColor: component.edgeEffectColor,
                    hasOwnGlassContainer: component.hasOwnGlassContainer,
                    activateSearch: component.activateSearch,
                    openStatusSetup: component.openStatusSetup,
                    allowAutomaticOrder: component.allowAutomaticOrder,
                    sideColumn: component.sideColumn,
                    openSideColumnOverflow: component.openSideColumnOverflow
                )
                if let currentLayout = self.currentLayout, let headerComponent = self.currentHeaderComponent {
                    let headerComponent = ChatListHeaderComponent(
                        leftInset: headerComponent.leftInset,
                        rightInset: headerComponent.rightInset,
                        trailingButtonsInset: headerComponent.trailingButtonsInset,
                        primaryContent: headerComponent.primaryContent,
                        secondaryContent: headerComponent.secondaryContent,
                        secondaryTransition: headerComponent.secondaryTransition,
                        storySubscriptions: headerComponent.storySubscriptions,
                        storiesIncludeHidden: headerComponent.storiesIncludeHidden,
                        storiesFraction: headerComponent.storiesFraction,
                        storiesUnlocked: headerComponent.storiesUnlocked,
                        uploadProgress: storyUploadProgress,
                        context: headerComponent.context,
                        theme: headerComponent.theme,
                        strings: headerComponent.strings,
                        openStatusSetup: headerComponent.openStatusSetup,
                        toggleIsLocked: headerComponent.toggleIsLocked,
                        sideColumnLength: headerComponent.sideColumnLength,
                        openSideColumnOverflow: headerComponent.openSideColumnOverflow
                    )
                    self.currentHeaderComponent = headerComponent
                    
                    let _ = self.headerContent.update(
                        transition: .immediate,
                        component: AnyComponent(headerComponent),
                        environment: {},
                        containerSize: CGSize(width: currentLayout.size.width, height: 44.0)
                    )
                }
            }
        }
        
        public func updateEdgeEffectForPinnedFraction(pinnedFraction: CGFloat, transition: ComponentTransition) {
            if self.pinnedFraction != pinnedFraction {
                self.pinnedFraction = pinnedFraction
                self.updateEdgeEffectColor(transition: transition)
            }
        }
        
        private func updateEdgeEffectColor(transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            let color: UIColor
            if let edgeEffectColor = component.edgeEffectColor {
                color = edgeEffectColor
            } else {
                var defaultColor = component.theme.list.plainBackgroundColor
                if component.activeSearch == nil {
                    defaultColor = component.theme.list.plainBackgroundColor.mixedWith(component.theme.chatList.pinnedItemBackgroundColor, alpha: self.pinnedFraction)
                }
                if !component.hasEdgeEffect {
                    defaultColor = component.theme.list.itemModalBlocksBackgroundColor
                }
                color = defaultColor
            }
            self.currentEdgeEffectColor = color
            self.edgeEffectView.updateColor(color: color, transition: transition)
        }
        
        func update(component: ChatListNavigationBar, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            var uploadProgressUpdated = false
            var storySubscriptionsUpdated = false
            if let previousComponent = self.component {
                if previousComponent.uploadProgress != component.uploadProgress {
                    uploadProgressUpdated = true
                }
                if previousComponent.storySubscriptions != component.storySubscriptions {
                    storySubscriptionsUpdated = true
                }
            }
            
            self.component = component
            self.state = state
            
            var contentHeight = component.statusBarHeight
            contentHeight += 3.0
            if let activeSearch = component.activeSearch {
                if !activeSearch.isExternal {
                    contentHeight += navigationBarSearchContentHeight
                }
            } else {
                contentHeight += 44.0
                contentHeight += 9.0
                
                if component.search != nil {
                    contentHeight += navigationBarSearchContentHeight + 2.0
                }
            }
            
            var headersContentHeight: CGFloat = 0.0
            if let disappearingHeaderPanelsView = self.disappearingHeaderPanels?.view {
                let headerPanelsFrame = CGRect(origin: CGPoint(x: 0.0, y: headersContentHeight), size: disappearingHeaderPanelsView.bounds.size)
                transition.setFrame(view: disappearingHeaderPanelsView, frame: headerPanelsFrame)
            }
            if let headerPanels = component.headerPanels {
                let headerPanelsView: ComponentView<Empty>
                var headerPanelsTransition = transition
                if let current = self.headerPanelsView {
                    headerPanelsView = current
                } else {
                    headerPanelsTransition = headerPanelsTransition.withAnimation(.none)
                    headerPanelsView = ComponentView()
                    self.headerPanelsView = headerPanelsView
                }
                let headerPanelsSize = headerPanelsView.update(
                    transition: headerPanelsTransition,
                    component: headerPanels,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - component.leftInset - component.rightInset, height: 10000.0)
                )
                let headerPanelsFrame = CGRect(origin: CGPoint(x: component.leftInset, y: headersContentHeight), size: headerPanelsSize)
                if let headerPanelsComponentView = headerPanelsView.view {
                    if headerPanelsComponentView.superview == nil {
                        self.bottomContentsContainer.addSubview(headerPanelsComponentView)
                        transition.animateAlpha(view: headerPanelsComponentView, from: 0.0, to: 1.0)
                    }
                    headerPanelsTransition.setFrame(view: headerPanelsComponentView, frame: headerPanelsFrame)
                }
                headersContentHeight += headerPanelsSize.height
            } else if let headerPanelsView = self.headerPanelsView {
                self.headerPanelsView = nil
                self.disappearingHeaderPanels = headerPanelsView
                
                if let headerPanelsComponentView = headerPanelsView.view {
                    transition.setAlpha(view: headerPanelsComponentView, alpha: 0.0, completion: { [weak self, weak headerPanelsComponentView] _ in
                        guard let self, let headerPanelsComponentView else {
                            return
                        }
                        headerPanelsComponentView.removeFromSuperview()
                        if self.disappearingHeaderPanels?.view === headerPanelsComponentView {
                            self.disappearingHeaderPanels = nil
                        }
                    })
                }
            }
            headersContentHeight += 3.0
            transition.setBounds(view: self.bottomContentsContainer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: headersContentHeight)))
            
            if let activeSearch = component.activeSearch, !activeSearch.isExternal {
                transition.setAlpha(view: self.bottomContentsContainer, alpha: 0.0)
            } else {
                transition.setAlpha(view: self.bottomContentsContainer, alpha: 1.0)
            }
            
            if component.activeSearch == nil {
                contentHeight += headersContentHeight
                
                if component.tabsNode != nil {
                    contentHeight += 40.0
                }
            }
            
            let size = CGSize(width: availableSize.width, height: contentHeight)
            self.currentLayout = CurrentLayout(size: size)
            
            self.hasDeferredScrollOffset = true
            self.liftedScrollGate.noteLayout()
            
            if uploadProgressUpdated || storySubscriptionsUpdated {
                if let rawScrollOffset = self.rawScrollOffset {
                    self.applyScroll(offset: rawScrollOffset, allowAvatarsExpansion: self.currentAllowAvatarsExpansion, forceUpdate: true, transition: transition)
                }
            }
            
            self.updateEdgeEffectColor(transition: transition)
            
            self.edgeEffectView.isHidden = !component.hasEdgeEffect

            if self.isContentLifted {
                self.transitionContentFrameUpdated?(CGRect(origin: CGPoint(), size: size))
            } else {
                self.contentView.frame = CGRect(origin: CGPoint(), size: size)
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

extension ChatListNavigationBar.View: NavigationBarComponentTransitionSource {
    /// The row's frame in the content view.
    var transitionRowFrame: CGRect {
        guard let barView = (self.headerContent.view as? ChatListHeaderComponent.View)?.navigationBarComponentView else {
            return CGRect()
        }
        return barView.convert(barView.bounds, to: self.contentView)
    }

    public func takeView() -> NavigationBarTransitionTakeViewInfo? {
        // A header its screen faded or hid would come back at full opacity once lifted.
        guard !self.isContentLifted, self.component != nil, self.alpha >= 1.0, !self.isHidden, self.contentView.superview === self else {
            return nil
        }
        self.isContentLifted = true
        self.liftedScrollGate.isClosed = true
        // The search field is content like the title: it rides this header's screen, leaving or arriving.
        return NavigationBarTransitionTakeViewInfo(containingView: self, contentView: self.contentView)
    }

    public func putBack() {
        guard self.isContentLifted else {
            return
        }
        self.isContentLifted = false
        self.transitionContentFrameUpdated = nil
        self.keepsOwnBackdrop = false
        self.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        self.insertSubview(self.contentView, at: 0)
        self.contentView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        if let offset = self.liftedScrollGate.open(currentOffset: self.rawScrollOffset) {
            self.applyScroll(offset: offset, allowAvatarsExpansion: self.currentAllowAvatarsExpansion, forceUpdate: true, transition: .immediate)
        }
    }

    public func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        // As the regular bar: in a role the transition draws the glass (capsules, the Duo column) and, unless it leaves
        // it to this header, the backdrop once above both screens; everything else rides this header's screen (UIKit's
        // matching views). The edge effect may live outside the header (a host re-parents it); alpha hides it wherever
        // it is.
        self.transitionRole = role
        self.applyEdgeEffectVisibility()
        self.applyGlassVisibility()
    }

    public func updateKeepsOwnBackdrop(_ keepsOwnBackdrop: Bool) {
        // Next to a bar without a backdrop (a chat) the edge effect stays: it rides this header's screen with the rest.
        if self.keepsOwnBackdrop != keepsOwnBackdrop {
            self.keepsOwnBackdrop = keepsOwnBackdrop
            self.applyEdgeEffectVisibility()
        }
    }

    private func applyEdgeEffectVisibility() {
        self.edgeEffectBackgroundView.alpha = self.transitionRole == nil || self.keepsOwnBackdrop ? 1.0 : 0.0
    }

    public func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool {
        let content = (self.headerContent.view as? ChatListHeaderComponent.View)?.transitionContent
        self.glassHold.hold(held, interrupted: interrupted, content: content, rowFrame: self.transitionRowFrame)
        self.applyGlassVisibility()
        return true
    }

    func applyGlassVisibility(transition: ComponentTransition = .immediate) {
        let detached = self.transitionRole != nil || self.glassHold.isHeld
        (self.headerContent.view as? ChatListHeaderComponent.View)?.navigationBarComponentView?.plattersDetached = detached
        if let sideColumnContainer = self.sideColumnContainer {
            let isVisible = self.sideColumnIsVisible && !detached
            transition.setAlpha(view: sideColumnContainer, alpha: isVisible ? 1.0 : 0.0)
            sideColumnContainer.isUserInteractionEnabled = isVisible
        }
    }

    public var componentTransitionState: NavigationBarComponentTransitionState? {
        // Everything from the layout the header shows (a lifted header holds its layout while its component may move
        // on), so the transition's capsules match what they hand over to.
        guard let component = self.component, let headerComponent = self.currentHeaderComponent, let headerView = self.headerContent.view as? ChatListHeaderComponent.View, let content = headerView.transitionContent, let theme = headerView.navigationBarThemeValue, let strings = headerView.navigationBarStringsValue, let barView = headerView.navigationBarComponentView else {
            return nil
        }
        // The renderer puts its backdrop's bottom edge 24 pt below `backdropHeight` (the regular bar's edge effect
        // overhang), so the header reports its own edge effect's bottom minus that.
        let edgeEffectFrame = self.edgeEffectBackgroundView.frame
        let hasBackdrop = component.hasEdgeEffect && !self.edgeEffectBackgroundView.isHidden
        return NavigationBarComponentTransitionState(
            content: content,
            theme: theme,
            strings: strings,
            rowFrame: self.transitionRowFrame,
            rowAlpha: headerView.alpha,
            leftInset: headerComponent.leftInset,
            rightInset: headerComponent.rightInset,
            trailingButtonsInset: headerComponent.trailingButtonsInset,
            sideColumnFrame: self.sideColumnIsVisible ? self.appliedSideColumn?.frame : nil,
            hidesSideColumnButtons: false,
            backdropHeight: max(0.0, edgeEffectFrame.maxY - 24.0),
            backdropColor: hasBackdrop ? (self.currentEdgeEffectColor ?? component.theme.list.plainBackgroundColor) : nil,
            backdropAlpha: hasBackdrop ? 1.0 : 0.0,
            backdropExtension: 0.0,
            leadingPressScale: barView.detachedLeftPressScale,
            leadingPressGlow: barView.detachedLeftPressGlow,
            trailingPressScales: barView.detachedRightPressScales,
            trailingPressGlows: barView.detachedRightPressGlows,
            backdropTintAlpha: ChatListNavigationBar.View.edgeEffectTintAlpha,
            backdropEdgeLength: ChatListNavigationBar.View.edgeEffectEdgeLength,
            keepsLoneBackdrop: true
        )
    }
}
