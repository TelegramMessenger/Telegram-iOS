import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import AvatarComponent
import MultilineTextComponent
import ButtonComponent

private final class CommunityAdminApprovalContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let community: EnginePeer
    let dismiss: () -> Void
    let noThanks: () -> Void

    init(
        context: AccountContext,
        community: EnginePeer,
        dismiss: @escaping () -> Void,
        noThanks: @escaping () -> Void
    ) {
        self.context = context
        self.community = community
        self.dismiss = dismiss
        self.noThanks = noThanks
    }

    static func ==(lhs: CommunityAdminApprovalContentComponent, rhs: CommunityAdminApprovalContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.community != rhs.community {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarShadow = UIImageView()
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let continueButton = ComponentView<Empty>()
        private let noThanksButton = ComponentView<Empty>()

        override init(frame: CGRect) {
            self.avatarShadow.image = UIImage(bundleImageName: "Components/CommunityShadow")

            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: CommunityAdminApprovalContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let theme = environment.theme

            self.backgroundColor = .clear

            let sideInset: CGFloat = 30.0
            let contentWidth = max(1.0, availableSize.width - sideInset * 2.0)

            let avatarSize = self.avatar.update(
                transition: transition,
                component: AnyComponent(AvatarComponent(
                    context: component.context,
                    theme: theme,
                    peer: component.community,
                    clipStyle: .roundedRect
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(self.avatarShadow)
                    self.addSubview(avatarView)
                }
                let avatarFrame = CGRect(
                    origin: CGPoint(
                        x: floorToScreenPixels((availableSize.width - avatarSize.width) / 2.0),
                        y: 32.0
                    ),
                    size: avatarSize
                )
                transition.setFrame(view: avatarView, frame: avatarFrame)

                if let shadowImage = self.avatarShadow.image {
                    self.avatarShadow.tintColor = theme.list.freeTextColor

                    let aspectRatio = shadowImage.size.width / shadowImage.size.height
                    let shadowSize = CGSize(width: avatarSize.width * aspectRatio, height: avatarSize.width)
                    let shadowFrame = shadowSize.centered(around: avatarFrame.center).offsetBy(dx: -13.0, dy: 0.0)
                    transition.setFrame(view: self.avatarShadow, frame: shadowFrame)
                }
            }

            var contentHeight: CGFloat = 32.0 + avatarSize.height + 11.0

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "You are a community admin",
                        font: Font.semibold(23.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 100.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(
                    origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: contentHeight),
                    size: titleSize
                ))
            }
            contentHeight += titleSize.height + 17.0

            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "You can now edit \(component.community.compactDisplayTitle) info\nand use other admin tools.",
                        font: Font.regular(15.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 200.0)
            )
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: CGRect(
                    origin: CGPoint(x: floorToScreenPixels((availableSize.width - subtitleSize.width) / 2.0), y: contentHeight),
                    size: subtitleSize
                ))
            }
            contentHeight += subtitleSize.height + 23.0

            let buttonHeight: CGFloat = 52.0
            let buttonSize = CGSize(width: contentWidth, height: buttonHeight)

            let continueButtonSize = self.continueButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(ButtonTextContentComponent(
                            text: "Continue",
                            badge: 0,
                            textColor: theme.list.itemCheckColors.foregroundColor,
                            fontSize: 17.0,
                            badgeBackground: theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    action: {
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: buttonSize
            )
            if let continueButtonView = self.continueButton.view {
                if continueButtonView.superview == nil {
                    self.addSubview(continueButtonView)
                }
                transition.setFrame(view: continueButtonView, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentHeight),
                    size: CGSize(width: contentWidth, height: continueButtonSize.height)
                ))
            }
            contentHeight += continueButtonSize.height + 10.0

            let noThanksButtonSize = self.noThanksButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.08),
                        foreground: theme.list.itemPrimaryTextColor,
                        pressedColor: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.14)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(ButtonTextContentComponent(
                            text: "No, thanks",
                            badge: 0,
                            textColor: theme.list.itemPrimaryTextColor,
                            fontSize: 17.0,
                            badgeBackground: theme.list.itemPrimaryTextColor,
                            badgeForeground: theme.list.itemBlocksBackgroundColor
                        ))
                    ),
                    action: {
                        component.noThanks()
                    }
                )),
                environment: {},
                containerSize: buttonSize
            )
            if let noThanksButtonView = self.noThanksButton.view {
                if noThanksButtonView.superview == nil {
                    self.addSubview(noThanksButtonView)
                }
                transition.setFrame(view: noThanksButtonView, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentHeight),
                    size: CGSize(width: contentWidth, height: noThanksButtonSize.height)
                ))
            }
            contentHeight += noThanksButtonSize.height + 30.0

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

private final class CommunityAdminApprovalScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let community: EnginePeer

    init(context: AccountContext, community: EnginePeer) {
        self.context = context
        self.community = community
    }

    static func ==(lhs: CommunityAdminApprovalScreenComponent, rhs: CommunityAdminApprovalScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.community != rhs.community {
            return false
        }
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(EnvironmentType, SheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()

        private var component: CommunityAdminApprovalScreenComponent?
        private var environment: EnvironmentType?

        private func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
            guard let controller = self.environment?.controller else {
                completion?()
                return
            }
            if animated {
                self.animateOut.invoke(Action { _ in
                    controller()?.dismiss(completion: completion)
                })
            } else {
                controller()?.dismiss(animated: false, completion: completion)
            }
        }

        private func presentNoThanksAlert() {
            guard let component = self.component, let controller = self.environment?.controller else {
                return
            }
            controller()?.present(textAlertController(
                context: component.context,
                title: "Dismiss yourself as community admin",
                text: "You'll lose access to community admin tools, but keep your group admin rights.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: {}),
                    TextAlertAction(type: .defaultAction, title: "OK", action: { [weak self] in
                        self?.dismiss(animated: true)
                    })
                ]
            ), in: .window(.root))
        }

        func update(component: CommunityAdminApprovalScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            let environment = environment[EnvironmentType.self].value
            self.environment = environment

            let theme = environment.theme
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(CommunityAdminApprovalContentComponent(
                        context: component.context,
                        community: component.community,
                        dismiss: { [weak self] in
                            self?.dismiss(animated: true)
                        },
                        noThanks: { [weak self] in
                            self?.presentNoThanksAlert()
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: self.animateOut
                )),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { [weak self] animated in
                            self?.dismiss(animated: animated)
                        }
                    )
                },
                containerSize: availableSize
            )
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

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class CommunityAdminApprovalScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, community: EnginePeer) {
        super.init(
            context: context,
            component: CommunityAdminApprovalScreenComponent(
                context: context,
                community: community
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }
}
