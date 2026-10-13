public extension Api {
    enum InputMessage: TypeConstructorDescription {
        public class Cons_inputMessageCallbackQuery: TypeConstructorDescription {
            public var id: Int32
            public var queryId: Int64
            public init(id: Int32, queryId: Int64) {
                self.id = id
                self.queryId = queryId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageCallbackQuery", [("id", ConstructorParameterDescription(self.id)), ("queryId", ConstructorParameterDescription(self.queryId))])
            }
        }
        public class Cons_inputMessageID: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageID", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_inputMessageReplyTo: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageReplyTo", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case inputMessageCallbackQuery(Cons_inputMessageCallbackQuery)
        case inputMessageID(Cons_inputMessageID)
        case inputMessagePinned
        case inputMessageReplyTo(Cons_inputMessageReplyTo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMessageCallbackQuery(let _data):
                if boxed {
                    buffer.appendInt32(-1392895362)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                break
            case .inputMessageID(let _data):
                if boxed {
                    buffer.appendInt32(-1502174430)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            case .inputMessagePinned:
                if boxed {
                    buffer.appendInt32(-2037963464)
                }
                break
            case .inputMessageReplyTo(let _data):
                if boxed {
                    buffer.appendInt32(-1160215659)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMessageCallbackQuery(let _data):
                return ("inputMessageCallbackQuery", [("id", ConstructorParameterDescription(_data.id)), ("queryId", ConstructorParameterDescription(_data.queryId))])
            case .inputMessageID(let _data):
                return ("inputMessageID", [("id", ConstructorParameterDescription(_data.id))])
            case .inputMessagePinned:
                return ("inputMessagePinned", [])
            case .inputMessageReplyTo(let _data):
                return ("inputMessageReplyTo", [("id", ConstructorParameterDescription(_data.id))])
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
                return Api.InputMessage.inputMessageCallbackQuery(Cons_inputMessageCallbackQuery(id: _1!, queryId: _2!))
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
                return Api.InputMessage.inputMessageID(Cons_inputMessageID(id: _1!))
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
                return Api.InputMessage.inputMessageReplyTo(Cons_inputMessageReplyTo(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputMessageReadMetric: TypeConstructorDescription {
        public class Cons_inputMessageReadMetric: TypeConstructorDescription {
            public var msgId: Int32
            public var viewId: Int64
            public var timeInViewMs: Int32
            public var activeTimeInViewMs: Int32
            public var heightToViewportRatioPermille: Int32
            public var seenRangeRatioPermille: Int32
            public init(msgId: Int32, viewId: Int64, timeInViewMs: Int32, activeTimeInViewMs: Int32, heightToViewportRatioPermille: Int32, seenRangeRatioPermille: Int32) {
                self.msgId = msgId
                self.viewId = viewId
                self.timeInViewMs = timeInViewMs
                self.activeTimeInViewMs = activeTimeInViewMs
                self.heightToViewportRatioPermille = heightToViewportRatioPermille
                self.seenRangeRatioPermille = seenRangeRatioPermille
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMessageReadMetric", [("msgId", ConstructorParameterDescription(self.msgId)), ("viewId", ConstructorParameterDescription(self.viewId)), ("timeInViewMs", ConstructorParameterDescription(self.timeInViewMs)), ("activeTimeInViewMs", ConstructorParameterDescription(self.activeTimeInViewMs)), ("heightToViewportRatioPermille", ConstructorParameterDescription(self.heightToViewportRatioPermille)), ("seenRangeRatioPermille", ConstructorParameterDescription(self.seenRangeRatioPermille))])
            }
        }
        case inputMessageReadMetric(Cons_inputMessageReadMetric)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMessageReadMetric(let _data):
                if boxed {
                    buffer.appendInt32(1076577429)
                }
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.viewId, buffer: buffer, boxed: false)
                serializeInt32(_data.timeInViewMs, buffer: buffer, boxed: false)
                serializeInt32(_data.activeTimeInViewMs, buffer: buffer, boxed: false)
                serializeInt32(_data.heightToViewportRatioPermille, buffer: buffer, boxed: false)
                serializeInt32(_data.seenRangeRatioPermille, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMessageReadMetric(let _data):
                return ("inputMessageReadMetric", [("msgId", ConstructorParameterDescription(_data.msgId)), ("viewId", ConstructorParameterDescription(_data.viewId)), ("timeInViewMs", ConstructorParameterDescription(_data.timeInViewMs)), ("activeTimeInViewMs", ConstructorParameterDescription(_data.activeTimeInViewMs)), ("heightToViewportRatioPermille", ConstructorParameterDescription(_data.heightToViewportRatioPermille)), ("seenRangeRatioPermille", ConstructorParameterDescription(_data.seenRangeRatioPermille))])
            }
        }

        public static func parse_inputMessageReadMetric(_ reader: BufferReader) -> InputMessageReadMetric? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputMessageReadMetric.inputMessageReadMetric(Cons_inputMessageReadMetric(msgId: _1!, viewId: _2!, timeInViewMs: _3!, activeTimeInViewMs: _4!, heightToViewportRatioPermille: _5!, seenRangeRatioPermille: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputNotifyPeer: TypeConstructorDescription {
        public class Cons_inputNotifyCommunity: TypeConstructorDescription {
            public var community: Api.InputChannel
            public init(community: Api.InputChannel) {
                self.community = community
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputNotifyCommunity", [("community", ConstructorParameterDescription(self.community))])
            }
        }
        public class Cons_inputNotifyForumTopic: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var topMsgId: Int32
            public init(peer: Api.InputPeer, topMsgId: Int32) {
                self.peer = peer
                self.topMsgId = topMsgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputNotifyForumTopic", [("peer", ConstructorParameterDescription(self.peer)), ("topMsgId", ConstructorParameterDescription(self.topMsgId))])
            }
        }
        public class Cons_inputNotifyPeer: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputNotifyPeer", [("peer", ConstructorParameterDescription(self.peer))])
            }
        }
        case inputNotifyBroadcasts
        case inputNotifyChats
        case inputNotifyCommunity(Cons_inputNotifyCommunity)
        case inputNotifyForumTopic(Cons_inputNotifyForumTopic)
        case inputNotifyPeer(Cons_inputNotifyPeer)
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
            case .inputNotifyCommunity(let _data):
                if boxed {
                    buffer.appendInt32(666573532)
                }
                _data.community.serialize(buffer, true)
                break
            case .inputNotifyForumTopic(let _data):
                if boxed {
                    buffer.appendInt32(1548122514)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMsgId, buffer: buffer, boxed: false)
                break
            case .inputNotifyPeer(let _data):
                if boxed {
                    buffer.appendInt32(-1195615476)
                }
                _data.peer.serialize(buffer, true)
                break
            case .inputNotifyUsers:
                if boxed {
                    buffer.appendInt32(423314455)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputNotifyBroadcasts:
                return ("inputNotifyBroadcasts", [])
            case .inputNotifyChats:
                return ("inputNotifyChats", [])
            case .inputNotifyCommunity(let _data):
                return ("inputNotifyCommunity", [("community", ConstructorParameterDescription(_data.community))])
            case .inputNotifyForumTopic(let _data):
                return ("inputNotifyForumTopic", [("peer", ConstructorParameterDescription(_data.peer)), ("topMsgId", ConstructorParameterDescription(_data.topMsgId))])
            case .inputNotifyPeer(let _data):
                return ("inputNotifyPeer", [("peer", ConstructorParameterDescription(_data.peer))])
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
        public static func parse_inputNotifyCommunity(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputChannel?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputChannel
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputNotifyPeer.inputNotifyCommunity(Cons_inputNotifyCommunity(community: _1!))
            }
            else {
                return nil
            }
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
                return Api.InputNotifyPeer.inputNotifyForumTopic(Cons_inputNotifyForumTopic(peer: _1!, topMsgId: _2!))
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
                return Api.InputNotifyPeer.inputNotifyPeer(Cons_inputNotifyPeer(peer: _1!))
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
    enum InputPasskeyCredential: TypeConstructorDescription {
        public class Cons_inputPasskeyCredentialPublicKey: TypeConstructorDescription {
            public var id: String
            public var rawId: String
            public var response: Api.InputPasskeyResponse
            public init(id: String, rawId: String, response: Api.InputPasskeyResponse) {
                self.id = id
                self.rawId = rawId
                self.response = response
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPasskeyCredentialPublicKey", [("id", ConstructorParameterDescription(self.id)), ("rawId", ConstructorParameterDescription(self.rawId)), ("response", ConstructorParameterDescription(self.response))])
            }
        }
        case inputPasskeyCredentialPublicKey(Cons_inputPasskeyCredentialPublicKey)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPasskeyCredentialPublicKey(let _data):
                if boxed {
                    buffer.appendInt32(1009235855)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.rawId, buffer: buffer, boxed: false)
                _data.response.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPasskeyCredentialPublicKey(let _data):
                return ("inputPasskeyCredentialPublicKey", [("id", ConstructorParameterDescription(_data.id)), ("rawId", ConstructorParameterDescription(_data.rawId)), ("response", ConstructorParameterDescription(_data.response))])
            }
        }

        public static func parse_inputPasskeyCredentialPublicKey(_ reader: BufferReader) -> InputPasskeyCredential? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputPasskeyResponse?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPasskeyResponse
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputPasskeyCredential.inputPasskeyCredentialPublicKey(Cons_inputPasskeyCredentialPublicKey(id: _1!, rawId: _2!, response: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputPasskeyResponse: TypeConstructorDescription {
        public class Cons_inputPasskeyResponseLogin: TypeConstructorDescription {
            public var clientData: Api.DataJSON
            public var authenticatorData: Buffer
            public var signature: Buffer
            public var userHandle: String
            public init(clientData: Api.DataJSON, authenticatorData: Buffer, signature: Buffer, userHandle: String) {
                self.clientData = clientData
                self.authenticatorData = authenticatorData
                self.signature = signature
                self.userHandle = userHandle
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPasskeyResponseLogin", [("clientData", ConstructorParameterDescription(self.clientData)), ("authenticatorData", ConstructorParameterDescription(self.authenticatorData)), ("signature", ConstructorParameterDescription(self.signature)), ("userHandle", ConstructorParameterDescription(self.userHandle))])
            }
        }
        public class Cons_inputPasskeyResponseRegister: TypeConstructorDescription {
            public var clientData: Api.DataJSON
            public var attestationData: Buffer
            public init(clientData: Api.DataJSON, attestationData: Buffer) {
                self.clientData = clientData
                self.attestationData = attestationData
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPasskeyResponseRegister", [("clientData", ConstructorParameterDescription(self.clientData)), ("attestationData", ConstructorParameterDescription(self.attestationData))])
            }
        }
        case inputPasskeyResponseLogin(Cons_inputPasskeyResponseLogin)
        case inputPasskeyResponseRegister(Cons_inputPasskeyResponseRegister)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPasskeyResponseLogin(let _data):
                if boxed {
                    buffer.appendInt32(-1021329078)
                }
                _data.clientData.serialize(buffer, true)
                serializeBytes(_data.authenticatorData, buffer: buffer, boxed: false)
                serializeBytes(_data.signature, buffer: buffer, boxed: false)
                serializeString(_data.userHandle, buffer: buffer, boxed: false)
                break
            case .inputPasskeyResponseRegister(let _data):
                if boxed {
                    buffer.appendInt32(1046713180)
                }
                _data.clientData.serialize(buffer, true)
                serializeBytes(_data.attestationData, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPasskeyResponseLogin(let _data):
                return ("inputPasskeyResponseLogin", [("clientData", ConstructorParameterDescription(_data.clientData)), ("authenticatorData", ConstructorParameterDescription(_data.authenticatorData)), ("signature", ConstructorParameterDescription(_data.signature)), ("userHandle", ConstructorParameterDescription(_data.userHandle))])
            case .inputPasskeyResponseRegister(let _data):
                return ("inputPasskeyResponseRegister", [("clientData", ConstructorParameterDescription(_data.clientData)), ("attestationData", ConstructorParameterDescription(_data.attestationData))])
            }
        }

        public static func parse_inputPasskeyResponseLogin(_ reader: BufferReader) -> InputPasskeyResponse? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputPasskeyResponse.inputPasskeyResponseLogin(Cons_inputPasskeyResponseLogin(clientData: _1!, authenticatorData: _2!, signature: _3!, userHandle: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPasskeyResponseRegister(_ reader: BufferReader) -> InputPasskeyResponse? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPasskeyResponse.inputPasskeyResponseRegister(Cons_inputPasskeyResponseRegister(clientData: _1!, attestationData: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputPaymentCredentials: TypeConstructorDescription {
        public class Cons_inputPaymentCredentials: TypeConstructorDescription {
            public var flags: Int32
            public var data: Api.DataJSON
            public init(flags: Int32, data: Api.DataJSON) {
                self.flags = flags
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPaymentCredentials", [("flags", ConstructorParameterDescription(self.flags)), ("data", ConstructorParameterDescription(self.data))])
            }
        }
        public class Cons_inputPaymentCredentialsApplePay: TypeConstructorDescription {
            public var paymentData: Api.DataJSON
            public init(paymentData: Api.DataJSON) {
                self.paymentData = paymentData
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPaymentCredentialsApplePay", [("paymentData", ConstructorParameterDescription(self.paymentData))])
            }
        }
        public class Cons_inputPaymentCredentialsGooglePay: TypeConstructorDescription {
            public var paymentToken: Api.DataJSON
            public init(paymentToken: Api.DataJSON) {
                self.paymentToken = paymentToken
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPaymentCredentialsGooglePay", [("paymentToken", ConstructorParameterDescription(self.paymentToken))])
            }
        }
        public class Cons_inputPaymentCredentialsSaved: TypeConstructorDescription {
            public var id: String
            public var tmpPassword: Buffer
            public init(id: String, tmpPassword: Buffer) {
                self.id = id
                self.tmpPassword = tmpPassword
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPaymentCredentialsSaved", [("id", ConstructorParameterDescription(self.id)), ("tmpPassword", ConstructorParameterDescription(self.tmpPassword))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPaymentCredentials(let _data):
                return ("inputPaymentCredentials", [("flags", ConstructorParameterDescription(_data.flags)), ("data", ConstructorParameterDescription(_data.data))])
            case .inputPaymentCredentialsApplePay(let _data):
                return ("inputPaymentCredentialsApplePay", [("paymentData", ConstructorParameterDescription(_data.paymentData))])
            case .inputPaymentCredentialsGooglePay(let _data):
                return ("inputPaymentCredentialsGooglePay", [("paymentToken", ConstructorParameterDescription(_data.paymentToken))])
            case .inputPaymentCredentialsSaved(let _data):
                return ("inputPaymentCredentialsSaved", [("id", ConstructorParameterDescription(_data.id)), ("tmpPassword", ConstructorParameterDescription(_data.tmpPassword))])
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
        public class Cons_inputPeerChannel: TypeConstructorDescription {
            public var channelId: Int64
            public var accessHash: Int64
            public init(channelId: Int64, accessHash: Int64) {
                self.channelId = channelId
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerChannel", [("channelId", ConstructorParameterDescription(self.channelId)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputPeerChannelFromMessage: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var channelId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, channelId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.channelId = channelId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerChannelFromMessage", [("peer", ConstructorParameterDescription(self.peer)), ("msgId", ConstructorParameterDescription(self.msgId)), ("channelId", ConstructorParameterDescription(self.channelId))])
            }
        }
        public class Cons_inputPeerChat: TypeConstructorDescription {
            public var chatId: Int64
            public init(chatId: Int64) {
                self.chatId = chatId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerChat", [("chatId", ConstructorParameterDescription(self.chatId))])
            }
        }
        public class Cons_inputPeerUser: TypeConstructorDescription {
            public var userId: Int64
            public var accessHash: Int64
            public init(userId: Int64, accessHash: Int64) {
                self.userId = userId
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerUser", [("userId", ConstructorParameterDescription(self.userId)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputPeerUserFromMessage: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var userId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, userId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerUserFromMessage", [("peer", ConstructorParameterDescription(self.peer)), ("msgId", ConstructorParameterDescription(self.msgId)), ("userId", ConstructorParameterDescription(self.userId))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPeerChannel(let _data):
                return ("inputPeerChannel", [("channelId", ConstructorParameterDescription(_data.channelId)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputPeerChannelFromMessage(let _data):
                return ("inputPeerChannelFromMessage", [("peer", ConstructorParameterDescription(_data.peer)), ("msgId", ConstructorParameterDescription(_data.msgId)), ("channelId", ConstructorParameterDescription(_data.channelId))])
            case .inputPeerChat(let _data):
                return ("inputPeerChat", [("chatId", ConstructorParameterDescription(_data.chatId))])
            case .inputPeerEmpty:
                return ("inputPeerEmpty", [])
            case .inputPeerSelf:
                return ("inputPeerSelf", [])
            case .inputPeerUser(let _data):
                return ("inputPeerUser", [("userId", ConstructorParameterDescription(_data.userId)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputPeerUserFromMessage(let _data):
                return ("inputPeerUserFromMessage", [("peer", ConstructorParameterDescription(_data.peer)), ("msgId", ConstructorParameterDescription(_data.msgId)), ("userId", ConstructorParameterDescription(_data.userId))])
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
        public class Cons_inputPeerNotifySettings: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerNotifySettings", [("flags", ConstructorParameterDescription(self.flags)), ("showPreviews", ConstructorParameterDescription(self.showPreviews)), ("silent", ConstructorParameterDescription(self.silent)), ("muteUntil", ConstructorParameterDescription(self.muteUntil)), ("sound", ConstructorParameterDescription(self.sound)), ("storiesMuted", ConstructorParameterDescription(self.storiesMuted)), ("storiesHideSender", ConstructorParameterDescription(self.storiesHideSender)), ("storiesSound", ConstructorParameterDescription(self.storiesSound))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPeerNotifySettings(let _data):
                return ("inputPeerNotifySettings", [("flags", ConstructorParameterDescription(_data.flags)), ("showPreviews", ConstructorParameterDescription(_data.showPreviews)), ("silent", ConstructorParameterDescription(_data.silent)), ("muteUntil", ConstructorParameterDescription(_data.muteUntil)), ("sound", ConstructorParameterDescription(_data.sound)), ("storiesMuted", ConstructorParameterDescription(_data.storiesMuted)), ("storiesHideSender", ConstructorParameterDescription(_data.storiesHideSender)), ("storiesSound", ConstructorParameterDescription(_data.storiesSound))])
            }
        }

        public static func parse_inputPeerNotifySettings(_ reader: BufferReader) -> InputPeerNotifySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _3: Api.Bool?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _4: Int32?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Api.NotificationSound?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            var _6: Api.Bool?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _7: Api.Bool?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _8: Api.NotificationSound?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.NotificationSound
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _8 != nil
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
        public class Cons_inputPhoneCall: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPhoneCall", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPhoneCall(let _data):
                return ("inputPhoneCall", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
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
        public class Cons_inputPhoto: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public init(id: Int64, accessHash: Int64, fileReference: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPhoto", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPhoto(let _data):
                return ("inputPhoto", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
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
