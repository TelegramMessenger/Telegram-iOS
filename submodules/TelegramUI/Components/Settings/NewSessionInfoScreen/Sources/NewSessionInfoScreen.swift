import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SheetComponent
import ButtonComponent
import TelegramCore
import AnimatedTextComponent

private final class NewSessionInfoSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let newSessionReview: NewSessionReview
    let dismiss: () -> Void
    
    init(
        newSessionReview: NewSessionReview,
        dismiss: @escaping () -> Void
    ) {
        self.newSessionReview = newSessionReview
        self.dismiss = dismiss
    }
    
    static func ==(lhs: NewSessionInfoSheetContentComponent, rhs: NewSessionInfoSheetContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let content = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var remainingTimer: Int
        private var timer: Foundation.Timer?
        
        private var component: NewSessionInfoSheetContentComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.remainingTimer = 5
            
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
        }
        
        func update(component: NewSessionInfoSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            if self.timer == nil {
                self.timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.remainingTimer = max(0, self.remainingTimer - 1)
                    if self.remainingTimer == 0 {
                        self.timer?.invalidate()
                    }
                    self.state?.updated(transition: .immediate)
                })
            }
            
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            let environment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 30.0
            
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(NewSessionInfoContentComponent(
                    theme: environment.theme,
                    strings: environment.strings,
                    newSessionReview: component.newSessionReview
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: contentSize))
            }
            contentHeight += contentSize.height
            contentHeight += 30.0
            
            var buttonContents: [AnyComponentWithIdentity<Empty>] = []
            buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                Text(text: environment.strings.SessionReview_OkAction, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
            )))
            if self.remainingTimer > 0 {
                buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(
                    AnimatedTextComponent(font: Font.with(size: 17.0, weight: .semibold, traits: .monospacedNumbers), color: environment.theme.list.itemCheckColors.foregroundColor.withMultipliedAlpha(0.5), items: [
                        AnimatedTextComponent.Item(id: AnyHashable(0 as Int), content: .number(self.remainingTimer, minDigits: 0))
                    ])
                )))
            }
            var buttonTransition = transition
            if transition.animation.isImmediate && previousComponent != nil {
                buttonTransition = buttonTransition.withAnimation(.curve(duration: 0.2, curve: .easeInOut))
            }
            let buttonSize = self.button.update(
                transition: buttonTransition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        HStack(buttonContents, spacing: 5.0)
                    )),
                    isEnabled: self.remainingTimer == 0,
                    tintWhenDisabled: false,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            contentHeight += buttonSize.height
            
            if environment.safeInsets.bottom.isZero {
                contentHeight += 16.0
            } else {
                contentHeight += environment.safeInsets.bottom + 14.0
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class NewSessionInfoScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let newSessionReview: NewSessionReview
    
    init(
        context: AccountContext,
        newSessionReview: NewSessionReview
    ) {
        self.context = context
        self.newSessionReview = newSessionReview
    }
    
    static func ==(lhs: NewSessionInfoScreenComponent, rhs: NewSessionInfoScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.newSessionReview != rhs.newSessionReview {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: NewSessionInfoScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: NewSessionInfoScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            self.component = component
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let sheetEnvironment = SheetComponentEnvironment(
                isDisplaying: environment.isVisible,
                isCentered: environment.metrics.widthClass == .regular,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] _ in
                    guard let self, let environment = self.environment else {
                        return
                    }
                    self.sheetAnimateOut.invoke(Action { _ in
                        if let controller = environment.controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                }
            )
            let _ = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(NewSessionInfoSheetContentComponent(
                        newSessionReview: component.newSessionReview,
                        dismiss: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { [weak self] _ in
                                if let controller = environment.controller() {
                                    controller.dismiss(completion: nil)
                                }
                                
                                guard let self else {
                                    return
                                }
                                let _ = self
                                //self.component?.buttonAction?()
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.plainBackgroundColor),
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class NewSessionInfoScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, newSessionReview: NewSessionReview) {
        super.init(context: context, component: NewSessionInfoScreenComponent(
            context: context,
            newSessionReview: newSessionReview
        ), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
    }
}
