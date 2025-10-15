import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SheetComponent
import ButtonComponent
import LottieComponent
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import TelegramStringFormatting
import BundleIconComponent

public final class ButtonSubtitleComponent: CombinedComponent {
    public let title: String
    public let color: UIColor
    
    public init(title: String, color: UIColor) {
        self.title = title
        self.color = color
    }
    
    public static func ==(lhs: ButtonSubtitleComponent, rhs: ButtonSubtitleComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.color !== rhs.color {
            return false
        }
        return true
    }
    
    public static var body: Body {
        let icon = Child(BundleIconComponent.self)
        let text = Child(Text.self)

        return { context in
            let icon = icon.update(
                component: BundleIconComponent(
                    name: "Chat/Input/Accessory Panels/TextLockIcon",
                    tintColor: context.component.color,
                    maxSize: CGSize(width: 10.0, height: 10.0)
                ),
                availableSize: CGSize(width: 100.0, height: 100.0),
                transition: context.transition
            )
            
            let text = text.update(
                component: Text(text: context.component.title, font: Font.medium(11.0), color: context.component.color),
                availableSize: CGSize(width: context.availableSize.width - 20.0, height: 100.0),
                transition: context.transition
            )

            let spacing: CGFloat = 3.0
            let size = CGSize(width: icon.size.width + spacing + text.size.width, height: text.size.height)
            context.add(icon
                .position(icon.size.centered(in: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: icon.size.width, height: size.height))).center)
            )
            context.add(text
                .position(text.size.centered(in: CGRect(origin: CGPoint(x: icon.size.width + spacing, y: 0.0), size: text.size)).center)
            )

            return size
        }
    }
}

private final class StoryQualityUpgradeSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let action: () -> Void
    let dismiss: () -> Void
    
    init(
        action: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.action = action
        self.dismiss = dismiss
    }
    
    static func ==(lhs: StoryQualityUpgradeSheetContentComponent, rhs: StoryQualityUpgradeSheetContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var cancelButton: ComponentView<Empty>?
        
        private var component: StoryQualityUpgradeSheetContentComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: StoryQualityUpgradeSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            
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
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 32.0
            
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "StoryUpgradeSheet"),
                    color: nil,
                    startingPosition: .begin,
                    size: CGSize(width: 100.0, height: 100.0)
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: 42.0), size: iconSize))
            }
            
            contentHeight += 138.0
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.Story_UpgradeQuality_Title, font: Font.semibold(20.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize))
            }
            contentHeight += titleSize.height
            contentHeight += 14.0
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.Story_UpgradeQuality_Text, font: Font.regular(14.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.18
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) * 0.5), y: contentHeight), size: textSize))
            }
            contentHeight += textSize.height
            contentHeight += 12.0
            
            contentHeight += 32.0

            var buttonContents: [AnyComponentWithIdentity<Empty>] = []
            buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                Text(text: environment.strings.Story_UpgradeQuality_Action, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
            )))
            
            buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(ButtonSubtitleComponent(
                title: environment.strings.Story_UpgradeQuality_ActionSubtitle,
                color: environment.theme.list.itemCheckColors.foregroundColor.withMultipliedAlpha(0.7)
            ))))
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        VStack(buttonContents, spacing: 3.0)
                    )),
                    isEnabled: true,
                    allowActionWhenDisabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        component.action()
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

private final class StoryQualityUpgradeSheetScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let buttonAction: (() -> Void)?
    
    init(
        context: AccountContext,
        buttonAction: (() -> Void)?
    ) {
        self.context = context
        self.buttonAction = buttonAction
    }
    
    static func ==(lhs: StoryQualityUpgradeSheetScreenComponent, rhs: StoryQualityUpgradeSheetScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: StoryQualityUpgradeSheetScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryQualityUpgradeSheetScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
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
                    content: AnyComponent(StoryQualityUpgradeSheetContentComponent(
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class StoryQualityUpgradeSheetScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        buttonAction: (() -> Void)? = nil
    ) {
        super.init(context: context, component: StoryQualityUpgradeSheetScreenComponent(
            context: context,
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
