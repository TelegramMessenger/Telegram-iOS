import Foundation

/// The descriptors published by the items immediately before and after some item.
///
/// `nil` on a side means *there is no neighbor on that side*. A non-nil descriptor from which a
/// consumer cannot recover its facet means *there is a neighbor, and it publishes nothing relevant*.
/// Those two cases are distinguishable on purpose — `ContactsPeerItem`, among others, depends on it.
public struct ListViewItemNeighbors: Equatable {
    public var previous: AnyEquatable?
    public var next: AnyEquatable?

    public init(previous: AnyEquatable?, next: AnyEquatable?) {
        self.previous = previous
        self.next = next
    }

    public static let none = ListViewItemNeighbors(previous: nil, next: nil)
}

/// Identifies a set of item types that participate in each other's header runs.
///
/// Before neighbor descriptors this was encoded as a concrete-type cast — `previousItem as?
/// CallListCallItem` meant "is my neighbor one of the types whose headers group with mine". Naming
/// the family directly says the same thing without coupling to a class.
///
/// A consumer that groups with *any* header-bearing neighbor (the former `as? ListViewItemWithHeader`
/// idiom) ignores this and reads `headerId` alone.
public struct ListViewItemHeaderFamily: Hashable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Facet for items that participate in header-run detection (first/last in a header group).
public protocol HeaderNeighborFacet {
    var headerId: ListViewItemNode.HeaderId? { get }
    /// `nil` for items that belong to no narrow family. Items in different families never group,
    /// even when their header ids happen to match.
    var headerFamily: ListViewItemHeaderFamily? { get }
}

/// Ready-made payload for items whose neighbors read nothing but the header facet.
public struct HeaderNeighborDescriptor: Equatable, HeaderNeighborFacet {
    public let headerId: ListViewItemNode.HeaderId?
    public let headerFamily: ListViewItemHeaderFamily?

    public init(headerId: ListViewItemNode.HeaderId?, headerFamily: ListViewItemHeaderFamily?) {
        self.headerId = headerId
        self.headerFamily = headerFamily
    }
}
