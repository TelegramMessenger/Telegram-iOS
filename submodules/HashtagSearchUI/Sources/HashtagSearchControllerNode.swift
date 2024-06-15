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

final class HashtagSearchControllerNode: ASDisplayNode, ASGestureRecognizerDelegate {
    private let context: AccountContext
    private weak var controller: HashtagSearchController?
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
    
    private let clippingNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    let currentController: ChatController?
    let myController: ChatController?
    let myChatContents: HashtagSearchGlobalChatContents?
    
    let globalController: ChatController?
    let globalChatContents: HashtagSearchGlobalChatContents?
    
    private var globalStorySearchContext: SearchStoryListContext?
    private var globalStorySearchDisposable = MetaDisposable()
    private var globalStorySearchState: StoryListContext.State?
    private var globalStorySearchComponentView: ComponentView<Empty>?
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var hasValidLayout = false
    
    init(context: AccountContext, controller: HashtagSearchController, peer: EnginePeer?, query: String, navigationBar: NavigationBar?, navigationController: NavigationController?) {
        self.context = context
        self.controller = controller
        self.query = query
        self.navigationBar = navigationBar
        self.isCashtag = query.hasPrefix("$")
        self.presentationData = controller.presentationData
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.containerNode = ASDisplayNode()
        
        self.searchContentNode = HashtagSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, initialQuery: query, hasCurrentChat: peer != nil, cancel: { [weak controller] in
            controller?.dismiss()
        })
        
        self.shimmerNode = ChatListSearchShimmerNode(key: .chats)
        self.shimmerNode.isUserInteractionEnabled = false
        self.shimmerNode.allowsGroupOpacity = true
        
        self.recentListNode = HashtagSearchRecentListNode(context: context)
        self.recentListNode.alpha = 0.0
        
        let navigationController = controller.navigationController as? NavigationController
        if let peer, !controller.all {
            self.currentController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .inline(navigationController), params: nil)
            self.currentController?.alwaysShowSearchResultsAsList = true
            self.currentController?.showListEmptyResults = true
            self.currentController?.customNavigationController = navigationController
        } else {
            self.currentController = nil
        }
                
        let myChatContents = HashtagSearchGlobalChatContents(context: context, query: query, publicPosts: false)
        self.myChatContents = myChatContents
        self.myController = context.sharedContext.makeChatController(context: context, chatLocation: .customChatContents, subject: .customChatContents(contents: myChatContents), botStart: nil, mode: .standard(.default), params: nil)
        self.myController?.alwaysShowSearchResultsAsList = true
        self.myController?.showListEmptyResults = true
        self.myController?.customNavigationController = navigationController
        
        let globalChatContents = HashtagSearchGlobalChatContents(context: context, query: query, publicPosts: true)
        self.globalChatContents = globalChatContents
        self.globalController = context.sharedContext.makeChatController(context: context, chatLocation: .customChatContents, subject: .customChatContents(contents: globalChatContents), botStart: nil, mode: .standard(.default), params: nil)
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
                
        if controller.all {
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
        
        navigationBar?.setContentNode(self.searchContentNode, animated: false)
        
        self.addSubnode(self.shimmerNode)
        
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
        
        self.updateStorySearch()
    }
    
    deinit {
        self.searchQueryDisposable?.dispose()
        self.isSearchingDisposable?.dispose()
        self.globalStorySearchDisposable.dispose()
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
        self.globalStorySearchState = nil
        self.globalStorySearchDisposable.set(nil)
        self.globalStorySearchContext = nil
        
        if !self.query.isEmpty {
            let globalStorySearchContext = SearchStoryListContext(account: self.context.account, source: .hashtag(self.query))
            self.globalStorySearchDisposable.set((globalStorySearchContext.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                guard let self else {
                    return
                }
                if state.totalCount > 0 {
                    self.globalStorySearchState = state
                } else {
                    self.globalStorySearchState = nil
                }
                self.requestUpdate(transition: .animated(duration: 0.25, curve: .easeInOut))
            }))
            self.globalStorySearchContext = globalStorySearchContext
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
        
        if let controller = self.currentController {
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top - 79.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
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
            if let state = self.globalStorySearchState {
                let componentView: ComponentView<Empty>
                var panelTransition = ComponentTransition(transition)
                if let current = self.globalStorySearchComponentView {
                    componentView = current
                } else {
                    panelTransition = .immediate
                    componentView = ComponentView()
                    self.globalStorySearchComponentView = componentView
                }
                let panelSize = componentView.update(
                    transition: .immediate,
                    component: AnyComponent(StoryResultsPanelComponent(
                        context: self.context,
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        query: self.query,
                        state: state,
                        sideInset: layout.safeInsets.left,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            let searchController = self.context.sharedContext.makeStorySearchController(context: self.context, scope: .query(self.query), listContext: self.globalStorySearchContext)
                            self.controller?.push(searchController)
                        }
                    )),
                    environment: {},
                    containerSize: layout.size
                )
                let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top - 36.0), size: panelSize)
                if let view = componentView.view {
                    if view.superview == nil {
                        controller.view.addSubview(view)
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: -panelSize.height), to: .zero, duration: 0.25, additive: true)
                    }
                    panelTransition.setFrame(view: view, frame: panelFrame)
                }
                topInset += panelSize.height
            } else if let globalStorySearchComponentView = self.globalStorySearchComponentView {
                globalStorySearchComponentView.view?.removeFromSuperview()
                self.globalStorySearchComponentView = nil
            }
            
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: layout.size.width * 2.0, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
            if controller.displayNode.supernode == nil {
                controller.viewWillAppear(false)
                self.containerNode.addSubnode(controller.displayNode)
                controller.viewDidAppear(false)
                
                controller.beginMessageSearch(self.query)
            }
        }
        
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: .zero, size: layout.size))
        
        let containerPosition: CGFloat = -layout.size.width * CGFloat(self.searchContentNode.selectedIndex) - self.panTransitionFraction * layout.size.width
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: containerPosition, y: 0.0), size: CGSize(width: layout.size.width * 3.0, height: layout.size.height)))
        
        let overflowInset: CGFloat = 0.0
        let topInset = navigationBarHeight
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: overflowInset, y: topInset), size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height))
        self.shimmerNode.update(context: self.context, size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height), presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, animationCache: self.context.animationCache, animationRenderer: self.context.animationRenderer, key: .chats, hasSelection: false, transition: transition)
        
        if isFirstTime {
            self.insertSubnode(self.recentListNode, aboveSubnode: self.shimmerNode)
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
