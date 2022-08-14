import Foundation
import MurMurHash32

public protocol PostboxCoding {
    init(decoder: PostboxDecoder)
    func encode(_ encoder: PostboxEncoder)
}

private final class EncodableTypeStore {
    var dict: [Int32 : (PostboxDecoder) -> PostboxCoding] = [:]
    
    func decode(_ typeHash: Int32, decoder: PostboxDecoder) -> PostboxCoding? {
        if let typeDecoder = self.dict[typeHash] {
            return typeDecoder(decoder)
        } else {
            return nil
        }
    }
}

private let _typeStore = EncodableTypeStore()
private let typeStore = { () -> EncodableTypeStore in
    return _typeStore
}()

public func postboxEncodableTypeHash(_ type: Any.Type) -> Int32 {
    let string = "\(type)"
    let hash = murMurHashString32(string)
    return hash
}

public func declareEncodable(_ type: Any.Type, f: @escaping(PostboxDecoder) -> PostboxCoding) {
    let string = "\(type)"
    let hash = murMurHashString32(string)
    if typeStore.dict[hash] != nil {
        assertionFailure("Encodable type hash collision for \(type)")
    }
    typeStore.dict[murMurHashString32("\(type)")] = f
}

public func declareEncodable(typeHash: Int32, _ f: @escaping(PostboxDecoder) -> PostboxCoding) {
    if typeStore.dict[typeHash] != nil {
        assertionFailure("Encodable type hash collision for \(typeHash)")
    }
    typeStore.dict[typeHash] = f
}

public func persistentHash32(_ string: String) -> Int32 {
    return murMurHashString32(string)
}

private let emptyMemory = malloc(1)!

public class MemoryBuffer: Equatable, CustomStringConvertible {
    public internal(set) var memory: UnsafeMutableRawPointer
    var capacity: Int
    public internal(set) var length: Int
    var freeWhenDone: Bool

    public init(copyOf buffer: MemoryBuffer) {
        self.memory = malloc(buffer.length)
        memcpy(self.memory, buffer.memory, buffer.length)
        self.capacity = buffer.length
        self.length = buffer.length
        self.freeWhenDone = true
    }
    
    public init(memory: UnsafeMutableRawPointer, capacity: Int, length: Int, freeWhenDone: Bool) {
        self.memory = memory
        self.capacity = capacity
        self.length = length
        self.freeWhenDone = freeWhenDone
    }
    
    public init(data: Data) {
        if data.count == 0 {
            self.memory = emptyMemory
            self.capacity = 0
            self.length = 0
            self.freeWhenDone = false
        } else {
            self.memory = malloc(data.count)!
            data.copyBytes(to: self.memory.assumingMemoryBound(to: UInt8.self), count: data.count)
            self.capacity = data.count
            self.length = data.count
            self.freeWhenDone = true
        }
    }
    
    public init() {
        self.memory = emptyMemory
        self.capacity = 0
        self.length = 0
        self.freeWhenDone = false
    }
    
    deinit {
        if self.freeWhenDone {
            free(self.memory)
        }
    }
    
    public var description: String {
        let hexString = NSMutableString()
        let bytes = self.memory.assumingMemoryBound(to: UInt8.self)
        for i in 0 ..< self.length {
            hexString.appendFormat("%02x", UInt(bytes[i]))
        }
        
        return hexString as String
    }
    
    public func makeData() -> Data {
        if self.length == 0 {
            return Data()
        } else {
            return Data(bytes: self.memory, count: self.length)
        }
    }
    
    public func withDataNoCopy(_ f: (Data) -> Void) {
        f(Data(bytesNoCopy: self.memory, count: self.length, deallocator: .none))
    }
    
    public static func ==(lhs: MemoryBuffer, rhs: MemoryBuffer) -> Bool {
        return lhs.length == rhs.length && memcmp(lhs.memory, rhs.memory, lhs.length) == 0
    }
}

public final class WriteBuffer: MemoryBuffer {
    public var offset = 0
    
    public override init() {
        super.init(memory: malloc(32), capacity: 32, length: 0, freeWhenDone: true)
    }
    
    public func makeReadBufferAndReset() -> ReadBuffer {
        let buffer = ReadBuffer(memory: self.memory, length: self.offset, freeWhenDone: true)
        self.memory = malloc(32)
        self.capacity = 32
        self.offset = 0
        return buffer
    }
    
    public func readBufferNoCopy() -> ReadBuffer {
        return ReadBuffer(memory: self.memory, length: self.offset, freeWhenDone: false)
    }
    
    override public func makeData() -> Data {
        return Data(bytes: self.memory.assumingMemoryBound(to: UInt8.self), count: self.offset)
    }
    
    public func reset() {
        self.offset = 0
    }
    
    public func write(_ data: UnsafeRawPointer, offset: Int = 0, length: Int) {
        if self.offset + length > self.capacity {
            self.capacity = self.offset + length + 256
            if self.length == 0 {
                self.memory = malloc(self.capacity)!
            } else {
                self.memory = realloc(self.memory, self.capacity)
            }
        }
        memcpy(self.memory + self.offset, data + offset, length)
        self.offset += length
        self.length = self.offset
    }
    
    public func write(_ data: Data) {
        let length = data.count
        if self.offset + length > self.capacity {
            self.capacity = self.offset + length + 256
            if self.length == 0 {
                self.memory = malloc(self.capacity)!
            } else {
                self.memory = realloc(self.memory, self.capacity)
            }
        }
        data.copyBytes(to: self.memory.advanced(by: offset).assumingMemoryBound(to: UInt8.self), count: length)
        self.offset += length
        self.length = self.offset
    }
}

public final class ReadBuffer: MemoryBuffer {
    public var offset = 0
    
    override public init(data: Data) {
        super.init(data: data)
    }
    
    public init(memory: UnsafeMutableRawPointer, length: Int, freeWhenDone: Bool) {
        super.init(memory: memory, capacity: length, length: length, freeWhenDone: freeWhenDone)
    }
    
    public init(memoryBufferNoCopy: MemoryBuffer) {
        super.init(memory: memoryBufferNoCopy.memory, capacity: memoryBufferNoCopy.length, length: memoryBufferNoCopy.length, freeWhenDone: false)
    }
    
    public func dataNoCopy() -> Data {
        return Data(bytesNoCopy: self.memory.assumingMemoryBound(to: UInt8.self), count: self.length, deallocator: .none)
    }
    
    public func read(_ data: UnsafeMutableRawPointer, offset: Int, length: Int) {
        memcpy(data + offset, self.memory.advanced(by: self.offset), length)
        self.offset += length
    }
    
    public func skip(_ length: Int) {
        self.offset += length
    }
    
    public func reset() {
        self.offset = 0
    }
    
    public func sharedBufferNoCopy() -> ReadBuffer {
        return ReadBuffer(memory: memory, length: length, freeWhenDone: false)
    }
}

enum ValueType: Int8 {
    case Int32 = 0
    case Int64 = 1
    case Bool = 2
    case Double = 3
    case String = 4
    case Object = 5
    case Int32Array = 6
    case Int64Array = 7
    case ObjectArray = 8
    case ObjectDictionary = 9
    case Bytes = 10
    case Nil = 11
    case StringArray = 12
    case BytesArray = 13
}

enum ObjectDataValueType {
    case Int32
    case Int64
    case Bool
    case Double
    case String
    case Object(hash: Int32)
    case Int32Array
    case Int64Array
    case ObjectArray
    case ObjectDictionary
    case Bytes
    case Nil
    case StringArray
    case BytesArray
}

private extension ObjectDataValueType {
    init?(_ type: ValueType) {
        switch type {
        case .Int32:
            self = .Int32
        case .Int64:
            self = .Int64
        case .Bool:
            self = .Bool
        case .Double:
            self = .Double
        case .String:
            self = .String
        case .Object:
            return nil
        case .Int32Array:
            self = .Int32Array
        case .Int64Array:
            self = .Int64Array
        case .ObjectArray:
            self = .ObjectArray
        case .ObjectDictionary:
            self = .ObjectDictionary
        case .Bytes:
            self = .Bytes
        case .Nil:
            self = .Nil
        case .StringArray:
            self = .StringArray
        case .BytesArray:
            self = .BytesArray
        }
    }
}

public final class PostboxEncoder {
    private let buffer = WriteBuffer()
    
    public init() {
    }
    
    public func memoryBuffer() -> MemoryBuffer {
        return self.buffer
    }
    
    public func makeReadBufferAndReset() -> ReadBuffer {
        return self.buffer.makeReadBufferAndReset()
    }
    
    public func readBufferNoCopy() -> ReadBuffer {
        return self.buffer.readBufferNoCopy()
    }
    
    public func makeData() -> Data {
        return self.buffer.makeData()
    }
    
    public func reset() {
        self.buffer.reset()
    }
    
    public func encodeKey(_ key: String) {
        let data = key.data(using: .utf8)!
        var length: Int8 = Int8(data.count)
        self.buffer.write(&length, offset: 0, length: 1)
        data.withUnsafeBytes { bytes in
            self.buffer.write(bytes.baseAddress!, offset: 0, length: Int(length))
        }
    }
    
    public func encodeNil(forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Nil.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
    }
    
    public func encodeInt32(_ value: Int32, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int32.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 4)
    }
    
    public func encodeInt64(_ value: Int64, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int64.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 8)
    }
    
    public func encodeBool(_ value: Bool, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bool.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v: Int8 = value ? 1 : 0
        self.buffer.write(&v, offset: 0, length: 1)
    }
    
    public func encodeDouble(_ value: Double, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Double.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 8)
    }
    
    public func encodeString(_ value: String, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.String.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        if let data = value.data(using: .utf8, allowLossyConversion: true) {
            var length: Int32 = Int32(data.count)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(data)
        } else {
            var length: Int32 = 0
            self.buffer.write(&length, offset: 0, length: 4)
        }
    }
    
    public func encodeRootObject(_ value: PostboxCoding) {
        self.encodeObject(value, forKey: "_")
    }
    
    public func encodeCodable<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            self.encodeData(data, forKey: key)
        }
    }
    
    public func encodeObject(_ value: PostboxCoding, forKey key: String) {
        self.encodeKey(key)
        var t: Int8 = ValueType.Object.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        
        let string = "\(type(of: value))"
        var typeHash: Int32 = murMurHashString32(string)
        self.buffer.write(&typeHash, offset: 0, length: 4)
        
        let innerEncoder = PostboxEncoder()
        value.encode(innerEncoder)
        
        var length: Int32 = Int32(innerEncoder.buffer.offset)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
    }
    
    public func encodeObjectWithEncoder<T>(_ value: T, encoder: (PostboxEncoder) -> Void, forKey key: String) {
        self.encodeKey(key)
        var t: Int8 = ValueType.Object.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        
        let string = "\(type(of: value))"
        var typeHash: Int32 = murMurHashString32(string)
        self.buffer.write(&typeHash, offset: 0, length: 4)
        
        let innerEncoder = PostboxEncoder()
        encoder(innerEncoder)
        
        var length: Int32 = Int32(innerEncoder.buffer.offset)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
    }
    
    public func encodeInt32Array(_ value: [Int32], forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int32Array.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        value.withUnsafeBufferPointer { (data: UnsafeBufferPointer) -> Void in
            self.buffer.write(UnsafeRawPointer(data.baseAddress!), offset: 0, length: Int(length) * 4)
            return
        }
    }
    
    public func encodeInt64Array(_ value: [Int64], forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int64Array.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        value.withUnsafeBufferPointer { (data: UnsafeBufferPointer) -> Void in
            self.buffer.write(UnsafeRawPointer(data.baseAddress!), offset: 0, length: Int(length) * 8)
            return
        }
    }

    public func encodeObjectToRawData<T: PostboxCoding>(_ value: T) -> AdaptedPostboxEncoder.RawObjectData {
        let typeHash: Int32 = murMurHashString32("\(type(of: value))")

        let innerEncoder = PostboxEncoder()
        value.encode(innerEncoder)

        return AdaptedPostboxEncoder.RawObjectData(typeHash: typeHash, data: innerEncoder.makeData())
    }
    
    public func encodeObjectArray<T: PostboxCoding>(_ value: [T], forKey key: String) {
        self.encodeKey(key)
        var t: Int8 = ValueType.ObjectArray.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        let innerEncoder = PostboxEncoder()
        for object in value {
            var typeHash: Int32 = murMurHashString32("\(type(of: object))")
            self.buffer.write(&typeHash, offset: 0, length: 4)
            
            innerEncoder.reset()
            object.encode(innerEncoder)
            
            var length: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
        }
    }
    
    public func encodeObjectArrayWithEncoder<T>(_ value: [T], forKey key: String, encoder: (T, PostboxEncoder) -> Void) {
        self.encodeKey(key)
        var t: Int8 = ValueType.ObjectArray.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        let innerEncoder = PostboxEncoder()
        for object in value {
            var typeHash: Int32 = murMurHashString32("\(type(of: object))")
            self.buffer.write(&typeHash, offset: 0, length: 4)
            
            innerEncoder.reset()
            encoder(object, innerEncoder)
            
            var length: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
        }
    }
    
    public func encodeGenericObjectArray(_ value: [PostboxCoding], forKey key: String) {
        self.encodeKey(key)
        var t: Int8 = ValueType.ObjectArray.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        let innerEncoder = PostboxEncoder()
        for object in value {
            var typeHash: Int32 = murMurHashString32("\(type(of: object))")
            self.buffer.write(&typeHash, offset: 0, length: 4)
            
            innerEncoder.reset()
            object.encode(innerEncoder)
            
            var length: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
        }
    }
    
    public func encodeStringArray(_ value: [String], forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.StringArray.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        
        for object in value {
            let data = object.data(using: .utf8, allowLossyConversion: true) ?? (String("").data(using: .utf8)!)
            var length: Int32 = Int32(data.count)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(data)
        }
    }
    
    public func encodeBytesArray(_ value: [MemoryBuffer], forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.BytesArray.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        
        for object in value {
            var length: Int32 = Int32(object.length)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(object.memory, offset: 0, length: object.length)
        }
    }
    
    public func encodeDataArray(_ value: [Data], forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.BytesArray.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        
        for object in value {
            var length: Int32 = Int32(object.count)
            self.buffer.write(&length, offset: 0, length: 4)
            object.withUnsafeBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                self.buffer.write(bytes, offset: 0, length: Int(length))
            }
        }
    }
    
    public func encodeObjectDictionary<K, V: PostboxCoding>(_ value: [K : V], forKey key: String) where K: PostboxCoding {
        self.encodeKey(key)
        var t: Int8 = ValueType.ObjectDictionary.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        
        let innerEncoder = PostboxEncoder()
        for record in value {
            var keyTypeHash: Int32 = murMurHashString32("\(type(of: record.0))")
            self.buffer.write(&keyTypeHash, offset: 0, length: 4)
            innerEncoder.reset()
            record.0.encode(innerEncoder)
            var keyLength: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&keyLength, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(keyLength))
            
            var valueTypeHash: Int32 = murMurHashString32("\(type(of: record.1))")
            self.buffer.write(&valueTypeHash, offset: 0, length: 4)
            innerEncoder.reset()
            record.1.encode(innerEncoder)
            var valueLength: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&valueLength, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(valueLength))
        }
    }
    
    public func encodeObjectDictionary<K, V: PostboxCoding>(_ value: [K : V], forKey key: String, keyEncoder: (K, PostboxEncoder) -> Void) {
        self.encodeKey(key)
        var t: Int8 = ValueType.ObjectDictionary.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        
        let innerEncoder = PostboxEncoder()
        for record in value {
            var keyTypeHash: Int32 = murMurHashString32("\(type(of: record.0))")
            self.buffer.write(&keyTypeHash, offset: 0, length: 4)
            innerEncoder.reset()
            keyEncoder(record.0, innerEncoder)
            var keyLength: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&keyLength, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(keyLength))
            
            var valueTypeHash: Int32 = murMurHashString32("\(type(of: record.1))")
            self.buffer.write(&valueTypeHash, offset: 0, length: 4)
            innerEncoder.reset()
            record.1.encode(innerEncoder)
            var valueLength: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&valueLength, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(valueLength))
        }
    }
    
    public func encodeBytes(_ bytes: WriteBuffer, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bytes.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var bytesLength: Int32 = Int32(bytes.offset)
        self.buffer.write(&bytesLength, offset: 0, length: 4)
        self.buffer.write(bytes.memory, offset: 0, length: bytes.offset)
    }
    
    public func encodeBytes(_ bytes: ReadBuffer, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bytes.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var bytesLength: Int32 = Int32(bytes.offset)
        self.buffer.write(&bytesLength, offset: 0, length: 4)
        self.buffer.write(bytes.memory, offset: 0, length: bytes.offset)
    }
    
    public func encodeBytes(_ bytes: MemoryBuffer, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bytes.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var bytesLength: Int32 = Int32(bytes.length)
        self.buffer.write(&bytesLength, offset: 0, length: 4)
        self.buffer.write(bytes.memory, offset: 0, length: bytes.length)
    }
    
    public func encodeData(_ data: Data, forKey key: String) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bytes.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var bytesLength: Int32 = Int32(data.count)
        self.buffer.write(&bytesLength, offset: 0, length: 4)
        data.withUnsafeBytes { rawBytes -> Void in
            let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            self.buffer.write(bytes, offset: 0, length: Int(bytesLength))
        }
    }

    public func encode<T: Encodable>(_ value: T, forKey key: String) {
        let typeHash: Int32 = murMurHashString32("\(type(of: value))")
        let innerEncoder = _AdaptedPostboxEncoder(typeHash: typeHash)
        try! value.encode(to: innerEncoder)

        let (data, valueType) = innerEncoder.makeData(addHeader: true, isDictionary: false)
        self.encodeInnerObjectData(data, valueType: valueType, forKey: key)
    }
    
    public func encodeArray<T: Encodable>(_ value: [T], forKey key: String) {
        self.encodeKey(key)
        var t: Int8 = ValueType.ObjectArray.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        
        for object in value {
            let typeHash: Int32 = murMurHashString32("\(type(of: object))")
            let innerEncoder = _AdaptedPostboxEncoder(typeHash: typeHash)
            try! object.encode(to: innerEncoder)

            let (data, _) = innerEncoder.makeData(addHeader: true, isDictionary: false)
            
            var length: Int32 = Int32(data.count)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(data)
        }
    }

    func encodeInnerObjectData(_ value: Data, valueType: ValueType, forKey key: String) {
        self.encodeKey(key)

        var t: Int8 = valueType.rawValue
        self.buffer.write(&t, offset: 0, length: 1)
        
        self.buffer.write(value)
    }

    func encodeInnerObjectDataWithHeader(typeHash: Int32, data: Data, valueType: ValueType, forKey key: String) {
        self.encodeKey(key)

        var t: Int8 = valueType.rawValue
        self.buffer.write(&t, offset: 0, length: 1)

        var typeHash = typeHash
        self.buffer.write(&typeHash, offset: 0, length: 4)

        var length: Int32 = Int32(data.count)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(data)
    }

    public let sharedWriteBuffer = WriteBuffer()
}

public final class PostboxDecoder {
    private let buffer: MemoryBuffer
    private var offset: Int = 0
    
    public init(buffer: MemoryBuffer) {
        self.buffer = buffer
    }
    
    private class func skipValue(_ bytes: UnsafePointer<Int8>, offset: inout Int, length: Int, valueType: ValueType) -> Bool {
        switch valueType {
        case .Int32:
            offset += 4
        case .Int64:
            offset += 8
        case .Bool:
            offset += 1
        case .Double:
            offset += 8
        case .String:
            var length: Int32 = 0
            memcpy(&length, bytes + offset, 4)
            offset += 4 + Int(length)
        case .Object:
            var length: Int32 = 0
            memcpy(&length, bytes + (offset + 4), 4)
            offset += 8 + Int(length)
        case .Int32Array:
            var length: Int32 = 0
            memcpy(&length, bytes + offset, 4)
            offset += 4 + Int(length) * 4
        case .Int64Array:
            var length: Int32 = 0
            memcpy(&length, bytes + offset, 4)
            offset += 4 + Int(length) * 8
        case .ObjectArray:
            var subLength: Int32 = 0
            memcpy(&subLength, bytes + offset, 4)
            offset += 4
            var i: Int32 = 0
            while i < subLength {
                var objectLength: Int32 = 0
                memcpy(&objectLength, bytes + (offset + 4), 4)
                offset += 8 + Int(objectLength)
                if offset < 0 || offset > length {
                    offset = 0
                    return false
                }
                i += 1
            }
            return true
        case .ObjectDictionary:
            var length: Int32 = 0
            memcpy(&length, bytes + offset, 4)
            offset += 4
            var i: Int32 = 0
            while i < length {
                var keyLength: Int32 = 0
                memcpy(&keyLength, bytes + (offset + 4), 4)
                offset += 8 + Int(keyLength)
                
                var valueLength: Int32 = 0
                memcpy(&valueLength, bytes + (offset + 4), 4)
                offset += 8 + Int(valueLength)
                i += 1
            }
        case .Bytes:
            var length: Int32 = 0
            memcpy(&length, bytes + offset, 4)
            offset += 4 + Int(length)
        case .Nil:
            break
        case .StringArray, .BytesArray:
            var length: Int32 = 0
            memcpy(&length, bytes + offset, 4)
            offset += 4
            var i: Int32 = 0
            while i < length {
                var stringLength: Int32 = 0
                memcpy(&stringLength, bytes + offset, 4)
                offset += 4 + Int(stringLength)
                i += 1
            }
        }
        return true
    }

    private class func positionOnKey(_ rawBytes: UnsafeRawPointer, offset: inout Int, maxOffset: Int, length: Int, key: String, valueType: ValueType) -> Bool {
        var actualValueType: ValueType = .Nil
        return positionOnKey(rawBytes, offset: &offset, maxOffset: maxOffset, length: length, key: key, valueType: valueType, actualValueType: &actualValueType, consumeKey: true)
    }

    private class func positionOnKey(_ rawBytes: UnsafeRawPointer, offset: inout Int, maxOffset: Int, length: Int, key: String, valueType: ValueType?, actualValueType: inout ValueType, consumeKey: Bool) -> Bool
    {
        let bytes = rawBytes.assumingMemoryBound(to: Int8.self)

        let startOffset = offset

        let keyData = key.data(using: .utf8)!

        let keyLength: Int = keyData.count
        while (offset < maxOffset) {
            let keyOffset = offset
            let readKeyLength = bytes[offset]
            assert(readKeyLength >= 0)
            offset += 1
            offset += Int(readKeyLength)

            let readValueType = bytes[offset]
            offset += 1

            if keyLength != Int(readKeyLength) {
                /*let keyString = String(data: Data(bytes: bytes + (offset - Int(readKeyLength) - 1), count: Int(readKeyLength)), encoding: .utf8)
                print("\(String(describing: keyString))")*/
                if !skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!) {
                    return false
                }
                continue
            }

            if keyData.withUnsafeBytes({ keyBytes -> Bool in
                return memcmp(bytes + (offset - Int(readKeyLength) - 1), keyBytes.baseAddress!, keyLength) == 0
            }) {
                if let valueType = valueType {
                    if readValueType == valueType.rawValue {
                        actualValueType = valueType
                        return true
                    } else if readValueType == ValueType.Nil.rawValue {
                        return false
                    } else {
                        if !skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!) {
                            return false
                        }
                    }
                } else {
                    if !consumeKey {
                        offset = keyOffset
                    }
                    actualValueType = ValueType(rawValue: readValueType)!
                    return true
                }
            } else {
                if !skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!) {
                    return false
                }
            }
        }

        if (startOffset != 0) {
            offset = 0
            return positionOnKey(bytes, offset: &offset, maxOffset: startOffset, length: length, key: key, valueType: valueType, actualValueType: &actualValueType, consumeKey: consumeKey)
        }

        return false
    }

    private class func positionOnStringKey(_ rawBytes: UnsafeRawPointer, offset: inout Int, maxOffset: Int, length: Int, key: String, valueType: ValueType) -> Bool
    {
        let bytes = rawBytes.assumingMemoryBound(to: Int8.self)
        
        let startOffset = offset
        
        let keyData = key.data(using: .utf8)!
        
        return keyData.withUnsafeBytes { rawBytes -> Bool in
            let keyBytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let keyLength: Int = keyData.count
            while (offset < maxOffset) {
                let readKeyLength = bytes[offset]
                assert(readKeyLength >= 0)
                offset += 1
                offset += Int(readKeyLength)
                
                let readValueType = bytes[offset]
                offset += 1
                
                if keyLength == Int(readKeyLength) && memcmp(bytes + (offset - Int(readKeyLength) - 1), keyBytes, keyLength) == 0 {
                    if readValueType == valueType.rawValue {
                        return true
                    } else if readValueType == ValueType.Nil.rawValue {
                        return false
                    } else {
                        if !skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!) {
                            return false
                        }
                    }
                } else {
                    if !skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!) {
                        return false
                    }
                }
            }
            
            if (startOffset != 0) {
                offset = 0
                return positionOnStringKey(bytes, offset: &offset, maxOffset: startOffset, length: length, key: key, valueType: valueType)
            }
            
            return false
        }
    }
    
    private class func positionOnKey(_ bytes: UnsafePointer<Int8>, offset: inout Int, maxOffset: Int, length: Int, key: Int16, valueType: ValueType) -> Bool
    {
        var keyValue = key
        let startOffset = offset
        
        let keyLength: Int = 2
        while (offset < maxOffset)
        {
            let readKeyLength = bytes[offset]
            offset += 1
            offset += Int(readKeyLength)
            
            let readValueType = bytes[offset]
            offset += 1
            
            if readValueType != valueType.rawValue || keyLength != Int(readKeyLength) || memcmp(bytes + (offset - Int(readKeyLength) - 1), &keyValue, keyLength) != 0 {
                if !skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!) {
                    return false
                }
            } else {
                return true
            }
        }
        
        if (startOffset != 0)
        {
            offset = 0
            return positionOnKey(bytes, offset: &offset, maxOffset: startOffset, length: length, key: key, valueType: valueType)
        }
        
        return false
    }

    public func containsKey(_ key: String) -> Bool {
        var actualValueType: ValueType = .Nil
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: nil, actualValueType: &actualValueType, consumeKey: false) {
            return true
        } else {
            return false
        }
    }

    public func decodeNilForKey(_ key: String) -> Bool {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Nil) {
            return true
        } else {
            return false
        }
    }
    
    public func decodeInt32ForKey(_ key: String, orElse: Int32) -> Int32 {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32) {
            var value: Int32 = 0
            memcpy(&value, self.buffer.memory + self.offset, 4)
            self.offset += 4
            return value
        } else {
            return orElse
        }
    }
    
    public func decodeOptionalInt32ForKey(_ key: String) -> Int32? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32) {
            var value: Int32 = 0
            memcpy(&value, self.buffer.memory + self.offset, 4)
            self.offset += 4
            return value
        } else {
            return nil
        }
    }
    
    public func decodeInt64ForKey(_ key: String, orElse: Int64) -> Int64 {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64) {
            var value: Int64 = 0
            memcpy(&value, self.buffer.memory + self.offset, 8)
            self.offset += 8
            return value
        } else {
            return orElse
        }
    }
    
    public func decodeOptionalInt64ForKey(_ key: String) -> Int64? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64) {
            var value: Int64 = 0
            memcpy(&value, self.buffer.memory + self.offset, 8)
            self.offset += 8
            return value
        } else {
            return nil
        }
    }
    
    public func decodeBoolForKey(_ key: String, orElse: Bool) -> Bool {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bool) {
            var value: Int8 = 0
            memcpy(&value, self.buffer.memory + self.offset, 1)
            self.offset += 1
            return value != 0
        } else {
            return orElse
        }
    }
    
    public func decodeOptionalBoolForKey(_ key: String) -> Bool? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bool) {
            var value: Int8 = 0
            memcpy(&value, self.buffer.memory + self.offset, 1)
            self.offset += 1
            return value != 0
        } else {
            return nil
        }
    }
    
    public func decodeDoubleForKey(_ key: String, orElse: Double) -> Double {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Double) {
            var value: Double = 0
            memcpy(&value, self.buffer.memory + self.offset, 8)
            self.offset += 8
            return value
        } else {
            return orElse
        }
    }
    
    public func decodeOptionalDoubleForKey(_ key: String) -> Double? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Double) {
            var value: Double = 0
            memcpy(&value, self.buffer.memory + self.offset, 8)
            self.offset += 8
            return value
        } else {
            return nil
        }
    }
    
    public func decodeStringForKey(_ key: String, orElse: String) -> String {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .String) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let data = Data(bytes: self.buffer.memory.assumingMemoryBound(to: UInt8.self).advanced(by: self.offset + 4), count: Int(length))
            self.offset += 4 + Int(length)
            return String(data: data, encoding: .utf8) ?? orElse
        } else {
            return orElse
        }
    }
    
    public func decodeOptionalStringForKey(_ key: String) -> String? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .String) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let data = Data(bytes: self.buffer.memory.assumingMemoryBound(to: UInt8.self).advanced(by: self.offset + 4), count: Int(length))
            self.offset += 4 + Int(length)
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    public func decodeRootObject() -> PostboxCoding? {
        return self.decodeObjectForKey("_")
    }

    public func decodeRootObjectWithHash(hash: Int32) -> PostboxCoding? {
        return typeStore.decode(hash, decoder: self)
    }
    
    public func decodeCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        if let data = self.decodeDataForKey(key) {
            return try? JSONDecoder().decode(T.self, from: data)
        } else {
            return nil
        }
    }
    
    public func decodeObjectForKey(_ key: String) -> PostboxCoding? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)

            let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(length), freeWhenDone: false))
            self.offset += 4 + Int(length)
            
            return typeStore.decode(typeHash, decoder: innerDecoder)
        } else {
            return nil
        }
    }

    func decodeObjectDataForKey(_ key: String) -> (Data, ObjectDataValueType)? {
        var actualValueType: ValueType = .Nil
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: nil, actualValueType: &actualValueType, consumeKey: true) {
            if case .Object = actualValueType {
                var hash: Int32 = 0
                memcpy(&hash, self.buffer.memory + self.offset, 4)
                self.offset += 4

                var length: Int32 = 0
                memcpy(&length, self.buffer.memory + self.offset, 4)
                self.offset += 4

                let innerData = ReadBuffer(memory: self.buffer.memory + self.offset, length: Int(length), freeWhenDone: false).makeData()
                self.offset += Int(length)

                return (innerData, .Object(hash: hash))
            } else {
                let initialOffset = self.offset
                if !PostboxDecoder.skipValue(self.buffer.memory.assumingMemoryBound(to: Int8.self), offset: &self.offset, length: self.buffer.length, valueType: actualValueType) {
                    return nil
                }

                let data = ReadBuffer(memory: UnsafeMutableRawPointer(mutating: self.buffer.memory.advanced(by: initialOffset)), length: self.offset - initialOffset, freeWhenDone: false).makeData()

                return (data, ObjectDataValueType(actualValueType)!)
            }
        } else {
            return nil
        }
    }
    
    public func decodeObjectForKey(_ key: String, decoder: (PostboxDecoder) -> PostboxCoding) -> PostboxCoding? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            
            let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(length), freeWhenDone: false))
            self.offset += 4 + Int(length)
            
            return decoder(innerDecoder)
        } else {
            return nil
        }
    }
    
    public func decodeAnyObjectForKey(_ key: String, decoder: (PostboxDecoder) -> Any?) -> Any? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            
            let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(length), freeWhenDone: false))
            self.offset += 4 + Int(length)
            
            return decoder(innerDecoder)
        } else {
            return nil
        }
    }
    
    public func decodeObjectForKeyThrowing(_ key: String, decoder: (PostboxDecoder) throws -> Any) throws -> Any? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            
            let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(length), freeWhenDone: false))
            self.offset += 4 + Int(length)
            
            return try decoder(innerDecoder)
        } else {
            return nil
        }
    }
    
    public func decodeInt32ArrayForKey(_ key: String) -> [Int32] {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32Array) {
            return decodeInt32ArrayRaw()
        } else {
            return []
        }
    }

    func decodeInt32ArrayRaw() -> [Int32] {
        var length: Int32 = 0
        memcpy(&length, self.buffer.memory + self.offset, 4)
        var array: [Int32] = []
        array.reserveCapacity(Int(length))
        var i: Int32 = 0
        while i < length {
            var element: Int32 = 0
            memcpy(&element, self.buffer.memory + (self.offset + 4 + 4 * Int(i)), 4)
            array.append(element)
            i += 1
        }
        self.offset += 4 + Int(length) * 4
        return array
    }
    
    public func decodeInt64ArrayForKey(_ key: String) -> [Int64] {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64Array) {
            return decodeInt64ArrayRaw()
        } else {
            return []
        }
    }

    func decodeInt64ArrayRaw() -> [Int64] {
        var length: Int32 = 0
        memcpy(&length, self.buffer.memory + self.offset, 4)
        var array: [Int64] = []
        array.reserveCapacity(Int(length))
        var i: Int32 = 0
        while i < length {
            var element: Int64 = 0
            memcpy(&element, self.buffer.memory + (self.offset + 4 + 8 * Int(i)), 8)
            array.append(element)
            i += 1
        }
        self.offset += 4 + Int(length) * 8
        return array
    }
    
    public func decodeObjectArrayWithDecoderForKey<T>(_ key: String) -> [T] where T: PostboxCoding {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [T] = []
            array.reserveCapacity(Int(length))
            
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.offset, 4)
                
                let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
                self.offset += 4 + Int(objectLength)
                
                array.append(T(decoder: innerDecoder))
                
                i += 1
            }
            
            return array
        } else {
            return []
        }
    }
    
    public func decodeOptionalObjectArrayWithDecoderForKey<T>(_ key: String) -> [T]? where T: PostboxCoding {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [T] = []
            array.reserveCapacity(Int(length))
            
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.offset, 4)
                
                let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
                self.offset += 4 + Int(objectLength)
                
                array.append(T(decoder: innerDecoder))
                
                i += 1
            }
            
            return array
        } else {
            if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32Array) {
                let array = decodeInt32ArrayRaw()
                if array.isEmpty {
                    return []
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    
    public func decodeObjectArrayWithCustomDecoderForKey<T>(_ key: String, decoder: (PostboxDecoder) throws -> T) throws -> [T] {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [T] = []
            array.reserveCapacity(Int(length))
            
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.offset, 4)
                
                let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
                self.offset += 4 + Int(objectLength)
                
                let value = try decoder(innerDecoder)
                array.append(value)
                
                i += 1
            }
            
            return array
        } else {
            return []
        }
    }
    
    public func decodeStringArrayForKey(_ key: String) -> [String] {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .StringArray) {
            return decodeStringArrayRaw()
        } else {
            return []
        }
    }
    
    public func decodeOptionalStringArrayForKey(_ key: String) -> [String]? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .StringArray) {
            return decodeStringArrayRaw()
        } else {
            return nil
        }
    }

    public func decodeStringArrayRaw() -> [String] {
        var length: Int32 = 0
        memcpy(&length, self.buffer.memory + self.offset, 4)
        self.offset += 4

        var array: [String] = []
        array.reserveCapacity(Int(length))

        var i: Int32 = 0
        while i < length {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let data = Data(bytes: self.buffer.memory.assumingMemoryBound(to: UInt8.self).advanced(by: self.offset + 4), count: Int(length))
            self.offset += 4 + Int(length)
            if let string = String(data: data, encoding: .utf8) {
                array.append(string)
            } else {
                assertionFailure()
                array.append("")
            }

            i += 1
        }

        return array
    }
    
    public func decodeBytesArrayForKey(_ key: String) -> [MemoryBuffer] {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .BytesArray) {
            return decodeBytesArrayRaw()
        } else {
            return []
        }
    }

    func decodeBytesArrayRaw() -> [MemoryBuffer] {
        var length: Int32 = 0
        memcpy(&length, self.buffer.memory + self.offset, 4)
        self.offset += 4

        var array: [MemoryBuffer] = []
        array.reserveCapacity(Int(length))

        var i: Int32 = 0
        while i < length {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let bytes = malloc(Int(length))!
            memcpy(bytes, self.buffer.memory.advanced(by: self.offset + 4), Int(length))
            array.append(MemoryBuffer(memory: bytes, capacity: Int(length), length: Int(length), freeWhenDone: true))
            self.offset += 4 + Int(length)

            i += 1
        }

        return array
    }

    func decodeObjectDataArrayRaw() -> [Data] {
        var length: Int32 = 0
        memcpy(&length, self.buffer.memory + self.offset, 4)
        self.offset += 4

        var array: [Data] = []
        array.reserveCapacity(Int(length))

        var i: Int32 = 0
        while i < length {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4

            var objectLength: Int32 = 0
            memcpy(&objectLength, self.buffer.memory + self.offset, 4)
            if objectLength < 0 || objectLength > 2 * 1024 * 1024 {
                preconditionFailure()
            }

            let innerBuffer = ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false)
            let innerData = innerBuffer.makeData()
            self.offset += 4 + Int(objectLength)

            array.append(innerData)

            i += 1
        }

        return array
    }
    
    public func decodeOptionalDataArrayForKey(_ key: String) -> [Data]? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .BytesArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [Data] = []
            array.reserveCapacity(Int(length))
            
            var i: Int32 = 0
            while i < length {
                var length: Int32 = 0
                memcpy(&length, self.buffer.memory + self.offset, 4)
                array.append(Data(bytes: self.buffer.memory.advanced(by: self.offset + 4), count: Int(length)))
                self.offset += 4 + Int(length)
                
                i += 1
            }
            
            return array
        } else {
            return nil
        }
    }
    
    public func decodeObjectArrayForKey<T>(_ key: String) -> [T] where T: PostboxCoding {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [T] = []
            array.reserveCapacity(Int(length))
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.offset, 4)
                
                let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
                self.offset += 4 + Int(objectLength)
                
                if !failed {
                    if let object = typeStore.decode(typeHash, decoder: innerDecoder) as? T {
                        array.append(object)
                    } else {
                        failed = true
                    }
                }
                
                i += 1
            }
            
            if failed {
                return []
            } else {
                return array
            }
        } else {
            return []
        }
    }

    public func decodeObjectArrayForKey(_ key: String) -> [PostboxCoding] {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [PostboxCoding] = []
            array.reserveCapacity(Int(length))
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.offset, 4)
                
                let innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
                self.offset += 4 + Int(objectLength)
                
                if !failed {
                    if let object = typeStore.decode(typeHash, decoder: innerDecoder) {
                        array.append(object)
                    } else {
                        failed = true
                    }
                }
                
                i += 1
            }
            
            if failed {
                return []
            } else {
                return array
            }
        } else {
            return []
        }
    }
    
    public func decodeObjectDictionaryForKey<K, V: PostboxCoding>(_ key: String) -> [K : V] where K: PostboxCoding, K: Hashable {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectDictionary) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var dictionary: [K : V] = [:]
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var keyHash: Int32 = 0
                memcpy(&keyHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var keyLength: Int32 = 0
                memcpy(&keyLength, self.buffer.memory + self.offset, 4)
                
                var innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(keyLength), freeWhenDone: false))
                self.offset += 4 + Int(keyLength)
                
                let key = failed ? nil : (typeStore.decode(keyHash, decoder: innerDecoder) as? K)
                    
                var valueHash: Int32 = 0
                memcpy(&valueHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var valueLength: Int32 = 0
                memcpy(&valueLength, self.buffer.memory + self.offset, 4)
                
                innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(valueLength), freeWhenDone: false))
                self.offset += 4 + Int(valueLength)
                
                let value = failed ? nil : (typeStore.decode(valueHash, decoder: innerDecoder) as? V)
                
                if let key = key, let value = value {
                    dictionary[key] = value
                } else {
                    failed = true
                }
                
                i += 1
            }
            
            if failed {
                return [:]
            } else {
                return dictionary
            }
        } else {
            return [:]
        }
    }
    
    public func decodeObjectDictionaryForKey<K, V: PostboxCoding>(_ key: String, keyDecoder: (PostboxDecoder) -> K) -> [K : V] where K: Hashable {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectDictionary) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var dictionary: [K : V] = [:]
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var keyHash: Int32 = 0
                memcpy(&keyHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var keyLength: Int32 = 0
                memcpy(&keyLength, self.buffer.memory + self.offset, 4)
                
                var innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(keyLength), freeWhenDone: false))
                self.offset += 4 + Int(keyLength)
                
                var key: K?
                if !failed {
                    key = keyDecoder(innerDecoder)
                }
                
                var valueHash: Int32 = 0
                memcpy(&valueHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var valueLength: Int32 = 0
                memcpy(&valueLength, self.buffer.memory + self.offset, 4)
                
                innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(valueLength), freeWhenDone: false))
                self.offset += 4 + Int(valueLength)
                
                let value = failed ? nil : (typeStore.decode(valueHash, decoder: innerDecoder) as? V)
                
                if let key = key, let value = value {
                    dictionary[key] = value
                } else {
                    failed = true
                }
                
                i += 1
            }
            
            if failed {
                return [:]
            } else {
                return dictionary
            }
        } else {
            return [:]
        }
    }
    
    public func decodeObjectDictionaryForKey<K, V: PostboxCoding>(_ key: String, keyDecoder: (PostboxDecoder) -> K, valueDecoder: (PostboxDecoder) -> V) -> [K : V] where K: Hashable {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectDictionary) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var dictionary: [K : V] = [:]
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var keyHash: Int32 = 0
                memcpy(&keyHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var keyLength: Int32 = 0
                memcpy(&keyLength, self.buffer.memory + self.offset, 4)
                
                var innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(keyLength), freeWhenDone: false))
                self.offset += 4 + Int(keyLength)
                
                var key: K?
                if !failed {
                    key = keyDecoder(innerDecoder)
                }
                
                var valueHash: Int32 = 0
                memcpy(&valueHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var valueLength: Int32 = 0
                memcpy(&valueLength, self.buffer.memory + self.offset, 4)
                
                innerDecoder = PostboxDecoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(valueLength), freeWhenDone: false))
                self.offset += 4 + Int(valueLength)
                
                let value = failed ? nil : (valueDecoder(innerDecoder) as V)
                
                if let key = key, let value = value {
                    dictionary[key] = value
                } else {
                    failed = true
                }
                
                i += 1
            }
            
            if failed {
                return [:]
            } else {
                return dictionary
            }
        } else {
            return [:]
        }
    }

    public func decodeObjectDataDictRaw() -> [(Data, Data)] {
        var dict: [(Data, Data)] = []

        var length: Int32 = 0
        memcpy(&length, self.buffer.memory + self.offset, 4)
        self.offset += 4

        var i: Int32 = 0
        while i < length {
            var keyHash: Int32 = 0
            memcpy(&keyHash, self.buffer.memory + self.offset, 4)
            self.offset += 4

            var keyLength: Int32 = 0
            memcpy(&keyLength, self.buffer.memory + self.offset, 4)

            let keyData = ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(keyLength), freeWhenDone: false).makeData()
            self.offset += 4 + Int(keyLength)

            var valueHash: Int32 = 0
            memcpy(&valueHash, self.buffer.memory + self.offset, 4)
            self.offset += 4

            var valueLength: Int32 = 0
            memcpy(&valueLength, self.buffer.memory + self.offset, 4)

            let objectData = ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(valueLength), freeWhenDone: false).makeData()
            self.offset += 4 + Int(valueLength)

            dict.append((keyData, objectData))

            i += 1
        }

        return dict
    }
    
    public func decodeBytesForKeyNoCopy(_ key: String) -> ReadBuffer? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bytes) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4 + Int(length)
            return ReadBuffer(memory: self.buffer.memory.advanced(by: self.offset - Int(length)), length: Int(length), freeWhenDone: false)
        } else {
            return nil
        }
    }
    
    public func decodeBytesForKey(_ key: String) -> ReadBuffer? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bytes) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4 + Int(length)
            let copyBytes = malloc(Int(length))!
            memcpy(copyBytes, self.buffer.memory.advanced(by: self.offset - Int(length)), Int(length))
            return ReadBuffer(memory: copyBytes, length: Int(length), freeWhenDone: true)
        } else {
            return nil
        }
    }

    static func parseDataRaw(data: Data) -> Data? {
        return data.withUnsafeBytes { bytes -> Data? in
            guard let baseAddress = bytes.baseAddress else {
                return nil
            }
            if bytes.count < 4 {
                return nil
            }

            var length: Int32 = 0
            memcpy(&length, baseAddress, 4)

            if length < 0 || length != (bytes.count - 4) {
                return nil
            }
            if length == 0 {
                return Data()
            }

            return Data(bytes: baseAddress.advanced(by: 4), count: Int(length))
        }
    }
    
    public func decodeDataForKey(_ key: String) -> Data? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bytes) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4 + Int(length)
            var result = Data(count: Int(length))
            result.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                memcpy(bytes, self.buffer.memory.advanced(by: self.offset - Int(length)), Int(length))
            }
            return result
        } else {
            return nil
        }
    }

    public func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4

            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)

            let innerBuffer = ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(length), freeWhenDone: false)
            let innerData = innerBuffer.makeData()
            self.offset += 4 + Int(length)

            do {
                let result = try AdaptedPostboxDecoder().decode(T.self, from: innerData)
                return result
            } catch let error {
                postboxLog("Decoding error: \(error)")
                //assertionFailure("Decoding error: \(error)")
                return nil
            }
        } else {
            return nil
        }
    }
    
    public func decodeArray<T: Decodable>(_ type: [T].Type, forKey key: String) -> [T]? {
        if PostboxDecoder.positionOnKey(self.buffer.memory, offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [T] = []
            array.reserveCapacity(Int(length))
            
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.offset, 4)
                
                let innerBuffer = ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false)
                let innerData = innerBuffer.makeData()
                self.offset += 4 + Int(length)

                do {
                    let result = try AdaptedPostboxDecoder().decode(T.self, from: innerData)
                    array.append(result)
                } catch let error {
                    postboxLog("Decoding error: \(error)")
                    //assertionFailure("Decoding error: \(error)")
                    return nil
                }
                
                i += 1
            }
            
            return array
        } else {
            return nil
        }
    }
}
