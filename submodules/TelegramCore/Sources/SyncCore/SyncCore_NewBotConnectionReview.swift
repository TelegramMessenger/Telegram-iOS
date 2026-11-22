import Foundation
import Postbox
import SwiftSignalKit

public final class NewBotConnectionReview: Codable, Equatable {
    struct Id {
        var rawValue: MemoryBuffer
        
        init(botId: PeerId) {
            let buffer = WriteBuffer()
            
            var rawBotId = botId.toInt64()
            buffer.write(&rawBotId, length: 8)
            
            self.rawValue = buffer.makeReadBufferAndReset()
        }
    }
    
    public let botId: PeerId
    public let device: String?
    public let location: String?
    public let timestamp: Int32?
    
    public init(botId: PeerId, device: String?, location: String?, timestamp: Int32?) {
        self.botId = botId
        self.device = device
        self.location = location
        self.timestamp = timestamp
    }
    
    public static func ==(lhs: NewBotConnectionReview, rhs: NewBotConnectionReview) -> Bool {
        if lhs.botId != rhs.botId {
            return false
        }
        if lhs.device != rhs.device {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        return true
    }
}

public func newBotConnectionReviews(postbox: Postbox) -> Signal<[NewBotConnectionReview], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.NewBotConnectionReviews)
    return postbox.combinedView(keys: [viewKey])
    |> mapToSignal { views -> Signal<[NewBotConnectionReview], NoError> in
        guard let view = views.views[viewKey] as? OrderedItemListView else {
            return .single([])
        }
        
        var result: [NewBotConnectionReview] = []
        for item in view.items {
            guard let item = item.contents.get(NewBotConnectionReview.self) else {
                continue
            }
            result.append(item)
        }
        
        return .single(result)
    }
}

public func addNewBotConnectionReview(postbox: Postbox, item: NewBotConnectionReview) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        guard let entry = CodableEntry(item) else {
            return
        }
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewBotConnectionReviews, item: OrderedItemListEntry(id: NewBotConnectionReview.Id(botId: item.botId).rawValue, contents: entry), removeTailIfCountExceeds: 200)
    }
    |> ignoreValues
}

public func removeNewBotConnectionReviews(postbox: Postbox, botIds: [PeerId]) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        for botId in botIds {
            transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.NewBotConnectionReviews, itemId: NewBotConnectionReview.Id(botId: botId).rawValue)
        }
    }
    |> ignoreValues
}
