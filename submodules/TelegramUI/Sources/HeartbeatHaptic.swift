import Foundation
import Display
import SwiftSignalKit

protocol EmojiHaptic {
    var enabled: Bool { get set }
    var active: Bool { get }
    
    func start(time: Double)
}

final class HeartbeatHaptic: EmojiHaptic {
    private var hapticFeedback = HapticFeedback()
    private var timer: SwiftSignalKit.Timer?
    private var time: Double = 0.0
    var enabled: Bool = false {
        didSet {
            if !self.enabled {
                self.reset()
            }
        }
    }
    
    var active: Bool {
        return self.timer != nil
    }
    
    private func reset() {
        if let timer = self.timer {
            self.time = 0.0
            timer.invalidate()
            self.timer = nil
        }
    }
    
    private func beat(time: Double) {
        let epsilon = 0.1
        if fabs(0.0 - time) < epsilon || fabs(1.0 - time) < epsilon || fabs(2.0 - time) < epsilon {
            self.hapticFeedback.impact(.medium)
        } else if fabs(0.2 - time) < epsilon || fabs(1.2 - time) < epsilon || fabs(2.2 - time) < epsilon {
            self.hapticFeedback.impact(.light)
        }
    }
    
    func start(time: Double) {
        self.hapticFeedback.prepareImpact()
        
        if time > 2.0 {
            return
        }

        var startTime: Double = 0.0
        var delay: Double = 0.0
        
        if time > 0.0 {
            if time <= 1.0 {
                startTime = 1.0
            } else if time <= 2.0 {
                startTime = 2.0
            }
        }
        
        delay = max(0.0, startTime - time)
        
        let block = { [weak self] in
            guard let strongSelf = self, strongSelf.enabled else {
                return
            }
            
            strongSelf.time = startTime
            strongSelf.beat(time: startTime)
            strongSelf.timer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: { [weak self] in
                guard let strongSelf = self, strongSelf.enabled else {
                    return
                }
                strongSelf.time += 0.2
                strongSelf.beat(time: strongSelf.time)
                
                if strongSelf.time > 2.2 {
                    strongSelf.reset()
                    strongSelf.time = 0.0
                    strongSelf.timer?.invalidate()
                    strongSelf.timer = nil
                }
                
                }, queue: Queue.mainQueue())
            strongSelf.timer?.start()
        }
        
        if delay > 0.0 {
            Queue.mainQueue().after(delay, block)
        } else {
            block()
        }
    }
}
