import Foundation

public protocol MediaResourceId {
    var uniqueId: String { get }
    var hashValue: Int { get }
    func isEqual(to: MediaResourceId) -> Bool
}

struct WrappedMediaResourceId: Hashable {
    let id: MediaResourceId
    
    init(_ id: MediaResourceId) {
        self.id = id
    }
    
    static func ==(lhs: WrappedMediaResourceId, rhs: WrappedMediaResourceId) -> Bool {
        return lhs.id.isEqual(to: rhs.id)
    }
    
    var hashValue: Int {
        return self.id.hashValue
    }
}

public protocol MediaResource {
    var id: MediaResourceId { get }
    var size: Int? { get }
}

public extension MediaResource {
    var size: Int? {
        return nil
    }
}

public protocol CachedMediaResourceRepresentation {
    var uniqueId: String { get }
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool
}
