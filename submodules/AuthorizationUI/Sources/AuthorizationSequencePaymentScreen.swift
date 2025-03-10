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
import LottieComponent
import ButtonComponent
import TextFormat
import InAppPurchaseManager
import ConfettiEffect

final class AuthorizationSequencePaymentScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let engine: TelegramEngineUnauthorized
    let inAppPurchaseManager: InAppPurchaseManager
    let presentationData: PresentationData
    let phoneNumber: String
    let phoneCodeHash: String
    let storeProduct: String
    
    init(
        engine: TelegramEngineUnauthorized,
        inAppPurchaseManager: InAppPurchaseManager,
        presentationData: PresentationData,
        phoneNumber: String,
        phoneCodeHash: String,
        storeProduct: String
    ) {
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
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                
            self.disablesInteractiveKeyboardGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.productsDisposable?.dispose()
        }
        
        private func proceed() {
            guard let component = self.component, let storeProduct = self.products.first(where: { $0.id == component.storeProduct }) else {
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
                    let _ = (component.inAppPurchaseManager.buyProduct(storeProduct, quantity: 1, purpose: purpose)
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        let _ = status
                        let _ = self
                    }, error: { [weak self] error in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
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
                    })
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
            self.component = component
            self.state = state
            
            if self.component == nil {
                self.productsDisposable = (component.inAppPurchaseManager.availableProducts
                |> deliverOnMainQueue).start(next: { [weak self] products in
                    guard let self else {
                        return
                    }
                    self.products = products
                    self.state?.updated()
                })
            }
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }
                        
            let animationHeight: CGFloat = 120.0
            let animationSize = self.animation.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "Coin"),
                    startingPosition: .begin
                )),
                environment: {},
                containerSize: CGSize(width: animationHeight, height: animationHeight)
            )
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.addSubview(animationView)
                }
                animationView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - animationSize.width) / 2.0), y: 156.0), size: animationSize)
            }
        
            let buttonHeight: CGFloat = 50.0
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            let bottomPanelHeight = bottomPanelPadding + buttonHeight + bottomInset
                        
            let sideInset: CGFloat = 16.0
            let buttonString = "Sign up for $1"
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
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
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
        engine: TelegramEngineUnauthorized,
        presentationData: PresentationData,
        inAppPurchaseManager: InAppPurchaseManager,
        phoneNumber: String,
        phoneCodeHash: String,
        storeProduct: String,
        back: @escaping () -> Void
    ) {
        super.init(component: AuthorizationSequencePaymentScreenComponent(
            engine: engine,
            inAppPurchaseManager: inAppPurchaseManager,
            presentationData: presentationData,
            phoneNumber: phoneNumber,
            phoneCodeHash: phoneCodeHash,
            storeProduct: storeProduct
        ), navigationBarAppearance: .transparent, theme: .default, updatedPresentationData: (initial: presentationData, signal: .single(presentationData)))
        
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
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
}
