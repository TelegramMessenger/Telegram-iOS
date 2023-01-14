import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ViewControllerComponent
import AccountContext
import SolidRoundedButtonComponent
import MultilineTextComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import InAppPurchaseManager
import ConfettiEffect
import TextFormat
import UniversalMediaPlayer

private final class PremiumGiftScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let peer: EnginePeer?
    let products: [PremiumGiftProduct]?
    let selectedProductId: String?
    
    let present: (ViewController) -> Void
    let selectProduct: (String) -> Void
    let buy: () -> Void
    
    init(context: AccountContext, peer: EnginePeer?, products: [PremiumGiftProduct]?, selectedProductId: String?, present: @escaping (ViewController) -> Void, selectProduct: @escaping (String) -> Void, buy: @escaping () -> Void) {
        self.context = context
        self.peer = peer
        self.products = products
        self.selectedProductId = selectedProductId
        self.present = present
        self.selectProduct = selectProduct
        self.buy = buy
    }
    
    static func ==(lhs: PremiumGiftScreenContentComponent, rhs: PremiumGiftScreenContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.products != rhs.products {
            return false
        }
        if lhs.selectedProductId != rhs.selectedProductId {
            return false
        }
        
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
    
        private var disposable: Disposable?
        private(set) var configuration = PremiumIntroConfiguration.defaultValue
        private(set) var promoConfiguration: PremiumPromoConfiguration?
        
        private var stickersDisposable: Disposable?
        private var preloadDisposableSet =  DisposableSet()
        
        var price: String?
        
        init(context: AccountContext) {
            self.context = context
            
            super.init()
            
            self.disposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Configuration.App(),
                TelegramEngine.EngineData.Item.Configuration.PremiumPromo()
            )
            |> deliverOnMainQueue).start(next: { [weak self] appConfiguration, promoConfiguration in
                if let strongSelf = self {
                    strongSelf.configuration = PremiumIntroConfiguration.with(appConfiguration: appConfiguration)
                    strongSelf.promoConfiguration = promoConfiguration
                    strongSelf.updated(transition: .immediate)
                    
//                    if let identifier = source.identifier {
//                        var jsonString: String = "{"
//                        jsonString += "\"source\": \"\(identifier)\","
//
//                        jsonString += "\"data\": {\"premium_promo_order\":["
//                        var isFirst = true
//                        for perk in strongSelf.configuration.perks {
//                            if !isFirst {
//                                jsonString += ","
//                            }
//                            isFirst = false
//                            jsonString += "\"\(perk.identifier)\""
//                        }
//                        jsonString += "]}}"
//
//                        if let data = jsonString.data(using: .utf8), let json = JSON(data: data) {
//                            addAppLogEvent(postbox: strongSelf.context.account.postbox, type: "premium.promo_screen_show", data: json)
//                        }
//                    }
                    
                    for (_, video) in promoConfiguration.videos {
                        strongSelf.preloadDisposableSet.add(preloadVideoResource(postbox: context.account.postbox, resourceReference: .standalone(resource: video.resource), duration: 3.0).start())
                    }
                }
            })
            
            let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
            
            let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)
            self.stickersDisposable = (self.context.account.postbox.combinedView(keys: [stickersKey])
            |> deliverOnMainQueue).start(next: { [weak self] views in
                guard let strongSelf = self else {
                    return
                }
                if let view = views.views[stickersKey] as? OrderedItemListView {
                    for item in view.items {
                        if let mediaItem = item.contents.get(RecentMediaItem.self) {
                            let file = mediaItem.media
                            strongSelf.preloadDisposableSet.add(freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: .standalone(media: file), resource: file.resource).start())
                            if let effect = file.videoThumbnails.first {
                                strongSelf.preloadDisposableSet.add(freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: .standalone(media: file), resource: effect.resource).start())
                            }
                        }
                    }
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.preloadDisposableSet.dispose()
            self.stickersDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context)
    }
        
    static var body: Body {
        let overscroll = Child(Rectangle.self)
        let fade = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let optionsSection = Child(SectionGroupComponent.self)
        let perksSection = Child(SectionGroupComponent.self)
        
        return { context in
            let sideInset: CGFloat = 16.0
            
            let component = context.component
            
            let scrollEnvironment = context.environment[ScrollChildEnvironment.self].value
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
         
            let theme = environment.theme
            let strings = environment.strings
            
            let availableWidth = context.availableSize.width
            let sideInsets = sideInset * 2.0 + environment.safeInsets.left + environment.safeInsets.right
            var size = CGSize(width: context.availableSize.width, height: 0.0)
            
            let overscroll = overscroll.update(
                component: Rectangle(color: theme.list.plainBackgroundColor),
                availableSize: CGSize(width: context.availableSize.width, height: 1000),
                transition: context.transition
            )
            context.add(overscroll
                .position(CGPoint(x: overscroll.size.width / 2.0, y: -overscroll.size.height / 2.0))
            )
            
            let fade = fade.update(
                component: RoundedRectangle(
                    colors: [
                        theme.list.plainBackgroundColor,
                        theme.list.blocksBackgroundColor
                    ],
                    cornerRadius: 0.0,
                    gradientDirection: .vertical
                ),
                availableSize: CGSize(width: availableWidth, height: 300),
                transition: context.transition
            )
            context.add(fade
                .position(CGPoint(x: fade.size.width / 2.0, y: fade.size.height / 2.0))
            )
            
            size.height += 183.0 + 10.0 + environment.navigationHeight - 56.0
            
            let textColor = theme.list.itemPrimaryTextColor
            let titleColor = theme.list.itemPrimaryTextColor
            let subtitleColor = theme.list.itemSecondaryTextColor
            let arrowColor = theme.list.disclosureArrowColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: textColor), linkAttribute: { _ in
                return nil
            })
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(
                        text: strings.Premium_Gift_Description(component.peer?.compactDisplayTitle ?? "").string,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: 240.0),
                transition: context.transition
            )
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height + text.size.height / 2.0))
            )
            size.height += text.size.height
            size.height += 21.0
            
            var items: [SectionGroupComponent.Item] = []
            
            var i = 0
            if let products = component.products {
                let gradientColors: [UIColor] = [
                    UIColor(rgb: 0x8e77ff),
                    UIColor(rgb: 0x9a6fff),
                    UIColor(rgb: 0xb36eee)
                ]
                
                let shortestOptionPrice: (Int64, NSDecimalNumber)
                if let product = products.last {
                    shortestOptionPrice = (Int64(Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months)), product.storeProduct.priceValue.dividing(by: NSDecimalNumber(value: product.months)))
                } else {
                    shortestOptionPrice = (1, NSDecimalNumber(decimal: 1))
                }
                
                for product in products {
                    let giftTitle: String
                    if product.months == 12 {
                        giftTitle = strings.Premium_Gift_Years(1)
                    } else {
                        giftTitle = strings.Premium_Gift_Months(product.months)
                    }
                    
                    let discountValue = Int((1.0 - Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months) / Float(shortestOptionPrice.0)) * 100.0)
                    let discount: String
                    if discountValue > 0 {
                        discount = "-\(discountValue)%"
                    } else {
                        discount = ""
                    }
                    
                    let defaultPrice = product.storeProduct.defaultPrice(shortestOptionPrice.1, monthsCount: Int(product.months))
                    
                    var subtitle = ""
                    var pricePerMonth = product.storeProduct.pricePerMonth(Int(product.months))
                    pricePerMonth = environment.strings.Premium_PricePerMonth(pricePerMonth).string
                    
                    if discountValue > 0 {
                        subtitle = "**\(defaultPrice)** \(product.price)"
                    }
                   
                    items.append(SectionGroupComponent.Item(
                        AnyComponentWithIdentity(
                            id: product.id,
                            component: AnyComponent(
                                PremiumOptionComponent(
                                    title: giftTitle,
                                    subtitle: subtitle,
                                    labelPrice: pricePerMonth,
                                    discount: discount,
                                    selected: product.id == component.selectedProductId,
                                    primaryTextColor: textColor,
                                    secondaryTextColor: subtitleColor,
                                    accentColor: gradientColors[i],
                                    checkForegroundColor: environment.theme.list.itemCheckColors.foregroundColor,
                                    checkBorderColor: environment.theme.list.itemCheckColors.strokeColor
                                )
                            )
                        ),
                        action: {
                            component.selectProduct(product.id)
                        })
                    )
                    i += 1
                }
            }
            
            let optionsSection = optionsSection.update(
                component: SectionGroupComponent(
                    items: items,
                    backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                    selectionColor: environment.theme.list.itemHighlightedBackgroundColor,
                    separatorColor: environment.theme.list.itemBlocksSeparatorColor
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(optionsSection
                .position(CGPoint(x: availableWidth / 2.0, y: size.height + optionsSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            size.height += optionsSection.size.height
            size.height += 23.0
            
            let state = context.state
            let accountContext = context.component.context
            let present = context.component.present
            let buy = context.component.buy
            
            let price = context.component.products?.first(where: { $0.id == context.component.selectedProductId })?.price
            state.price = price
            
            let gradientColors: [UIColor] = [
                UIColor(rgb: 0xF27C30),
                UIColor(rgb: 0xE36850),
                UIColor(rgb: 0xda5d63),
                UIColor(rgb: 0xD15078),
                UIColor(rgb: 0xC14998),
                UIColor(rgb: 0xB24CB5),
                UIColor(rgb: 0xA34ED0),
                UIColor(rgb: 0x9054E9),
                UIColor(rgb: 0x7561EB),
                UIColor(rgb: 0x5A6EEE),
                UIColor(rgb: 0x548DFF),
                UIColor(rgb: 0x54A3FF),
                UIColor(rgb: 0x54bdff)
            ]
            
            i = 0
            var perksItems: [SectionGroupComponent.Item] = []
            for perk in state.configuration.perks {
                let iconBackgroundColors = gradientColors[i]
                perksItems.append(SectionGroupComponent.Item(
                    AnyComponentWithIdentity(
                        id: perk.identifier,
                        component: AnyComponent(
                            PerkComponent(
                                iconName: perk.iconName,
                                iconBackgroundColors: [
                                    iconBackgroundColors
                                ],
                                title: perk.title(strings: strings),
                                titleColor: titleColor,
                                subtitle: perk.subtitle(strings: strings),
                                subtitleColor: subtitleColor,
                                arrowColor: arrowColor
                            )
                        )
                    ),
                    action: { [weak state] in
                        var demoSubject: PremiumDemoScreen.Subject
                        switch perk {
                        case .doubleLimits:
                            demoSubject = .doubleLimits
                        case .moreUpload:
                            demoSubject = .moreUpload
                        case .fasterDownload:
                            demoSubject = .fasterDownload
                        case .voiceToText:
                            demoSubject = .voiceToText
                        case .noAds:
                            demoSubject = .noAds
                        case .uniqueReactions:
                            demoSubject = .uniqueReactions
                        case .premiumStickers:
                            demoSubject = .premiumStickers
                        case .advancedChatManagement:
                            demoSubject = .advancedChatManagement
                        case .profileBadge:
                            demoSubject = .profileBadge
                        case .animatedUserpics:
                            demoSubject = .animatedUserpics
                        case .appIcons:
                            demoSubject = .appIcons
                        case .animatedEmoji:
                            demoSubject = .animatedEmoji
                        case .emojiStatus:
                            demoSubject = .emojiStatus
                        }
                        
                        var dismissImpl: (() -> Void)?
                        let controller = PremiumLimitsListScreen(context: accountContext, subject: demoSubject, source: .gift(state?.price), order: state?.configuration.perks, buttonText: strings.Premium_Gift_GiftSubscription(state?.price ?? "–").string, isPremium: false)
                        controller.action = {
                            dismissImpl?()
                            buy()
                        }
                        controller.disposed = {
//                                updateIsFocused(false)
                        }
                        present(controller)
                        dismissImpl = { [weak controller] in
                            controller?.dismiss(animated: true, completion: nil)
                        }
                        
//                        let controller = PremiumDemoScreen(
//                            context: accountContext,
//                            subject: demoSubject,
//                            source: .gift(state?.price),
//                            order: state?.configuration.perks,
//                            action: {
//                                buy()
//                            }
//                        )
//                        controller.disposed = {
////                            updateIsFocused(false)
//                        }
//                        present(controller)
////                        updateIsFocused(true)
                        
                        addAppLogEvent(postbox: accountContext.account.postbox, type: "premium.promo_screen_tap", data: ["item": perk.identifier])
                    }
                ))
                i += 1
            }
            
            let perksSection = perksSection.update(
                component: SectionGroupComponent(
                    items: perksItems,
                    backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                    selectionColor: environment.theme.list.itemHighlightedBackgroundColor,
                    separatorColor: environment.theme.list.itemBlocksSeparatorColor
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(perksSection
                .position(CGPoint(x: availableWidth / 2.0, y: size.height + perksSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            
            size.height += perksSection.size.height
            
            size.height += 10.0
            size.height += scrollEnvironment.insets.bottom
            
            return size
        }
    }
}

private struct PremiumGiftProduct: Equatable {
    let giftOption: CachedPremiumGiftOption
    let storeProduct: InAppPurchaseManager.Product
    
    var id: String {
        return self.storeProduct.id
    }
    
    var months: Int32 {
        return self.giftOption.months
    }
    
    var price: String {
        return self.storeProduct.price
    }
    
    var pricePerMonth: String {
        return self.storeProduct.pricePerMonth(Int(self.months))
    }
}

private final class PremiumGiftScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: PeerId
    let options: [CachedPremiumGiftOption]
    let updateInProgress: (Bool) -> Void
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let completion: (Int32) -> Void
    
    init(context: AccountContext, peerId: PeerId, options: [CachedPremiumGiftOption], updateInProgress: @escaping (Bool) -> Void, present: @escaping (ViewController) -> Void, push: @escaping (ViewController) -> Void, completion: @escaping (Int32) -> Void) {
        self.context = context
        self.peerId = peerId
        self.options = options
        self.updateInProgress = updateInProgress
        self.present = present
        self.push = push
        self.completion = completion
    }
        
    static func ==(lhs: PremiumGiftScreenComponent, rhs: PremiumGiftScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let peerId: PeerId
        private let options: [CachedPremiumGiftOption]
        private let updateInProgress: (Bool) -> Void
        private let present: (ViewController) -> Void
        private let completion: (Int32) -> Void
        
        var topContentOffset: CGFloat?
        var bottomContentOffset: CGFloat?
        
        var hasIdleAnimations = true
        
        var inProgress = false
        
        var peer: EnginePeer?
        var products: [PremiumGiftProduct]?
        var selectedProductId: String?
                        
        private var disposable: Disposable?
        private var paymentDisposable = MetaDisposable()
        private var activationDisposable = MetaDisposable()
        
        init(context: AccountContext, peerId: PeerId, options: [CachedPremiumGiftOption], updateInProgress: @escaping (Bool) -> Void, present: @escaping (ViewController) -> Void, completion: @escaping (Int32) -> Void) {
            self.context = context
            self.peerId = peerId
            self.options = options
            self.updateInProgress = updateInProgress
            self.present = present
            self.completion = completion
            
            super.init()
            
            let availableProducts: Signal<[InAppPurchaseManager.Product], NoError>
            if let inAppPurchaseManager = context.inAppPurchaseManager {
                availableProducts = inAppPurchaseManager.availableProducts
            } else {
                availableProducts = .single([])
            }
            
            self.disposable = combineLatest(
                queue: Queue.mainQueue(),
                availableProducts,
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            ).start(next: { [weak self] products, peer in
                if let strongSelf = self {
                    var gifts: [PremiumGiftProduct] = []
                    for option in strongSelf.options {
                        if let product = products.first(where: { $0.id == option.storeProductId }), !product.isSubscription {
                            gifts.append(PremiumGiftProduct(giftOption: option, storeProduct: product))
                        }
                    }

                    strongSelf.products = gifts
                    if strongSelf.selectedProductId == nil {
                        strongSelf.selectedProductId = strongSelf.products?.first?.id
                    }
                    strongSelf.peer = peer
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.paymentDisposable.dispose()
            self.activationDisposable.dispose()
        }
        
        func selectProduct(id: String) {
            self.selectedProductId = id
            self.updated(transition: .immediate)
        }
        
        func buy() {
            guard let inAppPurchaseManager = self.context.inAppPurchaseManager, !self.inProgress else {
                return
            }
            
            guard let product = self.products?.first(where: { $0.id == self.selectedProductId }) else {
                return
            }
            let (currency, amount) = product.storeProduct.priceCurrencyAndAmount
            let duration = product.months
                        
//            addAppLogEvent(postbox: self.context.account.postbox, type: "premium.promo_screen_accept")

            self.inProgress = true
            self.updateInProgress(true)
            self.updated(transition: .immediate)
            
            let _ = (self.context.engine.payments.canPurchasePremium(purpose: .gift(peerId: self.peerId, currency: currency, amount: amount))
            |> deliverOnMainQueue).start(next: { [weak self] available in
                if let strongSelf = self {
                    if available {
                        strongSelf.paymentDisposable.set((inAppPurchaseManager.buyProduct(product.storeProduct, targetPeerId: strongSelf.peerId)
                        |> deliverOnMainQueue).start(next: { [weak self] status in
                            if let strongSelf = self, case .purchased = status {
                                Queue.mainQueue().after(2.0) {
                                    let _ = updatePremiumPromoConfigurationOnce(account: strongSelf.context.account).start()
                                    strongSelf.inProgress = false
                                    strongSelf.updateInProgress(false)
                                    
                                    strongSelf.updated(transition: .easeInOut(duration: 0.25))
                                    strongSelf.completion(duration)
                                }
                            }
                        }, error: { [weak self] error in
                            if let strongSelf = self {
                                strongSelf.inProgress = false
                                strongSelf.updateInProgress(false)
                                strongSelf.updated(transition: .immediate)

                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
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
                                    case .cancelled:
                                        break
                                }
                                
                                if let errorText = errorText {
//                                    addAppLogEvent(postbox: strongSelf.context.account.postbox, type: "premium.promo_screen_fail")
                                    
                                    let alertController = textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                                    strongSelf.present(alertController)
                                }
                            }
                        }))
                    } else {
                        strongSelf.inProgress = false
                        strongSelf.updateInProgress(false)
                        strongSelf.updated(transition: .immediate)
                    }
                }
            })
        }
        
        func updateIsFocused(_ isFocused: Bool) {
            self.hasIdleAnimations = !isFocused
            self.updated(transition: .immediate)
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId, options: self.options, updateInProgress: self.updateInProgress, present: self.present, completion: self.completion)
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scrollContent = Child(ScrollComponent<EnvironmentType>.self)
        let star = Child(GiftAvatarComponent.self)
        let topPanel = Child(BlurredRectangle.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let bottomPanel = Child(BlurredRectangle.self)
        let bottomSeparator = Child(Rectangle.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let state = context.state
            
            let background = background.update(component: Rectangle(color: environment.theme.list.blocksBackgroundColor), environment: {}, availableSize: context.availableSize, transition: context.transition)
            
            var starIsVisible = true
            if let topContentOffset = state.topContentOffset, topContentOffset >= 123.0 {
                starIsVisible = false
            }
                            
            let topPanel = topPanel.update(
                component: BlurredRectangle(
                    color: environment.theme.rootController.navigationBar.blurredBackgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: environment.navigationHeight),
                transition: context.transition
            )
            
            let topSeparator = topSeparator.update(
                component: Rectangle(
                    color: environment.theme.rootController.navigationBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.Premium_Gift_Title, font: Font.bold(28.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            let bottomPanelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset
           
            let topInset: CGFloat = environment.navigationHeight - 56.0
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let scrollContent = scrollContent.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(PremiumGiftScreenContentComponent(
                        context: context.component.context,
                        peer: state.peer,
                        products: state.products,
                        selectedProductId: state.selectedProductId,
                        present: context.component.present,
                        selectProduct: { [weak state] productId in
                            state?.selectProduct(id: productId)
                        }, buy: { [weak state] in
                            state?.buy()
                        }
                    )),
                    contentInsets: UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: bottomPanelHeight, right: 0.0),
                    contentOffsetUpdated: { [weak state] topContentOffset, bottomContentOffset in
                        state?.topContentOffset = topContentOffset
                        state?.bottomContentOffset = bottomContentOffset
                        Queue.mainQueue().justDispatch {
                            state?.updated(transition: .immediate)
                        }
                    },
                    contentOffsetWillCommit: { targetContentOffset in
                        if targetContentOffset.pointee.y < 100.0 {
                            targetContentOffset.pointee = CGPoint(x: 0.0, y: 0.0)
                        } else if targetContentOffset.pointee.y < 123.0 {
                            targetContentOffset.pointee = CGPoint(x: 0.0, y: 123.0)
                        }
                    }
                ),
                environment: { environment },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(scrollContent
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let topPanelAlpha: CGFloat
            let titleOffset: CGFloat
            let titleScale: CGFloat
            let titleOffsetDelta = (topInset + 160.0) - (environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)
            let titleAlpha: CGFloat
            
            if let topContentOffset = state.topContentOffset {
                topPanelAlpha = min(20.0, max(0.0, topContentOffset - 95.0)) / 20.0
                let topContentOffset = topContentOffset + max(0.0, min(1.0, topContentOffset / titleOffsetDelta)) * 10.0
                titleOffset = topContentOffset
                let fraction = max(0.0, min(1.0, titleOffset / titleOffsetDelta))
                titleScale = 1.0 - fraction * 0.36
                titleAlpha = 1.0
            } else {
                topPanelAlpha = 0.0
                titleScale = 1.0
                titleOffset = 0.0
                titleAlpha = 1.0
            }
            
            let star = star.update(
                component: GiftAvatarComponent(
                    context: context.component.context,
                    peer: context.state.peer,
                    isVisible: starIsVisible,
                    hasIdleAnimations: state.hasIdleAnimations
                ),
                availableSize: CGSize(width: min(390.0, context.availableSize.width), height: 220.0),
                transition: context.transition
            )
        
            context.add(star
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topInset + star.size.height / 2.0 - 30.0 - titleOffset * titleScale))
                .scale(titleScale)
            )
            
            context.add(topPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
                .opacity(topPanelAlpha)
            )
            context.add(topSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height))
                .opacity(topPanelAlpha)
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: max(topInset + 160.0 - titleOffset, environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)))
                .scale(titleScale)
                .opacity(titleAlpha)
            )
                                
            let price: String?
            if let products = state.products, let selectedProductId = state.selectedProductId, let product = products.first(where: { $0.id == selectedProductId }) {
                price = product.price
            } else {
                price = nil
            }
            
            let sideInset: CGFloat = 16.0
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: environment.strings.Premium_Gift_GiftSubscription(price ?? "—").string,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: UIColor(rgb: 0x8878ff),
                        backgroundColors: [
                            UIColor(rgb: 0x0077ff),
                            UIColor(rgb: 0x6b93ff),
                            UIColor(rgb: 0x8878ff),
                            UIColor(rgb: 0xe46ace)
                        ],
                        foregroundColor: .white
                    ),
                    height: 50.0,
                    cornerRadius: 11.0,
                    gloss: true,
                    isLoading: state.inProgress,
                    action: {
                        state.buy()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: 50.0),
                transition: context.transition)
                           
            let bottomPanel = bottomPanel.update(
                component: BlurredRectangle(
                    color: environment.theme.rootController.tabBar.backgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: bottomPanelPadding + button.size.height + bottomInset),
                transition: context.transition
            )
            
            let bottomSeparator = bottomSeparator.update(
                component: Rectangle(
                    color: environment.theme.rootController.tabBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            let bottomPanelAlpha: CGFloat
            if let bottomContentOffset = state.bottomContentOffset {
                bottomPanelAlpha = min(16.0, bottomContentOffset) / 16.0
            } else {
                bottomPanelAlpha = 1.0
            }
            
            context.add(bottomPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height / 2.0))
                .opacity(bottomPanelAlpha)
            )
            context.add(bottomSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height))
                .opacity(bottomPanelAlpha)
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height + bottomPanelPadding + button.size.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class PremiumGiftScreen: ViewControllerComponentContainer {
    fileprivate let context: AccountContext
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
    
    public weak var sourceView: UIView?
    public weak var containerView: UIView?
    public var animationColor: UIColor?
    
    public init(context: AccountContext, peerId: PeerId, options: [CachedPremiumGiftOption]) {
        self.context = context
            
        var updateInProgressImpl: ((Bool) -> Void)?
        var pushImpl: ((ViewController) -> Void)?
//        var presentImpl: ((ViewController) -> Void)?
        var completionImpl: ((Int32) -> Void)?
        super.init(context: context, component: PremiumGiftScreenComponent(
            context: context,
            peerId: peerId,
            options: options,
            updateInProgress: { inProgress in
                updateInProgressImpl?(inProgress)
            },
            present: { c in
                pushImpl?(c)
            },
            push: { c in
                pushImpl?(c)
            },
            completion: { duration in
                completionImpl?(duration)
            }
        ), navigationBarAppearance: .transparent)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
        let cancelItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.setLeftBarButton(cancelItem, animated: false)
        self.navigationPresentation = .modal
        
        updateInProgressImpl = { [weak self] inProgress in
            if let strongSelf = self {
                strongSelf.navigationItem.leftBarButtonItem?.isEnabled = !inProgress
                strongSelf.view.disablesInteractiveTransitionGestureRecognizer = inProgress
                strongSelf.view.disablesInteractiveModalDismiss = inProgress
            }
        }
                
        pushImpl = { [weak self] c in
            self?.push(c)
        }
        
        completionImpl = { [weak self] duration in
            if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                var controllers = navigationController.viewControllers
                controllers = controllers.filter { !($0 is PeerInfoScreen) && !($0 is PremiumGiftScreen) }
                var foundController = false
                for controller in controllers.reversed() {
                    if let chatController = controller as? ChatController, case .peer(id: peerId) = chatController.chatLocation {
                        chatController.hintPlayNextOutgoingGift()
                        foundController = true
                        break
                    }
                }
                if !foundController {
                    let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false))
                    chatController.hintPlayNextOutgoingGift()
                    controllers.append(chatController)
                }
                navigationController.setViewControllers(controllers, animated: true)
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if !self.didSetReady {
            self.didSetReady = true
            if let view = self.node.hostView.findTaggedView(tag: GiftAvatarComponent.View.Tag()) as? GiftAvatarComponent.View {
                self._ready.set(view.ready)
            } else {
                self._ready.set(.single(true))
            }
        }
    }
}
