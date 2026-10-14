import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit
import ComponentFlow
import ViewControllerComponent
import ButtonComponent
import WalletContext
import WalletCardComponent
import WalletGiftStickerMediaComponent

private final class PeerWalletTransitionSource {
    weak var view: UIView?
    weak var window: UIWindow?
    let frame: CGRect
    let snapshot: UIView?

    init?(view: UIView?) {
        guard let view, let window = view.window else { return nil }
        self.view = view
        self.window = window
        self.frame = view.convert(view.bounds, to: window)
        self.snapshot = view.snapshotView(afterScreenUpdates: false)
    }
}

private final class PeerWalletOverlayComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer
    let card: WalletCard?
    let sourceBackgroundColor: UIColor?
    let sendMoney: (PeerWalletScreen) -> Void

    init(context: AccountContext, peer: EnginePeer, card: WalletCard?, sourceBackgroundColor: UIColor?, sendMoney: @escaping (PeerWalletScreen) -> Void) {
        self.context = context
        self.peer = peer
        self.card = card
        self.sourceBackgroundColor = sourceBackgroundColor
        self.sendMoney = sendMoney
    }

    static func ==(lhs: PeerWalletOverlayComponent, rhs: PeerWalletOverlayComponent) -> Bool {
        return lhs.context === rhs.context && lhs.peer == rhs.peer && lhs.card == rhs.card && lhs.sourceBackgroundColor == rhs.sourceBackgroundColor
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
            self.stickers = (card?.stickers ?? []).compactMap {
                WalletContext.CardSticker(serverSticker: $0, backgroundNftAddress: card?.backgroundNft?.address)
            }
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

    final class View: UIView, UIGestureRecognizerDelegate {
        private let blurView = UIVisualEffectView()
        private var blurIsLight: Bool?
        private var blurAnimator: UIViewPropertyAnimator?
        private var backgroundProgress: CGFloat = 0.0
        private var defaultButtonTheme: PresentationTheme?
        private var walletAccentColor: (theme: PresentationTheme, color: UIColor)?
        private let dimView = UIControl()
        private let cardContainer = UIView()
        private let cardMask = CAShapeLayer()
        private let slotView = UIView()
        private var shutterView: UIView?
        private weak var sourceView: UIView?
        private var initialSource: PeerWalletTransitionSource?
        private var pendingAnimateIn = false
        private var sourceWasHidden = false
        private var sourceFrame: CGRect?
        private var cardFrame = CGRect.zero
        private var buttonFrame = CGRect.zero
        private var animationSize = CGSize.zero
        private var animator: DisplayLinkAnimator?
        private var progress: CGFloat = 0.0
        private var usesFlight = false
        private var backgroundHidden = false
        private var isDismissing = false
        private let card = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private var dismissAction: (() -> Void)?
        private weak var state: State?
        private let stickerPlayback = WalletGiftStickerPlayback()
        private var stickerIntroDeadline: Double?
        private var stickerIntroPlayed = Set<String>()
        private let stickerTap = UITapGestureRecognizer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.stickerTap.addTarget(self, action: #selector(self.stickerTapped(_:)))
            self.stickerTap.delegate = self
            self.stickerPlayback.updated = { [weak self] frames in
                guard let self, let card = self.card.view as? WalletCardComponent.View else { return }
                let stickers = self.state?.stickers ?? []
                card.setStickerLive(frames.reduce(into: [:]) { result, item in
                    guard let sticker = stickers.first(where: { $0.gift.address == item.key }) else { return }
                    result[item.key] = WalletCardComponent.View.StickerLive(angle: CGFloat(sticker.angle), press: 0, grow: item.value.grow, image: item.value.image)
                })
            }
            self.slotView.isUserInteractionEnabled = false
            self.slotView.alpha = 0.0
            self.addSubview(self.slotView)
            self.blurView.isUserInteractionEnabled = false
            self.addSubview(self.blurView)
            self.dimView.addTarget(self, action: #selector(self.dimPressed), for: .touchUpInside)
            self.addSubview(self.dimView)
            self.addSubview(self.cardContainer)
            self.cardMask.fillColor = UIColor.black.cgColor
            self.alpha = 0.0
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func dimPressed() {
            self.dismissAction?()
        }

        private func tappedSticker(_ recognizer: UIGestureRecognizer) -> WalletContext.CardSticker? {
            guard let card = self.card.view as? WalletCardComponent.View else { return nil }
            return card.sticker(at: recognizer.location(in: card.stickerSurface))
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === self.stickerTap { return self.tappedSticker(gestureRecognizer) != nil }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        @objc private func stickerTapped(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let sticker = self.tappedSticker(recognizer),
                  let media = self.state?.stickerMedia[sticker.gift.address] else { return }
            self.stickerIntroDeadline = 0
            self.stickerPlayback.play(sticker.gift.address, media: media, enlarge: true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        private func playStickerIntro(state: State) {
            guard let deadline = self.stickerIntroDeadline, CACurrentMediaTime() < deadline else { return }
            for sticker in state.stickers {
                let id = sticker.gift.address
                guard !self.stickerIntroPlayed.contains(id), let media = state.stickerMedia[id], media.first != nil else { continue }
                self.stickerIntroPlayed.insert(id)
                self.stickerPlayback.play(id, media: media, enlarge: false)
            }
        }

        deinit {
            self.blurAnimator?.stopAnimation(true)
            self.animator?.invalidate()
            self.restoreSource()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil {
                self.animator?.invalidate()
                self.animator = nil
                self.restoreSource()
            } else {
                self.beginPendingAnimation()
            }
        }

        private func restoreSource() {
            if self.shutterView != nil {
                self.sourceView?.isHidden = self.sourceWasHidden
            }
            self.shutterView?.removeFromSuperview()
            self.shutterView = nil
            self.slotView.alpha = 0.0
        }

        private func prepareShutter(initialSource: PeerWalletTransitionSource? = nil) -> Bool {
            let frame: CGRect
            let snapshot: UIView?
            if let initialSource, let window = initialSource.window {
                frame = self.convert(initialSource.frame, from: window)
                snapshot = initialSource.snapshot
            } else {
                guard let source = self.sourceView, source.window != nil, self.window != nil,
                      !source.isHidden || self.shutterView != nil, source.alpha > 0.01 else { return false }
                frame = source.convert(source.bounds, to: self)
                snapshot = self.shutterView == nil ? source.snapshotView(afterScreenUpdates: false) : nil
            }
            guard !frame.isEmpty, self.bounds.intersects(frame) else { return false }
            if self.shutterView == nil, let snapshot {
                self.sourceWasHidden = self.sourceView?.isHidden ?? false
                snapshot.isUserInteractionEnabled = false
                snapshot.bounds = CGRect(origin: .zero, size: frame.size)
                snapshot.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
                snapshot.layer.position = CGPoint(x: frame.midX, y: frame.minY)
                self.addSubview(snapshot)
                self.shutterView = snapshot
            }
            guard let shutterView = self.shutterView else { return false }
            shutterView.bounds = CGRect(origin: .zero, size: frame.size)
            shutterView.layer.position = CGPoint(x: frame.midX, y: frame.minY)
            self.sourceView?.isHidden = true
            self.sourceFrame = frame
            self.slotView.frame = frame
            self.slotView.layer.cornerRadius = frame.height * 0.5
            return true
        }

        private func applyProgress() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            let p = max(0.0, min(1.0, self.progress))
            let motion = !UIAccessibility.isReduceMotionEnabled
            let dismissing = self.isDismissing
            let backgroundAlpha = self.backgroundHidden ? 0.0 : self.backgroundProgress
            self.blurView.alpha = backgroundAlpha
            self.dimView.alpha = backgroundAlpha
            guard let card = self.card.view as? WalletCardComponent.View else { return }
            var transform = CATransform3DIdentity
            var center = self.cardFrame.center
            self.cardContainer.alpha = 1.0
            func smooth(_ value: CGFloat) -> CGFloat {
                let value = max(0.0, min(1.0, value))
                return value * value * (3.0 - 2.0 * value)
            }
            let impact: CGFloat = dismissing ? 1.0 : 0.5
            let ringRate: CGFloat = 14.0
            let ringDamping: CGFloat = 6.0
            let tail = 1.0 - smooth((p - 0.88) / 0.12)
            func flight(_ time: CGFloat, start: CGFloat, arrival: CGFloat, lag: CGFloat = 1.0, hold: CGFloat = 0.0) -> CGFloat {
                let arrival = dismissing ? 0.0 : arrival
                let hold = hold * impact
                if time < impact {
                    let t = pow(max(0.0, time - hold) / (impact - hold), lag)
                    return (t * t * t - 2 * t * t + t) * start + (-2 * t * t * t + 3 * t * t) + (t * t * t - t * t) * arrival
                }
                let elapsed = time - impact
                return 1.0 + arrival * lag / ((impact - hold) * ringRate) * exp(-ringDamping * elapsed) * sin(ringRate * elapsed) * tail
            }
            if motion, self.usesFlight, let source = self.sourceFrame {
                let halfWidth = self.cardFrame.width * 0.5
                let halfHeight = self.cardFrame.height * 0.5
                let corners = [CGPoint(x: -halfWidth, y: -halfHeight), CGPoint(x: halfWidth, y: -halfHeight), CGPoint(x: halfWidth, y: halfHeight), CGPoint(x: -halfWidth, y: halfHeight)]
                let cameraDistance = max(280.0, self.cardFrame.width * 1.2)
                func pose(pitch: CGFloat, yaw: CGFloat, roll: CGFloat, scale: CGFloat, camera: CGFloat) -> CATransform3D {
                    var transform = CATransform3DIdentity
                    transform.m34 = -tail / camera
                    transform = CATransform3DRotate(transform, pitch, 1.0, 0.0, 0.0)
                    transform = CATransform3DRotate(transform, yaw, 0.0, 1.0, 0.0)
                    transform = CATransform3DRotate(transform, roll, 0.0, 0.0, 1.0)
                    return CATransform3DScale(transform, scale, scale, 1.0)
                }
                func project(_ transform: CATransform3D) -> [CGPoint] {
                    return corners.map { point -> CGPoint in
                        let w = max(0.001, point.x * transform.m14 + point.y * transform.m24 + transform.m44)
                        return CGPoint(x: (point.x * transform.m11 + point.y * transform.m21 + transform.m41) / w,
                            y: (point.x * transform.m12 + point.y * transform.m22 + transform.m42) / w)
                    }
                }

                let slotPitch: CGFloat = 50.0 * .pi / 180
                let slotScale = min(1.0, source.width / max(1.0, self.cardFrame.height))
                let slotReach = project(pose(pitch: slotPitch, yaw: 0.0, roll: -.pi / 2, scale: slotScale, camera: cameraDistance)).map { abs($0.x) }.max() ?? halfHeight
                let startScale = slotScale * min(1.0, source.width * 0.45 / max(1.0, slotReach))

                let travel = flight(p, start: 1.2, arrival: 0.16, hold: 0.1)
                let twist = smooth((p / impact - 0.4) / 0.3)
                let velocity = (flight(p + 0.004, start: 1.2, arrival: 0.16, hold: 0.1) - flight(p - 0.004, start: 1.2, arrival: 0.16, hold: 0.1)) / 0.008 * impact / 1.5 * twist
                let pitch = slotPitch * (1.0 - flight(p, start: 0.0, arrival: 0.16, hold: 0.38))
                let roll = -(1.0 - flight(p, start: 0.0, arrival: 0.18, hold: 0.4)) * .pi / 2
                let yaw = velocity * 9.0 * .pi / 180
                let scale = startScale + (1.0 - startScale) * flight(p, start: 0.0, arrival: 0.13, hold: 0.4)
                transform = pose(pitch: pitch, yaw: yaw, roll: roll, scale: scale, camera: cameraDistance)

                let projected = project(transform)
                let slotLine = source.midY
                let slidesDown = self.cardFrame.midY >= slotLine
                let hiddenEdge = slidesDown ? (projected.map { $0.y }.max() ?? halfHeight) : (projected.map { $0.y }.min() ?? -halfHeight)
                let reach = WalletCardComponent.View.projectionReach - 4.0
                let fit = projected.reduce(CGFloat(1.0)) { min($0, (halfWidth + reach) / max(1.0, abs($1.x)), (halfHeight + reach) / max(1.0, abs($1.y))) }
                if fit < 1.0 {
                    transform = pose(pitch: pitch, yaw: yaw, roll: roll, scale: scale * fit, camera: cameraDistance * fit)
                }
                self.cardContainer.layer.transform = CATransform3DMakeScale(1.0 / fit, 1.0 / fit, 1.0)

                let sideways = self.cardFrame.width * 0.055 * velocity
                let startY = slotLine - hiddenEdge
                center = CGPoint(x: source.midX + (self.cardFrame.midX - source.midX) * travel + sideways,
                    y: startY + (self.cardFrame.midY - startY) * travel)
                self.cardContainer.center = center
                self.cardContainer.alpha = smooth(p / 0.045)
                self.cardMask.frame = self.cardContainer.bounds
                let edge = halfHeight + (slotLine - center.y) * fit
                let span = max(self.animationSize.width, self.animationSize.height) * 3.0
                self.cardMask.path = CGPath(rect: CGRect(x: -span, y: slidesDown ? edge : edge - span, width: span * 2.0 + self.cardFrame.width, height: span), transform: nil)
                self.cardContainer.layer.mask = p < (dismissing ? 0.75 : impact) ? self.cardMask : nil

                let shutterLift = smooth(p / (dismissing ? 0.42 : 0.16))
                self.shutterView?.layer.transform = CATransform3DMakeScale(1.0, 1.0 - shutterLift * 0.5, 1.0)
                self.shutterView?.alpha = 1.0 - smooth((p - (dismissing ? 0.08 : 0.03)) / (dismissing ? 0.45 : 0.17))
                self.shutterView?.isHidden = false
                self.slotView.alpha = shutterLift
            } else {
                self.cardContainer.layer.mask = nil
                self.cardContainer.layer.transform = CATransform3DIdentity
                self.cardContainer.center = center
                self.cardContainer.alpha = p
            }
            card.isUserInteractionEnabled = p >= (self.usesFlight ? 0.6 : 1.0)
            card.updateScrollTransform(transform)
            if let button = self.sendButton.view {
                let buttonProgress = self.usesFlight ? flight(p - (dismissing ? 0.0 : 0.06), start: 2.4, arrival: 0.25) : 1.0 - pow(1.0 - min(1.0, p / 0.77), 3.0)
                button.center = CGPoint(x: self.buttonFrame.midX, y: self.buttonFrame.midY + (motion ? (self.animationSize.height - self.buttonFrame.minY + 8.0) * (1.0 - buttonProgress) : 0.0))
                button.alpha = motion ? 1.0 : p
            }
        }

        private func animate(to target: CGFloat, duration: Double, completion: @escaping () -> Void) {
            self.animator?.invalidate()
            let from = self.progress
            let initialBackground = self.backgroundProgress
            self.animator = DisplayLinkAnimator(duration: duration, from: from, to: target, update: { [weak self] value in
                guard let self else { return }
                self.progress = value
                let elapsed = abs(value - from) / max(0.0001, abs(target - from)) * CGFloat(duration)
                let backgroundFraction = min(1.0, elapsed / (target == 0.0 ? min(0.32, CGFloat(duration)) : 0.25))
                self.backgroundProgress = initialBackground + (target - initialBackground) * backgroundFraction
                self.applyProgress()
            }, completion: { [weak self] in
                guard let self else { return }
                self.animator = nil
                if target == 0.0 {
                    self.restoreSource()
                }
                completion()
            })
        }

        func setDimHidden() {
            self.animator?.invalidate()
            self.animator = nil
            self.restoreSource()
            let backgroundAlpha = self.blurView.alpha
            self.backgroundHidden = true
            self.blurView.alpha = 0.0
            self.blurView.layer.animateAlpha(from: backgroundAlpha, to: 0.0, duration: 0.15)
            self.dimView.alpha = 0.0
            self.dimView.layer.animateAlpha(from: backgroundAlpha, to: 0.0, duration: 0.15)
        }

        func animateIn(source: PeerWalletTransitionSource?) {
            self.sourceView = source?.view
            self.initialSource = source
            self.pendingAnimateIn = true
            self.beginPendingAnimation()
        }

        private func beginPendingAnimation() {
            guard self.pendingAnimateIn, self.window != nil, !self.bounds.isEmpty, !self.cardFrame.isEmpty else { return }
            self.pendingAnimateIn = false
            self.usesFlight = !UIAccessibility.isReduceMotionEnabled && self.prepareShutter(initialSource: self.initialSource)
            self.initialSource = nil
            self.applyProgress()
            self.alpha = 1.0
            self.isDismissing = false
            self.animate(to: 1.0, duration: UIAccessibility.isReduceMotionEnabled ? 0.25 : (self.usesFlight ? 1.05 : 0.65), completion: { [weak self] in
                guard let self, self.stickerIntroDeadline == nil else { return }
                self.stickerIntroDeadline = CACurrentMediaTime() + 4
                if let state = self.state { self.playStickerIntro(state: state) }
            })
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            self.beginPendingAnimation()
        }

        func animateOut(completion: @escaping () -> Void) {
            self.pendingAnimateIn = false
            self.initialSource = nil
            self.isUserInteractionEnabled = false
            if !UIAccessibility.isReduceMotionEnabled && self.prepareShutter() {
                self.usesFlight = true
                self.isDismissing = self.progress >= 1.0
                self.applyProgress()
                self.animate(to: 0.0, duration: max(0.08, 0.4 * Double(self.progress)), completion: completion)
            } else {
                // Preserve the current pose if the source disappeared during the flight.
                self.animator?.invalidate()
                self.animator = nil
                self.restoreSource()
                if !UIAccessibility.isReduceMotionEnabled, let button = self.sendButton.view {
                    button.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: self.animationSize.height - button.frame.minY + 8.0), duration: 0.15, removeOnCompletion: false, additive: true)
                }
                self.alpha = 0.0
                self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in completion() })
            }
        }

        func update(component: PeerWalletOverlayComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let controller = environment.controller
            self.dismissAction = {
                (controller() as? PeerWalletScreen)?.finish(animated: true)
            }
            let blurIsLight = environment.theme.rootController.keyboardColor == .light
            if self.blurIsLight != blurIsLight {
                self.blurIsLight = blurIsLight
                self.blurAnimator?.stopAnimation(true)
                self.blurView.effect = nil
                let effect = makeCustomZoomBlurEffect(isLight: blurIsLight)
                let blurAnimator = UIViewPropertyAnimator(duration: 1.0, curve: .linear, animations: { [weak blurView = self.blurView] in
                    blurView?.effect = effect
                })
                blurAnimator.startAnimation()
                blurAnimator.pauseAnimation()
                blurAnimator.fractionComplete = 2.0 / 3.0
                self.blurAnimator = blurAnimator
            }
            self.slotView.backgroundColor = component.sourceBackgroundColor?.mixedWith(.black, alpha: 0.3) ?? environment.theme.list.blocksBackgroundColor
            self.dimView.backgroundColor = environment.theme.contextMenu.dimColor
            transition.setFrame(view: self.blurView, frame: CGRect(origin: .zero, size: availableSize))
            transition.setFrame(view: self.dimView, frame: CGRect(origin: .zero, size: availableSize))
            let openQr: () -> Void = { [weak state] in
                guard let address = state?.address, !address.isEmpty, let controller = controller() else { return }
                controller.push(component.context.sharedContext.makeWalletReceiveScreen(context: component.context, address: address, isOwnWallet: component.peer.id == component.context.account.peerId))
            }
            let contentWidth = max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right)
            let centerX = environment.safeInsets.left + contentWidth * 0.5
            let buttonBottomInset: CGFloat = 30.0
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
                    self.cardContainer.addSubview(cardView)
                }
                self.cardFrame = CGRect(x: centerX - cardSize.width * 0.5, y: cardCenterY - cardSize.height * 0.5, width: cardSize.width, height: cardSize.height)
                self.cardContainer.bounds = CGRect(origin: .zero, size: cardSize)
                transition.setFrame(view: cardView, frame: CGRect(origin: .zero, size: cardSize))
            }

            let defaultButtonTheme: PresentationTheme
            if let current = self.defaultButtonTheme, current.referenceTheme == environment.theme.referenceTheme {
                defaultButtonTheme = current
            } else {
                defaultButtonTheme = makeDefaultPresentationTheme(reference: environment.theme.referenceTheme, serviceBackgroundColor: nil)
                self.defaultButtonTheme = defaultButtonTheme
            }
            var buttonColor = defaultButtonTheme.list.itemCheckColors.fillColor
            var buttonForegroundColor = defaultButtonTheme.list.itemCheckColors.foregroundColor
            if let cardView = self.card.view as? WalletCardComponent.View {
                let walletAccentColor: UIColor
                if let current = self.walletAccentColor, current.theme === environment.theme {
                    walletAccentColor = current.color
                } else {
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: environment.theme)
                    walletAccentColor = presentationDataWithDefaultAccent((initial: presentationData, signal: .never())).initial.theme.list.itemCheckColors.fillColor
                    self.walletAccentColor = (environment.theme, walletAccentColor)
                }
                cardView.giftButtonDefaultColor = walletAccentColor
                // Reuse the card's color mapping, as in WalletScreen. setGiftStyle
                // resolves the destination color synchronously for this static style.
                let styled = state.stickers.contains(where: { $0.style != nil })
                cardView.giftStyleUpdated = { _, to, _, _, _, _ in
                    if styled {
                        buttonColor = to
                        buttonForegroundColor = .white
                    }
                }
                cardView.setCardStickers(state.stickers, images: state.stickerMedia.compactMapValues { $0.first?.image }, hidden: [])
                self.state = state
                if self.stickerTap.view !== cardView { cardView.addGestureRecognizer(self.stickerTap) }
                self.playStickerIntro(state: state)
                let source = state.stickers.last(where: { $0.style != nil })
                cardView.setGiftStyle(from: source?.style, to: source?.style, origin: .zero, progress: 1,
                    pattern: source.flatMap { state.stickerMedia[$0.gift.address]?.patternImage })
                cardView.giftStyleUpdated = nil
            }

            let buttonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: buttonColor,
                        foreground: buttonForegroundColor,
                        pressedColor: buttonColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(id: "send", component: AnyComponent(Text(
                        text: component.peer.id == component.context.account.peerId ? environment.strings.Wallet_Transaction_OpenWallet : environment.strings.Wallet_SendMoney,
                        font: Font.semibold(17.0),
                        color: buttonForegroundColor
                    ))),
                    isEnabled: component.peer.id == component.context.account.peerId || (component.context.walletContext != nil && state.card != nil),
                    action: {
                        guard let controller = controller() as? PeerWalletScreen else { return }
                        component.sendMoney(controller)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - 60.0), height: 52.0)
            )
            if let buttonView = self.sendButton.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                self.buttonFrame = CGRect(x: 30.0, y: buttonTop, width: buttonSize.width, height: buttonSize.height)
                transition.setFrame(view: buttonView, frame: self.buttonFrame)
            }
            self.animationSize = availableSize
            self.applyProgress()
            self.beginPendingAnimation()
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
    private var transitionSource: PeerWalletTransitionSource?

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: EnginePeer, card: WalletCard?, sourceView: UIView? = nil, sourceBackgroundColor: UIColor? = nil, sendMoney: @escaping (PeerWalletScreen) -> Void) {
        self.transitionSource = PeerWalletTransitionSource(view: sourceView)
        super.init(
            context: context,
            component: PeerWalletOverlayComponent(context: context, peer: peer, card: card, sourceBackgroundColor: sourceBackgroundColor, sendMoney: sendMoney),
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
        if !self.didAnimateIn, let componentView = self.node.hostView.componentView as? PeerWalletOverlayComponent.View {
            self.didAnimateIn = true
            componentView.animateIn(source: self.transitionSource)
            self.transitionSource = nil
        }
    }

    public func openScreen(_ controller: ViewController) {
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
