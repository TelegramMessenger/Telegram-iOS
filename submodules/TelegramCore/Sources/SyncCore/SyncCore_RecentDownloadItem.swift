import Foundation
import Postbox
import SwiftSignalKit

public final class RecentDownloadItem: Codable, Equatable {
    struct Id {
        var rawValue: MemoryBuffer
        
        init(id: MessageId, resourceId: String) {
            let buffer = WriteBuffer()
            
            var idId: Int32 = id.id
            buffer.write(&idId, length: 4)
            
            var idNamespace: Int32 = id.namespace
            buffer.write(&idNamespace, length: 4)
            
            var peerId: Int64 = id.peerId.toInt64()
            buffer.write(&peerId, length: 8)
            
            let resourceIdData = resourceId.data(using: .utf8)!
            var resourceIdLength = Int32(resourceIdData.count)
            buffer.write(&resourceIdLength, length: 4)
            buffer.write(resourceIdData)
            
            self.rawValue = buffer.makeReadBufferAndReset()
        }
    }
    
    public let messageId: MessageId
    public let resourceId: String
    public let timestamp: Int32
    public let isSeen: Bool
    
    public init(messageId: MessageId, resourceId: String, timestamp: Int32, isSeen: Bool) {
        self.messageId = messageId
        self.resourceId = resourceId
        self.timestamp = timestamp
        self.isSeen = isSeen
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.messageId = try container.decode(MessageId.self, forKey: "messageId")
        self.resourceId = try container.decode(String.self, forKey: "resourceId")
        self.timestamp = try container.decode(Int32.self, forKey: "timestamp")
        self.isSeen = try container.decodeIfPresent(Bool.self, forKey: "isSeen") ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.messageId, forKey: "messageId")
        try container.encode(self.resourceId, forKey: "resourceId")
        try container.encode(self.timestamp, forKey: "timestamp")
        try container.encode(self.isSeen, forKey: "isSeen")
    }
    
    public static func ==(lhs: RecentDownloadItem, rhs: RecentDownloadItem) -> Bool {
        if lhs.messageId != rhs.messageId {
            return false
        }
        if lhs.resourceId != rhs.resourceId {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.isSeen != rhs.isSeen {
            return false
        }
        return true
    }
    
    func withSeen() -> RecentDownloadItem {
        return RecentDownloadItem(messageId: self.messageId, resourceId: self.resourceId, timestamp: self.timestamp, isSeen: true)
    }
}

public final class RenderedRecentDownloadItem: Equatable {
    public let message: Message
    public let timestamp: Int32
    public let isSeen: Bool
    public let resourceId: String
    public let size: Int
    
    public init(message: Message, timestamp: Int32, isSeen: Bool, resourceId: String, size: Int) {
        self.message = message
        self.timestamp = timestamp
        self.isSeen = isSeen
        self.resourceId = resourceId
        self.size = size
    }
    
    public static func ==(lhs: RenderedRecentDownloadItem, rhs: RenderedRecentDownloadItem) -> Bool {
        if lhs.message.id != rhs.message.id {
            return false
        }
        if lhs.message.stableVersion != rhs.message.stableVersion {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.isSeen != rhs.isSeen {
            return false
        }
        if lhs.resourceId != rhs.resourceId {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }
}

public func recentDownloadItems(postbox: Postbox) -> Signal<[RenderedRecentDownloadItem], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.RecentDownloads)
    return postbox.combinedView(keys: [viewKey])
    |> mapToSignal { views -> Signal<[RenderedRecentDownloadItem], NoError> in
        guard let view = views.views[viewKey] as? OrderedItemListView else {
            return .single([])
        }
        
        return combineLatest(postbox.transaction { transaction -> [RenderedRecentDownloadItem] in
            var result: [RenderedRecentDownloadItem] = []
            
            for item in view.items {
                guard let item = item.contents.get(RecentDownloadItem.self) else {
                    continue
                }
                guard let message = transaction.getMessage(item.messageId) else {
                    continue
                }
                
                var size: Int?
                for media in message.media {
                    if let result = findMediaResourceById(media: media, resourceId: MediaResourceId(item.resourceId)) {
                        size = result.size
                        break
                    }
                }
                
                if let size = size {
                    result.append(RenderedRecentDownloadItem(message: message, timestamp: item.timestamp, isSeen: item.isSeen, resourceId: item.resourceId, size: size))
                }
            }
            
            return result
        }, postbox.mediaBox.didRemoveResources)
        |> mapToSignal { items, _ -> Signal<[RenderedRecentDownloadItem], NoError> in
            var statusSignals: [Signal<Bool, NoError>] = []
            
            for item in items {
                statusSignals.append(postbox.mediaBox.resourceStatus(MediaResourceId(item.resourceId), resourceSize: item.size)
                |> map { status -> Bool in
                    switch status {
                    case .Local:
                        return true
                    default:
                        return false
                    }
                }
                |> distinctUntilChanged)
            }
            
            return combineLatest(queue: .mainQueue(), statusSignals)
            |> map { statuses -> [RenderedRecentDownloadItem] in
                var result: [RenderedRecentDownloadItem] = []
                for i in 0 ..< items.count {
                    if statuses[i] {
                        result.append(items[i])
                    }
                }
                return result
            }
        }
    }
}

public func addRecentDownloadItem(postbox: Postbox, item: RecentDownloadItem) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        guard let entry = CodableEntry(item) else {
            return
        }
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentDownloads, item: OrderedItemListEntry(id: RecentDownloadItem.Id(id: item.messageId, resourceId: item.resourceId).rawValue, contents: entry), removeTailIfCountExceeds: 200)
    }
    |> ignoreValues
}

public func clearRecentDownloadList(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.RecentDownloads, items: [])
    }
    |> ignoreValues
}

public func markRecentDownloadItemsAsSeen(postbox: Postbox, items: [(messageId: MessageId, resourceId: String)]) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        var unseenIds: [(messageId: MessageId, resourceId: String)] = []
        for item in items {
            guard let listItem = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentDownloads, itemId: RecentDownloadItem.Id(id: item.messageId, resourceId: item.resourceId).rawValue) else {
                continue
            }
            guard let listItemValue = listItem.contents.get(RecentDownloadItem.self), !listItemValue.isSeen else {
                continue
            }
            unseenIds.append(item)
        }
        
        if unseenIds.isEmpty {
            return
        }
        
        let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.RecentDownloads)
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.RecentDownloads, items: items.compactMap { entry -> OrderedItemListEntry? in
            guard let item = entry.contents.get(RecentDownloadItem.self) else {
                return nil
            }
            if unseenIds.contains(where: { $0.messageId == item.messageId && $0.resourceId == item.resourceId }) {
                guard let entry = CodableEntry(item.withSeen()) else {
                    return nil
                }
                return OrderedItemListEntry(id: RecentDownloadItem.Id(id: item.messageId, resourceId: item.resourceId).rawValue, contents: entry)
            } else {
                return entry
            }
        })
    }
    |> ignoreValues
}

public func markAllRecentDownloadItemsAsSeen(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.RecentDownloads)
        var hasUnseen = false
        for item in items {
            if let item = item.contents.get(RecentDownloadItem.self), !item.isSeen {
                hasUnseen = true
                break
            }
        }
        if !hasUnseen {
            return
        }
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.RecentDownloads, items: items.compactMap { item -> OrderedItemListEntry? in
            guard let item = item.contents.get(RecentDownloadItem.self) else {
                return nil
            }
            guard let entry = CodableEntry(item.withSeen()) else {
                return nil
            }
            return OrderedItemListEntry(id: RecentDownloadItem.Id(id: item.messageId, resourceId: item.resourceId).rawValue, contents: entry)
        })
    }
    |> ignoreValues
}
