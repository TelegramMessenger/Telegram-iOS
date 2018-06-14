import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public enum TelegramWallpaper: OrderedItemListEntryContents, Equatable {
    case none
    case builtin
    case color(Int32)
    case image([TelegramMediaImageRepresentation])
    case custom(String)
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
        case 0:
            self = .builtin
        case 1:
            self = .color(decoder.decodeInt32ForKey("c", orElse: 0))
        case 2:
            self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"))
        case 3:
            self = .none
        case 4:
            self = .custom(decoder.decodeStringForKey("p", orElse: ""))
        default:
            assertionFailure()
            self = .none
        }
    }
    
    public var hasWallpaper: Bool {
        switch self {
        case .none:
            return false
        case .color:
            return false
        default:
            return true
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .builtin:
            encoder.encodeInt32(0, forKey: "v")
        case let .color(color):
            encoder.encodeInt32(1, forKey: "v")
            encoder.encodeInt32(color, forKey: "c")
        case let .image(representations):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeObjectArray(representations, forKey: "i")
        case .none:
            encoder.encodeInt32(3, forKey: "v")
        case let .custom(path):
            encoder.encodeInt32(4, forKey: "v")
            encoder.encodeString(path, forKey: "p")
        }
    }
}

public func telegramWallpapers(account: Account) -> Signal<[TelegramWallpaper], NoError> {
    return account.postbox.transaction { transaction -> [TelegramWallpaper] in
        let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers)
        if items.count == 0 {
            return [.color(0x000000), .builtin]
        } else {
            return items.map { $0.contents as! TelegramWallpaper }
        }
    } |> mapToSignal { list -> Signal<[TelegramWallpaper], NoError> in
        let remote = account.network.request(Api.functions.account.getWallPapers())
            |> retryRequest
            |> mapToSignal { result -> Signal<[TelegramWallpaper], NoError> in
                var items: [TelegramWallpaper] = []
                for item in result {
                    switch item {
                        case let .wallPaper(_, _, sizes, color):
                            items.append(.image(telegramMediaImageRepresentationsFromApiSizes(sizes)))
                        case let .wallPaperSolid(_, _, bgColor, color):
                            items.append(.color(bgColor))
                    }
                }
                items.removeFirst()
                items.insert(.color(0x000000), at: 0)
                items.insert(.builtin, at: 1)
                
                if items == list {
                    return .complete()
                } else {
                    return account.postbox.transaction { transaction -> [TelegramWallpaper] in
                        var entries: [OrderedItemListEntry] = []
                        for item in items {
                            var intValue = Int32(entries.count)
                            let id = MemoryBuffer(data: Data(bytes: &intValue, count: 4))
                            entries.append(OrderedItemListEntry(id: id, contents: item))
                        }
                        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers, items: entries)
                        
                        return items
                    }
                }
            }
        return .single(list) |> then(remote)
    }
}
