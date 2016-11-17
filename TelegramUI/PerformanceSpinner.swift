import Foundation
import SwiftSignalKit

private final class SpinnerThread: NSObject {
    private var thread: Thread?
    private let condition: NSCondition
    private var workValue: CGFloat = 0
    
    override init() {
        self.condition = NSCondition()
        
        super.init()
        
        let thread = Thread(target: self, selector: #selector(self.entryPoint), object: nil)
        thread.name = "Spinner"
        self.thread = thread
        thread.start()
    }
    
    @objc func entryPoint() {
        while true {
            workValue = workValue + CGFloat(sin(Double(workValue)))
            usleep(100)
        }
    }
    
    func aquire() -> Int {
        return 0
    }
}

//private let atomicSpinner = SpinnerThread()

func performanceSpinnerAcquire() -> Int {
    //return atomicSpinner.aquire()
    return 0
}

func performanceSpinnerRelease(_ index: Int) -> Void {
}
