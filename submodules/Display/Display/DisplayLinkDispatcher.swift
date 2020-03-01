import Foundation
import UIKit

public class DisplayLinkDispatcher: NSObject {
    private var displayLink: CADisplayLink!
    private var blocksToDispatch: [() -> Void] = []
    private let limit: Int
    
    public init(limit: Int = 0) {
        self.limit = limit
        
        super.init()
        
        if #available(iOS 10.0, *) {
            //self.displayLink.preferredFramesPerSecond = 60
        } else {
            self.displayLink = CADisplayLink(target: self, selector: #selector(self.run))
            self.displayLink.isPaused = true
            self.displayLink.add(to: RunLoop.main, forMode: .common)
        }
    }
    
    public func dispatch(f: @escaping () -> Void) {
        if self.displayLink == nil {
            if Thread.isMainThread {
                f()
            } else {
                DispatchQueue.main.async(execute: f)
            }
        } else {
            self.blocksToDispatch.append(f)
            self.displayLink.isPaused = false
        }
    }
    
    @objc func run() {
        for _ in 0 ..< (self.limit == 0 ? 1000 : self.limit) {
            if self.blocksToDispatch.count == 0 {
                self.displayLink.isPaused = true
                break
            } else {
                let f = self.blocksToDispatch.removeFirst()
                f()
            }
        }
    }
}
