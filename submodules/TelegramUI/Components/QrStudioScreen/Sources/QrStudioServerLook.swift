import Foundation

enum QrStudioServerLook: Equatable {
    case `default`
    case emoji([QrStudioLookSettings.Emoji])
    case color(Int32)
    case gift(Int64)
    case backdrop(Int32)
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
            return emoji.isEmpty ? .default : .emoji(Array(emoji.prefix(6)))
        case 2:
            if let giftId = self.giftId {
                return .gift(giftId)
            }
            return .default
        default:
            if self.themeId == nil, let backdropId = self.backdropId {
                return .backdrop(backdropId)
            }
            if self.themeId == nil, let colorId = self.colorId {
                return .color(colorId)
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
        case let .emoji(emoji):
            result = QrStudioLookSettings(kind: 1, colorId: self.colorId, emoji: emoji, giftId: self.giftId, themeId: nil, backdropId: self.backdropId)
            result.codeRemoveFee = self.codeRemoveFee
            result.codeExpires = self.codeExpires
        case let .color(colorId):
            result.kind = 0
            result.colorId = colorId
            result.backdropId = nil
            result.themeId = nil
        case let .backdrop(backdropId):
            result.kind = 0
            result.backdropId = backdropId
            result.themeId = nil
        case let .gift(giftId):
            result.kind = 2
            result.giftId = giftId
        }
        return result
    }
}
