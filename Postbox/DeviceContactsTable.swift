import Foundation

protocol DeviceContactKey: PostboxCoding {
    
}

protocol DeviceContactEntry: PostboxCoding {
    
}

final class DeviceContactsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private var cachedEntries: [DeviceContactEntry] = []
    
}
