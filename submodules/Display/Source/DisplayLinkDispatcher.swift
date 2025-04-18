import Foundation
import UIKit

public class DisplayLinkDispatcher: NSObject {
    private var blocksToDispatch: [() -> Void] = []
    private let limit: Int
    
    public init(limit: Int = 0) {
        self.limit = limit
        
        super.init()
    }
    
    public func dispatch(f: @escaping () -> Void) {
        if Thread.isMainThread {
            f()
        } else {
            DispatchQueue.main.async(execute: f)
        }
    }
}
