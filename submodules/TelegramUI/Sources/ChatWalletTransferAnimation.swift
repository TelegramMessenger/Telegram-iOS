import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import WalletContext
import WalletSendScreen
import PremiumDiamondComponent
import ChatMessageBubbleItemNode
import ChatMessageTransferBubbleContentNode
import ChatControllerInteraction

final class ChatWalletTransferAnimation {
    private final class Arrival {
        let message: EngineRawMessage
        let rise: Bool
        var startTime: CFTimeInterval?
        var didPlayHaptic = false
        weak var target: ChatMessageTransferBubbleContentNode?

        init(message: EngineRawMessage, rise: Bool) {
            self.message = message
            self.rise = rise
        }
    }

    private final class Flight {
        let id: String
        let operationId: String
        let peerId: EnginePeer.Id
        var source: WalletSendTransferAnimationSource?
        var overlay: UIView?
        var createdAt: CFTimeInterval
        var startedAt: CFTimeInterval?
        var stableId: UInt32?
        var localId: Int32?
        var transactionHash: Data?
        weak var target: ChatMessageTransferBubbleContentNode?

        init(id: String, peerId: EnginePeer.Id) {
            self.id = id
            self.operationId = String(id.dropFirst("pending:".count))
            self.peerId = peerId
            self.createdAt = CACurrentMediaTime()
        }

        func launch(source: WalletSendTransferAnimationSource, window: UIWindow) {
            self.source = source
            self.createdAt = CACurrentMediaTime()
            let overlay = UIView(frame: window.bounds)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.isUserInteractionEnabled = false
            overlay.accessibilityElementsHidden = true
            window.addSubview(overlay)
            overlay.addSubview(source.diamond)
            source.diamond.center = source.center
            source.diamond.transform = CGAffineTransform(rotationAngle: source.rotation)
            source.diamond.isRenderingEnabled = true
            self.overlay = overlay
        }

        func matches(_ message: EngineRawMessage) -> Bool {
            guard message.id.peerId == self.peerId else { return false }
            let matches: Bool
            if let pending = message.attributes.compactMap({ $0 as? PendingWalletTransferMessageAttribute }).first {
                matches = pending.operationId == self.operationId
            } else if self.stableId == message.stableId {
                matches = true
            } else if message.id.namespace == Namespaces.Message.Local && self.localId == message.id.id {
                matches = true
            } else {
                matches = self.transactionHash != nil && message.media.contains(where: { media in
                    guard let action = media as? TelegramMediaAction,
                          case let .gramTransfer(_, _, transactionId, _, _) = action.action else { return false }
                    return ChatWalletTransferAnimation.transactionHash(transactionId) == self.transactionHash
                })
            }
            if matches { self.stableId = message.stableId }
            return matches
        }
    }

    private weak var controller: ChatControllerImpl?
    private var flights: [String: Flight] = [:]
    private var endedFlights = Set<String>()
    private var arrivals: [EngineMessage.Id: Arrival] = [:]
    private var seenArrivals = Set<EngineMessage.Id>()
    private var lastArrivalStartTime: CFTimeInterval?
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var activityDisposable: Disposable?
    private var isApplicationActive = UIApplication.shared.applicationState == .active
    private var isApplicationInForeground = UIApplication.shared.applicationState != .background

    init(controller: ChatControllerImpl) {
        self.controller = controller
        controller.controllerInteraction?.isAwaitingWalletTransferFlight = { [weak self] message in
            guard let self else { return false }
            for flight in self.flights.values {
                if let state = self.controller?.context.walletContext?.stateValue {
                    self.refresh(flight, state: state)
                }
                if flight.matches(message) { return true }
            }
            return false
        }
        self.activityDisposable = (combineLatest(
            controller.context.sharedContext.applicationBindings.applicationIsActive,
            controller.context.sharedContext.applicationBindings.applicationInForeground
        ) |> deliverOnMainQueue).start(next: { [weak self] active, foreground in
            guard let self else { return }
            self.isApplicationActive = active
            self.isApplicationInForeground = foreground
            if !foreground {
                self.cancelAll()
            } else if !active {
                for id in Array(self.arrivals.keys) {
                    self.cancelArrival(id)
                }
            }
        })
    }

    deinit {
        self.activityDisposable?.dispose()
        self.displayLink?.invalidate()
        for flight in self.flights.values {
            flight.source?.diamond.isRenderingEnabled = false
            flight.overlay?.removeFromSuperview()
        }
        for arrival in self.arrivals.values {
            arrival.target?.finishIncomingTransferAnimation()
        }
    }

    func arrivalState(_ id: EngineMessage.Id) -> WalletTransferArrivalState? {
        if let arrival = self.arrivals[id] {
            if let startTime = arrival.startTime {
                return .playing(startTime: startTime, rise: arrival.rise)
            }
            return .queued(rise: arrival.rise)
        }
        return self.seenArrivals.contains(id) ? .finished : nil
    }

    func requestArrival(_ message: EngineRawMessage) {
        guard self.isApplicationActive, !self.seenArrivals.contains(message.id),
              let interaction = self.controller?.controllerInteraction, interaction.canReadHistory,
              message.flags.contains(.Incoming),
              interaction.unreadMessageRange[UnreadMessageRangeKey(peerId: message.id.peerId, namespace: message.id.namespace)]?.contains(message.id.id) == true else { return }
        self.seenArrivals.insert(message.id)
        let rise = interaction.freshWalletTransferMessageIds.remove(message.id) != nil
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        self.arrivals[message.id] = Arrival(message: message, rise: rise)
        // All requests from the current layout transaction are sorted on the next frame.
        self.ensureDisplayLink()
    }

    func cancelArrival(_ id: EngineMessage.Id) {
        guard let arrival = self.arrivals.removeValue(forKey: id) else { return }
        arrival.target?.finishIncomingTransferAnimation()
        for node in self.contentNodes() where node.item?.message.id == id && node !== arrival.target {
            node.finishIncomingTransferAnimation()
        }
        if self.arrivals.isEmpty { self.lastArrivalStartTime = nil }
        self.stopDisplayLinkIfIdle()
    }

    private func updateArrivals(at now: CFTimeInterval, nodes: [ChatMessageTransferBubbleContentNode]) {
        for arrival in self.arrivals.values.sorted(by: { $0.message.index < $1.message.index }) {
            let id = arrival.message.id
            guard self.controller?.controllerInteraction?.canReadHistory == true,
                  !UIAccessibility.isReduceMotionEnabled,
                  let node = nodes.first(where: { $0.item?.message.id == id && $0.canPlayIncomingTransferAnimation }) else {
                self.cancelArrival(id)
                continue
            }
            if let previous = arrival.target, previous !== node {
                previous.finishIncomingTransferAnimation()
            }
            arrival.target = node
            if arrival.startTime == nil {
                if let previousStart = self.lastArrivalStartTime, now - previousStart < 0.9 { continue }
                arrival.startTime = now
                self.lastArrivalStartTime = now
            }
            guard let startTime = arrival.startTime else { continue }
            if now - startTime >= WalletTransferArrivalAnimation.duration {
                self.cancelArrival(id)
            } else {
                node.updateIncomingTransferAnimation(startTime: startTime, rise: arrival.rise, at: now)
                if self.arrivals[id] === arrival, !arrival.didPlayHaptic,
                   now - startTime >= WalletTransferArrivalAnimation.climax {
                    arrival.didPlayHaptic = true
                    Haptics.strong()
                }
            }
        }
    }

    func prepare(id: String) {
        guard self.isApplicationInForeground, !UIAccessibility.isReduceMotionEnabled,
              id.hasPrefix("pending:"), self.flights[id] == nil, !self.endedFlights.contains(id),
              let controller = self.controller, let peerId = controller.chatLocation.peerId,
              let state = controller.context.walletContext?.stateValue,
              let transaction = state.transactions.items.first(where: { $0.presentationId == id }),
              transaction.status != .failed else { return }
        let flight = Flight(id: id, peerId: peerId)
        self.refresh(flight, state: state)
        self.flights[id] = flight
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for node in self.contentNodes() where node.item.map({ flight.matches($0.message) }) == true {
            node.setAwaitingTransferFlight(true)
        }
        CATransaction.commit()
        self.ensureDisplayLink()
    }

    func receive(id: String, source: WalletSendTransferAnimationSource?) -> Bool {
        guard self.isApplicationInForeground, !UIAccessibility.isReduceMotionEnabled,
              id.hasPrefix("pending:"), self.flights[id]?.source == nil, !self.endedFlights.contains(id),
              let controller = self.controller, controller.isNodeLoaded,
              let peerId = controller.chatLocation.peerId,
              let wallet = controller.context.walletContext,
              let transaction = wallet.stateValue.transactions.items.first(where: { $0.presentationId == id }),
              transaction.status != .failed, let source, let window = source.window,
              controller.view.window === window else {
            self.cancel(id: id, animated: true)
            self.stopDisplayLinkIfIdle()
            return false
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let flight = self.flights[id] ?? Flight(id: id, peerId: peerId)
        flight.launch(source: source, window: window)
        self.refresh(flight, state: wallet.stateValue)
        self.flights[id] = flight
        for node in self.contentNodes() where node.item.map({ flight.matches($0.message) }) == true {
            node.setAwaitingTransferFlight(true)
        }
        CATransaction.commit()
        controller.scrollToEndOfHistory()
        self.update()
        self.ensureDisplayLink()
        return true
    }

    private func ensureDisplayLink() {
        if (!self.flights.isEmpty || !self.arrivals.isEmpty) && self.displayLink == nil {
            self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                self?.update()
            })
        }
    }

    func cancelAll() {
        for id in Array(self.arrivals.keys) {
            self.cancelArrival(id)
        }
        for id in Array(self.flights.keys) {
            self.cancel(id: id, animated: false)
        }
        self.stopDisplayLinkIfIdle()
    }

    private static func transactionHash(_ value: String?) -> Data? {
        guard let value else { return nil }
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 1 || UInt64(parts[0]) != nil,
              let last = parts.last, let hash = Data(base64Encoded: String(last)), hash.count == 32 else { return nil }
        return hash
    }

    private func refresh(_ flight: Flight, state: WalletContext.State) {
        if let pending = state.pendingTransfers.first(where: { $0.id == flight.operationId }) {
            flight.localId = pending.pendingMessage?.localId ?? flight.localId
            flight.transactionHash = Self.transactionHash(pending.transactionHash) ?? flight.transactionHash
        }
        if let transaction = state.transactions.items.first(where: { $0.presentationId == flight.id }) {
            flight.transactionHash = Self.transactionHash(transaction.transactionHash ?? transaction.id) ?? flight.transactionHash
        }
    }

    private func contentNodes() -> [ChatMessageTransferBubbleContentNode] {
        guard let controller = self.controller, controller.isNodeLoaded else { return [] }
        var result: [ChatMessageTransferBubbleContentNode] = []
        controller.chatDisplayNode.historyNode.forEachItemNode { node in
            guard let node = node as? ChatMessageBubbleItemNode else { return }
            result.append(contentsOf: node.contentNodes.compactMap { $0 as? ChatMessageTransferBubbleContentNode })
        }
        return result
    }

    private func update() {
        guard self.isApplicationInForeground, let controller = self.controller, controller.isNodeLoaded,
              controller.view.window != nil else {
            self.cancelAll()
            return
        }
        let now = CACurrentMediaTime()
        let nodes = self.contentNodes()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        self.updateArrivals(at: now, nodes: nodes)
        for id in Array(self.flights.keys) {
            guard let flight = self.flights[id] else { continue }
            guard let state = controller.context.walletContext?.stateValue else {
                self.cancel(id: id, animated: false)
                continue
            }
            self.refresh(flight, state: state)
            let transaction = state.transactions.items.first(where: { $0.presentationId == id })
            let hasPending = state.pendingTransfers.contains(where: { $0.id == flight.operationId })
            guard !UIAccessibility.isReduceMotionEnabled, flight.peerId == controller.chatLocation.peerId,
                  transaction?.status != .failed, transaction != nil || hasPending else {
                self.cancel(id: id, animated: true)
                continue
            }
            guard let source = flight.source, let overlay = flight.overlay else {
                if now - flight.createdAt >= 1.5 { self.cancel(id: id, animated: true) }
                continue
            }
            let target = nodes.first(where: { node in
                node.item.map({ flight.matches($0.message) }) == true
                    && node.transferDiamondTarget(in: overlay) != nil
            })
            if let previous = flight.target, previous !== target,
               previous.item.map({ flight.matches($0.message) }) == true {
                previous.setAwaitingTransferFlight(false)
            }
            flight.target = target
            guard let target, let slot = target.transferDiamondTarget(in: overlay),
                  overlay.bounds.contains(slot.center) else {
                if flight.startedAt != nil || now - flight.createdAt >= 0.5 {
                    self.cancel(id: id, animated: true)
                } else {
                    source.updateFlightHaptics(at: now)
                }
                continue
            }
            source.updateFlightHaptics(at: now)
            target.setAwaitingTransferFlight(true)
            if flight.startedAt == nil { flight.startedAt = now }
            let t = min(1.0, max(0.0, now - (flight.startedAt ?? now)) / 0.62)
            let deltaY = slot.center.y - source.center.y
            let rise = 56.0 + max(0.0, -deltaY)
            let b = -2.0 * rise - 2.0 * sqrt(max(0.0, rise * rise + rise * deltaY))
            let diamond = source.diamond
            diamond.transform = CGAffineTransform(rotationAngle: source.rotation * (1.0 - t))
            diamond.center = CGPoint(
                x: source.center.x + (slot.center.x - source.center.x) * t,
                y: source.center.y + b * t + (deltaY - b) * t * t
            )
            let width = (source.width + (slot.width - source.width) * t)
                * (1.0 + 0.28 * sin(.pi * min(1.0, t / 0.75)))
            let speed = Float(2.0 * .pi / 26.0 + (5.0 - 2.0 * .pi / 26.0) * min(1.0, t / 0.6))
            diamond.updateWalletTransfer(width: width, rotationSpeed: speed, completion: false,
                isDark: controller.presentationData.theme.overallDarkAppearance, appearance: t > 0.5 ? .cool : .blue)
            if t >= 1.0 {
                self.flights.removeValue(forKey: id)
                self.endedFlights.insert(id)
                Haptics.hit(0.8)
                target.acceptTransferDiamond(diamond)
                flight.overlay?.removeFromSuperview()
            }
        }
        self.stopDisplayLinkIfIdle()
    }

    private func cancel(id: String, animated: Bool) {
        guard let flight = self.flights.removeValue(forKey: id) else { return }
        self.endedFlights.insert(id)
        for node in self.contentNodes() where node.item.map({ flight.matches($0.message) }) == true {
            node.setAwaitingTransferFlight(false, animated: animated)
        }
        flight.source?.diamond.isRenderingEnabled = false
        if animated, let overlay = flight.overlay {
            overlay.alpha = 0.0
            overlay.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in
                overlay.removeFromSuperview()
            })
        } else {
            flight.overlay?.removeFromSuperview()
        }
    }

    private func stopDisplayLinkIfIdle() {
        if self.flights.isEmpty && self.arrivals.isEmpty {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }
}

extension ChatControllerImpl {
    func walletTransferAnimationCoordinator() -> ChatWalletTransferAnimation {
        if let current = self.walletTransferAnimation { return current }
        let animation = ChatWalletTransferAnimation(controller: self)
        self.walletTransferAnimation = animation
        return animation
    }
}
