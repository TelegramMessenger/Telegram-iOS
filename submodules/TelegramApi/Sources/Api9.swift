public extension Api {
    indirect enum InputPeer: TypeConstructorDescription {
        case inputPeerChannel(channelId: Int64, accessHash: Int64)
        case inputPeerChannelFromMessage(peer: Api.InputPeer, msgId: Int32, channelId: Int64)
        case inputPeerChat(chatId: Int64)
        case inputPeerEmpty
        case inputPeerSelf
        case inputPeerUser(userId: Int64, accessHash: Int64)
        case inputPeerUserFromMessage(peer: Api.InputPeer, msgId: Int32, userId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPeerChannel(let channelId, let accessHash):
                    if boxed {
                        buffer.appendInt32(666680316)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputPeerChannelFromMessage(let peer, let msgId, let channelId):
                    if boxed {
                        buffer.appendInt32(-1121318848)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
                case .inputPeerChat(let chatId):
                    if boxed {
                        buffer.appendInt32(900291769)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .inputPeerEmpty:
                    if boxed {
                        buffer.appendInt32(2134579434)
                    }
                    
                    break
                case .inputPeerSelf:
                    if boxed {
                        buffer.appendInt32(2107670217)
                    }
                    
                    break
                case .inputPeerUser(let userId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-571955892)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputPeerUserFromMessage(let peer, let msgId, let userId):
                    if boxed {
                        buffer.appendInt32(-1468331492)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPeerChannel(let channelId, let accessHash):
                return ("inputPeerChannel", [("channelId", String(describing: channelId)), ("accessHash", String(describing: accessHash))])
                case .inputPeerChannelFromMessage(let peer, let msgId, let channelId):
                return ("inputPeerChannelFromMessage", [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("channelId", String(describing: channelId))])
                case .inputPeerChat(let chatId):
                return ("inputPeerChat", [("chatId", String(describing: chatId))])
                case .inputPeerEmpty:
                return ("inputPeerEmpty", [])
                case .inputPeerSelf:
                return ("inputPeerSelf", [])
                case .inputPeerUser(let userId, let accessHash):
                return ("inputPeerUser", [("userId", String(describing: userId)), ("accessHash", String(describing: accessHash))])
                case .inputPeerUserFromMessage(let peer, let msgId, let userId):
                return ("inputPeerUserFromMessage", [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("userId", String(describing: userId))])
    }
    }
    
        public static func parse_inputPeerChannel(_ reader: BufferReader) -> InputPeer? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPeer.inputPeerChannel(channelId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerChannelFromMessage(_ reader: BufferReader) -> InputPeer? {
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
                return Api.InputPeer.inputPeerChannelFromMessage(peer: _1!, msgId: _2!, channelId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerChat(_ reader: BufferReader) -> InputPeer? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPeer.inputPeerChat(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerEmpty(_ reader: BufferReader) -> InputPeer? {
            return Api.InputPeer.inputPeerEmpty
        }
        public static func parse_inputPeerSelf(_ reader: BufferReader) -> InputPeer? {
            return Api.InputPeer.inputPeerSelf
        }
        public static func parse_inputPeerUser(_ reader: BufferReader) -> InputPeer? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPeer.inputPeerUser(userId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerUserFromMessage(_ reader: BufferReader) -> InputPeer? {
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
                return Api.InputPeer.inputPeerUserFromMessage(peer: _1!, msgId: _2!, userId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputPeerNotifySettings: TypeConstructorDescription {
        case inputPeerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: Api.NotificationSound?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPeerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound):
                    if boxed {
                        buffer.appendInt32(-551616469)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {showPreviews!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {silent!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(muteUntil!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {sound!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPeerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound):
                return ("inputPeerNotifySettings", [("flags", String(describing: flags)), ("showPreviews", String(describing: showPreviews)), ("silent", String(describing: silent)), ("muteUntil", String(describing: muteUntil)), ("sound", String(describing: sound))])
    }
    }
    
        public static func parse_inputPeerNotifySettings(_ reader: BufferReader) -> InputPeerNotifySettings? {
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
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            var _5: Api.NotificationSound?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.NotificationSound
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: _1!, showPreviews: _2, silent: _3, muteUntil: _4, sound: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputPhoneCall: TypeConstructorDescription {
        case inputPhoneCall(id: Int64, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhoneCall(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(506920429)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhoneCall(let id, let accessHash):
                return ("inputPhoneCall", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
    }
    }
    
        public static func parse_inputPhoneCall(_ reader: BufferReader) -> InputPhoneCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPhoneCall.inputPhoneCall(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputPhoto: TypeConstructorDescription {
        case inputPhoto(id: Int64, accessHash: Int64, fileReference: Buffer)
        case inputPhotoEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhoto(let id, let accessHash, let fileReference):
                    if boxed {
                        buffer.appendInt32(1001634122)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
                case .inputPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(483901197)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhoto(let id, let accessHash, let fileReference):
                return ("inputPhoto", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference))])
                case .inputPhotoEmpty:
                return ("inputPhotoEmpty", [])
    }
    }
    
        public static func parse_inputPhoto(_ reader: BufferReader) -> InputPhoto? {
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
                return Api.InputPhoto.inputPhoto(id: _1!, accessHash: _2!, fileReference: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoEmpty(_ reader: BufferReader) -> InputPhoto? {
            return Api.InputPhoto.inputPhotoEmpty
        }
    
    }
}
public extension Api {
    enum InputPrivacyKey: TypeConstructorDescription {
        case inputPrivacyKeyAddedByPhone
        case inputPrivacyKeyChatInvite
        case inputPrivacyKeyForwards
        case inputPrivacyKeyPhoneCall
        case inputPrivacyKeyPhoneNumber
        case inputPrivacyKeyPhoneP2P
        case inputPrivacyKeyProfilePhoto
        case inputPrivacyKeyStatusTimestamp
        case inputPrivacyKeyVoiceMessages
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPrivacyKeyAddedByPhone:
                    if boxed {
                        buffer.appendInt32(-786326563)
                    }
                    
                    break
                case .inputPrivacyKeyChatInvite:
                    if boxed {
                        buffer.appendInt32(-1107622874)
                    }
                    
                    break
                case .inputPrivacyKeyForwards:
                    if boxed {
                        buffer.appendInt32(-1529000952)
                    }
                    
                    break
                case .inputPrivacyKeyPhoneCall:
                    if boxed {
                        buffer.appendInt32(-88417185)
                    }
                    
                    break
                case .inputPrivacyKeyPhoneNumber:
                    if boxed {
                        buffer.appendInt32(55761658)
                    }
                    
                    break
                case .inputPrivacyKeyPhoneP2P:
                    if boxed {
                        buffer.appendInt32(-610373422)
                    }
                    
                    break
                case .inputPrivacyKeyProfilePhoto:
                    if boxed {
                        buffer.appendInt32(1461304012)
                    }
                    
                    break
                case .inputPrivacyKeyStatusTimestamp:
                    if boxed {
                        buffer.appendInt32(1335282456)
                    }
                    
                    break
                case .inputPrivacyKeyVoiceMessages:
                    if boxed {
                        buffer.appendInt32(-1360618136)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPrivacyKeyAddedByPhone:
                return ("inputPrivacyKeyAddedByPhone", [])
                case .inputPrivacyKeyChatInvite:
                return ("inputPrivacyKeyChatInvite", [])
                case .inputPrivacyKeyForwards:
                return ("inputPrivacyKeyForwards", [])
                case .inputPrivacyKeyPhoneCall:
                return ("inputPrivacyKeyPhoneCall", [])
                case .inputPrivacyKeyPhoneNumber:
                return ("inputPrivacyKeyPhoneNumber", [])
                case .inputPrivacyKeyPhoneP2P:
                return ("inputPrivacyKeyPhoneP2P", [])
                case .inputPrivacyKeyProfilePhoto:
                return ("inputPrivacyKeyProfilePhoto", [])
                case .inputPrivacyKeyStatusTimestamp:
                return ("inputPrivacyKeyStatusTimestamp", [])
                case .inputPrivacyKeyVoiceMessages:
                return ("inputPrivacyKeyVoiceMessages", [])
    }
    }
    
        public static func parse_inputPrivacyKeyAddedByPhone(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyAddedByPhone
        }
        public static func parse_inputPrivacyKeyChatInvite(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyChatInvite
        }
        public static func parse_inputPrivacyKeyForwards(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyForwards
        }
        public static func parse_inputPrivacyKeyPhoneCall(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyPhoneCall
        }
        public static func parse_inputPrivacyKeyPhoneNumber(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyPhoneNumber
        }
        public static func parse_inputPrivacyKeyPhoneP2P(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyPhoneP2P
        }
        public static func parse_inputPrivacyKeyProfilePhoto(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyProfilePhoto
        }
        public static func parse_inputPrivacyKeyStatusTimestamp(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyStatusTimestamp
        }
        public static func parse_inputPrivacyKeyVoiceMessages(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyVoiceMessages
        }
    
    }
}
public extension Api {
    enum InputPrivacyRule: TypeConstructorDescription {
        case inputPrivacyValueAllowAll
        case inputPrivacyValueAllowChatParticipants(chats: [Int64])
        case inputPrivacyValueAllowContacts
        case inputPrivacyValueAllowUsers(users: [Api.InputUser])
        case inputPrivacyValueDisallowAll
        case inputPrivacyValueDisallowChatParticipants(chats: [Int64])
        case inputPrivacyValueDisallowContacts
        case inputPrivacyValueDisallowUsers(users: [Api.InputUser])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPrivacyValueAllowAll:
                    if boxed {
                        buffer.appendInt32(407582158)
                    }
                    
                    break
                case .inputPrivacyValueAllowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(-2079962673)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .inputPrivacyValueAllowContacts:
                    if boxed {
                        buffer.appendInt32(218751099)
                    }
                    
                    break
                case .inputPrivacyValueAllowUsers(let users):
                    if boxed {
                        buffer.appendInt32(320652927)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .inputPrivacyValueDisallowAll:
                    if boxed {
                        buffer.appendInt32(-697604407)
                    }
                    
                    break
                case .inputPrivacyValueDisallowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(-380694650)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .inputPrivacyValueDisallowContacts:
                    if boxed {
                        buffer.appendInt32(195371015)
                    }
                    
                    break
                case .inputPrivacyValueDisallowUsers(let users):
                    if boxed {
                        buffer.appendInt32(-1877932953)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPrivacyValueAllowAll:
                return ("inputPrivacyValueAllowAll", [])
                case .inputPrivacyValueAllowChatParticipants(let chats):
                return ("inputPrivacyValueAllowChatParticipants", [("chats", String(describing: chats))])
                case .inputPrivacyValueAllowContacts:
                return ("inputPrivacyValueAllowContacts", [])
                case .inputPrivacyValueAllowUsers(let users):
                return ("inputPrivacyValueAllowUsers", [("users", String(describing: users))])
                case .inputPrivacyValueDisallowAll:
                return ("inputPrivacyValueDisallowAll", [])
                case .inputPrivacyValueDisallowChatParticipants(let chats):
                return ("inputPrivacyValueDisallowChatParticipants", [("chats", String(describing: chats))])
                case .inputPrivacyValueDisallowContacts:
                return ("inputPrivacyValueDisallowContacts", [])
                case .inputPrivacyValueDisallowUsers(let users):
                return ("inputPrivacyValueDisallowUsers", [("users", String(describing: users))])
    }
    }
    
        public static func parse_inputPrivacyValueAllowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowAll
        }
        public static func parse_inputPrivacyValueAllowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueAllowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowContacts
        }
        public static func parse_inputPrivacyValueAllowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueDisallowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowAll
        }
        public static func parse_inputPrivacyValueDisallowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueDisallowChatParticipants(chats: _1!)
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
                return Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputSecureFile: TypeConstructorDescription {
        case inputSecureFile(id: Int64, accessHash: Int64)
        case inputSecureFileUploaded(id: Int64, parts: Int32, md5Checksum: String, fileHash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSecureFile(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1399317950)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputSecureFileUploaded(let id, let parts, let md5Checksum, let fileHash, let secret):
                    if boxed {
                        buffer.appendInt32(859091184)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSecureFile(let id, let accessHash):
                return ("inputSecureFile", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputSecureFileUploaded(let id, let parts, let md5Checksum, let fileHash, let secret):
                return ("inputSecureFileUploaded", [("id", String(describing: id)), ("parts", String(describing: parts)), ("md5Checksum", String(describing: md5Checksum)), ("fileHash", String(describing: fileHash)), ("secret", String(describing: secret))])
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
                return Api.InputSecureFile.inputSecureFile(id: _1!, accessHash: _2!)
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
                return Api.InputSecureFile.inputSecureFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, fileHash: _4!, secret: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputSecureValue: TypeConstructorDescription {
        case inputSecureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.InputSecureFile?, reverseSide: Api.InputSecureFile?, selfie: Api.InputSecureFile?, translation: [Api.InputSecureFile]?, files: [Api.InputSecureFile]?, plainData: Api.SecurePlainData?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSecureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData):
                    if boxed {
                        buffer.appendInt32(-618540889)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {data!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {frontSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {reverseSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {selfie!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(translation!.count))
                    for item in translation! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(files!.count))
                    for item in files! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {plainData!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSecureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData):
                return ("inputSecureValue", [("flags", String(describing: flags)), ("type", String(describing: type)), ("data", String(describing: data)), ("frontSide", String(describing: frontSide)), ("reverseSide", String(describing: reverseSide)), ("selfie", String(describing: selfie)), ("translation", String(describing: translation)), ("files", String(describing: files)), ("plainData", String(describing: plainData))])
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureData
            } }
            var _4: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _5: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _6: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _7: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
            } }
            var _8: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
            } }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
            } }
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
                return Api.InputSecureValue.inputSecureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputSingleMedia: TypeConstructorDescription {
        case inputSingleMedia(flags: Int32, media: Api.InputMedia, randomId: Int64, message: String, entities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSingleMedia(let flags, let media, let randomId, let message, let entities):
                    if boxed {
                        buffer.appendInt32(482797855)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSingleMedia(let flags, let media, let randomId, let message, let entities):
                return ("inputSingleMedia", [("flags", String(describing: flags)), ("media", String(describing: media)), ("randomId", String(describing: randomId)), ("message", String(describing: message)), ("entities", String(describing: entities))])
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
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputSingleMedia.inputSingleMedia(flags: _1!, media: _2!, randomId: _3!, message: _4!, entities: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
