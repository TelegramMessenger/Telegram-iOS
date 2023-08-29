import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SheetComponent
import ButtonComponent
import TelegramCore

private final class ArchiveInfoSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let settings: GlobalPrivacySettings
    let openSettings: () -> Void
    let dismiss: () -> Void
    
    init(
        settings: GlobalPrivacySettings,
        openSettings: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.settings = settings
        self.openSettings = openSettings
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ArchiveInfoSheetContentComponent, rhs: ArchiveInfoSheetContentComponent) -> Bool {
        if lhs.settings != rhs.settings {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let content = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var component: ArchiveInfoSheetContentComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ArchiveInfoSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            
            let environment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 30.0
            
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(ArchiveInfoContentComponent(
                    theme: environment.theme,
                    strings: environment.strings,
                    settings: component.settings,
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
            contentHeight += 30.0
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        Text(text: environment.strings.ArchiveInfo_CloseAction, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: true,
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

private final class ArchiveInfoScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let settings: GlobalPrivacySettings
    let buttonAction: (() -> Void)?
    
    init(
        context: AccountContext,
        settings: GlobalPrivacySettings,
        buttonAction: (() -> Void)?
    ) {
        self.context = context
        self.settings = settings
        self.buttonAction = buttonAction
    }
    
    static func ==(lhs: ArchiveInfoScreenComponent, rhs: ArchiveInfoScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.settings != rhs.settings {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: ArchiveInfoScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ArchiveInfoScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
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
                    content: AnyComponent(ArchiveInfoSheetContentComponent(
                        settings: component.settings,
                        openSettings: { [weak self] in
                            guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                return
                            }
                            let context = component.context
                            self.sheetAnimateOut.invoke(Action { [weak context, weak controller] _ in
                                if let controller, let context {
                                    if let navigationController = controller.navigationController as? NavigationController {
                                        navigationController.pushViewController(context.sharedContext.makeArchiveSettingsController(context: context))
                                    }
                                    controller.dismiss(completion: nil)
                                }
                            })
                        },
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

public class ArchiveInfoScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, settings: GlobalPrivacySettings, buttonAction: (() -> Void)? = nil) {
        super.init(context: context, component: ArchiveInfoScreenComponent(
            context: context,
            settings: settings,
            buttonAction: buttonAction
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
