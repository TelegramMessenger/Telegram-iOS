import Foundation
import AVFoundation
import SwiftSignalKit

extension AVPlayer {
    func fadeVolume(from: Float, to: Float, duration: Float, completion: (() -> Void)? = nil) -> SwiftSignalKit.Timer? {
        self.volume = from
        guard from != to else { return nil }
        
        let interval: Float = 0.1
        let range = to - from
        let step = (range * interval) / duration
        
        func reachedTarget() -> Bool {
            guard self.volume >= 0, self.volume <= 1 else {
                self.volume = to
                return true
            }
            
            if to > from {
                return self.volume >= to
            }
            return self.volume <= to
        }
        
        var invalidateImpl: (() -> Void)?
        let timer = SwiftSignalKit.Timer(timeout: Double(interval), repeat: true, completion: { [weak self] in
            if let self, !reachedTarget() {
                self.volume += step
            } else {
                invalidateImpl?()
                completion?()
            }
        }, queue: Queue.mainQueue())
        invalidateImpl = { [weak timer] in
            timer?.invalidate()
        }
        timer.start()
        return timer
    }
}
