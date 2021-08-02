import Foundation
import UIKit
import Postbox

enum StickerVerificationStatus {
    case loading
    case verified
    case declined
}

public class ImportStickerPack {
    public class Sticker: Equatable {
        public enum Content {
            case image(Data)
            case animation(Data)
        }
        
        public static func == (lhs: ImportStickerPack.Sticker, rhs: ImportStickerPack.Sticker) -> Bool {
            return lhs.uuid == rhs.uuid
        }
        
        let content: Content
        let emojis: [String]
        let uuid: UUID
        var resource: MediaResource?
        
        init(content: Content, emojis: [String], uuid: UUID = UUID()) {
            self.content = content
            self.emojis = emojis
            self.uuid = uuid
        }
        
        var data: Data {
            switch self.content {
                case let .image(data):
                    return data
                case let .animation(data):
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
    public let isAnimated: Bool
    public let thumbnail: Sticker?
    public let stickers: [Sticker]
    
    public init?(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        self.software = json["software"] as? String ?? ""
        let isAnimated = json["isAnimated"] as? Bool ?? false
        self.isAnimated = isAnimated
        
        func parseSticker(_ sticker: [String: Any]) -> Sticker? {
            if let dataString = sticker["data"] as? String, let mimeType = sticker["mimeType"] as? String, let data = Data(base64Encoded: dataString) {
                var content: Sticker.Content?
                switch mimeType.lowercased() {
                    case "image/png":
                        if !isAnimated {
                            content = .image(data)
                        }
                    case "application/x-tgsticker":
                        if isAnimated {
                            content = .animation(data)
                        }
                    default:
                        break
                }
                if let content = content {
                    return Sticker(content: content, emojis: sticker["emojis"] as? [String] ?? [])
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
