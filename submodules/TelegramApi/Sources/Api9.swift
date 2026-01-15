public extension Api {
    enum InputBusinessBotRecipients: TypeConstructorDescription {
        case inputBusinessBotRecipients(flags: Int32, users: [Api.InputUser]?, excludeUsers: [Api.InputUser]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessBotRecipients(let flags, let users, let excludeUsers):
                    if boxed {
                        buffer.appendInt32(-991587810)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users!.count))
                    for item in users! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(excludeUsers!.count))
                    for item in excludeUsers! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessBotRecipients(let flags, let users, let excludeUsers):
                return ("inputBusinessBotRecipients", [("flags", flags as Any), ("users", users as Any), ("excludeUsers", excludeUsers as Any)])
    }
    }
    
        public static func parse_inputBusinessBotRecipients(_ reader: BufferReader) -> InputBusinessBotRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.InputUser]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            } }
            var _3: [Api.InputUser]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 6) == 0) || _3 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputBusinessBotRecipients.inputBusinessBotRecipients(flags: _1!, users: _2, excludeUsers: _3)
        }
    
    }
}
public extension Api {
    enum InputBusinessChatLink: TypeConstructorDescription {
        case inputBusinessChatLink(flags: Int32, message: String, entities: [Api.MessageEntity]?, title: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessChatLink(let flags, let message, let entities, let title):
                    if boxed {
                        buffer.appendInt32(292003751)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessChatLink(let flags, let message, let entities, let title):
                return ("inputBusinessChatLink", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("title", title as Any)])
    }
    }
    
        public static func parse_inputBusinessChatLink(_ reader: BufferReader) -> InputBusinessChatLink? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputBusinessChatLink.inputBusinessChatLink(flags: _1!, message: _2!, entities: _3, title: _4)
        }
    
    }
}
public extension Api {
    enum InputBusinessGreetingMessage: TypeConstructorDescription {
        case inputBusinessGreetingMessage(shortcutId: Int32, recipients: Api.InputBusinessRecipients, noActivityDays: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessGreetingMessage(let shortcutId, let recipients, let noActivityDays):
                    if boxed {
                        buffer.appendInt32(26528571)
                    }
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    recipients.serialize(buffer, true)
                    serializeInt32(noActivityDays, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessGreetingMessage(let shortcutId, let recipients, let noActivityDays):
                return ("inputBusinessGreetingMessage", [("shortcutId", shortcutId as Any), ("recipients", recipients as Any), ("noActivityDays", noActivityDays as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputBusinessGreetingMessage.inputBusinessGreetingMessage(shortcutId: _1!, recipients: _2!, noActivityDays: _3!)
        }
    
    }
}
public extension Api {
    enum InputBusinessIntro: TypeConstructorDescription {
        case inputBusinessIntro(flags: Int32, title: String, description: String, sticker: Api.InputDocument?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessIntro(let flags, let title, let description, let sticker):
                    if boxed {
                        buffer.appendInt32(163867085)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {sticker!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessIntro(let flags, let title, let description, let sticker):
                return ("inputBusinessIntro", [("flags", flags as Any), ("title", title as Any), ("description", description as Any), ("sticker", sticker as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputDocument
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputBusinessIntro.inputBusinessIntro(flags: _1!, title: _2!, description: _3!, sticker: _4)
        }
    
    }
}
public extension Api {
    enum InputBusinessRecipients: TypeConstructorDescription {
        case inputBusinessRecipients(flags: Int32, users: [Api.InputUser]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessRecipients(let flags, let users):
                    if boxed {
                        buffer.appendInt32(1871393450)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users!.count))
                    for item in users! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessRecipients(let flags, let users):
                return ("inputBusinessRecipients", [("flags", flags as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_inputBusinessRecipients(_ reader: BufferReader) -> InputBusinessRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.InputUser]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputBusinessRecipients.inputBusinessRecipients(flags: _1!, users: _2)
        }
    
    }
}
public extension Api {
    indirect enum InputChannel: TypeConstructorDescription {
        case inputChannel(channelId: Int64, accessHash: Int64)
        case inputChannelEmpty
        case inputChannelFromMessage(peer: Api.InputPeer, msgId: Int32, channelId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChannel(let channelId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-212145112)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputChannelEmpty:
                    if boxed {
                        buffer.appendInt32(-292807034)
                    }
                    
                    break
                case .inputChannelFromMessage(let peer, let msgId, let channelId):
                    if boxed {
                        buffer.appendInt32(1536380829)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChannel(let channelId, let accessHash):
                return ("inputChannel", [("channelId", channelId as Any), ("accessHash", accessHash as Any)])
                case .inputChannelEmpty:
                return ("inputChannelEmpty", [])
                case .inputChannelFromMessage(let peer, let msgId, let channelId):
                return ("inputChannelFromMessage", [("peer", peer as Any), ("msgId", msgId as Any), ("channelId", channelId as Any)])
    }
    }
    
        public static func parse_inputChannel(_ reader: BufferReader) -> InputChannel? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputChannel.inputChannel(channelId: _1!, accessHash: _2!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputChannel.inputChannelFromMessage(peer: _1!, msgId: _2!, channelId: _3!)
        }
    
    }
}
public extension Api {
    enum InputChatPhoto: TypeConstructorDescription {
        case inputChatPhoto(id: Api.InputPhoto)
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChatPhoto(let id):
                    if boxed {
                        buffer.appendInt32(-1991004873)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputChatPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(480546647)
                    }
                    
                    break
                case .inputChatUploadedPhoto(let flags, let file, let video, let videoStartTs, let videoEmojiMarkup):
                    if boxed {
                        buffer.appendInt32(-1110593856)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {file!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {videoEmojiMarkup!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChatPhoto(let id):
                return ("inputChatPhoto", [("id", id as Any)])
                case .inputChatPhotoEmpty:
                return ("inputChatPhotoEmpty", [])
                case .inputChatUploadedPhoto(let flags, let file, let video, let videoStartTs, let videoEmojiMarkup):
                return ("inputChatUploadedPhoto", [("flags", flags as Any), ("file", file as Any), ("video", video as Any), ("videoStartTs", videoStartTs as Any), ("videoEmojiMarkup", videoEmojiMarkup as Any)])
    }
    }
    
        public static func parse_inputChatPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputChatPhoto.inputChatPhoto(id: _1!)
        }
        public static func parse_inputChatPhotoEmpty(_ reader: BufferReader) -> InputChatPhoto? {
            return Api.InputChatPhoto.inputChatPhotoEmpty
        }
        public static func parse_inputChatUploadedPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _3: Api.InputFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _4: Double?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readDouble() }
            var _5: Api.VideoSize?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.VideoSize
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.InputChatPhoto.inputChatUploadedPhoto(flags: _1!, file: _2, video: _3, videoStartTs: _4, videoEmojiMarkup: _5)
        }
    
    }
}
public extension Api {
    enum InputChatTheme: TypeConstructorDescription {
        case inputChatTheme(emoticon: String)
        case inputChatThemeEmpty
        case inputChatThemeUniqueGift(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChatTheme(let emoticon):
                    if boxed {
                        buffer.appendInt32(-918689444)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .inputChatThemeEmpty:
                    if boxed {
                        buffer.appendInt32(-2094627709)
                    }
                    
                    break
                case .inputChatThemeUniqueGift(let slug):
                    if boxed {
                        buffer.appendInt32(-2014978076)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChatTheme(let emoticon):
                return ("inputChatTheme", [("emoticon", emoticon as Any)])
                case .inputChatThemeEmpty:
                return ("inputChatThemeEmpty", [])
                case .inputChatThemeUniqueGift(let slug):
                return ("inputChatThemeUniqueGift", [("slug", slug as Any)])
    }
    }
    
        public static func parse_inputChatTheme(_ reader: BufferReader) -> InputChatTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputChatTheme.inputChatTheme(emoticon: _1!)
        }
        public static func parse_inputChatThemeEmpty(_ reader: BufferReader) -> InputChatTheme? {
            return Api.InputChatTheme.inputChatThemeEmpty
        }
        public static func parse_inputChatThemeUniqueGift(_ reader: BufferReader) -> InputChatTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputChatTheme.inputChatThemeUniqueGift(slug: _1!)
        }
    
    }
}
public extension Api {
    enum InputChatlist: TypeConstructorDescription {
        case inputChatlistDialogFilter(filterId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChatlistDialogFilter(let filterId):
                    if boxed {
                        buffer.appendInt32(-203367885)
                    }
                    serializeInt32(filterId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChatlistDialogFilter(let filterId):
                return ("inputChatlistDialogFilter", [("filterId", filterId as Any)])
    }
    }
    
        public static func parse_inputChatlistDialogFilter(_ reader: BufferReader) -> InputChatlist? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputChatlist.inputChatlistDialogFilter(filterId: _1!)
        }
    
    }
}
public extension Api {
    enum InputCheckPasswordSRP: TypeConstructorDescription {
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(srpId: Int64, A: Buffer, M1: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputCheckPasswordEmpty:
                    if boxed {
                        buffer.appendInt32(-1736378792)
                    }
                    
                    break
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                    if boxed {
                        buffer.appendInt32(-763367294)
                    }
                    serializeInt64(srpId, buffer: buffer, boxed: false)
                    serializeBytes(A, buffer: buffer, boxed: false)
                    serializeBytes(M1, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputCheckPasswordEmpty:
                return ("inputCheckPasswordEmpty", [])
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                return ("inputCheckPasswordSRP", [("srpId", srpId as Any), ("A", A as Any), ("M1", M1 as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputCheckPasswordSRP.inputCheckPasswordSRP(srpId: _1!, A: _2!, M1: _3!)
        }
    
    }
}
public extension Api {
    enum InputClientProxy: TypeConstructorDescription {
        case inputClientProxy(address: String, port: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputClientProxy(let address, let port):
                    if boxed {
                        buffer.appendInt32(1968737087)
                    }
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeInt32(port, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputClientProxy(let address, let port):
                return ("inputClientProxy", [("address", address as Any), ("port", port as Any)])
    }
    }
    
        public static func parse_inputClientProxy(_ reader: BufferReader) -> InputClientProxy? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputClientProxy.inputClientProxy(address: _1!, port: _2!)
        }
    
    }
}
public extension Api {
    enum InputCollectible: TypeConstructorDescription {
        case inputCollectiblePhone(phone: String)
        case inputCollectibleUsername(username: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputCollectiblePhone(let phone):
                    if boxed {
                        buffer.appendInt32(-1562241884)
                    }
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
                case .inputCollectibleUsername(let username):
                    if boxed {
                        buffer.appendInt32(-476815191)
                    }
                    serializeString(username, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputCollectiblePhone(let phone):
                return ("inputCollectiblePhone", [("phone", phone as Any)])
                case .inputCollectibleUsername(let username):
                return ("inputCollectibleUsername", [("username", username as Any)])
    }
    }
    
        public static func parse_inputCollectiblePhone(_ reader: BufferReader) -> InputCollectible? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputCollectible.inputCollectiblePhone(phone: _1!)
        }
        public static func parse_inputCollectibleUsername(_ reader: BufferReader) -> InputCollectible? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputCollectible.inputCollectibleUsername(username: _1!)
        }
    
    }
}
public extension Api {
    enum InputContact: TypeConstructorDescription {
        case inputPhoneContact(flags: Int32, clientId: Int64, phone: String, firstName: String, lastName: String, note: Api.TextWithEntities?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhoneContact(let flags, let clientId, let phone, let firstName, let lastName, let note):
                    if boxed {
                        buffer.appendInt32(1780335806)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {note!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhoneContact(let flags, let clientId, let phone, let firstName, let lastName, let note):
                return ("inputPhoneContact", [("flags", flags as Any), ("clientId", clientId as Any), ("phone", phone as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("note", note as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.InputContact.inputPhoneContact(flags: _1!, clientId: _2!, phone: _3!, firstName: _4!, lastName: _5!, note: _6)
        }
    
    }
}
public extension Api {
    indirect enum InputDialogPeer: TypeConstructorDescription {
        case inputDialogPeer(peer: Api.InputPeer)
        case inputDialogPeerFolder(folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDialogPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-55902537)
                    }
                    peer.serialize(buffer, true)
                    break
                case .inputDialogPeerFolder(let folderId):
                    if boxed {
                        buffer.appendInt32(1684014375)
                    }
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDialogPeer(let peer):
                return ("inputDialogPeer", [("peer", peer as Any)])
                case .inputDialogPeerFolder(let folderId):
                return ("inputDialogPeerFolder", [("folderId", folderId as Any)])
    }
    }
    
        public static func parse_inputDialogPeer(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputDialogPeer.inputDialogPeer(peer: _1!)
        }
        public static func parse_inputDialogPeerFolder(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputDialogPeer.inputDialogPeerFolder(folderId: _1!)
        }
    
    }
}
public extension Api {
    enum InputDocument: TypeConstructorDescription {
        case inputDocument(id: Int64, accessHash: Int64, fileReference: Buffer)
        case inputDocumentEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDocument(let id, let accessHash, let fileReference):
                    if boxed {
                        buffer.appendInt32(448771445)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
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
                case .inputDocument(let id, let accessHash, let fileReference):
                return ("inputDocument", [("id", id as Any), ("accessHash", accessHash as Any), ("fileReference", fileReference as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputDocument.inputDocument(id: _1!, accessHash: _2!, fileReference: _3!)
        }
        public static func parse_inputDocumentEmpty(_ reader: BufferReader) -> InputDocument? {
            return Api.InputDocument.inputDocumentEmpty
        }
    
    }
}
public extension Api {
    enum InputEncryptedChat: TypeConstructorDescription {
        case inputEncryptedChat(chatId: Int32, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputEncryptedChat(let chatId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-247351839)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputEncryptedChat(let chatId, let accessHash):
                return ("inputEncryptedChat", [("chatId", chatId as Any), ("accessHash", accessHash as Any)])
    }
    }
    
        public static func parse_inputEncryptedChat(_ reader: BufferReader) -> InputEncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputEncryptedChat.inputEncryptedChat(chatId: _1!, accessHash: _2!)
        }
    
    }
}
public extension Api {
    enum InputEncryptedFile: TypeConstructorDescription {
        case inputEncryptedFile(id: Int64, accessHash: Int64)
        case inputEncryptedFileBigUploaded(id: Int64, parts: Int32, keyFingerprint: Int32)
        case inputEncryptedFileEmpty
        case inputEncryptedFileUploaded(id: Int64, parts: Int32, md5Checksum: String, keyFingerprint: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputEncryptedFile(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1511503333)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFileBigUploaded(let id, let parts, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(767652808)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFileEmpty:
                    if boxed {
                        buffer.appendInt32(406307684)
                    }
                    
                    break
                case .inputEncryptedFileUploaded(let id, let parts, let md5Checksum, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1690108678)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputEncryptedFile(let id, let accessHash):
                return ("inputEncryptedFile", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputEncryptedFileBigUploaded(let id, let parts, let keyFingerprint):
                return ("inputEncryptedFileBigUploaded", [("id", id as Any), ("parts", parts as Any), ("keyFingerprint", keyFingerprint as Any)])
                case .inputEncryptedFileEmpty:
                return ("inputEncryptedFileEmpty", [])
                case .inputEncryptedFileUploaded(let id, let parts, let md5Checksum, let keyFingerprint):
                return ("inputEncryptedFileUploaded", [("id", id as Any), ("parts", parts as Any), ("md5Checksum", md5Checksum as Any), ("keyFingerprint", keyFingerprint as Any)])
    }
    }
    
        public static func parse_inputEncryptedFile(_ reader: BufferReader) -> InputEncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputEncryptedFile.inputEncryptedFile(id: _1!, accessHash: _2!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputEncryptedFile.inputEncryptedFileBigUploaded(id: _1!, parts: _2!, keyFingerprint: _3!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputEncryptedFile.inputEncryptedFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, keyFingerprint: _4!)
        }
    
    }
}
public extension Api {
    enum InputFile: TypeConstructorDescription {
        case inputFile(id: Int64, parts: Int32, name: String, md5Checksum: String)
        case inputFileBig(id: Int64, parts: Int32, name: String)
        case inputFileStoryDocument(id: Api.InputDocument)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputFile(let id, let parts, let name, let md5Checksum):
                    if boxed {
                        buffer.appendInt32(-181407105)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    break
                case .inputFileBig(let id, let parts, let name):
                    if boxed {
                        buffer.appendInt32(-95482955)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    break
                case .inputFileStoryDocument(let id):
                    if boxed {
                        buffer.appendInt32(1658620744)
                    }
                    id.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputFile(let id, let parts, let name, let md5Checksum):
                return ("inputFile", [("id", id as Any), ("parts", parts as Any), ("name", name as Any), ("md5Checksum", md5Checksum as Any)])
                case .inputFileBig(let id, let parts, let name):
                return ("inputFileBig", [("id", id as Any), ("parts", parts as Any), ("name", name as Any)])
                case .inputFileStoryDocument(let id):
                return ("inputFileStoryDocument", [("id", id as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputFile.inputFile(id: _1!, parts: _2!, name: _3!, md5Checksum: _4!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputFile.inputFileBig(id: _1!, parts: _2!, name: _3!)
        }
        public static func parse_inputFileStoryDocument(_ reader: BufferReader) -> InputFile? {
            var _1: Api.InputDocument?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputFile.inputFileStoryDocument(id: _1!)
        }
    
    }
}
