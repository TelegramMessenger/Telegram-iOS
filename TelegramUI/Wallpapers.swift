import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum TelegramWallpaper: OrderedItemListEntryContents, Equatable {
    case builtin
    case color(Int32)
    case image([TelegramMediaImageRepresentation])
    
    public init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .builtin
            case 1:
                self = .color(decoder.decodeInt32ForKey("c", orElse: 0))
            case 2:
                self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"))
            default:
                assertionFailure()
                self = .builtin
        }
    }
    
    public func encode(_ encoder: Encoder) {
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
    
    public static func ==(lhs: TelegramWallpaper, rhs: TelegramWallpaper) -> Bool {
        switch lhs {
            case .builtin:
                if case .builtin = rhs {
                    return true
                } else {
                    return false
                }
            case let .color(color):
                if case .color(color) = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(lhsRepresentations):
                if case let .image(rhsRepresentations) = rhs, lhsRepresentations == rhsRepresentations {
                    return true
                } else {
                    return false
                }
        }
    }
}

func telegramWallpapers(account: Account) -> Signal<[TelegramWallpaper], NoError> {
    return account.postbox.modify { modifier -> [TelegramWallpaper] in
        let items = modifier.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers)
        if items.count == 0 {
            return [.builtin, .color(0x121212)]
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
                items.insert(.builtin, at: 0)
                items.insert(.color(0x121212), at: 1)
                
                if items == list {
                    return .complete()
                } else {
                    return account.postbox.modify { modifier -> [TelegramWallpaper] in
                        var entries: [OrderedItemListEntry] = []
                        for item in items {
                            var intValue = Int32(entries.count)
                            let id = MemoryBuffer(data: Data(bytes: &intValue, count: 4))
                            entries.append(OrderedItemListEntry(id: id, contents: item))
                        }
                        modifier.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers, items: entries)
                        
                        return items
                    }
                }
            }
        return .single(list) |> then(remote)
    }
}
