import Foundation
import CoreGraphics

struct QrStudioSpring {
    var duration: Double
    var bounce: Double
}

final class QrStudioSheetMotion {
    struct Sample: Equatable {
        var rise: CGFloat
        var spread: CGFloat
        var pull: CGFloat
        var search: CGFloat
        var height: CGFloat = 0.0

        static func openness(rise: CGFloat, pull: CGFloat, travel: CGFloat) -> CGFloat {
            let r = min(max(rise, 0.0), 1.08)
            guard travel > 0.0 else {
                return r
            }
            return r * min(max(1.0 - pull / travel, 0.0), 1.0)
        }

        func openness(travel: CGFloat) -> CGFloat {
            return Sample.openness(rise: self.rise, pull: self.pull, travel: travel)
        }
    }

    enum Key: Hashable {
        case rise
        case spread
        case pull
        case search
        case height
    }

    private struct Channel {
        var value: CGFloat
        var velocity: CGFloat = 0.0
        var target: CGFloat
        var spring: QrStudioSpring
    }

    static let riseOpen = QrStudioSpring(duration: 0.42, bounce: 0.1)
    static let spreadOpen = QrStudioSpring(duration: 0.36, bounce: 0.04)
    static let spreadClose = QrStudioSpring(duration: 0.3, bounce: 0.0)
    static let riseClose = QrStudioSpring(duration: 0.34, bounce: 0.04)
    static let pullBack = QrStudioSpring(duration: 0.45, bounce: 0.15)
    static let keyboard = QrStudioSpring(duration: 0.38, bounce: 0.0)
    static let tabHeight = QrStudioSpring(duration: 0.42, bounce: 0.0)

    private(set) var rise: CGFloat = 0.0
    private(set) var spread: CGFloat = 0.0
    private(set) var pull: CGFloat = 0.0
    private(set) var search: CGFloat = 0.0
    private(set) var height: CGFloat = 0.0
    private(set) var isOpen = false
    private(set) var isDragging = false

    private var channels: [Key: Channel] = [:]

    var isSettled: Bool {
        return self.channels.isEmpty
    }

    var sample: Sample {
        return Sample(rise: self.rise, spread: self.spread, pull: self.pull, search: self.search, height: self.height)
    }

    func openness(travel: CGFloat) -> CGFloat {
        return self.sample.openness(travel: travel)
    }

    func copy() -> QrStudioSheetMotion {
        let result = QrStudioSheetMotion()
        result.rise = self.rise
        result.spread = self.spread
        result.pull = self.pull
        result.search = self.search
        result.height = self.height
        result.isOpen = self.isOpen
        result.isDragging = self.isDragging
        result.channels = self.channels
        return result
    }

    func simulate(dt: Double, maxDuration: Double) -> [Sample] {
        let motion = self.copy()
        var samples: [Sample] = [motion.sample]
        var time = 0.0
        while !motion.isSettled && time < maxDuration {
            motion.step(dt)
            time += dt
            samples.append(motion.sample)
        }
        return samples
    }

    func adopt(_ value: Sample, velocity: Sample) {
        for key in Array(self.channels.keys) {
            guard var channel = self.channels[key] else {
                continue
            }
            switch key {
            case .rise:
                channel.value = value.rise
                channel.velocity = velocity.rise
            case .spread:
                channel.value = value.spread
                channel.velocity = velocity.spread
            case .pull:
                channel.value = value.pull
                channel.velocity = velocity.pull
            case .search:
                channel.value = value.search
                channel.velocity = velocity.search
            case .height:
                channel.value = value.height
                channel.velocity = velocity.height
            }
            self.channels[key] = channel
        }
        self.rise = value.rise
        self.spread = value.spread
        self.pull = value.pull
        self.search = value.search
        self.height = value.height
        self.step(0.0)
    }

    func settle(at value: Sample) {
        self.channels.removeAll()
        self.rise = value.rise
        self.spread = value.spread
        self.pull = value.pull
        self.search = value.search
        self.height = value.height
    }

    func setHeight(_ height: CGFloat, animated: Bool) {
        if self.channels[.height] == nil && self.height == height {
            return
        }
        if animated && self.height > 0.0 {
            self.animate(.height, to: height, QrStudioSheetMotion.tabHeight)
        } else {
            self.set(.height, height)
        }
    }

    func open(animated: Bool) {
        self.isOpen = true
        guard animated else {
            self.channels.removeValue(forKey: .rise)
            self.channels.removeValue(forKey: .spread)
            self.channels.removeValue(forKey: .pull)
            self.rise = 1.0
            self.spread = 1.0
            self.pull = 0.0
            return
        }
        self.animate(.rise, to: 1.0, QrStudioSheetMotion.riseOpen)
        self.animate(.spread, to: 1.0, QrStudioSheetMotion.spreadOpen)
        self.animate(.pull, to: 0.0, QrStudioSheetMotion.pullBack)
    }

    func close(velocity: CGFloat, travel: CGFloat) {
        guard self.isOpen else {
            return
        }
        self.isOpen = false
        self.isDragging = false
        let riseVelocity: CGFloat? = travel > 1.0 && velocity != 0.0 ? -velocity / travel : nil
        self.animate(.spread, to: 0.0, QrStudioSheetMotion.spreadClose)
        self.animate(.rise, to: 0.0, QrStudioSheetMotion.riseClose, velocity: riseVelocity)
    }

    func drag(_ translation: CGFloat) {
        guard self.isOpen else {
            return
        }
        self.isDragging = true
        let pull = translation >= 0.0 ? translation : -24.0 * (1.0 - exp(translation / 90.0))
        self.set(.pull, pull)
    }

    func release(velocity: CGFloat, travel: CGFloat) {
        guard self.isOpen else {
            return
        }
        self.isDragging = false
        if self.pull > 110.0 || (velocity > 700.0 && self.pull > 12.0) {
            self.close(velocity: velocity, travel: travel)
        } else {
            self.animate(.pull, to: 0.0, QrStudioSheetMotion.pullBack, velocity: velocity)
        }
    }

    func setSearch(_ isActive: Bool) {
        let target: CGFloat = isActive ? 1.0 : 0.0
        if self.channels[.search] == nil && self.search == target {
            return
        }
        self.animate(.search, to: target, QrStudioSheetMotion.keyboard)
    }

    func step(_ dt: Double) {
        let dt = min(max(dt, 0.0), 0.05)
        var riseSettled = false
        for key in Array(self.channels.keys) {
            guard var channel = self.channels[key] else {
                continue
            }
            QrStudioSheetMotion.advance(&channel, dt)
            let scale: CGFloat = key == .pull || key == .height ? 0.2 : 0.0005
            if abs(channel.value - channel.target) < scale && abs(channel.velocity) < scale * 20.0 {
                self.write(key, channel.target)
                self.channels.removeValue(forKey: key)
                if key == .rise {
                    riseSettled = true
                }
            } else {
                self.write(key, channel.value)
                self.channels[key] = channel
            }
        }
        if riseSettled && !self.isOpen {
            self.set(.pull, 0.0)
        }
    }

    private func value(_ key: Key) -> CGFloat {
        switch key {
        case .rise:
            return self.rise
        case .spread:
            return self.spread
        case .pull:
            return self.pull
        case .search:
            return self.search
        case .height:
            return self.height
        }
    }

    private func write(_ key: Key, _ value: CGFloat) {
        switch key {
        case .rise:
            self.rise = value
        case .spread:
            self.spread = value
        case .pull:
            self.pull = value
        case .search:
            self.search = value
        case .height:
            self.height = value
        }
    }

    private func set(_ key: Key, _ value: CGFloat) {
        self.channels.removeValue(forKey: key)
        self.write(key, value)
    }

    private func animate(_ key: Key, to target: CGFloat, _ spring: QrStudioSpring, velocity: CGFloat? = nil) {
        var channel = self.channels[key] ?? Channel(value: self.value(key), target: target, spring: spring)
        channel.target = target
        channel.spring = spring
        if let velocity {
            channel.velocity = velocity
        }
        self.channels[key] = channel
    }

    private static func advance(_ channel: inout Channel, _ dt: Double) {
        let w0 = 2.0 * Double.pi / max(channel.spring.duration, 0.01)
        let zeta = min(max(1.0 - channel.spring.bounce, 0.0), 1.0)
        let x0 = Double(channel.value - channel.target)
        let v0 = Double(channel.velocity)
        let x: Double
        let v: Double
        if zeta > 0.9999 {
            let e = exp(-w0 * dt)
            x = (x0 + (v0 + w0 * x0) * dt) * e
            v = (v0 - w0 * (v0 + w0 * x0) * dt) * e
        } else {
            let a = zeta * w0
            let wd = w0 * (1.0 - zeta * zeta).squareRoot()
            let e = exp(-a * dt)
            let cs = cos(wd * dt)
            let sn = sin(wd * dt)
            x = e * (x0 * cs + (v0 + a * x0) / wd * sn)
            v = e * (v0 * cs - (w0 * w0 * x0 + a * v0) / wd * sn)
        }
        channel.value = channel.target + CGFloat(x)
        channel.velocity = CGFloat(v)
    }
}

struct QrStudioSheetGeometry: Equatable {
    static let searchVisible: CGFloat = 146.0
    static let topRadius: CGFloat = 27.0

    let screen: CGSize
    let capsule: CGRect
    let sheet: CGRect
    let bottomRadius: CGFloat

    init(screen: CGSize, safeBottom: CGFloat, capsuleWidth: CGFloat, bottomCornerRadius: CGFloat) {
        self.screen = screen
        let height = (screen.height * 342.0 / 874.0).rounded()
        self.sheet = CGRect(x: 0.0, y: screen.height - height, width: screen.width, height: height)
        self.capsule = CGRect(x: ((screen.width - capsuleWidth) / 2.0).rounded(.down), y: screen.height - safeBottom - 44.0, width: capsuleWidth, height: 44.0)
        self.bottomRadius = bottomCornerRadius
    }

    var travel: CGFloat {
        return self.capsule.minY - self.sheet.minY
    }

    func searchLift(keyboard: CGFloat) -> CGFloat {
        return keyboard > 0.0 ? max(0.0, keyboard + QrStudioSheetGeometry.searchVisible - self.sheet.height) : 0.0
    }

    func sheetFrame(height: CGFloat) -> CGRect {
        guard height > 0.0 else {
            return self.sheet
        }
        return CGRect(x: self.sheet.minX, y: self.screen.height - height, width: self.sheet.width, height: height)
    }

    func frame(rise: CGFloat, spread: CGFloat, pull: CGFloat, lift: CGFloat, height: CGFloat = 0.0) -> CGRect {
        let target = self.sheetFrame(height: height).offsetBy(dx: 0.0, dy: pull - lift)
        let top = self.capsule.minY + (target.minY - self.capsule.minY) * rise
        let bottom = self.capsule.maxY + (target.maxY - self.capsule.maxY) * rise
        let width = self.capsule.width + (self.sheet.width - self.capsule.width) * spread
        let mid = self.capsule.midX + (self.sheet.midX - self.capsule.midX) * spread
        return CGRect(x: mid - width / 2.0, y: top, width: max(width, 1.0), height: max(bottom - top, 1.0))
    }

    func corners(rise: CGFloat, frame: CGRect) -> (top: CGFloat, bottom: CGFloat) {
        let k = QrStudioSheetGeometry.smooth(rise / 0.6)
        let radius = self.capsule.height / 2.0
        let limit = min(frame.width / 2.0, frame.height / 2.0)
        return (
            min(radius + (QrStudioSheetGeometry.topRadius - radius) * k, limit),
            min(radius + (self.bottomRadius - radius) * k, limit)
        )
    }

    static func phases(grown: CGFloat) -> (icons: CGFloat, glass: CGFloat, background: CGFloat, content: CGFloat) {
        return (
            1.0 - self.smooth(grown / 0.1),
            1.0 - self.smooth((grown - 0.04) / 0.18),
            self.smooth((grown - 0.02) / 0.18),
            self.smooth((grown - 0.1) / 0.3)
        )
    }

    static func raise(card: CGFloat, groupY: CGFloat, panelTop: CGFloat, gap: CGFloat) -> (fit: CGFloat, lift: CGFloat) {
        let below: CGFloat = 40.0
        let fit = min(1.0, max(0.4, (panelTop - gap - below - 108.0) / card))
        let top = panelTop - gap - below - card * fit
        let restTop = groupY - (card + below) / 2.0
        return (fit, min(0.0, top - restTop - card * (1.0 - fit)))
    }

    private static func smooth(_ value: CGFloat) -> CGFloat {
        let x = min(1.0, max(0.0, value))
        return x * x * (3.0 - 2.0 * x)
    }
}
