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

public final class MediaResourceStorageLocation {
    public let peerId: PeerId
    public let messageId: MessageId?
    
    public init(peerId: PeerId, messageId: MessageId?) {
        self.peerId = peerId
        self.messageId = messageId
    }
}

public enum MediaResourceUserContentType: UInt8, Equatable {
    case other = 0
    case image = 1
    case video = 2
    case audio = 3
    case file = 4
    case sticker = 6
    case avatar = 7
}

public struct MediaResourceFetchParameters {
    public let tag: MediaResourceFetchTag?
    public let info: MediaResourceFetchInfo?
    public let location: MediaResourceStorageLocation?
    public let contentType: MediaResourceUserContentType
    public let isRandomAccessAllowed: Bool
    
    public init(tag: MediaResourceFetchTag?, info: MediaResourceFetchInfo?, location: MediaResourceStorageLocation?, contentType: MediaResourceUserContentType, isRandomAccessAllowed: Bool) {
        self.tag = tag
        self.info = info
        self.location = location
        self.contentType = contentType
        self.isRandomAccessAllowed = isRandomAccessAllowed
    }
}
