import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public enum TelegramWallpaper: OrderedItemListEntryContents, Equatable {
    case builtin
    case color(Int32)
    case image([TelegramMediaImageRepresentation])
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .builtin
            case 1:
                self = .color(decoder.decodeInt32ForKey("c", orElse: 0))
            case 2:
                self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"))
            default:
                assertionFailure()
                self = .color(0xffffff)
        }
    }
    
    public var hasWallpaper: Bool {
        switch self {
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
        }
    }
}

public func telegramWallpapers(postbox: Postbox, network: Network) -> Signal<[TelegramWallpaper], NoError> {
    return postbox.transaction { transaction -> [TelegramWallpaper] in
        let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers)
        if items.count == 0 {
            return [.builtin]
        } else {
            return items.map { $0.contents as! TelegramWallpaper }
        }
    } |> mapToSignal { list -> Signal<[TelegramWallpaper], NoError> in
        let remote = network.request(Api.functions.account.getWallPapers())
        |> retryRequest
        |> mapToSignal { result -> Signal<[TelegramWallpaper], NoError> in
            var items: [TelegramWallpaper] = []
            for item in result {
                switch item {
                    case let .wallPaper(_, _, sizes, _):
                        items.append(.image(telegramMediaImageRepresentationsFromApiSizes(sizes).1))
                    case let .wallPaperSolid(_, _, bgColor, _):
                        items.append(.color(bgColor))
                }
            }
            items.removeFirst()
            items.insert(.builtin, at: 0)
            
            if items == list {
                return .complete()
            } else {
                return postbox.transaction { transaction -> [TelegramWallpaper] in
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
        return .single(list)
        |> then(remote)
    }
}
