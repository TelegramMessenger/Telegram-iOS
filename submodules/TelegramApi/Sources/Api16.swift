public extension Api {
    indirect enum MessageEntity: TypeConstructorDescription {
        case inputMessageEntityMentionName(offset: Int32, length: Int32, userId: Api.InputUser)
        case messageEntityBankCard(offset: Int32, length: Int32)
        case messageEntityBlockquote(flags: Int32, offset: Int32, length: Int32)
        case messageEntityBold(offset: Int32, length: Int32)
        case messageEntityBotCommand(offset: Int32, length: Int32)
        case messageEntityCashtag(offset: Int32, length: Int32)
        case messageEntityCode(offset: Int32, length: Int32)
        case messageEntityCustomEmoji(offset: Int32, length: Int32, documentId: Int64)
        case messageEntityEmail(offset: Int32, length: Int32)
        case messageEntityHashtag(offset: Int32, length: Int32)
        case messageEntityItalic(offset: Int32, length: Int32)
        case messageEntityMention(offset: Int32, length: Int32)
        case messageEntityMentionName(offset: Int32, length: Int32, userId: Int64)
        case messageEntityPhone(offset: Int32, length: Int32)
        case messageEntityPre(offset: Int32, length: Int32, language: String)
        case messageEntitySpoiler(offset: Int32, length: Int32)
        case messageEntityStrike(offset: Int32, length: Int32)
        case messageEntityTextUrl(offset: Int32, length: Int32, url: String)
        case messageEntityUnderline(offset: Int32, length: Int32)
        case messageEntityUnknown(offset: Int32, length: Int32)
        case messageEntityUrl(offset: Int32, length: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMessageEntityMentionName(let offset, let length, let userId):
                    if boxed {
                        buffer.appendInt32(546203849)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    break
                case .messageEntityBankCard(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1981704948)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBlockquote(let flags, let offset, let length):
                    if boxed {
                        buffer.appendInt32(-238245204)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBold(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1117713463)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBotCommand(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1827637959)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityCashtag(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1280209983)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityCode(let offset, let length):
                    if boxed {
                        buffer.appendInt32(681706865)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityCustomEmoji(let offset, let length, let documentId):
                    if boxed {
                        buffer.appendInt32(-925956616)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    break
                case .messageEntityEmail(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1692693954)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityHashtag(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1868782349)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityItalic(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-2106619040)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityMention(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-100378723)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityMentionName(let offset, let length, let userId):
                    if boxed {
                        buffer.appendInt32(-595914432)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .messageEntityPhone(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1687559349)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityPre(let offset, let length, let language):
                    if boxed {
                        buffer.appendInt32(1938967520)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeString(language, buffer: buffer, boxed: false)
                    break
                case .messageEntitySpoiler(let offset, let length):
                    if boxed {
                        buffer.appendInt32(852137487)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityStrike(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1090087980)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityTextUrl(let offset, let length, let url):
                    if boxed {
                        buffer.appendInt32(1990644519)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .messageEntityUnderline(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1672577397)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityUnknown(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1148011883)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityUrl(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1859134776)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMessageEntityMentionName(let offset, let length, let userId):
                return ("inputMessageEntityMentionName", [("offset", offset as Any), ("length", length as Any), ("userId", userId as Any)])
                case .messageEntityBankCard(let offset, let length):
                return ("messageEntityBankCard", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityBlockquote(let flags, let offset, let length):
                return ("messageEntityBlockquote", [("flags", flags as Any), ("offset", offset as Any), ("length", length as Any)])
                case .messageEntityBold(let offset, let length):
                return ("messageEntityBold", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityBotCommand(let offset, let length):
                return ("messageEntityBotCommand", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityCashtag(let offset, let length):
                return ("messageEntityCashtag", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityCode(let offset, let length):
                return ("messageEntityCode", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityCustomEmoji(let offset, let length, let documentId):
                return ("messageEntityCustomEmoji", [("offset", offset as Any), ("length", length as Any), ("documentId", documentId as Any)])
                case .messageEntityEmail(let offset, let length):
                return ("messageEntityEmail", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityHashtag(let offset, let length):
                return ("messageEntityHashtag", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityItalic(let offset, let length):
                return ("messageEntityItalic", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityMention(let offset, let length):
                return ("messageEntityMention", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityMentionName(let offset, let length, let userId):
                return ("messageEntityMentionName", [("offset", offset as Any), ("length", length as Any), ("userId", userId as Any)])
                case .messageEntityPhone(let offset, let length):
                return ("messageEntityPhone", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityPre(let offset, let length, let language):
                return ("messageEntityPre", [("offset", offset as Any), ("length", length as Any), ("language", language as Any)])
                case .messageEntitySpoiler(let offset, let length):
                return ("messageEntitySpoiler", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityStrike(let offset, let length):
                return ("messageEntityStrike", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityTextUrl(let offset, let length, let url):
                return ("messageEntityTextUrl", [("offset", offset as Any), ("length", length as Any), ("url", url as Any)])
                case .messageEntityUnderline(let offset, let length):
                return ("messageEntityUnderline", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityUnknown(let offset, let length):
                return ("messageEntityUnknown", [("offset", offset as Any), ("length", length as Any)])
                case .messageEntityUrl(let offset, let length):
                return ("messageEntityUrl", [("offset", offset as Any), ("length", length as Any)])
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
                return Api.MessageEntity.inputMessageEntityMentionName(offset: _1!, length: _2!, userId: _3!)
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
                return Api.MessageEntity.messageEntityBankCard(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityBlockquote(flags: _1!, offset: _2!, length: _3!)
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
                return Api.MessageEntity.messageEntityBold(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityBotCommand(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityCashtag(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityCode(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityCustomEmoji(offset: _1!, length: _2!, documentId: _3!)
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
                return Api.MessageEntity.messageEntityEmail(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityHashtag(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityItalic(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityMention(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityMentionName(offset: _1!, length: _2!, userId: _3!)
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
                return Api.MessageEntity.messageEntityPhone(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityPre(offset: _1!, length: _2!, language: _3!)
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
                return Api.MessageEntity.messageEntitySpoiler(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityStrike(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityTextUrl(offset: _1!, length: _2!, url: _3!)
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
                return Api.MessageEntity.messageEntityUnderline(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityUnknown(offset: _1!, length: _2!)
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
                return Api.MessageEntity.messageEntityUrl(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum MessageExtendedMedia: TypeConstructorDescription {
        case messageExtendedMedia(media: Api.MessageMedia)
        case messageExtendedMediaPreview(flags: Int32, w: Int32?, h: Int32?, thumb: Api.PhotoSize?, videoDuration: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageExtendedMedia(let media):
                    if boxed {
                        buffer.appendInt32(-297296796)
                    }
                    media.serialize(buffer, true)
                    break
                case .messageExtendedMediaPreview(let flags, let w, let h, let thumb, let videoDuration):
                    if boxed {
                        buffer.appendInt32(-1386050360)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(w!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(h!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {thumb!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(videoDuration!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageExtendedMedia(let media):
                return ("messageExtendedMedia", [("media", media as Any)])
                case .messageExtendedMediaPreview(let flags, let w, let h, let thumb, let videoDuration):
                return ("messageExtendedMediaPreview", [("flags", flags as Any), ("w", w as Any), ("h", h as Any), ("thumb", thumb as Any), ("videoDuration", videoDuration as Any)])
    }
    }
    
        public static func parse_messageExtendedMedia(_ reader: BufferReader) -> MessageExtendedMedia? {
            var _1: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageExtendedMedia.messageExtendedMedia(media: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageExtendedMediaPreview(_ reader: BufferReader) -> MessageExtendedMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Api.PhotoSize?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PhotoSize
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageExtendedMedia.messageExtendedMediaPreview(flags: _1!, w: _2, h: _3, thumb: _4, videoDuration: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageFwdHeader: TypeConstructorDescription {
        case messageFwdHeader(flags: Int32, fromId: Api.Peer?, fromName: String?, date: Int32, channelPost: Int32?, postAuthor: String?, savedFromPeer: Api.Peer?, savedFromMsgId: Int32?, savedFromId: Api.Peer?, savedFromName: String?, savedDate: Int32?, psaType: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageFwdHeader(let flags, let fromId, let fromName, let date, let channelPost, let postAuthor, let savedFromPeer, let savedFromMsgId, let savedFromId, let savedFromName, let savedDate, let psaType):
                    if boxed {
                        buffer.appendInt32(1313731771)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(fromName!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(channelPost!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(postAuthor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {savedFromPeer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(savedFromMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {savedFromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeString(savedFromName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(savedDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(psaType!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageFwdHeader(let flags, let fromId, let fromName, let date, let channelPost, let postAuthor, let savedFromPeer, let savedFromMsgId, let savedFromId, let savedFromName, let savedDate, let psaType):
                return ("messageFwdHeader", [("flags", flags as Any), ("fromId", fromId as Any), ("fromName", fromName as Any), ("date", date as Any), ("channelPost", channelPost as Any), ("postAuthor", postAuthor as Any), ("savedFromPeer", savedFromPeer as Any), ("savedFromMsgId", savedFromMsgId as Any), ("savedFromId", savedFromId as Any), ("savedFromName", savedFromName as Any), ("savedDate", savedDate as Any), ("psaType", psaType as Any)])
    }
    }
    
        public static func parse_messageFwdHeader(_ reader: BufferReader) -> MessageFwdHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _3: String?
            if Int(_1!) & Int(1 << 5) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: Api.Peer?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_8 = reader.readInt32() }
            var _9: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _10: String?
            if Int(_1!) & Int(1 << 9) != 0 {_10 = parseString(reader) }
            var _11: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_11 = reader.readInt32() }
            var _12: String?
            if Int(_1!) & Int(1 << 6) != 0 {_12 = parseString(reader) }
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
                return Api.MessageFwdHeader.messageFwdHeader(flags: _1!, fromId: _2, fromName: _3, date: _4!, channelPost: _5, postAuthor: _6, savedFromPeer: _7, savedFromMsgId: _8, savedFromId: _9, savedFromName: _10, savedDate: _11, psaType: _12)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum MessageMedia: TypeConstructorDescription {
        case messageMediaContact(phoneNumber: String, firstName: String, lastName: String, vcard: String, userId: Int64)
        case messageMediaDice(value: Int32, emoticon: String)
        case messageMediaDocument(flags: Int32, document: Api.Document?, altDocuments: [Api.Document]?, videoCover: Api.Photo?, videoTimestamp: Int32?, ttlSeconds: Int32?)
        case messageMediaEmpty
        case messageMediaGame(game: Api.Game)
        case messageMediaGeo(geo: Api.GeoPoint)
        case messageMediaGeoLive(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32, proximityNotificationRadius: Int32?)
        case messageMediaGiveaway(flags: Int32, channels: [Int64], countriesIso2: [String]?, prizeDescription: String?, quantity: Int32, months: Int32?, stars: Int64?, untilDate: Int32)
        case messageMediaGiveawayResults(flags: Int32, channelId: Int64, additionalPeersCount: Int32?, launchMsgId: Int32, winnersCount: Int32, unclaimedCount: Int32, winners: [Int64], months: Int32?, stars: Int64?, prizeDescription: String?, untilDate: Int32)
        case messageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String, extendedMedia: Api.MessageExtendedMedia?)
        case messageMediaPaidMedia(starsAmount: Int64, extendedMedia: [Api.MessageExtendedMedia])
        case messageMediaPhoto(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?)
        case messageMediaPoll(poll: Api.Poll, results: Api.PollResults)
        case messageMediaStory(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?)
        case messageMediaToDo(flags: Int32, todo: Api.TodoList, completions: [Api.TodoCompletion]?)
        case messageMediaUnsupported
        case messageMediaVenue(geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case messageMediaWebPage(flags: Int32, webpage: Api.WebPage)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageMediaContact(let phoneNumber, let firstName, let lastName, let vcard, let userId):
                    if boxed {
                        buffer.appendInt32(1882335561)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .messageMediaDice(let value, let emoticon):
                    if boxed {
                        buffer.appendInt32(1065280907)
                    }
                    serializeInt32(value, buffer: buffer, boxed: false)
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .messageMediaDocument(let flags, let document, let altDocuments, let videoCover, let videoTimestamp, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(1389939929)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(altDocuments!.count))
                    for item in altDocuments! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 9) != 0 {videoCover!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(videoTimestamp!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .messageMediaEmpty:
                    if boxed {
                        buffer.appendInt32(1038967584)
                    }
                    
                    break
                case .messageMediaGame(let game):
                    if boxed {
                        buffer.appendInt32(-38694904)
                    }
                    game.serialize(buffer, true)
                    break
                case .messageMediaGeo(let geo):
                    if boxed {
                        buffer.appendInt32(1457575028)
                    }
                    geo.serialize(buffer, true)
                    break
                case .messageMediaGeoLive(let flags, let geo, let heading, let period, let proximityNotificationRadius):
                    if boxed {
                        buffer.appendInt32(-1186937242)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(heading!, buffer: buffer, boxed: false)}
                    serializeInt32(period, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(proximityNotificationRadius!, buffer: buffer, boxed: false)}
                    break
                case .messageMediaGiveaway(let flags, let channels, let countriesIso2, let prizeDescription, let quantity, let months, let stars, let untilDate):
                    if boxed {
                        buffer.appendInt32(-1442366485)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(channels.count))
                    for item in channels {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(countriesIso2!.count))
                    for item in countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(prizeDescription!, buffer: buffer, boxed: false)}
                    serializeInt32(quantity, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(months!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt64(stars!, buffer: buffer, boxed: false)}
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    break
                case .messageMediaGiveawayResults(let flags, let channelId, let additionalPeersCount, let launchMsgId, let winnersCount, let unclaimedCount, let winners, let months, let stars, let prizeDescription, let untilDate):
                    if boxed {
                        buffer.appendInt32(-827703647)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(additionalPeersCount!, buffer: buffer, boxed: false)}
                    serializeInt32(launchMsgId, buffer: buffer, boxed: false)
                    serializeInt32(winnersCount, buffer: buffer, boxed: false)
                    serializeInt32(unclaimedCount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(winners.count))
                    for item in winners {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(months!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt64(stars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(prizeDescription!, buffer: buffer, boxed: false)}
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    break
                case .messageMediaInvoice(let flags, let title, let description, let photo, let receiptMsgId, let currency, let totalAmount, let startParam, let extendedMedia):
                    if boxed {
                        buffer.appendInt32(-156940077)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(receiptMsgId!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {extendedMedia!.serialize(buffer, true)}
                    break
                case .messageMediaPaidMedia(let starsAmount, let extendedMedia):
                    if boxed {
                        buffer.appendInt32(-1467669359)
                    }
                    serializeInt64(starsAmount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(extendedMedia.count))
                    for item in extendedMedia {
                        item.serialize(buffer, true)
                    }
                    break
                case .messageMediaPhoto(let flags, let photo, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(1766936791)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .messageMediaPoll(let poll, let results):
                    if boxed {
                        buffer.appendInt32(1272375192)
                    }
                    poll.serialize(buffer, true)
                    results.serialize(buffer, true)
                    break
                case .messageMediaStory(let flags, let peer, let id, let story):
                    if boxed {
                        buffer.appendInt32(1758159491)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {story!.serialize(buffer, true)}
                    break
                case .messageMediaToDo(let flags, let todo, let completions):
                    if boxed {
                        buffer.appendInt32(-1974226924)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    todo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(completions!.count))
                    for item in completions! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .messageMediaUnsupported:
                    if boxed {
                        buffer.appendInt32(-1618676578)
                    }
                    
                    break
                case .messageMediaVenue(let geo, let title, let address, let provider, let venueId, let venueType):
                    if boxed {
                        buffer.appendInt32(784356159)
                    }
                    geo.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    break
                case .messageMediaWebPage(let flags, let webpage):
                    if boxed {
                        buffer.appendInt32(-571405253)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    webpage.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageMediaContact(let phoneNumber, let firstName, let lastName, let vcard, let userId):
                return ("messageMediaContact", [("phoneNumber", phoneNumber as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("vcard", vcard as Any), ("userId", userId as Any)])
                case .messageMediaDice(let value, let emoticon):
                return ("messageMediaDice", [("value", value as Any), ("emoticon", emoticon as Any)])
                case .messageMediaDocument(let flags, let document, let altDocuments, let videoCover, let videoTimestamp, let ttlSeconds):
                return ("messageMediaDocument", [("flags", flags as Any), ("document", document as Any), ("altDocuments", altDocuments as Any), ("videoCover", videoCover as Any), ("videoTimestamp", videoTimestamp as Any), ("ttlSeconds", ttlSeconds as Any)])
                case .messageMediaEmpty:
                return ("messageMediaEmpty", [])
                case .messageMediaGame(let game):
                return ("messageMediaGame", [("game", game as Any)])
                case .messageMediaGeo(let geo):
                return ("messageMediaGeo", [("geo", geo as Any)])
                case .messageMediaGeoLive(let flags, let geo, let heading, let period, let proximityNotificationRadius):
                return ("messageMediaGeoLive", [("flags", flags as Any), ("geo", geo as Any), ("heading", heading as Any), ("period", period as Any), ("proximityNotificationRadius", proximityNotificationRadius as Any)])
                case .messageMediaGiveaway(let flags, let channels, let countriesIso2, let prizeDescription, let quantity, let months, let stars, let untilDate):
                return ("messageMediaGiveaway", [("flags", flags as Any), ("channels", channels as Any), ("countriesIso2", countriesIso2 as Any), ("prizeDescription", prizeDescription as Any), ("quantity", quantity as Any), ("months", months as Any), ("stars", stars as Any), ("untilDate", untilDate as Any)])
                case .messageMediaGiveawayResults(let flags, let channelId, let additionalPeersCount, let launchMsgId, let winnersCount, let unclaimedCount, let winners, let months, let stars, let prizeDescription, let untilDate):
                return ("messageMediaGiveawayResults", [("flags", flags as Any), ("channelId", channelId as Any), ("additionalPeersCount", additionalPeersCount as Any), ("launchMsgId", launchMsgId as Any), ("winnersCount", winnersCount as Any), ("unclaimedCount", unclaimedCount as Any), ("winners", winners as Any), ("months", months as Any), ("stars", stars as Any), ("prizeDescription", prizeDescription as Any), ("untilDate", untilDate as Any)])
                case .messageMediaInvoice(let flags, let title, let description, let photo, let receiptMsgId, let currency, let totalAmount, let startParam, let extendedMedia):
                return ("messageMediaInvoice", [("flags", flags as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("receiptMsgId", receiptMsgId as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("startParam", startParam as Any), ("extendedMedia", extendedMedia as Any)])
                case .messageMediaPaidMedia(let starsAmount, let extendedMedia):
                return ("messageMediaPaidMedia", [("starsAmount", starsAmount as Any), ("extendedMedia", extendedMedia as Any)])
                case .messageMediaPhoto(let flags, let photo, let ttlSeconds):
                return ("messageMediaPhoto", [("flags", flags as Any), ("photo", photo as Any), ("ttlSeconds", ttlSeconds as Any)])
                case .messageMediaPoll(let poll, let results):
                return ("messageMediaPoll", [("poll", poll as Any), ("results", results as Any)])
                case .messageMediaStory(let flags, let peer, let id, let story):
                return ("messageMediaStory", [("flags", flags as Any), ("peer", peer as Any), ("id", id as Any), ("story", story as Any)])
                case .messageMediaToDo(let flags, let todo, let completions):
                return ("messageMediaToDo", [("flags", flags as Any), ("todo", todo as Any), ("completions", completions as Any)])
                case .messageMediaUnsupported:
                return ("messageMediaUnsupported", [])
                case .messageMediaVenue(let geo, let title, let address, let provider, let venueId, let venueType):
                return ("messageMediaVenue", [("geo", geo as Any), ("title", title as Any), ("address", address as Any), ("provider", provider as Any), ("venueId", venueId as Any), ("venueType", venueType as Any)])
                case .messageMediaWebPage(let flags, let webpage):
                return ("messageMediaWebPage", [("flags", flags as Any), ("webpage", webpage as Any)])
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
                return Api.MessageMedia.messageMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, vcard: _4!, userId: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaDice(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageMedia.messageMediaDice(value: _1!, emoticon: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaDocument(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _3: [Api.Document]?
            if Int(_1!) & Int(1 << 5) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            } }
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 5) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 9) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 10) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MessageMedia.messageMediaDocument(flags: _1!, document: _2, altDocuments: _3, videoCover: _4, videoTimestamp: _5, ttlSeconds: _6)
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
                return Api.MessageMedia.messageMediaGame(game: _1!)
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
                return Api.MessageMedia.messageMediaGeo(geo: _1!)
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
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageMedia.messageMediaGeoLive(flags: _1!, geo: _2!, heading: _3, period: _4!, proximityNotificationRadius: _5)
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
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = parseString(reader) }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = reader.readInt32() }
            var _7: Int64?
            if Int(_1!) & Int(1 << 5) != 0 {_7 = reader.readInt64() }
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
                return Api.MessageMedia.messageMediaGiveaway(flags: _1!, channels: _2!, countriesIso2: _3, prizeDescription: _4, quantity: _5!, months: _6, stars: _7, untilDate: _8!)
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
            if Int(_1!) & Int(1 << 3) != 0 {_3 = reader.readInt32() }
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
            if Int(_1!) & Int(1 << 4) != 0 {_8 = reader.readInt32() }
            var _9: Int64?
            if Int(_1!) & Int(1 << 5) != 0 {_9 = reader.readInt64() }
            var _10: String?
            if Int(_1!) & Int(1 << 1) != 0 {_10 = parseString(reader) }
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
                return Api.MessageMedia.messageMediaGiveawayResults(flags: _1!, channelId: _2!, additionalPeersCount: _3, launchMsgId: _4!, winnersCount: _5!, unclaimedCount: _6!, winners: _7!, months: _8, stars: _9, prizeDescription: _10, untilDate: _11!)
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
            var _6: String?
            _6 = parseString(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: String?
            _8 = parseString(reader)
            var _9: Api.MessageExtendedMedia?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.MessageExtendedMedia
            } }
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
                return Api.MessageMedia.messageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, receiptMsgId: _5, currency: _6!, totalAmount: _7!, startParam: _8!, extendedMedia: _9)
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
                return Api.MessageMedia.messageMediaPaidMedia(starsAmount: _1!, extendedMedia: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageMediaPhoto(_ reader: BufferReader) -> MessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Photo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageMedia.messageMediaPhoto(flags: _1!, photo: _2, ttlSeconds: _3)
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
                return Api.MessageMedia.messageMediaPoll(poll: _1!, results: _2!)
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StoryItem
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageMedia.messageMediaStory(flags: _1!, peer: _2!, id: _3!, story: _4)
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
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TodoCompletion.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageMedia.messageMediaToDo(flags: _1!, todo: _2!, completions: _3)
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
                return Api.MessageMedia.messageMediaVenue(geo: _1!, title: _2!, address: _3!, provider: _4!, venueId: _5!, venueType: _6!)
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
                return Api.MessageMedia.messageMediaWebPage(flags: _1!, webpage: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
