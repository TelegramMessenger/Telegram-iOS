import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramBaseController
import AccountContext
import ChatListUI
import ListMessageItem
import AnimationCache
import MultiAnimationRenderer

public final class HashtagSearchController: TelegramBaseController {
    private let queue = Queue()
    
    private let context: AccountContext
    private let peer: EnginePeer?
    private let query: String
    let all: Bool
    private var transitionDisposable: Disposable?
    private let openMessageFromSearchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private var controllerNode: HashtagSearchControllerNode {
        return self.displayNode as! HashtagSearchControllerNode
    }
    
    public init(context: AccountContext, peer: EnginePeer?, query: String, all: Bool = false) {
        self.context = context
        self.peer = peer
        self.query = query
        self.all = all
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = query
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
//        let location: SearchMessagesLocation = .general(scope: .everywhere, tags: nil, minDate: nil, maxDate: nil)
//        let search = context.engine.messages.searchMessages(location: location, query: query, state: nil)
//        let foundMessages: Signal<[ChatListSearchEntry], NoError> = combineLatest(search, self.context.sharedContext.presentationData)
//        |> map { result, presentationData in
//            let result = result.0
//            let chatListPresentationData = ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
//            return result.messages.map({ .message(EngineMessage($0), EngineRenderedPeer(message: EngineMessage($0)), result.readStates[$0.id.peerId].flatMap { EnginePeerReadCounters(state: $0, isMuted: false) }, nil, chatListPresentationData, result.totalCount, nil, false, .index($0.index), nil, .generic, false, nil, false) })
//        }
        
//        let interaction = ChatListNodeInteraction(context: context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, activateSearch: {
//        }, peerSelected: { _, _, _, _ in
//        }, disabledPeerSelected: { _, _, _ in
//        }, togglePeerSelected: { _, _ in
//        }, togglePeersSelection: { _, _ in
//        }, additionalCategorySelected: { _ in
//        }, messageSelected: { [weak self] peer, _, message, _ in
//            if let strongSelf = self {
//                strongSelf.openMessageFromSearchDisposable.set((strongSelf.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer) |> deliverOnMainQueue).start(next: { actualPeer in
//                    if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
//                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(actualPeer), subject: message.id.peerId == actualPeer.id ? .message(id: .id(message.id), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil) : nil, keepStack: .always))
//                    }
//                }))
//            }
//        }, groupSelected: { _ in
//        }, addContact: {_ in
//        }, setPeerIdWithRevealedOptions: { _, _ in
//        }, setItemPinned: { _, _ in
//        }, setPeerMuted: { _, _ in
//        }, setPeerThreadMuted: { _, _, _ in
//        }, deletePeer: { _, _ in
//        }, deletePeerThread: { _, _ in
//        }, setPeerThreadStopped: { _, _, _ in
//        }, setPeerThreadPinned: { _, _, _ in
//        }, setPeerThreadHidden: { _, _, _ in
//        }, updatePeerGrouping: { _, _ in
//        }, togglePeerMarkedUnread: { _, _ in
//        }, toggleArchivedFolderHiddenByDefault: {
//        }, toggleThreadsSelection: { _, _ in
//        }, hidePsa: { _ in
//        }, activateChatPreview: { _, _, _, gesture, _ in
//            gesture?.cancel()
//        }, present: { _ in
//        }, openForumThread: { _, _ in
//        }, openStorageManagement: {
//        }, openPasswordSetup: {
//        }, openPremiumIntro: {
//        }, openPremiumGift: { _ in
//        }, openPremiumManagement: {   
//        }, openActiveSessions: {
//        }, openBirthdaySetup: {
//        }, performActiveSessionAction: { _, _ in
//        }, openChatFolderUpdates: {
//        }, hideChatFolderUpdates: {
//        }, openStories: { _, _ in
//        }, dismissNotice: { _ in
//        }, editPeer: { _ in
//        })
                
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = HashtagSearchControllerNode(context: self.context, controller: self, peer: self.peer, query: self.query, navigationBar: self.navigationBar, navigationController: self.navigationController as? NavigationController)
        if let chatController = self.controllerNode.currentController {
            chatController.parentController = self
        }
        
        self.displayNodeDidLoad()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.controllerNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let _ = self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, transition: transition)
    }
}
