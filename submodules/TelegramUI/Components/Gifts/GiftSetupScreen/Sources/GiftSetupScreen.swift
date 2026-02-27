import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BalancedTextComponent
import ListSectionComponent
import ListActionItemComponent
import ListItemComponentAdaptor
import BundleIconComponent
import LottieComponent
import TextFieldComponent
import ButtonComponent
import BotPaymentsUI
import ChatEntityKeyboardInputNode
import EmojiSuggestionsComponent
import ChatPresentationInterfaceState
import AudioToolbox
import TextFormat
import InAppPurchaseManager
import BlurredBackgroundComponent
import ProgressNavigationButtonNode
import Markdown
import UndoUI
import ConfettiEffect
import EdgeEffect
import AnimatedTextComponent
import GlassBarButtonComponent
import MessageInputPanelComponent
import GiftRemainingCountComponent
import GlassBackgroundComponent

private final class GiftSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let subject: GiftSetupScreen.Subject
    let auctionAcquiredGifts: Signal<[GiftAuctionAcquiredGift], NoError>?
    let completion: (() -> Void)?
    
    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        subject: GiftSetupScreen.Subject,
        auctionAcquiredGifts: Signal<[GiftAuctionAcquiredGift], NoError>?,
        completion: (() -> Void)? = nil
    ) {
        self.context = context
        self.peerId = peerId
        self.subject = subject
        self.auctionAcquiredGifts = auctionAcquiredGifts
        self.completion = completion
    }
    
    static func ==(lhs: GiftSetupScreenComponent, rhs: GiftSetupScreenComponent) -> Bool {
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var containerCornerRadius: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let bottomEdgeEffectView: EdgeEffectView
                
        private let backgroundHandleView: UIImageView
        
        private let closeButton = ComponentView<Empty>()
        
        private let remainingCount = ComponentView<Empty>()
        private let auctionFooter = ComponentView<Empty>()
        private let resaleSection = ComponentView<Empty>()
        private let introContent = ComponentView<Empty>()
        private let introSection = ComponentView<Empty>()
        private let starsSection = ComponentView<Empty>()
        private let upgradeSection = ComponentView<Empty>()
        private let hideSection = ComponentView<Empty>()
        
        private let glassContainerView = GlassBackgroundContainerView()
        private let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        private let actionButton = ComponentView<Empty>()
        
        private var ignoreScrolling: Bool = false
        
        private var component: GiftSetupScreenComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var currentInputMode: MessageInputPanelComponent.InputMode = .text
        
        private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
        private var inputMediaNodeDataDisposable: Disposable?
        private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
        private var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
        private var inputMediaNode: ChatEntityKeyboardInputNode?
        private var inputMediaNodeBackground = SimpleLayer()
        private var inputMediaNodeTargetTag: AnyObject?
        private let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        private var previousInputHeight: CGFloat?
        
        private var currentEmojiSuggestionView: ComponentHostView<Empty>?
        
        private var hideName = false
        private var includeUpgrade = false
        private var payWithStars = false
        
        private var inProgress = false
                        
        private var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        private var sendPaidMessageStars: StarsAmount?
                
        private var giftAuction: GiftAuctionContext?
        private var giftAuctionState: GiftAuctionContext.State?
        private var giftAuctionDisposable: Disposable?
        private var giftAuctionTimer: SwiftSignalKit.Timer?

        private var cachedStarImage: (UIImage, PresentationTheme)?
        
        private var updateDisposable: Disposable?
        
        private var optionsDisposable: Disposable?
        private(set) var options: [StarsTopUpOption] = [] {
            didSet {
                self.optionsPromise.set(self.options)
            }
        }
        private let optionsPromise = ValuePromise<[StarsTopUpOption]?>(nil)
        private let previewPromise = Promise<StarGiftUpgradePreview?>(nil)
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = UIView()
            
            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 38.0
            self.containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 38.0
            
            self.backgroundHandleView = UIImageView()
            
            self.navigationBarContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.bottomEdgeEffectView = EdgeEffectView()
                        
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.layer.addSublayer(self.backgroundLayer)
                        
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.containerView.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.containerView.addSubview(self.navigationBarContainer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.inputMediaNodeDataDisposable?.dispose()
            self.updateDisposable?.dispose()
            self.optionsDisposable?.dispose()
            self.giftAuctionDisposable?.dispose()
            self.giftAuctionTimer?.invalidate()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
                
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let minScale: CGFloat = (itemLayout.containerSize.width - 6.0 * 2.0) / itemLayout.containerSize.width
            let minScaledTranslation: CGFloat = (itemLayout.containerSize.height - itemLayout.containerSize.height * minScale) * 0.5 - 6.0
            let minScaledCornerRadius: CGFloat = itemLayout.containerCornerRadius
            
            let scale = minScale * (1.0 - topOffsetFraction) + 1.0 * topOffsetFraction
            let scaledTranslation = minScaledTranslation * (1.0 - topOffsetFraction)
            let scaledCornerRadius = minScaledCornerRadius * (1.0 - topOffsetFraction) + itemLayout.containerCornerRadius * topOffsetFraction
            
            var containerTransform = CATransform3DIdentity
            containerTransform = CATransform3DTranslate(containerTransform, 0.0, scaledTranslation, 0.0)
            containerTransform = CATransform3DScale(containerTransform, scale, scale, scale)
            transition.setTransform(view: self.containerView, transform: containerTransform)
            transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: scaledCornerRadius)
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            self.bottomEdgeEffectView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
            self.bottomEdgeEffectView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
        }
        
        @objc private func proceed() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
                        
            switch component.subject {
            case let .premium(product):
                if self.payWithStars, let starsPrice = product.starsPrice, let peer = self.peerMap[component.peerId] {
                    if let balance = component.context.starsContext?.currentState?.balance, balance.value < starsPrice {
                        self.proceedWithStarGift()
                    } else {
                        let controller = textAlertController(
                            context: component.context,
                            title: environment.strings.Gift_Send_Premium_Confirmation_Title,
                            text: environment.strings.Gift_Send_Premium_Confirmation_Text(
                                peer.compactDisplayTitle,
                                environment.strings.Gift_Send_Premium_Confirmation_Text_Stars(Int32(clamping: starsPrice))
                            ).string,
                            actions: [
                                TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                                TextAlertAction(type: .defaultAction, title: environment.strings.Gift_Send_Premium_Confirmation_Confirm, action: { [weak self] in
                                    if let self {
                                        self.proceedWithStarGift()
                                    }
                                })
                            ],
                            parseMarkdown: true
                        )
                        environment.controller()?.present(controller, in: .window(.root))
                    }
                } else {
                    self.proceedWithPremiumGift()
                }
            case .starGift:
                self.proceedWithStarGift()
            }
        }
        
        private func proceedWithPremiumGift() {
            guard let component = self.component, case let .premium(product) = component.subject, let storeProduct = product.storeProduct, let inAppPurchaseManager = component.context.inAppPurchaseManager else {
                return
            }
            
            self.inProgress = true
            self.state?.updated()

            let (currency, amount) = storeProduct.priceCurrencyAndAmount
                     
            addAppLogEvent(postbox: component.context.account.postbox, type: "premium_gift.promo_screen_accept")

            var textInputText = NSAttributedString()
            if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, case let .text(text) = inputPanelView.getSendMessageInput() {
                textInputText = text
            }
            let entities = generateChatInputTextEntities(textInputText)
            let purpose: AppStoreTransactionPurpose = .giftCode(peerIds: [component.peerId], boostPeer: nil, currency: currency, amount: amount, text: textInputText.string, entities: entities)
            let quantity: Int32 = 1
                        
            let completion = component.completion
            
            let _ = (component.context.engine.payments.canPurchasePremium(purpose: purpose)
            |> deliverOnMainQueue).start(next: { [weak self] available in
                guard let self else {
                    return
                }
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                if available {
                    let _ = (inAppPurchaseManager.buyProduct(storeProduct, quantity: quantity, purpose: purpose)
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        if let completion {
                            completion()
                            
                            if let self, let controller = self.environment?.controller() {
                                controller.dismiss()
                            }
                        } else {
                            guard let self, case .purchased = status, let controller = self.environment?.controller(), let navigationController = controller.navigationController as? NavigationController else {
                                return
                            }
                            
                            var controllers = navigationController.viewControllers
                            controllers = controllers.filter { !($0 is GiftSetupScreen) && !($0 is GiftOptionsScreenProtocol) && !($0 is PeerInfoScreen) && !($0 is ContactSelectionController) }
                            var foundController = false
                            for controller in controllers.reversed() {
                                if let chatController = controller as? ChatController, case .peer(id: component.peerId) = chatController.chatLocation {
                                    chatController.hintPlayNextOutgoingGift()
                                    foundController = true
                                    break
                                }
                            }
                            if !foundController {
                                let chatController = component.context.sharedContext.makeChatController(context: component.context, chatLocation: .peer(id: component.peerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                                chatController.hintPlayNextOutgoingGift()
                                controllers.append(chatController)
                            }
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }, error: { [weak self] error in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        self.state?.updated(transition: .immediate)

                        var errorText: String?
                        switch error {
                            case .generic:
                                errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                            case .network:
                                errorText = presentationData.strings.Premium_Purchase_ErrorNetwork
                            case .notAllowed:
                                errorText = presentationData.strings.Premium_Purchase_ErrorNotAllowed
                            case .cantMakePayments:
                                errorText = presentationData.strings.Premium_Purchase_ErrorCantMakePayments
                            case .assignFailed:
                                errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                            case .tryLater:
                                errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                            case .cancelled:
                                break
                        }
                        
                        if let errorText {
                            addAppLogEvent(postbox: component.context.account.postbox, type: "premium_gift.promo_screen_fail")
                            
                            let alertController = textAlertController(context: component.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                            controller.present(alertController, in: .window(.root))
                        }
                    })
                } else {
                    self.inProgress = false
                    self.state?.updated(transition: .immediate)
                }
            })
        }
        
        private func proceedWithStarGift() {
            guard let component = self.component, let environment = self.environment, let starsContext = component.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
            
            let context = component.context
            let peerId = component.peerId
            
            var textInputText = NSAttributedString()
            if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, case let .text(text) = inputPanelView.getSendMessageInput() {
                textInputText = text
            }
            let entities = generateChatInputTextEntities(textInputText)
            
            if case let .starGift(gift, _) = component.subject, gift.flags.contains(.isAuction), let navigationController = environment.controller()?.navigationController as? NavigationController, let auctionContext = self.giftAuction {
                let controller = context.sharedContext.makeGiftAuctionBidScreen(
                    context: context,
                    toPeerId: peerId,
                    text: textInputText.string,
                    entities: entities,
                    hideName: self.hideName,
                    auctionContext: auctionContext,
                    acquiredGifts: component.auctionAcquiredGifts
                )
                environment.controller()?.dismiss()
                navigationController.pushViewController(controller)
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    
            var finalPrice: Int64
            var perUserLimit: Int32?
            var giftFile: TelegramMediaFile?
            let source: BotPaymentInvoiceSource
            switch component.subject {
            case let .premium(product):
                if let option = product.starsGiftOption {
                    finalPrice = option.amount
                    source = .premiumGift(peerId: peerId, option: option, text: textInputText.string, entities: entities)
                } else {
                    fatalError()
                }
            case let .starGift(starGift, _):
                finalPrice = starGift.price
                if self.includeUpgrade, let upgradeStars = starGift.upgradeStars  {
                    finalPrice += upgradeStars
                }
                perUserLimit = starGift.perUserLimit?.total
                giftFile = starGift.file
                source = .starGift(hideName: self.hideName, includeUpgrade: self.includeUpgrade, peerId: peerId, giftId: starGift.id, text: textInputText.string, entities: entities)
            }
            
            let proceed = { [weak self] in
                guard let self else {
                    return
                }
                
                self.inProgress = true
                self.state?.updated()
                
                let completion = component.completion
                
                let signal = BotCheckoutController.InputData.fetch(context: component.context, source: source)
                |> `catch` { error -> Signal<BotCheckoutController.InputData, SendBotPaymentFormError> in
                    switch error {
                    case .disallowedStarGifts:
                        return .fail(.disallowedStarGift)
                    case .starGiftsUserLimit:
                        return .fail(.starGiftUserLimit)
                    default:
                        return .fail(.generic)
                    }
                }
                |> mapToSignal { inputData -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
                    return component.context.engine.payments.sendStarsPaymentForm(formId: inputData.form.id, source: source)
                }
                |> deliverOnMainQueue
                                
                let _ = signal.start(next: { [weak self] result in
                    guard let self, let controller = self.environment?.controller(), let navigationController = controller.navigationController as? NavigationController else {
                        return
                    }

                    if peerId.namespace == Namespaces.Peer.CloudChannel, case let .starGift(starGift, _) = component.subject {
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { !($0 is GiftSetupScreen) && !($0 is GiftOptionsScreenProtocol) }
                        navigationController.setViewControllers(controllers, animated: true)
                        
                        let tooltipController = UndoOverlayController(
                            presentationData: presentationData,
                            content: .sticker(
                                context: context,
                                file: starGift.file,
                                loop: true,
                                title: nil,
                                text: presentationData.strings.Gift_Send_Success(self.peerMap[peerId]?.compactDisplayTitle ?? "", presentationData.strings.Gift_Send_Success_Stars(Int32(clamping: starGift.price))).string,
                                undoText: nil,
                                customAction: nil
                            ),
                            action: { _ in return true }
                        )
                        (navigationController.viewControllers.last as? ViewController)?.present(tooltipController, in: .current)
                        
                        navigationController.view.addSubview(ConfettiView(frame: navigationController.view.bounds))
                    } else if peerId.namespace == Namespaces.Peer.CloudUser {
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { !($0 is GiftSetupScreen) && !($0 is GiftOptionsScreenProtocol) && !($0 is PeerInfoScreen) && !($0 is ContactSelectionController) }
                        var foundController = false
                        for controller in controllers.reversed() {
                            if let chatController = controller as? ChatController, case .peer(id: component.peerId) = chatController.chatLocation {
                                chatController.hintPlayNextOutgoingGift()
                                foundController = true
                                break
                            }
                        }
                        if !foundController {
                            let chatController = component.context.sharedContext.makeChatController(context: component.context, chatLocation: .peer(id: component.peerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                            chatController.hintPlayNextOutgoingGift()
                            controllers.append(chatController)
                        }
                        navigationController.setViewControllers(controllers, animated: true)
                        
                        if case let .starGift(starGift, _) = component.subject, let perUserLimit = starGift.perUserLimit {
                            Queue.mainQueue().after(0.5) {
                                let remains = max(0, perUserLimit.remains - 1)
                                let text: String
                                if remains == 0 {
                                    text = presentationData.strings.Gift_Send_Limited_Success_Text_None
                                } else {
                                    text = presentationData.strings.Gift_Send_Limited_Success_Text(remains)
                                }
                                let tooltipController = UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .sticker(
                                        context: context,
                                        file: starGift.file,
                                        loop: true,
                                        title: presentationData.strings.Gift_Send_Limited_Success_Title,
                                        text: text,
                                        undoText: nil,
                                        customAction: nil
                                    ),
                                    position: .top,
                                    action: { _ in return true }
                                )
                                (navigationController.viewControllers.last as? ViewController)?.present(tooltipController, in: .current)
                            }
                        }
                    }
                    
                    if let completion {
                        completion()
                        
                        if let controller = self.environment?.controller() {
                            controller.dismiss()
                        }
                    }
                    
                    Queue.mainQueue().after(2.5) {
                        starsContext.load(force: true)
                    }
                }, error: { [weak self] error in
                    guard let self, let controller = self.environment?.controller() else {
                        return
                    }
                    
                    self.inProgress = false
                    self.state?.updated()
                    
                    var errorText: String?
                    switch error {
                    case .starGiftUserLimit:
                        if let perUserLimit, let giftFile {
                            let text = presentationData.strings.Gift_Options_Gift_BuyLimitReached(perUserLimit)
                            let undoController = UndoOverlayController(
                                presentationData: presentationData,
                                content: .sticker(context: component.context, file: giftFile, loop: true, title: nil, text: text, undoText: nil, customAction: nil),
                                elevatedLayout: true,
                                action: { _ in return false }
                            )
                            controller.present(undoController, in: .current)
                            return
                        }
                        return
                    case .starGiftOutOfStock:
                        errorText = presentationData.strings.Gift_Send_ErrorOutOfStock
                    case .disallowedStarGift:
                        errorText = presentationData.strings.Gift_Send_ErrorDisallowed(self.peerMap[peerId]?.compactDisplayTitle ?? "").string
                    default:
                        errorText = presentationData.strings.Gift_Send_ErrorUnknown
                    }
                    
                    if let errorText = errorText {
                        let alertController = textAlertController(context: component.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true)
                        controller.present(alertController, in: .window(.root))
                    }
                })
            }
            
            if starsState.balance < StarsAmount(value: finalPrice, nanos: 0) {
                let _ = (self.optionsPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    let purchaseController = component.context.sharedContext.makeStarsPurchaseScreen(
                        context: component.context,
                        starsContext: starsContext,
                        options: options ?? [],
                        purpose: .starGift(peerId: component.peerId, requiredStars: finalPrice),
                        targetPeerId: nil,
                        customTheme: nil,
                        completion: { [weak self, weak starsContext] stars in
                            guard let self, let starsContext else {
                                return
                            }
                            self.inProgress = true
                            self.state?.updated()
                            
                            starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                            let _ = (starsContext.onUpdate
                            |> deliverOnMainQueue).start(next: {
                                proceed()
                            })
                        }
                    )
                    controller.push(purchaseController)
                })
            } else {
                proceed()
            }
        }
        
        @objc private func previewTap() {
            self.deactivateInput()
        }
        
        private func updateInputMediaNode(
            component: GiftSetupScreenComponent,
            availableSize: CGSize,
            bottomInset: CGFloat,
            inputHeight: CGFloat,
            effectiveInputHeight: CGFloat,
            metrics: LayoutMetrics,
            deviceMetrics: DeviceMetrics,
            transition: ComponentTransition
        ) -> CGFloat {
            let bottomInset: CGFloat = bottomInset + 8.0
            let bottomContainerInset: CGFloat = 0.0
            let needsInputActivation: Bool = !"".isEmpty
            
            var height: CGFloat = 0.0
            if case .emoji = self.currentInputMode, let inputData = self.inputMediaNodeData {
                let inputMediaNode: ChatEntityKeyboardInputNode
                var inputMediaNodeTransition = transition
                var animateIn = false
                if let current = self.inputMediaNode {
                    inputMediaNode = current
                } else {
                    animateIn = true
                    inputMediaNodeTransition = inputMediaNodeTransition.withAnimation(.none)
                    inputMediaNode = ChatEntityKeyboardInputNode(
                        context: component.context,
                        currentInputData: inputData,
                        updatedInputData: self.inputMediaNodeDataPromise.get(),
                        defaultToEmojiTab: true,
                        opaqueTopPanelBackground: false,
                        useOpaqueTheme: true,
                        interaction: self.inputMediaInteraction,
                        chatPeerId: nil,
                        stateContext: self.inputMediaNodeStateContext,
                        forceHasPremium: true
                    )
                    inputMediaNode.clipsToBounds = true
                    
                    inputMediaNode.externalTopPanelContainerImpl = nil
                    inputMediaNode.useExternalSearchContainer = true
                    if inputMediaNode.view.superview == nil {
                        self.inputMediaNodeBackground.removeAllAnimations()
                        self.layer.addSublayer(self.inputMediaNodeBackground)
                        self.addSubview(inputMediaNode.view)
                    }
                    self.inputMediaNode = inputMediaNode
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let presentationInterfaceState = ChatPresentationInterfaceState(
                    chatWallpaper: .builtin(WallpaperSettings()),
                    theme: presentationData.theme,
                    preferredGlassType: .default,
                    strings: presentationData.strings,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    nameDisplayOrder: presentationData.nameDisplayOrder,
                    limitsConfiguration: component.context.currentLimitsConfiguration.with { $0 },
                    fontSize: presentationData.chatFontSize,
                    bubbleCorners: presentationData.chatBubbleCorners,
                    accountPeerId: component.context.account.peerId,
                    mode: .standard(.default),
                    chatLocation: .peer(id: component.context.account.peerId),
                    subject: nil,
                    peerNearbyData: nil,
                    greetingData: nil,
                    pendingUnpinnedAllMessages: false,
                    activeGroupCallInfo: nil,
                    hasActiveGroupCall: false,
                    threadData: nil,
                    isGeneralThreadClosed: nil,
                    replyMessage: nil,
                    accountPeerColor: nil,
                    businessIntro: nil
                )
                
                self.inputMediaNodeBackground.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor.cgColor
                
                let heightAndOverflow = inputMediaNode.updateLayout(width: availableSize.width, leftInset: 0.0, rightInset: 0.0, bottomInset: bottomInset, standardInputHeight: deviceMetrics.standardInputHeight(inLandscape: false), inputHeight: inputHeight < 100.0 ? inputHeight - bottomContainerInset : inputHeight, maximumHeight: availableSize.height, inputPanelHeight: 0.0, transition: .immediate, interfaceState: presentationInterfaceState, layoutMetrics: metrics, deviceMetrics: deviceMetrics, isVisible: true, isExpanded: false)
                let inputNodeHeight = heightAndOverflow.0
                let inputNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputNodeHeight), size: CGSize(width: availableSize.width, height: inputNodeHeight))
                
                let inputNodeBackgroundFrame = CGRect(origin: CGPoint(x: inputNodeFrame.minX, y: inputNodeFrame.minY - 6.0), size: CGSize(width: inputNodeFrame.width, height: inputNodeFrame.height + 6.0))
                
                if needsInputActivation {
                    let inputNodeFrame = inputNodeFrame.offsetBy(dx: 0.0, dy: inputNodeHeight)
                    ComponentTransition.immediate.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                    ComponentTransition.immediate.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundFrame)
                }
                
                if animateIn {
                    var targetFrame = inputNodeFrame
                    targetFrame.origin.y = availableSize.height
                    inputMediaNodeTransition.setFrame(layer: inputMediaNode.layer, frame: targetFrame)
                    
                    let inputNodeBackgroundTargetFrame = CGRect(origin: CGPoint(x: targetFrame.minX, y: targetFrame.minY - 6.0), size: CGSize(width: targetFrame.width, height: targetFrame.height + 6.0))
                    
                    inputMediaNodeTransition.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundTargetFrame)
                    
                    transition.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                    transition.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundFrame)
                } else {
                    inputMediaNodeTransition.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                    inputMediaNodeTransition.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeBackgroundFrame)
                }
                
                height = heightAndOverflow.0
            } else {
                self.inputMediaNodeTargetTag = nil
                
                if let inputMediaNode = self.inputMediaNode {
                    self.inputMediaNode = nil
                    var targetFrame = inputMediaNode.frame
                    targetFrame.origin.y = availableSize.height
                    transition.setFrame(view: inputMediaNode.view, frame: targetFrame, completion: { [weak inputMediaNode] _ in
                        if let inputMediaNode {
                            Queue.mainQueue().after(0.3) {
                                inputMediaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { [weak inputMediaNode] _ in
                                    inputMediaNode?.view.removeFromSuperview()
                                })
                            }
                        }
                    })
                    transition.setFrame(layer: self.inputMediaNodeBackground, frame: targetFrame, completion: { [weak self] _ in
                        Queue.mainQueue().after(0.3) {
                            guard let self else {
                                return
                            }
                            if self.currentInputMode == .text {
                                self.inputMediaNodeBackground.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { [weak self] finished in
                                    guard let self else {
                                        return
                                    }
                                    
                                    if finished {
                                        self.inputMediaNodeBackground.removeFromSuperlayer()
                                    }
                                    self.inputMediaNodeBackground.removeAllAnimations()
                                })
                            }
                        }
                    })
                }
            }
            
            return height
        }
        
        private func activateInput() {
            self.currentInputMode = .text
            if !hasFirstResponder(self) {
                if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
                    view.activateInput()
                }
            } else {
                self.state?.updated(transition: .immediate)
            }
        }
        
        private var nextTransitionUserData: Any?
        @objc private func deactivateInput() {
            guard let _ = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            self.currentInputMode = .text
            if hasFirstResponder(self) {
                if let view = self.inputPanel.view as? MessageInputPanelComponent.View {
                    self.nextTransitionUserData = TextFieldComponent.AnimationHint(view: nil, kind: .textFocusChanged(isFocused: false))
                    if view.isActive {
                        view.deactivateInput(force: true)
                    } else {
                        self.endEditing(true)
                    }
                }
            } else {
                self.state?.updated(transition: .spring(duration: 0.4).withUserData(TextFieldComponent.AnimationHint(view: nil, kind: .textFocusChanged(isFocused: false))))
            }
        }
        
        func update(component: GiftSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let theme = environment.theme.withModalBlocksBackground()
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, environment.deviceMetrics.screenSize.width) - environment.safeInsets.left * 2.0
            }
            let rawSideInset: CGFloat = floor((availableSize.width - fillingSize) * 0.5)
            let sideInset: CGFloat = rawSideInset + 24.0
            
            let peerName = self.peerMap[component.peerId]?.compactDisplayTitle ?? ""
            let isSelfGift = component.peerId == component.context.account.peerId
            let isChannelGift = component.peerId.namespace == Namespaces.Peer.CloudChannel
            
            if self.component == nil {
                if isSelfGift {
                    self.hideName = true
                }
                
                if case let .starGift(gift, _) = component.subject, gift.flags.contains(.isAuction), let giftAuctionsManager = component.context.giftAuctionsManager {
                    let _ = (giftAuctionsManager.auctionContext(for: .giftId(gift.id))
                    |> deliverOnMainQueue).start(next: { [weak self] auctionContext in
                        guard let self, let auctionContext else {
                            return
                        }
                        self.giftAuction = auctionContext
                        self.giftAuctionDisposable = (auctionContext.state
                        |> deliverOnMainQueue).start(next: { [weak self] state in
                            guard let self else {
                                return
                            }
                            self.giftAuctionState = state
                            self.state?.updated()
                        })
                        
                        self.giftAuctionTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                            self?.state?.updated()
                        }, queue: Queue.mainQueue())
                        self.giftAuctionTimer?.start()
                    })
                }
                                
                var releasedBy: EnginePeer.Id?
                if case let .starGift(gift, true) = component.subject, gift.upgradeStars != nil {
                    self.includeUpgrade = true
                }
                if case let .starGift(gift, _) = component.subject {
                    releasedBy = gift.releasedBy
                }
                
                var peerIds: [EnginePeer.Id] = [
                    component.context.account.peerId,
                    component.peerId
                ]
                if let releasedBy {
                    peerIds.append(releasedBy)
                }
                
                let _ = combineLatest(queue: Queue.mainQueue(),
                    component.context.engine.data.get(EngineDataMap(
                        peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                            return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                        }
                    )),
                    component.context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.SendPaidMessageStars(id: component.peerId)
                    )
                ).start(next: { [weak self] peers, sendPaidMessageStars in
                    guard let self else {
                        return
                    }
                    var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                    for (peerId, maybePeer) in peers {
                        if let peer = maybePeer {
                            peersMap[peerId] = peer
                        }
                    }
                    self.peerMap = peersMap
                    self.sendPaidMessageStars = sendPaidMessageStars
                    
                    self.state?.updated()
                })
                
                self.inputMediaNodeDataPromise.set(
                    ChatEntityKeyboardInputNode.inputData(
                        context: component.context,
                        chatPeerId: nil,
                        areCustomEmojiEnabled: true,
                        hasTrending: false,
                        hasSearch: true,
                        hasStickers: false,
                        hasGifs: false,
                        hideBackground: true,
                        forceHasPremium: true,
                        sendGif: nil
                    )
                )
                self.inputMediaNodeDataDisposable = (self.inputMediaNodeDataPromise.get()
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.inputMediaNodeData = value
                })
                
                self.inputMediaInteraction = ChatEntityKeyboardInputNode.Interaction(
                    sendSticker: { _, _, _, _, _, _, _, _, _ in
                        return false
                    },
                    sendEmoji: { _, _, _ in
                        let _ = self
                    },
                    sendGif: { _, _, _, _, _ in
                        return false
                    },
                    sendBotContextResultAsGif: { _, _ , _, _, _, _ in
                        return false
                    },
                    updateChoosingSticker: { _ in
                    },
                    switchToTextInput: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.currentInputMode = .text
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    dismissTextInput: {
                    },
                    insertText: { [weak self] text in
                        guard let self else {
                            return
                        }
                        self.inputPanelExternalState.insertText(text)
                    },
                    backwardsDeleteText: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.inputPanelExternalState.deleteBackward()
                    },
                    openStickerEditor: {
                    },
                    presentController: { [weak self] c, a in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.present(c, in: .window(.root), with: a)
                    },
                    presentGlobalOverlayController: { [weak self] c, a in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.presentInGlobalOverlay(c, with: a)
                    },
                    getNavigationController: { [weak self] () -> NavigationController? in
                        guard let self else {
                            return nil
                        }
                        guard let controller = self.environment?.controller() as? GiftSetupScreen else {
                            return nil
                        }
                        
                        if let navigationController = controller.navigationController as? NavigationController {
                            return navigationController
                        }
                        return nil
                    },
                    requestLayout: { [weak self] transition in
                        guard let self else {
                            return
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: ComponentTransition(transition))
                        }
                    }
                )
                
                self.optionsDisposable = (component.context.engine.payments.starsTopUpOptions()
                |> deliverOnMainQueue).start(next: { [weak self] options in
                    guard let self else {
                        return
                    }
                    self.options = options
                })
                
                if case let .starGift(gift, _) = component.subject {
                    if let _ = gift.upgradeStars {
                        self.previewPromise.set(
                            component.context.engine.payments.starGiftUpgradePreview(giftId: gift.id)
                        )
                    }
                    
                    self.updateDisposable = component.context.engine.payments.keepStarGiftsUpdated().start()
                }
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = theme.list.blocksBackgroundColor.cgColor
            }
                        
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
   
            if self.backgroundHandleView.image == nil {
                self.backgroundHandleView.image = generateStretchableFilledCircleImage(diameter: 5.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.backgroundHandleView.tintColor = environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.2)
            let backgroundHandleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - 36.0) * 0.5), y: 5.0), size: CGSize(width: 36.0, height: 5.0))
            if self.backgroundHandleView.superview == nil {
                self.navigationBarContainer.addSubview(self.backgroundHandleView)
            }
            transition.setFrame(view: self.backgroundHandleView, frame: backgroundHandleFrame)
            
            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: rawSideInset + 16.0, y: 16.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            var initialContentHeight = contentHeight
            let clippingY: CGFloat
                        
            let giftConfiguration = GiftConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                    
            let footerAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
                        
            var inputHeight: CGFloat = 0.0
            inputHeight += self.updateInputMediaNode(
                component: component,
                availableSize: availableSize,
                bottomInset: environment.safeInsets.bottom,
                inputHeight: 0.0,
                effectiveInputHeight: environment.deviceMetrics.standardInputHeight(inLandscape: false),
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                transition: transition
            )
            if self.inputMediaNode == nil {
                if environment.inputHeight.isZero && self.inputPanelExternalState.isEditing, let previousInputHeight = self.previousInputHeight {
                    inputHeight = previousInputHeight
                } else {
                    inputHeight = environment.inputHeight
                }
            }
            self.previousInputHeight = inputHeight
                         
            let listItemParams = ListViewItemLayoutParams(width: fillingSize, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            var introContentSize = CGSize()
            if let accountPeer = self.peerMap[component.context.account.peerId] {
                var inputPanelSize = CGSize()
                let inputPanelInset: CGFloat = 16.0
                if self.sendPaidMessageStars == nil {
                    let nextInputMode: MessageInputPanelComponent.InputMode
                    switch self.currentInputMode {
                    case .text:
                        nextInputMode = .emoji
                    case .emoji:
                        nextInputMode = .text
                    default:
                        nextInputMode = .emoji
                    }
                    
                    self.inputPanel.parentState = state
                    inputPanelSize = self.inputPanel.update(
                        transition: transition,
                        component: AnyComponent(MessageInputPanelComponent(
                            externalState: self.inputPanelExternalState,
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            style: .gift,
                            placeholder: .plain(environment.strings.Gift_Send_Customize_MessagePlaceholder),
                            sendPaidMessageStars: nil,
                            maxLength: Int(giftConfiguration.maxCaptionLength),
                            queryTypes: [],
                            alwaysDarkWhenHasText: false,
                            useGrayBackground: false,
                            resetInputContents: nil,
                            nextInputMode: { _ in return nextInputMode },
                            areVoiceMessagesAvailable: false,
                            presentController: { c in
                            },
                            presentInGlobalOverlay: { c in
                            },
                            sendMessageAction: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.deactivateInput()
                            },
                            sendMessageOptionsAction: nil,
                            sendStickerAction: { _ in },
                            setMediaRecordingActive: nil,
                            lockMediaRecording: {
                            },
                            stopAndPreviewMediaRecording: {
                            },
                            discardMediaRecordingPreview: nil,
                            attachmentAction: nil,
                            myReaction: nil,
                            likeAction: nil,
                            likeOptionsAction: nil,
                            inputModeAction: { [weak self] in
                                if let self {
                                    switch self.currentInputMode {
                                    case .text:
                                        self.currentInputMode = .emoji
                                    case .emoji:
                                        self.currentInputMode = .text
                                    default:
                                        self.currentInputMode = .emoji
                                    }
                                    if self.currentInputMode == .text {
                                        self.activateInput()
                                    } else {
                                        self.state?.updated(transition: .immediate)
                                    }
                                }
                            },
                            timeoutAction: nil,
                            forwardAction: nil,
                            paidMessageAction: nil,
                            moreAction: nil,
                            presentCaptionPositionTooltip: nil,
                            presentVoiceMessagesUnavailableTooltip: nil,
                            presentTextLengthLimitTooltip: {
                            },
                            presentTextFormattingTooltip: {
                            },
                            paste: { _ in
                            },
                            audioRecorder: nil,
                            videoRecordingStatus: nil,
                            isRecordingLocked: false,
                            hasRecordedVideo: false,
                            recordedAudioPreview: nil,
                            hasRecordedVideoPreview: false,
                            wasRecordingDismissed: false,
                            timeoutValue: nil,
                            timeoutSelected: false,
                            displayGradient: false,
                            bottomInset: 0.0,
                            isFormattingLocked: false,
                            hideKeyboard: self.currentInputMode == .emoji,
                            customInputView: nil,
                            forceIsEditing: self.currentInputMode == .emoji,
                            disabledPlaceholder: nil,
                            header: nil,
                            isChannel: false,
                            storyItem: nil,
                            chatLocation: nil
                        )),
                        environment: {},
                        containerSize: CGSize(width: fillingSize - inputPanelInset * 2.0, height: 160.0)
                    )
                }
                
                var upgradeStars: Int64?
                let subject: ChatGiftPreviewItem.Subject
                var releasedBy: EnginePeer.Id?
                switch component.subject {
                case let .premium(product):
                    if self.payWithStars, let starsPrice = product.starsPrice {
                        subject = .premium(months: product.months, amount: starsPrice, currency: "XTR")
                    } else {
                        let (currency, amount) = product.storeProduct?.priceCurrencyAndAmount ?? ("USD", 1)
                        subject = .premium(months: product.months, amount: amount, currency: currency)
                    }
                case let .starGift(gift, _):
                    subject = .starGift(gift: gift)
                    upgradeStars = gift.upgradeStars
                    releasedBy = gift.releasedBy
                }
                
                var peers: [EnginePeer] = [accountPeer]
                if let peer = self.peerMap[component.peerId] {
                    peers.append(peer)
                }
                if let releasedBy, let peer = self.peerMap[releasedBy] {
                    peers.append(peer)
                }
                
                var textInputText = NSAttributedString()
                if let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View, case let .text(text) = inputPanelView.getSendMessageInput(applyAutocorrection: false) {
                    textInputText = text
                }
                var inputBottomInset: CGFloat = inputPanelSize.height - 26.0
                if component.peerId == component.context.account.peerId {
                    inputBottomInset += 8.0
                }
                introContentSize = self.introContent.update(
                    transition: transition,
                    component: AnyComponent(
                        ListItemComponentAdaptor(
                            itemGenerator: ChatGiftPreviewItem(
                                context: component.context,
                                theme: environment.theme,
                                componentTheme: environment.theme,
                                strings: environment.strings,
                                sectionId: 0,
                                fontSize: presentationData.chatFontSize,
                                chatBubbleCorners: presentationData.chatBubbleCorners,
                                wallpaper: presentationData.chatWallpaper,
                                dateTimeFormat: environment.dateTimeFormat,
                                nameDisplayOrder: presentationData.nameDisplayOrder,
                                peers: peers,
                                subject: subject,
                                chatPeerId: component.peerId,
                                text: textInputText.string,
                                entities: generateChatInputTextEntities(textInputText),
                                upgradeStars: self.includeUpgrade ? upgradeStars : nil,
                                chargeStars: nil,
                                bottomInset: max(0.0, inputBottomInset)
                            ),
                            params: listItemParams
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: fillingSize, height: 10000.0)
                )
                if let introContentView = self.introContent.view {
                    if introContentView.superview == nil {
                        introContentView.clipsToBounds = true
                        introContentView.layer.cornerRadius = 38.0
                        introContentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                        
                        self.scrollContentView.addSubview(introContentView)
                        introContentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.previewTap)))
                    }
                    transition.setFrame(view: introContentView, frame: CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: introContentSize))
                }
                
                let glassContainerFrame = CGRect(origin: CGPoint(x: rawSideInset + inputPanelInset, y: contentHeight + introContentSize.height - inputPanelInset - inputPanelSize.height + 6.0 - 20.0), size: CGSize(width: inputPanelSize.width, height: inputPanelSize.height + 40.0))
                self.glassContainerView.update(size: glassContainerFrame.size, isDark: theme.overallDarkAppearance, transition: transition)
                
                let inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: 20.0), size: inputPanelSize)
                if let inputPanelView = self.inputPanel.view {
                    if inputPanelView.superview == nil {
                        self.scrollContentView.addSubview(self.glassContainerView)
                        self.glassContainerView.contentView.addSubview(inputPanelView)
                    }
                    transition.setFrame(view: self.glassContainerView, frame: glassContainerFrame)
                    transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
                }
            }
            contentHeight += introContentSize.height
            contentHeight += sectionSpacing
            
            if case let .starGift(starGift, forceUnique) = component.subject, let availability = starGift.availability, availability.resale > 0 {
                if let forceUnique, !forceUnique {
                } else {
                    let resaleSectionSize = self.resaleSection.update(
                        transition: transition,
                        component: AnyComponent(ListSectionComponent(
                            theme: theme,
                            style: .glass,
                            header: nil,
                            footer: nil,
                            items: [
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                    theme: theme,
                                    style: .glass,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(
                                            MultilineTextComponent(
                                                text: .plain(NSAttributedString(string: environment.strings.Gift_Send_AvailableForResale, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: theme.list.itemPrimaryTextColor))
                                            )
                                        )),
                                    ], alignment: .left, spacing: 2.0)),
                                    accessory: .custom(ListActionItemComponent.CustomAccessory(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: presentationStringsFormattedNumber(Int32(availability.resale), environment.dateTimeFormat.groupingSeparator),
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: theme.list.itemSecondaryTextColor
                                        )),
                                        maximumNumberOfLines: 0
                                    ))), insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 16.0))),
                                    action: { [weak self] _ in
                                        guard let self, let component = self.component, let controller = environment.controller() else {
                                            return
                                        }
                                        let storeController = component.context.sharedContext.makeGiftStoreController(
                                            context: component.context,
                                            peerId: component.peerId,
                                            gift: starGift
                                        )
                                        controller.push(storeController)
                                    }
                                )))
                            ]
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                    )
                    let resaleSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: resaleSectionSize)
                    if let resaleSectionView = self.resaleSection.view {
                        if resaleSectionView.superview == nil {
                            self.scrollContentView.addSubview(resaleSectionView)
                        }
                        transition.setFrame(view: resaleSectionView, frame: resaleSectionFrame)
                    }
                    contentHeight += resaleSectionSize.height
                    contentHeight += sectionSpacing
                }
            }
            
            switch component.subject {
            case let .premium(product):
                let balance = component.context.starsContext?.currentState?.balance.value ?? 0
                if let starsPrice = product.starsPrice, balance >= starsPrice {
                    let balanceString = presentationStringsFormattedNumber(Int32(balance), environment.dateTimeFormat.groupingSeparator)
                    
                    let starsFooterRawString = environment.strings.Gift_Send_PayWithStars_Info("# \(balanceString)").string
                    let starsFooterText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(starsFooterRawString, attributes: footerAttributes))
                    
                    if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                        self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.list.itemAccentColor)!, environment.theme)
                    }
                    if let range = starsFooterText.string.range(of: "#") {
                        starsFooterText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: starsFooterText.string))
                    }
                    if let range = starsFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                        starsFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: starsFooterText.string))
                    }
                    
                    let priceString = presentationStringsFormattedNumber(Int32(starsPrice), environment.dateTimeFormat.groupingSeparator)
                    let starsAttributedText = NSMutableAttributedString(string: environment.strings.Gift_Send_PayWithStars("#\(priceString)").string, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: theme.list.itemPrimaryTextColor)
                    let range = (starsAttributedText.string as NSString).range(of: "#")
                    if range.location != NSNotFound {
                        starsAttributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                        starsAttributedText.addAttribute(.baselineOffset, value: 1.0, range: range)
                    }
                    
                    let starsSectionSize = self.starsSection.update(
                        transition: transition,
                        component: AnyComponent(ListSectionComponent(
                            theme: theme,
                            style: .glass,
                            header: nil,
                            footer: AnyComponent(MultilineTextWithEntitiesComponent(
                                context: component.context,
                                animationCache: component.context.animationCache,
                                animationRenderer: component.context.animationRenderer,
                                placeholderColor: .clear,
                                text: .plain(starsFooterText),
                                maximumNumberOfLines: 0,
                                highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.1),
                                highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                                highlightAction: { attributes in
                                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                        return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                    } else {
                                        return nil
                                    }
                                },
                                tapAction: { [weak self] _, _ in
                                    guard let self, let component = self.component, let controller = self.environment?.controller(), let starsContext = component.context.starsContext else {
                                        return
                                    }
                                    let _ = (self.optionsPromise.get()
                                    |> filter { $0 != nil }
                                    |> take(1)
                                    |> deliverOnMainQueue).startStandalone(next: { options in
                                        let purchaseController = component.context.sharedContext.makeStarsPurchaseScreen(context: component.context, starsContext: starsContext, options: options ?? [], purpose: .generic, targetPeerId: nil, customTheme: nil, completion: { stars in
                                            starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                                        })
                                        controller.push(purchaseController)
                                    })
                                }
                            )),
                            items: [
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                    theme: theme,
                                    style: .glass,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(
                                            MultilineTextWithEntitiesComponent(
                                                context: component.context,
                                                animationCache: component.context.animationCache,
                                                animationRenderer: component.context.animationRenderer,
                                                placeholderColor: theme.list.mediaPlaceholderColor,
                                                text: .plain(starsAttributedText)
                                            )
                                        )),
                                    ], alignment: .left, spacing: 2.0)),
                                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.payWithStars, action: { [weak self] _ in
                                        guard let self else {
                                            return
                                        }
                                        self.payWithStars = !self.payWithStars
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    })),
                                    action: nil
                                )))
                            ]
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                    )
                    let starsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: starsSectionSize)
                    if let starsSectionView = self.starsSection.view {
                        if starsSectionView.superview == nil {
                            self.scrollContentView.addSubview(starsSectionView)
                        }
                        transition.setFrame(view: starsSectionView, frame: starsSectionFrame)
                    }
                    contentHeight += starsSectionSize.height
                    contentHeight += sectionSpacing
                }
            case let .starGift(gift, forceUnique):
                if let upgradeStars = gift.upgradeStars, component.peerId != component.context.account.peerId {
                    let upgradeFooterRawString: String
                    if isChannelGift {
                        upgradeFooterRawString = environment.strings.Gift_SendChannel_Upgrade_Info(peerName).string
                    } else {
                        if forceUnique == true {
                            upgradeFooterRawString = environment.strings.Gift_Send_Upgrade_ForcedInfo(peerName).string
                        } else {
                            upgradeFooterRawString = environment.strings.Gift_Send_Upgrade_Info(peerName).string
                        }
                    }
                    let parsedString = parseMarkdownIntoAttributedString(upgradeFooterRawString, attributes: footerAttributes)
                    
                    let upgradeFooterText = NSMutableAttributedString(attributedString: parsedString)
                    
                    if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                        self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.list.itemAccentColor)!, environment.theme)
                    }
                    if let range = upgradeFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                        upgradeFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: upgradeFooterText.string))
                    }
                    
                    let upgradeAttributedText = NSMutableAttributedString(string: environment.strings.Gift_Send_Upgrade("#\(upgradeStars)").string, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: theme.list.itemPrimaryTextColor)
                    let range = (upgradeAttributedText.string as NSString).range(of: "#")
                    if range.location != NSNotFound {
                        upgradeAttributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                        upgradeAttributedText.addAttribute(.baselineOffset, value: 1.0, range: range)
                    }
                    
                    let upgradeSectionSize = self.upgradeSection.update(
                        transition: transition,
                        component: AnyComponent(ListSectionComponent(
                            theme: theme,
                            style: .glass,
                            header: nil,
                            footer: AnyComponent(MultilineTextComponent(
                                text: .plain(upgradeFooterText),
                                maximumNumberOfLines: 0,
                                highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.1),
                                highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                                highlightAction: { attributes in
                                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                        return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                    } else {
                                        return nil
                                    }
                                },
                                tapAction: { [weak self] _, _ in
                                    guard let self else {
                                        return
                                    }
                                    let _ = (self.previewPromise.get()
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { [weak self] upgradePreview in
                                        guard let self, let component = self.component, let controller = self.environment?.controller(), let upgradePreview else {
                                            return
                                        }
                                        let previewController = component.context.sharedContext.makeGiftUpgradePreviewScreen(context: component.context, gift: gift, attributes: upgradePreview.attributes, peerName: peerName)
                                        controller.push(previewController)
                                    })
                                }
                            )),
                            items: [
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                    theme: theme,
                                    style: .glass,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(
                                            MultilineTextWithEntitiesComponent(
                                                context: component.context,
                                                animationCache: component.context.animationCache,
                                                animationRenderer: component.context.animationRenderer,
                                                placeholderColor: theme.list.mediaPlaceholderColor,
                                                text: .plain(upgradeAttributedText)
                                            )
                                        )),
                                    ], alignment: .left, spacing: 2.0)),
                                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.includeUpgrade, isEnabled: forceUnique != true, action: { [weak self] _ in
                                        guard let self, forceUnique != true else {
                                            return
                                        }
                                        self.includeUpgrade = !self.includeUpgrade
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    })),
                                    action: nil
                                )))
                            ]
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                    )
                    let upgradeSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: upgradeSectionSize)
                    if let upgradeSectionView = self.upgradeSection.view {
                        if upgradeSectionView.superview == nil {
                            self.scrollContentView.addSubview(upgradeSectionView)
                        }
                        transition.setFrame(view: upgradeSectionView, frame: upgradeSectionFrame)
                    }
                    contentHeight += upgradeSectionSize.height
                    contentHeight += sectionSpacing
                }
                
                let hideSectionFooterString: String
                if isSelfGift {
                    hideSectionFooterString = environment.strings.Gift_SendSelf_HideMyName_Info
                } else if isChannelGift {
                    hideSectionFooterString = environment.strings.Gift_SendChannel_HideMyName_Info
                } else {
                    hideSectionFooterString = environment.strings.Gift_Send_HideMyName_Info(peerName, peerName).string
                }
                let hideSectionSize = self.hideSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: hideSectionFooterString,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                style: .glass,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: isSelfGift ? environment.strings.Gift_SendSelf_HideMyName : environment.strings.Gift_Send_HideMyName,
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))),
                                ], alignment: .left, spacing: 2.0)),
                                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.hideName, action: { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    self.hideName = !self.hideName
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                })),
                                action: nil
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let hideSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: hideSectionSize)
                if let hideSectionView = self.hideSection.view {
                    if hideSectionView.superview == nil {
                        self.scrollContentView.addSubview(hideSectionView)
                    }
                    transition.setFrame(view: hideSectionView, frame: hideSectionFrame)
                }
                contentHeight += hideSectionSize.height
            }
            contentHeight += sectionSpacing
            
            if case let .starGift(starGift, _) = component.subject, let availability = starGift.availability {
                contentHeight -= 77.0
                contentHeight += 16.0
                
                var remains: Int32 = availability.remains
                if let auctionState = self.giftAuctionState {
                    switch auctionState.auctionState {
                    case let .ongoing(_, _, _, _, _, _, _, giftsLeft, _, _, _, _):
                        remains = giftsLeft
                    case .finished:
                        remains = 0
                    }
                }
                let total: Int32 = availability.total
                let position = CGFloat(remains) / CGFloat(total)
                let sold = total - remains
                let remainingCountSize = self.remainingCount.update(
                    transition: transition,
                    component: AnyComponent(GiftRemainingCountComponent(
                        inactiveColor: theme.list.itemBlocksBackgroundColor,
                        activeColors: [UIColor(rgb: 0x72d6ff), UIColor(rgb: 0x32a0f9)],
                        inactiveTitle: environment.strings.Gift_Send_Remains(remains),
                        inactiveValue: "",
                        inactiveTitleColor: theme.list.itemSecondaryTextColor,
                        activeTitle: "",
                        activeValue: sold > 0 ? environment.strings.Gift_Send_Sold(sold) : "",
                        activeTitleColor: .white,
                        badgeText: "",
                        badgePosition: position,
                        badgeGraphPosition: position,
                        invertProgress: true,
                        leftString: "",
                        groupingSeparator: environment.dateTimeFormat.groupingSeparator
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let remainingCountFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: remainingCountSize)
                if let remainingCountView = self.remainingCount.view {
                    if remainingCountView.superview == nil {
                        self.scrollContentView.addSubview(remainingCountView)
                    }
                    transition.setFrame(view: remainingCountView, frame: remainingCountFrame)
                }
                contentHeight += remainingCountSize.height
                contentHeight += 7.0
                                
                if starGift.flags.contains(.isAuction), let giftsPerRound = starGift.auctionGiftsPerRound {
                    let parsedString = parseMarkdownIntoAttributedString(environment.strings.Gift_Setup_AuctionInfo(environment.strings.Gift_Setup_AuctionInfo_Gifts(giftsPerRound), environment.strings.Gift_Setup_AuctionInfo_Bidders(giftsPerRound)).string, attributes: footerAttributes)
                    let auctionFooterText = NSMutableAttributedString(attributedString: parsedString)
                    
                    if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                        self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.list.itemAccentColor)!, environment.theme)
                    }
                    if let range = auctionFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                        auctionFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: auctionFooterText.string))
                    }
                    
                    let auctionFooterSize = self.auctionFooter.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(auctionFooterText),
                            maximumNumberOfLines: 0,
                            highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { [weak self] _, _ in
                                guard let self, let component = self.component,  let controller = self.environment?.controller(), let auctionContext = self.giftAuction else {
                                    return
                                }
                                let infoController = component.context.sharedContext.makeGiftAuctionInfoScreen(context: component.context, auctionContext: auctionContext, completion: nil)
                                controller.push(infoController)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 10000.0)
                    )
                    let auctionFooterFrame = CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: auctionFooterSize)
                    if let auctionFooterView = self.auctionFooter.view {
                        if auctionFooterView.superview == nil {
                            self.scrollContentView.addSubview(auctionFooterView)
                        }
                        transition.setFrame(view: auctionFooterView, frame: auctionFooterFrame)
                    }
                    contentHeight += auctionFooterSize.height
                }
                
                contentHeight += sectionSpacing
            }
            
            initialContentHeight = contentHeight
            
            if self.cachedStarImage == nil || self.cachedStarImage?.1 !== environment.theme {
                self.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: .white)!, environment.theme)
            }
            
            var buttonIsEnabled = true
            let buttonString: String
            switch component.subject {
            case let .premium(product):
                if self.payWithStars, let starsPrice = product.starsPrice {
                    let amountString = presentationStringsFormattedNumber(Int32(starsPrice), presentationData.dateTimeFormat.groupingSeparator)
                    buttonString = "\(environment.strings.Gift_Send_Send)  # \(amountString)"
                } else {
                    let amountString = product.price
                    buttonString = "\(environment.strings.Gift_Send_Send) \(amountString)"
                }
            case let .starGift(starGift, _):
                var finalPrice: Int64 = starGift.price
                if self.includeUpgrade, let upgradePrice = starGift.upgradeStars {
                    finalPrice += upgradePrice
                }
                let amountString = presentationStringsFormattedNumber(Int32(finalPrice), presentationData.dateTimeFormat.groupingSeparator)
                let buttonTitle = isSelfGift ? environment.strings.Gift_Send_Buy : environment.strings.Gift_Send_Send
                buttonString = "\(buttonTitle)  # \(amountString)"
                if let availability = starGift.availability, availability.remains == 0 {
                    buttonIsEnabled = false
                }
            }
            
            var buttonTitleItems: [AnyComponentWithIdentity<Empty>] = []
            if let _ = self.giftAuction {
                var isUpcoming = false
                if let giftAuctionState = self.giftAuctionState {
                    switch giftAuctionState.auctionState {
                    case let .ongoing(_, startTime, endTime, _, _, _, _, _, _, _, _, _):
                        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        let endTimeout: Int32
                        if currentTime < startTime {
                            endTimeout = max(0, startTime - currentTime)
                            isUpcoming = true
                        } else {
                            endTimeout = max(0, endTime - currentTime)
                        }
                        
                        let hours = Int(endTimeout / 3600)
                        let minutes = Int((endTimeout % 3600) / 60)
                        let seconds = Int(endTimeout % 60)
                        
                        let rawString: String
                        if isUpcoming {
                            rawString = hours > 0 ? environment.strings.Gift_Auction_StartsInHours : environment.strings.Gift_Auction_StartsInMinutes
                        } else {
                            rawString = hours > 0 ? environment.strings.Gift_Auction_TimeLeftHours : environment.strings.Gift_Auction_TimeLeftMinutes
                        }
                        
                        var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
                        var startIndex = rawString.startIndex
                        while true {
                            if let range = rawString.range(of: "{", range: startIndex ..< rawString.endIndex) {
                                if range.lowerBound != startIndex {
                                    buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "prefix", content: .text(String(rawString[startIndex ..< range.lowerBound]))))
                                }
                                
                                startIndex = range.upperBound
                                if let endRange = rawString.range(of: "}", range: startIndex ..< rawString.endIndex) {
                                    let controlString = rawString[range.upperBound ..< endRange.lowerBound]
                                    if controlString == "h" {
                                        buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "h", content: .number(hours, minDigits: 2)))
                                    } else if controlString == "m" {
                                        buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                                    } else if controlString == "s" {
                                        buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
                                    }
                                    
                                    startIndex = endRange.upperBound
                                }
                            } else {
                                break
                            }
                        }
                        if startIndex != rawString.endIndex {
                            buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "suffix", content: .text(String(rawString[startIndex ..< rawString.endIndex]))))
                        }
                        
                        buttonTitleItems.append(AnyComponentWithIdentity(id: "timer", component: AnyComponent(AnimatedTextComponent(
                            font: Font.with(size: 12.0, weight: .medium, traits: .monospacedNumbers),
                            color: environment.theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7),
                            items: buttonAnimatedTitleItems,
                            noDelay: true
                        ))))
                    case .finished:
                        buttonIsEnabled = false
                    }
                }
                let buttonAttributedString = NSMutableAttributedString(string: isUpcoming ? environment.strings.Gift_Auction_EarlyBid : environment.strings.Gift_Setup_PlaceBid, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                buttonTitleItems.insert(AnyComponentWithIdentity(id: "bid", component: AnyComponent(
                    MultilineTextComponent(text: .plain(buttonAttributedString))
                )), at: 0)
            } else {
                let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = self.cachedStarImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                
                buttonTitleItems.append(AnyComponentWithIdentity(id: buttonString, component: AnyComponent(
                    MultilineTextComponent(text: .plain(buttonAttributedString))
                )))
            }
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 32.0)
            let buttonHeight: CGFloat = 52.0
            let actionButtonSize = self.actionButton.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        isShimmering: true
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable("title"),
                        component: AnyComponent(VStack(buttonTitleItems, spacing: 1.0))
                    ),
                    isEnabled: buttonIsEnabled,
                    displaysProgress: self.inProgress,
                    action: { [weak self] in
                        self?.proceed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: fillingSize - buttonInsets.left - buttonInsets.right, height: buttonHeight)
            )
            var bottomPanelHeight = 13.0 + buttonInsets.bottom + actionButtonSize.height
            
            let bottomEdgeEffectHeight: CGFloat = bottomPanelHeight
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: availableSize.height - bottomEdgeEffectHeight), size: CGSize(width: fillingSize, height: bottomEdgeEffectHeight))
            transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            self.bottomEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: transition)
            if self.bottomEdgeEffectView.superview == nil {
                self.containerView.addSubview(self.bottomEdgeEffectView)
            }
            
            let actionButtonFrame = CGRect(origin: CGPoint(x: rawSideInset + buttonInsets.left, y: availableSize.height - buttonInsets.bottom - actionButtonSize.height), size: actionButtonSize)
            if let buttonView = self.actionButton.view {
                if buttonView.superview == nil {
                    self.containerView.addSubview(buttonView)
                }
                buttonView.frame = actionButtonFrame
            }
                        
            bottomPanelHeight -= 1.0
                        
            contentHeight += bottomPanelHeight
            initialContentHeight += bottomPanelHeight
            
            clippingY = actionButtonFrame.maxY + 24.0
                        
            var topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            if self.inputPanelExternalState.isEditing {
                topInset = 0.0
            }
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 38.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, containerCornerRadius: environment.deviceMetrics.screenCornerRadius, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: fillingSize, height: availableSize.height)))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: availableSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setPosition(view: self.containerView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let bottomInset: CGFloat = contentHeight - 12.0
            
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class GiftSetupScreen: ViewControllerComponentContainer, GiftSetupScreenProtocol {
    public enum Subject: Equatable {
        case premium(PremiumGiftProduct)
        case starGift(StarGift.Gift, Bool?)
    }
    
    private let context: AccountContext
    
    private var didPlayAppearAnimation: Bool = false
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        subject: Subject,
        auctionAcquiredGifts: Signal<[GiftAuctionAcquiredGift], NoError>? = nil,
        completion: (() -> Void)? = nil
    ) {
        self.context = context
        
        super.init(context: context, component: GiftSetupScreenComponent(
            context: context,
            peerId: peerId,
            subject: subject,
            auctionAcquiredGifts: auctionAcquiredGifts,
            completion: completion
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if !self.didPlayAppearAnimation {
            self.didPlayAppearAnimation = true
            
            if let componentView = self.node.hostView.componentView as? GiftSetupScreenComponent.View {
                componentView.alpha = 0.0
                Queue.mainQueue().after(0.01, {
                    componentView.alpha = 1.0
                    componentView.animateIn()
                })
            }
        }
    }
        
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? GiftSetupScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private struct GiftConfiguration {
    static var defaultValue: GiftConfiguration {
        return GiftConfiguration(maxCaptionLength: 255)
    }
    
    let maxCaptionLength: Int32
    
    fileprivate init(maxCaptionLength: Int32) {
        self.maxCaptionLength = maxCaptionLength
    }
    
    static func with(appConfiguration: AppConfiguration) -> GiftConfiguration {
        if let data = appConfiguration.data {
            var maxCaptionLength: Int32?
            if let value = data["stargifts_message_length_max"] as? Double {
                maxCaptionLength = Int32(value)
            }
            return GiftConfiguration(maxCaptionLength: maxCaptionLength ?? GiftConfiguration.defaultValue.maxCaptionLength)
        } else {
            return .defaultValue
        }
    }
}

public final class PremiumGiftProduct: Equatable {
    public let giftOption: CachedPremiumGiftOption
    public let starsGiftOption: CachedPremiumGiftOption?
    public let storeProduct: InAppPurchaseManager.Product?
    public let discount: Int?
    
    public var id: String {
        return self.storeProduct?.id ?? (self.giftOption.storeProductId ?? "")
    }
    
    public var months: Int32 {
        return self.giftOption.months
    }
    
    public var price: String {
        return self.storeProduct?.price ?? formatCurrencyAmount(self.giftOption.amount, currency: self.giftOption.currency)
    }
    
    public var starsPrice: Int64? {
        return self.starsGiftOption?.amount
    }
    
    public init(
        giftOption: CachedPremiumGiftOption,
        starsGiftOption: CachedPremiumGiftOption?,
        storeProduct: InAppPurchaseManager.Product?,
        discount: Int?
    ) {
        self.giftOption = giftOption
        self.starsGiftOption = starsGiftOption
        self.storeProduct = storeProduct
        self.discount = discount
    }
    
    public static func ==(lhs: PremiumGiftProduct, rhs: PremiumGiftProduct) -> Bool {
        if lhs.giftOption != rhs.giftOption {
            return false
        }
        if lhs.starsGiftOption != rhs.starsGiftOption {
            return false
        }
        if lhs.storeProduct != rhs.storeProduct {
            return false
        }
        if lhs.discount != rhs.discount {
            return false
        }
        return true
    }
}

func hasFirstResponder(_ view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    }
    for subview in view.subviews {
        if hasFirstResponder(subview) {
            return true
        }
    }
    return false
}
