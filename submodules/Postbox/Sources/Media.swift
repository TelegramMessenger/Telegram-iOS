import Foundation

public struct MediaId: Hashable, PostboxCoding, CustomStringConvertible, Codable {
    public typealias Namespace = Int32
    public typealias Id = Int64
    
    public let namespace: Namespace
    public let id: Id
    
    public var description: String {
        get {
            return "\(namespace):\(id)"
        }
    }
    
    public init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ buffer: ReadBuffer) {
        var namespace: Int32 = 0
        var id: Int64 = 0
        
        memcpy(&namespace, buffer.memory + buffer.offset, 4)
        self.namespace = namespace
        memcpy(&id, buffer.memory + (buffer.offset + 4), 8)
        self.id = id
        buffer.offset += 12
    }
    
    public init(decoder: PostboxDecoder) {
        self.namespace = decoder.decodeInt32ForKey("n", orElse: 0)
        self.id = decoder.decodeInt64ForKey("i", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.namespace, forKey: "n")
        encoder.encodeInt64(self.id, forKey: "i")
    }
    
    public func encodeToBuffer(_ buffer: WriteBuffer) {
        var namespace = self.namespace
        var id = self.id
        buffer.write(&namespace, offset: 0, length: 4);
        buffer.write(&id, offset: 0, length: 8);
    }
    
    public static func encodeArrayToBuffer(_ array: [MediaId], buffer: WriteBuffer) {
        var length: Int32 = Int32(array.count)
        buffer.write(&length, offset: 0, length: 4)
        for id in array {
            id.encodeToBuffer(buffer)
        }
    }
    
    public static func decodeArrayFromBuffer(_ buffer: ReadBuffer) -> [MediaId] {
        var length: Int32 = 0
        memcpy(&length, buffer.memory, 4)
        buffer.offset += 4
        var i = 0
        var array: [MediaId] = []
        while i < Int(length) {
            array.append(MediaId(buffer))
            i += 1
        }
        return array
    }
}

public protocol AssociatedMediaData: AnyObject, PostboxCoding {
    func isEqual(to: AssociatedMediaData) -> Bool
}

public protocol Media: AnyObject, PostboxCoding {
    var id: MediaId? { get }
    var peerIds: [PeerId] { get }
    
    var indexableText: String? { get }
    
    func isLikelyToBeUpdated() -> Bool

    func preventsAutomaticMessageSendingFailure() -> Bool
    
    func isEqual(to other: Media) -> Bool
    func isSemanticallyEqual(to other: Media) -> Bool
}

public extension Media {
    func isLikelyToBeUpdated() -> Bool {
        return false
    }

    func preventsAutomaticMessageSendingFailure() -> Bool {
        return false
    }

    var indexableText: String? {
        return nil
    }
}
