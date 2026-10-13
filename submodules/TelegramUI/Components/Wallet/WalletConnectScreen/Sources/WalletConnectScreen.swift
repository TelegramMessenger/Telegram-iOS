import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import ButtonComponent
import WalletContext
import WalletCardComponent
import AlertUI
import UndoUI

fileprivate enum WalletConnectFinishResult {
    case cancelled
    case connected
}

public final class WalletConnectAppIconComponent: Component {
    let applicationName: String
    let context: AccountContext
    let icon: WalletTonConnectIcon?
    let size: CGFloat
    let cornerRadius: CGFloat?

    public init(context: AccountContext, applicationName: String, icon: WalletTonConnectIcon?, size: CGFloat = 88.0, cornerRadius: CGFloat? = nil) {
        self.applicationName = applicationName
        self.context = context
        self.icon = icon
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public static func ==(lhs: WalletConnectAppIconComponent, rhs: WalletConnectAppIconComponent) -> Bool {
        return lhs.applicationName == rhs.applicationName && lhs.context === rhs.context && lhs.icon == rhs.icon && lhs.size == rhs.size && lhs.cornerRadius == rhs.cornerRadius
    }

    public final class View: UIView {
        private let imageView = UIImageView()
        private let fallbackLabel = UILabel()
        private var currentIcon: WalletTonConnectIcon?
        private weak var accountContext: AccountContext?
        private let fetchDisposable = MetaDisposable()
        private let dataDisposable = MetaDisposable()

        public override init(frame: CGRect) {
            super.init(frame: frame)

            self.clipsToBounds = true
            self.backgroundColor = UIColor(rgb: 0x2aabee)
            self.imageView.contentMode = .scaleAspectFill
            self.fallbackLabel.textAlignment = .center
            self.fallbackLabel.font = Font.bold(40.0)
            self.fallbackLabel.textColor = .white
            self.addSubview(self.fallbackLabel)
            self.addSubview(self.imageView)
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.fetchDisposable.dispose()
            self.dataDisposable.dispose()
        }

        func update(component: WalletConnectAppIconComponent, availableSize: CGSize) -> CGSize {
            let size = CGSize(width: min(availableSize.width, component.size), height: min(availableSize.height, component.size))
            self.layer.cornerRadius = component.cornerRadius ?? size.height / 2.0
            self.fallbackLabel.font = Font.bold(min(40.0, size.height * 0.5))
            self.imageView.frame = CGRect(origin: .zero, size: size)
            self.fallbackLabel.frame = CGRect(origin: .zero, size: size)
            self.fallbackLabel.text = component.applicationName.first.map { String($0).uppercased() }

            if self.currentIcon != component.icon || self.accountContext !== component.context {
                self.currentIcon = component.icon
                self.accountContext = component.context
                self.fetchDisposable.set(nil)
                self.dataDisposable.set(nil)
                self.imageView.image = nil
                self.fallbackLabel.isHidden = false

                if let icon = component.icon, icon.size > 0, icon.size <= 2 * 1024 * 1024,
                   icon.mimeType.lowercased().hasPrefix("image/") {
                    let mediaBox = component.context.account.postbox.mediaBox
                    let resource = WebFileReferenceMediaResource(url: icon.url, size: Int64(icon.size), accessHash: icon.accessHash)
                    self.dataDisposable.set((mediaBox.resourceData(resource)
                    |> map { data -> UIImage? in
                        guard data.complete, data.size <= 2 * 1024 * 1024 else { return nil }
                        return UIImage(contentsOfFile: data.path)
                    }
                    |> deliverOnMainQueue).start(next: { [weak self, weak context = component.context] image in
                        guard let self, self.currentIcon == icon, self.accountContext === context, let image else { return }
                        self.imageView.image = image
                        self.fallbackLabel.isHidden = true
                    }))
                    self.fetchDisposable.set(fetchedMediaResource(mediaBox: mediaBox, userLocation: .other,
                        userContentType: .image, reference: .standalone(resource: resource), statsCategory: .image).start())
                }
            }
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

private final class WalletConnectSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let request: WalletContext.TonConnectRequest
    let connect: (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    let animateOut: ActionSlot<Action<Void>>
    let getController: () -> ViewController?

    init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectRequest,
        connect: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void,
        animateOut: ActionSlot<Action<Void>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.walletContext = walletContext
        self.request = request
        self.connect = connect
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletConnectSheetContent, rhs: WalletConnectSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.walletContext !== rhs.walletContext {
            return false
        }
        if lhs.request != rhs.request {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let getController: () -> ViewController?
        private let disposables = DisposableSet()

        fileprivate var walletState: WalletContext.State?
        fileprivate var accountName = ""
        fileprivate var isConnecting = false

        init(
            context: AccountContext,
            walletContext: WalletContext,
            getController: @escaping () -> ViewController?
        ) {
            self.getController = getController

            super.init()

            self.disposables.add((walletContext.state
            |> deliverOnMainQueue).start(next: { [weak self] walletState in
                guard let self else {
                    return
                }
                self.walletState = walletState
                self.updated(transition: .easeInOut(duration: 0.25))
            }))

            self.disposables.add((context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self else {
                    return
                }
                let accountName = peer?.debugDisplayTitle.uppercased() ?? ""
                if self.accountName != accountName {
                    self.accountName = accountName
                    self.updated(transition: .immediate)
                }
            }))
        }

        deinit {
            self.disposables.dispose()
        }

        func finish(_ result: WalletConnectFinishResult, animated: Bool, animateOut: ActionSlot<Action<Void>>) {
            guard let controller = self.getController() as? WalletConnectScreen else {
                return
            }
            controller.finish(result, animated: animated, animateOut: animateOut)
        }

        func connect(component: WalletConnectSheetContent) {
            guard !self.isConnecting else {
                return
            }
            self.isConnecting = true
            // Keep the button spinner visible while preventing the sheet's pan or dim-tap dismissal.
            self.getController()?.view.isUserInteractionEnabled = false
            self.updated(transition: .easeInOut(duration: 0.2))
            
            component.connect({ [weak self] result in
                guard let self else {
                    return
                }
                self.getController()?.view.isUserInteractionEnabled = true
                switch result {
                case .success:
                    self.finish(.connected, animated: true, animateOut: component.animateOut)
                case let .failure(error):
                    self.isConnecting = false
                    self.updated(transition: .easeInOut(duration: 0.2))
                    if error == .authorizationCancelled { return }
                    guard let controller = self.getController() else {
                        return
                    }
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    controller.present(textAlertController(
                        context: component.context,
                        title: nil,
                        text: presentationData.strings.Wallet_Connect_Error,
                        actions: [
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                        ]
                    ), in: .window(.root))
                }
            })
        }

        func openReceive(context: AccountContext, address: String) {
            guard let controller = self.getController() else {
                return
            }
            let receiveController = context.sharedContext.makeWalletReceiveScreen(
                context: context,
                address: address
            )
            if controller.navigationController != nil {
                controller.push(receiveController)
            } else {
                controller.window?.present(
                    receiveController,
                    on: .root,
                    blockInteraction: false,
                    completion: {
                    }
                )
            }
        }
    }

    func makeState() -> State {
        return State(
            context: self.context,
            walletContext: self.walletContext,
            getController: self.getController
        )
    }

    static var body: Body {
        let appIcon = Child(WalletConnectAppIconComponent.self)
        let title = Child(BalancedTextComponent.self)
        let domain = Child(HStack<Empty>.self)
        let permission = Child(BalancedTextComponent.self)
        let card = Child(WalletCardComponent.self)
        let disclaimer = Child(BalancedTextComponent.self)
        let cancelButton = Child(ButtonComponent.self)
        let connectButton = Child(ButtonComponent.self)
        let closeButton = Child(GlassBarButtonComponent.self)

        return { context in
            let component = context.component
            let state = context.state
            let environment = context.environment[EnvironmentType.self].value
            let theme = environment.theme

            let safeContentWidth = max(
                0.0,
                context.availableSize.width - environment.safeInsets.left - environment.safeInsets.right
            )
            let contentCenterX = environment.safeInsets.left + safeContentWidth / 2.0
            let textWidth = max(1.0, safeContentWidth - 48.0)
            let primaryTextColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let accentColor = theme.actionSheet.controlAccentColor

            var contentHeight: CGFloat = 32.0

            let appIconSize = CGSize(width: 88.0, height: 88.0)
            let appIconCenter = CGPoint(
                x: contentCenterX,
                y: contentHeight + appIconSize.height / 2.0
            )

            let appIcon = appIcon.update(
                component: WalletConnectAppIconComponent(
                    context: component.context,
                    applicationName: component.request.applicationName,
                    icon: component.request.icon
                ),
                availableSize: appIconSize,
                transition: context.transition
            )
            context.add(appIcon
                .position(appIconCenter)
                .cornerRadius(appIconSize.width * 0.5)
                .clipsToBounds(true)
            )
            contentHeight += appIconSize.height
            contentHeight += 18.0

            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Wallet_Connect_Title(component.request.applicationName).string,
                        font: Font.bold(22.0),
                        textColor: primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + title.size.height / 2.0
            )))
            contentHeight += title.size.height
            contentHeight += 5.0

            let domainItems: [AnyComponentWithIdentity<Empty>] = [AnyComponentWithIdentity(
                id: "domain",
                component: AnyComponent(Text(
                    text: component.request.domain,
                    font: Font.semibold(15.0),
                    color: accentColor
                ))
            )]
            let domain = domain.update(
                component: HStack<Empty>(domainItems, spacing: 4.0),
                availableSize: CGSize(width: textWidth, height: 30.0),
                transition: .immediate
            )
            context.add(domain.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + domain.size.height / 2.0
            )))
            contentHeight += domain.size.height
            contentHeight += 19.0

            var permissionTexts: [String] = []
            permissionTexts.append(environment.strings.Wallet_Connect_Permissions)
            for permission in component.request.permissions {
                if case let .proof(domain) = permission {
                    permissionTexts.append(environment.strings.Wallet_Connect_Proof(domain).string)
                }
            }
            let permissionText = permissionTexts.joined(separator: "\n\n")
            let permission = permission.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: permissionText,
                        font: Font.regular(15.0),
                        textColor: primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(permission.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + permission.size.height / 2.0
            )))
            contentHeight += permission.size.height
            contentHeight += 18.0

            let cardWidth = min(361.0, max(1.0, safeContentWidth - 42.0))
            let walletInfo: WalletContext.WalletInfo?
            if let walletState = state.walletState, case let .wallet(value) = walletState.phase {
                walletInfo = value
            } else {
                walletInfo = nil
            }
            let fiatCurrency = state.walletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = state.walletState?.fiat.selectedRate
            let card = card.update(
                component: WalletCardComponent(
                    theme: environment.theme,
                    balance: state.walletState?.balance.currentValue,
                    fiatCurrency: fiatCurrency,
                    fiatRate: fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    name: state.accountName,
                    address: walletInfo?.address ?? "",
                    isVisible: environment.isVisible,
                    qrPressed: { [weak state] in
                        guard let walletInfo else {
                            return
                        }
                        state?.openReceive(
                            context: component.context,
                            address: walletInfo.address
                        )
                    }
                ),
                availableSize: CGSize(width: cardWidth, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(card.position(
                CGPoint(
                    x: contentCenterX,
                    y: contentHeight + card.size.height / 2.0
                ))
                .clipsToBounds(false)
            )
            contentHeight += card.size.height
            contentHeight += 20.0

            let disclaimer = disclaimer.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Wallet_Connect_Disclaimer(component.request.applicationName).string,
                        font: Font.regular(13.0),
                        textColor: secondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(disclaimer.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + disclaimer.size.height / 2.0
            )))
            contentHeight += disclaimer.size.height
            contentHeight += 19.0

            let buttonSpacing: CGFloat = 10.0
            let buttonInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let buttonsWidth = max(2.0, safeContentWidth - buttonInsets.left - buttonInsets.right)
            let cancelButtonWidth = floorToScreenPixels((buttonsWidth - buttonSpacing) / 2.0)
            let connectButtonWidth = buttonsWidth - buttonSpacing - cancelButtonWidth

            let cancelButton = cancelButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                        foreground: theme.list.itemPrimaryTextColor,
                        pressedColor: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.16),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "cancel",
                        component: AnyComponent(Text(
                            text: environment.strings.Common_Cancel,
                            font: Font.semibold(17.0),
                            color: theme.list.itemPrimaryTextColor
                        ))
                    ),
                    isEnabled: !state.isConnecting,
                    action: { [weak state] in
                        state?.finish(.cancelled, animated: true, animateOut: component.animateOut)
                    }
                ),
                availableSize: CGSize(width: cancelButtonWidth, height: 52.0),
                transition: context.transition
            )
            context.add(cancelButton.position(CGPoint(
                x: contentCenterX - buttonSpacing / 2.0 - cancelButton.size.width / 2.0,
                y: contentHeight + cancelButton.size.height / 2.0
            )))

            let connectButton = connectButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "connect",
                        component: AnyComponent(Text(
                            text: environment.strings.Wallet_Connect_Action,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: !state.isConnecting,
                    displaysProgress: state.isConnecting,
                    action: { [weak state] in
                        state?.connect(component: component)
                    }
                ),
                availableSize: CGSize(width: connectButtonWidth, height: 52.0),
                transition: context.transition
            )
            context.add(connectButton.position(CGPoint(
                x: contentCenterX + buttonSpacing / 2.0 + connectButton.size.width / 2.0,
                y: contentHeight + connectButton.size.height / 2.0
            )))
            contentHeight += max(cancelButton.size.height, connectButton.size.height)
            contentHeight += buttonInsets.bottom

            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(
                        id: "close",
                        component: AnyComponent(BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        ))
                    ),
                    action: { [weak state] _ in
                        guard state?.isConnecting == false else {
                            return
                        }
                        state?.finish(.cancelled, animated: true, animateOut: component.animateOut)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton.position(CGPoint(
                x: environment.safeInsets.left + 16.0 + closeButton.size.width / 2.0,
                y: 16.0 + closeButton.size.height / 2.0
            )))

            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class WalletConnectSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let request: WalletContext.TonConnectRequest
    let connect: (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectRequest,
        connect: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    ) {
        self.context = context
        self.walletContext = walletContext
        self.request = request
        self.connect = connect
    }

    static func ==(lhs: WalletConnectSheetComponent, rhs: WalletConnectSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.walletContext !== rhs.walletContext {
            return false
        }
        if lhs.request != rhs.request {
            return false
        }
        return true
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller

            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletConnectSheetContent(
                        context: context.component.context,
                        walletContext: context.component.walletContext,
                        request: context.component.request,
                        connect: context.component.connect,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
                    }
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
                            if let controller = controller() as? WalletConnectScreen {
                                controller.finish(
                                    .cancelled,
                                    animated: animated,
                                    animateOut: animateOut
                                )
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )

            context.add(sheet.position(CGPoint(
                x: context.availableSize.width / 2.0,
                y: context.availableSize.height / 2.0
            )))

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }

                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(
                        top: 0.0,
                        left: max(sideInset, environment.safeInsets.left),
                        bottom: 0.0,
                        right: max(sideInset, environment.safeInsets.right)
                    ),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false,
                    presentedInFormSheet: false
                )
                controller.presentationContext.containerLayoutUpdated(
                    layout,
                    transition: context.transition.containedViewLayoutTransition
                )
            }

            return context.availableSize
        }
    }
}

public final class WalletConnectScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private var applicationName: String
    private let walletContext: WalletContext
    private let connectAction: (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    private let cancelled: () -> Void
    public var tonConnectClosed: (() -> Void)?
    private var finishResult: WalletConnectFinishResult?

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectRequest,
        cancelled: @escaping () -> Void,
        connect: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    ) {
        self.context = context
        self.applicationName = request.applicationName
        self.walletContext = walletContext
        self.connectAction = connect
        self.cancelled = cancelled

        super.init(
            context: context,
            component: WalletConnectSheetComponent(
                context: context,
                walletContext: walletContext,
                request: request,
                connect: connect
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    public func updateRequest(_ request: WalletContext.TonConnectRequest) {
        self.applicationName = request.applicationName
        self.updateComponent(component: AnyComponent(WalletConnectSheetComponent(context: self.context,
            walletContext: self.walletContext, request: request, connect: self.connectAction)), transition: .immediate)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }

    fileprivate func finish(
        _ result: WalletConnectFinishResult,
        animated: Bool,
        animateOut: ActionSlot<Action<Void>>?
    ) {
        guard self.finishResult == nil else {
            return
        }
        self.finishResult = result

        let callback: () -> Void
        switch result {
        case .cancelled:
            callback = self.cancelled
        case .connected:
            let context = self.context
            let applicationName = self.applicationName
            callback = {
                guard let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController,
                      let controller = navigationController.viewControllers.reversed().first(where: { !($0 is WalletConnectScreen) }) as? ViewController else {
                    return
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                controller.present(
                    UndoOverlayController(
                        presentationData: presentationData,
                        content: .actionSucceeded(
                            title: presentationData.strings.Wallet_Connect_SuccessTitle,
                            text: presentationData.strings.Wallet_Connect_SuccessText(applicationName).string,
                            cancel: nil,
                            destructive: false
                        ),
                        elevatedLayout: false,
                        animateInAsReplacement: false,
                        action: { _ in
                            return false
                        }
                    ),
                    in: .current
                )
            }
        }

        let dismissController: () -> Void = { [weak self] in
            guard let self else {
                callback()
                return
            }
            self.dismiss(completion: {
                callback()
                self.tonConnectClosed?()
            })
        }

        if animated, let animateOut {
            animateOut.invoke(Action { _ in
                dismissController()
            })
        } else if animated {
            dismissController()
        } else {
            self.dismiss(animated: false, completion: {
                callback()
                self.tonConnectClosed?()
            })
        }
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(
            tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        } else {
            self.finish(.cancelled, animated: false, animateOut: nil)
        }
    }
}
