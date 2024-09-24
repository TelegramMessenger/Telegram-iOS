import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
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

final class GiftSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let gift: StarGift

    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        gift: StarGift
    ) {
        self.context = context
        self.peerId = peerId
        self.gift = gift
    }

    static func ==(lhs: GiftSetupScreenComponent, rhs: GiftSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.gift != rhs.gift {
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
        private let introContent = ComponentView<Empty>()
        private let introSection = ComponentView<Empty>()
        private let hideSection = ComponentView<Empty>()
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
        
        private var hideName = false
        
        private var previousHadInputHeight: Bool = false
        private var recenterOnTag: NSObject?
                
        private var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        
        private var starImage: (UIImage, PresentationTheme)?
        
        private var optionsDisposable: Disposable?
        private(set) var options: [StarsTopUpOption] = [] {
            didSet {
                self.optionsPromise.set(self.options)
            }
        }
        private let optionsPromise = ValuePromise<[StarsTopUpOption]?>(nil)
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
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
        }
        
        func proceed() {
            guard let component = self.component, let starsContext = component.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
            
            let proceed = { [weak self] in
                guard let self else {
                    return
                }
                let source: BotPaymentInvoiceSource = .starGift(hideName: self.hideName, peerId: component.peerId, giftId: component.gift.id, text: self.textInputState.text.string, entities: [])
                let inputData = BotCheckoutController.InputData.fetch(context: component.context, source: source)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                    return .single(nil)
                }
                
                let _ = (inputData
                |> deliverOnMainQueue).startStandalone(next: { [weak self] inputData in
                    guard let inputData else {
                        return
                    }
                    let _ = (component.context.engine.payments.sendStarsPaymentForm(formId: inputData.form.id, source: source)
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let self, let controller = self.environment?.controller(), let navigationController = controller.navigationController as? NavigationController else {
                            return
                        }
                        
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { !($0 is GiftSetupScreen) && !($0 is GiftOptionsScreenProtocol) }
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
                    })
                })
            }
            
            if starsState.balance < component.gift.price {
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
                        purpose: .starGift(peerId: component.peerId, requiredStars: component.gift.price),
                        completion: { [weak starsContext] stars in
                            starsContext?.add(balance: stars)
                            Queue.mainQueue().after(0.1) {
                                proceed()
                            }
                        }
                    )
                    controller.push(purchaseController)
                })
            } else {
                proceed()
            }
        }
        
        func update(component: GiftSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                let _ = (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.peerId),
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] peer, accountPeer in
                    guard let self else {
                        return
                    }
                    if let peer {
                        self.peerMap[peer.id] = peer
                    }
                    if let accountPeer {
                        self.peerMap[accountPeer.id] = accountPeer
                    }
                    
                    self.state?.updated()
                })
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition
            if !transition.animation.isImmediate {
                alphaTransition = .easeInOut(duration: 0.25)
            } else {
                alphaTransition = .immediate
            }
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let _ = alphaTransition
            let _ = presentationData
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Send a Gift", font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
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
            
            let bottomContentInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            contentHeight += 26.0
            
            self.recenterOnTag = nil
            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), let targetView = hint.view {
                if let textView = self.introSection.findTaggedView(tag: self.textInputTag) {
                    if targetView.isDescendant(of: textView) {
                        self.recenterOnTag = self.textInputTag
                    }
                }
            }
            
            var introSectionItems: [AnyComponentWithIdentity<Empty>] = []
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(Rectangle(color: .clear, height: 346.0, tag: self.introPlaceholderTag))))
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: self.textInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetText.flatMap {
                    return ListMultilineTextFieldItemComponent.ResetText(value: $0)
                },
                placeholder: environment.strings.Business_Intro_IntroTextPlaceholder,
                autocapitalizationType: .none,
                autocorrectionType: .no,
                returnKeyType: .done,
                characterLimit: 70,
                displayCharacterLimit: true,
                emptyLineHandling: .notAllowed,
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
                tag: self.textInputTag
            ))))
            self.resetText = nil
            
            let introSectionSize = self.introSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "CUSTOMIZE YOUR GIFT",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
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
            
//            let titleText: String
//            if self.titleInputState.text.string.isEmpty {
//                titleText = environment.strings.Conversation_EmptyPlaceholder
//            } else {
//                let rawTitle = self.titleInputState.text.string
//                titleText = rawTitle.count <= maxTitleLength ? rawTitle : String(rawTitle[rawTitle.startIndex ..< rawTitle.index(rawTitle.startIndex, offsetBy: maxTitleLength)])
//            }
            
//            let textText: String
//            if self.textInputState.text.string.isEmpty {
//                textText = environment.strings.Conversation_GreetingText
//            } else {
//                let rawText = self.textInputState.text.string
//                textText = rawText.count <= maxTextLength ? rawText : String(rawText[rawText.startIndex ..< rawText.index(rawText.startIndex, offsetBy: maxTextLength)])
//            }
            
            let listItemParams = ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
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
                            accountPeer: self.peerMap[component.context.account.peerId],
                            gift: component.gift,
                            text: self.textInputState.text.string
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
                    }
                }
                transition.setFrame(view: introContentView, frame: CGRect(origin: CGPoint(), size: introContentSize))
            }
            
            if self.recenterOnTag == nil && self.previousHadInputHeight != (environment.inputHeight > 0.0) {
                if self.textInputState.isEditing {
                    self.recenterOnTag = self.textInputTag
                }
            }
            self.previousHadInputHeight = environment.inputHeight > 0.0
    
            let peerName = self.peerMap[component.peerId]?.compactDisplayTitle ?? ""
            let hideSectionSize = self.hideSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Hide my name and message from visitors to \(peerName)'s profile. \(peerName) will still see your name and message.",
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
                                        string: "Hide My Name",
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
            
            contentHeight += bottomContentInset
            
            let inputHeight: CGFloat = environment.inputHeight
            let combinedBottomInset = max(inputHeight, environment.safeInsets.bottom)
            contentHeight += combinedBottomInset
            
            
            if self.starImage == nil || self.starImage?.1 !== environment.theme {
                self.starImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: environment.theme.list.itemCheckColors.foregroundColor)!, environment.theme)
            }
            let amountString = presentationStringsFormattedNumber(Int32(component.gift.price), presentationData.dateTimeFormat.groupingSeparator)
            let buttonAttributedString = NSMutableAttributedString(string: "Send a Gift for   #  \(amountString)", font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = self.starImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: environment.theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        self?.proceed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50)
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                buttonView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - buttonSize.width) / 2.0), y: availableSize.height - environment.safeInsets.bottom - buttonSize.height), size: buttonSize)
            }
            
            let previousBounds = self.scrollView.bounds
            
            self.ignoreScrolling = true
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
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
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class GiftSetupScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        gift: StarGift
    ) {
        self.context = context
        
        super.init(context: context, component: GiftSetupScreenComponent(
            context: context,
            peerId: peerId,
            gift: gift
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        self.title = ""
        //self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
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
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
}
