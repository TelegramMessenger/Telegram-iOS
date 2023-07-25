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

public final class ChatListNavigationBar: Component {
    public final class AnimationHint {
        let disableStoriesAnimations: Bool
        let crossfadeStoryPeers: Bool
        
        public init(disableStoriesAnimations: Bool, crossfadeStoryPeers: Bool) {
            self.disableStoriesAnimations = disableStoriesAnimations
            self.crossfadeStoryPeers = crossfadeStoryPeers
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let statusBarHeight: CGFloat
    public let sideInset: CGFloat
    public let isSearchActive: Bool
    public let primaryContent: ChatListHeaderComponent.Content?
    public let secondaryContent: ChatListHeaderComponent.Content?
    public let secondaryTransition: CGFloat
    public let storySubscriptions: EngineStorySubscriptions?
    public let storiesIncludeHidden: Bool
    public let uploadProgress: Float?
    public let tabsNode: ASDisplayNode?
    public let tabsNodeIsSearch: Bool
    public let accessoryPanelContainer: ASDisplayNode?
    public let accessoryPanelContainerHeight: CGFloat
    public let activateSearch: (NavigationBarSearchContentNode) -> Void
    public let openStatusSetup: (UIView) -> Void
    public let allowAutomaticOrder: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        statusBarHeight: CGFloat,
        sideInset: CGFloat,
        isSearchActive: Bool,
        primaryContent: ChatListHeaderComponent.Content?,
        secondaryContent: ChatListHeaderComponent.Content?,
        secondaryTransition: CGFloat,
        storySubscriptions: EngineStorySubscriptions?,
        storiesIncludeHidden: Bool,
        uploadProgress: Float?,
        tabsNode: ASDisplayNode?,
        tabsNodeIsSearch: Bool,
        accessoryPanelContainer: ASDisplayNode?,
        accessoryPanelContainerHeight: CGFloat,
        activateSearch: @escaping (NavigationBarSearchContentNode) -> Void,
        openStatusSetup: @escaping (UIView) -> Void,
        allowAutomaticOrder: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.statusBarHeight = statusBarHeight
        self.sideInset = sideInset
        self.isSearchActive = isSearchActive
        self.primaryContent = primaryContent
        self.secondaryContent = secondaryContent
        self.secondaryTransition = secondaryTransition
        self.storySubscriptions = storySubscriptions
        self.storiesIncludeHidden = storiesIncludeHidden
        self.uploadProgress = uploadProgress
        self.tabsNode = tabsNode
        self.tabsNodeIsSearch = tabsNodeIsSearch
        self.accessoryPanelContainer = accessoryPanelContainer
        self.accessoryPanelContainerHeight = accessoryPanelContainerHeight
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
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.isSearchActive != rhs.isSearchActive {
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
        return true
    }
    
    private struct CurrentLayout {
        var size: CGSize
        
        init(size: CGSize) {
            self.size = size
        }
    }
    
    public static let searchScrollHeight: CGFloat = 52.0
    public static let storiesScrollHeight: CGFloat = {
        return 83.0
    }()

    public final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let separatorLayer: SimpleLayer
        
        public let headerContent = ComponentView<Empty>()
        
        public private(set) var searchContentNode: NavigationBarSearchContentNode?
        
        private var component: ChatListNavigationBar?
        private weak var state: EmptyComponentState?
        
        private var scrollTheme: PresentationTheme?
        private var scrollStrings: PresentationStrings?
        
        private var currentLayout: CurrentLayout?
        private var rawScrollOffset: CGFloat?
        private var currentAllowAvatarsExpansion: Bool = false
        public private(set) var clippedScrollOffset: CGFloat?
        
        public var deferScrollApplication: Bool = false
        private var hasDeferredScrollOffset: Bool = false
        
        public private(set) var storiesUnlocked: Bool = false
        
        private var tabsNode: ASDisplayNode?
        private var tabsNodeIsSearch: Bool = false
        private weak var disappearingTabsView: UIView?
        private var disappearingTabsViewSearch: Bool = false
        
        private var currentHeaderComponent: ChatListHeaderComponent?
        
        override public init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.backgroundView.layer.anchorPoint = CGPoint(x: 0.0, y: 1.0)
            self.separatorLayer = SimpleLayer()
            self.separatorLayer.anchorPoint = CGPoint()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separatorLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.frame.contains(point) {
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
        
        public func applyCurrentScroll(transition: Transition) {
            if let rawScrollOffset = self.rawScrollOffset, self.hasDeferredScrollOffset {
                self.applyScroll(offset: rawScrollOffset, allowAvatarsExpansion: self.currentAllowAvatarsExpansion, transition: transition)
            }
        }
        
        public func applyScroll(offset: CGFloat, allowAvatarsExpansion: Bool, forceUpdate: Bool = false, transition: Transition) {
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
            
            let themeUpdated = component.theme !== self.scrollTheme || component.strings !== self.scrollStrings
            
            self.scrollTheme = component.theme
            self.scrollStrings = component.strings
            
            let searchOffsetDistance: CGFloat = ChatListNavigationBar.searchScrollHeight
            
            let minContentOffset: CGFloat = ChatListNavigationBar.searchScrollHeight
            
            let clippedScrollOffset = min(minContentOffset, offset)
            if self.clippedScrollOffset == clippedScrollOffset && !self.hasDeferredScrollOffset && !forceUpdate && !allowAvatarsExpansionUpdated {
                return
            }
            self.hasDeferredScrollOffset = false
            self.clippedScrollOffset = clippedScrollOffset
            
            let visibleSize = CGSize(width: currentLayout.size.width, height: max(0.0, currentLayout.size.height - clippedScrollOffset))
            
            let previousHeight = self.separatorLayer.position.y
            
            self.backgroundView.update(size: CGSize(width: visibleSize.width, height: 1000.0), transition: transition.containedViewLayoutTransition)
            
            transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: CGPoint(), size: CGSize(width: visibleSize.width, height: 1000.0)))
            transition.animatePosition(view: self.backgroundView, from: CGPoint(x: 0.0, y: -visibleSize.height + self.backgroundView.layer.position.y), to: CGPoint(), additive: true)
            self.backgroundView.layer.position = CGPoint(x: 0.0, y: visibleSize.height)
            
            transition.setFrameWithAdditivePosition(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: visibleSize.height), size: CGSize(width: visibleSize.width, height: UIScreenPixel)))
            
            let searchContentNode: NavigationBarSearchContentNode
            if let current = self.searchContentNode {
                searchContentNode = current
                
                if themeUpdated {
                    let placeholder: String
                    let compactPlaceholder: String
                    
                    placeholder = component.strings.Common_Search
                    compactPlaceholder = component.strings.Common_Search
                    
                    searchContentNode.updateThemeAndPlaceholder(theme: component.theme, placeholder: placeholder, compactPlaceholder: compactPlaceholder)
                }
            } else {
                let placeholder: String
                let compactPlaceholder: String
                
                placeholder = component.strings.Common_Search
                compactPlaceholder = component.strings.Common_Search
                
                searchContentNode = NavigationBarSearchContentNode(
                    theme: component.theme,
                    placeholder: placeholder,
                    compactPlaceholder: compactPlaceholder,
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
            
            let searchSize = CGSize(width: currentLayout.size.width - 6.0 * 2.0, height: navigationBarSearchContentHeight)
            var searchFrame = CGRect(origin: CGPoint(x: 6.0, y: visibleSize.height - searchSize.height), size: searchSize)
            if component.tabsNode != nil {
                searchFrame.origin.y -= 40.0
            }
            if !component.isSearchActive {
                searchFrame.origin.y -= component.accessoryPanelContainerHeight
            }
            
            let clippedSearchOffset = max(0.0, min(clippedScrollOffset, searchOffsetDistance))
            let searchOffsetFraction = clippedSearchOffset / searchOffsetDistance
            searchContentNode.expansionProgress = 1.0 - searchOffsetFraction
            
            transition.setFrameWithAdditivePosition(view: searchContentNode.view, frame: searchFrame)
            
            searchContentNode.updateLayout(size: searchSize, leftInset: component.sideInset, rightInset: component.sideInset, transition: transition.containedViewLayoutTransition)
            
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
                sideInset: component.sideInset + 16.0,
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
            if component.isSearchActive {
                headerContentY = -headerContentSize.height
            } else {
                if component.statusBarHeight < 1.0 {
                    headerContentY = 0.0
                } else {
                    headerContentY = component.statusBarHeight + 5.0
                }
            }
            let headerContentFrame = CGRect(origin: CGPoint(x: 0.0, y: headerContentY), size: headerContentSize)
            if let headerContentView = self.headerContent.view {
                if headerContentView.superview == nil {
                    headerContentView.layer.anchorPoint = CGPoint()
                    self.addSubview(headerContentView)
                }
                transition.setFrameWithAdditivePosition(view: headerContentView, frame: headerContentFrame)
                
                if component.isSearchActive != (headerContentView.alpha == 0.0) {
                    headerContentView.alpha = component.isSearchActive ? 0.0 : 1.0
                    
                    if !transition.animation.isImmediate {
                        if component.isSearchActive {
                            headerContentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.14)
                        } else {
                            headerContentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                    }
                }
            }
            
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
            if !component.isSearchActive {
                tabsFrame.origin.y -= component.accessoryPanelContainerHeight
            }
            if component.tabsNode != nil {
                tabsFrame.origin.y -= 46.0
            }
            
            var accessoryPanelContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: visibleSize.height), size: CGSize(width: visibleSize.width, height: component.accessoryPanelContainerHeight))
            if !component.isSearchActive {
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
        
        public func updateStoryUploadProgress(storyUploadProgress: Float?) {
            guard let component = self.component else {
                return
            }
            if component.uploadProgress != storyUploadProgress {
                self.component = ChatListNavigationBar(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    statusBarHeight: component.statusBarHeight,
                    sideInset: component.sideInset,
                    isSearchActive: component.isSearchActive,
                    primaryContent: component.primaryContent,
                    secondaryContent: component.secondaryContent,
                    secondaryTransition: component.secondaryTransition,
                    storySubscriptions: component.storySubscriptions,
                    storiesIncludeHidden: component.storiesIncludeHidden,
                    uploadProgress: storyUploadProgress,
                    tabsNode: component.tabsNode,
                    tabsNodeIsSearch: component.tabsNodeIsSearch,
                    accessoryPanelContainer: component.accessoryPanelContainer,
                    accessoryPanelContainerHeight: component.accessoryPanelContainerHeight,
                    activateSearch: component.activateSearch,
                    openStatusSetup: component.openStatusSetup,
                    allowAutomaticOrder: component.allowAutomaticOrder
                )
                if let currentLayout = self.currentLayout, let headerComponent = self.currentHeaderComponent {
                    let headerComponent = ChatListHeaderComponent(
                        sideInset: headerComponent.sideInset,
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
        
        func update(component: ChatListNavigationBar, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
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
            
            if themeUpdated {
                self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.separatorLayer.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            var contentHeight = component.statusBarHeight
            
            if component.statusBarHeight >= 1.0 {
                contentHeight += 3.0
            }
            contentHeight += 44.0
            
            if component.isSearchActive {
                if component.statusBarHeight < 1.0 {
                    contentHeight += 8.0
                }
            } else {
                contentHeight += navigationBarSearchContentHeight
            }
            
            if component.tabsNode != nil {
                contentHeight += 40.0
            }
            
            if component.accessoryPanelContainer != nil && !component.isSearchActive {
                contentHeight += component.accessoryPanelContainerHeight
            }
            
            let size = CGSize(width: availableSize.width, height: contentHeight)
            self.currentLayout = CurrentLayout(size: size)
            
            self.hasDeferredScrollOffset = true
            
            if uploadProgressUpdated || storySubscriptionsUpdated {
                if let rawScrollOffset = self.rawScrollOffset {
                    self.applyScroll(offset: rawScrollOffset, allowAvatarsExpansion: self.currentAllowAvatarsExpansion, forceUpdate: true, transition: transition)
                }
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
