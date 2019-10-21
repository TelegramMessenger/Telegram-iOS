import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

import SyncCore

extension SecureFileMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource, EncryptedMediaResource {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        return Api.InputFileLocation.inputSecureFileLocation(id: self.file.id, accessHash: self.file.accessHash)
    }
    
    public func decrypt(data: Data, params: Any) -> Data? {
        guard let context = params as? SecureIdAccessContext else {
            return nil
        }
        return decryptedSecureIdFile(context: context, encryptedData: data, fileHash: self.file.fileHash, encryptedSecret: self.file.encryptedSecret)
    }
}
