import Foundation

public struct MediaResourceId: Equatable, Hashable {
    public var stringRepresentation: String

    public init(_ stringRepresentation: String) {
        self.stringRepresentation = stringRepresentation
    }
}

public protocol MediaResource: AnyObject {
    var id: MediaResourceId { get }
    var size: Int64? { get }
    var streamable: Bool { get }
    var headerSize: Int32 { get }
    
    func isEqual(to: MediaResource) -> Bool
}

public extension MediaResource {
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
    public let isRandomAccessAllowed: Bool
    
    public init(tag: MediaResourceFetchTag?, info: MediaResourceFetchInfo?, isRandomAccessAllowed: Bool) {
        self.tag = tag
        self.info = info
        self.isRandomAccessAllowed = isRandomAccessAllowed
    }
}
