import Foundation
import UIKit
import Display
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramBaseController
import AccountContext
import ChatListUI

public final class HashtagSearchController: TelegramBaseController {
    private let queue = Queue()
    
    private let context: AccountContext
    private let peer: Peer?
    private let query: String
    private var transitionDisposable: Disposable?
    private let openMessageFromSearchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var controllerNode: HashtagSearchControllerNode {
        return self.displayNode as! HashtagSearchControllerNode
    }
    
    public init(context: AccountContext, peer: Peer?, query: String) {
        self.context = context
        self.peer = peer
        self.query = query
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = query
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        let chatListPresentationData = ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations)
        
        let location: SearchMessagesLocation = .general
        let search = searchMessages(account: context.account, location: location, query: query, state: nil)
        let foundMessages: Signal<[ChatListSearchEntry], NoError> = search
        |> map { result, _ in
            return result.messages.map({ .message($0, RenderedPeer(message: $0), result.readStates[$0.id.peerId], chatListPresentationData) })
        }
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { _, _ in
        }, disabledPeerSelected: { _ in
        }, togglePeerSelected: { _ in
        }, additionalCategorySelected: { _ in
        }, messageSelected: { [weak self] peer, message, _ in
            if let strongSelf = self {
                strongSelf.openMessageFromSearchDisposable.set((storedMessageFromSearchPeer(account: strongSelf.context.account, peer: peer) |> deliverOnMainQueue).start(next: { actualPeerId in
                    if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(actualPeerId), subject: message.id.peerId == actualPeerId ? .message(message.id) : nil, keepStack: .always))
                    }
                }))
                strongSelf.controllerNode.listNode.clearHighlightAnimated(true)
            }
        }, groupSelected: { _ in
        }, addContact: {_ in
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, deletePeer: { _ in
        }, updatePeerGrouping: { _, _ in
        }, togglePeerMarkedUnread: { _, _ in
        }, toggleArchivedFolderHiddenByDefault: {
        }, hidePsa: { _ in
        }, activateChatPreview: { _, _, gesture in
            gesture?.cancel()
        }, present: { _ in
        })
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        self.transitionDisposable = (foundMessages
        |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries, displayingResults: true, context: strongSelf.context, presentationData: strongSelf.presentationData, enableHeaders: false, filter: [], interaction: interaction, peerContextAction: nil, toggleExpandLocalResults: {
                }, toggleExpandGlobalResults: {
                })
                strongSelf.controllerNode.enqueueTransition(transition, firstTime: firstTime)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.transitionDisposable?.dispose()
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = HashtagSearchControllerNode(context: self.context, peer: self.peer, query: self.query, theme: self.presentationData.theme, strings: self.presentationData.strings, navigationController: self.navigationController as? NavigationController)
        if let chatController = self.controllerNode.chatController {
            chatController.parentController = self
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
