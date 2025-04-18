import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

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

public final class RecentMediaItem: Codable, Equatable {
    public let media: TelegramMediaFile.Accessor
    private let serializedFile: Data?
    
    public init(_ media: TelegramMediaFile) {
        self.media = TelegramMediaFile.Accessor(media)
        self.serializedFile = nil
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let serializedFileData = try container.decodeIfPresent(Data.self, forKey: "md") {
            self.serializedFile = serializedFileData
            var byteBuffer = ByteBuffer(data: serializedFileData)
            self.media = TelegramMediaFile.Accessor(FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramMediaFile, serializedFileData)
        } else {
            let mediaData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "m")
            let media = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: mediaData.data)))
            self.media = TelegramMediaFile.Accessor(media)
            self.serializedFile = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let serializedFile = self.serializedFile {
            try container.encode(serializedFile, forKey: "md")
        } else if let file = self.media._wrappedFile {
            var builder = FlatBufferBuilder(initialSize: 1024)
            let value = file.encodeToFlatBuffers(builder: &builder)
            builder.finish(offset: value)
            let serializedFile = builder.data
            try container.encode(serializedFile, forKey: "md")
        } else {
            preconditionFailure()
        }
    }
    
    public static func ==(lhs: RecentMediaItem, rhs: RecentMediaItem) -> Bool {
        return lhs.media == rhs.media
    }
}

public struct RecentEmojiItemId {
    public enum Id {
        case media(MediaId)
        case text(String)
    }
    
    public let rawValue: MemoryBuffer
    public let id: Id
    
    public init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
        
        assert(rawValue.length >= 1)
        var type: UInt8 = 0
        memcpy(&type, rawValue.memory.advanced(by: 0), 1)
        
        if type == 0 {
            assert(rawValue.length == 1 + 4 + 8)
            var mediaIdNamespace: Int32 = 0
            var mediaIdId: Int64 = 0
            memcpy(&mediaIdNamespace, rawValue.memory.advanced(by: 1), 4)
            memcpy(&mediaIdId, rawValue.memory.advanced(by: 1 + 4), 8)
            self.id = .media(MediaId(namespace: mediaIdNamespace, id: mediaIdId))
        } else if type == 1 {
            var length: UInt16 = 0
            assert(rawValue.length >= 1 + 2)
            memcpy(&length, rawValue.memory.advanced(by: 1), 2)
            
            assert(rawValue.length >= 1 + 2 + Int(length))
            
            self.id = .text(String(data: Data(bytes: rawValue.memory.advanced(by: 1 + 2), count: Int(length)), encoding: .utf8) ?? ".")
        } else {
            assert(false)
            self.id = .text(".")
        }
    }
    
    public init(_ mediaId: MediaId) {
        self.id = .media(mediaId)
        
        var mediaIdNamespace: Int32 = mediaId.namespace
        var mediaIdId: Int64 = mediaId.id
        self.rawValue = MemoryBuffer(memory: malloc(1 + 4 + 8)!, capacity: 1 + 4 + 8, length: 1 + 4 + 8, freeWhenDone: true)
        var type: UInt8 = 0
        memcpy(self.rawValue.memory.advanced(by: 0), &type, 1)
        memcpy(self.rawValue.memory.advanced(by: 1), &mediaIdNamespace, 4)
        memcpy(self.rawValue.memory.advanced(by: 1 + 4), &mediaIdId, 8)
    }
    
    public init(_ text: String) {
        self.id = .text(text)
        
        let data = text.data(using: .utf8) ?? Data()
        var length: UInt16 = UInt16(data.count)
        
        self.rawValue = MemoryBuffer(memory: malloc(1 + 2 + data.count)!, capacity: 1 + 2 + data.count, length: 1 + 2 + data.count, freeWhenDone: true)
        var type: UInt8 = 1
        memcpy(self.rawValue.memory.advanced(by: 0), &type, 1)
        memcpy(self.rawValue.memory.advanced(by: 1), &length, 2)
        data.withUnsafeBytes { bytes in
            let _ = memcpy(self.rawValue.memory.advanced(by: 1 + 2), bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), bytes.count)
        }
    }
}

public final class RecentEmojiItem: Codable, Equatable {
    public enum Content: Equatable {
        case file(TelegramMediaFile)
        case text(String)
    }
    
    public let content: Content
    
    public init(_ content: Content) {
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let mediaData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "m") {
            self.content = .file(TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: mediaData.data))))
        } else {
            self.content = .text(try container.decode(String.self, forKey: "s"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self.content {
        case let .file(file):
            try container.encode(PostboxEncoder().encodeObjectToRawData(file), forKey: "m")
        case let .text(string):
            try container.encode(string, forKey: "s")
        }
    }
    
    public static func ==(lhs: RecentEmojiItem, rhs: RecentEmojiItem) -> Bool {
        return lhs.content == rhs.content
    }
}

public struct RecentReactionItemId {
    public enum Id: Hashable {
        case custom(MediaId)
        case builtin(String)
        case stars
    }
    
    public let rawValue: MemoryBuffer
    public let id: Id
    
    public init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
        
        assert(rawValue.length >= 1)
        var type: UInt8 = 0
        memcpy(&type, rawValue.memory.advanced(by: 0), 1)
        
        if type == 0 {
            assert(rawValue.length == 1 + 4 + 8)
            var mediaIdNamespace: Int32 = 0
            var mediaIdId: Int64 = 0
            memcpy(&mediaIdNamespace, rawValue.memory.advanced(by: 1), 4)
            memcpy(&mediaIdId, rawValue.memory.advanced(by: 1 + 4), 8)
            self.id = .custom(MediaId(namespace: mediaIdNamespace, id: mediaIdId))
        } else if type == 1 {
            var length: UInt16 = 0
            assert(rawValue.length >= 1 + 2)
            memcpy(&length, rawValue.memory.advanced(by: 1), 2)
            
            assert(rawValue.length >= 1 + 2 + Int(length))
            
            self.id = .builtin(String(data: Data(bytes: rawValue.memory.advanced(by: 1 + 2), count: Int(length)), encoding: .utf8) ?? ".")
        } else if type == 2 {
            self.id = .stars
        } else {
            assert(false)
            self.id = .builtin(".")
        }
    }
    
    public init(_ mediaId: MediaId) {
        self.id = .custom(mediaId)
        
        var mediaIdNamespace: Int32 = mediaId.namespace
        var mediaIdId: Int64 = mediaId.id
        self.rawValue = MemoryBuffer(memory: malloc(1 + 4 + 8)!, capacity: 1 + 4 + 8, length: 1 + 4 + 8, freeWhenDone: true)
        var type: UInt8 = 0
        memcpy(self.rawValue.memory.advanced(by: 0), &type, 1)
        memcpy(self.rawValue.memory.advanced(by: 1), &mediaIdNamespace, 4)
        memcpy(self.rawValue.memory.advanced(by: 1 + 4), &mediaIdId, 8)
    }
    
    public init(_ text: String) {
        self.id = .builtin(text)
        
        let data = text.data(using: .utf8) ?? Data()
        var length: UInt16 = UInt16(data.count)
        
        self.rawValue = MemoryBuffer(memory: malloc(1 + 2 + data.count)!, capacity: 1 + 2 + data.count, length: 1 + 2 + data.count, freeWhenDone: true)
        var type: UInt8 = 1
        memcpy(self.rawValue.memory.advanced(by: 0), &type, 1)
        memcpy(self.rawValue.memory.advanced(by: 1), &length, 2)
        data.withUnsafeBytes { bytes in
            let _ = memcpy(self.rawValue.memory.advanced(by: 1 + 2), bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), bytes.count)
        }
    }
    
    public init(_ id: Id) {
        precondition(id == .stars)
        self.id = id
        
        self.rawValue = MemoryBuffer(memory: malloc(1)!, capacity: 1, length: 1, freeWhenDone: true)
        
        var type: UInt8 = 2
        memcpy(self.rawValue.memory.advanced(by: 0), &type, 1)
    }
}

public final class RecentReactionItem: Codable, Equatable {
    public enum Content: Equatable {
        case custom(TelegramMediaFile.Accessor)
        case builtin(String)
        case stars
    }
    
    public let content: Content
    
    public var id: RecentReactionItemId {
        switch self.content {
        case let .builtin(value):
            return RecentReactionItemId(value)
        case let .custom(file):
            return RecentReactionItemId(file.fileId)
        case .stars:
            return RecentReactionItemId(.stars)
        }
    }
    
    public init(_ content: Content) {
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        if let mediaData = try container.decodeIfPresent(Data.self, forKey: "md") {
            var byteBuffer = ByteBuffer(data: mediaData)
            let file = TelegramMediaFile.Accessor(FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramMediaFile, mediaData)
            self.content = .custom(file)
        } else if let mediaData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "m") {
            self.content = .custom(TelegramMediaFile.Accessor(TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: mediaData.data)))))
        } else if let _ = try container.decodeIfPresent(Int64.self, forKey: "star") {
            self.content = .stars
        } else {
            self.content = .builtin(try container.decode(String.self, forKey: "s"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self.content {
        case let .custom(file):
            if let serializedFile = file._wrappedData {
                try container.encode(serializedFile, forKey: "md")
            } else if let file = file._wrappedFile {
                var builder = FlatBufferBuilder(initialSize: 1024)
                let value = file.encodeToFlatBuffers(builder: &builder)
                builder.finish(offset: value)
                let serializedFile = builder.data
                try container.encode(serializedFile, forKey: "md")
            } else {
                preconditionFailure()
            }
        case let .builtin(string):
            try container.encode(string, forKey: "s")
        case .stars:
            try container.encode(0 as Int64, forKey: "star")
        }
    }
    
    public static func ==(lhs: RecentReactionItem, rhs: RecentReactionItem) -> Bool {
        return lhs.content == rhs.content
    }
}

public struct RecentStarGiftItemId {
    public let rawValue: MemoryBuffer
    public let id: Int64
    
    public init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
        assert(rawValue.length == 8)
        var id: Int64 = 0
        memcpy(&id, rawValue.memory, 8)
        self.id = id
    }
    
    public init(_ id: Int64) {
        var id = id
        self.id = id
        self.rawValue = MemoryBuffer(memory: malloc(8)!, capacity: 8, length: 8, freeWhenDone: true)
        memcpy(self.rawValue.memory, &id, 8)
    }
}

public final class RecentStarGiftItem: Codable, Equatable {
    public let starGift: StarGift.UniqueGift
    
    public init(_ starGift: StarGift.UniqueGift) {
        self.starGift = starGift
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.starGift = try container.decode(StarGift.UniqueGift.self, forKey: "g")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.starGift, forKey: "g")
    }
    
    public static func ==(lhs: RecentStarGiftItem, rhs: RecentStarGiftItem) -> Bool {
        return lhs.starGift == rhs.starGift
    }
}
