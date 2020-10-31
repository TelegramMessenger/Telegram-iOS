import Foundation
import Postbox
import CryptoUtils

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public extension MemoryBuffer {
    func md5Digest() -> Data {
        return CryptoMD5(self.memory, Int32(self.length))
    }
}
