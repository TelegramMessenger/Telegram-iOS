public extension Api {
    enum InputChatTheme: TypeConstructorDescription {
        public class Cons_inputChatTheme: TypeConstructorDescription {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputChatTheme", [("emoticon", ConstructorParameterDescription(self.emoticon))])
            }
        }
        public class Cons_inputChatThemeUniqueGift: TypeConstructorDescription {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputChatThemeUniqueGift", [("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        case inputChatTheme(Cons_inputChatTheme)
        case inputChatThemeEmpty
        case inputChatThemeUniqueGift(Cons_inputChatThemeUniqueGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputChatTheme(let _data):
                if boxed {
                    buffer.appendInt32(-918689444)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                break
            case .inputChatThemeEmpty:
                if boxed {
                    buffer.appendInt32(-2094627709)
                }
                break
            case .inputChatThemeUniqueGift(let _data):
                if boxed {
                    buffer.appendInt32(-2014978076)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputChatTheme(let _data):
                return ("inputChatTheme", [("emoticon", ConstructorParameterDescription(_data.emoticon))])
            case .inputChatThemeEmpty:
                return ("inputChatThemeEmpty", [])
            case .inputChatThemeUniqueGift(let _data):
                return ("inputChatThemeUniqueGift", [("slug", ConstructorParameterDescription(_data.slug))])
            }
        }

        public static func parse_inputChatTheme(_ reader: BufferReader) -> InputChatTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatTheme.inputChatTheme(Cons_inputChatTheme(emoticon: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputChatThemeEmpty(_ reader: BufferReader) -> InputChatTheme? {
            return Api.InputChatTheme.inputChatThemeEmpty
        }
        public static func parse_inputChatThemeUniqueGift(_ reader: BufferReader) -> InputChatTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatTheme.inputChatThemeUniqueGift(Cons_inputChatThemeUniqueGift(slug: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputChatlist: TypeConstructorDescription {
        public class Cons_inputChatlistDialogFilter: TypeConstructorDescription {
            public var filterId: Int32
            public init(filterId: Int32) {
                self.filterId = filterId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputChatlistDialogFilter", [("filterId", ConstructorParameterDescription(self.filterId))])
            }
        }
        case inputChatlistDialogFilter(Cons_inputChatlistDialogFilter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputChatlistDialogFilter(let _data):
                if boxed {
                    buffer.appendInt32(-203367885)
                }
                serializeInt32(_data.filterId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputChatlistDialogFilter(let _data):
                return ("inputChatlistDialogFilter", [("filterId", ConstructorParameterDescription(_data.filterId))])
            }
        }

        public static func parse_inputChatlistDialogFilter(_ reader: BufferReader) -> InputChatlist? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatlist.inputChatlistDialogFilter(Cons_inputChatlistDialogFilter(filterId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputCheckPasswordSRP: TypeConstructorDescription {
        public class Cons_inputCheckPasswordSRP: TypeConstructorDescription {
            public var srpId: Int64
            public var A: Buffer
            public var M1: Buffer
            public init(srpId: Int64, A: Buffer, M1: Buffer) {
                self.srpId = srpId
                self.A = A
                self.M1 = M1
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputCheckPasswordSRP", [("srpId", ConstructorParameterDescription(self.srpId)), ("A", ConstructorParameterDescription(self.A)), ("M1", ConstructorParameterDescription(self.M1))])
            }
        }
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(Cons_inputCheckPasswordSRP)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputCheckPasswordEmpty:
                if boxed {
                    buffer.appendInt32(-1736378792)
                }
                break
            case .inputCheckPasswordSRP(let _data):
                if boxed {
                    buffer.appendInt32(-763367294)
                }
                serializeInt64(_data.srpId, buffer: buffer, boxed: false)
                serializeBytes(_data.A, buffer: buffer, boxed: false)
                serializeBytes(_data.M1, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputCheckPasswordEmpty:
                return ("inputCheckPasswordEmpty", [])
            case .inputCheckPasswordSRP(let _data):
                return ("inputCheckPasswordSRP", [("srpId", ConstructorParameterDescription(_data.srpId)), ("A", ConstructorParameterDescription(_data.A)), ("M1", ConstructorParameterDescription(_data.M1))])
            }
        }

        public static func parse_inputCheckPasswordEmpty(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            return Api.InputCheckPasswordSRP.inputCheckPasswordEmpty
        }
        public static func parse_inputCheckPasswordSRP(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputCheckPasswordSRP.inputCheckPasswordSRP(Cons_inputCheckPasswordSRP(srpId: _1!, A: _2!, M1: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputClientProxy: TypeConstructorDescription {
        public class Cons_inputClientProxy: TypeConstructorDescription {
            public var address: String
            public var port: Int32
            public init(address: String, port: Int32) {
                self.address = address
                self.port = port
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputClientProxy", [("address", ConstructorParameterDescription(self.address)), ("port", ConstructorParameterDescription(self.port))])
            }
        }
        case inputClientProxy(Cons_inputClientProxy)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputClientProxy(let _data):
                if boxed {
                    buffer.appendInt32(1968737087)
                }
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeInt32(_data.port, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputClientProxy(let _data):
                return ("inputClientProxy", [("address", ConstructorParameterDescription(_data.address)), ("port", ConstructorParameterDescription(_data.port))])
            }
        }

        public static func parse_inputClientProxy(_ reader: BufferReader) -> InputClientProxy? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputClientProxy.inputClientProxy(Cons_inputClientProxy(address: _1!, port: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputCollectible: TypeConstructorDescription {
        public class Cons_inputCollectiblePhone: TypeConstructorDescription {
            public var phone: String
            public init(phone: String) {
                self.phone = phone
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputCollectiblePhone", [("phone", ConstructorParameterDescription(self.phone))])
            }
        }
        public class Cons_inputCollectibleUsername: TypeConstructorDescription {
            public var username: String
            public init(username: String) {
                self.username = username
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputCollectibleUsername", [("username", ConstructorParameterDescription(self.username))])
            }
        }
        case inputCollectiblePhone(Cons_inputCollectiblePhone)
        case inputCollectibleUsername(Cons_inputCollectibleUsername)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputCollectiblePhone(let _data):
                if boxed {
                    buffer.appendInt32(-1562241884)
                }
                serializeString(_data.phone, buffer: buffer, boxed: false)
                break
            case .inputCollectibleUsername(let _data):
                if boxed {
                    buffer.appendInt32(-476815191)
                }
                serializeString(_data.username, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputCollectiblePhone(let _data):
                return ("inputCollectiblePhone", [("phone", ConstructorParameterDescription(_data.phone))])
            case .inputCollectibleUsername(let _data):
                return ("inputCollectibleUsername", [("username", ConstructorParameterDescription(_data.username))])
            }
        }

        public static func parse_inputCollectiblePhone(_ reader: BufferReader) -> InputCollectible? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputCollectible.inputCollectiblePhone(Cons_inputCollectiblePhone(phone: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputCollectibleUsername(_ reader: BufferReader) -> InputCollectible? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputCollectible.inputCollectibleUsername(Cons_inputCollectibleUsername(username: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputContact: TypeConstructorDescription {
        public class Cons_inputPhoneContact: TypeConstructorDescription {
            public var flags: Int32
            public var clientId: Int64
            public var phone: String
            public var firstName: String
            public var lastName: String
            public var note: Api.TextWithEntities?
            public init(flags: Int32, clientId: Int64, phone: String, firstName: String, lastName: String, note: Api.TextWithEntities?) {
                self.flags = flags
                self.clientId = clientId
                self.phone = phone
                self.firstName = firstName
                self.lastName = lastName
                self.note = note
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPhoneContact", [("flags", ConstructorParameterDescription(self.flags)), ("clientId", ConstructorParameterDescription(self.clientId)), ("phone", ConstructorParameterDescription(self.phone)), ("firstName", ConstructorParameterDescription(self.firstName)), ("lastName", ConstructorParameterDescription(self.lastName)), ("note", ConstructorParameterDescription(self.note))])
            }
        }
        case inputPhoneContact(Cons_inputPhoneContact)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPhoneContact(let _data):
                if boxed {
                    buffer.appendInt32(1780335806)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.clientId, buffer: buffer, boxed: false)
                serializeString(_data.phone, buffer: buffer, boxed: false)
                serializeString(_data.firstName, buffer: buffer, boxed: false)
                serializeString(_data.lastName, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.note!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPhoneContact(let _data):
                return ("inputPhoneContact", [("flags", ConstructorParameterDescription(_data.flags)), ("clientId", ConstructorParameterDescription(_data.clientId)), ("phone", ConstructorParameterDescription(_data.phone)), ("firstName", ConstructorParameterDescription(_data.firstName)), ("lastName", ConstructorParameterDescription(_data.lastName)), ("note", ConstructorParameterDescription(_data.note))])
            }
        }

        public static func parse_inputPhoneContact(_ reader: BufferReader) -> InputContact? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.TextWithEntities?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputContact.inputPhoneContact(Cons_inputPhoneContact(flags: _1!, clientId: _2!, phone: _3!, firstName: _4!, lastName: _5!, note: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputDialogPeer: TypeConstructorDescription {
        public class Cons_inputDialogPeer: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputDialogPeer", [("peer", ConstructorParameterDescription(self.peer))])
            }
        }
        public class Cons_inputDialogPeerCommunity: TypeConstructorDescription {
            public var community: Api.InputChannel
            public init(community: Api.InputChannel) {
                self.community = community
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputDialogPeerCommunity", [("community", ConstructorParameterDescription(self.community))])
            }
        }
        public class Cons_inputDialogPeerFolder: TypeConstructorDescription {
            public var folderId: Int32
            public init(folderId: Int32) {
                self.folderId = folderId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputDialogPeerFolder", [("folderId", ConstructorParameterDescription(self.folderId))])
            }
        }
        case inputDialogPeer(Cons_inputDialogPeer)
        case inputDialogPeerCommunity(Cons_inputDialogPeerCommunity)
        case inputDialogPeerFolder(Cons_inputDialogPeerFolder)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputDialogPeer(let _data):
                if boxed {
                    buffer.appendInt32(-55902537)
                }
                _data.peer.serialize(buffer, true)
                break
            case .inputDialogPeerCommunity(let _data):
                if boxed {
                    buffer.appendInt32(1777300164)
                }
                _data.community.serialize(buffer, true)
                break
            case .inputDialogPeerFolder(let _data):
                if boxed {
                    buffer.appendInt32(1684014375)
                }
                serializeInt32(_data.folderId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputDialogPeer(let _data):
                return ("inputDialogPeer", [("peer", ConstructorParameterDescription(_data.peer))])
            case .inputDialogPeerCommunity(let _data):
                return ("inputDialogPeerCommunity", [("community", ConstructorParameterDescription(_data.community))])
            case .inputDialogPeerFolder(let _data):
                return ("inputDialogPeerFolder", [("folderId", ConstructorParameterDescription(_data.folderId))])
            }
        }

        public static func parse_inputDialogPeer(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeer(Cons_inputDialogPeer(peer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputDialogPeerCommunity(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Api.InputChannel?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputChannel
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeerCommunity(Cons_inputDialogPeerCommunity(community: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputDialogPeerFolder(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeerFolder(Cons_inputDialogPeerFolder(folderId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputDocument: TypeConstructorDescription {
        public class Cons_inputDocument: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public init(id: Int64, accessHash: Int64, fileReference: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputDocument", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference))])
            }
        }
        case inputDocument(Cons_inputDocument)
        case inputDocumentEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputDocument(let _data):
                if boxed {
                    buffer.appendInt32(448771445)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                break
            case .inputDocumentEmpty:
                if boxed {
                    buffer.appendInt32(1928391342)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputDocument(let _data):
                return ("inputDocument", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference))])
            case .inputDocumentEmpty:
                return ("inputDocumentEmpty", [])
            }
        }

        public static func parse_inputDocument(_ reader: BufferReader) -> InputDocument? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputDocument.inputDocument(Cons_inputDocument(id: _1!, accessHash: _2!, fileReference: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputDocumentEmpty(_ reader: BufferReader) -> InputDocument? {
            return Api.InputDocument.inputDocumentEmpty
        }
    }
}
public extension Api {
    enum InputEncryptedChat: TypeConstructorDescription {
        public class Cons_inputEncryptedChat: TypeConstructorDescription {
            public var chatId: Int32
            public var accessHash: Int64
            public init(chatId: Int32, accessHash: Int64) {
                self.chatId = chatId
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEncryptedChat", [("chatId", ConstructorParameterDescription(self.chatId)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        case inputEncryptedChat(Cons_inputEncryptedChat)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputEncryptedChat(let _data):
                if boxed {
                    buffer.appendInt32(-247351839)
                }
                serializeInt32(_data.chatId, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputEncryptedChat(let _data):
                return ("inputEncryptedChat", [("chatId", ConstructorParameterDescription(_data.chatId)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            }
        }

        public static func parse_inputEncryptedChat(_ reader: BufferReader) -> InputEncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputEncryptedChat.inputEncryptedChat(Cons_inputEncryptedChat(chatId: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputEncryptedFile: TypeConstructorDescription {
        public class Cons_inputEncryptedFile: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEncryptedFile", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputEncryptedFileBigUploaded: TypeConstructorDescription {
            public var id: Int64
            public var parts: Int32
            public var keyFingerprint: Int32
            public init(id: Int64, parts: Int32, keyFingerprint: Int32) {
                self.id = id
                self.parts = parts
                self.keyFingerprint = keyFingerprint
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEncryptedFileBigUploaded", [("id", ConstructorParameterDescription(self.id)), ("parts", ConstructorParameterDescription(self.parts)), ("keyFingerprint", ConstructorParameterDescription(self.keyFingerprint))])
            }
        }
        public class Cons_inputEncryptedFileUploaded: TypeConstructorDescription {
            public var id: Int64
            public var parts: Int32
            public var md5Checksum: String
            public var keyFingerprint: Int32
            public init(id: Int64, parts: Int32, md5Checksum: String, keyFingerprint: Int32) {
                self.id = id
                self.parts = parts
                self.md5Checksum = md5Checksum
                self.keyFingerprint = keyFingerprint
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEncryptedFileUploaded", [("id", ConstructorParameterDescription(self.id)), ("parts", ConstructorParameterDescription(self.parts)), ("md5Checksum", ConstructorParameterDescription(self.md5Checksum)), ("keyFingerprint", ConstructorParameterDescription(self.keyFingerprint))])
            }
        }
        case inputEncryptedFile(Cons_inputEncryptedFile)
        case inputEncryptedFileBigUploaded(Cons_inputEncryptedFileBigUploaded)
        case inputEncryptedFileEmpty
        case inputEncryptedFileUploaded(Cons_inputEncryptedFileUploaded)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputEncryptedFile(let _data):
                if boxed {
                    buffer.appendInt32(1511503333)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputEncryptedFileBigUploaded(let _data):
                if boxed {
                    buffer.appendInt32(767652808)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.parts, buffer: buffer, boxed: false)
                serializeInt32(_data.keyFingerprint, buffer: buffer, boxed: false)
                break
            case .inputEncryptedFileEmpty:
                if boxed {
                    buffer.appendInt32(406307684)
                }
                break
            case .inputEncryptedFileUploaded(let _data):
                if boxed {
                    buffer.appendInt32(1690108678)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.parts, buffer: buffer, boxed: false)
                serializeString(_data.md5Checksum, buffer: buffer, boxed: false)
                serializeInt32(_data.keyFingerprint, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputEncryptedFile(let _data):
                return ("inputEncryptedFile", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputEncryptedFileBigUploaded(let _data):
                return ("inputEncryptedFileBigUploaded", [("id", ConstructorParameterDescription(_data.id)), ("parts", ConstructorParameterDescription(_data.parts)), ("keyFingerprint", ConstructorParameterDescription(_data.keyFingerprint))])
            case .inputEncryptedFileEmpty:
                return ("inputEncryptedFileEmpty", [])
            case .inputEncryptedFileUploaded(let _data):
                return ("inputEncryptedFileUploaded", [("id", ConstructorParameterDescription(_data.id)), ("parts", ConstructorParameterDescription(_data.parts)), ("md5Checksum", ConstructorParameterDescription(_data.md5Checksum)), ("keyFingerprint", ConstructorParameterDescription(_data.keyFingerprint))])
            }
        }

        public static func parse_inputEncryptedFile(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputEncryptedFile.inputEncryptedFile(Cons_inputEncryptedFile(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileBigUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
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
                return Api.InputEncryptedFile.inputEncryptedFileBigUploaded(Cons_inputEncryptedFileBigUploaded(id: _1!, parts: _2!, keyFingerprint: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileEmpty(_ reader: BufferReader) -> InputEncryptedFile? {
            return Api.InputEncryptedFile.inputEncryptedFileEmpty
        }
        public static func parse_inputEncryptedFileUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputEncryptedFile.inputEncryptedFileUploaded(Cons_inputEncryptedFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, keyFingerprint: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputFile: TypeConstructorDescription {
        public class Cons_inputFile: TypeConstructorDescription {
            public var id: Int64
            public var parts: Int32
            public var name: String
            public var md5Checksum: String
            public init(id: Int64, parts: Int32, name: String, md5Checksum: String) {
                self.id = id
                self.parts = parts
                self.name = name
                self.md5Checksum = md5Checksum
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputFile", [("id", ConstructorParameterDescription(self.id)), ("parts", ConstructorParameterDescription(self.parts)), ("name", ConstructorParameterDescription(self.name)), ("md5Checksum", ConstructorParameterDescription(self.md5Checksum))])
            }
        }
        public class Cons_inputFileBig: TypeConstructorDescription {
            public var id: Int64
            public var parts: Int32
            public var name: String
            public init(id: Int64, parts: Int32, name: String) {
                self.id = id
                self.parts = parts
                self.name = name
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputFileBig", [("id", ConstructorParameterDescription(self.id)), ("parts", ConstructorParameterDescription(self.parts)), ("name", ConstructorParameterDescription(self.name))])
            }
        }
        public class Cons_inputFileStoryDocument: TypeConstructorDescription {
            public var id: Api.InputDocument
            public init(id: Api.InputDocument) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputFileStoryDocument", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case inputFile(Cons_inputFile)
        case inputFileBig(Cons_inputFileBig)
        case inputFileStoryDocument(Cons_inputFileStoryDocument)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputFile(let _data):
                if boxed {
                    buffer.appendInt32(-181407105)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.parts, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeString(_data.md5Checksum, buffer: buffer, boxed: false)
                break
            case .inputFileBig(let _data):
                if boxed {
                    buffer.appendInt32(-95482955)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.parts, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                break
            case .inputFileStoryDocument(let _data):
                if boxed {
                    buffer.appendInt32(1658620744)
                }
                _data.id.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputFile(let _data):
                return ("inputFile", [("id", ConstructorParameterDescription(_data.id)), ("parts", ConstructorParameterDescription(_data.parts)), ("name", ConstructorParameterDescription(_data.name)), ("md5Checksum", ConstructorParameterDescription(_data.md5Checksum))])
            case .inputFileBig(let _data):
                return ("inputFileBig", [("id", ConstructorParameterDescription(_data.id)), ("parts", ConstructorParameterDescription(_data.parts)), ("name", ConstructorParameterDescription(_data.name))])
            case .inputFileStoryDocument(let _data):
                return ("inputFileStoryDocument", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_inputFile(_ reader: BufferReader) -> InputFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFile.inputFile(Cons_inputFile(id: _1!, parts: _2!, name: _3!, md5Checksum: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileBig(_ reader: BufferReader) -> InputFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputFile.inputFileBig(Cons_inputFileBig(id: _1!, parts: _2!, name: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileStoryDocument(_ reader: BufferReader) -> InputFile? {
            var _1: Api.InputDocument?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputFile.inputFileStoryDocument(Cons_inputFileStoryDocument(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputFileLocation: TypeConstructorDescription {
        public class Cons_inputDocumentFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var thumbSize: String
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.thumbSize = thumbSize
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputDocumentFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference)), ("thumbSize", ConstructorParameterDescription(self.thumbSize))])
            }
        }
        public class Cons_inputEncryptedFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEncryptedFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputFileLocation: TypeConstructorDescription {
            public var volumeId: Int64
            public var localId: Int32
            public var secret: Int64
            public var fileReference: Buffer
            public init(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer) {
                self.volumeId = volumeId
                self.localId = localId
                self.secret = secret
                self.fileReference = fileReference
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputFileLocation", [("volumeId", ConstructorParameterDescription(self.volumeId)), ("localId", ConstructorParameterDescription(self.localId)), ("secret", ConstructorParameterDescription(self.secret)), ("fileReference", ConstructorParameterDescription(self.fileReference))])
            }
        }
        public class Cons_inputGroupCallStream: TypeConstructorDescription {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public var timeMs: Int64
            public var scale: Int32
            public var videoChannel: Int32?
            public var videoQuality: Int32?
            public init(flags: Int32, call: Api.InputGroupCall, timeMs: Int64, scale: Int32, videoChannel: Int32?, videoQuality: Int32?) {
                self.flags = flags
                self.call = call
                self.timeMs = timeMs
                self.scale = scale
                self.videoChannel = videoChannel
                self.videoQuality = videoQuality
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGroupCallStream", [("flags", ConstructorParameterDescription(self.flags)), ("call", ConstructorParameterDescription(self.call)), ("timeMs", ConstructorParameterDescription(self.timeMs)), ("scale", ConstructorParameterDescription(self.scale)), ("videoChannel", ConstructorParameterDescription(self.videoChannel)), ("videoQuality", ConstructorParameterDescription(self.videoQuality))])
            }
        }
        public class Cons_inputPeerPhotoFileLocation: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.InputPeer
            public var photoId: Int64
            public init(flags: Int32, peer: Api.InputPeer, photoId: Int64) {
                self.flags = flags
                self.peer = peer
                self.photoId = photoId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerPhotoFileLocation", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("photoId", ConstructorParameterDescription(self.photoId))])
            }
        }
        public class Cons_inputPhotoFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var thumbSize: String
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.thumbSize = thumbSize
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPhotoFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference)), ("thumbSize", ConstructorParameterDescription(self.thumbSize))])
            }
        }
        public class Cons_inputPhotoLegacyFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var volumeId: Int64
            public var localId: Int32
            public var secret: Int64
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, volumeId: Int64, localId: Int32, secret: Int64) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.volumeId = volumeId
                self.localId = localId
                self.secret = secret
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPhotoLegacyFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference)), ("volumeId", ConstructorParameterDescription(self.volumeId)), ("localId", ConstructorParameterDescription(self.localId)), ("secret", ConstructorParameterDescription(self.secret))])
            }
        }
        public class Cons_inputSecureFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSecureFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputStickerSetThumb: TypeConstructorDescription {
            public var stickerset: Api.InputStickerSet
            public var thumbVersion: Int32
            public init(stickerset: Api.InputStickerSet, thumbVersion: Int32) {
                self.stickerset = stickerset
                self.thumbVersion = thumbVersion
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickerSetThumb", [("stickerset", ConstructorParameterDescription(self.stickerset)), ("thumbVersion", ConstructorParameterDescription(self.thumbVersion))])
            }
        }
        case inputDocumentFileLocation(Cons_inputDocumentFileLocation)
        case inputEncryptedFileLocation(Cons_inputEncryptedFileLocation)
        case inputFileLocation(Cons_inputFileLocation)
        case inputGroupCallStream(Cons_inputGroupCallStream)
        case inputPeerPhotoFileLocation(Cons_inputPeerPhotoFileLocation)
        case inputPhotoFileLocation(Cons_inputPhotoFileLocation)
        case inputPhotoLegacyFileLocation(Cons_inputPhotoLegacyFileLocation)
        case inputSecureFileLocation(Cons_inputSecureFileLocation)
        case inputStickerSetThumb(Cons_inputStickerSetThumb)
        case inputTakeoutFileLocation

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputDocumentFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-1160743548)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                serializeString(_data.thumbSize, buffer: buffer, boxed: false)
                break
            case .inputEncryptedFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-182231723)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-539317279)
                }
                serializeInt64(_data.volumeId, buffer: buffer, boxed: false)
                serializeInt32(_data.localId, buffer: buffer, boxed: false)
                serializeInt64(_data.secret, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                break
            case .inputGroupCallStream(let _data):
                if boxed {
                    buffer.appendInt32(93890858)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.call.serialize(buffer, true)
                serializeInt64(_data.timeMs, buffer: buffer, boxed: false)
                serializeInt32(_data.scale, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.videoChannel!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.videoQuality!, buffer: buffer, boxed: false)
                }
                break
            case .inputPeerPhotoFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(925204121)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt64(_data.photoId, buffer: buffer, boxed: false)
                break
            case .inputPhotoFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(1075322878)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                serializeString(_data.thumbSize, buffer: buffer, boxed: false)
                break
            case .inputPhotoLegacyFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-667654413)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                serializeInt64(_data.volumeId, buffer: buffer, boxed: false)
                serializeInt32(_data.localId, buffer: buffer, boxed: false)
                serializeInt64(_data.secret, buffer: buffer, boxed: false)
                break
            case .inputSecureFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-876089816)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputStickerSetThumb(let _data):
                if boxed {
                    buffer.appendInt32(-1652231205)
                }
                _data.stickerset.serialize(buffer, true)
                serializeInt32(_data.thumbVersion, buffer: buffer, boxed: false)
                break
            case .inputTakeoutFileLocation:
                if boxed {
                    buffer.appendInt32(700340377)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputDocumentFileLocation(let _data):
                return ("inputDocumentFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference)), ("thumbSize", ConstructorParameterDescription(_data.thumbSize))])
            case .inputEncryptedFileLocation(let _data):
                return ("inputEncryptedFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputFileLocation(let _data):
                return ("inputFileLocation", [("volumeId", ConstructorParameterDescription(_data.volumeId)), ("localId", ConstructorParameterDescription(_data.localId)), ("secret", ConstructorParameterDescription(_data.secret)), ("fileReference", ConstructorParameterDescription(_data.fileReference))])
            case .inputGroupCallStream(let _data):
                return ("inputGroupCallStream", [("flags", ConstructorParameterDescription(_data.flags)), ("call", ConstructorParameterDescription(_data.call)), ("timeMs", ConstructorParameterDescription(_data.timeMs)), ("scale", ConstructorParameterDescription(_data.scale)), ("videoChannel", ConstructorParameterDescription(_data.videoChannel)), ("videoQuality", ConstructorParameterDescription(_data.videoQuality))])
            case .inputPeerPhotoFileLocation(let _data):
                return ("inputPeerPhotoFileLocation", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("photoId", ConstructorParameterDescription(_data.photoId))])
            case .inputPhotoFileLocation(let _data):
                return ("inputPhotoFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference)), ("thumbSize", ConstructorParameterDescription(_data.thumbSize))])
            case .inputPhotoLegacyFileLocation(let _data):
                return ("inputPhotoLegacyFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference)), ("volumeId", ConstructorParameterDescription(_data.volumeId)), ("localId", ConstructorParameterDescription(_data.localId)), ("secret", ConstructorParameterDescription(_data.secret))])
            case .inputSecureFileLocation(let _data):
                return ("inputSecureFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputStickerSetThumb(let _data):
                return ("inputStickerSetThumb", [("stickerset", ConstructorParameterDescription(_data.stickerset)), ("thumbVersion", ConstructorParameterDescription(_data.thumbVersion))])
            case .inputTakeoutFileLocation:
                return ("inputTakeoutFileLocation", [])
            }
        }

        public static func parse_inputDocumentFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputDocumentFileLocation(Cons_inputDocumentFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputEncryptedFileLocation(Cons_inputEncryptedFileLocation(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputFileLocation(Cons_inputFileLocation(volumeId: _1!, localId: _2!, secret: _3!, fileReference: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputGroupCallStream(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputFileLocation.inputGroupCallStream(Cons_inputGroupCallStream(flags: _1!, call: _2!, timeMs: _3!, scale: _4!, videoChannel: _5, videoQuality: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputFileLocation.inputPeerPhotoFileLocation(Cons_inputPeerPhotoFileLocation(flags: _1!, peer: _2!, photoId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputPhotoFileLocation(Cons_inputPhotoFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoLegacyFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputFileLocation.inputPhotoLegacyFileLocation(Cons_inputPhotoLegacyFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, volumeId: _4!, localId: _5!, secret: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputSecureFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputSecureFileLocation(Cons_inputSecureFileLocation(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetThumb(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputStickerSetThumb(Cons_inputStickerSetThumb(stickerset: _1!, thumbVersion: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputTakeoutFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            return Api.InputFileLocation.inputTakeoutFileLocation
        }
    }
}
