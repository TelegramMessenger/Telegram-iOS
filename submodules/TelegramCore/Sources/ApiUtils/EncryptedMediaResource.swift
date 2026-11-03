import Foundation

public protocol EncryptedMediaResource {
    func decrypt(data: Data, params: Any) -> Data?
}
