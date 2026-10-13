public extension Api {
    enum InputStarsTransaction: TypeConstructorDescription {
        public class Cons_inputStarsTransaction: TypeConstructorDescription {
            public var flags: Int32
            public var id: String
            public init(flags: Int32, id: String) {
                self.flags = flags
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStarsTransaction", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id))])
            }
        }
        case inputStarsTransaction(Cons_inputStarsTransaction)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStarsTransaction(let _data):
                if boxed {
                    buffer.appendInt32(543876817)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputStarsTransaction(let _data):
                return ("inputStarsTransaction", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_inputStarsTransaction(_ reader: BufferReader) -> InputStarsTransaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputStarsTransaction.inputStarsTransaction(Cons_inputStarsTransaction(flags: _1!, id: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputStickerSet: TypeConstructorDescription {
        public class Cons_inputStickerSetDice: TypeConstructorDescription {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickerSetDice", [("emoticon", ConstructorParameterDescription(self.emoticon))])
            }
        }
        public class Cons_inputStickerSetID: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickerSetID", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputStickerSetShortName: TypeConstructorDescription {
            public var shortName: String
            public init(shortName: String) {
                self.shortName = shortName
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickerSetShortName", [("shortName", ConstructorParameterDescription(self.shortName))])
            }
        }
        case inputStickerSetAnimatedEmoji
        case inputStickerSetAnimatedEmojiAnimations
        case inputStickerSetDice(Cons_inputStickerSetDice)
        case inputStickerSetEmojiChannelDefaultStatuses
        case inputStickerSetEmojiDefaultStatuses
        case inputStickerSetEmojiDefaultTopicIcons
        case inputStickerSetEmojiGenericAnimations
        case inputStickerSetEmpty
        case inputStickerSetID(Cons_inputStickerSetID)
        case inputStickerSetPremiumGifts
        case inputStickerSetShortName(Cons_inputStickerSetShortName)
        case inputStickerSetTonGifts

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStickerSetAnimatedEmoji:
                if boxed {
                    buffer.appendInt32(42402760)
                }
                break
            case .inputStickerSetAnimatedEmojiAnimations:
                if boxed {
                    buffer.appendInt32(215889721)
                }
                break
            case .inputStickerSetDice(let _data):
                if boxed {
                    buffer.appendInt32(-427863538)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                break
            case .inputStickerSetEmojiChannelDefaultStatuses:
                if boxed {
                    buffer.appendInt32(1232373075)
                }
                break
            case .inputStickerSetEmojiDefaultStatuses:
                if boxed {
                    buffer.appendInt32(701560302)
                }
                break
            case .inputStickerSetEmojiDefaultTopicIcons:
                if boxed {
                    buffer.appendInt32(1153562857)
                }
                break
            case .inputStickerSetEmojiGenericAnimations:
                if boxed {
                    buffer.appendInt32(80008398)
                }
                break
            case .inputStickerSetEmpty:
                if boxed {
                    buffer.appendInt32(-4838507)
                }
                break
            case .inputStickerSetID(let _data):
                if boxed {
                    buffer.appendInt32(-1645763991)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputStickerSetPremiumGifts:
                if boxed {
                    buffer.appendInt32(-930399486)
                }
                break
            case .inputStickerSetShortName(let _data):
                if boxed {
                    buffer.appendInt32(-2044933984)
                }
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                break
            case .inputStickerSetTonGifts:
                if boxed {
                    buffer.appendInt32(485912992)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputStickerSetAnimatedEmoji:
                return ("inputStickerSetAnimatedEmoji", [])
            case .inputStickerSetAnimatedEmojiAnimations:
                return ("inputStickerSetAnimatedEmojiAnimations", [])
            case .inputStickerSetDice(let _data):
                return ("inputStickerSetDice", [("emoticon", ConstructorParameterDescription(_data.emoticon))])
            case .inputStickerSetEmojiChannelDefaultStatuses:
                return ("inputStickerSetEmojiChannelDefaultStatuses", [])
            case .inputStickerSetEmojiDefaultStatuses:
                return ("inputStickerSetEmojiDefaultStatuses", [])
            case .inputStickerSetEmojiDefaultTopicIcons:
                return ("inputStickerSetEmojiDefaultTopicIcons", [])
            case .inputStickerSetEmojiGenericAnimations:
                return ("inputStickerSetEmojiGenericAnimations", [])
            case .inputStickerSetEmpty:
                return ("inputStickerSetEmpty", [])
            case .inputStickerSetID(let _data):
                return ("inputStickerSetID", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputStickerSetPremiumGifts:
                return ("inputStickerSetPremiumGifts", [])
            case .inputStickerSetShortName(let _data):
                return ("inputStickerSetShortName", [("shortName", ConstructorParameterDescription(_data.shortName))])
            case .inputStickerSetTonGifts:
                return ("inputStickerSetTonGifts", [])
            }
        }

        public static func parse_inputStickerSetAnimatedEmoji(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetAnimatedEmoji
        }
        public static func parse_inputStickerSetAnimatedEmojiAnimations(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetAnimatedEmojiAnimations
        }
        public static func parse_inputStickerSetDice(_ reader: BufferReader) -> InputStickerSet? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickerSet.inputStickerSetDice(Cons_inputStickerSetDice(emoticon: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetEmojiChannelDefaultStatuses(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmojiChannelDefaultStatuses
        }
        public static func parse_inputStickerSetEmojiDefaultStatuses(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmojiDefaultStatuses
        }
        public static func parse_inputStickerSetEmojiDefaultTopicIcons(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmojiDefaultTopicIcons
        }
        public static func parse_inputStickerSetEmojiGenericAnimations(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmojiGenericAnimations
        }
        public static func parse_inputStickerSetEmpty(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmpty
        }
        public static func parse_inputStickerSetID(_ reader: BufferReader) -> InputStickerSet? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputStickerSet.inputStickerSetID(Cons_inputStickerSetID(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetPremiumGifts(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetPremiumGifts
        }
        public static func parse_inputStickerSetShortName(_ reader: BufferReader) -> InputStickerSet? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickerSet.inputStickerSetShortName(Cons_inputStickerSetShortName(shortName: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetTonGifts(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetTonGifts
        }
    }
}
public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription {
        public class Cons_inputStickerSetItem: TypeConstructorDescription {
            public var flags: Int32
            public var document: Api.InputDocument
            public var emoji: String
            public var maskCoords: Api.MaskCoords?
            public var keywords: String?
            public init(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?, keywords: String?) {
                self.flags = flags
                self.document = document
                self.emoji = emoji
                self.maskCoords = maskCoords
                self.keywords = keywords
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickerSetItem", [("flags", ConstructorParameterDescription(self.flags)), ("document", ConstructorParameterDescription(self.document)), ("emoji", ConstructorParameterDescription(self.emoji)), ("maskCoords", ConstructorParameterDescription(self.maskCoords)), ("keywords", ConstructorParameterDescription(self.keywords))])
            }
        }
        case inputStickerSetItem(Cons_inputStickerSetItem)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStickerSetItem(let _data):
                if boxed {
                    buffer.appendInt32(853188252)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                serializeString(_data.emoji, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.maskCoords!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.keywords!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputStickerSetItem(let _data):
                return ("inputStickerSetItem", [("flags", ConstructorParameterDescription(_data.flags)), ("document", ConstructorParameterDescription(_data.document)), ("emoji", ConstructorParameterDescription(_data.emoji)), ("maskCoords", ConstructorParameterDescription(_data.maskCoords)), ("keywords", ConstructorParameterDescription(_data.keywords))])
            }
        }

        public static func parse_inputStickerSetItem(_ reader: BufferReader) -> InputStickerSetItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.MaskCoords?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.MaskCoords
                }
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputStickerSetItem.inputStickerSetItem(Cons_inputStickerSetItem(flags: _1!, document: _2!, emoji: _3!, maskCoords: _4, keywords: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputStickeredMedia: TypeConstructorDescription {
        public class Cons_inputStickeredMediaDocument: TypeConstructorDescription {
            public var id: Api.InputDocument
            public init(id: Api.InputDocument) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickeredMediaDocument", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_inputStickeredMediaPhoto: TypeConstructorDescription {
            public var id: Api.InputPhoto
            public init(id: Api.InputPhoto) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickeredMediaPhoto", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case inputStickeredMediaDocument(Cons_inputStickeredMediaDocument)
        case inputStickeredMediaPhoto(Cons_inputStickeredMediaPhoto)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStickeredMediaDocument(let _data):
                if boxed {
                    buffer.appendInt32(70813275)
                }
                _data.id.serialize(buffer, true)
                break
            case .inputStickeredMediaPhoto(let _data):
                if boxed {
                    buffer.appendInt32(1251549527)
                }
                _data.id.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputStickeredMediaDocument(let _data):
                return ("inputStickeredMediaDocument", [("id", ConstructorParameterDescription(_data.id))])
            case .inputStickeredMediaPhoto(let _data):
                return ("inputStickeredMediaPhoto", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_inputStickeredMediaDocument(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputDocument?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaDocument(Cons_inputStickeredMediaDocument(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickeredMediaPhoto(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaPhoto(Cons_inputStickeredMediaPhoto(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputStorePaymentPurpose: TypeConstructorDescription {
        public class Cons_inputStorePaymentAuthCode: TypeConstructorDescription {
            public var flags: Int32
            public var phoneNumber: String
            public var phoneCodeHash: String
            public var premiumDays: Int32
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, phoneNumber: String, phoneCodeHash: String, premiumDays: Int32, currency: String, amount: Int64) {
                self.flags = flags
                self.phoneNumber = phoneNumber
                self.phoneCodeHash = phoneCodeHash
                self.premiumDays = premiumDays
                self.currency = currency
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentAuthCode", [("flags", ConstructorParameterDescription(self.flags)), ("phoneNumber", ConstructorParameterDescription(self.phoneNumber)), ("phoneCodeHash", ConstructorParameterDescription(self.phoneCodeHash)), ("premiumDays", ConstructorParameterDescription(self.premiumDays)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount))])
            }
        }
        public class Cons_inputStorePaymentGiftPremium: TypeConstructorDescription {
            public var userId: Api.InputUser
            public var currency: String
            public var amount: Int64
            public init(userId: Api.InputUser, currency: String, amount: Int64) {
                self.userId = userId
                self.currency = currency
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentGiftPremium", [("userId", ConstructorParameterDescription(self.userId)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount))])
            }
        }
        public class Cons_inputStorePaymentPremiumGiftCode: TypeConstructorDescription {
            public var flags: Int32
            public var users: [Api.InputUser]
            public var boostPeer: Api.InputPeer?
            public var currency: String
            public var amount: Int64
            public var message: Api.TextWithEntities?
            public init(flags: Int32, users: [Api.InputUser], boostPeer: Api.InputPeer?, currency: String, amount: Int64, message: Api.TextWithEntities?) {
                self.flags = flags
                self.users = users
                self.boostPeer = boostPeer
                self.currency = currency
                self.amount = amount
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentPremiumGiftCode", [("flags", ConstructorParameterDescription(self.flags)), ("users", ConstructorParameterDescription(self.users)), ("boostPeer", ConstructorParameterDescription(self.boostPeer)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_inputStorePaymentPremiumGiveaway: TypeConstructorDescription {
            public var flags: Int32
            public var boostPeer: Api.InputPeer
            public var additionalPeers: [Api.InputPeer]?
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var randomId: Int64
            public var untilDate: Int32
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64) {
                self.flags = flags
                self.boostPeer = boostPeer
                self.additionalPeers = additionalPeers
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.randomId = randomId
                self.untilDate = untilDate
                self.currency = currency
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentPremiumGiveaway", [("flags", ConstructorParameterDescription(self.flags)), ("boostPeer", ConstructorParameterDescription(self.boostPeer)), ("additionalPeers", ConstructorParameterDescription(self.additionalPeers)), ("countriesIso2", ConstructorParameterDescription(self.countriesIso2)), ("prizeDescription", ConstructorParameterDescription(self.prizeDescription)), ("randomId", ConstructorParameterDescription(self.randomId)), ("untilDate", ConstructorParameterDescription(self.untilDate)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount))])
            }
        }
        public class Cons_inputStorePaymentPremiumSubscription: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentPremiumSubscription", [("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        public class Cons_inputStorePaymentStarsGift: TypeConstructorDescription {
            public var userId: Api.InputUser
            public var stars: Int64
            public var currency: String
            public var amount: Int64
            public init(userId: Api.InputUser, stars: Int64, currency: String, amount: Int64) {
                self.userId = userId
                self.stars = stars
                self.currency = currency
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentStarsGift", [("userId", ConstructorParameterDescription(self.userId)), ("stars", ConstructorParameterDescription(self.stars)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount))])
            }
        }
        public class Cons_inputStorePaymentStarsGiveaway: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64
            public var boostPeer: Api.InputPeer
            public var additionalPeers: [Api.InputPeer]?
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var randomId: Int64
            public var untilDate: Int32
            public var currency: String
            public var amount: Int64
            public var users: Int32
            public init(flags: Int32, stars: Int64, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, users: Int32) {
                self.flags = flags
                self.stars = stars
                self.boostPeer = boostPeer
                self.additionalPeers = additionalPeers
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.randomId = randomId
                self.untilDate = untilDate
                self.currency = currency
                self.amount = amount
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentStarsGiveaway", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars)), ("boostPeer", ConstructorParameterDescription(self.boostPeer)), ("additionalPeers", ConstructorParameterDescription(self.additionalPeers)), ("countriesIso2", ConstructorParameterDescription(self.countriesIso2)), ("prizeDescription", ConstructorParameterDescription(self.prizeDescription)), ("randomId", ConstructorParameterDescription(self.randomId)), ("untilDate", ConstructorParameterDescription(self.untilDate)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_inputStorePaymentStarsTopup: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64
            public var currency: String
            public var amount: Int64
            public var spendPurposePeer: Api.InputPeer?
            public init(flags: Int32, stars: Int64, currency: String, amount: Int64, spendPurposePeer: Api.InputPeer?) {
                self.flags = flags
                self.stars = stars
                self.currency = currency
                self.amount = amount
                self.spendPurposePeer = spendPurposePeer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStorePaymentStarsTopup", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("spendPurposePeer", ConstructorParameterDescription(self.spendPurposePeer))])
            }
        }
        case inputStorePaymentAuthCode(Cons_inputStorePaymentAuthCode)
        case inputStorePaymentGiftPremium(Cons_inputStorePaymentGiftPremium)
        case inputStorePaymentPremiumGiftCode(Cons_inputStorePaymentPremiumGiftCode)
        case inputStorePaymentPremiumGiveaway(Cons_inputStorePaymentPremiumGiveaway)
        case inputStorePaymentPremiumSubscription(Cons_inputStorePaymentPremiumSubscription)
        case inputStorePaymentStarsGift(Cons_inputStorePaymentStarsGift)
        case inputStorePaymentStarsGiveaway(Cons_inputStorePaymentStarsGiveaway)
        case inputStorePaymentStarsTopup(Cons_inputStorePaymentStarsTopup)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStorePaymentAuthCode(let _data):
                if boxed {
                    buffer.appendInt32(1069645911)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.phoneCodeHash, buffer: buffer, boxed: false)
                serializeInt32(_data.premiumDays, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentGiftPremium(let _data):
                if boxed {
                    buffer.appendInt32(1634697192)
                }
                _data.userId.serialize(buffer, true)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentPremiumGiftCode(let _data):
                if boxed {
                    buffer.appendInt32(-75955309)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.boostPeer!.serialize(buffer, true)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .inputStorePaymentPremiumGiveaway(let _data):
                if boxed {
                    buffer.appendInt32(369444042)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.boostPeer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.additionalPeers!.count))
                    for item in _data.additionalPeers! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.countriesIso2!.count))
                    for item in _data.countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.prizeDescription!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentPremiumSubscription(let _data):
                if boxed {
                    buffer.appendInt32(-1502273946)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentStarsGift(let _data):
                if boxed {
                    buffer.appendInt32(494149367)
                }
                _data.userId.serialize(buffer, true)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentStarsGiveaway(let _data):
                if boxed {
                    buffer.appendInt32(1964968186)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                _data.boostPeer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.additionalPeers!.count))
                    for item in _data.additionalPeers! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.countriesIso2!.count))
                    for item in _data.countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.prizeDescription!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeInt32(_data.users, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentStarsTopup(let _data):
                if boxed {
                    buffer.appendInt32(-106780981)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.spendPurposePeer!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputStorePaymentAuthCode(let _data):
                return ("inputStorePaymentAuthCode", [("flags", ConstructorParameterDescription(_data.flags)), ("phoneNumber", ConstructorParameterDescription(_data.phoneNumber)), ("phoneCodeHash", ConstructorParameterDescription(_data.phoneCodeHash)), ("premiumDays", ConstructorParameterDescription(_data.premiumDays)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount))])
            case .inputStorePaymentGiftPremium(let _data):
                return ("inputStorePaymentGiftPremium", [("userId", ConstructorParameterDescription(_data.userId)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount))])
            case .inputStorePaymentPremiumGiftCode(let _data):
                return ("inputStorePaymentPremiumGiftCode", [("flags", ConstructorParameterDescription(_data.flags)), ("users", ConstructorParameterDescription(_data.users)), ("boostPeer", ConstructorParameterDescription(_data.boostPeer)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("message", ConstructorParameterDescription(_data.message))])
            case .inputStorePaymentPremiumGiveaway(let _data):
                return ("inputStorePaymentPremiumGiveaway", [("flags", ConstructorParameterDescription(_data.flags)), ("boostPeer", ConstructorParameterDescription(_data.boostPeer)), ("additionalPeers", ConstructorParameterDescription(_data.additionalPeers)), ("countriesIso2", ConstructorParameterDescription(_data.countriesIso2)), ("prizeDescription", ConstructorParameterDescription(_data.prizeDescription)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("untilDate", ConstructorParameterDescription(_data.untilDate)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount))])
            case .inputStorePaymentPremiumSubscription(let _data):
                return ("inputStorePaymentPremiumSubscription", [("flags", ConstructorParameterDescription(_data.flags))])
            case .inputStorePaymentStarsGift(let _data):
                return ("inputStorePaymentStarsGift", [("userId", ConstructorParameterDescription(_data.userId)), ("stars", ConstructorParameterDescription(_data.stars)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount))])
            case .inputStorePaymentStarsGiveaway(let _data):
                return ("inputStorePaymentStarsGiveaway", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars)), ("boostPeer", ConstructorParameterDescription(_data.boostPeer)), ("additionalPeers", ConstructorParameterDescription(_data.additionalPeers)), ("countriesIso2", ConstructorParameterDescription(_data.countriesIso2)), ("prizeDescription", ConstructorParameterDescription(_data.prizeDescription)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("untilDate", ConstructorParameterDescription(_data.untilDate)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("users", ConstructorParameterDescription(_data.users))])
            case .inputStorePaymentStarsTopup(let _data):
                return ("inputStorePaymentStarsTopup", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("spendPurposePeer", ConstructorParameterDescription(_data.spendPurposePeer))])
            }
        }

        public static func parse_inputStorePaymentAuthCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputStorePaymentPurpose.inputStorePaymentAuthCode(Cons_inputStorePaymentAuthCode(flags: _1!, phoneNumber: _2!, phoneCodeHash: _3!, premiumDays: _4!, currency: _5!, amount: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentGiftPremium(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputStorePaymentPurpose.inputStorePaymentGiftPremium(Cons_inputStorePaymentGiftPremium(userId: _1!, currency: _2!, amount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentPremiumGiftCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            var _3: Api.InputPeer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.TextWithEntities?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumGiftCode(Cons_inputStorePaymentPremiumGiftCode(flags: _1!, users: _2!, boostPeer: _3, currency: _4!, amount: _5!, message: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentPremiumGiveaway(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _3: [Api.InputPeer]?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
                }
            }
            var _4: [String]?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: String?
            _8 = parseString(reader)
            var _9: Int64?
            _9 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumGiveaway(Cons_inputStorePaymentPremiumGiveaway(flags: _1!, boostPeer: _2!, additionalPeers: _3, countriesIso2: _4, prizeDescription: _5, randomId: _6!, untilDate: _7!, currency: _8!, amount: _9!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentPremiumSubscription(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumSubscription(Cons_inputStorePaymentPremiumSubscription(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentStarsGift(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsGift(Cons_inputStorePaymentStarsGift(userId: _1!, stars: _2!, currency: _3!, amount: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentStarsGiveaway(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.InputPeer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _4: [Api.InputPeer]?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
                }
            }
            var _5: [String]?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            var _6: String?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _6 = parseString(reader)
            }
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: String?
            _9 = parseString(reader)
            var _10: Int64?
            _10 = reader.readInt64()
            var _11: Int32?
            _11 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsGiveaway(Cons_inputStorePaymentStarsGiveaway(flags: _1!, stars: _2!, boostPeer: _3!, additionalPeers: _4, countriesIso2: _5, prizeDescription: _6, randomId: _7!, untilDate: _8!, currency: _9!, amount: _10!, users: _11!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentStarsTopup(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Api.InputPeer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsTopup(Cons_inputStorePaymentStarsTopup(flags: _1!, stars: _2!, currency: _3!, amount: _4!, spendPurposePeer: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputTheme: TypeConstructorDescription {
        public class Cons_inputTheme: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputTheme", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputThemeSlug: TypeConstructorDescription {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputThemeSlug", [("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        case inputTheme(Cons_inputTheme)
        case inputThemeSlug(Cons_inputThemeSlug)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputTheme(let _data):
                if boxed {
                    buffer.appendInt32(1012306921)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputThemeSlug(let _data):
                if boxed {
                    buffer.appendInt32(-175567375)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputTheme(let _data):
                return ("inputTheme", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputThemeSlug(let _data):
                return ("inputThemeSlug", [("slug", ConstructorParameterDescription(_data.slug))])
            }
        }

        public static func parse_inputTheme(_ reader: BufferReader) -> InputTheme? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputTheme.inputTheme(Cons_inputTheme(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputThemeSlug(_ reader: BufferReader) -> InputTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputTheme.inputThemeSlug(Cons_inputThemeSlug(slug: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputThemeSettings: TypeConstructorDescription {
        public class Cons_inputThemeSettings: TypeConstructorDescription {
            public var flags: Int32
            public var baseTheme: Api.BaseTheme
            public var accentColor: Int32
            public var outboxAccentColor: Int32?
            public var messageColors: [Int32]?
            public var wallpaper: Api.InputWallPaper?
            public var wallpaperSettings: Api.WallPaperSettings?
            public init(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.InputWallPaper?, wallpaperSettings: Api.WallPaperSettings?) {
                self.flags = flags
                self.baseTheme = baseTheme
                self.accentColor = accentColor
                self.outboxAccentColor = outboxAccentColor
                self.messageColors = messageColors
                self.wallpaper = wallpaper
                self.wallpaperSettings = wallpaperSettings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputThemeSettings", [("flags", ConstructorParameterDescription(self.flags)), ("baseTheme", ConstructorParameterDescription(self.baseTheme)), ("accentColor", ConstructorParameterDescription(self.accentColor)), ("outboxAccentColor", ConstructorParameterDescription(self.outboxAccentColor)), ("messageColors", ConstructorParameterDescription(self.messageColors)), ("wallpaper", ConstructorParameterDescription(self.wallpaper)), ("wallpaperSettings", ConstructorParameterDescription(self.wallpaperSettings))])
            }
        }
        case inputThemeSettings(Cons_inputThemeSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputThemeSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1881255857)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.baseTheme.serialize(buffer, true)
                serializeInt32(_data.accentColor, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.outboxAccentColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.messageColors!.count))
                    for item in _data.messageColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.wallpaper!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.wallpaperSettings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputThemeSettings(let _data):
                return ("inputThemeSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("baseTheme", ConstructorParameterDescription(_data.baseTheme)), ("accentColor", ConstructorParameterDescription(_data.accentColor)), ("outboxAccentColor", ConstructorParameterDescription(_data.outboxAccentColor)), ("messageColors", ConstructorParameterDescription(_data.messageColors)), ("wallpaper", ConstructorParameterDescription(_data.wallpaper)), ("wallpaperSettings", ConstructorParameterDescription(_data.wallpaperSettings))])
            }
        }

        public static func parse_inputThemeSettings(_ reader: BufferReader) -> InputThemeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BaseTheme?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BaseTheme
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _4 = reader.readInt32()
            }
            var _5: [Int32]?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _6: Api.InputWallPaper?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.InputWallPaper
                }
            }
            var _7: Api.WallPaperSettings?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputThemeSettings.inputThemeSettings(Cons_inputThemeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, outboxAccentColor: _4, messageColors: _5, wallpaper: _6, wallpaperSettings: _7))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputUser: TypeConstructorDescription {
        public class Cons_inputUser: TypeConstructorDescription {
            public var userId: Int64
            public var accessHash: Int64
            public init(userId: Int64, accessHash: Int64) {
                self.userId = userId
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputUser", [("userId", ConstructorParameterDescription(self.userId)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputUserFromMessage: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var userId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, userId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputUserFromMessage", [("peer", ConstructorParameterDescription(self.peer)), ("msgId", ConstructorParameterDescription(self.msgId)), ("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        case inputUser(Cons_inputUser)
        case inputUserEmpty
        case inputUserFromMessage(Cons_inputUserFromMessage)
        case inputUserSelf

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputUser(let _data):
                if boxed {
                    buffer.appendInt32(-233744186)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputUserEmpty:
                if boxed {
                    buffer.appendInt32(-1182234929)
                }
                break
            case .inputUserFromMessage(let _data):
                if boxed {
                    buffer.appendInt32(497305826)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .inputUserSelf:
                if boxed {
                    buffer.appendInt32(-138301121)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputUser(let _data):
                return ("inputUser", [("userId", ConstructorParameterDescription(_data.userId)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputUserEmpty:
                return ("inputUserEmpty", [])
            case .inputUserFromMessage(let _data):
                return ("inputUserFromMessage", [("peer", ConstructorParameterDescription(_data.peer)), ("msgId", ConstructorParameterDescription(_data.msgId)), ("userId", ConstructorParameterDescription(_data.userId))])
            case .inputUserSelf:
                return ("inputUserSelf", [])
            }
        }

        public static func parse_inputUser(_ reader: BufferReader) -> InputUser? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputUser.inputUser(Cons_inputUser(userId: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputUserEmpty(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserEmpty
        }
        public static func parse_inputUserFromMessage(_ reader: BufferReader) -> InputUser? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputUser.inputUserFromMessage(Cons_inputUserFromMessage(peer: _1!, msgId: _2!, userId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputUserSelf(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserSelf
        }
    }
}
public extension Api {
    enum InputWallPaper: TypeConstructorDescription {
        public class Cons_inputWallPaper: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputWallPaper", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputWallPaperNoFile: TypeConstructorDescription {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputWallPaperNoFile", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_inputWallPaperSlug: TypeConstructorDescription {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputWallPaperSlug", [("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        case inputWallPaper(Cons_inputWallPaper)
        case inputWallPaperNoFile(Cons_inputWallPaperNoFile)
        case inputWallPaperSlug(Cons_inputWallPaperSlug)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputWallPaper(let _data):
                if boxed {
                    buffer.appendInt32(-433014407)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputWallPaperNoFile(let _data):
                if boxed {
                    buffer.appendInt32(-1770371538)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            case .inputWallPaperSlug(let _data):
                if boxed {
                    buffer.appendInt32(1913199744)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputWallPaper(let _data):
                return ("inputWallPaper", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputWallPaperNoFile(let _data):
                return ("inputWallPaperNoFile", [("id", ConstructorParameterDescription(_data.id))])
            case .inputWallPaperSlug(let _data):
                return ("inputWallPaperSlug", [("slug", ConstructorParameterDescription(_data.slug))])
            }
        }

        public static func parse_inputWallPaper(_ reader: BufferReader) -> InputWallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWallPaper.inputWallPaper(Cons_inputWallPaper(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperNoFile(_ reader: BufferReader) -> InputWallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputWallPaper.inputWallPaperNoFile(Cons_inputWallPaperNoFile(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperSlug(_ reader: BufferReader) -> InputWallPaper? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputWallPaper.inputWallPaperSlug(Cons_inputWallPaperSlug(slug: _1!))
            }
            else {
                return nil
            }
        }
    }
}
