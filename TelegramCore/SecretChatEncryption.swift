import Foundation
#if os(macOS)
    import PostboxMac
    import MtProtoKitMac
#else
    import Postbox
    import MtProtoKitDynamic
#endif

private func messageKey(key: SecretChatKey, msgKey: UnsafeRawPointer) -> (aesKey: Data, aesIv: Data) {
    let x: Int = 0
    
    var sha1AData = Data()
    sha1AData.count = 16 + 32
    sha1AData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        memcpy(bytes, msgKey, 16)
        memcpy(bytes.advanced(by: 16), key.key.memory.advanced(by: x), 32)
    }
    let sha1A = MTSha1(sha1AData)!
    
    var sha1BData = Data()
    sha1BData.count = 16 + 16 + 16
    sha1BData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        memcpy(bytes, key.key.memory.advanced(by: 32 + x), 16)
        memcpy(bytes.advanced(by: 16), msgKey, 16)
        memcpy(bytes.advanced(by: 16 + 16), key.key.memory.advanced(by: 48 + x), 16)
    }
    let sha1B = MTSha1(sha1BData)!
    
    var sha1CData = Data()
    sha1CData.count = 32 + 16
    sha1CData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        memcpy(bytes, key.key.memory.advanced(by: 64 + x), 32)
        memcpy(bytes.advanced(by: 32), msgKey, 16)
    }
    let sha1C = MTSha1(sha1CData)!
    
    var sha1DData = Data()
    sha1DData.count = 16 + 32
    sha1DData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        memcpy(bytes, msgKey, 16)
        memcpy(bytes.advanced(by: 16), key.key.memory.advanced(by: 96 + x), 32)
    }
    let sha1D = MTSha1(sha1DData)!
    
    var aesKey = Data()
    aesKey.count = 8 + 12 + 12
    aesKey.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        sha1A.withUnsafeBytes { (sha1A: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes, sha1A, 8)
        }
        sha1B.withUnsafeBytes { (sha1B: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes.advanced(by: 8), sha1B.advanced(by: 8), 12)
        }
        sha1C.withUnsafeBytes { (sha1C: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes.advanced(by: 8 + 12), sha1C.advanced(by: 4), 12)
        }
    }
    
    var aesIv = Data()
    aesIv.count = 12 + 8 + 4 + 8
    aesIv.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        sha1A.withUnsafeBytes { (sha1A: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes, sha1A.advanced(by: 8), 12)
        }
        sha1B.withUnsafeBytes { (sha1B: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes.advanced(by: 12), sha1B, 8)
        }
        sha1C.withUnsafeBytes { (sha1C: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes.advanced(by: 12 + 8), sha1C.advanced(by: 16), 4)
        }
        sha1D.withUnsafeBytes { (sha1D: UnsafePointer<UInt8>) -> Void in
            memcpy(bytes.advanced(by: 12 + 8 + 4), sha1D, 8)
        }
    }
    return (aesKey, aesIv)
}

func withDecryptedMessageContents(key: SecretChatKey, data: MemoryBuffer, _ f: (MemoryBuffer?) -> Void) {
    assert(key.key.length == 256)
    
    if data.length < 4 + 16 + 16 {
        f(nil)
        return
    }
    
    let msgKey = data.memory.advanced(by: 8)
    
    let (aesKey, aesIv) = messageKey(key: key, msgKey: msgKey)
    
    let decryptedData = MTAesDecrypt(Data(bytes: data.memory.advanced(by: 8 + 16), count: data.length - (8 + 16)), aesKey, aesIv)!
    
    if decryptedData.count < 4 * 3 {
        f(nil)
        return
    }
    
    var payloadLength: Int32 = 0
    decryptedData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
        memcpy(&payloadLength, bytes, 4)
    }
    
    let paddingLength = decryptedData.count - (Int(payloadLength) + 4)
    if Int(payloadLength) > decryptedData.count - 4 || paddingLength > 16 {
        f(nil)
        return
    }
    
    let calculatedMsgKeyData = MTSubdataSha1(decryptedData, 0, UInt(payloadLength) + 4)!
    let msgKeyMatches = calculatedMsgKeyData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Bool in
        return memcmp(bytes.advanced(by: calculatedMsgKeyData.count - 16), msgKey, 16) == 0
    }
    
    if !msgKeyMatches {
        f(nil)
        return
    }
    
    decryptedData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
        f(MemoryBuffer(memory: UnsafeMutablePointer(mutating: bytes.advanced(by: 4)), capacity: Int(payloadLength), length: Int(payloadLength), freeWhenDone: false))
    }
}

func encryptedMessageContents(key: SecretChatKey, data: MemoryBuffer) -> Data {
    var payloadLength: Int32 = Int32(data.length)
    var payloadData = Data()
    withUnsafeBytes(of: &payloadLength, { bytes -> Void in
        payloadData.append(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 4)
    })
    payloadData.append(data.memory.assumingMemoryBound(to: UInt8.self), count: data.length)
    
    var msgKey = MTSha1(payloadData)!
    msgKey.replaceSubrange(0 ..< (msgKey.count - 16), with: Data())
    
    var randomBuf = malloc(16)!
    defer {
        free(randomBuf)
    }
    let randomBytes = randomBuf.assumingMemoryBound(to: UInt8.self)
    arc4random_buf(randomBuf, 16)
    
    var randomIndex = 0
    while payloadData.count % 16 != 0 {
        payloadData.append(randomBytes.advanced(by: randomIndex), count: 1)
        randomIndex += 1
    }
    
    let (aesKey, aesIv) = msgKey.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> (Data, Data) in
        return messageKey(key: key, msgKey: bytes)
    }
    
    let encryptedData = MTAesEncrypt(payloadData, aesKey, aesIv)!
    var encryptedPayload = Data()
    var keyFingerprint: Int64 = key.fingerprint
    withUnsafeBytes(of: &keyFingerprint, { bytes -> Void in
        encryptedPayload.append(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 8)
    })
    encryptedPayload.append(msgKey)
    encryptedPayload.append(encryptedData)
    return encryptedPayload
}
