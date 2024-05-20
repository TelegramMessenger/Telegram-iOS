import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import PresentationDataUtils
import ViewControllerComponent
import AccountContext
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import InAppPurchaseManager
import AnimationCache
import MultiAnimationRenderer
import UndoUI
import TelegramStringFormatting
import ListSectionComponent
import ListActionItemComponent
import ScrollComponent
import BlurredBackgroundComponent
import TextFormat
import PremiumStarComponent
import BundleIconComponent
import ConfettiEffect

private struct StarsProduct: Equatable {
    let option: StarsTopUpOption
    let storeProduct: InAppPurchaseManager.Product
    
    var id: String {
        return self.storeProduct.id
    }

    var price: String {
        return self.storeProduct.price
    }
}

private final class StarsPurchaseScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let options: [StarsTopUpOption]
    let peerId: EnginePeer.Id?
    let requiredStars: Int32?
    let forceDark: Bool
    let products: [StarsProduct]?
    let expanded: Bool
    let stateUpdated: (Transition) -> Void
    let buy: (StarsProduct) -> Void
    
    init(
        context: AccountContext,
        options: [StarsTopUpOption],
        peerId: EnginePeer.Id?,
        requiredStars: Int32?,
        forceDark: Bool,
        products: [StarsProduct]?,
        expanded: Bool,
        stateUpdated: @escaping (Transition) -> Void,
        buy: @escaping (StarsProduct) -> Void
    ) {
        self.context = context
        self.options = options
        self.peerId = peerId
        self.requiredStars = requiredStars
        self.forceDark = forceDark
        self.products = products
        self.expanded = expanded
        self.stateUpdated = stateUpdated
        self.buy = buy
    }
    
    static func ==(lhs: StarsPurchaseScreenContentComponent, rhs: StarsPurchaseScreenContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.requiredStars != rhs.requiredStars {
            return false
        }
        if lhs.forceDark != rhs.forceDark {
            return false
        }
        if lhs.products != rhs.products {
            return false
        }
        if lhs.expanded != rhs.expanded {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        var products: [StarsProduct]?
        var peer: EnginePeer?
        
        private var disposable: Disposable?
    
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(
            context: AccountContext,
            peerId: EnginePeer.Id?
        ) {
            self.context = context
            
            super.init()
            
            if let peerId {
                self.disposable = (context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    if let self, let peer {
                        self.peer = peer
                        self.updated(transition: .immediate)
                    }
                })
            }
            
            let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId)
    }
    
    static var body: Body {
        let overscroll = Child(Rectangle.self)
        let fade = Child(RoundedRectangle.self)
        let text = Child(BalancedTextComponent.self)
        let list = Child(VStack<Empty>.self)
        let termsText = Child(BalancedTextComponent.self)
             
        return { context in
            let sideInset: CGFloat = 16.0
            
            let scrollEnvironment = context.environment[ScrollChildEnvironment.self].value
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            state.products = context.component.products
            
            let theme = environment.theme
            let presentationData = context.component.context.sharedContext.currentPresentationData.with { $0 }
            
            let availableWidth = context.availableSize.width
            let sideInsets = sideInset * 2.0 + environment.safeInsets.left + environment.safeInsets.right
            var size = CGSize(width: context.availableSize.width, height: 0.0)
            
            var topBackgroundColor = theme.list.plainBackgroundColor
            let bottomBackgroundColor = theme.list.blocksBackgroundColor
            if theme.overallDarkAppearance {
                topBackgroundColor = bottomBackgroundColor
            }
        
            let overscroll = overscroll.update(
                component: Rectangle(color: topBackgroundColor),
                availableSize: CGSize(width: context.availableSize.width, height: 1000),
                transition: context.transition
            )
            context.add(overscroll
                .position(CGPoint(x: overscroll.size.width / 2.0, y: -overscroll.size.height / 2.0))
            )
            
            let fade = fade.update(
                component: RoundedRectangle(
                    colors: [
                        topBackgroundColor,
                        bottomBackgroundColor
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
            let accentColor = theme.list.itemAccentColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            //TODO:localize
            let textString: String
//            if let peer = state.peer, let requiredStars = context.component.requiredStars {
//                textString = "\(peer.compactDisplayTitle) requests \(requiredStars) Stars.\n\nAvailable balance: **1000 Stars**.\n\nBuy **Stars** to unlock **content and services** in miniapps on **Telegram**."
//            } else {
            textString = "Choose how many Stars you would like to buy."
//            }
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: accentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: textString,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.2),
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
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets - 8.0, height: 240.0),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height + text.size.height / 2.0))
                .appear(.default(alpha: true))
                .disappear(.default(alpha: true))
            )
            size.height += text.size.height
            size.height += 21.0
               
            let initialValues: [Int64] = [
                15,
                75,
                250,
                500,
                1000,
                2500
            ]
            
            let stars: [Int64: Int] = [
                15: 1,
                75: 2,
                250: 3,
                500: 4,
                1000: 5,
                2500: 6,
                25: 1,
                50: 1,
                100: 2,
                150: 2,
                350: 3,
                750: 4,
                1500: 5
            ]
            
            let externalStateUpdated = context.component.stateUpdated
            let layoutPerks = {
                size.height += 8.0
                                
                var i = 0
                var items: [AnyComponentWithIdentity<Empty>] = []
                                                
                guard let products = state.products else {
                    return
                }
                for product in products {
                    if !context.component.expanded && !initialValues.contains(product.option.count) {
                        continue
                    }
                        
                    let title = "\(product.option.count) Stars"
                    let price = product.price
                    
                    let titleComponent = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.medium(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    ))
                    
                    let buy = context.component.buy
                    items.append(AnyComponentWithIdentity(
                        id: product.id,
                        component: AnyComponent(ListSectionComponent(
                            theme: environment.theme,
                            header: nil,
                            footer: nil,
                            items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: titleComponent,
                                contentInsets: UIEdgeInsets(top: 12.0, left: -6.0, bottom: 12.0, right: 0.0),
                                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(StarsIconComponent(
                                    count: stars[product.option.count] ?? 1
                                )))),
                                accessory: .custom(ListActionItemComponent.CustomAccessory(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: price,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 0
                                ))), insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 16.0))),
                                action: { _ in
                                    buy(product)
                                }
                            )))]
                        ))
                    ))
                    i += 1
                }
                
                if !context.component.expanded {
                    let titleComponent = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Show More Options",
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemAccentColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    ))
                    
                    let titleCombinedComponent = AnyComponent(HStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: titleComponent),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(BundleIconComponent(name: "Chat/Input/Search/DownButton", tintColor: environment.theme.list.itemAccentColor)))
                    ], spacing: 1.0))
                    
                    items.append(AnyComponentWithIdentity(
                        id: items.count,
                        component: AnyComponent(ListSectionComponent(
                            theme: environment.theme,
                            header: nil,
                            footer: nil,
                            items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: titleCombinedComponent,
                                titleAlignment: .center,
                                contentInsets: UIEdgeInsets(top: 7.0, left: 0.0, bottom: 7.0, right: 0.0),
                                leftIcon: nil,
                                accessory: .none,
                                action: { _ in
                                    externalStateUpdated(.easeInOut(duration: 0.3))
                                }
                            )))]
                        ))
                    ))
                }
 
                let list = list.update(
                    component: VStack(items, spacing: 16.0),
                    environment: {},
                    availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(list
                    .position(CGPoint(x: availableWidth / 2.0, y: size.height + list.size.height / 2.0))
                )
                size.height += list.size.height
                
                size.height += 23.0
            }
            
            layoutPerks()
            
            
            let termsFont = Font.regular(13.0)
            let termsTextColor = environment.theme.list.freeTextColor
            let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsFont, textColor: environment.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let textSideInset: CGFloat = 16.0
            
            let termsText = termsText.update(
                component: BalancedTextComponent(
                    text: .markdown(text: "By proceeding and purchasing Stars, you agree with [Terms and Conditions]().", attributes: termsMarkdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        
                    }
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets - textSideInset * 3.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(termsText
                .position(CGPoint(x: availableWidth / 2.0, y: size.height + termsText.size.height / 2.0))
            )
            size.height += termsText.size.height
            size.height += 10.0
            
            size.height += scrollEnvironment.insets.bottom
            
            return size
        }
    }
}

private final class StarsPurchaseScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let starsContext: StarsContext
    let options: [StarsTopUpOption]
    let peerId: EnginePeer.Id?
    let requiredStars: Int32?
    let forceDark: Bool
    let updateInProgress: (Bool) -> Void
    let present: (ViewController) -> Void
    let completion: () -> Void
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        options: [StarsTopUpOption],
        peerId: EnginePeer.Id?,
        requiredStars: Int32?,
        forceDark: Bool,
        updateInProgress: @escaping (Bool) -> Void,
        present: @escaping (ViewController) -> Void,
        completion: @escaping () -> Void
    ) {
        self.context = context
        self.starsContext = starsContext
        self.options = options
        self.peerId = peerId
        self.requiredStars = requiredStars
        self.forceDark = forceDark
        self.updateInProgress = updateInProgress
        self.present = present
        self.completion = completion
    }
        
    static func ==(lhs: StarsPurchaseScreenComponent, rhs: StarsPurchaseScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.starsContext !== rhs.starsContext {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.requiredStars != rhs.requiredStars {
            return false
        }
        if lhs.forceDark != rhs.forceDark {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let updateInProgress: (Bool) -> Void
        private let present: (ViewController) -> Void
        private let completion: () -> Void
        
        var topContentOffset: CGFloat?
        var bottomContentOffset: CGFloat?
        
        var hasIdleAnimations = true
        
        var inProgress = false
        
        private(set) var promoConfiguration: PremiumPromoConfiguration?
        
        private(set) var products: [StarsProduct]?
        private(set) var starsState: StarsContext.State?
                
        let animationCache: AnimationCache
        let animationRenderer: MultiAnimationRenderer
                
        private var disposable: Disposable?
        private var paymentDisposable = MetaDisposable()
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(
            context: AccountContext,
            starsContext: StarsContext,
            initialOptions: [StarsTopUpOption],
            updateInProgress: @escaping (Bool) -> Void,
            present: @escaping (ViewController) -> Void,
            completion: @escaping () -> Void
        ) {
            self.context = context
            self.updateInProgress = updateInProgress
            self.present = present
            self.completion = completion
            
            self.animationCache = context.animationCache
            self.animationRenderer = context.animationRenderer
            
            super.init()
            
            let availableProducts: Signal<[InAppPurchaseManager.Product], NoError>
            if let inAppPurchaseManager = context.inAppPurchaseManager {
                availableProducts = inAppPurchaseManager.availableProducts
            } else {
                availableProducts = .single([])
            }
            
            let options: Signal<[StarsTopUpOption], NoError>
            if !initialOptions.isEmpty {
                options = .single(initialOptions)
            } else {
                options = .single([]) |> then(context.engine.payments.starsTopUpOptions())
            }
                                    
            self.disposable = combineLatest(
                queue: Queue.mainQueue(),
                availableProducts,
                options,
                starsContext.state
            ).start(next: { [weak self] availableProducts, options, starsState in
                guard let self else {
                    return
                }
                var products: [StarsProduct] = []
                for option in options {
                    if let product = availableProducts.first(where: { $0.id == option.storeProductId }) {
                        products.append(StarsProduct(option: option, storeProduct: product))
                    }
                }

                self.products = products.sorted(by: { $0.option.count < $1.option.count })
                self.starsState = starsState
                
                self.updated(transition: .immediate)
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.paymentDisposable.dispose()
        }
        
        func buy(product: StarsProduct) {
            guard let inAppPurchaseManager = self.context.inAppPurchaseManager, !self.inProgress else {
                return
            }
            
            self.inProgress = true
            self.updateInProgress(true)
            self.updated(transition: .immediate)
            
            let (currency, amount) = product.storeProduct.priceCurrencyAndAmount
            let purpose: AppStoreTransactionPurpose = .stars(count: product.option.count, currency: currency, amount: amount)
            
            let _ = (self.context.engine.payments.canPurchasePremium(purpose: purpose)
            |> deliverOnMainQueue).start(next: { [weak self] available in
                if let strongSelf = self {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    if available {
                        strongSelf.paymentDisposable.set((inAppPurchaseManager.buyProduct(product.storeProduct, purpose: purpose)
                        |> deliverOnMainQueue).start(next: { [weak self] status in
                            if let self, case .purchased = status {
                                self.inProgress = false
                                self.updateInProgress(false)
                                
                                self.updated(transition: .easeInOut(duration: 0.25))
                                self.completion()
                            }
                        }, error: { [weak self] error in
                            if let strongSelf = self {
                                strongSelf.inProgress = false
                                strongSelf.updateInProgress(false)
                                strongSelf.updated(transition: .immediate)

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
        
        var isExpanded = false
    }
    
    func makeState() -> State {
        return State(context: self.context, starsContext: self.starsContext, initialOptions: self.options, updateInProgress: self.updateInProgress, present: self.present, completion: self.completion)
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scrollContent = Child(ScrollComponent<EnvironmentType>.self)
        let star = Child(PremiumStarComponent.self)
        let topPanel = Child(BlurredBackgroundComponent.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let balanceText = Child(MultilineTextComponent.self)
        
        let scrollAction = ActionSlot<CGPoint?>()
                
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let state = context.state
                        
            let background = background.update(component: Rectangle(color: environment.theme.list.blocksBackgroundColor), environment: {}, availableSize: context.availableSize, transition: context.transition)
            
            var starIsVisible = true
            if let topContentOffset = state.topContentOffset, topContentOffset >= 123.0 {
                starIsVisible = false
            }

            let header = star.update(
                component: PremiumStarComponent(
                    isIntro: true,
                    isVisible: starIsVisible,
                    hasIdleAnimations: state.hasIdleAnimations,
                    colors: [
                        UIColor(rgb: 0xea8904),
                        UIColor(rgb: 0xf09903),
                        UIColor(rgb: 0xfec209),
                        UIColor(rgb: 0xfed31a)
                    ]
                ),
                availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                transition: context.transition
            )
            
            let topPanel = topPanel.update(
                component: BlurredBackgroundComponent(
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
            
            //TODO:localize
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Get Stars", font: Font.bold(28.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )

            let textColor = environment.theme.list.itemPrimaryTextColor
            let accentColor = UIColor(rgb: 0x597cf5)
            
            let textFont = Font.regular(14.0)
            let boldTextFont = Font.bold(14.0)
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: accentColor), linkAttribute: { _ in
                return nil
            })
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: UIColor(rgb: 0xf09903))!, environment.theme)
            }
            
            let balanceAttributedString = parseMarkdownIntoAttributedString("Balance:  *  **\(state.starsState?.balance ?? 0)**", attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
            if let range = balanceAttributedString.string.range(of: "*"), let chevronImage = state.cachedChevronImage?.0 {
                balanceAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: balanceAttributedString.string))
                balanceAttributedString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xf09903), range: NSRange(range, in: balanceAttributedString.string))
                balanceAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: balanceAttributedString.string))
            }
            let balanceText = balanceText.update(
                component: MultilineTextComponent(
                    text: .plain(balanceAttributedString),
                    horizontalAlignment: .left,
                    maximumNumberOfLines: 0
                ),
                availableSize: CGSize(width: 200, height: context.availableSize.height),
                transition: .immediate
            )
              
            let scrollContent = scrollContent.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(StarsPurchaseScreenContentComponent(
                        context: context.component.context,
                        options: context.component.options,
                        peerId: context.component.peerId,
                        requiredStars: context.component.requiredStars,
                        forceDark: context.component.forceDark,
                        products: state.products,
                        expanded: state.isExpanded,
                        stateUpdated: { [weak state] transition in
                            scrollAction.invoke(CGPoint(x: 0.0, y: 176.0))
                            state?.isExpanded = true
                            state?.updated(transition: transition)
                        },
                        buy: { [weak state] product in
                            state?.buy(product: product)
                        }
                    )),
                    contentInsets: UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0),
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
                        } else if targetContentOffset.pointee.y < 176.0 {
                            targetContentOffset.pointee = CGPoint(x: 0.0, y: 176.0)
                        }
                    },
                    resetScroll: scrollAction
                ),
                environment: { environment },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let topInset: CGFloat = environment.navigationHeight - 56.0
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
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
            
            context.add(header
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topInset + header.size.height / 2.0 - 30.0 - titleOffset * titleScale))
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
            
            context.add(balanceText
                .position(CGPoint(x: context.availableSize.width - 16.0 - balanceText.size.width / 2.0, y: 28.0))
            )
                                    
            return context.availableSize
        }
    }
}

public final class StarsPurchaseScreen: ViewControllerComponentContainer {
    fileprivate let context: AccountContext
    fileprivate let starsContext: StarsContext
    fileprivate let options: [StarsTopUpOption]
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
        
    public init(
        context: AccountContext,
        starsContext: StarsContext,
        options: [StarsTopUpOption],
        peerId: EnginePeer.Id?,
        requiredStars: Int32?,
        modal: Bool = true,
        forceDark: Bool = false
    ) {
        self.context = context
        self.starsContext = starsContext
        self.options = options
            
        var updateInProgressImpl: ((Bool) -> Void)?
        var presentImpl: ((ViewController) -> Void)?
        var completionImpl: (() -> Void)?
        super.init(context: context, component: StarsPurchaseScreenComponent(
            context: context,
            starsContext: starsContext,
            options: options,
            peerId: peerId,
            requiredStars: requiredStars,
            forceDark: forceDark,
            updateInProgress: { inProgress in
                updateInProgressImpl?(inProgress)
            },
            present: { c in
                presentImpl?(c)
            },
            completion: {
                completionImpl?()
            }
        ), navigationBarAppearance: .transparent, presentationMode: modal ? .modal : .default, theme: forceDark ? .dark : .default)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        if modal {
            let cancelItem = UIBarButtonItem(title: presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.cancelPressed))
            self.navigationItem.setLeftBarButton(cancelItem, animated: false)
            self.navigationPresentation = .modal
        } else {
            self.navigationPresentation = .modalInLargeLayout
        }
        
        updateInProgressImpl = { [weak self] inProgress in
            if let strongSelf = self {
                strongSelf.navigationItem.leftBarButtonItem?.isEnabled = !inProgress
                strongSelf.view.disablesInteractiveTransitionGestureRecognizer = inProgress
                strongSelf.view.disablesInteractiveModalDismiss = inProgress
            }
        }
        presentImpl = { [weak self] c in
            if let self {
                self.present(c, in: .window(.root))
            }
        }
        completionImpl = { [weak self] in
            if let self {
                self.animateSuccess()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
        self.wasDismissed?()
    }
    
    public func animateSuccess() {
        self.dismiss()
        self.navigationController?.view.addSubview(ConfettiView(frame: self.view.bounds, customImage: UIImage(bundleImageName: "Peer Info/PremiumIcon")))
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if !self.didSetReady {
            if let view = self.node.hostView.findTaggedView(tag: PremiumStarComponent.View.Tag()) as? PremiumStarComponent.View {
                self.didSetReady = true
                self._ready.set(view.ready)
            }
        }
    }
}

func generateStarsIcon(count: Int) -> UIImage {
    let image = generateGradientTintedImage(
        image: UIImage(bundleImageName: "Peer Info/PremiumIcon"),
        colors: [
            UIColor(rgb: 0xfed219),
            UIColor(rgb: 0xf3a103),
            UIColor(rgb: 0xe78104)
        ],
        direction: .diagonal
    )!
    
    let imageSize = CGSize(width: 20.0, height: 20.0)
    let partImage = generateImage(imageSize, contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size), byTiling: false)
            context.saveGState()
            context.clip(to: CGRect(origin: .zero, size: size).insetBy(dx: -1.0, dy: -1.0).offsetBy(dx: -2.0, dy: 0.0), mask: cgImage)
            
            context.setBlendMode(.clear)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.restoreGState()
            
            context.setBlendMode(.clear)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width / 2.0, height: size.height - 4.0)))
        }
    })!
    
    let spacing: CGFloat = (3.0 - UIScreenPixel)
    let totalWidth = 20.0 + spacing * CGFloat(count - 1)
    
    return generateImage(CGSize(width: ceil(totalWidth), height: 20.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        var originX = floorToScreenPixels((size.width - totalWidth) / 2.0)
        
        if let cgImage = image.cgImage, let partCGImage = partImage.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: originX, y: 0.0), size: imageSize), byTiling: false)
            originX += spacing
            
            for _ in 0 ..< count - 1 {
                context.draw(partCGImage, in: CGRect(origin: CGPoint(x: originX, y: 0.0), size: imageSize), byTiling: false)
                originX += spacing
            }
        }
    })!
}

final class StarsIconComponent: CombinedComponent {
    let count: Int
    
    init(
        count: Int
    ) {
        self.count = count
    }
    
    static func ==(lhs: StarsIconComponent, rhs: StarsIconComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        return true
    }
    
    static var body: Body {
        let icon = Child(Image.self)
        
        var image: (UIImage, Int)?
        
        return { context in
            if image == nil || image?.1 != context.component.count {
                image = (generateStarsIcon(count: context.component.count), context.component.count)
            }
            
            let iconSize = CGSize(width: image!.0.size.width, height: 20.0)
            
            let icon = icon.update(
                component: Image(image: image?.0),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let iconPosition = CGPoint(x: iconSize.width / 2.0, y: iconSize.height / 2.0)
            context.add(icon
                .position(iconPosition)
            )
            return iconSize
        }
    }
}
