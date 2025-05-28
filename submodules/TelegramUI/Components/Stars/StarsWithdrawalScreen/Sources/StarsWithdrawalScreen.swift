import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
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
import AccountContext
import PresentationDataUtils
import ListSectionComponent
import TelegramStringFormatting
import UndoUI

private let amountTag = GenericComponentViewTag()

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: StarsWithdrawScreen.Mode
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        let title = Child(Text.self)
        let amountSection = Child(ListSectionComponent.self)
        let amountAdditionalLabel = Child(MultilineTextComponent.self)
        let button = Child(ButtonComponent.self)
        let balanceTitle = Child(MultilineTextComponent.self)
        let balanceValue = Child(MultilineTextComponent.self)
        let balanceIcon = Child(BundleIconComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let controller = environment.controller
            
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let sideInset: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - closeButton.size.width, y: 28.0))
            )
            
            let titleString: String
            let amountTitle: String
            let amountPlaceholder: String
            var amountLabel: String?
            var amountRightLabel: String?
            
            let minAmount: StarsAmount?
            let maxAmount: StarsAmount?
            
            let withdrawConfiguration = StarsWithdrawConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let resaleConfiguration = StarsSubscriptionConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            
            switch component.mode {
            case let .withdraw(status):
                titleString = environment.strings.Stars_Withdraw_Title
                amountTitle = environment.strings.Stars_Withdraw_AmountTitle
                amountPlaceholder = environment.strings.Stars_Withdraw_AmountPlaceholder
                
                minAmount = withdrawConfiguration.minWithdrawAmount.flatMap { StarsAmount(value: $0, nanos: 0) }
                maxAmount = status.balances.availableBalance
            case .accountWithdraw:
                titleString = environment.strings.Stars_Withdraw_Title
                amountTitle = environment.strings.Stars_Withdraw_AmountTitle
                amountPlaceholder = environment.strings.Stars_Withdraw_AmountPlaceholder
                
                minAmount = withdrawConfiguration.minWithdrawAmount.flatMap { StarsAmount(value: $0, nanos: 0) }
                maxAmount = state.balance
            case .paidMedia:
                titleString = environment.strings.Stars_PaidContent_Title
                amountTitle = environment.strings.Stars_PaidContent_AmountTitle
                amountPlaceholder = environment.strings.Stars_PaidContent_AmountPlaceholder
               
                minAmount = StarsAmount(value: 1, nanos: 0)
                maxAmount = withdrawConfiguration.maxPaidMediaAmount.flatMap { StarsAmount(value: $0, nanos: 0) }
                
                if let usdWithdrawRate = withdrawConfiguration.usdWithdrawRate, let amount = state.amount, amount > StarsAmount.zero {
                    let usdRate = Double(usdWithdrawRate) / 1000.0 / 100.0
                    amountLabel = "≈\(formatTonUsdValue(amount.value, divide: false, rate: usdRate, dateTimeFormat: environment.dateTimeFormat))"
                }
            case .reaction:
                titleString = environment.strings.Stars_SendStars_Title
                amountTitle = environment.strings.Stars_SendStars_AmountTitle
                amountPlaceholder = environment.strings.Stars_SendStars_AmountPlaceholder
                
                minAmount = StarsAmount(value: 1, nanos: 0)
                maxAmount = withdrawConfiguration.maxPaidMediaAmount.flatMap { StarsAmount(value: $0, nanos: 0) }
            case let .starGiftResell(_, update):
                titleString = update ? environment.strings.Stars_SellGift_EditTitle : environment.strings.Stars_SellGift_Title
                amountTitle = environment.strings.Stars_SellGift_AmountTitle
                amountPlaceholder = environment.strings.Stars_SellGift_AmountPlaceholder
                
                minAmount = StarsAmount(value: resaleConfiguration.starGiftResaleMinAmount, nanos: 0)
                maxAmount = StarsAmount(value: resaleConfiguration.starGiftResaleMaxAmount, nanos: 0)
            case let .paidMessages(_, minAmountValue, _, _):
                titleString = environment.strings.Stars_SendMessage_AdjustmentTitle
                amountTitle = environment.strings.Stars_SendMessage_AdjustmentSectionHeader
                amountPlaceholder = environment.strings.Stars_SendMessage_AdjustmentPlaceholder
                
                minAmount = StarsAmount(value: minAmountValue, nanos: 0)
                maxAmount = StarsAmount(value: resaleConfiguration.paidMessageMaxAmount, nanos: 0)
            }
            
            let title = title.update(
                component: Text(text: titleString, font: Font.bold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 40.0
            
            let balance: StarsAmount?
            if case .accountWithdraw = component.mode {
                balance = state.balance
            } else if case .reaction = component.mode {
                balance = state.balance
            } else if case let .withdraw(starsState) = component.mode {
                balance = starsState.balances.availableBalance
            } else {
                balance = nil
            }
            
            if let balance {
                let balanceTitle = balanceTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Stars_Transfer_Balance,
                            font: Font.regular(14.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                let balanceValue = balanceValue.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: presentationStringsFormattedNumber(balance, environment.dateTimeFormat.groupingSeparator),
                            font: Font.semibold(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
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
                
                let topBalanceOriginY = 11.0
                context.add(balanceTitle
                    .position(CGPoint(x: 16.0 + environment.safeInsets.left + balanceTitle.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height / 2.0))
                )
                context.add(balanceIcon
                    .position(CGPoint(x: 16.0 + environment.safeInsets.left + balanceIcon.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0 + 1.0 + UIScreenPixel))
                )
                context.add(balanceValue
                    .position(CGPoint(x: 16.0 + environment.safeInsets.left + balanceIcon.size.width + 3.0 + balanceValue.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0 + 2.0 - UIScreenPixel))
                )
            }
            
            let amountFont = Font.regular(13.0)
            let boldAmountFont = Font.semibold(13.0)
            let amountTextColor = theme.list.freeTextColor
            let amountMarkdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: amountFont, textColor: amountTextColor),
                bold: MarkdownAttributeSet(font: boldAmountFont, textColor: amountTextColor),
                link: MarkdownAttributeSet(font: amountFont, textColor: theme.list.itemAccentColor),
                linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
                }
            )
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
            }
            let amountFooter: AnyComponent<Empty>?
            switch component.mode {
            case .paidMedia:
                let amountInfoString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_PaidContent_AmountInfo, attributes: amountMarkdownAttributes, textAlignment: .natural))
                if let range = amountInfoString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                    amountInfoString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: amountInfoString.string))
                }
                amountFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(amountInfoString),
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
                    tapAction: { attributes, _ in
                        if let controller = controller() as? StarsWithdrawScreen, let navigationController = controller.navigationController as? NavigationController {
                            component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Stars_PaidContent_AmountInfo_URL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    }
                ))
            case let .reaction(starsToTop):
                let amountInfoString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_SendStars_AmountInfo("\(starsToTop ?? 0)").string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                amountFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(amountInfoString),
                    maximumNumberOfLines: 0
                ))
            case .starGiftResell:
                let amountInfoString: NSAttributedString
                if let value = state.amount?.value, value > 0 {
                    let starsValue = Int32(floor(Float(value) * Float(resaleConfiguration.starGiftCommissionPermille) / 1000.0))
                    let starsString = environment.strings.Stars_SellGift_AmountInfo_Stars(starsValue)
                    amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_SellGift_AmountInfo(starsString).string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                    
                    if let usdWithdrawRate = withdrawConfiguration.usdWithdrawRate {
                        let usdRate = Double(usdWithdrawRate) / 1000.0 / 100.0
                        amountRightLabel = "≈\(formatTonUsdValue(Int64(starsValue), divide: false, rate: usdRate, dateTimeFormat: environment.dateTimeFormat))"
                    }
                } else {
                    amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_SellGift_AmountInfo("\(resaleConfiguration.starGiftCommissionPermille / 10)%").string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                }
                amountFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(amountInfoString),
                    maximumNumberOfLines: 0
                ))
            case let .paidMessages(_, _, fractionAfterCommission, _):
                let amountInfoString: NSAttributedString
                if let value = state.amount?.value, value > 0 {
                    let fullValue: Int64 = Int64(value) * 1_000_000_000 * Int64(fractionAfterCommission) / 100
                    let amountValue = StarsAmount(value: fullValue / 1_000_000_000, nanos: Int32(fullValue % 1_000_000_000))
                    amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_SendMessage_AdjustmentSectionFooterValue("\(amountValue)").string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                } else {
                    amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_SendMessage_AdjustmentSectionFooterEmpty, attributes: amountMarkdownAttributes, textAlignment: .natural))
                }
                amountFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(amountInfoString),
                    maximumNumberOfLines: 0
                ))
            default:
                amountFooter = nil
            }
            let amountSection = amountSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: amountTitle.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: amountFooter,
                    items: [
                        AnyComponentWithIdentity(
                            id: "amount",
                            component: AnyComponent(
                                AmountFieldComponent(
                                    textColor: theme.list.itemPrimaryTextColor,
                                    secondaryColor: theme.list.itemSecondaryTextColor,
                                    placeholderColor: theme.list.itemPlaceholderTextColor,
                                    value: state.amount?.value,
                                    minValue: minAmount?.value,
                                    maxValue: maxAmount?.value,
                                    placeholderText: amountPlaceholder,
                                    labelText: amountLabel,
                                    amountUpdated: { [weak state] amount in
                                        state?.amount = amount.flatMap { StarsAmount(value: $0, nanos: 0) }
                                        state?.updated()
                                    },
                                    tag: amountTag
                                )
                            )
                        )
                    ]
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(amountSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + amountSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            contentSize.height += amountSection.size.height
            if let amountRightLabel {
                let amountAdditionalLabel = amountAdditionalLabel.update(
                    component: MultilineTextComponent(text: .plain(NSAttributedString(string: amountRightLabel, font: amountFont, textColor: amountTextColor))),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(amountAdditionalLabel
                    .position(CGPoint(x: context.availableSize.width - amountAdditionalLabel.size.width / 2.0 - sideInset - 16.0, y: contentSize.height - amountAdditionalLabel.size.height / 2.0)))
            }
            contentSize.height += 32.0
    
            let buttonString: String
            if case .paidMedia = component.mode {
                buttonString = environment.strings.Stars_PaidContent_Create
            } else if case .starGiftResell = component.mode {
                if let amount = state.amount, amount.value > 0 {
                    buttonString = "\(environment.strings.Stars_SellGift_SellFor)  # \(presentationStringsFormattedNumber(amount, environment.dateTimeFormat.groupingSeparator))"
                } else {
                    buttonString = environment.strings.Stars_SellGift_Sell
                }
            } else if case .paidMessages = component.mode {
                buttonString = environment.strings.Stars_SendMessage_AdjustmentAction
            } else if let amount = state.amount {
                buttonString = "\(environment.strings.Stars_Withdraw_Withdraw)  # \(presentationStringsFormattedNumber(amount, environment.dateTimeFormat.groupingSeparator))"
            } else {
                buttonString = environment.strings.Stars_Withdraw_Withdraw
            }
            
            if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
            }
            
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: (state.amount ?? StarsAmount.zero) > StarsAmount.zero,
                    displaysProgress: false,
                    action: { [weak state] in
                        if let controller = controller() as? StarsWithdrawScreen, let amount = state?.amount {
                            if let minAmount, amount < minAmount {
                                controller.presentMinAmountTooltip(minAmount.value)
                            } else {
                                controller.completion(amount.value)
                                controller.dismissAnimated()
                            }
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50),
                transition: .immediate
            )
            context.add(button
                .clipsToBounds(true)
                .cornerRadius(10.0)
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
            contentSize.height += 15.0
            
            contentSize.height += max(environment.inputHeight, environment.safeInsets.bottom)

            return contentSize
        }
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let mode: StarsWithdrawScreen.Mode
        
        fileprivate var amount: StarsAmount?
        
        fileprivate var balance: StarsAmount?
        private var stateDisposable: Disposable?
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(
            context: AccountContext,
            mode: StarsWithdrawScreen.Mode
        ) {
            self.context = context
            self.mode = mode
            
            var amount: StarsAmount?
            switch mode {
            case let .withdraw(stats):
                amount = StarsAmount(value: stats.balances.availableBalance.value, nanos: 0)
            case .accountWithdraw:
                amount = context.starsContext?.currentState.flatMap { StarsAmount(value: $0.balance.value, nanos: 0) }
            case let .paidMedia(initialValue):
                amount = initialValue.flatMap { StarsAmount(value: $0, nanos: 0) }
            case .reaction:
                amount = nil
            case .starGiftResell:
                amount = nil
            case let .paidMessages(initialValue, _, _, _):
                amount = StarsAmount(value: initialValue, nanos: 0)
            }
            
            self.amount = amount
            
            super.init()
            
            if case .reaction = self.mode, let starsContext = context.starsContext {
                self.stateDisposable = (starsContext.state
                |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                    if let self, let balance = state?.balance {
                        self.balance = balance
                        self.updated()
                    }
                })
            }
            
            if case let .starGiftResell(giftToMatch, update) = self.mode {
                if update {
                    if let resellStars = giftToMatch.resellStars {
                        self.amount = StarsAmount(value: resellStars, nanos: 0)
                    }
                } else {
                    let _ = (context.engine.payments.cachedStarGifts()
                     |> filter { $0 != nil }
                     |> take(1)
                     |> deliverOnMainQueue).start(next: { [weak self] gifts in
                        guard let self, let gifts else {
                            return
                        }
                        guard let matchingGift = gifts.first(where: { gift in
                            if case let .generic(gift) = gift, gift.title == giftToMatch.title {
                                return true
                            } else {
                                return false
                            }
                        }) else {
                            return
                        }
                        if case let .generic(genericGift) = matchingGift, let minResaleStars = genericGift.availability?.minResaleStars {
                            self.amount = StarsAmount(value: minResaleStars, nanos: 0)
                            self.updated()
                        }
                    })
                }
            }
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, mode: self.mode)
    }
}

private final class StarsWithdrawSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let mode: StarsWithdrawScreen.Mode
    
    init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode
    ) {
        self.context = context
        self.mode = mode
    }
    
    static func ==(lhs: StarsWithdrawSheetComponent, rhs: StarsWithdrawSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
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
                        mode: context.component.mode,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.blocksBackgroundColor),
                    followContentSizeChanges: false,
                    clipsContent: true,
                    isScrollEnabled: false,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
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

public final class StarsWithdrawScreen: ViewControllerComponentContainer {
    public enum Mode: Equatable {
        case withdraw(StarsRevenueStats)
        case accountWithdraw
        case paidMedia(Int64?)
        case reaction(Int64?)
        case starGiftResell(StarGift.UniqueGift, Bool)
        case paidMessages(current: Int64, minValue: Int64, fractionAfterCommission: Int, kind: StarsWithdrawalScreenSubject.PaidMessageKind)
    }
    
    private let context: AccountContext
    private let mode: StarsWithdrawScreen.Mode
    fileprivate let completion: (Int64) -> Void
        
    public init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode,
        completion: @escaping (Int64) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.completion = completion
        
        super.init(
            context: context,
            component: StarsWithdrawSheetComponent(
                context: context,
                mode: mode
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let view = self.node.hostView.findTaggedView(tag: amountTag) as? AmountFieldComponent.View {
            Queue.mainQueue().after(0.01) {
                view.activateInput()
                view.selectAll()
            }
        }
    }
    
    func presentMinAmountTooltip(_ minAmount: Int64) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var text = presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum(presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum_Stars(Int32(minAmount))).string
        if case .starGiftResell = self.mode {
            //TODO:localize
            text = "You cannot sell gift for less than \(presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum_Stars(Int32(minAmount)))."
        }
        
        let resultController = UndoOverlayController(
            presentationData: presentationData,
            content: .image(
                image: UIImage(bundleImageName: "Premium/Stars/StarLarge")!,
                title: nil,
                text: text,
                round: false,
                undoText: nil
            ),
            elevatedLayout: false,
            position: .top,
            action: { _ in return true})
        self.present(resultController, in: .window(.root))
        
        if let view = self.node.hostView.findTaggedView(tag: amountTag) as? AmountFieldComponent.View {
            view.animateError()
        }
    }
        
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private let invalidAmountCharacters = CharacterSet.decimalDigits.inverted

private final class AmountFieldComponent: Component {
    typealias EnvironmentType = Empty
    
    let textColor: UIColor
    let secondaryColor: UIColor
    let placeholderColor: UIColor
    let value: Int64?
    let minValue: Int64?
    let maxValue: Int64?
    let placeholderText: String
    let labelText: String?
    let amountUpdated: (Int64?) -> Void
    let tag: AnyObject?
    
    init(
        textColor: UIColor,
        secondaryColor: UIColor,
        placeholderColor: UIColor,
        value: Int64?,
        minValue: Int64?,
        maxValue: Int64?,
        placeholderText: String,
        labelText: String?,
        amountUpdated: @escaping (Int64?) -> Void,
        tag: AnyObject? = nil
    ) {
        self.textColor = textColor
        self.secondaryColor = secondaryColor
        self.placeholderColor = placeholderColor
        self.value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.placeholderText = placeholderText
        self.labelText = labelText
        self.amountUpdated = amountUpdated
        self.tag = tag
    }
    
    static func ==(lhs: AmountFieldComponent, rhs: AmountFieldComponent) -> Bool {
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.secondaryColor != rhs.secondaryColor {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.minValue != rhs.minValue {
            return false
        }
        if lhs.maxValue != rhs.maxValue {
            return false
        }
        if lhs.placeholderText != rhs.placeholderText {
            return false
        }
        if lhs.labelText != rhs.labelText {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let placeholderView: ComponentView<Empty>
        private let iconView: UIImageView
        private let textField: TextFieldNodeView
        private let labelView: ComponentView<Empty>
        
        private var component: AmountFieldComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.placeholderView = ComponentView<Empty>()
            self.textField = TextFieldNodeView(frame: .zero)
            self.labelView = ComponentView<Empty>()
            
            self.iconView = UIImageView(image: UIImage(bundleImageName: "Premium/Stars/StarLarge"))

            super.init(frame: frame)

            self.textField.delegate = self
            self.textField.addTarget(self, action: #selector(self.textChanged(_:)), for: .editingChanged)
            
            self.addSubview(self.textField)
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func textChanged(_ sender: Any) {
            let text = self.textField.text ?? ""
            let amount: Int64?
            if !text.isEmpty, let value = Int64(text) {
                amount = value
            } else {
                amount = nil
            }
            self.component?.amountUpdated(amount)
            self.placeholderView.view?.isHidden = !text.isEmpty
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.rangeOfCharacter(from: invalidAmountCharacters) != nil {
                return false
            }
            var newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            if newText == "0" || (newText.count > 1 && newText.hasPrefix("0")) {
                newText.removeFirst()
                textField.text = newText
                self.textChanged(self.textField)
                return false
            }
            
            if let component = self.component {
                let amount: Int64?
                if !newText.isEmpty, let value = Int64(normalizeArabicNumeralString(newText, type: .western)) {
                    amount = value
                } else {
                    amount = nil
                }
                if let amount, let maxAmount = component.maxValue, amount > maxAmount {
                    textField.text = "\(maxAmount)"
                    self.textChanged(self.textField)
                    self.animateError()
                    return false
                }
            }
            return true
        }
        
        func activateInput() {
            self.textField.becomeFirstResponder()
        }
        
        func selectAll() {
            self.textField.selectAll(nil)
        }
        
        func animateError() {
            self.textField.layer.addShakeAnimation()
            let hapticFeedback = HapticFeedback()
            hapticFeedback.error()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                let _ = hapticFeedback
            })
        }
        
        func update(component: AmountFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.textField.textColor = component.textColor
            if let value = component.value {
                self.textField.text = "\(value)"
            } else {
                self.textField.text = ""
            }
            self.textField.font = Font.regular(17.0)
            
            self.textField.keyboardType = .numberPad
            self.textField.returnKeyType = .done
            self.textField.autocorrectionType = .no
            self.textField.autocapitalizationType = .none
                        
            self.component = component
            self.state = state
                       
            let size = CGSize(width: availableSize.width, height: 44.0)
            
            let sideInset: CGFloat = 15.0
            var leftInset: CGFloat = 15.0
            if let icon = self.iconView.image {
                leftInset += icon.size.width + 6.0
                self.iconView.frame = CGRect(origin: CGPoint(x: 15.0, y: floorToScreenPixels((size.height - icon.size.height) / 2.0)), size: icon.size)
            }
            
            let placeholderSize = self.placeholderView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(
                    Text(
                        text: component.placeholderText,
                        font: Font.regular(17.0),
                        color: component.placeholderColor
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            if let placeholderComponentView = self.placeholderView.view {
                if placeholderComponentView.superview == nil {
                    self.insertSubview(placeholderComponentView, at: 0)
                }
                
                placeholderComponentView.frame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((size.height - placeholderSize.height) / 2.0) + 1.0 - UIScreenPixel), size: placeholderSize)
                placeholderComponentView.isHidden = !(self.textField.text ?? "").isEmpty
            }
            
            if let labelText = component.labelText {
                let labelSize = self.labelView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        Text(
                            text: labelText,
                            font: Font.regular(17.0),
                            color: component.secondaryColor
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                
                if let labelView = self.labelView.view {
                    if labelView.superview == nil {
                        self.insertSubview(labelView, at: 0)
                    }
                    
                    labelView.frame = CGRect(origin: CGPoint(x: size.width - sideInset - labelSize.width, y: floorToScreenPixels((size.height - labelSize.height) / 2.0) + 1.0 - UIScreenPixel), size: labelSize)
                }
            } else if let labelView = self.labelView.view, labelView.superview != nil {
                labelView.removeFromSuperview()
            }
            
            self.textField.frame = CGRect(x: leftInset, y: 0.0, width: size.width - 30.0, height: 44.0)
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

private struct StarsWithdrawConfiguration {
    static var defaultValue: StarsWithdrawConfiguration {
        return StarsWithdrawConfiguration(minWithdrawAmount: nil, maxPaidMediaAmount: nil, usdWithdrawRate: nil)
    }
    
    let minWithdrawAmount: Int64?
    let maxPaidMediaAmount: Int64?
    let usdWithdrawRate: Double?
    
    fileprivate init(minWithdrawAmount: Int64?, maxPaidMediaAmount: Int64?, usdWithdrawRate: Double?) {
        self.minWithdrawAmount = minWithdrawAmount
        self.maxPaidMediaAmount = maxPaidMediaAmount
        self.usdWithdrawRate = usdWithdrawRate
    }
    
    static func with(appConfiguration: AppConfiguration) -> StarsWithdrawConfiguration {
        if let data = appConfiguration.data {
            var minWithdrawAmount: Int64?
            if let value = data["stars_revenue_withdrawal_min"] as? Double {
                minWithdrawAmount = Int64(value)
            }
            var maxPaidMediaAmount: Int64?
            if let value = data["stars_paid_post_amount_max"] as? Double {
                maxPaidMediaAmount = Int64(value)
            }
            var usdWithdrawRate: Double?
            if let value = data["stars_usd_withdraw_rate_x1000"] as? Double {
                usdWithdrawRate = value
            }
            
            return StarsWithdrawConfiguration(minWithdrawAmount: minWithdrawAmount, maxPaidMediaAmount: maxPaidMediaAmount, usdWithdrawRate: usdWithdrawRate)
        } else {
            return .defaultValue
        }
    }
}
