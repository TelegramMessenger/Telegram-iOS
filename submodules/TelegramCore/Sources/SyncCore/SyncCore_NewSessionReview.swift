import Foundation
import Postbox
import SwiftSignalKit

public final class NewSessionReview: Codable, Equatable {
    struct Id {
        var rawValue: MemoryBuffer
        
        init(id: Int64) {
            let buffer = WriteBuffer()
            
            var id = id
            buffer.write(&id, length: 8)
            
            self.rawValue = buffer.makeReadBufferAndReset()
        }
    }
    
    public let id: Int64
    public let device: String
    public let location: String
    
    public init(id: Int64, device: String, location: String) {
        self.id = id
        self.device = device
        self.location = location
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.id = try container.decode(Int64.self, forKey: "id")
        self.device = try container.decode(String.self, forKey: "device")
        self.location = try container.decode(String.self, forKey: "location")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.id, forKey: "id")
        try container.encode(self.device, forKey: "device")
        try container.encode(self.location, forKey: "location")
    }
    
    public static func ==(lhs: NewSessionReview, rhs: NewSessionReview) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.device != rhs.device {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        return true
    }
}

public func newSessionReviews(postbox: Postbox) -> Signal<[NewSessionReview], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.NewSessionReviews)
    return postbox.combinedView(keys: [viewKey])
    |> mapToSignal { views -> Signal<[NewSessionReview], NoError> in
        guard let view = views.views[viewKey] as? OrderedItemListView else {
            return .single([])
        }
        
        var result: [NewSessionReview] = []
        
        for item in view.items {
            guard let item = item.contents.get(NewSessionReview.self) else {
                continue
            }
            result.append(item)
        }
        
        return .single(result)
    }
}

public func addNewSessionReview(postbox: Postbox, item: NewSessionReview) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        guard let entry = CodableEntry(item) else {
            return
        }
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewSessionReviews, item: OrderedItemListEntry(id: NewSessionReview.Id(id: item.id).rawValue, contents: entry), removeTailIfCountExceeds: 200)
    }
    |> ignoreValues
}

public func clearNewSessionReviews(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.NewSessionReviews, items: [])
    }
    |> ignoreValues
}

public func removeNewSessionReviews(postbox: Postbox, ids: [Int64]) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        for id in ids {
            transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewSessionReviews, itemId: NewSessionReview.Id(id: id).rawValue)
        }
    }
    |> ignoreValues
}
