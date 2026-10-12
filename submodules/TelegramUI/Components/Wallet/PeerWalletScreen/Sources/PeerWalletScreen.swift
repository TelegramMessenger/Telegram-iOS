import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import ButtonComponent
import WalletContext
import WalletCardComponent

private final class PeerWalletContentComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer
    let balance: Int64?
    let address: String?
    let fiatCurrency: WalletContext.FiatCurrency
    let fiatRate: WalletContext.FiatRate?
    let sendMoney: () -> Void
    let openQr: () -> Void

    init(context: AccountContext, peer: EnginePeer, balance: Int64?, address: String?, fiatCurrency: WalletContext.FiatCurrency, fiatRate: WalletContext.FiatRate?, sendMoney: @escaping () -> Void, openQr: @escaping () -> Void) {
        self.context = context
        self.peer = peer
        self.balance = balance
        self.address = address
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.sendMoney = sendMoney
        self.openQr = openQr
    }

    static func ==(lhs: PeerWalletContentComponent, rhs: PeerWalletContentComponent) -> Bool {
        return lhs.context === rhs.context && lhs.peer == rhs.peer && lhs.balance == rhs.balance && lhs.address == rhs.address && lhs.fiatCurrency == rhs.fiatCurrency && lhs.fiatRate == rhs.fiatRate
    }

    static var body: Body {
        let handle = Child(RoundedRectangle.self)
        let card = Child(WalletCardComponent.self)
        let sendButton = Child(ButtonComponent.self)

        return { context in
            let component = context.component
            let environment = context.environment[EnvironmentType.self].value
            let contentWidth = max(1.0, context.availableSize.width - environment.safeInsets.left - environment.safeInsets.right)
            let centerX = environment.safeInsets.left + contentWidth * 0.5
            let handle = handle.update(
                component: RoundedRectangle(color: environment.theme.list.itemSecondaryTextColor.withMultipliedAlpha(0.3), cornerRadius: 2.5),
                availableSize: CGSize(width: 36.0, height: 5.0),
                transition: context.transition
            )
            context.add(handle.position(CGPoint(x: centerX, y: 7.5)))

            var contentHeight: CGFloat = 16.0
            let card = card.update(
                component: WalletCardComponent(
                    theme: environment.theme,
                    balance: component.balance,
                    fiatCurrency: component.fiatCurrency,
                    fiatRate: component.fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    name: component.peer.debugDisplayTitle.uppercased(),
                    address: component.address ?? "",
                    isVisible: environment.isVisible,
                    cardPressed: component.openQr,
                    qrPressed: component.openQr
                ),
                availableSize: CGSize(width: max(1.0, contentWidth - 32.0), height: context.availableSize.height),
                transition: context.transition
            )
            context.add(card.position(CGPoint(x: centerX, y: contentHeight + card.size.height * 0.5)))
            contentHeight += card.size.height + 24.0

            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let sendButton = sendButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(id: "send", component: AnyComponent(Text(
                        text: environment.strings.Wallet_SendMoney,
                        font: Font.semibold(17.0),
                        color: environment.theme.list.itemCheckColors.foregroundColor
                    ))),
                    isEnabled: component.context.walletContext != nil,
                    action: component.sendMoney
                ),
                availableSize: CGSize(width: max(1.0, contentWidth - buttonInsets.left - buttonInsets.right), height: 52.0),
                transition: context.transition
            )
            context.add(sendButton.position(CGPoint(x: centerX, y: contentHeight + sendButton.size.height * 0.5)))
            contentHeight += sendButton.size.height + buttonInsets.bottom
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class PeerWalletSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer
    let balance: Int64?
    let sendMoney: (PeerWalletScreen) -> Void

    init(context: AccountContext, peer: EnginePeer, balance: Int64?, sendMoney: @escaping (PeerWalletScreen) -> Void) {
        self.context = context
        self.peer = peer
        self.balance = balance
        self.sendMoney = sendMoney
    }

    static func ==(lhs: PeerWalletSheetComponent, rhs: PeerWalletSheetComponent) -> Bool {
        return lhs.context === rhs.context && lhs.peer == rhs.peer && lhs.balance == rhs.balance
    }

    final class State: ComponentState {
        var peer: EnginePeer
        var balance: Int64?
        var address: String?
        var fiatCurrency: WalletContext.FiatCurrency = .usd
        var fiatRate: WalletContext.FiatRate?
        private let disposables = DisposableSet()

        init(context: AccountContext, peer: EnginePeer, balance: Int64?) {
            self.peer = peer
            self.balance = balance
            super.init()

            self.disposables.add((context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id),
                TelegramEngine.EngineData.Item.Peer.CachedData(id: peer.id)
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer, cachedData in
                guard let self else { return }
                if let peer {
                    self.peer = peer
                }
                if let cachedData = cachedData as? CachedUserData {
                    self.balance = cachedData.gramBalance
                }
                self.updated(transition: .immediate)
            }))
            self.disposables.add((context.engine.wallet.getUserAddresses(userIds: [peer.id], force: false)
            |> deliverOnMainQueue).start(next: { [weak self] addresses in
                guard let self else { return }
                self.address = addresses.first(where: { $0.userId == peer.id })?.address
                self.updated(transition: .immediate)
            }))
            if let walletContext = context.walletContext {
                self.disposables.add((walletContext.state
                |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                    guard let self else { return }
                    if self.fiatCurrency != state.fiat.selectedCurrency || self.fiatRate != state.fiat.selectedRate {
                        self.fiatCurrency = state.fiat.selectedCurrency
                        self.fiatRate = state.fiat.selectedRate
                        self.updated(transition: .immediate)
                    }
                }))
            }
        }

        deinit {
            self.disposables.dispose()
        }
    }

    func makeState() -> State {
        return State(context: self.context, peer: self.peer, balance: self.balance)
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
                    content: AnyComponent(PeerWalletContentComponent(
                        context: component.context,
                        peer: state.peer,
                        balance: state.balance,
                        address: state.address,
                        fiatCurrency: state.fiatCurrency,
                        fiatRate: state.fiatRate,
                        sendMoney: {
                            guard let controller = controller() as? PeerWalletScreen else { return }
                            component.sendMoney(controller)
                        },
                        openQr: { [weak state] in
                            guard let address = state?.address, !address.isEmpty, let controller = controller() else { return }
                            controller.push(component.context.sharedContext.makeWalletReceiveScreen(context: component.context, address: address, isOwnWallet: false))
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: externalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            (controller() as? PeerWalletScreen)?.finish(animated: animated, animateOut: animateOut)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheet.position(CGPoint(x: context.availableSize.width * 0.5, y: context.availableSize.height * 0.5)))
            if let controller = controller() {
                var sideInset: CGFloat = 0.0
                var bottomInset = max(environment.safeInsets.bottom, externalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) * 0.5) - 12.0
                    bottomInset = (context.availableSize.height + externalState.contentHeight) * 0.5
                }
                controller.presentationContext.containerLayoutUpdated(ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    reservedCorners: environment.reservedCorners,
                    division: nil,
                    additionalInsets: .zero,
                    statusBarHeight: environment.fullStatusBarHeight,
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

public final class PeerWalletScreen: ViewControllerComponentContainer {
    private var isFinishing = false

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: EnginePeer, balance: Int64?, sendMoney: @escaping (PeerWalletScreen) -> Void) {
        super.init(
            context: context,
            component: PeerWalletSheetComponent(context: context, peer: peer, balance: balance, sendMoney: sendMoney),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    public func openSendMoney(_ controller: ViewController) {
        guard !self.isFinishing, let navigationController = self.navigationController as? NavigationController else { return }
        self.isFinishing = true
        if let sheetView = self.node.hostView.findTaggedView(
            tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            sheetView.setDimHidden(true, animated: true)
        }
        navigationController.pushViewController(controller, animated: true, completion: { [weak self, weak navigationController] in
            guard let self, let navigationController else { return }
            navigationController.setViewControllers(navigationController.viewControllers.filter { $0 !== self }, animated: false)
        })
    }

    fileprivate func finish(animated: Bool, animateOut: ActionSlot<Action<Void>>, completion: (() -> Void)? = nil) {
        guard !self.isFinishing else { return }
        self.isFinishing = true
        let dismiss: () -> Void = { [weak self] in
            guard let self else { return }
            if let navigationController = self.navigationController as? NavigationController {
                navigationController.setViewControllers(navigationController.viewControllers.filter { $0 !== self }, animated: false, completion: completion ?? {})
            } else {
                self.dismiss(completion: completion)
            }
        }
        if animated {
            animateOut.invoke(Action { _ in dismiss() })
        } else {
            dismiss()
        }
    }
}
