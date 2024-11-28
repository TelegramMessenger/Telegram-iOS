public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription {
        case inputStickerSetItem(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?, keywords: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickerSetItem(let flags, let document, let emoji, let maskCoords, let keywords):
                    if boxed {
                        buffer.appendInt32(853188252)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    serializeString(emoji, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {maskCoords!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(keywords!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickerSetItem(let flags, let document, let emoji, let maskCoords, let keywords):
                return ("inputStickerSetItem", [("flags", flags as Any), ("document", document as Any), ("emoji", emoji as Any), ("maskCoords", maskCoords as Any), ("keywords", keywords as Any)])
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
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputStickerSetItem.inputStickerSetItem(flags: _1!, document: _2!, emoji: _3!, maskCoords: _4, keywords: _5)
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
                return ("inputStickeredMediaDocument", [("id", id as Any)])
                case .inputStickeredMediaPhoto(let id):
                return ("inputStickeredMediaPhoto", [("id", id as Any)])
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
        case inputStorePaymentPremiumGiftCode(flags: Int32, users: [Api.InputUser], boostPeer: Api.InputPeer?, currency: String, amount: Int64, message: Api.TextWithEntities?)
        case inputStorePaymentPremiumGiveaway(flags: Int32, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64)
        case inputStorePaymentPremiumSubscription(flags: Int32)
        case inputStorePaymentStarsGift(userId: Api.InputUser, stars: Int64, currency: String, amount: Int64)
        case inputStorePaymentStarsGiveaway(flags: Int32, stars: Int64, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, users: Int32)
        case inputStorePaymentStarsTopup(stars: Int64, currency: String, amount: Int64)
    
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
                case .inputStorePaymentPremiumGiftCode(let flags, let users, let boostPeer, let currency, let amount, let message):
                    if boxed {
                        buffer.appendInt32(-75955309)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {boostPeer!.serialize(buffer, true)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {message!.serialize(buffer, true)}
                    break
                case .inputStorePaymentPremiumGiveaway(let flags, let boostPeer, let additionalPeers, let countriesIso2, let prizeDescription, let randomId, let untilDate, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(369444042)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    boostPeer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(additionalPeers!.count))
                    for item in additionalPeers! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(countriesIso2!.count))
                    for item in countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(prizeDescription!, buffer: buffer, boxed: false)}
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
                case .inputStorePaymentPremiumSubscription(let flags):
                    if boxed {
                        buffer.appendInt32(-1502273946)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .inputStorePaymentStarsGift(let userId, let stars, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(494149367)
                    }
                    userId.serialize(buffer, true)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
                case .inputStorePaymentStarsGiveaway(let flags, let stars, let boostPeer, let additionalPeers, let countriesIso2, let prizeDescription, let randomId, let untilDate, let currency, let amount, let users):
                    if boxed {
                        buffer.appendInt32(1964968186)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    boostPeer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(additionalPeers!.count))
                    for item in additionalPeers! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(countriesIso2!.count))
                    for item in countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(prizeDescription!, buffer: buffer, boxed: false)}
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    serializeInt32(users, buffer: buffer, boxed: false)
                    break
                case .inputStorePaymentStarsTopup(let stars, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(-572715178)
                    }
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStorePaymentGiftPremium(let userId, let currency, let amount):
                return ("inputStorePaymentGiftPremium", [("userId", userId as Any), ("currency", currency as Any), ("amount", amount as Any)])
                case .inputStorePaymentPremiumGiftCode(let flags, let users, let boostPeer, let currency, let amount, let message):
                return ("inputStorePaymentPremiumGiftCode", [("flags", flags as Any), ("users", users as Any), ("boostPeer", boostPeer as Any), ("currency", currency as Any), ("amount", amount as Any), ("message", message as Any)])
                case .inputStorePaymentPremiumGiveaway(let flags, let boostPeer, let additionalPeers, let countriesIso2, let prizeDescription, let randomId, let untilDate, let currency, let amount):
                return ("inputStorePaymentPremiumGiveaway", [("flags", flags as Any), ("boostPeer", boostPeer as Any), ("additionalPeers", additionalPeers as Any), ("countriesIso2", countriesIso2 as Any), ("prizeDescription", prizeDescription as Any), ("randomId", randomId as Any), ("untilDate", untilDate as Any), ("currency", currency as Any), ("amount", amount as Any)])
                case .inputStorePaymentPremiumSubscription(let flags):
                return ("inputStorePaymentPremiumSubscription", [("flags", flags as Any)])
                case .inputStorePaymentStarsGift(let userId, let stars, let currency, let amount):
                return ("inputStorePaymentStarsGift", [("userId", userId as Any), ("stars", stars as Any), ("currency", currency as Any), ("amount", amount as Any)])
                case .inputStorePaymentStarsGiveaway(let flags, let stars, let boostPeer, let additionalPeers, let countriesIso2, let prizeDescription, let randomId, let untilDate, let currency, let amount, let users):
                return ("inputStorePaymentStarsGiveaway", [("flags", flags as Any), ("stars", stars as Any), ("boostPeer", boostPeer as Any), ("additionalPeers", additionalPeers as Any), ("countriesIso2", countriesIso2 as Any), ("prizeDescription", prizeDescription as Any), ("randomId", randomId as Any), ("untilDate", untilDate as Any), ("currency", currency as Any), ("amount", amount as Any), ("users", users as Any)])
                case .inputStorePaymentStarsTopup(let stars, let currency, let amount):
                return ("inputStorePaymentStarsTopup", [("stars", stars as Any), ("currency", currency as Any), ("amount", amount as Any)])
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
        public static func parse_inputStorePaymentPremiumGiftCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            var _3: Api.InputPeer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPeer
            } }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumGiftCode(flags: _1!, users: _2!, boostPeer: _3, currency: _4!, amount: _5!, message: _6)
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
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            } }
            var _4: [String]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            var _5: String?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = parseString(reader) }
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
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumGiveaway(flags: _1!, boostPeer: _2!, additionalPeers: _3, countriesIso2: _4, prizeDescription: _5, randomId: _6!, untilDate: _7!, currency: _8!, amount: _9!)
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
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsGift(userId: _1!, stars: _2!, currency: _3!, amount: _4!)
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
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            } }
            var _5: [String]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = parseString(reader) }
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
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsGiveaway(flags: _1!, stars: _2!, boostPeer: _3!, additionalPeers: _4, countriesIso2: _5, prizeDescription: _6, randomId: _7!, untilDate: _8!, currency: _9!, amount: _10!, users: _11!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentStarsTopup(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsTopup(stars: _1!, currency: _2!, amount: _3!)
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
                return ("inputTheme", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputThemeSlug(let slug):
                return ("inputThemeSlug", [("slug", slug as Any)])
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
                return ("inputThemeSettings", [("flags", flags as Any), ("baseTheme", baseTheme as Any), ("accentColor", accentColor as Any), ("outboxAccentColor", outboxAccentColor as Any), ("messageColors", messageColors as Any), ("wallpaper", wallpaper as Any), ("wallpaperSettings", wallpaperSettings as Any)])
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
                return ("inputUser", [("userId", userId as Any), ("accessHash", accessHash as Any)])
                case .inputUserEmpty:
                return ("inputUserEmpty", [])
                case .inputUserFromMessage(let peer, let msgId, let userId):
                return ("inputUserFromMessage", [("peer", peer as Any), ("msgId", msgId as Any), ("userId", userId as Any)])
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
                return ("inputWallPaper", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputWallPaperNoFile(let id):
                return ("inputWallPaperNoFile", [("id", id as Any)])
                case .inputWallPaperSlug(let slug):
                return ("inputWallPaperSlug", [("slug", slug as Any)])
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
                return ("inputWebDocument", [("url", url as Any), ("size", size as Any), ("mimeType", mimeType as Any), ("attributes", attributes as Any)])
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
                return ("inputWebFileAudioAlbumThumbLocation", [("flags", flags as Any), ("document", document as Any), ("title", title as Any), ("performer", performer as Any)])
                case .inputWebFileGeoPointLocation(let geoPoint, let accessHash, let w, let h, let zoom, let scale):
                return ("inputWebFileGeoPointLocation", [("geoPoint", geoPoint as Any), ("accessHash", accessHash as Any), ("w", w as Any), ("h", h as Any), ("zoom", zoom as Any), ("scale", scale as Any)])
                case .inputWebFileLocation(let url, let accessHash):
                return ("inputWebFileLocation", [("url", url as Any), ("accessHash", accessHash as Any)])
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
        case invoice(flags: Int32, currency: String, prices: [Api.LabeledPrice], maxTipAmount: Int64?, suggestedTipAmounts: [Int64]?, termsUrl: String?, subscriptionPeriod: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .invoice(let flags, let currency, let prices, let maxTipAmount, let suggestedTipAmounts, let termsUrl, let subscriptionPeriod):
                    if boxed {
                        buffer.appendInt32(77522308)
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
                    if Int(flags) & Int(1 << 10) != 0 {serializeString(termsUrl!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(subscriptionPeriod!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .invoice(let flags, let currency, let prices, let maxTipAmount, let suggestedTipAmounts, let termsUrl, let subscriptionPeriod):
                return ("invoice", [("flags", flags as Any), ("currency", currency as Any), ("prices", prices as Any), ("maxTipAmount", maxTipAmount as Any), ("suggestedTipAmounts", suggestedTipAmounts as Any), ("termsUrl", termsUrl as Any), ("subscriptionPeriod", subscriptionPeriod as Any)])
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
            if Int(_1!) & Int(1 << 10) != 0 {_6 = parseString(reader) }
            var _7: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_7 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 8) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 8) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 10) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Invoice.invoice(flags: _1!, currency: _2!, prices: _3!, maxTipAmount: _4, suggestedTipAmounts: _5, termsUrl: _6, subscriptionPeriod: _7)
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
                return ("jsonObjectValue", [("key", key as Any), ("value", value as Any)])
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
                return ("jsonArray", [("value", value as Any)])
                case .jsonBool(let value):
                return ("jsonBool", [("value", value as Any)])
                case .jsonNull:
                return ("jsonNull", [])
                case .jsonNumber(let value):
                return ("jsonNumber", [("value", value as Any)])
                case .jsonObject(let value):
                return ("jsonObject", [("value", value as Any)])
                case .jsonString(let value):
                return ("jsonString", [("value", value as Any)])
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
