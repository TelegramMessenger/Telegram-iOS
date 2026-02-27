public extension Api {
    enum InputBusinessBotRecipients: TypeConstructorDescription {
        public class Cons_inputBusinessBotRecipients {
            public var flags: Int32
            public var users: [Api.InputUser]?
            public var excludeUsers: [Api.InputUser]?
            public init(flags: Int32, users: [Api.InputUser]?, excludeUsers: [Api.InputUser]?) {
                self.flags = flags
                self.users = users
                self.excludeUsers = excludeUsers
            }
        }
        case inputBusinessBotRecipients(Cons_inputBusinessBotRecipients)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBusinessBotRecipients(let _data):
                if boxed {
                    buffer.appendInt32(-991587810)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.users!.count))
                    for item in _data.users! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.excludeUsers!.count))
                    for item in _data.excludeUsers! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBusinessBotRecipients(let _data):
                return ("inputBusinessBotRecipients", [("flags", _data.flags as Any), ("users", _data.users as Any), ("excludeUsers", _data.excludeUsers as Any)])
            }
        }

        public static func parse_inputBusinessBotRecipients(_ reader: BufferReader) -> InputBusinessBotRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.InputUser]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
                }
            }
            var _3: [Api.InputUser]?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 6) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBusinessBotRecipients.inputBusinessBotRecipients(Cons_inputBusinessBotRecipients(flags: _1!, users: _2, excludeUsers: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBusinessChatLink: TypeConstructorDescription {
        public class Cons_inputBusinessChatLink {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var title: String?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, title: String?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.title = title
            }
        }
        case inputBusinessChatLink(Cons_inputBusinessChatLink)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBusinessChatLink(let _data):
                if boxed {
                    buffer.appendInt32(292003751)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBusinessChatLink(let _data):
                return ("inputBusinessChatLink", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("title", _data.title as Any)])
            }
        }

        public static func parse_inputBusinessChatLink(_ reader: BufferReader) -> InputBusinessChatLink? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBusinessChatLink.inputBusinessChatLink(Cons_inputBusinessChatLink(flags: _1!, message: _2!, entities: _3, title: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBusinessGreetingMessage: TypeConstructorDescription {
        public class Cons_inputBusinessGreetingMessage {
            public var shortcutId: Int32
            public var recipients: Api.InputBusinessRecipients
            public var noActivityDays: Int32
            public init(shortcutId: Int32, recipients: Api.InputBusinessRecipients, noActivityDays: Int32) {
                self.shortcutId = shortcutId
                self.recipients = recipients
                self.noActivityDays = noActivityDays
            }
        }
        case inputBusinessGreetingMessage(Cons_inputBusinessGreetingMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBusinessGreetingMessage(let _data):
                if boxed {
                    buffer.appendInt32(26528571)
                }
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                _data.recipients.serialize(buffer, true)
                serializeInt32(_data.noActivityDays, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBusinessGreetingMessage(let _data):
                return ("inputBusinessGreetingMessage", [("shortcutId", _data.shortcutId as Any), ("recipients", _data.recipients as Any), ("noActivityDays", _data.noActivityDays as Any)])
            }
        }

        public static func parse_inputBusinessGreetingMessage(_ reader: BufferReader) -> InputBusinessGreetingMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputBusinessRecipients?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputBusinessRecipients
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBusinessGreetingMessage.inputBusinessGreetingMessage(Cons_inputBusinessGreetingMessage(shortcutId: _1!, recipients: _2!, noActivityDays: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBusinessIntro: TypeConstructorDescription {
        public class Cons_inputBusinessIntro {
            public var flags: Int32
            public var title: String
            public var description: String
            public var sticker: Api.InputDocument?
            public init(flags: Int32, title: String, description: String, sticker: Api.InputDocument?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.sticker = sticker
            }
        }
        case inputBusinessIntro(Cons_inputBusinessIntro)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBusinessIntro(let _data):
                if boxed {
                    buffer.appendInt32(163867085)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.sticker!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBusinessIntro(let _data):
                return ("inputBusinessIntro", [("flags", _data.flags as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("sticker", _data.sticker as Any)])
            }
        }

        public static func parse_inputBusinessIntro(_ reader: BufferReader) -> InputBusinessIntro? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InputDocument?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputDocument
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBusinessIntro.inputBusinessIntro(Cons_inputBusinessIntro(flags: _1!, title: _2!, description: _3!, sticker: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBusinessRecipients: TypeConstructorDescription {
        public class Cons_inputBusinessRecipients {
            public var flags: Int32
            public var users: [Api.InputUser]?
            public init(flags: Int32, users: [Api.InputUser]?) {
                self.flags = flags
                self.users = users
            }
        }
        case inputBusinessRecipients(Cons_inputBusinessRecipients)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBusinessRecipients(let _data):
                if boxed {
                    buffer.appendInt32(1871393450)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.users!.count))
                    for item in _data.users! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBusinessRecipients(let _data):
                return ("inputBusinessRecipients", [("flags", _data.flags as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_inputBusinessRecipients(_ reader: BufferReader) -> InputBusinessRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.InputUser]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.InputBusinessRecipients.inputBusinessRecipients(Cons_inputBusinessRecipients(flags: _1!, users: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputChannel: TypeConstructorDescription {
        public class Cons_inputChannel {
            public var channelId: Int64
            public var accessHash: Int64
            public init(channelId: Int64, accessHash: Int64) {
                self.channelId = channelId
                self.accessHash = accessHash
            }
        }
        public class Cons_inputChannelFromMessage {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var channelId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, channelId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.channelId = channelId
            }
        }
        case inputChannel(Cons_inputChannel)
        case inputChannelEmpty
        case inputChannelFromMessage(Cons_inputChannelFromMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputChannel(let _data):
                if boxed {
                    buffer.appendInt32(-212145112)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputChannelEmpty:
                if boxed {
                    buffer.appendInt32(-292807034)
                }
                break
            case .inputChannelFromMessage(let _data):
                if boxed {
                    buffer.appendInt32(1536380829)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputChannel(let _data):
                return ("inputChannel", [("channelId", _data.channelId as Any), ("accessHash", _data.accessHash as Any)])
            case .inputChannelEmpty:
                return ("inputChannelEmpty", [])
            case .inputChannelFromMessage(let _data):
                return ("inputChannelFromMessage", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("channelId", _data.channelId as Any)])
            }
        }

        public static func parse_inputChannel(_ reader: BufferReader) -> InputChannel? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputChannel.inputChannel(Cons_inputChannel(channelId: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputChannelEmpty(_ reader: BufferReader) -> InputChannel? {
            return Api.InputChannel.inputChannelEmpty
        }
        public static func parse_inputChannelFromMessage(_ reader: BufferReader) -> InputChannel? {
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
                return Api.InputChannel.inputChannelFromMessage(Cons_inputChannelFromMessage(peer: _1!, msgId: _2!, channelId: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputChatPhoto: TypeConstructorDescription {
        public class Cons_inputChatPhoto {
            public var id: Api.InputPhoto
            public init(id: Api.InputPhoto) {
                self.id = id
            }
        }
        public class Cons_inputChatUploadedPhoto {
            public var flags: Int32
            public var file: Api.InputFile?
            public var video: Api.InputFile?
            public var videoStartTs: Double?
            public var videoEmojiMarkup: Api.VideoSize?
            public init(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?) {
                self.flags = flags
                self.file = file
                self.video = video
                self.videoStartTs = videoStartTs
                self.videoEmojiMarkup = videoEmojiMarkup
            }
        }
        case inputChatPhoto(Cons_inputChatPhoto)
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(Cons_inputChatUploadedPhoto)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputChatPhoto(let _data):
                if boxed {
                    buffer.appendInt32(-1991004873)
                }
                _data.id.serialize(buffer, true)
                break
            case .inputChatPhotoEmpty:
                if boxed {
                    buffer.appendInt32(480546647)
                }
                break
            case .inputChatUploadedPhoto(let _data):
                if boxed {
                    buffer.appendInt32(-1110593856)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.file!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.video!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeDouble(_data.videoStartTs!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.videoEmojiMarkup!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputChatPhoto(let _data):
                return ("inputChatPhoto", [("id", _data.id as Any)])
            case .inputChatPhotoEmpty:
                return ("inputChatPhotoEmpty", [])
            case .inputChatUploadedPhoto(let _data):
                return ("inputChatUploadedPhoto", [("flags", _data.flags as Any), ("file", _data.file as Any), ("video", _data.video as Any), ("videoStartTs", _data.videoStartTs as Any), ("videoEmojiMarkup", _data.videoEmojiMarkup as Any)])
            }
        }

        public static func parse_inputChatPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatPhoto.inputChatPhoto(Cons_inputChatPhoto(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputChatPhotoEmpty(_ reader: BufferReader) -> InputChatPhoto? {
            return Api.InputChatPhoto.inputChatPhotoEmpty
        }
        public static func parse_inputChatUploadedPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.InputFile
                }
            }
            var _3: Api.InputFile?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.InputFile
                }
            }
            var _4: Double?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readDouble()
            }
            var _5: Api.VideoSize?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.VideoSize
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputChatPhoto.inputChatUploadedPhoto(Cons_inputChatUploadedPhoto(flags: _1!, file: _2, video: _3, videoStartTs: _4, videoEmojiMarkup: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputChatTheme: TypeConstructorDescription {
        public class Cons_inputChatTheme {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_inputChatThemeUniqueGift {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputChatTheme(let _data):
                return ("inputChatTheme", [("emoticon", _data.emoticon as Any)])
            case .inputChatThemeEmpty:
                return ("inputChatThemeEmpty", [])
            case .inputChatThemeUniqueGift(let _data):
                return ("inputChatThemeUniqueGift", [("slug", _data.slug as Any)])
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
        public class Cons_inputChatlistDialogFilter {
            public var filterId: Int32
            public init(filterId: Int32) {
                self.filterId = filterId
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputChatlistDialogFilter(let _data):
                return ("inputChatlistDialogFilter", [("filterId", _data.filterId as Any)])
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
        public class Cons_inputCheckPasswordSRP {
            public var srpId: Int64
            public var A: Buffer
            public var M1: Buffer
            public init(srpId: Int64, A: Buffer, M1: Buffer) {
                self.srpId = srpId
                self.A = A
                self.M1 = M1
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputCheckPasswordEmpty:
                return ("inputCheckPasswordEmpty", [])
            case .inputCheckPasswordSRP(let _data):
                return ("inputCheckPasswordSRP", [("srpId", _data.srpId as Any), ("A", _data.A as Any), ("M1", _data.M1 as Any)])
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
        public class Cons_inputClientProxy {
            public var address: String
            public var port: Int32
            public init(address: String, port: Int32) {
                self.address = address
                self.port = port
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputClientProxy(let _data):
                return ("inputClientProxy", [("address", _data.address as Any), ("port", _data.port as Any)])
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
        public class Cons_inputCollectiblePhone {
            public var phone: String
            public init(phone: String) {
                self.phone = phone
            }
        }
        public class Cons_inputCollectibleUsername {
            public var username: String
            public init(username: String) {
                self.username = username
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputCollectiblePhone(let _data):
                return ("inputCollectiblePhone", [("phone", _data.phone as Any)])
            case .inputCollectibleUsername(let _data):
                return ("inputCollectibleUsername", [("username", _data.username as Any)])
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
        public class Cons_inputPhoneContact {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputPhoneContact(let _data):
                return ("inputPhoneContact", [("flags", _data.flags as Any), ("clientId", _data.clientId as Any), ("phone", _data.phone as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("note", _data.note as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
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
        public class Cons_inputDialogPeer {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        public class Cons_inputDialogPeerFolder {
            public var folderId: Int32
            public init(folderId: Int32) {
                self.folderId = folderId
            }
        }
        case inputDialogPeer(Cons_inputDialogPeer)
        case inputDialogPeerFolder(Cons_inputDialogPeerFolder)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputDialogPeer(let _data):
                if boxed {
                    buffer.appendInt32(-55902537)
                }
                _data.peer.serialize(buffer, true)
                break
            case .inputDialogPeerFolder(let _data):
                if boxed {
                    buffer.appendInt32(1684014375)
                }
                serializeInt32(_data.folderId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputDialogPeer(let _data):
                return ("inputDialogPeer", [("peer", _data.peer as Any)])
            case .inputDialogPeerFolder(let _data):
                return ("inputDialogPeerFolder", [("folderId", _data.folderId as Any)])
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
        public class Cons_inputDocument {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public init(id: Int64, accessHash: Int64, fileReference: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputDocument(let _data):
                return ("inputDocument", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("fileReference", _data.fileReference as Any)])
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
        public class Cons_inputEncryptedChat {
            public var chatId: Int32
            public var accessHash: Int64
            public init(chatId: Int32, accessHash: Int64) {
                self.chatId = chatId
                self.accessHash = accessHash
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputEncryptedChat(let _data):
                return ("inputEncryptedChat", [("chatId", _data.chatId as Any), ("accessHash", _data.accessHash as Any)])
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
        public class Cons_inputEncryptedFile {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputEncryptedFileBigUploaded {
            public var id: Int64
            public var parts: Int32
            public var keyFingerprint: Int32
            public init(id: Int64, parts: Int32, keyFingerprint: Int32) {
                self.id = id
                self.parts = parts
                self.keyFingerprint = keyFingerprint
            }
        }
        public class Cons_inputEncryptedFileUploaded {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputEncryptedFile(let _data):
                return ("inputEncryptedFile", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            case .inputEncryptedFileBigUploaded(let _data):
                return ("inputEncryptedFileBigUploaded", [("id", _data.id as Any), ("parts", _data.parts as Any), ("keyFingerprint", _data.keyFingerprint as Any)])
            case .inputEncryptedFileEmpty:
                return ("inputEncryptedFileEmpty", [])
            case .inputEncryptedFileUploaded(let _data):
                return ("inputEncryptedFileUploaded", [("id", _data.id as Any), ("parts", _data.parts as Any), ("md5Checksum", _data.md5Checksum as Any), ("keyFingerprint", _data.keyFingerprint as Any)])
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
        public class Cons_inputFile {
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
        }
        public class Cons_inputFileBig {
            public var id: Int64
            public var parts: Int32
            public var name: String
            public init(id: Int64, parts: Int32, name: String) {
                self.id = id
                self.parts = parts
                self.name = name
            }
        }
        public class Cons_inputFileStoryDocument {
            public var id: Api.InputDocument
            public init(id: Api.InputDocument) {
                self.id = id
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputFile(let _data):
                return ("inputFile", [("id", _data.id as Any), ("parts", _data.parts as Any), ("name", _data.name as Any), ("md5Checksum", _data.md5Checksum as Any)])
            case .inputFileBig(let _data):
                return ("inputFileBig", [("id", _data.id as Any), ("parts", _data.parts as Any), ("name", _data.name as Any)])
            case .inputFileStoryDocument(let _data):
                return ("inputFileStoryDocument", [("id", _data.id as Any)])
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
