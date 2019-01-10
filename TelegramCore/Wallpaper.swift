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
            case let .image(representations):
                if case .image(representations) = rhs {
                    return true
                } else {
                    return false
            }
            case let .file(lhsId, _, lhsIsCreator, lhsTitle, lhsSlug, _, lhsColor):
                if case let .file(rhsId, _, rhsIsCreator, rhsTitle, rhsSlug, _, rhsColor) = rhs, lhsId == rhsId, lhsIsCreator == rhsIsCreator, lhsTitle == rhsTitle, lhsSlug == rhsSlug, lhsColor == rhsColor {
                    return true
                } else {
                    return false
                }
        }
    }
}

extension TelegramWallpaper {
    init(apiWallpaper: Api.WallPaper) {
        switch apiWallpaper {
            case let .wallPaper(wallPaper):
                self = .image(telegramMediaImageRepresentationsFromApiSizes(wallPaper.sizes).1)
            case let .wallPaperSolid(_, _, bgColor, _):
                self = .color(bgColor)
            case let .wallPaperDocument(flags, id, accessHash, title, slug, document, color):
                if let file = telegramMediaFileFromApiDocument(document) {
                    self = .file(id: id, accessHash: accessHash, isCreator: (flags & 1 << 0) != 0, title: title, slug: slug, file: file, color: color)
                } else {
                    assertionFailure()
                    self = .color(0xffffff)
                }
        }
    }
}
