import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import ViewControllerComponent
import ResizableSheetComponent
import TelegramPresentationData
import PresentationDataUtils
import MultilineTextComponent
import ButtonComponent
import ListSectionComponent
import ListActionItemComponent
import GlassBarButtonComponent
import BundleIconComponent

struct BotCheckoutPaymentWebToken: Equatable {
    let title: String
    let data: String
    var saveOnServer: Bool
}

enum BotCheckoutPaymentMethod: Equatable {
    case savedCredentials(BotPaymentSavedCredentials)
    case webToken(BotCheckoutPaymentWebToken)
    case applePay
    case other(BotPaymentMethod)
    
    var title: String {
        switch self {
            case let .savedCredentials(credentials):
                switch credentials {
                    case let .card(_, title):
                        return title
                }
            case let .webToken(token):
                return token.title
            case .applePay:
                return "Apple Pay"
            case let .other(method):
                return method.title
        }
    }
}

private func splitSavedCardTitle(_ title: String) -> (String, String?) {
    guard let separatorIndex = title.lastIndex(of: "*") else {
        return (title, nil)
    }
    
    let name = String(title[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    let suffix = String(title[title.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !suffix.isEmpty else {
        return (title, nil)
    }
    
    return (name, "•••• \(suffix)")
}

private final class BotCheckoutPaymentMethodContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let methods: [BotCheckoutPaymentMethod]
    let selectedMethod: BotCheckoutPaymentMethod?
    let selectMethod: (BotCheckoutPaymentMethod) -> Void
    let addCard: () -> Void
    
    init(
        methods: [BotCheckoutPaymentMethod],
        selectedMethod: BotCheckoutPaymentMethod?,
        selectMethod: @escaping (BotCheckoutPaymentMethod) -> Void,
        addCard: @escaping () -> Void
    ) {
        self.methods = methods
        self.selectedMethod = selectedMethod
        self.selectMethod = selectMethod
        self.addCard = addCard
    }
    
    static func ==(lhs: BotCheckoutPaymentMethodContentComponent, rhs: BotCheckoutPaymentMethodContentComponent) -> Bool {
        if lhs.methods != rhs.methods {
            return false
        }
        if lhs.selectedMethod != rhs.selectedMethod {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let section = ComponentView<Empty>()
        
        private var component: BotCheckoutPaymentMethodContentComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BotCheckoutPaymentMethodContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let theme = environment.theme.withModalBlocksBackground()
            let itemFontSize: CGFloat = 17.0
            let sideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 76.0 + 9.0
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            for i in 0 ..< component.methods.count {
                let method = component.methods[i]
                let isSelected = method == component.selectedMethod
                
                var title = method.title
                var icon: ListActionItemComponent.Icon?
                var accessory: ListActionItemComponent.Accessory?
                
                switch method {
                case let .savedCredentials(credentials):
                    switch credentials {
                    case let .card(_, cardTitle):
                        let (cardName, cardSuffix) = splitSavedCardTitle(cardTitle)
                        title = cardName
                        if let cardSuffix {
                            accessory = .custom(ListActionItemComponent.CustomAccessory(
                                component: AnyComponentWithIdentity(
                                    id: AnyHashable("card-suffix-\(i)-\(cardSuffix)"),
                                    component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: cardSuffix,
                                            font: Font.regular(itemFontSize),
                                            textColor: theme.list.itemSecondaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))
                                ),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 16.0)
                            ))
                        }
                    }
                case .applePay:
                    title = "Apple Pay"
                    icon = ListActionItemComponent.Icon(
                        component: AnyComponentWithIdentity(
                            id: AnyHashable("apple-pay"),
                            component: AnyComponent(BundleIconComponent(
                                name: "Bot Payments/ApplePayLogo",
                                tintColor: nil
                            ))
                        )
                    )
                case let .webToken(token):
                    let (cardName, cardSuffix) = splitSavedCardTitle(token.title)
                    title = cardName
                    if let cardSuffix {
                        accessory = .custom(ListActionItemComponent.CustomAccessory(
                            component: AnyComponentWithIdentity(
                                id: AnyHashable("card-suffix-\(i)-\(cardSuffix)"),
                                component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: cardSuffix,
                                        font: Font.regular(itemFontSize),
                                        textColor: theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 16.0)
                        ))
                    }
                case let .other(method):
                    title = method.title
                }
                
                items.append(AnyComponentWithIdentity(id: AnyHashable("method-\(i)"), component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.regular(itemFontSize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                        isSelected: isSelected,
                        toggle: {
                            component.selectMethod(method)
                        }
                    )),
                    icon: icon,
                    accessory: accessory,
                    action: { _ in
                        component.selectMethod(method)
                    }
                ))))
            }
            
            items.append(AnyComponentWithIdentity(id: AnyHashable("add-card"), component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Checkout_PaymentMethod_New,
                        font: Font.regular(itemFontSize),
                        textColor: theme.list.itemAccentColor
                    )),
                    maximumNumberOfLines: 1
                )),
                contentInsets: UIEdgeInsets(top: 12.0, left: 45.0, bottom: 12.0, right: 0.0),
                leftIcon: nil,
                icon: nil,
                accessory: nil,
                action: { _ in
                    component.addCard()
                }
            ))))
            
            self.section.parentState = state
            let sectionSize = self.section.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: items
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let sectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: sectionSize)
            if let sectionView = self.section.view {
                if sectionView.superview == nil {
                    self.addSubview(sectionView)
                }
                transition.setFrame(view: sectionView, frame: sectionFrame)
            }
            contentHeight += sectionSize.height
            contentHeight += 112.0
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class BotCheckoutPaymentMethodScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let currentMethod: BotCheckoutPaymentMethod?
    let methods: [BotCheckoutPaymentMethod]
    let applyValue: (BotCheckoutPaymentMethod) -> Void
    let newCard: () -> Void
    let otherMethod: (String, String) -> Void
    
    init(
        context: AccountContext,
        currentMethod: BotCheckoutPaymentMethod?,
        methods: [BotCheckoutPaymentMethod],
        applyValue: @escaping (BotCheckoutPaymentMethod) -> Void,
        newCard: @escaping () -> Void,
        otherMethod: @escaping (String, String) -> Void
    ) {
        self.context = context
        self.currentMethod = currentMethod
        self.methods = methods
        self.applyValue = applyValue
        self.newCard = newCard
        self.otherMethod = otherMethod
    }
    
    static func ==(lhs: BotCheckoutPaymentMethodScreenComponent, rhs: BotCheckoutPaymentMethodScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.currentMethod != rhs.currentMethod {
            return false
        }
        if lhs.methods != rhs.methods {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()
        
        private var component: BotCheckoutPaymentMethodScreenComponent?
        private weak var state: EmptyComponentState?
        private var selectedMethod: BotCheckoutPaymentMethod?
        private var isDismissing = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BotCheckoutPaymentMethodScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                if let currentMethod = component.currentMethod, component.methods.contains(currentMethod) {
                    self.selectedMethod = currentMethod
                } else {
                    self.selectedMethod = nil
                }
            }
            
            self.component = component
            self.state = state
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let controller = environment.controller
            let theme = environment.theme.withModalBlocksBackground()
            
            let dismiss: (Bool, (() -> Void)?) -> Void = { [weak self] animated, completion in
                guard let self, !self.isDismissing else {
                    return
                }
                self.isDismissing = true
                
                let performDismiss: () -> Void = {
                    if let controller = controller() as? BotCheckoutPaymentMethodScreen {
                        controller.completePendingDismiss()
                        controller.dismiss(animated: false)
                    }
                    completion?()
                }
                
                if animated {
                    self.animateOut.invoke(Action { _ in
                        performDismiss()
                    })
                } else {
                    performDismiss()
                }
            }
            
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(BotCheckoutPaymentMethodContentComponent(
                        methods: component.methods,
                        selectedMethod: self.selectedMethod,
                        selectMethod: { [weak self] method in
                            guard let self else {
                                return
                            }
                            self.selectedMethod = method
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        addCard: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            dismiss(true, {
                                component.newCard()
                            })
                        }
                    )),
                    titleItem: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Checkout_PaymentMethod,
                            font: Font.semibold(17.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
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
                                dismiss(true, nil)
                            }
                        )
                    ),
                    bottomItem: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("proceed"),
                            component: AnyComponent(ButtonTextContentComponent(
                                text: environment.strings.Checkout_PaymentMethod_Proceed,
                                badge: 0,
                                textColor: theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                badgeForeground: theme.list.itemCheckColors.fillColor
                            ))
                        ),
                        isEnabled: self.selectedMethod != nil,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component, let selectedMethod = self.selectedMethod else {
                                return
                            }
                            dismiss(true, {
                                switch selectedMethod {
                                case let .other(method):
                                    component.otherMethod(method.url, method.title)
                                default:
                                    component.applyValue(selectedMethod)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    animateOut: self.animateOut
                )),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: 0.0,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        screenSize: availableSize,
                        regularMetricsSize: nil,
                        dismiss: { animated in
                            dismiss(animated, nil)
                        }
                    )
                },
                forceUpdate: true,
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class BotCheckoutPaymentMethodScreen: ViewControllerComponentContainer {
    private var isDismissed = false
    private var dismissCompletion: (() -> Void)?
    
    init(context: AccountContext, currentMethod: BotCheckoutPaymentMethod?, methods: [BotCheckoutPaymentMethod], applyValue: @escaping (BotCheckoutPaymentMethod) -> Void, newCard: @escaping () -> Void, otherMethod: @escaping (String, String) -> Void) {
        super.init(
            context: context,
            component: BotCheckoutPaymentMethodScreenComponent(
                context: context,
                currentMethod: currentMethod,
                methods: methods,
                applyValue: applyValue,
                newCard: newCard,
                otherMethod: otherMethod
            ),
            navigationBarAppearance: .none
        )
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func completePendingDismiss() {
        let dismissCompletion = self.dismissCompletion
        self.dismissCompletion = nil
        dismissCompletion?()
    }
    
    func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.dismissCompletion = completion
            
            if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
                view.dismissAnimated()
            } else {
                self.completePendingDismiss()
                self.dismiss(animated: false)
            }
        }
    }
}
