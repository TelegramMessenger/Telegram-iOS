import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramStringFormatting
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

private final class BotCheckoutShippingOptionContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let currency: String
    let options: [BotPaymentShippingOption]
    let selectedId: String?
    let selectOption: (String) -> Void
    
    init(
        currency: String,
        options: [BotPaymentShippingOption],
        selectedId: String?,
        selectOption: @escaping (String) -> Void
    ) {
        self.currency = currency
        self.options = options
        self.selectedId = selectedId
        self.selectOption = selectOption
    }
    
    static func ==(lhs: BotCheckoutShippingOptionContentComponent, rhs: BotCheckoutShippingOptionContentComponent) -> Bool {
        if lhs.currency != rhs.currency {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let section = ComponentView<Empty>()
        
        private var component: BotCheckoutShippingOptionContentComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BotCheckoutShippingOptionContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let theme = environment.theme.withModalBlocksBackground()
            let itemFontSize: CGFloat = 17.0
            let sideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 76.0 + 9.0
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            for option in component.options {
                let totalPrice = option.prices.reduce(Int64(0)) { current, price in
                    return current + price.amount
                }
                let priceText = formatCurrencyAmount(totalPrice, currency: component.currency)
                let isSelected = option.id == component.selectedId
                
                items.append(AnyComponentWithIdentity(id: option.id, component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: option.title,
                            font: Font.regular(itemFontSize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                        isSelected: isSelected,
                        toggle: {
                            component.selectOption(option.id)
                        }
                    )),
                    icon: nil,
                    accessory: .custom(ListActionItemComponent.CustomAccessory(
                        component: AnyComponentWithIdentity(
                            id: AnyHashable("price-\(option.id)"),
                            component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: priceText,
                                    font: Font.regular(itemFontSize),
                                    textColor: theme.list.itemSecondaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))
                        ),
                        insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 16.0)
                    )),
                    action: { _ in
                        component.selectOption(option.id)
                    }
                ))))
            }
            
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

private final class BotCheckoutShippingOptionScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let currency: String
    let options: [BotPaymentShippingOption]
    let currentId: String?
    let applyValue: (String) -> Void
    
    init(
        context: AccountContext,
        currency: String,
        options: [BotPaymentShippingOption],
        currentId: String?,
        applyValue: @escaping (String) -> Void
    ) {
        self.context = context
        self.currency = currency
        self.options = options
        self.currentId = currentId
        self.applyValue = applyValue
    }
    
    static func ==(lhs: BotCheckoutShippingOptionScreenComponent, rhs: BotCheckoutShippingOptionScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.currentId != rhs.currentId {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()
        
        private var component: BotCheckoutShippingOptionScreenComponent?
        private weak var state: EmptyComponentState?
        private var selectedId: String?
        private var isDismissing = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BotCheckoutShippingOptionScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                if let currentId = component.currentId, component.options.contains(where: { $0.id == currentId }) {
                    self.selectedId = currentId
                } else {
                    self.selectedId = nil
                }
            }
            
            self.component = component
            self.state = state
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let controller = environment.controller
            let theme = environment.theme.withModalBlocksBackground()
            
            let dismiss: (Bool) -> Void = { [weak self] animated in
                guard let self, !self.isDismissing else {
                    return
                }
                self.isDismissing = true
                
                let performDismiss: () -> Void = {
                    if let controller = controller() as? BotCheckoutShippingOptionScreen {
                        controller.completePendingDismiss()
                        controller.dismiss(animated: false)
                    }
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
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(BotCheckoutShippingOptionContentComponent(
                        currency: component.currency,
                        options: component.options,
                        selectedId: self.selectedId,
                        selectOption: { [weak self] id in
                            guard let self else {
                                return
                            }
                            self.selectedId = id
                            self.state?.updated(transition: .spring(duration: 0.35))
                        }
                    )),
                    titleItem: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Checkout_ShippingMethod,
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
                                dismiss(true)
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
                                text: environment.strings.Checkout_ShippingMethod_Proceed,
                                badge: 0,
                                textColor: theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                badgeForeground: theme.list.itemCheckColors.fillColor
                            ))
                        ),
                        isEnabled: self.selectedId != nil,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component, let selectedId = self.selectedId else {
                                return
                            }
                            component.applyValue(selectedId)
                            dismiss(true)
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
                            dismiss(animated)
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

final class BotCheckoutShippingOptionScreen: ViewControllerComponentContainer {
    private var isDismissed = false
    private var dismissCompletion: (() -> Void)?
    
    init(context: AccountContext, currency: String, options: [BotPaymentShippingOption], currentId: String?, applyValue: @escaping (String) -> Void) {
        super.init(
            context: context,
            component: BotCheckoutShippingOptionScreenComponent(
                context: context,
                currency: currency,
                options: options,
                currentId: currentId,
                applyValue: applyValue
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
