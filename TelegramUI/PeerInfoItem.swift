
typealias PeerInfoItemSectionId = UInt32

protocol PeerInfoItem {
    var sectionId: PeerInfoItemSectionId { get }
}

func peerInfoItemInsets(item: PeerInfoItem, topItem: PeerInfoItem?, bottomItem: PeerInfoItem?) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    if let topItem = topItem, topItem.sectionId != item.sectionId {
        insets.top += 22.0
    }
    if bottomItem == nil {
        insets.bottom += 22.0
    }
    
    return insets
}
