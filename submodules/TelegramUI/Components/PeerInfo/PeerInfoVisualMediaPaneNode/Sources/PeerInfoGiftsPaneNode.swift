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
import TelegramStringFormatting
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
import UndoUI
import CheckComponent
import LottieComponent

public final class PeerInfoGiftsPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let peerId: PeerId
    private let profileGifts: ProfileGiftsContext
    private let canManage: Bool
    
    private var dataDisposable: Disposable?
    
    private let chatControllerInteraction: ChatControllerInteraction
    private let openPeerContextAction: (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void
    
    public weak var parentController: ViewController?
    
    private let backgroundNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    
    private var footerText: ComponentView<Empty>?
    private var panelBackground: NavigationBackgroundNode?
    private var panelSeparator: ASDisplayNode?
    private var panelButton: SolidRoundedButtonNode?
    private var panelCheck: ComponentView<Empty>?
    
    private let emptyResultsClippingView = UIView()
    private let emptyResultsAnimation = ComponentView<Empty>()
    private let emptyResultsTitle = ComponentView<Empty>()
    private let emptyResultsAction = ComponentView<Empty>()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
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
    private var resultsAreFiltered = false
    private var resultsAreEmpty = false
    
    public init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction, openPeerContextAction: @escaping (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void, profileGifts: ProfileGiftsContext, canManage: Bool) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.openPeerContextAction = openPeerContextAction
        self.profileGifts = profileGifts
        self.canManage = canManage
        
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
            self.starsProducts = state.filteredGifts
            
            self.resultsAreFiltered = state.filter != .All
            self.resultsAreEmpty = state.filter != .All && state.filteredGifts.isEmpty
        
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
        
        self.emptyResultsClippingView.clipsToBounds = true
        self.scrollNode.view.addSubview(self.emptyResultsClippingView)
    }
    
    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        self.scrollNode.view.setContentOffset(.zero, animated: true)
        return true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling(interactive: true, transition: .immediate)
    }
    
    private var notify = false
    func updateScrolling(interactive: Bool = false, transition: ComponentTransition) {
        if let starsProducts = self.starsProducts, let params = self.currentParams {
            let optionSpacing: CGFloat = 10.0
            let itemsSideInset = params.sideInset + 16.0
            
            let defaultItemsInRow = params.size.width > params.size.height ? 5 : 3
            let itemsInRow = max(1, min(starsProducts.count, defaultItemsInRow))
            let defaultOptionWidth = (params.size.width - itemsSideInset * 2.0 - optionSpacing * CGFloat(defaultItemsInRow - 1)) / CGFloat(defaultItemsInRow)
            let optionWidth = (params.size.width - itemsSideInset * 2.0 - optionSpacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow)
            
            let starsOptionSize = CGSize(width: optionWidth, height: defaultOptionWidth)
            
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
            
            let topInset: CGFloat = 60.0
            
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: itemsSideInset, y: topInset), size: starsOptionSize)
            
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
                            ribbonText = params.presentationData.strings.PeerInfo_Gifts_OneOf(compactNumericCountString(Int(availability.total), decimalSeparator: params.presentationData.dateTimeFormat.decimalSeparator)).string
                        } else {
                            ribbonText = nil
                        }
                    case let .unique(gift):
                        ribbonText = params.presentationData.strings.PeerInfo_Gifts_OneOf(compactNumericCountString(Int(gift.availability.issued), decimalSeparator: params.presentationData.dateTimeFormat.decimalSeparator)).string
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
                                        updateSavedToProfile: { [weak self] reference, added in
                                            guard let self else {
                                                return
                                            }
                                            self.profileGifts.updateStarGiftAddedToProfile(reference: reference, added: added)
                                        },
                                        convertToStars: { [weak self] in
                                            guard let self, let reference = product.reference else {
                                                return
                                            }
                                            self.profileGifts.convertStarGift(reference: reference)
                                        },
                                        transferGift: { [weak self] prepaid, peerId in
                                            guard let self, let reference = product.reference else {
                                                return
                                            }
                                            self.profileGifts.transferStarGift(prepaid: prepaid, reference: reference, peerId: peerId)
                                        },
                                        upgradeGift: { [weak self] formId, keepOriginalInfo in
                                            guard let self, let reference = product.reference else {
                                                return .never()
                                            }
                                            return self.profileGifts.upgradeStarGift(formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
                                        },
                                        shareStory: { [weak self] uniqueGift in
                                            guard let self, let parentController = self.parentController else {
                                                return
                                            }
                                            Queue.mainQueue().after(0.15) {
                                                let controller = self.context.sharedContext.makeStorySharingScreen(context: self.context, subject: .gift(uniqueGift), parentController: parentController)
                                                parentController.push(controller)
                                            }
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
                            
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                itemFrame.origin.x += itemFrame.width + optionSpacing
                if itemFrame.maxX > params.size.width {
                    itemFrame.origin.x = itemsSideInset
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
            
            let transition = ComponentTransition.immediate
            
            let size = params.size
            let sideInset = params.sideInset
            let bottomInset = params.bottomInset
            let presentationData = params.presentationData
          
            let themeUpdated = self.theme !== presentationData.theme
            self.theme = presentationData.theme
            
            let panelBackground: NavigationBackgroundNode
            let panelSeparator: ASDisplayNode
            let panelButton: SolidRoundedButtonNode
            
            let panelAlpha = params.expandProgress
            
            if let current = self.panelBackground {
                panelBackground = current
            } else {
                panelBackground = NavigationBackgroundNode(color: presentationData.theme.rootController.tabBar.backgroundColor)
                self.addSubnode(panelBackground)
                self.panelBackground = panelBackground
            }
            
            if let current = self.panelSeparator {
                panelSeparator = current
            } else {
                panelSeparator = ASDisplayNode()
                self.addSubnode(panelSeparator)
                self.panelSeparator = panelSeparator
            }
                                    
            if let current = self.panelButton {
                panelButton = current
            } else {
                panelButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: presentationData.theme), height: 50.0, cornerRadius: 10.0)
                self.view.addSubview(panelButton.view)
                self.panelButton = panelButton
            
                panelButton.title = self.peerId == self.context.account.peerId ? params.presentationData.strings.PeerInfo_Gifts_Send : params.presentationData.strings.PeerInfo_Gifts_SendGift
                
                panelButton.pressed = { [weak self] in
                    self?.buttonPressed()
                }
            }
        
            if themeUpdated {
                panelBackground.updateColor(color: presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
                panelSeparator.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
                panelButton.updateTheme(SolidRoundedButtonTheme(theme: presentationData.theme))
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
            var bottomPanelHeight = bottomInset + buttonSize.height + 8.0
            if params.visibleHeight < 110.0 {
                scrollOffset -= bottomPanelHeight
            }
            
            transition.setFrame(view: panelButton.view, frame: CGRect(origin: CGPoint(x: buttonSideInset, y: size.height - bottomInset - buttonSize.height - scrollOffset), size: buttonSize))
            transition.setAlpha(view: panelButton.view, alpha: panelAlpha)
            let _ = panelButton.updateLayout(width: buttonSize.width, transition: .immediate)
            
            if self.canManage {
                bottomPanelHeight -= 9.0
                
                let panelCheck: ComponentView<Empty>
                if let current = self.panelCheck {
                    panelCheck = current
                } else {
                    panelCheck = ComponentView<Empty>()
                    self.panelCheck = panelCheck
                }
                let checkTheme = CheckComponent.Theme(
                    backgroundColor: presentationData.theme.list.itemCheckColors.fillColor,
                    strokeColor: presentationData.theme.list.itemCheckColors.foregroundColor,
                    borderColor: presentationData.theme.list.itemCheckColors.strokeColor,
                    overlayBorder: false,
                    hasInset: false,
                    hasShadow: false
                )
                
                let panelCheckSize = panelCheck.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                    theme: checkTheme,
                                    size: CGSize(width: 22.0, height: 22.0),
                                    selected: self.profileGifts.currentState?.notificationsEnabled ?? false
                                ))),
                                AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_ChannelNotify, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor))
                                )))
                            ],
                            spacing: 16.0
                            )),
                            effectAlignment: .center,
                            action: { [weak self] in
                                guard let self, let currentState = self.profileGifts.currentState else {
                                    return
                                }
                                let enabled = !(currentState.notificationsEnabled ?? false)
                                self.profileGifts.toggleStarGiftsNotifications(enabled: enabled)
                                
                                let animation = enabled ? "anim_profileunmute" : "anim_profilemute"
                                let text = enabled ? presentationData.strings.PeerInfo_Gifts_ChannelNotifyTooltip : presentationData.strings.PeerInfo_Gifts_ChannelNotifyDisabledTooltip
                                
                                let controller = UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .universal(animation: animation, scale: 0.075, colors: ["__allcolors__": UIColor.white], title: nil, text: text, customUndoText: nil, timeout: nil),
                                    appearance: UndoOverlayController.Appearance(bottomInset: 53.0),
                                    action: { _ in return true }
                                )
                                self.chatControllerInteraction.presentController(controller, nil)
                              
                                self.updateScrolling(transition: .immediate)
                            },
                            animateAlpha: false,
                            animateScale: false
                        )
                    ),
                    environment: {},
                    containerSize: buttonSize
                )
                if let panelCheckView = panelCheck.view {
                    if panelCheckView.superview == nil {
                        self.view.addSubview(panelCheckView)
                    }
                    panelCheckView.frame = CGRect(origin: CGPoint(x: floor((size.width - panelCheckSize.width) / 2.0), y: size.height - bottomInset - panelCheckSize.height - 11.0 - scrollOffset), size: panelCheckSize)
                    transition.setAlpha(view: panelCheckView, alpha: panelAlpha)
                }
                panelButton.isHidden = true
            }
            
            transition.setFrame(view: panelBackground.view, frame: CGRect(x: 0.0, y: size.height - bottomPanelHeight - scrollOffset, width: size.width, height: bottomPanelHeight))
            transition.setAlpha(view: panelBackground.view, alpha: panelAlpha)
            panelBackground.update(size: CGSize(width: size.width, height: bottomPanelHeight), transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: panelSeparator.view, frame: CGRect(x: 0.0, y: size.height - bottomPanelHeight - scrollOffset, width: size.width, height: UIScreenPixel))
            transition.setAlpha(view: panelSeparator.view, alpha: panelAlpha)
            
            let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            if self.resultsAreEmpty {
                let sideInset: CGFloat = 44.0
                let emptyAnimationHeight = 148.0
                let topInset: CGFloat = 0.0
                let bottomInset: CGFloat = bottomPanelHeight
                let visibleHeight = params.visibleHeight
                let emptyAnimationSpacing: CGFloat = 20.0
                let emptyTextSpacing: CGFloat = 18.0
                
                self.emptyResultsClippingView.isHidden = false
                                
                transition.setFrame(view: self.emptyResultsClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: self.scrollNode.frame.size))
                transition.setBounds(view: self.emptyResultsClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: self.scrollNode.frame.size))
                
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_NoResults, font: Font.semibold(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: params.size
                )
                let emptyResultsActionSize = self.emptyResultsAction.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(
                                MultilineTextComponent(
                                    text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_NoResults_ViewAll, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)),
                                    horizontalAlignment: .center,
                                    maximumNumberOfLines: 0
                                )
                            ),
                            effectAlignment: .center,
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.profileGifts.updateFilter(.All)
                            },
                            animateScale: false
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: params.size.width - sideInset * 2.0, height: visibleHeight)
                )
                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                    )),
                    environment: {},
                    containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
                )
      
                let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyResultsTitleSize.height + emptyResultsActionSize.height + emptyTextSpacing
                let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
                
                let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
                
                let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsTitleSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyAnimationSpacing), size: emptyResultsTitleSize)
                
                let emptyResultsActionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsActionSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsActionSize)
                
                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.emptyResultsClippingView.addSubview(view)
                        view.playOnce()
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    transition.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.emptyResultsClippingView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
                if let view = self.emptyResultsAction.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.emptyResultsClippingView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsActionFrame.size)
                    transition.setPosition(view: view, position: emptyResultsActionFrame.center)
                }
            } else {
                if let view = self.emptyResultsAnimation.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        self.emptyResultsClippingView.isHidden = true
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsAction.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
            
            if self.peerId == self.context.account.peerId {
                let footerText: ComponentView<Empty>
                if let current = self.footerText {
                    footerText = current
                } else {
                    footerText = ComponentView<Empty>()
                    self.footerText = footerText
                }
                let footerTextSize = footerText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        BalancedTextComponent(
                            text: .markdown(text: presentationData.strings.PeerInfo_Gifts_Info, attributes: markdownAttributes),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: size.width - 32.0, height: 200.0)
                )
                if let view = footerText.view {
                    if view.superview == nil {
                        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.buttonPressed)))
                        self.scrollNode.view.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((size.width - footerTextSize.width) / 2.0), y: contentHeight), size: footerTextSize))
                }
                contentHeight += footerTextSize.height
            }
            contentHeight += bottomPanelHeight
            
            bottomScrollInset = bottomPanelHeight - 40.0
            
            contentHeight += params.bottomInset
            
            self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 50.0, left: 0.0, bottom: bottomScrollInset, right: 0.0)
            
            let contentSize = CGSize(width: params.size.width, height: contentHeight)
            if self.scrollNode.view.contentSize != contentSize {
                self.scrollNode.view.contentSize = contentSize
            }
        }
        
        let bottomContentOffset = max(0.0, self.scrollNode.view.contentSize.height - self.scrollNode.view.contentOffset.y - self.scrollNode.view.frame.height)
        if interactive, bottomContentOffset < 200.0 {
            self.profileGifts.loadMore()
        }
    }
        
    @objc private func buttonPressed() {
        if self.peerId == self.context.account.peerId {
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
        } else {
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Birthday(id: self.peerId))
            |> deliverOnMainQueue).start(next: { birthday in
                var hasBirthday = false
                if let birthday {
                    hasBirthday = hasBirthdayToday(birthday: birthday)
                }
                let controller = self.context.sharedContext.makeGiftOptionsController(
                    context: self.context,
                    peerId: self.peerId,
                    premiumOptions: [],
                    hasBirthday: hasBirthday,
                    completion: nil
                )
                self.chatControllerInteraction.navigationController()?.pushViewController(controller)
            })
        }
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
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
