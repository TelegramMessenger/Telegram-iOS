import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import TelegramApiMac
#else
import Postbox
import SwiftSignalKit
import TelegramApi
#endif

public final class TelegramTheme: OrderedItemListEntryContents, Equatable {
    public let id: Int64
    public let accessHash: Int64
    public let slug: String
    public let title: String
    public let file: TelegramMediaFile
    public let isCreator: Bool
    public let isDefault: Bool
    
    public init(id: Int64, accessHash: Int64, slug: String, title: String, file: TelegramMediaFile, isCreator: Bool, isDefault: Bool) {
        self.id = id
        self.accessHash = accessHash
        self.slug = slug
        self.title = title
        self.file = file
        self.isCreator = isCreator
        self.isDefault = isDefault
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("accessHash", orElse: 0)
        self.slug = decoder.decodeStringForKey("slug", orElse: "")
        self.title = decoder.decodeStringForKey("title", orElse: "")
        self.file = decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as! TelegramMediaFile
        self.isCreator = decoder.decodeInt32ForKey("isCreator", orElse: 0) != 0
        self.isDefault = decoder.decodeInt32ForKey("isDefault", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
        encoder.encodeInt64(self.accessHash, forKey: "accessHash")
        encoder.encodeString(self.slug, forKey: "slug")
        encoder.encodeString(self.title, forKey: "title")
        encoder.encodeObject(self.file, forKey: "file")
        encoder.encodeInt32(self.isCreator ? 1 : 0, forKey: "isCreator")
        encoder.encodeInt32(self.isDefault ? 1 : 0, forKey: "isDefault")
    }
    
    public static func ==(lhs: TelegramTheme, rhs: TelegramTheme) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.accessHash != rhs.accessHash {
            return false
        }
        if lhs.slug != rhs.slug {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.file.id != rhs.file.id {
            return false
        }
        if lhs.isCreator != rhs.isCreator {
            return false
        }
        if lhs.isDefault != rhs.isDefault {
            return false
        }
        return true
    }
}

extension TelegramTheme {
    convenience init?(apiTheme: Api.Theme) {
        switch apiTheme {
            case let .theme(flags, id, accessHash, slug, title, document):
                if let file = telegramMediaFileFromApiDocument(document) {
                    self.init(id: id, accessHash: accessHash, slug: slug, title: title, file: file, isCreator: (flags & 1 << 0) != 0, isDefault: (flags & 1 << 1) != 0)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}
