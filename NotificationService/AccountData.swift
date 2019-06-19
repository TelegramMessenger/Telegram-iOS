import Foundation
import CommonCrypto
import LightweightAccountData

private func sha256Digest(_ data: Data) -> Data {
    let length = data.count
    return data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Data in
        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        result.withUnsafeMutableBytes { (destBytes: UnsafeMutablePointer<UInt8>) -> Void in
            CC_SHA256(bytes, UInt32(length), destBytes)
        }
        return result
    }
}

func decryptedNotificationPayload(accounts: [StoredAccountInfo], data: Data) -> (StoredAccountInfo, [AnyHashable: Any])? {
    if data.count < 8 + 16 {
        return nil
    }
    
    for account in accounts {
        let notificationKey = account.notificationKey
        
        if data.subdata(in: 0 ..< 8) != notificationKey.id {
            continue
        }
        
        let x = 8
        let msgKey = data.subdata(in: 8 ..< (8 + 16))
        let rawData = data.subdata(in: (8 + 16) ..< data.count)
        let sha256_a = sha256Digest(msgKey + notificationKey.data.subdata(in: x ..< (x + 36)))
        let sha256_b = sha256Digest(notificationKey.data.subdata(in: (40 + x) ..< (40 + x + 36)) + msgKey)
        let aesKey = sha256_a.subdata(in: 0 ..< 8) + sha256_b.subdata(in: 8 ..< (8 + 16)) + sha256_a.subdata(in: 24 ..< (24 + 8))
        let aesIv = sha256_b.subdata(in: 0 ..< 8) + sha256_a.subdata(in: 8 ..< (8 + 16)) + sha256_b.subdata(in: 24 ..< (24 + 8))
        
        guard let data = MTAesDecrypt(rawData, aesKey, aesIv), data.count > 4 else {
            return nil
        }
        
        var dataLength: Int32 = 0
        data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
            memcpy(&dataLength, bytes, 4)
        }
        
        if dataLength < 0 || dataLength > data.count - 4 {
            return nil
        }
        
        let checkMsgKeyLarge = sha256Digest(notificationKey.data.subdata(in: (88 + x) ..< (88 + x + 32)) + data)
        let checkMsgKey = checkMsgKeyLarge.subdata(in: 8 ..< (8 + 16))
        
        if checkMsgKey != msgKey {
            return nil
        }
        
        let contentData = data.subdata(in: 4 ..< (4 + Int(dataLength)))
        guard let result = try? JSONSerialization.jsonObject(with: contentData, options: []) else {
            return nil
        }
        guard let dict = result as? [AnyHashable: Any] else {
            return nil
        }
        return (account, dict)
    }
    return nil
}
