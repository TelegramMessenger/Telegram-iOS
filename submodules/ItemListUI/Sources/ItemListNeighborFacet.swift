import Foundation
import Display

/// What `itemListNeighbors` needs to know about a neighboring item.
///
/// Replaces the `previousItem as? ItemListItem` idiom. Recovered from a neighbor descriptor with
/// `neighbors.previous?.base(ItemListNeighborFacet.self)`.
public protocol ItemListNeighborFacet {
    var sectionId: ItemListSectionId { get }
    var isAlwaysPlain: Bool { get }
    var requestsNoInset: Bool { get }
    /// Drives the `.reduced` top inset. Was `topItem is ItemListTextItem`.
    var isTextItem: Bool { get }
    /// Was `(topItem as? ItemListRevealOptionsStatefulItem)?.hasActiveRevealOptions ?? false`.
    var hasActiveRevealOptions: Bool { get }
}

public struct ItemListItemNeighborDescriptor: Equatable, ItemListNeighborFacet {
    public let sectionId: ItemListSectionId
    public let isAlwaysPlain: Bool
    public let requestsNoInset: Bool
    public let isTextItem: Bool
    public let hasActiveRevealOptions: Bool

    public init(sectionId: ItemListSectionId, isAlwaysPlain: Bool, requestsNoInset: Bool, isTextItem: Bool, hasActiveRevealOptions: Bool) {
        self.sectionId = sectionId
        self.isAlwaysPlain = isAlwaysPlain
        self.requestsNoInset = requestsNoInset
        self.isTextItem = isTextItem
        self.hasActiveRevealOptions = hasActiveRevealOptions
    }
}

/// Payload for an `ItemListItem` that also participates in header runs. Concrete types declare
/// `neighborDescriptor` returning one of these, which shadows the shared extension below.
public struct ItemListHeaderNeighborDescriptor: Equatable, ItemListNeighborFacet, HeaderNeighborFacet {
    public let sectionId: ItemListSectionId
    public let isAlwaysPlain: Bool
    public let requestsNoInset: Bool
    public let isTextItem: Bool
    public let hasActiveRevealOptions: Bool
    public let headerId: ListViewItemNode.HeaderId?
    public let headerFamily: ListViewItemHeaderFamily?

    public init(sectionId: ItemListSectionId, isAlwaysPlain: Bool, requestsNoInset: Bool, isTextItem: Bool, hasActiveRevealOptions: Bool, headerId: ListViewItemNode.HeaderId?, headerFamily: ListViewItemHeaderFamily?) {
        self.sectionId = sectionId
        self.isAlwaysPlain = isAlwaysPlain
        self.requestsNoInset = requestsNoInset
        self.isTextItem = isTextItem
        self.hasActiveRevealOptions = hasActiveRevealOptions
        self.headerId = headerId
        self.headerFamily = headerFamily
    }
}

public extension ItemListItem where Self: ListViewItem {
    /// Supplies `ListViewItem.neighborDescriptor` for every `ItemListItem` at once. Concrete types
    /// needing more (a header facet, a narrow family) declare the property themselves, which
    /// shadows this.
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ItemListItemNeighborDescriptor(
            sectionId: self.sectionId,
            isAlwaysPlain: self.isAlwaysPlain,
            requestsNoInset: self.requestsNoInset,
            isTextItem: self is ItemListTextItem,
            hasActiveRevealOptions: (self as? ItemListRevealOptionsStatefulItem)?.hasActiveRevealOptions ?? false
        ))
    }
}

/// Facet-based replacement for `itemListNeighbors(item:topItem:bottomItem:)`.
///
/// Note the asymmetry carried over from the original: the `.reduced` inset is computed for the top
/// neighbor only — the bottom branch has no `isTextItem` check.
public func itemListNeighbors(item: ItemListItem,
                              topFacet: ItemListNeighborFacet?,
                              bottomFacet: ItemListNeighborFacet?) -> ItemListNeighbors {
    let topNeighbor: ItemListNeighbor
    if let topFacet = topFacet {
        if topFacet.sectionId != item.sectionId {
            let topInset: ItemListInsetWithOtherSection
            if topFacet.requestsNoInset {
                topInset = .none
            } else {
                if topFacet.isTextItem {
                    topInset = .reduced
                } else {
                    topInset = .full
                }
            }
            topNeighbor = .otherSection(topInset)
        } else {
            topNeighbor = .sameSection(alwaysPlain: topFacet.isAlwaysPlain)
        }
    } else {
        topNeighbor = .none
    }

    let bottomNeighbor: ItemListNeighbor
    if let bottomFacet = bottomFacet {
        if bottomFacet.sectionId != item.sectionId {
            let bottomInset: ItemListInsetWithOtherSection
            if bottomFacet.requestsNoInset {
                bottomInset = .none
            } else {
                bottomInset = .full
            }
            bottomNeighbor = .otherSection(bottomInset)
        } else {
            bottomNeighbor = .sameSection(alwaysPlain: bottomFacet.isAlwaysPlain)
        }
    } else {
        bottomNeighbor = .none
    }

    return ItemListNeighbors(
        top: topNeighbor,
        bottom: bottomNeighbor,
        topHasActiveRevealOptions: topFacet?.hasActiveRevealOptions ?? false,
        bottomHasActiveRevealOptions: bottomFacet?.hasActiveRevealOptions ?? false
    )
}
