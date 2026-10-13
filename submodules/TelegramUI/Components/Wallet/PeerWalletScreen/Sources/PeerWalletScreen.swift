import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit
import ComponentFlow
import ViewControllerComponent
import ButtonComponent
import WalletContext
import WalletCardComponent
import WalletGiftStickerMediaComponent

private final class PeerWalletOverlayComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer
    let card: WalletCard?
    let sendMoney: (PeerWalletScreen) -> Void

    init(context: AccountContext, peer: EnginePeer, card: WalletCard?, sendMoney: @escaping (PeerWalletScreen) -> Void) {
        self.context = context
        self.peer = peer
        self.card = card
        self.sendMoney = sendMoney
    }

    static func ==(lhs: PeerWalletOverlayComponent, rhs: PeerWalletOverlayComponent) -> Bool {
        return lhs.context === rhs.context && lhs.peer == rhs.peer && lhs.card == rhs.card
    }

    final class State: ComponentState {
        var peer: EnginePeer
        private(set) var card: WalletCard?
        var balance: Int64? { self.card?.balance }
        var address: String? { self.card?.address }
        var stickers: [WalletContext.CardSticker] = []
        var stickerMedia: [String: WalletGiftStickerMedia] = [:]
        var fiatCurrency: WalletContext.FiatCurrency = .usd
        var fiatRate: WalletContext.FiatRate?
        private let disposables = DisposableSet()

        init(context: AccountContext, peer: EnginePeer, card: WalletCard?) {
            self.peer = peer
            self.card = nil
            super.init()
            self.updateCard(card, context: context)

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
                    self.updateCard(cachedData.walletCard, context: context)
                }
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

        private func updateCard(_ card: WalletCard?, context: AccountContext) {
            guard self.card != card else { return }
            let previous = self.card
            self.card = card
            self.stickers = (card?.stickers ?? []).compactMap(WalletContext.CardSticker.init(serverSticker:))
            let ids = Set(self.stickers.map { $0.gift.address })
            for id in Array(self.stickerMedia.keys) where !ids.contains(id) { self.stickerMedia.removeValue(forKey: id) }
            for sticker in self.stickers {
                let id = sticker.gift.address
                let unchanged = previous?.stickers.contains(where: { $0.nft == sticker.gift.nft }) == true
                if self.stickerMedia[id] != nil && unchanged { continue }
                let media = WalletGiftStickerMedia(context: context, gift: sticker.gift, modelFile: sticker.modelFile,
                    style: sticker.giftStyle)
                self.stickerMedia[id] = media
                media.updated = { [weak self, weak media] in
                    guard let self, self.stickerMedia[id] === media else { return }
                    self.updated(transition: .immediate)
                }
            }
        }

        deinit {
            self.disposables.dispose()
        }
    }

    func makeState() -> State {
        return State(context: self.context, peer: self.peer, card: self.card)
    }

    final class View: UIView {
        private let dimView = UIControl()
        private let card = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private var dismissAction: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
            self.dimView.addTarget(self, action: #selector(self.dimPressed), for: .touchUpInside)
            self.addSubview(self.dimView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func dimPressed() {
            self.dismissAction?()
        }

        func setDimHidden() {
            self.dimView.alpha = 0.0
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
        }

        func animateIn(sourceView: UIView?) {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            guard !UIAccessibility.isReduceMotionEnabled else {
                self.card.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                self.sendButton.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                return
            }
            if let card = self.card.view, let parent = card.superview {
                if let sourceView, sourceView.window === self.window, self.window != nil {
                    let sourceRect = sourceView.convert(sourceView.bounds, to: parent)
                    let sourceCenter = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
                    let scale = max(0.05, min(1.0, min(sourceRect.width / max(1.0, card.bounds.width), sourceRect.height / max(1.0, card.bounds.height))))
                    card.layer.animateSpring(from: NSValue(cgPoint: sourceCenter), to: NSValue(cgPoint: card.center), keyPath: "position", duration: 0.65, damping: 65.0)
                    card.layer.animateSpring(from: scale, to: 1.0, keyPath: "transform.scale", duration: 0.65, damping: 65.0)
                } else {
                    card.layer.animateSpring(from: 0.85, to: 1.0, keyPath: "transform.scale", duration: 0.65, damping: 65.0)
                }
                card.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            }
            if let button = self.sendButton.view, let parent = button.superview {
                let bottom = self.convert(CGPoint(x: 0.0, y: self.bounds.maxY), to: parent).y
                button.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: bottom - button.frame.minY + 8.0)), to: NSValue(cgPoint: .zero), keyPath: "position", duration: 0.5, damping: 85.0, additive: true)
            }
        }

        func animateOut(completion: @escaping () -> Void) {
            self.isUserInteractionEnabled = false
            guard !UIAccessibility.isReduceMotionEnabled, let button = self.sendButton.view, let parent = button.superview else {
                self.alpha = 0.0
                self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in completion() })
                return
            }
            self.dimView.alpha = 0.0
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
            if let card = self.card.view {
                card.alpha = 0.0
                card.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            }
            let bottom = self.convert(CGPoint(x: 0.0, y: self.bounds.maxY), to: parent).y
            button.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: bottom - button.frame.minY + 8.0), duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false, additive: true, completion: { _ in completion() })
        }

        func update(component: PeerWalletOverlayComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let controller = environment.controller
            self.dismissAction = {
                (controller() as? PeerWalletScreen)?.finish(animated: true)
            }
            transition.setFrame(view: self.dimView, frame: CGRect(origin: .zero, size: availableSize))
            let openQr: () -> Void = { [weak state] in
                guard let address = state?.address, !address.isEmpty, let controller = controller() else { return }
                controller.push(component.context.sharedContext.makeWalletReceiveScreen(context: component.context, address: address, isOwnWallet: false))
            }
            let contentWidth = max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right)
            let centerX = environment.safeInsets.left + contentWidth * 0.5
            let buttonBottomInset = max(16.0, environment.safeInsets.bottom)
            let buttonTop = availableSize.height - buttonBottomInset - 52.0
            let cardTopLimit = max(environment.safeInsets.top, environment.statusBarHeight) + 16.0
            let cardHeightLimit = max(1.0, buttonTop - 24.0 - cardTopLimit)
            let cardWidth = min(430.0, max(1.0, contentWidth - 44.0), cardHeightLimit * 370.0 / 220.0)
            let cardSize = self.card.update(
                transition: transition,
                component: AnyComponent(WalletCardComponent(
                    theme: environment.theme,
                    balance: state.balance,
                    fiatCurrency: state.fiatCurrency,
                    fiatRate: state.fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    name: state.peer.debugDisplayTitle.uppercased(),
                    address: state.address ?? "",
                    isVisible: environment.isVisible,
                    cardPressed: openQr,
                    qrPressed: openQr
                )),
                environment: {},
                containerSize: CGSize(width: cardWidth, height: cardHeightLimit)
            )
            let cardCenterY = max(cardTopLimit + cardSize.height * 0.5, min(availableSize.height * 0.5, buttonTop - 24.0 - cardSize.height * 0.5))
            if let cardView = self.card.view {
                if cardView.superview == nil {
                    self.addSubview(cardView)
                }
                transition.setFrame(view: cardView, frame: CGRect(x: centerX - cardSize.width * 0.5, y: cardCenterY - cardSize.height * 0.5, width: cardSize.width, height: cardSize.height))
            }

            if let cardView = self.card.view as? WalletCardComponent.View {
                cardView.setCardStickers(state.stickers, images: state.stickerMedia.compactMapValues { $0.first?.image }, hidden: [])
            }

            let buttonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
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
                    isEnabled: component.context.walletContext != nil && state.card != nil,
                    action: {
                        guard let controller = controller() as? PeerWalletScreen else { return }
                        component.sendMoney(controller)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: min(406.0, max(1.0, contentWidth - 72.0)), height: 52.0)
            )
            if let buttonView = self.sendButton.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(x: centerX - buttonSize.width * 0.5, y: buttonTop, width: buttonSize.width, height: buttonSize.height))
            }
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class PeerWalletScreen: ViewControllerComponentContainer {
    private var isFinishing = false
    private var didAnimateIn = false
    private weak var sourceView: UIView?

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: EnginePeer, card: WalletCard?, sourceView: UIView? = nil, sendMoney: @escaping (PeerWalletScreen) -> Void) {
        self.sourceView = sourceView
        super.init(
            context: context,
            component: PeerWalletOverlayComponent(context: context, peer: peer, card: card, sendMoney: sendMoney),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        self.navigationPresentation = .flatModal
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.didAnimateIn {
            self.didAnimateIn = true
            (self.node.hostView.componentView as? PeerWalletOverlayComponent.View)?.animateIn(sourceView: self.sourceView)
        }
    }

    public func openSendMoney(_ controller: ViewController) {
        guard !self.isFinishing, let navigationController = self.navigationController as? NavigationController else { return }
        self.isFinishing = true
        (self.node.hostView.componentView as? PeerWalletOverlayComponent.View)?.setDimHidden()
        navigationController.pushViewController(controller, animated: true, completion: { [weak self, weak navigationController] in
            guard let self, let navigationController else { return }
            navigationController.setViewControllers(navigationController.viewControllers.filter { $0 !== self }, animated: false)
        })
    }

    fileprivate func finish(animated: Bool, completion: (() -> Void)? = nil) {
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
        if animated, let componentView = self.node.hostView.componentView as? PeerWalletOverlayComponent.View {
            componentView.animateOut(completion: dismiss)
        } else {
            dismiss()
        }
    }
}
