import Foundation

private func readPeerIds(_ buffer: ReadBuffer) -> Set<PeerId> {
    assert(buffer.length % 8 == 0)
    let count = buffer.length / 8
    var result = Set<PeerId>()
    for _ in 0 ..< count {
        var value: Int64 = 0
        buffer.read(&value, offset: 0, length: 8)
        result.insert(PeerId(value))
    }
    return result
}

private func writePeerIds(_ buffer: WriteBuffer, _ peerIds: Set<PeerId>) {
    for id in peerIds {
        var value: Int64 = id.toInt64()
        buffer.write(&value, offset: 0, length: 8)
    }
}

final class ReverseAssociatedPeerTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedAssociations: [PeerId: Set<PeerId>] = [:]
    private var updatedAssociations = Set<PeerId>()
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    func get(peerId: PeerId) -> Set<PeerId> {
        if let cached = self.cachedAssociations[peerId] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(peerId)) {
                let peerIds = readPeerIds(value)
                self.cachedAssociations[peerId] = peerIds
                return peerIds
            } else {
                self.cachedAssociations[peerId] = Set()
                return Set()
            }
        }
    }
    
    func addReverseAssociation(target targetPeerId: PeerId, from sourcePeerId: PeerId) {
        var value = self.get(peerId: targetPeerId)
        if value.contains(sourcePeerId) {
            assertionFailure()
        } else {
            value.insert(sourcePeerId)
            self.cachedAssociations[targetPeerId] = value
            self.updatedAssociations.insert(targetPeerId)
        }
    }
    
    func removeReverseAssociation(target targetPeerId: PeerId, from sourcePeerId: PeerId) {
        var value = self.get(peerId: targetPeerId)
        if !value.contains(sourcePeerId) {
            assertionFailure()
        } else {
            value.remove(sourcePeerId)
            self.cachedAssociations[targetPeerId] = value
            self.updatedAssociations.insert(targetPeerId)
        }
    }
    
    override func clearMemoryCache() {
        self.cachedAssociations.removeAll()
        assert(self.updatedAssociations.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedAssociations.isEmpty {
            let buffer = WriteBuffer()
            for peerId in self.updatedAssociations {
                if let peerIds = self.cachedAssociations[peerId] {
                    if peerIds.isEmpty {
                        self.valueBox.remove(self.table, key: self.key(peerId), secure: false)
                    } else {
                        buffer.reset()
                        writePeerIds(buffer, peerIds)
                        self.valueBox.set(self.table, key: self.key(peerId), value: buffer)
                    }
                } else {
                    assertionFailure()
                }
            }
            
            self.updatedAssociations.removeAll()
        }
    }
}
