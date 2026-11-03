import Foundation
import CoreMotion

final class QrStudioDeviceTilt {
    private let motion = CMMotionManager()
    private var isRunning = false
    private var base: SIMD3<Double>?
    private var tilt = SIMD2<Double>(0.0, 0.0)
    private var lastTime: Double?

    func start() {
        guard !self.isRunning, self.motion.isDeviceMotionAvailable else {
            return
        }
        self.isRunning = true
        self.motion.deviceMotionUpdateInterval = 1.0 / 60.0
        self.motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else {
                return
            }
            self.feed(SIMD3(gravity.x, gravity.y, gravity.z))
        }
    }

    func stop() {
        guard self.isRunning else {
            return
        }
        self.isRunning = false
        self.motion.stopDeviceMotionUpdates()
        self.base = nil
        self.tilt = SIMD2(0.0, 0.0)
        self.lastTime = nil
    }

    func value() -> SIMD2<Double> {
        return self.tilt
    }

    private func feed(_ gravity: SIMD3<Double>) {
        let now = QrStudioClock.now
        let dt = min(max(self.lastTime.flatMap { now - $0 } ?? 0.0, 0.0), 0.1)
        self.lastTime = now
        guard let base = self.base else {
            self.base = gravity
            return
        }
        let nextBase = base + (gravity - base) * (1.0 - exp(-dt / 4.0))
        self.base = nextBase
        let target = SIMD2(gravity.x - nextBase.x, gravity.y - nextBase.y)
        self.tilt += (target - self.tilt) * (1.0 - exp(-dt / 0.08))
    }
}
