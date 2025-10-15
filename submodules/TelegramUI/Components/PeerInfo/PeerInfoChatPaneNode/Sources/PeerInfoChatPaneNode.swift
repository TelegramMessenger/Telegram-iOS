import UIKit
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
import ContextUI

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

public final class PeerInfoChatPaneNode: ASDisplayNode, PeerInfoPaneNode, ASScrollViewDelegate, ASGestureRecognizerDelegate {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let navigationController: () -> NavigationController?
    
    private let chatController: ChatController
    
    private let coveringView: UIView
    
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
    
    private var searchNavigationContentNode: SearchNavigationContentNode?
    public var navigationContentNode: PeerInfoPanelNodeNavigationContentNode? {
        return self.searchNavigationContentNode
    }
    public var externalDataUpdated: ((ContainedViewLayoutTransition) -> Void)?

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
        
    public init(context: AccountContext, peerId: EnginePeer.Id, navigationController: @escaping () -> NavigationController?) {
        self.context = context
        self.peerId = peerId
        self.navigationController = navigationController
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.coveringView = UIView()
        
        self.chatController = context.sharedContext.makeChatController(context: context, chatLocation: .replyThread(message: ChatReplyThreadMessage(peerId: context.account.peerId, threadId: peerId.toInt64(), channelMessageId: nil, isChannelPost: false, isForumPost: false, isMonoforumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false)), subject: nil, botStart: nil, mode: .standard(.embedded(invertDirection: true)), params: nil)
        self.chatController.navigation_setNavigationController(navigationController())
        
        super.init()
        
        self.clipsToBounds = true
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
        })
        
        let strings = self.presentationData.strings
        self.statusPromise.set(self.context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: self.context.account.peerId, threadId: peerId.toInt64(), tag: [])
        )
        |> map { count in
            if let count {
                return PeerInfoStatusData(text: strings.Conversation_Messages(Int32(count)), isActivity: false, key: .savedMessages)
            } else {
                return nil
            }
        })
        
        self.ready.set(self.chatController.ready.get())
        
        self.addSubnode(self.chatController.displayNode)
        self.chatController.displayNode.clipsToBounds = true
        
        self.view.addSubview(self.coveringView)
        
        self.chatController.stateUpdated = { [weak self] transition in
            guard let self else {
                return
            }
            if let contentNode = self.chatController.customNavigationBarContentNode {
                if self.searchNavigationContentNode?.contentNode !== contentNode {
                    self.searchNavigationContentNode = SearchNavigationContentNode(chatController: self.chatController, contentNode: contentNode)
                    self.searchNavigationContentNode?.panelNode = self.chatController.customNavigationPanelNode
                    self.externalDataUpdated?(transition)
                } else if self.searchNavigationContentNode?.panelNode !== self.chatController.customNavigationPanelNode {
                    self.searchNavigationContentNode?.panelNode = self.chatController.customNavigationPanelNode
                    self.externalDataUpdated?(transition.isAnimated ? transition : .animated(duration: 0.4, curve: .spring))
                } else {
                    self.searchNavigationContentNode?.update(transition: transition)
                }
            } else {
                if self.searchNavigationContentNode !== nil {
                    self.searchNavigationContentNode = nil
                    self.externalDataUpdated?(transition)
                }
            }
        }
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
    
    public func activateSearch() {
        self.chatController.activateSearch(domain: .everything, query: "")
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
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        
        let fullHeight = navigationHeight + size.height
        
        let chatFrame = CGRect(origin: CGPoint(x: 0.0, y: -navigationHeight), size: CGSize(width: size.width, height: fullHeight))
        
        if !self.chatController.displayNode.bounds.isEmpty {
            if let contextController = self.chatController.visibleContextController as? ContextController {
                let deltaY = chatFrame.minY - self.chatController.displayNode.frame.minY
                contextController.addRelativeContentOffset(CGPoint(x: 0.0, y: -deltaY * 0.0), transition: transition)
            }
        }
        
        self.coveringView.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        transition.updateFrame(view: self.coveringView, frame: CGRect(origin: CGPoint(x: 0.0, y: -1.0), size: CGSize(width: size.width, height: topInset + 1.0)))
        
        let combinedBottomInset = bottomInset
        transition.updateFrame(node: self.chatController.displayNode, frame: chatFrame)
        self.chatController.updateIsScrollingLockedAtTop(isScrollingLockedAtTop: isScrollingLockedAtTop)
        self.chatController.containerLayoutUpdated(ContainerViewLayout(size: chatFrame.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(top: topInset + navigationHeight, left: sideInset, bottom: combinedBottomInset, right: sideInset), safeInsets: UIEdgeInsets(top: navigationHeight + topInset + 4.0, left: sideInset, bottom: combinedBottomInset, right: sideInset), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        return result
    }
}
