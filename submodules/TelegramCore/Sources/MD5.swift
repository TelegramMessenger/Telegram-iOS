import Foundation
import Postbox

public extension MemoryBuffer {
    func md5Digest() -> Data {
        return CryptoMD5(self.memory, Int32(self.length))
    }
}
