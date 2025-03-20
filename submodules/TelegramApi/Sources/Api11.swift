public extension Api {
    enum InputMessage: TypeConstructorDescription {
        case inputMessageCallbackQuery(id: Int32, queryId: Int64)
        case inputMessageID(id: Int32)
        case inputMessagePinned
        case inputMessageReplyTo(id: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMessageCallbackQuery(let id, let queryId):
                    if boxed {
                        buffer.appendInt32(-1392895362)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    break
                case .inputMessageID(let id):
                    if boxed {
                        buffer.appendInt32(-1502174430)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .inputMessagePinned:
                    if boxed {
                        buffer.appendInt32(-2037963464)
                    }
                    
                    break
                case .inputMessageReplyTo(let id):
                    if boxed {
                        buffer.appendInt32(-1160215659)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMessageCallbackQuery(let id, let queryId):
                return ("inputMessageCallbackQuery", [("id", id as Any), ("queryId", queryId as Any)])
                case .inputMessageID(let id):
                return ("inputMessageID", [("id", id as Any)])
                case .inputMessagePinned:
                return ("inputMessagePinned", [])
                case .inputMessageReplyTo(let id):
                return ("inputMessageReplyTo", [("id", id as Any)])
    }
    }
    
        public static func parse_inputMessageCallbackQuery(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMessage.inputMessageCallbackQuery(id: _1!, queryId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessageID(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageID(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessagePinned(_ reader: BufferReader) -> InputMessage? {
            return Api.InputMessage.inputMessagePinned
        }
        public static func parse_inputMessageReplyTo(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageReplyTo(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputNotifyPeer: TypeConstructorDescription {
        case inputNotifyBroadcasts
        case inputNotifyChats
        case inputNotifyForumTopic(peer: Api.InputPeer, topMsgId: Int32)
        case inputNotifyPeer(peer: Api.InputPeer)
        case inputNotifyUsers
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputNotifyBroadcasts:
                    if boxed {
                        buffer.appendInt32(-1311015810)
                    }
                    
                    break
                case .inputNotifyChats:
                    if boxed {
                        buffer.appendInt32(1251338318)
                    }
                    
                    break
                case .inputNotifyForumTopic(let peer, let topMsgId):
                    if boxed {
                        buffer.appendInt32(1548122514)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    break
                case .inputNotifyPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-1195615476)
                    }
                    peer.serialize(buffer, true)
                    break
                case .inputNotifyUsers:
                    if boxed {
                        buffer.appendInt32(423314455)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputNotifyBroadcasts:
                return ("inputNotifyBroadcasts", [])
                case .inputNotifyChats:
                return ("inputNotifyChats", [])
                case .inputNotifyForumTopic(let peer, let topMsgId):
                return ("inputNotifyForumTopic", [("peer", peer as Any), ("topMsgId", topMsgId as Any)])
                case .inputNotifyPeer(let peer):
                return ("inputNotifyPeer", [("peer", peer as Any)])
                case .inputNotifyUsers:
                return ("inputNotifyUsers", [])
    }
    }
    
        public static func parse_inputNotifyBroadcasts(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyBroadcasts
        }
        public static func parse_inputNotifyChats(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyChats
        }
        public static func parse_inputNotifyForumTopic(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputNotifyPeer.inputNotifyForumTopic(peer: _1!, topMsgId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputNotifyPeer(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputNotifyPeer.inputNotifyPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputNotifyUsers(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyUsers
        }
    
    }
}
public extension Api {
    enum InputPaymentCredentials: TypeConstructorDescription {
        case inputPaymentCredentials(flags: Int32, data: Api.DataJSON)
        case inputPaymentCredentialsApplePay(paymentData: Api.DataJSON)
        case inputPaymentCredentialsGooglePay(paymentToken: Api.DataJSON)
        case inputPaymentCredentialsSaved(id: String, tmpPassword: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPaymentCredentials(let flags, let data):
                    if boxed {
                        buffer.appendInt32(873977640)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsApplePay(let paymentData):
                    if boxed {
                        buffer.appendInt32(178373535)
                    }
                    paymentData.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsGooglePay(let paymentToken):
                    if boxed {
                        buffer.appendInt32(-1966921727)
                    }
                    paymentToken.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsSaved(let id, let tmpPassword):
                    if boxed {
                        buffer.appendInt32(-1056001329)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeBytes(tmpPassword, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPaymentCredentials(let flags, let data):
                return ("inputPaymentCredentials", [("flags", flags as Any), ("data", data as Any)])
                case .inputPaymentCredentialsApplePay(let paymentData):
                return ("inputPaymentCredentialsApplePay", [("paymentData", paymentData as Any)])
                case .inputPaymentCredentialsGooglePay(let paymentToken):
                return ("inputPaymentCredentialsGooglePay", [("paymentToken", paymentToken as Any)])
                case .inputPaymentCredentialsSaved(let id, let tmpPassword):
                return ("inputPaymentCredentialsSaved", [("id", id as Any), ("tmpPassword", tmpPassword as Any)])
    }
    }
    
        public static func parse_inputPaymentCredentials(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPaymentCredentials.inputPaymentCredentials(flags: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsApplePay(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsApplePay(paymentData: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsGooglePay(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsGooglePay(paymentToken: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsSaved(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsSaved(id: _1!, tmpPassword: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
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
                return ("inputPeerChannel", [("channelId", channelId as Any), ("accessHash", accessHash as Any)])
                case .inputPeerChannelFromMessage(let peer, let msgId, let channelId):
                return ("inputPeerChannelFromMessage", [("peer", peer as Any), ("msgId", msgId as Any), ("channelId", channelId as Any)])
                case .inputPeerChat(let chatId):
                return ("inputPeerChat", [("chatId", chatId as Any)])
                case .inputPeerEmpty:
                return ("inputPeerEmpty", [])
                case .inputPeerSelf:
                return ("inputPeerSelf", [])
                case .inputPeerUser(let userId, let accessHash):
                return ("inputPeerUser", [("userId", userId as Any), ("accessHash", accessHash as Any)])
                case .inputPeerUserFromMessage(let peer, let msgId, let userId):
                return ("inputPeerUserFromMessage", [("peer", peer as Any), ("msgId", msgId as Any), ("userId", userId as Any)])
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
        case inputPeerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesSound: Api.NotificationSound?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPeerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound, let storiesMuted, let storiesHideSender, let storiesSound):
                    if boxed {
                        buffer.appendInt32(-892638494)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {showPreviews!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {silent!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(muteUntil!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {sound!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {storiesMuted!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {storiesHideSender!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 8) != 0 {storiesSound!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPeerNotifySettings(let flags, let showPreviews, let silent, let muteUntil, let sound, let storiesMuted, let storiesHideSender, let storiesSound):
                return ("inputPeerNotifySettings", [("flags", flags as Any), ("showPreviews", showPreviews as Any), ("silent", silent as Any), ("muteUntil", muteUntil as Any), ("sound", sound as Any), ("storiesMuted", storiesMuted as Any), ("storiesHideSender", storiesHideSender as Any), ("storiesSound", storiesSound as Any)])
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
            var _6: Api.Bool?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _7: Api.Bool?
            if Int(_1!) & Int(1 << 7) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _8: Api.NotificationSound?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.NotificationSound
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 6) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 8) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.InputPeerNotifySettings.inputPeerNotifySettings(flags: _1!, showPreviews: _2, silent: _3, muteUntil: _4, sound: _5, storiesMuted: _6, storiesHideSender: _7, storiesSound: _8)
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
                return ("inputPhoneCall", [("id", id as Any), ("accessHash", accessHash as Any)])
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
                return ("inputPhoto", [("id", id as Any), ("accessHash", accessHash as Any), ("fileReference", fileReference as Any)])
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
        case inputPrivacyKeyAbout
        case inputPrivacyKeyAddedByPhone
        case inputPrivacyKeyBirthday
        case inputPrivacyKeyChatInvite
        case inputPrivacyKeyForwards
        case inputPrivacyKeyNoPaidMessages
        case inputPrivacyKeyPhoneCall
        case inputPrivacyKeyPhoneNumber
        case inputPrivacyKeyPhoneP2P
        case inputPrivacyKeyProfilePhoto
        case inputPrivacyKeyStarGiftsAutoSave
        case inputPrivacyKeyStatusTimestamp
        case inputPrivacyKeyVoiceMessages
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPrivacyKeyAbout:
                    if boxed {
                        buffer.appendInt32(941870144)
                    }
                    
                    break
                case .inputPrivacyKeyAddedByPhone:
                    if boxed {
                        buffer.appendInt32(-786326563)
                    }
                    
                    break
                case .inputPrivacyKeyBirthday:
                    if boxed {
                        buffer.appendInt32(-698740276)
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
                case .inputPrivacyKeyNoPaidMessages:
                    if boxed {
                        buffer.appendInt32(-1111124044)
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
                case .inputPrivacyKeyStarGiftsAutoSave:
                    if boxed {
                        buffer.appendInt32(-512548031)
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
                case .inputPrivacyKeyAbout:
                return ("inputPrivacyKeyAbout", [])
                case .inputPrivacyKeyAddedByPhone:
                return ("inputPrivacyKeyAddedByPhone", [])
                case .inputPrivacyKeyBirthday:
                return ("inputPrivacyKeyBirthday", [])
                case .inputPrivacyKeyChatInvite:
                return ("inputPrivacyKeyChatInvite", [])
                case .inputPrivacyKeyForwards:
                return ("inputPrivacyKeyForwards", [])
                case .inputPrivacyKeyNoPaidMessages:
                return ("inputPrivacyKeyNoPaidMessages", [])
                case .inputPrivacyKeyPhoneCall:
                return ("inputPrivacyKeyPhoneCall", [])
                case .inputPrivacyKeyPhoneNumber:
                return ("inputPrivacyKeyPhoneNumber", [])
                case .inputPrivacyKeyPhoneP2P:
                return ("inputPrivacyKeyPhoneP2P", [])
                case .inputPrivacyKeyProfilePhoto:
                return ("inputPrivacyKeyProfilePhoto", [])
                case .inputPrivacyKeyStarGiftsAutoSave:
                return ("inputPrivacyKeyStarGiftsAutoSave", [])
                case .inputPrivacyKeyStatusTimestamp:
                return ("inputPrivacyKeyStatusTimestamp", [])
                case .inputPrivacyKeyVoiceMessages:
                return ("inputPrivacyKeyVoiceMessages", [])
    }
    }
    
        public static func parse_inputPrivacyKeyAbout(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyAbout
        }
        public static func parse_inputPrivacyKeyAddedByPhone(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyAddedByPhone
        }
        public static func parse_inputPrivacyKeyBirthday(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyBirthday
        }
        public static func parse_inputPrivacyKeyChatInvite(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyChatInvite
        }
        public static func parse_inputPrivacyKeyForwards(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyForwards
        }
        public static func parse_inputPrivacyKeyNoPaidMessages(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyNoPaidMessages
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
        public static func parse_inputPrivacyKeyStarGiftsAutoSave(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyStarGiftsAutoSave
        }
        public static func parse_inputPrivacyKeyStatusTimestamp(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyStatusTimestamp
        }
        public static func parse_inputPrivacyKeyVoiceMessages(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeyVoiceMessages
        }
    
    }
}
