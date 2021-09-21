import Foundation
import Postbox

public struct ArchivedStickerPacksInfoId {
    public let rawValue: MemoryBuffer
    public let id: Int32
    
    init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
        assert(rawValue.length == 4)
        var idValue: Int32 = 0
        memcpy(&idValue, rawValue.memory, 4)
        self.id = idValue
    }
    
    init(_ id: Int32) {
        self.id = id
        var idValue: Int32 = id
        self.rawValue = MemoryBuffer(memory: malloc(4)!, capacity: 4, length: 4, freeWhenDone: true)
        memcpy(self.rawValue.memory, &idValue, 4)
    }
}

public final class ArchivedStickerPacksInfo: Codable {
    public let count: Int32
    
    init(count: Int32) {
        self.count = count
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.count = try container.decode(Int32.self, forKey: "c")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.count, forKey: "c")
    }
}
