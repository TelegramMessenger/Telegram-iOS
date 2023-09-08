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
    
    let mode: StoryStealthModeSheetScreen.Mode
    let backwardDuration: Int32
    let forwardDuration: Int32
    let action: () -> Void
    let dismiss: () -> Void
    
    init(
        mode: StoryStealthModeSheetScreen.Mode,
        backwardDuration: Int32,
        forwardDuration: Int32,
        action: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.mode = mode
        self.backwardDuration = backwardDuration
        self.forwardDuration = forwardDuration
        self.action = action
        self.dismiss = dismiss
    }
    
    static func ==(lhs: StoryStealthModeSheetContentComponent, rhs: StoryStealthModeSheetContentComponent) -> Bool {
        if lhs.mode != rhs.mode {
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
        
        private var cancelButton: ComponentView<Empty>?
        
        private var component: StoryStealthModeSheetContentComponent?
        private weak var state: EmptyComponentState?
        
        private var timer: Timer?
        private var showCooldownToast: Bool = false
        private var hideCooldownTimer: Timer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
            self.hideCooldownTimer?.invalidate()
        }
        
        private func displayCooldown() {
            if !self.showCooldownToast {
                self.showCooldownToast = true
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
            }
            
            self.hideCooldownTimer?.invalidate()
            self.hideCooldownTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false, block: { [weak self] _ in
                guard let self else {
                    return
                }
                self.hideCooldownTimer?.invalidate()
                self.hideCooldownTimer = nil
                
                self.showCooldownToast = false
                
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
            })
        }
        
        func update(component: StoryStealthModeSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var remainingCooldownSeconds: Int32 = 0
            if case let .control(cooldownUntilTimestamp) = component.mode {
                if let cooldownUntilTimestamp {
                    remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                    remainingCooldownSeconds = max(0, remainingCooldownSeconds)
                }
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
            
            if remainingCooldownSeconds > 0, self.showCooldownToast {
                let toast: ComponentView<Empty>
                var toastTransition = transition
                if let current = self.toast {
                    toast = current
                } else {
                    toastTransition = toastTransition.withAnimation(.none)
                    toast = ComponentView()
                    self.toast = toast
                }
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
                            text: .markdown(text: environment.strings.Story_StealthMode_ToastCooldownText, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                            maximumNumberOfLines: 0
                        ))
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                if let toastView = toast.view {
                    if toastView.superview == nil {
                        self.addSubview(toastView)
                        toastView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        
                        if let toastView = toastView as? ToastContentComponent.View, let iconView = toastView.iconView as? LottieComponent.View {
                            iconView.playOnce()
                        }
                    }
                    toastTransition.setFrame(view: toastView, frame: CGRect(origin: CGPoint(x: sideInset, y: -sideInset - toastSize.height), size: toastSize))
                }
            } else {
                if let toast = self.toast {
                    self.toast = nil
                    if let toastView = toast.view {
                        toastView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak toastView] _ in
                            toastView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if case .upgrade = component.mode {
                let cancelButton: ComponentView<Empty>
                if let current = self.cancelButton {
                    cancelButton = current
                } else {
                    cancelButton = ComponentView()
                    self.cancelButton = cancelButton
                }
                let cancelButtonSize = cancelButton.update(
                    transition: transition,
                    component: AnyComponent(Button(
                        content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.list.itemAccentColor)),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.dismiss()
                        }
                    ).minSize(CGSize(width: 8.0, height: 44.0))),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                if let cancelButtonView = cancelButton.view {
                    if cancelButtonView.superview == nil {
                        self.addSubview(cancelButtonView)
                    }
                    transition.setFrame(view: cancelButtonView, frame: CGRect(origin: CGPoint(x: 16.0, y: 6.0), size: cancelButtonSize))
                }
            } else if let cancelButton = self.cancelButton {
                self.cancelButton = nil
                cancelButton.view?.removeFromSuperview()
            }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 32.0
            
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(StoryStealthModeInfoContentComponent(
                    theme: environment.theme,
                    strings: environment.strings,
                    backwardDuration: component.backwardDuration,
                    forwardDuration: component.forwardDuration,
                    mode: component.mode,
                    dismiss: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.dismiss()
                    }
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
            
            let buttonText: String
            let content: AnyComponentWithIdentity<Empty>
            switch component.mode {
            case .control:
                if remainingCooldownSeconds <= 0 {
                    buttonText = environment.strings.Story_StealthMode_EnableAction
                } else {
                    buttonText = environment.strings.Story_StealthMode_CooldownAction(stringForDuration(remainingCooldownSeconds)).string
                }
                content = AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(Text(text: buttonText, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)))
            case .upgrade:
                buttonText = environment.strings.Story_StealthMode_UpgradeAction
                content = AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(
                    HStack([
                        AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(Text(text: buttonText, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor))),
                        AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(name: "premium_unlock"),
                            color: environment.theme.list.itemCheckColors.foregroundColor,
                            startingPosition: .begin,
                            size: CGSize(width: 30.0, height: 30.0),
                            loop: true
                        )))
                    ], spacing: 4.0)
                ))
            }
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: content,
                    isEnabled: remainingCooldownSeconds <= 0,
                    allowActionWhenDisabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        switch component.mode {
                        case let .control(cooldownUntilTimestamp):
                            var remainingCooldownSeconds: Int32 = 0
                            if let cooldownUntilTimestamp {
                                remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                                remainingCooldownSeconds = max(0, remainingCooldownSeconds)
                            }
                            
                            if remainingCooldownSeconds > 0 {
                                self.displayCooldown()
                            } else {
                                component.action()
                            }
                        case .upgrade:
                            component.action()
                        }
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
    let mode: StoryStealthModeSheetScreen.Mode
    let backwardDuration: Int32
    let forwardDuration: Int32
    let buttonAction: (() -> Void)?
    
    init(
        context: AccountContext,
        mode: StoryStealthModeSheetScreen.Mode,
        backwardDuration: Int32,
        forwardDuration: Int32,
        buttonAction: (() -> Void)?
    ) {
        self.context = context
        self.mode = mode
        self.backwardDuration = backwardDuration
        self.forwardDuration = forwardDuration
        self.buttonAction = buttonAction
    }
    
    static func ==(lhs: StoryStealthModeSheetScreenComponent, rhs: StoryStealthModeSheetScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
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
                        mode: component.mode,
                        backwardDuration: component.backwardDuration,
                        forwardDuration: component.forwardDuration,
                        action: { [weak self] in
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
                        },
                        dismiss: {
                            self.sheetAnimateOut.invoke(Action { _ in
                                if let controller = environment.controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.overallDarkAppearance ? environment.theme.list.itemBlocksBackgroundColor : environment.theme.list.blocksBackgroundColor),
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
    public enum Mode: Equatable {
        case control(cooldownUntilTimestamp: Int32?)
        case upgrade
    }
    
    public init(
        context: AccountContext,
        mode: Mode,
        backwardDuration: Int32,
        forwardDuration: Int32,
        buttonAction: (() -> Void)? = nil
    ) {
        super.init(context: context, component: StoryStealthModeSheetScreenComponent(
            context: context,
            mode: mode,
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
