import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import PresentationDataUtils
import SwiftSignalKit
import ComponentFlow
import ViewControllerComponent
import ButtonComponent
import BalancedTextComponent
import PlainButtonComponent
import WalletContext
import WalletCardComponent
import WalletGiftStickerMediaComponent

private final class PeerWalletTransitionSource {
    weak var view: UIView?
    weak var window: UIWindow?
    let frame: CGRect

    init?(view: UIView?) {
        guard let view, let window = view.window else { return nil }
        self.view = view
        self.window = window
        self.frame = view.convert(view.bounds, to: window)
    }
}

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
        var hasOwnWallet: Bool
        private let disposables = DisposableSet()

        init(context: AccountContext, peer: EnginePeer, card: WalletCard?) {
            self.peer = peer
            self.card = nil
            self.hasOwnWallet = context.walletContext?.stateValue.walletAddress != nil
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
                    let hasOwnWallet = state.walletAddress != nil
                    if self.fiatCurrency != state.fiat.selectedCurrency || self.fiatRate != state.fiat.selectedRate || self.hasOwnWallet != hasOwnWallet {
                        self.fiatCurrency = state.fiat.selectedCurrency
                        self.fiatRate = state.fiat.selectedRate
                        self.hasOwnWallet = hasOwnWallet
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
        private let noticeContainer = UIView()
        private let notice = ComponentView<Empty>()
        private let cardContainer = UIView()
        private let cardMask = CAGradientLayer()
        private let cardEdgeView = UIView()
        private let cardEdgeMask = CAGradientLayer()
        private weak var sourceLabel: UIView?
        private weak var sourceView: UIView?
        private var initialSource: PeerWalletTransitionSource?
        private var pendingAnimateIn = false
        private var sourceClipped: Bool?
        private var sourceFrame: CGRect?
        private var cardFrame = CGRect.zero
        private var buttonFrame = CGRect.zero
        private var animationSize = CGSize.zero
        private var animator: DisplayLinkAnimator?
        private var progress: CGFloat = 0.0
        private var usesFlight = false
        private var backgroundHidden = false
        private var noticeVisible = false
        private var isDismissing = false
        private let card = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private var dismissAction: (() -> Void)?
        private weak var state: State?
        private let stickerPlayback = WalletGiftStickerPlayback()
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
            self.blurView.isUserInteractionEnabled = false
            self.addSubview(self.blurView)
            self.dimView.addTarget(self, action: #selector(self.dimPressed), for: .touchUpInside)
            self.addSubview(self.dimView)
            self.noticeContainer.isUserInteractionEnabled = false
            self.addSubview(self.noticeContainer)
            self.addSubview(self.cardContainer)
            self.cardContainer.addSubview(self.cardEdgeView)
            self.cardMask.colors = (0 ... 8).map { index -> CGColor in
                let t = CGFloat(index) / 8.0
                return UIColor.black.withAlphaComponent(t * t * (3.0 - 2.0 * t)).cgColor
            }
            self.cardMask.startPoint = CGPoint(x: 0.5, y: 0.0)
            self.cardMask.endPoint = CGPoint(x: 0.5, y: 1.0)
            self.cardEdgeMask.colors = self.cardMask.colors
            self.cardEdgeMask.startPoint = self.cardMask.startPoint
            self.cardEdgeMask.endPoint = self.cardMask.endPoint
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
            self.stickerPlayback.play(sticker.gift.address, media: media, enlarge: true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            self.sourceLabel?.transform = .identity
            self.sourceLabel = nil
            if let sourceClipped = self.sourceClipped {
                self.sourceView?.clipsToBounds = sourceClipped
            }
            self.sourceClipped = nil
        }

        private func prepareShutter(initialSource: PeerWalletTransitionSource? = nil) -> Bool {
            let frame: CGRect
            if let initialSource, let window = initialSource.window {
                frame = self.convert(initialSource.frame, from: window)
            } else {
                guard let source = self.sourceView, source.window != nil, self.window != nil else { return false }
                frame = source.convert(source.bounds, to: self)
            }
            guard !frame.isEmpty, self.bounds.intersects(frame), let source = self.sourceView else { return false }
            if self.sourceClipped == nil {
                self.sourceClipped = source.clipsToBounds
                source.clipsToBounds = true
            }
            self.sourceLabel = (source as? PlainButtonComponent.View)?.contentView
            self.sourceFrame = frame
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

                let slotLine = source.midY
                let slotFeather: CGFloat = 30.0
                let straddlesSlot = self.cardFrame.minY < slotLine
                let sidewaysHold: CGFloat = straddlesSlot && !dismissing ? 0.6 : 0.45
                func cardPose(_ time: CGFloat) -> (pitch: CGFloat, yaw: CGFloat, roll: CGFloat, scale: CGFloat, travel: CGFloat, sideTravel: CGFloat, velocity: CGFloat) {
                    let travel = flight(time, start: 1.2, arrival: 0.16, hold: 0.1)
                    let twist = smooth((time / impact - sidewaysHold + 0.05) / 0.3)
                    let velocity = (flight(time + 0.004, start: 1.2, arrival: 0.16, hold: 0.1) - flight(time - 0.004, start: 1.2, arrival: 0.16, hold: 0.1)) / 0.008 * impact / 1.5 * twist
                    return (
                        pitch: slotPitch * (1.0 - flight(time, start: 0.0, arrival: 0.16, hold: 0.38)),
                        yaw: velocity * 9.0 * .pi / 180,
                        roll: -(1.0 - flight(time, start: 0.0, arrival: 0.18, hold: 0.4)) * .pi / 2,
                        scale: startScale + (1.0 - startScale) * flight(time, start: 0.0, arrival: 0.13, hold: 0.4),
                        travel: travel,
                        sideTravel: flight(time, start: 0.0, arrival: 0.16, hold: sidewaysHold),
                        velocity: velocity
                    )
                }
                func baseCenterY(_ projected: [CGPoint], travel: CGFloat) -> CGFloat {
                    let hiddenEdge = projected.map { $0.y }.max() ?? halfHeight
                    let startY = slotLine - hiddenEdge
                    return startY + (self.cardFrame.midY - startY) * travel
                }

                let peak: CGFloat = dismissing ? 0.42 : 0.6 * impact
                let peakPose = cardPose(peak)
                let peakProjected = project(pose(pitch: peakPose.pitch, yaw: peakPose.yaw, roll: peakPose.roll, scale: peakPose.scale, camera: cameraDistance))
                let peakCenterY = baseCenterY(peakProjected, travel: peakPose.travel)
                let clearance = max(0.0, slotLine + slotFeather + 4.0 - (peakCenterY + (peakProjected.map { $0.y }.min() ?? -halfHeight)))

                let current = cardPose(p)
                let peakTravel = max(0.001, peakPose.travel)
                let dip: CGFloat
                if p < peak {
                    dip = current.travel / peakTravel
                } else {
                    let fallSpan = dismissing ? 1.0 - peak : 0.8 * impact
                    let peakSlope = (cardPose(peak + 0.004).travel - cardPose(peak - 0.004).travel) / 0.008 / peakTravel
                    let t = min(1.0, (p - peak) / fallSpan)
                    dip = (2.0 * t * t * t - 3.0 * t * t + 1.0) + (t * t * t - 2.0 * t * t + t) * peakSlope * fallSpan
                }
                transform = pose(pitch: current.pitch, yaw: current.yaw, roll: current.roll, scale: current.scale, camera: cameraDistance)
                let projected = project(transform)
                let reach = WalletCardComponent.View.projectionReach - 4.0
                let fit = projected.reduce(CGFloat(1.0)) { min($0, (halfWidth + reach) / max(1.0, abs($1.x)), (halfHeight + reach) / max(1.0, abs($1.y))) }
                if fit < 1.0 {
                    transform = pose(pitch: current.pitch, yaw: current.yaw, roll: current.roll, scale: current.scale * fit, camera: cameraDistance * fit)
                }
                self.cardContainer.layer.transform = CATransform3DMakeScale(1.0 / fit, 1.0 / fit, 1.0)

                let sideways = self.cardFrame.width * 0.055 * current.velocity
                center = CGPoint(x: source.midX + (self.cardFrame.midX - source.midX) * current.sideTravel + sideways,
                    y: baseCenterY(projected, travel: current.travel) + clearance * dip)
                self.cardContainer.center = center
                self.cardContainer.alpha = smooth(p / 0.045)
                let edge = halfHeight + (slotLine - center.y) * fit
                let span = max(self.animationSize.width, self.animationSize.height) * 3.0
                self.cardMask.frame = CGRect(x: -span, y: edge, width: span * 2.0 + self.cardFrame.width, height: span)
                self.cardMask.locations = (0 ... 8).map { NSNumber(value: Double(CGFloat($0) / 8.0 * slotFeather * fit / span)) }
                let masksSlot = p < (clearance > 0.0 ? peak : (dismissing ? 0.75 : impact))
                self.cardContainer.layer.mask = masksSlot ? self.cardMask : nil
                let cardTop = projected.map { $0.y }.min() ?? -halfHeight
                let edgeFade = 1.0 - smooth((center.y + cardTop - slotLine) / slotFeather)
                if masksSlot && edgeFade > 0.0 {
                    let edgeStart = halfHeight + cardTop * fit - (1.0 - edgeFade) * slotFeather * fit
                    self.cardEdgeMask.frame = CGRect(x: -span, y: edgeStart, width: span * 2.0 + self.cardFrame.width, height: span)
                    self.cardEdgeMask.locations = self.cardMask.locations
                    self.cardEdgeView.layer.mask = self.cardEdgeMask
                } else {
                    self.cardEdgeView.layer.mask = nil
                }

                let labelLift = smooth(p / (dismissing ? 0.4 : 0.3))
                self.sourceLabel?.transform = CGAffineTransform(translationX: 0.0, y: -source.height * labelLift)
            } else {
                self.cardContainer.layer.mask = nil
                self.cardEdgeView.layer.mask = nil
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
                if target == 1.0 && elapsed >= 0.3 {
                    self.setNoticeVisible(true, duration: 0.2)
                }
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
            self.setNoticeVisible(false, duration: 0.06)
        }

        private func setNoticeVisible(_ visible: Bool, duration: Double) {
            guard self.noticeVisible != visible else { return }
            self.noticeVisible = visible
            guard let noticeView = self.notice.view else { return }
            let alpha: CGFloat = visible ? 1.0 : 0.0
            let previousAlpha = noticeView.layer.presentation()?.opacity ?? noticeView.layer.opacity
            noticeView.alpha = alpha
            noticeView.layer.animateAlpha(from: CGFloat(previousAlpha), to: alpha, duration: duration)
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
            self.animate(to: 1.0, duration: UIAccessibility.isReduceMotionEnabled ? 0.25 : (self.usesFlight ? 0.79 : 0.65), completion: { [weak self] in
                self?.setNoticeVisible(true, duration: 0.2)
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
            self.setNoticeVisible(false, duration: 0.06)
            if !UIAccessibility.isReduceMotionEnabled && self.prepareShutter() {
                self.usesFlight = true
                self.isDismissing = self.progress >= 1.0
                self.applyProgress()
                self.animate(to: 0.0, duration: max(0.06, 0.3 * Double(self.progress)), completion: completion)
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
                self.noticeContainer.layer.compositingFilter = blurIsLight ? "plusD" : "plusL"
            }
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
            var cardTopLimit = max(environment.safeInsets.top, environment.statusBarHeight) + 16.0
            self.noticeContainer.frame = CGRect(origin: .zero, size: availableSize)
            let noticeString: String?
            if component.peer.id == component.context.account.peerId {
                noticeString = environment.strings.Wallet_PublicBalanceNotice
            } else if let balance = state.balance {
                let amount = formatTonAmountText(balance, dateTimeFormat: environment.dateTimeFormat, formatString: environment.strings.Currency_Grams)
                let name = state.peer.displayTitle(strings: environment.strings, displayOrder: component.context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder)
                noticeString = environment.strings.Wallet_PeerBalanceNotice(name, amount).string
            } else {
                noticeString = nil
            }
            if let noticeString {
                func noticeText(_ color: UIColor) -> AnyComponent<Empty> {
                    return AnyComponent(BalancedTextComponent(
                        text: .plain(NSAttributedString(
                            string: noticeString,
                            font: Font.semibold(17.0),
                            textColor: color,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.0
                    ))
                }
                let noticeContainerSize = CGSize(width: max(1.0, contentWidth - 64.0), height: availableSize.height)
                let noticeSize = self.notice.update(transition: .immediate, component: noticeText(blurIsLight ? UIColor(white: 0.63, alpha: 0.6) : UIColor(white: 0.5, alpha: 0.4)), environment: {}, containerSize: noticeContainerSize)
                let noticeFrame = CGRect(origin: CGPoint(x: floor(centerX - noticeSize.width * 0.5), y: cardTopLimit + 24.0), size: noticeSize)
                if let noticeView = self.notice.view {
                    if noticeView.superview == nil {
                        noticeView.alpha = self.noticeVisible ? 1.0 : 0.0
                        self.noticeContainer.addSubview(noticeView)
                    }
                    noticeView.isHidden = false
                    noticeView.frame = noticeFrame
                }
                cardTopLimit = noticeFrame.maxY + 24.0
            } else {
                self.notice.view?.isHidden = true
            }
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
                    self.cardEdgeView.addSubview(cardView)
                }
                self.cardFrame = CGRect(x: centerX - cardSize.width * 0.5, y: cardCenterY - cardSize.height * 0.5, width: cardSize.width, height: cardSize.height)
                self.cardContainer.bounds = CGRect(origin: .zero, size: cardSize)
                self.cardEdgeView.frame = self.cardContainer.bounds
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
            if environment.theme.overallDarkAppearance {
                buttonColor = defaultDarkColorPresentationTheme.list.itemAccentColor
                buttonForegroundColor = .white
            }
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
                let source = state.stickers.last(where: { $0.style != nil })
                cardView.setGiftStyle(from: source?.style, to: source?.style, origin: .zero, progress: 1,
                    pattern: source.flatMap { state.stickerMedia[$0.gift.address]?.patternImage })
                cardView.giftStyleUpdated = nil
            }

            let isOwnWallet = component.peer.id == component.context.account.peerId
            let showsWalletInfo = !isOwnWallet && !state.hasOwnWallet
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
                        text: isOwnWallet ? environment.strings.Wallet_Transaction_OpenWallet : (showsWalletInfo ? environment.strings.Wallet_HowDoesItWork : environment.strings.Wallet_SendMoney),
                        font: Font.semibold(17.0),
                        color: buttonForegroundColor
                    ))),
                    isEnabled: isOwnWallet || showsWalletInfo || (component.context.walletContext != nil && state.card != nil),
                    action: {
                        guard let controller = controller() as? PeerWalletScreen else { return }
                        if showsWalletInfo {
                            controller.push(component.context.sharedContext.makeWalletInfoScreen(context: component.context, mode: .wallet, completion: nil))
                        } else {
                            component.sendMoney(controller)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, min(430.0, availableSize.width - 60.0)), height: 52.0)
            )
            if let buttonView = self.sendButton.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                self.buttonFrame = CGRect(x: floor((availableSize.width - buttonSize.width) * 0.5), y: buttonTop, width: buttonSize.width, height: buttonSize.height)
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

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peer: EnginePeer, card: WalletCard?, sourceView: UIView? = nil, sendMoney: @escaping (PeerWalletScreen) -> Void) {
        self.transitionSource = PeerWalletTransitionSource(view: sourceView)
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
