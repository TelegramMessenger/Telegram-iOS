import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import AccountContext
import SheetComponent
import ButtonComponent
import TelegramCore

private final class BirthdayPickerSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let settings: Signal<AccountPrivacySettings?, NoError>
    let openSettings: () -> Void
    let dismiss: () -> Void
    let action: (TelegramBirthday) -> Void
    
    init(
        settings: Signal<AccountPrivacySettings?, NoError>,
        openSettings: @escaping () -> Void,
        dismiss: @escaping () -> Void,
        action: @escaping (TelegramBirthday) -> Void
    ) {
        self.settings = settings
        self.openSettings = openSettings
        self.dismiss = dismiss
        self.action = action
    }
    
    static func ==(lhs: BirthdayPickerSheetContentComponent, rhs: BirthdayPickerSheetContentComponent) -> Bool {
        if lhs !== rhs {
            return true
        }
        return true
    }
    
    final class View: UIView {
        private let cancel = ComponentView<Empty>()
        private let content = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var birthday = TelegramBirthday(day: 1, month: 1, year: nil)
        
        private var component: BirthdayPickerSheetContentComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BirthdayPickerSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 18.0
                        
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(BirthdayPickerContentComponent(
                    theme: environment.theme,
                    strings: environment.strings, 
                    settings: component.settings,
                    value: self.birthday,
                    updateValue: { [weak self] value in
                        if let self {
                            self.birthday = value
                        }
                    },
                    dismiss: component.dismiss,
                    openSettings: component.openSettings
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
            contentHeight += 8.0
            
            let cancelSize = self.cancel.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.list.itemAccentColor)),
                    action: { [weak self] in
                        if let self, let component = self.component {
                            component.dismiss()
                        }
                    }
                ).minSize(CGSize(width: 32.0, height: 32.0))),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 32.0)
            )
            let cancelFrame = CGRect(origin: CGPoint(x: sideInset, y: 13.0), size: cancelSize)
            if let cancelView = self.cancel.view {
                if cancelView.superview == nil {
                    self.addSubview(cancelView)
                }
                transition.setFrame(view: cancelView, frame: cancelFrame)
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
                        Text(text: environment.strings.Birthday_Save, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.action(self.birthday)
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class BirthdayPickerScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let settings: Signal<AccountPrivacySettings?, NoError>
    let openSettings: (() -> Void)?
    let completion: ((TelegramBirthday) -> Void)?
    
    init(
        context: AccountContext,
        settings: Signal<AccountPrivacySettings?, NoError>,
        openSettings: (() -> Void)?,
        completion: ((TelegramBirthday) -> Void)?
    ) {
        self.context = context
        self.settings = settings
        self.openSettings = openSettings
        self.completion = completion
    }
    
    static func ==(lhs: BirthdayPickerScreenComponent, rhs: BirthdayPickerScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: BirthdayPickerScreenComponent?
        private var environment: EnvironmentType?
                
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var didAppear = false
        func update(component: BirthdayPickerScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            if environment.isVisible {
                self.didAppear = true
            }
            
            let sheetEnvironment = SheetComponentEnvironment(
                isDisplaying: self.didAppear || environment.isVisible,
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
                    content: AnyComponent(BirthdayPickerSheetContentComponent(
                        settings: component.settings,
                        openSettings: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.openSettings?()
                        },
                        dismiss: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { _ in
                                if let controller = environment.controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }, action: { [weak self] value in
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
                                self.component?.completion?(value)
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.plainBackgroundColor),
                    isScrollEnabled: false,
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class BirthdayPickerScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, settings: Signal<AccountPrivacySettings?, NoError>, openSettings: (() -> Void)?, completion: ((TelegramBirthday) -> Void)? = nil) {
        super.init(context: context, component: BirthdayPickerScreenComponent(
            context: context,
            settings: settings,
            openSettings: openSettings,
            completion: completion
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
