import WalletGiftStickerMediaComponent
import UIKit
import Display
import AccountContext
import WalletContext
import WalletCardComponent

final class WalletGiftStickerCoordinator: NSObject, UIGestureRecognizerDelegate {
    private struct Pose {
        var center: CGPoint
        var side: CGFloat
        var angle: CGFloat
        var lift: CGFloat = 0
        var front: CGFloat = 1
        var bend: CGFloat = 0
        var shade: CGFloat = 0
        var border: CGFloat = 1
        var opacity: CGFloat = 1
        var axis = CGPoint(x: 0, y: 1)
        var tilt: CGFloat = 0
    }
    private struct Drag {
        let gift: WalletContext.Collectible
        let original: Pose
        let start: Double
        let fromCard: Bool
        var center: CGPoint
        var angle: CGFloat
        var scale: CGFloat
        var offset: CGPoint
        var previousPoint: CGPoint
        var samples: [(time: Double, point: CGPoint)] = []

        func velocity(at now: Double) -> CGPoint {
            guard let first = self.samples.first, let last = self.samples.last,
                  last.time - first.time > 0.008 else { return .zero }
            let dt = last.time - first.time
            let fade = exp(-max(0, now - last.time) / 0.09)
            return CGPoint(x: (last.point.x - first.point.x) / dt * fade,
                y: (last.point.y - first.point.y) / dt * fade)
        }
    }
    private struct Twist {
        let distance: CGFloat
        var lastAngle: CGFloat
        var turn: CGFloat = 0
        let scale: CGFloat
        let angle: CGFloat
        let center: CGPoint
        let midpoint: CGPoint
    }
    private struct Flight {
        let id: String
        let from: Pose
        let to: Pose
        let start: Double
        let sticking: Bool
        let returning: Bool
        var thrown = false
        var trash = false
        var handedOff = false
        var contacted = false
        var peelFirst = false
        var fast = false
    }
    private struct Play {
        let id: String
        let start: Double
        var head: Double = 0
        var requested = false
        var image: UIImage?
        var ended: Double?
    }

    private weak var host: UIView?
    private weak var scrollView: UIScrollView?
    private weak var grid: WalletCollectiblesGridView?
    private weak var card: WalletCardComponent.View?
    private weak var wallet: WalletContext?
    private weak var context: AccountContext?
    private var address: String?
    private var visible = false
    private var canEdit = false
    private var placements: [WalletContext.CardSticker] = []
    private var pendingCommit: [WalletContext.CardSticker]?
    private var media: [String: WalletGiftStickerMedia] = [:]
    private var mediaGifts: [String: WalletContext.Collectible] = [:]
    private var drag: Drag?
    private var twist: Twist?
    private var fingerCount = 0
    private var flights: [String: Flight] = [:]
    private var flightViews: [String: WalletStickerWaveView] = [:]
    private struct Pending { let gift: WalletContext.Collectible; let point: CGPoint; let fromCard: Bool }
    private struct Hold {
        let original: WalletContext.CardSticker
        let start: Double
        var previousAngle: CGFloat
        var distance: CGFloat
        var scale: CGFloat
        var rawAngle: CGFloat
        var resized = false
        var snapped: Int?
    }
    private var pending: Pending?
    private var hold: Hold?
    private var holdTimer: Timer?
    private var dismissMenu: (() -> Void)?
    var showMenu: ((UIView, Bool, Bool, Bool, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void) -> (() -> Void)?)?
    private let trash = WalletStickerTrashView()
    var removeTitle: String = "" { didSet { self.trash.title = self.removeTitle } }
    private var previousTick: Double?
    private var impactActive = false
    private let holdPress = WalletStickerSpring(0, 260, 0.58)
    private let holdRealSize = WalletStickerSpring(0, 420, 1)
    private let tapBoop = WalletStickerSpring(0, 300, 0.5)
    private var liveStickerId: String?
    private var trashHot = false
    private var styleFrom: WalletContext.CardGiftStyle?
    private var styleTo: WalletContext.CardGiftStyle?
    private var styleStart: Double?
    private var styleOrigin = CGPoint.zero
    private var play: Play?
    private var link: SharedDisplayLinkDriver.Link?
    private let gesture = WalletGiftStickerGesture()
    private let tap = UITapGestureRecognizer()
    private let overlay = UIView()
    private let face = WalletStickerWaveView(frame: .zero)
    private var savedScrollEnabled = true
    private var lifecycleObserver: NSObjectProtocol?
    var limitReached: (() -> Void)?
    var isDragging: Bool { self.drag != nil || self.pending != nil || self.hold != nil }

    init(host: UIView, scrollView: UIScrollView, grid: WalletCollectiblesGridView) {
        self.host = host
        self.scrollView = scrollView
        self.grid = grid
        super.init()
        self.overlay.isUserInteractionEnabled = false
        self.overlay.addSubview(self.face)
        self.gesture.delegate = self
        self.gesture.cancelsTouchesInView = true

        self.overlay.addSubview(self.trash)
        self.gesture.delayAtPoint = { [weak self] point in
            guard let self, let host = self.host, self.visible, self.canEdit else { return nil }
            if self.sticker(at: point) != nil { return 0 }
            if let (gift, _) = self.grid?.stickerCandidate(at: point, in: host), gift.kind == .gift,
               self.grid?.isStickerReady(address: gift.address) == true,
               self.flights[gift.address] == nil, let context = self.context {
                self.media[gift.address]?.prepareForSticker(context: context)
                return 0.17
            }
            return nil
        }
        self.gesture.began = { [weak self] point in self?.beginPending(at: point) ?? false }
        self.gesture.moved = { [weak self] points in self?.track(points) }
        self.gesture.finished = { [weak self] cancelled in self?.finishInteraction(cancelled: cancelled) }
        host.addGestureRecognizer(self.gesture)
        self.tap.addTarget(self, action: #selector(self.tapped(_:)))
        self.tap.delegate = self
        self.tap.require(toFail: self.gesture)
        host.addGestureRecognizer(self.tap)
        self.grid?.visibleGiftsChanged = { [weak self] gifts in self?.prepare(gifts) }
        self.lifecycleObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.cancel() }
    }

    deinit {
        self.link?.invalidate()
        if let lifecycleObserver { NotificationCenter.default.removeObserver(lifecycleObserver) }
    }

    func update(context: AccountContext, wallet: WalletContext, state: WalletContext.State?, card: WalletCardComponent.View?, visible: Bool) {
        let address = state?.walletAddress
        let restoring = self.context !== context || self.wallet !== wallet || self.address != address || !self.visible
        if self.context !== context || self.wallet !== wallet || self.address != address {
            self.cancel()
            self.media.removeAll()
            self.mediaGifts.removeAll()
            self.pendingCommit = nil
            self.placements = []
            self.styleFrom = nil; self.styleTo = nil; self.styleStart = nil
            self.card?.setGiftStyle(from: nil, to: nil, origin: .zero, progress: 1)
        }
        self.context = context
        self.wallet = wallet
        self.address = address
        self.card = card
        self.visible = visible
        if case .wallet? = state?.phase { self.canEdit = true } else { self.canEdit = false }
        self.gesture.isEnabled = visible && self.canEdit
        self.tap.isEnabled = visible
        if !visible { self.cancel() }
        let stored = state?.cardStickers ?? []
        if self.pendingCommit == stored { self.pendingCommit = nil }
        let value = self.pendingCommit ?? stored
        if value != self.placements {
            // A confirmed transfer or wallet refresh can remove a gift mid-gesture.
            let activePlacedId = self.drag.flatMap { $0.fromCard ? $0.gift.address : nil }
                ?? self.hold?.original.gift.address ?? self.play?.id
            if let activePlacedId, !value.contains(where: { $0.gift.address == activePlacedId }) {
                self.cancel()
            }
            if let hold = self.hold, let edited = self.placements.first(where: { $0.gift.address == hold.original.gift.address }), value.contains(where: { $0.gift.address == edited.gift.address }) {
                self.placements = value.map { $0.gift.address == edited.gift.address ? edited : $0 }
            } else { self.placements = value }
        }
        for (id, flight) in self.flights where flight.sticking && !self.placements.contains(where: { $0.gift.address == id }) {
            self.flights.removeValue(forKey: id); self.flightViews.removeValue(forKey: id)?.removeFromSuperview()
        }
        if restoring {
            self.styleTo = self.placements.compactMap(\.style).last
            self.styleFrom = self.styleTo; self.styleStart = nil
        }
        self.prepare(self.placements.map(\.gift) + (visible ? (self.grid?.visibleGifts ?? []) : []))
        self.sync()
    }

    func cancel() {
        self.gesture.cancel()
        if self.drag != nil { self.release(cancelled: true) }
        self.finishInteraction(cancelled: true)
        self.dismissMenu?(); self.dismissMenu = nil
        self.flights.removeAll()
        self.trash.isHidden = true; self.trashHot = false
        for view in self.flightViews.values { view.removeFromSuperview() }
        self.flightViews.removeAll()
        self.styleStart = nil
        self.play = nil
        self.holdPress.set(0); self.holdRealSize.set(0); self.tapBoop.set(0)
        self.liveStickerId = nil; self.trash.reset()
        self.card?.setStickerLive([:])
        for id in self.media.keys { self.grid?.setStickerReturnScale(address: id, scale: 1) }
        self.impactActive = false; self.card?.resetStickerImpact()
        self.stopClock()
        self.sync()
    }

    private func prepare(_ gifts: [WalletContext.Collectible]) {
        guard let context else { return }
        for gift in gifts where gift.kind == .gift {
            let onCard = self.placements.contains(where: { $0.gift.address == gift.address })
            if let media = self.media[gift.address], self.mediaGifts[gift.address]?.giftSlug == gift.giftSlug {
                if onCard { media.prepareForSticker(context: context) }
                continue
            }
            let item = WalletGiftStickerMedia(context: context, gift: gift,
                modelFile: self.placements.first(where: { $0.gift.address == gift.address })?.modelFile,
                style: self.placements.first(where: { $0.gift.address == gift.address })?.giftStyle, prepareSticker: onCard)
            self.media[gift.address] = item
            self.mediaGifts[gift.address] = gift
            item.updated = { [weak self, weak item] in
                guard let self, let item, self.media[gift.address] === item else { return }
                // Upgrade pre-model layouts without changing their position or stacking order.
                if let index = self.placements.firstIndex(where: { $0.gift.address == gift.address }),
                   let modelFile = item.modelFile,
                   self.placements[index].modelFile != modelFile || (item.style != nil && self.placements[index].giftStyle != item.style) {
                    let sticker = self.placements[index]
                    self.placements[index] = WalletContext.CardSticker(gift: sticker.gift, x: sticker.x, y: sticker.y,
                        angle: sticker.angle, scale: sticker.scale, modelFile: modelFile, geometryVersion: sticker.geometryVersion,
                        style: sticker.style, giftStyle: item.style ?? sticker.giftStyle,
                        aspectRatio: sticker.aspectRatio, cornerRadius: sticker.cornerRadius)
                    if self.hold == nil { self.commit() }
                }
                self.sync()
            }
        }
        var keep = Set(self.placements.map { $0.gift.address } + (self.grid?.visibleGifts.map(\.address) ?? []))
        if let drag { keep.insert(drag.gift.address) }
        keep.formUnion(self.flights.keys)
        if let play { keep.insert(play.id) }
        for id in Array(self.media.keys) where !keep.contains(id) {
            self.media.removeValue(forKey: id)
            self.mediaGifts.removeValue(forKey: id)
        }
    }

    private func sync() {
        var images: [String: UIImage] = [:]
        for (id, item) in self.media {
            if let first = item.first {
                images[id] = first.image
            }
        }
        if self.hold != nil, let play, let image = play.image { images[play.id] = image }
        var hidden = Set<String>()
        if let drag { hidden.insert(drag.gift.address) }
        for flight in self.flights.values where flight.sticking && !flight.handedOff { hidden.insert(flight.id) }
        if let play, self.hold == nil, CACurrentMediaTime() - play.start >= 0.14,
           play.ended.map({ CACurrentMediaTime() - $0 < 0.20 }) ?? true { hidden.insert(play.id) }
        self.card?.setCardStickers(self.placements, images: images, hidden: hidden)
        var occupied = Set(self.placements.map { $0.gift.address })
        if let drag { occupied.insert(drag.gift.address) }
        var lifted = Set(self.flights.keys)
        if let drag { lifted.insert(drag.gift.address) }
        self.grid?.setStickers(occupied: occupied, lifted: lifted, styles: self.media.compactMapValues { $0.style }, media: self.media)
        self.updateStyle()

    }

    private func sticker(at point: CGPoint) -> WalletContext.CardSticker? {
        guard let card, let host, self.visible else { return nil }
        let surface = card.stickerSurface
        let local = surface.convert(point, from: host)
        guard surface.bounds.contains(local), card.stickerPointIsInteractive(local) else { return nil }
        for sticker in self.placements.reversed() where self.media[sticker.gift.address]?.first != nil && self.flights[sticker.gift.address] == nil {
            let center = CGPoint(x: CGFloat(sticker.x) * surface.bounds.width, y: CGFloat(sticker.y) * surface.bounds.height)
            let side = surface.bounds.width * CGFloat(sticker.renderedWidthFraction)
            if hypot(local.x - center.x, local.y - center.y) < side * 0.42 { return sticker }
        }
        return nil
    }

    private func pose(_ sticker: WalletContext.CardSticker) -> Pose? {
        guard let card, let host else { return nil }
        let surface = card.stickerSurface
        let center = CGPoint(x: CGFloat(sticker.x) * surface.bounds.width, y: CGFloat(sticker.y) * surface.bounds.height)
        let side = surface.bounds.width * CGFloat(sticker.renderedWidthFraction)
        let origin = surface.convert(center, to: host)
        let right = surface.convert(CGPoint(x: center.x + side, y: center.y), to: host)
        return Pose(center: origin, side: hypot(right.x - origin.x, right.y - origin.y),
            angle: CGFloat(sticker.angle) + atan2(right.y - origin.y, right.x - origin.x))
    }

    private func gridPose(address: String, rect: CGRect) -> Pose? {
        guard self.media[address]?.first != nil else { return nil }
        guard let frame = self.grid?.stickerModelFrame(address: address, side: rect.width) else { return nil }
        return Pose(center: CGPoint(x: rect.minX + frame.midX, y: rect.minY + frame.midY), side: frame.width, angle: 0)
    }

    private static func clamp(_ scale: CGFloat) -> CGFloat {
        min(WalletStickerPlacement.maximum, max(WalletStickerPlacement.minimum, scale))
    }

    private func lockInteraction() {
        if !self.cardIsLocked {
            self.savedScrollEnabled = self.scrollView?.isScrollEnabled ?? true
            self.cardIsLocked = true
        }
        self.scrollView?.isScrollEnabled = false
        self.card?.stickerInteractionLocked = true
    }
    private var cardIsLocked = false
    private func unlockInteraction() {
        if self.cardIsLocked { self.scrollView?.isScrollEnabled = self.savedScrollEnabled }
        self.cardIsLocked = false
        self.card?.stickerInteractionLocked = false
    }

    private func beginPending(at point: CGPoint) -> Bool {
        guard let host, self.pending == nil, self.drag == nil, self.hold == nil else { return false }
        self.play = nil
        let gift: WalletContext.Collectible
        let onCard: Bool
        if let sticker = self.sticker(at: point) { gift = sticker.gift; onCard = true }
        else if let (item, _) = self.grid?.stickerCandidate(at: point, in: host) { gift = item; onCard = false }
        else { return false }
        self.pending = Pending(gift: gift, point: point, fromCard: onCard)
        self.lockInteraction()
        self.grid?.pressSticker(address: gift.address, pressed: !onCard)
        self.holdTimer?.invalidate()
        let timer = Timer(timeInterval: onCard ? 0.45 : 0.15, repeats: false) { [weak self] _ in
            guard let self, let pending = self.pending else { return }
            self.holdTimer = nil
            if pending.fromCard { self.beginHold(pending) }
            else { self.openMenu(pending) }
        }
        self.holdTimer = timer; RunLoop.main.add(timer, forMode: .common)
        self.sync()
        return true
    }

    private func openMenu(_ pending: Pending) {
        guard let source = self.grid?.stickerSourceView(address: pending.gift.address) else { return }
        let sticker = self.placements.first(where: { $0.gift.address == pending.gift.address })
        self.dismissMenu = self.showMenu?(source, sticker != nil, sticker?.style != nil,
            self.media[pending.gift.address]?.style != nil && self.media[pending.gift.address]?.patternImage != nil, { [weak self] in
                self?.menuAction(pending.gift, color: false)
            }, { [weak self] in self?.menuAction(pending.gift, color: true) }, { [weak self] in
                self?.dismissMenu = nil
                self?.grid?.pressSticker(address: pending.gift.address, pressed: false)
            })
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func menuAction(_ gift: WalletContext.Collectible, color: Bool) {
        self.finishInteraction(cancelled: false)
        self.dismissMenu = nil
        guard self.visible, let media = self.media[gift.address], media.first != nil else { return }
        if let index = self.placements.firstIndex(where: { $0.gift.address == gift.address }) {
            if color {
                let apply = self.placements[index].style == nil
                guard !apply || media.style != nil else { return }
                self.styleOrigin = CGPoint(x: CGFloat(self.placements[index].x) * (self.card?.stickerSurface.bounds.width ?? 0),
                    y: CGFloat(self.placements[index].y) * (self.card?.stickerSurface.bounds.height ?? 0))
                self.placements = self.placements.enumerated().map { i, s in s.withStyle(i == index && apply ? media.style : nil) }
            } else {
                let sticker = self.placements.remove(at: index)
                if let from = self.pose(sticker) { self.returnGift(gift, from: from, peelFirst: true) }
            }
            self.commit(); self.sync()
        } else {
            guard let host, let rect = self.grid?.stickerFrame(address: gift.address, in: host),
                  let from = self.gridPose(address: gift.address, rect: rect),
                  let spot = self.solver(excluding: gift.address)?.spread(aim: nil, scale: 1) else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning); return
            }
            self.place(gift, from: from, spot: spot, angle: 0, thrown: true, style: color ? media.style : nil)
        }
    }

    private func beginHold(_ pending: Pending) {
        guard let sticker = self.placements.first(where: { $0.gift.address == pending.gift.address }),
              let pose = self.pose(sticker) else { return }
        self.pending = nil
        self.liveStickerId = sticker.gift.address
        self.holdPress.with(260, 0.58).to(1); self.holdRealSize.set(0)
        self.hold = Hold(original: sticker, start: CACurrentMediaTime(),
            previousAngle: atan2(pending.point.y - pose.center.y, pending.point.x - pose.center.x),
            distance: hypot(pending.point.x - pose.center.x, pending.point.y - pose.center.y),
            scale: Self.clamp(CGFloat(sticker.renderedWidthFraction / WalletContext.CardSticker.widthFraction)), rawAngle: CGFloat(sticker.angle))
        self.play = Play(id: sticker.gift.address, start: CACurrentMediaTime(), image: self.media[sticker.gift.address]?.first?.image)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.startClock(); self.sync()
    }

    private func track(_ points: [CGPoint]) {
        guard let first = points.first else { return }
        if let pending {
            if hypot(first.x - pending.point.x, first.y - pending.point.y) > 8 || points.count > 1 {
                self.holdTimer?.invalidate(); self.holdTimer = nil
                self.dismissMenu?(); self.dismissMenu = nil
                self.grid?.pressSticker(address: pending.gift.address, pressed: false)
                self.pending = nil
                if self.begin(at: pending.point) { self.move(points) }
                else { self.unlockInteraction() }
            }
            return
        }
        if var hold = self.hold,
           let index = self.placements.firstIndex(where: { $0.gift.address == hold.original.gift.address }),
           let pose = self.pose(self.placements[index]) {
            let distance = hypot(first.x - pose.center.x, first.y - pose.center.y)
            var angle = hold.rawAngle
            var scale = CGFloat(self.placements[index].renderedWidthFraction / WalletContext.CardSticker.widthFraction)
            if points.count > 1 {
                let other = points[1]
                let d = max(1, hypot(other.x - first.x, other.y - first.y))
                let a = atan2(other.y - first.y, other.x - first.x)
                if self.twist == nil { self.twist = Twist(distance: d, lastAngle: a, scale: scale, angle: angle, center: pose.center, midpoint: first) }
                if var twist = self.twist {
                    twist.turn += atan2(sin(a - twist.lastAngle), cos(a - twist.lastAngle)); twist.lastAngle = a
                    angle = twist.angle + twist.turn; scale = Self.clamp(twist.scale * d / twist.distance)
                    self.twist = twist; hold.resized = true
                }
            } else {
                let a = atan2(first.y - pose.center.y, first.x - pose.center.x)
                if self.twist == nil, distance > 14 {
                    angle += atan2(sin(a - hold.previousAngle), cos(a - hold.previousAngle))
                    if abs(distance - hold.distance) > 5 { hold.resized = true }
                    if hold.resized { scale = Self.clamp(hold.scale + (distance - hold.distance) / 110) }
                }
                if self.twist != nil { hold.distance = distance; hold.scale = scale }
                hold.previousAngle = a; self.twist = nil
            }
            hold.rawAngle = angle
            let quarter = Int((angle / (.pi / 2)).rounded())
            let snap = CGFloat(quarter) * .pi / 2
            if abs(angle - snap) < 5 * .pi / 180 {
                if hold.snapped != quarter { UISelectionFeedbackGenerator().selectionChanged() }
                hold.snapped = quarter; angle = snap
            } else { hold.snapped = nil }
            self.placements[index] = self.placements[index].updated(angle: Double(angle), scale: Double(Self.clamp(scale)), geometryVersion: 1)
            self.hold = hold
            self.sync()
            return
        }
        self.move(points)
    }

    private func finishInteraction(cancelled: Bool) {
        self.holdTimer?.invalidate(); self.holdTimer = nil
        if let pending {
            self.pending = nil
            if cancelled || self.dismissMenu == nil {
                self.grid?.pressSticker(address: pending.gift.address, pressed: false)
            }
            if pending.fromCard && !cancelled {
                self.liveStickerId = pending.gift.address; self.tapBoop.velocity += 3
                self.play = Play(id: pending.gift.address, start: CACurrentMediaTime(), image: self.media[pending.gift.address]?.first?.image)
                self.startClock()
            }
        }
        if let hold {
            if cancelled, let index = self.placements.firstIndex(where: { $0.gift.address == hold.original.gift.address }) {
                self.placements[index] = hold.original
            }
            self.hold = nil; self.twist = nil; self.play = nil
            self.holdPress.with(380, 0.62).to(0)
            if !cancelled { self.commit() }
        }
        if self.drag != nil { self.release(cancelled: cancelled) }
        self.unlockInteraction(); self.sync()
    }

    private func updateDragFeedback(_ drag: Drag) {
        guard let host else { return }

        self.trash.center = CGPoint(x: host.bounds.width / 2, y: host.bounds.height - host.safeAreaInsets.bottom - 64)

        let hot = drag.fromCard && hypot(drag.previousPoint.x - self.trash.center.x, drag.previousPoint.y - self.trash.center.y) < 90
        if hot != self.trashHot { UISelectionFeedbackGenerator().selectionChanged(); self.trashHot = hot; self.trash.setOpen(hot) }

    }

    private func begin(at point: CGPoint) -> Bool {
        guard self.drag == nil, let host, let card else { return false }
        let gift: WalletContext.Collectible
        let origin: Pose
        let fromCard: Bool
        let scale: CGFloat
        if let sticker = self.sticker(at: point), let value = self.pose(sticker) {
            gift = sticker.gift; origin = value; scale = Self.clamp(CGFloat(sticker.renderedWidthFraction / WalletContext.CardSticker.widthFraction)); fromCard = true
        } else if let (item, rect) = self.grid?.stickerCandidate(at: point, in: host),
                  item.kind == .gift, !self.placements.contains(where: { $0.gift.address == item.address }) {
            gift = item
            guard let value = self.gridPose(address: item.address, rect: rect) else { return false }
            origin = value
            scale = 1; fromCard = false
        } else { return false }
        guard self.media[gift.address]?.first != nil, fromCard || self.grid?.isStickerReady(address: gift.address) == true else { return false }
        let side = card.stickerSurface.bounds.width * WalletContext.CardSticker.widthFraction * scale * 1.4
        let offset = CGPoint(x: side * 0.34, y: -side * 0.58)
        self.drag = Drag(gift: gift, original: origin, start: CACurrentMediaTime(), fromCard: fromCard,
            center: CGPoint(x: point.x + offset.x, y: point.y + offset.y), angle: origin.angle,
            scale: scale, offset: offset, previousPoint: point)
        self.twist = nil
        self.fingerCount = 1
        self.lockInteraction()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.startClock()
        self.tick()
        self.sync()
        return true
    }

    private func move(_ points: [CGPoint]) {
        guard var drag = self.drag, let first = points.first else { return }
        let now = CACurrentMediaTime()
        if points.count > 1 {
            let other = points[1]
            let midpoint = CGPoint(x: (first.x + other.x) * 0.5, y: (first.y + other.y) * 0.5)
            let distance = max(1, hypot(other.x - first.x, other.y - first.y))
            let angle = atan2(other.y - first.y, other.x - first.x)
            if self.twist == nil {
                self.twist = Twist(distance: distance, lastAngle: angle, scale: drag.scale,
                    angle: drag.angle, center: drag.center, midpoint: midpoint)
            }
            if var twist = self.twist {
                twist.turn += atan2(sin(angle - twist.lastAngle), cos(angle - twist.lastAngle))
                twist.lastAngle = angle
                drag.scale = Self.clamp(twist.scale * distance / twist.distance)
                drag.angle = twist.angle + twist.turn
                let k = drag.scale / twist.scale
                let dx = twist.center.x - twist.midpoint.x, dy = twist.center.y - twist.midpoint.y
                drag.center = CGPoint(x: midpoint.x + (dx * cos(twist.turn) - dy * sin(twist.turn)) * k,
                    y: midpoint.y + (dx * sin(twist.turn) + dy * cos(twist.turn)) * k)
                self.twist = twist
            }
        } else {
            if self.fingerCount > 1 {
                drag.offset = CGPoint(x: drag.center.x - first.x, y: drag.center.y - first.y)
            }
            self.twist = nil
            drag.center = CGPoint(x: first.x + drag.offset.x, y: first.y + drag.offset.y)
        }
        // Reset velocity history when handing control between fingers.
        if self.fingerCount != points.count { drag.samples.removeAll(keepingCapacity: true) }
        drag.samples.append((time: now, point: first))
        drag.samples.removeAll { now - $0.time > 0.12 }
        drag.previousPoint = first
        self.fingerCount = points.count
        self.drag = drag
        self.updateDragFeedback(drag)
    }

    private func dragPose(_ drag: Drag, now: Double) -> Pose {
        let peel = Self.ease((now - drag.start) / 0.3)
        let raise = Self.ease((now - drag.start - 0.225) / 0.26)
        let side = (self.card?.stickerSurface.bounds.width ?? 370) * WalletContext.CardSticker.widthFraction * drag.scale * 1.4
        var pose = Self.mix(drag.original, Pose(center: drag.center, side: side, angle: drag.angle), raise)
        if self.twist == nil {
            let velocity = drag.velocity(at: now)
            let speed = hypot(velocity.x, velocity.y)
            pose.angle += max(-0.25, min(0.25, velocity.x * 0.00035)) * raise
            pose.tilt = min(14, speed * 0.009) * raise
            if speed > 1 { pose.axis = CGPoint(x: -velocity.y / speed, y: velocity.x / speed) }
        }
        if drag.fromCard {
            let bin = self.trash.attraction
            pose.center.x += (self.trash.iconCenter.x - pose.center.x) * bin
            pose.center.y += (self.trash.center.y - 48 - pose.center.y) * bin
            pose.side += (40 - pose.side) * bin
        }
        pose.border = drag.fromCard ? 1 : min(1, peel * 1.3)
        pose.lift = raise
        pose.front = 1 - peel
        pose.bend = 0.75 * (1 - raise)
        pose.shade = 1 - raise
        return pose
    }

    private func release(cancelled: Bool) {
        guard let drag else { return }
        let now = CACurrentMediaTime()
        let from = self.dragPose(drag, now: now)
        let velocity = drag.velocity(at: now)
        self.drag = nil; self.twist = nil
        self.unlockInteraction()
        if cancelled { self.sync(); self.tick(); return }
        guard let card, let host else { self.sync(); return }
        let local = card.stickerSurface.convert(from.center, from: host)
        let tossed = velocity.y < -600 && hypot(velocity.x, velocity.y) > 700
        if drag.fromCard && self.trashHot {
            self.placements.removeAll { $0.gift.address == drag.gift.address }
            self.flights[drag.gift.address] = Flight(id: drag.gift.address, from: from,
                to: Pose(center: CGPoint(x: self.trash.iconCenter.x, y: self.trash.center.y + 2), side: 1, angle: from.angle + 0.5, opacity: 0),
                start: CACurrentMediaTime(), sticking: false, returning: false, trash: true)
            self.trash.isHidden = false
            self.commit(); self.sync(); return
        }
        let solver = self.solver(excluding: drag.gift.address)
        let nearCard = card.stickerSurface.bounds.insetBy(dx: -30, dy: -30).contains(local)
        let spot = tossed ? solver?.spread(aim: local, scale: drag.scale) : (nearCard ? solver?.drop(near: local, scale: drag.scale) : nil)
        if let spot {
            self.place(drag.gift, from: from, spot: spot, angle: drag.angle, thrown: tossed)
        } else {
            if nearCard || tossed { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            // A full card must not remove an existing sticker.
            if drag.fromCard && (nearCard || tossed), let original = self.placements.first(where: { $0.gift.address == drag.gift.address }), let to = self.pose(original) {
                self.flights[drag.gift.address] = Flight(id: drag.gift.address, from: from, to: to,
                    start: CACurrentMediaTime(), sticking: true, returning: false)
            } else {
                self.placements.removeAll { $0.gift.address == drag.gift.address }
                self.returnGift(drag.gift, from: from, fast: velocity.y > 650)
            }
            self.commit(); self.sync()
        }
        self.trashHot = false
    }

    private func solver(excluding id: String) -> WalletStickerPlacement? {
        guard let card else { return nil }
        // Committed destinations reserve space even while their overlays are flying.
        return WalletStickerPlacement(size: card.stickerSurface.bounds.size, obstacles: card.stickerObstacles,
            occupants: self.placements.filter { $0.gift.address != id })
    }

    private func place(_ gift: WalletContext.Collectible, from: Pose, spot: WalletStickerPlacement.Spot, angle: CGFloat, thrown: Bool, style: WalletContext.CardGiftStyle? = nil) {
        guard let card else { return }
        let size = card.stickerSurface.bounds.size
        let previous = self.placements.first(where: { $0.gift.address == gift.address })
        guard previous != nil || self.placements.count < 10 else {
            self.returnGift(gift, from: from)
            self.limitReached?()
            return
        }
        let sticker = WalletContext.CardSticker(gift: gift, x: Double(spot.center.x / size.width), y: Double(spot.center.y / size.height),
            angle: Double(angle), scale: Double(spot.scale), modelFile: self.media[gift.address]?.modelFile,
            geometryVersion: 1, style: style ?? previous?.style, giftStyle: self.media[gift.address]?.style,
            aspectRatio: previous?.aspectRatio, cornerRadius: previous?.cornerRadius)
        self.placements.removeAll { $0.gift.address == gift.address }
        if style != nil { self.placements = self.placements.map { $0.withStyle(nil) } }
        self.placements.append(sticker)
        if thrown { self.revealCard() }
        self.flights[gift.address] = Flight(id: gift.address, from: from, to: self.pose(sticker) ?? from,
            start: CACurrentMediaTime(), sticking: true, returning: false, thrown: thrown)
        self.styleOrigin = spot.center
        self.commit(); self.sync(); self.startClock()
    }

    private func revealCard() {
        guard let scrollView else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top), animated: true)
    }

    private func returnGift(_ gift: WalletContext.Collectible, from: Pose, peelFirst: Bool = false, fast: Bool = false) {
        let cell = self.host.flatMap { self.grid?.stickerFrame(address: gift.address, in: $0) }
        let to = cell.flatMap { self.gridPose(address: gift.address, rect: $0) }
            ?? Pose(center: from.center, side: from.side * 0.6, angle: from.angle, opacity: 0)
        self.flights[gift.address] = Flight(id: gift.address, from: from, to: to, start: CACurrentMediaTime(), sticking: false, returning: cell != nil, peelFirst: peelFirst, fast: fast)
        self.startClock()
    }

    private func commit() {
        guard let address else { return }
        self.placements = WalletContext.CardSticker.validated(self.placements)
        self.pendingCommit = self.placements
        self.wallet?.updateCardStickers(self.placements, walletAddress: address)
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, self.drag == nil, self.play == nil,
              let sticker = self.sticker(at: recognizer.location(in: self.host)),
              let media = self.media[sticker.gift.address], media.first != nil else { return }
        self.liveStickerId = sticker.gift.address; self.tapBoop.velocity += 3
        self.play = Play(id: sticker.gift.address, start: CACurrentMediaTime(), image: media.first?.image)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        self.startClock()
        self.tick()
        self.sync()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard self.visible else { return false }
        if gestureRecognizer === self.tap { return self.sticker(at: touch.location(in: self.host)) != nil }
        return true
    }

    private func startClock() {
        guard let host else { return }
        self.overlay.frame = host.bounds
        if self.overlay.superview == nil { host.addSubview(self.overlay) }
        host.bringSubviewToFront(self.overlay)
        if self.link == nil {
            self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] _ in self?.tick() }
        }
    }

    private func stopClock() {
        self.link?.invalidate()
        self.link = nil
        self.previousTick = nil
        if !self.isDragging { self.card?.stickerInteractionLocked = false }
        self.overlay.removeFromSuperview()
        self.overlay.layer.mask = nil
    }

    private func tick() {
        guard let host, host.window != nil, self.visible else { self.cancel(); return }
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(1 / 30.0, max(0, now - (self.previousTick ?? now))))
        self.previousTick = now
        self.impactActive = self.card?.stepStickerImpact(dt) ?? false
        let carrying = self.drag.map { drag in
            guard drag.fromCard, let card else { return false }
            return !card.stickerSurface.bounds.contains(card.stickerSurface.convert(drag.center, from: host))
        } ?? false
        let trashActive = self.trash.step(dt, carrying: carrying, trashing: self.flights.values.contains(where: { $0.trash }), finger: self.drag?.previousPoint)
        var image: UIImage?
        var art: UIImage?
        var pose: Pose?
        self.overlay.frame = host.bounds
        self.overlay.layer.mask = nil
        if let drag {
            image = self.media[drag.gift.address]?.first?.image
            art = self.media[drag.gift.address]?.first?.art
            pose = self.dragPose(drag, now: now)
        } else if var play = self.play, let sticker = self.placements.first(where: { $0.gift.address == play.id }),
                  let media = self.media[play.id], var value = self.pose(sticker) {
            let up: CGFloat
            if let ended = play.ended {
                up = 1 - Self.ease((now - ended) / 0.34)
                if now - ended >= 0.34 {
                    if self.hold != nil { self.play = Play(id: play.id, start: now, image: media.first?.image) }
                    else { self.play = nil; self.sync() }
                }
            } else {
                up = Self.ease((now - play.start) / 0.22)
                if !play.requested && now - play.start >= play.head {
                    let id = play.id, start = play.start
                    let head = play.head
                    play.requested = media.frame(at: head) { [weak self] frame in
                        guard let self, var current = self.play, current.id == id, current.start == start else { return }
                        current.requested = false
                        if let frame { current.image = frame.image }
                        current.head = head + 1.0 / 30.0
                        if current.head >= media.duration || frame == nil { current.ended = CACurrentMediaTime() }
                        self.play = current
                    }
                }
                self.play = play
            }
            value.side *= 1 + 0.22 * up
            value.lift = 0.5 * up
            let fadeIn = min(1, (now - play.start) / 0.14)
            let fadeOut = play.ended.map { (0.34 - (now - $0)) / 0.14 } ?? 1
            value.opacity = CGFloat(max(0, min(fadeIn, fadeOut)))
            image = play.ended == nil ? play.image : media.first?.image
            pose = value
        }
        if let image, var pose {
            if UIAccessibility.isReduceMotionEnabled { pose.bend = 0; pose.shade = 0; pose.tilt = 0 }
            self.face.bounds = CGRect(x: 0, y: 0, width: pose.side * 1.6, height: pose.side * 1.6)
            self.face.center = pose.center
            var transform = CATransform3DIdentity
            transform.m34 = -1 / max(1, pose.side * 3)
            transform = CATransform3DRotate(transform, pose.angle, 0, 0, 1)
            transform = CATransform3DRotate(transform, pose.tilt * .pi / 180, pose.axis.x, pose.axis.y, 0)
            self.face.layer.transform = transform
            self.face.alpha = pose.opacity
            self.face.update(image: image, art: art, border: pose.border, front: pose.front, bend: pose.bend, shade: pose.shade, lift: pose.lift)
        }
        self.face.isHidden = pose == nil || self.hold != nil
        if self.play != nil { self.sync() }
        self.tickFlights(now: now)
        self.tickStyle(now: now)
        self.holdRealSize.to(self.hold?.resized == true ? 1 : 0)
        for spring in [self.holdPress, self.holdRealSize, self.tapBoop] { spring.step(dt) }
        let liveActive = self.hold != nil || !self.holdPress.resting() || !self.tapBoop.resting()
        if let id = self.liveStickerId, let sticker = self.placements.first(where: { $0.gift.address == id }), liveActive {
            let grow = 0.7 * self.holdPress.value * (1 - 0.9 * min(1, max(0, self.holdRealSize.value)))
            self.card?.setStickerLive([id: .init(angle: CGFloat(sticker.angle), press: min(1, max(0, self.holdPress.value)),
                grow: (1 + grow) * (1 + self.tapBoop.value), image: self.play?.image)])
        } else {
            self.card?.setStickerLive([:]); self.liveStickerId = nil
        }
        if self.drag == nil && self.flights.isEmpty && self.play == nil && !liveActive && self.styleStart == nil && !self.impactActive && !trashActive { self.stopClock() }

    }

    private func tickFlights(now: Double) {
        for (id, initial) in self.flights {
            var flight = initial
            let elapsed = max(0, now - flight.start)
            let contact = flight.thrown ? 0.5 : 0.18
            let travel = flight.peelFirst ? 0.5 : (flight.fast ? 0.32 : 0.44)
            let lead = flight.peelFirst ? 0.225 : 0
            let duration = flight.sticking ? contact + 0.42 + 0.08 : (flight.trash ? 0.34 : (flight.returning ? lead + travel : 0.25))
            var target = flight.to
            if flight.sticking, let sticker = self.placements.first(where: { $0.gift.address == id }), let projected = self.pose(sticker) {
                target = projected
                target.angle = flight.from.angle + atan2(sin(projected.angle - flight.from.angle), cos(projected.angle - flight.from.angle))
            } else if flight.returning, let host, let rect = self.grid?.stickerFrame(address: id, in: host), let cell = self.gridPose(address: id, rect: rect) {
                target = cell
            }
            let a = flight.from
            var pose = a
            if flight.sticking {
                let u = CGFloat(min(1, elapsed / contact))
                let e = flight.thrown ? 1 - pow(1 - u, 3) : Self.ease(elapsed / contact)
                pose = Self.mix(a, target, e)
                if flight.thrown {
                    let dx = target.center.x - a.center.x, dy = target.center.y - a.center.y
                    let length = max(1, hypot(dx, dy)), direction: CGFloat = dx >= 0 ? -1 : 1
                    let bow = min(110, length * 0.32), arc = sin(.pi * u)
                    pose.center.x += -dy / length * bow * direction * arc
                    pose.center.y += (dx / length * bow * direction - bow * 0.5) * arc
                    pose.side *= 1 + 0.12 * arc
                    pose.border = min(1, u * 3); pose.lift = 0.9 * arc
                    let tip = Self.ease(Double((u - 0.6) / 0.4))
                    pose.bend = 0.75 * tip; pose.shade = tip
                } else {
                    pose.border = a.border + (1 - a.border) * e
                    pose.tilt = a.tilt * (1 - e); pose.axis = a.axis
                    pose.lift = a.lift * (1 - e)
                    pose.bend = 0.75 * e; pose.shade = e
                }
                pose.front = Self.ease((elapsed - contact) / 0.42)
                if elapsed >= contact + 0.42 { pose.bend = 0; pose.shade = 0 }
                if elapsed >= contact && !flight.contacted {
                    flight.contacted = true
                    self.flights[id] = flight
                    self.updateStyle()
                    if let card, let host {
                        card.stickerImpact(at: card.stickerSurface.convert(target.center, from: host), thrown: flight.thrown)
                        self.impactActive = true
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
                if elapsed >= contact + 0.42 && !flight.handedOff {
                    flight.handedOff = true
                    self.flights[id] = flight
                    self.sync()
                }
            } else if flight.trash {
                let u = CGFloat(min(1, elapsed / duration)), e = u * u, w = 1 - e
                let c = CGPoint(x: (a.center.x + target.center.x) / 2, y: min(a.center.y, target.center.y) - 26)
                pose.center = CGPoint(x: w*w*a.center.x + 2*w*e*c.x + e*e*target.center.x,
                    y: w*w*a.center.y + 2*w*e*c.y + e*e*target.center.y)
                pose.side = a.side * (1 - 0.85 * e); pose.lift = a.lift * (1 - u)
                pose.angle = a.angle + 0.9 * e; pose.opacity = min(1, (1 - u) / 0.18)
            } else if flight.returning {
                let u = CGFloat(min(1, max(0, (elapsed - lead) / travel)))
                let e = flight.peelFirst ? (u < 0.5 ? 2*u*u : 1 - 2*(1-u)*(1-u)) : 1 - (1-u)*(1-u)
                let distance = hypot(target.center.x-a.center.x, target.center.y-a.center.y)
                let c = CGPoint(x: (a.center.x+target.center.x)/2, y: (a.center.y+target.center.y)/2 - min(90, distance*0.28))
                let w = 1-e, arc = sin(.pi*e)
                pose = Self.mix(a, target, e)
                pose.center = CGPoint(x: w*w*a.center.x+2*w*e*c.x+e*e*target.center.x, y: w*w*a.center.y+2*w*e*c.y+e*e*target.center.y)
                pose.side *= 1+0.05*arc; pose.angle = a.angle*(1-e); pose.lift = 0.8*arc
                pose.border = min(1, max(0, 1-(e-0.35)/0.4))*a.border
                let raise = Self.ease((elapsed-lead)/0.26)
                if flight.peelFirst && raise < 1 {
                    pose.front = 1-Self.ease(elapsed/0.3); pose.bend = 0.75*(1-raise); pose.shade = 1-raise
                } else {
                    let tip = Self.ease(Double((u-0.52)/0.14)), lay = Self.ease(Double((u-0.66)/0.34))
                    pose.front = lay; pose.bend = lay < 1 ? 0.375*tip : 0; pose.shade = lay < 1 ? 0.5*tip : 0
                }
                let k = min(1, max(0, (u-0.62)/0.38))
                self.grid?.setStickerReturnScale(address: id, scale: 1-0.022*sin(.pi*k))
            } else {
                pose = Self.mix(a, target, CGFloat(min(1, elapsed/duration)))
                pose.opacity = 1-CGFloat(min(1, elapsed/duration))
            }
            self.flights[id] = flight
            let view = self.flightViews[id] ?? WalletStickerWaveView(frame: .zero)
            if view.superview == nil { self.overlay.addSubview(view); self.flightViews[id] = view }
            if let frame = self.media[id]?.first { self.render(view, frame: frame, pose: pose) }
            if flight.sticking, elapsed > contact, let card {
                let shape = CAShapeLayer(), surface = card.stickerSurface, path = UIBezierPath()
                for (i, point) in [CGPoint.zero, CGPoint(x: surface.bounds.width, y: 0), CGPoint(x: surface.bounds.width, y: surface.bounds.height), CGPoint(x: 0, y: surface.bounds.height)].enumerated() {
                    let p = surface.convert(point, to: view)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.close(); shape.path = path.cgPath; view.layer.mask = shape
            } else { view.layer.mask = nil }
            if elapsed >= duration {
                self.flights.removeValue(forKey: id); self.flightViews.removeValue(forKey: id)?.removeFromSuperview()
                self.grid?.setStickerReturnScale(address: id, scale: 1)
                if flight.trash { self.trash.gulp() }
                self.sync()
            }
        }
    }

    private func render(_ view: WalletStickerWaveView, frame: WalletGiftStickerFrame, pose: Pose) {
        view.bounds = CGRect(x: 0, y: 0, width: pose.side * 1.6, height: pose.side * 1.6)
        view.center = pose.center; view.alpha = pose.opacity
        var transform = CATransform3DIdentity
        transform.m34 = -1 / max(1, pose.side * 3)
        transform = CATransform3DRotate(transform, pose.angle, 0, 0, 1)
        transform = CATransform3DRotate(transform, pose.tilt * .pi / 180, pose.axis.x, pose.axis.y, 0)
        view.layer.transform = transform
        view.update(image: frame.image, art: frame.art, border: pose.border, front: pose.front,
            bend: UIAccessibility.isReduceMotionEnabled ? 0 : pose.bend, shade: pose.shade, lift: pose.lift)
    }

    private func stylePattern(_ style: WalletContext.CardGiftStyle?) -> UIImage? {
        self.media.values.first(where: { $0.style == style })?.patternImage
    }

    private func updateStyle() {
        let source = self.placements.last(where: { $0.style != nil })
        let target = source?.style
        if let source, let flight = self.flights[source.gift.address], flight.sticking && !flight.contacted {
            // Persist at menu selection, reveal only when this gift touches the card.
            return
        }
        if (self.styleStart == nil || target != self.styleTo), let source, let size = self.card?.stickerSurface.bounds.size {
            self.styleOrigin = CGPoint(x: CGFloat(source.x) * size.width, y: CGFloat(source.y) * size.height)
        }
        if target != self.styleTo {
            self.styleFrom = self.styleTo; self.styleTo = target
            self.styleStart = self.visible ? CACurrentMediaTime() : nil
            if self.styleStart != nil { self.startClock() }
        }
        if self.styleStart == nil { self.card?.setGiftStyle(from: nil, to: target, origin: self.styleOrigin, progress: 1, pattern: self.stylePattern(target)) }
    }

    private func tickStyle(now: Double) {
        guard let start = self.styleStart else { return }
        let progress = min(1, (now - start) / (self.styleTo == nil ? 0.45 : 1.05))
        self.card?.setGiftStyle(from: self.styleFrom, to: self.styleTo, origin: self.styleOrigin, progress: progress, pattern: self.stylePattern(self.styleTo ?? self.styleFrom))
        if progress >= 1 { self.styleStart = nil; self.styleFrom = self.styleTo }
    }

    private static func ease(_ value: Double) -> CGFloat {
        let t = CGFloat(max(0, min(1, value)))
        return t * t * (3 - 2 * t)
    }
    private static func mix(_ a: Pose, _ b: Pose, _ t: CGFloat) -> Pose {
        return Pose(center: CGPoint(x: a.center.x + (b.center.x - a.center.x) * t, y: a.center.y + (b.center.y - a.center.y) * t),
            side: a.side + (b.side - a.side) * t, angle: a.angle + (b.angle - a.angle) * t,
            opacity: a.opacity + (b.opacity - a.opacity) * t)
    }
}

/// Tracks both fingers without letting a long-press recognizer end when the
/// original finger lifts. The timer only claims a touch on an eligible gift.
final class WalletGiftStickerGesture: UIGestureRecognizer {
    var delayAtPoint: ((CGPoint) -> TimeInterval?)?
    var began: ((CGPoint) -> Bool)?
    var moved: (([CGPoint]) -> Void)?
    var finished: ((Bool) -> Void)?
    private var touches: [UITouch] = []
    private var timer: Timer?
    private var origin: CGPoint = .zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        self.touches.append(contentsOf: touches.sorted { $0.timestamp < $1.timestamp })
        if self.state == .began || self.state == .changed {
            self.report()
        } else if self.timer == nil, let touch = self.touches.first, let view = self.view {
            let point = touch.location(in: view)
            guard let delay = self.delayAtPoint?(point) else { self.state = .failed; return }
            self.origin = point
            let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                guard let self, self.state == .possible, let touch = self.touches.first else { return }
                self.timer = nil
                if self.began?(touch.location(in: self.view)) == true {
                    self.state = .began
                    self.report()
                } else {
                    self.state = .failed
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .possible {
            if let point = self.touches.first?.location(in: self.view), hypot(point.x - self.origin.x, point.y - self.origin.y) > 10 {
                self.timer?.invalidate()
                self.timer = nil
                self.state = .failed
            }
        } else {
            self.state = .changed
            self.report()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        let active = self.state == .began || self.state == .changed
        if active { self.report() }
        self.touches.removeAll { touches.contains($0) }
        if self.touches.isEmpty {
            self.timer?.invalidate()
            self.timer = nil
            if active { self.finished?(false) }
            self.state = active ? .ended : .failed
        } else if active {
            self.report()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        self.cancel()
    }

    func cancel() {
        self.timer?.invalidate()
        self.timer = nil
        if self.state == .began || self.state == .changed {
            self.finished?(true)
            self.state = .cancelled
        } else if self.state == .possible {
            self.state = .failed
        }
    }

    override func reset() {
        super.reset()
        self.timer?.invalidate()
        self.timer = nil
        self.touches.removeAll()
    }

    private func report() {
        self.moved?(self.touches.prefix(2).map { $0.location(in: self.view) })
    }

    deinit { self.timer?.invalidate() }
}
