import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import AnimatedStickerComponent
import SolidRoundedButtonComponent
import MultilineTextComponent
import PresentationDataUtils

public final class SheetComponentEnvironment: Equatable {
    public let isDisplaying: Bool
    public let dismiss: () -> Void
    
    public init(isDisplaying: Bool, dismiss: @escaping () -> Void) {
        self.isDisplaying = isDisplaying
        self.dismiss = dismiss
    }
    
    public static func ==(lhs: SheetComponentEnvironment, rhs: SheetComponentEnvironment) -> Bool {
        if lhs.isDisplaying != rhs.isDisplaying {
            return false
        }
        return true
    }
}

public final class SheetComponent<ChildEnvironmentType: Equatable>: Component {
    public typealias EnvironmentType = (ChildEnvironmentType, SheetComponentEnvironment)
    
    public let content: AnyComponent<ChildEnvironmentType>
    public let backgroundColor: UIColor
    public let animateOut: ActionSlot<Action<()>>
    
    public init(content: AnyComponent<ChildEnvironmentType>, backgroundColor: UIColor, animateOut: ActionSlot<Action<()>>) {
        self.content = content
        self.backgroundColor = backgroundColor
        self.animateOut = animateOut
    }
    
    public static func ==(lhs: SheetComponent, rhs: SheetComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.animateOut != rhs.animateOut {
            return false
        }
        
        return true
    }
    
    public final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let scrollView: UIScrollView
        private let backgroundView: UIView
        private let contentView: ComponentHostView<ChildEnvironmentType>
        
        private var previousIsDisplaying: Bool = false
        private var dismiss: (() -> Void)?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
            
            self.scrollView = UIScrollView()
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = true
            
            self.backgroundView = UIView()
            self.backgroundView.layer.cornerRadius = 10.0
            self.backgroundView.layer.masksToBounds = true
            
            self.contentView = ComponentHostView<ChildEnvironmentType>()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            
            self.scrollView.addSubview(self.backgroundView)
            self.scrollView.addSubview(self.contentView)
            self.addSubview(self.scrollView)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimViewTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func dimViewTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.dismiss?()
            }
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.bounds.contains(self.convert(point, to: self.backgroundView)) {
                return self.dimView
            }
            
            return super.hitTest(point, with: event)
        }
        
        private func animateOut(completion: @escaping () -> Void) {
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            self.scrollView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.bounds.height - self.scrollView.contentInset.top), duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
        }
        
        func update(component: SheetComponent<ChildEnvironmentType>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            component.animateOut.connect { [weak self] completion in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.animateOut {
                    completion(Void())
                }
            }
            
            if self.backgroundView.backgroundColor != component.backgroundColor {
                self.backgroundView.backgroundColor = component.backgroundColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            
            let contentSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    environment[ChildEnvironmentType.self]
                },
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height + 1000.0)), completion: nil)
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            self.scrollView.contentSize = contentSize
            self.scrollView.contentInset = UIEdgeInsets(top: max(0.0, availableSize.height - contentSize.height), left: 0.0, bottom: 0.0, right: 0.0)
            
            if environment[SheetComponentEnvironment.self].value.isDisplaying, !self.previousIsDisplaying, let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
                self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                self.scrollView.layer.animatePosition(from: CGPoint(x: 0.0, y: availableSize.height - self.scrollView.contentInset.top), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true, completion: nil)
            }
            self.previousIsDisplaying = environment[SheetComponentEnvironment.self].value.isDisplaying
            
            self.dismiss = environment[SheetComponentEnvironment.self].value.dismiss
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

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
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
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
