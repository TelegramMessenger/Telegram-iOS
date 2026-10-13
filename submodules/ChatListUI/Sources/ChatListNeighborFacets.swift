import Foundation
import Display
import ItemListUI

public extension ListViewItemHeaderFamily {
    static let chatList = ListViewItemHeaderFamily("chatList")
}

/// Facts a `ChatListItem` reads off the item below it, beyond the header run.
public protocol ChatListNeighborFacet {
    var isPinned: Bool { get }
    var hasActiveRevealControls: Bool { get }
}

public struct ChatListItemNeighborDescriptor: Equatable, HeaderNeighborFacet, ChatListNeighborFacet {
    public let headerId: ListViewItemNode.HeaderId?
    public let headerFamily: ListViewItemHeaderFamily?
    public let isPinned: Bool
    public let hasActiveRevealControls: Bool

    public init(headerId: ListViewItemNode.HeaderId?, isPinned: Bool, hasActiveRevealControls: Bool) {
        self.headerId = headerId
        self.headerFamily = .chatList
        self.isPinned = isPinned
        self.hasActiveRevealControls = hasActiveRevealControls
    }
}

/// Presence marker: `ChatListAdditionalCategoryItem` asks only whether its neighbor is another one.
public protocol ChatListAdditionalCategoryNeighborFacet {
}

public struct ChatListAdditionalCategoryNeighborDescriptor: Equatable, ItemListNeighborFacet, HeaderNeighborFacet, ChatListAdditionalCategoryNeighborFacet {
    public let sectionId: ItemListSectionId
    public let isAlwaysPlain: Bool
    public let requestsNoInset: Bool
    public let isTextItem: Bool
    public let hasActiveRevealOptions: Bool
    public let headerId: ListViewItemNode.HeaderId?
    public let headerFamily: ListViewItemHeaderFamily?

    public init(sectionId: ItemListSectionId, isAlwaysPlain: Bool, requestsNoInset: Bool, headerId: ListViewItemNode.HeaderId?) {
        self.sectionId = sectionId
        self.isAlwaysPlain = isAlwaysPlain
        self.requestsNoInset = requestsNoInset
        self.isTextItem = false
        self.hasActiveRevealOptions = false
        self.headerId = headerId
        self.headerFamily = nil
    }
}
