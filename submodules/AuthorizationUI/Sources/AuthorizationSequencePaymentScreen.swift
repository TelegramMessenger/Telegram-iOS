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
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import ButtonComponent
import TextFormat
import InAppPurchaseManager
import ConfettiEffect
import PremiumCoinComponent
import Markdown
import CountrySelectionUI
import AccountContext

final class AuthorizationSequencePaymentScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let sharedContext: SharedAccountContext
    let engine: TelegramEngineUnauthorized
    let inAppPurchaseManager: InAppPurchaseManager
    let presentationData: PresentationData
    let phoneNumber: String
    let phoneCodeHash: String
    let storeProduct: String
    
    init(
        sharedContext: SharedAccountContext,
        engine: TelegramEngineUnauthorized,
        inAppPurchaseManager: InAppPurchaseManager,
        presentationData: PresentationData,
        phoneNumber: String,
        phoneCodeHash: String,
        storeProduct: String
    ) {
        self.sharedContext = sharedContext
        self.engine = engine
        self.inAppPurchaseManager = inAppPurchaseManager
        self.presentationData = presentationData
        self.phoneNumber = phoneNumber
        self.phoneCodeHash = phoneCodeHash
        self.storeProduct = storeProduct
    }

    static func ==(lhs: AuthorizationSequencePaymentScreenComponent, rhs: AuthorizationSequencePaymentScreenComponent) -> Bool {
        if lhs.storeProduct != rhs.storeProduct {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let animation = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let list = ComponentView<Empty>()
        private let check = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
                
        private var isUpdating: Bool = false
        
        private var component: AuthorizationSequencePaymentScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var products: [InAppPurchaseManager.Product] = []
        private var productsDisposable: Disposable?
        private var inProgress = false
        
        private var paymentDisposable = MetaDisposable()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                
            self.disablesInteractiveKeyboardGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.paymentDisposable.dispose()
            self.productsDisposable?.dispose()
        }
        
        private func proceed() {
            guard let component = self.component, let storeProduct = self.products.first(where: { $0.id == component.storeProduct }), !self.inProgress else {
                return
            }
            
            self.inProgress = true
            self.state?.updated()
            
            let (currency, amount) = storeProduct.priceCurrencyAndAmount
            let purpose: AppStoreTransactionPurpose = .authCode(restore: false, phoneNumber: component.phoneNumber, phoneCodeHash: component.phoneCodeHash, currency: currency, amount: amount)
            let _ = (component.engine.payments.canPurchasePremium(purpose: purpose)
            |> deliverOnMainQueue).start(next: { [weak self] available in
                guard let self else {
                    return
                }
                let presentationData = component.presentationData
                if available {
                    self.paymentDisposable.set((component.inAppPurchaseManager.buyProduct(storeProduct, quantity: 1, purpose: purpose)
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        guard let self else {
                            return
                        }
                        self.inProgress = false
                    }, error: { [weak self] error in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        self.inProgress = false
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
                            //addAppLogEvent(postbox: component.engine.account.postbox, type: "premium_gift.promo_screen_fail")
                            
                            let _ = errorText
                            let _ = controller
                            //let alertController = textAlertController(context: component.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                            //controller.present(alertController, in: .window(.root))
                        }
                    }))
                } else {
                    self.inProgress = false
                    self.state?.updated(transition: .immediate)
                }
            })
        }
        
        func update(component: AuthorizationSequencePaymentScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                        
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            self.state = state
            
            if self.component == nil {
                self.productsDisposable = (component.inAppPurchaseManager.availableProducts
                |> deliverOnMainQueue).start(next: { [weak self] products in
                    guard let self else {
                        return
                    }
                    self.products = products
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
            }
            
            self.component = component
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                        
            let animationSize = self.animation.update(
                transition: transition,
                component: AnyComponent(PremiumCoinComponent(
                    mode: .business,
                    isIntro: true,
                    isVisible: true,
                    hasIdleAnimations: true
                )),
                environment: {},
                containerSize: CGSize(width: min(414.0, availableSize.width), height: 184.0)
            )
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Login_Fee_Title, font: Font.bold(28.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
                        
            let textColor = environment.theme.list.itemPrimaryTextColor
            let secondaryTextColor = environment.theme.list.itemSecondaryTextColor
            let linkColor = environment.theme.list.itemAccentColor
            
            var countryName: String = ""
            if let (country, _) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(component.phoneNumber, preferredCountries: [:]) {
                countryName = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(country.id, strings: environment.strings) ?? country.name
            }
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "cost",
                    component: AnyComponent(ParagraphComponent(
                        title: environment.strings.Login_Fee_SmsCost_Title,
                        titleColor: textColor,
                        text: environment.strings.Login_Fee_SmsCost_Text(countryName).string,
                        textColor: secondaryTextColor,
                        iconName: "Premium/Authorization/Cost",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "verification",
                    component: AnyComponent(ParagraphComponent(
                        title: environment.strings.Login_Fee_Verification_Title,
                        titleColor: textColor,
                        text: environment.strings.Login_Fee_Verification_Text,
                        textColor: secondaryTextColor,
                        iconName: "Premium/Authorization/Verification",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "support",
                    component: AnyComponent(ParagraphComponent(
                        title: environment.strings.Login_Fee_Support_Title,
                        titleColor: textColor,
                        text: environment.strings.Login_Fee_Support_Text,
                        textColor: secondaryTextColor,
                        iconName: "Premium/Authorization/Support",
                        iconColor: linkColor,
                        action: { [weak self] in
                            guard let self, let controller = self.environment?.controller(), let product = self.products.first(where: { $0.id == component.storeProduct }) else {
                                return
                            }
                            let introController = component.sharedContext.makePremiumIntroController(
                                sharedContext: component.sharedContext,
                                engine: component.engine,
                                inAppPurchaseManager: component.inAppPurchaseManager,
                                source: .auth(product.price),
                                proceed: { [weak self] in
                                    self?.proceed()
                                }
                            )
                            controller.push(introController)
                        }
                    ))
                )
            )
            
            let listSize = self.list.update(
                transition: transition,
                component: AnyComponent(List(items)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            
            let buttonHeight: CGFloat = 50.0
            let bottomPanelPadding: CGFloat = 12.0
            let titleSpacing: CGFloat = -24.0
            let listSpacing: CGFloat = 12.0
            let totalHeight = animationSize.height + titleSpacing + titleSize.height + listSpacing + listSize.height
            
            var originY = floor((availableSize.height - buttonHeight - bottomPanelPadding * 2.0 - totalHeight) / 2.0)
            
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.addSubview(animationView)
                }
                animationView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - animationSize.width) / 2.0), y: originY), size: animationSize)
                originY += animationSize.height + titleSpacing
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: originY), size: titleSize)
                originY += titleSize.height + listSpacing
            }
            
            if let listView = self.list.view {
                if listView.superview == nil {
                    self.addSubview(listView)
                }
                listView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - listSize.width) / 2.0), y: originY), size: listSize)
            }
        
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            let bottomPanelHeight = bottomPanelPadding + buttonHeight + bottomInset
                                    
            let priceString: String
            if let product = self.products.first(where: { $0.id == component.storeProduct }) {
                priceString = product.price
            } else {
                priceString = "–"
            }
            
            let buttonString = environment.strings.Login_Fee_SignUp(priceString).string
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(buttonString),
                        component: AnyComponent(
                            VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))),
                                AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Login_Fee_GetPremiumForAWeek, font: Font.medium(11.0), textColor: environment.theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7), paragraphAlignment: .center)))))
                            ], spacing: 1.0)
                        )
                    ),
                    isEnabled: true,
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

public final class AuthorizationSequencePaymentScreen: ViewControllerComponentContainer {
    public init(
        sharedContext: SharedAccountContext,
        engine: TelegramEngineUnauthorized,
        presentationData: PresentationData,
        inAppPurchaseManager: InAppPurchaseManager,
        phoneNumber: String,
        phoneCodeHash: String,
        storeProduct: String,
        back: @escaping () -> Void
    ) {
        super.init(component: AuthorizationSequencePaymentScreenComponent(
            sharedContext: sharedContext,
            engine: engine,
            inAppPurchaseManager: inAppPurchaseManager,
            presentationData: presentationData,
            phoneNumber: phoneNumber,
            phoneCodeHash: phoneCodeHash,
            storeProduct: storeProduct
        ), navigationBarAppearance: .transparent, theme: .default, updatedPresentationData: (initial: presentationData, signal: .single(presentationData)))
        
        loadServerCountryCodes(accountManager: sharedContext.accountManager, engine: engine, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.requestLayout(forceUpdate: true, transition: .immediate)
            }
        })
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
    }
    
    public override func loadDisplayNode() {
        super.loadDisplayNode()
        
        self.displayNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
}

private final class ParagraphComponent: CombinedComponent {
    let title: String
    let titleColor: UIColor
    let text: String
    let textColor: UIColor
    let iconName: String
    let iconColor: UIColor
    let action: (() -> Void)?
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        iconName: String,
        iconColor: UIColor,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.iconName = iconName
        self.iconColor = iconColor
        self.action = action
    }
    
    static func ==(lhs: ParagraphComponent, rhs: ParagraphComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedChevronImage: (UIImage, UIColor)?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            let state = context.state
            
            let leftInset: CGFloat = 64.0
            let rightInset: CGFloat = 32.0
            let textSideInset: CGFloat = leftInset + 8.0
            let spacing: CGFloat = 5.0
            
            let textTopInset: CGFloat = 9.0
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let titleColor = component.titleColor
            let textColor = component.textColor
            let linkColor = component.iconColor
            let titleMarkdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: boldTextFont, textColor: titleColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: titleColor),
                link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
                        
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== linkColor {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, linkColor)
            }
            
            let titleAttributedString = parseMarkdownIntoAttributedString(component.title, attributes: titleMarkdownAttributes).mutableCopy() as! NSMutableAttributedString
            if let range = titleAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                titleAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: titleAttributedString.string))
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(titleAttributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1,
                    highlightColor: linkColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                            component.action?()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            

            let textMarkdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: linkColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: textMarkdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: linkColor.withAlphaComponent(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                            component.action?()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: context.availableSize.height),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.iconColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
         
            context.add(title
                .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(icon
                .position(CGPoint(x: 47.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 18.0)
        }
    }
}
