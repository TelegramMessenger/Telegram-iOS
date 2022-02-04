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

public final class HashtagSearchController: TelegramBaseController {
    private let queue = Queue()
    
    private let context: AccountContext
    private let peer: EnginePeer?
    private let query: String
    private var transitionDisposable: Disposable?
    private let openMessageFromSearchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var controllerNode: HashtagSearchControllerNode {
        return self.displayNode as! HashtagSearchControllerNode
    }
    
    public init(context: AccountContext, peer: EnginePeer?, query: String) {
        self.context = context
        self.peer = peer
        self.query = query
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = query
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        let chatListPresentationData = ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)
        
        let location: SearchMessagesLocation = .general(tags: nil, minDate: nil, maxDate: nil)
        let search = context.engine.messages.searchMessages(location: location, query: query, state: nil)
        let foundMessages: Signal<[ChatListSearchEntry], NoError> = search
        |> map { result, _ in
            return result.messages.map({ .message(EngineMessage($0), EngineRenderedPeer(message: EngineMessage($0)), result.readStates[$0.id.peerId].flatMap(EnginePeerReadCounters.init), chatListPresentationData, result.totalCount, nil, false) })
        }
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { _, _, _ in
        }, disabledPeerSelected: { _ in
        }, togglePeerSelected: { _ in
        }, togglePeersSelection: { _, _ in
        }, additionalCategorySelected: { _ in
        }, messageSelected: { [weak self] peer, message, _ in
            if let strongSelf = self {
                strongSelf.openMessageFromSearchDisposable.set((storedMessageFromSearchPeer(account: strongSelf.context.account, peer: peer._asPeer()) |> deliverOnMainQueue).start(next: { actualPeerId in
                    if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(actualPeerId), subject: message.id.peerId == actualPeerId ? .message(id: .id(message.id), highlight: true, timecode: nil) : nil, keepStack: .always))
                    }
                }))
                strongSelf.controllerNode.listNode.clearHighlightAnimated(true)
            }
        }, groupSelected: { _ in
        }, addContact: {_ in
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, deletePeer: { _, _ in
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
                
                let listInteraction = ListMessageItemInteraction(openMessage: { message, mode -> Bool in
                    return true
                }, openMessageContextMenu: { message, bool, node, rect, gesture in 
                }, toggleMessagesSelection: { messageId, selected in
                }, openUrl: { url, _, _, message in
                }, openInstantPage: { message, data in
                }, longTap: { action, message in 
                }, getHiddenMedia: {
                    return [:]
                })
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries, displayingResults: true, isEmpty: entries.isEmpty, isLoading: false, animated: false, context: strongSelf.context, presentationData: strongSelf.presentationData, enableHeaders: false, filter: [], tagMask: nil, interaction: interaction, listInteraction: listInteraction, peerContextAction: nil, toggleExpandLocalResults: {
                }, toggleExpandGlobalResults: {
                }, searchPeer: { _ in
                }, searchQuery: "", searchOptions: nil, messageContextAction: nil)
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
        self.displayNode = HashtagSearchControllerNode(context: self.context, peer: self.peer, query: self.query, theme: self.presentationData.theme, strings: self.presentationData.strings, navigationBar: self.navigationBar, navigationController: self.navigationController as? NavigationController)
        if let chatController = self.controllerNode.chatController {
            chatController.parentController = self
        }
        
        self.displayNodeDidLoad()
    }

    private var suspendNavigationBarLayout: Bool = false
    private var suspendedNavigationBarLayout: ContainerViewLayout?
    private var additionalNavigationBarBackgroundHeight: CGFloat = 0.0

    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.suspendNavigationBarLayout {
            self.suspendedNavigationBarLayout = layout
            return
        }
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, transition: transition)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.suspendNavigationBarLayout = true

        super.containerLayoutUpdated(layout, transition: transition)
        
        self.additionalNavigationBarBackgroundHeight = self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)

        self.suspendNavigationBarLayout = false
        if let suspendedNavigationBarLayout = self.suspendedNavigationBarLayout {
            self.suspendedNavigationBarLayout = suspendedNavigationBarLayout
            self.applyNavigationBarLayout(suspendedNavigationBarLayout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, transition: transition)
        }
    }
}
