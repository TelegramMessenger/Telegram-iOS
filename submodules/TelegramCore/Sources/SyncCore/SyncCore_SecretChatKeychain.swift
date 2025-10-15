import Foundation
import Postbox

public enum SecretChatKeyValidity: PostboxCoding, Equatable {
    case indefinite
    case sequenceBasedIndexRange(fromCanonicalIndex: Int32)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case 0:
                self = .indefinite
            case 1:
                self = .sequenceBasedIndexRange(fromCanonicalIndex: decoder.decodeInt32ForKey("l", orElse: 0))
            default:
                assertionFailure()
                self = .sequenceBasedIndexRange(fromCanonicalIndex: Int32.max)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .indefinite:
                encoder.encodeInt32(0, forKey: "r")
            case let .sequenceBasedIndexRange(fromCanonicalIndex):
                encoder.encodeInt32(1, forKey: "r")
                encoder.encodeInt32(fromCanonicalIndex, forKey: "l")
        }
    }
    
    public static func ==(lhs: SecretChatKeyValidity, rhs: SecretChatKeyValidity) -> Bool {
        switch lhs {
            case .indefinite:
                if case .indefinite = rhs {
                    return true
                } else {
                    return false
                }
            case let .sequenceBasedIndexRange(fromCanonicalIndex):
                if case .sequenceBasedIndexRange(fromCanonicalIndex) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class SecretChatKey: PostboxCoding, Equatable {
    public let fingerprint: Int64
    public let key: MemoryBuffer
    public let validity: SecretChatKeyValidity
    public let useCount: Int32
    
    public init(fingerprint: Int64, key: MemoryBuffer, validity: SecretChatKeyValidity, useCount: Int32) {
        self.fingerprint = fingerprint
        self.key = key
        self.validity = validity
        self.useCount = useCount
    }
    
    public init(decoder: PostboxDecoder) {
        self.fingerprint = decoder.decodeInt64ForKey("f", orElse: 0)
        self.key = decoder.decodeBytesForKey("k")!
        self.validity = decoder.decodeObjectForKey("v", decoder: { SecretChatKeyValidity(decoder: $0) }) as! SecretChatKeyValidity
        self.useCount = decoder.decodeInt32ForKey("u", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.fingerprint, forKey: "f")
        encoder.encodeBytes(self.key, forKey: "k")
        encoder.encodeObject(self.validity, forKey: "v")
        encoder.encodeInt32(self.useCount, forKey: "u")
    }
    
    public func withIncrementedUseCount() -> SecretChatKey {
        return SecretChatKey(fingerprint: self.fingerprint, key: self.key, validity: self.validity, useCount: self.useCount + 1)
    }
    
    public static func ==(lhs: SecretChatKey, rhs: SecretChatKey) -> Bool {
        if lhs.fingerprint != rhs.fingerprint {
            return false
        }
        if lhs.validity != rhs.validity {
            return false
        }
        if lhs.useCount != rhs.useCount {
            return false
        }
        return true
    }
}

public final class SecretChatKeychain: PostboxCoding, Equatable {
    public let keys: [SecretChatKey]
    
    public init(keys: [SecretChatKey]) {
        self.keys = keys
    }
    
    public init(decoder: PostboxDecoder) {
        self.keys = decoder.decodeObjectArrayWithDecoderForKey("k")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.keys, forKey: "k")
    }
    
    public func key(fingerprint: Int64) -> SecretChatKey? {
        for key in self.keys {
            if key.fingerprint == fingerprint {
                return key
            }
        }
        return nil
    }
    
    public func indefinitelyValidKey() -> SecretChatKey? {
        for key in self.keys {
            if case .indefinite = key.validity {
                return key
            }
        }
        return nil
    }
    
    public func latestKey(validForSequenceBasedCanonicalIndex index: Int32) -> SecretChatKey? {
        var maxFromCanonicalIndex: (Int, Int32)?
        for i in 0 ..< self.keys.count {
            switch self.keys[i].validity {
                case .indefinite:
                    break
                case let .sequenceBasedIndexRange(fromCanonicalIndex):
                    if index >= fromCanonicalIndex {
                        if maxFromCanonicalIndex == nil || maxFromCanonicalIndex!.1 < fromCanonicalIndex {
                            maxFromCanonicalIndex = (i, fromCanonicalIndex)
                        }
                    }
            }
        }
        
        if let (keyIndex, _) = maxFromCanonicalIndex {
            return self.keys[keyIndex]
        }
        
        for i in 0 ..< self.keys.count {
            switch self.keys[i].validity {
                case .indefinite:
                    return self.keys[i]
                default:
                    break
            }
        }
        
        return nil
    }
    
    public func withUpdatedKey(fingerprint: Int64, _ f: (SecretChatKey?) -> SecretChatKey?) -> SecretChatKeychain {
        var keys = self.keys
        var found = false
        for i in 0 ..< keys.count {
            if keys[i].fingerprint == fingerprint {
                found = true
                let updatedKey = f(keys[i])
                if let updatedKey = updatedKey {
                    keys[i] = updatedKey
                } else {
                    keys.remove(at: i)
                }
                break
            }
        }
        if !found {
            let updatedKey = f(nil)
            if let updatedKey = updatedKey {
                keys.append(updatedKey)
            }
        }
        return SecretChatKeychain(keys: keys)
    }
    
    public static func ==(lhs: SecretChatKeychain, rhs: SecretChatKeychain) -> Bool {
        return lhs.keys == rhs.keys
    }
}
