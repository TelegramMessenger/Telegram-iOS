import Foundation

public protocol Coding {
    init(decoder: Decoder)
    func encode(encoder: Encoder)
}

private struct EncodableTypeStore {
    var dict: [Int32 : Decoder -> Coding] = [:]
    
    func decode(typeHash: Int32, decoder: Decoder) -> Coding? {
        if let typeDecoder = self.dict[typeHash] {
            return typeDecoder(decoder)
        } else {
            return nil
        }
    }
}

private var typeStore = EncodableTypeStore()

public func declareEncodable(type: Any.Type, f: Decoder -> Coding) {
    let hash = murMurHashString32("\(type)")
    if typeStore.dict[hash] != nil {
        assertionFailure("Encodable type hash collision for \(type)")
    }
    typeStore.dict[murMurHashString32("\(type)")] = f
}

public final class WriteBuffer {
    var memory: UnsafeMutablePointer<Void> = nil
    var capacity: Int
    var offset: Int
    
    public init() {
        self.memory = malloc(32)
        self.capacity = 32
        self.offset = 0
    }
    
    deinit {
        free(self.memory)
    }
    
    func makeReadBufferAndReset() -> ReadBuffer {
        let buffer = ReadBuffer(memory: self.memory, length: self.offset, freeWhenDone: true)
        self.memory = malloc(32)
        self.capacity = 32
        self.offset = 0
        return buffer
    }
    
    func makeData() -> NSData {
        return NSData(bytes: self.memory, length: self.offset)
    }
    
    public func reset() {
        self.offset = 0
    }
    
    func write(data: UnsafePointer<Void>, offset: Int, length: Int) {
        if self.offset + length > self.capacity {
            self.capacity = self.offset + length + 256
            self.memory = realloc(self.memory, self.capacity)
        }
        memcpy(self.memory + self.offset, data + offset, length)
        self.offset += length
    }
}

public final class ReadBuffer {
    var memory: UnsafeMutablePointer<Void>
    var length: Int
    var offset : Int
    let freeWhenDone: Bool
    
    init(memory: UnsafeMutablePointer<Void>, length: Int, freeWhenDone: Bool) {
        self.memory = memory
        self.length = length
        self.offset = 0
        self.freeWhenDone = freeWhenDone
    }
    
    deinit {
        if self.freeWhenDone {
            free(self.memory)
        }
    }
    
    func read(data: UnsafeMutablePointer<Void>, offset: Int, length: Int) {
        memcpy(data + offset, self.memory + self.offset, length)
        self.offset += length
    }
    
    func reset() {
        self.offset = 0
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
    
    public func makeReadBufferAndReset() -> ReadBuffer {
        return self.buffer.makeReadBufferAndReset()
    }
    
    public func makeData() -> NSData {
        return self.buffer.makeData()
    }
    
    public func reset() {
        self.buffer.reset()
    }
    
    public func encodeKey(key: UnsafePointer<Int8>) {
        var length: Int8 = Int8(strlen(key))
        self.buffer.write(&length, offset: 0, length: 1)
        self.buffer.write(UnsafePointer<Void>(key), offset: 0, length: Int(length))
    }
    
    public func encodeInt32(value: Int32, forKey key: UnsafePointer<Int8>) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int32.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 4)
    }
    
    public func encodeInt64(value: Int64, forKey key: UnsafePointer<Int8>) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Int64.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 8)
    }
    
    public func encodeBool(value: Bool, forKey key: UnsafePointer<Int8>) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bool.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v: Int8 = value ? 1 : 0
        self.buffer.write(&v, offset: 0, length: 1)
    }
    
    public func encodeDouble(value: Double, forKey key: UnsafePointer<Int8>) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Double.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var v = value
        self.buffer.write(&v, offset: 0, length: 8)
    }
    
    public func encodeString(value: String, forKey key: UnsafePointer<Int8>) {
        self.encodeKey(key)
        var type: Int8 = ValueType.String.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        let data = value.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
        var length: Int32 = Int32(data.length)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(data.bytes, offset: 0, length: Int(length))
    }
    
    public func encodeRootObject(value: Coding) {
        self.encodeObject(value, forKey: "_")
    }
    
    public func encodeObject(value: Coding, forKey key: UnsafePointer<Int8>) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Object.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        
        var typeHash: Int32 = murMurHashString32(_stdlib_getDemangledTypeName(value))
        self.buffer.write(&typeHash, offset: 0, length: 4)
        
        let innerEncoder = Encoder()
        value.encode(innerEncoder)
        
        var length: Int32 = Int32(innerEncoder.buffer.offset)
        self.buffer.write(&length, offset: 0, length: 4)
        self.buffer.write(innerEncoder.buffer.memory, offset: 0, length: Int(length))
    }
    
    public func encodeInt32Array(value: [Int32], forKey key: UnsafePointer<Int8>) {
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
    
    public func encodeInt64Array(value: [Int64], forKey key: UnsafePointer<Int8>) {
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
    
    public func encodeObjectArray<T: Coding>(value: [T], forKey key: UnsafePointer<Int8>) {
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
    
    public func encodeObjectDictionary<K, V: Coding where K: Coding, K: Hashable>(value: [K : V], forKey key: UnsafePointer<Int8>) {
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
    
    public func encodeBytes(bytes: WriteBuffer, forKey key: UnsafePointer<Int8>) {
        self.encodeKey(key)
        var type: Int8 = ValueType.Bytes.rawValue
        self.buffer.write(&type, offset: 0, length: 1)
        var bytesLength: Int32 = Int32(bytes.offset)
        self.buffer.write(&bytesLength, offset: 0, length: 4)
        self.buffer.write(bytes.memory, offset: 0, length: bytes.offset)
    }
}

public final class Decoder {
    private let buffer: ReadBuffer
    
    public init(buffer: ReadBuffer) {
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
                    i++
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
                    i++
                }
            case .Bytes:
                var length: Int32 = 0
                memcpy(&length, bytes + offset, 4)
                offset += 4 + Int(length)
        }
    }
    
    private class func positionOnKey(bytes: UnsafePointer<Int8>, inout offset: Int, maxOffset: Int, length: Int, key: UnsafePointer<Int8>, valueType: ValueType) -> Bool
    {
        var startOffset = offset
        
        let keyLength: Int = Int(strlen(key))
        while (offset < maxOffset)
        {
            let readKeyLength = bytes[offset]
            offset += 1
            offset += Int(readKeyLength)
            
            let readValueType = bytes[offset]
            offset += 1
            
            if readValueType != valueType.rawValue || keyLength != Int(readKeyLength) || memcmp(bytes + (offset - Int(readKeyLength) - 1), key, keyLength) != 0 {
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
    
    public func decodeInt32ForKey(key: UnsafePointer<Int8>) -> Int32 {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32) {
            var value: Int32 = 0
            memcpy(&value, self.buffer.memory + self.buffer.offset, 4)
            self.buffer.offset += 4
            return value
        } else {
            return 0
        }
    }
    
    public func decodeInt64ForKey(key: UnsafePointer<Int8>) -> Int64 {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64) {
            var value: Int64 = 0
            memcpy(&value, self.buffer.memory + self.buffer.offset, 8)
            self.buffer.offset += 8
            return value
        } else {
            return 0
        }
    }
    
    public func decodeBoolForKey(key: UnsafePointer<Int8>) -> Bool {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bool) {
            var value: Int8 = 0
            memcpy(&value, self.buffer.memory + self.buffer.offset, 1)
            self.buffer.offset += 1
            return value != 0
        } else {
            return false
        }
    }
    
    public func decodeDoubleForKey(key: UnsafePointer<Int8>) -> Double {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Double) {
            var value: Double = 0
            memcpy(&value, self.buffer.memory + self.buffer.offset, 8)
            self.buffer.offset += 8
            return value
        } else {
            return 0
        }
    }
    
    public func decodeStringForKey(key: UnsafePointer<Int8>) -> String {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .String) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.buffer.offset, 4)
            let data = NSData(bytes: self.buffer.memory + (self.buffer.offset + 4), length: Int(length))
            self.buffer.offset += 4 + Int(length)
            let value = NSString(data: data, encoding: NSUTF8StringEncoding)
            return (value as? String) ?? ""
        } else {
            return ""
        }
    }
    
    public func decodeRootObject() -> Coding? {
        return self.decodeObjectForKey("_")
    }
    
    public func decodeObjectForKey(key: UnsafePointer<Int8>) -> Coding? {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Object) {
            var typeHash: Int32 = 0
            memcpy(&typeHash, self.buffer.memory + self.buffer.offset, 4)
            self.buffer.offset += 4
            
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.buffer.offset, 4)

            var innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.buffer.offset + 4), length: Int(length), freeWhenDone: false))
            self.buffer.offset += 4 + Int(length)
            
            return typeStore.decode(typeHash, decoder: innerDecoder)
        } else {
            return nil
        }
    }
    
    public func decodeInt32ArrayForKey(key: UnsafePointer<Int8>) -> [Int32] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int32Array) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.buffer.offset, 4)
            var array: [Int32] = []
            array.reserveCapacity(Int(length))
            var i: Int32 = 0
            while i < length {
                var element: Int32 = 0
                memcpy(&element, self.buffer.memory + (self.buffer.offset + 4 + 4 * Int(i)), 4)
                array.append(element)
                i++
            }
            self.buffer.offset += 4 + Int(length) * 4
            return array
        } else {
            return []
        }
    }
    
    public func decodeInt64ArrayForKey(key: UnsafePointer<Int8>) -> [Int64] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Int64Array) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.buffer.offset, 4)
            var array: [Int64] = []
            array.reserveCapacity(Int(length))
            var i: Int32 = 0
            while i < length {
                var element: Int64 = 0
                memcpy(&element, self.buffer.memory + (self.buffer.offset + 4 + 8 * Int(i)), 8)
                array.append(element)
                i++
            }
            self.buffer.offset += 4 + Int(length) * 8
            return array
        } else {
            return []
        }
    }
    
    public func decodeObjectArrayForKey<T: Coding>(key: UnsafePointer<Int8>) -> [T] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectArray) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.buffer.offset, 4)
            self.buffer.offset += 4
            
            var array: [T] = []
            array.reserveCapacity(Int(length))
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var typeHash: Int32 = 0
                memcpy(&typeHash, self.buffer.memory + self.buffer.offset, 4)
                self.buffer.offset += 4
                
                var objectLength: Int32 = 0
                memcpy(&objectLength, self.buffer.memory + self.buffer.offset, 4)
                
                var innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.buffer.offset + 4), length: Int(objectLength), freeWhenDone: false))
                self.buffer.offset += 4 + Int(objectLength)
                
                if !failed {
                    if let object = typeStore.decode(typeHash, decoder: innerDecoder) as? T {
                        array.append(object)
                    } else {
                        failed = true
                    }
                }
                
                i++
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
    
    public func decodeObjectDictionaryForKey<K, V: Coding where K: Coding, K: Hashable>(key: UnsafePointer<Int8>) -> [K : V] {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .ObjectDictionary) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.buffer.offset, 4)
            self.buffer.offset += 4
            
            var dictionary: [K : V] = [:]
            
            var failed = false
            var i: Int32 = 0
            while i < length {
                var keyHash: Int32 = 0
                memcpy(&keyHash, self.buffer.memory + self.buffer.offset, 4)
                self.buffer.offset += 4
                
                var keyLength: Int32 = 0
                memcpy(&keyLength, self.buffer.memory + self.buffer.offset, 4)
                
                var innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.buffer.offset + 4), length: Int(keyLength), freeWhenDone: false))
                self.buffer.offset += 4 + Int(keyLength)
                
                let key = failed ? nil : (typeStore.decode(keyHash, decoder: innerDecoder) as? K)
                    
                var valueHash: Int32 = 0
                memcpy(&valueHash, self.buffer.memory + self.buffer.offset, 4)
                self.buffer.offset += 4
                
                var valueLength: Int32 = 0
                memcpy(&valueLength, self.buffer.memory + self.buffer.offset, 4)
                
                innerDecoder = Decoder(buffer: ReadBuffer(memory: self.buffer.memory + (self.buffer.offset + 4), length: Int(valueLength), freeWhenDone: false))
                self.buffer.offset += 4 + Int(valueLength)
                
                let value = failed ? nil : (typeStore.decode(valueHash, decoder: innerDecoder) as? V)
                
                if let key = key, value = value {
                    dictionary[key] = value
                } else {
                    failed = true
                }
                
                i++
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
    
    public func decodeBytesForKeyNoCopy(key: UnsafePointer<Int8>) -> ReadBuffer! {
        if Decoder.positionOnKey(UnsafePointer<Int8>(self.buffer.memory), offset: &self.buffer.offset, maxOffset: self.buffer.length, length: self.buffer.length, key: key, valueType: .Bytes) {
            var length: Int32 = 0
            memcpy(&length, self.buffer.memory + self.buffer.offset, 4)
            self.buffer.offset += 4 + Int(length)
            return ReadBuffer(memory: UnsafeMutablePointer<Int8>(self.buffer.memory + (self.buffer.offset - Int(length))), length: Int(length), freeWhenDone: false)
        } else {
            return nil
        }
    }
}
