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
import ListActionItemComponent
import ChatScheduleTimeController
import TabSelectorComponent
import PresentationDataUtils
import BalanceNeededScreen

private let amountTag = GenericComponentViewTag()

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: StarsWithdrawScreen.Mode
    let controller: () -> ViewController?
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode,
        controller: @escaping () -> ViewController?,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.controller = controller
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        return true
    }
    
    static var body: (CombinedComponentContext<SheetContent>) -> CGSize {
        let closeButton = Child(Button.self)
        let balance = Child(BalanceComponent.self)
        let title = Child(Text.self)
        let currencyToggle = Child(TabSelectorComponent.self)
        let amountSection = Child(ListSectionComponent.self)
        let amountAdditionalLabel = Child(MultilineTextComponent.self)
        let timestampSection = Child(ListSectionComponent.self)
        let button = Child(ButtonComponent.self)
        let balanceTitle = Child(MultilineTextComponent.self)
        let balanceValue = Child(MultilineTextComponent.self)
        let balanceIcon = Child(BundleIconComponent.self)
        
        let body: (CombinedComponentContext<SheetContent>) -> CGSize = { (context: CombinedComponentContext<SheetContent>) -> CGSize in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            state.component = component
            
            let controller = environment.controller
            
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let sideInset: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            if case let .suggestedPost(mode, _, _, _) = component.mode {
                var displayBalance = false
                switch mode {
                case let .sender(_, isFromAdmin):
                    displayBalance = !isFromAdmin
                case .admin:
                    break
                }
                
                if displayBalance {
                    let balance = balance.update(
                        component: BalanceComponent(
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            currency: state.currency,
                            balance: state.currency == .stars ? state.starsBalance : state.tonBalance,
                            alignment: .right
                        ),
                        availableSize: CGSize(width: 200.0, height: 200.0),
                        transition: .immediate
                    )
                    let balanceFrame = CGRect(origin: CGPoint(x: context.availableSize.width - balance.size.width - 15.0, y: floor((56.0 - balance.size.height) * 0.5)), size: balance.size)
                    context.add(balance
                        .anchorPoint(CGPoint(x: 1.0, y: 0.0))
                        .position(CGPoint(x: balanceFrame.maxX, y: balanceFrame.minY))
                    )
                }
                
                let closeButton = closeButton.update(
                    component: Button(
                        content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.list.itemAccentColor)),
                        action: {
                            component.dismiss()
                        }
                    ).minSize(CGSize(width: 8.0, height: 44.0)),
                    availableSize: CGSize(width: 200.0, height: 100.0),
                    transition: .immediate
                )
                let closeFrame = CGRect(origin: CGPoint(x: 16.0, y: floor((56.0 - closeButton.size.height) * 0.5)), size: closeButton.size)
                context.add(closeButton
                    .position(closeFrame.center)
                )
            } else {
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
            }
            
            let titleString: String
            let amountTitle: String
            let amountPlaceholder: String
            var amountLabel: String?
            var amountRightLabel: String?
            
            let minAmount: StarsAmount?
            var allowZero = false
            let maxAmount: StarsAmount?
            
            let withdrawConfiguration = StarsWithdrawConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let resaleConfiguration = StarsSubscriptionConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            
            switch component.mode {
            case let .withdraw(status, _):
                titleString = environment.strings.Stars_Withdraw_Title
                amountTitle = environment.strings.Stars_Withdraw_AmountTitle
                amountPlaceholder = environment.strings.Stars_Withdraw_AmountPlaceholder
                
                minAmount = withdrawConfiguration.minWithdrawAmount.flatMap { StarsAmount(value: $0, nanos: 0) }
                maxAmount = status.balances.availableBalance.amount
            case .accountWithdraw:
                titleString = environment.strings.Stars_Withdraw_Title
                amountTitle = environment.strings.Stars_Withdraw_AmountTitle
                amountPlaceholder = environment.strings.Stars_Withdraw_AmountPlaceholder
                
                minAmount = withdrawConfiguration.minWithdrawAmount.flatMap { StarsAmount(value: $0, nanos: 0) }
                maxAmount = state.starsBalance
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
            case let .starGiftResell(_, update, _):
                titleString = update ? environment.strings.Stars_SellGift_EditTitle : environment.strings.Stars_SellGift_Title
                amountTitle = environment.strings.Stars_SellGift_AmountTitle
                amountPlaceholder = environment.strings.Stars_SellGift_AmountPlaceholder
                
                minAmount = StarsAmount(value: resaleConfiguration.starGiftResaleMinAmount, nanos: 0)
                maxAmount = StarsAmount(value: resaleConfiguration.starGiftResaleMaxAmount, nanos: 0)
            case let .paidMessages(_, minAmountValue, _, _, _):
                titleString = environment.strings.Stars_SendMessage_AdjustmentTitle
                amountTitle = environment.strings.Stars_SendMessage_AdjustmentSectionHeader
                amountPlaceholder = environment.strings.Stars_SendMessage_AdjustmentPlaceholder
                
                minAmount = StarsAmount(value: minAmountValue, nanos: 0)
                maxAmount = StarsAmount(value: resaleConfiguration.paidMessageMaxAmount, nanos: 0)
            case let .suggestedPost(mode, _, _, _):
                switch mode {
                case .sender:
                    titleString = environment.strings.Chat_PostSuggestion_Suggest_TitleCreate
                case .admin:
                    titleString = environment.strings.Chat_PostSuggestion_Suggest_TitleEdit
                }
                switch state.currency {
                case .stars:
                    amountTitle = environment.strings.Chat_PostSuggestion_Suggest_PriceSectionStars
                    maxAmount = StarsAmount(value: resaleConfiguration.channelMessageSuggestionMaxStarsAmount, nanos: 0)
                    minAmount = StarsAmount(value: resaleConfiguration.channelMessageSuggestionMinStarsAmount, nanos: 0)
                case .ton:
                    amountTitle = environment.strings.Chat_PostSuggestion_Suggest_PriceSectionTon
                    maxAmount = StarsAmount(value: resaleConfiguration.channelMessageSuggestionMaxTonAmount, nanos: 0)
                    minAmount = StarsAmount(value: 0, nanos: 0)
                }
                amountPlaceholder = environment.strings.Chat_PostSuggestion_Suggest_PricePlaceholder
                allowZero = true
                
                if let usdWithdrawRate = withdrawConfiguration.usdWithdrawRate, let tonUsdRate = withdrawConfiguration.tonUsdRate, let amount = state.amount, amount > StarsAmount.zero {
                    switch state.currency {
                    case .stars:
                        let usdRate = Double(usdWithdrawRate) / 1000.0 / 100.0
                        amountLabel = "≈\(formatTonUsdValue(amount.value, divide: false, rate: usdRate, dateTimeFormat: environment.dateTimeFormat))"
                    case .ton:
                        let usdRate = Double(tonUsdRate) / 1000.0 / 1000000.0
                        amountLabel = "≈\(formatTonUsdValue(amount.value, divide: false, rate: usdRate, dateTimeFormat: environment.dateTimeFormat))"
                    }
                }
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
                balance = state.starsBalance
            } else if case .reaction = component.mode {
                balance = state.starsBalance
            } else if case let .withdraw(starsState, _) = component.mode {
                balance = starsState.balances.availableBalance.amount
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
            
            var tonBalanceValue: StarsAmount = .zero
            if let tonBalance = state.tonBalance {
                tonBalanceValue = tonBalance
            }
            
            if case let .suggestedPost(mode, _, _, _) = component.mode {
                var displayCurrencySelector = false
                switch mode {
                case let .sender(_, isFromAdmin):
                    if isFromAdmin {
                        displayCurrencySelector = true
                    } else {
                        if state.currency == .ton || tonBalanceValue > StarsAmount.zero {
                            displayCurrencySelector = true
                        }
                    }
                case .admin:
                    displayCurrencySelector = true
                }
                
                if displayCurrencySelector {
                    let selectedId: AnyHashable = state.currency == .stars ? AnyHashable(0 as Int) : AnyHashable(1 as Int)
                    let starsTitle: String
                    let tonTitle: String
                    switch mode {
                    case .sender:
                        starsTitle = environment.strings.Chat_PostSuggestion_Suggest_OfferStars
                        tonTitle = environment.strings.Chat_PostSuggestion_Suggest_OfferTon
                    case .admin:
                        starsTitle = environment.strings.Chat_PostSuggestion_Suggest_RequestStars
                        tonTitle = environment.strings.Chat_PostSuggestion_Suggest_RequestTon
                    }
                    
                    let currencyToggle = currencyToggle.update(
                        component: TabSelectorComponent(
                            colors: TabSelectorComponent.Colors(
                                foreground: theme.list.itemSecondaryTextColor,
                                selection: theme.list.itemSecondaryTextColor.withMultipliedAlpha(0.15),
                                simple: true
                            ),
                            customLayout: TabSelectorComponent.CustomLayout(
                                font: Font.medium(14.0),
                                spacing: 10.0
                            ),
                            items: [
                                TabSelectorComponent.Item(
                                    id: AnyHashable(0),
                                    content: .component(AnyComponent(CurrencyTabItemComponent(icon: .stars, title: starsTitle, theme: theme)))
                                ),
                                TabSelectorComponent.Item(
                                    id: AnyHashable(1),
                                    content: .component(AnyComponent(CurrencyTabItemComponent(icon: .ton, title: tonTitle, theme: theme)))
                                )
                            ],
                            selectedId: selectedId,
                            setSelectedId: { [weak state] id in
                                guard let state else {
                                    return
                                }
                                
                                let currency: CurrencyAmount.Currency
                                if id == AnyHashable(0) {
                                    currency = .stars
                                } else {
                                    currency = .ton
                                }
                                if state.currency != currency {
                                    state.currency = currency
                                    state.amount = nil
                                }
                                state.updated(transition: .spring(duration: 0.4))
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 100.0),
                        transition: context.transition
                    )
                    contentSize.height -= 17.0
                    let currencyToggleFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - currencyToggle.size.width) * 0.5), y: contentSize.height), size: currencyToggle.size)
                    context.add(currencyToggle
                        .position(currencyToggle.size.centered(in: currencyToggleFrame).center))
                    
                    contentSize.height += currencyToggle.size.height + 29.0
                }
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
            case let .reaction(starsToTop, _):
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
            case let .paidMessages(_, _, fractionAfterCommission, _, _):
                let amountInfoString: NSAttributedString
                if let value = state.amount?.value, value > 0 {
                    let fullValue: Int64 = Int64(value) * 1_000_000_000 * Int64(fractionAfterCommission) / 100
                    let amountValue = StarsAmount(value: fullValue / 1_000_000_000, nanos: Int32(fullValue % 1_000_000_000))
                    amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_SendMessage_AdjustmentSectionFooterValue("\(amountValue)").string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                } else {
                    amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_SendMessage_AdjustmentSectionFooterEmptyValue("\(fractionAfterCommission)").string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                }
                amountFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(amountInfoString),
                    maximumNumberOfLines: 0
                ))
            case let .suggestedPost(mode, _, _, _):
                switch mode {
                case let .sender(channel, isFromAdmin):
                    let string: String
                    if isFromAdmin {
                        switch state.currency {
                        case .stars:
                            string = environment.strings.Chat_PostSuggestion_Suggest_RequestDescriptionStars
                        case .ton:
                            string = environment.strings.Chat_PostSuggestion_Suggest_RequestDescriptionTon
                        }
                    } else {
                        switch state.currency {
                        case .stars:
                            string = environment.strings.Chat_PostSuggestion_Suggest_OfferDescriptionStars(channel.compactDisplayTitle).string
                        case .ton:
                            string = environment.strings.Chat_PostSuggestion_Suggest_OfferDescriptionTon(channel.compactDisplayTitle).string
                        }
                    }
                    let amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                    amountFooter = AnyComponent(MultilineTextComponent(
                        text: .plain(amountInfoString),
                        maximumNumberOfLines: 0
                    ))
                case .admin:
                    let string: String
                    switch state.currency {
                    case .stars:
                        string = environment.strings.Chat_PostSuggestion_Suggest_RequestDescriptionStars
                    case .ton:
                        string = environment.strings.Chat_PostSuggestion_Suggest_RequestDescriptionTon
                    }
                    let amountInfoString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(string, attributes: amountMarkdownAttributes, textAlignment: .natural))
                    amountFooter = AnyComponent(MultilineTextComponent(
                        text: .plain(amountInfoString),
                        maximumNumberOfLines: 0
                    ))
                }
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
                                    accentColor: theme.list.itemAccentColor,
                                    value: state.amount?.value,
                                    minValue: minAmount?.value,
                                    allowZero: allowZero,
                                    maxValue: maxAmount?.value,
                                    placeholderText: amountPlaceholder,
                                    labelText: amountLabel,
                                    currency: state.currency,
                                    dateTimeFormat: presentationData.dateTimeFormat,
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
                transition: .immediate
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
            
            if case let .suggestedPost(mode, _, _, _) = component.mode {
                contentSize.height += 24.0
                
                let footerString: String
                switch mode {
                case .sender:
                    footerString = environment.strings.Chat_PostSuggestion_Suggest_OfferDateDescription
                case .admin:
                    footerString = environment.strings.Chat_PostSuggestion_Suggest_EditDateDescription
                }
                
                let timestampFooterString = NSAttributedString(attributedString: parseMarkdownIntoAttributedString(footerString, attributes: amountMarkdownAttributes, textAlignment: .natural))
                let timestampFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(timestampFooterString),
                    maximumNumberOfLines: 0
                ))
                
                let timeString: String
                if let timestamp = state.timestamp {
                    timeString = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: timestamp, alwaysShowTime: true, allowYesterday: true, format: HumanReadableStringFormat(
                        dateFormatString: { value in
                            return PresentationStrings.FormattedString(string: strings.SuggestPost_SetTimeFormat_Date(value).string, ranges: [])
                        },
                        tomorrowFormatString: { value in
                            return PresentationStrings.FormattedString(string: strings.SuggestPost_SetTimeFormat_TomorrowAt(value).string, ranges: [])
                        },
                        todayFormatString: { value in
                            return PresentationStrings.FormattedString(string: strings.SuggestPost_SetTimeFormat_TodayAt(value).string, ranges: [])
                        },
                        yesterdayFormatString: { value in
                            return PresentationStrings.FormattedString(string: strings.SuggestPost_SetTimeFormat_TodayAt(value).string, ranges: [])
                        }
                    )).string
                } else {
                    timeString = "Anytime"
                }
                
                let timestampSection = timestampSection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        header: nil,
                        footer: timestampFooter,
                        items: [AnyComponentWithIdentity(
                            id: "timestamp",
                            component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: "Time",
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: environment.theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))),
                                ], alignment: .left, spacing: 2.0)),
                                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: timeString,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                )))),
                                accessory: .arrow,
                                action: { [weak state] _ in
                                    guard let state else {
                                        return
                                    }
                                    let component = state.component
                                    
                                    let theme = environment.theme
                                    
                                    let minimalTime: Int32 = Int32(Date().timeIntervalSince1970) + 5 * 60 + 10
                                    let controller = ChatScheduleTimeController(context: state.context, updatedPresentationData: (state.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), state.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), mode: .suggestPost(needsTime: false, isAdmin: false, funds: nil), style: .default, currentTime: state.timestamp, minimalTime: minimalTime, dismissByTapOutside: true, completion: { [weak state] time in
                                        guard let state else {
                                            return
                                        }
                                        state.timestamp = time == 0 ? nil : time
                                        state.updated(transition: .immediate)
                                    })
                                    component.controller()?.view.endEditing(true)
                                    component.controller()?.present(controller, in: .window(.root))
                                }
                            ))
                        )]
                    ),
                    environment: {},
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(timestampSection
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + timestampSection.size.height / 2.0))
                    .clipsToBounds(true)
                    .cornerRadius(10.0)
                )
                contentSize.height += timestampSection.size.height
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
            } else if case let .suggestedPost(mode, _, _, _) = component.mode {
                switch mode {
                case .sender:
                    if let amount = state.amount, amount != .zero {
                        let currencySymbol: String
                        let currencyAmount: String
                        switch state.currency {
                        case .stars:
                            currencySymbol = "#"
                            currencyAmount = presentationStringsFormattedNumber(amount, environment.dateTimeFormat.groupingSeparator)
                        case .ton:
                            currencySymbol = "$"
                            currencyAmount = formatTonAmountText(amount.value, dateTimeFormat: environment.dateTimeFormat)
                        }
                        buttonString = environment.strings.Chat_PostSuggestion_Suggest_OfferButtonPrice("\(currencySymbol) \(currencyAmount)").string
                    } else {
                        buttonString = environment.strings.Chat_PostSuggestion_Suggest_OfferButtonFree
                    }
                case .admin:
                    buttonString = environment.strings.Chat_PostSuggestion_Suggest_UpdateButton
                }
            } else if let amount = state.amount {
                buttonString = "\(environment.strings.Stars_Withdraw_Withdraw)  # \(presentationStringsFormattedNumber(amount, environment.dateTimeFormat.groupingSeparator))"
            } else {
                buttonString = environment.strings.Stars_Withdraw_Withdraw
            }
            
            if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
            }
            if state.cachedTonImage == nil || state.cachedTonImage?.1 !== theme {
                state.cachedTonImage = (generateTintedImage(image: UIImage(bundleImageName: "Ads/TonAbout"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
            }
            
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            if let range = buttonAttributedString.string.range(of: "$"), let tonImage = state.cachedTonImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: tonImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            var isButtonEnabled = false
            let amount = state.amount ?? StarsAmount.zero
            if amount > StarsAmount.zero {
                isButtonEnabled = true
            } else if case let .paidMessages(_, minValue, _, _, _) = context.component.mode {
                if minValue <= 0 {
                    isButtonEnabled = true
                }
            } else if case .suggestedPost = context.component.mode {
                isButtonEnabled = true
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
                    isEnabled: isButtonEnabled,
                    displaysProgress: false,
                    action: { [weak state] in
                        if let controller = controller() as? StarsWithdrawScreen, let state {
                            let amount = state.amount ?? StarsAmount.zero
                            
                            if let minAmount, amount < minAmount, (!allowZero || amount != .zero) {
                                controller.presentMinAmountTooltip(minAmount.value, currency: state.currency)
                            } else {
                                switch state.mode {
                                case let .withdraw(_, completion):
                                    completion(amount.value)
                                case let .accountWithdraw(completion):
                                    completion(amount.value)
                                case let .paidMedia(_, completion):
                                    completion(amount.value)
                                case let .reaction(_, completion):
                                    completion(amount.value)
                                case let .starGiftResell(_, _, completion):
                                    completion(amount.value)
                                case let .paidMessages(_, _, _, _, completion):
                                    completion(amount.value)
                                case let .suggestedPost(_, _, _, completion):
                                    switch state.currency {
                                    case .stars:
                                        if let balance = state.starsBalance, amount > balance {
                                            guard let starsContext = state.context.starsContext else {
                                                return
                                            }
                                            let _ = (state.context.engine.payments.starsTopUpOptions()
                                            |> take(1)
                                            |> deliverOnMainQueue).startStandalone(next: { [weak controller, weak state] options in
                                                guard let controller, let state else {
                                                    return
                                                }
                                                let purchaseController = state.context.sharedContext.makeStarsPurchaseScreen(context: state.context, starsContext: starsContext, options: options, purpose: .generic, completion: { _ in
                                                })
                                                controller.push(purchaseController)
                                            })
                                            
                                            return
                                        }
                                    case .ton:
                                        if let balance = state.tonBalance, amount > balance {
                                            let needed = amount - balance
                                            var fragmentUrl = "https://fragment.com/ads/topup"
                                            if let data = state.context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                                                fragmentUrl = value
                                            }
                                            controller.push(BalanceNeededScreen(
                                                context: state.context,
                                                amount: needed,
                                                buttonAction: { [weak state] in
                                                    guard let state else {
                                                        return
                                                    }
                                                    state.context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                                                }
                                            ))
                                            return
                                        }
                                    }
                                    
                                    completion(CurrencyAmount(amount: amount, currency: state.currency), state.timestamp)
                                }
                                
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
        
        return body
    }
    
    final class State: ComponentState {
        fileprivate let context: AccountContext
        fileprivate let mode: StarsWithdrawScreen.Mode
        
        fileprivate var component: SheetContent
        
        fileprivate var amount: StarsAmount?
        fileprivate var currency: CurrencyAmount.Currency = .stars
        fileprivate var timestamp: Int32?
        
        fileprivate var starsBalance: StarsAmount?
        private var starsStateDisposable: Disposable?
        fileprivate var tonBalance: StarsAmount?
        private var tonStateDisposable: Disposable?
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedTonImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(component: SheetContent) {
            self.context = component.context
            self.mode = component.mode
            self.component = component
            
            var amount: StarsAmount?
            var currency: CurrencyAmount.Currency = .stars
            switch mode {
            case let .withdraw(stats, _):
                amount = StarsAmount(value: stats.balances.availableBalance.amount.value, nanos: 0)
            case .accountWithdraw:
                amount = context.starsContext?.currentState.flatMap { StarsAmount(value: $0.balance.value, nanos: 0) }
            case let .paidMedia(initialValue, _):
                amount = initialValue.flatMap { StarsAmount(value: $0, nanos: 0) }
            case .reaction:
                amount = nil
            case .starGiftResell:
                amount = nil
            case let .paidMessages(initialValue, _, _, _, _):
                amount = StarsAmount(value: initialValue, nanos: 0)
            case let .suggestedPost(_, initialValue, initialTimestamp, _):
                currency = initialValue.currency
                amount = initialValue.amount
                self.timestamp = initialTimestamp
            }
            
            self.currency = currency
            self.amount = amount
            
            super.init()
            
            var needsBalance = false
            switch self.mode {
            case .reaction:
                needsBalance = true
            case let .suggestedPost(mode, _, _, _):
                switch mode {
                case .sender:
                    needsBalance = true
                case .admin:
                    break
                }
            default:
                break
            }
            if needsBalance {
                if let starsContext = component.context.starsContext {
                    self.starsStateDisposable = (starsContext.state
                    |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                        if let self, let balance = state?.balance {
                            self.starsBalance = balance
                            self.updated()
                        }
                    })
                }
                if let tonContext = component.context.tonContext {
                    self.tonStateDisposable = (tonContext.state
                    |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                        if let self, let balance = state?.balance {
                            self.tonBalance = balance
                            self.updated()
                        }
                    })
                }
            }
            
            if case let .starGiftResell(giftToMatch, update, _) = self.mode {
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
            self.starsStateDisposable?.dispose()
            self.tonStateDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(component: self)
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
                        controller: {
                            return controller()
                        },
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
    public enum Mode {
        public enum SuggestedPostMode {
            case sender(channel: EnginePeer, isFromAdmin: Bool)
            case admin
        }
        
        case withdraw(StarsRevenueStats, completion: (Int64) -> Void)
        case accountWithdraw(completion: (Int64) -> Void)
        case paidMedia(Int64?, completion: (Int64) -> Void)
        case reaction(Int64?, completion: (Int64) -> Void)
        case starGiftResell(StarGift.UniqueGift, Bool, completion: (Int64) -> Void)
        case paidMessages(current: Int64, minValue: Int64, fractionAfterCommission: Int, kind: StarsWithdrawalScreenSubject.PaidMessageKind, completion: (Int64) -> Void)
        case suggestedPost(mode: SuggestedPostMode, price: CurrencyAmount, timestamp: Int32?, completion: (CurrencyAmount, Int32?) -> Void)
    }
    
    private let context: AccountContext
    private let mode: StarsWithdrawScreen.Mode
        
    public init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode
    ) {
        self.context = context
        self.mode = mode
        
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
    
    func presentMinAmountTooltip(_ minAmount: Int64, currency: CurrencyAmount.Currency) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var text = presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum(presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum_Stars(Int32(minAmount))).string
        if case .starGiftResell = self.mode {
            text = presentationData.strings.Stars_SellGiftMinAmountToast_Text("\(presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum_Stars(Int32(minAmount)))").string
        } else if case let .suggestedPost(mode, _, _, _) = self.mode {
            let resaleConfiguration = StarsSubscriptionConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
            switch currency {
            case .stars:
                switch mode {
                case .admin:
                    text = presentationData.strings.Chat_PostSuggestion_Suggest_AdminMinAmountStars_Text("\(resaleConfiguration.channelMessageSuggestionMinStarsAmount)").string
                case let .sender(_, isFromAdmin):
                    if isFromAdmin {
                        text = presentationData.strings.Chat_PostSuggestion_Suggest_AdminMinAmountStars_Text("\(resaleConfiguration.channelMessageSuggestionMinStarsAmount)").string
                    } else {
                        text = presentationData.strings.Chat_PostSuggestion_Suggest_UserMinAmountStars_Text("\(resaleConfiguration.channelMessageSuggestionMinStarsAmount)").string
                    }
                }
            case .ton:
                break
            }
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

private final class AmountFieldStarsFormatter: NSObject, UITextFieldDelegate {
    private let currency: CurrencyAmount.Currency
    private let dateTimeFormat: PresentationDateTimeFormat
    
    private let textField: UITextField
    private let minValue: Int64
    private let allowZero: Bool
    private let maxValue: Int64
    private let updated: (Int64) -> Void
    private let isEmptyUpdated: (Bool) -> Void
    private let animateError: () -> Void
    private let focusUpdated: (Bool) -> Void

    init?(textField: UITextField, currency: CurrencyAmount.Currency, dateTimeFormat: PresentationDateTimeFormat, minValue: Int64, allowZero: Bool, maxValue: Int64, updated: @escaping (Int64) -> Void, isEmptyUpdated: @escaping (Bool) -> Void, animateError: @escaping () -> Void, focusUpdated: @escaping (Bool) -> Void) {
        self.textField = textField
        self.currency = currency
        self.dateTimeFormat = dateTimeFormat
        self.minValue = minValue
        self.allowZero = allowZero
        self.maxValue = maxValue
        self.updated = updated
        self.isEmptyUpdated = isEmptyUpdated
        self.animateError = animateError
        self.focusUpdated = focusUpdated

        super.init()
    }
    
    func amountFrom(text: String) -> Int64 {
        var amount: Int64?
        if !text.isEmpty {
            switch self.currency {
            case .stars:
                if let value = Int64(text) {
                    amount = value
                }
            case .ton:
                let scale: Int64 = 1_000_000_000  // 10⁹  (one “nano”)
                if let dot = text.firstIndex(of: ".") {
                    // Slices for the parts on each side of the dot
                    var wholeSlice     = String(text[..<dot])
                    if wholeSlice.isEmpty {
                        wholeSlice = "0"
                    }
                    let fractionSlice  = text[text.index(after: dot)...]

                    // Make the fractional string exactly 9 characters long
                    var fractionStr = String(fractionSlice)
                    if fractionStr.count > 9 {
                        fractionStr = String(fractionStr.prefix(9))      // trim extra digits
                    } else {
                        fractionStr = fractionStr.padding(
                            toLength: 9, withPad: "0", startingAt: 0)     // pad with zeros
                    }

                    // Convert and combine
                    if let whole = Int64(wholeSlice),
                       let frac  = Int64(fractionStr) {
                        
                        let whole = min(whole, Int64.max / scale)
                        
                        amount = whole * scale + frac
                    }
                } else if let whole = Int64(text) {   // string had no dot at all
                    let whole = min(whole, Int64.max / scale)
                    
                    amount = whole * scale
                }
            }
        }
        return amount ?? 0
    }

    func onTextChanged(text: String) {
        self.updated(self.amountFrom(text: text))
        self.isEmptyUpdated(text.isEmpty)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var acceptZero = false
        if self.minValue <= 0 {
            acceptZero = true
        }
        
        var newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        if newText.contains(where: { c in
            switch c {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                return false
            default:
                if case .ton = self.currency {
                    if c == "." {
                        return false
                    }
                }
                return true
            }
        }) {
            return false
        }
        if newText.count(where: { $0 == "." }) > 1 {
            return false
        }
        
        switch self.currency {
        case .stars:
            if (newText == "0" && !acceptZero) || (newText.count > 1 && newText.hasPrefix("0")) {
                newText.removeFirst()
                textField.text = newText
                self.onTextChanged(text: newText)
                return false
            }
        case .ton:
            var fixedText = false
            if let index = newText.firstIndex(of: ".") {
                let fractionalString = newText[newText.index(after: index)...]
                if fractionalString.count > 2 {
                    newText = String(newText[newText.startIndex ..< newText.index(index, offsetBy: 3)])
                    fixedText = true
                }
            }
            
            if (newText == "0" && !acceptZero) || (newText.count > 1 && newText.hasPrefix("0") && !newText.hasPrefix("0.")) {
                newText.removeFirst()
                fixedText = true
            }
            
            if fixedText {
                textField.text = newText
                self.onTextChanged(text: newText)
                return false
            }
        }
        
        let amount: Int64 = self.amountFrom(text: newText)
        if amount > self.maxValue {
            switch self.currency {
            case .stars:
                textField.text = "\(self.maxValue)"
            case .ton:
                textField.text = "\(formatTonAmountText(self.maxValue, dateTimeFormat: PresentationDateTimeFormat(timeFormat: self.dateTimeFormat.timeFormat, dateFormat: self.dateTimeFormat.dateFormat, dateSeparator: "", dateSuffix: "", requiresFullYear: false, decimalSeparator: ".", groupingSeparator: "")))"
            }
            self.onTextChanged(text: self.textField.text ?? "")
            self.animateError()
            return false
        }
        
        self.onTextChanged(text: newText)
        
        return true
    }
}

private final class AmountFieldComponent: Component {
    typealias EnvironmentType = Empty
    
    let textColor: UIColor
    let secondaryColor: UIColor
    let placeholderColor: UIColor
    let accentColor: UIColor
    let value: Int64?
    let minValue: Int64?
    let allowZero: Bool
    let maxValue: Int64?
    let placeholderText: String
    let labelText: String?
    let currency: CurrencyAmount.Currency
    let dateTimeFormat: PresentationDateTimeFormat
    let amountUpdated: (Int64?) -> Void
    let tag: AnyObject?
    
    init(
        textColor: UIColor,
        secondaryColor: UIColor,
        placeholderColor: UIColor,
        accentColor: UIColor,
        value: Int64?,
        minValue: Int64?,
        allowZero: Bool,
        maxValue: Int64?,
        placeholderText: String,
        labelText: String?,
        currency: CurrencyAmount.Currency,
        dateTimeFormat: PresentationDateTimeFormat,
        amountUpdated: @escaping (Int64?) -> Void,
        tag: AnyObject? = nil
    ) {
        self.textColor = textColor
        self.secondaryColor = secondaryColor
        self.placeholderColor = placeholderColor
        self.accentColor = accentColor
        self.value = value
        self.minValue = minValue
        self.allowZero = allowZero
        self.maxValue = maxValue
        self.placeholderText = placeholderText
        self.labelText = labelText
        self.currency = currency
        self.dateTimeFormat = dateTimeFormat
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
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.minValue != rhs.minValue {
            return false
        }
        if lhs.allowZero != rhs.allowZero {
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
        if lhs.currency != rhs.currency {
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
        private let icon = ComponentView<Empty>()
        private let textField: TextFieldNodeView
        private var starsFormatter: AmountFieldStarsFormatter?
        private var tonFormatter: AmountFieldStarsFormatter?
        private let labelView: ComponentView<Empty>
        
        private var component: AmountFieldComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.placeholderView = ComponentView<Empty>()
            self.textField = TextFieldNodeView(frame: .zero)
            self.labelView = ComponentView<Empty>()

            super.init(frame: frame)
            
            self.addSubview(self.textField)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.textField.textColor = component.textColor
            if self.component?.currency != component.currency {
                if let value = component.value, value != .zero {
                    var text = ""
                    switch component.currency {
                    case .stars:
                        text = "\(value)"
                    case .ton:
                        text = "\(formatTonAmountText(value, dateTimeFormat: PresentationDateTimeFormat(timeFormat: component.dateTimeFormat.timeFormat, dateFormat: component.dateTimeFormat.dateFormat, dateSeparator: "", dateSuffix: "", requiresFullYear: false, decimalSeparator: ".", groupingSeparator: "")))"
                    }
                    self.textField.text = text
                } else {
                    self.textField.text = ""
                }
            }
            self.textField.font = Font.regular(17.0)
            
            self.textField.returnKeyType = .done
            self.textField.autocorrectionType = .no
            self.textField.autocapitalizationType = .none
            
            if self.component?.currency != component.currency {
                switch component.currency {
                case .stars:
                    self.textField.delegate = self
                    self.textField.keyboardType = .numberPad
                    if self.starsFormatter == nil {
                        self.starsFormatter = AmountFieldStarsFormatter(
                            textField: self.textField,
                            currency: component.currency,
                            dateTimeFormat: component.dateTimeFormat,
                            minValue: component.minValue ?? 0,
                            allowZero: component.allowZero,
                            maxValue: component.maxValue ?? Int64.max,
                            updated: { [weak self] value in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if !self.isUpdating {
                                    component.amountUpdated(value == 0 ? nil : value)
                                }
                            },
                            isEmptyUpdated: { [weak self] isEmpty in
                                guard let self else {
                                    return
                                }
                                self.placeholderView.view?.isHidden = !isEmpty
                            },
                            animateError: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.animateError()
                            },
                            focusUpdated: { _ in
                            }
                        )
                    }
                    self.tonFormatter = nil
                    self.textField.delegate = self.starsFormatter
                case .ton:
                    self.textField.keyboardType = .numbersAndPunctuation
                    if self.tonFormatter == nil {
                        self.tonFormatter = AmountFieldStarsFormatter(
                            textField: self.textField,
                            currency: component.currency,
                            dateTimeFormat: component.dateTimeFormat,
                            minValue: component.minValue ?? 0,
                            allowZero: component.allowZero,
                            maxValue: component.maxValue ?? 10000000,
                            updated: { [weak self] value in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if !self.isUpdating {
                                    component.amountUpdated(value == 0 ? nil : value)
                                }
                            },
                            isEmptyUpdated: { [weak self] isEmpty in
                                guard let self else {
                                    return
                                }
                                self.placeholderView.view?.isHidden = !isEmpty
                            },
                            animateError: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.animateError()
                            },
                            focusUpdated: { _ in
                            }
                        )
                    }
                    self.starsFormatter = nil
                    self.textField.delegate = self.tonFormatter
                }
                self.textField.reloadInputViews()
            }
                        
            self.component = component
            self.state = state
                       
            let size = CGSize(width: availableSize.width, height: 44.0)
            
            let sideInset: CGFloat = 16.0
            var leftInset: CGFloat = 16.0
            
            let iconName: String
            var iconTintColor: UIColor?
            let iconMaxSize: CGSize?
            var iconOffset = CGPoint()
            switch component.currency {
            case .stars:
                iconName = "Premium/Stars/StarLarge"
                iconMaxSize = CGSize(width: 22.0, height: 22.0)
            case .ton:
                iconName = "Ads/TonBig"
                iconTintColor = component.accentColor
                iconMaxSize = CGSize(width: 18.0, height: 18.0)
                iconOffset = CGPoint(x: 3.0, y: 1.0)
            }
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: iconName,
                    tintColor: iconTintColor,
                    maxSize: iconMaxSize
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.frame = CGRect(origin: CGPoint(x: iconOffset.x + 15.0, y: iconOffset.y - 1.0 + floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
            }
            
            leftInset += 24.0 + 6.0
            
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
                
                placeholderComponentView.frame = CGRect(origin: CGPoint(x: leftInset, y: -1.0 + floorToScreenPixels((size.height - placeholderSize.height) / 2.0) + 1.0 - UIScreenPixel), size: placeholderSize)
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
        return StarsWithdrawConfiguration(minWithdrawAmount: nil, maxPaidMediaAmount: nil, usdWithdrawRate: nil, tonUsdRate: nil)
    }
    
    let minWithdrawAmount: Int64?
    let maxPaidMediaAmount: Int64?
    let usdWithdrawRate: Double?
    let tonUsdRate: Double?
    
    fileprivate init(minWithdrawAmount: Int64?, maxPaidMediaAmount: Int64?, usdWithdrawRate: Double?, tonUsdRate: Double?) {
        self.minWithdrawAmount = minWithdrawAmount
        self.maxPaidMediaAmount = maxPaidMediaAmount
        self.usdWithdrawRate = usdWithdrawRate
        self.tonUsdRate = tonUsdRate
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
            var tonUsdRate: Double?
            if let value = data["ton_usd_rate"] as? Double {
                tonUsdRate = value
            }
            
            return StarsWithdrawConfiguration(minWithdrawAmount: minWithdrawAmount, maxPaidMediaAmount: maxPaidMediaAmount, usdWithdrawRate: usdWithdrawRate, tonUsdRate: tonUsdRate)
        } else {
            return .defaultValue
        }
    }
}

private final class BalanceComponent: CombinedComponent {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let currency: CurrencyAmount.Currency
    let balance: StarsAmount?
    let alignment: NSTextAlignment
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        currency: CurrencyAmount.Currency,
        balance: StarsAmount?,
        alignment: NSTextAlignment
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.currency = currency
        self.balance = balance
        self.alignment = alignment
    }
    
    static func ==(lhs: BalanceComponent, rhs: BalanceComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        if lhs.balance != rhs.balance {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let balance = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            var size = CGSize(width: 0.0, height: 0.0)
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: context.component.strings.SendStarReactions_Balance, font: Font.regular(14.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            size.width = max(size.width, title.size.width)
            size.height += title.size.height
            
            let balanceText: String
            if let value = context.component.balance {
                switch context.component.currency {
                case .stars:
                    balanceText = "\(value.stringValue)"
                case .ton:
                    let dateTimeFormat = context.component.context.sharedContext.currentPresentationData.with({ $0 }).dateTimeFormat
                    balanceText = "\(formatTonAmountText(value.value, dateTimeFormat: dateTimeFormat))"
                }
            } else {
                balanceText = "..."
            }
            let balance = balance.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: balanceText, font: Font.medium(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let iconSize: CGSize
            let iconName: String
            var iconOffset = CGPoint()
            var iconTintColor: UIColor?
            switch context.component.currency {
            case .stars:
                iconSize = CGSize(width: 18.0, height: 18.0)
                iconName = "Premium/Stars/StarLarge"
            case .ton:
                iconSize = CGSize(width: 13.0, height: 13.0)
                iconName = "Ads/TonBig"
                iconTintColor = context.component.theme.list.itemAccentColor
                iconOffset = CGPoint(x: 0.0, y: 2.33)
            }
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: iconName,
                    tintColor: iconTintColor
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let titleSpacing: CGFloat = 1.0
            let iconSpacing: CGFloat = 2.0
            
            size.height += titleSpacing
            
            size.width = max(size.width, icon.size.width + iconSpacing + balance.size.width)
            size.height += balance.size.height
            
            if context.component.alignment == .right {
                context.add(
                    title.position(
                        title.size.centered(in: CGRect(origin: CGPoint(x: size.width - title.size.width, y: 0.0), size: title.size)).center
                    )
                )
                context.add(
                    balance.position(
                        balance.size.centered(in: CGRect(origin: CGPoint(x: size.width - balance.size.width, y: title.size.height + titleSpacing), size: balance.size)).center
                    )
                )
                context.add(
                    icon.position(
                        icon.size.centered(in: CGRect(origin: CGPoint(x: iconOffset.x + size.width - balance.size.width - icon.size.width - 1.0, y: iconOffset.y + title.size.height + titleSpacing), size: icon.size)).center
                    )
                )
            } else {
                context.add(
                    title.position(
                        title.size.centered(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: title.size)).center
                    )
                )
                context.add(
                    balance.position(
                        balance.size.centered(in: CGRect(origin: CGPoint(x: icon.size.width + iconSpacing, y: title.size.height + titleSpacing), size: balance.size)).center
                    )
                )
                context.add(
                    icon.position(
                        icon.size.centered(in: CGRect(origin: CGPoint(x: -1.0, y: title.size.height + titleSpacing), size: icon.size)).center
                    )
                )
            }

            return size
        }
    }
}

private final class CurrencyTabItemComponent: Component {
    typealias EnvironmentType = TabSelectorComponent.ItemEnvironment
    
    enum Icon {
        case stars
        case ton
    }
    
    let icon: Icon
    let title: String
    let theme: PresentationTheme
    
    init(
        icon: Icon,
        title: String,
        theme: PresentationTheme
    ) {
        self.icon = icon
        self.title = title
        self.theme = theme
    }
    
    static func ==(lhs: CurrencyTabItemComponent, rhs: CurrencyTabItemComponent) -> Bool {
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: CurrencyTabItemComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let iconSpacing: CGFloat = 4.0
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: component.icon == .stars ? "Premium/Stars/StarLarge" : "Ads/TonAbout",
                    tintColor: component.icon == .stars ? nil : component.theme.list.itemAccentColor
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.medium(14.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let titleFrame = CGRect(origin: CGPoint(x: iconSize.width + iconSpacing, y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
                
                transition.setTintColor(layer: titleView.layer, color: component.theme.list.freeTextColor.mixedWith(component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.5), alpha: environment[TabSelectorComponent.ItemEnvironment.self].value.selectionFraction))
            }
            
            let iconFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((titleSize.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.frame = iconFrame
            }
            
            return CGSize(width: iconSize.width + iconSpacing + titleSize.width, height: titleSize.height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
