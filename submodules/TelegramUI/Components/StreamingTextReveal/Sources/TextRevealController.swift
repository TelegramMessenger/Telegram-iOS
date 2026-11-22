import Foundation

public final class TextRevealController {
    private static let velocityTau: Double = 0.12
    private static let gapEwmaAlpha: Double = 0.4
    private static let initialGap: Double = 0.5
    private static let stallFloor: Double = 0.10
    private static let finalizeTime: Double = 0.3
    private static let frameDtCap: Double = 0.05
    private static let initialInputRate: Double = 40.0

    public private(set) var revealedCount: Double
    private var velocity: Double = 0.0
    private var avgInterArrival: Double = TextRevealController.initialGap
    private var lastSampleTime: Double?
    private var lastSampleLength: Int?
    private var predictedNextArrivalTime: Double?
    private var chunkCount: Int = 0
    public private(set) var latestLength: Int
    public private(set) var isFinalizing: Bool = false
    private var lastFrameTime: Double?
    public var durationMultiplier: Double

    public init(initialRevealedCount: Int, initialLength: Int, durationMultiplier: Double = 1.0) {
        self.revealedCount = Double(initialRevealedCount)
        self.latestLength = initialLength
        self.durationMultiplier = max(0.0001, durationMultiplier)
    }

    public var currentGlyphCount: Int {
        return Int(self.revealedCount)
    }

    public func observeUpdate(latestLength: Int, at now: Double) {
        if let lastLen = self.lastSampleLength {
            if latestLength > lastLen {
                if let lastTime = self.lastSampleTime {
                    let interArrival = max(now - lastTime, 0.001)
                    self.avgInterArrival = TextRevealController.gapEwmaAlpha * interArrival
                        + (1.0 - TextRevealController.gapEwmaAlpha) * self.avgInterArrival
                }
                self.lastSampleTime = now
                self.lastSampleLength = latestLength
                self.predictedNextArrivalTime = now + self.avgInterArrival
                self.chunkCount += 1
            } else if latestLength < lastLen {
                self.lastSampleLength = latestLength
            }
        } else {
            self.lastSampleTime = now
            self.lastSampleLength = latestLength
            self.predictedNextArrivalTime = now + self.avgInterArrival
            self.chunkCount += 1
        }
        self.latestLength = latestLength
        if self.revealedCount > Double(latestLength) {
            self.revealedCount = Double(latestLength)
        }
    }

    public func finalize(finalLength: Int) {
        self.latestLength = finalLength
        self.isFinalizing = true
        if self.revealedCount > Double(finalLength) {
            self.revealedCount = Double(finalLength)
        }
    }

    public func tick(now: Double) -> (revealedGlyphCount: Int, isComplete: Bool) {
        let dt = min(now - (self.lastFrameTime ?? now), TextRevealController.frameDtCap)
        let lag = max(0.0, Double(self.latestLength) - self.revealedCount)
        let targetVelocity: Double
        if self.isFinalizing {
            targetVelocity = max(self.velocity, lag / TextRevealController.finalizeTime)
        } else if self.chunkCount < 2 {
            targetVelocity = lag > 0.0 ? TextRevealController.initialInputRate : 0.0
        } else if let predNext = self.predictedNextArrivalTime {
            let timeToNext = max(TextRevealController.stallFloor, predNext - now)
            targetVelocity = lag / timeToNext
        } else {
            targetVelocity = lag > 0.0 ? TextRevealController.initialInputRate : 0.0
        }
        let smoothing = min(1.0, dt / TextRevealController.velocityTau)
        self.velocity += (targetVelocity - self.velocity) * smoothing
        self.revealedCount = min(Double(self.latestLength), self.revealedCount + self.velocity * dt / self.durationMultiplier)
        self.lastFrameTime = now
        let isComplete = self.isFinalizing && self.revealedCount >= Double(self.latestLength)
        return (Int(self.revealedCount), isComplete)
    }
}
