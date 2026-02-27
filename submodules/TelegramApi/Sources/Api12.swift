public extension Api {
    enum InputPaymentCredentials: TypeConstructorDescription {
        public class Cons_inputPaymentCredentials {
            public var flags: Int32
            public var data: Api.DataJSON
            public init(flags: Int32, data: Api.DataJSON) {
                self.flags = flags
                self.data = data
            }
        }
        public class Cons_inputPaymentCredentialsApplePay {
            public var paymentData: Api.DataJSON
            public init(paymentData: Api.DataJSON) {
                self.paymentData = paymentData
            }
        }
        public class Cons_inputPaymentCredentialsGooglePay {
            public var paymentToken: Api.DataJSON
            public init(paymentToken: Api.DataJSON) {
                self.paymentToken = paymentToken
            }
        }
        public class Cons_inputPaymentCredentialsSaved {
            public var id: String
            public var tmpPassword: Buffer
            public init(id: String, tmpPassword: Buffer) {
                self.id = id
                self.tmpPassword = tmpPassword
            }
        }
        case inputPaymentCredentials(Cons_inputPaymentCredentials)
        case inputPaymentCredentialsApplePay(Cons_inputPaymentCredentialsApplePay)
        case inputPaymentCredentialsGooglePay(Cons_inputPaymentCredentialsGooglePay)
        case inputPaymentCredentialsSaved(Cons_inputPaymentCredentialsSaved)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPaymentCredentials(let _data):
                if boxed {
                    buffer.appendInt32(873977640)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.data.serialize(buffer, true)
                break
            case .inputPaymentCredentialsApplePay(let _data):
                if boxed {
                    buffer.appendInt32(178373535)
                }
                _data.paymentData.serialize(buffer, true)
                break
            case .inputPaymentCredentialsGooglePay(let _data):
                if boxed {
                    buffer.appendInt32(-1966921727)
                }
                _data.paymentToken.serialize(buffer, true)
                break
            case .inputPaymentCredentialsSaved(let _data):
                if boxed {
                    buffer.appendInt32(-1056001329)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeBytes(_data.tmpPassword, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputPaymentCredentials(let _data):
                return ("inputPaymentCredentials", [("flags", _data.flags as Any), ("data", _data.data as Any)])
            case .inputPaymentCredentialsApplePay(let _data):
                return ("inputPaymentCredentialsApplePay", [("paymentData", _data.paymentData as Any)])
            case .inputPaymentCredentialsGooglePay(let _data):
                return ("inputPaymentCredentialsGooglePay", [("paymentToken", _data.paymentToken as Any)])
            case .inputPaymentCredentialsSaved(let _data):
                return ("inputPaymentCredentialsSaved", [("id", _data.id as Any), ("tmpPassword", _data.tmpPassword as Any)])
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
                return Api.InputPaymentCredentials.inputPaymentCredentials(Cons_inputPaymentCredentials(flags: _1!, data: _2!))
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
                return Api.InputPaymentCredentials.inputPaymentCredentialsApplePay(Cons_inputPaymentCredentialsApplePay(paymentData: _1!))
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
                return Api.InputPaymentCredentials.inputPaymentCredentialsGooglePay(Cons_inputPaymentCredentialsGooglePay(paymentToken: _1!))
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
                return Api.InputPaymentCredentials.inputPaymentCredentialsSaved(Cons_inputPaymentCredentialsSaved(id: _1!, tmpPassword: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputPeer: TypeConstructorDescription {
        public class Cons_inputPeerChannel {
            public var channelId: Int64
            public var accessHash: Int64
            public init(channelId: Int64, accessHash: Int64) {
                self.channelId = channelId
                self.accessHash = accessHash
            }
        }
        public class Cons_inputPeerChannelFromMessage {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var channelId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, channelId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.channelId = channelId
            }
        }
        public class Cons_inputPeerChat {
            public var chatId: Int64
            public init(chatId: Int64) {
                self.chatId = chatId
            }
        }
        public class Cons_inputPeerUser {
            public var userId: Int64
            public var accessHash: Int64
            public init(userId: Int64, accessHash: Int64) {
                self.userId = userId
                self.accessHash = accessHash
            }
        }
        public class Cons_inputPeerUserFromMessage {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var userId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, userId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.userId = userId
            }
        }
        case inputPeerChannel(Cons_inputPeerChannel)
        case inputPeerChannelFromMessage(Cons_inputPeerChannelFromMessage)
        case inputPeerChat(Cons_inputPeerChat)
        case inputPeerEmpty
        case inputPeerSelf
        case inputPeerUser(Cons_inputPeerUser)
        case inputPeerUserFromMessage(Cons_inputPeerUserFromMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPeerChannel(let _data):
                if boxed {
                    buffer.appendInt32(666680316)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputPeerChannelFromMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1121318848)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                break
            case .inputPeerChat(let _data):
                if boxed {
                    buffer.appendInt32(900291769)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
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
            case .inputPeerUser(let _data):
                if boxed {
                    buffer.appendInt32(-571955892)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputPeerUserFromMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1468331492)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputPeerChannel(let _data):
                return ("inputPeerChannel", [("channelId", _data.channelId as Any), ("accessHash", _data.accessHash as Any)])
            case .inputPeerChannelFromMessage(let _data):
                return ("inputPeerChannelFromMessage", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("channelId", _data.channelId as Any)])
            case .inputPeerChat(let _data):
                return ("inputPeerChat", [("chatId", _data.chatId as Any)])
            case .inputPeerEmpty:
                return ("inputPeerEmpty", [])
            case .inputPeerSelf:
                return ("inputPeerSelf", [])
            case .inputPeerUser(let _data):
                return ("inputPeerUser", [("userId", _data.userId as Any), ("accessHash", _data.accessHash as Any)])
            case .inputPeerUserFromMessage(let _data):
                return ("inputPeerUserFromMessage", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("userId", _data.userId as Any)])
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
                return Api.InputPeer.inputPeerChannel(Cons_inputPeerChannel(channelId: _1!, accessHash: _2!))
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
                return Api.InputPeer.inputPeerChannelFromMessage(Cons_inputPeerChannelFromMessage(peer: _1!, msgId: _2!, channelId: _3!))
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
                return Api.InputPeer.inputPeerChat(Cons_inputPeerChat(chatId: _1!))
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
                return Api.InputPeer.inputPeerUser(Cons_inputPeerUser(userId: _1!, accessHash: _2!))
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
                return Api.InputPeer.inputPeerUserFromMessage(Cons_inputPeerUserFromMessage(peer: _1!, msgId: _2!, userId: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputPeerNotifySettings: TypeConstructorDescription {
        public class Cons_inputPeerNotifySettings {
            public var flags: Int32
            public var showPreviews: Api.Bool?
            public var silent: Api.Bool?
            public var muteUntil: Int32?
            public var sound: Api.NotificationSound?
            public var storiesMuted: Api.Bool?
            public var storiesHideSender: Api.Bool?
            public var storiesSound: Api.NotificationSound?
            public init(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesSound: Api.NotificationSound?) {
                self.flags = flags
                self.showPreviews = showPreviews
                self.silent = silent
                self.muteUntil = muteUntil
                self.sound = sound
                self.storiesMuted = storiesMuted
                self.storiesHideSender = storiesHideSender
                self.storiesSound = storiesSound
            }
        }
        case inputPeerNotifySettings(Cons_inputPeerNotifySettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPeerNotifySettings(let _data):
                if boxed {
                    buffer.appendInt32(-892638494)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.showPreviews!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.silent!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.muteUntil!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.sound!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.storiesMuted!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    _data.storiesHideSender!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.storiesSound!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputPeerNotifySettings(let _data):
                return ("inputPeerNotifySettings", [("flags", _data.flags as Any), ("showPreviews", _data.showPreviews as Any), ("silent", _data.silent as Any), ("muteUntil", _data.muteUntil as Any), ("sound", _data.sound as Any), ("storiesMuted", _data.storiesMuted as Any), ("storiesHideSender", _data.storiesHideSender as Any), ("storiesSound", _data.storiesSound as Any)])
            }
        }

        public static func parse_inputPeerNotifySettings(_ reader: BufferReader) -> InputPeerNotifySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Api.NotificationSound?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            var _6: Api.Bool?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _7: Api.Bool?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _8: Api.NotificationSound?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 6) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 8) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.InputPeerNotifySettings.inputPeerNotifySettings(Cons_inputPeerNotifySettings(flags: _1!, showPreviews: _2, silent: _3, muteUntil: _4, sound: _5, storiesMuted: _6, storiesHideSender: _7, storiesSound: _8))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputPhoneCall: TypeConstructorDescription {
        public class Cons_inputPhoneCall {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        case inputPhoneCall(Cons_inputPhoneCall)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPhoneCall(let _data):
                if boxed {
                    buffer.appendInt32(506920429)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputPhoneCall(let _data):
                return ("inputPhoneCall", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
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
                return Api.InputPhoneCall.inputPhoneCall(Cons_inputPhoneCall(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputPhoto: TypeConstructorDescription {
        public class Cons_inputPhoto {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public init(id: Int64, accessHash: Int64, fileReference: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
            }
        }
        case inputPhoto(Cons_inputPhoto)
        case inputPhotoEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPhoto(let _data):
                if boxed {
                    buffer.appendInt32(1001634122)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
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
            case .inputPhoto(let _data):
                return ("inputPhoto", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("fileReference", _data.fileReference as Any)])
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
                return Api.InputPhoto.inputPhoto(Cons_inputPhoto(id: _1!, accessHash: _2!, fileReference: _3!))
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
        case inputPrivacyKeySavedMusic
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
            case .inputPrivacyKeySavedMusic:
                if boxed {
                    buffer.appendInt32(1304334886)
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
            case .inputPrivacyKeySavedMusic:
                return ("inputPrivacyKeySavedMusic", [])
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
        public static func parse_inputPrivacyKeySavedMusic(_ reader: BufferReader) -> InputPrivacyKey? {
            return Api.InputPrivacyKey.inputPrivacyKeySavedMusic
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
public extension Api {
    enum InputPrivacyRule: TypeConstructorDescription {
        public class Cons_inputPrivacyValueAllowChatParticipants {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
        }
        public class Cons_inputPrivacyValueAllowUsers {
            public var users: [Api.InputUser]
            public init(users: [Api.InputUser]) {
                self.users = users
            }
        }
        public class Cons_inputPrivacyValueDisallowChatParticipants {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
        }
        public class Cons_inputPrivacyValueDisallowUsers {
            public var users: [Api.InputUser]
            public init(users: [Api.InputUser]) {
                self.users = users
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputPrivacyValueAllowAll:
                return ("inputPrivacyValueAllowAll", [])
            case .inputPrivacyValueAllowBots:
                return ("inputPrivacyValueAllowBots", [])
            case .inputPrivacyValueAllowChatParticipants(let _data):
                return ("inputPrivacyValueAllowChatParticipants", [("chats", _data.chats as Any)])
            case .inputPrivacyValueAllowCloseFriends:
                return ("inputPrivacyValueAllowCloseFriends", [])
            case .inputPrivacyValueAllowContacts:
                return ("inputPrivacyValueAllowContacts", [])
            case .inputPrivacyValueAllowPremium:
                return ("inputPrivacyValueAllowPremium", [])
            case .inputPrivacyValueAllowUsers(let _data):
                return ("inputPrivacyValueAllowUsers", [("users", _data.users as Any)])
            case .inputPrivacyValueDisallowAll:
                return ("inputPrivacyValueDisallowAll", [])
            case .inputPrivacyValueDisallowBots:
                return ("inputPrivacyValueDisallowBots", [])
            case .inputPrivacyValueDisallowChatParticipants(let _data):
                return ("inputPrivacyValueDisallowChatParticipants", [("chats", _data.chats as Any)])
            case .inputPrivacyValueDisallowContacts:
                return ("inputPrivacyValueDisallowContacts", [])
            case .inputPrivacyValueDisallowUsers(let _data):
                return ("inputPrivacyValueDisallowUsers", [("users", _data.users as Any)])
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
