import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import ButtonComponent
import Markdown
import BalancedTextComponent
import AvatarNode
import TextFormat
import TelegramStringFormatting
import StarsAvatarComponent
import EmojiTextAttachmentView
import EmojiStatusComponent
import UndoUI
import PlainButtonComponent
import TooltipUI
import GiftAnimationComponent
import LottieComponent
import ContextUI
import TelegramNotices
import GiftItemComponent

private final class GiftValueSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gift: StarGift
    let valueInfo: StarGift.UniqueGift.ValueInfo
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        gift: StarGift,
        valueInfo: StarGift.UniqueGift.ValueInfo,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.gift = gift
        self.valueInfo = valueInfo
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: GiftValueSheetContent, rhs: GiftValueSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.valueInfo != rhs.valueInfo {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let lastSalePriceTag = GenericComponentViewTag()
        let floorPriceTag = GenericComponentViewTag()
        let averagePriceTag = GenericComponentViewTag()
        
        private let context: AccountContext
        private let animateOut: ActionSlot<Action<()>>
        private let getController: () -> ViewController?
        
        private var disposable: Disposable?
        var initialized = false
        
        var starGiftsMap: [Int64: StarGift.Gift] = [:]
        
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedSmallStarImage: (UIImage, PresentationTheme)?
        var cachedSubtitleStarImage: (UIImage, PresentationTheme)?
        var cachedTonImage: (UIImage, PresentationTheme)?
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
                                        
        init(
            context: AccountContext,
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.context = context
            self.animateOut = animateOut
            self.getController = getController
            
            super.init()
            
            self.disposable = (context.engine.payments.cachedStarGifts()
            |> deliverOnMainQueue).startStrict(next: { [weak self] starGifts in
                if let strongSelf = self {
                    var starGiftsMap: [Int64: StarGift.Gift] = [:]
                    if let starGifts {
                        for gift in starGifts {
                            if case let .generic(gift) = gift {
                                starGiftsMap[gift.id] = gift
                            }
                        }
                    }
                    strongSelf.starGiftsMap = starGiftsMap
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func showAttributeInfo(tag: Any, text: String) {
            guard let controller = self.getController() as? GiftValueScreen else {
                return
            }
            controller.dismissAllTooltips()
            
            guard let sourceView = controller.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: controller.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 12.0), size: CGSize())
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .markdown(text: text), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            })
            controller.present(tooltipController, in: .current)
        }
        
        func openGiftResale(gift: StarGift.Gift) {
            guard let controller = self.getController() as? GiftValueScreen else {
                return
            }
            let storeController = self.context.sharedContext.makeGiftStoreController(
                context: self.context,
                peerId: self.context.account.peerId,
                gift: gift
            )
            controller.push(storeController)
        }
        
        func openGiftFragmentResale(url: String) {
            guard let controller = self.getController() as? GiftValueScreen, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
        }
        
        func dismiss(animated: Bool) {
            guard let controller = self.getController() as? GiftValueScreen else {
                return
            }
            if animated {
                controller.dismissAllTooltips()
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, animateOut: self.animateOut, getController: self.getController)
    }
    
    static var body: Body {
        let buttons = Child(ButtonsComponent.self)
        let animation = Child(GiftCompositionComponent.self)
        
        let titleBackground = Child(RoundedRectangle.self)
        let title = Child(MultilineTextComponent.self)
        
        let description = Child(MultilineTextComponent.self)
        
        let table = Child(TableComponent.self)
        
        let telegramSaleButton = Child(PlainButtonComponent.self)
        let fragmentSaleButton = Child(PlainButtonComponent.self)
        
        let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            let titleString: String = formatCurrencyAmount(component.valueInfo.value, currency: component.valueInfo.currency)
            var giftTitle: String = ""
            var giftCollectionTitle: String = ""
            var animationFile: TelegramMediaFile?
            var giftIconSubject: GiftItemComponent.Subject?
            var genericGift: StarGift.Gift?
            
            switch component.gift {
            case let .generic(gift):
                animationFile = gift.file
                giftIconSubject = .starGift(gift: gift, price: "")
            case let .unique(gift):
                for attribute in gift.attributes {
                    if case let .model(_, file, _) = attribute {
                        animationFile = file
                    }
                }
                giftCollectionTitle = gift.title
                giftTitle = "\(gift.title) #\(formatCollectibleNumber(gift.number, dateTimeFormat: dateTimeFormat))"
                
                if let gift = state.starGiftsMap[gift.giftId] {
                    giftIconSubject = .starGift(gift: gift, price: "")
                    genericGift = gift
                }
            }
       
            let buttons = buttons.update(
                component: ButtonsComponent(
                    theme: theme,
                    isOverlay: false,
                    showMoreButton: false,
                    closePressed: { [weak state] in
                        guard let state else {
                            return
                        }
                        state.dismiss(animated: true)
                    },
                    morePressed: { _, _ in
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )
                                                            
            var originY: CGFloat = 0.0
                        
            let headerHeight: CGFloat = 210.0
            let headerSubject: GiftCompositionComponent.Subject?
            if let animationFile {
                headerSubject = .generic(animationFile)
            } else {
                headerSubject = nil
            }
            
            if let headerSubject {
                let animation = animation.update(
                    component: GiftCompositionComponent(
                        context: component.context,
                        theme: environment.theme,
                        subject: headerSubject,
                        animationOffset: nil,
                        animationScale: nil,
                        displayAnimationStars: false,
                        externalState: giftCompositionExternalState,
                        requestUpdate: { [weak state] _ in
                            state?.updated()
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: headerHeight),
                    transition: context.transition
                )
                context.add(animation
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: headerHeight / 2.0))
                )
            }
            originY += headerHeight
                       
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleString,
                        font: Font.with(size: 24.0, design: .round, weight: .bold),
                        textColor: theme.list.itemCheckColors.foregroundColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            let titleBackground = titleBackground.update(
                component: RoundedRectangle(color: theme.actionSheet.controlAccentColor, cornerRadius: 24.0),
                environment: {},
                availableSize: CGSize(width: title.size.width + 32.0, height: 48.0),
                transition: .immediate
            )
            context.add(titleBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 187.0))
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 187.0))
            )
                       
            var descriptionText: String
            if component.valueInfo.valueIsAverage {
                descriptionText = strings.Gift_Value_DescriptionAveragePrice(giftCollectionTitle).string
            } else {
                if component.valueInfo.isLastSaleOnFragment {
                    descriptionText = strings.Gift_Value_DescriptionLastPriceFragment(giftTitle).string
                } else {
                    descriptionText = strings.Gift_Value_DescriptionLastPriceTelegram(giftTitle).string
                }
            }
            if !descriptionText.isEmpty {
                let linkColor = theme.actionSheet.controlAccentColor
                if state.cachedSmallStarImage == nil || state.cachedSmallStarImage?.1 !== environment.theme {
                    state.cachedSmallStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Premium/Stars/ButtonStar"), color: .white)!, theme)
                }
                if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                    state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
                }
                
                let textFont =  Font.regular(15.0)
                let boldTextFont =  Font.semibold(15.0)
                let textColor = theme.list.itemPrimaryTextColor
                
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                
                descriptionText = descriptionText.replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                if let range = attributedString.string.range(of: "*"), let starImage = state.cachedSmallStarImage?.0 {
                    attributedString.addAttribute(.font, value: Font.regular(13.0), range: NSRange(range, in: attributedString.string))
                    attributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: attributedString.string))
                    attributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: attributedString.string))
                }
                if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                    attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                }
                
                let description = description.update(
                    component: MultilineTextComponent(
                        text: .plain(attributedString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 5,
                        lineSpacing: 0.2,
                        highlightColor: linkColor.withAlphaComponent(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { _, _ in
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(description
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 231.0 + description.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += description.size.height
                originY += 42.0
            } else {
                originY += 9.0
            }
                        
            let tableFont = Font.regular(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
    
            var tableItems: [TableComponent.Item] = []
            
            tableItems.append(.init(
                id: "initialDate",
                title: strings.Gift_Value_InitialSale,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: component.valueInfo.initialSaleDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                )
            ))
                                    
            let valueString = "⭐️\(formatStarsAmountText(StarsAmount(value: component.valueInfo.initialSaleStars, nanos: 0), dateTimeFormat: dateTimeFormat)) (≈\(formatCurrencyAmount(component.valueInfo.initialSalePrice, currency: component.valueInfo.currency)))"
            let valueAttributedString = NSMutableAttributedString(string: valueString, font: tableFont, textColor: tableTextColor)
            let range = (valueAttributedString.string as NSString).range(of: "⭐️")
            if range.location != NSNotFound {
                valueAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                valueAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
            }
            
            tableItems.append(.init(
                id: "initialPrice",
                title: strings.Gift_Value_InitialPrice,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: theme.list.mediaPlaceholderColor,
                    text: .plain(valueAttributedString),
                    maximumNumberOfLines: 0
                )),
                insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
            ))
            
            if let lastSaleDate = component.valueInfo.lastSaleDate {
                tableItems.append(.init(
                    id: "lastDate",
                    title: strings.Gift_Value_LastSale,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: lastSaleDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            if let lastSalePrice = component.valueInfo.lastSalePrice {
                let lastSalePriceString = formatCurrencyAmount(lastSalePrice, currency: component.valueInfo.currency)
                let tag = state.lastSalePriceTag
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: lastSalePriceString, font: tableFont, textColor: tableTextColor)))
                        )
                    )
                )
                
                let percentage = Int32(floor(Double(lastSalePrice) / Double(component.valueInfo.initialSalePrice) * 100.0 - 100.0))
                let percentageString = (percentage > 0 ? "+\(percentage)" : "\(percentage)") + "%"
                
                items.append(AnyComponentWithIdentity(
                    id: AnyHashable(1),
                    component: AnyComponent(Button(
                        content: AnyComponent(ButtonContentComponent(
                            context: component.context,
                            text: percentageString,
                            color: theme.list.itemAccentColor
                        )),
                        action: { [weak state] in
                            state?.showAttributeInfo(tag: tag, text: strings.Gift_Value_LastPriceInfo(lastSalePriceString, giftCollectionTitle).string)
                            
                        }
                    ).tagged(tag))
                ))
                let itemComponent = AnyComponent(
                    HStack(items, spacing: 4.0)
                )
                tableItems.append(.init(
                    id: "lastPrice",
                    title: strings.Gift_Value_LastPrice,
                    hasBackground: false,
                    component: itemComponent
                ))
            }
            
            if let floorPrice = component.valueInfo.floorPrice {
                let floorPriceString = formatCurrencyAmount(floorPrice, currency: component.valueInfo.currency)
                let tag = state.floorPriceTag
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: floorPriceString, font: tableFont, textColor: tableTextColor)))
                        )
                    )
                )
                items.append(AnyComponentWithIdentity(
                    id: AnyHashable(1),
                    component: AnyComponent(Button(
                        content: AnyComponent(ButtonContentComponent(
                            context: component.context,
                            text: "?",
                            color: theme.list.itemAccentColor
                        )),
                        action: { [weak state] in
                            state?.showAttributeInfo(tag: tag, text: strings.Gift_Value_MinimumPriceInfo(floorPriceString, giftCollectionTitle).string)
                        }
                    ).tagged(tag))
                ))
                let itemComponent = AnyComponent(
                    HStack(items, spacing: 4.0)
                )
                tableItems.append(.init(
                    id: "floorPrice",
                    title: strings.Gift_Value_MinimumPrice,
                    hasBackground: false,
                    component: itemComponent
                ))
            }
                        
            if let averagePrice = component.valueInfo.averagePrice {
                let averagePriceString = formatCurrencyAmount(averagePrice, currency: component.valueInfo.currency)
                let tag = state.averagePriceTag
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: averagePriceString, font: tableFont, textColor: tableTextColor)))
                        )
                    )
                )
                items.append(AnyComponentWithIdentity(
                    id: AnyHashable(1),
                    component: AnyComponent(Button(
                        content: AnyComponent(ButtonContentComponent(
                            context: component.context,
                            text: "?",
                            color: theme.list.itemAccentColor
                        )),
                        action: { [weak state] in
                            state?.showAttributeInfo(tag: tag, text: strings.Gift_Value_AveragePriceInfo(averagePriceString, giftCollectionTitle).string)
                        }
                    ).tagged(tag))
                ))
                let itemComponent = AnyComponent(
                    HStack(items, spacing: 4.0)
                )
                tableItems.append(.init(
                    id: "averagePrice",
                    title: strings.Gift_Value_AveragePrice,
                    hasBackground: false,
                    component: itemComponent
                ))
            }
                
            let table = table.update(
                component: TableComponent(
                    theme: environment.theme,
                    items: tableItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
                .appear(.default(alpha: true))
                .disappear(.default(alpha: true))
            )
            originY += table.size.height + 23.0
            
            if component.valueInfo.listedCount != nil || component.valueInfo.fragmentListedCount != nil {
                originY += 5.0
            }
                                      
            if let listedCount = component.valueInfo.listedCount, let giftIconSubject {
                let telegramSaleButton = telegramSaleButton.update(
                    component: PlainButtonComponent(
                        content: AnyComponent(
                            HStack([
                                AnyComponentWithIdentity(id: "count", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(listedCount, dateTimeFormat.groupingSeparator), font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
                                )),
                                AnyComponentWithIdentity(id: "spacing", component: AnyComponent(
                                    Rectangle(color: .clear, width: 8.0, height: 1.0)
                                )),
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: theme,
                                        strings: strings,
                                        peer: nil,
                                        subject: giftIconSubject,
                                        mode: .buttonIcon
                                    )
                                )),
                                AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: "  \(strings.Gift_Value_ForSaleOnTelegram)", font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
                                )),
                                AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
                                    BundleIconComponent(name: "Chat/Context Menu/Arrow", tintColor: theme.actionSheet.controlAccentColor)
                                ))
                            ], spacing: 0.0)
                        ),
                        action: { [weak state] in
                            guard let state, let genericGift else {
                                return
                            }
                            state.openGiftResale(gift: genericGift)
                        },
                        animateScale: false
                    ),
                    environment: {},
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(telegramSaleButton
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + telegramSaleButton.size.height / 2.0))
                )
                originY += telegramSaleButton.size.height
                originY += 12.0
            }
            
            if let listedCount = component.valueInfo.fragmentListedCount, let fragmentListedUrl = component.valueInfo.fragmentListedUrl, let giftIconSubject {
                if component.valueInfo.listedCount != nil {
                    originY += 18.0
                }
                
                let fragmentSaleButton = fragmentSaleButton.update(
                    component: PlainButtonComponent(
                        content: AnyComponent(
                            HStack([
                                AnyComponentWithIdentity(id: "count", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(listedCount, dateTimeFormat.groupingSeparator), font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
                                )),
                                AnyComponentWithIdentity(id: "spacing", component: AnyComponent(
                                    Rectangle(color: .clear, width: 8.0, height: 1.0)
                                )),
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: theme,
                                        strings: strings,
                                        peer: nil,
                                        subject: giftIconSubject,
                                        mode: .buttonIcon
                                    )
                                )),
                                AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: "  \(strings.Gift_Value_ForSaleOnFragment)", font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
                                )),
                                AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
                                    BundleIconComponent(name: "Chat/Context Menu/Arrow", tintColor: theme.actionSheet.controlAccentColor)
                                ))
                            ], spacing: 0.0)
                        ),
                        action: { [weak state] in
                            state?.openGiftFragmentResale(url: fragmentListedUrl)
                        },
                        animateScale: false
                    ),
                    environment: {},
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(fragmentSaleButton
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + fragmentSaleButton.size.height / 2.0))
                )
                originY += fragmentSaleButton.size.height
                originY += 12.0
            }
            
            context.add(buttons
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - 16.0 - buttons.size.width / 2.0, y: 28.0))
            )
            
            let effectiveBottomInset: CGFloat = environment.metrics.isTablet ? 0.0 : environment.safeInsets.bottom
            return CGSize(width: context.availableSize.width, height: originY + 5.0 + effectiveBottomInset)
        }
    }
}

final class GiftValueSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gift: StarGift
    let valueInfo: StarGift.UniqueGift.ValueInfo
    
    init(
        context: AccountContext,
        gift: StarGift,
        valueInfo: StarGift.UniqueGift.ValueInfo
    ) {
        self.context = context
        self.gift = gift
        self.valueInfo = valueInfo
    }
    
    static func ==(lhs: GiftValueSheetComponent, rhs: GiftValueSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.valueInfo != rhs.valueInfo {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(GiftValueSheetContent(
                        context: context.component.context,
                        gift: context.component.gift,
                        valueInfo: context.component.valueInfo,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        if let controller = controller() as? GiftValueScreen {
                            controller.dismissAllTooltips()
                        }
                    },
                    willDismiss: {
                    }
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
                                if let controller = controller() as? GiftValueScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftValueScreen {
                                    controller.dismissAllTooltips()
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
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

final class GiftValueScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let gift: StarGift
    private let valueInfo: StarGift.UniqueGift.ValueInfo
    
    public init(
        context: AccountContext,
        gift: StarGift,
        valueInfo: StarGift.UniqueGift.ValueInfo
    ) {
        self.context = context
        self.gift = gift
        self.valueInfo = valueInfo
        
        super.init(
            context: context,
            component: GiftValueSheetComponent(
                context: context,
                gift: gift,
                valueInfo: valueInfo
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
        
    public func dismissAnimated() {
        self.dismissAllTooltips()

        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
            
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
}
