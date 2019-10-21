import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

import SyncCore

extension SecretChatFileReference {
    convenience init?(_ file: Api.EncryptedFile) {
        switch file {
            case let .encryptedFile(id, accessHash, size, dcId, keyFingerprint):
                self.init(id: id, accessHash: accessHash, size: size, datacenterId: dcId, keyFingerprint: keyFingerprint)
            case .encryptedFileEmpty:
                return nil
        }
    }
}
