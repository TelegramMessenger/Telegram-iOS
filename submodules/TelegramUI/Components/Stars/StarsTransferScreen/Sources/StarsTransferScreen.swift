import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import ItemListUI
import UndoUI
import AccountContext
import PresentationDataUtils
import StarsImageComponent
import ConfettiEffect
import PremiumPeerShortcutComponent
import StarsBalanceOverlayComponent
import PlainButtonComponent
import GlassBarButtonComponent
import TelegramStringFormatting

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let starsContext: StarsContext
    let invoice: TelegramMediaInvoice
    let source: BotPaymentInvoiceSource
    let extendedMedia: [TelegramExtendedMedia]
    let inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>
    let navigateToPeer: ((EnginePeer) -> Void)?
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        invoice: TelegramMediaInvoice,
        source: BotPaymentInvoiceSource,
        extendedMedia: [TelegramExtendedMedia],
        inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>,
        navigateToPeer: ((EnginePeer) -> Void)?,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.starsContext = starsContext
        self.invoice = invoice
        self.source = source
        self.extendedMedia = extendedMedia
        self.inputData = inputData
        self.navigateToPeer = navigateToPeer
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.invoice != rhs.invoice {
            return false
        }
        if lhs.extendedMedia != rhs.extendedMedia {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedStarImage: (UIImage, PresentationTheme)?
        
        private let context: AccountContext
        private let starsContext: StarsContext
        private let source: BotPaymentInvoiceSource
        private let extendedMedia: [TelegramExtendedMedia]
        private let invoice: TelegramMediaInvoice
        
        private(set) var botPeer: EnginePeer?
        private(set) var chatPeer: EnginePeer?
        private(set) var authorPeer: EnginePeer?
        private var peerDisposable: Disposable?
        private(set) var balance: StarsAmount?
        private(set) var form: BotPaymentForm?
        private(set) var navigateToPeer: ((EnginePeer) -> Void)?
        
        private var stateDisposable: Disposable?
        
        private var optionsDisposable: Disposable?
        private(set) var options: [StarsTopUpOption] = [] {
            didSet {
                self.optionsPromise.set(self.options)
            }
        }
        private let optionsPromise = ValuePromise<[StarsTopUpOption]?>(nil)
        
        var inProgress = false
        
        init(
            context: AccountContext,
            starsContext: StarsContext,
            source: BotPaymentInvoiceSource,
            extendedMedia: [TelegramExtendedMedia],
            invoice: TelegramMediaInvoice,
            inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>,
            navigateToPeer: ((EnginePeer) -> Void)?
        ) {
            self.context = context
            self.starsContext = starsContext
            self.source = source
            self.extendedMedia = extendedMedia
            self.invoice = invoice
            self.navigateToPeer = navigateToPeer
            
            super.init()
            
            let chatPeer: Signal<EnginePeer?, NoError>
            if case let .message(messageId) = source {
                chatPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
            } else {
                chatPeer = .single(nil)
            }
            
            self.peerDisposable = (combineLatest(
                inputData,
                chatPeer
            )
            |> deliverOnMainQueue).start(next: { [weak self] inputData, chatPeer in
                guard let self else {
                    return
                }
                self.balance = inputData?.0.balance ?? StarsAmount.zero
                self.form = inputData?.1
                self.botPeer = inputData?.2
                self.chatPeer = chatPeer
                self.authorPeer = inputData?.3
                self.updated(transition: .immediate)
                
                if self.optionsDisposable == nil, let balance = self.balance, balance < StarsAmount(value: self.invoice.totalAmount, nanos: 0) {
                    self.optionsDisposable = (context.engine.payments.starsTopUpOptions()
                    |> deliverOnMainQueue).start(next: { [weak self] options in
                        guard let self else {
                            return
                        }
                        self.options = options
                    })
                }
            })
            
            self.stateDisposable = (starsContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                self.balance = state?.balance
                self.updated(transition: .immediate)
            })
        }
        
        deinit {
            self.peerDisposable?.dispose()
            self.stateDisposable?.dispose()
            self.optionsDisposable?.dispose()
        }
        
        func buy(requestTopUp: @escaping (@escaping () -> Void) -> Void, completion: @escaping (Bool) -> Void) {
            guard let form, let balance else {
                return
            }
            
            let navigateToPeer = self.navigateToPeer
            let action = { [weak self] in
                guard let self else {
                    return
                }
                self.inProgress = true
                self.updated()
                
                let _ = (self.context.engine.payments.sendStarsPaymentForm(formId: form.id, source: self.source)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    completion(true)
                    if case let .starsChatSubscription(link) = self.source {
                        let _ = (self.context.engine.peers.joinLinkInformation(link)
                        |> deliverOnMainQueue).startStandalone(next: { result in
                            if case let .alreadyJoined(peer) = result {
                                navigateToPeer?(peer)
                            }
                        })
                    }
                }, error: { [weak self] error in
                    guard let self else {
                        return
                    }
                    switch error {
                    case .alreadyPaid:
                        if !self.extendedMedia.isEmpty, case let .message(messageId) = self.source  {
                            let _ = self.context.engine.messages.updateExtendedMedia(messageIds: [messageId]).startStandalone()
                        }
                    default:
                        break
                    }
                    completion(false)
                })
            }
            
            if balance < StarsAmount(value: self.invoice.totalAmount, nanos: 0) {
                if self.options.isEmpty {
                    self.inProgress = true
                    self.updated()
                }
                let _ = (self.optionsPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                    if let self {
                        self.inProgress = false
                        self.updated()
                    
                        requestTopUp({ [weak self] in
                            guard let self else {
                                return
                            }
                            self.inProgress = true
                            self.updated()
                            
                            let _ = (self.starsContext.state
                            |> filter { state in
                                if let state {
                                    return !state.flags.contains(.isPendingBalance)
                                }
                                return false
                            }
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { _ in
                                Queue.mainQueue().after(0.1, { [weak self] in
                                    if let self, let balance = self.balance, balance < StarsAmount(value: self.invoice.totalAmount, nanos: 0) {
                                        self.inProgress = false
                                        self.updated()
                                        
                                        self.buy(requestTopUp: requestTopUp, completion: completion)
                                    } else {
                                        action()
                                    }
                                })
                            })
                        })
                    }
                })
            } else {
                action()
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, starsContext: self.starsContext, source: self.source, extendedMedia: self.extendedMedia, invoice: self.invoice, inputData: self.inputData, navigateToPeer: self.navigateToPeer)
    }
        
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let star = Child(StarsImageComponent.self)
        let closeButton = Child(GlassBarButtonComponent.self)
        let title = Child(Text.self)
        let peerShortcut = Child(PlainButtonComponent.self)
        
        let text = Child(BalancedTextComponent.self)
        let button = Child(ButtonComponent.self)
        let balanceTitle = Child(MultilineTextComponent.self)
        let balanceValue = Child(MultilineTextComponent.self)
        let balanceIcon = Child(BundleIconComponent.self)
        let info = Child(BalancedTextComponent.self)

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme
            let strings = presentationData.strings
                        
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.actionSheet.opaqueItemBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            var isExtendedMedia = false
            let subject: StarsImageComponent.Subject
            if !component.extendedMedia.isEmpty {
                subject = .extendedMedia(component.extendedMedia)
                isExtendedMedia = true
            } else if let peer = state.botPeer {
                if let photo = component.invoice.photo {
                    subject = .photo(photo)
                } else {
                    subject = .transactionPeer(.peer(peer))
                }
            } else {
                subject = .none
            }
            
            var isBot = false
            if case let .user(user) = state.botPeer, user.botInfo != nil {
                isBot = true
            }
            
            var isSubscription = false
            if case .starsChatSubscription = component.source {
                isSubscription = true
            } else if let _ = component.invoice.subscriptionPeriod {
                isSubscription = true
            }
            let star = star.update(
                component: StarsImageComponent(
                    context: component.context,
                    subject: subject,
                    theme: theme,
                    diameter: 90.0,
                    backgroundColor: theme.actionSheet.opaqueItemBackgroundColor,
                    icon: isSubscription && !isBot ? .star : nil,
                    value: isBot ? component.invoice.totalAmount : nil
                ),
                availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                transition: context.transition
            )
            context.add(star
                .position(CGPoint(x: context.availableSize.width / 2.0, y: star.size.height / 2.0 - 27.0))
            )
            
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { _ in
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )

            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            contentSize.height += 126.0
            
            let titleString: String
            if isSubscription {
                if isBot {
                    titleString = component.invoice.title
                } else {
                    titleString = strings.Stars_Transfer_Subscribe_Channel_Title
                }
            } else {
                titleString = strings.Stars_Transfer_Title
            }
            
            let title = title.update(
                component: Text(text: titleString, font: Font.bold(24.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 13.0
            
            if isBot && !isExtendedMedia, let peer = state.botPeer {
                contentSize.height -= 3.0
                let peerShortcut = peerShortcut.update(
                    component: PlainButtonComponent(
                        content: AnyComponent(
                            PremiumPeerShortcutComponent(
                                context: component.context,
                                theme: theme,
                                peer: peer
                            )
                        ),
                        action: {
                            component.navigateToPeer?(peer)
                        },
                        animateAlpha: component.navigateToPeer != nil,
                        animateScale: false
                    ),
                    availableSize: CGSize(width: context.availableSize.width - 32.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(peerShortcut
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + peerShortcut.size.height / 2.0))
                )
                contentSize.height += peerShortcut.size.height
                contentSize.height += 13.0
            }
                        
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let amount = component.invoice.totalAmount
            let infoText: String
            if case .starsChatSubscription = context.component.source {
                infoText = strings.Stars_Transfer_SubscribeInfo(state.botPeer?.compactDisplayTitle ?? "", strings.Stars_Transfer_Info_Stars(Int32(clamping: amount))).string
            } else if let _ = component.invoice.subscriptionPeriod {
                infoText = strings.Stars_Transfer_BotSubscribeInfo(component.invoice.title, state.botPeer?.compactDisplayTitle ?? "", strings.Stars_Transfer_BotSubscribeInfo_Stars(Int32(clamping: amount))).string
            } else if !component.extendedMedia.isEmpty {
                var description: String = ""
                var photoCount: Int32 = 0
                var videoCount: Int32 = 0
                for media in component.extendedMedia {
                    if case let .preview(_, _, videoDuration) = media, videoDuration != nil {
                        videoCount += 1
                    } else {
                        photoCount += 1
                    }
                }
                if photoCount > 0 && videoCount > 0 {
                    description = strings.Stars_Transfer_MediaAnd("**\(strings.Stars_Transfer_Photos(photoCount))**", "**\(strings.Stars_Transfer_Videos(videoCount))**").string
                } else if photoCount > 0 {
                    if photoCount > 1 {
                        description += "**\(strings.Stars_Transfer_Photos(photoCount))**"
                    } else {
                        description += "**\(strings.Stars_Transfer_SinglePhoto)**"
                    }
                } else if videoCount > 0 {
                    if videoCount > 1 {
                        description += "**\(strings.Stars_Transfer_Videos(videoCount))**"
                    } else {
                        description += "**\(strings.Stars_Transfer_SingleVideo)**"
                    }
                }
                
                if let authorPeerName = state.authorPeer?.compactDisplayTitle {
                    infoText = strings.Stars_Transfer_UnlockBotInfo(
                        description,
                        authorPeerName,
                        strings.Stars_Transfer_Info_Stars(Int32(clamping: amount))
                    ).string
                } else if let botPeerName = state.botPeer?.compactDisplayTitle {
                    infoText = strings.Stars_Transfer_UnlockBotInfo(
                        description,
                        botPeerName,
                        strings.Stars_Transfer_Info_Stars(Int32(clamping: amount))
                    ).string
                } else {
                    infoText = strings.Stars_Transfer_UnlockInfo(
                        description,
                        state.chatPeer?.compactDisplayTitle ?? "",
                        strings.Stars_Transfer_Info_Stars(Int32(clamping: amount))
                    ).string
                }
            } else {
                infoText = strings.Stars_Transfer_Info(
                    component.invoice.title,
                    state.botPeer?.compactDisplayTitle ?? "",
                    strings.Stars_Transfer_Info_Stars(Int32(clamping: amount))
                ).string
            }
            
            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: infoText,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += 28.0
            
            let balanceTitle = balanceTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Stars_Transfer_Balance,
                        font: Font.regular(14.0),
                        textColor: textColor
                    )),
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let smallLabelFont = Font.regular(11.0)
            let labelFont = Font.semibold(14.0)
            let formattedBalance = formatStarsAmountText(state.balance ?? StarsAmount.zero, dateTimeFormat: environment.dateTimeFormat)
            let balanceText = tonAmountAttributedString(formattedBalance, integralFont: labelFont, fractionalFont: smallLabelFont, color: textColor, decimalSeparator: environment.dateTimeFormat.decimalSeparator)
            
            let balanceValue = balanceValue.update(
                component: MultilineTextComponent(
                    text: .plain(balanceText),
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            let balanceIcon = balanceIcon.update(
                component: BundleIconComponent(name: "Premium/Stars/StarSmall", tintColor: nil),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let topBalanceOriginY = 19.0
            context.add(balanceTitle
                .position(CGPoint(x: context.availableSize.width - 16.0 - environment.safeInsets.left - balanceTitle.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height / 2.0))
            )
            context.add(balanceIcon
                .position(CGPoint(x: context.availableSize.width - 16.0 - environment.safeInsets.left - balanceIcon.size.width / 2.0 - balanceValue.size.width - 3.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0 + 1.0 + UIScreenPixel))
            )
            context.add(balanceValue
                .position(CGPoint(x: context.availableSize.width - 16.0 - environment.safeInsets.left - balanceValue.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0))
            )
           
            if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
            }
            
            let amountString = presentationStringsFormattedNumber(Int32(amount), presentationData.dateTimeFormat.groupingSeparator)
            let buttonAttributedString: NSMutableAttributedString
            if case .starsChatSubscription = component.source {
                buttonAttributedString = NSMutableAttributedString(string: "\(strings.Stars_Transfer_SubscribeFor)   #  \(amountString) \(strings.Stars_Transfer_SubscribePerMonth)", font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                
            } else if let _ = component.invoice.subscriptionPeriod {
                buttonAttributedString = NSMutableAttributedString(string: "\(strings.Stars_Transfer_SubscribeFor)   #  \(amountString) \(strings.Stars_Transfer_SubscribePerMonth)", font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            } else {
                buttonAttributedString = NSMutableAttributedString(string: "\(strings.Stars_Transfer_Pay)   #  \(amountString)", font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            }
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: environment.theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let controller = environment.controller() as? StarsTransferScreen
                        
            let accountContext = component.context
            let starsContext = component.starsContext
            let botTitle = state.botPeer?.compactDisplayTitle ?? ""
            let invoice = component.invoice
            let isMedia = !component.extendedMedia.isEmpty
            
            let buttonSideInset: CGFloat = 30.0
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: state.inProgress,
                    action: { [weak state, weak controller] in
                        state?.buy(requestTopUp: { [weak controller] completion in
                            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: accountContext.currentAppConfiguration.with { $0 })
                            if !premiumConfiguration.isPremiumDisabled {
                                let purpose: StarsPurchasePurpose
                                if isMedia {
                                    purpose = .unlockMedia(requiredStars: invoice.totalAmount)
                                } else if let peerId = state?.botPeer?.id {
                                    purpose = .transfer(peerId: peerId, requiredStars: invoice.totalAmount)
                                } else {
                                    purpose = .generic
                                }
                                let purchaseController = accountContext.sharedContext.makeStarsPurchaseScreen(
                                    context: accountContext,
                                    starsContext: starsContext,
                                    options: state?.options ?? [],
                                    purpose: purpose,
                                    targetPeerId: nil,
                                    customTheme: nil,
                                    completion: { [weak starsContext] stars in
                                        guard let starsContext else {
                                            return
                                        }
                                        starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                                        let _ = (starsContext.onUpdate
                                        |> deliverOnMainQueue).start(next: {
                                            completion()
                                        })
                                    }
                                )
                                controller?.push(purchaseController)
                            } else {
                                let alertController = textAlertController(context: accountContext, title: nil, text: presentationData.strings.Stars_Transfer_Unavailable, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                                controller?.present(alertController, in: .window(.root))
                            }
                        }, completion: { [weak controller] success in
                            if success {
                                let presentationData = accountContext.sharedContext.currentPresentationData.with { $0 }
                                var title = presentationData.strings.Stars_Transfer_PurchasedTitle
                                let text: String
                                if isSubscription {
                                    title = presentationData.strings.Stars_Transfer_Subscribe_Successful_Title
                                    text = presentationData.strings.Stars_Transfer_Subscribe_Successful_Text(presentationData.strings.Stars_Transfer_Purchased_Stars(Int32(clamping: invoice.totalAmount)), botTitle).string
                                } else if let _ = component.invoice.extendedMedia {
                                    text = presentationData.strings.Stars_Transfer_UnlockedText( presentationData.strings.Stars_Transfer_Purchased_Stars(Int32(clamping: invoice.totalAmount))).string
                                } else {
                                    text = presentationData.strings.Stars_Transfer_PurchasedText(invoice.title, botTitle, presentationData.strings.Stars_Transfer_Purchased_Stars(Int32(clamping: invoice.totalAmount))).string
                                }
                                
                                if let navigationController = controller?.navigationController {
                                    Queue.mainQueue().after(0.5) {
                                        if let lastController = navigationController.viewControllers.last as? ViewController {
                                            let resultController = UndoOverlayController(
                                                presentationData: presentationData,
                                                content: .universal(
                                                    animation: "StarsSend",
                                                    scale: 0.066,
                                                    colors: [:],
                                                    title: title,
                                                    text: text,
                                                    customUndoText: nil,
                                                    timeout: nil
                                                ),
                                                elevatedLayout: lastController is ChatController,
                                                action: { _ in return true}
                                            )
                                            lastController.present(resultController, in: .window(.root))
                                        }
                                    }
                                }
                            }
                            
                            controller?.complete(paid: success)
                            controller?.dismissAnimated()
                            
                            Queue.mainQueue().after(2.5) {
                                starsContext.load(force: true)
                            }
                        })
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - buttonSideInset * 2.0, height: 52),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
            
            let termsText = isSubscription ? strings.Stars_Subscription_Terms : strings.Stars_Transfer_Terms
            let termsURL = isSubscription ? strings.Stars_Subscription_Terms_URL : strings.Stars_Transfer_Terms_URL
            
            contentSize.height += 14.0
            
            let termsTextFont = Font.regular(13.0)
            let termsTextColor = theme.actionSheet.secondaryTextColor
            let termsLinkColor = theme.actionSheet.controlAccentColor
            let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsTextFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsTextFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsTextFont, textColor: termsLinkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let info = info.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: termsText,
                        attributes: termsMarkdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: linkColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak controller] attributes, _ in
                        if let controller, let navigationController = controller.navigationController as? NavigationController {
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: termsURL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    }
                ),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(info
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + info.size.height / 2.0))
            )
            contentSize.height += info.size.height
            
            var bottomInset: CGFloat = environment.safeInsets.bottom
            if bottomInset < 5.0 {
                bottomInset = 8.0
            }
            contentSize.height += 4.0 + bottomInset
            
            return contentSize
        }
    }
}

private final class StarsTransferSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let starsContext: StarsContext
    private let invoice: TelegramMediaInvoice
    private let source: BotPaymentInvoiceSource
    private let extendedMedia: [TelegramExtendedMedia]
    private let inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>
    private let navigateToPeer: ((EnginePeer) -> Void)?
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        invoice: TelegramMediaInvoice,
        source: BotPaymentInvoiceSource,
        extendedMedia: [TelegramExtendedMedia],
        inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>,
        navigateToPeer: ((EnginePeer) -> Void)?
    ) {
        self.context = context
        self.starsContext = starsContext
        self.invoice = invoice
        self.source = source
        self.extendedMedia = extendedMedia
        self.inputData = inputData
        self.navigateToPeer = navigateToPeer
    }
    
    static func ==(lhs: StarsTransferSheetComponent, rhs: StarsTransferSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.invoice != rhs.invoice {
            return false
        }
        if lhs.extendedMedia != rhs.extendedMedia {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        starsContext: context.component.starsContext,
                        invoice: context.component.invoice,
                        source: context.component.source,
                        extendedMedia: context.component.extendedMedia,
                        inputData: context.component.inputData,
                        navigateToPeer: context.component.navigateToPeer,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class StarsTransferScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let extendedMedia: [TelegramExtendedMedia]
    private let completion: (Bool) -> Void
        
    public init(
        context: AccountContext,
        starsContext: StarsContext,
        invoice: TelegramMediaInvoice,
        source: BotPaymentInvoiceSource,
        extendedMedia: [TelegramExtendedMedia] = [],
        inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>,
        navigateToPeer: ((EnginePeer) -> Void)? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        self.context = context
        self.extendedMedia =  extendedMedia
        self.completion = completion
                
        super.init(
            context: context,
            component: StarsTransferSheetComponent(
                context: context,
                starsContext: starsContext,
                invoice: invoice,
                source: source,
                extendedMedia: extendedMedia,
                inputData: inputData,
                navigateToPeer: navigateToPeer
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        
        starsContext.load(force: false)
    }
    
    deinit {
        self.complete(paid: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var didComplete = false
    fileprivate func complete(paid: Bool) {
        guard !self.didComplete else {
            return
        }
        self.didComplete = true
        self.completion(paid)
        
        if !self.extendedMedia.isEmpty && paid {
            self.navigationController?.view.addSubview(ConfettiView(frame: self.view.bounds, customImage: UIImage(bundleImageName: "Peer Info/PremiumIcon")))
        }
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
