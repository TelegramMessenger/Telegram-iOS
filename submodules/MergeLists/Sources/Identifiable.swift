import Foundation

public protocol Identifiable {
    associatedtype T: Hashable
    var stableId: T { get }
}
