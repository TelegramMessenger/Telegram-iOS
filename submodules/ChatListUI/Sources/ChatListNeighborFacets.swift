import Foundation
import Display
import ItemListUI
import AccountContext

public extension ListViewItemHeaderFamily {
    static let chatList = ListViewItemHeaderFamily("chatList")
}

/// Facts a `ChatListItem` reads off the item below it, beyond the header run.
public protocol ChatListNeighborFacet {
    var isPinned: Bool { get }
    var hasActiveRevealControls: Bool { get }
    /// In the chat side list: what highlights the row, so the row above can hide its separator under the plate.
    var sideListHighlightKey: ChatListSideListHighlightKey? { get }
}

public enum ChatListSideListHighlightKey: Equatable {
    /// The "All Messages" row: highlighted when no thread is.
    case allThreads
    case location(ChatLocation)
}

public struct ChatListItemNeighborDescriptor: Equatable, HeaderNeighborFacet, ChatListNeighborFacet {
    public let headerId: ListViewItemNode.HeaderId?
    public let headerFamily: ListViewItemHeaderFamily?
    public let isPinned: Bool
    public let hasActiveRevealControls: Bool
    public let sideListHighlightKey: ChatListSideListHighlightKey?

    public init(headerId: ListViewItemNode.HeaderId?, isPinned: Bool, hasActiveRevealControls: Bool, sideListHighlightKey: ChatListSideListHighlightKey?) {
        self.headerId = headerId
        self.headerFamily = .chatList
        self.isPinned = isPinned
        self.hasActiveRevealControls = hasActiveRevealControls
        self.sideListHighlightKey = sideListHighlightKey
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
