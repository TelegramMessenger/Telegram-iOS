import Foundation

internal class DeallocatingObject : Printable {
    private var deallocated: UnsafeMutablePointer<Bool>
    
    init(deallocated: UnsafeMutablePointer<Bool>) {
        self.deallocated = deallocated
    }
    
    deinit {
        self.deallocated.memory = true
    }
    
    public var description: String {
        get {
            return ""
        }
    }
}
