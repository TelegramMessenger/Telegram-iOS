import Foundation
import TelegramCorePrivateModule
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public extension MemoryBuffer {
    public func md5Digest() -> Data {
        return CryptoMD5(self.memory, Int32(self.length))
    }
}
