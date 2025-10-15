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
    
    let context: AccountContext
    let mode: BirthdayPickerScreen.Mode
    let settings: Signal<AccountPrivacySettings?, NoError>
    let canHideYear: Bool
    let openSettings: () -> Void
    let dismiss: () -> Void
    let action: (TelegramBirthday) -> Void
    let requestHideYear: (ComponentTransition) -> Void
    
    init(
        context: AccountContext,
        mode: BirthdayPickerScreen.Mode,
        settings: Signal<AccountPrivacySettings?, NoError>,
        canHideYear: Bool,
        openSettings: @escaping () -> Void,
        dismiss: @escaping () -> Void,
        action: @escaping (TelegramBirthday) -> Void,
        requestHideYear: @escaping (ComponentTransition) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.settings = settings
        self.canHideYear = canHideYear
        self.openSettings = openSettings
        self.dismiss = dismiss
        self.action = action
        self.requestHideYear = requestHideYear
    }
    
    static func ==(lhs: BirthdayPickerSheetContentComponent, rhs: BirthdayPickerSheetContentComponent) -> Bool {
        if lhs.canHideYear != rhs.canHideYear {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let cancel = ComponentView<Empty>()
        private let content = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var birthday = TelegramBirthday(day: 1, month: 1, year: nil)
        
        private var component: BirthdayPickerSheetContentComponent?
        private var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: BirthdayPickerSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                if case let .acceptSuggestion(birthday) = component.mode {
                    self.birthday = birthday
                }
            }
            
            self.component = component
            self.state = state
                        
            let environment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 18.0
                        
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(BirthdayPickerContentComponent(
                    context: component.context,
                    mode: component.mode,
                    theme: environment.theme,
                    strings: environment.strings, 
                    settings: component.settings,
                    value: self.birthday,
                    canHideYear: component.canHideYear,
                    updateValue: { [weak self] value in
                        if let self {
                            self.birthday = value
                        }
                    },
                    dismiss: component.dismiss,
                    openSettings: component.openSettings,
                    requestHideYear: component.requestHideYear
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
            
            let buttonTitle: String
            switch component.mode {
            case .generic:
                buttonTitle = environment.strings.Birthday_Save
            case .suggest:
                buttonTitle = environment.strings.SuggestBirthdate_Suggest_Action
            case .acceptSuggestion:
                buttonTitle = environment.strings.SuggestBirthdate_Accept_Action
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
                        Text(text: buttonTitle, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
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
    let mode: BirthdayPickerScreen.Mode
    let settings: Signal<AccountPrivacySettings?, NoError>
    let openSettings: (() -> Void)?
    let completion: ((TelegramBirthday) -> Void)?
    
    init(
        context: AccountContext,
        mode: BirthdayPickerScreen.Mode,
        settings: Signal<AccountPrivacySettings?, NoError>,
        openSettings: (() -> Void)?,
        completion: ((TelegramBirthday) -> Void)?
    ) {
        self.context = context
        self.mode = mode
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
        
        private var canHideYear = false
        
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
            if self.component == nil {
                if case let .acceptSuggestion(birthday) = component.mode, let _ = birthday.year {
                    self.canHideYear = true
                }
            }
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
                        context: component.context,
                        mode: component.mode,
                        settings: component.settings,
                        canHideYear: self.canHideYear,
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
                        },
                        action: { [weak self] value in
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
                        },
                        requestHideYear: { [weak self] transition in
                            guard let self, let controller = self.environment?.controller() as? BirthdayPickerScreen else {
                                return
                            }
                            self.canHideYear = false
                            controller.requestLayout(forceUpdate: true, transition: transition)
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.plainBackgroundColor),
                    followContentSizeChanges: true,
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
    public enum Mode: Equatable {
        case generic
        case suggest(EnginePeer.Id)
        case acceptSuggestion(TelegramBirthday)
    }
    public init(context: AccountContext, mode: Mode = .generic, settings: Signal<AccountPrivacySettings?, NoError>, openSettings: (() -> Void)?, completion: ((TelegramBirthday) -> Void)? = nil) {
        super.init(context: context, component: BirthdayPickerScreenComponent(
            context: context,
            mode: mode,
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
