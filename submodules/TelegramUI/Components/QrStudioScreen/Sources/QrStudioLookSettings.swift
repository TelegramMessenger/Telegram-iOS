import Foundation
import TelegramCore

func qrStudioToggle<Id: Equatable>(_ ids: inout [Id], _ id: Id, limit: Int) -> Bool {
    if let index = ids.firstIndex(of: id) {
        guard ids.count > 1 else {
            return false
        }
        ids.remove(at: index)
        return true
    }
    if ids.count >= limit {
        ids.removeFirst(ids.count - limit + 1)
    }
    ids.append(id)
    return true
}

struct QrStudioLookSettings: Codable, Equatable {
    enum Emoji: Equatable, Hashable {
        case unicode(String)
        case custom(Int64)
    }

    struct Resolved<File> {
        var kind: Int32
        var emoji: [(Emoji, File)]
        var giftId: Int64?
    }

    var kind: Int32
    var colorId: Int32?
    var emojiUnicode: [String]
    var emojiFileIds: [Int64]
    var giftId: Int64?
    var codeRemoveFee: Bool?
    var codeExpires: Bool?
    var themeId: String?
    var backdropId: Int32?
    var gift: StarGift.UniqueGift?
    var giftReference: StarGiftReference?

    init(kind: Int32, colorId: Int32?, emoji: [Emoji], giftId: Int64?, themeId: String? = nil, backdropId: Int32? = nil) {
        self.backdropId = backdropId
        self.themeId = themeId
        self.kind = kind
        self.colorId = colorId
        var emojiUnicode: [String] = []
        var emojiFileIds: [Int64] = []
        for item in emoji {
            switch item {
            case let .unicode(value):
                emojiUnicode.append(value)
                emojiFileIds.append(0)
            case let .custom(fileId):
                emojiUnicode.append("")
                emojiFileIds.append(fileId)
            }
        }
        self.emojiUnicode = emojiUnicode
        self.emojiFileIds = emojiFileIds
        self.giftId = giftId
    }

    var emoji: [Emoji] {
        var result: [Emoji] = []
        for i in 0 ..< min(self.emojiUnicode.count, self.emojiFileIds.count) {
            if !self.emojiUnicode[i].isEmpty {
                result.append(.unicode(self.emojiUnicode[i]))
            } else if self.emojiFileIds[i] != 0 {
                result.append(.custom(self.emojiFileIds[i]))
            }
        }
        return result
    }

    var customFileIds: [Int64] {
        return self.emojiFileIds.filter { $0 != 0 }
    }

    func resolve<File>(unicodeFiles: [String: File], customFiles: [Int64: File], giftIds: [Int64]?, hasPremium: Bool) -> Resolved<File> {
        var emoji: [(Emoji, File)] = []
        for item in self.emoji {
            switch item {
            case let .unicode(value):
                if let file = unicodeFiles[value] {
                    emoji.append((item, file))
                }
            case let .custom(fileId):
                if hasPremium, let file = customFiles[fileId] {
                    emoji.append((item, file))
                }
            }
        }

        var kind: Int32 = (0 ... 2).contains(self.kind) ? self.kind : 0
        var giftId = self.giftId
        if let giftIds {
            if let currentGiftId = giftId, !giftIds.contains(currentGiftId) {
                giftId = nil
            }
        }
        if kind == 2 && giftId == nil {
            kind = 0
        }

        return Resolved(
            kind: kind,
            emoji: emoji,
            giftId: giftId
        )
    }
}
