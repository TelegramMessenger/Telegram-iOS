public extension Api.messages {
    enum ExportedChatInvite: TypeConstructorDescription {
        public class Cons_exportedChatInvite: TypeConstructorDescription {
            public var invite: Api.ExportedChatInvite
            public var users: [Api.User]
            public init(invite: Api.ExportedChatInvite, users: [Api.User]) {
                self.invite = invite
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedChatInvite", [("invite", ConstructorParameterDescription(self.invite)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_exportedChatInviteReplaced: TypeConstructorDescription {
            public var invite: Api.ExportedChatInvite
            public var newInvite: Api.ExportedChatInvite
            public var users: [Api.User]
            public init(invite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite, users: [Api.User]) {
                self.invite = invite
                self.newInvite = newInvite
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedChatInviteReplaced", [("invite", ConstructorParameterDescription(self.invite)), ("newInvite", ConstructorParameterDescription(self.newInvite)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case exportedChatInvite(Cons_exportedChatInvite)
        case exportedChatInviteReplaced(Cons_exportedChatInviteReplaced)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedChatInvite(let _data):
                if boxed {
                    buffer.appendInt32(410107472)
                }
                _data.invite.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .exportedChatInviteReplaced(let _data):
                if boxed {
                    buffer.appendInt32(572915951)
                }
                _data.invite.serialize(buffer, true)
                _data.newInvite.serialize(buffer, true)
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
            case .exportedChatInvite(let _data):
                return ("exportedChatInvite", [("invite", ConstructorParameterDescription(_data.invite)), ("users", ConstructorParameterDescription(_data.users))])
            case .exportedChatInviteReplaced(let _data):
                return ("exportedChatInviteReplaced", [("invite", ConstructorParameterDescription(_data.invite)), ("newInvite", ConstructorParameterDescription(_data.newInvite)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_exportedChatInvite(_ reader: BufferReader) -> ExportedChatInvite? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.ExportedChatInvite.exportedChatInvite(Cons_exportedChatInvite(invite: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_exportedChatInviteReplaced(_ reader: BufferReader) -> ExportedChatInvite? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.ExportedChatInvite.exportedChatInviteReplaced(Cons_exportedChatInviteReplaced(invite: _1!, newInvite: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum ExportedChatInvites: TypeConstructorDescription {
        public class Cons_exportedChatInvites: TypeConstructorDescription {
            public var count: Int32
            public var invites: [Api.ExportedChatInvite]
            public var users: [Api.User]
            public init(count: Int32, invites: [Api.ExportedChatInvite], users: [Api.User]) {
                self.count = count
                self.invites = invites
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedChatInvites", [("count", ConstructorParameterDescription(self.count)), ("invites", ConstructorParameterDescription(self.invites)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case exportedChatInvites(Cons_exportedChatInvites)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedChatInvites(let _data):
                if boxed {
                    buffer.appendInt32(-1111085620)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.invites.count))
                for item in _data.invites {
                    item.serialize(buffer, true)
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
            case .exportedChatInvites(let _data):
                return ("exportedChatInvites", [("count", ConstructorParameterDescription(_data.count)), ("invites", ConstructorParameterDescription(_data.invites)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_exportedChatInvites(_ reader: BufferReader) -> ExportedChatInvites? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ExportedChatInvite]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ExportedChatInvite.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.ExportedChatInvites.exportedChatInvites(Cons_exportedChatInvites(count: _1!, invites: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum FavedStickers: TypeConstructorDescription {
        public class Cons_favedStickers: TypeConstructorDescription {
            public var hash: Int64
            public var packs: [Api.StickerPack]
            public var stickers: [Api.Document]
            public init(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document]) {
                self.hash = hash
                self.packs = packs
                self.stickers = stickers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("favedStickers", [("hash", ConstructorParameterDescription(self.hash)), ("packs", ConstructorParameterDescription(self.packs)), ("stickers", ConstructorParameterDescription(self.stickers))])
            }
        }
        case favedStickers(Cons_favedStickers)
        case favedStickersNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .favedStickers(let _data):
                if boxed {
                    buffer.appendInt32(750063767)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.packs.count))
                for item in _data.packs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stickers.count))
                for item in _data.stickers {
                    item.serialize(buffer, true)
                }
                break
            case .favedStickersNotModified:
                if boxed {
                    buffer.appendInt32(-1634752813)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .favedStickers(let _data):
                return ("favedStickers", [("hash", ConstructorParameterDescription(_data.hash)), ("packs", ConstructorParameterDescription(_data.packs)), ("stickers", ConstructorParameterDescription(_data.stickers))])
            case .favedStickersNotModified:
                return ("favedStickersNotModified", [])
            }
        }

        public static func parse_favedStickers(_ reader: BufferReader) -> FavedStickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.FavedStickers.favedStickers(Cons_favedStickers(hash: _1!, packs: _2!, stickers: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_favedStickersNotModified(_ reader: BufferReader) -> FavedStickers? {
            return Api.messages.FavedStickers.favedStickersNotModified
        }
    }
}
public extension Api.messages {
    enum FeaturedStickers: TypeConstructorDescription {
        public class Cons_featuredStickers: TypeConstructorDescription {
            public var flags: Int32
            public var hash: Int64
            public var count: Int32
            public var sets: [Api.StickerSetCovered]
            public var unread: [Int64]
            public init(flags: Int32, hash: Int64, count: Int32, sets: [Api.StickerSetCovered], unread: [Int64]) {
                self.flags = flags
                self.hash = hash
                self.count = count
                self.sets = sets
                self.unread = unread
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("featuredStickers", [("flags", ConstructorParameterDescription(self.flags)), ("hash", ConstructorParameterDescription(self.hash)), ("count", ConstructorParameterDescription(self.count)), ("sets", ConstructorParameterDescription(self.sets)), ("unread", ConstructorParameterDescription(self.unread))])
            }
        }
        public class Cons_featuredStickersNotModified: TypeConstructorDescription {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("featuredStickersNotModified", [("count", ConstructorParameterDescription(self.count))])
            }
        }
        case featuredStickers(Cons_featuredStickers)
        case featuredStickersNotModified(Cons_featuredStickersNotModified)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .featuredStickers(let _data):
                if boxed {
                    buffer.appendInt32(-1103615738)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sets.count))
                for item in _data.sets {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.unread.count))
                for item in _data.unread {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .featuredStickersNotModified(let _data):
                if boxed {
                    buffer.appendInt32(-958657434)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .featuredStickers(let _data):
                return ("featuredStickers", [("flags", ConstructorParameterDescription(_data.flags)), ("hash", ConstructorParameterDescription(_data.hash)), ("count", ConstructorParameterDescription(_data.count)), ("sets", ConstructorParameterDescription(_data.sets)), ("unread", ConstructorParameterDescription(_data.unread))])
            case .featuredStickersNotModified(let _data):
                return ("featuredStickersNotModified", [("count", ConstructorParameterDescription(_data.count))])
            }
        }

        public static func parse_featuredStickers(_ reader: BufferReader) -> FeaturedStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            var _5: [Int64]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.FeaturedStickers.featuredStickers(Cons_featuredStickers(flags: _1!, hash: _2!, count: _3!, sets: _4!, unread: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_featuredStickersNotModified(_ reader: BufferReader) -> FeaturedStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.FeaturedStickers.featuredStickersNotModified(Cons_featuredStickersNotModified(count: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum ForumTopics: TypeConstructorDescription {
        public class Cons_forumTopics: TypeConstructorDescription {
            public var flags: Int32
            public var count: Int32
            public var topics: [Api.ForumTopic]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var pts: Int32
            public init(flags: Int32, count: Int32, topics: [Api.ForumTopic], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], pts: Int32) {
                self.flags = flags
                self.count = count
                self.topics = topics
                self.messages = messages
                self.chats = chats
                self.users = users
                self.pts = pts
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("forumTopics", [("flags", ConstructorParameterDescription(self.flags)), ("count", ConstructorParameterDescription(self.count)), ("topics", ConstructorParameterDescription(self.topics)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users)), ("pts", ConstructorParameterDescription(self.pts))])
            }
        }
        case forumTopics(Cons_forumTopics)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .forumTopics(let _data):
                if boxed {
                    buffer.appendInt32(913709011)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topics.count))
                for item in _data.topics {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .forumTopics(let _data):
                return ("forumTopics", [("flags", ConstructorParameterDescription(_data.flags)), ("count", ConstructorParameterDescription(_data.count)), ("topics", ConstructorParameterDescription(_data.topics)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users)), ("pts", ConstructorParameterDescription(_data.pts))])
            }
        }

        public static func parse_forumTopics(_ reader: BufferReader) -> ForumTopics? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.ForumTopic]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ForumTopic.self)
            }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.messages.ForumTopics.forumTopics(Cons_forumTopics(flags: _1!, count: _2!, topics: _3!, messages: _4!, chats: _5!, users: _6!, pts: _7!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum FoundStickerSets: TypeConstructorDescription {
        public class Cons_foundStickerSets: TypeConstructorDescription {
            public var hash: Int64
            public var sets: [Api.StickerSetCovered]
            public init(hash: Int64, sets: [Api.StickerSetCovered]) {
                self.hash = hash
                self.sets = sets
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("foundStickerSets", [("hash", ConstructorParameterDescription(self.hash)), ("sets", ConstructorParameterDescription(self.sets))])
            }
        }
        case foundStickerSets(Cons_foundStickerSets)
        case foundStickerSetsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .foundStickerSets(let _data):
                if boxed {
                    buffer.appendInt32(-1963942446)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sets.count))
                for item in _data.sets {
                    item.serialize(buffer, true)
                }
                break
            case .foundStickerSetsNotModified:
                if boxed {
                    buffer.appendInt32(223655517)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .foundStickerSets(let _data):
                return ("foundStickerSets", [("hash", ConstructorParameterDescription(_data.hash)), ("sets", ConstructorParameterDescription(_data.sets))])
            case .foundStickerSetsNotModified:
                return ("foundStickerSetsNotModified", [])
            }
        }

        public static func parse_foundStickerSets(_ reader: BufferReader) -> FoundStickerSets? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.FoundStickerSets.foundStickerSets(Cons_foundStickerSets(hash: _1!, sets: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_foundStickerSetsNotModified(_ reader: BufferReader) -> FoundStickerSets? {
            return Api.messages.FoundStickerSets.foundStickerSetsNotModified
        }
    }
}
public extension Api.messages {
    enum FoundStickers: TypeConstructorDescription {
        public class Cons_foundStickers: TypeConstructorDescription {
            public var flags: Int32
            public var nextOffset: Int32?
            public var hash: Int64
            public var stickers: [Api.Document]
            public init(flags: Int32, nextOffset: Int32?, hash: Int64, stickers: [Api.Document]) {
                self.flags = flags
                self.nextOffset = nextOffset
                self.hash = hash
                self.stickers = stickers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("foundStickers", [("flags", ConstructorParameterDescription(self.flags)), ("nextOffset", ConstructorParameterDescription(self.nextOffset)), ("hash", ConstructorParameterDescription(self.hash)), ("stickers", ConstructorParameterDescription(self.stickers))])
            }
        }
        public class Cons_foundStickersNotModified: TypeConstructorDescription {
            public var flags: Int32
            public var nextOffset: Int32?
            public init(flags: Int32, nextOffset: Int32?) {
                self.flags = flags
                self.nextOffset = nextOffset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("foundStickersNotModified", [("flags", ConstructorParameterDescription(self.flags)), ("nextOffset", ConstructorParameterDescription(self.nextOffset))])
            }
        }
        case foundStickers(Cons_foundStickers)
        case foundStickersNotModified(Cons_foundStickersNotModified)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .foundStickers(let _data):
                if boxed {
                    buffer.appendInt32(-2100698480)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stickers.count))
                for item in _data.stickers {
                    item.serialize(buffer, true)
                }
                break
            case .foundStickersNotModified(let _data):
                if boxed {
                    buffer.appendInt32(1611711796)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .foundStickers(let _data):
                return ("foundStickers", [("flags", ConstructorParameterDescription(_data.flags)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset)), ("hash", ConstructorParameterDescription(_data.hash)), ("stickers", ConstructorParameterDescription(_data.stickers))])
            case .foundStickersNotModified(let _data):
                return ("foundStickersNotModified", [("flags", ConstructorParameterDescription(_data.flags)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset))])
            }
        }

        public static func parse_foundStickers(_ reader: BufferReader) -> FoundStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: [Api.Document]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.FoundStickers.foundStickers(Cons_foundStickers(flags: _1!, nextOffset: _2, hash: _3!, stickers: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_foundStickersNotModified(_ reader: BufferReader) -> FoundStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.messages.FoundStickers.foundStickersNotModified(Cons_foundStickersNotModified(flags: _1!, nextOffset: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum HighScores: TypeConstructorDescription {
        public class Cons_highScores: TypeConstructorDescription {
            public var scores: [Api.HighScore]
            public var users: [Api.User]
            public init(scores: [Api.HighScore], users: [Api.User]) {
                self.scores = scores
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("highScores", [("scores", ConstructorParameterDescription(self.scores)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case highScores(Cons_highScores)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .highScores(let _data):
                if boxed {
                    buffer.appendInt32(-1707344487)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.scores.count))
                for item in _data.scores {
                    item.serialize(buffer, true)
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
            case .highScores(let _data):
                return ("highScores", [("scores", ConstructorParameterDescription(_data.scores)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_highScores(_ reader: BufferReader) -> HighScores? {
            var _1: [Api.HighScore]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.HighScore.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.HighScores.highScores(Cons_highScores(scores: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum HistoryImport: TypeConstructorDescription {
        public class Cons_historyImport: TypeConstructorDescription {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("historyImport", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case historyImport(Cons_historyImport)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .historyImport(let _data):
                if boxed {
                    buffer.appendInt32(375566091)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .historyImport(let _data):
                return ("historyImport", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_historyImport(_ reader: BufferReader) -> HistoryImport? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.HistoryImport.historyImport(Cons_historyImport(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum HistoryImportParsed: TypeConstructorDescription {
        public class Cons_historyImportParsed: TypeConstructorDescription {
            public var flags: Int32
            public var title: String?
            public init(flags: Int32, title: String?) {
                self.flags = flags
                self.title = title
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("historyImportParsed", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title))])
            }
        }
        case historyImportParsed(Cons_historyImportParsed)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .historyImportParsed(let _data):
                if boxed {
                    buffer.appendInt32(1578088377)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .historyImportParsed(let _data):
                return ("historyImportParsed", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title))])
            }
        }

        public static func parse_historyImportParsed(_ reader: BufferReader) -> HistoryImportParsed? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.messages.HistoryImportParsed.historyImportParsed(Cons_historyImportParsed(flags: _1!, title: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum InactiveChats: TypeConstructorDescription {
        public class Cons_inactiveChats: TypeConstructorDescription {
            public var dates: [Int32]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(dates: [Int32], chats: [Api.Chat], users: [Api.User]) {
                self.dates = dates
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inactiveChats", [("dates", ConstructorParameterDescription(self.dates)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case inactiveChats(Cons_inactiveChats)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inactiveChats(let _data):
                if boxed {
                    buffer.appendInt32(-1456996667)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dates.count))
                for item in _data.dates {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
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
            case .inactiveChats(let _data):
                return ("inactiveChats", [("dates", ConstructorParameterDescription(_data.dates)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_inactiveChats(_ reader: BufferReader) -> InactiveChats? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.InactiveChats.inactiveChats(Cons_inactiveChats(dates: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    indirect enum InvitedUsers: TypeConstructorDescription {
        public class Cons_invitedUsers: TypeConstructorDescription {
            public var updates: Api.Updates
            public var missingInvitees: [Api.MissingInvitee]
            public init(updates: Api.Updates, missingInvitees: [Api.MissingInvitee]) {
                self.updates = updates
                self.missingInvitees = missingInvitees
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("invitedUsers", [("updates", ConstructorParameterDescription(self.updates)), ("missingInvitees", ConstructorParameterDescription(self.missingInvitees))])
            }
        }
        case invitedUsers(Cons_invitedUsers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .invitedUsers(let _data):
                if boxed {
                    buffer.appendInt32(2136862630)
                }
                _data.updates.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.missingInvitees.count))
                for item in _data.missingInvitees {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .invitedUsers(let _data):
                return ("invitedUsers", [("updates", ConstructorParameterDescription(_data.updates)), ("missingInvitees", ConstructorParameterDescription(_data.missingInvitees))])
            }
        }

        public static func parse_invitedUsers(_ reader: BufferReader) -> InvitedUsers? {
            var _1: Api.Updates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Updates
            }
            var _2: [Api.MissingInvitee]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MissingInvitee.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.InvitedUsers.invitedUsers(Cons_invitedUsers(updates: _1!, missingInvitees: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum MessageEditData: TypeConstructorDescription {
        public class Cons_messageEditData: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEditData", [("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        case messageEditData(Cons_messageEditData)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageEditData(let _data):
                if boxed {
                    buffer.appendInt32(649453030)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .messageEditData(let _data):
                return ("messageEditData", [("flags", ConstructorParameterDescription(_data.flags))])
            }
        }

        public static func parse_messageEditData(_ reader: BufferReader) -> MessageEditData? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.MessageEditData.messageEditData(Cons_messageEditData(flags: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum MessageReactionsList: TypeConstructorDescription {
        public class Cons_messageReactionsList: TypeConstructorDescription {
            public var flags: Int32
            public var count: Int32
            public var reactions: [Api.MessagePeerReaction]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, reactions: [Api.MessagePeerReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.reactions = reactions
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageReactionsList", [("flags", ConstructorParameterDescription(self.flags)), ("count", ConstructorParameterDescription(self.count)), ("reactions", ConstructorParameterDescription(self.reactions)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users)), ("nextOffset", ConstructorParameterDescription(self.nextOffset))])
            }
        }
        case messageReactionsList(Cons_messageReactionsList)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageReactionsList(let _data):
                if boxed {
                    buffer.appendInt32(834488621)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.reactions.count))
                for item in _data.reactions {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .messageReactionsList(let _data):
                return ("messageReactionsList", [("flags", ConstructorParameterDescription(_data.flags)), ("count", ConstructorParameterDescription(_data.count)), ("reactions", ConstructorParameterDescription(_data.reactions)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset))])
            }
        }

        public static func parse_messageReactionsList(_ reader: BufferReader) -> MessageReactionsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessagePeerReaction]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessagePeerReaction.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.messages.MessageReactionsList.messageReactionsList(Cons_messageReactionsList(flags: _1!, count: _2!, reactions: _3!, chats: _4!, users: _5!, nextOffset: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum MessageViews: TypeConstructorDescription {
        public class Cons_messageViews: TypeConstructorDescription {
            public var views: [Api.MessageViews]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(views: [Api.MessageViews], chats: [Api.Chat], users: [Api.User]) {
                self.views = views
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageViews", [("views", ConstructorParameterDescription(self.views)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case messageViews(Cons_messageViews)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageViews(let _data):
                if boxed {
                    buffer.appendInt32(-1228606141)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.views.count))
                for item in _data.views {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
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
            case .messageViews(let _data):
                return ("messageViews", [("views", ConstructorParameterDescription(_data.views)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_messageViews(_ reader: BufferReader) -> MessageViews? {
            var _1: [Api.MessageViews]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageViews.self)
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.MessageViews.messageViews(Cons_messageViews(views: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum Messages: TypeConstructorDescription {
        public class Cons_channelMessages: TypeConstructorDescription {
            public var flags: Int32
            public var pts: Int32
            public var count: Int32
            public var offsetIdOffset: Int32?
            public var messages: [Api.Message]
            public var topics: [Api.ForumTopic]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, pts: Int32, count: Int32, offsetIdOffset: Int32?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.pts = pts
                self.count = count
                self.offsetIdOffset = offsetIdOffset
                self.messages = messages
                self.topics = topics
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelMessages", [("flags", ConstructorParameterDescription(self.flags)), ("pts", ConstructorParameterDescription(self.pts)), ("count", ConstructorParameterDescription(self.count)), ("offsetIdOffset", ConstructorParameterDescription(self.offsetIdOffset)), ("messages", ConstructorParameterDescription(self.messages)), ("topics", ConstructorParameterDescription(self.topics)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_messages: TypeConstructorDescription {
            public var messages: [Api.Message]
            public var topics: [Api.ForumTopic]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
                self.messages = messages
                self.topics = topics
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messages", [("messages", ConstructorParameterDescription(self.messages)), ("topics", ConstructorParameterDescription(self.topics)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_messagesNotModified: TypeConstructorDescription {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messagesNotModified", [("count", ConstructorParameterDescription(self.count))])
            }
        }
        public class Cons_messagesSlice: TypeConstructorDescription {
            public var flags: Int32
            public var count: Int32
            public var nextRate: Int32?
            public var offsetIdOffset: Int32?
            public var searchFlood: Api.SearchPostsFlood?
            public var messages: [Api.Message]
            public var topics: [Api.ForumTopic]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, nextRate: Int32?, offsetIdOffset: Int32?, searchFlood: Api.SearchPostsFlood?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.nextRate = nextRate
                self.offsetIdOffset = offsetIdOffset
                self.searchFlood = searchFlood
                self.messages = messages
                self.topics = topics
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messagesSlice", [("flags", ConstructorParameterDescription(self.flags)), ("count", ConstructorParameterDescription(self.count)), ("nextRate", ConstructorParameterDescription(self.nextRate)), ("offsetIdOffset", ConstructorParameterDescription(self.offsetIdOffset)), ("searchFlood", ConstructorParameterDescription(self.searchFlood)), ("messages", ConstructorParameterDescription(self.messages)), ("topics", ConstructorParameterDescription(self.topics)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case channelMessages(Cons_channelMessages)
        case messages(Cons_messages)
        case messagesNotModified(Cons_messagesNotModified)
        case messagesSlice(Cons_messagesSlice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelMessages(let _data):
                if boxed {
                    buffer.appendInt32(-948520370)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.offsetIdOffset!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topics.count))
                for item in _data.topics {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .messages(let _data):
                if boxed {
                    buffer.appendInt32(494135274)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topics.count))
                for item in _data.topics {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .messagesNotModified(let _data):
                if boxed {
                    buffer.appendInt32(1951620897)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            case .messagesSlice(let _data):
                if boxed {
                    buffer.appendInt32(1595959062)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.nextRate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.offsetIdOffset!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.searchFlood!.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topics.count))
                for item in _data.topics {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
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
            case .channelMessages(let _data):
                return ("channelMessages", [("flags", ConstructorParameterDescription(_data.flags)), ("pts", ConstructorParameterDescription(_data.pts)), ("count", ConstructorParameterDescription(_data.count)), ("offsetIdOffset", ConstructorParameterDescription(_data.offsetIdOffset)), ("messages", ConstructorParameterDescription(_data.messages)), ("topics", ConstructorParameterDescription(_data.topics)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            case .messages(let _data):
                return ("messages", [("messages", ConstructorParameterDescription(_data.messages)), ("topics", ConstructorParameterDescription(_data.topics)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            case .messagesNotModified(let _data):
                return ("messagesNotModified", [("count", ConstructorParameterDescription(_data.count))])
            case .messagesSlice(let _data):
                return ("messagesSlice", [("flags", ConstructorParameterDescription(_data.flags)), ("count", ConstructorParameterDescription(_data.count)), ("nextRate", ConstructorParameterDescription(_data.nextRate)), ("offsetIdOffset", ConstructorParameterDescription(_data.offsetIdOffset)), ("searchFlood", ConstructorParameterDescription(_data.searchFlood)), ("messages", ConstructorParameterDescription(_data.messages)), ("topics", ConstructorParameterDescription(_data.topics)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_channelMessages(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: [Api.Message]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _6: [Api.ForumTopic]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ForumTopic.self)
            }
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.messages.Messages.channelMessages(Cons_channelMessages(flags: _1!, pts: _2!, count: _3!, offsetIdOffset: _4, messages: _5!, topics: _6!, chats: _7!, users: _8!))
            }
            else {
                return nil
            }
        }
        public static func parse_messages(_ reader: BufferReader) -> Messages? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.ForumTopic]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ForumTopic.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.Messages.messages(Cons_messages(messages: _1!, topics: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_messagesNotModified(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.Messages.messagesNotModified(Cons_messagesNotModified(count: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messagesSlice(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Api.SearchPostsFlood?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.SearchPostsFlood
                }
            }
            var _6: [Api.Message]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _7: [Api.ForumTopic]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ForumTopic.self)
            }
            var _8: [Api.Chat]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.messages.Messages.messagesSlice(Cons_messagesSlice(flags: _1!, count: _2!, nextRate: _3, offsetIdOffset: _4, searchFlood: _5, messages: _6!, topics: _7!, chats: _8!, users: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum MyStickers: TypeConstructorDescription {
        public class Cons_myStickers: TypeConstructorDescription {
            public var count: Int32
            public var sets: [Api.StickerSetCovered]
            public init(count: Int32, sets: [Api.StickerSetCovered]) {
                self.count = count
                self.sets = sets
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("myStickers", [("count", ConstructorParameterDescription(self.count)), ("sets", ConstructorParameterDescription(self.sets))])
            }
        }
        case myStickers(Cons_myStickers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .myStickers(let _data):
                if boxed {
                    buffer.appendInt32(-83926371)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sets.count))
                for item in _data.sets {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .myStickers(let _data):
                return ("myStickers", [("count", ConstructorParameterDescription(_data.count)), ("sets", ConstructorParameterDescription(_data.sets))])
            }
        }

        public static func parse_myStickers(_ reader: BufferReader) -> MyStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.MyStickers.myStickers(Cons_myStickers(count: _1!, sets: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum PeerDialogs: TypeConstructorDescription {
        public class Cons_peerDialogs: TypeConstructorDescription {
            public var dialogs: [Api.Dialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var state: Api.updates.State
            public init(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], state: Api.updates.State) {
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
                self.state = state
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("peerDialogs", [("dialogs", ConstructorParameterDescription(self.dialogs)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users)), ("state", ConstructorParameterDescription(self.state))])
            }
        }
        case peerDialogs(Cons_peerDialogs)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerDialogs(let _data):
                if boxed {
                    buffer.appendInt32(863093588)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dialogs.count))
                for item in _data.dialogs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                _data.state.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .peerDialogs(let _data):
                return ("peerDialogs", [("dialogs", ConstructorParameterDescription(_data.dialogs)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users)), ("state", ConstructorParameterDescription(_data.state))])
            }
        }

        public static func parse_peerDialogs(_ reader: BufferReader) -> PeerDialogs? {
            var _1: [Api.Dialog]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Dialog.self)
            }
            var _2: [Api.Message]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _5: Api.updates.State?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.PeerDialogs.peerDialogs(Cons_peerDialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!, state: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum PeerSettings: TypeConstructorDescription {
        public class Cons_peerSettings: TypeConstructorDescription {
            public var settings: Api.PeerSettings
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(settings: Api.PeerSettings, chats: [Api.Chat], users: [Api.User]) {
                self.settings = settings
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("peerSettings", [("settings", ConstructorParameterDescription(self.settings)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case peerSettings(Cons_peerSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerSettings(let _data):
                if boxed {
                    buffer.appendInt32(1753266509)
                }
                _data.settings.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
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
            case .peerSettings(let _data):
                return ("peerSettings", [("settings", ConstructorParameterDescription(_data.settings)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            var _1: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerSettings
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.PeerSettings.peerSettings(Cons_peerSettings(settings: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum PreparedInlineMessage: TypeConstructorDescription {
        public class Cons_preparedInlineMessage: TypeConstructorDescription {
            public var queryId: Int64
            public var result: Api.BotInlineResult
            public var peerTypes: [Api.InlineQueryPeerType]
            public var cacheTime: Int32
            public var users: [Api.User]
            public init(queryId: Int64, result: Api.BotInlineResult, peerTypes: [Api.InlineQueryPeerType], cacheTime: Int32, users: [Api.User]) {
                self.queryId = queryId
                self.result = result
                self.peerTypes = peerTypes
                self.cacheTime = cacheTime
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("preparedInlineMessage", [("queryId", ConstructorParameterDescription(self.queryId)), ("result", ConstructorParameterDescription(self.result)), ("peerTypes", ConstructorParameterDescription(self.peerTypes)), ("cacheTime", ConstructorParameterDescription(self.cacheTime)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case preparedInlineMessage(Cons_preparedInlineMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .preparedInlineMessage(let _data):
                if boxed {
                    buffer.appendInt32(-11046771)
                }
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                _data.result.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peerTypes.count))
                for item in _data.peerTypes {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.cacheTime, buffer: buffer, boxed: false)
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
            case .preparedInlineMessage(let _data):
                return ("preparedInlineMessage", [("queryId", ConstructorParameterDescription(_data.queryId)), ("result", ConstructorParameterDescription(_data.result)), ("peerTypes", ConstructorParameterDescription(_data.peerTypes)), ("cacheTime", ConstructorParameterDescription(_data.cacheTime)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_preparedInlineMessage(_ reader: BufferReader) -> PreparedInlineMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.BotInlineResult?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BotInlineResult
            }
            var _3: [Api.InlineQueryPeerType]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InlineQueryPeerType.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.PreparedInlineMessage.preparedInlineMessage(Cons_preparedInlineMessage(queryId: _1!, result: _2!, peerTypes: _3!, cacheTime: _4!, users: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum QuickReplies: TypeConstructorDescription {
        public class Cons_quickReplies: TypeConstructorDescription {
            public var quickReplies: [Api.QuickReply]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(quickReplies: [Api.QuickReply], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.quickReplies = quickReplies
                self.messages = messages
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("quickReplies", [("quickReplies", ConstructorParameterDescription(self.quickReplies)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case quickReplies(Cons_quickReplies)
        case quickRepliesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .quickReplies(let _data):
                if boxed {
                    buffer.appendInt32(-963811691)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.quickReplies.count))
                for item in _data.quickReplies {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .quickRepliesNotModified:
                if boxed {
                    buffer.appendInt32(1603398491)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .quickReplies(let _data):
                return ("quickReplies", [("quickReplies", ConstructorParameterDescription(_data.quickReplies)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            case .quickRepliesNotModified:
                return ("quickRepliesNotModified", [])
            }
        }

        public static func parse_quickReplies(_ reader: BufferReader) -> QuickReplies? {
            var _1: [Api.QuickReply]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.QuickReply.self)
            }
            var _2: [Api.Message]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.QuickReplies.quickReplies(Cons_quickReplies(quickReplies: _1!, messages: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_quickRepliesNotModified(_ reader: BufferReader) -> QuickReplies? {
            return Api.messages.QuickReplies.quickRepliesNotModified
        }
    }
}
public extension Api.messages {
    enum Reactions: TypeConstructorDescription {
        public class Cons_reactions: TypeConstructorDescription {
            public var hash: Int64
            public var reactions: [Api.Reaction]
            public init(hash: Int64, reactions: [Api.Reaction]) {
                self.hash = hash
                self.reactions = reactions
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("reactions", [("hash", ConstructorParameterDescription(self.hash)), ("reactions", ConstructorParameterDescription(self.reactions))])
            }
        }
        case reactions(Cons_reactions)
        case reactionsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .reactions(let _data):
                if boxed {
                    buffer.appendInt32(-352454890)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.reactions.count))
                for item in _data.reactions {
                    item.serialize(buffer, true)
                }
                break
            case .reactionsNotModified:
                if boxed {
                    buffer.appendInt32(-1334846497)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .reactions(let _data):
                return ("reactions", [("hash", ConstructorParameterDescription(_data.hash)), ("reactions", ConstructorParameterDescription(_data.reactions))])
            case .reactionsNotModified:
                return ("reactionsNotModified", [])
            }
        }

        public static func parse_reactions(_ reader: BufferReader) -> Reactions? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Reaction]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Reaction.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.Reactions.reactions(Cons_reactions(hash: _1!, reactions: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_reactionsNotModified(_ reader: BufferReader) -> Reactions? {
            return Api.messages.Reactions.reactionsNotModified
        }
    }
}
