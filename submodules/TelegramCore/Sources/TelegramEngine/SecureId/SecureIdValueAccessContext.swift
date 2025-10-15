import Foundation

public struct SecureIdValueAccessContext: Equatable {
    let secret: Data
    let id: Int64
    
    public static func ==(lhs: SecureIdValueAccessContext, rhs: SecureIdValueAccessContext) -> Bool {
        if lhs.secret != rhs.secret {
            return false
        }
        if lhs.id != rhs.id {
            return false
        }
        return true
    }
}

public func generateSecureIdValueEmptyAccessContext() -> SecureIdValueAccessContext? {
    return SecureIdValueAccessContext(secret: Data(), id: 0)
}

public func generateSecureIdValueAccessContext() -> SecureIdValueAccessContext? {
    guard let secret = generateSecureSecretData() else {
        return nil
    }
    let secretHashData = sha512Digest(secret)
    var secretHash: Int64 = 0
    secretHashData.withUnsafeBytes { rawBytes -> Void in
        let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

        memcpy(&secretHash, bytes.advanced(by: secretHashData.count - 8), 8)
    }
    return SecureIdValueAccessContext(secret: secret, id: secretHash)
}
