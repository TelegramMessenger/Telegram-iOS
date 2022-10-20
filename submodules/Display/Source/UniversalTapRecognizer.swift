import UIKit
import UIKit.UIGestureRecognizerSubclass

private class TimerTargetWrapper: NSObject {
    let f: () -> Void
    
    init(_ f: @escaping () -> Void) {
        self.f = f
    }
    
    @objc func timerEvent() {
        self.f()
    }
}

class UniversalTapRecognizer: UITapGestureRecognizer {
    private let tapMaxDelay: Double = 0.15
    
    private var timer: Timer?
    
    deinit {
        self.timer?.invalidate()
    }
    
    override func reset() {
        super.reset()
        
        self.timer?.invalidate()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let timer = Timer(timeInterval: self.tapMaxDelay, target: TimerTargetWrapper({ [weak self] in
            if let strongSelf = self {
                if strongSelf.state != .ended {
                    strongSelf.state = .failed
                }
            }
        }), selector: #selector(TimerTargetWrapper.timerEvent), userInfo: nil, repeats: false)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
