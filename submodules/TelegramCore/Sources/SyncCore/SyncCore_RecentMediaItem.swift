import Foundation
import Postbox

public struct RecentMediaItemId {
    public let rawValue: MemoryBuffer
    public let mediaId: MediaId
    
    public init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
        assert(rawValue.length == 4 + 8)
        var mediaIdNamespace: Int32 = 0
        var mediaIdId: Int64 = 0
        memcpy(&mediaIdNamespace, rawValue.memory, 4)
        memcpy(&mediaIdId, rawValue.memory.advanced(by: 4), 8)
        self.mediaId = MediaId(namespace: mediaIdNamespace, id: mediaIdId)
    }
    
    public init(_ mediaId: MediaId) {
        self.mediaId = mediaId
        var mediaIdNamespace: Int32 = mediaId.namespace
        var mediaIdId: Int64 = mediaId.id
        self.rawValue = MemoryBuffer(memory: malloc(4 + 8)!, capacity: 4 + 8, length: 4 + 8, freeWhenDone: true)
        memcpy(self.rawValue.memory, &mediaIdNamespace, 4)
        memcpy(self.rawValue.memory.advanced(by: 4), &mediaIdId, 8)
    }
}

public final class RecentMediaItem: OrderedItemListEntryContents, Equatable {
    public let media: Media
    
    public init(_ media: Media) {
        self.media = media
    }
    
    public init(decoder: PostboxDecoder) {
        self.media = decoder.decodeObjectForKey("m") as! Media
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.media, forKey: "m")
    }
    
    public static func ==(lhs: RecentMediaItem, rhs: RecentMediaItem) -> Bool {
        return lhs.media.isEqual(to: rhs.media)
    }
}
