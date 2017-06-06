import Foundation

private func writePeerIds(_ buffer: WriteBuffer, _ peerIds: Set<PeerId>) {
    for id in peerIds {
        var value: Int64 = id.toInt64()
        buffer.write(&value, offset: 0, length: 8)
    }
}

func postboxUpgrade_13to14(metadataTable: MetadataTable, valueBox: ValueBox) {
    var reverseAssociations: [PeerId: Set<PeerId>] = [:]
    
    let peerTable = ValueBoxTable(id: 2, keyType: .int64)
    valueBox.scan(peerTable, values: { _, value in
        if let peer = Decoder(buffer: value).decodeRootObject() as? Peer {
            if let association = peer.associatedPeerId {
                if reverseAssociations[association] == nil {
                    reverseAssociations[association] = Set()
                }
                reverseAssociations[association]!.insert(peer.id)
            }
        } else {
            assertionFailure()
        }
        return true
    })
    
    let reverseAssociatedPeerTable = ValueBoxTable(id: 40, keyType: .int64)

    let sharedKey = ValueBoxKey(length: 8)
    let sharedBuffer = WriteBuffer()
    for (peerId, associations) in reverseAssociations {
        sharedBuffer.reset()
        writePeerIds(sharedBuffer, associations)
        
        sharedKey.setInt64(0, value: peerId.toInt64())
        valueBox.set(reverseAssociatedPeerTable, key: sharedKey, value: sharedBuffer)
    }
    
    metadataTable.setUserVersion(14)
}
