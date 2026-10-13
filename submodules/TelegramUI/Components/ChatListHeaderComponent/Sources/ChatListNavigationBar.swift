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
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        statusBarHeight: CGFloat,
        leftInset: CGFloat,
        rightInset: CGFloat,
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
        allowAutomaticOrder: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.statusBarHeight = statusBarHeight
        self.leftInset = leftInset
        self.rightInset = rightInset
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
        
        override public init(frame: CGRect) {
            self.edgeEffectView = EdgeEffectView()
            
            self.headerBackgroundContainer = SparseContainerView()
            self.headerBackgroundContainer.layer.anchorPoint = CGPoint()
            
            self.bottomContentsContainer = UIView()
            self.bottomContentsContainer.layer.anchorPoint = CGPoint()
            
            super.init(frame: frame)
            
            self.addSubview(self.edgeEffectView)
            self.addSubview(self.bottomContentsContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if point.y >= self.currentHeight {
                return nil
            }
            
            if self.alpha.isZero {
                return nil
            }
            for view in self.subviews.reversed() {
                if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                    return result
                }
            }
            
            let result = super.hitTest(point, with: event)
            return result
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
                    self.addSubview(searchContentNode.view)
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
                
                let _ = searchContentNode.updateLayout(size: searchSize, leftInset: component.leftInset, rightInset: component.rightInset, transition: transition.containedViewLayoutTransition)
                
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
            self.edgeEffectView.update(content: nil, blur: true, alpha: 0.85, rect: edgeEffectFrame, edge: .top, edgeSize: min(54.0, edgeEffectHeight), transition: transition)
            
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
                primaryContent: component.primaryContent,
                secondaryContent: component.secondaryContent,
                secondaryTransition: component.secondaryTransition,
                networkStatus: nil,
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
                }
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
                    self.addSubview(self.headerBackgroundContainer)
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
                if tabsNode.view.superview !== self {
                    tabsNode.view.layer.anchorPoint = CGPoint()
                    tabsNodeTransition = .immediate
                    tabsNode.view.alpha = 1.0
                    self.addSubview(tabsNode.view)
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
                if accessoryPanelContainer.view.superview !== self {
                    accessoryPanelContainer.view.layer.anchorPoint = CGPoint()
                    accessoryPanelContainer.clipsToBounds = true
                    tabsNodeTransition = .immediate
                    accessoryPanelContainer.view.alpha = 1.0
                    self.addSubview(accessoryPanelContainer.view)
                    if !transition.animation.isImmediate {
                        accessoryPanelContainer.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                } else {
                    transition.setAlpha(view: accessoryPanelContainer.view, alpha: 1.0)
                }
                
                tabsNodeTransition.setFrameWithAdditivePosition(view: accessoryPanelContainer.view, frame: accessoryPanelContainerFrame)
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
                    allowAutomaticOrder: component.allowAutomaticOrder
                )
                if let currentLayout = self.currentLayout, let headerComponent = self.currentHeaderComponent {
                    let headerComponent = ChatListHeaderComponent(
                        leftInset: headerComponent.leftInset,
                        rightInset: headerComponent.rightInset,
                        primaryContent: headerComponent.primaryContent,
                        secondaryContent: headerComponent.secondaryContent,
                        secondaryTransition: headerComponent.secondaryTransition,
                        networkStatus: headerComponent.networkStatus,
                        storySubscriptions: headerComponent.storySubscriptions,
                        storiesIncludeHidden: headerComponent.storiesIncludeHidden,
                        storiesFraction: headerComponent.storiesFraction,
                        storiesUnlocked: headerComponent.storiesUnlocked,
                        uploadProgress: storyUploadProgress,
                        context: headerComponent.context,
                        theme: headerComponent.theme,
                        strings: headerComponent.strings,
                        openStatusSetup: headerComponent.openStatusSetup,
                        toggleIsLocked: headerComponent.toggleIsLocked
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
            
            if uploadProgressUpdated || storySubscriptionsUpdated {
                if let rawScrollOffset = self.rawScrollOffset {
                    self.applyScroll(offset: rawScrollOffset, allowAvatarsExpansion: self.currentAllowAvatarsExpansion, forceUpdate: true, transition: transition)
                }
            }
            
            self.updateEdgeEffectColor(transition: transition)
            
            self.edgeEffectView.isHidden = !component.hasEdgeEffect
            
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
