#if canImport(CryptoKit)
import Foundation
import CryptoKit
import CommonCrypto

extension Data {
    var sha256: String {
        if #available(iOS 13.0, *) {
            return hexString(SHA256.hash(data: self).makeIterator())
        } else {
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            self.withUnsafeBytes { bytes in
                _ = CC_SHA256(bytes.baseAddress, CC_LONG(self.count), &digest)
            }
            return hexString(digest.makeIterator())
        }
    }
    
    private func hexString(_ iterator: Array<UInt8>.Iterator) -> String {
        return iterator.map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    var sha256: String {
        if let data = self.data(using: .utf8) {
            return data.sha256
        }
        return ""
    }
}
#endif
