public extension Api {
    enum EmojiLanguage: TypeConstructorDescription {
        public class Cons_emojiLanguage: TypeConstructorDescription {
            public var langCode: String
            public init(langCode: String) {
                self.langCode = langCode
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiLanguage", [("langCode", ConstructorParameterDescription(self.langCode))])
            }
        }
        case emojiLanguage(Cons_emojiLanguage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiLanguage(let _data):
                if boxed {
                    buffer.appendInt32(-1275374751)
                }
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiLanguage(let _data):
                return ("emojiLanguage", [("langCode", ConstructorParameterDescription(_data.langCode))])
            }
        }

        public static func parse_emojiLanguage(_ reader: BufferReader) -> EmojiLanguage? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiLanguage.emojiLanguage(Cons_emojiLanguage(langCode: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmojiList: TypeConstructorDescription {
        public class Cons_emojiList: TypeConstructorDescription {
            public var hash: Int64
            public var documentId: [Int64]
            public init(hash: Int64, documentId: [Int64]) {
                self.hash = hash
                self.documentId = documentId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiList", [("hash", ConstructorParameterDescription(self.hash)), ("documentId", ConstructorParameterDescription(self.documentId))])
            }
        }
        case emojiList(Cons_emojiList)
        case emojiListNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiList(let _data):
                if boxed {
                    buffer.appendInt32(2048790993)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documentId.count))
                for item in _data.documentId {
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiList(let _data):
                return ("emojiList", [("hash", ConstructorParameterDescription(_data.hash)), ("documentId", ConstructorParameterDescription(_data.documentId))])
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
                return Api.EmojiList.emojiList(Cons_emojiList(hash: _1!, documentId: _2!))
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
        public class Cons_emojiStatus: TypeConstructorDescription {
            public var flags: Int32
            public var documentId: Int64
            public var until: Int32?
            public init(flags: Int32, documentId: Int64, until: Int32?) {
                self.flags = flags
                self.documentId = documentId
                self.until = until
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiStatus", [("flags", ConstructorParameterDescription(self.flags)), ("documentId", ConstructorParameterDescription(self.documentId)), ("until", ConstructorParameterDescription(self.until))])
            }
        }
        public class Cons_emojiStatusCollectible: TypeConstructorDescription {
            public var flags: Int32
            public var collectibleId: Int64
            public var documentId: Int64
            public var title: String
            public var slug: String
            public var patternDocumentId: Int64
            public var centerColor: Int32
            public var edgeColor: Int32
            public var patternColor: Int32
            public var textColor: Int32
            public var until: Int32?
            public init(flags: Int32, collectibleId: Int64, documentId: Int64, title: String, slug: String, patternDocumentId: Int64, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, until: Int32?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.documentId = documentId
                self.title = title
                self.slug = slug
                self.patternDocumentId = patternDocumentId
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.patternColor = patternColor
                self.textColor = textColor
                self.until = until
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiStatusCollectible", [("flags", ConstructorParameterDescription(self.flags)), ("collectibleId", ConstructorParameterDescription(self.collectibleId)), ("documentId", ConstructorParameterDescription(self.documentId)), ("title", ConstructorParameterDescription(self.title)), ("slug", ConstructorParameterDescription(self.slug)), ("patternDocumentId", ConstructorParameterDescription(self.patternDocumentId)), ("centerColor", ConstructorParameterDescription(self.centerColor)), ("edgeColor", ConstructorParameterDescription(self.edgeColor)), ("patternColor", ConstructorParameterDescription(self.patternColor)), ("textColor", ConstructorParameterDescription(self.textColor)), ("until", ConstructorParameterDescription(self.until))])
            }
        }
        public class Cons_inputEmojiStatusCollectible: TypeConstructorDescription {
            public var flags: Int32
            public var collectibleId: Int64
            public var until: Int32?
            public init(flags: Int32, collectibleId: Int64, until: Int32?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.until = until
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEmojiStatusCollectible", [("flags", ConstructorParameterDescription(self.flags)), ("collectibleId", ConstructorParameterDescription(self.collectibleId)), ("until", ConstructorParameterDescription(self.until))])
            }
        }
        case emojiStatus(Cons_emojiStatus)
        case emojiStatusCollectible(Cons_emojiStatusCollectible)
        case emojiStatusEmpty
        case inputEmojiStatusCollectible(Cons_inputEmojiStatusCollectible)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiStatus(let _data):
                if boxed {
                    buffer.appendInt32(-402717046)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.until!, buffer: buffer, boxed: false)
                }
                break
            case .emojiStatusCollectible(let _data):
                if boxed {
                    buffer.appendInt32(1904500795)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.collectibleId, buffer: buffer, boxed: false)
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                serializeInt64(_data.patternDocumentId, buffer: buffer, boxed: false)
                serializeInt32(_data.centerColor, buffer: buffer, boxed: false)
                serializeInt32(_data.edgeColor, buffer: buffer, boxed: false)
                serializeInt32(_data.patternColor, buffer: buffer, boxed: false)
                serializeInt32(_data.textColor, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.until!, buffer: buffer, boxed: false)
                }
                break
            case .emojiStatusEmpty:
                if boxed {
                    buffer.appendInt32(769727150)
                }
                break
            case .inputEmojiStatusCollectible(let _data):
                if boxed {
                    buffer.appendInt32(118758847)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.collectibleId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.until!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiStatus(let _data):
                return ("emojiStatus", [("flags", ConstructorParameterDescription(_data.flags)), ("documentId", ConstructorParameterDescription(_data.documentId)), ("until", ConstructorParameterDescription(_data.until))])
            case .emojiStatusCollectible(let _data):
                return ("emojiStatusCollectible", [("flags", ConstructorParameterDescription(_data.flags)), ("collectibleId", ConstructorParameterDescription(_data.collectibleId)), ("documentId", ConstructorParameterDescription(_data.documentId)), ("title", ConstructorParameterDescription(_data.title)), ("slug", ConstructorParameterDescription(_data.slug)), ("patternDocumentId", ConstructorParameterDescription(_data.patternDocumentId)), ("centerColor", ConstructorParameterDescription(_data.centerColor)), ("edgeColor", ConstructorParameterDescription(_data.edgeColor)), ("patternColor", ConstructorParameterDescription(_data.patternColor)), ("textColor", ConstructorParameterDescription(_data.textColor)), ("until", ConstructorParameterDescription(_data.until))])
            case .emojiStatusEmpty:
                return ("emojiStatusEmpty", [])
            case .inputEmojiStatusCollectible(let _data):
                return ("inputEmojiStatusCollectible", [("flags", ConstructorParameterDescription(_data.flags)), ("collectibleId", ConstructorParameterDescription(_data.collectibleId)), ("until", ConstructorParameterDescription(_data.until))])
            }
        }

        public static func parse_emojiStatus(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiStatus.emojiStatus(Cons_emojiStatus(flags: _1!, documentId: _2!, until: _3))
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _11 = reader.readInt32()
            }
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
            let _c11 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.EmojiStatus.emojiStatusCollectible(Cons_emojiStatusCollectible(flags: _1!, collectibleId: _2!, documentId: _3!, title: _4!, slug: _5!, patternDocumentId: _6!, centerColor: _7!, edgeColor: _8!, patternColor: _9!, textColor: _10!, until: _11))
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiStatus.inputEmojiStatusCollectible(Cons_inputEmojiStatusCollectible(flags: _1!, collectibleId: _2!, until: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmojiURL: TypeConstructorDescription {
        public class Cons_emojiURL: TypeConstructorDescription {
            public var url: String
            public init(url: String) {
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiURL", [("url", ConstructorParameterDescription(self.url))])
            }
        }
        case emojiURL(Cons_emojiURL)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiURL(let _data):
                if boxed {
                    buffer.appendInt32(-1519029347)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiURL(let _data):
                return ("emojiURL", [("url", ConstructorParameterDescription(_data.url))])
            }
        }

        public static func parse_emojiURL(_ reader: BufferReader) -> EmojiURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiURL.emojiURL(Cons_emojiURL(url: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EncryptedChat: TypeConstructorDescription {
        public class Cons_encryptedChat: TypeConstructorDescription {
            public var id: Int32
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gAOrB: Buffer
            public var keyFingerprint: Int64
            public init(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64) {
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gAOrB = gAOrB
                self.keyFingerprint = keyFingerprint
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedChat", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("date", ConstructorParameterDescription(self.date)), ("adminId", ConstructorParameterDescription(self.adminId)), ("participantId", ConstructorParameterDescription(self.participantId)), ("gAOrB", ConstructorParameterDescription(self.gAOrB)), ("keyFingerprint", ConstructorParameterDescription(self.keyFingerprint))])
            }
        }
        public class Cons_encryptedChatDiscarded: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public init(flags: Int32, id: Int32) {
                self.flags = flags
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedChatDiscarded", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_encryptedChatEmpty: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedChatEmpty", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_encryptedChatRequested: TypeConstructorDescription {
            public var flags: Int32
            public var folderId: Int32?
            public var id: Int32
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gA: Buffer
            public init(flags: Int32, folderId: Int32?, id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gA: Buffer) {
                self.flags = flags
                self.folderId = folderId
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gA = gA
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedChatRequested", [("flags", ConstructorParameterDescription(self.flags)), ("folderId", ConstructorParameterDescription(self.folderId)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("date", ConstructorParameterDescription(self.date)), ("adminId", ConstructorParameterDescription(self.adminId)), ("participantId", ConstructorParameterDescription(self.participantId)), ("gA", ConstructorParameterDescription(self.gA))])
            }
        }
        public class Cons_encryptedChatWaiting: TypeConstructorDescription {
            public var id: Int32
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public init(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64) {
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedChatWaiting", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("date", ConstructorParameterDescription(self.date)), ("adminId", ConstructorParameterDescription(self.adminId)), ("participantId", ConstructorParameterDescription(self.participantId))])
            }
        }
        case encryptedChat(Cons_encryptedChat)
        case encryptedChatDiscarded(Cons_encryptedChatDiscarded)
        case encryptedChatEmpty(Cons_encryptedChatEmpty)
        case encryptedChatRequested(Cons_encryptedChatRequested)
        case encryptedChatWaiting(Cons_encryptedChatWaiting)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .encryptedChat(let _data):
                if boxed {
                    buffer.appendInt32(1643173063)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt64(_data.participantId, buffer: buffer, boxed: false)
                serializeBytes(_data.gAOrB, buffer: buffer, boxed: false)
                serializeInt64(_data.keyFingerprint, buffer: buffer, boxed: false)
                break
            case .encryptedChatDiscarded(let _data):
                if boxed {
                    buffer.appendInt32(505183301)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            case .encryptedChatEmpty(let _data):
                if boxed {
                    buffer.appendInt32(-1417756512)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            case .encryptedChatRequested(let _data):
                if boxed {
                    buffer.appendInt32(1223809356)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt64(_data.participantId, buffer: buffer, boxed: false)
                serializeBytes(_data.gA, buffer: buffer, boxed: false)
                break
            case .encryptedChatWaiting(let _data):
                if boxed {
                    buffer.appendInt32(1722964307)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt64(_data.participantId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .encryptedChat(let _data):
                return ("encryptedChat", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("date", ConstructorParameterDescription(_data.date)), ("adminId", ConstructorParameterDescription(_data.adminId)), ("participantId", ConstructorParameterDescription(_data.participantId)), ("gAOrB", ConstructorParameterDescription(_data.gAOrB)), ("keyFingerprint", ConstructorParameterDescription(_data.keyFingerprint))])
            case .encryptedChatDiscarded(let _data):
                return ("encryptedChatDiscarded", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id))])
            case .encryptedChatEmpty(let _data):
                return ("encryptedChatEmpty", [("id", ConstructorParameterDescription(_data.id))])
            case .encryptedChatRequested(let _data):
                return ("encryptedChatRequested", [("flags", ConstructorParameterDescription(_data.flags)), ("folderId", ConstructorParameterDescription(_data.folderId)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("date", ConstructorParameterDescription(_data.date)), ("adminId", ConstructorParameterDescription(_data.adminId)), ("participantId", ConstructorParameterDescription(_data.participantId)), ("gA", ConstructorParameterDescription(_data.gA))])
            case .encryptedChatWaiting(let _data):
                return ("encryptedChatWaiting", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("date", ConstructorParameterDescription(_data.date)), ("adminId", ConstructorParameterDescription(_data.adminId)), ("participantId", ConstructorParameterDescription(_data.participantId))])
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
                return Api.EncryptedChat.encryptedChat(Cons_encryptedChat(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!, gAOrB: _6!, keyFingerprint: _7!))
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
                return Api.EncryptedChat.encryptedChatDiscarded(Cons_encryptedChatDiscarded(flags: _1!, id: _2!))
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
                return Api.EncryptedChat.encryptedChatEmpty(Cons_encryptedChatEmpty(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatRequested(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
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
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.EncryptedChat.encryptedChatRequested(Cons_encryptedChatRequested(flags: _1!, folderId: _2, id: _3!, accessHash: _4!, date: _5!, adminId: _6!, participantId: _7!, gA: _8!))
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
                return Api.EncryptedChat.encryptedChatWaiting(Cons_encryptedChatWaiting(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EncryptedFile: TypeConstructorDescription {
        public class Cons_encryptedFile: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var size: Int64
            public var dcId: Int32
            public var keyFingerprint: Int32
            public init(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, keyFingerprint: Int32) {
                self.id = id
                self.accessHash = accessHash
                self.size = size
                self.dcId = dcId
                self.keyFingerprint = keyFingerprint
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedFile", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("size", ConstructorParameterDescription(self.size)), ("dcId", ConstructorParameterDescription(self.dcId)), ("keyFingerprint", ConstructorParameterDescription(self.keyFingerprint))])
            }
        }
        case encryptedFile(Cons_encryptedFile)
        case encryptedFileEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .encryptedFile(let _data):
                if boxed {
                    buffer.appendInt32(-1476358952)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt64(_data.size, buffer: buffer, boxed: false)
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeInt32(_data.keyFingerprint, buffer: buffer, boxed: false)
                break
            case .encryptedFileEmpty:
                if boxed {
                    buffer.appendInt32(-1038136962)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .encryptedFile(let _data):
                return ("encryptedFile", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("size", ConstructorParameterDescription(_data.size)), ("dcId", ConstructorParameterDescription(_data.dcId)), ("keyFingerprint", ConstructorParameterDescription(_data.keyFingerprint))])
            case .encryptedFileEmpty:
                return ("encryptedFileEmpty", [])
            }
        }

        public static func parse_encryptedFile(_ reader: BufferReader) -> EncryptedFile? {
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.EncryptedFile.encryptedFile(Cons_encryptedFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, keyFingerprint: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedFileEmpty(_ reader: BufferReader) -> EncryptedFile? {
            return Api.EncryptedFile.encryptedFileEmpty
        }
    }
}
public extension Api {
    enum EncryptedMessage: TypeConstructorDescription {
        public class Cons_encryptedMessage: TypeConstructorDescription {
            public var randomId: Int64
            public var chatId: Int32
            public var date: Int32
            public var bytes: Buffer
            public var file: Api.EncryptedFile
            public init(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer, file: Api.EncryptedFile) {
                self.randomId = randomId
                self.chatId = chatId
                self.date = date
                self.bytes = bytes
                self.file = file
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedMessage", [("randomId", ConstructorParameterDescription(self.randomId)), ("chatId", ConstructorParameterDescription(self.chatId)), ("date", ConstructorParameterDescription(self.date)), ("bytes", ConstructorParameterDescription(self.bytes)), ("file", ConstructorParameterDescription(self.file))])
            }
        }
        public class Cons_encryptedMessageService: TypeConstructorDescription {
            public var randomId: Int64
            public var chatId: Int32
            public var date: Int32
            public var bytes: Buffer
            public init(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer) {
                self.randomId = randomId
                self.chatId = chatId
                self.date = date
                self.bytes = bytes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("encryptedMessageService", [("randomId", ConstructorParameterDescription(self.randomId)), ("chatId", ConstructorParameterDescription(self.chatId)), ("date", ConstructorParameterDescription(self.date)), ("bytes", ConstructorParameterDescription(self.bytes))])
            }
        }
        case encryptedMessage(Cons_encryptedMessage)
        case encryptedMessageService(Cons_encryptedMessageService)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .encryptedMessage(let _data):
                if boxed {
                    buffer.appendInt32(-317144808)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                serializeInt32(_data.chatId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeBytes(_data.bytes, buffer: buffer, boxed: false)
                _data.file.serialize(buffer, true)
                break
            case .encryptedMessageService(let _data):
                if boxed {
                    buffer.appendInt32(594758406)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                serializeInt32(_data.chatId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeBytes(_data.bytes, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .encryptedMessage(let _data):
                return ("encryptedMessage", [("randomId", ConstructorParameterDescription(_data.randomId)), ("chatId", ConstructorParameterDescription(_data.chatId)), ("date", ConstructorParameterDescription(_data.date)), ("bytes", ConstructorParameterDescription(_data.bytes)), ("file", ConstructorParameterDescription(_data.file))])
            case .encryptedMessageService(let _data):
                return ("encryptedMessageService", [("randomId", ConstructorParameterDescription(_data.randomId)), ("chatId", ConstructorParameterDescription(_data.chatId)), ("date", ConstructorParameterDescription(_data.date)), ("bytes", ConstructorParameterDescription(_data.bytes))])
            }
        }

        public static func parse_encryptedMessage(_ reader: BufferReader) -> EncryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.EncryptedFile?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.EncryptedFile
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.EncryptedMessage.encryptedMessage(Cons_encryptedMessage(randomId: _1!, chatId: _2!, date: _3!, bytes: _4!, file: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedMessageService(_ reader: BufferReader) -> EncryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.EncryptedMessage.encryptedMessageService(Cons_encryptedMessageService(randomId: _1!, chatId: _2!, date: _3!, bytes: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum EphemeralMessage: TypeConstructorDescription {
        public class Cons_ephemeralMessage: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var fromId: Api.Peer
            public var peerId: Api.Peer?
            public var receiverId: Int64
            public var topMsgId: Int32?
            public var date: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var media: Api.MessageMedia?
            public var replyMarkup: Api.ReplyMarkup?
            public var replyTo: Api.MessageReplyHeader?
            public var richMessage: Api.RichMessage?
            public var chatInstance: Int64?
            public var anchorMsgId: Int32?
            public init(flags: Int32, id: Int32, fromId: Api.Peer, peerId: Api.Peer?, receiverId: Int64, topMsgId: Int32?, date: Int32, message: String, entities: [Api.MessageEntity]?, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, replyTo: Api.MessageReplyHeader?, richMessage: Api.RichMessage?, chatInstance: Int64?, anchorMsgId: Int32?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.peerId = peerId
                self.receiverId = receiverId
                self.topMsgId = topMsgId
                self.date = date
                self.message = message
                self.entities = entities
                self.media = media
                self.replyMarkup = replyMarkup
                self.replyTo = replyTo
                self.richMessage = richMessage
                self.chatInstance = chatInstance
                self.anchorMsgId = anchorMsgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("ephemeralMessage", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("fromId", ConstructorParameterDescription(self.fromId)), ("peerId", ConstructorParameterDescription(self.peerId)), ("receiverId", ConstructorParameterDescription(self.receiverId)), ("topMsgId", ConstructorParameterDescription(self.topMsgId)), ("date", ConstructorParameterDescription(self.date)), ("message", ConstructorParameterDescription(self.message)), ("entities", ConstructorParameterDescription(self.entities)), ("media", ConstructorParameterDescription(self.media)), ("replyMarkup", ConstructorParameterDescription(self.replyMarkup)), ("replyTo", ConstructorParameterDescription(self.replyTo)), ("richMessage", ConstructorParameterDescription(self.richMessage)), ("chatInstance", ConstructorParameterDescription(self.chatInstance)), ("anchorMsgId", ConstructorParameterDescription(self.anchorMsgId))])
            }
        }
        case ephemeralMessage(Cons_ephemeralMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .ephemeralMessage(let _data):
                if boxed {
                    buffer.appendInt32(-584597783)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                _data.fromId.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.peerId!.serialize(buffer, true)
                }
                serializeInt64(_data.receiverId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.media!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.replyTo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.richMessage!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt64(_data.chatInstance!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.anchorMsgId!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .ephemeralMessage(let _data):
                return ("ephemeralMessage", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("peerId", ConstructorParameterDescription(_data.peerId)), ("receiverId", ConstructorParameterDescription(_data.receiverId)), ("topMsgId", ConstructorParameterDescription(_data.topMsgId)), ("date", ConstructorParameterDescription(_data.date)), ("message", ConstructorParameterDescription(_data.message)), ("entities", ConstructorParameterDescription(_data.entities)), ("media", ConstructorParameterDescription(_data.media)), ("replyMarkup", ConstructorParameterDescription(_data.replyMarkup)), ("replyTo", ConstructorParameterDescription(_data.replyTo)), ("richMessage", ConstructorParameterDescription(_data.richMessage)), ("chatInstance", ConstructorParameterDescription(_data.chatInstance)), ("anchorMsgId", ConstructorParameterDescription(_data.anchorMsgId))])
            }
        }

        public static func parse_ephemeralMessage(_ reader: BufferReader) -> EphemeralMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: String?
            _8 = parseString(reader)
            var _9: [Api.MessageEntity]?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _10: Api.MessageMedia?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.MessageMedia
                }
            }
            var _11: Api.ReplyMarkup?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _11 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            var _12: Api.MessageReplyHeader?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
                }
            }
            var _13: Api.RichMessage?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _13 = Api.parse(reader, signature: signature) as? Api.RichMessage
                }
            }
            var _14: Int64?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                _14 = reader.readInt64()
            }
            var _15: Int32?
            if Int(_1 ?? 0) & Int(1 << 11) != 0 {
                _15 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 9) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _11 != nil
            let _c12 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _12 != nil
            let _c13 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _13 != nil
            let _c14 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _14 != nil
            let _c15 = (Int(_1 ?? 0) & Int(1 << 11) == 0) || _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.EphemeralMessage.ephemeralMessage(Cons_ephemeralMessage(flags: _1!, id: _2!, fromId: _3!, peerId: _4, receiverId: _5!, topMsgId: _6, date: _7!, message: _8!, entities: _9, media: _10, replyMarkup: _11, replyTo: _12, richMessage: _13, chatInstance: _14, anchorMsgId: _15))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ExportedChatInvite: TypeConstructorDescription {
        public class Cons_chatInviteExported: TypeConstructorDescription {
            public var flags: Int32
            public var link: String
            public var adminId: Int64
            public var date: Int32
            public var startDate: Int32?
            public var expireDate: Int32?
            public var usageLimit: Int32?
            public var usage: Int32?
            public var requested: Int32?
            public var subscriptionExpired: Int32?
            public var title: String?
            public var subscriptionPricing: Api.StarsSubscriptionPricing?
            public init(flags: Int32, link: String, adminId: Int64, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, usage: Int32?, requested: Int32?, subscriptionExpired: Int32?, title: String?, subscriptionPricing: Api.StarsSubscriptionPricing?) {
                self.flags = flags
                self.link = link
                self.adminId = adminId
                self.date = date
                self.startDate = startDate
                self.expireDate = expireDate
                self.usageLimit = usageLimit
                self.usage = usage
                self.requested = requested
                self.subscriptionExpired = subscriptionExpired
                self.title = title
                self.subscriptionPricing = subscriptionPricing
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatInviteExported", [("flags", ConstructorParameterDescription(self.flags)), ("link", ConstructorParameterDescription(self.link)), ("adminId", ConstructorParameterDescription(self.adminId)), ("date", ConstructorParameterDescription(self.date)), ("startDate", ConstructorParameterDescription(self.startDate)), ("expireDate", ConstructorParameterDescription(self.expireDate)), ("usageLimit", ConstructorParameterDescription(self.usageLimit)), ("usage", ConstructorParameterDescription(self.usage)), ("requested", ConstructorParameterDescription(self.requested)), ("subscriptionExpired", ConstructorParameterDescription(self.subscriptionExpired)), ("title", ConstructorParameterDescription(self.title)), ("subscriptionPricing", ConstructorParameterDescription(self.subscriptionPricing))])
            }
        }
        case chatInviteExported(Cons_chatInviteExported)
        case chatInvitePublicJoinRequests

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatInviteExported(let _data):
                if boxed {
                    buffer.appendInt32(-1574126186)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.link, buffer: buffer, boxed: false)
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.startDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.expireDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.usageLimit!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.usage!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.requested!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.subscriptionExpired!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.subscriptionPricing!.serialize(buffer, true)
                }
                break
            case .chatInvitePublicJoinRequests:
                if boxed {
                    buffer.appendInt32(-317687113)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatInviteExported(let _data):
                return ("chatInviteExported", [("flags", ConstructorParameterDescription(_data.flags)), ("link", ConstructorParameterDescription(_data.link)), ("adminId", ConstructorParameterDescription(_data.adminId)), ("date", ConstructorParameterDescription(_data.date)), ("startDate", ConstructorParameterDescription(_data.startDate)), ("expireDate", ConstructorParameterDescription(_data.expireDate)), ("usageLimit", ConstructorParameterDescription(_data.usageLimit)), ("usage", ConstructorParameterDescription(_data.usage)), ("requested", ConstructorParameterDescription(_data.requested)), ("subscriptionExpired", ConstructorParameterDescription(_data.subscriptionExpired)), ("title", ConstructorParameterDescription(_data.title)), ("subscriptionPricing", ConstructorParameterDescription(_data.subscriptionPricing))])
            case .chatInvitePublicJoinRequests:
                return ("chatInvitePublicJoinRequests", [])
            }
        }

        public static func parse_chatInviteExported(_ reader: BufferReader) -> ExportedChatInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Int32?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int32?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                _10 = reader.readInt32()
            }
            var _11: String?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _11 = parseString(reader)
            }
            var _12: Api.StarsSubscriptionPricing?
            if Int(_1 ?? 0) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.StarsSubscriptionPricing
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _11 != nil
            let _c12 = (Int(_1 ?? 0) & Int(1 << 9) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.ExportedChatInvite.chatInviteExported(Cons_chatInviteExported(flags: _1!, link: _2!, adminId: _3!, date: _4!, startDate: _5, expireDate: _6, usageLimit: _7, usage: _8, requested: _9, subscriptionExpired: _10, title: _11, subscriptionPricing: _12))
            }
            else {
                return nil
            }
        }
        public static func parse_chatInvitePublicJoinRequests(_ reader: BufferReader) -> ExportedChatInvite? {
            return Api.ExportedChatInvite.chatInvitePublicJoinRequests
        }
    }
}
public extension Api {
    enum ExportedChatlistInvite: TypeConstructorDescription {
        public class Cons_exportedChatlistInvite: TypeConstructorDescription {
            public var flags: Int32
            public var title: String
            public var url: String
            public var peers: [Api.Peer]
            public init(flags: Int32, title: String, url: String, peers: [Api.Peer]) {
                self.flags = flags
                self.title = title
                self.url = url
                self.peers = peers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedChatlistInvite", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("url", ConstructorParameterDescription(self.url)), ("peers", ConstructorParameterDescription(self.peers))])
            }
        }
        case exportedChatlistInvite(Cons_exportedChatlistInvite)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedChatlistInvite(let _data):
                if boxed {
                    buffer.appendInt32(206668204)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .exportedChatlistInvite(let _data):
                return ("exportedChatlistInvite", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("url", ConstructorParameterDescription(_data.url)), ("peers", ConstructorParameterDescription(_data.peers))])
            }
        }

        public static func parse_exportedChatlistInvite(_ reader: BufferReader) -> ExportedChatlistInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Peer]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ExportedChatlistInvite.exportedChatlistInvite(Cons_exportedChatlistInvite(flags: _1!, title: _2!, url: _3!, peers: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ExportedContactToken: TypeConstructorDescription {
        public class Cons_exportedContactToken: TypeConstructorDescription {
            public var url: String
            public var expires: Int32
            public init(url: String, expires: Int32) {
                self.url = url
                self.expires = expires
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedContactToken", [("url", ConstructorParameterDescription(self.url)), ("expires", ConstructorParameterDescription(self.expires))])
            }
        }
        case exportedContactToken(Cons_exportedContactToken)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedContactToken(let _data):
                if boxed {
                    buffer.appendInt32(1103040667)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .exportedContactToken(let _data):
                return ("exportedContactToken", [("url", ConstructorParameterDescription(_data.url)), ("expires", ConstructorParameterDescription(_data.expires))])
            }
        }

        public static func parse_exportedContactToken(_ reader: BufferReader) -> ExportedContactToken? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ExportedContactToken.exportedContactToken(Cons_exportedContactToken(url: _1!, expires: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ExportedMessageLink: TypeConstructorDescription {
        public class Cons_exportedMessageLink: TypeConstructorDescription {
            public var link: String
            public var html: String
            public init(link: String, html: String) {
                self.link = link
                self.html = html
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedMessageLink", [("link", ConstructorParameterDescription(self.link)), ("html", ConstructorParameterDescription(self.html))])
            }
        }
        case exportedMessageLink(Cons_exportedMessageLink)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedMessageLink(let _data):
                if boxed {
                    buffer.appendInt32(1571494644)
                }
                serializeString(_data.link, buffer: buffer, boxed: false)
                serializeString(_data.html, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .exportedMessageLink(let _data):
                return ("exportedMessageLink", [("link", ConstructorParameterDescription(_data.link)), ("html", ConstructorParameterDescription(_data.html))])
            }
        }

        public static func parse_exportedMessageLink(_ reader: BufferReader) -> ExportedMessageLink? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ExportedMessageLink.exportedMessageLink(Cons_exportedMessageLink(link: _1!, html: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ExportedStoryLink: TypeConstructorDescription {
        public class Cons_exportedStoryLink: TypeConstructorDescription {
            public var link: String
            public init(link: String) {
                self.link = link
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedStoryLink", [("link", ConstructorParameterDescription(self.link))])
            }
        }
        case exportedStoryLink(Cons_exportedStoryLink)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedStoryLink(let _data):
                if boxed {
                    buffer.appendInt32(1070138683)
                }
                serializeString(_data.link, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .exportedStoryLink(let _data):
                return ("exportedStoryLink", [("link", ConstructorParameterDescription(_data.link))])
            }
        }

        public static func parse_exportedStoryLink(_ reader: BufferReader) -> ExportedStoryLink? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ExportedStoryLink.exportedStoryLink(Cons_exportedStoryLink(link: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum FactCheck: TypeConstructorDescription {
        public class Cons_factCheck: TypeConstructorDescription {
            public var flags: Int32
            public var country: String?
            public var text: Api.TextWithEntities?
            public var hash: Int64
            public init(flags: Int32, country: String?, text: Api.TextWithEntities?, hash: Int64) {
                self.flags = flags
                self.country = country
                self.text = text
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("factCheck", [("flags", ConstructorParameterDescription(self.flags)), ("country", ConstructorParameterDescription(self.country)), ("text", ConstructorParameterDescription(self.text)), ("hash", ConstructorParameterDescription(self.hash))])
            }
        }
        case factCheck(Cons_factCheck)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .factCheck(let _data):
                if boxed {
                    buffer.appendInt32(-1197736753)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.country!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.text!.serialize(buffer, true)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .factCheck(let _data):
                return ("factCheck", [("flags", ConstructorParameterDescription(_data.flags)), ("country", ConstructorParameterDescription(_data.country)), ("text", ConstructorParameterDescription(_data.text)), ("hash", ConstructorParameterDescription(_data.hash))])
            }
        }

        public static func parse_factCheck(_ reader: BufferReader) -> FactCheck? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _2 = parseString(reader)
            }
            var _3: Api.TextWithEntities?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.FactCheck.factCheck(Cons_factCheck(flags: _1!, country: _2, text: _3, hash: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum FileHash: TypeConstructorDescription {
        public class Cons_fileHash: TypeConstructorDescription {
            public var offset: Int64
            public var limit: Int32
            public var hash: Buffer
            public init(offset: Int64, limit: Int32, hash: Buffer) {
                self.offset = offset
                self.limit = limit
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("fileHash", [("offset", ConstructorParameterDescription(self.offset)), ("limit", ConstructorParameterDescription(self.limit)), ("hash", ConstructorParameterDescription(self.hash))])
            }
        }
        case fileHash(Cons_fileHash)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .fileHash(let _data):
                if boxed {
                    buffer.appendInt32(-207944868)
                }
                serializeInt64(_data.offset, buffer: buffer, boxed: false)
                serializeInt32(_data.limit, buffer: buffer, boxed: false)
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .fileHash(let _data):
                return ("fileHash", [("offset", ConstructorParameterDescription(_data.offset)), ("limit", ConstructorParameterDescription(_data.limit)), ("hash", ConstructorParameterDescription(_data.hash))])
            }
        }

        public static func parse_fileHash(_ reader: BufferReader) -> FileHash? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.FileHash.fileHash(Cons_fileHash(offset: _1!, limit: _2!, hash: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Folder: TypeConstructorDescription {
        public class Cons_folder: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var title: String
            public var photo: Api.ChatPhoto?
            public init(flags: Int32, id: Int32, title: String, photo: Api.ChatPhoto?) {
                self.flags = flags
                self.id = id
                self.title = title
                self.photo = photo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("folder", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("title", ConstructorParameterDescription(self.title)), ("photo", ConstructorParameterDescription(self.photo))])
            }
        }
        case folder(Cons_folder)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .folder(let _data):
                if boxed {
                    buffer.appendInt32(-11252123)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .folder(let _data):
                return ("folder", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("title", ConstructorParameterDescription(_data.title)), ("photo", ConstructorParameterDescription(_data.photo))])
            }
        }

        public static func parse_folder(_ reader: BufferReader) -> Folder? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ChatPhoto?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Folder.folder(Cons_folder(flags: _1!, id: _2!, title: _3!, photo: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum FolderPeer: TypeConstructorDescription {
        public class Cons_folderPeer: TypeConstructorDescription {
            public var peer: Api.Peer
            public var folderId: Int32
            public init(peer: Api.Peer, folderId: Int32) {
                self.peer = peer
                self.folderId = folderId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("folderPeer", [("peer", ConstructorParameterDescription(self.peer)), ("folderId", ConstructorParameterDescription(self.folderId))])
            }
        }
        case folderPeer(Cons_folderPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .folderPeer(let _data):
                if boxed {
                    buffer.appendInt32(-373643672)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.folderId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .folderPeer(let _data):
                return ("folderPeer", [("peer", ConstructorParameterDescription(_data.peer)), ("folderId", ConstructorParameterDescription(_data.folderId))])
            }
        }

        public static func parse_folderPeer(_ reader: BufferReader) -> FolderPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.FolderPeer.folderPeer(Cons_folderPeer(peer: _1!, folderId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum ForumTopic: TypeConstructorDescription {
        public class Cons_forumTopic: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var date: Int32
            public var peer: Api.Peer
            public var title: String
            public var iconColor: Int32
            public var iconEmojiId: Int64?
            public var topMessage: Int32
            public var readInboxMaxId: Int32
            public var readOutboxMaxId: Int32
            public var unreadCount: Int32
            public var unreadMentionsCount: Int32
            public var unreadReactionsCount: Int32
            public var unreadPollVotesCount: Int32
            public var fromId: Api.Peer
            public var notifySettings: Api.PeerNotifySettings
            public var draft: Api.DraftMessage?
            public init(flags: Int32, id: Int32, date: Int32, peer: Api.Peer, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, unreadPollVotesCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?) {
                self.flags = flags
                self.id = id
                self.date = date
                self.peer = peer
                self.title = title
                self.iconColor = iconColor
                self.iconEmojiId = iconEmojiId
                self.topMessage = topMessage
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.unreadMentionsCount = unreadMentionsCount
                self.unreadReactionsCount = unreadReactionsCount
                self.unreadPollVotesCount = unreadPollVotesCount
                self.fromId = fromId
                self.notifySettings = notifySettings
                self.draft = draft
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("forumTopic", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("date", ConstructorParameterDescription(self.date)), ("peer", ConstructorParameterDescription(self.peer)), ("title", ConstructorParameterDescription(self.title)), ("iconColor", ConstructorParameterDescription(self.iconColor)), ("iconEmojiId", ConstructorParameterDescription(self.iconEmojiId)), ("topMessage", ConstructorParameterDescription(self.topMessage)), ("readInboxMaxId", ConstructorParameterDescription(self.readInboxMaxId)), ("readOutboxMaxId", ConstructorParameterDescription(self.readOutboxMaxId)), ("unreadCount", ConstructorParameterDescription(self.unreadCount)), ("unreadMentionsCount", ConstructorParameterDescription(self.unreadMentionsCount)), ("unreadReactionsCount", ConstructorParameterDescription(self.unreadReactionsCount)), ("unreadPollVotesCount", ConstructorParameterDescription(self.unreadPollVotesCount)), ("fromId", ConstructorParameterDescription(self.fromId)), ("notifySettings", ConstructorParameterDescription(self.notifySettings)), ("draft", ConstructorParameterDescription(self.draft))])
            }
        }
        public class Cons_forumTopicDeleted: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("forumTopicDeleted", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case forumTopic(Cons_forumTopic)
        case forumTopicDeleted(Cons_forumTopicDeleted)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .forumTopic(let _data):
                if boxed {
                    buffer.appendInt32(-52766699)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeInt32(_data.iconColor, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.iconEmojiId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.topMessage, buffer: buffer, boxed: false)
                serializeInt32(_data.readInboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.readOutboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadMentionsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadReactionsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadPollVotesCount, buffer: buffer, boxed: false)
                _data.fromId.serialize(buffer, true)
                _data.notifySettings.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.draft!.serialize(buffer, true)
                }
                break
            case .forumTopicDeleted(let _data):
                if boxed {
                    buffer.appendInt32(37687451)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .forumTopic(let _data):
                return ("forumTopic", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("date", ConstructorParameterDescription(_data.date)), ("peer", ConstructorParameterDescription(_data.peer)), ("title", ConstructorParameterDescription(_data.title)), ("iconColor", ConstructorParameterDescription(_data.iconColor)), ("iconEmojiId", ConstructorParameterDescription(_data.iconEmojiId)), ("topMessage", ConstructorParameterDescription(_data.topMessage)), ("readInboxMaxId", ConstructorParameterDescription(_data.readInboxMaxId)), ("readOutboxMaxId", ConstructorParameterDescription(_data.readOutboxMaxId)), ("unreadCount", ConstructorParameterDescription(_data.unreadCount)), ("unreadMentionsCount", ConstructorParameterDescription(_data.unreadMentionsCount)), ("unreadReactionsCount", ConstructorParameterDescription(_data.unreadReactionsCount)), ("unreadPollVotesCount", ConstructorParameterDescription(_data.unreadPollVotesCount)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("notifySettings", ConstructorParameterDescription(_data.notifySettings)), ("draft", ConstructorParameterDescription(_data.draft))])
            case .forumTopicDeleted(let _data):
                return ("forumTopicDeleted", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_forumTopic(_ reader: BufferReader) -> ForumTopic? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int64?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Int32?
            _13 = reader.readInt32()
            var _14: Int32?
            _14 = reader.readInt32()
            var _15: Api.Peer?
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _16: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _17: Api.DraftMessage?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _17 = Api.parse(reader, signature: signature) as? Api.DraftMessage
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return Api.ForumTopic.forumTopic(Cons_forumTopic(flags: _1!, id: _2!, date: _3!, peer: _4!, title: _5!, iconColor: _6!, iconEmojiId: _7, topMessage: _8!, readInboxMaxId: _9!, readOutboxMaxId: _10!, unreadCount: _11!, unreadMentionsCount: _12!, unreadReactionsCount: _13!, unreadPollVotesCount: _14!, fromId: _15!, notifySettings: _16!, draft: _17))
            }
            else {
                return nil
            }
        }
        public static func parse_forumTopicDeleted(_ reader: BufferReader) -> ForumTopic? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ForumTopic.forumTopicDeleted(Cons_forumTopicDeleted(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum FoundStory: TypeConstructorDescription {
        public class Cons_foundStory: TypeConstructorDescription {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("foundStory", [("peer", ConstructorParameterDescription(self.peer)), ("story", ConstructorParameterDescription(self.story))])
            }
        }
        case foundStory(Cons_foundStory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .foundStory(let _data):
                if boxed {
                    buffer.appendInt32(-394605632)
                }
                _data.peer.serialize(buffer, true)
                _data.story.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .foundStory(let _data):
                return ("foundStory", [("peer", ConstructorParameterDescription(_data.peer)), ("story", ConstructorParameterDescription(_data.story))])
            }
        }

        public static func parse_foundStory(_ reader: BufferReader) -> FoundStory? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StoryItem?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.FoundStory.foundStory(Cons_foundStory(peer: _1!, story: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Game: TypeConstructorDescription {
        public class Cons_game: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var shortName: String
            public var title: String
            public var description: String
            public var photo: Api.Photo
            public var document: Api.Document?
            public init(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.shortName = shortName
                self.title = title
                self.description = description
                self.photo = photo
                self.document = document
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("game", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("shortName", ConstructorParameterDescription(self.shortName)), ("title", ConstructorParameterDescription(self.title)), ("description", ConstructorParameterDescription(self.description)), ("photo", ConstructorParameterDescription(self.photo)), ("document", ConstructorParameterDescription(self.document))])
            }
        }
        case game(Cons_game)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .game(let _data):
                if boxed {
                    buffer.appendInt32(-1107729093)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                _data.photo.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .game(let _data):
                return ("game", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("shortName", ConstructorParameterDescription(_data.shortName)), ("title", ConstructorParameterDescription(_data.title)), ("description", ConstructorParameterDescription(_data.description)), ("photo", ConstructorParameterDescription(_data.photo)), ("document", ConstructorParameterDescription(_data.document))])
            }
        }

        public static func parse_game(_ reader: BufferReader) -> Game? {
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
            var _6: String?
            _6 = parseString(reader)
            var _7: Api.Photo?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _8: Api.Document?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Game.game(Cons_game(flags: _1!, id: _2!, accessHash: _3!, shortName: _4!, title: _5!, description: _6!, photo: _7!, document: _8))
            }
            else {
                return nil
            }
        }
    }
}
