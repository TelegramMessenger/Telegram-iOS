import Foundation
import CommonCrypto

struct MasterNotificationKey: Codable {
    let id: Data
    let data: Data
}

struct AccountDatacenterKey: Codable {
    let id: Int64
    let data: Data
}

struct AccountDatacenterInfo: Codable {
    let masterKey: AccountDatacenterKey
}

struct StoredAccountInfo: Codable {
    let primaryId: Int32
    let isTestingEnvironment: Bool
    let datacenters: [Int32: AccountDatacenterInfo]
}

struct AccountData {
    let id: Int64
    let isTestingEnvironment: Bool
    let basePath: String
    let datacenterId: Int32
    let datacenters: [Int32: AccountDatacenterInfo]
    let notificationKey: MasterNotificationKey?
}

func loadAccountsData(rootPath: String) -> [Int64: AccountData] {
    var result: [Int64: AccountData] = [:]
    if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
        for url in contents {
            let directoryName = url.lastPathComponent
            if directoryName.hasPrefix("account-"), let id = UInt64(directoryName[directoryName.index(directoryName.startIndex, offsetBy: "account-".count)...]) {
                var notificationKey: MasterNotificationKey?
                if let data = try? Data(contentsOf: URL(fileURLWithPath: url.path + "/notificationsKey")), let value = try? JSONDecoder().decode(MasterNotificationKey.self, from: data) {
                    notificationKey = value
                }
                var storedInfo: StoredAccountInfo?
                if let data = try? Data(contentsOf: URL(fileURLWithPath: url.path + "/storedInfo")), let value = try? JSONDecoder().decode(StoredAccountInfo.self, from: data) {
                    storedInfo = value
                }
                if let storedInfo = storedInfo {
                    result[Int64(bitPattern: id)] = AccountData(id: Int64(bitPattern: id), isTestingEnvironment: storedInfo.isTestingEnvironment, basePath: url.path, datacenterId: storedInfo.primaryId, datacenters: storedInfo.datacenters, notificationKey: notificationKey)
                }
            }
        }
    }
    return result
}

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

func decryptedNotificationPayload(accounts: [Int64: AccountData], data: Data) -> (AccountData, [AnyHashable: Any])? {
    if data.count < 8 + 16 {
        return nil
    }
    
    for (_, account) in accounts {
        guard let notificationKey = account.notificationKey else {
            continue
        }
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
