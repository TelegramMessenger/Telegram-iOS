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
import ItemShimmeringLoadingComponent

private struct StarsProduct: Equatable {
    enum Option: Equatable {
        case topUp(StarsTopUpOption)
        case gift(StarsGiftOption)
    }
    
    let option: Option
    let storeProduct: InAppPurchaseManager.Product
    
    var count: Int64 {
        switch self.option {
        case let .topUp(option):
            return option.count
        case let .gift(option):
            return option.count
        }
    }
    
    var isExtended: Bool {
        switch self.option {
        case let .topUp(option):
            return option.isExtended
        case let .gift(option):
            return option.isExtended
        }
    }
    
    var id: String {
        return self.storeProduct.id
    }

    var price: String {
        return self.storeProduct.price
    }
}

private final class StarsPurchaseScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    public class ExternalState {
        public var descriptionHeight: CGFloat = 0.0
        
        public init() {
            
        }
    }
    
    let context: AccountContext
    let externalState: ExternalState
    let containerSize: CGSize
    let balance: StarsAmount?
    let options: [Any]
    let purpose: StarsPurchasePurpose
    let selectedProductId: String?
    let forceDark: Bool
    let products: [StarsProduct]?
    let expanded: Bool
    let peers: [EnginePeer.Id: EnginePeer]
    let stateUpdated: (ComponentTransition) -> Void
    let buy: (StarsProduct) -> Void
    let openAppExamples: () -> Void
    
    init(
        context: AccountContext,
        externalState: ExternalState,
        containerSize: CGSize,
        balance: StarsAmount?,
        options: [Any],
        purpose: StarsPurchasePurpose,
        selectedProductId: String?,
        forceDark: Bool,
        products: [StarsProduct]?,
        expanded: Bool,
        peers: [EnginePeer.Id: EnginePeer],
        stateUpdated: @escaping (ComponentTransition) -> Void,
        buy: @escaping (StarsProduct) -> Void,
        openAppExamples: @escaping () -> Void
    ) {
        self.context = context
        self.externalState = externalState
        self.containerSize = containerSize
        self.balance = balance
        self.options = options
        self.purpose = purpose
        self.selectedProductId = selectedProductId
        self.forceDark = forceDark
        self.products = products
        self.expanded = expanded
        self.peers = peers
        self.stateUpdated = stateUpdated
        self.buy = buy
        self.openAppExamples = openAppExamples
    }
    
    static func ==(lhs: StarsPurchaseScreenContentComponent, rhs: StarsPurchaseScreenContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.containerSize != rhs.containerSize {
            return false
        }
        if lhs.purpose != rhs.purpose {
            return false
        }
        if lhs.selectedProductId != rhs.selectedProductId {
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
        if lhs.peers != rhs.peers {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        var products: [StarsProduct]?
        
        private var disposable: Disposable?

        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(
            context: AccountContext,
            purpose: StarsPurchasePurpose
        ) {
            self.context = context
            
            super.init()
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, purpose: self.purpose)
    }
    
    static var body: Body {
        let text = Child(BalancedTextComponent.self)
        let list = Child(VStack<Empty>.self)
        let termsText = Child(BalancedTextComponent.self)
             
        return { context in
            let sideInset: CGFloat = 16.0
    
            let component = context.component
            let scrollEnvironment = context.environment[ScrollChildEnvironment.self].value
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
    
            state.products = component.products
            
            let theme = environment.theme
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let availableWidth = context.availableSize.width
            let sideInsets = sideInset * 2.0 + environment.safeInsets.left + environment.safeInsets.right
            var size = CGSize(width: context.availableSize.width, height: 0.0)
                        
            size.height += 183.0 + 10.0 + environment.navigationHeight - 56.0
            
            let textColor = theme.list.itemPrimaryTextColor
            let accentColor = theme.list.itemAccentColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            let textString: String
            switch context.component.purpose {
            case .generic:
                textString = strings.Stars_Purchase_GetStarsInfo
            case let .topUp(_, purpose):
                var text = strings.Stars_Purchase_GenericPurchasePurpose
                if let purpose, !purpose.isEmpty {
                    switch purpose {
                    case "subs":
                        text = strings.Stars_Purchase_PurchasePurpose_subs
                    default:
                        let key = "Stars.Purchase.PurchasePurpose.\(purpose)"
                        if let string = strings.primaryComponent.dict[key] {
                            text = string
                        } else if let string = strings.secondaryComponent?.dict[key] {
                            text = string
                        }
                    }
                }
                textString = text
            case .gift:
                textString = strings.Stars_Purchase_GiftInfo(component.peers.first?.value.compactDisplayTitle ?? "").string
            case .transfer:
                textString = strings.Stars_Purchase_StarsNeededInfo(component.peers.first?.value.compactDisplayTitle ?? "").string
            case .reactions:
                textString = strings.Stars_Purchase_StarsReactionsNeededInfo(component.peers.first?.value.compactDisplayTitle ?? "").string
            case let .subscription(_, _, renew):
                textString = renew ? strings.Stars_Purchase_SubscriptionRenewInfo(component.peers.first?.value.compactDisplayTitle ?? "").string : strings.Stars_Purchase_SubscriptionInfo(component.peers.first?.value.compactDisplayTitle ?? "").string
            case .unlockMedia:
                textString = strings.Stars_Purchase_StarsNeededUnlockInfo
            case .starGift:
                textString = strings.Stars_Purchase_StarGiftInfo(component.peers.first?.value.compactDisplayTitle ?? "").string
            case .upgradeStarGift:
                textString = strings.Stars_Purchase_UpgradeStarGiftInfo
            }
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: accentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: accentColor)!, theme)
            }
            
            let textAttributedString = parseMarkdownIntoAttributedString(textString, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
            
            if let range = textAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                textAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: textAttributedString.string))
            }
            
            let openAppExamples = component.openAppExamples
            let text = text.update(
                component: BalancedTextComponent(
                    text: .plain(textAttributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        openAppExamples()
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
            
            context.component.externalState.descriptionHeight = text.size.height
            
            let externalStateUpdated = context.component.stateUpdated
            
            size.height += 8.0
                            
            var i = 0
            var items: [AnyComponentWithIdentity<Empty>] = []
                           
            if let products = state.products, let balance = context.component.balance {
                var minimumCount: StarsAmount?
                if let requiredStars = context.component.purpose.requiredStars {
                    if case .generic = context.component.purpose {
                        minimumCount = StarsAmount(value: requiredStars, nanos: 0)
                    } else {
                        minimumCount = StarsAmount(value: requiredStars, nanos: 0) - balance
                    }
                }
                
                for product in products {
                    if let minimumCount, minimumCount > StarsAmount(value: product.count, nanos: 0) && !(items.isEmpty && product.id == products.last?.id) {
                        continue
                    }
                    
                    if let _ = minimumCount, items.isEmpty {
                        
                    } else if !context.component.expanded && product.isExtended {
                        continue
                    }
                    
                    let title = strings.Stars_Purchase_Stars(Int32(product.count))
                    let price = product.price
                    
                    let titleComponent = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.medium(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    ))
                    
                    let backgroundComponent: AnyComponent<Empty>?
                    if product.storeProduct.id == context.component.selectedProductId {
                        backgroundComponent = AnyComponent(
                            ItemShimmeringLoadingComponent(color: environment.theme.list.itemAccentColor)
                        )
                    } else {
                        backgroundComponent = nil
                    }
                    
                    let buy = context.component.buy
                    items.append(AnyComponentWithIdentity(
                        id: product.id,
                        component: AnyComponent(ListSectionComponent(
                            theme: environment.theme,
                            header: nil,
                            footer: nil,
                            items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                background: backgroundComponent,
                                title: titleComponent,
                                contentInsets: UIEdgeInsets(top: 12.0, left: -6.0, bottom: 12.0, right: 0.0),
                                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(StarsIconComponent(
                                    amount: product.count
                                ))), true),
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
                                },
                                highlighting: .disabled,
                                updateIsHighlighted: { view, isHighlighted in
                                    let transition: ComponentTransition = .easeInOut(duration: 0.25)
                                    if let superview = view.superview {
                                        transition.setScale(view: superview, scale: isHighlighted ? 0.9 : 1.0)
                                    }
                                }
                            )))]
                        ))
                    ))
                    i += 1
                }
            }
            
            if !context.component.expanded && items.count > 1 {
                let titleComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.Stars_Purchase_ShowMore,
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

            
            let termsFont = Font.regular(13.0)
            let termsTextColor = environment.theme.list.freeTextColor
            let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsFont, textColor: environment.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let textSideInset: CGFloat = 16.0
            
            let termsText = termsText.update(
                component: BalancedTextComponent(
                    text: .markdown(text: strings.Stars_Purchase_Info, attributes: termsMarkdownAttributes),
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
                        component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Stars_Purchase_Terms_URL, forceExternal: false, presentationData: presentationData, navigationController: nil, dismissInput: {})
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
            
            if context.component.expanded {
                size.height = max(size.height, component.containerSize.height + 150.0 + text.size.height)
            }
            
            return size
        }
    }
}

private final class StarsPurchaseScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let starsContext: StarsContext
    let options: [Any]
    let purpose: StarsPurchasePurpose
    let forceDark: Bool
    let openAppExamples: () -> Void
    let updateInProgress: (Bool) -> Void
    let present: (ViewController) -> Void
    let completion: (Int64) -> Void
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        options: [Any],
        purpose: StarsPurchasePurpose,
        forceDark: Bool,
        openAppExamples: @escaping () -> Void,
        updateInProgress: @escaping (Bool) -> Void,
        present: @escaping (ViewController) -> Void,
        completion: @escaping (Int64) -> Void
    ) {
        self.context = context
        self.starsContext = starsContext
        self.options = options
        self.purpose = purpose
        self.forceDark = forceDark
        self.openAppExamples = openAppExamples
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
        if lhs.purpose != rhs.purpose {
            return false
        }
        if lhs.forceDark != rhs.forceDark {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let purpose: StarsPurchasePurpose
        
        private let updateInProgress: (Bool) -> Void
        private let present: (ViewController) -> Void
        private let completion: (Int64) -> Void
        
        var topContentOffset: CGFloat?
        var bottomContentOffset: CGFloat?
        
        var hasIdleAnimations = true
        
        var progressProduct: StarsProduct?
                
        private(set) var products: [StarsProduct]?
        private(set) var starsState: StarsContext.State?
        
        var peers: [EnginePeer.Id: EnginePeer] = [:]
                
        let animationCache: AnimationCache
        let animationRenderer: MultiAnimationRenderer
                
        private var disposable: Disposable?
        private var paymentDisposable = MetaDisposable()
        
        init(
            context: AccountContext,
            starsContext: StarsContext,
            purpose: StarsPurchasePurpose,
            initialOptions: [Any],
            updateInProgress: @escaping (Bool) -> Void,
            present: @escaping (ViewController) -> Void,
            completion: @escaping (Int64) -> Void
        ) {
            self.context = context
            self.purpose = purpose
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
                        
            let products: Signal<[StarsProduct], NoError>
            switch purpose {
            case .gift:
                let options: Signal<[StarsGiftOption], NoError>
                if !initialOptions.isEmpty, let initialGiftOptions = initialOptions as? [StarsGiftOption] {
                    options = .single(initialGiftOptions)
                } else {
                    options = .single([]) |> then(context.engine.payments.starsGiftOptions(peerId: nil))
                }
                products = combineLatest(availableProducts, options)
                |> map { availableProducts, options in
                    var products: [StarsProduct] = []
                    for option in options {
                        if let product = availableProducts.first(where: { $0.id == option.storeProductId }) {
                            products.append(StarsProduct(option: .gift(option), storeProduct: product))
                        }
                    }
                    return products
                }
            default:
                let options: Signal<[StarsTopUpOption], NoError>
                if !initialOptions.isEmpty, let initialTopUpOptions = initialOptions as? [StarsTopUpOption] {
                    options = .single(initialTopUpOptions)
                } else {
                    options = .single([]) |> then(context.engine.payments.starsTopUpOptions())
                }
                products = combineLatest(availableProducts, options)
                |> map { availableProducts, options in
                    var products: [StarsProduct] = []
                    for option in options {
                        if let product = availableProducts.first(where: { $0.id == option.storeProductId }) {
                            products.append(StarsProduct(option: .topUp(option), storeProduct: product))
                        }
                    }
                    return products
                }
            }
                      
            let peerIds = purpose.peerIds
            self.disposable = combineLatest(
                queue: Queue.mainQueue(),
                products,
                starsContext.state,
                context.engine.data.get(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
            ).start(next: { [weak self] products, starsState, result in
                guard let self else {
                    return
                }
                self.products = products.sorted(by: { $0.count < $1.count })
                self.starsState = starsState
                
                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for peerId in peerIds {
                    if let maybePeer = result[peerId], let peer = maybePeer {
                        peers[peerId] = peer
                    }
                }
                self.peers = peers
                
                self.updated(transition: .immediate)
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.paymentDisposable.dispose()
        }
        
        func buy(product: StarsProduct) {
            guard let inAppPurchaseManager = self.context.inAppPurchaseManager, self.progressProduct == nil else {
                return
            }
            
            self.progressProduct = product
            self.updateInProgress(true)
            self.updated(transition: .easeInOut(duration: 0.2))
            
            let (currency, amount) = product.storeProduct.priceCurrencyAndAmount
            let purpose: AppStoreTransactionPurpose
            switch self.purpose {
            case let .gift(peerId):
                purpose = .starsGift(peerId: peerId, count: product.count, currency: currency, amount: amount)
            default:
                purpose = .stars(count: product.count, currency: currency, amount: amount)
            }
            
            let _ = (self.context.engine.payments.canPurchasePremium(purpose: purpose)
            |> deliverOnMainQueue).start(next: { [weak self] available in
                if let strongSelf = self {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    if available {
                        strongSelf.paymentDisposable.set((inAppPurchaseManager.buyProduct(product.storeProduct, purpose: purpose)
                        |> deliverOnMainQueue).start(next: { [weak self] status in
                            if let self, case .purchased = status {
                                self.updateInProgress(false)
                                
                                self.updated(transition: .easeInOut(duration: 0.2))
                                self.completion(product.count)
                            }
                        }, error: { [weak self] error in
                            if let strongSelf = self {
                                strongSelf.progressProduct = nil
                                strongSelf.updateInProgress(false)
                                strongSelf.updated(transition: .easeInOut(duration: 0.2))

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
                                        errorText = presentationData.strings.Premium_Purchase_ErrorTryLater
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
                        strongSelf.progressProduct = nil
                        strongSelf.updateInProgress(false)
                        strongSelf.updated(transition: .easeInOut(duration: 0.2))
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
        return State(context: self.context, starsContext: self.starsContext, purpose: self.purpose, initialOptions: self.options, updateInProgress: self.updateInProgress, present: self.present, completion: self.completion)
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scrollContent = Child(ScrollComponent<EnvironmentType>.self)
        let star = Child(PremiumStarComponent.self)
        let avatar = Child(GiftAvatarComponent.self)
        let topPanel = Child(BlurredBackgroundComponent.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let balanceTitle = Child(MultilineTextComponent.self)
        let balanceValue = Child(MultilineTextComponent.self)
        let balanceIcon = Child(BundleIconComponent.self)
        
        let scrollAction = ActionSlot<CGPoint?>()
        
        let contentExternalState = StarsPurchaseScreenContentComponent.ExternalState()
                
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let state = context.state
            
            let strings = environment.strings
                        
            let background = background.update(component: Rectangle(color: environment.theme.list.blocksBackgroundColor), environment: {}, availableSize: context.availableSize, transition: context.transition)
            
            var starIsVisible = true
            if let topContentOffset = state.topContentOffset, topContentOffset >= 123.0 {
                starIsVisible = false
            }

            let header: _UpdatedChildComponent
            if case let .gift(peerId) = context.component.purpose {
                var peers: [EnginePeer] = []
                if let peer = state.peers[peerId] {
                    peers.append(peer)
                }
                header = avatar.update(
                    component: GiftAvatarComponent(
                        context: context.component.context,
                        theme: environment.theme,
                        peers: peers,
                        isVisible: starIsVisible,
                        hasIdleAnimations: state.hasIdleAnimations,
                        color: UIColor(rgb: 0xf9b004),
                        hasLargeParticles: true
                    ),
                    availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
            } else {
                header = star.update(
                    component: PremiumStarComponent(
                        theme: environment.theme,
                        isIntro: true,
                        isVisible: starIsVisible,
                        hasIdleAnimations: state.hasIdleAnimations,
                        colors: [
                            UIColor(rgb: 0xe57d02),
                            UIColor(rgb: 0xf09903),
                            UIColor(rgb: 0xf9b004),
                            UIColor(rgb: 0xfdd219)
                        ],
                        particleColor: UIColor(rgb: 0xf9b004),
                        backgroundColor: environment.theme.list.blocksBackgroundColor
                    ),
                    availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                    transition: context.transition
                )
            }
            
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
            
            let titleText: String
            switch context.component.purpose {
            case .generic:
                titleText = strings.Stars_Purchase_GetStars
            case .gift:
                titleText = strings.Stars_Purchase_GiftStars
            case let .topUp(requiredStars, _), let .transfer(_, requiredStars), let .reactions(_, requiredStars), let .subscription(_, requiredStars, _), let .unlockMedia(requiredStars), let .starGift(_, requiredStars), let .upgradeStarGift(requiredStars):
                titleText = strings.Stars_Purchase_StarsNeeded(Int32(requiredStars))
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.bold(28.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )

            let balanceTitle = balanceTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Stars_Purchase_Balance,
                        font: Font.regular(14.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            let starsBalance: StarsAmount = state.starsState?.balance ?? StarsAmount.zero
            let balanceValue = balanceValue.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: presentationStringsFormattedNumber(starsBalance, environment.dateTimeFormat.groupingSeparator),
                        font: Font.semibold(14.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
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
              
            let scrollContent = scrollContent.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(StarsPurchaseScreenContentComponent(
                        context: context.component.context,
                        externalState: contentExternalState,
                        containerSize: context.availableSize,
                        balance: state.starsState?.balance,
                        options: context.component.options,
                        purpose: context.component.purpose,
                        selectedProductId: state.progressProduct?.storeProduct.id,
                        forceDark: context.component.forceDark,
                        products: state.products,
                        expanded: state.isExpanded,
                        peers: state.peers,
                        stateUpdated: { [weak state] transition in
                            scrollAction.invoke(CGPoint(x: 0.0, y: 150.0 + contentExternalState.descriptionHeight))
                            state?.isExpanded = true
                            state?.updated(transition: transition)
                        },
                        buy: { [weak state] product in
                            state?.buy(product: product)
                        },
                        openAppExamples: context.component.openAppExamples
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
                        let anchorOffset = 150.0 + contentExternalState.descriptionHeight
                        if targetContentOffset.pointee.y < 100.0 {
                            targetContentOffset.pointee = CGPoint(x: 0.0, y: 0.0)
                        } else if targetContentOffset.pointee.y < anchorOffset {
                            targetContentOffset.pointee = CGPoint(x: 0.0, y: anchorOffset)
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
            
            let navigationHeight = environment.navigationHeight - environment.statusBarHeight
            let topBalanceOriginY = environment.statusBarHeight + (navigationHeight - balanceTitle.size.height - balanceValue.size.height) / 2.0
            context.add(balanceTitle
                .position(CGPoint(x: context.availableSize.width - 16.0 - environment.safeInsets.right - balanceTitle.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height / 2.0))
            )
            context.add(balanceValue
                .position(CGPoint(x: context.availableSize.width - 16.0 - environment.safeInsets.right - balanceValue.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0))
            )
            context.add(balanceIcon
                .position(CGPoint(x: context.availableSize.width - 16.0 - environment.safeInsets.right - balanceValue.size.width - balanceIcon.size.width / 2.0 - 2.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0 - UIScreenPixel))
            )
                                    
            return context.availableSize
        }
    }
}

public final class StarsPurchaseScreen: ViewControllerComponentContainer {
    fileprivate let context: AccountContext
    fileprivate let starsContext: StarsContext
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
        
    public init(
        context: AccountContext,
        starsContext: StarsContext,
        options: [Any] = [],
        purpose: StarsPurchasePurpose,
        completion: @escaping (Int64) -> Void = { _ in }
    ) {
        self.context = context
        self.starsContext = starsContext
            
        var openAppExamplesImpl: (() -> Void)?
        var updateInProgressImpl: ((Bool) -> Void)?
        var presentImpl: ((ViewController) -> Void)?
        var completionImpl: ((Int64) -> Void)?
        super.init(context: context, component: StarsPurchaseScreenComponent(
            context: context,
            starsContext: starsContext,
            options: options,
            purpose: purpose,
            forceDark: false,
            openAppExamples: {
                openAppExamplesImpl?()
            },
            updateInProgress: { inProgress in
                updateInProgressImpl?(inProgress)
            },
            present: { c in
                presentImpl?(c)
            },
            completion: { stars in
                completionImpl?(stars)
            }
        ), navigationBarAppearance: .transparent, presentationMode: .modal, theme: .default)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let cancelItem = UIBarButtonItem(title: presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.setLeftBarButton(cancelItem, animated: false)
        self.navigationPresentation = .modal
        
        openAppExamplesImpl = { [weak self] in
            guard let self else {
                return
            }
            let _ = (context.sharedContext.makeMiniAppListScreenInitialData(context: context)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] initialData in
                guard let self, let navigationController = self.navigationController as? NavigationController else {
                    return
                }
                navigationController.pushViewController(context.sharedContext.makeMiniAppListScreen(context: context, initialData: initialData))
            })
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
        completionImpl = { [weak self] stars in
            if let self {
                self.animateSuccess()
                
                completion(stars)
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
            } else if let view = self.node.hostView.findTaggedView(tag: GiftAvatarComponent.View.Tag()) as? GiftAvatarComponent.View {
                self.didSetReady = true
                self._ready.set(view.ready)
            }
        }
    }
}

func generateStarsIcon(amount: Int64) -> UIImage {
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
        1500: 5,
        
        5000: 6,
        10000: 6,
        25000: 7,
        35000: 7
    ]
    let count = stars[amount] ?? 1
    
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
        
        let mainImage = UIImage(bundleImageName: "Premium/Stars/StarLarge")
        if let cgImage = mainImage?.cgImage, let partCGImage = partImage.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: originX, y: 0.0), size: imageSize).insetBy(dx: -1.5, dy: -1.5), byTiling: false)
            originX += spacing + UIScreenPixel
            
            for _ in 0 ..< count - 1 {
                context.draw(partCGImage, in: CGRect(origin: CGPoint(x: originX, y: -UIScreenPixel), size: imageSize).insetBy(dx: -1.0 + UIScreenPixel, dy: -1.0 + UIScreenPixel), byTiling: false)
                originX += spacing
            }
        }
    })!
}

final class StarsIconComponent: CombinedComponent {
    let amount: Int64
    
    init(
        amount: Int64
    ) {
        self.amount = amount
    }
    
    static func ==(lhs: StarsIconComponent, rhs: StarsIconComponent) -> Bool {
        if lhs.amount != rhs.amount {
            return false
        }
        return true
    }
    
    static var body: Body {
        let icon = Child(Image.self)
        
        var image: (UIImage, Int64)?
        
        return { context in
            if image == nil || image?.1 != context.component.amount {
                image = (generateStarsIcon(amount: context.component.amount), context.component.amount)
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

private extension StarsPurchasePurpose {
    var peerIds: [EnginePeer.Id] {
        switch self {
        case let .gift(peerId):
            return [peerId]
        case let .transfer(peerId, _):
            return [peerId]
        case let .reactions(peerId, _):
            return [peerId]
        case let .subscription(peerId, _, _):
            return [peerId]
        case let .starGift(peerId, _):
            return [peerId]
        default:
            return []
        }
    }
    
    var requiredStars: Int64? {
        switch self {
        case let .topUp(requiredStars, _):
            return requiredStars
        case let .transfer(_, requiredStars):
            return requiredStars
        case let .reactions(_, requiredStars):
            return requiredStars
        case let .subscription(_, requiredStars, _):
            return requiredStars
        case let .unlockMedia(requiredStars):
            return requiredStars
        case let .starGift(_, requiredStars):
            return requiredStars
        case let .upgradeStarGift(requiredStars):
            return requiredStars
        default:
            return nil
        }
    }
}
