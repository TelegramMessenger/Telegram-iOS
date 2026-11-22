import Foundation

public final class CodableEntry: Equatable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public init?<T: Encodable>(_ value: T) {
        let encoder = PostboxEncoder()
        encoder.encode(value, forKey: "_")
        self.data = encoder.makeData()
    }

    public init(legacyValue: PostboxCoding) {
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(legacyValue)
        self.data = encoder.makeData()
    }

    public func get<T: Decodable>(_ type: T.Type) -> T? {
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: self.data))
        return decoder.decode(T.self, forKey: "_")
    }

    public func getLegacy<T: PostboxCoding>(_ type: T.Type) -> T? {
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: self.data))
        let object = decoder.decodeRootObject()
        if let object = object as? T {
            return object
        } else {
            return nil
        }
    }

    public func getLegacy() -> PostboxCoding? {
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: self.data))
        let object = decoder.decodeRootObject()
        if let object = object {
            return object
        } else {
            return nil
        }
    }

    public static func ==(lhs: CodableEntry, rhs: CodableEntry) -> Bool {
        return lhs.data == rhs.data
    }
}

public final class PreferencesEntry: Equatable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public init?<T: Encodable>(_ value: T?) {
        guard let value = value else {
            return nil
        }
        let encoder = PostboxEncoder()
        encoder.encode(value, forKey: "_")
        self.data = encoder.makeData()
    }

    public func get<T: Decodable>(_ type: T.Type) -> T? {
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: self.data))
        let result = decoder.decode(T.self, forKey: "_")
        //assert(result != nil)
        return result
    }

    public static func ==(lhs: PreferencesEntry, rhs: PreferencesEntry) -> Bool {
        return lhs.data == rhs.data
    }
}

public extension PreferencesEntry {
    var relatedResources: [MediaResourceId] {
        return []
    }
}
