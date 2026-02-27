import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import CryptoUtils

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
    guard data.withUnsafeBytes({ rawBytes -> Bool in
        let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
        
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

func decryptedSecureSecret(encryptedSecretData: Data, password: String, derivation: TwoStepSecurePasswordDerivation, id: Int64) -> Data? {
    guard let passwordHash = securePasswordKDF(password: password, derivation: derivation) else {
        return nil
    }
    
    let secretKey = passwordHash.subdata(in: 0 ..< 32)
    let iv = passwordHash.subdata(in: 32 ..< (32 + 16))
    
    guard let decryptedSecret = CryptoAES(false, secretKey, iv, encryptedSecretData) else {
        return nil
    }
    
    if !verifySecureSecret(decryptedSecret) {
        return nil
    }
    
    let secretHashData = sha256Digest(decryptedSecret)
    var secretId: Int64 = 0
    secretHashData.withUnsafeBytes { rawBytes -> Void in
        let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

        memcpy(&secretId, bytes, 8)
    }
    
    if secretId != id {
        return nil
    }
    
    return decryptedSecret
}

func encryptedSecureSecret(secretData: Data, password: String, inputDerivation: TwoStepSecurePasswordDerivation) -> (data: Data, salt: TwoStepSecurePasswordDerivation, id: Int64)? {
    let secretHashData = sha256Digest(secretData)
    var secretId: Int64 = 0
    secretHashData.withUnsafeBytes { rawBytes -> Void in
        let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

        memcpy(&secretId, bytes, 8)
    }
    
    guard let (passwordHash, updatedDerivation) = securePasswordUpdateKDF(password: password, derivation: inputDerivation) else {
        return nil
    }
    
    let secretKey = passwordHash.subdata(in: 0 ..< 32)
    let iv = passwordHash.subdata(in: 32 ..< (32 + 16))
    
    guard let encryptedSecret = CryptoAES(true, secretKey, iv, secretData) else {
        return nil
    }
    
    if decryptedSecureSecret(encryptedSecretData: encryptedSecret, password: password, derivation: updatedDerivation, id: secretId) != secretData {
        return nil
    }
    
    return (encryptedSecret, updatedDerivation, secretId)
}

func generateSecureSecretData() -> Data? {
    var secretData = Data(count: 32)
    let secretDataCount = secretData.count
    
    guard secretData.withUnsafeMutableBytes({ rawBytes -> Bool in
        let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

        let copyResult = SecRandomCopyBytes(nil, 32, bytes)
        return copyResult == errSecSuccess
    }) else {
        return nil
    }
    
    secretData.withUnsafeMutableBytes({ rawBytes -> Void in
        let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

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

public struct SecureIdAccessContext: Equatable {
    let secret: Data
    let id: Int64
}

public enum SecureIdAccessError {
    case generic
    case passwordError(AuthorizationPasswordVerificationError)
    case secretPasswordMismatch
}

func _internal_accessSecureId(network: Network, password: String) -> Signal<(context: SecureIdAccessContext, settings: TwoStepVerificationSettings), SecureIdAccessError> {
    return _internal_requestTwoStepVerifiationSettings(network: network, password: password)
    |> mapError { error -> SecureIdAccessError in
        return .passwordError(error)
    }
    |> mapToSignal { settings -> Signal<(context: SecureIdAccessContext, settings: TwoStepVerificationSettings), SecureIdAccessError> in
        if let secureSecret = settings.secureSecret {
            if let decryptedSecret = decryptedSecureSecret(encryptedSecretData: secureSecret.data, password: password, derivation: secureSecret.derivation, id: secureSecret.id) {
                return .single((SecureIdAccessContext(secret: decryptedSecret, id: secureSecret.id), settings))
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
                secretHashData.withUnsafeBytes { rawBytes -> Void in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

                    memcpy(&secretId, bytes, 8)
                }
                return (SecureIdAccessContext(secret: decryptedSecret, id: secretId), settings)
            }
        }
    }
}
