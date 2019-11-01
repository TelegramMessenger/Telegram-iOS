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

public protocol MediaResource {
    var id: MediaResourceId { get }
    var size: Int? { get }
    var streamable: Bool { get }
    var headerSize: Int32 { get }
    
    func isEqual(to: MediaResource) -> Bool
}

public extension MediaResource {
    var size: Int? {
        return nil
    }
    
    var streamable: Bool {
        return false
    }
    
    var headerSize: Int32 {
        return 0
    }
}

public protocol CachedMediaResourceRepresentation {
    var uniqueId: String { get }
    var keepDuration: CachedMediaRepresentationKeepDuration { get }
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool
}

public protocol MediaResourceFetchTag {
}

public protocol MediaResourceFetchInfo {
}

public struct MediaResourceFetchParameters {
    public let tag: MediaResourceFetchTag?
    public let info: MediaResourceFetchInfo?
    
    public init(tag: MediaResourceFetchTag?, info: MediaResourceFetchInfo?) {
        self.tag = tag
        self.info = info
    }
}
