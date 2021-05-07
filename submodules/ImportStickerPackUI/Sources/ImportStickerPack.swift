import Foundation
import UIKit

public class ImportStickerPack {
    public class Sticker: Equatable {
        public static func == (lhs: ImportStickerPack.Sticker, rhs: ImportStickerPack.Sticker) -> Bool {
            return lhs.uuid == rhs.uuid
        }
        
        let image: UIImage
        let emojis: [String]
        let uuid: UUID
        
        init(image: UIImage, emojis: [String], uuid: UUID = UUID()) {
            self.image = image
            self.emojis = emojis
            self.uuid = uuid
        }
    }
    
    public var identifier: String
    public var name: String
    public let software: String
    public var thumbnail: String?
    public let isAnimated: Bool
    
    public var stickers: [Sticker]
    
    public init?(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        
        self.name = json["name"] as? String ?? ""
        self.identifier = json["identifier"] as? String ?? ""
        self.software = json["software"] as? String ?? ""
        self.isAnimated = json["isAnimated"] as? Bool ?? false
        
        var stickers: [Sticker] = []
        if let stickersArray = json["stickers"] as? [[String: Any]] {
            for sticker in stickersArray {
                if let dataString = sticker["data"] as? String, let data = Data(base64Encoded: dataString), let image = UIImage(data: data) {
                    stickers.append(Sticker(image: image, emojis: sticker["emojis"] as? [String] ?? []))
                }
            }
        }
        self.stickers = stickers
    }
}
