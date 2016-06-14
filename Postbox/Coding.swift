import Foundation

public protocol Coding {
    init(decoder: Decoder)
    func encode(encoder: Encoder)
}

private final class EncodableTypeStore {
    var dict: [Int32 : Decoder -> Coding] = [:]
    
    func decode(typeHash: Int32, decoder: Decoder) -> Coding? {
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

public func declareEncodable(type: Any.Type, f: Decoder -> Coding) {
    let string = "\(type)"
    let hash = murMurHashString32(string)
    if typeStore.dict[hash] != nil {
        assertionFailure("Encodable type hash collision for \(type)")
    }
    typeStore.dict[murMurHashString32("\(type)")] = f
}

public class MemoryBuffer: Equatable, CustomStringConvertible {
    var memory: UnsafeMutablePointer<Void>
    var capacity: Int
    var length: Int
    var freeWhenDone: Bool
    
    public init(memory: UnsafeMutablePointer<Void>, capacity: Int, length: Int, freeWhenDone: Bool) {
        self.memory = memory
        self.capacity = capacity
        self.length = length
        self.freeWhenDone = freeWhenDone
    }
    
    public init(data: NSData) {
        self.memory = UnsafeMutablePointer(data.bytes)
        self.capacity = data.length
        self.length = data.length
        self.freeWhenDone = false
    }
    
    public init() {
        self.memory = nil
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
        let bytes = UnsafeMutablePointer<UInt8>(self.memory)
        for i in 0 ..< self.length {
            hexString.appendFormat("%02x", UInt(bytes[i]))
        }
        
        return hexString as String
    }
}

public func ==(lhs: MemoryBuffer, rhs: MemoryBuffer) -> Bool {
    return lhs.length == rhs.length && memcmp(lhs.memory, rhs.memory, lhs.length) == 0
}

public final class WriteBuffer: MemoryBuffer {
    var offset = 0
    
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
    
    public func makeData() -> NSData {
        return NSData(bytes: self.memory, length: self.offset)
    }
    
    public func reset() {
        self.offset = 0
    }
    
    public func write(data: UnsafePointer<Void>, offset: Int, length: Int) {
        if self.offset + length > self.capacity {
            self.capacity = self.offset + length + 256
            self.memory = realloc(self.memory, self.capacity)
        }
        memcpy(self.memory + self.offset, data + offset, length)
        self.offset += length
        self.length = self.offset
    }
}

public final class ReadBuffer: MemoryBuffer {
    var offset = 0
    
    public init(memory: UnsafeMutablePointer<Void>, length: Int, freeWhenDone: Bool) {
        super.init(memory: memory, capacity: length, length: length, freeWhenDone: freeWhenDone)
    }
    
    public init(memoryBufferNoCopy: MemoryBuffer) {
        super.init(memory: memoryBufferNoCopy.memory, capacity: memoryBufferNoCopy.length, length: memoryBufferNoCopy.length, freeWhenDone: false)
    }
    
    func dataNoCopy() -> NSData {
        return NSData(bytesNoCopy: self.memory, length: self.length, freeWhenDone: false)
    }
    
    func read(data: UnsafeMutablePointer<Void>, offset: Int, length: Int) {
        memcpy(data + offset, self.memory + self.offset, length)
        self.offset += length
    }
    
    func skip(length: Int) {
        self.offset += length
    }
    
    func reset() {
        self.offset = 0
    }
    
    func sharedBufferNoCopy() -> ReadBuffer {
        return ReadBuffer(memory: memory, length: length, freeWhenDone: false)
    }
}

private enum ValueType: Int8 {
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
}

public final class Encoder {
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
    
    public func makeData() -> NSData {
        return self.buffer.makeData()
    }
    
    public func reset() {
        self.buffer.reset()
    }
    
    public func encodeKey(key: StaticString) {
        var length: Int8 = Int8(key.byteSize)
        self.buffer.write(&length, offset: 0, length: 1)
        self.buffer.write(key.utf8Start, offset: 0, length: Int(length))
    }
    
    public func encodeInt32(value: Int32, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int32.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 4)
    }
    
    public func encodeInt64(value: Int64, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int64.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 8)
    }
    
    public func encodeBool(value: Bool, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bool.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v: Int8 = value ? 1 : 0
        self.buffer.write(&v, offset: 0, length: 1)
    }
    
    public func encodeDouble(value: Double, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Double.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 8)
    }
    
    public func encodeString(value: String, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.String.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        let data = value.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
        var length: Int32 = Int32(data.length)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(data.bytes, offset: 0, length: Int(length))
    }
    
    public func encodeString(value: DeferredString, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.String.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        let data = value.data
        var length: Int32 = Int32(data.length)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(data.bytes, offset: 0, length: Int(length))
    }
    
    public func encodeRootObject(value: Coding) {
        self.encodeObject(value, forKey: "_")
    }
    
    public func encodeObject(value: Coding, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Object.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        
        let string = "\(value.dynamicType)"
        var typeHash: Int32 = murMurHashString32(string)
        self.buffer.write(&typeHash, offset: 0, length: 4)
        
        let innerEncoder = Encoder()
        value.encode(innerEncoder)
        
        var length: Int32 = Int32(innerEncoder.buffer.offset)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
    }
    
    public func encodeInt32Array(value: [Int32], forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int32Array.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        value.withUnsafeBufferPointer { (data: UnsafeBufferPointer) -> Void in
            self.buffer.write(UnsafePointer<Void>(data.baseAddress), offset: 0, length: Int(length) * 4)
            return
        }
    }
    
    public func encodeInt64Array(value: [Int64], forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int64Array.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        value.withUnsafeBufferPointer { (data: UnsafeBufferPointer) -> Void in
            self.buffer.write(UnsafePointer<Void>(data.baseAddress), offset: 0, length: Int(length) * 8)
            return
        }
    }
    
    public func encodeObjectArray<T: Coding>(value: [T], forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.ObjectArray.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        let innerEncoder = Encoder()
        for object in value {
            var typeHash: Int32 = murMurHashString32("\(object.dynamicType)")
            self.buffer.write(&typeHash, offset: 0, length: 4)
            
            innerEncoder.reset()
            object.encode(innerEncoder)
            
            var length: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
        }
    }
    
    public func encodeObjectArray(value: [Coding], forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.ObjectArray.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        let innerEncoder = Encoder()
        for object in value {
            var typeHash: Int32 = murMurHashString32("\(object.dynamicType)")
            self.buffer.write(&typeHash, offset: 0, length: 4)
            
            innerEncoder.reset()
            object.encode(innerEncoder)
            
            var length: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&length, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
        }
    }
    
    public func encodeObjectDictionary<K, V: Coding where K: Coding, K: Hashable>(value: [K : V], forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.ObjectDictionary.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var length: Int32 = Int32(value.count)
        self.buffer.write(&length, offset: 0, length: 4)
        
        let innerEncoder = Encoder()
        for record in value {
            var keyTypeHash: Int32 = murMurHashString32("\(record.0.dynamicType)")
            self.buffer.write(&keyTypeHash, offset: 0, length: 4)
            innerEncoder.reset()
            record.0.encode(innerEncoder)
            var keyLength: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&keyLength, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(keyLength))
            
            var valueTypeHash: Int32 = murMurHashString32("\(record.1.dynamicType)")
            self.buffer.write(&valueTypeHash, offset: 0, length: 4)
            innerEncoder.reset()
            record.1.encode(innerEncoder)
            var valueLength: Int32 = Int32(innerEncoder.buffer.offset)
            self.buffer.write(&valueLength, offset: 0, length: 4)
            self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(valueLength))
        }
    }
    
    public func encodeBytes(bytes: WriteBuffer, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bytes.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var bytesLength: Int32 = Int32(bytes.offset)
        self.buffer.write(&bytesLength, offset: 0, length: 4)
        self.buffer.write(bytes.memory, offset: 0, length: bytes.offset)
    }
    
    public func encodeBytes(bytes: ReadBuffer, forKey key: StaticString) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bytes.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var bytesLength: Int32 = Int32(bytes.offset)
        self.buffer.write(&bytesLength, offset: 0, length: 4)
        self.buffer.write(bytes.memory, offset: 0, length: bytes.offset)
    }

    public let sharedWriteBuffer = WriteBuffer()
}

public final class Decoder {
    private let buffer: MemoryBuffer
    private var offset: Int = 0
    
    public init(buffer: MemoryBuffer) {
        self.buffer = buffer
    }
    
    private class func skipValue(bytes: UnsafePointer<Int8>, inout offset: Int, length: Int, valueType: ValueType) {
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
                var length: Int32 = 0
                memcpy(&length, bytes + offset, 4)
                offset += 4
                var i: Int32 = 0
                while i < length {
                    var objectLength: Int32 = 0
                    memcpy(&objectLength, bytes + (offset + 4), 4)
                    offset += 8 + Int(objectLength)
                    i += 1
                }
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
        }
    }
    
    private class func positionOnKey(bytes: UnsafePointer<Int8>, inout offset: Int, maxOffset: Int, length: Int, key: StaticString, valueType: ValueType) -> Bool
    {
        let startOffset = offset
        
        let keyLength: Int = key.byteSize
        while (offset < maxOffset)
        {
            let readKeyLength = bytes[offset]
            offset += 1
            offset += Int(readKeyLength)
            
            let readValueType = bytes[offset]
            offset += 1
            
            if readValueType != valueType.rawValue || keyLength != Int(readKeyLength) || memcmp(bytes + (offset - Int(readKeyLength) - 1), key.utf8Start, keyLength) != 0 {
                skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!)
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
    
    private class func positionOnKey(bytes: UnsafePointer<Int8>, inout offset: Int, maxOffset: Int, length: Int, key: Int16, valueType: ValueType) -> Bool
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
                skipValue(bytes, offset: &offset, length: length, valueType: ValueType(rawValue: readValueType)!)
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
    
    public func decodeInt32ForKey(key: StaticString) -> Int32 {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32) {
            var value: Int32 = 0
            memcpy(&value, self.buffer.memory + self.offset, 4)
            self.offset += 4
            return value
        } else {
            return 0
        }
    }
    
    public func decodeInt32ForKey(key: StaticString) -> Int32? {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32) {
            var value: Int32 = 0
            memcpy(&value, self.buffer.memory + self.offset, 4)
            self.offset += 4
            return value
        } else {
            return nil
        }
    }
    
    public func decodeInt64ForKey(key: StaticString) -> Int64 {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64) {
            var value: Int64 = 0
            memcpy(&value, self.buffer.memory + self.offset, 8)
            self.offset += 8
            return value
        } else {
            return 0
        }
    }
    
    public func decodeInt64ForKey(key: StaticString) -> Int64? {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64) {
            var value: Int64 = 0
            memcpy(&value, self.buffer.memory + self.offset, 8)
            self.offset += 8
            return value
        } else {
            return nil
        }
    }
    
    public func decodeBoolForKey(key: StaticString) -> Bool {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bool) {
            var value: Int8 = 0
            memcpy(&value, self.buffer.memory + self.offset, 1)
            self.offset += 1
            return value != 0
        } else {
            return false
        }
    }
    
    public func decodeDoubleForKey(key: StaticString) -> Double {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Double) {
            var value: Double = 0
            memcpy(&value, self.buffer.memory + self.offset, 8)
            self.offset += 8
            return value
        } else {
            return 0
        }
    }
    
    public func decodeStringForKey(key: StaticString) -> String {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .String) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let data = NSData(bytes: self.buffer.memory + (self.offset + 4), length: Int(length))
            self.offset += 4 + Int(length)
            let value = NSString(data: data, encoding: NSUTF8StringEncoding)
            return (value as? String) ?? ""
        } else {
            return ""
        }
    }
    
    public func decodeStringForKey(key: StaticString) -> String? {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .String) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let data = NSData(bytes: self.buffer.memory + (self.offset + 4), length: Int(length))
            self.offset += 4 + Int(length)
            let value = NSString(data: data, encoding: NSUTF8StringEncoding)
            return value as? String
        } else {
            return nil
        }
    }

    public func decodeStringForKey(key: StaticString) -> DeferredString {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .String) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let data = NSData(bytes: self.buffer.memory + (self.offset + 4), length: Int(length))
            self.offset += 4 + Int(length)
            return DeferredStringValue(data)
        } else {
            return DeferredStringValue("")
        }
    }
    
    public func decodeStringForKey(key: StaticString) -> DeferredString? {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .String) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            let data = NSData(bytes: self.buffer.memory + (self.offset + 4), length: Int(length))
            self.offset += 4 + Int(length)
            return DeferredStringValue(data)
        } else {
            return nil
        }
    }
    
    public func decodeRootObject() -> Coding? {
        return self.decodeObjectForKey("_")
    }
    
    public func decodeObjectForKey(key: StaticString) -> Coding? {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)

            let innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(length), freeWhenDone: false))
            self.offset += 4 + Int(length)
            
            return typeStore.decode(typeHash, decoder: innerDecoder)
        } else {
            return nil
        }
    }
    
    public func decodeObjectForKey(key: StaticString, decoder: Decoder -> Coding) -> Coding? {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            
            let innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(length), freeWhenDone: false))
            self.offset += 4 + Int(length)
            
            return decoder(innerDecoder)
        } else {
            return nil
        }
    }
    
    public func decodeInt32ArrayForKey(key: StaticString) -> [Int32] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32Array) {
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
        } else {
            return []
        }
    }
    
    public func decodeInt64ArrayForKey(key: StaticString) -> [Int64] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64Array) {
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
        } else {
            return []
        }
    }
    
    public func decodeObjectArrayWithDecoderForKey<T where T: Coding>(key: StaticString) -> [T] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
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
                
                let innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
                self.offset += 4 + Int(objectLength)
                
                if !failed {
                    if let object = T(decoder: innerDecoder) as? T {
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
    
    public func decodeObjectArrayForKey<T where T: Coding>(key: StaticString) -> [T] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
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
                
                let innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
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

    public func decodeObjectArrayForKey(key: StaticString) -> [Coding] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4
            
            var array: [Coding] = []
            array.reserveCapacity(Int(length))
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.offset, 4)
                
                let innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(objectLength), freeWhenDone: false))
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
    
    public func decodeObjectDictionaryForKey<K, V: Coding where K: Coding, K: Hashable>(key: StaticString) -> [K : V] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectDictionary) {
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
                
                var innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(keyLength), freeWhenDone: false))
                self.offset += 4 + Int(keyLength)
                
                let key = failed ? nil : (typeStore.decode(keyHash, decoder: innerDecoder) as? K)
                    
                var valueHash: Int32 = 0
                memcpy(&valueHash, self.buffer.memory + self.offset, 4)
                self.offset += 4
                
                var valueLength: Int32 = 0
                memcpy(&valueLength, self.buffer.memory + self.offset, 4)
                
                innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.offset + 4), length: Int(valueLength), freeWhenDone: false))
                self.offset += 4 + Int(valueLength)
                
                let value = failed ? nil : (typeStore.decode(valueHash, decoder: innerDecoder) as? V)
                
                if let key = key, value = value {
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
    
    public func decodeBytesForKeyNoCopy(key: StaticString) -> ReadBuffer! {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bytes) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.offset, 4)
            self.offset += 4 + Int(length)
            return ReadBuffer(memory: UnsafeMutablePointer<Int8>(self.buffer.memory + (self.offset - Int(length))), length: Int(length), freeWhenDone: false)
        } else {
            return nil
        }
    }
}
