public extension Api {
    enum RestrictionReason: TypeConstructorDescription {
        public class Cons_restrictionReason {
            public var platform: String
            public var reason: String
            public var text: String
            public init(platform: String, reason: String, text: String) {
                self.platform = platform
                self.reason = reason
                self.text = text
            }
        }
        case restrictionReason(Cons_restrictionReason)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .restrictionReason(let _data):
                if boxed {
                    buffer.appendInt32(-797791052)
                }
                serializeString(_data.platform, buffer: buffer, boxed: false)
                serializeString(_data.reason, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .restrictionReason(let _data):
                return ("restrictionReason", [("platform", _data.platform as Any), ("reason", _data.reason as Any), ("text", _data.text as Any)])
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
                return Api.RestrictionReason.restrictionReason(Cons_restrictionReason(platform: _1!, reason: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum RichText: TypeConstructorDescription {
        public class Cons_textAnchor {
            public var text: Api.RichText
            public var name: String
            public init(text: Api.RichText, name: String) {
                self.text = text
                self.name = name
            }
        }
        public class Cons_textBold {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textConcat {
            public var texts: [Api.RichText]
            public init(texts: [Api.RichText]) {
                self.texts = texts
            }
        }
        public class Cons_textEmail {
            public var text: Api.RichText
            public var email: String
            public init(text: Api.RichText, email: String) {
                self.text = text
                self.email = email
            }
        }
        public class Cons_textFixed {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textImage {
            public var documentId: Int64
            public var w: Int32
            public var h: Int32
            public init(documentId: Int64, w: Int32, h: Int32) {
                self.documentId = documentId
                self.w = w
                self.h = h
            }
        }
        public class Cons_textItalic {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textMarked {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textPhone {
            public var text: Api.RichText
            public var phone: String
            public init(text: Api.RichText, phone: String) {
                self.text = text
                self.phone = phone
            }
        }
        public class Cons_textPlain {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_textStrike {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textSubscript {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textSuperscript {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textUnderline {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textUrl {
            public var text: Api.RichText
            public var url: String
            public var webpageId: Int64
            public init(text: Api.RichText, url: String, webpageId: Int64) {
                self.text = text
                self.url = url
                self.webpageId = webpageId
            }
        }
        case textAnchor(Cons_textAnchor)
        case textBold(Cons_textBold)
        case textConcat(Cons_textConcat)
        case textEmail(Cons_textEmail)
        case textEmpty
        case textFixed(Cons_textFixed)
        case textImage(Cons_textImage)
        case textItalic(Cons_textItalic)
        case textMarked(Cons_textMarked)
        case textPhone(Cons_textPhone)
        case textPlain(Cons_textPlain)
        case textStrike(Cons_textStrike)
        case textSubscript(Cons_textSubscript)
        case textSuperscript(Cons_textSuperscript)
        case textUnderline(Cons_textUnderline)
        case textUrl(Cons_textUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .textAnchor(let _data):
                if boxed {
                    buffer.appendInt32(894777186)
                }
                _data.text.serialize(buffer, true)
                serializeString(_data.name, buffer: buffer, boxed: false)
                break
            case .textBold(let _data):
                if boxed {
                    buffer.appendInt32(1730456516)
                }
                _data.text.serialize(buffer, true)
                break
            case .textConcat(let _data):
                if boxed {
                    buffer.appendInt32(2120376535)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.texts.count))
                for item in _data.texts {
                    item.serialize(buffer, true)
                }
                break
            case .textEmail(let _data):
                if boxed {
                    buffer.appendInt32(-564523562)
                }
                _data.text.serialize(buffer, true)
                serializeString(_data.email, buffer: buffer, boxed: false)
                break
            case .textEmpty:
                if boxed {
                    buffer.appendInt32(-599948721)
                }
                break
            case .textFixed(let _data):
                if boxed {
                    buffer.appendInt32(1816074681)
                }
                _data.text.serialize(buffer, true)
                break
            case .textImage(let _data):
                if boxed {
                    buffer.appendInt32(136105807)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                break
            case .textItalic(let _data):
                if boxed {
                    buffer.appendInt32(-653089380)
                }
                _data.text.serialize(buffer, true)
                break
            case .textMarked(let _data):
                if boxed {
                    buffer.appendInt32(55281185)
                }
                _data.text.serialize(buffer, true)
                break
            case .textPhone(let _data):
                if boxed {
                    buffer.appendInt32(483104362)
                }
                _data.text.serialize(buffer, true)
                serializeString(_data.phone, buffer: buffer, boxed: false)
                break
            case .textPlain(let _data):
                if boxed {
                    buffer.appendInt32(1950782688)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .textStrike(let _data):
                if boxed {
                    buffer.appendInt32(-1678197867)
                }
                _data.text.serialize(buffer, true)
                break
            case .textSubscript(let _data):
                if boxed {
                    buffer.appendInt32(-311786236)
                }
                _data.text.serialize(buffer, true)
                break
            case .textSuperscript(let _data):
                if boxed {
                    buffer.appendInt32(-939827711)
                }
                _data.text.serialize(buffer, true)
                break
            case .textUnderline(let _data):
                if boxed {
                    buffer.appendInt32(-1054465340)
                }
                _data.text.serialize(buffer, true)
                break
            case .textUrl(let _data):
                if boxed {
                    buffer.appendInt32(1009288385)
                }
                _data.text.serialize(buffer, true)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.webpageId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .textAnchor(let _data):
                return ("textAnchor", [("text", _data.text as Any), ("name", _data.name as Any)])
            case .textBold(let _data):
                return ("textBold", [("text", _data.text as Any)])
            case .textConcat(let _data):
                return ("textConcat", [("texts", _data.texts as Any)])
            case .textEmail(let _data):
                return ("textEmail", [("text", _data.text as Any), ("email", _data.email as Any)])
            case .textEmpty:
                return ("textEmpty", [])
            case .textFixed(let _data):
                return ("textFixed", [("text", _data.text as Any)])
            case .textImage(let _data):
                return ("textImage", [("documentId", _data.documentId as Any), ("w", _data.w as Any), ("h", _data.h as Any)])
            case .textItalic(let _data):
                return ("textItalic", [("text", _data.text as Any)])
            case .textMarked(let _data):
                return ("textMarked", [("text", _data.text as Any)])
            case .textPhone(let _data):
                return ("textPhone", [("text", _data.text as Any), ("phone", _data.phone as Any)])
            case .textPlain(let _data):
                return ("textPlain", [("text", _data.text as Any)])
            case .textStrike(let _data):
                return ("textStrike", [("text", _data.text as Any)])
            case .textSubscript(let _data):
                return ("textSubscript", [("text", _data.text as Any)])
            case .textSuperscript(let _data):
                return ("textSuperscript", [("text", _data.text as Any)])
            case .textUnderline(let _data):
                return ("textUnderline", [("text", _data.text as Any)])
            case .textUrl(let _data):
                return ("textUrl", [("text", _data.text as Any), ("url", _data.url as Any), ("webpageId", _data.webpageId as Any)])
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
                return Api.RichText.textAnchor(Cons_textAnchor(text: _1!, name: _2!))
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
                return Api.RichText.textBold(Cons_textBold(text: _1!))
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
                return Api.RichText.textConcat(Cons_textConcat(texts: _1!))
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
                return Api.RichText.textEmail(Cons_textEmail(text: _1!, email: _2!))
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
                return Api.RichText.textFixed(Cons_textFixed(text: _1!))
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
                return Api.RichText.textImage(Cons_textImage(documentId: _1!, w: _2!, h: _3!))
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
                return Api.RichText.textItalic(Cons_textItalic(text: _1!))
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
                return Api.RichText.textMarked(Cons_textMarked(text: _1!))
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
                return Api.RichText.textPhone(Cons_textPhone(text: _1!, phone: _2!))
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
                return Api.RichText.textPlain(Cons_textPlain(text: _1!))
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
                return Api.RichText.textStrike(Cons_textStrike(text: _1!))
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
                return Api.RichText.textSubscript(Cons_textSubscript(text: _1!))
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
                return Api.RichText.textSuperscript(Cons_textSuperscript(text: _1!))
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
                return Api.RichText.textUnderline(Cons_textUnderline(text: _1!))
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
                return Api.RichText.textUrl(Cons_textUrl(text: _1!, url: _2!, webpageId: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SavedContact: TypeConstructorDescription {
        public class Cons_savedPhoneContact {
            public var phone: String
            public var firstName: String
            public var lastName: String
            public var date: Int32
            public init(phone: String, firstName: String, lastName: String, date: Int32) {
                self.phone = phone
                self.firstName = firstName
                self.lastName = lastName
                self.date = date
            }
        }
        case savedPhoneContact(Cons_savedPhoneContact)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedPhoneContact(let _data):
                if boxed {
                    buffer.appendInt32(289586518)
                }
                serializeString(_data.phone, buffer: buffer, boxed: false)
                serializeString(_data.firstName, buffer: buffer, boxed: false)
                serializeString(_data.lastName, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedPhoneContact(let _data):
                return ("savedPhoneContact", [("phone", _data.phone as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("date", _data.date as Any)])
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
                return Api.SavedContact.savedPhoneContact(Cons_savedPhoneContact(phone: _1!, firstName: _2!, lastName: _3!, date: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum SavedDialog: TypeConstructorDescription {
        public class Cons_monoForumDialog {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMessage: Int32
            public var readInboxMaxId: Int32
            public var readOutboxMaxId: Int32
            public var unreadCount: Int32
            public var unreadReactionsCount: Int32
            public var draft: Api.DraftMessage?
            public init(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadReactionsCount: Int32, draft: Api.DraftMessage?) {
                self.flags = flags
                self.peer = peer
                self.topMessage = topMessage
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.unreadReactionsCount = unreadReactionsCount
                self.draft = draft
            }
        }
        public class Cons_savedDialog {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMessage: Int32
            public init(flags: Int32, peer: Api.Peer, topMessage: Int32) {
                self.flags = flags
                self.peer = peer
                self.topMessage = topMessage
            }
        }
        case monoForumDialog(Cons_monoForumDialog)
        case savedDialog(Cons_savedDialog)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .monoForumDialog(let _data):
                if boxed {
                    buffer.appendInt32(1681948327)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMessage, buffer: buffer, boxed: false)
                serializeInt32(_data.readInboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.readOutboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadReactionsCount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.draft!.serialize(buffer, true)
                }
                break
            case .savedDialog(let _data):
                if boxed {
                    buffer.appendInt32(-1115174036)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMessage, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .monoForumDialog(let _data):
                return ("monoForumDialog", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("topMessage", _data.topMessage as Any), ("readInboxMaxId", _data.readInboxMaxId as Any), ("readOutboxMaxId", _data.readOutboxMaxId as Any), ("unreadCount", _data.unreadCount as Any), ("unreadReactionsCount", _data.unreadReactionsCount as Any), ("draft", _data.draft as Any)])
            case .savedDialog(let _data):
                return ("savedDialog", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("topMessage", _data.topMessage as Any)])
            }
        }

        public static func parse_monoForumDialog(_ reader: BufferReader) -> SavedDialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.DraftMessage?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.DraftMessage
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.SavedDialog.monoForumDialog(Cons_monoForumDialog(flags: _1!, peer: _2!, topMessage: _3!, readInboxMaxId: _4!, readOutboxMaxId: _5!, unreadCount: _6!, unreadReactionsCount: _7!, draft: _8))
            }
            else {
                return nil
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
                return Api.SavedDialog.savedDialog(Cons_savedDialog(flags: _1!, peer: _2!, topMessage: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SavedReactionTag: TypeConstructorDescription {
        public class Cons_savedReactionTag {
            public var flags: Int32
            public var reaction: Api.Reaction
            public var title: String?
            public var count: Int32
            public init(flags: Int32, reaction: Api.Reaction, title: String?, count: Int32) {
                self.flags = flags
                self.reaction = reaction
                self.title = title
                self.count = count
            }
        }
        case savedReactionTag(Cons_savedReactionTag)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedReactionTag(let _data):
                if boxed {
                    buffer.appendInt32(-881854424)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.reaction.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedReactionTag(let _data):
                return ("savedReactionTag", [("flags", _data.flags as Any), ("reaction", _data.reaction as Any), ("title", _data.title as Any), ("count", _data.count as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SavedReactionTag.savedReactionTag(Cons_savedReactionTag(flags: _1!, reaction: _2!, title: _3, count: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SavedStarGift: TypeConstructorDescription {
        public class Cons_savedStarGift {
            public var flags: Int32
            public var fromId: Api.Peer?
            public var date: Int32
            public var gift: Api.StarGift
            public var message: Api.TextWithEntities?
            public var msgId: Int32?
            public var savedId: Int64?
            public var convertStars: Int64?
            public var upgradeStars: Int64?
            public var canExportAt: Int32?
            public var transferStars: Int64?
            public var canTransferAt: Int32?
            public var canResellAt: Int32?
            public var collectionId: [Int32]?
            public var prepaidUpgradeHash: String?
            public var dropOriginalDetailsStars: Int64?
            public var giftNum: Int32?
            public var canCraftAt: Int32?
            public init(flags: Int32, fromId: Api.Peer?, date: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, msgId: Int32?, savedId: Int64?, convertStars: Int64?, upgradeStars: Int64?, canExportAt: Int32?, transferStars: Int64?, canTransferAt: Int32?, canResellAt: Int32?, collectionId: [Int32]?, prepaidUpgradeHash: String?, dropOriginalDetailsStars: Int64?, giftNum: Int32?, canCraftAt: Int32?) {
                self.flags = flags
                self.fromId = fromId
                self.date = date
                self.gift = gift
                self.message = message
                self.msgId = msgId
                self.savedId = savedId
                self.convertStars = convertStars
                self.upgradeStars = upgradeStars
                self.canExportAt = canExportAt
                self.transferStars = transferStars
                self.canTransferAt = canTransferAt
                self.canResellAt = canResellAt
                self.collectionId = collectionId
                self.prepaidUpgradeHash = prepaidUpgradeHash
                self.dropOriginalDetailsStars = dropOriginalDetailsStars
                self.giftNum = giftNum
                self.canCraftAt = canCraftAt
            }
        }
        case savedStarGift(Cons_savedStarGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedStarGift(let _data):
                if boxed {
                    buffer.appendInt32(1105150972)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.gift.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.msgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt64(_data.savedId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.convertStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt64(_data.upgradeStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.canExportAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.transferStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt32(_data.canTransferAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeInt32(_data.canResellAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.collectionId!.count))
                    for item in _data.collectionId! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.prepaidUpgradeHash!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    serializeInt64(_data.dropOriginalDetailsStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 19) != 0 {
                    serializeInt32(_data.giftNum!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    serializeInt32(_data.canCraftAt!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedStarGift(let _data):
                return ("savedStarGift", [("flags", _data.flags as Any), ("fromId", _data.fromId as Any), ("date", _data.date as Any), ("gift", _data.gift as Any), ("message", _data.message as Any), ("msgId", _data.msgId as Any), ("savedId", _data.savedId as Any), ("convertStars", _data.convertStars as Any), ("upgradeStars", _data.upgradeStars as Any), ("canExportAt", _data.canExportAt as Any), ("transferStars", _data.transferStars as Any), ("canTransferAt", _data.canTransferAt as Any), ("canResellAt", _data.canResellAt as Any), ("collectionId", _data.collectionId as Any), ("prepaidUpgradeHash", _data.prepaidUpgradeHash as Any), ("dropOriginalDetailsStars", _data.dropOriginalDetailsStars as Any), ("giftNum", _data.giftNum as Any), ("canCraftAt", _data.canCraftAt as Any)])
            }
        }

        public static func parse_savedStarGift(_ reader: BufferReader) -> SavedStarGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.StarGift?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = reader.readInt64()
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 6) != 0 {
                _9 = reader.readInt64()
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {
                _11 = reader.readInt64()
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {
                _12 = reader.readInt32()
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {
                _13 = reader.readInt32()
            }
            var _14: [Int32]?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let _ = reader.readInt32() {
                    _14 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _15: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _15 = parseString(reader)
            }
            var _16: Int64?
            if Int(_1!) & Int(1 << 18) != 0 {
                _16 = reader.readInt64()
            }
            var _17: Int32?
            if Int(_1!) & Int(1 << 19) != 0 {
                _17 = reader.readInt32()
            }
            var _18: Int32?
            if Int(_1!) & Int(1 << 20) != 0 {
                _18 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 7) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 8) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 13) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 14) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 15) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 16) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 18) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 19) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 20) == 0) || _18 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 {
                return Api.SavedStarGift.savedStarGift(Cons_savedStarGift(flags: _1!, fromId: _2, date: _3!, gift: _4!, message: _5, msgId: _6, savedId: _7, convertStars: _8, upgradeStars: _9, canExportAt: _10, transferStars: _11, canTransferAt: _12, canResellAt: _13, collectionId: _14, prepaidUpgradeHash: _15, dropOriginalDetailsStars: _16, giftNum: _17, canCraftAt: _18))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SearchPostsFlood: TypeConstructorDescription {
        public class Cons_searchPostsFlood {
            public var flags: Int32
            public var totalDaily: Int32
            public var remains: Int32
            public var waitTill: Int32?
            public var starsAmount: Int64
            public init(flags: Int32, totalDaily: Int32, remains: Int32, waitTill: Int32?, starsAmount: Int64) {
                self.flags = flags
                self.totalDaily = totalDaily
                self.remains = remains
                self.waitTill = waitTill
                self.starsAmount = starsAmount
            }
        }
        case searchPostsFlood(Cons_searchPostsFlood)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchPostsFlood(let _data):
                if boxed {
                    buffer.appendInt32(1040931690)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.totalDaily, buffer: buffer, boxed: false)
                serializeInt32(_data.remains, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.waitTill!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.starsAmount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .searchPostsFlood(let _data):
                return ("searchPostsFlood", [("flags", _data.flags as Any), ("totalDaily", _data.totalDaily as Any), ("remains", _data.remains as Any), ("waitTill", _data.waitTill as Any), ("starsAmount", _data.starsAmount as Any)])
            }
        }

        public static func parse_searchPostsFlood(_ reader: BufferReader) -> SearchPostsFlood? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.SearchPostsFlood.searchPostsFlood(Cons_searchPostsFlood(flags: _1!, totalDaily: _2!, remains: _3!, waitTill: _4, starsAmount: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SearchResultsCalendarPeriod: TypeConstructorDescription {
        public class Cons_searchResultsCalendarPeriod {
            public var date: Int32
            public var minMsgId: Int32
            public var maxMsgId: Int32
            public var count: Int32
            public init(date: Int32, minMsgId: Int32, maxMsgId: Int32, count: Int32) {
                self.date = date
                self.minMsgId = minMsgId
                self.maxMsgId = maxMsgId
                self.count = count
            }
        }
        case searchResultsCalendarPeriod(Cons_searchResultsCalendarPeriod)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchResultsCalendarPeriod(let _data):
                if boxed {
                    buffer.appendInt32(-911191137)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.minMsgId, buffer: buffer, boxed: false)
                serializeInt32(_data.maxMsgId, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .searchResultsCalendarPeriod(let _data):
                return ("searchResultsCalendarPeriod", [("date", _data.date as Any), ("minMsgId", _data.minMsgId as Any), ("maxMsgId", _data.maxMsgId as Any), ("count", _data.count as Any)])
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
                return Api.SearchResultsCalendarPeriod.searchResultsCalendarPeriod(Cons_searchResultsCalendarPeriod(date: _1!, minMsgId: _2!, maxMsgId: _3!, count: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SearchResultsPosition: TypeConstructorDescription {
        public class Cons_searchResultPosition {
            public var msgId: Int32
            public var date: Int32
            public var offset: Int32
            public init(msgId: Int32, date: Int32, offset: Int32) {
                self.msgId = msgId
                self.date = date
                self.offset = offset
            }
        }
        case searchResultPosition(Cons_searchResultPosition)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchResultPosition(let _data):
                if boxed {
                    buffer.appendInt32(2137295719)
                }
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .searchResultPosition(let _data):
                return ("searchResultPosition", [("msgId", _data.msgId as Any), ("date", _data.date as Any), ("offset", _data.offset as Any)])
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
                return Api.SearchResultsPosition.searchResultPosition(Cons_searchResultPosition(msgId: _1!, date: _2!, offset: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureCredentialsEncrypted: TypeConstructorDescription {
        public class Cons_secureCredentialsEncrypted {
            public var data: Buffer
            public var hash: Buffer
            public var secret: Buffer
            public init(data: Buffer, hash: Buffer, secret: Buffer) {
                self.data = data
                self.hash = hash
                self.secret = secret
            }
        }
        case secureCredentialsEncrypted(Cons_secureCredentialsEncrypted)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureCredentialsEncrypted(let _data):
                if boxed {
                    buffer.appendInt32(871426631)
                }
                serializeBytes(_data.data, buffer: buffer, boxed: false)
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                serializeBytes(_data.secret, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureCredentialsEncrypted(let _data):
                return ("secureCredentialsEncrypted", [("data", _data.data as Any), ("hash", _data.hash as Any), ("secret", _data.secret as Any)])
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
                return Api.SecureCredentialsEncrypted.secureCredentialsEncrypted(Cons_secureCredentialsEncrypted(data: _1!, hash: _2!, secret: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureData: TypeConstructorDescription {
        public class Cons_secureData {
            public var data: Buffer
            public var dataHash: Buffer
            public var secret: Buffer
            public init(data: Buffer, dataHash: Buffer, secret: Buffer) {
                self.data = data
                self.dataHash = dataHash
                self.secret = secret
            }
        }
        case secureData(Cons_secureData)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureData(let _data):
                if boxed {
                    buffer.appendInt32(-1964327229)
                }
                serializeBytes(_data.data, buffer: buffer, boxed: false)
                serializeBytes(_data.dataHash, buffer: buffer, boxed: false)
                serializeBytes(_data.secret, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureData(let _data):
                return ("secureData", [("data", _data.data as Any), ("dataHash", _data.dataHash as Any), ("secret", _data.secret as Any)])
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
                return Api.SecureData.secureData(Cons_secureData(data: _1!, dataHash: _2!, secret: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureFile: TypeConstructorDescription {
        public class Cons_secureFile {
            public var id: Int64
            public var accessHash: Int64
            public var size: Int64
            public var dcId: Int32
            public var date: Int32
            public var fileHash: Buffer
            public var secret: Buffer
            public init(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, date: Int32, fileHash: Buffer, secret: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.size = size
                self.dcId = dcId
                self.date = date
                self.fileHash = fileHash
                self.secret = secret
            }
        }
        case secureFile(Cons_secureFile)
        case secureFileEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureFile(let _data):
                if boxed {
                    buffer.appendInt32(2097791614)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt64(_data.size, buffer: buffer, boxed: false)
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeBytes(_data.secret, buffer: buffer, boxed: false)
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
            case .secureFile(let _data):
                return ("secureFile", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("size", _data.size as Any), ("dcId", _data.dcId as Any), ("date", _data.date as Any), ("fileHash", _data.fileHash as Any), ("secret", _data.secret as Any)])
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
                return Api.SecureFile.secureFile(Cons_secureFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, date: _5!, fileHash: _6!, secret: _7!))
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
public extension Api {
    enum SecurePasswordKdfAlgo: TypeConstructorDescription {
        public class Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000 {
            public var salt: Buffer
            public init(salt: Buffer) {
                self.salt = salt
            }
        }
        public class Cons_securePasswordKdfAlgoSHA512 {
            public var salt: Buffer
            public init(salt: Buffer) {
                self.salt = salt
            }
        }
        case securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000)
        case securePasswordKdfAlgoSHA512(Cons_securePasswordKdfAlgoSHA512)
        case securePasswordKdfAlgoUnknown

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let _data):
                if boxed {
                    buffer.appendInt32(-1141711456)
                }
                serializeBytes(_data.salt, buffer: buffer, boxed: false)
                break
            case .securePasswordKdfAlgoSHA512(let _data):
                if boxed {
                    buffer.appendInt32(-2042159726)
                }
                serializeBytes(_data.salt, buffer: buffer, boxed: false)
                break
            case .securePasswordKdfAlgoUnknown:
                if boxed {
                    buffer.appendInt32(4883767)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let _data):
                return ("securePasswordKdfAlgoPBKDF2HMACSHA512iter100000", [("salt", _data.salt as Any)])
            case .securePasswordKdfAlgoSHA512(let _data):
                return ("securePasswordKdfAlgoSHA512", [("salt", _data.salt as Any)])
            case .securePasswordKdfAlgoUnknown:
                return ("securePasswordKdfAlgoUnknown", [])
            }
        }

        public static func parse_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(salt: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_securePasswordKdfAlgoSHA512(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoSHA512(Cons_securePasswordKdfAlgoSHA512(salt: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_securePasswordKdfAlgoUnknown(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoUnknown
        }
    }
}
