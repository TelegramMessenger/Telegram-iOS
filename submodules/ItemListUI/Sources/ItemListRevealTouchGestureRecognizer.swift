import UIKit

/// A public-API recognizer with the reference's 25-point horizontal hysteresis.
/// It fails early on vertical movement so the hosting scroll view can take over.
final class ItemListRevealTouchGestureRecognizer: UIGestureRecognizer {
    var canBegin: ((CGPoint, CGFloat) -> Bool)?
    var horizontalIntent: (() -> Void)?
    private(set) var translation: CGFloat = 0
    private(set) var horizontalVelocity: CGFloat = 0
    private(set) var initialDirection: CGFloat = 0
    private(set) var location: CGPoint = .zero
    private var origin: CGPoint = .zero
    private var recognizedOrigin: CGFloat = 0
    private var samples: [(time: TimeInterval, x: CGFloat)] = []
    private var trackedTouch: UITouch?
    private var reportedHorizontalIntent = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil, touches.count == 1, let touch = touches.first else {
            state = state == .began || state == .changed ? .cancelled : .failed
            return
        }
        trackedTouch = touch
        origin = touch.location(in: view); location = origin
        recognizedOrigin = origin.x
        samples = [(touch.timestamp, origin.x)]
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        for point in event.coalescedTouches(for: touch) ?? [touch] { sample(point) }
        let dx = location.x - origin.x, dy = location.y - origin.y
        if state == .possible {
            if abs(dy) > 10 && abs(dy) >= abs(dx) { state = .failed; return }
            // Telegram's context gesture permits simultaneous non-pan gestures.
            // Cancel its pending long press on movement, without beginning the
            // reveal before the reference's 25-point recognition threshold.
            if !reportedHorizontalIntent && abs(dx) > 10 && abs(dx) > abs(dy) && canBegin?(origin, dx < 0 ? -1 : 1) != false {
                reportedHorizontalIntent = true
                horizontalIntent?()
            }
            if abs(dx) >= 25.0 && abs(dx) > abs(dy) {
                initialDirection = dx < 0 ? -1 : 1
                if let canBegin = self.canBegin, !canBegin(self.origin, self.initialDirection) {
                    self.state = .failed
                    return
                }
                // UIPan's observed translation starts at zero after its hysteresis.
                recognizedOrigin = origin.x + (dx < 0 ? -1 : 1) * 25.0
                translation = location.x - recognizedOrigin
                state = .began
            }
        } else if state == .began || state == .changed {
            translation = location.x - recognizedOrigin
            state = .changed
        }
    }

    private func sample(_ touch: UITouch) {
        let point = touch.location(in: view)
        location = point
        samples.append((touch.timestamp, point.x))
        samples.removeAll { touch.timestamp - $0.time > 0.08 }
        // Least-squares velocity tolerates coalesced samples and uneven event intervals.
        let count = CGFloat(samples.count)
        guard count > 1 else { return }
        let firstTime = samples[0].time
        let meanT = samples.reduce(0.0) { $0 + ($1.time - firstTime) } / Double(count)
        let meanX = samples.reduce(CGFloat.zero) { $0 + $1.x } / count
        var numerator = 0.0, denominator = 0.0
        for s in samples {
            let t = s.time - firstTime - meanT
            numerator += t * Double(s.x - meanX); denominator += t * t
        }
        if denominator > 0.000001 { horizontalVelocity = numerator / denominator }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        // UIPan retains the last movement velocity while a stationary finger is
        // held. The reference's ended callback confirms this; don't zero on lift.
        state = state == .began || state == .changed ? .ended : .failed
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = state == .began || state == .changed ? .cancelled : .failed
    }
    override func reset() {
        super.reset(); trackedTouch = nil; samples.removeAll(keepingCapacity: true)
        translation = 0; horizontalVelocity = 0; initialDirection = 0; location = .zero
        reportedHorizontalIntent = false
    }
}
