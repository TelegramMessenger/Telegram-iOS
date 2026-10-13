public extension Api {
    enum InputPrivacyRule: TypeConstructorDescription {
        public class Cons_inputPrivacyValueAllowChatParticipants: TypeConstructorDescription {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPrivacyValueAllowChatParticipants", [("chats", ConstructorParameterDescription(self.chats))])
            }
        }
        public class Cons_inputPrivacyValueAllowUsers: TypeConstructorDescription {
            public var users: [Api.InputUser]
            public init(users: [Api.InputUser]) {
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPrivacyValueAllowUsers", [("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_inputPrivacyValueDisallowChatParticipants: TypeConstructorDescription {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPrivacyValueDisallowChatParticipants", [("chats", ConstructorParameterDescription(self.chats))])
            }
        }
        public class Cons_inputPrivacyValueDisallowUsers: TypeConstructorDescription {
            public var users: [Api.InputUser]
            public init(users: [Api.InputUser]) {
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPrivacyValueDisallowUsers", [("users", ConstructorParameterDescription(self.users))])
            }
        }
        case inputPrivacyValueAllowAll
        case inputPrivacyValueAllowBots
        case inputPrivacyValueAllowChatParticipants(Cons_inputPrivacyValueAllowChatParticipants)
        case inputPrivacyValueAllowCloseFriends
        case inputPrivacyValueAllowContacts
        case inputPrivacyValueAllowPremium
        case inputPrivacyValueAllowUsers(Cons_inputPrivacyValueAllowUsers)
        case inputPrivacyValueDisallowAll
        case inputPrivacyValueDisallowBots
        case inputPrivacyValueDisallowChatParticipants(Cons_inputPrivacyValueDisallowChatParticipants)
        case inputPrivacyValueDisallowContacts
        case inputPrivacyValueDisallowUsers(Cons_inputPrivacyValueDisallowUsers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPrivacyValueAllowAll:
                if boxed {
                    buffer.appendInt32(407582158)
                }
                break
            case .inputPrivacyValueAllowBots:
                if boxed {
                    buffer.appendInt32(1515179237)
                }
                break
            case .inputPrivacyValueAllowChatParticipants(let _data):
                if boxed {
                    buffer.appendInt32(-2079962673)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .inputPrivacyValueAllowCloseFriends:
                if boxed {
                    buffer.appendInt32(793067081)
                }
                break
            case .inputPrivacyValueAllowContacts:
                if boxed {
                    buffer.appendInt32(218751099)
                }
                break
            case .inputPrivacyValueAllowPremium:
                if boxed {
                    buffer.appendInt32(2009975281)
                }
                break
            case .inputPrivacyValueAllowUsers(let _data):
                if boxed {
                    buffer.appendInt32(320652927)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .inputPrivacyValueDisallowAll:
                if boxed {
                    buffer.appendInt32(-697604407)
                }
                break
            case .inputPrivacyValueDisallowBots:
                if boxed {
                    buffer.appendInt32(-991594219)
                }
                break
            case .inputPrivacyValueDisallowChatParticipants(let _data):
                if boxed {
                    buffer.appendInt32(-380694650)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .inputPrivacyValueDisallowContacts:
                if boxed {
                    buffer.appendInt32(195371015)
                }
                break
            case .inputPrivacyValueDisallowUsers(let _data):
                if boxed {
                    buffer.appendInt32(-1877932953)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPrivacyValueAllowAll:
                return ("inputPrivacyValueAllowAll", [])
            case .inputPrivacyValueAllowBots:
                return ("inputPrivacyValueAllowBots", [])
            case .inputPrivacyValueAllowChatParticipants(let _data):
                return ("inputPrivacyValueAllowChatParticipants", [("chats", ConstructorParameterDescription(_data.chats))])
            case .inputPrivacyValueAllowCloseFriends:
                return ("inputPrivacyValueAllowCloseFriends", [])
            case .inputPrivacyValueAllowContacts:
                return ("inputPrivacyValueAllowContacts", [])
            case .inputPrivacyValueAllowPremium:
                return ("inputPrivacyValueAllowPremium", [])
            case .inputPrivacyValueAllowUsers(let _data):
                return ("inputPrivacyValueAllowUsers", [("users", ConstructorParameterDescription(_data.users))])
            case .inputPrivacyValueDisallowAll:
                return ("inputPrivacyValueDisallowAll", [])
            case .inputPrivacyValueDisallowBots:
                return ("inputPrivacyValueDisallowBots", [])
            case .inputPrivacyValueDisallowChatParticipants(let _data):
                return ("inputPrivacyValueDisallowChatParticipants", [("chats", ConstructorParameterDescription(_data.chats))])
            case .inputPrivacyValueDisallowContacts:
                return ("inputPrivacyValueDisallowContacts", [])
            case .inputPrivacyValueDisallowUsers(let _data):
                return ("inputPrivacyValueDisallowUsers", [("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_inputPrivacyValueAllowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowAll
        }
        public static func parse_inputPrivacyValueAllowBots(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowBots
        }
        public static func parse_inputPrivacyValueAllowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowChatParticipants(Cons_inputPrivacyValueAllowChatParticipants(chats: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueAllowCloseFriends(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowCloseFriends
        }
        public static func parse_inputPrivacyValueAllowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowContacts
        }
        public static func parse_inputPrivacyValueAllowPremium(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowPremium
        }
        public static func parse_inputPrivacyValueAllowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowUsers(Cons_inputPrivacyValueAllowUsers(users: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueDisallowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowAll
        }
        public static func parse_inputPrivacyValueDisallowBots(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowBots
        }
        public static func parse_inputPrivacyValueDisallowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueDisallowChatParticipants(Cons_inputPrivacyValueDisallowChatParticipants(chats: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueDisallowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowContacts
        }
        public static func parse_inputPrivacyValueDisallowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(Cons_inputPrivacyValueDisallowUsers(users: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputQuickReplyShortcut: TypeConstructorDescription {
        public class Cons_inputQuickReplyShortcut: TypeConstructorDescription {
            public var shortcut: String
            public init(shortcut: String) {
                self.shortcut = shortcut
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputQuickReplyShortcut", [("shortcut", ConstructorParameterDescription(self.shortcut))])
            }
        }
        public class Cons_inputQuickReplyShortcutId: TypeConstructorDescription {
            public var shortcutId: Int32
            public init(shortcutId: Int32) {
                self.shortcutId = shortcutId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputQuickReplyShortcutId", [("shortcutId", ConstructorParameterDescription(self.shortcutId))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputQuickReplyShortcut(let _data):
                return ("inputQuickReplyShortcut", [("shortcut", ConstructorParameterDescription(_data.shortcut))])
            case .inputQuickReplyShortcutId(let _data):
                return ("inputQuickReplyShortcutId", [("shortcutId", ConstructorParameterDescription(_data.shortcutId))])
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
        public class Cons_inputReplyToEphemeralMessage: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputReplyToEphemeralMessage", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_inputReplyToMessage: TypeConstructorDescription {
            public var flags: Int32
            public var replyToMsgId: Int32
            public var topMsgId: Int32?
            public var replyToPeerId: Api.InputPeer?
            public var quoteText: String?
            public var quoteEntities: [Api.MessageEntity]?
            public var quoteOffset: Int32?
            public var monoforumPeerId: Api.InputPeer?
            public var todoItemId: Int32?
            public var pollOption: Buffer?
            public init(flags: Int32, replyToMsgId: Int32, topMsgId: Int32?, replyToPeerId: Api.InputPeer?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, monoforumPeerId: Api.InputPeer?, todoItemId: Int32?, pollOption: Buffer?) {
                self.flags = flags
                self.replyToMsgId = replyToMsgId
                self.topMsgId = topMsgId
                self.replyToPeerId = replyToPeerId
                self.quoteText = quoteText
                self.quoteEntities = quoteEntities
                self.quoteOffset = quoteOffset
                self.monoforumPeerId = monoforumPeerId
                self.todoItemId = todoItemId
                self.pollOption = pollOption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputReplyToMessage", [("flags", ConstructorParameterDescription(self.flags)), ("replyToMsgId", ConstructorParameterDescription(self.replyToMsgId)), ("topMsgId", ConstructorParameterDescription(self.topMsgId)), ("replyToPeerId", ConstructorParameterDescription(self.replyToPeerId)), ("quoteText", ConstructorParameterDescription(self.quoteText)), ("quoteEntities", ConstructorParameterDescription(self.quoteEntities)), ("quoteOffset", ConstructorParameterDescription(self.quoteOffset)), ("monoforumPeerId", ConstructorParameterDescription(self.monoforumPeerId)), ("todoItemId", ConstructorParameterDescription(self.todoItemId)), ("pollOption", ConstructorParameterDescription(self.pollOption))])
            }
        }
        public class Cons_inputReplyToMonoForum: TypeConstructorDescription {
            public var monoforumPeerId: Api.InputPeer
            public init(monoforumPeerId: Api.InputPeer) {
                self.monoforumPeerId = monoforumPeerId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputReplyToMonoForum", [("monoforumPeerId", ConstructorParameterDescription(self.monoforumPeerId))])
            }
        }
        public class Cons_inputReplyToStory: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var storyId: Int32
            public init(peer: Api.InputPeer, storyId: Int32) {
                self.peer = peer
                self.storyId = storyId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputReplyToStory", [("peer", ConstructorParameterDescription(self.peer)), ("storyId", ConstructorParameterDescription(self.storyId))])
            }
        }
        case inputReplyToEphemeralMessage(Cons_inputReplyToEphemeralMessage)
        case inputReplyToMessage(Cons_inputReplyToMessage)
        case inputReplyToMonoForum(Cons_inputReplyToMonoForum)
        case inputReplyToStory(Cons_inputReplyToStory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputReplyToEphemeralMessage(let _data):
                if boxed {
                    buffer.appendInt32(1092204894)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            case .inputReplyToMessage(let _data):
                if boxed {
                    buffer.appendInt32(1003796418)
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
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeBytes(_data.pollOption!, buffer: buffer, boxed: false)
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputReplyToEphemeralMessage(let _data):
                return ("inputReplyToEphemeralMessage", [("id", ConstructorParameterDescription(_data.id))])
            case .inputReplyToMessage(let _data):
                return ("inputReplyToMessage", [("flags", ConstructorParameterDescription(_data.flags)), ("replyToMsgId", ConstructorParameterDescription(_data.replyToMsgId)), ("topMsgId", ConstructorParameterDescription(_data.topMsgId)), ("replyToPeerId", ConstructorParameterDescription(_data.replyToPeerId)), ("quoteText", ConstructorParameterDescription(_data.quoteText)), ("quoteEntities", ConstructorParameterDescription(_data.quoteEntities)), ("quoteOffset", ConstructorParameterDescription(_data.quoteOffset)), ("monoforumPeerId", ConstructorParameterDescription(_data.monoforumPeerId)), ("todoItemId", ConstructorParameterDescription(_data.todoItemId)), ("pollOption", ConstructorParameterDescription(_data.pollOption))])
            case .inputReplyToMonoForum(let _data):
                return ("inputReplyToMonoForum", [("monoforumPeerId", ConstructorParameterDescription(_data.monoforumPeerId))])
            case .inputReplyToStory(let _data):
                return ("inputReplyToStory", [("peer", ConstructorParameterDescription(_data.peer)), ("storyId", ConstructorParameterDescription(_data.storyId))])
            }
        }

        public static func parse_inputReplyToEphemeralMessage(_ reader: BufferReader) -> InputReplyTo? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputReplyTo.inputReplyToEphemeralMessage(Cons_inputReplyToEphemeralMessage(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputReplyToMessage(_ reader: BufferReader) -> InputReplyTo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.InputPeer?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: [Api.MessageEntity]?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _7: Int32?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Api.InputPeer?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            var _9: Int32?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Buffer?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                _10 = parseBytes(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.InputReplyTo.inputReplyToMessage(Cons_inputReplyToMessage(flags: _1!, replyToMsgId: _2!, topMsgId: _3, replyToPeerId: _4, quoteText: _5, quoteEntities: _6, quoteOffset: _7, monoforumPeerId: _8, todoItemId: _9, pollOption: _10))
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
    enum InputRichFile: TypeConstructorDescription {
        public class Cons_inputRichFileDocument: TypeConstructorDescription {
            public var id: String
            public var document: Api.InputDocument
            public init(id: String, document: Api.InputDocument) {
                self.id = id
                self.document = document
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputRichFileDocument", [("id", ConstructorParameterDescription(self.id)), ("document", ConstructorParameterDescription(self.document))])
            }
        }
        public class Cons_inputRichFilePhoto: TypeConstructorDescription {
            public var id: String
            public var photo: Api.InputPhoto
            public init(id: String, photo: Api.InputPhoto) {
                self.id = id
                self.photo = photo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputRichFilePhoto", [("id", ConstructorParameterDescription(self.id)), ("photo", ConstructorParameterDescription(self.photo))])
            }
        }
        case inputRichFileDocument(Cons_inputRichFileDocument)
        case inputRichFilePhoto(Cons_inputRichFilePhoto)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputRichFileDocument(let _data):
                if boxed {
                    buffer.appendInt32(-2094522947)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                break
            case .inputRichFilePhoto(let _data):
                if boxed {
                    buffer.appendInt32(-1694473685)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                _data.photo.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputRichFileDocument(let _data):
                return ("inputRichFileDocument", [("id", ConstructorParameterDescription(_data.id)), ("document", ConstructorParameterDescription(_data.document))])
            case .inputRichFilePhoto(let _data):
                return ("inputRichFilePhoto", [("id", ConstructorParameterDescription(_data.id)), ("photo", ConstructorParameterDescription(_data.photo))])
            }
        }

        public static func parse_inputRichFileDocument(_ reader: BufferReader) -> InputRichFile? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.InputDocument?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputRichFile.inputRichFileDocument(Cons_inputRichFileDocument(id: _1!, document: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputRichFilePhoto(_ reader: BufferReader) -> InputRichFile? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputRichFile.inputRichFilePhoto(Cons_inputRichFilePhoto(id: _1!, photo: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputRichMessage: TypeConstructorDescription {
        public class Cons_inputRichMessage: TypeConstructorDescription {
            public var flags: Int32
            public var blocks: [Api.PageBlock]
            public var photos: [Api.InputPhoto]?
            public var documents: [Api.InputDocument]?
            public var users: [Api.InputUser]?
            public init(flags: Int32, blocks: [Api.PageBlock], photos: [Api.InputPhoto]?, documents: [Api.InputDocument]?, users: [Api.InputUser]?) {
                self.flags = flags
                self.blocks = blocks
                self.photos = photos
                self.documents = documents
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputRichMessage", [("flags", ConstructorParameterDescription(self.flags)), ("blocks", ConstructorParameterDescription(self.blocks)), ("photos", ConstructorParameterDescription(self.photos)), ("documents", ConstructorParameterDescription(self.documents)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_inputRichMessageHTML: TypeConstructorDescription {
            public var flags: Int32
            public var html: String
            public var files: [Api.InputRichFile]?
            public init(flags: Int32, html: String, files: [Api.InputRichFile]?) {
                self.flags = flags
                self.html = html
                self.files = files
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputRichMessageHTML", [("flags", ConstructorParameterDescription(self.flags)), ("html", ConstructorParameterDescription(self.html)), ("files", ConstructorParameterDescription(self.files))])
            }
        }
        public class Cons_inputRichMessageMarkdown: TypeConstructorDescription {
            public var flags: Int32
            public var markdown: String
            public var files: [Api.InputRichFile]?
            public init(flags: Int32, markdown: String, files: [Api.InputRichFile]?) {
                self.flags = flags
                self.markdown = markdown
                self.files = files
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputRichMessageMarkdown", [("flags", ConstructorParameterDescription(self.flags)), ("markdown", ConstructorParameterDescription(self.markdown)), ("files", ConstructorParameterDescription(self.files))])
            }
        }
        case inputRichMessage(Cons_inputRichMessage)
        case inputRichMessageHTML(Cons_inputRichMessageHTML)
        case inputRichMessageMarkdown(Cons_inputRichMessageMarkdown)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputRichMessage(let _data):
                if boxed {
                    buffer.appendInt32(-456898052)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.photos!.count))
                    for item in _data.photos! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.documents!.count))
                    for item in _data.documents! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.users!.count))
                    for item in _data.users! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .inputRichMessageHTML(let _data):
                if boxed {
                    buffer.appendInt32(-624196758)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.html, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.files!.count))
                    for item in _data.files! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .inputRichMessageMarkdown(let _data):
                if boxed {
                    buffer.appendInt32(4937516)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.markdown, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.files!.count))
                    for item in _data.files! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputRichMessage(let _data):
                return ("inputRichMessage", [("flags", ConstructorParameterDescription(_data.flags)), ("blocks", ConstructorParameterDescription(_data.blocks)), ("photos", ConstructorParameterDescription(_data.photos)), ("documents", ConstructorParameterDescription(_data.documents)), ("users", ConstructorParameterDescription(_data.users))])
            case .inputRichMessageHTML(let _data):
                return ("inputRichMessageHTML", [("flags", ConstructorParameterDescription(_data.flags)), ("html", ConstructorParameterDescription(_data.html)), ("files", ConstructorParameterDescription(_data.files))])
            case .inputRichMessageMarkdown(let _data):
                return ("inputRichMessageMarkdown", [("flags", ConstructorParameterDescription(_data.flags)), ("markdown", ConstructorParameterDescription(_data.markdown)), ("files", ConstructorParameterDescription(_data.files))])
            }
        }

        public static func parse_inputRichMessage(_ reader: BufferReader) -> InputRichMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _3: [Api.InputPhoto]?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPhoto.self)
                }
            }
            var _4: [Api.InputDocument]?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputDocument.self)
                }
            }
            var _5: [Api.InputUser]?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputRichMessage.inputRichMessage(Cons_inputRichMessage(flags: _1!, blocks: _2!, photos: _3, documents: _4, users: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_inputRichMessageHTML(_ reader: BufferReader) -> InputRichMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.InputRichFile]?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputRichFile.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputRichMessage.inputRichMessageHTML(Cons_inputRichMessageHTML(flags: _1!, html: _2!, files: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_inputRichMessageMarkdown(_ reader: BufferReader) -> InputRichMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.InputRichFile]?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputRichFile.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputRichMessage.inputRichMessageMarkdown(Cons_inputRichMessageMarkdown(flags: _1!, markdown: _2!, files: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputSavedStarGift: TypeConstructorDescription {
        public class Cons_inputSavedStarGiftChat: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var savedId: Int64
            public init(peer: Api.InputPeer, savedId: Int64) {
                self.peer = peer
                self.savedId = savedId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSavedStarGiftChat", [("peer", ConstructorParameterDescription(self.peer)), ("savedId", ConstructorParameterDescription(self.savedId))])
            }
        }
        public class Cons_inputSavedStarGiftSlug: TypeConstructorDescription {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSavedStarGiftSlug", [("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        public class Cons_inputSavedStarGiftUser: TypeConstructorDescription {
            public var msgId: Int32
            public init(msgId: Int32) {
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSavedStarGiftUser", [("msgId", ConstructorParameterDescription(self.msgId))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputSavedStarGiftChat(let _data):
                return ("inputSavedStarGiftChat", [("peer", ConstructorParameterDescription(_data.peer)), ("savedId", ConstructorParameterDescription(_data.savedId))])
            case .inputSavedStarGiftSlug(let _data):
                return ("inputSavedStarGiftSlug", [("slug", ConstructorParameterDescription(_data.slug))])
            case .inputSavedStarGiftUser(let _data):
                return ("inputSavedStarGiftUser", [("msgId", ConstructorParameterDescription(_data.msgId))])
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
        public class Cons_inputSecureFile: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSecureFile", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputSecureFileUploaded: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSecureFileUploaded", [("id", ConstructorParameterDescription(self.id)), ("parts", ConstructorParameterDescription(self.parts)), ("md5Checksum", ConstructorParameterDescription(self.md5Checksum)), ("fileHash", ConstructorParameterDescription(self.fileHash)), ("secret", ConstructorParameterDescription(self.secret))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputSecureFile(let _data):
                return ("inputSecureFile", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputSecureFileUploaded(let _data):
                return ("inputSecureFileUploaded", [("id", ConstructorParameterDescription(_data.id)), ("parts", ConstructorParameterDescription(_data.parts)), ("md5Checksum", ConstructorParameterDescription(_data.md5Checksum)), ("fileHash", ConstructorParameterDescription(_data.fileHash)), ("secret", ConstructorParameterDescription(_data.secret))])
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
        public class Cons_inputSecureValue: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSecureValue", [("flags", ConstructorParameterDescription(self.flags)), ("type", ConstructorParameterDescription(self.type)), ("data", ConstructorParameterDescription(self.data)), ("frontSide", ConstructorParameterDescription(self.frontSide)), ("reverseSide", ConstructorParameterDescription(self.reverseSide)), ("selfie", ConstructorParameterDescription(self.selfie)), ("translation", ConstructorParameterDescription(self.translation)), ("files", ConstructorParameterDescription(self.files)), ("plainData", ConstructorParameterDescription(self.plainData))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputSecureValue(let _data):
                return ("inputSecureValue", [("flags", ConstructorParameterDescription(_data.flags)), ("type", ConstructorParameterDescription(_data.type)), ("data", ConstructorParameterDescription(_data.data)), ("frontSide", ConstructorParameterDescription(_data.frontSide)), ("reverseSide", ConstructorParameterDescription(_data.reverseSide)), ("selfie", ConstructorParameterDescription(_data.selfie)), ("translation", ConstructorParameterDescription(_data.translation)), ("files", ConstructorParameterDescription(_data.files)), ("plainData", ConstructorParameterDescription(_data.plainData))])
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.SecureData
                }
            }
            var _4: Api.InputSecureFile?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
                }
            }
            var _5: Api.InputSecureFile?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
                }
            }
            var _6: Api.InputSecureFile?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
                }
            }
            var _7: [Api.InputSecureFile]?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let _ = reader.readInt32() {
                    _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
                }
            }
            var _8: [Api.InputSecureFile]?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
                }
            }
            var _9: Api.SecurePlainData?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _9 != nil
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
        public class Cons_inputSingleMedia: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSingleMedia", [("flags", ConstructorParameterDescription(self.flags)), ("media", ConstructorParameterDescription(self.media)), ("randomId", ConstructorParameterDescription(self.randomId)), ("message", ConstructorParameterDescription(self.message)), ("entities", ConstructorParameterDescription(self.entities))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputSingleMedia(let _data):
                return ("inputSingleMedia", [("flags", ConstructorParameterDescription(_data.flags)), ("media", ConstructorParameterDescription(_data.media)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("message", ConstructorParameterDescription(_data.message)), ("entities", ConstructorParameterDescription(_data.entities))])
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
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
        public class Cons_inputStarGiftAuction: TypeConstructorDescription {
            public var giftId: Int64
            public init(giftId: Int64) {
                self.giftId = giftId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStarGiftAuction", [("giftId", ConstructorParameterDescription(self.giftId))])
            }
        }
        public class Cons_inputStarGiftAuctionSlug: TypeConstructorDescription {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStarGiftAuctionSlug", [("slug", ConstructorParameterDescription(self.slug))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputStarGiftAuction(let _data):
                return ("inputStarGiftAuction", [("giftId", ConstructorParameterDescription(_data.giftId))])
            case .inputStarGiftAuctionSlug(let _data):
                return ("inputStarGiftAuctionSlug", [("slug", ConstructorParameterDescription(_data.slug))])
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
