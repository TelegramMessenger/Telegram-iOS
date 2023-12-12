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
        
    public init(context: AccountContext, navigationController: @escaping () -> NavigationController?) {
        self.context = context
        self.navigationController = navigationController
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
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
        
        self.chatListNode.peerSelected = { [weak self] peer, _, _, _, _ in
            guard let self, let navigationController = self.navigationController() else {
                return
            }
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: self.context,
                chatLocation: .replyThread(ChatReplyThreadMessage(
                    messageId: makeThreadIdMessageId(
                        peerId: self.context.account.peerId,
                        threadId: peer.id.toInt64()
                    ),
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
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }

    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
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
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
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
