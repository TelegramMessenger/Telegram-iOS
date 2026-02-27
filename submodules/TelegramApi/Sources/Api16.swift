public extension Api {
    indirect enum MessageEntity: TypeConstructorDescription {
        public class Cons_inputMessageEntityMentionName {
            public var offset: Int32
            public var length: Int32
            public var userId: Api.InputUser
            public init(offset: Int32, length: Int32, userId: Api.InputUser) {
                self.offset = offset
                self.length = length
                self.userId = userId
            }
        }
        public class Cons_messageEntityBankCard {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityBlockquote {
            public var flags: Int32
            public var offset: Int32
            public var length: Int32
            public init(flags: Int32, offset: Int32, length: Int32) {
                self.flags = flags
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityBold {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityBotCommand {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityCashtag {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityCode {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityCustomEmoji {
            public var offset: Int32
            public var length: Int32
            public var documentId: Int64
            public init(offset: Int32, length: Int32, documentId: Int64) {
                self.offset = offset
                self.length = length
                self.documentId = documentId
            }
        }
        public class Cons_messageEntityEmail {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityHashtag {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityItalic {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityMention {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityMentionName {
            public var offset: Int32
            public var length: Int32
            public var userId: Int64
            public init(offset: Int32, length: Int32, userId: Int64) {
                self.offset = offset
                self.length = length
                self.userId = userId
            }
        }
        public class Cons_messageEntityPhone {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityPre {
            public var offset: Int32
            public var length: Int32
            public var language: String
            public init(offset: Int32, length: Int32, language: String) {
                self.offset = offset
                self.length = length
                self.language = language
            }
        }
        public class Cons_messageEntitySpoiler {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityStrike {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityTextUrl {
            public var offset: Int32
            public var length: Int32
            public var url: String
            public init(offset: Int32, length: Int32, url: String) {
                self.offset = offset
                self.length = length
                self.url = url
            }
        }
        public class Cons_messageEntityUnderline {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityUnknown {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityUrl {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
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
        case messageEntityEmail(Cons_messageEntityEmail)
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
            case .messageEntityEmail(let _data):
                if boxed {
                    buffer.appendInt32(1692693954)
                }
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputMessageEntityMentionName(let _data):
                return ("inputMessageEntityMentionName", [("offset", _data.offset as Any), ("length", _data.length as Any), ("userId", _data.userId as Any)])
            case .messageEntityBankCard(let _data):
                return ("messageEntityBankCard", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityBlockquote(let _data):
                return ("messageEntityBlockquote", [("flags", _data.flags as Any), ("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityBold(let _data):
                return ("messageEntityBold", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityBotCommand(let _data):
                return ("messageEntityBotCommand", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityCashtag(let _data):
                return ("messageEntityCashtag", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityCode(let _data):
                return ("messageEntityCode", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityCustomEmoji(let _data):
                return ("messageEntityCustomEmoji", [("offset", _data.offset as Any), ("length", _data.length as Any), ("documentId", _data.documentId as Any)])
            case .messageEntityEmail(let _data):
                return ("messageEntityEmail", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityHashtag(let _data):
                return ("messageEntityHashtag", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityItalic(let _data):
                return ("messageEntityItalic", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityMention(let _data):
                return ("messageEntityMention", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityMentionName(let _data):
                return ("messageEntityMentionName", [("offset", _data.offset as Any), ("length", _data.length as Any), ("userId", _data.userId as Any)])
            case .messageEntityPhone(let _data):
                return ("messageEntityPhone", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityPre(let _data):
                return ("messageEntityPre", [("offset", _data.offset as Any), ("length", _data.length as Any), ("language", _data.language as Any)])
            case .messageEntitySpoiler(let _data):
                return ("messageEntitySpoiler", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityStrike(let _data):
                return ("messageEntityStrike", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityTextUrl(let _data):
                return ("messageEntityTextUrl", [("offset", _data.offset as Any), ("length", _data.length as Any), ("url", _data.url as Any)])
            case .messageEntityUnderline(let _data):
                return ("messageEntityUnderline", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityUnknown(let _data):
                return ("messageEntityUnknown", [("offset", _data.offset as Any), ("length", _data.length as Any)])
            case .messageEntityUrl(let _data):
                return ("messageEntityUrl", [("offset", _data.offset as Any), ("length", _data.length as Any)])
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
        public class Cons_messageExtendedMedia {
            public var media: Api.MessageMedia
            public init(media: Api.MessageMedia) {
                self.media = media
            }
        }
        public class Cons_messageExtendedMediaPreview {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageExtendedMedia(let _data):
                return ("messageExtendedMedia", [("media", _data.media as Any)])
            case .messageExtendedMediaPreview(let _data):
                return ("messageExtendedMediaPreview", [("flags", _data.flags as Any), ("w", _data.w as Any), ("h", _data.h as Any), ("thumb", _data.thumb as Any), ("videoDuration", _data.videoDuration as Any)])
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
        public class Cons_messageFwdHeader {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageFwdHeader(let _data):
                return ("messageFwdHeader", [("flags", _data.flags as Any), ("fromId", _data.fromId as Any), ("fromName", _data.fromName as Any), ("date", _data.date as Any), ("channelPost", _data.channelPost as Any), ("postAuthor", _data.postAuthor as Any), ("savedFromPeer", _data.savedFromPeer as Any), ("savedFromMsgId", _data.savedFromMsgId as Any), ("savedFromId", _data.savedFromId as Any), ("savedFromName", _data.savedFromName as Any), ("savedDate", _data.savedDate as Any), ("psaType", _data.psaType as Any)])
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
        public class Cons_messageMediaContact {
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
        }
        public class Cons_messageMediaDice {
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
        }
        public class Cons_messageMediaDocument {
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
        }
        public class Cons_messageMediaGame {
            public var game: Api.Game
            public init(game: Api.Game) {
                self.game = game
            }
        }
        public class Cons_messageMediaGeo {
            public var geo: Api.GeoPoint
            public init(geo: Api.GeoPoint) {
                self.geo = geo
            }
        }
        public class Cons_messageMediaGeoLive {
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
        }
        public class Cons_messageMediaGiveaway {
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
        }
        public class Cons_messageMediaGiveawayResults {
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
        }
        public class Cons_messageMediaInvoice {
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
        }
        public class Cons_messageMediaPaidMedia {
            public var starsAmount: Int64
            public var extendedMedia: [Api.MessageExtendedMedia]
            public init(starsAmount: Int64, extendedMedia: [Api.MessageExtendedMedia]) {
                self.starsAmount = starsAmount
                self.extendedMedia = extendedMedia
            }
        }
        public class Cons_messageMediaPhoto {
            public var flags: Int32
            public var photo: Api.Photo?
            public var ttlSeconds: Int32?
            public init(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?) {
                self.flags = flags
                self.photo = photo
                self.ttlSeconds = ttlSeconds
            }
        }
        public class Cons_messageMediaPoll {
            public var poll: Api.Poll
            public var results: Api.PollResults
            public init(poll: Api.Poll, results: Api.PollResults) {
                self.poll = poll
                self.results = results
            }
        }
        public class Cons_messageMediaStory {
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
        }
        public class Cons_messageMediaToDo {
            public var flags: Int32
            public var todo: Api.TodoList
            public var completions: [Api.TodoCompletion]?
            public init(flags: Int32, todo: Api.TodoList, completions: [Api.TodoCompletion]?) {
                self.flags = flags
                self.todo = todo
                self.completions = completions
            }
        }
        public class Cons_messageMediaVenue {
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
        }
        public class Cons_messageMediaVideoStream {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public init(flags: Int32, call: Api.InputGroupCall) {
                self.flags = flags
                self.call = call
            }
        }
        public class Cons_messageMediaWebPage {
            public var flags: Int32
            public var webpage: Api.WebPage
            public init(flags: Int32, webpage: Api.WebPage) {
                self.flags = flags
                self.webpage = webpage
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
                    buffer.appendInt32(1766936791)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.ttlSeconds!, buffer: buffer, boxed: false)
                }
                break
            case .messageMediaPoll(let _data):
                if boxed {
                    buffer.appendInt32(1272375192)
                }
                _data.poll.serialize(buffer, true)
                _data.results.serialize(buffer, true)
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageMediaContact(let _data):
                return ("messageMediaContact", [("phoneNumber", _data.phoneNumber as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("vcard", _data.vcard as Any), ("userId", _data.userId as Any)])
            case .messageMediaDice(let _data):
                return ("messageMediaDice", [("flags", _data.flags as Any), ("value", _data.value as Any), ("emoticon", _data.emoticon as Any), ("gameOutcome", _data.gameOutcome as Any)])
            case .messageMediaDocument(let _data):
                return ("messageMediaDocument", [("flags", _data.flags as Any), ("document", _data.document as Any), ("altDocuments", _data.altDocuments as Any), ("videoCover", _data.videoCover as Any), ("videoTimestamp", _data.videoTimestamp as Any), ("ttlSeconds", _data.ttlSeconds as Any)])
            case .messageMediaEmpty:
                return ("messageMediaEmpty", [])
            case .messageMediaGame(let _data):
                return ("messageMediaGame", [("game", _data.game as Any)])
            case .messageMediaGeo(let _data):
                return ("messageMediaGeo", [("geo", _data.geo as Any)])
            case .messageMediaGeoLive(let _data):
                return ("messageMediaGeoLive", [("flags", _data.flags as Any), ("geo", _data.geo as Any), ("heading", _data.heading as Any), ("period", _data.period as Any), ("proximityNotificationRadius", _data.proximityNotificationRadius as Any)])
            case .messageMediaGiveaway(let _data):
                return ("messageMediaGiveaway", [("flags", _data.flags as Any), ("channels", _data.channels as Any), ("countriesIso2", _data.countriesIso2 as Any), ("prizeDescription", _data.prizeDescription as Any), ("quantity", _data.quantity as Any), ("months", _data.months as Any), ("stars", _data.stars as Any), ("untilDate", _data.untilDate as Any)])
            case .messageMediaGiveawayResults(let _data):
                return ("messageMediaGiveawayResults", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("additionalPeersCount", _data.additionalPeersCount as Any), ("launchMsgId", _data.launchMsgId as Any), ("winnersCount", _data.winnersCount as Any), ("unclaimedCount", _data.unclaimedCount as Any), ("winners", _data.winners as Any), ("months", _data.months as Any), ("stars", _data.stars as Any), ("prizeDescription", _data.prizeDescription as Any), ("untilDate", _data.untilDate as Any)])
            case .messageMediaInvoice(let _data):
                return ("messageMediaInvoice", [("flags", _data.flags as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("receiptMsgId", _data.receiptMsgId as Any), ("currency", _data.currency as Any), ("totalAmount", _data.totalAmount as Any), ("startParam", _data.startParam as Any), ("extendedMedia", _data.extendedMedia as Any)])
            case .messageMediaPaidMedia(let _data):
                return ("messageMediaPaidMedia", [("starsAmount", _data.starsAmount as Any), ("extendedMedia", _data.extendedMedia as Any)])
            case .messageMediaPhoto(let _data):
                return ("messageMediaPhoto", [("flags", _data.flags as Any), ("photo", _data.photo as Any), ("ttlSeconds", _data.ttlSeconds as Any)])
            case .messageMediaPoll(let _data):
                return ("messageMediaPoll", [("poll", _data.poll as Any), ("results", _data.results as Any)])
            case .messageMediaStory(let _data):
                return ("messageMediaStory", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("id", _data.id as Any), ("story", _data.story as Any)])
            case .messageMediaToDo(let _data):
                return ("messageMediaToDo", [("flags", _data.flags as Any), ("todo", _data.todo as Any), ("completions", _data.completions as Any)])
            case .messageMediaUnsupported:
                return ("messageMediaUnsupported", [])
            case .messageMediaVenue(let _data):
                return ("messageMediaVenue", [("geo", _data.geo as Any), ("title", _data.title as Any), ("address", _data.address as Any), ("provider", _data.provider as Any), ("venueId", _data.venueId as Any), ("venueType", _data.venueType as Any)])
            case .messageMediaVideoStream(let _data):
                return ("messageMediaVideoStream", [("flags", _data.flags as Any), ("call", _data.call as Any)])
            case .messageMediaWebPage(let _data):
                return ("messageMediaWebPage", [("flags", _data.flags as Any), ("webpage", _data.webpage as Any)])
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
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageMedia.messageMediaPhoto(Cons_messageMediaPhoto(flags: _1!, photo: _2, ttlSeconds: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaPoll(_ reader: BufferReader) -> MessageMedia? {
            var _1: Api.Poll?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Poll
            }
            var _2: Api.PollResults?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PollResults
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageMedia.messageMediaPoll(Cons_messageMediaPoll(poll: _1!, results: _2!))
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
