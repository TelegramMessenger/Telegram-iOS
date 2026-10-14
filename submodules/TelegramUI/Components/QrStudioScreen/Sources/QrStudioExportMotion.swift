import Foundation
import CoreGraphics

enum QrStudioExportMotion {
    static let loop: Double = 5.0
    static let fps: Int = 30

    static var frameCount: Int {
        return Int(self.loop * Double(self.fps))
    }

    static func wobble(hash: Double, at t: Double) -> (dx: CGFloat, dy: CGFloat, degrees: Double) {
        let base = 2.0 * Double.pi * t / self.loop
        let n: Double = hash < 0.5 ? 1.0 : 2.0
        let m: Double = hash < 0.25 || hash > 0.75 ? 1.0 : 2.0
        let direction: Double = qrStudioFract(hash * 43.3) < 0.5 ? -1.0 : 1.0
        let phase = hash * 2.0 * Double.pi
        let radius = 3.0 + 4.0 * qrStudioFract(hash * 31.7)
        let angle = base * n * direction + phase
        let dx = CGFloat(radius * (cos(angle) - cos(phase)))
        let dy = CGFloat(radius * (sin(angle) - sin(phase)))
        let degrees = 4.0 * (sin(base * m + phase) - sin(phase))
        return (dx, dy, degrees)
    }

    static func loopCycles(period: Double) -> Int {
        guard period > 0.0 else {
            return 1
        }
        return max(1, Int((self.loop / period).rounded()))
    }

    static func frameIndex(frameCount: Int, period: Double, phase: Double, at t: Double) -> Int {
        guard frameCount > 1, period > 0.0 else {
            return 0
        }
        let cycles = Double(self.loopCycles(period: period))
        let local = t.truncatingRemainder(dividingBy: self.loop)
        var position = (local / self.loop * cycles + phase).truncatingRemainder(dividingBy: 1.0)
        if position < 0.0 {
            position += 1.0
        }
        if abs(position - 1.0) < 1e-9 {
            position = 0.0
        }
        return min(frameCount - 1, Int(position * Double(frameCount)))
    }

    static func frameStep(frameDuration: Double) -> Int {
        guard frameDuration > 0.0 else {
            return 1
        }
        return max(1, Int((1.0 / frameDuration / Double(self.fps)).rounded()))
    }

    static func phase(hash: Double) -> Double {
        return Double(qrStudioPhaseGroup(hash: hash)) / Double(QrStudioPhasedAnimation.groupCount)
    }
}
