import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SheetComponent
import ButtonComponent
import ToastComponent
import LottieComponent
import MultilineTextComponent
import Markdown
import TelegramStringFormatting

private final class StoryStealthModeSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let cooldownUntilTimestamp: Int32?
    let backwardDuration: Int32
    let forwardDuration: Int32
    let dismiss: () -> Void
    
    init(
        cooldownUntilTimestamp: Int32?,
        backwardDuration: Int32,
        forwardDuration: Int32,
        dismiss: @escaping () -> Void
    ) {
        self.cooldownUntilTimestamp = cooldownUntilTimestamp
        self.backwardDuration = backwardDuration
        self.forwardDuration = forwardDuration
        self.dismiss = dismiss
    }
    
    static func ==(lhs: StoryStealthModeSheetContentComponent, rhs: StoryStealthModeSheetContentComponent) -> Bool {
        if lhs.cooldownUntilTimestamp != rhs.cooldownUntilTimestamp {
            return false
        }
        if lhs.backwardDuration != rhs.backwardDuration {
            return false
        }
        if lhs.forwardDuration != rhs.forwardDuration {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var toast: ComponentView<Empty>?
        private let content = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var component: StoryStealthModeSheetContentComponent?
        private weak var state: EmptyComponentState?
        
        private var timer: Timer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
        }
        
        func update(component: StoryStealthModeSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var remainingCooldownSeconds: Int32 = 0
            if let cooldownUntilTimestamp = component.cooldownUntilTimestamp {
                remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                remainingCooldownSeconds = max(0, remainingCooldownSeconds)
            }
            if remainingCooldownSeconds > 0 {
                if self.timer == nil {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.state?.updated(transition: .immediate)
                    })
                }
            } else {
                if let timer = self.timer {
                    self.timer = nil
                    timer.invalidate()
                }
            }
            
            let environment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            
            if remainingCooldownSeconds > 0 {
                let toast: ComponentView<Empty>
                var toastTransition = transition
                if let current = self.toast {
                    toast = current
                } else {
                    toastTransition = toastTransition.withAnimation(.none)
                    toast = ComponentView()
                    self.toast = toast
                }
                //TODO:localize
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let toastSize = toast.update(
                    transition: toastTransition,
                    component: AnyComponent(ToastContentComponent(
                        icon: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(name: "anim_infotip"),
                            startingPosition: .begin,
                            size: CGSize(width: 32.0, height: 32.0)
                        )),
                        content: AnyComponent(MultilineTextComponent(
                            text: .markdown(text: "Please wait until the **Stealth Mode** is ready to use again", attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                            maximumNumberOfLines: 0
                        ))
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                if let toastView = toast.view {
                    if toastView.superview == nil {
                        self.addSubview(toastView)
                        
                        if let toastView = toastView as? ToastContentComponent.View, let iconView = toastView.iconView as? LottieComponent.View {
                            iconView.playOnce()
                        }
                    }
                    toastTransition.setFrame(view: toastView, frame: CGRect(origin: CGPoint(x: sideInset, y: -sideInset - toastSize.height), size: toastSize))
                }
            } else {
                if let toast = self.toast {
                    self.toast = nil
                    toast.view?.removeFromSuperview()
                }
            }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 32.0
            
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(StoryStealthModeInfoContentComponent(
                    theme: environment.theme,
                    strings: environment.strings,
                    backwardDuration: component.backwardDuration,
                    forwardDuration: component.forwardDuration
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
            contentHeight += 41.0
            
            //TODO:localize
            let buttonText: String
            if remainingCooldownSeconds <= 0 {
                buttonText = "Enable Stealth Mode"
            } else {
                buttonText = "Available in \(stringForDuration(remainingCooldownSeconds))"
            }
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        Text(text: buttonText, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: remainingCooldownSeconds <= 0,
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

private final class StoryStealthModeSheetScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let cooldownUntilTimestamp: Int32?
    let backwardDuration: Int32
    let forwardDuration: Int32
    let buttonAction: (() -> Void)?
    
    init(
        context: AccountContext,
        cooldownUntilTimestamp: Int32?,
        backwardDuration: Int32,
        forwardDuration: Int32,
        buttonAction: (() -> Void)?
    ) {
        self.context = context
        self.cooldownUntilTimestamp = cooldownUntilTimestamp
        self.backwardDuration = backwardDuration
        self.forwardDuration = forwardDuration
        self.buttonAction = buttonAction
    }
    
    static func ==(lhs: StoryStealthModeSheetScreenComponent, rhs: StoryStealthModeSheetScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.cooldownUntilTimestamp != rhs.cooldownUntilTimestamp {
            return false
        }
        if lhs.backwardDuration != rhs.backwardDuration {
            return false
        }
        if lhs.forwardDuration != rhs.forwardDuration {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: StoryStealthModeSheetScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryStealthModeSheetScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
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
                    content: AnyComponent(StoryStealthModeSheetContentComponent(
                        cooldownUntilTimestamp: component.cooldownUntilTimestamp,
                        backwardDuration: component.backwardDuration,
                        forwardDuration: component.forwardDuration,
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
                                self.component?.buttonAction?()
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

public class StoryStealthModeSheetScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        cooldownUntilTimestamp: Int32?,
        backwardDuration: Int32,
        forwardDuration: Int32,
        buttonAction: (() -> Void)? = nil
    ) {
        super.init(context: context, component: StoryStealthModeSheetScreenComponent(
            context: context,
            cooldownUntilTimestamp: cooldownUntilTimestamp,
            backwardDuration: backwardDuration,
            forwardDuration: forwardDuration,
            buttonAction: buttonAction
        ), navigationBarAppearance: .none, theme: .dark)
        
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
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        super.dismiss(completion: {
            completion?()
        })
        self.wasDismissed?()
    }
}
