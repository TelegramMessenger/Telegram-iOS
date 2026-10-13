import Foundation
import UIKit
import Display
import AccountContext
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import ButtonComponent
import WalletContext
import WalletConnectScreen
import TelegramPresentationData
import SwiftSignalKit

private final class WalletAppInfoContentComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let manifest: TonConnectManifestInfo
    let isDisconnecting: Bool
    let disconnect: () -> Void
    let animateOut: ActionSlot<Action<Void>>
    let getController: () -> ViewController?

    init(context: AccountContext, manifest: TonConnectManifestInfo, isDisconnecting: Bool, disconnect: @escaping () -> Void, animateOut: ActionSlot<Action<Void>>, getController: @escaping () -> ViewController?) {
        self.context = context
        self.manifest = manifest
        self.isDisconnecting = isDisconnecting
        self.disconnect = disconnect
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletAppInfoContentComponent, rhs: WalletAppInfoContentComponent) -> Bool {
        return lhs.context === rhs.context && lhs.manifest == rhs.manifest && lhs.isDisconnecting == rhs.isDisconnecting
    }

    static var body: Body {
        let icon = Child(WalletConnectAppIconComponent.self)
        let title = Child(BalancedTextComponent.self)
        let domain = Child(ButtonComponent.self)
        let description = Child(BalancedTextComponent.self)
        let disconnectButton = Child(ButtonComponent.self)
        let closeButton = Child(GlassBarButtonComponent.self)

        return { context in
            let component = context.component
            let environment = context.environment[EnvironmentType.self].value
            let theme = environment.theme
            let contentWidth = max(1.0, context.availableSize.width - environment.safeInsets.left - environment.safeInsets.right)
            let centerX = environment.safeInsets.left + contentWidth / 2.0
            let textWidth = max(1.0, contentWidth - 48.0)
            var contentHeight: CGFloat = 32.0

            let icon = icon.update(
                component: WalletConnectAppIconComponent(context: component.context, applicationName: component.manifest.name, icon: component.manifest.icon),
                availableSize: CGSize(width: 88.0, height: 88.0),
                transition: context.transition
            )
            context.add(icon
                .position(CGPoint(x: centerX, y: contentHeight + icon.size.height / 2.0))
                .cornerRadius(icon.size.width * 0.5)
                .clipsToBounds(true)
            )
            contentHeight += icon.size.height + 18.0

            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: component.manifest.name, font: Font.bold(22.0), textColor: theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title.position(CGPoint(x: centerX, y: contentHeight + title.size.height / 2.0)))
            contentHeight += title.size.height - 6.0

            let domain = domain.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(color: .clear, foreground: theme.actionSheet.controlAccentColor, pressedColor: .clear),
                    content: AnyComponentWithIdentity(id: "domain", component: AnyComponent(BalancedTextComponent(
                        text: .plain(NSAttributedString(string: component.manifest.domain, font: Font.semibold(15.0), textColor: theme.actionSheet.controlAccentColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 2
                    ))),
                    contentInsets: .zero,
                    isEnabled: !component.isDisconnecting,
                    action: {
                        guard let controller = component.getController() else {
                            return
                        }
                        component.context.sharedContext.openExternalUrl(
                            context: component.context,
                            urlContext: .generic,
                            url: component.manifest.url,
                            forceExternal: false,
                            presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                            navigationController: controller.navigationController as? NavigationController,
                            dismissInput: {}
                        )
                    }
                ),
                availableSize: CGSize(width: textWidth, height: 44.0),
                transition: context.transition
            )
            context.add(domain.position(CGPoint(x: centerX, y: contentHeight + domain.size.height / 2.0)))
            contentHeight += domain.size.height + 5.0

            let description = description.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.Wallet_Apps_Permissions, font: Font.regular(15.0), textColor: theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(description.position(CGPoint(x: centerX, y: contentHeight + description.size.height / 2.0)))
            contentHeight += description.size.height + 25.0

            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let disconnectButton = disconnectButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemDestructiveColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemDestructiveColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(id: "disconnect", component: AnyComponent(Text(
                        text: environment.strings.Wallet_Apps_Disconnect,
                        font: Font.semibold(17.0),
                        color: theme.list.itemCheckColors.foregroundColor
                    ))),
                    isEnabled: !component.isDisconnecting,
                    displaysProgress: component.isDisconnecting,
                    action: component.disconnect
                ),
                availableSize: CGSize(width: max(1.0, contentWidth - buttonInsets.left - buttonInsets.right), height: 52.0),
                transition: context.transition
            )
            context.add(disconnectButton.position(CGPoint(x: centerX, y: contentHeight + disconnectButton.size.height / 2.0)))
            contentHeight += disconnectButton.size.height + buttonInsets.bottom

            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    isEnabled: !component.isDisconnecting,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(BundleIconComponent(
                        name: "Navigation/Close",
                        tintColor: theme.chat.inputPanel.panelControlColor
                    ))),
                    action: { _ in
                        (component.getController() as? WalletAppInfoScreen)?.finish(animated: true, animateOut: component.animateOut)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: context.transition
            )
            context.add(closeButton.position(CGPoint(x: environment.safeInsets.left + 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0)))

            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class WalletAppInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let manifest: TonConnectManifestInfo
    let disconnect: (@escaping (Bool) -> Void) -> Void

    init(context: AccountContext, manifest: TonConnectManifestInfo, disconnect: @escaping (@escaping (Bool) -> Void) -> Void) {
        self.context = context
        self.manifest = manifest
        self.disconnect = disconnect
    }

    static func ==(lhs: WalletAppInfoSheetComponent, rhs: WalletAppInfoSheetComponent) -> Bool {
        return lhs.context === rhs.context && lhs.manifest == rhs.manifest
    }

    final class State: ComponentState {
        var isDisconnecting = false

        func disconnect(component: WalletAppInfoSheetComponent, controller: WalletAppInfoScreen, animateOut: ActionSlot<Action<Void>>) {
            guard !self.isDisconnecting, !controller.isFinishing else {
                return
            }
            self.isDisconnecting = true
            controller.isDisconnecting = true
            self.updated(transition: .easeInOut(duration: 0.2))
            component.disconnect { [weak self, weak controller] succeeded in
                guard let self else {
                    return
                }
                self.isDisconnecting = false
                controller?.isDisconnecting = false
                self.updated(transition: .easeInOut(duration: 0.2))
                if succeeded {
                    controller?.finish(animated: true, animateOut: animateOut)
                }
            }
        }
    }

    func makeState() -> State {
        return State()
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let externalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let component = context.component
            let state = context.state
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent(WalletAppInfoContentComponent(
                        context: context.component.context,
                        manifest: context.component.manifest,
                        isDisconnecting: state.isDisconnecting,
                        disconnect: { [weak state] in
                            guard let controller = controller() as? WalletAppInfoScreen else {
                                return
                            }
                            state?.disconnect(component: component, controller: controller, animateOut: animateOut)
                        },
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    isScrollEnabled: !state.isDisconnecting,
                    autoAnimateOut: false,
                    externalState: externalState,
                    animateOut: animateOut,
                    onPan: {},
                    willDismiss: {}
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            (controller() as? WalletAppInfoScreen)?.finish(animated: animated, animateOut: animateOut)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheet.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))

            if let controller = controller() {
                var sideInset: CGFloat = 0.0
                var bottomInset = max(environment.safeInsets.bottom, externalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height + externalState.contentHeight) / 2.0
                }
                controller.presentationContext.containerLayoutUpdated(ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false,
                    presentedInFormSheet: false
                ), transition: context.transition.containedViewLayoutTransition)
            }
            return context.availableSize
        }
    }
}

final class WalletAppInfoScreen: ViewControllerComponentContainer {
    let sessionId: Int64
    private let closed: () -> Void
    fileprivate var isDisconnecting = false
    fileprivate var isFinishing = false

    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>), sessionId: Int64, manifest: TonConnectManifestInfo, disconnect: @escaping (@escaping (Bool) -> Void) -> Void, closed: @escaping () -> Void) {
        self.sessionId = sessionId
        self.closed = closed
        super.init(
            context: context,
            component: WalletAppInfoSheetComponent(context: context, manifest: manifest, disconnect: disconnect),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    fileprivate func finish(animated: Bool, animateOut: ActionSlot<Action<Void>>?) {
        guard !self.isDisconnecting, !self.isFinishing else {
            return
        }
        self.isFinishing = true
        let closed = self.closed
        let dismiss: () -> Void = { [weak self] in
            guard let self else {
                closed()
                return
            }
            if let navigationController = self.navigationController as? NavigationController {
                navigationController.setViewControllers(navigationController.viewControllers.filter { $0 !== self }, animated: false, completion: closed)
            } else {
                self.dismiss(completion: closed)
            }
        }
        if animated, let animateOut {
            animateOut.invoke(Action { _ in dismiss() })
        } else {
            dismiss()
        }
    }

    func dismissAnimated() {
        guard !self.isDisconnecting, !self.isFinishing else {
            return
        }
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        } else {
            self.finish(animated: false, animateOut: nil)
        }
    }
}
