import Foundation

public protocol MediaResourceId {
    var uniqueId: String { get }
    var hashValue: Int { get }
    func isEqual(to: MediaResourceId) -> Bool
}

public struct WrappedMediaResourceId: Hashable {
    public let id: MediaResourceId
    
    public init(_ id: MediaResourceId) {
        self.id = id
    }
    
    public static func ==(lhs: WrappedMediaResourceId, rhs: WrappedMediaResourceId) -> Bool {
        return lhs.id.isEqual(to: rhs.id)
    }
    
    public var hashValue: Int {
        return self.id.hashValue
    }
}

public func anyHashableFromMediaResourceId(_ id: MediaResourceId) -> AnyHashable {
    return AnyHashable(WrappedMediaResourceId(id))
}
