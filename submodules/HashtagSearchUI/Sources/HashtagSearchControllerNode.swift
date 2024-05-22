import Display
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatListUI
import SegmentedControlNode
import ChatListSearchItemHeader

final class HashtagSearchControllerNode: ASDisplayNode {
    private let context: AccountContext
    private weak var controller: HashtagSearchController?
    private var query: String
    
    private let searchQueryPromise = ValuePromise<String>()
    private var searchQueryDisposable: Disposable?
    
    private let navigationBar: NavigationBar?

    private let searchContentNode: HashtagSearchNavigationContentNode
    private let shimmerNode: ChatListSearchShimmerNode
    private let recentListNode: HashtagSearchRecentListNode
    
    private let isSearching = Promise<Bool>()
    private var isSearchingDisposable: Disposable?
    
    let currentController: ChatController?
    let myController: ChatController?
    let myChatContents: HashtagSearchGlobalChatContents?
    
    let globalController: ChatController?
    let globalChatContents: HashtagSearchGlobalChatContents?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var hasValidLayout = false
    
    init(context: AccountContext, controller: HashtagSearchController, peer: EnginePeer?, query: String, navigationBar: NavigationBar?, navigationController: NavigationController?) {
        self.context = context
        self.controller = controller
        self.query = query
        self.navigationBar = navigationBar
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let cleanHashtag = query.replacingOccurrences(of: "#", with: "")
        self.searchContentNode = HashtagSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, initialQuery: cleanHashtag, hasCurrentChat: peer != nil, cancel: { [weak controller] in
            controller?.dismiss()
        })
        
        self.shimmerNode = ChatListSearchShimmerNode(key: .chats)
        self.shimmerNode.isUserInteractionEnabled = false
        self.shimmerNode.allowsGroupOpacity = true
        
        self.recentListNode = HashtagSearchRecentListNode(context: context)
                
        let navigationController = controller.navigationController as? NavigationController
        if let peer {
            self.currentController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .inline(navigationController))
            self.currentController?.alwaysShowSearchResultsAsList = true
            self.currentController?.showListEmptyResults = true
            self.currentController?.customNavigationController = navigationController
        } else {
            self.currentController = nil
        }
        
        self.isSearching.set(self.currentController?.searching.get() ?? .single(false))
        
        let myChatContents = HashtagSearchGlobalChatContents(context: context, kind: .hashTagSearch, query: cleanHashtag, onlyMy: true)
        self.myChatContents = myChatContents
        self.myController = context.sharedContext.makeChatController(context: context, chatLocation: .customChatContents, subject: .customChatContents(contents: myChatContents), botStart: nil, mode: .standard(.default))
        self.myController?.alwaysShowSearchResultsAsList = true
        self.myController?.showListEmptyResults = true
        self.myController?.customNavigationController = navigationController
        if peer == nil {
            self.searchContentNode.selectedIndex = 1
        }
        
        let globalChatContents = HashtagSearchGlobalChatContents(context: context, kind: .hashTagSearch, query: cleanHashtag, onlyMy: false)
        self.globalChatContents = globalChatContents
        self.globalController = context.sharedContext.makeChatController(context: context, chatLocation: .customChatContents, subject: .customChatContents(contents: globalChatContents), botStart: nil, mode: .standard(.default))
        self.globalController?.alwaysShowSearchResultsAsList = true
        self.globalController?.showListEmptyResults = true
        self.globalController?.customNavigationController = navigationController
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
                
        if controller.all {
            self.currentController?.displayNode.isHidden = true
            self.myController?.displayNode.isHidden = false
            self.globalController?.displayNode.isHidden = true
        } else {
            if let _ = peer {
                self.currentController?.displayNode.isHidden = false
                self.myController?.displayNode.isHidden = true
                self.globalController?.displayNode.isHidden = true
            } else {
                self.myController?.displayNode.isHidden = false
                self.globalController?.displayNode.isHidden = true
            }
        }
        
        self.searchContentNode.indexUpdated = { [weak self] index in
            guard let self else {
                return
            }
            self.searchContentNode.selectedIndex = index
            if index == 0 {
                self.currentController?.displayNode.isHidden = false
                self.myController?.displayNode.isHidden = true
                self.globalController?.displayNode.isHidden = true
                self.isSearching.set(self.currentController?.searching.get() ?? .single(false))
            } else if index == 1 {
                self.currentController?.displayNode.isHidden = true
                self.myController?.displayNode.isHidden = false
                self.globalController?.displayNode.isHidden = true
                self.isSearching.set(self.myChatContents?.searching ?? .single(false))
            } else if index == 2 {
                self.currentController?.displayNode.isHidden = true
                self.myController?.displayNode.isHidden = true
                self.globalController?.displayNode.isHidden = false
                self.isSearching.set(self.globalChatContents?.searching ?? .single(false))
            }
        }
               
        self.recentListNode.setSearchQuery = { [weak self] query in
            guard let self else {
                return
            }
            self.searchContentNode.query = query
            self.updateSearchQuery(query)
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
        
        let _ = addRecentHashtagSearchQuery(engine: context.engine, string: query.replacingOccurrences(of: "#", with: "")).startStandalone()
        self.searchContentNode.onReturn = { query in
            let _ = addRecentHashtagSearchQuery(engine: context.engine, string: query).startStandalone()
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
                self.updateSearchQuery(query)
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
    }
    
    deinit {
        self.searchQueryDisposable?.dispose()
        self.isSearchingDisposable?.dispose()
    }
    
    func updateSearchQuery(_ query: String) {
        self.query = query
        
        var cleanQuery = query
        if cleanQuery.hasPrefix("#") {
            cleanQuery.removeFirst()
        }
        if !cleanQuery.isEmpty {
            self.currentController?.beginMessageSearch("#" + cleanQuery)
            
            self.myChatContents?.hashtagSearchUpdate(query: cleanQuery)
            self.myController?.beginMessageSearch("#" + cleanQuery)
            
            self.globalChatContents?.hashtagSearchUpdate(query: cleanQuery)
            self.globalController?.beginMessageSearch("#" + cleanQuery)
        }
        
        if let (layout, navigationHeight) = self.containerLayout {
            let _ = self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    @objc private func cancelPressed() {
        self.currentController?.cancelSelectingMessages()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.backgroundColor = theme.chatList.backgroundColor
        self.searchContentNode.updateTheme(theme)
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
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let isFirstTime = self.containerLayout == nil
        self.containerLayout = (layout, navigationBarHeight)
                
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let toolbarHeight: CGFloat = 40.0
            
        insets.top += toolbarHeight - 4.0
        if let controller = self.currentController {
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top - 79.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
            if controller.displayNode.supernode == nil {
                controller.viewWillAppear(false)
                self.insertSubnode(controller.displayNode, at: 0)
                controller.viewDidAppear(false)
                
                controller.beginMessageSearch(self.query)
            }
        }
        
        if let controller = self.myController {
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top - 89.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
            if controller.displayNode.supernode == nil {
                controller.viewWillAppear(false)
                self.insertSubnode(controller.displayNode, at: 0)
                controller.viewDidAppear(false)
                
                controller.beginMessageSearch(self.query)
            }
        }
        
        if let controller = self.globalController {
            transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layout.size))
            controller.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top - 89.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
            
            if controller.displayNode.supernode == nil {
                controller.viewWillAppear(false)
                self.insertSubnode(controller.displayNode, at: 0)
                controller.viewDidAppear(false)
                
                controller.beginMessageSearch(self.query)
            }
        }
        
        let overflowInset: CGFloat = 0.0
        let topInset = navigationBarHeight
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: overflowInset, y: topInset), size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height))
        self.shimmerNode.update(context: self.context, size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height), presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, animationCache: self.context.animationCache, animationRenderer: self.context.animationRenderer, key: .chats, hasSelection: false, transition: transition)
        
        if isFirstTime {
            self.insertSubnode(self.recentListNode, aboveSubnode: self.shimmerNode)
        }
        
        self.recentListNode.frame = CGRect(origin: .zero, size: layout.size)
        self.recentListNode.updateLayout(layout: ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top - 35.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
        self.recentListNode.isHidden = !self.query.isEmpty
        
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
