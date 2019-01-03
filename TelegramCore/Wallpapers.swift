import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

//wallPaperDocument flags:# id:long creator:flags.0?true access_hash:long title:string slug:flags.1?string document:Document color:flags.2?int = WallPaper;

public enum TelegramWallpaper: OrderedItemListEntryContents, Equatable {
    case builtin
    case color(Int32)
    case image([TelegramMediaImageRepresentation])
    case file(id: Int64, accessHash: Int64, isCreator: Bool, title: String, slug: String?, file: TelegramMediaFile, color: Int32?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .builtin
            case 1:
                self = .color(decoder.decodeInt32ForKey("c", orElse: 0))
            case 2:
                self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"))
            case 3:
                self = .file(id: decoder.decodeInt64ForKey("id", orElse: 0), accessHash: decoder.decodeInt64ForKey("accessHash", orElse: 0), isCreator: decoder.decodeInt32ForKey("isCreator", orElse: 0) != 0, title: decoder.decodeStringForKey("title", orElse: ""), slug: decoder.decodeOptionalStringForKey("slug"), file: decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as! TelegramMediaFile, color: decoder.decodeOptionalInt32ForKey("color"))
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
            case let .file(id, accessHash, isCreator, title, slug, file, color):
                encoder.encodeInt32(3, forKey: "v")
                encoder.encodeInt64(id, forKey: "id")
                encoder.encodeInt64(accessHash, forKey: "accessHash")
                encoder.encodeInt32(isCreator ? 1 : 0, forKey: "isCreator")
                encoder.encodeString(title, forKey: "title")
                if let slug = slug {
                    encoder.encodeString(slug, forKey: "slug")
                } else {
                    encoder.encodeNil(forKey: "slug")
                }
                encoder.encodeObject(file, forKey: "file")
                if let color = color {
                    encoder.encodeInt32(color, forKey: "color")
                } else {
                    encoder.encodeNil(forKey: "color")
                }
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
                    case let .wallPaper(wallPaper):
                        items.append(.image(telegramMediaImageRepresentationsFromApiSizes(wallPaper.sizes).1))
                    case let .wallPaperSolid(_, _, bgColor, _):
                        items.append(.color(bgColor))
                    case let .wallPaperDocument(flags, id, accessHash, title, slug, document, color):
                        if let file = telegramMediaFileFromApiDocument(document) {
                            items.append(.file(id: id, accessHash: accessHash, isCreator: (flags & 1 << 0) != 0, title: title, slug: slug, file: file, color: color))
                        }
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
