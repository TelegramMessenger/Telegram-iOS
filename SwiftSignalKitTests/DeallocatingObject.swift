import Foundation

internal class DeallocatingObject : CustomStringConvertible {
    private var deallocated: UnsafeMutablePointer<Bool>
    
    init(deallocated: UnsafeMutablePointer<Bool>) {
        self.deallocated = deallocated
    }
    
    deinit {
        self.deallocated.memory = true
    }
    
    var description: String {
        get {
            return ""
        }
    }
}
