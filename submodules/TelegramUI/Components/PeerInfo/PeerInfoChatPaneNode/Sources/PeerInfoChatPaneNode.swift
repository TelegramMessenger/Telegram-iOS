import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import TelegramStringFormatting
import ComponentFlow
import TelegramUIPreferences
import AppBundle
import PeerInfoPaneNode

public final class PeerInfoChatPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let navigationController: () -> NavigationController?
    
    private let chatController: ChatController
    
    public weak var parentController: ViewController? {
        didSet {
            if self.parentController !== oldValue {
                if let parentController = self.parentController {
                    self.chatController.willMove(toParent: parentController)
                    parentController.addChild(self.chatController)
                    self.chatController.didMove(toParent: parentController)
                } else {
                    self.chatController.willMove(toParent: nil)
                    self.chatController.removeFromParent()
                    self.chatController.didMove(toParent: nil)
                }
            }
        }
    }
    
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
        
    public init(context: AccountContext, peerId: EnginePeer.Id, navigationController: @escaping () -> NavigationController?) {
        self.context = context
        self.peerId = peerId
        self.navigationController = navigationController
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.chatController = context.sharedContext.makeChatController(context: context, chatLocation: .replyThread(message: ChatReplyThreadMessage(peerId: context.account.peerId, threadId: peerId.toInt64(), channelMessageId: nil, isChannelPost: false, isForumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false)), subject: nil, botStart: nil, mode: .standard(.embedded(invertDirection: true)))
        
        super.init()
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
        })
        
        self.ready.set(self.chatController.ready.get())
        
        self.addSubnode(self.chatController.displayNode)
        self.chatController.displayNode.clipsToBounds = true
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }

    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        return self.chatController.performScrollToTop()
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
        if velocity > 0.0 {
            self.chatController.transferScrollingVelocity(velocity)
        }
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
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        let chatFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: size.width, height: size.height - topInset))
        
        let combinedBottomInset = bottomInset
        transition.updateFrame(node: self.chatController.displayNode, frame: chatFrame)
        self.chatController.updateIsScrollingLockedAtTop(isScrollingLockedAtTop: isScrollingLockedAtTop)
        self.chatController.containerLayoutUpdated(ContainerViewLayout(size: chatFrame.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(top: 4.0, left: sideInset, bottom: combinedBottomInset, right: sideInset), safeInsets: UIEdgeInsets(top: 4.0, left: sideInset, bottom: combinedBottomInset, right: sideInset), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        return result
    }
}
