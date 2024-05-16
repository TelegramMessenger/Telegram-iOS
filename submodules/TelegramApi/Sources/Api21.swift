public extension Api {
    enum RequestPeerType: TypeConstructorDescription {
        case requestPeerTypeBroadcast(flags: Int32, hasUsername: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?)
        case requestPeerTypeChat(flags: Int32, hasUsername: Api.Bool?, forum: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?)
        case requestPeerTypeUser(flags: Int32, bot: Api.Bool?, premium: Api.Bool?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .requestPeerTypeBroadcast(let flags, let hasUsername, let userAdminRights, let botAdminRights):
                    if boxed {
                        buffer.appendInt32(865857388)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {hasUsername!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {userAdminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {botAdminRights!.serialize(buffer, true)}
                    break
                case .requestPeerTypeChat(let flags, let hasUsername, let forum, let userAdminRights, let botAdminRights):
                    if boxed {
                        buffer.appendInt32(-906990053)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {hasUsername!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {forum!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {userAdminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {botAdminRights!.serialize(buffer, true)}
                    break
                case .requestPeerTypeUser(let flags, let bot, let premium):
                    if boxed {
                        buffer.appendInt32(1597737472)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {bot!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {premium!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .requestPeerTypeBroadcast(let flags, let hasUsername, let userAdminRights, let botAdminRights):
                return ("requestPeerTypeBroadcast", [("flags", flags as Any), ("hasUsername", hasUsername as Any), ("userAdminRights", userAdminRights as Any), ("botAdminRights", botAdminRights as Any)])
                case .requestPeerTypeChat(let flags, let hasUsername, let forum, let userAdminRights, let botAdminRights):
                return ("requestPeerTypeChat", [("flags", flags as Any), ("hasUsername", hasUsername as Any), ("forum", forum as Any), ("userAdminRights", userAdminRights as Any), ("botAdminRights", botAdminRights as Any)])
                case .requestPeerTypeUser(let flags, let bot, let premium):
                return ("requestPeerTypeUser", [("flags", flags as Any), ("bot", bot as Any), ("premium", premium as Any)])
    }
    }
    
        public static func parse_requestPeerTypeBroadcast(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _4: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.RequestPeerType.requestPeerTypeBroadcast(flags: _1!, hasUsername: _2, userAdminRights: _3, botAdminRights: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_requestPeerTypeChat(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _4: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _5: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 4) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.RequestPeerType.requestPeerTypeChat(flags: _1!, hasUsername: _2, forum: _3, userAdminRights: _4, botAdminRights: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_requestPeerTypeUser(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.RequestPeerType.requestPeerTypeUser(flags: _1!, bot: _2, premium: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum RequestedPeer: TypeConstructorDescription {
        case requestedPeerChannel(flags: Int32, channelId: Int64, title: String?, username: String?, photo: Api.Photo?)
        case requestedPeerChat(flags: Int32, chatId: Int64, title: String?, photo: Api.Photo?)
        case requestedPeerUser(flags: Int32, userId: Int64, firstName: String?, lastName: String?, username: String?, photo: Api.Photo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .requestedPeerChannel(let flags, let channelId, let title, let username, let photo):
                    if boxed {
                        buffer.appendInt32(-1952185372)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    break
                case .requestedPeerChat(let flags, let chatId, let title, let photo):
                    if boxed {
                        buffer.appendInt32(1929860175)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    break
                case .requestedPeerUser(let flags, let userId, let firstName, let lastName, let username, let photo):
                    if boxed {
                        buffer.appendInt32(-701500310)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .requestedPeerChannel(let flags, let channelId, let title, let username, let photo):
                return ("requestedPeerChannel", [("flags", flags as Any), ("channelId", channelId as Any), ("title", title as Any), ("username", username as Any), ("photo", photo as Any)])
                case .requestedPeerChat(let flags, let chatId, let title, let photo):
                return ("requestedPeerChat", [("flags", flags as Any), ("chatId", chatId as Any), ("title", title as Any), ("photo", photo as Any)])
                case .requestedPeerUser(let flags, let userId, let firstName, let lastName, let username, let photo):
                return ("requestedPeerUser", [("flags", flags as Any), ("userId", userId as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("username", username as Any), ("photo", photo as Any)])
    }
    }
    
        public static func parse_requestedPeerChannel(_ reader: BufferReader) -> RequestedPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.RequestedPeer.requestedPeerChannel(flags: _1!, channelId: _2!, title: _3, username: _4, photo: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_requestedPeerChat(_ reader: BufferReader) -> RequestedPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.RequestedPeer.requestedPeerChat(flags: _1!, chatId: _2!, title: _3, photo: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_requestedPeerUser(_ reader: BufferReader) -> RequestedPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.RequestedPeer.requestedPeerUser(flags: _1!, userId: _2!, firstName: _3, lastName: _4, username: _5, photo: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum RestrictionReason: TypeConstructorDescription {
        case restrictionReason(platform: String, reason: String, text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .restrictionReason(let platform, let reason, let text):
                    if boxed {
                        buffer.appendInt32(-797791052)
                    }
                    serializeString(platform, buffer: buffer, boxed: false)
                    serializeString(reason, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .restrictionReason(let platform, let reason, let text):
                return ("restrictionReason", [("platform", platform as Any), ("reason", reason as Any), ("text", text as Any)])
    }
    }
    
        public static func parse_restrictionReason(_ reader: BufferReader) -> RestrictionReason? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.RestrictionReason.restrictionReason(platform: _1!, reason: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum RichText: TypeConstructorDescription {
        case textAnchor(text: Api.RichText, name: String)
        case textBold(text: Api.RichText)
        case textConcat(texts: [Api.RichText])
        case textEmail(text: Api.RichText, email: String)
        case textEmpty
        case textFixed(text: Api.RichText)
        case textImage(documentId: Int64, w: Int32, h: Int32)
        case textItalic(text: Api.RichText)
        case textMarked(text: Api.RichText)
        case textPhone(text: Api.RichText, phone: String)
        case textPlain(text: String)
        case textStrike(text: Api.RichText)
        case textSubscript(text: Api.RichText)
        case textSuperscript(text: Api.RichText)
        case textUnderline(text: Api.RichText)
        case textUrl(text: Api.RichText, url: String, webpageId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .textAnchor(let text, let name):
                    if boxed {
                        buffer.appendInt32(894777186)
                    }
                    text.serialize(buffer, true)
                    serializeString(name, buffer: buffer, boxed: false)
                    break
                case .textBold(let text):
                    if boxed {
                        buffer.appendInt32(1730456516)
                    }
                    text.serialize(buffer, true)
                    break
                case .textConcat(let texts):
                    if boxed {
                        buffer.appendInt32(2120376535)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(texts.count))
                    for item in texts {
                        item.serialize(buffer, true)
                    }
                    break
                case .textEmail(let text, let email):
                    if boxed {
                        buffer.appendInt32(-564523562)
                    }
                    text.serialize(buffer, true)
                    serializeString(email, buffer: buffer, boxed: false)
                    break
                case .textEmpty:
                    if boxed {
                        buffer.appendInt32(-599948721)
                    }
                    
                    break
                case .textFixed(let text):
                    if boxed {
                        buffer.appendInt32(1816074681)
                    }
                    text.serialize(buffer, true)
                    break
                case .textImage(let documentId, let w, let h):
                    if boxed {
                        buffer.appendInt32(136105807)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .textItalic(let text):
                    if boxed {
                        buffer.appendInt32(-653089380)
                    }
                    text.serialize(buffer, true)
                    break
                case .textMarked(let text):
                    if boxed {
                        buffer.appendInt32(55281185)
                    }
                    text.serialize(buffer, true)
                    break
                case .textPhone(let text, let phone):
                    if boxed {
                        buffer.appendInt32(483104362)
                    }
                    text.serialize(buffer, true)
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
                case .textPlain(let text):
                    if boxed {
                        buffer.appendInt32(1950782688)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .textStrike(let text):
                    if boxed {
                        buffer.appendInt32(-1678197867)
                    }
                    text.serialize(buffer, true)
                    break
                case .textSubscript(let text):
                    if boxed {
                        buffer.appendInt32(-311786236)
                    }
                    text.serialize(buffer, true)
                    break
                case .textSuperscript(let text):
                    if boxed {
                        buffer.appendInt32(-939827711)
                    }
                    text.serialize(buffer, true)
                    break
                case .textUnderline(let text):
                    if boxed {
                        buffer.appendInt32(-1054465340)
                    }
                    text.serialize(buffer, true)
                    break
                case .textUrl(let text, let url, let webpageId):
                    if boxed {
                        buffer.appendInt32(1009288385)
                    }
                    text.serialize(buffer, true)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(webpageId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .textAnchor(let text, let name):
                return ("textAnchor", [("text", text as Any), ("name", name as Any)])
                case .textBold(let text):
                return ("textBold", [("text", text as Any)])
                case .textConcat(let texts):
                return ("textConcat", [("texts", texts as Any)])
                case .textEmail(let text, let email):
                return ("textEmail", [("text", text as Any), ("email", email as Any)])
                case .textEmpty:
                return ("textEmpty", [])
                case .textFixed(let text):
                return ("textFixed", [("text", text as Any)])
                case .textImage(let documentId, let w, let h):
                return ("textImage", [("documentId", documentId as Any), ("w", w as Any), ("h", h as Any)])
                case .textItalic(let text):
                return ("textItalic", [("text", text as Any)])
                case .textMarked(let text):
                return ("textMarked", [("text", text as Any)])
                case .textPhone(let text, let phone):
                return ("textPhone", [("text", text as Any), ("phone", phone as Any)])
                case .textPlain(let text):
                return ("textPlain", [("text", text as Any)])
                case .textStrike(let text):
                return ("textStrike", [("text", text as Any)])
                case .textSubscript(let text):
                return ("textSubscript", [("text", text as Any)])
                case .textSuperscript(let text):
                return ("textSuperscript", [("text", text as Any)])
                case .textUnderline(let text):
                return ("textUnderline", [("text", text as Any)])
                case .textUrl(let text, let url, let webpageId):
                return ("textUrl", [("text", text as Any), ("url", url as Any), ("webpageId", webpageId as Any)])
    }
    }
    
        public static func parse_textAnchor(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RichText.textAnchor(text: _1!, name: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_textBold(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textBold(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textConcat(_ reader: BufferReader) -> RichText? {
            var _1: [Api.RichText]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RichText.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textConcat(texts: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textEmail(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RichText.textEmail(text: _1!, email: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_textEmpty(_ reader: BufferReader) -> RichText? {
            return Api.RichText.textEmpty
        }
        public static func parse_textFixed(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textFixed(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textImage(_ reader: BufferReader) -> RichText? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.RichText.textImage(documentId: _1!, w: _2!, h: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_textItalic(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textItalic(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textMarked(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textMarked(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textPhone(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RichText.textPhone(text: _1!, phone: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_textPlain(_ reader: BufferReader) -> RichText? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textPlain(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textStrike(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textStrike(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textSubscript(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textSubscript(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textSuperscript(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textSuperscript(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textUnderline(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textUnderline(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textUrl(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.RichText.textUrl(text: _1!, url: _2!, webpageId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SavedContact: TypeConstructorDescription {
        case savedPhoneContact(phone: String, firstName: String, lastName: String, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedPhoneContact(let phone, let firstName, let lastName, let date):
                    if boxed {
                        buffer.appendInt32(289586518)
                    }
                    serializeString(phone, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedPhoneContact(let phone, let firstName, let lastName, let date):
                return ("savedPhoneContact", [("phone", phone as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("date", date as Any)])
    }
    }
    
        public static func parse_savedPhoneContact(_ reader: BufferReader) -> SavedContact? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SavedContact.savedPhoneContact(phone: _1!, firstName: _2!, lastName: _3!, date: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SavedDialog: TypeConstructorDescription {
        case savedDialog(flags: Int32, peer: Api.Peer, topMessage: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedDialog(let flags, let peer, let topMessage):
                    if boxed {
                        buffer.appendInt32(-1115174036)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedDialog(let flags, let peer, let topMessage):
                return ("savedDialog", [("flags", flags as Any), ("peer", peer as Any), ("topMessage", topMessage as Any)])
    }
    }
    
        public static func parse_savedDialog(_ reader: BufferReader) -> SavedDialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SavedDialog.savedDialog(flags: _1!, peer: _2!, topMessage: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SavedReactionTag: TypeConstructorDescription {
        case savedReactionTag(flags: Int32, reaction: Api.Reaction, title: String?, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedReactionTag(let flags, let reaction, let title, let count):
                    if boxed {
                        buffer.appendInt32(-881854424)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedReactionTag(let flags, let reaction, let title, let count):
                return ("savedReactionTag", [("flags", flags as Any), ("reaction", reaction as Any), ("title", title as Any), ("count", count as Any)])
    }
    }
    
        public static func parse_savedReactionTag(_ reader: BufferReader) -> SavedReactionTag? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Reaction?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SavedReactionTag.savedReactionTag(flags: _1!, reaction: _2!, title: _3, count: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SearchResultsCalendarPeriod: TypeConstructorDescription {
        case searchResultsCalendarPeriod(date: Int32, minMsgId: Int32, maxMsgId: Int32, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .searchResultsCalendarPeriod(let date, let minMsgId, let maxMsgId, let count):
                    if boxed {
                        buffer.appendInt32(-911191137)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(minMsgId, buffer: buffer, boxed: false)
                    serializeInt32(maxMsgId, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .searchResultsCalendarPeriod(let date, let minMsgId, let maxMsgId, let count):
                return ("searchResultsCalendarPeriod", [("date", date as Any), ("minMsgId", minMsgId as Any), ("maxMsgId", maxMsgId as Any), ("count", count as Any)])
    }
    }
    
        public static func parse_searchResultsCalendarPeriod(_ reader: BufferReader) -> SearchResultsCalendarPeriod? {
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
                return Api.SearchResultsCalendarPeriod.searchResultsCalendarPeriod(date: _1!, minMsgId: _2!, maxMsgId: _3!, count: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SearchResultsPosition: TypeConstructorDescription {
        case searchResultPosition(msgId: Int32, date: Int32, offset: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .searchResultPosition(let msgId, let date, let offset):
                    if boxed {
                        buffer.appendInt32(2137295719)
                    }
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .searchResultPosition(let msgId, let date, let offset):
                return ("searchResultPosition", [("msgId", msgId as Any), ("date", date as Any), ("offset", offset as Any)])
    }
    }
    
        public static func parse_searchResultPosition(_ reader: BufferReader) -> SearchResultsPosition? {
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
                return Api.SearchResultsPosition.searchResultPosition(msgId: _1!, date: _2!, offset: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureCredentialsEncrypted: TypeConstructorDescription {
        case secureCredentialsEncrypted(data: Buffer, hash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureCredentialsEncrypted(let data, let hash, let secret):
                    if boxed {
                        buffer.appendInt32(871426631)
                    }
                    serializeBytes(data, buffer: buffer, boxed: false)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureCredentialsEncrypted(let data, let hash, let secret):
                return ("secureCredentialsEncrypted", [("data", data as Any), ("hash", hash as Any), ("secret", secret as Any)])
    }
    }
    
        public static func parse_secureCredentialsEncrypted(_ reader: BufferReader) -> SecureCredentialsEncrypted? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureCredentialsEncrypted.secureCredentialsEncrypted(data: _1!, hash: _2!, secret: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureData: TypeConstructorDescription {
        case secureData(data: Buffer, dataHash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureData(let data, let dataHash, let secret):
                    if boxed {
                        buffer.appendInt32(-1964327229)
                    }
                    serializeBytes(data, buffer: buffer, boxed: false)
                    serializeBytes(dataHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureData(let data, let dataHash, let secret):
                return ("secureData", [("data", data as Any), ("dataHash", dataHash as Any), ("secret", secret as Any)])
    }
    }
    
        public static func parse_secureData(_ reader: BufferReader) -> SecureData? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureData.secureData(data: _1!, dataHash: _2!, secret: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureFile: TypeConstructorDescription {
        case secureFile(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, date: Int32, fileHash: Buffer, secret: Buffer)
        case secureFileEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureFile(let id, let accessHash, let size, let dcId, let date, let fileHash, let secret):
                    if boxed {
                        buffer.appendInt32(2097791614)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt64(size, buffer: buffer, boxed: false)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
                case .secureFileEmpty:
                    if boxed {
                        buffer.appendInt32(1679398724)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureFile(let id, let accessHash, let size, let dcId, let date, let fileHash, let secret):
                return ("secureFile", [("id", id as Any), ("accessHash", accessHash as Any), ("size", size as Any), ("dcId", dcId as Any), ("date", date as Any), ("fileHash", fileHash as Any), ("secret", secret as Any)])
                case .secureFileEmpty:
                return ("secureFileEmpty", [])
    }
    }
    
        public static func parse_secureFile(_ reader: BufferReader) -> SecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Buffer?
            _7 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.SecureFile.secureFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, date: _5!, fileHash: _6!, secret: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_secureFileEmpty(_ reader: BufferReader) -> SecureFile? {
            return Api.SecureFile.secureFileEmpty
        }
    
    }
}
