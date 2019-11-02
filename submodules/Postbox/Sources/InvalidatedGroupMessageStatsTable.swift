import Foundation

public struct PeerGroupAndNamespace: Hashable {
    public let groupId: PeerGroupId
    public let namespace: MessageId.Namespace
    
    public init(groupId: PeerGroupId, namespace: MessageId.Namespace) {
        self.groupId = groupId
        self.namespace = namespace
    }
}

final class InvalidatedGroupMessageStatsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(groupId: PeerGroupId, namespace: MessageId.Namespace) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: groupId.rawValue)
        self.sharedKey.setInt32(4, value: namespace)
        return self.sharedKey
    }
    
    private var updatedGroupIds: [PeerGroupAndNamespace: Bool] = [:]
    
    func set(groupId: PeerGroupId, namespace: MessageId.Namespace, needsValidation: Bool, operations: inout [PeerGroupAndNamespace: Bool]) {
        let key = PeerGroupAndNamespace(groupId: groupId, namespace: namespace)
        self.updatedGroupIds[key] = needsValidation
        operations[key] = needsValidation
    }
    
    func get() -> Set<PeerGroupAndNamespace> {
        self.beforeCommit()
        
        var result = Set<PeerGroupAndNamespace>()
        self.valueBox.scan(self.table, keys: { key in
            result.insert(PeerGroupAndNamespace(groupId: PeerGroupId(rawValue: key.getInt32(0)), namespace: key.getInt32(4)))
            return true
        })
        return result
    }
    
    override func beforeCommit() {
        if !self.updatedGroupIds.isEmpty {
            for (groupIdAndNamespace, needsValidation) in self.updatedGroupIds {
                if needsValidation {
                    self.valueBox.set(self.table, key: self.key(groupId: groupIdAndNamespace.groupId, namespace: groupIdAndNamespace.namespace), value: MemoryBuffer(data: Data()))
                } else {
                    self.valueBox.remove(self.table, key: self.key(groupId: groupIdAndNamespace.groupId, namespace: groupIdAndNamespace.namespace), secure: false)
                }
            }
            self.updatedGroupIds.removeAll()
        }
    }
}
