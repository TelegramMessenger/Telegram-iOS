import Foundation
import Display
import ItemListUI

/// `BotCheckoutPriceItem` asks two things about its neighbors that have nothing to do with headers:
/// whether the item above is the checkout header (extra top offset), and whether the item below is
/// the final price row (extra bottom padding).
protocol BotCheckoutNeighborFacet {
    var isCheckoutHeaderItem: Bool { get }
    /// `nil` when the neighbor is not a price item at all.
    var priceItemIsFinal: Bool? { get }
}

struct BotCheckoutNeighborDescriptor: Equatable, ItemListNeighborFacet, BotCheckoutNeighborFacet {
    let sectionId: ItemListSectionId
    let isAlwaysPlain: Bool
    let requestsNoInset: Bool
    let isTextItem: Bool
    let hasActiveRevealOptions: Bool
    let isCheckoutHeaderItem: Bool
    let priceItemIsFinal: Bool?

    init(sectionId: ItemListSectionId, isAlwaysPlain: Bool, requestsNoInset: Bool, isCheckoutHeaderItem: Bool, priceItemIsFinal: Bool?) {
        self.sectionId = sectionId
        self.isAlwaysPlain = isAlwaysPlain
        self.requestsNoInset = requestsNoInset
        self.isTextItem = false
        self.hasActiveRevealOptions = false
        self.isCheckoutHeaderItem = isCheckoutHeaderItem
        self.priceItemIsFinal = priceItemIsFinal
    }
}
