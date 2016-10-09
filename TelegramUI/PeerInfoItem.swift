
typealias PeerInfoItemSectionId = UInt32

protocol PeerInfoItem {
    var sectionId: PeerInfoItemSectionId { get }
}

enum PeerInfoItemNeighbor {
    case none
    case otherSection
    case sameSection
}

struct PeerInfoItemNeighbors {
    let top: PeerInfoItemNeighbor
    let bottom: PeerInfoItemNeighbor
}

func peerInfoItemNeighbors(item: PeerInfoItem, topItem: PeerInfoItem?, bottomItem: PeerInfoItem?) -> PeerInfoItemNeighbors {
    let topNeighbor: PeerInfoItemNeighbor
    if let topItem = topItem {
        if topItem.sectionId != item.sectionId {
            topNeighbor = .otherSection
        } else {
            topNeighbor = .sameSection
        }
    } else {
        topNeighbor = .none
    }
    
    let bottomNeighbor: PeerInfoItemNeighbor
    if let bottomItem = bottomItem {
        if bottomItem.sectionId != item.sectionId {
            bottomNeighbor = .otherSection
        } else {
            bottomNeighbor = .sameSection
        }
    } else {
        bottomNeighbor = .none
    }

    return PeerInfoItemNeighbors(top: topNeighbor, bottom: bottomNeighbor)
}

enum PeerInfoListStyle {
    case plain
    case blocks
}

func peerInfoItemNeighborsPlainInsets(_ neighbors: PeerInfoItemNeighbors) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    switch neighbors.top {
        case .otherSection:
            insets.top += 22.0
        case .none, .sameSection:
            break
    }
    switch neighbors.bottom {
        case .none:
            insets.bottom += 22.0
        case .otherSection, .sameSection:
            break
    }
    return insets
}
