import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum SecureIdFieldType {
    case identity
    case address
    case phone
    case email
}

public enum SecureIdFileReference {
    case none
    case file(id: Int64, accessHash: Int64, size: Int32, datacenterId: Int32, fileHash: String)
}

public enum SecureIdFieldValueData {
    case none
    case data(data: Data, hash: String, secret: Data)
    case files(files: [SecureIdFileReference], hash: String, secret: Data)
    case text(text: String, hash: String)
}

public struct SecureIdFieldValue {
    public let name: String
    public let data: SecureIdFieldValueData
}

public struct SecureIdField {
    public let type: SecureIdFieldType
    public let value: SecureIdFieldValue
}

public struct SecureIdForm {
    public let peerId: PeerId
    public let fields: [SecureIdField]
}
