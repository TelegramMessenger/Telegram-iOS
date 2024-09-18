import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem
import MergeLists
import ItemListUI
import ChatControllerInteraction
import MultilineTextComponent
import Markdown
import PeerInfoPaneNode
import GiftItemComponent
import PlainButtonComponent
import GiftViewScreen
import ButtonComponent

public final class PeerInfoGiftsPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let peerId: PeerId
    private let profileGifts: ProfileGiftsContext
    
    private var dataDisposable: Disposable?
    
    private let chatControllerInteraction: ChatControllerInteraction
    private let openPeerContextAction: (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void
    
    public weak var parentController: ViewController?
    
    private let backgroundNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private var theme: PresentationTheme?
    private let presentationDataPromise = Promise<PresentationData>()
    
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
            
    private var starsProducts: [ProfileGiftsContext.State.StarGift]?
    
    private var starsItems: [AnyHashable: ComponentView<Empty>] = [:]
    
    public init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction, openPeerContextAction: @escaping (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void, profileGifts: ProfileGiftsContext) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.openPeerContextAction = openPeerContextAction
        self.profileGifts = profileGifts
        
        self.backgroundNode = ASDisplayNode()
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.scrollNode)
                        
        self.dataDisposable = (profileGifts.state
        |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            guard let self else {
                return
            }
            self.statusPromise.set(.single(PeerInfoStatusData(text: "\(state.count ?? 0) gifts", isActivity: true, key: .gifts)))
            self.starsProducts = state.gifts
            
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
            
            self.updateScrolling()
        })
    }
    
    deinit {
        self.dataDisposable?.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self
    }
    
    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        self.scrollNode.view.setContentOffset(.zero, animated: true)
        return true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling()
    }
    
    func updateScrolling() {
        if let starsProducts = self.starsProducts, let params = self.currentParams {
            let optionSpacing: CGFloat = 10.0
            let sideInset = params.sideInset + 16.0
            
            let itemsInRow = min(starsProducts.count, 3)
            let optionWidth = (params.size.width - sideInset * 2.0 - optionSpacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow)
            
            let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
            
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
            
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: 60.0), size: starsOptionSize)
            for product in starsProducts {
                let itemId = AnyHashable(product.date)
                validIds.append(itemId)
                
                let itemTransition = ComponentTransition.immediate
                let visibleItem: ComponentView<Empty>
                if let current = self.starsItems[itemId] {
                    visibleItem = current
                } else {
                    visibleItem = ComponentView()
                    self.starsItems[itemId] = visibleItem
                }
                
                var isVisible = false
                if visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                
                if isVisible {
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    GiftItemComponent(
                                        context: self.context,
                                        theme: params.presentationData.theme,
                                        peer: product.fromPeer,
                                        subject: .starGift(product.gift.id, product.gift.file),
                                        price: "⭐️ \(product.gift.price)",
                                        ribbon: product.gift.availability != nil ?
                                        GiftItemComponent.Ribbon(
                                            text: "1 of 1K",
                                            color: UIColor(rgb: 0x58c1fe)
                                        )
                                        : nil
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    if let self {
                                        let controller = GiftViewScreen(
                                            context: self.context,
                                            subject: .profileGift(self.peerId, product)
                                        )
                                        self.parentController?.push(controller)
                                    }
                                },
                                animateAlpha: false
                            )
                        ),
                        environment: {},
                        containerSize: starsOptionSize
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.scrollNode.view.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                itemFrame.origin.x += itemFrame.width + optionSpacing
                if itemFrame.maxX > params.size.width {
                    itemFrame.origin.x = sideInset
                    itemFrame.origin.y += starsOptionSize.height + optionSpacing
                }
            }
            
            let contentHeight = ceil(CGFloat(starsProducts.count) / 3.0) * starsOptionSize.height + 60.0 + params.bottomInset + 16.0
            
//            //TODO:localize
//            let buttonSize = self.button.update(
//                transition: .immediate,
//                component: AnyComponent(ButtonComponent(
//                    background: ButtonComponent.Background(
//                        color: params.presentationData.theme.list.itemCheckColors.fillColor,
//                        foreground: params.presentationData.theme.list.itemCheckColors.foregroundColor,
//                        pressedColor: params.presentationData.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
//                        cornerRadius: 10.0
//                    ),
//                    content: AnyComponentWithIdentity(
//                        id: AnyHashable(0),
//                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Send Gifts to Friends", font: Font.semibold(17.0), textColor: )params.presentationData.theme.list.itemCheckColors.foregroundColor)))
//                    ),
//                    isEnabled: true,
//                    displaysProgress: false,
//                    action: {
//                        
//                    }
//                )),
//                environment: {},
//                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50)
//            )
//            if let buttonView = self.button.view {
//                if buttonView.superview == nil {
//                    self.addSubview(buttonView)
//                }
//                buttonView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - buttonSize.width) / 2.0), y: availableSize.height - environment.safeInsets.bottom - buttonSize.height), size: buttonSize)
//            }
            
//            contentHeight += 100.0
            
            
            let contentSize = CGSize(width: params.size.width, height: contentHeight)
            if self.scrollNode.view.contentSize != contentSize {
                self.scrollNode.view.contentSize = contentSize
            }
        }
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, sideInset, bottomInset, isScrollingLockedAtTop, presentationData)
        self.presentationDataPromise.set(.single(presentationData))
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))

        if isScrollingLockedAtTop {
            self.scrollNode.view.contentOffset = .zero
        }
        self.scrollNode.view.isScrollEnabled = !isScrollingLockedAtTop
        
        self.updateScrolling()
    }
    
    public func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    public func updateHiddenMedia() {
    }
    
    public func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
//            self.scrollNode.transferVelocity(velocity)
        }
    }
    
    public func cancelPreviewGestures() {
    }
    
    public func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    public func addToTransitionSurface(view: UIView) {
    }
    
    public func updateSelectedMessages(animated: Bool) {
    }
}

private struct StarsGiftProduct: Equatable {
    let emoji: String
    let price: Int64
    let isLimited: Bool
}
