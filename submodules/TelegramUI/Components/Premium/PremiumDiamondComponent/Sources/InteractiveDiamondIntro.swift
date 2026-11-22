import Foundation
import CoreGraphics

public struct InteractiveDiamondIntro {
    public static let delay = 0.18
    public static let duration = 1.2
    private static let omega = 2.0 * Double.pi / 0.9

    public let progress: CGFloat
    public var lift: CGFloat { -48.0 * 4.0 * self.progress * (1.0 - self.progress) }
    public var scale: CGFloat { self.scale(from: 6.0) }

    public func scale(from initialScale: CGFloat, allowsOvershoot: Bool = false) -> CGFloat {
        let remaining = 1.0 - self.progress
        let offset: CGFloat
        if allowsOvershoot && remaining < 0.0 {
            offset = -pow(-remaining, 1.25)
        } else {
            offset = pow(max(0.0, remaining), 1.25)
        }
        return 1.0 + (initialScale - 1.0) * offset
    }

    public init(progress: CGFloat) {
        self.progress = progress
    }

    public init(time: Double?, speed: Double = 1.0, damping: Double = 0.8) {
        let duration = Self.delay + (Self.duration - Self.delay) / speed
        guard let time, time < duration else {
            self.progress = 1.0
            return
        }
        let t = max(time - Self.delay, 0.0) * speed
        let decay = damping * Self.omega
        let frequency = Self.omega * sqrt(1.0 - damping * damping)
        self.progress = CGFloat(1.0 - exp(-decay * t) * (cos(frequency * t) + (decay - 1.2) / frequency * sin(frequency * t)))
    }
}
