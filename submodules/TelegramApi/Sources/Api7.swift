public extension Api {
    enum EmojiURL: TypeConstructorDescription {
        public class Cons_emojiURL {
            public var url: String
            public init(url: String) {
                self.url = url
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .emojiURL(let _data):
                return ("emojiURL", [("url", _data.url as Any)])
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
        public class Cons_encryptedChat {
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
        }
        public class Cons_encryptedChatDiscarded {
            public var flags: Int32
            public var id: Int32
            public init(flags: Int32, id: Int32) {
                self.flags = flags
                self.id = id
            }
        }
        public class Cons_encryptedChatEmpty {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
        }
        public class Cons_encryptedChatRequested {
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
        }
        public class Cons_encryptedChatWaiting {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .encryptedChat(let _data):
                return ("encryptedChat", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("date", _data.date as Any), ("adminId", _data.adminId as Any), ("participantId", _data.participantId as Any), ("gAOrB", _data.gAOrB as Any), ("keyFingerprint", _data.keyFingerprint as Any)])
            case .encryptedChatDiscarded(let _data):
                return ("encryptedChatDiscarded", [("flags", _data.flags as Any), ("id", _data.id as Any)])
            case .encryptedChatEmpty(let _data):
                return ("encryptedChatEmpty", [("id", _data.id as Any)])
            case .encryptedChatRequested(let _data):
                return ("encryptedChatRequested", [("flags", _data.flags as Any), ("folderId", _data.folderId as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("date", _data.date as Any), ("adminId", _data.adminId as Any), ("participantId", _data.participantId as Any), ("gA", _data.gA as Any)])
            case .encryptedChatWaiting(let _data):
                return ("encryptedChatWaiting", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("date", _data.date as Any), ("adminId", _data.adminId as Any), ("participantId", _data.participantId as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
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
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
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
        public class Cons_encryptedFile {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .encryptedFile(let _data):
                return ("encryptedFile", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("size", _data.size as Any), ("dcId", _data.dcId as Any), ("keyFingerprint", _data.keyFingerprint as Any)])
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
        public class Cons_encryptedMessage {
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
        }
        public class Cons_encryptedMessageService {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .encryptedMessage(let _data):
                return ("encryptedMessage", [("randomId", _data.randomId as Any), ("chatId", _data.chatId as Any), ("date", _data.date as Any), ("bytes", _data.bytes as Any), ("file", _data.file as Any)])
            case .encryptedMessageService(let _data):
                return ("encryptedMessageService", [("randomId", _data.randomId as Any), ("chatId", _data.chatId as Any), ("date", _data.date as Any), ("bytes", _data.bytes as Any)])
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
    enum ExportedChatInvite: TypeConstructorDescription {
        public class Cons_chatInviteExported {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatInviteExported(let _data):
                return ("chatInviteExported", [("flags", _data.flags as Any), ("link", _data.link as Any), ("adminId", _data.adminId as Any), ("date", _data.date as Any), ("startDate", _data.startDate as Any), ("expireDate", _data.expireDate as Any), ("usageLimit", _data.usageLimit as Any), ("usage", _data.usage as Any), ("requested", _data.requested as Any), ("subscriptionExpired", _data.subscriptionExpired as Any), ("title", _data.title as Any), ("subscriptionPricing", _data.subscriptionPricing as Any)])
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
            if Int(_1!) & Int(1 << 4) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _10 = reader.readInt32()
            }
            var _11: String?
            if Int(_1!) & Int(1 << 8) != 0 {
                _11 = parseString(reader)
            }
            var _12: Api.StarsSubscriptionPricing?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.StarsSubscriptionPricing
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 7) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 10) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 8) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 9) == 0) || _12 != nil
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
        public class Cons_exportedChatlistInvite {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedChatlistInvite(let _data):
                return ("exportedChatlistInvite", [("flags", _data.flags as Any), ("title", _data.title as Any), ("url", _data.url as Any), ("peers", _data.peers as Any)])
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
        public class Cons_exportedContactToken {
            public var url: String
            public var expires: Int32
            public init(url: String, expires: Int32) {
                self.url = url
                self.expires = expires
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedContactToken(let _data):
                return ("exportedContactToken", [("url", _data.url as Any), ("expires", _data.expires as Any)])
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
        public class Cons_exportedMessageLink {
            public var link: String
            public var html: String
            public init(link: String, html: String) {
                self.link = link
                self.html = html
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedMessageLink(let _data):
                return ("exportedMessageLink", [("link", _data.link as Any), ("html", _data.html as Any)])
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
        public class Cons_exportedStoryLink {
            public var link: String
            public init(link: String) {
                self.link = link
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedStoryLink(let _data):
                return ("exportedStoryLink", [("link", _data.link as Any)])
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
        public class Cons_factCheck {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .factCheck(let _data):
                return ("factCheck", [("flags", _data.flags as Any), ("country", _data.country as Any), ("text", _data.text as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_factCheck(_ reader: BufferReader) -> FactCheck? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = parseString(reader)
            }
            var _3: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
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
        public class Cons_fileHash {
            public var offset: Int64
            public var limit: Int32
            public var hash: Buffer
            public init(offset: Int64, limit: Int32, hash: Buffer) {
                self.offset = offset
                self.limit = limit
                self.hash = hash
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .fileHash(let _data):
                return ("fileHash", [("offset", _data.offset as Any), ("limit", _data.limit as Any), ("hash", _data.hash as Any)])
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
        public class Cons_folder {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .folder(let _data):
                return ("folder", [("flags", _data.flags as Any), ("id", _data.id as Any), ("title", _data.title as Any), ("photo", _data.photo as Any)])
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
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
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
        public class Cons_folderPeer {
            public var peer: Api.Peer
            public var folderId: Int32
            public init(peer: Api.Peer, folderId: Int32) {
                self.peer = peer
                self.folderId = folderId
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .folderPeer(let _data):
                return ("folderPeer", [("peer", _data.peer as Any), ("folderId", _data.folderId as Any)])
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
        public class Cons_forumTopic {
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
            public var fromId: Api.Peer
            public var notifySettings: Api.PeerNotifySettings
            public var draft: Api.DraftMessage?
            public init(flags: Int32, id: Int32, date: Int32, peer: Api.Peer, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?) {
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
                self.fromId = fromId
                self.notifySettings = notifySettings
                self.draft = draft
            }
        }
        public class Cons_forumTopicDeleted {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
        }
        case forumTopic(Cons_forumTopic)
        case forumTopicDeleted(Cons_forumTopicDeleted)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .forumTopic(let _data):
                if boxed {
                    buffer.appendInt32(-838922550)
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .forumTopic(let _data):
                return ("forumTopic", [("flags", _data.flags as Any), ("id", _data.id as Any), ("date", _data.date as Any), ("peer", _data.peer as Any), ("title", _data.title as Any), ("iconColor", _data.iconColor as Any), ("iconEmojiId", _data.iconEmojiId as Any), ("topMessage", _data.topMessage as Any), ("readInboxMaxId", _data.readInboxMaxId as Any), ("readOutboxMaxId", _data.readOutboxMaxId as Any), ("unreadCount", _data.unreadCount as Any), ("unreadMentionsCount", _data.unreadMentionsCount as Any), ("unreadReactionsCount", _data.unreadReactionsCount as Any), ("fromId", _data.fromId as Any), ("notifySettings", _data.notifySettings as Any), ("draft", _data.draft as Any)])
            case .forumTopicDeleted(let _data):
                return ("forumTopicDeleted", [("id", _data.id as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
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
            var _14: Api.Peer?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _15: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _16: Api.DraftMessage?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _16 = Api.parse(reader, signature: signature) as? Api.DraftMessage
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 4) == 0) || _16 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 {
                return Api.ForumTopic.forumTopic(Cons_forumTopic(flags: _1!, id: _2!, date: _3!, peer: _4!, title: _5!, iconColor: _6!, iconEmojiId: _7, topMessage: _8!, readInboxMaxId: _9!, readOutboxMaxId: _10!, unreadCount: _11!, unreadMentionsCount: _12!, unreadReactionsCount: _13!, fromId: _14!, notifySettings: _15!, draft: _16))
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
        public class Cons_foundStory {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .foundStory(let _data):
                return ("foundStory", [("peer", _data.peer as Any), ("story", _data.story as Any)])
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
        public class Cons_game {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .game(let _data):
                return ("game", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("shortName", _data.shortName as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("document", _data.document as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
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
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Game.game(Cons_game(flags: _1!, id: _2!, accessHash: _3!, shortName: _4!, title: _5!, description: _6!, photo: _7!, document: _8))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GeoPoint: TypeConstructorDescription {
        public class Cons_geoPoint {
            public var flags: Int32
            public var long: Double
            public var lat: Double
            public var accessHash: Int64
            public var accuracyRadius: Int32?
            public init(flags: Int32, long: Double, lat: Double, accessHash: Int64, accuracyRadius: Int32?) {
                self.flags = flags
                self.long = long
                self.lat = lat
                self.accessHash = accessHash
                self.accuracyRadius = accuracyRadius
            }
        }
        case geoPoint(Cons_geoPoint)
        case geoPointEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .geoPoint(let _data):
                if boxed {
                    buffer.appendInt32(-1297942941)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeDouble(_data.long, buffer: buffer, boxed: false)
                serializeDouble(_data.lat, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.accuracyRadius!, buffer: buffer, boxed: false)
                }
                break
            case .geoPointEmpty:
                if boxed {
                    buffer.appendInt32(286776671)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .geoPoint(let _data):
                return ("geoPoint", [("flags", _data.flags as Any), ("long", _data.long as Any), ("lat", _data.lat as Any), ("accessHash", _data.accessHash as Any), ("accuracyRadius", _data.accuracyRadius as Any)])
            case .geoPointEmpty:
                return ("geoPointEmpty", [])
            }
        }

        public static func parse_geoPoint(_ reader: BufferReader) -> GeoPoint? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.GeoPoint.geoPoint(Cons_geoPoint(flags: _1!, long: _2!, lat: _3!, accessHash: _4!, accuracyRadius: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_geoPointEmpty(_ reader: BufferReader) -> GeoPoint? {
            return Api.GeoPoint.geoPointEmpty
        }
    }
}
public extension Api {
    enum GeoPointAddress: TypeConstructorDescription {
        public class Cons_geoPointAddress {
            public var flags: Int32
            public var countryIso2: String
            public var state: String?
            public var city: String?
            public var street: String?
            public init(flags: Int32, countryIso2: String, state: String?, city: String?, street: String?) {
                self.flags = flags
                self.countryIso2 = countryIso2
                self.state = state
                self.city = city
                self.street = street
            }
        }
        case geoPointAddress(Cons_geoPointAddress)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .geoPointAddress(let _data):
                if boxed {
                    buffer.appendInt32(-565420653)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.countryIso2, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.state!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.city!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.street!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .geoPointAddress(let _data):
                return ("geoPointAddress", [("flags", _data.flags as Any), ("countryIso2", _data.countryIso2 as Any), ("state", _data.state as Any), ("city", _data.city as Any), ("street", _data.street as Any)])
            }
        }

        public static func parse_geoPointAddress(_ reader: BufferReader) -> GeoPointAddress? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.GeoPointAddress.geoPointAddress(Cons_geoPointAddress(flags: _1!, countryIso2: _2!, state: _3, city: _4, street: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GlobalPrivacySettings: TypeConstructorDescription {
        public class Cons_globalPrivacySettings {
            public var flags: Int32
            public var noncontactPeersPaidStars: Int64?
            public var disallowedGifts: Api.DisallowedGiftsSettings?
            public init(flags: Int32, noncontactPeersPaidStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?) {
                self.flags = flags
                self.noncontactPeersPaidStars = noncontactPeersPaidStars
                self.disallowedGifts = disallowedGifts
            }
        }
        case globalPrivacySettings(Cons_globalPrivacySettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .globalPrivacySettings(let _data):
                if boxed {
                    buffer.appendInt32(-29248689)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt64(_data.noncontactPeersPaidStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.disallowedGifts!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .globalPrivacySettings(let _data):
                return ("globalPrivacySettings", [("flags", _data.flags as Any), ("noncontactPeersPaidStars", _data.noncontactPeersPaidStars as Any), ("disallowedGifts", _data.disallowedGifts as Any)])
            }
        }

        public static func parse_globalPrivacySettings(_ reader: BufferReader) -> GlobalPrivacySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 5) != 0 {
                _2 = reader.readInt64()
            }
            var _3: Api.DisallowedGiftsSettings?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.DisallowedGiftsSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 5) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 6) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GlobalPrivacySettings.globalPrivacySettings(Cons_globalPrivacySettings(flags: _1!, noncontactPeersPaidStars: _2, disallowedGifts: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCall: TypeConstructorDescription {
        public class Cons_groupCall {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var participantsCount: Int32
            public var title: String?
            public var streamDcId: Int32?
            public var recordStartDate: Int32?
            public var scheduleDate: Int32?
            public var unmutedVideoCount: Int32?
            public var unmutedVideoLimit: Int32
            public var version: Int32
            public var inviteLink: String?
            public var sendPaidMessagesStars: Int64?
            public var defaultSendAs: Api.Peer?
            public init(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32, inviteLink: String?, sendPaidMessagesStars: Int64?, defaultSendAs: Api.Peer?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.participantsCount = participantsCount
                self.title = title
                self.streamDcId = streamDcId
                self.recordStartDate = recordStartDate
                self.scheduleDate = scheduleDate
                self.unmutedVideoCount = unmutedVideoCount
                self.unmutedVideoLimit = unmutedVideoLimit
                self.version = version
                self.inviteLink = inviteLink
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.defaultSendAs = defaultSendAs
            }
        }
        public class Cons_groupCallDiscarded {
            public var id: Int64
            public var accessHash: Int64
            public var duration: Int32
            public init(id: Int64, accessHash: Int64, duration: Int32) {
                self.id = id
                self.accessHash = accessHash
                self.duration = duration
            }
        }
        case groupCall(Cons_groupCall)
        case groupCallDiscarded(Cons_groupCallDiscarded)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCall(let _data):
                if boxed {
                    buffer.appendInt32(-273500649)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.participantsCount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.streamDcId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.recordStartDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.scheduleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.unmutedVideoCount!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.unmutedVideoLimit, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.inviteLink!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    serializeInt64(_data.sendPaidMessagesStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 21) != 0 {
                    _data.defaultSendAs!.serialize(buffer, true)
                }
                break
            case .groupCallDiscarded(let _data):
                if boxed {
                    buffer.appendInt32(2004925620)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.duration, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCall(let _data):
                return ("groupCall", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("participantsCount", _data.participantsCount as Any), ("title", _data.title as Any), ("streamDcId", _data.streamDcId as Any), ("recordStartDate", _data.recordStartDate as Any), ("scheduleDate", _data.scheduleDate as Any), ("unmutedVideoCount", _data.unmutedVideoCount as Any), ("unmutedVideoLimit", _data.unmutedVideoLimit as Any), ("version", _data.version as Any), ("inviteLink", _data.inviteLink as Any), ("sendPaidMessagesStars", _data.sendPaidMessagesStars as Any), ("defaultSendAs", _data.defaultSendAs as Any)])
            case .groupCallDiscarded(let _data):
                return ("groupCallDiscarded", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("duration", _data.duration as Any)])
            }
        }

        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _12 = parseString(reader)
            }
            var _13: Int64?
            if Int(_1!) & Int(1 << 20) != 0 {
                _13 = reader.readInt64()
            }
            var _14: Api.Peer?
            if Int(_1!) & Int(1 << 21) != 0 {
                if let signature = reader.readInt32() {
                    _14 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 10) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 16) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 20) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 21) == 0) || _14 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 {
                return Api.GroupCall.groupCall(Cons_groupCall(flags: _1!, id: _2!, accessHash: _3!, participantsCount: _4!, title: _5, streamDcId: _6, recordStartDate: _7, scheduleDate: _8, unmutedVideoCount: _9, unmutedVideoLimit: _10!, version: _11!, inviteLink: _12, sendPaidMessagesStars: _13, defaultSendAs: _14))
            }
            else {
                return nil
            }
        }
        public static func parse_groupCallDiscarded(_ reader: BufferReader) -> GroupCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GroupCall.groupCallDiscarded(Cons_groupCallDiscarded(id: _1!, accessHash: _2!, duration: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallDonor: TypeConstructorDescription {
        public class Cons_groupCallDonor {
            public var flags: Int32
            public var peerId: Api.Peer?
            public var stars: Int64
            public init(flags: Int32, peerId: Api.Peer?, stars: Int64) {
                self.flags = flags
                self.peerId = peerId
                self.stars = stars
            }
        }
        case groupCallDonor(Cons_groupCallDonor)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallDonor(let _data):
                if boxed {
                    buffer.appendInt32(-297595771)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.peerId!.serialize(buffer, true)
                }
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallDonor(let _data):
                return ("groupCallDonor", [("flags", _data.flags as Any), ("peerId", _data.peerId as Any), ("stars", _data.stars as Any)])
            }
        }

        public static func parse_groupCallDonor(_ reader: BufferReader) -> GroupCallDonor? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GroupCallDonor.groupCallDonor(Cons_groupCallDonor(flags: _1!, peerId: _2, stars: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallMessage: TypeConstructorDescription {
        public class Cons_groupCallMessage {
            public var flags: Int32
            public var id: Int32
            public var fromId: Api.Peer
            public var date: Int32
            public var message: Api.TextWithEntities
            public var paidMessageStars: Int64?
            public init(flags: Int32, id: Int32, fromId: Api.Peer, date: Int32, message: Api.TextWithEntities, paidMessageStars: Int64?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.date = date
                self.message = message
                self.paidMessageStars = paidMessageStars
            }
        }
        case groupCallMessage(Cons_groupCallMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallMessage(let _data):
                if boxed {
                    buffer.appendInt32(445316222)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                _data.fromId.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.message.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.paidMessageStars!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallMessage(let _data):
                return ("groupCallMessage", [("flags", _data.flags as Any), ("id", _data.id as Any), ("fromId", _data.fromId as Any), ("date", _data.date as Any), ("message", _data.message as Any), ("paidMessageStars", _data.paidMessageStars as Any)])
            }
        }

        public static func parse_groupCallMessage(_ reader: BufferReader) -> GroupCallMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _6: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.GroupCallMessage.groupCallMessage(Cons_groupCallMessage(flags: _1!, id: _2!, fromId: _3!, date: _4!, message: _5!, paidMessageStars: _6))
            }
            else {
                return nil
            }
        }
    }
}
