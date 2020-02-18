import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences

final class PeerInfoListPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let chatControllerInteraction: ChatControllerInteraction
    
    private let listNode: ChatHistoryListNode
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    private let selectedMessagesPromise = Promise<Set<MessageId>?>(nil)
    private var selectedMessages: Set<MessageId>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    
    private var hiddenMediaDisposable: Disposable?
    
    init(context: AccountContext, chatControllerInteraction: ChatControllerInteraction, peerId: PeerId, tagMask: MessageTags) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        
        self.selectedMessages = chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
        self.selectedMessagesPromise.set(.single(self.selectedMessages))
        
        self.listNode = ChatHistoryListNode(context: context, chatLocation: .peer(peerId), tagMask: tagMask, subject: nil, controllerInteraction: chatControllerInteraction, selectedMessages: self.selectedMessagesPromise.get(), mode: .list(search: false, reversed: false, displayHeaders: .allButLast))
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        self.ready.set(self.listNode.historyState.get()
        |> take(1)
        |> map { _ -> Bool in true })
    }
    
    deinit {
        self.hiddenMediaDisposable?.dispose()
    }
    
    func scrollToTop() -> Bool {
        let offset = self.listNode.visibleContentOffset()
        switch offset {
        case let .known(value) where value <= CGFloat.ulpOfOne:
            return false
        default:
            self.listNode.scrollToEndOfHistory()
            return true
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, isScrollingLockedAtTop, presentationData)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve))
        if isScrollingLockedAtTop {
            switch self.listNode.visibleContentOffset() {
            case .known(0.0), .none:
                break
            default:
                self.listNode.scrollToEndOfHistory()
            }
        }
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        self.listNode.messageInCurrentHistoryView(id)
    }
    
    func updateHiddenMedia() {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                itemNode.updateHiddenMedia()
            }
        }
    }
    
    func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
            self.listNode.transferVelocity(velocity)
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            }
        }
        return transitionNode
    }
    
    func addToTransitionSurface(view: UIView) {
        self.view.addSubview(view)
    }
    
    func updateSelectedMessages(animated: Bool) {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateSelectionState(animated: animated)
            }
        }
        self.selectedMessages = self.chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
    }
}
