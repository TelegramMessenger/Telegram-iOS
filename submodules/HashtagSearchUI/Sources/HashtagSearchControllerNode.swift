import Display
import UIKit
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatListUI
import SegmentedControlNode
import ChatListSearchItemHeader
import PeerInfoVisualMediaPaneNode
import UIKitRuntimeUtils

final class HashtagSearchControllerNode: ASDisplayNode, ASGestureRecognizerDelegate {
    private let context: AccountContext
    private weak var controller: HashtagSearchController?
    private let peer: EnginePeer?
    private var query: String
    private var isCashtag = false
    private var presentationData: PresentationData
    
    private let searchQueryPromise = ValuePromise<String>()
    private var searchQueryDisposable: Disposable?
    
    private let navigationBar: NavigationBar?

    private let searchContentNode: HashtagSearchNavigationContentNode
    private let shimmerNode: ChatListSearchShimmerNode
    private let recentListNode: HashtagSearchRecentListNode
    
    private let isSearching = Promise<Bool>()
    private var isSearchingDisposable: Disposable?
    
    private var searchResultsCount: Int32 = 0
    private var searchResultsCountDisposable: Disposable?
    
    private let clippingNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    let currentController: ChatController?
    let myController: ChatController?
    let myChatContents: HashtagSearchGlobalChatContents?
    
    let globalController: ChatController?
    let globalChatContents: HashtagSearchGlobalChatContents?
    
    private var storySearchContext: SearchStoryListContext?
    private var storySearchDisposable = MetaDisposable()
    private var storySearchState: StoryListContext.State?
    private var storySearchComponentView: ComponentView<Empty>?
    
    private var storySearchPaneNode: PeerInfoStoryPaneNode?
    private var isDisplayingStories = false
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var hasValidLayout = false
    
    init(context: AccountContext, controller: HashtagSearchController, peer: EnginePeer?, query: String, navigationBar: NavigationBar?, navigationController: NavigationController?) {
        self.context = context
        self.controller = controller
        self.peer = peer
        self.query = query
        self.navigationBar = navigationBar
        self.isCashtag = query.hasPrefix("$")
        self.presentationData = controller.presentationData
        self.isDisplayingStories = controller.stories
        
        var presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var controllerParams: ChatControllerParams?
        if controller.forceDark {
            controllerParams = ChatControllerParams(forcedTheme: defaultDarkColorPresentationTheme, forcedWallpaper: defaultBuiltinWallpaper(data: .default, colors: defaultDarkWallpaperGradientColors.map(\.rgb), intensity: -34))
            presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
        }
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.containerNode = ASDisplayNode()
        
        self.searchContentNode = HashtagSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, initialQuery: query, hasCurrentChat: peer != nil, hasTabs: controller.mode != .chatOnly, cancel: { [weak controller] in
            controller?.dismiss()
        })
        
        self.shimmerNode = ChatListSearchShimmerNode(key: .chats)
        self.shimmerNode.isUserInteractionEnabled = false
        self.shimmerNode.allowsGroupOpacity = true
        
        self.recentListNode = HashtagSearchRecentListNode(context: context)
        self.recentListNode.alpha = 0.0
        
        let navigationController = controller.navigationController as? NavigationController
        if let peer, controller.mode != .noChat {
            self.currentController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .inline(navigationController), params: controllerParams)
            self.currentController?.alwaysShowSearchResultsAsList = true
            self.currentController?.showListEmptyResults = true
            self.currentController?.customNavigationController = navigationController
        } else {
            self.currentController = nil
        }
                
        if let _ = peer, controller.mode != .chatOnly {
            let myChatContents = HashtagSearchGlobalChatContents(context: context, query: query, publicPosts: false)
            self.myChatContents = myChatContents
            self.myController = context.sharedContext.makeChatController(context: context, chatLocation: .customChatContents, subject: .customChatContents(contents: myChatContents), botStart: nil, mode: .standard(.default), params: controllerParams)
            self.myController?.alwaysShowSearchResultsAsList = true
            self.myController?.showListEmptyResults = true
            self.myController?.customNavigationController = navigationController
        } else {
            self.myChatContents = nil
            self.myController = nil
        }
        
        let globalChatContents = HashtagSearchGlobalChatContents(context: context, query: query, publicPosts: true)
        self.globalChatContents = globalChatContents
        self.globalController = context.sharedContext.makeChatController(context: context, chatLocation: .customChatContents, subject: .customChatContents(contents: globalChatContents), botStart: nil, mode: .standard(.default), params: controllerParams)
        self.globalController?.alwaysShowSearchResultsAsList = true
        self.globalController?.showListEmptyResults = true
        self.globalController?.customNavigationController = navigationController
                
        if controller.publicPosts {
            self.searchContentNode.selectedIndex = 2
        } else if peer == nil {
            self.searchContentNode.selectedIndex = 1
        } else {
            self.searchContentNode.selectedIndex = 0
        }
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.containerNode)
                
        if controller.mode == .noChat {
            self.isSearching.set(self.myChatContents?.searching ?? .single(false))
        } else {
            if let _ = peer {
                let isSearching: Signal<Bool, NoError>
                if let currentController = self.currentController {
                    isSearching = .single(true)
                    |> then(
                        currentController.searching.get()
                        |> delay(0.5, queue: Queue.mainQueue())
                    )
                } else {
                    isSearching = .single(false)
                }
                self.isSearching.set(isSearching)
            } else {
                self.isSearching.set(self.myChatContents?.searching ?? .single(false))
            }
        }
        
        self.searchContentNode.indexUpdated = { [weak self] index in
            guard let self else {
                return
            }
            self.searchContentNode.selectedIndex = index
            if index == 0 {
                self.isSearching.set(self.currentController?.searching.get() ?? .single(false))
            } else if index == 1 {
                self.isSearching.set(self.myChatContents?.searching ?? .single(false))
            } else if index == 2 {
                self.isSearching.set(self.globalChatContents?.searching ?? .single(false))
            }
            self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
        }
               
        self.recentListNode.setSearchQuery = { [weak self] query in
            guard let self else {
                return
            }
            self.searchContentNode.query = query
            self.updateSearchQuery(query)
            
            Queue.mainQueue().after(0.4) {
                let _ = addRecentHashtagSearchQuery(engine: context.engine, string: query).startStandalone()
            }
        }
        
        self.currentController?.isSelectingMessagesUpdated = { [weak self] isSelecting in
            if let strongSelf = self {
                let button: UIBarButtonItem? = isSelecting ? UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .done, target: self, action: #selector(strongSelf.cancelPressed)) : nil
                strongSelf.controller?.navigationItem.setRightBarButton(button, animated: true)
            }
        }
        
        if controller.mode != .chatOnly {
            navigationBar?.setContentNode(self.searchContentNode, animated: false)
        }
        
        if !self.isDisplayingStories {
            self.addSubnode(self.shimmerNode)
        }
        
        self.searchContentNode.setQueryUpdated { [weak self] query in
            self?.searchQueryPromise.set(query)
        }
        
        if !self.isCashtag {
            let _ = addRecentHashtagSearchQuery(engine: context.engine, string: query).startStandalone()
            self.searchContentNode.onReturn = { query in
                let _ = addRecentHashtagSearchQuery(engine: context.engine, string: "#" + query).startStandalone()
            }
        }
        
        let throttledSearchQuery = self.searchQueryPromise.get()
        |> mapToSignal { query -> Signal<String, NoError> in
            if !query.isEmpty {
                return (.complete() |> delay(1.0, queue: Queue.mainQueue()))
                |> then(.single(query))
            } else {
                return .single(query)
            }
        }
        
        self.searchQueryDisposable = (throttledSearchQuery
        |> deliverOnMainQueue).start(next: { [weak self] query in
            if let self {
                let prefix: String
                if self.isCashtag {
                    prefix = "$"
                } else {
                    prefix = "#"
                }
                self.updateSearchQuery(prefix + query)
            }
        })
        
        self.isSearchingDisposable = (self.isSearching.get()
        |> deliverOnMainQueue).start(next: { [weak self] isSearching in
            if let self {
                self.searchContentNode.isSearching = isSearching
                let transition: ContainedViewLayoutTransition = isSearching ? .immediate : .animated(duration: 0.2, curve: .easeInOut)
                transition.updateAlpha(node: self.shimmerNode, alpha: isSearching ? 1.0 : 0.0)
            }
        })
        
        if let currentController = self.currentController {
            self.searchResultsCountDisposable = (currentController.searchResultsCount.get()
            |> deliverOnMainQueue).start(next: { [weak self] searchResultsCount in
                guard let self else {
                    return
                }
                self.searchResultsCount = searchResultsCount
                self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
            })
        }
        
        self.updateStorySearch()
    }
    
    deinit {
        self.searchQueryDisposable?.dispose()
        self.isSearchingDisposable?.dispose()
        self.searchResultsCountDisposable?.dispose()
        self.storySearchDisposable.dispose()
    }
    
    private var panAllowedDirections: InteractiveTransitionGestureRecognizerDirections {
        let currentIndex = self.searchContentNode.selectedIndex
        let minIndex: Int
        if let _ = self.currentController {
            minIndex = 0
        } else {
            minIndex = 1
        }
        let maxIndex = 2
        
        var directions: InteractiveTransitionGestureRecognizerDirections = []
        if currentIndex > minIndex {
            directions.insert(.rightCenter)
        }
        if currentIndex < maxIndex {
            directions.insert(.leftCenter)
        }
        return directions
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let self else {
                return []
            }
            return self.panAllowedDirections
        }, edgeWidth: .widthMultiplier(factor: 1.0 / 6.0, min: 22.0, max: 80.0))
        panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return false
        }
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    private var panTransitionFraction: CGFloat = 0.0
    private var panCurrentAllowedDirections: InteractiveTransitionGestureRecognizerDirections = [.leftCenter, .rightCenter]
    
    @objc private func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self.view).x
        let velocity = gestureRecognizer.velocity(in: self.view).x
        
        switch gestureRecognizer.state {
        case .began, .changed:
            if case .began = gestureRecognizer.state {
                self.panCurrentAllowedDirections = self.panAllowedDirections
            }
            
            self.panTransitionFraction = -translation / self.view.bounds.width
            if !self.panCurrentAllowedDirections.contains(.leftCenter) {
                self.panTransitionFraction = min(0.0, self.panTransitionFraction)
            }
            if !self.panCurrentAllowedDirections.contains(.rightCenter) {
                self.panTransitionFraction = max(0.0, self.panTransitionFraction)
            }
        
            self.searchContentNode.transitionFraction = self.panTransitionFraction
            
            self.requestUpdate(transition: .immediate)
        case .ended, .cancelled:
            var directionIsToRight: Bool?
            if abs(velocity) > 10.0 {
                if translation > 0.0 {
                    if velocity <= 0.0 {
                        directionIsToRight = nil
                    } else {
                        directionIsToRight = true
                    }
                } else {
                    if velocity >= 0.0 {
                        directionIsToRight = nil
                    } else {
                        directionIsToRight = false
                    }
                }
            } else {
                if abs(translation) > self.view.bounds.width / 2.0 {
                    directionIsToRight = translation > self.view.bounds.width / 2.0
                }
            }
            if !self.panCurrentAllowedDirections.contains(.rightCenter) && directionIsToRight == true {
                directionIsToRight = nil
            }
            if !self.panCurrentAllowedDirections.contains(.leftCenter) && directionIsToRight == false {
                directionIsToRight = nil
            }
            
            if let directionIsToRight {
                if directionIsToRight {
                    self.searchContentNode.selectedIndex -= 1
                } else {
                    self.searchContentNode.selectedIndex += 1
                }
            }
            
            self.panTransitionFraction = 0.0
            self.searchContentNode.transitionFraction = nil
            
            self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
        default:
            break
        }
    }
    
    private func updateSearchQuery(_ query: String) {
        let queryUpdated = self.query != query
        self.query = query
        
        if !query.isEmpty {
            self.currentController?.beginMessageSearch(query)
            
            self.myChatContents?.hashtagSearchUpdate(query: query)
            self.myController?.beginMessageSearch(query)
            
            self.globalChatContents?.hashtagSearchUpdate(query: query)
            self.globalController?.beginMessageSearch(query)
        }
        
        if queryUpdated {
            self.updateStorySearch()
        }
        
        self.requestUpdate(transition: .immediate)
    }
    
    private func updateStorySearch() {
        self.storySearchState = nil
        self.storySearchDisposable.set(nil)
        self.storySearchContext = nil
        
        if !self.query.isEmpty {
            var peerId: EnginePeer.Id?
            if self.controller?.mode == .chatOnly {
                peerId = self.peer?.id
            }
            let storySearchContext = SearchStoryListContext(account: self.context.account, source: .hashtag(peerId, self.query))
            self.storySearchDisposable.set((storySearchContext.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                guard let self else {
                    return
                }
                if state.totalCount > 0 {
                    self.storySearchState = state
                } else {
                    self.storySearchState = nil
                    self.currentController?.externalSearchResultsCount = nil
                }
                self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
            }))
            self.storySearchContext = storySearchContext
        }
    }
    
    @objc private func cancelPressed() {
        self.currentController?.cancelSelectingMessages()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        self.searchContentNode.updateTheme(presentationData.theme)
    }
    
    func scrollToTop() {
        if self.searchContentNode.selectedIndex == 0 {
            self.currentController?.scrollToTop?()
        } else if self.searchContentNode.selectedIndex == 2 {
            self.globalController?.scrollToTop?()
        } else {
            self.myController?.scrollToTop?()
        }
    }
    
    private func animateContentOut() {
        guard let controller = self.currentController else {
            return
        }
        controller.contentContainerNode.layer.animateSublayerScale(from: 1.0, to: 0.95, duration: 0.3, removeOnCompletion: false)
        
        if let blurFilter = makeBlurFilter() {
            blurFilter.setValue(30.0 as NSNumber, forKey: "inputRadius")
            controller.contentContainerNode.layer.filters = [blurFilter]
            controller.contentContainerNode.layer.animate(from: 0.0 as NSNumber, to: 30.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, removeOnCompletion: false)
        }
    }
    
    private func animateContentIn() {
        guard let controller = self.currentController else {
            return
        }
        controller.contentContainerNode.layer.animateSublayerScale(from: 0.95, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        
        if let blurFilter = makeBlurFilter() {
            blurFilter.setValue(0.0 as NSNumber, forKey: "inputRadius")
            controller.contentContainerNode.layer.filters = [blurFilter]
            controller.contentContainerNode.layer.animate(from: 30.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak controller] completed in
                guard let controller, completed else {
                    return
                }
                controller.contentContainerNode.layer.filters = []
            })
        }
    }
    
    func requestUpdate(transition: ContainedViewLayoutTransition) {
        if let (layout, navigationHeight) = self.containerLayout {
            let _ = self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: transition)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let isFirstTime = self.containerLayout == nil
        self.containerLayout = (layout, navigationBarHeight)
                
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let toolbarHeight: CGFloat = 40.0
        insets.top += toolbarHeight - 4.0
        
        if isFirstTime {
            self.insertSubnode(self.clippingNode, at: 0)
        }
        
        var storyParentController: ViewController?
        if self.controller?.mode == .chatOnly {
            storyParentController = self.currentController
        } else {
            storyParentController = self.globalController
        }
        
        var currentTopInset: CGFloat = 0.0
        var globalTopInset: CGFloat = 0.0
        
        var panelSearchState: StoryResultsPanelComponent.SearchState?
        if let storySearchState = self.storySearchState {
            if self.isDisplayingStories {
                if self.searchResultsCount > 0 {
                    panelSearchState = .messages(self.searchResultsCount)
                }
            } else {
                panelSearchState = .stories(storySearchState)
            }
        }
        
        if self.isDisplayingStories {
            if let storySearchState = self.storySearchState {
                self.currentController?.externalSearchResultsCount = Int32(storySearchState.totalCount)
            } else {
                self.currentController?.externalSearchResultsCount = nil
            }
        } else {
            self.currentController?.externalSearchResultsCount = nil
        }
        
        if let panelSearchState {
            if let storyParentController {
                let componentView: ComponentView<Empty>
                var panelTransition = ComponentTransition(transition)
                if let current = self.storySearchComponentView {
                    componentView = current
                } else {
                    panelTransition = .immediate
                    componentView = ComponentView()
                    self.storySearchComponentView = componentView
                }
                let panelSize = componentView.update(
                    transition: panelTransition,
                    component: AnyComponent(StoryResultsPanelComponent(
                        context: self.context,
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        query: self.query,
                        peer: self.controller?.mode == .chatOnly ? self.peer : nil,
                        state: panelSearchState,
                        sideInset: layout.safeInsets.left,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.controller?.mode == .chatOnly {
                                self.isDisplayingStories = !self.isDisplayingStories
                                self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
                            } else {
                                let searchController = self.context.sharedContext.makeStorySearchController(context: self.context, scope: .query(nil, self.query), listContext: self.storySearchContext)
                                self.controller?.push(searchController)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: layout.size
                )
                let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top - 36.0), size: panelSize)
                if let view = componentView.view {
                    if view.superview == nil {
                        storyParentController.view.addSubview(view)
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: -panelSize.height), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    }
                    panelTransition.setFrame(view: view, frame: panelFrame)
                }
                if self.controller?.mode == .chatOnly {
                    currentTopInset += panelSize.height
                } else {
                    globalTopInset += panelSize.height
                }
            }
        } else if let storySearchComponentView = self.storySearchComponentView {
            storySearchComponentView.view?.removeFromSuperview()
            self.storySearchComponentView = nil
        }
        
        if let controller = self.currentController {
            var topInset: CGFloat = insets.top - 79.0
            topInset += currentTopInset
            
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
            if controller.displayNode.supernode == nil {
                controller.viewWillAppear(false)
                self.containerNode.addSubnode(controller.displayNode)
                controller.viewDidAppear(false)
                
                controller.beginMessageSearch(self.query)
            }
        }
        
        if let controller = self.myController {
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: layout.size.width, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top - 89.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
            if controller.displayNode.supernode == nil {
                controller.viewWillAppear(false)
                self.containerNode.addSubnode(controller.displayNode)
                controller.viewDidAppear(false)
                
                controller.beginMessageSearch(self.query)
            }
        }
         
        if let controller = self.globalController {
            var topInset: CGFloat = insets.top - 89.0
            topInset += globalTopInset
            
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: layout.size.width * 2.0, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
            if controller.displayNode.supernode == nil {
                controller.viewWillAppear(false)
                self.containerNode.addSubnode(controller.displayNode)
                controller.viewDidAppear(false)
                
                controller.beginMessageSearch(self.query)
            }
        }
        
        if self.isDisplayingStories, let peer = self.peer, let storySearchContext = self.storySearchContext {
            let storySearchPaneNode: PeerInfoStoryPaneNode
            var paneTransition = transition
            if let current = self.storySearchPaneNode {
                storySearchPaneNode = current
            } else {
                storySearchPaneNode = PeerInfoStoryPaneNode(
                    context: self.context,
                    scope: .search(peerId: peer.id, query: self.query),
                    captureProtected: false,
                    isProfileEmbedded: false,
                    canManageStories: false,
                    navigationController: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return self.controller?.navigationController as? NavigationController
                    },
                    listContext: storySearchContext
                )
                self.storySearchPaneNode = storySearchPaneNode
                if let storySearchView = self.storySearchComponentView?.view {
                    storySearchView.superview?.insertSubview(storySearchPaneNode.view, belowSubview: storySearchView)
                } else {
                    storyParentController?.view.addSubview(storySearchPaneNode.view)
                }
                paneTransition = .immediate
                
                if transition.isAnimated {
                    storySearchPaneNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    storySearchPaneNode.layer.animateSublayerScale(from: 0.95, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    self.animateContentOut()
                }
            }
            
            var bottomInset: CGFloat = 0.0
            if case .regular = layout.metrics.widthClass {
                bottomInset += 49.0
            } else {
                bottomInset += 45.0
            }
            bottomInset += layout.intrinsicInsets.bottom
            
            storySearchPaneNode.update(
                size: layout.size,
                topInset: navigationBarHeight,
                sideInset: layout.safeInsets.left,
                bottomInset: 0.0,
                deviceMetrics: layout.deviceMetrics,
                visibleHeight: layout.size.height - currentTopInset,
                isScrollingLockedAtTop: false,
                expandProgress: 1.0,
                navigationHeight: 0.0,
                presentationData: self.presentationData,
                synchronous: false,
                transition: paneTransition
            )
            storySearchPaneNode.view.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            paneTransition.updateFrame(node: storySearchPaneNode, frame: CGRect(origin: CGPoint(x: 0.0, y: currentTopInset), size: CGSize(width: layout.size.width, height: layout.size.height - bottomInset - currentTopInset)))
        } else if let storySearchPaneNode = self.storySearchPaneNode {
            self.storySearchPaneNode = nil
            
            storySearchPaneNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                storySearchPaneNode.view.removeFromSuperview()
            })
            storySearchPaneNode.layer.animateSublayerScale(from: 1.0, to: 0.95, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            self.animateContentIn()
        }
        
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: .zero, size: layout.size))
        
        let containerPosition: CGFloat = -layout.size.width * CGFloat(self.searchContentNode.selectedIndex) - self.panTransitionFraction * layout.size.width
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: containerPosition, y: 0.0), size: CGSize(width: layout.size.width * 3.0, height: layout.size.height)))
        
        let overflowInset: CGFloat = 0.0
        let topInset = navigationBarHeight
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: overflowInset, y: topInset), size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height))
        self.shimmerNode.update(context: self.context, size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height), presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, animationCache: self.context.animationCache, animationRenderer: self.context.animationRenderer, key: .chats, hasSelection: false, transition: transition)
        
        if isFirstTime {
            if self.shimmerNode.supernode != nil {
                self.insertSubnode(self.recentListNode, aboveSubnode: self.shimmerNode)
            } else {
                self.insertSubnode(self.recentListNode, aboveSubnode: self.clippingNode)
            }
        }
        
        transition.updateFrame(node: self.recentListNode, frame: CGRect(origin: .zero, size: layout.size))
        self.recentListNode.updateLayout(layout: ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top - 35.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
        
        let recentTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        if self.query.isEmpty {
            recentTransition.updateAlpha(node: self.recentListNode, alpha: 1.0)
        } else if self.recentListNode.alpha > 0.0 {
            Queue.mainQueue().after(0.1, {
                if !self.query.isEmpty {
                    recentTransition.updateAlpha(node: self.recentListNode, alpha: 0.0)
                }
            })
        }
        
        if !self.hasValidLayout {
            self.hasValidLayout = true
        }

        if self.currentController != nil {
            return toolbarHeight
        } else {
            return 0.0
        }
    }
}
