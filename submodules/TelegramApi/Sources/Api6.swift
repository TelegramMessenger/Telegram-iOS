public extension Api {
    enum DocumentAttribute: TypeConstructorDescription {
        case documentAttributeAnimated
        case documentAttributeAudio(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?)
        case documentAttributeCustomEmoji(flags: Int32, alt: String, stickerset: Api.InputStickerSet)
        case documentAttributeFilename(fileName: String)
        case documentAttributeHasStickers
        case documentAttributeImageSize(w: Int32, h: Int32)
        case documentAttributeSticker(flags: Int32, alt: String, stickerset: Api.InputStickerSet, maskCoords: Api.MaskCoords?)
        case documentAttributeVideo(flags: Int32, duration: Double, w: Int32, h: Int32, preloadPrefixSize: Int32?, videoStartTs: Double?, videoCodec: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .documentAttributeAnimated:
                    if boxed {
                        buffer.appendInt32(297109817)
                    }
                    
                    break
                case .documentAttributeAudio(let flags, let duration, let title, let performer, let waveform):
                    if boxed {
                        buffer.appendInt32(-1739392570)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(performer!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(waveform!, buffer: buffer, boxed: false)}
                    break
                case .documentAttributeCustomEmoji(let flags, let alt, let stickerset):
                    if boxed {
                        buffer.appendInt32(-48981863)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(alt, buffer: buffer, boxed: false)
                    stickerset.serialize(buffer, true)
                    break
                case .documentAttributeFilename(let fileName):
                    if boxed {
                        buffer.appendInt32(358154344)
                    }
                    serializeString(fileName, buffer: buffer, boxed: false)
                    break
                case .documentAttributeHasStickers:
                    if boxed {
                        buffer.appendInt32(-1744710921)
                    }
                    
                    break
                case .documentAttributeImageSize(let w, let h):
                    if boxed {
                        buffer.appendInt32(1815593308)
                    }
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .documentAttributeSticker(let flags, let alt, let stickerset, let maskCoords):
                    if boxed {
                        buffer.appendInt32(1662637586)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(alt, buffer: buffer, boxed: false)
                    stickerset.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {maskCoords!.serialize(buffer, true)}
                    break
                case .documentAttributeVideo(let flags, let duration, let w, let h, let preloadPrefixSize, let videoStartTs, let videoCodec):
                    if boxed {
                        buffer.appendInt32(1137015880)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeDouble(duration, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(preloadPrefixSize!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(videoCodec!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .documentAttributeAnimated:
                return ("documentAttributeAnimated", [])
                case .documentAttributeAudio(let flags, let duration, let title, let performer, let waveform):
                return ("documentAttributeAudio", [("flags", flags as Any), ("duration", duration as Any), ("title", title as Any), ("performer", performer as Any), ("waveform", waveform as Any)])
                case .documentAttributeCustomEmoji(let flags, let alt, let stickerset):
                return ("documentAttributeCustomEmoji", [("flags", flags as Any), ("alt", alt as Any), ("stickerset", stickerset as Any)])
                case .documentAttributeFilename(let fileName):
                return ("documentAttributeFilename", [("fileName", fileName as Any)])
                case .documentAttributeHasStickers:
                return ("documentAttributeHasStickers", [])
                case .documentAttributeImageSize(let w, let h):
                return ("documentAttributeImageSize", [("w", w as Any), ("h", h as Any)])
                case .documentAttributeSticker(let flags, let alt, let stickerset, let maskCoords):
                return ("documentAttributeSticker", [("flags", flags as Any), ("alt", alt as Any), ("stickerset", stickerset as Any), ("maskCoords", maskCoords as Any)])
                case .documentAttributeVideo(let flags, let duration, let w, let h, let preloadPrefixSize, let videoStartTs, let videoCodec):
                return ("documentAttributeVideo", [("flags", flags as Any), ("duration", duration as Any), ("w", w as Any), ("h", h as Any), ("preloadPrefixSize", preloadPrefixSize as Any), ("videoStartTs", videoStartTs as Any), ("videoCodec", videoCodec as Any)])
    }
    }
    
        public static func parse_documentAttributeAnimated(_ reader: BufferReader) -> DocumentAttribute? {
            return Api.DocumentAttribute.documentAttributeAnimated
        }
        public static func parse_documentAttributeAudio(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseBytes(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.DocumentAttribute.documentAttributeAudio(flags: _1!, duration: _2!, title: _3, performer: _4, waveform: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeCustomEmoji(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.DocumentAttribute.documentAttributeCustomEmoji(flags: _1!, alt: _2!, stickerset: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeFilename(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.DocumentAttribute.documentAttributeFilename(fileName: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeHasStickers(_ reader: BufferReader) -> DocumentAttribute? {
            return Api.DocumentAttribute.documentAttributeHasStickers
        }
        public static func parse_documentAttributeImageSize(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.DocumentAttribute.documentAttributeImageSize(w: _1!, h: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeSticker(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _4: Api.MaskCoords?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.MaskCoords
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.DocumentAttribute.documentAttributeSticker(flags: _1!, alt: _2!, stickerset: _3!, maskCoords: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeVideo(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
            var _6: Double?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = reader.readDouble() }
            var _7: String?
            if Int(_1!) & Int(1 << 5) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.DocumentAttribute.documentAttributeVideo(flags: _1!, duration: _2!, w: _3!, h: _4!, preloadPrefixSize: _5, videoStartTs: _6, videoCodec: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum DraftMessage: TypeConstructorDescription {
        case draftMessage(flags: Int32, replyTo: Api.InputReplyTo?, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, date: Int32, effect: Int64?, suggestedPost: Api.SuggestedPost?)
        case draftMessageEmpty(flags: Int32, date: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .draftMessage(let flags, let replyTo, let message, let entities, let media, let date, let effect, let suggestedPost):
                    if boxed {
                        buffer.appendInt32(-1763006997)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {replyTo!.serialize(buffer, true)}
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {media!.serialize(buffer, true)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt64(effect!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {suggestedPost!.serialize(buffer, true)}
                    break
                case .draftMessageEmpty(let flags, let date):
                    if boxed {
                        buffer.appendInt32(453805082)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(date!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .draftMessage(let flags, let replyTo, let message, let entities, let media, let date, let effect, let suggestedPost):
                return ("draftMessage", [("flags", flags as Any), ("replyTo", replyTo as Any), ("message", message as Any), ("entities", entities as Any), ("media", media as Any), ("date", date as Any), ("effect", effect as Any), ("suggestedPost", suggestedPost as Any)])
                case .draftMessageEmpty(let flags, let date):
                return ("draftMessageEmpty", [("flags", flags as Any), ("date", date as Any)])
    }
    }
    
        public static func parse_draftMessage(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputReplyTo?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputReplyTo
            } }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _5: Api.InputMedia?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InputMedia
            } }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int64?
            if Int(_1!) & Int(1 << 7) != 0 {_7 = reader.readInt64() }
            var _8: Api.SuggestedPost?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.SuggestedPost
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 5) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 8) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.DraftMessage.draftMessage(flags: _1!, replyTo: _2, message: _3!, entities: _4, media: _5, date: _6!, effect: _7, suggestedPost: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_draftMessageEmpty(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.DraftMessage.draftMessageEmpty(flags: _1!, date: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmailVerification: TypeConstructorDescription {
        case emailVerificationApple(token: String)
        case emailVerificationCode(code: String)
        case emailVerificationGoogle(token: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emailVerificationApple(let token):
                    if boxed {
                        buffer.appendInt32(-1764723459)
                    }
                    serializeString(token, buffer: buffer, boxed: false)
                    break
                case .emailVerificationCode(let code):
                    if boxed {
                        buffer.appendInt32(-1842457175)
                    }
                    serializeString(code, buffer: buffer, boxed: false)
                    break
                case .emailVerificationGoogle(let token):
                    if boxed {
                        buffer.appendInt32(-611279166)
                    }
                    serializeString(token, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emailVerificationApple(let token):
                return ("emailVerificationApple", [("token", token as Any)])
                case .emailVerificationCode(let code):
                return ("emailVerificationCode", [("code", code as Any)])
                case .emailVerificationGoogle(let token):
                return ("emailVerificationGoogle", [("token", token as Any)])
    }
    }
    
        public static func parse_emailVerificationApple(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationApple(token: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerificationCode(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationCode(code: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerificationGoogle(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationGoogle(token: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmailVerifyPurpose: TypeConstructorDescription {
        case emailVerifyPurposeLoginChange
        case emailVerifyPurposeLoginSetup(phoneNumber: String, phoneCodeHash: String)
        case emailVerifyPurposePassport
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emailVerifyPurposeLoginChange:
                    if boxed {
                        buffer.appendInt32(1383932651)
                    }
                    
                    break
                case .emailVerifyPurposeLoginSetup(let phoneNumber, let phoneCodeHash):
                    if boxed {
                        buffer.appendInt32(1128644211)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    break
                case .emailVerifyPurposePassport:
                    if boxed {
                        buffer.appendInt32(-1141565819)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emailVerifyPurposeLoginChange:
                return ("emailVerifyPurposeLoginChange", [])
                case .emailVerifyPurposeLoginSetup(let phoneNumber, let phoneCodeHash):
                return ("emailVerifyPurposeLoginSetup", [("phoneNumber", phoneNumber as Any), ("phoneCodeHash", phoneCodeHash as Any)])
                case .emailVerifyPurposePassport:
                return ("emailVerifyPurposePassport", [])
    }
    }
    
        public static func parse_emailVerifyPurposeLoginChange(_ reader: BufferReader) -> EmailVerifyPurpose? {
            return Api.EmailVerifyPurpose.emailVerifyPurposeLoginChange
        }
        public static func parse_emailVerifyPurposeLoginSetup(_ reader: BufferReader) -> EmailVerifyPurpose? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmailVerifyPurpose.emailVerifyPurposeLoginSetup(phoneNumber: _1!, phoneCodeHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerifyPurposePassport(_ reader: BufferReader) -> EmailVerifyPurpose? {
            return Api.EmailVerifyPurpose.emailVerifyPurposePassport
        }
    
    }
}
public extension Api {
    enum EmojiGroup: TypeConstructorDescription {
        case emojiGroup(title: String, iconEmojiId: Int64, emoticons: [String])
        case emojiGroupGreeting(title: String, iconEmojiId: Int64, emoticons: [String])
        case emojiGroupPremium(title: String, iconEmojiId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiGroup(let title, let iconEmojiId, let emoticons):
                    if boxed {
                        buffer.appendInt32(2056961449)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt64(iconEmojiId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
                case .emojiGroupGreeting(let title, let iconEmojiId, let emoticons):
                    if boxed {
                        buffer.appendInt32(-2133693241)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt64(iconEmojiId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
                case .emojiGroupPremium(let title, let iconEmojiId):
                    if boxed {
                        buffer.appendInt32(154914612)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt64(iconEmojiId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiGroup(let title, let iconEmojiId, let emoticons):
                return ("emojiGroup", [("title", title as Any), ("iconEmojiId", iconEmojiId as Any), ("emoticons", emoticons as Any)])
                case .emojiGroupGreeting(let title, let iconEmojiId, let emoticons):
                return ("emojiGroupGreeting", [("title", title as Any), ("iconEmojiId", iconEmojiId as Any), ("emoticons", emoticons as Any)])
                case .emojiGroupPremium(let title, let iconEmojiId):
                return ("emojiGroupPremium", [("title", title as Any), ("iconEmojiId", iconEmojiId as Any)])
    }
    }
    
        public static func parse_emojiGroup(_ reader: BufferReader) -> EmojiGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [String]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiGroup.emojiGroup(title: _1!, iconEmojiId: _2!, emoticons: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiGroupGreeting(_ reader: BufferReader) -> EmojiGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [String]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiGroup.emojiGroupGreeting(title: _1!, iconEmojiId: _2!, emoticons: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiGroupPremium(_ reader: BufferReader) -> EmojiGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiGroup.emojiGroupPremium(title: _1!, iconEmojiId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiKeyword: TypeConstructorDescription {
        case emojiKeyword(keyword: String, emoticons: [String])
        case emojiKeywordDeleted(keyword: String, emoticons: [String])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiKeyword(let keyword, let emoticons):
                    if boxed {
                        buffer.appendInt32(-709641735)
                    }
                    serializeString(keyword, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
                case .emojiKeywordDeleted(let keyword, let emoticons):
                    if boxed {
                        buffer.appendInt32(594408994)
                    }
                    serializeString(keyword, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiKeyword(let keyword, let emoticons):
                return ("emojiKeyword", [("keyword", keyword as Any), ("emoticons", emoticons as Any)])
                case .emojiKeywordDeleted(let keyword, let emoticons):
                return ("emojiKeywordDeleted", [("keyword", keyword as Any), ("emoticons", emoticons as Any)])
    }
    }
    
        public static func parse_emojiKeyword(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeyword(keyword: _1!, emoticons: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiKeywordDeleted(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeywordDeleted(keyword: _1!, emoticons: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiKeywordsDifference: TypeConstructorDescription {
        case emojiKeywordsDifference(langCode: String, fromVersion: Int32, version: Int32, keywords: [Api.EmojiKeyword])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiKeywordsDifference(let langCode, let fromVersion, let version, let keywords):
                    if boxed {
                        buffer.appendInt32(1556570557)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keywords.count))
                    for item in keywords {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiKeywordsDifference(let langCode, let fromVersion, let version, let keywords):
                return ("emojiKeywordsDifference", [("langCode", langCode as Any), ("fromVersion", fromVersion as Any), ("version", version as Any), ("keywords", keywords as Any)])
    }
    }
    
        public static func parse_emojiKeywordsDifference(_ reader: BufferReader) -> EmojiKeywordsDifference? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.EmojiKeyword]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiKeyword.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.EmojiKeywordsDifference.emojiKeywordsDifference(langCode: _1!, fromVersion: _2!, version: _3!, keywords: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiLanguage: TypeConstructorDescription {
        case emojiLanguage(langCode: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiLanguage(let langCode):
                    if boxed {
                        buffer.appendInt32(-1275374751)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiLanguage(let langCode):
                return ("emojiLanguage", [("langCode", langCode as Any)])
    }
    }
    
        public static func parse_emojiLanguage(_ reader: BufferReader) -> EmojiLanguage? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiLanguage.emojiLanguage(langCode: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiList: TypeConstructorDescription {
        case emojiList(hash: Int64, documentId: [Int64])
        case emojiListNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiList(let hash, let documentId):
                    if boxed {
                        buffer.appendInt32(2048790993)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documentId.count))
                    for item in documentId {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .emojiListNotModified:
                    if boxed {
                        buffer.appendInt32(1209970170)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiList(let hash, let documentId):
                return ("emojiList", [("hash", hash as Any), ("documentId", documentId as Any)])
                case .emojiListNotModified:
                return ("emojiListNotModified", [])
    }
    }
    
        public static func parse_emojiList(_ reader: BufferReader) -> EmojiList? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiList.emojiList(hash: _1!, documentId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiListNotModified(_ reader: BufferReader) -> EmojiList? {
            return Api.EmojiList.emojiListNotModified
        }
    
    }
}
public extension Api {
    enum EmojiStatus: TypeConstructorDescription {
        case emojiStatus(flags: Int32, documentId: Int64, until: Int32?)
        case emojiStatusCollectible(flags: Int32, collectibleId: Int64, documentId: Int64, title: String, slug: String, patternDocumentId: Int64, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, until: Int32?)
        case emojiStatusEmpty
        case inputEmojiStatusCollectible(flags: Int32, collectibleId: Int64, until: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiStatus(let flags, let documentId, let until):
                    if boxed {
                        buffer.appendInt32(-402717046)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(until!, buffer: buffer, boxed: false)}
                    break
                case .emojiStatusCollectible(let flags, let collectibleId, let documentId, let title, let slug, let patternDocumentId, let centerColor, let edgeColor, let patternColor, let textColor, let until):
                    if boxed {
                        buffer.appendInt32(1904500795)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(collectibleId, buffer: buffer, boxed: false)
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    serializeInt64(patternDocumentId, buffer: buffer, boxed: false)
                    serializeInt32(centerColor, buffer: buffer, boxed: false)
                    serializeInt32(edgeColor, buffer: buffer, boxed: false)
                    serializeInt32(patternColor, buffer: buffer, boxed: false)
                    serializeInt32(textColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(until!, buffer: buffer, boxed: false)}
                    break
                case .emojiStatusEmpty:
                    if boxed {
                        buffer.appendInt32(769727150)
                    }
                    
                    break
                case .inputEmojiStatusCollectible(let flags, let collectibleId, let until):
                    if boxed {
                        buffer.appendInt32(118758847)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(collectibleId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(until!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiStatus(let flags, let documentId, let until):
                return ("emojiStatus", [("flags", flags as Any), ("documentId", documentId as Any), ("until", until as Any)])
                case .emojiStatusCollectible(let flags, let collectibleId, let documentId, let title, let slug, let patternDocumentId, let centerColor, let edgeColor, let patternColor, let textColor, let until):
                return ("emojiStatusCollectible", [("flags", flags as Any), ("collectibleId", collectibleId as Any), ("documentId", documentId as Any), ("title", title as Any), ("slug", slug as Any), ("patternDocumentId", patternDocumentId as Any), ("centerColor", centerColor as Any), ("edgeColor", edgeColor as Any), ("patternColor", patternColor as Any), ("textColor", textColor as Any), ("until", until as Any)])
                case .emojiStatusEmpty:
                return ("emojiStatusEmpty", [])
                case .inputEmojiStatusCollectible(let flags, let collectibleId, let until):
                return ("inputEmojiStatusCollectible", [("flags", flags as Any), ("collectibleId", collectibleId as Any), ("until", until as Any)])
    }
    }
    
        public static func parse_emojiStatus(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiStatus.emojiStatus(flags: _1!, documentId: _2!, until: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiStatusCollectible(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_11 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 0) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.EmojiStatus.emojiStatusCollectible(flags: _1!, collectibleId: _2!, documentId: _3!, title: _4!, slug: _5!, patternDocumentId: _6!, centerColor: _7!, edgeColor: _8!, patternColor: _9!, textColor: _10!, until: _11)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiStatusEmpty(_ reader: BufferReader) -> EmojiStatus? {
            return Api.EmojiStatus.emojiStatusEmpty
        }
        public static func parse_inputEmojiStatusCollectible(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiStatus.inputEmojiStatusCollectible(flags: _1!, collectibleId: _2!, until: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiURL: TypeConstructorDescription {
        case emojiURL(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiURL(let url):
                    if boxed {
                        buffer.appendInt32(-1519029347)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiURL(let url):
                return ("emojiURL", [("url", url as Any)])
    }
    }
    
        public static func parse_emojiURL(_ reader: BufferReader) -> EmojiURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiURL.emojiURL(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EncryptedChat: TypeConstructorDescription {
        case encryptedChat(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64)
        case encryptedChatDiscarded(flags: Int32, id: Int32)
        case encryptedChatEmpty(id: Int32)
        case encryptedChatRequested(flags: Int32, folderId: Int32?, id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gA: Buffer)
        case encryptedChatWaiting(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1643173063)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gAOrB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .encryptedChatDiscarded(let flags, let id):
                    if boxed {
                        buffer.appendInt32(505183301)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .encryptedChatEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-1417756512)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .encryptedChatRequested(let flags, let folderId, let id, let accessHash, let date, let adminId, let participantId, let gA):
                    if boxed {
                        buffer.appendInt32(1223809356)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    break
                case .encryptedChatWaiting(let id, let accessHash, let date, let adminId, let participantId):
                    if boxed {
                        buffer.appendInt32(1722964307)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                return ("encryptedChat", [("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("gAOrB", gAOrB as Any), ("keyFingerprint", keyFingerprint as Any)])
                case .encryptedChatDiscarded(let flags, let id):
                return ("encryptedChatDiscarded", [("flags", flags as Any), ("id", id as Any)])
                case .encryptedChatEmpty(let id):
                return ("encryptedChatEmpty", [("id", id as Any)])
                case .encryptedChatRequested(let flags, let folderId, let id, let accessHash, let date, let adminId, let participantId, let gA):
                return ("encryptedChatRequested", [("flags", flags as Any), ("folderId", folderId as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("gA", gA as Any)])
                case .encryptedChatWaiting(let id, let accessHash, let date, let adminId, let participantId):
                return ("encryptedChatWaiting", [("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any)])
    }
    }
    
        public static func parse_encryptedChat(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.EncryptedChat.encryptedChat(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!, gAOrB: _6!, keyFingerprint: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatDiscarded(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EncryptedChat.encryptedChatDiscarded(flags: _1!, id: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatEmpty(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.EncryptedChat.encryptedChatEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatRequested(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: Buffer?
            _8 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.EncryptedChat.encryptedChatRequested(flags: _1!, folderId: _2, id: _3!, accessHash: _4!, date: _5!, adminId: _6!, participantId: _7!, gA: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatWaiting(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.EncryptedChat.encryptedChatWaiting(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
