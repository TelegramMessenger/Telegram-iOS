public extension Api {
    indirect enum MessageEntity: TypeConstructorDescription {
        public class Cons_inputMessageEntityMentionName: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public var userId: Api.InputUser
            public init(offset: Int32, length: Int32, userId: Api.InputUser) {
                self.offset = offset
                self.length = length
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageEntityMentionName", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length)), ("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        public class Cons_messageEntityBankCard: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityBankCard", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityBlockquote: TypeConstructorDescription {
            public var flags: Int32
            public var offset: Int32
            public var length: Int32
            public init(flags: Int32, offset: Int32, length: Int32) {
                self.flags = flags
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityBlockquote", [("flags", ConstructorParameterDescription(self.flags)), ("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityBold: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityBold", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityBotCommand: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityBotCommand", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityCashtag: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityCashtag", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityCode: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityCode", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityCustomEmoji: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public var documentId: Int64
            public init(offset: Int32, length: Int32, documentId: Int64) {
                self.offset = offset
                self.length = length
                self.documentId = documentId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityCustomEmoji", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length)), ("documentId", ConstructorParameterDescription(self.documentId))])
            }
        }
        public class Cons_messageEntityDiffDelete: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityDiffDelete", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityDiffInsert: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityDiffInsert", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityDiffReplace: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public var oldText: String
            public init(offset: Int32, length: Int32, oldText: String) {
                self.offset = offset
                self.length = length
                self.oldText = oldText
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityDiffReplace", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length)), ("oldText", ConstructorParameterDescription(self.oldText))])
            }
        }
        public class Cons_messageEntityEmail: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityEmail", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityFormattedDate: TypeConstructorDescription {
            public var flags: Int32
            public var offset: Int32
            public var length: Int32
            public var date: Int32
            public init(flags: Int32, offset: Int32, length: Int32, date: Int32) {
                self.flags = flags
                self.offset = offset
                self.length = length
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityFormattedDate", [("flags", ConstructorParameterDescription(self.flags)), ("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length)), ("date", ConstructorParameterDescription(self.date))])
            }
        }
        public class Cons_messageEntityHashtag: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityHashtag", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityItalic: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityItalic", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityMention: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityMention", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityMentionName: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public var userId: Int64
            public init(offset: Int32, length: Int32, userId: Int64) {
                self.offset = offset
                self.length = length
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityMentionName", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length)), ("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        public class Cons_messageEntityPhone: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityPhone", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityPre: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public var language: String
            public init(offset: Int32, length: Int32, language: String) {
                self.offset = offset
                self.length = length
                self.language = language
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityPre", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length)), ("language", ConstructorParameterDescription(self.language))])
            }
        }
        public class Cons_messageEntitySpoiler: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntitySpoiler", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityStrike: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityStrike", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityTextUrl: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public var url: String
            public init(offset: Int32, length: Int32, url: String) {
                self.offset = offset
                self.length = length
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityTextUrl", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        public class Cons_messageEntityUnderline: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityUnderline", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityUnknown: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityUnknown", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_messageEntityUrl: TypeConstructorDescription {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEntityUrl", [("offset", ConstructorParameterDescription(self.offset)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        case inputMessageEntityMentionName(Cons_inputMessageEntityMentionName)
        case messageEntityBankCard(Cons_messageEntityBankCard)
        case messageEntityBlockquote(Cons_messageEntityBlockquote)
        case messageEntityBold(Cons_messageEntityBold)
        case messageEntityBotCommand(Cons_messageEntityBotCommand)
        case messageEntityCashtag(Cons_messageEntityCashtag)
        case messageEntityCode(Cons_messageEntityCode)
        case messageEntityCustomEmoji(Cons_messageEntityCustomEmoji)
        case messageEntityDiffDelete(Cons_messageEntityDiffDelete)
        case messageEntityDiffInsert(Cons_messageEntityDiffInsert)
        case messageEntityDiffReplace(Cons_messageEntityDiffReplace)
        case messageEntityEmail(Cons_messageEntityEmail)
        case messageEntityFormattedDate(Cons_messageEntityFormattedDate)
        case messageEntityHashtag(Cons_messageEntityHashtag)
        case messageEntityItalic(Cons_messageEntityItalic)
        case messageEntityMention(Cons_messageEntityMention)
        case messageEntityMentionName(Cons_messageEntityMentionName)
        case messageEntityPhone(Cons_messageEntityPhone)
        case messageEntityPre(Cons_messageEntityPre)
        case messageEntitySpoiler(Cons_messageEntitySpoiler)
        case messageEntityStrike(Cons_messageEntityStrike)
        case messageEntityTextUrl(Cons_messageEntityTextUrl)
        case messageEntityUnderline(Cons_messageEntityUnderline)
        case messageEntityUnknown(Cons_messageEntityUnknown)
        case messageEntityUrl(Cons_messageEntityUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMessageEntityMentionName(let _data):
                if boxed {
                    buffer.appendInt32(546203849)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                _data.userId.serialize(buffer, true)
                break
            case .messageEntityBankCard(let _data):
                if boxed {
                    buffer.appendInt32(1981704948)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityBlockquote(let _data):
                if boxed {
                    buffer.appendInt32(-238245204)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityBold(let _data):
                if boxed {
                    buffer.appendInt32(-1117713463)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityBotCommand(let _data):
                if boxed {
                    buffer.appendInt32(1827637959)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityCashtag(let _data):
                if boxed {
                    buffer.appendInt32(1280209983)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityCode(let _data):
                if boxed {
                    buffer.appendInt32(681706865)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityCustomEmoji(let _data):
                if boxed {
                    buffer.appendInt32(-925956616)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                break
            case .messageEntityDiffDelete(let _data):
                if boxed {
                    buffer.appendInt32(106086853)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityDiffInsert(let _data):
                if boxed {
                    buffer.appendInt32(1903653142)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityDiffReplace(let _data):
                if boxed {
                    buffer.appendInt32(-960371289)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                serializeString(_data.oldText, buffer: buffer, boxed: false)
                break
            case .messageEntityEmail(let _data):
                if boxed {
                    buffer.appendInt32(1692693954)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityFormattedDate(let _data):
                if boxed {
                    buffer.appendInt32(-1874147385)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .messageEntityHashtag(let _data):
                if boxed {
                    buffer.appendInt32(1868782349)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityItalic(let _data):
                if boxed {
                    buffer.appendInt32(-2106619040)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityMention(let _data):
                if boxed {
                    buffer.appendInt32(-100378723)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityMentionName(let _data):
                if boxed {
                    buffer.appendInt32(-595914432)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .messageEntityPhone(let _data):
                if boxed {
                    buffer.appendInt32(-1687559349)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityPre(let _data):
                if boxed {
                    buffer.appendInt32(1938967520)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                serializeString(_data.language, buffer: buffer, boxed: false)
                break
            case .messageEntitySpoiler(let _data):
                if boxed {
                    buffer.appendInt32(852137487)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityStrike(let _data):
                if boxed {
                    buffer.appendInt32(-1090087980)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityTextUrl(let _data):
                if boxed {
                    buffer.appendInt32(1990644519)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .messageEntityUnderline(let _data):
                if boxed {
                    buffer.appendInt32(-1672577397)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityUnknown(let _data):
                if boxed {
                    buffer.appendInt32(-1148011883)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .messageEntityUrl(let _data):
                if boxed {
                    buffer.appendInt32(1859134776)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMessageEntityMentionName(let _data):
                return ("inputMessageEntityMentionName", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length)), ("userId", ConstructorParameterDescription(_data.userId))])
            case .messageEntityBankCard(let _data):
                return ("messageEntityBankCard", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityBlockquote(let _data):
                return ("messageEntityBlockquote", [("flags", ConstructorParameterDescription(_data.flags)), ("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityBold(let _data):
                return ("messageEntityBold", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityBotCommand(let _data):
                return ("messageEntityBotCommand", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityCashtag(let _data):
                return ("messageEntityCashtag", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityCode(let _data):
                return ("messageEntityCode", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityCustomEmoji(let _data):
                return ("messageEntityCustomEmoji", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length)), ("documentId", ConstructorParameterDescription(_data.documentId))])
            case .messageEntityDiffDelete(let _data):
                return ("messageEntityDiffDelete", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityDiffInsert(let _data):
                return ("messageEntityDiffInsert", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityDiffReplace(let _data):
                return ("messageEntityDiffReplace", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length)), ("oldText", ConstructorParameterDescription(_data.oldText))])
            case .messageEntityEmail(let _data):
                return ("messageEntityEmail", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityFormattedDate(let _data):
                return ("messageEntityFormattedDate", [("flags", ConstructorParameterDescription(_data.flags)), ("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length)), ("date", ConstructorParameterDescription(_data.date))])
            case .messageEntityHashtag(let _data):
                return ("messageEntityHashtag", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityItalic(let _data):
                return ("messageEntityItalic", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityMention(let _data):
                return ("messageEntityMention", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityMentionName(let _data):
                return ("messageEntityMentionName", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length)), ("userId", ConstructorParameterDescription(_data.userId))])
            case .messageEntityPhone(let _data):
                return ("messageEntityPhone", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityPre(let _data):
                return ("messageEntityPre", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length)), ("language", ConstructorParameterDescription(_data.language))])
            case .messageEntitySpoiler(let _data):
                return ("messageEntitySpoiler", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityStrike(let _data):
                return ("messageEntityStrike", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityTextUrl(let _data):
                return ("messageEntityTextUrl", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length)), ("url", ConstructorParameterDescription(_data.url))])
            case .messageEntityUnderline(let _data):
                return ("messageEntityUnderline", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityUnknown(let _data):
                return ("messageEntityUnknown", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            case .messageEntityUrl(let _data):
                return ("messageEntityUrl", [("offset", ConstructorParameterDescription(_data.offset)), ("length", ConstructorParameterDescription(_data.length))])
            }
        }

        public static func parse_inputMessageEntityMentionName(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.InputUser?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.inputMessageEntityMentionName(Cons_inputMessageEntityMentionName(offset: _1!, length: _2!, userId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBankCard(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBankCard(Cons_messageEntityBankCard(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBlockquote(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityBlockquote(Cons_messageEntityBlockquote(flags: _1!, offset: _2!, length: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBold(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBold(Cons_messageEntityBold(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityBotCommand(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBotCommand(Cons_messageEntityBotCommand(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityCashtag(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityCashtag(Cons_messageEntityCashtag(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityCode(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityCode(Cons_messageEntityCode(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityCustomEmoji(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityCustomEmoji(Cons_messageEntityCustomEmoji(offset: _1!, length: _2!, documentId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityDiffDelete(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityDiffDelete(Cons_messageEntityDiffDelete(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityDiffInsert(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityDiffInsert(Cons_messageEntityDiffInsert(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityDiffReplace(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityDiffReplace(Cons_messageEntityDiffReplace(offset: _1!, length: _2!, oldText: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityEmail(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityEmail(Cons_messageEntityEmail(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityFormattedDate(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageEntity.messageEntityFormattedDate(Cons_messageEntityFormattedDate(flags: _1!, offset: _2!, length: _3!, date: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityHashtag(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityHashtag(Cons_messageEntityHashtag(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityItalic(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityItalic(Cons_messageEntityItalic(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityMention(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityMention(Cons_messageEntityMention(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityMentionName(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityMentionName(Cons_messageEntityMentionName(offset: _1!, length: _2!, userId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityPhone(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityPhone(Cons_messageEntityPhone(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityPre(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityPre(Cons_messageEntityPre(offset: _1!, length: _2!, language: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntitySpoiler(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntitySpoiler(Cons_messageEntitySpoiler(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityStrike(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityStrike(Cons_messageEntityStrike(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityTextUrl(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageEntity.messageEntityTextUrl(Cons_messageEntityTextUrl(offset: _1!, length: _2!, url: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityUnderline(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityUnderline(Cons_messageEntityUnderline(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityUnknown(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityUnknown(Cons_messageEntityUnknown(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEntityUrl(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityUrl(Cons_messageEntityUrl(offset: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum MessageExtendedMedia: TypeConstructorDescription {
        public class Cons_messageExtendedMedia: TypeConstructorDescription {
            public var media: Api.MessageMedia
            public init(media: Api.MessageMedia) {
                self.media = media
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageExtendedMedia", [("media", ConstructorParameterDescription(self.media))])
            }
        }
        public class Cons_messageExtendedMediaPreview: TypeConstructorDescription {
            public var flags: Int32
            public var w: Int32?
            public var h: Int32?
            public var thumb: Api.PhotoSize?
            public var videoDuration: Int32?
            public init(flags: Int32, w: Int32?, h: Int32?, thumb: Api.PhotoSize?, videoDuration: Int32?) {
                self.flags = flags
                self.w = w
                self.h = h
                self.thumb = thumb
                self.videoDuration = videoDuration
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageExtendedMediaPreview", [("flags", ConstructorParameterDescription(self.flags)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("thumb", ConstructorParameterDescription(self.thumb)), ("videoDuration", ConstructorParameterDescription(self.videoDuration))])
            }
        }
        case messageExtendedMedia(Cons_messageExtendedMedia)
        case messageExtendedMediaPreview(Cons_messageExtendedMediaPreview)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageExtendedMedia(let _data):
                if boxed {
                    buffer.appendInt32(-297296796)
                }
                _data.media.serialize(buffer, true)
                break
            case .messageExtendedMediaPreview(let _data):
                if boxed {
                    buffer.appendInt32(-1386050360)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.w!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.h!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.thumb!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.videoDuration!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .messageExtendedMedia(let _data):
                return ("messageExtendedMedia", [("media", ConstructorParameterDescription(_data.media))])
            case .messageExtendedMediaPreview(let _data):
                return ("messageExtendedMediaPreview", [("flags", ConstructorParameterDescription(_data.flags)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("thumb", ConstructorParameterDescription(_data.thumb)), ("videoDuration", ConstructorParameterDescription(_data.videoDuration))])
            }
        }

        public static func parse_messageExtendedMedia(_ reader: BufferReader) -> MessageExtendedMedia? {
            var _1: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageExtendedMedia.messageExtendedMedia(Cons_messageExtendedMedia(media: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageExtendedMediaPreview(_ reader: BufferReader) -> MessageExtendedMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.PhotoSize?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.PhotoSize
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageExtendedMedia.messageExtendedMediaPreview(Cons_messageExtendedMediaPreview(flags: _1!, w: _2, h: _3, thumb: _4, videoDuration: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessageFwdHeader: TypeConstructorDescription {
        public class Cons_messageFwdHeader: TypeConstructorDescription {
            public var flags: Int32
            public var fromId: Api.Peer?
            public var fromName: String?
            public var date: Int32
            public var channelPost: Int32?
            public var postAuthor: String?
            public var savedFromPeer: Api.Peer?
            public var savedFromMsgId: Int32?
            public var savedFromId: Api.Peer?
            public var savedFromName: String?
            public var savedDate: Int32?
            public var psaType: String?
            public init(flags: Int32, fromId: Api.Peer?, fromName: String?, date: Int32, channelPost: Int32?, postAuthor: String?, savedFromPeer: Api.Peer?, savedFromMsgId: Int32?, savedFromId: Api.Peer?, savedFromName: String?, savedDate: Int32?, psaType: String?) {
                self.flags = flags
                self.fromId = fromId
                self.fromName = fromName
                self.date = date
                self.channelPost = channelPost
                self.postAuthor = postAuthor
                self.savedFromPeer = savedFromPeer
                self.savedFromMsgId = savedFromMsgId
                self.savedFromId = savedFromId
                self.savedFromName = savedFromName
                self.savedDate = savedDate
                self.psaType = psaType
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageFwdHeader", [("flags", ConstructorParameterDescription(self.flags)), ("fromId", ConstructorParameterDescription(self.fromId)), ("fromName", ConstructorParameterDescription(self.fromName)), ("date", ConstructorParameterDescription(self.date)), ("channelPost", ConstructorParameterDescription(self.channelPost)), ("postAuthor", ConstructorParameterDescription(self.postAuthor)), ("savedFromPeer", ConstructorParameterDescription(self.savedFromPeer)), ("savedFromMsgId", ConstructorParameterDescription(self.savedFromMsgId)), ("savedFromId", ConstructorParameterDescription(self.savedFromId)), ("savedFromName", ConstructorParameterDescription(self.savedFromName)), ("savedDate", ConstructorParameterDescription(self.savedDate)), ("psaType", ConstructorParameterDescription(self.psaType))])
            }
        }
        case messageFwdHeader(Cons_messageFwdHeader)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageFwdHeader(let _data):
                if boxed {
                    buffer.appendInt32(1313731771)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.fromName!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.channelPost!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.postAuthor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.savedFromPeer!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.savedFromMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.savedFromId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeString(_data.savedFromName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.savedDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeString(_data.psaType!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .messageFwdHeader(let _data):
                return ("messageFwdHeader", [("flags", ConstructorParameterDescription(_data.flags)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("fromName", ConstructorParameterDescription(_data.fromName)), ("date", ConstructorParameterDescription(_data.date)), ("channelPost", ConstructorParameterDescription(_data.channelPost)), ("postAuthor", ConstructorParameterDescription(_data.postAuthor)), ("savedFromPeer", ConstructorParameterDescription(_data.savedFromPeer)), ("savedFromMsgId", ConstructorParameterDescription(_data.savedFromMsgId)), ("savedFromId", ConstructorParameterDescription(_data.savedFromId)), ("savedFromName", ConstructorParameterDescription(_data.savedFromName)), ("savedDate", ConstructorParameterDescription(_data.savedDate)), ("psaType", ConstructorParameterDescription(_data.psaType))])
            }
        }

        public static func parse_messageFwdHeader(_ reader: BufferReader) -> MessageFwdHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = reader.readInt32()
            }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = parseString(reader)
            }
            var _7: Api.Peer?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _10: String?
            if Int(_1!) & Int(1 << 9) != 0 {
                _10 = parseString(reader)
            }
            var _11: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _11 = reader.readInt32()
            }
            var _12: String?
            if Int(_1!) & Int(1 << 6) != 0 {
                _12 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 5) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 8) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 9) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 10) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 6) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.MessageFwdHeader.messageFwdHeader(Cons_messageFwdHeader(flags: _1!, fromId: _2, fromName: _3, date: _4!, channelPost: _5, postAuthor: _6, savedFromPeer: _7, savedFromMsgId: _8, savedFromId: _9, savedFromName: _10, savedDate: _11, psaType: _12))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum MessageMedia: TypeConstructorDescription {
        public class Cons_messageMediaContact: TypeConstructorDescription {
            public var phoneNumber: String
            public var firstName: String
            public var lastName: String
            public var vcard: String
            public var userId: Int64
            public init(phoneNumber: String, firstName: String, lastName: String, vcard: String, userId: Int64) {
                self.phoneNumber = phoneNumber
                self.firstName = firstName
                self.lastName = lastName
                self.vcard = vcard
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaContact", [("phoneNumber", ConstructorParameterDescription(self.phoneNumber)), ("firstName", ConstructorParameterDescription(self.firstName)), ("lastName", ConstructorParameterDescription(self.lastName)), ("vcard", ConstructorParameterDescription(self.vcard)), ("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        public class Cons_messageMediaDice: TypeConstructorDescription {
            public var flags: Int32
            public var value: Int32
            public var emoticon: String
            public var gameOutcome: Api.messages.EmojiGameOutcome?
            public init(flags: Int32, value: Int32, emoticon: String, gameOutcome: Api.messages.EmojiGameOutcome?) {
                self.flags = flags
                self.value = value
                self.emoticon = emoticon
                self.gameOutcome = gameOutcome
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaDice", [("flags", ConstructorParameterDescription(self.flags)), ("value", ConstructorParameterDescription(self.value)), ("emoticon", ConstructorParameterDescription(self.emoticon)), ("gameOutcome", ConstructorParameterDescription(self.gameOutcome))])
            }
        }
        public class Cons_messageMediaDocument: TypeConstructorDescription {
            public var flags: Int32
            public var document: Api.Document?
            public var altDocuments: [Api.Document]?
            public var videoCover: Api.Photo?
            public var videoTimestamp: Int32?
            public var ttlSeconds: Int32?
            public init(flags: Int32, document: Api.Document?, altDocuments: [Api.Document]?, videoCover: Api.Photo?, videoTimestamp: Int32?, ttlSeconds: Int32?) {
                self.flags = flags
                self.document = document
                self.altDocuments = altDocuments
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
                self.ttlSeconds = ttlSeconds
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaDocument", [("flags", ConstructorParameterDescription(self.flags)), ("document", ConstructorParameterDescription(self.document)), ("altDocuments", ConstructorParameterDescription(self.altDocuments)), ("videoCover", ConstructorParameterDescription(self.videoCover)), ("videoTimestamp", ConstructorParameterDescription(self.videoTimestamp)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds))])
            }
        }
        public class Cons_messageMediaGame: TypeConstructorDescription {
            public var game: Api.Game
            public init(game: Api.Game) {
                self.game = game
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaGame", [("game", ConstructorParameterDescription(self.game))])
            }
        }
        public class Cons_messageMediaGeo: TypeConstructorDescription {
            public var geo: Api.GeoPoint
            public init(geo: Api.GeoPoint) {
                self.geo = geo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaGeo", [("geo", ConstructorParameterDescription(self.geo))])
            }
        }
        public class Cons_messageMediaGeoLive: TypeConstructorDescription {
            public var flags: Int32
            public var geo: Api.GeoPoint
            public var heading: Int32?
            public var period: Int32
            public var proximityNotificationRadius: Int32?
            public init(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32, proximityNotificationRadius: Int32?) {
                self.flags = flags
                self.geo = geo
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaGeoLive", [("flags", ConstructorParameterDescription(self.flags)), ("geo", ConstructorParameterDescription(self.geo)), ("heading", ConstructorParameterDescription(self.heading)), ("period", ConstructorParameterDescription(self.period)), ("proximityNotificationRadius", ConstructorParameterDescription(self.proximityNotificationRadius))])
            }
        }
        public class Cons_messageMediaGiveaway: TypeConstructorDescription {
            public var flags: Int32
            public var channels: [Int64]
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var quantity: Int32
            public var months: Int32?
            public var stars: Int64?
            public var untilDate: Int32
            public init(flags: Int32, channels: [Int64], countriesIso2: [String]?, prizeDescription: String?, quantity: Int32, months: Int32?, stars: Int64?, untilDate: Int32) {
                self.flags = flags
                self.channels = channels
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.quantity = quantity
                self.months = months
                self.stars = stars
                self.untilDate = untilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaGiveaway", [("flags", ConstructorParameterDescription(self.flags)), ("channels", ConstructorParameterDescription(self.channels)), ("countriesIso2", ConstructorParameterDescription(self.countriesIso2)), ("prizeDescription", ConstructorParameterDescription(self.prizeDescription)), ("quantity", ConstructorParameterDescription(self.quantity)), ("months", ConstructorParameterDescription(self.months)), ("stars", ConstructorParameterDescription(self.stars)), ("untilDate", ConstructorParameterDescription(self.untilDate))])
            }
        }
        public class Cons_messageMediaGiveawayResults: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var additionalPeersCount: Int32?
            public var launchMsgId: Int32
            public var winnersCount: Int32
            public var unclaimedCount: Int32
            public var winners: [Int64]
            public var months: Int32?
            public var stars: Int64?
            public var prizeDescription: String?
            public var untilDate: Int32
            public init(flags: Int32, channelId: Int64, additionalPeersCount: Int32?, launchMsgId: Int32, winnersCount: Int32, unclaimedCount: Int32, winners: [Int64], months: Int32?, stars: Int64?, prizeDescription: String?, untilDate: Int32) {
                self.flags = flags
                self.channelId = channelId
                self.additionalPeersCount = additionalPeersCount
                self.launchMsgId = launchMsgId
                self.winnersCount = winnersCount
                self.unclaimedCount = unclaimedCount
                self.winners = winners
                self.months = months
                self.stars = stars
                self.prizeDescription = prizeDescription
                self.untilDate = untilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaGiveawayResults", [("flags", ConstructorParameterDescription(self.flags)), ("channelId", ConstructorParameterDescription(self.channelId)), ("additionalPeersCount", ConstructorParameterDescription(self.additionalPeersCount)), ("launchMsgId", ConstructorParameterDescription(self.launchMsgId)), ("winnersCount", ConstructorParameterDescription(self.winnersCount)), ("unclaimedCount", ConstructorParameterDescription(self.unclaimedCount)), ("winners", ConstructorParameterDescription(self.winners)), ("months", ConstructorParameterDescription(self.months)), ("stars", ConstructorParameterDescription(self.stars)), ("prizeDescription", ConstructorParameterDescription(self.prizeDescription)), ("untilDate", ConstructorParameterDescription(self.untilDate))])
            }
        }
        public class Cons_messageMediaInvoice: TypeConstructorDescription {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var receiptMsgId: Int32?
            public var currency: String
            public var totalAmount: Int64
            public var startParam: String
            public var extendedMedia: Api.MessageExtendedMedia?
            public init(flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String, extendedMedia: Api.MessageExtendedMedia?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.receiptMsgId = receiptMsgId
                self.currency = currency
                self.totalAmount = totalAmount
                self.startParam = startParam
                self.extendedMedia = extendedMedia
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaInvoice", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("description", ConstructorParameterDescription(self.description)), ("photo", ConstructorParameterDescription(self.photo)), ("receiptMsgId", ConstructorParameterDescription(self.receiptMsgId)), ("currency", ConstructorParameterDescription(self.currency)), ("totalAmount", ConstructorParameterDescription(self.totalAmount)), ("startParam", ConstructorParameterDescription(self.startParam)), ("extendedMedia", ConstructorParameterDescription(self.extendedMedia))])
            }
        }
        public class Cons_messageMediaPaidMedia: TypeConstructorDescription {
            public var starsAmount: Int64
            public var extendedMedia: [Api.MessageExtendedMedia]
            public init(starsAmount: Int64, extendedMedia: [Api.MessageExtendedMedia]) {
                self.starsAmount = starsAmount
                self.extendedMedia = extendedMedia
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaPaidMedia", [("starsAmount", ConstructorParameterDescription(self.starsAmount)), ("extendedMedia", ConstructorParameterDescription(self.extendedMedia))])
            }
        }
        public class Cons_messageMediaPhoto: TypeConstructorDescription {
            public var flags: Int32
            public var photo: Api.Photo?
            public var ttlSeconds: Int32?
            public var video: Api.Document?
            public init(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?, video: Api.Document?) {
                self.flags = flags
                self.photo = photo
                self.ttlSeconds = ttlSeconds
                self.video = video
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaPhoto", [("flags", ConstructorParameterDescription(self.flags)), ("photo", ConstructorParameterDescription(self.photo)), ("ttlSeconds", ConstructorParameterDescription(self.ttlSeconds)), ("video", ConstructorParameterDescription(self.video))])
            }
        }
        public class Cons_messageMediaPoll: TypeConstructorDescription {
            public var flags: Int32
            public var poll: Api.Poll
            public var results: Api.PollResults
            public var attachedMedia: Api.MessageMedia?
            public init(flags: Int32, poll: Api.Poll, results: Api.PollResults, attachedMedia: Api.MessageMedia?) {
                self.flags = flags
                self.poll = poll
                self.results = results
                self.attachedMedia = attachedMedia
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaPoll", [("flags", ConstructorParameterDescription(self.flags)), ("poll", ConstructorParameterDescription(self.poll)), ("results", ConstructorParameterDescription(self.results)), ("attachedMedia", ConstructorParameterDescription(self.attachedMedia))])
            }
        }
        public class Cons_messageMediaStory: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var id: Int32
            public var story: Api.StoryItem?
            public init(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?) {
                self.flags = flags
                self.peer = peer
                self.id = id
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaStory", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("id", ConstructorParameterDescription(self.id)), ("story", ConstructorParameterDescription(self.story))])
            }
        }
        public class Cons_messageMediaToDo: TypeConstructorDescription {
            public var flags: Int32
            public var todo: Api.TodoList
            public var completions: [Api.TodoCompletion]?
            public init(flags: Int32, todo: Api.TodoList, completions: [Api.TodoCompletion]?) {
                self.flags = flags
                self.todo = todo
                self.completions = completions
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaToDo", [("flags", ConstructorParameterDescription(self.flags)), ("todo", ConstructorParameterDescription(self.todo)), ("completions", ConstructorParameterDescription(self.completions))])
            }
        }
        public class Cons_messageMediaVenue: TypeConstructorDescription {
            public var geo: Api.GeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public init(geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
                self.geo = geo
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaVenue", [("geo", ConstructorParameterDescription(self.geo)), ("title", ConstructorParameterDescription(self.title)), ("address", ConstructorParameterDescription(self.address)), ("provider", ConstructorParameterDescription(self.provider)), ("venueId", ConstructorParameterDescription(self.venueId)), ("venueType", ConstructorParameterDescription(self.venueType))])
            }
        }
        public class Cons_messageMediaVideoStream: TypeConstructorDescription {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public init(flags: Int32, call: Api.InputGroupCall) {
                self.flags = flags
                self.call = call
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaVideoStream", [("flags", ConstructorParameterDescription(self.flags)), ("call", ConstructorParameterDescription(self.call))])
            }
        }
        public class Cons_messageMediaWebPage: TypeConstructorDescription {
            public var flags: Int32
            public var webpage: Api.WebPage
            public init(flags: Int32, webpage: Api.WebPage) {
                self.flags = flags
                self.webpage = webpage
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageMediaWebPage", [("flags", ConstructorParameterDescription(self.flags)), ("webpage", ConstructorParameterDescription(self.webpage))])
            }
        }
        case messageMediaContact(Cons_messageMediaContact)
        case messageMediaDice(Cons_messageMediaDice)
        case messageMediaDocument(Cons_messageMediaDocument)
        case messageMediaEmpty
        case messageMediaGame(Cons_messageMediaGame)
        case messageMediaGeo(Cons_messageMediaGeo)
        case messageMediaGeoLive(Cons_messageMediaGeoLive)
        case messageMediaGiveaway(Cons_messageMediaGiveaway)
        case messageMediaGiveawayResults(Cons_messageMediaGiveawayResults)
        case messageMediaInvoice(Cons_messageMediaInvoice)
        case messageMediaPaidMedia(Cons_messageMediaPaidMedia)
        case messageMediaPhoto(Cons_messageMediaPhoto)
        case messageMediaPoll(Cons_messageMediaPoll)
        case messageMediaStory(Cons_messageMediaStory)
        case messageMediaToDo(Cons_messageMediaToDo)
        case messageMediaUnsupported
        case messageMediaVenue(Cons_messageMediaVenue)
        case messageMediaVideoStream(Cons_messageMediaVideoStream)
        case messageMediaWebPage(Cons_messageMediaWebPage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageMediaContact(let _data):
                if boxed {
                    buffer.appendInt32(1882335561)
                }
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.firstName, buffer: buffer, boxed: false)
                serializeString(_data.lastName, buffer: buffer, boxed: false)
                serializeString(_data.vcard, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .messageMediaDice(let _data):
                if boxed {
                    buffer.appendInt32(147581959)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.value, buffer: buffer, boxed: false)
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.gameOutcome!.serialize(buffer, true)
                }
                break
            case .messageMediaDocument(let _data):
                if boxed {
                    buffer.appendInt32(1389939929)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.altDocuments!.count))
                    for item in _data.altDocuments! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.videoCover!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.videoTimestamp!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                break
            case .messageMediaEmpty:
                if boxed {
                    buffer.appendInt32(1038967584)
                }
                break
            case .messageMediaGame(let _data):
                if boxed {
                    buffer.appendInt32(-38694904)
                }
                _data.game.serialize(buffer, true)
                break
            case .messageMediaGeo(let _data):
                if boxed {
                    buffer.appendInt32(1457575028)
                }
                _data.geo.serialize(buffer, true)
                break
            case .messageMediaGeoLive(let _data):
                if boxed {
                    buffer.appendInt32(-1186937242)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.geo.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.heading!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.period, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.proximityNotificationRadius!, buffer: buffer, boxed: false)
                }
                break
            case .messageMediaGiveaway(let _data):
                if boxed {
                    buffer.appendInt32(-1442366485)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.channels.count))
                for item in _data.channels {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.countriesIso2!.count))
                    for item in _data.countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.prizeDescription!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.quantity, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.months!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt64(_data.stars!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                break
            case .messageMediaGiveawayResults(let _data):
                if boxed {
                    buffer.appendInt32(-827703647)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.additionalPeersCount!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.launchMsgId, buffer: buffer, boxed: false)
                serializeInt32(_data.winnersCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unclaimedCount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.winners.count))
                for item in _data.winners {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.months!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt64(_data.stars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.prizeDescription!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                break
            case .messageMediaInvoice(let _data):
                if boxed {
                    buffer.appendInt32(-156940077)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.receiptMsgId!, buffer: buffer, boxed: false)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                serializeString(_data.startParam, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.extendedMedia!.serialize(buffer, true)
                }
                break
            case .messageMediaPaidMedia(let _data):
                if boxed {
                    buffer.appendInt32(-1467669359)
                }
                serializeInt64(_data.starsAmount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.extendedMedia.count))
                for item in _data.extendedMedia {
                    item.serialize(buffer, true)
                }
                break
            case .messageMediaPhoto(let _data):
                if boxed {
                    buffer.appendInt32(-501814429)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.video!.serialize(buffer, true)
                }
                break
            case .messageMediaPoll(let _data):
                if boxed {
                    buffer.appendInt32(2000637542)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.poll.serialize(buffer, true)
                _data.results.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.attachedMedia!.serialize(buffer, true)
                }
                break
            case .messageMediaStory(let _data):
                if boxed {
                    buffer.appendInt32(1758159491)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.story!.serialize(buffer, true)
                }
                break
            case .messageMediaToDo(let _data):
                if boxed {
                    buffer.appendInt32(-1974226924)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.todo.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.completions!.count))
                    for item in _data.completions! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .messageMediaUnsupported:
                if boxed {
                    buffer.appendInt32(-1618676578)
                }
                break
            case .messageMediaVenue(let _data):
                if boxed {
                    buffer.appendInt32(784356159)
                }
                _data.geo.serialize(buffer, true)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeString(_data.provider, buffer: buffer, boxed: false)
                serializeString(_data.venueId, buffer: buffer, boxed: false)
                serializeString(_data.venueType, buffer: buffer, boxed: false)
                break
            case .messageMediaVideoStream(let _data):
                if boxed {
                    buffer.appendInt32(-899896439)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.call.serialize(buffer, true)
                break
            case .messageMediaWebPage(let _data):
                if boxed {
                    buffer.appendInt32(-571405253)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.webpage.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .messageMediaContact(let _data):
                return ("messageMediaContact", [("phoneNumber", ConstructorParameterDescription(_data.phoneNumber)), ("firstName", ConstructorParameterDescription(_data.firstName)), ("lastName", ConstructorParameterDescription(_data.lastName)), ("vcard", ConstructorParameterDescription(_data.vcard)), ("userId", ConstructorParameterDescription(_data.userId))])
            case .messageMediaDice(let _data):
                return ("messageMediaDice", [("flags", ConstructorParameterDescription(_data.flags)), ("value", ConstructorParameterDescription(_data.value)), ("emoticon", ConstructorParameterDescription(_data.emoticon)), ("gameOutcome", ConstructorParameterDescription(_data.gameOutcome))])
            case .messageMediaDocument(let _data):
                return ("messageMediaDocument", [("flags", ConstructorParameterDescription(_data.flags)), ("document", ConstructorParameterDescription(_data.document)), ("altDocuments", ConstructorParameterDescription(_data.altDocuments)), ("videoCover", ConstructorParameterDescription(_data.videoCover)), ("videoTimestamp", ConstructorParameterDescription(_data.videoTimestamp)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds))])
            case .messageMediaEmpty:
                return ("messageMediaEmpty", [])
            case .messageMediaGame(let _data):
                return ("messageMediaGame", [("game", ConstructorParameterDescription(_data.game))])
            case .messageMediaGeo(let _data):
                return ("messageMediaGeo", [("geo", ConstructorParameterDescription(_data.geo))])
            case .messageMediaGeoLive(let _data):
                return ("messageMediaGeoLive", [("flags", ConstructorParameterDescription(_data.flags)), ("geo", ConstructorParameterDescription(_data.geo)), ("heading", ConstructorParameterDescription(_data.heading)), ("period", ConstructorParameterDescription(_data.period)), ("proximityNotificationRadius", ConstructorParameterDescription(_data.proximityNotificationRadius))])
            case .messageMediaGiveaway(let _data):
                return ("messageMediaGiveaway", [("flags", ConstructorParameterDescription(_data.flags)), ("channels", ConstructorParameterDescription(_data.channels)), ("countriesIso2", ConstructorParameterDescription(_data.countriesIso2)), ("prizeDescription", ConstructorParameterDescription(_data.prizeDescription)), ("quantity", ConstructorParameterDescription(_data.quantity)), ("months", ConstructorParameterDescription(_data.months)), ("stars", ConstructorParameterDescription(_data.stars)), ("untilDate", ConstructorParameterDescription(_data.untilDate))])
            case .messageMediaGiveawayResults(let _data):
                return ("messageMediaGiveawayResults", [("flags", ConstructorParameterDescription(_data.flags)), ("channelId", ConstructorParameterDescription(_data.channelId)), ("additionalPeersCount", ConstructorParameterDescription(_data.additionalPeersCount)), ("launchMsgId", ConstructorParameterDescription(_data.launchMsgId)), ("winnersCount", ConstructorParameterDescription(_data.winnersCount)), ("unclaimedCount", ConstructorParameterDescription(_data.unclaimedCount)), ("winners", ConstructorParameterDescription(_data.winners)), ("months", ConstructorParameterDescription(_data.months)), ("stars", ConstructorParameterDescription(_data.stars)), ("prizeDescription", ConstructorParameterDescription(_data.prizeDescription)), ("untilDate", ConstructorParameterDescription(_data.untilDate))])
            case .messageMediaInvoice(let _data):
                return ("messageMediaInvoice", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("description", ConstructorParameterDescription(_data.description)), ("photo", ConstructorParameterDescription(_data.photo)), ("receiptMsgId", ConstructorParameterDescription(_data.receiptMsgId)), ("currency", ConstructorParameterDescription(_data.currency)), ("totalAmount", ConstructorParameterDescription(_data.totalAmount)), ("startParam", ConstructorParameterDescription(_data.startParam)), ("extendedMedia", ConstructorParameterDescription(_data.extendedMedia))])
            case .messageMediaPaidMedia(let _data):
                return ("messageMediaPaidMedia", [("starsAmount", ConstructorParameterDescription(_data.starsAmount)), ("extendedMedia", ConstructorParameterDescription(_data.extendedMedia))])
            case .messageMediaPhoto(let _data):
                return ("messageMediaPhoto", [("flags", ConstructorParameterDescription(_data.flags)), ("photo", ConstructorParameterDescription(_data.photo)), ("ttlSeconds", ConstructorParameterDescription(_data.ttlSeconds)), ("video", ConstructorParameterDescription(_data.video))])
            case .messageMediaPoll(let _data):
                return ("messageMediaPoll", [("flags", ConstructorParameterDescription(_data.flags)), ("poll", ConstructorParameterDescription(_data.poll)), ("results", ConstructorParameterDescription(_data.results)), ("attachedMedia", ConstructorParameterDescription(_data.attachedMedia))])
            case .messageMediaStory(let _data):
                return ("messageMediaStory", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("id", ConstructorParameterDescription(_data.id)), ("story", ConstructorParameterDescription(_data.story))])
            case .messageMediaToDo(let _data):
                return ("messageMediaToDo", [("flags", ConstructorParameterDescription(_data.flags)), ("todo", ConstructorParameterDescription(_data.todo)), ("completions", ConstructorParameterDescription(_data.completions))])
            case .messageMediaUnsupported:
                return ("messageMediaUnsupported", [])
            case .messageMediaVenue(let _data):
                return ("messageMediaVenue", [("geo", ConstructorParameterDescription(_data.geo)), ("title", ConstructorParameterDescription(_data.title)), ("address", ConstructorParameterDescription(_data.address)), ("provider", ConstructorParameterDescription(_data.provider)), ("venueId", ConstructorParameterDescription(_data.venueId)), ("venueType", ConstructorParameterDescription(_data.venueType))])
            case .messageMediaVideoStream(let _data):
                return ("messageMediaVideoStream", [("flags", ConstructorParameterDescription(_data.flags)), ("call", ConstructorParameterDescription(_data.call))])
            case .messageMediaWebPage(let _data):
                return ("messageMediaWebPage", [("flags", ConstructorParameterDescription(_data.flags)), ("webpage", ConstructorParameterDescription(_data.webpage))])
            }
        }

        public static func parse_messageMediaContact(_ reader: BufferReader) -> MessageMedia? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageMedia.messageMediaContact(Cons_messageMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, vcard: _4!, userId: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaDice(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.messages.EmojiGameOutcome?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.messages.EmojiGameOutcome
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageMedia.messageMediaDice(Cons_messageMediaDice(flags: _1!, value: _2!, emoticon: _3!, gameOutcome: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaDocument(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _3: [Api.Document]?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
                }
            }
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 5) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 9) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 10) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MessageMedia.messageMediaDocument(Cons_messageMediaDocument(flags: _1!, document: _2, altDocuments: _3, videoCover: _4, videoTimestamp: _5, ttlSeconds: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaEmpty(_ reader: BufferReader) -> MessageMedia? {
            return Api.MessageMedia.messageMediaEmpty
        }
        public static func parse_messageMediaGame(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.Game?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Game
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageMedia.messageMediaGame(Cons_messageMediaGame(game: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaGeo(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageMedia.messageMediaGeo(Cons_messageMediaGeo(geo: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaGeoLive(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageMedia.messageMediaGeoLive(Cons_messageMediaGeoLive(flags: _1!, geo: _2!, heading: _3, period: _4!, proximityNotificationRadius: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaGiveaway(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            var _3: [String]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            var _4: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int64?
            if Int(_1!) & Int(1 << 5) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Int32?
            _8 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.MessageMedia.messageMediaGiveaway(Cons_messageMediaGiveaway(flags: _1!, channels: _2!, countriesIso2: _3, prizeDescription: _4, quantity: _5!, months: _6, stars: _7, untilDate: _8!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaGiveawayResults(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: [Int64]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 5) != 0 {
                _9 = reader.readInt64()
            }
            var _10: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _10 = parseString(reader)
            }
            var _11: Int32?
            _11 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.MessageMedia.messageMediaGiveawayResults(Cons_messageMediaGiveawayResults(flags: _1!, channelId: _2!, additionalPeersCount: _3, launchMsgId: _4!, winnersCount: _5!, unclaimedCount: _6!, winners: _7!, months: _8, stars: _9, prizeDescription: _10, untilDate: _11!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaInvoice(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.WebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = reader.readInt32()
            }
            var _6: String?
            _6 = parseString(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: String?
            _8 = parseString(reader)
            var _9: Api.MessageExtendedMedia?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.MessageExtendedMedia
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.MessageMedia.messageMediaInvoice(Cons_messageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, receiptMsgId: _5, currency: _6!, totalAmount: _7!, startParam: _8!, extendedMedia: _9))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaPaidMedia(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.MessageExtendedMedia]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageExtendedMedia.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageMedia.messageMediaPaidMedia(Cons_messageMediaPaidMedia(starsAmount: _1!, extendedMedia: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaPhoto(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Photo?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.Document?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageMedia.messageMediaPhoto(Cons_messageMediaPhoto(flags: _1!, photo: _2, ttlSeconds: _3, video: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaPoll(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Poll?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Poll
            }
            var _3: Api.PollResults?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PollResults
            }
            var _4: Api.MessageMedia?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.MessageMedia
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageMedia.messageMediaPoll(Cons_messageMediaPoll(flags: _1!, poll: _2!, results: _3!, attachedMedia: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaStory(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.StoryItem?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.StoryItem
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageMedia.messageMediaStory(Cons_messageMediaStory(flags: _1!, peer: _2!, id: _3!, story: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaToDo(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.TodoList?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TodoList
            }
            var _3: [Api.TodoCompletion]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TodoCompletion.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageMedia.messageMediaToDo(Cons_messageMediaToDo(flags: _1!, todo: _2!, completions: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaUnsupported(_ reader: BufferReader) -> MessageMedia? {
            return Api.MessageMedia.messageMediaUnsupported
        }
        public static func parse_messageMediaVenue(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MessageMedia.messageMediaVenue(Cons_messageMediaVenue(geo: _1!, title: _2!, address: _3!, provider: _4!, venueId: _5!, venueType: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaVideoStream(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageMedia.messageMediaVideoStream(Cons_messageMediaVideoStream(flags: _1!, call: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaWebPage(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.WebPage?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageMedia.messageMediaWebPage(Cons_messageMediaWebPage(flags: _1!, webpage: _2!))
            }
            else {
                return nil
            }
        }
    }
}
