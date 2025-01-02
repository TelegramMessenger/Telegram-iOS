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
import BalancedTextComponent
import Markdown
import PeerInfoPaneNode
import GiftItemComponent
import PlainButtonComponent
import GiftViewScreen
import SolidRoundedButtonNode

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
    
    private var unlockBackground: NavigationBackgroundNode?
    private var unlockSeparator: ASDisplayNode?
    private var unlockText: ComponentView<Empty>?
    private var unlockButton: SolidRoundedButtonNode?
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
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
            let isFirstTime = starsProducts == nil
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.statusPromise.set(.single(PeerInfoStatusData(text: presentationData.strings.SharedMedia_GiftCount(state.count ?? 0), isActivity: true, key: .gifts)))
            self.starsProducts = state.gifts
            
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
            
            self.updateScrolling(transition: isFirstTime ? .immediate : .easeInOut(duration: 0.25))
        })
    }
    
    deinit {
        self.dataDisposable?.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        self.scrollNode.view.delegate = self
    }
    
    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        self.scrollNode.view.setContentOffset(.zero, animated: true)
        return true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling(transition: .immediate)
    }
    
    func updateScrolling(transition: ComponentTransition) {
        if let starsProducts = self.starsProducts, let params = self.currentParams {
            let optionSpacing: CGFloat = 10.0
            let sideInset = params.sideInset + 16.0
            
            let itemsInRow = max(1, min(starsProducts.count, 3))
            let optionWidth = (params.size.width - sideInset * 2.0 - optionSpacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow)
            
            let starsOptionSize = CGSize(width: optionWidth, height: optionWidth)
            
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
            
            let topInset: CGFloat = 60.0
            
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: starsOptionSize)
            
            var index: Int32 = 0
            for product in starsProducts {
                var isVisible = false
                if visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                
                if isVisible {
                    let info: String
                    switch product.gift {
                    case let .generic(gift):
                        info = "g_\(gift.id)"
                    case let .unique(gift):
                        info = "u_\(gift.id)"
                    }
                    let id = "\(index)_\(info)"
                    let itemId = AnyHashable(id)
                    validIds.append(itemId)
                    
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.starsItems[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        self.starsItems[itemId] = visibleItem
                        itemTransition = .immediate
                    }
                    
                    let ribbonText: String?
                    var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
                    switch product.gift {
                    case let .generic(gift):
                        if let availability = gift.availability {
                            ribbonText = params.presentationData.strings.PeerInfo_Gifts_OneOf(compactNumericCountString(Int(availability.total))).string
                        } else {
                            ribbonText = nil
                        }
                    case let .unique(gift):
                        ribbonText = params.presentationData.strings.PeerInfo_Gifts_OneOf(compactNumericCountString(Int(gift.availability.total))).string
                        for attribute in gift.attributes {
                            if case let .backdrop(_, innerColor, outerColor, _, _, _) = attribute {
                                ribbonColor = .custom(outerColor, innerColor)
                                break
                            }
                        }
                    }
                    
                    let peer: GiftItemComponent.Peer?
                    let subject: GiftItemComponent.Subject
                    switch product.gift {
                    case let .generic(gift):
                        subject = .starGift(gift: gift, price: "⭐️ \(gift.price)")
                        peer = product.fromPeer.flatMap { .peer($0) } ?? .anonymous
                    case let .unique(gift):
                        subject = .uniqueGift(gift: gift)
                        peer = nil
                    }
                    
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    GiftItemComponent(
                                        context: self.context,
                                        theme: params.presentationData.theme,
                                        peer: peer,
                                        subject: subject,
                                        ribbon: ribbonText.flatMap { GiftItemComponent.Ribbon(text: $0, color: ribbonColor) },
                                        isHidden: !product.savedToProfile,
                                        mode: .profile
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    let controller = GiftViewScreen(
                                        context: self.context,
                                        subject: .profileGift(self.peerId, product),
                                        updateSavedToProfile: { [weak self] messageId, added in
                                            guard let self else {
                                                return
                                            }
                                            self.profileGifts.updateStarGiftAddedToProfile(messageId: messageId, added: added)
                                        },
                                        convertToStars: { [weak self] in
                                            guard let self, let messageId = product.messageId else {
                                                return
                                            }
                                            self.profileGifts.convertStarGift(messageId: messageId)
                                        },
                                        transferGift: { [weak self] prepaid, peerId in
                                            guard let self, let messageId = product.messageId else {
                                                return
                                            }
                                            self.profileGifts.transferStarGift(prepaid: prepaid, messageId: messageId, peerId: peerId)
                                        },
                                        upgradeGift: { [weak self] formId, keepOriginalInfo in
                                            guard let self, let messageId = product.messageId else {
                                                return .never()
                                            }
                                            return self.profileGifts.upgradeStarGift(formId: formId, messageId: messageId, keepOriginalInfo: keepOriginalInfo)
                                        }
                                    )
                                    self.parentController?.push(controller)
                                    
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
                index += 1
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.starsItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeIds {
                self.starsItems.removeValue(forKey: id)
            }
            
            var bottomScrollInset: CGFloat = 0.0
            var contentHeight = ceil(CGFloat(starsProducts.count) / 3.0) * (starsOptionSize.height + optionSpacing) - optionSpacing + topInset + 16.0
            if self.peerId == self.context.account.peerId {
                let transition = ComponentTransition.immediate
                
                let size = params.size
                let sideInset = params.sideInset
                let bottomInset = params.bottomInset
                let presentationData = params.presentationData
              
                let themeUpdated = self.theme !== presentationData.theme
                self.theme = presentationData.theme
                
                let unlockText: ComponentView<Empty>
                let unlockBackground: NavigationBackgroundNode
                let unlockSeparator: ASDisplayNode
                let unlockButton: SolidRoundedButtonNode
                if let current = self.unlockText {
                    unlockText = current
                } else {
                    unlockText = ComponentView<Empty>()
                    self.unlockText = unlockText
                }
                
                if let current = self.unlockBackground {
                    unlockBackground = current
                } else {
                    unlockBackground = NavigationBackgroundNode(color: presentationData.theme.rootController.tabBar.backgroundColor)
                    self.addSubnode(unlockBackground)
                    self.unlockBackground = unlockBackground
                }
                
                if let current = self.unlockSeparator {
                    unlockSeparator = current
                } else {
                    unlockSeparator = ASDisplayNode()
                    self.addSubnode(unlockSeparator)
                    self.unlockSeparator = unlockSeparator
                }
                                        
                if let current = self.unlockButton {
                    unlockButton = current
                } else {
                    unlockButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: presentationData.theme), height: 50.0, cornerRadius: 10.0)
                    self.view.addSubview(unlockButton.view)
                    self.unlockButton = unlockButton
                
                    unlockButton.title = params.presentationData.strings.PeerInfo_Gifts_Send
                    
                    unlockButton.pressed = { [weak self] in
                        self?.buttonPressed()
                    }
                }
            
                if themeUpdated {
                    unlockBackground.updateColor(color: presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
                    unlockSeparator.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
                    unlockButton.updateTheme(SolidRoundedButtonTheme(theme: presentationData.theme))
                }
                
                let textFont = Font.regular(13.0)
                let boldTextFont = Font.semibold(13.0)
                let textColor = presentationData.theme.list.itemSecondaryTextColor
                let linkColor = presentationData.theme.list.itemAccentColor
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor), linkAttribute: { _ in
                    return nil
                })
                
                var scrollOffset: CGFloat = max(0.0, size.height - params.visibleHeight)
                
                let buttonSideInset = sideInset + 16.0
                let buttonSize = CGSize(width: size.width - buttonSideInset * 2.0, height: 50.0)
                let bottomPanelHeight = bottomInset + buttonSize.height + 8.0
                if params.visibleHeight < 110.0 {
                    scrollOffset -= bottomPanelHeight
                }
                
                transition.setFrame(view: unlockButton.view, frame: CGRect(origin: CGPoint(x: buttonSideInset, y: size.height - bottomInset - buttonSize.height - scrollOffset), size: buttonSize))
                let _ = unlockButton.updateLayout(width: buttonSize.width, transition: .immediate)
                
                transition.setFrame(view: unlockBackground.view, frame: CGRect(x: 0.0, y: size.height - bottomInset - buttonSize.height - 8.0 - scrollOffset, width: size.width, height: bottomPanelHeight))
                unlockBackground.update(size: CGSize(width: size.width, height: bottomPanelHeight), transition: transition.containedViewLayoutTransition)
                transition.setFrame(view: unlockSeparator.view, frame: CGRect(x: 0.0, y: size.height - bottomInset - buttonSize.height - 8.0 - scrollOffset, width: size.width, height: UIScreenPixel))
                
                let unlockSize = unlockText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        BalancedTextComponent(
                            text: .markdown(text: params.presentationData.strings.PeerInfo_Gifts_Info, attributes: markdownAttributes),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: size.width - 32.0, height: 200.0)
                )
                if let view = unlockText.view {
                    if view.superview == nil {
                        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.buttonPressed)))
                        self.scrollNode.view.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((size.width - unlockSize.width) / 2.0), y: contentHeight), size: unlockSize))
                }
                contentHeight += unlockSize.height
                contentHeight += bottomPanelHeight
                
                bottomScrollInset = bottomPanelHeight - 40.0
            }
            contentHeight += params.bottomInset
            
            self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 50.0, left: 0.0, bottom: bottomScrollInset, right: 0.0)
            
            let contentSize = CGSize(width: params.size.width, height: contentHeight)
            if self.scrollNode.view.contentSize != contentSize {
                self.scrollNode.view.contentSize = contentSize
            }
        }
        
        let bottomContentOffset = max(0.0, self.scrollNode.view.contentSize.height - self.scrollNode.view.contentOffset.y - self.scrollNode.view.frame.height)
        if bottomContentOffset < 200.0 {
            self.profileGifts.loadMore()
        }
    }
        
    @objc private func buttonPressed() {
        let _ = (self.context.account.stateManager.contactBirthdays
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] birthdays in
            guard let self else {
                return
            }
            let controller = self.context.sharedContext.makePremiumGiftController(context: self.context, source: .settings(birthdays), completion: nil)
            controller.navigationPresentation = .modal
            self.chatControllerInteraction.navigationController()?.pushViewController(controller)
        })
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, presentationData)
        self.presentationDataPromise.set(.single(presentationData))
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))

        if isScrollingLockedAtTop {
            self.scrollNode.view.contentOffset = .zero
        }
        self.scrollNode.view.isScrollEnabled = !isScrollingLockedAtTop
        
        self.updateScrolling(transition: ComponentTransition(transition))
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
