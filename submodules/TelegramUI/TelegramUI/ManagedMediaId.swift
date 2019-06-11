import Foundation

protocol ManagedMediaId {
    var hashValue: Int { get }
    func isEqual(to: ManagedMediaId) -> Bool
}
