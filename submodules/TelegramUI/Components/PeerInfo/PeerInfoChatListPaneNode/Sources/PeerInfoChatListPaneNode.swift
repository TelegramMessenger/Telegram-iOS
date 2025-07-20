import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import TelegramStringFormatting
import ShimmerEffect
import ComponentFlow
import TelegramNotices
import TelegramUIPreferences
import AppBundle
import PeerInfoPaneNode
import ChatListUI
import DeleteChatPeerActionSheetItem
import UndoUI

private final class SearchNavigationContentNode: ASDisplayNode, PeerInfoPanelNodeNavigationContentNode {
    private struct Params: Equatable {
        var width: CGFloat
        var defaultHeight: CGFloat
        var insets: UIEdgeInsets
        
        init(width: CGFloat, defaultHeight: CGFloat, insets: UIEdgeInsets) {
            self.width = width
            self.defaultHeight = defaultHeight
            self.insets = insets
        }
    }
    
    weak var chatController: ChatController?
    let contentNode: NavigationBarContentNode
    
    var panelNode: ChatControllerCustomNavigationPanelNode?
    private var appliedPanelNode: ChatControllerCustomNavigationPanelNode?
    
    private var params: Params?
    
    init(chatController: ChatController, contentNode: NavigationBarContentNode) {
        self.chatController = chatController
        self.contentNode = contentNode
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    func update(transition: ContainedViewLayoutTransition) {
        if let params = self.params {
            let _ = self.update(width: params.width, defaultHeight: params.defaultHeight, insets: params.insets, transition: transition)
        }
    }
    
    func update(width: CGFloat, defaultHeight: CGFloat, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.params = Params(width: width, defaultHeight: defaultHeight, insets: insets)
        
        let size = CGSize(width: width, height: defaultHeight)
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: size))
        self.contentNode.updateLayout(size: size, leftInset: insets.left, rightInset: insets.right, transition: transition)
        
        var contentHeight: CGFloat = size.height + 10.0
        
        if self.appliedPanelNode !== self.panelNode {
            if let previous = self.appliedPanelNode {
                transition.updateAlpha(node: previous, alpha: 0.0, completion: { [weak previous] _ in
                    previous?.removeFromSupernode()
                })
            }
            
            self.appliedPanelNode = self.panelNode
            if let panelNode = self.panelNode, let chatController = self.chatController {
                self.addSubnode(panelNode)
                let panelLayout = panelNode.updateLayout(width: width, leftInset: insets.left, rightInset: insets.right, transition: .immediate, chatController: chatController)
                let panelHeight = panelLayout.backgroundHeight
                let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: panelHeight))
                panelNode.frame = panelFrame
                panelNode.alpha = 0.0
                transition.updateAlpha(node: panelNode, alpha: 1.0)
                
                contentHeight += panelHeight - 1.0
            }
        } else if let panelNode = self.panelNode, let chatController = self.chatController {
            let panelLayout = panelNode.updateLayout(width: width, leftInset: insets.left, rightInset: insets.right, transition: transition, chatController: chatController)
            let panelHeight = panelLayout.backgroundHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: panelHeight))
            transition.updateFrame(node: panelNode, frame: panelFrame)
            
            contentHeight += panelHeight - 1.0
        }
        
        return contentHeight
    }
}

public final class PeerInfoChatListPaneNode: ASDisplayNode, PeerInfoPaneNode, ASScrollViewDelegate, ASGestureRecognizerDelegate {
    private let context: AccountContext
    
    private let navigationController: () -> NavigationController?
    
    public weak var parentController: ViewController?
    
    private var currentParams: (size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    public var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    public var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }

    public var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public var tabBarOffset: CGFloat {
        return 0.0
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let chatListNode: ChatListNode
    
    private var emptyShimmerEffectNode: ChatListShimmerNode?
    private var shimmerNodeOffset: CGFloat = 0.0
    private var floatingHeaderOffset: CGFloat?
    
    private let coveringView: UIView
    private var chatController: ChatController?
    private var removeChatWhenNotSearching: Bool = false
    
    private var searchNavigationContentNode: SearchNavigationContentNode?
    public var navigationContentNode: PeerInfoPanelNodeNavigationContentNode? {
        return self.searchNavigationContentNode
    }
    public var externalDataUpdated: ((ContainedViewLayoutTransition) -> Void)?
        
    public init(context: AccountContext, navigationController: @escaping () -> NavigationController?) {
        self.context = context
        self.navigationController = navigationController
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        let strings = presentationData.strings
        
        self.coveringView = UIView()
        
        self.chatListNode = ChatListNode(
            context: self.context,
            location: .savedMessagesChats(peerId: context.account.peerId),
            chatListFilter: nil,
            previewing: false,
            fillPreloadItems: false,
            mode: .chatList(appendContacts: false),
            isPeerEnabled: nil,
            theme: self.presentationData.theme,
            fontSize: self.presentationData.listsFontSize,
            strings: self.presentationData.strings,
            dateTimeFormat: self.presentationData.dateTimeFormat,
            nameSortOrder: self.presentationData.nameSortOrder,
            nameDisplayOrder: self.presentationData.nameDisplayOrder,
            animationCache: self.context.animationCache,
            animationRenderer: self.context.animationRenderer,
            disableAnimations: false,
            isInlineMode: false,
            autoSetReady: false,
            isMainTab: nil
        )
        self.chatListNode.synchronousDrawingWhenNotAnimated = true
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.chatListNode)
        
        self.view.addSubview(self.coveringView)
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
        })
        
        self.ready.set(self.chatListNode.ready)
        
        self.statusPromise.set(self.context.engine.messages.savedMessagesPeersStats()
        |> map { count in
            if let count {
                return PeerInfoStatusData(text: strings.Notifications_Exceptions(Int32(count)), isActivity: false, key: .savedMessagesChats)
            } else {
                return PeerInfoStatusData(text: strings.Channel_NotificationLoading.lowercased(), isActivity: false, key: .savedMessagesChats)
            }
        })
        
        self.chatListNode.peerSelected = { [weak self] peer, _, _, _, _ in
            guard let self, let navigationController = self.navigationController() else {
                return
            }
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: self.context,
                chatLocation: .replyThread(ChatReplyThreadMessage(
                    peerId: self.context.account.peerId,
                    threadId: peer.id.toInt64(),
                    channelMessageId: nil,
                    isChannelPost: false,
                    isForumPost: false,
                    isMonoforumPost: false,
                    maxMessage: nil,
                    maxReadIncomingMessageId: nil,
                    maxReadOutgoingMessageId: nil,
                    unreadCount: 0,
                    initialFilledHoles: IndexSet(),
                    initialAnchor: .automatic,
                    isNotAvailable: false
                )),
                subject: nil,
                keepStack: .always
            ))
            self.chatListNode.clearHighlightAnimated(true)
        }
        
        self.chatListNode.isEmptyUpdated = { [weak self] isEmptyState, _, transition in
            guard let self else {
                return
            }
            var needsShimmerNode = false
            let shimmerNodeOffset: CGFloat = 0.0
            
            switch isEmptyState {
            case let .empty(isLoadingValue, _):
                if isLoadingValue {
                    needsShimmerNode = true
                }
            case .notEmpty:
                break
            }
            
            if needsShimmerNode {
                self.shimmerNodeOffset = shimmerNodeOffset
                if self.emptyShimmerEffectNode == nil {
                    let emptyShimmerEffectNode = ChatListShimmerNode()
                    self.emptyShimmerEffectNode = emptyShimmerEffectNode
                    self.insertSubnode(emptyShimmerEffectNode, belowSubnode: self.chatListNode)
                    if let currentParams = self.currentParams, let offset = self.floatingHeaderOffset {
                        self.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: currentParams.size, insets: UIEdgeInsets(top: currentParams.topInset, left: currentParams.sideInset, bottom: currentParams.bottomInset, right: currentParams.sideInset), verticalOffset: offset + self.shimmerNodeOffset, transition: .immediate)
                    }
                }
            } else if let emptyShimmerEffectNode = self.emptyShimmerEffectNode {
                self.emptyShimmerEffectNode = nil
                let emptyNodeTransition = transition.isAnimated ? transition : .animated(duration: 0.3, curve: .easeInOut)
                emptyNodeTransition.updateAlpha(node: emptyShimmerEffectNode, alpha: 0.0, completion: { [weak emptyShimmerEffectNode] _ in
                    emptyShimmerEffectNode?.removeFromSupernode()
                })
                self.chatListNode.alpha = 0.0
                emptyNodeTransition.updateAlpha(node: self.chatListNode, alpha: 1.0)
            }
        }
        
        self.chatListNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
            guard let self else {
                return
            }
            self.floatingHeaderOffset = offset
            if let currentParams = self.currentParams, let emptyShimmerEffectNode = self.emptyShimmerEffectNode {
                self.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: currentParams.size, insets: UIEdgeInsets(top: currentParams.topInset, left: currentParams.sideInset, bottom: currentParams.bottomInset, right: currentParams.sideInset), verticalOffset: offset + self.shimmerNodeOffset, transition: transition)
            }
        }
        
        self.chatListNode.push = { [weak self] c in
            guard let self else {
                return
            }
            self.parentController?.push(c)
        }
        
        self.chatListNode.present = { [weak self] c in
            guard let self else {
                return
            }
            self.parentController?.present(c, in: .window(.root))
        }
        
        self.chatListNode.deletePeerChat = { [weak self] peerId, _ in
            guard let self else {
                return
            }
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                
                self.view.window?.endEditing(true)
                
                let actionSheet = ActionSheetController(presentationData: self.presentationData)
                var items: [ActionSheetItem] = []
                items.append(DeleteChatPeerActionSheetItem(context: self.context, peer: peer, chatPeer: peer, action: .deleteSavedPeer, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder, balancedLayout: true))
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.Common_Delete, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    guard let self else {
                        return
                    }
                    
                    self.chatListNode.updateState({ state in
                        var state = state
                        state.pendingRemovalItemIds.insert(ChatListNodeState.ItemId(peerId: peer.id, threadId: nil))
                        return state
                    })
                    self.parentController?.forEachController({ controller in
                        if let controller = controller as? UndoOverlayController {
                            controller.dismissWithCommitActionAndReplacementAnimation()
                        }
                        return true
                    })
                    
                    if self.chatListNode.entryPeerIds.count == 0 || self.chatListNode.entryPeerIds == [peer.id] {
                        let _ = context.engine.messages.clearHistoryInteractively(peerId: self.context.account.peerId, threadId: peer.id.toInt64(), type: .forLocalPeer).startStandalone(completed: {
                        })
                        context.engine.peers.updateSavedMessagesViewAsTopics(value: false)
                        
                        self.parentController?.dismiss()
                        
                        return
                    }
                    
                    let context = self.context
                    let undoController = UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(context: self.context, title: NSAttributedString(string: self.presentationData.strings.SavedMessages_SubChatDeleted), text: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
                        if value == .commit {
                            let _ = context.engine.messages.clearHistoryInteractively(peerId: context.account.peerId, threadId: peer.id.toInt64(), type: .forLocalPeer).startStandalone(completed: {
                                guard let self else {
                                    return
                                }
                                self.chatListNode.updateState({ state in
                                    var state = state
                                    state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peer.id, threadId: nil))
                                    return state
                                })
                            })
                            return true
                        } else if value == .undo {
                            if let self {
                                self.chatListNode.updateState({ state in
                                    var state = state
                                    state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peer.id, threadId: nil))
                                    return state
                                })
                            }
                            return true
                        }
                        return false
                    })
                    self.parentController?.present(undoController, in: .window(.root))
                }))
                
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                self.parentController?.present(actionSheet, in: .window(.root))
            })
        }
        
        self.chatListNode.activateChatPreview = { [weak self] item, _, node, gesture, location in
            guard let self, let parentController = self.parentController else {
                gesture?.cancel()
                return
            }
            
            if case let .peer(peerData) = item.content {
                let threadId = peerData.peer.peerId.toInt64()
                let chatController = self.context.sharedContext.makeChatController(context: self.context, chatLocation: .replyThread(message: ChatReplyThreadMessage(
                    peerId: self.context.account.peerId, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: false, isMonoforumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false
                )), subject: nil, botStart: nil, mode: .standard(.previewing), params: nil)
                chatController.canReadHistory.set(false)
                let source: ContextContentSource = .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, navigationController: parentController.navigationController as? NavigationController))
                
                let contextController = ContextController(presentationData: self.presentationData, source: source, items: savedMessagesPeerMenuItems(context: self.context, threadId: threadId, parentController: parentController, deletePeerChat: { [weak self] peerId in
                    guard let self else {
                        return
                    }
                    self.chatListNode.deletePeerChat?(peerId, false)
                }) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                parentController.presentInGlobalOverlay(contextController)
            }
        }
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    public func activateSearch() {
        if self.chatController == nil {
            let chatController = self.context.sharedContext.makeChatController(context: self.context, chatLocation: .peer(id: self.context.account.peerId), subject: nil, botStart: nil, mode: .standard(.embedded(invertDirection: false)), params: nil)
            chatController.alwaysShowSearchResultsAsList = true
            chatController.includeSavedPeersInSearchResults = true
            self.chatController = chatController
            chatController.navigation_setNavigationController(self.navigationController())
            
            self.insertSubnode(chatController.displayNode, aboveSubnode: self.chatListNode)
            chatController.displayNode.alpha = 0.0
            chatController.displayNode.clipsToBounds = true
            
            self.updateChatController(transition: .immediate)
            
            let _ = (chatController.ready.get()
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self, weak chatController] _ in
                guard let self, let chatController, self.chatController === chatController else {
                    return
                }
                
                chatController.customDismissSearch = { [weak self] in
                    guard let self else {
                        return
                    }
                    if self.searchNavigationContentNode !== nil {
                        self.searchNavigationContentNode = nil
                        self.externalDataUpdated?(.animated(duration: 0.4, curve: .spring))
                    }
                    
                    self.removeChatController()
                }
                chatController.stateUpdated = { [weak self] transition in
                    guard let self, let chatController = self.chatController else {
                        return
                    }
                    if let contentNode = chatController.customNavigationBarContentNode {
                        self.removeChatWhenNotSearching = true
                        
                        chatController.displayNode.layer.allowsGroupOpacity = true
                        if transition.isAnimated {
                            ComponentTransition.easeInOut(duration: 0.2).setAlpha(layer: chatController.displayNode.layer, alpha: 1.0)
                        }
                        
                        if self.searchNavigationContentNode?.contentNode !== contentNode {
                            self.searchNavigationContentNode = SearchNavigationContentNode(chatController: chatController, contentNode: contentNode)
                            self.searchNavigationContentNode?.panelNode = chatController.customNavigationPanelNode
                            self.externalDataUpdated?(transition)
                        } else if self.searchNavigationContentNode?.panelNode !== chatController.customNavigationPanelNode {
                            self.searchNavigationContentNode?.panelNode = chatController.customNavigationPanelNode
                            self.externalDataUpdated?(transition.isAnimated ? transition : .animated(duration: 0.4, curve: .spring))
                        } else {
                            self.searchNavigationContentNode?.update(transition: transition)
                        }
                    } else {
                        if self.searchNavigationContentNode !== nil {
                            self.searchNavigationContentNode = nil
                            self.externalDataUpdated?(transition)
                        }
                        
                        if self.removeChatWhenNotSearching {
                            self.removeChatController()
                        }
                    }
                }
                
                chatController.activateSearch(domain: .everything, query: "")
            })
        }
    }
    
    private func removeChatController() {
        if let chatController = self.chatController {
            self.chatController = nil
            
            let displayNode = chatController.displayNode
            chatController.displayNode.layer.allowsGroupOpacity = true
            chatController.displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak displayNode] _ in
                displayNode?.removeFromSupernode()
            })
        }
    }

    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        if let chatController = self.chatController {
            let _ = chatController.performScrollToTop()
        } else {
            self.chatListNode.scrollToPosition(.top(adjustForTempInset: false))
        }
        
        return false
    }

    public func hitTestResultForScrolling() -> UIView? {
        return nil
    }

    public func brieflyDisableTouchActions() {
    }
    
    public func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    public func updateHiddenMedia() {
    }
    
    public func transferVelocity(_ velocity: CGFloat) {
    }
    
    public func cancelPreviewGestures() {
    }
    
    public func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    public func addToTransitionSurface(view: UIView) {
    }
    
    override public func didLoad() {
        super.didLoad()
    }
    
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    private func layoutEmptyShimmerEffectNode(node: ChatListShimmerNode, size: CGSize, insets: UIEdgeInsets, verticalOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        node.update(context: self.context, animationCache: self.context.animationCache, animationRenderer: self.context.animationRenderer, size: size, isInlineMode: false, presentationData: self.presentationData, transition: .immediate)
        transition.updateFrameAdditive(node: node, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: size))
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.state != .failed, let otherGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer {
            let _ = otherGestureRecognizer
            return true
        } else {
            return false
        }
    }
    
    public func updateSelectedMessages(animated: Bool) {
    }
    
    private func updateChatController(transition: ContainedViewLayoutTransition) {
        guard let chatController = self.chatController else {
            return
        }
        guard let currentParams = self.currentParams else {
            return
        }
        
        let size = currentParams.size
        let topInset = currentParams.topInset
        let sideInset = currentParams.sideInset
        let bottomInset = currentParams.bottomInset
        let navigationHeight = currentParams.navigationHeight
        let deviceMetrics = currentParams.deviceMetrics
        let isScrollingLockedAtTop = currentParams.isScrollingLockedAtTop
        
        let fullHeight = navigationHeight + size.height
        
        let chatFrame = CGRect(origin: CGPoint(x: 0.0, y: -navigationHeight), size: CGSize(width: size.width, height: fullHeight))
        
        if !chatController.displayNode.bounds.isEmpty {
            if let contextController = chatController.visibleContextController as? ContextController {
                let deltaY = chatFrame.minY - chatController.displayNode.frame.minY
                contextController.addRelativeContentOffset(CGPoint(x: 0.0, y: -deltaY * 0.0), transition: transition)
            }
        }
        
        let combinedBottomInset = bottomInset
        transition.updateFrame(node: chatController.displayNode, frame: chatFrame)
        chatController.updateIsScrollingLockedAtTop(isScrollingLockedAtTop: isScrollingLockedAtTop)
        chatController.containerLayoutUpdated(ContainerViewLayout(size: chatFrame.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(top: topInset + navigationHeight, left: sideInset, bottom: combinedBottomInset, right: sideInset), safeInsets: UIEdgeInsets(top: navigationHeight + topInset + 4.0, left: sideInset, bottom: combinedBottomInset, right: sideInset), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, deviceMetrics: deviceMetrics, visibleHeight, isScrollingLockedAtTop, expandProgress, navigationHeight, presentationData)
        
        self.coveringView.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        transition.updateFrame(view: self.coveringView, frame: CGRect(origin: CGPoint(x: 0.0, y: -1.0), size: CGSize(width: size.width, height: topInset + 1.0)))
        
        let fullHeight = navigationHeight + size.height
        let chatFrame = CGRect(origin: CGPoint(x: 0.0, y: -navigationHeight), size: CGSize(width: size.width, height: fullHeight))
        let combinedBottomInset = bottomInset
        
        transition.updateFrame(node: self.chatListNode, frame: chatFrame)
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.chatListNode.updateLayout(
            transition: transition,
            updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                size: size,
                insets: UIEdgeInsets(top: topInset + navigationHeight, left: sideInset, bottom: combinedBottomInset, right: sideInset),
                duration: duration,
                curve: curve
            ),
            visibleTopInset: topInset + navigationHeight,
            originalTopInset: topInset + navigationHeight,
            storiesInset: 0.0,
            inlineNavigationLocation: nil,
            inlineNavigationTransitionFraction: 0.0
        )
        
        self.updateChatController(transition: transition)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        return result
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController?
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, navigationController: NavigationController?) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.navigationController = navigationController
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode.view, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}
