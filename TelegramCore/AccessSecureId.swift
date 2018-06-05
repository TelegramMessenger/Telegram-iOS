import Foundation
#if os(macOS)
    import PostboxMac
    import MtProtoKitMac
    import SwiftSignalKitMac
#else
    import Postbox
    import MtProtoKitDynamic
    import SwiftSignalKit
#endif

import TelegramCorePrivateModule

private enum GenerateSecureSecretError {
    case generic
}

func encryptSecureData(key: Data, iv: Data, data: Data, decrypt: Bool) -> Data? {
    if data.count % 16 != 0 {
        return nil
    }
    
    return CryptoAES(!decrypt, key, iv, data)
}

func verifySecureSecret(_ data: Data) -> Bool {
    guard data.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Bool in
        var checksum: UInt32 = 0
        for i in 0 ..< data.count {
            checksum += UInt32(bytes.advanced(by: i).pointee)
            checksum = checksum % 255
        }
        if checksum == 239 {
            return true
        } else {
            return false
        }
    }) else {
        return false
    }
    return true
}

func decryptedSecureSecret(encryptedSecretData: Data, password: String, salt: Data, id: Int64) -> Data? {
    guard let passwordData = password.data(using: .utf8) else {
        return nil
    }
    let passwordHash = sha512Digest(salt + passwordData + salt)
    let secretKey = passwordHash.subdata(in: 0 ..< 32)
    let iv = passwordHash.subdata(in: 32 ..< (32 + 16))
    
    guard let decryptedSecret = CryptoAES(false, secretKey, iv, encryptedSecretData) else {
        return nil;
    }
    
    if !verifySecureSecret(decryptedSecret) {
        return nil
    }
    
    let secretHashData = sha256Digest(decryptedSecret)
    var secretId: Int64 = 0
    secretHashData.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
        memcpy(&secretId, bytes, 8)
    }
    
    if secretId != id {
        return nil
    }
    
    return decryptedSecret
}

func encryptedSecureSecret(secretData: Data, password: String, inputSalt: Data) -> (data: Data, salt: Data, id: Int64)? {
    let secretHashData = sha256Digest(secretData)
    var secretId: Int64 = 0
    secretHashData.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
        memcpy(&secretId, bytes, 8)
    }
    
    guard let passwordData = password.data(using: .utf8) else {
        return nil
    }
    
    var randomSalt = Data(count: 8)
    let randomSaltCount = randomSalt.count
    guard randomSalt.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<Int8>) -> Bool in
        let result = SecRandomCopyBytes(nil, randomSaltCount, bytes)
        return result == errSecSuccess
    }) else {
        return nil
    }
    
    let secretSalt = inputSalt + randomSalt
    
    let passwordHash = sha512Digest(secretSalt + passwordData + secretSalt)
    let secretKey = passwordHash.subdata(in: 0 ..< 32)
    let iv = passwordHash.subdata(in: 32 ..< (32 + 16))
    
    guard let encryptedSecret = CryptoAES(true, secretKey, iv, secretData) else {
        return nil
    }
    
    if decryptedSecureSecret(encryptedSecretData: encryptedSecret, password: password, salt: secretSalt, id: secretId) != secretData {
        return nil
    }
    
    return (encryptedSecret, secretSalt, secretId)
}

func generateSecureSecretData() -> Data? {
    var secretData = Data(count: 32)
    let secretDataCount = secretData.count
    
    guard secretData.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<Int8>) -> Bool in
        let copyResult = SecRandomCopyBytes(nil, 32, bytes)
        return copyResult == errSecSuccess
    }) else {
        return nil
    }
    
    secretData.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) in
        while true {
            var checksum: UInt32 = 0
            for i in 0 ..< secretDataCount {
                checksum += UInt32(bytes.advanced(by: i).pointee)
                checksum = checksum % 255
            }
            if checksum == 239 {
                break
            } else {
                var i = secretDataCount - 1
                inner: while i >= 0 {
                    var byte = bytes.advanced(by: i).pointee
                    if byte != 0xff {
                        byte += 1
                        bytes.advanced(by: i).pointee = byte
                        break inner
                    } else {
                        byte = 0
                        bytes.advanced(by: i).pointee = byte
                    }
                    i -= 1
                }
            }
        }
    })
    return secretData
}

private func generateSecureSecret(network: Network, password: String) -> Signal<Data, GenerateSecureSecretError> {
    guard let secretData = generateSecureSecretData() else {
        return .fail(.generic)
    }
    
    return updateTwoStepVerificationSecureSecret(network: network, password: password, secret: secretData)
    |> mapError { _ -> GenerateSecureSecretError in
        return .generic
    }
    |> map { _ -> Data in
        return secretData
    }
}

public struct SecureIdAccessContext {
    let secret: Data
    let id: Int64
}

public enum SecureIdAccessError {
    case generic
    case passwordError(AuthorizationPasswordVerificationError)
    case secretPasswordMismatch
}

public func accessSecureId(network: Network, password: String) -> Signal<SecureIdAccessContext, SecureIdAccessError> {
    return requestTwoStepVerifiationSettings(network: network, password: password)
    |> mapError { error -> SecureIdAccessError in
        return .passwordError(error)
    }
    |> mapToSignal { settings -> Signal<SecureIdAccessContext, SecureIdAccessError> in
        if let secureSecret = settings.secureSecret {
            if let decryptedSecret = decryptedSecureSecret(encryptedSecretData: secureSecret.data, password: password, salt: secureSecret.salt, id: secureSecret.id) {
                return .single(SecureIdAccessContext(secret: decryptedSecret, id: secureSecret.id))
            } else {
                return .fail(.secretPasswordMismatch)
            }
        } else {
            return generateSecureSecret(network: network, password: password)
            |> mapError { _ -> SecureIdAccessError in
                return SecureIdAccessError.generic
            }
            |> map { decryptedSecret in
                let secretHashData = sha256Digest(decryptedSecret)
                var secretId: Int64 = 0
                secretHashData.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                    memcpy(&secretId, bytes, 8)
                }
                return SecureIdAccessContext(secret: decryptedSecret, id: secretId)
            }
        }
    }
}
