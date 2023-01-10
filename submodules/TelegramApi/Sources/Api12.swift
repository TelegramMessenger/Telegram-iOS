public extension Api {
    indirect enum MessageEntity: TypeConstructorDescription {
        case inputMessageEntityMentionName(offset: Int32, length: Int32, userId: Api.InputUser)
        case messageEntityBankCard(offset: Int32, length: Int32)
        case messageEntityBlockquote(offset: Int32, length: Int32)
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
                case .messageEntityBlockquote(let offset, let length):
                    if boxed {
                        buffer.appendInt32(34469328)
                    }
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
                return ("inputMessageEntityMentionName", [("offset", String(describing: offset)), ("length", String(describing: length)), ("userId", String(describing: userId))])
                case .messageEntityBankCard(let offset, let length):
                return ("messageEntityBankCard", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityBlockquote(let offset, let length):
                return ("messageEntityBlockquote", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityBold(let offset, let length):
                return ("messageEntityBold", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityBotCommand(let offset, let length):
                return ("messageEntityBotCommand", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityCashtag(let offset, let length):
                return ("messageEntityCashtag", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityCode(let offset, let length):
                return ("messageEntityCode", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityCustomEmoji(let offset, let length, let documentId):
                return ("messageEntityCustomEmoji", [("offset", String(describing: offset)), ("length", String(describing: length)), ("documentId", String(describing: documentId))])
                case .messageEntityEmail(let offset, let length):
                return ("messageEntityEmail", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityHashtag(let offset, let length):
                return ("messageEntityHashtag", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityItalic(let offset, let length):
                return ("messageEntityItalic", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityMention(let offset, let length):
                return ("messageEntityMention", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityMentionName(let offset, let length, let userId):
                return ("messageEntityMentionName", [("offset", String(describing: offset)), ("length", String(describing: length)), ("userId", String(describing: userId))])
                case .messageEntityPhone(let offset, let length):
                return ("messageEntityPhone", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityPre(let offset, let length, let language):
                return ("messageEntityPre", [("offset", String(describing: offset)), ("length", String(describing: length)), ("language", String(describing: language))])
                case .messageEntitySpoiler(let offset, let length):
                return ("messageEntitySpoiler", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityStrike(let offset, let length):
                return ("messageEntityStrike", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityTextUrl(let offset, let length, let url):
                return ("messageEntityTextUrl", [("offset", String(describing: offset)), ("length", String(describing: length)), ("url", String(describing: url))])
                case .messageEntityUnderline(let offset, let length):
                return ("messageEntityUnderline", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityUnknown(let offset, let length):
                return ("messageEntityUnknown", [("offset", String(describing: offset)), ("length", String(describing: length))])
                case .messageEntityUrl(let offset, let length):
                return ("messageEntityUrl", [("offset", String(describing: offset)), ("length", String(describing: length))])
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageEntity.messageEntityBlockquote(offset: _1!, length: _2!)
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
                return ("messageExtendedMedia", [("media", String(describing: media))])
                case .messageExtendedMediaPreview(let flags, let w, let h, let thumb, let videoDuration):
                return ("messageExtendedMediaPreview", [("flags", String(describing: flags)), ("w", String(describing: w)), ("h", String(describing: h)), ("thumb", String(describing: thumb)), ("videoDuration", String(describing: videoDuration))])
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
        case messageFwdHeader(flags: Int32, fromId: Api.Peer?, fromName: String?, date: Int32, channelPost: Int32?, postAuthor: String?, savedFromPeer: Api.Peer?, savedFromMsgId: Int32?, psaType: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageFwdHeader(let flags, let fromId, let fromName, let date, let channelPost, let postAuthor, let savedFromPeer, let savedFromMsgId, let psaType):
                    if boxed {
                        buffer.appendInt32(1601666510)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(fromName!, buffer: buffer, boxed: false)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(channelPost!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(postAuthor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {savedFromPeer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(savedFromMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(psaType!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageFwdHeader(let flags, let fromId, let fromName, let date, let channelPost, let postAuthor, let savedFromPeer, let savedFromMsgId, let psaType):
                return ("messageFwdHeader", [("flags", String(describing: flags)), ("fromId", String(describing: fromId)), ("fromName", String(describing: fromName)), ("date", String(describing: date)), ("channelPost", String(describing: channelPost)), ("postAuthor", String(describing: postAuthor)), ("savedFromPeer", String(describing: savedFromPeer)), ("savedFromMsgId", String(describing: savedFromMsgId)), ("psaType", String(describing: psaType))])
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
            var _9: String?
            if Int(_1!) & Int(1 << 6) != 0 {_9 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 5) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.MessageFwdHeader.messageFwdHeader(flags: _1!, fromId: _2, fromName: _3, date: _4!, channelPost: _5, postAuthor: _6, savedFromPeer: _7, savedFromMsgId: _8, psaType: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageInteractionCounters: TypeConstructorDescription {
        case messageInteractionCounters(msgId: Int32, views: Int32, forwards: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageInteractionCounters(let msgId, let views, let forwards):
                    if boxed {
                        buffer.appendInt32(-1387279939)
                    }
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(views, buffer: buffer, boxed: false)
                    serializeInt32(forwards, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageInteractionCounters(let msgId, let views, let forwards):
                return ("messageInteractionCounters", [("msgId", String(describing: msgId)), ("views", String(describing: views)), ("forwards", String(describing: forwards))])
    }
    }
    
        public static func parse_messageInteractionCounters(_ reader: BufferReader) -> MessageInteractionCounters? {
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
                return Api.MessageInteractionCounters.messageInteractionCounters(msgId: _1!, views: _2!, forwards: _3!)
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
        case messageMediaDocument(flags: Int32, document: Api.Document?, ttlSeconds: Int32?)
        case messageMediaEmpty
        case messageMediaGame(game: Api.Game)
        case messageMediaGeo(geo: Api.GeoPoint)
        case messageMediaGeoLive(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32, proximityNotificationRadius: Int32?)
        case messageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String, extendedMedia: Api.MessageExtendedMedia?)
        case messageMediaPhoto(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?)
        case messageMediaPoll(poll: Api.Poll, results: Api.PollResults)
        case messageMediaUnsupported
        case messageMediaVenue(geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case messageMediaWebPage(webpage: Api.WebPage)
    
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
                case .messageMediaDocument(let flags, let document, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-1666158377)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {document!.serialize(buffer, true)}
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
                case .messageMediaWebPage(let webpage):
                    if boxed {
                        buffer.appendInt32(-1557277184)
                    }
                    webpage.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageMediaContact(let phoneNumber, let firstName, let lastName, let vcard, let userId):
                return ("messageMediaContact", [("phoneNumber", String(describing: phoneNumber)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("vcard", String(describing: vcard)), ("userId", String(describing: userId))])
                case .messageMediaDice(let value, let emoticon):
                return ("messageMediaDice", [("value", String(describing: value)), ("emoticon", String(describing: emoticon))])
                case .messageMediaDocument(let flags, let document, let ttlSeconds):
                return ("messageMediaDocument", [("flags", String(describing: flags)), ("document", String(describing: document)), ("ttlSeconds", String(describing: ttlSeconds))])
                case .messageMediaEmpty:
                return ("messageMediaEmpty", [])
                case .messageMediaGame(let game):
                return ("messageMediaGame", [("game", String(describing: game))])
                case .messageMediaGeo(let geo):
                return ("messageMediaGeo", [("geo", String(describing: geo))])
                case .messageMediaGeoLive(let flags, let geo, let heading, let period, let proximityNotificationRadius):
                return ("messageMediaGeoLive", [("flags", String(describing: flags)), ("geo", String(describing: geo)), ("heading", String(describing: heading)), ("period", String(describing: period)), ("proximityNotificationRadius", String(describing: proximityNotificationRadius))])
                case .messageMediaInvoice(let flags, let title, let description, let photo, let receiptMsgId, let currency, let totalAmount, let startParam, let extendedMedia):
                return ("messageMediaInvoice", [("flags", String(describing: flags)), ("title", String(describing: title)), ("description", String(describing: description)), ("photo", String(describing: photo)), ("receiptMsgId", String(describing: receiptMsgId)), ("currency", String(describing: currency)), ("totalAmount", String(describing: totalAmount)), ("startParam", String(describing: startParam)), ("extendedMedia", String(describing: extendedMedia))])
                case .messageMediaPhoto(let flags, let photo, let ttlSeconds):
                return ("messageMediaPhoto", [("flags", String(describing: flags)), ("photo", String(describing: photo)), ("ttlSeconds", String(describing: ttlSeconds))])
                case .messageMediaPoll(let poll, let results):
                return ("messageMediaPoll", [("poll", String(describing: poll)), ("results", String(describing: results))])
                case .messageMediaUnsupported:
                return ("messageMediaUnsupported", [])
                case .messageMediaVenue(let geo, let title, let address, let provider, let venueId, let venueType):
                return ("messageMediaVenue", [("geo", String(describing: geo)), ("title", String(describing: title)), ("address", String(describing: address)), ("provider", String(describing: provider)), ("venueId", String(describing: venueId)), ("venueType", String(describing: venueType))])
                case .messageMediaWebPage(let webpage):
                return ("messageMediaWebPage", [("webpage", String(describing: webpage))])
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
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageMedia.messageMediaDocument(flags: _1!, document: _2, ttlSeconds: _3)
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
            var _1: Api.WebPage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageMedia.messageMediaWebPage(webpage: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
