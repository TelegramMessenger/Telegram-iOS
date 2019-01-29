import Foundation
import UIKit
import SwiftSignalKit

final class ThrottledValue<T: Equatable> {
    private var value: T
    private let interval: Double
    private var previousSetTimestamp: Double
    private let valuePromise: ValuePromise<T>
    private var timer: SwiftSignalKit.Timer?
    
    init(value: T, interval: Double) {
        self.value = value
        self.interval = interval
        self.previousSetTimestamp = CACurrentMediaTime()
        self.valuePromise = ValuePromise(value)
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func set(value: T) {
        guard self.value != value else {
            return
        }
        self.timer?.invalidate()
        let timestamp = CACurrentMediaTime()
        if timestamp > self.previousSetTimestamp + self.interval {
            self.previousSetTimestamp = timestamp
            self.valuePromise.set(value)
        } else {
            let timer = SwiftSignalKit.Timer(timeout: self.interval, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.valuePromise.set(strongSelf.value)
                }
            }, queue: Queue.mainQueue())
            self.timer = timer
            timer.start()
        }
    }
    
    func get() -> Signal<T, NoError> {
        return self.valuePromise.get()
    }
}
