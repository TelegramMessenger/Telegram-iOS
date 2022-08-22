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
import CheckNode

private final class ProductGroupComponent: Component {
    public final class Item: Equatable {
        public let content: AnyComponentWithIdentity<Empty>
        public let action: () -> Void
        
        public init(_ content: AnyComponentWithIdentity<Empty>, action: @escaping () -> Void) {
            self.content = content
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.content != rhs.content {
                return false
            }
            
            return true
        }
    }
    
    let items: [Item]
    let backgroundColor: UIColor
    let selectionColor: UIColor
    
    init(
        items: [Item],
        backgroundColor: UIColor,
        selectionColor: UIColor
    ) {
        self.items = items
        self.backgroundColor = backgroundColor
        self.selectionColor = selectionColor
    }
    
    public static func ==(lhs: ProductGroupComponent, rhs: ProductGroupComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.selectionColor != rhs.selectionColor {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var buttonViews: [AnyHashable: HighlightTrackingButton] = [:]
        private var itemViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        
        private var component: ProductGroupComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed(_ sender: HighlightTrackingButton) {
            guard let component = self.component else {
                return
            }
            
            if let (id, _) = self.buttonViews.first(where: { $0.value === sender }), let item = component.items.first(where: { $0.content.id == id }) {
                item.action()
            }
        }
        
        func update(component: ProductGroupComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let spacing: CGFloat = 16.0
            var size = CGSize(width: availableSize.width, height: 0.0)
            
            var validIds: [AnyHashable] = []
            
            var i = 0
            for item in component.items {
                validIds.append(item.content.id)
                
                let buttonView: HighlightTrackingButton
                let itemView: ComponentHostView<Empty>
                var itemTransition = transition
                
                if let current = self.buttonViews[item.content.id] {
                    buttonView = current
                } else {
                    buttonView = HighlightTrackingButton()
                    buttonView.clipsToBounds = true
                    buttonView.layer.cornerRadius = 10.0
                    if #available(iOS 13.0, *) {
                        buttonView.layer.cornerCurve = .continuous
                    }
                    buttonView.isMultipleTouchEnabled = false
                    buttonView.isExclusiveTouch = true
                    buttonView.addTarget(self, action: #selector(self.buttonPressed(_:)), for: .touchUpInside)
                    self.buttonViews[item.content.id] = buttonView
                    self.addSubview(buttonView)
                }
                buttonView.backgroundColor = component.backgroundColor
                
                if let current = self.itemViews[item.content.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<Empty>()
                    self.itemViews[item.content.id] = itemView
                    self.addSubview(itemView)
                }
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.content.component,
                    environment: {},
                    containerSize: CGSize(width: size.width, height: .greatestFiniteMagnitude)
                )
                
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: itemSize)
                buttonView.frame = CGRect(origin: itemFrame.origin, size: CGSize(width: availableSize.width, height: itemSize.height + UIScreenPixel))
                itemView.frame = CGRect(origin: CGPoint(x: itemFrame.minX, y: itemFrame.minY + floor((itemFrame.height - itemSize.height) / 2.0)), size: itemSize)
                itemView.isUserInteractionEnabled = false
                
                buttonView.highligthedChanged = { [weak buttonView] highlighted in
                    if highlighted {
                        buttonView?.backgroundColor = component.selectionColor
                    } else {
                        UIView.animate(withDuration: 0.3, animations: {
                            buttonView?.backgroundColor = component.backgroundColor
                        })
                    }
                }
                
                size.height += itemSize.height + spacing
                
                i += 1
            }
            
            size.height -= spacing
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            self.component = component
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class GiftComponent: CombinedComponent {
    let title: String
    let totalPrice: String
    let perMonthPrice: String
    let discount: String
    let selected: Bool
    let primaryTextColor: UIColor
    let secondaryTextColor: UIColor
    let accentColor: UIColor
    let checkForegroundColor: UIColor
    let checkBorderColor: UIColor
    
    init(
        title: String,
        totalPrice: String,
        perMonthPrice: String,
        discount: String,
        selected: Bool,
        primaryTextColor: UIColor,
        secondaryTextColor: UIColor,
        accentColor: UIColor,
        checkForegroundColor: UIColor,
        checkBorderColor: UIColor
    ) {
        self.title = title
        self.totalPrice = totalPrice
        self.perMonthPrice = perMonthPrice
        self.discount = discount
        self.selected = selected
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.checkForegroundColor = checkForegroundColor
        self.checkBorderColor = checkBorderColor
    }
    
    static func ==(lhs: GiftComponent, rhs: GiftComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.totalPrice != rhs.totalPrice {
            return false
        }
        if lhs.perMonthPrice != rhs.perMonthPrice {
            return false
        }
        if lhs.discount != rhs.discount {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        if lhs.primaryTextColor != rhs.primaryTextColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.checkForegroundColor != rhs.checkForegroundColor {
            return false
        }
        if lhs.checkBorderColor != rhs.checkBorderColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let check = Child(CheckComponent.self)
        let title = Child(MultilineTextComponent.self)
        let discountBackground = Child(RoundedRectangle.self)
        let discount = Child(MultilineTextComponent.self)
        let subtitle = Child(MultilineTextComponent.self)
        let label = Child(MultilineTextComponent.self)
        let selection = Child(RoundedRectangle.self)
        
        return { context in
            let component = context.component
            
            let insets = UIEdgeInsets(top: 9.0, left: 62.0, bottom: 12.0, right: 16.0)
            
            let spacing: CGFloat = 2.0
            
            let label = label.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.totalPrice,
                            font: Font.regular(17),
                            textColor: component.secondaryTextColor
                        )
                    ),
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.title,
                            font: Font.regular(17),
                            textColor: component.primaryTextColor
                        )
                    ),
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - insets.left - insets.right - label.size.width, height: context.availableSize.height),
                transition: context.transition
            )
            
            let discountSize: CGSize
            if !component.discount.isEmpty {
                let discount = discount.update(
                    component: MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: component.discount,
                                font: Font.with(size: 14.0, design: .round, weight: .semibold, traits: []),
                                textColor: .white
                            )
                        ),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                discountSize = CGSize(width: discount.size.width + 6.0, height: 18.0)
            
                let discountBackground = discountBackground.update(
                    component: RoundedRectangle(
                        color: component.accentColor,
                        cornerRadius: 5.0
                    ),
                    availableSize: discountSize,
                    transition: context.transition
                )
                
                context.add(discountBackground
                    .position(CGPoint(x: insets.left + discountSize.width / 2.0, y: insets.top + title.size.height + spacing + discountSize.height / 2.0))
                )
                
                context.add(discount
                    .position(CGPoint(x: insets.left + discountSize.width / 2.0, y: insets.top + title.size.height + spacing + discountSize.height / 2.0))
                )
            } else {
                discountSize = CGSize(width: 0.0, height: 18.0)
            }
            
            let subtitle = subtitle.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.perMonthPrice,
                            font: Font.regular(13),
                            textColor: component.secondaryTextColor
                        )
                    ),
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - insets.left - insets.right - label.size.width - discountSize.width, height: context.availableSize.height),
                transition: context.transition
            )
            
            let check = check.update(
                component: CheckComponent(
                    theme: CheckComponent.Theme(
                        backgroundColor: component.accentColor,
                        strokeColor: component.checkForegroundColor,
                        borderColor: component.checkBorderColor,
                        overlayBorder: false,
                        hasInset: false,
                        hasShadow: false
                    ),
                    selected: component.selected
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                
            context.add(title
                .position(CGPoint(x: insets.left + title.size.width / 2.0, y: insets.top + title.size.height / 2.0))
            )
               
            context.add(subtitle
                .position(CGPoint(x: insets.left + (discountSize.width.isZero ? 0.0 : discountSize.width + 7.0) + subtitle.size.width / 2.0, y: insets.top + title.size.height + spacing + discountSize.height / 2.0))
            )
            
            let size = CGSize(width: context.availableSize.width, height: insets.top + title.size.height + spacing + subtitle.size.height + insets.bottom)
            let distance = context.availableSize.width - insets.left - insets.right - label.size.width - subtitle.size.width - discountSize.width - 7.0
            
            let labelOriginY: CGFloat
            if distance > 8.0 {
                labelOriginY = size.height / 2.0
            } else {
                labelOriginY = insets.top + title.size.height / 2.0
            }
            
            context.add(label
                .position(CGPoint(x: context.availableSize.width - insets.right - label.size.width / 2.0, y: labelOriginY))
            )
            
            context.add(check
                .position(CGPoint(x: 20.0 + check.size.width / 2.0, y: size.height / 2.0))
            )
            
            if component.selected {
                let selection = selection.update(
                    component: RoundedRectangle(
                        color: component.accentColor,
                        cornerRadius: 10.0,
                        stroke: 2.0
                    ),
                    availableSize: size,
                    transition: context.transition
                )
                context.add(selection
                    .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
                )
            }

            return size
        }
    }
}

private final class CheckComponent: Component {
    struct Theme: Equatable {
        public let backgroundColor: UIColor
        public let strokeColor: UIColor
        public let borderColor: UIColor
        public let overlayBorder: Bool
        public let hasInset: Bool
        public let hasShadow: Bool
        public let filledBorder: Bool
        public let borderWidth: CGFloat?
        
        public init(backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool, filledBorder: Bool = false, borderWidth: CGFloat? = nil) {
            self.backgroundColor = backgroundColor
            self.strokeColor = strokeColor
            self.borderColor = borderColor
            self.overlayBorder = overlayBorder
            self.hasInset = hasInset
            self.hasShadow = hasShadow
            self.filledBorder = filledBorder
            self.borderWidth = borderWidth
        }
        
        var checkNodeTheme: CheckNodeTheme {
            return CheckNodeTheme(
                backgroundColor: self.backgroundColor,
                strokeColor: self.strokeColor,
                borderColor: self.borderColor,
                overlayBorder: self.overlayBorder,
                hasInset: self.hasInset,
                hasShadow: self.hasShadow,
                filledBorder: self.filledBorder,
                borderWidth: self.borderWidth
            )
        }
    }
    
    let theme: Theme
    let selected: Bool
    
    init(
        theme: Theme,
        selected: Bool
    ) {
        self.theme = theme
        self.selected = selected
    }
    
    static func ==(lhs: CheckComponent, rhs: CheckComponent) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var currentValue: CGFloat?
        private var animator: DisplayLinkAnimator?

        private var checkLayer: CheckLayer {
            return self.layer as! CheckLayer
        }
        
        override class var layerClass: AnyClass {
            return CheckLayer.self
        }
        
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

    
        func update(component: CheckComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.checkLayer.setSelected(component.selected, animated: true)
            self.checkLayer.theme = component.theme.checkNodeTheme
            
            return CGSize(width: 22.0, height: 22.0)
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class PremiumGiftScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let peer: EnginePeer?
    let products: [PremiumGiftProduct]?
    let selectedProductId: String?
    
    let present: (ViewController) -> Void
    let selectProduct: (String) -> Void
    
    init(context: AccountContext, peer: EnginePeer?, products: [PremiumGiftProduct]?, selectedProductId: String?, present: @escaping (ViewController) -> Void, selectProduct: @escaping (String) -> Void) {
        self.context = context
        self.peer = peer
        self.products = products
        self.selectedProductId = selectedProductId
        self.present = present
        self.selectProduct = selectProduct
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
        
    static var body: Body {
        let overscroll = Child(Rectangle.self)
        let fade = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let section = Child(ProductGroupComponent.self)
        
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
            let subtitleColor = theme.list.itemSecondaryTextColor
            
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
            
            var items: [ProductGroupComponent.Item] = []
                        
            let gradientColors: [UIColor] = [
                UIColor(rgb: 0x8e77ff),
                UIColor(rgb: 0x9a6fff),
                UIColor(rgb: 0xb36eee)
            ]
            
            var i = 0
            if let products = component.products {
                let shortestOptionPrice: Int64
                if let product = products.last {
                    shortestOptionPrice = Int64(Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months))
                } else {
                    shortestOptionPrice = 1
                }
                
                for product in products {
                    let giftTitle: String
                    if product.months == 12 {
                        giftTitle = strings.Premium_Gift_Years(1)
                    } else {
                        giftTitle = strings.Premium_Gift_Months(product.months)
                    }
                    
                    let discountValue = Int((1.0 - Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months) / Float(shortestOptionPrice)) * 100.0)
                    let discount: String
                    if discountValue > 0 {
                        discount = "-\(discountValue)%"
                    } else {
                        discount = ""
                    }
                    
                    items.append(ProductGroupComponent.Item(
                        AnyComponentWithIdentity(
                            id: product.id,
                            component: AnyComponent(
                                GiftComponent(
                                    title: giftTitle,
                                    totalPrice: product.price,
                                    perMonthPrice: strings.Premium_Gift_PricePerMonth(product.pricePerMonth).string,
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
            
            let section = section.update(
                component: ProductGroupComponent(
                    items: items,
                    backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                    selectionColor: environment.theme.list.itemHighlightedBackgroundColor
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(section
                .position(CGPoint(x: availableWidth / 2.0, y: size.height + section.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            size.height += section.size.height
            size.height += 23.0
            
            
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
                                strongSelf.activationDisposable.set((strongSelf.context.account.postbox.peerView(id: strongSelf.context.account.peerId)
                                |> castError(AssignAppStoreTransactionError.self)
                                |> take(until: { view in
                                    if let peer = view.peers[view.peerId], peer.isPremium {
                                        return SignalTakeAction(passthrough: false, complete: true)
                                    } else {
                                        return SignalTakeAction(passthrough: false, complete: false)
                                    }
                                })
                                |> mapToSignal { _ -> Signal<Never, AssignAppStoreTransactionError> in
                                    return .never()
                                }
                                |> timeout(15.0, queue: Queue.mainQueue(), alternate: .fail(.timeout))
                                |> deliverOnMainQueue).start(error: { [weak self] _ in
                                    if let strongSelf = self {
                                        strongSelf.inProgress = false
                                        strongSelf.updateInProgress(false)
                                        
                                        strongSelf.updated(transition: .immediate)
                                        
//                                        addAppLogEvent(postbox: strongSelf.context.account.postbox, type: "premium.promo_screen_fail")
                                        
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        let errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                                        let alertController = textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                                        strongSelf.present(alertController)
                                    }
                                }, completed: { [weak self] in
                                    if let strongSelf = self {
                                        Queue.mainQueue().after(2.0) {
                                            let _ = updatePremiumPromoConfigurationOnce(account: strongSelf.context.account).start()
                                            strongSelf.inProgress = false
                                            strongSelf.updateInProgress(false)
                                            
                                            strongSelf.updated(transition: .easeInOut(duration: 0.25))
                                            strongSelf.completion(duration)
                                        }
                                    }
                                }))
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
        let termsText = Child(MultilineTextComponent.self)
        
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
            if let bottomContentOffset = state.bottomContentOffset, context.availableSize.width > 320.0 {
                bottomPanelAlpha = min(16.0, bottomContentOffset) / 16.0
            } else {
                bottomPanelAlpha = 0.0
            }
            
            context.add(bottomPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height / 2.0))
                .opacity(bottomPanelAlpha)
                .disappear(Transition.Disappear { view, transition, completion in
                    if case .none = transition.animation {
                        completion()
                        return
                    }
                    view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: bottomPanel.size.height), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
                        completion()
                    })
                })
            )
            context.add(bottomSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height))
                .opacity(bottomPanelAlpha)
                .disappear(Transition.Disappear { view, transition, completion in
                    if case .none = transition.animation {
                        completion()
                        return
                    }
                    view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: bottomPanel.size.height), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
                        completion()
                    })
                })
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height + bottomPanelPadding + button.size.height / 2.0))
                .disappear(Transition.Disappear { view, transition, completion in
                    if case .none = transition.animation {
                        completion()
                        return
                    }
                    view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: bottomPanel.size.height), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
                        completion()
                    })
                })
            )
            
            if let _ = context.state.peer {
                let accountContext = context.component.context
                let present = context.component.present
                
                let sideInset: CGFloat = 16.0
                let textSideInset: CGFloat = 16.0
                let availableWidth = context.availableSize.width
                let sideInsets = sideInset * 2.0 + environment.safeInsets.left + environment.safeInsets.right
                
                if availableWidth > 320.0 {
                    let termsFont = Font.regular(13.0)
                    let termsTextColor = environment.theme.list.freeTextColor
                    let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsFont, textColor: environment.theme.list.itemAccentColor), linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    })
                               
                    let termsString: MultilineTextComponent.TextContent = .markdown(
                        text: environment.strings.Premium_Gift_Info,
                        attributes: termsMarkdownAttributes
                    )
                    
                    let termsText = termsText.update(
                        component: MultilineTextComponent(
                            text: termsString,
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.0,
                            highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.3),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { attributes, _ in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                    let controller = PremiumIntroScreen(context: accountContext, source: .giftTerms)
                                    present(controller)
                                }
                            }
                        ),
                        environment: {},
                        availableSize: CGSize(width: availableWidth - sideInsets - textSideInset * 2.0, height: .greatestFiniteMagnitude),
                        transition: context.transition
                    )
                    context.add(termsText
                        .position(CGPoint(x: sideInset + environment.safeInsets.left + textSideInset + termsText.size.width / 2.0, y: context.availableSize.height - bottomPanel.size.height - termsText.size.height))
                    )
                }
            }
            
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
