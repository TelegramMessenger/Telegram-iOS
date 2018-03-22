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

func decryptedSecureSecret(encryptedSecretData: Data, password: String) -> Data? {
    guard let passwordData = password.data(using: .utf8) else {
        return nil
    }
    let passwordHash = sha512Digest(passwordData)
    let secretKey = passwordHash.subdata(in: 0 ..< 32)
    let iv = passwordHash.subdata(in: 32 ..< (32 + 16))
    
    var decryptedSecret = Data(count: encryptedSecretData.count)
    
    guard decryptedSecret.withUnsafeMutableBytes({ (decryptedSecretBytes: UnsafeMutablePointer<Int8>) -> Bool in
        return secretKey.withUnsafeBytes { (secretKeyBytes: UnsafePointer<Int8>) -> Bool in
            return iv.withUnsafeBytes { (ivBytes: UnsafePointer<Int8>) -> Bool in
                return encryptedSecretData.withUnsafeBytes { (encryptedSecretDataBytes: UnsafePointer<Int8>) -> Bool in
                    var processedCount: Int = 0
                    let result = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES128), 0, secretKeyBytes, secretKey.count, ivBytes, encryptedSecretDataBytes, encryptedSecretData.count, decryptedSecretBytes, decryptedSecret.count, &processedCount)
                    if result != kCCSuccess {
                        return false
                    }
                    if processedCount != decryptedSecret.count {
                        return false
                    }
                    return true
                }
            }
        }
    }) else {
        return nil
    }
    
    guard decryptedSecret.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) -> Bool in
        var checksum: UInt32 = 0
        for i in 0 ..< decryptedSecret.count {
            checksum += UInt32(bytes.advanced(by: i).pointee)
            checksum = checksum % 255
        }
        if checksum == 239 {
            return true
        } else {
            return false
        }
    }) else {
        return nil
    }
    
    return decryptedSecret
}

func encryptedSecureSecret(secretData: Data, password: String) -> Data? {
    guard let passwordData = password.data(using: .utf8) else {
        return nil
    }
    
    let passwordHash = sha512Digest(passwordData)
    let secretKey = passwordHash.subdata(in: 0 ..< 32)
    let iv = passwordHash.subdata(in: 32 ..< (32 + 16))
    
    var encryptedSecret = Data(count: secretData.count)
    
    guard encryptedSecret.withUnsafeMutableBytes({ (encryptedSecretBytes: UnsafeMutablePointer<Int8>) -> Bool in
        return secretKey.withUnsafeBytes { (secretKeyBytes: UnsafePointer<Int8>) -> Bool in
            return iv.withUnsafeBytes { (ivBytes: UnsafePointer<Int8>) -> Bool in
                return secretData.withUnsafeBytes { (secretDataBytes: UnsafePointer<Int8>) -> Bool in
                    var processedCount: Int = 0
                    let result = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES128), 0, secretKeyBytes, secretKey.count, ivBytes, secretDataBytes, secretData.count, encryptedSecretBytes, encryptedSecret.count, &processedCount)
                    if result != kCCSuccess {
                        return false
                    }
                    if processedCount != encryptedSecret.count {
                        return false
                    }
                    return true
                }
            }
        }
    }) else {
        return nil
    }
    
    if decryptedSecureSecret(encryptedSecretData: encryptedSecret, password: password) != secretData {
        return nil
    }
    
    return encryptedSecret
}

private func generateSecureSecret(network: Network, password: String) -> Signal<Data, GenerateSecureSecretError> {
    var secretData = Data(count: 32)
    guard secretData.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<Int8>) -> Bool in
        let copyResult = SecRandomCopyBytes(nil, 32, bytes)
        return copyResult == errSecSuccess
    }) else {
        return .fail(.generic)
    }
    
    secretData.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) in
        while true {
            var checksum: UInt32 = 0
            for i in 0 ..< secretData.count {
                checksum += UInt32(bytes.advanced(by: i).pointee)
                checksum = checksum % 255
            }
            if checksum == 239 {
                break
            } else {
                var i = secretData.count - 1
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
    
    guard let encryptedSecret = encryptedSecureSecret(secretData: secretData, password: password) else {
        return .fail(.generic)
    }
    
    return updateTwoStepVerificationSecureSecret(network: network, password: password, updatedSecret: encryptedSecret)
    |> mapError { _ -> GenerateSecureSecretError in
        return .generic
    }
    |> map { _ -> Data in
        return secretData
    }
}

public struct SecureIdAccessContext {
    let secret: Data
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
            if let decryptedSecret = decryptedSecureSecret(encryptedSecretData: secureSecret, password: "q") { //password
                return .single(SecureIdAccessContext(secret: decryptedSecret))
            } else {
                return .fail(.secretPasswordMismatch)
            }
        } else {
            return generateSecureSecret(network: network, password: password)
            |> mapError { _ -> SecureIdAccessError in
                return SecureIdAccessError.generic
            }
            |> map { decryptedSecret in
                return SecureIdAccessContext(secret: decryptedSecret)
            }
        }
    }
}
