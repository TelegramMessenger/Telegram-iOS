import Foundation

final class PeerChatTopTaggedMessageIdsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private var cachedTopIds: [PeerId: [MessageId.Namespace: MessageId?]] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    private let sharedKey = ValueBoxKey(length: 8 + 4 + 4)
    
    override func beforeCommit() {
        for peerId in self.updatedPeerIds {
            
        }
        self.updatedPeerIds.removeAll()
    }
}
