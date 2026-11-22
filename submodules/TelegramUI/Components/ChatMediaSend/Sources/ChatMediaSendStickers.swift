import Foundation
import TelegramCore
import MediaEditor

public func chatMediaSendCollectStickers(entities: [CodableDrawingEntity]) -> [TelegramMediaFile] {
    var stickers: [TelegramMediaFile] = []
    for entity in entities {
        switch entity {
        case let .sticker(stickerEntity):
            if case let .file(file, fileType) = stickerEntity.content, case .sticker = fileType {
                stickers.append(file.media)
            }
        case let .text(textEntity):
            if let subEntities = textEntity.renderSubEntities {
                for entity in subEntities {
                    if let stickerEntity = entity as? DrawingStickerEntity, case let .file(file, fileType) = stickerEntity.content, case .sticker = fileType {
                        stickers.append(file.media)
                    }
                }
            }
        default:
            break
        }
    }
    return stickers
}
