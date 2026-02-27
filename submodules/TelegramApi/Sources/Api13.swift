public extension Api {
    enum InputQuickReplyShortcut: TypeConstructorDescription {
        public class Cons_inputQuickReplyShortcut {
            public var shortcut: String
            public init(shortcut: String) {
                self.shortcut = shortcut
            }
        }
        public class Cons_inputQuickReplyShortcutId {
            public var shortcutId: Int32
            public init(shortcutId: Int32) {
                self.shortcutId = shortcutId
            }
        }
        case inputQuickReplyShortcut(Cons_inputQuickReplyShortcut)
        case inputQuickReplyShortcutId(Cons_inputQuickReplyShortcutId)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputQuickReplyShortcut(let _data):
                if boxed {
                    buffer.appendInt32(609840449)
                }
                serializeString(_data.shortcut, buffer: buffer, boxed: false)
                break
            case .inputQuickReplyShortcutId(let _data):
                if boxed {
                    buffer.appendInt32(18418929)
                }
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputQuickReplyShortcut(let _data):
                return ("inputQuickReplyShortcut", [("shortcut", _data.shortcut as Any)])
            case .inputQuickReplyShortcutId(let _data):
                return ("inputQuickReplyShortcutId", [("shortcutId", _data.shortcutId as Any)])
            }
        }

        public static func parse_inputQuickReplyShortcut(_ reader: BufferReader) -> InputQuickReplyShortcut? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputQuickReplyShortcut.inputQuickReplyShortcut(Cons_inputQuickReplyShortcut(shortcut: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputQuickReplyShortcutId(_ reader: BufferReader) -> InputQuickReplyShortcut? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputQuickReplyShortcut.inputQuickReplyShortcutId(Cons_inputQuickReplyShortcutId(shortcutId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputReplyTo: TypeConstructorDescription {
        public class Cons_inputReplyToMessage {
            public var flags: Int32
            public var replyToMsgId: Int32
            public var topMsgId: Int32?
            public var replyToPeerId: Api.InputPeer?
            public var quoteText: String?
            public var quoteEntities: [Api.MessageEntity]?
            public var quoteOffset: Int32?
            public var monoforumPeerId: Api.InputPeer?
            public var todoItemId: Int32?
            public init(flags: Int32, replyToMsgId: Int32, topMsgId: Int32?, replyToPeerId: Api.InputPeer?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, monoforumPeerId: Api.InputPeer?, todoItemId: Int32?) {
                self.flags = flags
                self.replyToMsgId = replyToMsgId
                self.topMsgId = topMsgId
                self.replyToPeerId = replyToPeerId
                self.quoteText = quoteText
                self.quoteEntities = quoteEntities
                self.quoteOffset = quoteOffset
                self.monoforumPeerId = monoforumPeerId
                self.todoItemId = todoItemId
            }
        }
        public class Cons_inputReplyToMonoForum {
            public var monoforumPeerId: Api.InputPeer
            public init(monoforumPeerId: Api.InputPeer) {
                self.monoforumPeerId = monoforumPeerId
            }
        }
        public class Cons_inputReplyToStory {
            public var peer: Api.InputPeer
            public var storyId: Int32
            public init(peer: Api.InputPeer, storyId: Int32) {
                self.peer = peer
                self.storyId = storyId
            }
        }
        case inputReplyToMessage(Cons_inputReplyToMessage)
        case inputReplyToMonoForum(Cons_inputReplyToMonoForum)
        case inputReplyToStory(Cons_inputReplyToStory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputReplyToMessage(let _data):
                if boxed {
                    buffer.appendInt32(-2036351472)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.replyToMsgId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.replyToPeerId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.quoteText!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.quoteEntities!.count))
                    for item in _data.quoteEntities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.quoteOffset!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.monoforumPeerId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.todoItemId!, buffer: buffer, boxed: false)
                }
                break
            case .inputReplyToMonoForum(let _data):
                if boxed {
                    buffer.appendInt32(1775660101)
                }
                _data.monoforumPeerId.serialize(buffer, true)
                break
            case .inputReplyToStory(let _data):
                if boxed {
                    buffer.appendInt32(1484862010)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.storyId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputReplyToMessage(let _data):
                return ("inputReplyToMessage", [("flags", _data.flags as Any), ("replyToMsgId", _data.replyToMsgId as Any), ("topMsgId", _data.topMsgId as Any), ("replyToPeerId", _data.replyToPeerId as Any), ("quoteText", _data.quoteText as Any), ("quoteEntities", _data.quoteEntities as Any), ("quoteOffset", _data.quoteOffset as Any), ("monoforumPeerId", _data.monoforumPeerId as Any), ("todoItemId", _data.todoItemId as Any)])
            case .inputReplyToMonoForum(let _data):
                return ("inputReplyToMonoForum", [("monoforumPeerId", _data.monoforumPeerId as Any)])
            case .inputReplyToStory(let _data):
                return ("inputReplyToStory", [("peer", _data.peer as Any), ("storyId", _data.storyId as Any)])
            }
        }

        public static func parse_inputReplyToMessage(_ reader: BufferReader) -> InputReplyTo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.InputPeer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Api.InputPeer?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {
                _9 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputReplyTo.inputReplyToMessage(Cons_inputReplyToMessage(flags: _1!, replyToMsgId: _2!, topMsgId: _3, replyToPeerId: _4, quoteText: _5, quoteEntities: _6, quoteOffset: _7, monoforumPeerId: _8, todoItemId: _9))
            }
            else {
                return nil
            }
        }
        public static func parse_inputReplyToMonoForum(_ reader: BufferReader) -> InputReplyTo? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputReplyTo.inputReplyToMonoForum(Cons_inputReplyToMonoForum(monoforumPeerId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputReplyToStory(_ reader: BufferReader) -> InputReplyTo? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputReplyTo.inputReplyToStory(Cons_inputReplyToStory(peer: _1!, storyId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputSavedStarGift: TypeConstructorDescription {
        public class Cons_inputSavedStarGiftChat {
            public var peer: Api.InputPeer
            public var savedId: Int64
            public init(peer: Api.InputPeer, savedId: Int64) {
                self.peer = peer
                self.savedId = savedId
            }
        }
        public class Cons_inputSavedStarGiftSlug {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        public class Cons_inputSavedStarGiftUser {
            public var msgId: Int32
            public init(msgId: Int32) {
                self.msgId = msgId
            }
        }
        case inputSavedStarGiftChat(Cons_inputSavedStarGiftChat)
        case inputSavedStarGiftSlug(Cons_inputSavedStarGiftSlug)
        case inputSavedStarGiftUser(Cons_inputSavedStarGiftUser)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputSavedStarGiftChat(let _data):
                if boxed {
                    buffer.appendInt32(-251549057)
                }
                _data.peer.serialize(buffer, true)
                serializeInt64(_data.savedId, buffer: buffer, boxed: false)
                break
            case .inputSavedStarGiftSlug(let _data):
                if boxed {
                    buffer.appendInt32(545636920)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            case .inputSavedStarGiftUser(let _data):
                if boxed {
                    buffer.appendInt32(1764202389)
                }
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputSavedStarGiftChat(let _data):
                return ("inputSavedStarGiftChat", [("peer", _data.peer as Any), ("savedId", _data.savedId as Any)])
            case .inputSavedStarGiftSlug(let _data):
                return ("inputSavedStarGiftSlug", [("slug", _data.slug as Any)])
            case .inputSavedStarGiftUser(let _data):
                return ("inputSavedStarGiftUser", [("msgId", _data.msgId as Any)])
            }
        }

        public static func parse_inputSavedStarGiftChat(_ reader: BufferReader) -> InputSavedStarGift? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputSavedStarGift.inputSavedStarGiftChat(Cons_inputSavedStarGiftChat(peer: _1!, savedId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputSavedStarGiftSlug(_ reader: BufferReader) -> InputSavedStarGift? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputSavedStarGift.inputSavedStarGiftSlug(Cons_inputSavedStarGiftSlug(slug: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputSavedStarGiftUser(_ reader: BufferReader) -> InputSavedStarGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputSavedStarGift.inputSavedStarGiftUser(Cons_inputSavedStarGiftUser(msgId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputSecureFile: TypeConstructorDescription {
        public class Cons_inputSecureFile {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputSecureFileUploaded {
            public var id: Int64
            public var parts: Int32
            public var md5Checksum: String
            public var fileHash: Buffer
            public var secret: Buffer
            public init(id: Int64, parts: Int32, md5Checksum: String, fileHash: Buffer, secret: Buffer) {
                self.id = id
                self.parts = parts
                self.md5Checksum = md5Checksum
                self.fileHash = fileHash
                self.secret = secret
            }
        }
        case inputSecureFile(Cons_inputSecureFile)
        case inputSecureFileUploaded(Cons_inputSecureFileUploaded)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputSecureFile(let _data):
                if boxed {
                    buffer.appendInt32(1399317950)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputSecureFileUploaded(let _data):
                if boxed {
                    buffer.appendInt32(859091184)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.parts, buffer: buffer, boxed: false)
                serializeString(_data.md5Checksum, buffer: buffer, boxed: false)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeBytes(_data.secret, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputSecureFile(let _data):
                return ("inputSecureFile", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            case .inputSecureFileUploaded(let _data):
                return ("inputSecureFileUploaded", [("id", _data.id as Any), ("parts", _data.parts as Any), ("md5Checksum", _data.md5Checksum as Any), ("fileHash", _data.fileHash as Any), ("secret", _data.secret as Any)])
            }
        }

        public static func parse_inputSecureFile(_ reader: BufferReader) -> InputSecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputSecureFile.inputSecureFile(Cons_inputSecureFile(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputSecureFileUploaded(_ reader: BufferReader) -> InputSecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputSecureFile.inputSecureFileUploaded(Cons_inputSecureFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, fileHash: _4!, secret: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputSecureValue: TypeConstructorDescription {
        public class Cons_inputSecureValue {
            public var flags: Int32
            public var type: Api.SecureValueType
            public var data: Api.SecureData?
            public var frontSide: Api.InputSecureFile?
            public var reverseSide: Api.InputSecureFile?
            public var selfie: Api.InputSecureFile?
            public var translation: [Api.InputSecureFile]?
            public var files: [Api.InputSecureFile]?
            public var plainData: Api.SecurePlainData?
            public init(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.InputSecureFile?, reverseSide: Api.InputSecureFile?, selfie: Api.InputSecureFile?, translation: [Api.InputSecureFile]?, files: [Api.InputSecureFile]?, plainData: Api.SecurePlainData?) {
                self.flags = flags
                self.type = type
                self.data = data
                self.frontSide = frontSide
                self.reverseSide = reverseSide
                self.selfie = selfie
                self.translation = translation
                self.files = files
                self.plainData = plainData
            }
        }
        case inputSecureValue(Cons_inputSecureValue)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputSecureValue(let _data):
                if boxed {
                    buffer.appendInt32(-618540889)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.data!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.frontSide!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.reverseSide!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.selfie!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.translation!.count))
                    for item in _data.translation! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.files!.count))
                    for item in _data.files! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.plainData!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputSecureValue(let _data):
                return ("inputSecureValue", [("flags", _data.flags as Any), ("type", _data.type as Any), ("data", _data.data as Any), ("frontSide", _data.frontSide as Any), ("reverseSide", _data.reverseSide as Any), ("selfie", _data.selfie as Any), ("translation", _data.translation as Any), ("files", _data.files as Any), ("plainData", _data.plainData as Any)])
            }
        }

        public static func parse_inputSecureValue(_ reader: BufferReader) -> InputSecureValue? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _3: Api.SecureData?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.SecureData
                }
            }
            var _4: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
                }
            }
            var _5: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
                }
            }
            var _6: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
                }
            }
            var _7: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let _ = reader.readInt32() {
                    _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
                }
            }
            var _8: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
                }
            }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputSecureValue.inputSecureValue(Cons_inputSecureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputSingleMedia: TypeConstructorDescription {
        public class Cons_inputSingleMedia {
            public var flags: Int32
            public var media: Api.InputMedia
            public var randomId: Int64
            public var message: String
            public var entities: [Api.MessageEntity]?
            public init(flags: Int32, media: Api.InputMedia, randomId: Int64, message: String, entities: [Api.MessageEntity]?) {
                self.flags = flags
                self.media = media
                self.randomId = randomId
                self.message = message
                self.entities = entities
            }
        }
        case inputSingleMedia(Cons_inputSingleMedia)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputSingleMedia(let _data):
                if boxed {
                    buffer.appendInt32(482797855)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.media.serialize(buffer, true)
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputSingleMedia(let _data):
                return ("inputSingleMedia", [("flags", _data.flags as Any), ("media", _data.media as Any), ("randomId", _data.randomId as Any), ("message", _data.message as Any), ("entities", _data.entities as Any)])
            }
        }

        public static func parse_inputSingleMedia(_ reader: BufferReader) -> InputSingleMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputMedia?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputMedia
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputSingleMedia.inputSingleMedia(Cons_inputSingleMedia(flags: _1!, media: _2!, randomId: _3!, message: _4!, entities: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputStarGiftAuction: TypeConstructorDescription {
        public class Cons_inputStarGiftAuction {
            public var giftId: Int64
            public init(giftId: Int64) {
                self.giftId = giftId
            }
        }
        public class Cons_inputStarGiftAuctionSlug {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        case inputStarGiftAuction(Cons_inputStarGiftAuction)
        case inputStarGiftAuctionSlug(Cons_inputStarGiftAuctionSlug)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStarGiftAuction(let _data):
                if boxed {
                    buffer.appendInt32(48327832)
                }
                serializeInt64(_data.giftId, buffer: buffer, boxed: false)
                break
            case .inputStarGiftAuctionSlug(let _data):
                if boxed {
                    buffer.appendInt32(2058715912)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputStarGiftAuction(let _data):
                return ("inputStarGiftAuction", [("giftId", _data.giftId as Any)])
            case .inputStarGiftAuctionSlug(let _data):
                return ("inputStarGiftAuctionSlug", [("slug", _data.slug as Any)])
            }
        }

        public static func parse_inputStarGiftAuction(_ reader: BufferReader) -> InputStarGiftAuction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStarGiftAuction.inputStarGiftAuction(Cons_inputStarGiftAuction(giftId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStarGiftAuctionSlug(_ reader: BufferReader) -> InputStarGiftAuction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStarGiftAuction.inputStarGiftAuctionSlug(Cons_inputStarGiftAuctionSlug(slug: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputStarsTransaction: TypeConstructorDescription {
        public class Cons_inputStarsTransaction {
            public var flags: Int32
            public var id: String
            public init(flags: Int32, id: String) {
                self.flags = flags
                self.id = id
            }
        }
        case inputStarsTransaction(Cons_inputStarsTransaction)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStarsTransaction(let _data):
                if boxed {
                    buffer.appendInt32(543876817)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputStarsTransaction(let _data):
                return ("inputStarsTransaction", [("flags", _data.flags as Any), ("id", _data.id as Any)])
            }
        }

        public static func parse_inputStarsTransaction(_ reader: BufferReader) -> InputStarsTransaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputStarsTransaction.inputStarsTransaction(Cons_inputStarsTransaction(flags: _1!, id: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputStickerSet: TypeConstructorDescription {
        public class Cons_inputStickerSetDice {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_inputStickerSetID {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputStickerSetShortName {
            public var shortName: String
            public init(shortName: String) {
                self.shortName = shortName
            }
        }
        case inputStickerSetAnimatedEmoji
        case inputStickerSetAnimatedEmojiAnimations
        case inputStickerSetDice(Cons_inputStickerSetDice)
        case inputStickerSetEmojiChannelDefaultStatuses
        case inputStickerSetEmojiDefaultStatuses
        case inputStickerSetEmojiDefaultTopicIcons
        case inputStickerSetEmojiGenericAnimations
        case inputStickerSetEmpty
        case inputStickerSetID(Cons_inputStickerSetID)
        case inputStickerSetPremiumGifts
        case inputStickerSetShortName(Cons_inputStickerSetShortName)
        case inputStickerSetTonGifts

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
            case .inputStickerSetDice(let _data):
                if boxed {
                    buffer.appendInt32(-427863538)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                break
            case .inputStickerSetEmojiChannelDefaultStatuses:
                if boxed {
                    buffer.appendInt32(1232373075)
                }
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
            case .inputStickerSetID(let _data):
                if boxed {
                    buffer.appendInt32(-1645763991)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputStickerSetPremiumGifts:
                if boxed {
                    buffer.appendInt32(-930399486)
                }
                break
            case .inputStickerSetShortName(let _data):
                if boxed {
                    buffer.appendInt32(-2044933984)
                }
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                break
            case .inputStickerSetTonGifts:
                if boxed {
                    buffer.appendInt32(485912992)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputStickerSetAnimatedEmoji:
                return ("inputStickerSetAnimatedEmoji", [])
            case .inputStickerSetAnimatedEmojiAnimations:
                return ("inputStickerSetAnimatedEmojiAnimations", [])
            case .inputStickerSetDice(let _data):
                return ("inputStickerSetDice", [("emoticon", _data.emoticon as Any)])
            case .inputStickerSetEmojiChannelDefaultStatuses:
                return ("inputStickerSetEmojiChannelDefaultStatuses", [])
            case .inputStickerSetEmojiDefaultStatuses:
                return ("inputStickerSetEmojiDefaultStatuses", [])
            case .inputStickerSetEmojiDefaultTopicIcons:
                return ("inputStickerSetEmojiDefaultTopicIcons", [])
            case .inputStickerSetEmojiGenericAnimations:
                return ("inputStickerSetEmojiGenericAnimations", [])
            case .inputStickerSetEmpty:
                return ("inputStickerSetEmpty", [])
            case .inputStickerSetID(let _data):
                return ("inputStickerSetID", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            case .inputStickerSetPremiumGifts:
                return ("inputStickerSetPremiumGifts", [])
            case .inputStickerSetShortName(let _data):
                return ("inputStickerSetShortName", [("shortName", _data.shortName as Any)])
            case .inputStickerSetTonGifts:
                return ("inputStickerSetTonGifts", [])
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
                return Api.InputStickerSet.inputStickerSetDice(Cons_inputStickerSetDice(emoticon: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetEmojiChannelDefaultStatuses(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmojiChannelDefaultStatuses
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
                return Api.InputStickerSet.inputStickerSetID(Cons_inputStickerSetID(id: _1!, accessHash: _2!))
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
                return Api.InputStickerSet.inputStickerSetShortName(Cons_inputStickerSetShortName(shortName: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetTonGifts(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetTonGifts
        }
    }
}
public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription {
        public class Cons_inputStickerSetItem {
            public var flags: Int32
            public var document: Api.InputDocument
            public var emoji: String
            public var maskCoords: Api.MaskCoords?
            public var keywords: String?
            public init(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?, keywords: String?) {
                self.flags = flags
                self.document = document
                self.emoji = emoji
                self.maskCoords = maskCoords
                self.keywords = keywords
            }
        }
        case inputStickerSetItem(Cons_inputStickerSetItem)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStickerSetItem(let _data):
                if boxed {
                    buffer.appendInt32(853188252)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                serializeString(_data.emoji, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.maskCoords!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.keywords!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputStickerSetItem(let _data):
                return ("inputStickerSetItem", [("flags", _data.flags as Any), ("document", _data.document as Any), ("emoji", _data.emoji as Any), ("maskCoords", _data.maskCoords as Any), ("keywords", _data.keywords as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.MaskCoords
                }
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputStickerSetItem.inputStickerSetItem(Cons_inputStickerSetItem(flags: _1!, document: _2!, emoji: _3!, maskCoords: _4, keywords: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputStickeredMedia: TypeConstructorDescription {
        public class Cons_inputStickeredMediaDocument {
            public var id: Api.InputDocument
            public init(id: Api.InputDocument) {
                self.id = id
            }
        }
        public class Cons_inputStickeredMediaPhoto {
            public var id: Api.InputPhoto
            public init(id: Api.InputPhoto) {
                self.id = id
            }
        }
        case inputStickeredMediaDocument(Cons_inputStickeredMediaDocument)
        case inputStickeredMediaPhoto(Cons_inputStickeredMediaPhoto)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStickeredMediaDocument(let _data):
                if boxed {
                    buffer.appendInt32(70813275)
                }
                _data.id.serialize(buffer, true)
                break
            case .inputStickeredMediaPhoto(let _data):
                if boxed {
                    buffer.appendInt32(1251549527)
                }
                _data.id.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputStickeredMediaDocument(let _data):
                return ("inputStickeredMediaDocument", [("id", _data.id as Any)])
            case .inputStickeredMediaPhoto(let _data):
                return ("inputStickeredMediaPhoto", [("id", _data.id as Any)])
            }
        }

        public static func parse_inputStickeredMediaDocument(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputDocument?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaDocument(Cons_inputStickeredMediaDocument(id: _1!))
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
                return Api.InputStickeredMedia.inputStickeredMediaPhoto(Cons_inputStickeredMediaPhoto(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputStorePaymentPurpose: TypeConstructorDescription {
        public class Cons_inputStorePaymentAuthCode {
            public var flags: Int32
            public var phoneNumber: String
            public var phoneCodeHash: String
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, phoneNumber: String, phoneCodeHash: String, currency: String, amount: Int64) {
                self.flags = flags
                self.phoneNumber = phoneNumber
                self.phoneCodeHash = phoneCodeHash
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentGiftPremium {
            public var userId: Api.InputUser
            public var currency: String
            public var amount: Int64
            public init(userId: Api.InputUser, currency: String, amount: Int64) {
                self.userId = userId
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentPremiumGiftCode {
            public var flags: Int32
            public var users: [Api.InputUser]
            public var boostPeer: Api.InputPeer?
            public var currency: String
            public var amount: Int64
            public var message: Api.TextWithEntities?
            public init(flags: Int32, users: [Api.InputUser], boostPeer: Api.InputPeer?, currency: String, amount: Int64, message: Api.TextWithEntities?) {
                self.flags = flags
                self.users = users
                self.boostPeer = boostPeer
                self.currency = currency
                self.amount = amount
                self.message = message
            }
        }
        public class Cons_inputStorePaymentPremiumGiveaway {
            public var flags: Int32
            public var boostPeer: Api.InputPeer
            public var additionalPeers: [Api.InputPeer]?
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var randomId: Int64
            public var untilDate: Int32
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64) {
                self.flags = flags
                self.boostPeer = boostPeer
                self.additionalPeers = additionalPeers
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.randomId = randomId
                self.untilDate = untilDate
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentPremiumSubscription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_inputStorePaymentStarsGift {
            public var userId: Api.InputUser
            public var stars: Int64
            public var currency: String
            public var amount: Int64
            public init(userId: Api.InputUser, stars: Int64, currency: String, amount: Int64) {
                self.userId = userId
                self.stars = stars
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentStarsGiveaway {
            public var flags: Int32
            public var stars: Int64
            public var boostPeer: Api.InputPeer
            public var additionalPeers: [Api.InputPeer]?
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var randomId: Int64
            public var untilDate: Int32
            public var currency: String
            public var amount: Int64
            public var users: Int32
            public init(flags: Int32, stars: Int64, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, users: Int32) {
                self.flags = flags
                self.stars = stars
                self.boostPeer = boostPeer
                self.additionalPeers = additionalPeers
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.randomId = randomId
                self.untilDate = untilDate
                self.currency = currency
                self.amount = amount
                self.users = users
            }
        }
        public class Cons_inputStorePaymentStarsTopup {
            public var flags: Int32
            public var stars: Int64
            public var currency: String
            public var amount: Int64
            public var spendPurposePeer: Api.InputPeer?
            public init(flags: Int32, stars: Int64, currency: String, amount: Int64, spendPurposePeer: Api.InputPeer?) {
                self.flags = flags
                self.stars = stars
                self.currency = currency
                self.amount = amount
                self.spendPurposePeer = spendPurposePeer
            }
        }
        case inputStorePaymentAuthCode(Cons_inputStorePaymentAuthCode)
        case inputStorePaymentGiftPremium(Cons_inputStorePaymentGiftPremium)
        case inputStorePaymentPremiumGiftCode(Cons_inputStorePaymentPremiumGiftCode)
        case inputStorePaymentPremiumGiveaway(Cons_inputStorePaymentPremiumGiveaway)
        case inputStorePaymentPremiumSubscription(Cons_inputStorePaymentPremiumSubscription)
        case inputStorePaymentStarsGift(Cons_inputStorePaymentStarsGift)
        case inputStorePaymentStarsGiveaway(Cons_inputStorePaymentStarsGiveaway)
        case inputStorePaymentStarsTopup(Cons_inputStorePaymentStarsTopup)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputStorePaymentAuthCode(let _data):
                if boxed {
                    buffer.appendInt32(-1682807955)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.phoneCodeHash, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentGiftPremium(let _data):
                if boxed {
                    buffer.appendInt32(1634697192)
                }
                _data.userId.serialize(buffer, true)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentPremiumGiftCode(let _data):
                if boxed {
                    buffer.appendInt32(-75955309)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.boostPeer!.serialize(buffer, true)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .inputStorePaymentPremiumGiveaway(let _data):
                if boxed {
                    buffer.appendInt32(369444042)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.boostPeer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.additionalPeers!.count))
                    for item in _data.additionalPeers! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.countriesIso2!.count))
                    for item in _data.countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.prizeDescription!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentPremiumSubscription(let _data):
                if boxed {
                    buffer.appendInt32(-1502273946)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentStarsGift(let _data):
                if boxed {
                    buffer.appendInt32(494149367)
                }
                _data.userId.serialize(buffer, true)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentStarsGiveaway(let _data):
                if boxed {
                    buffer.appendInt32(1964968186)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                _data.boostPeer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.additionalPeers!.count))
                    for item in _data.additionalPeers! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.countriesIso2!.count))
                    for item in _data.countriesIso2! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.prizeDescription!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeInt32(_data.users, buffer: buffer, boxed: false)
                break
            case .inputStorePaymentStarsTopup(let _data):
                if boxed {
                    buffer.appendInt32(-106780981)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.spendPurposePeer!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputStorePaymentAuthCode(let _data):
                return ("inputStorePaymentAuthCode", [("flags", _data.flags as Any), ("phoneNumber", _data.phoneNumber as Any), ("phoneCodeHash", _data.phoneCodeHash as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any)])
            case .inputStorePaymentGiftPremium(let _data):
                return ("inputStorePaymentGiftPremium", [("userId", _data.userId as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any)])
            case .inputStorePaymentPremiumGiftCode(let _data):
                return ("inputStorePaymentPremiumGiftCode", [("flags", _data.flags as Any), ("users", _data.users as Any), ("boostPeer", _data.boostPeer as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any), ("message", _data.message as Any)])
            case .inputStorePaymentPremiumGiveaway(let _data):
                return ("inputStorePaymentPremiumGiveaway", [("flags", _data.flags as Any), ("boostPeer", _data.boostPeer as Any), ("additionalPeers", _data.additionalPeers as Any), ("countriesIso2", _data.countriesIso2 as Any), ("prizeDescription", _data.prizeDescription as Any), ("randomId", _data.randomId as Any), ("untilDate", _data.untilDate as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any)])
            case .inputStorePaymentPremiumSubscription(let _data):
                return ("inputStorePaymentPremiumSubscription", [("flags", _data.flags as Any)])
            case .inputStorePaymentStarsGift(let _data):
                return ("inputStorePaymentStarsGift", [("userId", _data.userId as Any), ("stars", _data.stars as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any)])
            case .inputStorePaymentStarsGiveaway(let _data):
                return ("inputStorePaymentStarsGiveaway", [("flags", _data.flags as Any), ("stars", _data.stars as Any), ("boostPeer", _data.boostPeer as Any), ("additionalPeers", _data.additionalPeers as Any), ("countriesIso2", _data.countriesIso2 as Any), ("prizeDescription", _data.prizeDescription as Any), ("randomId", _data.randomId as Any), ("untilDate", _data.untilDate as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any), ("users", _data.users as Any)])
            case .inputStorePaymentStarsTopup(let _data):
                return ("inputStorePaymentStarsTopup", [("flags", _data.flags as Any), ("stars", _data.stars as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any), ("spendPurposePeer", _data.spendPurposePeer as Any)])
            }
        }

        public static func parse_inputStorePaymentAuthCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
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
                return Api.InputStorePaymentPurpose.inputStorePaymentAuthCode(Cons_inputStorePaymentAuthCode(flags: _1!, phoneNumber: _2!, phoneCodeHash: _3!, currency: _4!, amount: _5!))
            }
            else {
                return nil
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
                return Api.InputStorePaymentPurpose.inputStorePaymentGiftPremium(Cons_inputStorePaymentGiftPremium(userId: _1!, currency: _2!, amount: _3!))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumGiftCode(Cons_inputStorePaymentPremiumGiftCode(flags: _1!, users: _2!, boostPeer: _3, currency: _4!, amount: _5!, message: _6))
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
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
                }
            }
            var _4: [String]?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            var _5: String?
            if Int(_1!) & Int(1 << 4) != 0 {
                _5 = parseString(reader)
            }
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
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumGiveaway(Cons_inputStorePaymentPremiumGiveaway(flags: _1!, boostPeer: _2!, additionalPeers: _3, countriesIso2: _4, prizeDescription: _5, randomId: _6!, untilDate: _7!, currency: _8!, amount: _9!))
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
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumSubscription(Cons_inputStorePaymentPremiumSubscription(flags: _1!))
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
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsGift(Cons_inputStorePaymentStarsGift(userId: _1!, stars: _2!, currency: _3!, amount: _4!))
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
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
                }
            }
            var _5: [String]?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {
                _6 = parseString(reader)
            }
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
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsGiveaway(Cons_inputStorePaymentStarsGiveaway(flags: _1!, stars: _2!, boostPeer: _3!, additionalPeers: _4, countriesIso2: _5, prizeDescription: _6, randomId: _7!, untilDate: _8!, currency: _9!, amount: _10!, users: _11!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentStarsTopup(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Api.InputPeer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputStorePaymentPurpose.inputStorePaymentStarsTopup(Cons_inputStorePaymentStarsTopup(flags: _1!, stars: _2!, currency: _3!, amount: _4!, spendPurposePeer: _5))
            }
            else {
                return nil
            }
        }
    }
}
