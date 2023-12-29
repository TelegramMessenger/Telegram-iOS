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

public final class PeerInfoChatListPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let context: AccountContext
    
    private let navigationController: () -> NavigationController?
    
    public weak var parentController: ViewController?
    
    private var currentParams: (size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
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
        
    public init(context: AccountContext, navigationController: @escaping () -> NavigationController?) {
        self.context = context
        self.navigationController = navigationController
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        let strings = presentationData.strings
        
        self.chatListNode = ChatListNode(
            context: self.context,
            location: .savedMessagesChats,
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
        
        super.init()
        
        self.addSubnode(self.chatListNode)
        
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
                    
                    self.parentController?.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(title: self.presentationData.strings.SavedMessages_SubChatDeleted, text: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
                        guard let self else {
                            return false
                        }
                        if value == .commit {
                            let _ = self.context.engine.messages.clearHistoryInteractively(peerId: self.context.account.peerId, threadId: peer.id.toInt64(), type: .forLocalPeer).startStandalone(completed: { [weak self] in
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
                            self.chatListNode.updateState({ state in
                                var state = state
                                state.pendingRemovalItemIds.remove(ChatListNodeState.ItemId(peerId: peer.id, threadId: nil))
                                return state
                            })
                            return true
                        }
                        return false
                    }), in: .current)
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
                    peerId: self.context.account.peerId, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false
                )), subject: nil, botStart: nil, mode: .standard(.previewing))
                chatController.canReadHistory.set(false)
                let source: ContextContentSource = .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, navigationController: parentController.navigationController as? NavigationController))
                
                let contextController = ContextController(presentationData: self.presentationData, source: source, items: savedMessagesPeerMenuItems(context: self.context, threadId: threadId, parentController: parentController) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                parentController.presentInGlobalOverlay(contextController)
            }
        }
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }

    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        self.chatListNode.scrollToPosition(.top(adjustForTempInset: false))
        
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
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        
        transition.updateFrame(node: self.chatListNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.chatListNode.updateLayout(
            transition: transition,
            updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                size: size,
                insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset),
                duration: duration,
                curve: curve
            ),
            visibleTopInset: topInset,
            originalTopInset: topInset,
            storiesInset: 0.0,
            inlineNavigationLocation: nil,
            inlineNavigationTransitionFraction: 0.0
        )
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
