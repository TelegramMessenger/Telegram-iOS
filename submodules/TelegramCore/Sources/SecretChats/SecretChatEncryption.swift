import Foundation
import Postbox
import MtProtoKit


private func messageKey(key: SecretChatKey, msgKey: UnsafeRawPointer, mode: SecretChatEncryptionMode) -> (aesKey: Data, aesIv: Data) {
    switch mode {
        case .v1:
            let x: Int = 0
            
            var sha1AData = Data()
            sha1AData.count = 16 + 32
            sha1AData.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                memcpy(bytes, msgKey, 16)
                memcpy(bytes.advanced(by: 16), key.key.memory.advanced(by: x), 32)
            }
            let sha1A = MTSha1(sha1AData)
            
            var sha1BData = Data()
            sha1BData.count = 16 + 16 + 16
            sha1BData.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                memcpy(bytes, key.key.memory.advanced(by: 32 + x), 16)
                memcpy(bytes.advanced(by: 16), msgKey, 16)
                memcpy(bytes.advanced(by: 16 + 16), key.key.memory.advanced(by: 48 + x), 16)
            }
            let sha1B = MTSha1(sha1BData)
            
            var sha1CData = Data()
            sha1CData.count = 32 + 16
            sha1CData.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                memcpy(bytes, key.key.memory.advanced(by: 64 + x), 32)
                memcpy(bytes.advanced(by: 32), msgKey, 16)
            }
            let sha1C = MTSha1(sha1CData)
            
            var sha1DData = Data()
            sha1DData.count = 16 + 32
            sha1DData.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                memcpy(bytes, msgKey, 16)
                memcpy(bytes.advanced(by: 16), key.key.memory.advanced(by: 96 + x), 32)
            }
            let sha1D = MTSha1(sha1DData)
            
            var aesKey = Data()
            aesKey.count = 8 + 12 + 12
            aesKey.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                sha1A.withUnsafeBytes { sha1A -> Void in
                    memcpy(bytes, sha1A.baseAddress!.assumingMemoryBound(to: UInt8.self), 8)
                }
                sha1B.withUnsafeBytes { sha1B -> Void in
                    memcpy(bytes.advanced(by: 8), sha1B.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: 8), 12)
                }
                sha1C.withUnsafeBytes { sha1C -> Void in
                    memcpy(bytes.advanced(by: 8 + 12), sha1C.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: 4), 12)
                }
            }
            
            var aesIv = Data()
            aesIv.count = 12 + 8 + 4 + 8
            aesIv.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                sha1A.withUnsafeBytes { sha1A -> Void in
                    memcpy(bytes, sha1A.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: 8), 12)
                }
                sha1B.withUnsafeBytes { sha1B -> Void in
                    memcpy(bytes.advanced(by: 12), sha1B.baseAddress!.assumingMemoryBound(to: UInt8.self), 8)
                }
                sha1C.withUnsafeBytes { sha1C -> Void in
                    memcpy(bytes.advanced(by: 12 + 8), sha1C.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: 16), 4)
                }
                sha1D.withUnsafeBytes { sha1D -> Void in
                    memcpy(bytes.advanced(by: 12 + 8 + 4), sha1D.baseAddress!.assumingMemoryBound(to: UInt8.self), 8)
                }
            }
            return (aesKey, aesIv)
        case let .v2(role):
            var xValue: Int
            switch role {
                case .creator:
                    xValue = 0
                case .participant:
                    xValue = 8
            }
            
            var sha256_a_data = Data()
            sha256_a_data.append(msgKey.assumingMemoryBound(to: UInt8.self), count: 16)
            sha256_a_data.append(key.key.memory.assumingMemoryBound(to: UInt8.self).advanced(by: xValue), count: 36)
            
            let sha256_a = MTSha256(sha256_a_data)
            
            var sha256_b_data = Data()
            sha256_b_data.append(key.key.memory.assumingMemoryBound(to: UInt8.self).advanced(by: 40 + xValue), count: 36)
            sha256_b_data.append(msgKey.assumingMemoryBound(to: UInt8.self), count: 16)
            
            let sha256_b = MTSha256(sha256_b_data)
            
            var aesKey = Data()
            aesKey.append(sha256_a.subdata(in: 0 ..< (0 + 8)))
            aesKey.append(sha256_b.subdata(in: 8 ..< (8 + 16)))
            aesKey.append(sha256_a.subdata(in: 24 ..< (24 + 8)))
            
            var aesIv = Data()
            aesIv.append(sha256_b.subdata(in: 0 ..< (0 + 8)))
            aesIv.append(sha256_a.subdata(in: 8 ..< (8 + 16)))
            aesIv.append(sha256_b.subdata(in: 24 ..< (24 + 8)))
            
            return (aesKey, aesIv)
    }
}

func withDecryptedMessageContents(parameters: SecretChatEncryptionParameters, data: MemoryBuffer) -> MemoryBuffer? {
    assert(parameters.key.key.length == 256)
    
    if data.length < 4 + 16 + 16 {
        return nil
    }
    
    let msgKey = data.memory.advanced(by: 8)
    
    switch parameters.mode {
        case .v1:
            let (aesKey, aesIv) = messageKey(key: parameters.key, msgKey: msgKey, mode: parameters.mode)
            
            let decryptedData = MTAesDecrypt(Data(bytes: data.memory.advanced(by: 8 + 16), count: data.length - (8 + 16)), aesKey, aesIv)!
            
            if decryptedData.count < 4 * 3 {
                return nil
            }
            
            var payloadLength: Int32 = 0
            decryptedData.withUnsafeBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                memcpy(&payloadLength, bytes, 4)
            }
            
            let paddingLength = decryptedData.count - (Int(payloadLength) + 4)
            if Int(payloadLength) > decryptedData.count - 4 || paddingLength > 16 {
                return nil
            }
            
            let calculatedMsgKeyData = MTSubdataSha1(decryptedData, 0, UInt(payloadLength) + 4)
            let msgKeyMatches = calculatedMsgKeyData.withUnsafeBytes { rawBytes -> Bool in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                return memcmp(bytes.advanced(by: calculatedMsgKeyData.count - 16), msgKey, 16) == 0
            }
            
            if !msgKeyMatches {
                return nil
            }
            
            let result = decryptedData.withUnsafeBytes { rawBytes -> Data in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                return Data(bytes: bytes.advanced(by: 4), count: Int(payloadLength))
            }
            return MemoryBuffer(data: result)
        case let .v2(role):
            let senderRole: SecretChatRole
            switch role {
                case .creator:
                    senderRole = .participant
                case .participant:
                    senderRole = .creator
            }
            let (aesKey, aesIv) = messageKey(key: parameters.key, msgKey: msgKey, mode: .v2(role: senderRole))
            
            let decryptedData = MTAesDecrypt(Data(bytes: data.memory.advanced(by: 8 + 16), count: data.length - (8 + 16)), aesKey, aesIv)!
            
            if decryptedData.count < 4 * 3 {
                return nil
            }
            
            var payloadLength: Int32 = 0
            decryptedData.withUnsafeBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                memcpy(&payloadLength, bytes, 4)
            }
            
            let paddingLength = decryptedData.count - (Int(payloadLength) + 4)
            
            let xValue: Int
            switch role {
                case .creator:
                    xValue = 8
                case .participant:
                    xValue = 0
            }
            
            var keyLargeData = Data()
            keyLargeData.append(parameters.key.key.memory.assumingMemoryBound(to: UInt8.self).advanced(by: 88 + xValue), count: 32)
            keyLargeData.append(decryptedData)
            
            let keyLarge = MTSha256(keyLargeData)
            let localMessageKey = keyLarge.subdata(in: 8 ..< (8 + 16))
            
            let msgKeyData = Data(bytes: msgKey.assumingMemoryBound(to: UInt8.self), count: 16)
            
            if Int(payloadLength) <= 0 || Int(payloadLength) > decryptedData.count - 4 || paddingLength < 12 || paddingLength > 1024 {
                
                if localMessageKey != msgKeyData {
                    Logger.shared.log("SecretChatEncryption", "message key doesn't match (length check)")
                }
                
                return nil
            }
            
            if localMessageKey != msgKeyData {
                Logger.shared.log("SecretChatEncryption", "message key doesn't match")
                return nil
            }
            
            let result = decryptedData.withUnsafeBytes { rawBytes -> Data in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                return Data(bytes: bytes.advanced(by: 4), count: Int(payloadLength))
            }
            return MemoryBuffer(data: result)
    }
}

enum SecretChatEncryptionMode {
    case v1
    case v2(role: SecretChatRole)
}

struct SecretChatEncryptionParameters {
    let key: SecretChatKey
    let mode: SecretChatEncryptionMode
}

func encryptedMessageContents(parameters: SecretChatEncryptionParameters, data: MemoryBuffer) -> Data {
    var payloadLength: Int32 = Int32(data.length)
    var payloadData = Data()
    withUnsafeBytes(of: &payloadLength, { bytes -> Void in
        payloadData.append(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 4)
    })
    payloadData.append(data.memory.assumingMemoryBound(to: UInt8.self), count: data.length)
    
    switch parameters.mode {
        case .v1:
            var msgKey = MTSha1(payloadData)
            msgKey.replaceSubrange(0 ..< (msgKey.count - 16), with: Data())
            
            let randomBuf = malloc(16)!
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
            
            let (aesKey, aesIv) = msgKey.withUnsafeBytes { rawBytes -> (Data, Data) in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                return messageKey(key: parameters.key, msgKey: bytes, mode: parameters.mode)
            }
            
            let encryptedData = MTAesEncrypt(payloadData, aesKey, aesIv)!
            var encryptedPayload = Data()
            var keyFingerprint: Int64 = parameters.key.fingerprint
            withUnsafeBytes(of: &keyFingerprint, { bytes -> Void in
                encryptedPayload.append(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 8)
            })
            encryptedPayload.append(msgKey)
            encryptedPayload.append(encryptedData)
            return encryptedPayload
        case let .v2(role):
            var randomBytes = Data(count: 128)
            let randomBytesCount = randomBytes.count
            randomBytes.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

                arc4random_buf(bytes, randomBytesCount)
            }
            
            var decryptedData = payloadData
            var take = 0
            while take < 12 {
                decryptedData.append(randomBytes.subdata(in: take ..< (take + 1)))
                take += 1
            }
            
            while decryptedData.count % 16 != 0 {
                decryptedData.append(randomBytes.subdata(in: take ..< (take + 1)))
                take += 1
            }
            
            var remainingCount = Int(arc4random_uniform(UInt32(72 + 1 - take)))
            while remainingCount % 16 != 0 {
                remainingCount -= 1
            }
            
            for _ in 0 ..< remainingCount {
                decryptedData.append(randomBytes.subdata(in: take ..< (take + 1)))
                take += 1
            }
            
            var xValue: Int
            switch role {
                case .creator:
                    xValue = 0
                case .participant:
                    xValue = 8
            }
            
            var keyData = Data()
            keyData.append(parameters.key.key.memory.assumingMemoryBound(to: UInt8.self).advanced(by: 88 + xValue), count: 32)
            
            keyData.append(decryptedData)
            
            let keyLarge = MTSha256(keyData)
            
            let msgKey = keyLarge.subdata(in: 8 ..< (8 + 16))
            
            let (aesKey, aesIv) = msgKey.withUnsafeBytes { rawBytes -> (Data, Data) in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                return messageKey(key: parameters.key, msgKey: bytes, mode: parameters.mode)
            }
            
            let encryptedData = MTAesEncrypt(decryptedData, aesKey, aesIv)!
            var encryptedPayload = Data()
            var keyFingerprint: Int64 = parameters.key.fingerprint
            withUnsafeBytes(of: &keyFingerprint, { bytes -> Void in
                encryptedPayload.append(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 8)
            })
            encryptedPayload.append(msgKey)
            encryptedPayload.append(encryptedData)
            return encryptedPayload
    }
}
