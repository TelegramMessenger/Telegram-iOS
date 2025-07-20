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
import ListMultilineTextFieldItemComponent
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
import GiftViewScreen
import UndoUI
import ConfettiEffect

final class GiftSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let subject: GiftSetupScreen.Subject
    let completion: (() -> Void)?
    
    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        subject: GiftSetupScreen.Subject,
        completion: (() -> Void)? = nil
    ) {
        self.context = context
        self.peerId = peerId
        self.subject = subject
        self.completion = completion
    }

    static func ==(lhs: GiftSetupScreenComponent, rhs: GiftSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let navigationTitle = ComponentView<Empty>()
        private let remainingCount = ComponentView<Empty>()
        private let resaleSection = ComponentView<Empty>()
        private let introContent = ComponentView<Empty>()
        private let introSection = ComponentView<Empty>()
        private let starsSection = ComponentView<Empty>()
        private let upgradeSection = ComponentView<Empty>()
        private let hideSection = ComponentView<Empty>()
    
        private let buttonBackground = ComponentView<Empty>()
        private let buttonSeparator = SimpleLayer()
        private let button = ComponentView<Empty>()
        
        private var ignoreScrolling: Bool = false
        private var isUpdating: Bool = false
        
        private var component: GiftSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let introPlaceholderTag = NSObject()
        private let textInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let textInputTag = NSObject()
        private var resetText: String?
        
        private var currentInputMode: ListMultilineTextFieldItemComponent.InputMode = .keyboard
        
        private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
        private var inputMediaNodeDataDisposable: Disposable?
        private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
        private var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
        private var inputMediaNode: ChatEntityKeyboardInputNode?
        private var inputMediaNodeBackground = SimpleLayer()
        private var inputMediaNodeTargetTag: AnyObject?
        private let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        
        private var currentEmojiSuggestionView: ComponentHostView<Empty>?
        
        private var hideName = false
        private var includeUpgrade = false
        private var payWithStars = false
        
        private var inProgress = false
        
        
        private var previousHadInputHeight: Bool = false
        private var previousInputHeight: CGFloat?
        private var recenterOnTag: NSObject?
                
        private var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        private var sendPaidMessageStars: StarsAmount?
        
        private var starImage: (UIImage, PresentationTheme)?
        
        private var optionsDisposable: Disposable?
        private(set) var options: [StarsTopUpOption] = [] {
            didSet {
                self.optionsPromise.set(self.options)
            }
        }
        private let optionsPromise = ValuePromise<[StarsTopUpOption]?>(nil)
        private let previewPromise = Promise<[StarGift.UniqueGift.Attribute]?>(nil)
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
                
            self.disablesInteractiveKeyboardGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private var scrolledUp = true
        private func updateScrolling(transition: ComponentTransition) {
            let navigationRevealOffsetY: CGFloat = 0.0
            
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentOffset.y - navigationRevealOffsetY) / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
            
            var scrolledUp = false
            if navigationAlpha < 0.5 {
                scrolledUp = true
            } else if navigationAlpha > 0.5 {
                scrolledUp = false
            }
            
            if self.scrolledUp != scrolledUp {
                self.scrolledUp = scrolledUp
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
            
            if let navigationTitleView = self.navigationTitle.view {
                transition.setAlpha(view: navigationTitleView, alpha: 1.0)
            }
            
            let bottomContentOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.contentOffset.y - self.scrollView.frame.height)
            let bottomPanelAlpha = min(16.0, bottomContentOffset) / 16.0
            self.buttonBackground.view?.alpha = bottomPanelAlpha
            self.buttonSeparator.opacity = Float(bottomPanelAlpha)
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
                                environment.strings.Gift_Send_Premium_Confirmation_Text_Stars(Int32(starsPrice))
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

            let entities = generateChatInputTextEntities(self.textInputState.text)
            let purpose: AppStoreTransactionPurpose = .giftCode(peerIds: [component.peerId], boostPeer: nil, currency: currency, amount: amount, text: self.textInputState.text.string, entities: entities)
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
            guard let component = self.component, let starsContext = component.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
            
            let context = component.context
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let peerId = component.peerId
            
            let entities = generateChatInputTextEntities(self.textInputState.text)
            
            var finalPrice: Int64
            let source: BotPaymentInvoiceSource
            switch component.subject {
            case let .premium(product):
                if let option = product.starsGiftOption {
                    finalPrice = option.amount
                    source = .premiumGift(peerId: peerId, option: option, text: self.textInputState.text.string, entities: entities)
                } else {
                    fatalError()
                }
            case let .starGift(starGift, _):
                finalPrice = starGift.price
                if self.includeUpgrade, let upgradeStars = starGift.upgradeStars  {
                    finalPrice += upgradeStars
                }
                source = .starGift(hideName: self.hideName, includeUpgrade: self.includeUpgrade, peerId: peerId, giftId: starGift.id, text: self.textInputState.text.string, entities: entities)
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
                                text: presentationData.strings.Gift_Send_Success(self.peerMap[peerId]?.compactDisplayTitle ?? "", presentationData.strings.Gift_Send_Success_Stars(Int32(starGift.price))).string,
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
                    }
                    
                    if let completion {
                        completion()
                        
                        if let controller = self.environment?.controller() {
                            controller.dismiss()
                        }
                    }
                    
                    starsContext.load(force: true)
                }, error: { [weak self] error in
                    guard let self, let controller = self.environment?.controller() else {
                        return
                    }
                    
                    self.inProgress = false
                    self.state?.updated()
                    
                    var errorText: String?
                    switch error {
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
            
            self.currentInputMode = .keyboard
            if hasFirstResponder(self) {
                if let titleView = self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View {
                    if titleView.isActive {
                        titleView.deactivateInput()
                    } else {
                        self.endEditing(true)
                    }
                }
            } else {
                self.state?.updated(transition: .spring(duration: 0.4))
            }
        }
        
        func update(component: GiftSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let peerName = self.peerMap[component.peerId]?.compactDisplayTitle ?? ""
            let isSelfGift = component.peerId == component.context.account.peerId
            let isChannelGift = component.peerId.namespace == Namespaces.Peer.CloudChannel
            
            if self.component == nil {
                if isSelfGift {
                    self.hideName = true
                }
                
                if case let .starGift(gift, true) = component.subject, gift.upgradeStars != nil {
                    self.includeUpgrade = true
                }
                
                let _ = (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.peerId),
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId),
                    TelegramEngine.EngineData.Item.Peer.SendPaidMessageStars(id: component.peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] peer, accountPeer, sendPaidMessageStars in
                    guard let self else {
                        return
                    }
                    if let peer {
                        self.peerMap[peer.id] = peer
                    }
                    if let accountPeer {
                        self.peerMap[accountPeer.id] = accountPeer
                    }
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
                        self.currentInputMode = .keyboard
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    dismissTextInput: {
                    },
                    insertText: { [weak self] text in
                        guard let self else {
                            return
                        }
                        if let textInputView = self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View {
                            textInputView.insertText(text: text)
                        }
                    },
                    backwardsDeleteText: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let textInputView = self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View {
                            if self.textInputState.isEditing {
                                textInputView.backwardsDeleteText()
                            }
                        }
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
                            |> map(Optional.init)
                        )
                    }
                }
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                             
            let navigationTitleString: String
            if isSelfGift {
                navigationTitleString = environment.strings.Gift_SendSelf_Title
            } else if isChannelGift {
                navigationTitleString = environment.strings.Gift_SendChannel_Title
            } else {
                navigationTitleString = environment.strings.Gift_Send_TitleTo(peerName).string
            }
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: navigationTitleString, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - navigationTitleSize.width) / 2.0), y: environment.statusBarHeight + floor((environment.navigationHeight - environment.statusBarHeight - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.addSubview(navigationTitleView)
                    }
                }
                transition.setFrame(view: navigationTitleView, frame: navigationTitleFrame)
            }
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            contentHeight += 26.0
            
            if case let .starGift(starGift, _) = component.subject, let availability = starGift.availability {
                let remains: Int32 = availability.remains
                let total: Int32 = availability.total
                let position = CGFloat(remains) / CGFloat(total)
                let sold = total - remains
                let remainingCountSize = self.remainingCount.update(
                    transition: transition,
                    component: AnyComponent(RemainingCountComponent(
                        inactiveColor: environment.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3),
                        activeColors: [UIColor(rgb: 0x5bc2ff), UIColor(rgb: 0x2d9eff)],
                        inactiveTitle: environment.strings.Gift_Send_Remains(remains),
                        inactiveValue: "",
                        inactiveTitleColor: environment.theme.list.itemSecondaryTextColor,
                        activeTitle: "",
                        activeValue: environment.strings.Gift_Send_Sold(sold),//totalString,
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
                let remainingCountFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight - 77.0), size: remainingCountSize)
                if let remainingCountView = self.remainingCount.view {
                    if remainingCountView.superview == nil {
                        self.scrollView.addSubview(remainingCountView)
                    }
                    transition.setFrame(view: remainingCountView, frame: remainingCountFrame)
                }
                contentHeight += remainingCountSize.height
                contentHeight -= 77.0
                contentHeight += sectionSpacing
            }
            
            if case let .starGift(starGift, forceUnique) = component.subject, let availability = starGift.availability, availability.resale > 0 {
                if let forceUnique, !forceUnique {
                } else {
                    let resaleSectionSize = self.resaleSection.update(
                        transition: transition,
                        component: AnyComponent(ListSectionComponent(
                            theme: environment.theme,
                            header: nil,
                            footer: nil,
                            items: [
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                    theme: environment.theme,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(
                                            MultilineTextComponent(
                                                text: .plain(NSAttributedString(string: environment.strings.Gift_Send_AvailableForResale, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: environment.theme.list.itemPrimaryTextColor))
                                            )
                                        )),
                                    ], alignment: .left, spacing: 2.0)),
                                    accessory: .custom(ListActionItemComponent.CustomAccessory(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: presentationStringsFormattedNumber(Int32(availability.resale), environment.dateTimeFormat.groupingSeparator),
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: environment.theme.list.itemSecondaryTextColor
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
                            self.scrollView.addSubview(resaleSectionView)
                        }
                        transition.setFrame(view: resaleSectionView, frame: resaleSectionFrame)
                    }
                    contentHeight += resaleSectionSize.height
                    contentHeight += sectionSpacing
                }
            }
            
            let giftConfiguration = GiftConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
               
            var introSectionItems: [AnyComponentWithIdentity<Empty>] = []
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(Rectangle(color: .clear, height: 346.0, tag: self.introPlaceholderTag))))
            
            if self.sendPaidMessageStars == nil {
                introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListMultilineTextFieldItemComponent(
                    externalState: self.textInputState,
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    initialText: "",
                    resetText: self.resetText.flatMap {
                        return ListMultilineTextFieldItemComponent.ResetText(value: $0)
                    },
                    placeholder: environment.strings.Gift_Send_Customize_MessagePlaceholder,
                    autocapitalizationType: .sentences,
                    autocorrectionType: .yes,
                    returnKeyType: .done,
                    characterLimit: Int(giftConfiguration.maxCaptionLength),
                    displayCharacterLimit: true,
                    emptyLineHandling: .notAllowed,
                    formatMenuAvailability: .available([.bold, .italic, .underline, .strikethrough, .spoiler]),
                    updated: { _ in
                    },
                    returnKeyAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let titleView = self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View {
                            titleView.endEditing(true)
                        }
                    },
                    textUpdateTransition: .spring(duration: 0.4),
                    inputMode: self.currentInputMode,
                    toggleInputMode: { [weak self] in
                        guard let self else {
                            return
                        }
                        switch self.currentInputMode {
                        case .keyboard:
                            self.currentInputMode = .emoji
                        case .emoji:
                            self.currentInputMode = .keyboard
                        }
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    tag: self.textInputTag
                ))))
                self.resetText = nil
            }
            
            let footerAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
            
            let introFooter: AnyComponent<Empty>?
            switch component.subject {
            case .premium:
                introFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Gift_Send_Customize_Info(peerName).string,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: environment.theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                ))
            case .starGift:
                introFooter = nil
            }
                          
            let introSectionSize = self.introSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: introFooter,
                    items: introSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let introSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: introSectionSize)
            if let introSectionView = self.introSection.view {
                if introSectionView.superview == nil {
                    self.scrollView.addSubview(introSectionView)
                    self.introSection.parentState = state
                }
                transition.setFrame(view: introSectionView, frame: introSectionFrame)
            }
            contentHeight += introSectionSize.height
            contentHeight += sectionSpacing
            
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
                if environment.inputHeight.isZero && self.textInputState.isEditing, let previousInputHeight = self.previousInputHeight {
                    inputHeight = previousInputHeight
                } else {
                    inputHeight = environment.inputHeight
                }
            }
                         
            let listItemParams = ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            if let accountPeer = self.peerMap[component.context.account.peerId] {
                var upgradeStars: Int64?
                let subject: ChatGiftPreviewItem.Subject
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
                }
                
                var peers: [EnginePeer] = [accountPeer]
                if let peer = self.peerMap[component.peerId] {
                    peers.append(peer)
                }
                
                let introContentSize = self.introContent.update(
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
                                text: self.textInputState.text.string,
                                entities: generateChatInputTextEntities(self.textInputState.text),
                                upgradeStars: self.includeUpgrade ? upgradeStars : nil,
                                chargeStars: self.textInputState.text.string.isEmpty ? nil : 250
                            ),
                            params: listItemParams
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                if let introContentView = self.introContent.view {
                    if introContentView.superview == nil {
                        if let placeholderView = self.introSection.findTaggedView(tag: self.introPlaceholderTag) {
                            placeholderView.addSubview(introContentView)
                            
                            placeholderView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.previewTap)))
                        }
                    }
                    transition.setFrame(view: introContentView, frame: CGRect(origin: CGPoint(), size: introContentSize))
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
                        self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
                    }
                    if let range = starsFooterText.string.range(of: "#") {
                        starsFooterText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: starsFooterText.string))
                    }
                    if let range = starsFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                        starsFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: starsFooterText.string))
                    }
                    
                    let priceString = presentationStringsFormattedNumber(Int32(starsPrice), environment.dateTimeFormat.groupingSeparator)
                    let starsAttributedText = NSMutableAttributedString(string: environment.strings.Gift_Send_PayWithStars("#\(priceString)").string, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: environment.theme.list.itemPrimaryTextColor)
                    let range = (starsAttributedText.string as NSString).range(of: "#")
                    if range.location != NSNotFound {
                        starsAttributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                        starsAttributedText.addAttribute(.baselineOffset, value: 1.0, range: range)
                    }
                    
                    let starsSectionSize = self.starsSection.update(
                        transition: transition,
                        component: AnyComponent(ListSectionComponent(
                            theme: environment.theme,
                            header: nil,
                            footer: AnyComponent(MultilineTextWithEntitiesComponent(
                                context: component.context,
                                animationCache: component.context.animationCache,
                                animationRenderer: component.context.animationRenderer,
                                placeholderColor: .clear,
                                text: .plain(starsFooterText),
                                maximumNumberOfLines: 0,
                                highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
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
                                        let purchaseController = component.context.sharedContext.makeStarsPurchaseScreen(context: component.context, starsContext: starsContext, options: options ?? [], purpose: .generic, completion: { stars in
                                            starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                                        })
                                        controller.push(purchaseController)
                                    })
                                }
                            )),
                            items: [
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                    theme: environment.theme,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(
                                            MultilineTextWithEntitiesComponent(
                                                context: component.context,
                                                animationCache: component.context.animationCache,
                                                animationRenderer: component.context.animationRenderer,
                                                placeholderColor: environment.theme.list.mediaPlaceholderColor,
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
                            self.scrollView.addSubview(starsSectionView)
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
                        self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
                    }
                    if let range = upgradeFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                        upgradeFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: upgradeFooterText.string))
                    }
                    
                    let upgradeAttributedText = NSMutableAttributedString(string: environment.strings.Gift_Send_Upgrade("#\(upgradeStars)").string, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: environment.theme.list.itemPrimaryTextColor)
                    let range = (upgradeAttributedText.string as NSString).range(of: "#")
                    if range.location != NSNotFound {
                        upgradeAttributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                        upgradeAttributedText.addAttribute(.baselineOffset, value: 1.0, range: range)
                    }
                    
                    let upgradeSectionSize = self.upgradeSection.update(
                        transition: transition,
                        component: AnyComponent(ListSectionComponent(
                            theme: environment.theme,
                            header: nil,
                            footer: AnyComponent(MultilineTextComponent(
                                text: .plain(upgradeFooterText),
                                maximumNumberOfLines: 0,
                                highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
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
                                    |> deliverOnMainQueue).start(next: { [weak self] attributes in
                                        guard let self, let component = self.component, let controller = self.environment?.controller(), let attributes else {
                                            return
                                        }
                                        let previewController = GiftViewScreen(
                                            context: component.context,
                                            subject: .upgradePreview(attributes, peerName)
                                        )
                                        controller.push(previewController)
                                    })
                                }
                            )),
                            items: [
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                    theme: environment.theme,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(
                                            MultilineTextWithEntitiesComponent(
                                                context: component.context,
                                                animationCache: component.context.animationCache,
                                                animationRenderer: component.context.animationRenderer,
                                                placeholderColor: environment.theme.list.mediaPlaceholderColor,
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
                            self.scrollView.addSubview(upgradeSectionView)
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
                        theme: environment.theme,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: hideSectionFooterString,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: isSelfGift ? environment.strings.Gift_SendSelf_HideMyName : environment.strings.Gift_Send_HideMyName,
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: environment.theme.list.itemPrimaryTextColor
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
                        self.scrollView.addSubview(hideSectionView)
                    }
                    transition.setFrame(view: hideSectionView, frame: hideSectionFrame)
                }
                contentHeight += hideSectionSize.height
            }
                
            contentHeight += 24.0
            
            let buttonHeight: CGFloat = 50.0
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            let bottomPanelHeight = bottomPanelPadding + buttonHeight + bottomInset
            
            let combinedBottomInset = max(inputHeight, environment.safeInsets.bottom)
            contentHeight += max(bottomPanelHeight, combinedBottomInset)
            
            if self.starImage == nil || self.starImage?.1 !== environment.theme {
                self.starImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: environment.theme.list.itemCheckColors.foregroundColor)!, environment.theme)
            }

            let bottomPanelSize = self.buttonBackground.update(
                transition: transition,
                component: AnyComponent(BlurredBackgroundComponent(
                    color: environment.theme.rootController.tabBar.backgroundColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: bottomPanelHeight)
            )
            self.buttonSeparator.backgroundColor = environment.theme.rootController.tabBar.separatorColor.cgColor
            
            if let view = self.buttonBackground.view {
                if view.superview == nil {
                    self.addSubview(view)
                    self.layer.addSublayer(self.buttonSeparator)
                }
                view.frame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelSize.height), size: bottomPanelSize)
                self.buttonSeparator.frame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelSize.height), size: CGSize(width: availableSize.width, height: UIScreenPixel))
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
            
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = self.starImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: environment.theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0,
                        isShimmering: true
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(buttonString),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: buttonIsEnabled,
                    displaysProgress: self.inProgress,
                    action: { [weak self] in
                        self?.proceed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: buttonHeight)
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                buttonView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - buttonSize.width) / 2.0), y: availableSize.height - bottomPanelHeight + bottomPanelPadding), size: buttonSize)
            }
            
            let controller = environment.controller()
            if inputHeight > 10.0 {
                if self.inProgress {
                    let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: environment.theme.rootController.navigationBar.accentTextColor))
                    controller?.navigationItem.rightBarButtonItem = item
                } else {
                    let rightBarButtonItem = UIBarButtonItem(title: environment.strings.Gift_Send_SendShort, style: .done, target: self, action: #selector(self.proceed))
                    rightBarButtonItem.isEnabled = buttonIsEnabled
                    controller?.navigationItem.setRightBarButton(rightBarButtonItem, animated: controller?.navigationItem.rightBarButtonItem == nil)
                }
            } else {
                controller?.navigationItem.setRightBarButton(nil, animated: true)
            }
            
            if self.textInputState.isEditing, let emojiSuggestion = self.textInputState.currentEmojiSuggestion, emojiSuggestion.disposable == nil {
                emojiSuggestion.disposable = (EmojiSuggestionsComponent.suggestionData(context: component.context, isSavedMessages: false, query: emojiSuggestion.position.value)
                |> deliverOnMainQueue).start(next: { [weak self, weak emojiSuggestion] result in
                    guard let self, self.textInputState.currentEmojiSuggestion === emojiSuggestion else {
                        return
                    }
                    
                    emojiSuggestion?.value = result
                    self.state?.updated()
                })
            }
            
            var hasTrackingView = self.textInputState.hasTrackingView
            if let currentEmojiSuggestion = self.textInputState.currentEmojiSuggestion, let value = currentEmojiSuggestion.value as? [TelegramMediaFile], value.isEmpty {
                hasTrackingView = false
            }
            if !self.textInputState.isEditing {
                hasTrackingView = false
            }
            
            if !hasTrackingView {
                if let currentEmojiSuggestion = self.textInputState.currentEmojiSuggestion {
                    self.textInputState.currentEmojiSuggestion = nil
                    currentEmojiSuggestion.disposable?.dispose()
                }
                
                if let currentEmojiSuggestionView = self.currentEmojiSuggestionView {
                    self.currentEmojiSuggestionView = nil
                    
                    currentEmojiSuggestionView.alpha = 0.0
                    currentEmojiSuggestionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak currentEmojiSuggestionView] _ in
                        currentEmojiSuggestionView?.removeFromSuperview()
                    })
                }
            }
                        
            if self.textInputState.isEditing, let emojiSuggestion = self.textInputState.currentEmojiSuggestion, let value = emojiSuggestion.value as? [TelegramMediaFile] {
                let currentEmojiSuggestionView: ComponentHostView<Empty>
                if let current = self.currentEmojiSuggestionView {
                    currentEmojiSuggestionView = current
                } else {
                    currentEmojiSuggestionView = ComponentHostView<Empty>()
                    self.currentEmojiSuggestionView = currentEmojiSuggestionView
                    self.addSubview(currentEmojiSuggestionView)
                    
                    currentEmojiSuggestionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            
                let globalPosition: CGPoint
                if let textView = (self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View)?.textFieldView  {
                    globalPosition = textView.convert(emojiSuggestion.localPosition, to: self)
                } else {
                    globalPosition = .zero
                }
                
                let sideInset: CGFloat = 7.0
                
                let viewSize = currentEmojiSuggestionView.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiSuggestionsComponent(
                        context: component.context,
                        userLocation: .other,
                        theme: EmojiSuggestionsComponent.Theme(theme: environment.theme, backgroundColor: environment.theme.list.itemBlocksBackgroundColor),
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        files: value,
                        action: { [weak self] file in
                            guard let self, let textView = (self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View)?.textFieldView, let currentEmojiSuggestion = self.textInputState.currentEmojiSuggestion else {
                                return
                            }
                            
                            AudioServicesPlaySystemSound(0x450)
                            
                            let inputState = textView.getInputState()
                            let inputText = NSMutableAttributedString(attributedString: inputState.inputText)
                            
                            var text: String?
                            var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                            loop: for attribute in file.attributes {
                                switch attribute {
                                case let .CustomEmoji(_, _, displayText, _):
                                    text = displayText
                                    emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                                    break loop
                                default:
                                    break
                                }
                            }
                            
                            if let emojiAttribute = emojiAttribute, let text = text {
                                let replacementText = NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute])
                                
                                let range = currentEmojiSuggestion.position.range
                                let previousText = inputText.attributedSubstring(from: range)
                                inputText.replaceCharacters(in: range, with: replacementText)
                                
                                var replacedUpperBound = range.lowerBound
                                while true {
                                    if inputText.attributedSubstring(from: NSRange(location: 0, length: replacedUpperBound)).string.hasSuffix(previousText.string) {
                                        let replaceRange = NSRange(location: replacedUpperBound - previousText.length, length: previousText.length)
                                        if replaceRange.location < 0 {
                                            break
                                        }
                                        let adjacentString = inputText.attributedSubstring(from: replaceRange)
                                        if adjacentString.string != previousText.string || adjacentString.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) != nil {
                                            break
                                        }
                                        inputText.replaceCharacters(in: replaceRange, with: NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: emojiAttribute.interactivelySelectedFromPackId, fileId: emojiAttribute.fileId, file: emojiAttribute.file)]))
                                        replacedUpperBound = replaceRange.lowerBound
                                    } else {
                                        break
                                    }
                                }
                                
                                let selectionPosition = range.lowerBound + (replacementText.string as NSString).length
                                textView.updateText(inputText, selectionRange: selectionPosition ..< selectionPosition)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                
                let viewFrame = CGRect(origin: CGPoint(x: min(availableSize.width - sideInset - viewSize.width, max(sideInset, floor(globalPosition.x - viewSize.width / 2.0))), y: globalPosition.y - 4.0 - viewSize.height), size: viewSize)
                currentEmojiSuggestionView.frame = viewFrame
                if let componentView = currentEmojiSuggestionView.componentView as? EmojiSuggestionsComponent.View {
                    componentView.adjustBackground(relativePositionX: floor(globalPosition.x + 10.0))
                }
            }

            let previousBounds = self.scrollView.bounds
            
            self.recenterOnTag = nil
            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), let targetView = hint.view {
                if let textView = self.introSection.findTaggedView(tag: self.textInputTag) {
                    if targetView.isDescendant(of: textView) {
                        self.recenterOnTag = self.textInputTag
                    }
                }
            }
            if self.recenterOnTag == nil && self.previousHadInputHeight != (environment.inputHeight > 0.0), case .keyboard = self.currentInputMode {
                if self.textInputState.isEditing {
                    self.recenterOnTag = self.textInputTag
                }
            }
            self.previousHadInputHeight = inputHeight > 0.0
            self.previousInputHeight = inputHeight
            
            self.ignoreScrolling = true
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            if let recenterOnTag = self.recenterOnTag {
                self.recenterOnTag = nil
                
                if let targetView = self.introSection.findTaggedView(tag: recenterOnTag) {
                    let caretRect = targetView.convert(targetView.bounds, to: self.scrollView)
                    var scrollViewBounds = self.scrollView.bounds
                    let minButtonDistance: CGFloat = 16.0
                    if -scrollViewBounds.minY + caretRect.maxY > availableSize.height - combinedBottomInset - minButtonDistance {
                        scrollViewBounds.origin.y = -(availableSize.height - combinedBottomInset - minButtonDistance - caretRect.maxY)
                        if scrollViewBounds.origin.y < 0.0 {
                            scrollViewBounds.origin.y = 0.0
                        }
                    }
                    if self.scrollView.bounds != scrollViewBounds {
                        transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
                    }
                }
            }
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return availableSize
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
                    importState: nil,
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
                            if self.currentInputMode == .keyboard {
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
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class GiftSetupScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case premium(PremiumGiftProduct)
        case starGift(StarGift.Gift, Bool?)
    }
    
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        subject: Subject,
        completion: (() -> Void)? = nil
    ) {
        self.context = context
        
        super.init(context: context, component: GiftSetupScreenComponent(
            context: context,
            peerId: peerId,
            subject: subject,
            completion: completion
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        self.title = ""
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? GiftSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
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

public struct PremiumGiftProduct: Equatable {
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
}
