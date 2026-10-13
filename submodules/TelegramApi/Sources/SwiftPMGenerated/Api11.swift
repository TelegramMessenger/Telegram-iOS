import TelegramApiObjC
public extension Api {
    enum InputMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputMessageCallbackQuery {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMessageID {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMessageReplyTo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputMessageCallbackQuery(Cons_inputMessageCallbackQuery)
        case inputMessageID(Cons_inputMessageID)
        case inputMessagePinned
        case inputMessageReplyTo(Cons_inputMessageReplyTo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputMessageCallbackQuery(Cons_inputMessageCallbackQuery(tlObject: object))
            case 1:
                self = .inputMessageID(Cons_inputMessageID(tlObject: object))
            case 2:
                self = .inputMessagePinned
            case 3:
                self = .inputMessageReplyTo(Cons_inputMessageReplyTo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputMessageCallbackQuery(let _data):
                return _data.tlObject
            case .inputMessageID(let _data):
                return _data.tlObject
            case .inputMessagePinned:
                return TLObjectSingleton(TLApiConstructorAt(861))
            case .inputMessageReplyTo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputMessage] {
            return tlObjectsAt(object, offset).map { Api.InputMessage(tlObject: $0) }
        }

    }
}
public extension Api.InputMessage.Cons_inputMessageCallbackQuery {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var queryId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int32, queryId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1127))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, queryId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMessage.Cons_inputMessageID {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1089))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMessage.Cons_inputMessageReplyTo {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1232))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputMessageReadMetric: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputMessageReadMetric {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputMessageReadMetric(Cons_inputMessageReadMetric)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputMessageReadMetric(Cons_inputMessageReadMetric(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputMessageReadMetric(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputMessageReadMetric] {
            return tlObjectsAt(object, offset).map { Api.InputMessageReadMetric(tlObject: $0) }
        }

    }
}
public extension Api.InputMessageReadMetric.Cons_inputMessageReadMetric {
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var viewId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var timeInViewMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var activeTimeInViewMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var heightToViewportRatioPermille: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var seenRangeRatioPermille: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    init(msgId: Int32, viewId: Int64, timeInViewMs: Int32, activeTimeInViewMs: Int32, heightToViewportRatioPermille: Int32, seenRangeRatioPermille: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(417))
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 48, viewId)
        tlStore(_tlObject, 28, timeInViewMs)
        tlStore(_tlObject, 32, activeTimeInViewMs)
        tlStore(_tlObject, 36, heightToViewportRatioPermille)
        tlStore(_tlObject, 40, seenRangeRatioPermille)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputNotifyPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputNotifyCommunity {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputNotifyForumTopic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputNotifyPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputNotifyBroadcasts
        case inputNotifyChats
        case inputNotifyCommunity(Cons_inputNotifyCommunity)
        case inputNotifyForumTopic(Cons_inputNotifyForumTopic)
        case inputNotifyPeer(Cons_inputNotifyPeer)
        case inputNotifyUsers


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputNotifyBroadcasts
            case 1:
                self = .inputNotifyChats
            case 2:
                self = .inputNotifyCommunity(Cons_inputNotifyCommunity(tlObject: object))
            case 3:
                self = .inputNotifyForumTopic(Cons_inputNotifyForumTopic(tlObject: object))
            case 4:
                self = .inputNotifyPeer(Cons_inputNotifyPeer(tlObject: object))
            case 5:
                self = .inputNotifyUsers
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputNotifyBroadcasts:
                return TLObjectSingleton(TLApiConstructorAt(1158))
            case .inputNotifyChats:
                return TLObjectSingleton(TLApiConstructorAt(480))
            case .inputNotifyCommunity(let _data):
                return _data.tlObject
            case .inputNotifyForumTopic(let _data):
                return _data.tlObject
            case .inputNotifyPeer(let _data):
                return _data.tlObject
            case .inputNotifyUsers:
                return TLObjectSingleton(TLApiConstructorAt(166))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputNotifyPeer] {
            return tlObjectsAt(object, offset).map { Api.InputNotifyPeer(tlObject: $0) }
        }

    }
}
public extension Api.InputNotifyPeer.Cons_inputNotifyCommunity {
    @_alwaysEmitIntoClient var community: Api.InputChannel {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputChannel(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(community: Api.InputChannel) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(259))
        tlStoreReference(_tlObject, 24, community.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputNotifyPeer.Cons_inputNotifyForumTopic {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var topMsgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.InputPeer, topMsgId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(594))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, topMsgId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputNotifyPeer.Cons_inputNotifyPeer {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.InputPeer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1215))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputPasskeyCredential: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPasskeyCredentialPublicKey {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPasskeyCredentialPublicKey(Cons_inputPasskeyCredentialPublicKey)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPasskeyCredentialPublicKey(Cons_inputPasskeyCredentialPublicKey(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPasskeyCredentialPublicKey(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPasskeyCredential] {
            return tlObjectsAt(object, offset).map { Api.InputPasskeyCredential(tlObject: $0) }
        }

    }
}
public extension Api.InputPasskeyCredential.Cons_inputPasskeyCredentialPublicKey {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var rawId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var response: Api.InputPasskeyResponse {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPasskeyResponse(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(id: String, rawId: String, response: Api.InputPasskeyResponse) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(382))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, rawId as NSString)
        tlStoreReference(_tlObject, 40, response.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputPasskeyResponse: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPasskeyResponseLogin {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPasskeyResponseRegister {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPasskeyResponseLogin(Cons_inputPasskeyResponseLogin)
        case inputPasskeyResponseRegister(Cons_inputPasskeyResponseRegister)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPasskeyResponseLogin(Cons_inputPasskeyResponseLogin(tlObject: object))
            case 1:
                self = .inputPasskeyResponseRegister(Cons_inputPasskeyResponseRegister(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPasskeyResponseLogin(let _data):
                return _data.tlObject
            case .inputPasskeyResponseRegister(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPasskeyResponse] {
            return tlObjectsAt(object, offset).map { Api.InputPasskeyResponse(tlObject: $0) }
        }

    }
}
public extension Api.InputPasskeyResponse.Cons_inputPasskeyResponseLogin {
    @_alwaysEmitIntoClient var clientData: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var authenticatorData: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var signature: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var userHandle: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(clientData: Api.DataJSON, authenticatorData: Buffer, signature: Buffer, userHandle: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1300))
        tlStoreReference(_tlObject, 24, clientData.tlObject)
        tlStoreReference(_tlObject, 32, authenticatorData.makeData() as NSData)
        tlStoreReference(_tlObject, 40, signature.makeData() as NSData)
        tlStoreReference(_tlObject, 48, userHandle as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPasskeyResponse.Cons_inputPasskeyResponseRegister {
    @_alwaysEmitIntoClient var clientData: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var attestationData: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(clientData: Api.DataJSON, attestationData: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(404))
        tlStoreReference(_tlObject, 24, clientData.tlObject)
        tlStoreReference(_tlObject, 32, attestationData.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputPaymentCredentials: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPaymentCredentials {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPaymentCredentialsApplePay {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPaymentCredentialsGooglePay {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPaymentCredentialsSaved {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPaymentCredentials(Cons_inputPaymentCredentials)
        case inputPaymentCredentialsApplePay(Cons_inputPaymentCredentialsApplePay)
        case inputPaymentCredentialsGooglePay(Cons_inputPaymentCredentialsGooglePay)
        case inputPaymentCredentialsSaved(Cons_inputPaymentCredentialsSaved)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPaymentCredentials(Cons_inputPaymentCredentials(tlObject: object))
            case 1:
                self = .inputPaymentCredentialsApplePay(Cons_inputPaymentCredentialsApplePay(tlObject: object))
            case 2:
                self = .inputPaymentCredentialsGooglePay(Cons_inputPaymentCredentialsGooglePay(tlObject: object))
            case 3:
                self = .inputPaymentCredentialsSaved(Cons_inputPaymentCredentialsSaved(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPaymentCredentials(let _data):
                return _data.tlObject
            case .inputPaymentCredentialsApplePay(let _data):
                return _data.tlObject
            case .inputPaymentCredentialsGooglePay(let _data):
                return _data.tlObject
            case .inputPaymentCredentialsSaved(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPaymentCredentials] {
            return tlObjectsAt(object, offset).map { Api.InputPaymentCredentials(tlObject: $0) }
        }

    }
}
public extension Api.InputPaymentCredentials.Cons_inputPaymentCredentials {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var data: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, data: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(332))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, data.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPaymentCredentials.Cons_inputPaymentCredentialsApplePay {
    @_alwaysEmitIntoClient var paymentData: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(paymentData: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(71))
        tlStoreReference(_tlObject, 24, paymentData.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPaymentCredentials.Cons_inputPaymentCredentialsGooglePay {
    @_alwaysEmitIntoClient var paymentToken: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(paymentToken: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(889))
        tlStoreReference(_tlObject, 24, paymentToken.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPaymentCredentials.Cons_inputPaymentCredentialsSaved {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var tmpPassword: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(id: String, tmpPassword: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1286))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, tmpPassword.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPeerChannel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPeerChannelFromMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPeerChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPeerUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPeerUserFromMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPeerChannel(Cons_inputPeerChannel)
        case inputPeerChannelFromMessage(Cons_inputPeerChannelFromMessage)
        case inputPeerChat(Cons_inputPeerChat)
        case inputPeerEmpty
        case inputPeerSelf
        case inputPeerUser(Cons_inputPeerUser)
        case inputPeerUserFromMessage(Cons_inputPeerUserFromMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPeerChannel(Cons_inputPeerChannel(tlObject: object))
            case 1:
                self = .inputPeerChannelFromMessage(Cons_inputPeerChannelFromMessage(tlObject: object))
            case 2:
                self = .inputPeerChat(Cons_inputPeerChat(tlObject: object))
            case 3:
                self = .inputPeerEmpty
            case 4:
                self = .inputPeerSelf
            case 5:
                self = .inputPeerUser(Cons_inputPeerUser(tlObject: object))
            case 6:
                self = .inputPeerUserFromMessage(Cons_inputPeerUserFromMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPeerChannel(let _data):
                return _data.tlObject
            case .inputPeerChannelFromMessage(let _data):
                return _data.tlObject
            case .inputPeerChat(let _data):
                return _data.tlObject
            case .inputPeerEmpty:
                return TLObjectSingleton(TLApiConstructorAt(819))
            case .inputPeerSelf:
                return TLObjectSingleton(TLApiConstructorAt(812))
            case .inputPeerUser(let _data):
                return _data.tlObject
            case .inputPeerUserFromMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPeer] {
            return tlObjectsAt(object, offset).map { Api.InputPeer(tlObject: $0) }
        }

    }
}
public extension Api.InputPeer.Cons_inputPeerChannel {
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(channelId: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(260))
        tlStore(_tlObject, 24, channelId)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPeer.Cons_inputPeerChannelFromMessage {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(peer: Api.InputPeer, msgId: Int32, channelId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1247))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 40, channelId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPeer.Cons_inputPeerChat {
    @_alwaysEmitIntoClient var chatId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(chatId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(342))
        tlStore(_tlObject, 24, chatId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPeer.Cons_inputPeerUser {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(userId: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1459))
        tlStore(_tlObject, 24, userId)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPeer.Cons_inputPeerUserFromMessage {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(peer: Api.InputPeer, msgId: Int32, userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1098))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 40, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputPeerNotifySettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPeerNotifySettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPeerNotifySettings(Cons_inputPeerNotifySettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPeerNotifySettings(Cons_inputPeerNotifySettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPeerNotifySettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPeerNotifySettings] {
            return tlObjectsAt(object, offset).map { Api.InputPeerNotifySettings(tlObject: $0) }
        }

    }
}
public extension Api.InputPeerNotifySettings.Cons_inputPeerNotifySettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var showPreviews: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var silent: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var muteUntil: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var sound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var storiesMuted: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var storiesHideSender: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var storiesSound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesSound: Api.NotificationSound?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1347))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, showPreviews?.tlObject)
        tlStoreReference(_tlObject, 40, silent?.tlObject)
        if let _tlValue = muteUntil { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, sound?.tlObject)
        tlStoreReference(_tlObject, 56, storiesMuted?.tlObject)
        tlStoreReference(_tlObject, 64, storiesHideSender?.tlObject)
        tlStoreReference(_tlObject, 72, storiesSound?.tlObject)
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputPhoneCall: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPhoneCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPhoneCall(Cons_inputPhoneCall)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPhoneCall(Cons_inputPhoneCall(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPhoneCall(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPhoneCall] {
            return tlObjectsAt(object, offset).map { Api.InputPhoneCall(tlObject: $0) }
        }

    }
}
public extension Api.InputPhoneCall.Cons_inputPhoneCall {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(204))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputPhoto: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPhoto(Cons_inputPhoto)
        case inputPhotoEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPhoto(Cons_inputPhoto(tlObject: object))
            case 1:
                self = .inputPhotoEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPhoto(let _data):
                return _data.tlObject
            case .inputPhotoEmpty:
                return TLObjectSingleton(TLApiConstructorAt(191))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPhoto] {
            return tlObjectsAt(object, offset).map { Api.InputPhoto(tlObject: $0) }
        }

    }
}
public extension Api.InputPhoto.Cons_inputPhoto {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(id: Int64, accessHash: Int64, fileReference: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(376))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        tlStoreReference(_tlObject, 40, fileReference.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputPrivacyKey: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
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


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPrivacyKeyAbout
            case 1:
                self = .inputPrivacyKeyAddedByPhone
            case 2:
                self = .inputPrivacyKeyBirthday
            case 3:
                self = .inputPrivacyKeyChatInvite
            case 4:
                self = .inputPrivacyKeyForwards
            case 5:
                self = .inputPrivacyKeyNoPaidMessages
            case 6:
                self = .inputPrivacyKeyPhoneCall
            case 7:
                self = .inputPrivacyKeyPhoneNumber
            case 8:
                self = .inputPrivacyKeyPhoneP2P
            case 9:
                self = .inputPrivacyKeyProfilePhoto
            case 10:
                self = .inputPrivacyKeySavedMusic
            case 11:
                self = .inputPrivacyKeyStarGiftsAutoSave
            case 12:
                self = .inputPrivacyKeyStatusTimestamp
            case 13:
                self = .inputPrivacyKeyVoiceMessages
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPrivacyKeyAbout:
                return TLObjectSingleton(TLApiConstructorAt(359))
            case .inputPrivacyKeyAddedByPhone:
                return TLObjectSingleton(TLApiConstructorAt(1384))
            case .inputPrivacyKeyBirthday:
                return TLObjectSingleton(TLApiConstructorAt(1411))
            case .inputPrivacyKeyChatInvite:
                return TLObjectSingleton(TLApiConstructorAt(1262))
            case .inputPrivacyKeyForwards:
                return TLObjectSingleton(TLApiConstructorAt(1080))
            case .inputPrivacyKeyNoPaidMessages:
                return TLObjectSingleton(TLApiConstructorAt(1254))
            case .inputPrivacyKeyPhoneCall:
                return TLObjectSingleton(TLApiConstructorAt(1670))
            case .inputPrivacyKeyPhoneNumber:
                return TLObjectSingleton(TLApiConstructorAt(27))
            case .inputPrivacyKeyPhoneP2P:
                return TLObjectSingleton(TLApiConstructorAt(1441))
            case .inputPrivacyKeyProfilePhoto:
                return TLObjectSingleton(TLApiConstructorAt(564))
            case .inputPrivacyKeySavedMusic:
                return TLObjectSingleton(TLApiConstructorAt(504))
            case .inputPrivacyKeyStarGiftsAutoSave:
                return TLObjectSingleton(TLApiConstructorAt(1484))
            case .inputPrivacyKeyStatusTimestamp:
                return TLObjectSingleton(TLApiConstructorAt(513))
            case .inputPrivacyKeyVoiceMessages:
                return TLObjectSingleton(TLApiConstructorAt(1142))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPrivacyKey] {
            return tlObjectsAt(object, offset).map { Api.InputPrivacyKey(tlObject: $0) }
        }

    }
}
