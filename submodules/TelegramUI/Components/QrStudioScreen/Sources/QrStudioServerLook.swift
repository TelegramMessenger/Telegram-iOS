import Foundation

enum QrStudioServerLook: Equatable {
    case `default`
    case emojiBackdrop(emoji: [QrStudioLookSettings.Emoji]?, backdropId: Int32?)
    case gift(Int64)
}

extension QrStudioLookSettings {
    func serverLook(hasPremium: Bool) -> QrStudioServerLook {
        switch self.kind {
        case 1:
            let emoji = self.emoji.filter { item in
                if case .custom = item {
                    return hasPremium
                }
                return true
            }
            let backdropId = self.themeId == nil ? self.backdropId : nil
            if emoji.isEmpty && backdropId == nil {
                return .default
            }
            return .emojiBackdrop(emoji: emoji.isEmpty ? nil : Array(emoji.prefix(6)), backdropId: backdropId)
        case 2:
            if let giftId = self.giftId {
                return .gift(giftId)
            }
            return .default
        default:
            if self.themeId == nil, let backdropId = self.backdropId {
                return .emojiBackdrop(emoji: nil, backdropId: backdropId)
            }
            return .default
        }
    }

    func applying(_ server: QrStudioServerLook) -> QrStudioLookSettings {
        var result = self
        switch server {
        case .default:
            result.kind = 0
            result.colorId = nil
            result.backdropId = nil
            result.themeId = nil
        case let .emojiBackdrop(emoji, backdropId):
            if let emoji, !emoji.isEmpty {
                let encoded = QrStudioLookSettings(kind: 1, colorId: nil, emoji: emoji, giftId: nil)
                result.kind = 1
                result.emojiUnicode = encoded.emojiUnicode
                result.emojiFileIds = encoded.emojiFileIds
            } else {
                result.kind = 0
            }
            result.colorId = nil
            result.backdropId = backdropId
            result.themeId = nil
        case let .gift(giftId):
            result.kind = 2
            result.giftId = giftId
        }
        return result
    }
}
