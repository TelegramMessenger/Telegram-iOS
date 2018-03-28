import Foundation

public struct SecureIdValueAccessContext: Equatable {
    let secret: Data
    let hash: Int64
    
    public static func ==(lhs: SecureIdValueAccessContext, rhs: SecureIdValueAccessContext) -> Bool {
        if lhs.secret != rhs.secret {
            return false
        }
        if lhs.hash != rhs.hash {
            return false
        }
        return true
    }
}

public func generateSecureIdValueAccessContext() -> SecureIdValueAccessContext? {
    guard let secret = generateSecureSecretData() else {
        return nil
    }
    let secretHashData = sha512Digest(secret)
    var secretHash: Int64 = 0
    secretHashData.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
        memcpy(&secretHash, bytes.advanced(by: secretHashData.count - 8), 8)
    }
    return SecureIdValueAccessContext(secret: secret, hash: secretHash)
}
