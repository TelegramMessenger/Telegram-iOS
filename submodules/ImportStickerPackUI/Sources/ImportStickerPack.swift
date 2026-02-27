import Foundation
import UIKit
import TelegramCore

enum StickerVerificationStatus {
    case loading
    case verified
    case declined
}

public class ImportStickerPack {
    public enum StickerPackType {
        public enum ContentType {
            case image
            case animation
            case video
            
            var importType: CreateStickerSetType.ContentType {
                switch self {
                case .image:
                    return .image
                case .animation:
                    return .animation
                case .video:
                    return .video
                }
            }
        }
        
        case stickers(content: ContentType)
        case emoji(content: ContentType, textColored: Bool)
        
        var contentType: StickerPackType.ContentType {
            switch self {
            case let .stickers(content), let .emoji(content, _):
                return content
            }
        }
        
        var importType: CreateStickerSetType {
            switch self {
            case let .stickers(content):
                return .stickers(content: content.importType)
            case let .emoji(content, textColored):
                return .emoji(content: content.importType, textColored: textColored)
            }
        }
    }
    
    public class Sticker: Equatable {
        public enum Content {
            case image(Data)
            case animation(Data)
            case video(Data, String)
        }
        
        var mimeType: String {
            switch self.content {
                case .image:
                    return "image/png"
                case .animation:
                    return "application/x-tgsticker"
                case let .video(_, mimeType):
                    return mimeType
            }
        }
        
        public static func == (lhs: ImportStickerPack.Sticker, rhs: ImportStickerPack.Sticker) -> Bool {
            return lhs.uuid == rhs.uuid
        }
        
        let content: Content
        let emojis: [String]
        let keywords: String
        let uuid: UUID
        var resource: EngineMediaResource?
        
        init(content: Content, emojis: [String], keywords: String, uuid: UUID = UUID()) {
            self.content = content
            self.emojis = emojis
            self.keywords = keywords
            self.uuid = uuid
        }
        
        var data: Data {
            switch self.content {
                case let .image(data), let .animation(data), let .video(data, _):
                    return data
            }
        }
        
        var isAnimated: Bool {
            if case .animation = self.content {
                return true
            } else {
                return false
            }
        }
    }
    
    public let software: String
    public let type: StickerPackType
    public let thumbnail: Sticker?
    public let stickers: [Sticker]
    
    public init?(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        self.software = json["software"] as? String ?? ""
        let isAnimated = json["isAnimated"] as? Bool ?? false
        let isVideo = json["isVideo"] as? Bool ?? false
        let isEmoji = json["isEmoji"] as? Bool ?? false
        let isTextColored = json["isTextColored"] as? Bool ?? false
        let type: StickerPackType
        if isEmoji {
            if isAnimated {
                type = .emoji(content: .animation, textColored: isTextColored)
            } else if isVideo {
                type = .emoji(content: .video, textColored: isTextColored)
            } else {
                type = .emoji(content: .image, textColored: isTextColored)
            }
        } else {
            if isAnimated {
                type = .stickers(content: .animation)
            } else if isVideo {
                type = .stickers(content: .video)
            } else {
                type = .stickers(content: .image)
            }
        }
        self.type = type
        
        func parseSticker(_ sticker: [String: Any]) -> Sticker? {
            if let dataString = sticker["data"] as? String, let mimeType = sticker["mimeType"] as? String, let data = Data(base64Encoded: dataString) {
                var content: Sticker.Content?
                switch mimeType.lowercased() {
                case "image/png":
                    if case .image = type.contentType {
                        content = .image(data)
                    }
                case "application/x-tgsticker":
                    if case .animation = type.contentType {
                        content = .animation(data)
                    }
                case "video/webm", "image/webp", "image/gif":
                    if case .video = type.contentType {
                        content = .video(data, mimeType)
                    }
                default:
                    break
                }
                if let content = content {
                    return Sticker(content: content, emojis: sticker["emojis"] as? [String] ?? [], keywords: sticker["keywords"] as? String ?? "")
                }
            }
            return nil
        }
        
        if let thumbnail = json["thumbnail"] as? [String: Any], let parsedSticker = parseSticker(thumbnail) {
            self.thumbnail = parsedSticker
        } else {
            self.thumbnail = nil
        }
        
        var stickers: [Sticker] = []
        if let stickersArray = json["stickers"] as? [[String: Any]] {
            for sticker in stickersArray {
                if let parsedSticker = parseSticker(sticker) {
                    stickers.append(parsedSticker)
                }
            }
        }
        self.stickers = stickers
    }
}
