public extension Api {
    enum InputStickerSet: TypeConstructorDescription {
        case inputStickerSetAnimatedEmoji
        case inputStickerSetAnimatedEmojiAnimations
        case inputStickerSetDice(emoticon: String)
        case inputStickerSetEmojiDefaultStatuses
        case inputStickerSetEmojiDefaultTopicIcons
        case inputStickerSetEmojiGenericAnimations
        case inputStickerSetEmpty
        case inputStickerSetID(id: Int64, accessHash: Int64)
        case inputStickerSetPremiumGifts
        case inputStickerSetShortName(shortName: String)
    
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
                case .inputStickerSetDice(let emoticon):
                    if boxed {
                        buffer.appendInt32(-427863538)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
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
                case .inputStickerSetID(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1645763991)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetPremiumGifts:
                    if boxed {
                        buffer.appendInt32(-930399486)
                    }
                    
                    break
                case .inputStickerSetShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2044933984)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickerSetAnimatedEmoji:
                return ("inputStickerSetAnimatedEmoji", [])
                case .inputStickerSetAnimatedEmojiAnimations:
                return ("inputStickerSetAnimatedEmojiAnimations", [])
                case .inputStickerSetDice(let emoticon):
                return ("inputStickerSetDice", [("emoticon", String(describing: emoticon))])
                case .inputStickerSetEmojiDefaultStatuses:
                return ("inputStickerSetEmojiDefaultStatuses", [])
                case .inputStickerSetEmojiDefaultTopicIcons:
                return ("inputStickerSetEmojiDefaultTopicIcons", [])
                case .inputStickerSetEmojiGenericAnimations:
                return ("inputStickerSetEmojiGenericAnimations", [])
                case .inputStickerSetEmpty:
                return ("inputStickerSetEmpty", [])
                case .inputStickerSetID(let id, let accessHash):
                return ("inputStickerSetID", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputStickerSetPremiumGifts:
                return ("inputStickerSetPremiumGifts", [])
                case .inputStickerSetShortName(let shortName):
                return ("inputStickerSetShortName", [("shortName", String(describing: shortName))])
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
                return Api.InputStickerSet.inputStickerSetDice(emoticon: _1!)
            }
            else {
                return nil
            }
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
                return Api.InputStickerSet.inputStickerSetID(id: _1!, accessHash: _2!)
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
                return Api.InputStickerSet.inputStickerSetShortName(shortName: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription {
        case inputStickerSetItem(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickerSetItem(let flags, let document, let emoji, let maskCoords):
                    if boxed {
                        buffer.appendInt32(-6249322)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    serializeString(emoji, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {maskCoords!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickerSetItem(let flags, let document, let emoji, let maskCoords):
                return ("inputStickerSetItem", [("flags", String(describing: flags)), ("document", String(describing: document)), ("emoji", String(describing: emoji)), ("maskCoords", String(describing: maskCoords))])
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.MaskCoords
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputStickerSetItem.inputStickerSetItem(flags: _1!, document: _2!, emoji: _3!, maskCoords: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputStickeredMedia: TypeConstructorDescription {
        case inputStickeredMediaDocument(id: Api.InputDocument)
        case inputStickeredMediaPhoto(id: Api.InputPhoto)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickeredMediaDocument(let id):
                    if boxed {
                        buffer.appendInt32(70813275)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputStickeredMediaPhoto(let id):
                    if boxed {
                        buffer.appendInt32(1251549527)
                    }
                    id.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickeredMediaDocument(let id):
                return ("inputStickeredMediaDocument", [("id", String(describing: id))])
                case .inputStickeredMediaPhoto(let id):
                return ("inputStickeredMediaPhoto", [("id", String(describing: id))])
    }
    }
    
        public static func parse_inputStickeredMediaDocument(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputDocument?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaDocument(id: _1!)
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
                return Api.InputStickeredMedia.inputStickeredMediaPhoto(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputStorePaymentPurpose: TypeConstructorDescription {
        case inputStorePaymentGiftPremium(userId: Api.InputUser, currency: String, amount: Int64)
        case inputStorePaymentPremiumSubscription(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStorePaymentGiftPremium(let userId, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(1634697192)
                    }
                    userId.serialize(buffer, true)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
                case .inputStorePaymentPremiumSubscription(let flags):
                    if boxed {
                        buffer.appendInt32(-1502273946)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStorePaymentGiftPremium(let userId, let currency, let amount):
                return ("inputStorePaymentGiftPremium", [("userId", String(describing: userId)), ("currency", String(describing: currency)), ("amount", String(describing: amount))])
                case .inputStorePaymentPremiumSubscription(let flags):
                return ("inputStorePaymentPremiumSubscription", [("flags", String(describing: flags))])
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
                return Api.InputStorePaymentPurpose.inputStorePaymentGiftPremium(userId: _1!, currency: _2!, amount: _3!)
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
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumSubscription(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputTheme: TypeConstructorDescription {
        case inputTheme(id: Int64, accessHash: Int64)
        case inputThemeSlug(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputTheme(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1012306921)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputThemeSlug(let slug):
                    if boxed {
                        buffer.appendInt32(-175567375)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputTheme(let id, let accessHash):
                return ("inputTheme", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputThemeSlug(let slug):
                return ("inputThemeSlug", [("slug", String(describing: slug))])
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
                return Api.InputTheme.inputTheme(id: _1!, accessHash: _2!)
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
                return Api.InputTheme.inputThemeSlug(slug: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputThemeSettings: TypeConstructorDescription {
        case inputThemeSettings(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.InputWallPaper?, wallpaperSettings: Api.WallPaperSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputThemeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper, let wallpaperSettings):
                    if boxed {
                        buffer.appendInt32(-1881255857)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    baseTheme.serialize(buffer, true)
                    serializeInt32(accentColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(outboxAccentColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messageColors!.count))
                    for item in messageColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaper!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaperSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputThemeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper, let wallpaperSettings):
                return ("inputThemeSettings", [("flags", String(describing: flags)), ("baseTheme", String(describing: baseTheme)), ("accentColor", String(describing: accentColor)), ("outboxAccentColor", String(describing: outboxAccentColor)), ("messageColors", String(describing: messageColors)), ("wallpaper", String(describing: wallpaper)), ("wallpaperSettings", String(describing: wallpaperSettings))])
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
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            var _6: Api.InputWallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputWallPaper
            } }
            var _7: Api.WallPaperSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputThemeSettings.inputThemeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, outboxAccentColor: _4, messageColors: _5, wallpaper: _6, wallpaperSettings: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputUser: TypeConstructorDescription {
        case inputUser(userId: Int64, accessHash: Int64)
        case inputUserEmpty
        case inputUserFromMessage(peer: Api.InputPeer, msgId: Int32, userId: Int64)
        case inputUserSelf
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputUser(let userId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-233744186)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputUserEmpty:
                    if boxed {
                        buffer.appendInt32(-1182234929)
                    }
                    
                    break
                case .inputUserFromMessage(let peer, let msgId, let userId):
                    if boxed {
                        buffer.appendInt32(497305826)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .inputUserSelf:
                    if boxed {
                        buffer.appendInt32(-138301121)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputUser(let userId, let accessHash):
                return ("inputUser", [("userId", String(describing: userId)), ("accessHash", String(describing: accessHash))])
                case .inputUserEmpty:
                return ("inputUserEmpty", [])
                case .inputUserFromMessage(let peer, let msgId, let userId):
                return ("inputUserFromMessage", [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("userId", String(describing: userId))])
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
                return Api.InputUser.inputUser(userId: _1!, accessHash: _2!)
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
                return Api.InputUser.inputUserFromMessage(peer: _1!, msgId: _2!, userId: _3!)
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
        case inputWallPaper(id: Int64, accessHash: Int64)
        case inputWallPaperNoFile(id: Int64)
        case inputWallPaperSlug(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputWallPaper(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-433014407)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputWallPaperNoFile(let id):
                    if boxed {
                        buffer.appendInt32(-1770371538)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .inputWallPaperSlug(let slug):
                    if boxed {
                        buffer.appendInt32(1913199744)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputWallPaper(let id, let accessHash):
                return ("inputWallPaper", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputWallPaperNoFile(let id):
                return ("inputWallPaperNoFile", [("id", String(describing: id))])
                case .inputWallPaperSlug(let slug):
                return ("inputWallPaperSlug", [("slug", String(describing: slug))])
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
                return Api.InputWallPaper.inputWallPaper(id: _1!, accessHash: _2!)
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
                return Api.InputWallPaper.inputWallPaperNoFile(id: _1!)
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
                return Api.InputWallPaper.inputWallPaperSlug(slug: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputWebDocument: TypeConstructorDescription {
        case inputWebDocument(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputWebDocument(let url, let size, let mimeType, let attributes):
                    if boxed {
                        buffer.appendInt32(-1678949555)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputWebDocument(let url, let size, let mimeType, let attributes):
                return ("inputWebDocument", [("url", String(describing: url)), ("size", String(describing: size)), ("mimeType", String(describing: mimeType)), ("attributes", String(describing: attributes))])
    }
    }
    
        public static func parse_inputWebDocument(_ reader: BufferReader) -> InputWebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputWebDocument.inputWebDocument(url: _1!, size: _2!, mimeType: _3!, attributes: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputWebFileLocation: TypeConstructorDescription {
        case inputWebFileAudioAlbumThumbLocation(flags: Int32, document: Api.InputDocument?, title: String?, performer: String?)
        case inputWebFileGeoPointLocation(geoPoint: Api.InputGeoPoint, accessHash: Int64, w: Int32, h: Int32, zoom: Int32, scale: Int32)
        case inputWebFileLocation(url: String, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputWebFileAudioAlbumThumbLocation(let flags, let document, let title, let performer):
                    if boxed {
                        buffer.appendInt32(-193992412)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(performer!, buffer: buffer, boxed: false)}
                    break
                case .inputWebFileGeoPointLocation(let geoPoint, let accessHash, let w, let h, let zoom, let scale):
                    if boxed {
                        buffer.appendInt32(-1625153079)
                    }
                    geoPoint.serialize(buffer, true)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(zoom, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    break
                case .inputWebFileLocation(let url, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1036396922)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputWebFileAudioAlbumThumbLocation(let flags, let document, let title, let performer):
                return ("inputWebFileAudioAlbumThumbLocation", [("flags", String(describing: flags)), ("document", String(describing: document)), ("title", String(describing: title)), ("performer", String(describing: performer))])
                case .inputWebFileGeoPointLocation(let geoPoint, let accessHash, let w, let h, let zoom, let scale):
                return ("inputWebFileGeoPointLocation", [("geoPoint", String(describing: geoPoint)), ("accessHash", String(describing: accessHash)), ("w", String(describing: w)), ("h", String(describing: h)), ("zoom", String(describing: zoom)), ("scale", String(describing: scale))])
                case .inputWebFileLocation(let url, let accessHash):
                return ("inputWebFileLocation", [("url", String(describing: url)), ("accessHash", String(describing: accessHash))])
    }
    }
    
        public static func parse_inputWebFileAudioAlbumThumbLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
            } }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputWebFileLocation.inputWebFileAudioAlbumThumbLocation(flags: _1!, document: _2, title: _3, performer: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileGeoPointLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputWebFileLocation.inputWebFileGeoPointLocation(geoPoint: _1!, accessHash: _2!, w: _3!, h: _4!, zoom: _5!, scale: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWebFileLocation.inputWebFileLocation(url: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Invoice: TypeConstructorDescription {
        case invoice(flags: Int32, currency: String, prices: [Api.LabeledPrice], maxTipAmount: Int64?, suggestedTipAmounts: [Int64]?, recurringTermsUrl: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .invoice(let flags, let currency, let prices, let maxTipAmount, let suggestedTipAmounts, let recurringTermsUrl):
                    if boxed {
                        buffer.appendInt32(1048946971)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prices.count))
                    for item in prices {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt64(maxTipAmount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(suggestedTipAmounts!.count))
                    for item in suggestedTipAmounts! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 9) != 0 {serializeString(recurringTermsUrl!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .invoice(let flags, let currency, let prices, let maxTipAmount, let suggestedTipAmounts, let recurringTermsUrl):
                return ("invoice", [("flags", String(describing: flags)), ("currency", String(describing: currency)), ("prices", String(describing: prices)), ("maxTipAmount", String(describing: maxTipAmount)), ("suggestedTipAmounts", String(describing: suggestedTipAmounts)), ("recurringTermsUrl", String(describing: recurringTermsUrl))])
    }
    }
    
        public static func parse_invoice(_ reader: BufferReader) -> Invoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.LabeledPrice]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LabeledPrice.self)
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {_4 = reader.readInt64() }
            var _5: [Int64]?
            if Int(_1!) & Int(1 << 8) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 9) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 8) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 8) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 9) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Invoice.invoice(flags: _1!, currency: _2!, prices: _3!, maxTipAmount: _4, suggestedTipAmounts: _5, recurringTermsUrl: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum JSONObjectValue: TypeConstructorDescription {
        case jsonObjectValue(key: String, value: Api.JSONValue)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .jsonObjectValue(let key, let value):
                    if boxed {
                        buffer.appendInt32(-1059185703)
                    }
                    serializeString(key, buffer: buffer, boxed: false)
                    value.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .jsonObjectValue(let key, let value):
                return ("jsonObjectValue", [("key", String(describing: key)), ("value", String(describing: value))])
    }
    }
    
        public static func parse_jsonObjectValue(_ reader: BufferReader) -> JSONObjectValue? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.JSONValue?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.JSONObjectValue.jsonObjectValue(key: _1!, value: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum JSONValue: TypeConstructorDescription {
        case jsonArray(value: [Api.JSONValue])
        case jsonBool(value: Api.Bool)
        case jsonNull
        case jsonNumber(value: Double)
        case jsonObject(value: [Api.JSONObjectValue])
        case jsonString(value: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .jsonArray(let value):
                    if boxed {
                        buffer.appendInt32(-146520221)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(value.count))
                    for item in value {
                        item.serialize(buffer, true)
                    }
                    break
                case .jsonBool(let value):
                    if boxed {
                        buffer.appendInt32(-952869270)
                    }
                    value.serialize(buffer, true)
                    break
                case .jsonNull:
                    if boxed {
                        buffer.appendInt32(1064139624)
                    }
                    
                    break
                case .jsonNumber(let value):
                    if boxed {
                        buffer.appendInt32(736157604)
                    }
                    serializeDouble(value, buffer: buffer, boxed: false)
                    break
                case .jsonObject(let value):
                    if boxed {
                        buffer.appendInt32(-1715350371)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(value.count))
                    for item in value {
                        item.serialize(buffer, true)
                    }
                    break
                case .jsonString(let value):
                    if boxed {
                        buffer.appendInt32(-1222740358)
                    }
                    serializeString(value, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .jsonArray(let value):
                return ("jsonArray", [("value", String(describing: value))])
                case .jsonBool(let value):
                return ("jsonBool", [("value", String(describing: value))])
                case .jsonNull:
                return ("jsonNull", [])
                case .jsonNumber(let value):
                return ("jsonNumber", [("value", String(describing: value))])
                case .jsonObject(let value):
                return ("jsonObject", [("value", String(describing: value))])
                case .jsonString(let value):
                return ("jsonString", [("value", String(describing: value))])
    }
    }
    
        public static func parse_jsonArray(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonArray(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonBool(_ reader: BufferReader) -> JSONValue? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonBool(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonNull(_ reader: BufferReader) -> JSONValue? {
            return Api.JSONValue.jsonNull
        }
        public static func parse_jsonNumber(_ reader: BufferReader) -> JSONValue? {
            var _1: Double?
            _1 = reader.readDouble()
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonNumber(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonObject(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONObjectValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONObjectValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonObject(value: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_jsonString(_ reader: BufferReader) -> JSONValue? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonString(value: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
