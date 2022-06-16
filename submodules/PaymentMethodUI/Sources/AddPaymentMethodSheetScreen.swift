import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SheetComponent
import AnimatedStickerComponent
import SolidRoundedButtonComponent
import MultilineTextComponent
import PresentationDataUtils

private final class AddPaymentMethodSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let action: () -> Void
    private let dismiss: () -> Void
    
    init(context: AccountContext, action: @escaping () -> Void, dismiss: @escaping () -> Void) {
        self.context = context
        self.action = action
        self.dismiss = dismiss
    }
    
    static func ==(lhs: AddPaymentMethodSheetContent, rhs: AddPaymentMethodSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let animation = Child(AnimatedStickerComponent.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let actionButton = Child(SolidRoundedButtonComponent.self)
        let cancelButton = Child(Button.self)
        
        return { context in
            let sideInset: CGFloat = 40.0
            let buttonSideInset: CGFloat = 16.0
            
            let environment = context.environment[EnvironmentType.self].value
            let action = context.component.action
            let dismiss = context.component.dismiss
            
            let animation = animation.update(
                component: AnimatedStickerComponent(
                    account: context.component.context.account,
                    animation: AnimatedStickerComponent.Animation(
                        source: .bundle(name: "CreateStream"),
                        loop: true
                    ),
                    size: CGSize(width: 138.0, height: 138.0)
                ),
                availableSize: CGSize(width: 138.0, height: 138.0),
                transition: context.transition
            )
            
            //TODO:localize
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Payment Method", font: UIFont.boldSystemFont(ofSize: 17.0), textColor: .black)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            
            //TODO:localize
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Add your debit or credit card to buy goods and services on Telegram.", font: UIFont.systemFont(ofSize: 15.0), textColor: .gray)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            
            //TODO:localize
            let actionButton = actionButton.update(
                component: SolidRoundedButtonComponent(
                    title: "Add Payment Method",
                    theme: SolidRoundedButtonComponent.Theme(theme: environment.theme),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: true,
                    action: {
                        dismiss()
                        action()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - buttonSideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            //TODO:localize
            let cancelButton = cancelButton.update(
                component: Button(
                    content: AnyComponent(
                        Text(
                            text: "Cancel",
                            font: UIFont.systemFont(ofSize: 17.0),
                            color: environment.theme.list.itemAccentColor
                        )
                    ),
                    action: {
                        dismiss()
                    }
                ).minSize(CGSize(width: context.availableSize.width - buttonSideInset * 2.0, height: 50.0)),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - buttonSideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            var size = CGSize(width: context.availableSize.width, height: 24.0)
            
            context.add(animation
                .position(CGPoint(x: size.width / 2.0, y: size.height + animation.size.height / 2.0))
            )
            size.height += animation.size.height
            size.height += 16.0
            
            context.add(title
                .position(CGPoint(x: size.width / 2.0, y: size.height + title.size.height / 2.0))
            )
            size.height += title.size.height
            size.height += 16.0
            
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height + text.size.height / 2.0))
            )
            size.height += text.size.height
            size.height += 40.0
            
            context.add(actionButton
                .position(CGPoint(x: size.width / 2.0, y: size.height + actionButton.size.height / 2.0))
            )
            size.height += actionButton.size.height
            size.height += 8.0
            
            context.add(cancelButton
                .position(CGPoint(x: size.width / 2.0, y: size.height + cancelButton.size.height / 2.0))
            )
            size.height += cancelButton.size.height
            
            size.height += 8.0 + max(environment.safeInsets.bottom, 15.0)
            
            return size
        }
    }
}

private final class AddPaymentMethodSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let action: () -> Void
    
    init(context: AccountContext, action: @escaping () -> Void) {
        self.context = context
        self.action = action
    }
    
    static func ==(lhs: AddPaymentMethodSheetComponent, rhs: AddPaymentMethodSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(AddPaymentMethodSheetContent(
                        context: context.component.context,
                        action: context.component.action,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .white,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: false,
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

public final class AddPaymentMethodSheetScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, action: @escaping () -> Void) {
        super.init(context: context, component: AddPaymentMethodSheetComponent(context: context, action: action), navigationBarAppearance: .none)
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
}
