import Foundation
import TelegramCorePrivateModule
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

#if swift(>=4.0)
import CommonCrypto
#endif

public extension MemoryBuffer {
    public func md5Digest() -> Data {
        var res = Data()
        res.count = Int(CC_MD5_DIGEST_LENGTH)
        res.withUnsafeMutableBytes { mutableBytes -> Void in
            CC_MD5(self.memory, CC_LONG(self.length), mutableBytes)
        }
        return res
    }
}
