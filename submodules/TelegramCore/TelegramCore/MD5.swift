import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public extension MemoryBuffer {
    func md5Digest() -> Data {
        return CryptoMD5(self.memory, Int32(self.length))
    }
}
