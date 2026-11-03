import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import AvatarComponent
import MultilineTextComponent
import ButtonComponent
import BundleIconComponent

private final class CommunityPrivateChatContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let chatPeer: EnginePeer
    let requestedByPeer: EnginePeer?
    let memberCount: Int32?
    let dismiss: () -> Void
    let messageOwner: () -> Void

    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        requestedByPeer: EnginePeer?,
        memberCount: Int32?,
        dismiss: @escaping () -> Void,
        messageOwner: @escaping () -> Void
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.requestedByPeer = requestedByPeer
        self.memberCount = memberCount
        self.dismiss = dismiss
        self.messageOwner = messageOwner
    }

    static func ==(lhs: CommunityPrivateChatContentComponent, rhs: CommunityPrivateChatContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.chatPeer != rhs.chatPeer {
            return false
        }
        if lhs.requestedByPeer != rhs.requestedByPeer {
            return false
        }
        if lhs.memberCount != rhs.memberCount {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let infoText = ComponentView<Empty>()
        private let messageOwnerButton = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()

        private var hiddenIconImage: UIImage?

        private func infoAttributedText(theme: PresentationTheme, strings: PresentationStrings) -> NSAttributedString {
            if self.hiddenIconImage == nil {
                self.hiddenIconImage = generateTintedImage(
                    image: generateScaledImage(image: UIImage(bundleImageName: "Chat/Message/Hidden"), size: CGSize(width: 20.0, height: 20.0), opaque: false),
                    color: theme.list.itemPrimaryTextColor
                )
            }

            let text = NSMutableAttributedString(
                string: "#  \(strings.Community_PrivateChat_Info)",
                font: Font.regular(15.0),
                textColor: theme.list.itemPrimaryTextColor
            )
            if let image = self.hiddenIconImage {
                text.addAttribute(.attachment, value: image, range: NSRange(location: 0, length: 1))
                text.addAttribute(.baselineOffset, value: 2.0, range: NSRange(location: 0, length: 1))
            }
            return text
        }

        func update(component: CommunityPrivateChatContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
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
                    peer: component.chatPeer,
                    clipStyle: .round
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                transition.setFrame(view: avatarView, frame: CGRect(
                    origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarSize.width) / 2.0), y: 32.0),
                    size: avatarSize
                ))
            }

            var contentHeight: CGFloat = 32.0 + avatarSize.height + 11.0

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.chatPeer.compactDisplayTitle,
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

            let infoSize = self.infoText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(self.infoAttributedText(theme: theme, strings: environment.strings)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 200.0)
            )
            if let infoView = self.infoText.view {
                if infoView.superview == nil {
                    self.addSubview(infoView)
                }
                transition.setFrame(view: infoView, frame: CGRect(
                    origin: CGPoint(x: floorToScreenPixels((availableSize.width - infoSize.width) / 2.0), y: contentHeight),
                    size: infoSize
                ))
            }
            contentHeight += infoSize.height + 23.0

            let buttonHeight: CGFloat = 52.0
            let buttonSize = CGSize(width: contentWidth, height: buttonHeight)

            let messageOwnerButtonSize = self.messageOwnerButton.update(
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
                            text: environment.strings.Community_PrivateChat_MessageOwner,
                            badge: 0,
                            textColor: theme.list.itemCheckColors.foregroundColor,
                            fontSize: 17.0,
                            badgeBackground: theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: component.requestedByPeer != nil,
                    action: {
                        component.messageOwner()
                    }
                )),
                environment: {},
                containerSize: buttonSize
            )
            if let messageOwnerButtonView = self.messageOwnerButton.view {
                if messageOwnerButtonView.superview == nil {
                    self.addSubview(messageOwnerButtonView)
                }
                transition.setFrame(view: messageOwnerButtonView, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentHeight),
                    size: CGSize(width: contentWidth, height: messageOwnerButtonSize.height)
                ))
            }
            contentHeight += messageOwnerButtonSize.height + 10.0

            let cancelButtonSize = self.cancelButton.update(
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
                            text: environment.strings.Common_Cancel,
                            badge: 0,
                            textColor: theme.list.itemPrimaryTextColor,
                            fontSize: 17.0,
                            badgeBackground: theme.list.itemPrimaryTextColor,
                            badgeForeground: theme.list.itemBlocksBackgroundColor
                        ))
                    ),
                    action: {
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: buttonSize
            )
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: contentHeight),
                    size: CGSize(width: contentWidth, height: cancelButtonSize.height)
                ))
            }
            contentHeight += cancelButtonSize.height + 30.0

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

private final class CommunityPrivateChatScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let chatPeer: EnginePeer
    let requestedByPeer: EnginePeer?
    let memberCount: Int32?
    let messageOwner: () -> Void

    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        requestedByPeer: EnginePeer?,
        memberCount: Int32?,
        messageOwner: @escaping () -> Void
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.requestedByPeer = requestedByPeer
        self.memberCount = memberCount
        self.messageOwner = messageOwner
    }

    static func ==(lhs: CommunityPrivateChatScreenComponent, rhs: CommunityPrivateChatScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.chatPeer != rhs.chatPeer {
            return false
        }
        if lhs.requestedByPeer != rhs.requestedByPeer {
            return false
        }
        if lhs.memberCount != rhs.memberCount {
            return false
        }
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(EnvironmentType, SheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()

        private var component: CommunityPrivateChatScreenComponent?
        private var environment: EnvironmentType?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

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

        func update(component: CommunityPrivateChatScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            let environment = environment[EnvironmentType.self].value
            self.environment = environment

            let theme = environment.theme
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(CommunityPrivateChatContentComponent(
                        context: component.context,
                        chatPeer: component.chatPeer,
                        requestedByPeer: component.requestedByPeer,
                        memberCount: component.memberCount,
                        dismiss: { [weak self] in
                            self?.dismiss(animated: true)
                        },
                        messageOwner: { [weak self] in
                            self?.dismiss(animated: true, completion: {
                                component.messageOwner()
                            })
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

public final class CommunityPrivateChatScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        chatPeer: EnginePeer,
        requestedByPeer: EnginePeer?,
        memberCount: Int32?,
        messageOwner: @escaping () -> Void
    ) {
        super.init(
            context: context,
            component: CommunityPrivateChatScreenComponent(
                context: context,
                chatPeer: chatPeer,
                requestedByPeer: requestedByPeer,
                memberCount: memberCount,
                messageOwner: messageOwner
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
