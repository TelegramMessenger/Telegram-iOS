import Foundation

public protocol Identifiable {
    associatedtype T: Hashable
    var stableId: T { get }
}

public struct AnyIdentifiable {
    var stableId: AnyHashable
    
    public init<T>(_ value: T) where T : Identifiable {
        self.stableId = value.stableId
    }
}
