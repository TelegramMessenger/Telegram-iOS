import Foundation
import Postbox

public func decryptedResourceData(data: MediaResourceData, resource: MediaResource, params: Any) -> Data? {
    guard data.complete else {
        return nil
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [.mappedRead]) else {
        return nil
    }
    if let resource = resource as? EncryptedMediaResource {
        return resource.decrypt(data: data, params: params)
    } else {
        return data
    }
}
