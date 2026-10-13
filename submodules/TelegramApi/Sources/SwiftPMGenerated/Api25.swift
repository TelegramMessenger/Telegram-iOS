import TelegramApiObjC
public extension Api {
    enum SecureValue: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_secureValue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case secureValue(Cons_secureValue)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secureValue(Cons_secureValue(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secureValue(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecureValue] {
            return tlObjectsAt(object, offset).map { Api.SecureValue(tlObject: $0) }
        }

    }
}
public extension Api.SecureValue.Cons_secureValue {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var data: Api.SecureData? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.SecureData(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var frontSide: Api.SecureFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.SecureFile(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var reverseSide: Api.SecureFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.SecureFile(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var selfie: Api.SecureFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.SecureFile(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var translation: [Api.SecureFile]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.SecureFile.tlArray(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var files: [Api.SecureFile]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.SecureFile.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var plainData: Api.SecurePlainData? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.SecurePlainData(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var hash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 96) } }
    }
    init(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(160))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, type.tlObject)
        tlStoreReference(_tlObject, 40, data?.tlObject)
        tlStoreReference(_tlObject, 48, frontSide?.tlObject)
        tlStoreReference(_tlObject, 56, reverseSide?.tlObject)
        tlStoreReference(_tlObject, 64, selfie?.tlObject)
        tlStoreReference(_tlObject, 72, translation.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, files.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 88, plainData?.tlObject)
        tlStoreReference(_tlObject, 96, hash.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecureValueError: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_secureValueError {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorData {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorFiles {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorFrontSide {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorReverseSide {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorSelfie {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorTranslationFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_secureValueErrorTranslationFiles {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case secureValueError(Cons_secureValueError)
        case secureValueErrorData(Cons_secureValueErrorData)
        case secureValueErrorFile(Cons_secureValueErrorFile)
        case secureValueErrorFiles(Cons_secureValueErrorFiles)
        case secureValueErrorFrontSide(Cons_secureValueErrorFrontSide)
        case secureValueErrorReverseSide(Cons_secureValueErrorReverseSide)
        case secureValueErrorSelfie(Cons_secureValueErrorSelfie)
        case secureValueErrorTranslationFile(Cons_secureValueErrorTranslationFile)
        case secureValueErrorTranslationFiles(Cons_secureValueErrorTranslationFiles)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secureValueError(Cons_secureValueError(tlObject: object))
            case 1:
                self = .secureValueErrorData(Cons_secureValueErrorData(tlObject: object))
            case 2:
                self = .secureValueErrorFile(Cons_secureValueErrorFile(tlObject: object))
            case 3:
                self = .secureValueErrorFiles(Cons_secureValueErrorFiles(tlObject: object))
            case 4:
                self = .secureValueErrorFrontSide(Cons_secureValueErrorFrontSide(tlObject: object))
            case 5:
                self = .secureValueErrorReverseSide(Cons_secureValueErrorReverseSide(tlObject: object))
            case 6:
                self = .secureValueErrorSelfie(Cons_secureValueErrorSelfie(tlObject: object))
            case 7:
                self = .secureValueErrorTranslationFile(Cons_secureValueErrorTranslationFile(tlObject: object))
            case 8:
                self = .secureValueErrorTranslationFiles(Cons_secureValueErrorTranslationFiles(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secureValueError(let _data):
                return _data.tlObject
            case .secureValueErrorData(let _data):
                return _data.tlObject
            case .secureValueErrorFile(let _data):
                return _data.tlObject
            case .secureValueErrorFiles(let _data):
                return _data.tlObject
            case .secureValueErrorFrontSide(let _data):
                return _data.tlObject
            case .secureValueErrorReverseSide(let _data):
                return _data.tlObject
            case .secureValueErrorSelfie(let _data):
                return _data.tlObject
            case .secureValueErrorTranslationFile(let _data):
                return _data.tlObject
            case .secureValueErrorTranslationFiles(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecureValueError] {
            return tlObjectsAt(object, offset).map { Api.SecureValueError(tlObject: $0) }
        }

    }
}
public extension Api.SecureValueError.Cons_secureValueError {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var hash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, hash: Buffer, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(863))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, hash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorData {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var dataHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var field: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1533))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, dataHash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, field as NSString)
        tlStoreReference(_tlObject, 48, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorFile {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var fileHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(787))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, fileHash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorFiles {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var fileHash: [Buffer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBuffersAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(657))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, fileHash.map { item in item.makeData() } as NSArray)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorFrontSide {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var fileHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(6))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, fileHash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorReverseSide {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var fileHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(862))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, fileHash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorSelfie {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var fileHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1508))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, fileHash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorTranslationFile {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var fileHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1055))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, fileHash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecureValueError.Cons_secureValueErrorTranslationFiles {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var fileHash: [Buffer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBuffersAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(335))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, fileHash.map { item in item.makeData() } as NSArray)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecureValueHash: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_secureValueHash {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case secureValueHash(Cons_secureValueHash)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secureValueHash(Cons_secureValueHash(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secureValueHash(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecureValueHash] {
            return tlObjectsAt(object, offset).map { Api.SecureValueHash(tlObject: $0) }
        }

    }
}
public extension Api.SecureValueHash.Cons_secureValueHash {
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var hash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(type: Api.SecureValueType, hash: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1569))
        tlStoreReference(_tlObject, 24, type.tlObject)
        tlStoreReference(_tlObject, 32, hash.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecureValueType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case secureValueTypeAddress
        case secureValueTypeBankStatement
        case secureValueTypeDriverLicense
        case secureValueTypeEmail
        case secureValueTypeIdentityCard
        case secureValueTypeInternalPassport
        case secureValueTypePassport
        case secureValueTypePassportRegistration
        case secureValueTypePersonalDetails
        case secureValueTypePhone
        case secureValueTypeRentalAgreement
        case secureValueTypeTemporaryRegistration
        case secureValueTypeUtilityBill


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secureValueTypeAddress
            case 1:
                self = .secureValueTypeBankStatement
            case 2:
                self = .secureValueTypeDriverLicense
            case 3:
                self = .secureValueTypeEmail
            case 4:
                self = .secureValueTypeIdentityCard
            case 5:
                self = .secureValueTypeInternalPassport
            case 6:
                self = .secureValueTypePassport
            case 7:
                self = .secureValueTypePassportRegistration
            case 8:
                self = .secureValueTypePersonalDetails
            case 9:
                self = .secureValueTypePhone
            case 10:
                self = .secureValueTypeRentalAgreement
            case 11:
                self = .secureValueTypeTemporaryRegistration
            case 12:
                self = .secureValueTypeUtilityBill
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secureValueTypeAddress:
                return TLObjectSingleton(TLApiConstructorAt(1360))
            case .secureValueTypeBankStatement:
                return TLObjectSingleton(TLApiConstructorAt(880))
            case .secureValueTypeDriverLicense:
                return TLObjectSingleton(TLApiConstructorAt(48))
            case .secureValueTypeEmail:
                return TLObjectSingleton(TLApiConstructorAt(912))
            case .secureValueTypeIdentityCard:
                return TLObjectSingleton(TLApiConstructorAt(1054))
            case .secureValueTypeInternalPassport:
                return TLObjectSingleton(TLApiConstructorAt(990))
            case .secureValueTypePassport:
                return TLObjectSingleton(TLApiConstructorAt(392))
            case .secureValueTypePassportRegistration:
                return TLObjectSingleton(TLApiConstructorAt(992))
            case .secureValueTypePersonalDetails:
                return TLObjectSingleton(TLApiConstructorAt(1020))
            case .secureValueTypePhone:
                return TLObjectSingleton(TLApiConstructorAt(1168))
            case .secureValueTypeRentalAgreement:
                return TLObjectSingleton(TLApiConstructorAt(895))
            case .secureValueTypeTemporaryRegistration:
                return TLObjectSingleton(TLApiConstructorAt(1546))
            case .secureValueTypeUtilityBill:
                return TLObjectSingleton(TLApiConstructorAt(1685))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecureValueType] {
            return tlObjectsAt(object, offset).map { Api.SecureValueType(tlObject: $0) }
        }

    }
}
public extension Api {
    enum SendAsPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sendAsPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sendAsPeer(Cons_sendAsPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sendAsPeer(Cons_sendAsPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sendAsPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SendAsPeer] {
            return tlObjectsAt(object, offset).map { Api.SendAsPeer(tlObject: $0) }
        }

    }
}
public extension Api.SendAsPeer.Cons_sendAsPeer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, peer: Api.Peer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1210))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SendMessageAction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputSendMessageRichMessageDraftAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageEmojiInteraction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageEmojiInteractionSeen {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageHistoryImportAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageRichMessageDraftAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageStopDraftAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageTextDraftAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageUploadAudioAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageUploadDocumentAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageUploadPhotoAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageUploadRoundAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sendMessageUploadVideoAction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputSendMessageRichMessageDraftAction(Cons_inputSendMessageRichMessageDraftAction)
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageChooseStickerAction
        case sendMessageEmojiInteraction(Cons_sendMessageEmojiInteraction)
        case sendMessageEmojiInteractionSeen(Cons_sendMessageEmojiInteractionSeen)
        case sendMessageGamePlayAction
        case sendMessageGeoLocationAction
        case sendMessageHistoryImportAction(Cons_sendMessageHistoryImportAction)
        case sendMessageRecordAudioAction
        case sendMessageRecordRoundAction
        case sendMessageRecordVideoAction
        case sendMessageRichMessageDraftAction(Cons_sendMessageRichMessageDraftAction)
        case sendMessageStopDraftAction(Cons_sendMessageStopDraftAction)
        case sendMessageTextDraftAction(Cons_sendMessageTextDraftAction)
        case sendMessageTypingAction
        case sendMessageUploadAudioAction(Cons_sendMessageUploadAudioAction)
        case sendMessageUploadDocumentAction(Cons_sendMessageUploadDocumentAction)
        case sendMessageUploadPhotoAction(Cons_sendMessageUploadPhotoAction)
        case sendMessageUploadRoundAction(Cons_sendMessageUploadRoundAction)
        case sendMessageUploadVideoAction(Cons_sendMessageUploadVideoAction)
        case speakingInGroupCallAction


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputSendMessageRichMessageDraftAction(Cons_inputSendMessageRichMessageDraftAction(tlObject: object))
            case 1:
                self = .sendMessageCancelAction
            case 2:
                self = .sendMessageChooseContactAction
            case 3:
                self = .sendMessageChooseStickerAction
            case 4:
                self = .sendMessageEmojiInteraction(Cons_sendMessageEmojiInteraction(tlObject: object))
            case 5:
                self = .sendMessageEmojiInteractionSeen(Cons_sendMessageEmojiInteractionSeen(tlObject: object))
            case 6:
                self = .sendMessageGamePlayAction
            case 7:
                self = .sendMessageGeoLocationAction
            case 8:
                self = .sendMessageHistoryImportAction(Cons_sendMessageHistoryImportAction(tlObject: object))
            case 9:
                self = .sendMessageRecordAudioAction
            case 10:
                self = .sendMessageRecordRoundAction
            case 11:
                self = .sendMessageRecordVideoAction
            case 12:
                self = .sendMessageRichMessageDraftAction(Cons_sendMessageRichMessageDraftAction(tlObject: object))
            case 13:
                self = .sendMessageStopDraftAction(Cons_sendMessageStopDraftAction(tlObject: object))
            case 14:
                self = .sendMessageTextDraftAction(Cons_sendMessageTextDraftAction(tlObject: object))
            case 15:
                self = .sendMessageTypingAction
            case 16:
                self = .sendMessageUploadAudioAction(Cons_sendMessageUploadAudioAction(tlObject: object))
            case 17:
                self = .sendMessageUploadDocumentAction(Cons_sendMessageUploadDocumentAction(tlObject: object))
            case 18:
                self = .sendMessageUploadPhotoAction(Cons_sendMessageUploadPhotoAction(tlObject: object))
            case 19:
                self = .sendMessageUploadRoundAction(Cons_sendMessageUploadRoundAction(tlObject: object))
            case 20:
                self = .sendMessageUploadVideoAction(Cons_sendMessageUploadVideoAction(tlObject: object))
            case 21:
                self = .speakingInGroupCallAction
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputSendMessageRichMessageDraftAction(let _data):
                return _data.tlObject
            case .sendMessageCancelAction:
                return TLObjectSingleton(TLApiConstructorAt(1694))
            case .sendMessageChooseContactAction:
                return TLObjectSingleton(TLApiConstructorAt(627))
            case .sendMessageChooseStickerAction:
                return TLObjectSingleton(TLApiConstructorAt(1149))
            case .sendMessageEmojiInteraction(let _data):
                return _data.tlObject
            case .sendMessageEmojiInteractionSeen(let _data):
                return _data.tlObject
            case .sendMessageGamePlayAction:
                return TLObjectSingleton(TLApiConstructorAt(1458))
            case .sendMessageGeoLocationAction:
                return TLObjectSingleton(TLApiConstructorAt(147))
            case .sendMessageHistoryImportAction(let _data):
                return _data.tlObject
            case .sendMessageRecordAudioAction:
                return TLObjectSingleton(TLApiConstructorAt(1401))
            case .sendMessageRecordRoundAction:
                return TLObjectSingleton(TLApiConstructorAt(877))
            case .sendMessageRecordVideoAction:
                return TLObjectSingleton(TLApiConstructorAt(1058))
            case .sendMessageRichMessageDraftAction(let _data):
                return _data.tlObject
            case .sendMessageStopDraftAction(let _data):
                return _data.tlObject
            case .sendMessageTextDraftAction(let _data):
                return _data.tlObject
            case .sendMessageTypingAction:
                return TLObjectSingleton(TLApiConstructorAt(142))
            case .sendMessageUploadAudioAction(let _data):
                return _data.tlObject
            case .sendMessageUploadDocumentAction(let _data):
                return _data.tlObject
            case .sendMessageUploadPhotoAction(let _data):
                return _data.tlObject
            case .sendMessageUploadRoundAction(let _data):
                return _data.tlObject
            case .sendMessageUploadVideoAction(let _data):
                return _data.tlObject
            case .speakingInGroupCallAction:
                return TLObjectSingleton(TLApiConstructorAt(1427))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SendMessageAction] {
            return tlObjectsAt(object, offset).map { Api.SendMessageAction(tlObject: $0) }
        }

    }
}
public extension Api.SendMessageAction.Cons_inputSendMessageRichMessageDraftAction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var richMessage: Api.InputRichMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputRichMessage(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, randomId: Int64, richMessage: Api.InputRichMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1106))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, randomId)
        tlStoreReference(_tlObject, 40, richMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageEmojiInteraction {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var interaction: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(emoticon: String, msgId: Int32, interaction: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(250))
        tlStoreReference(_tlObject, 32, emoticon as NSString)
        tlStore(_tlObject, 24, msgId)
        tlStoreReference(_tlObject, 40, interaction.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageEmojiInteractionSeen {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(emoticon: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1199))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageHistoryImportAction {
    @_alwaysEmitIntoClient var progress: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(progress: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1446))
        tlStore(_tlObject, 24, progress)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageRichMessageDraftAction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var richMessage: Api.RichMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichMessage(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, randomId: Int64, richMessage: Api.RichMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(534))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, randomId)
        tlStoreReference(_tlObject, 40, richMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageStopDraftAction {
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(randomId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1684))
        tlStore(_tlObject, 24, randomId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageTextDraftAction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, randomId: Int64, text: Api.TextWithEntities) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(344))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, randomId)
        tlStoreReference(_tlObject, 40, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageUploadAudioAction {
    @_alwaysEmitIntoClient var progress: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(progress: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1616))
        tlStore(_tlObject, 24, progress)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageUploadDocumentAction {
    @_alwaysEmitIntoClient var progress: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(progress: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1111))
        tlStore(_tlObject, 24, progress)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageUploadPhotoAction {
    @_alwaysEmitIntoClient var progress: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(progress: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1387))
        tlStore(_tlObject, 24, progress)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageUploadRoundAction {
    @_alwaysEmitIntoClient var progress: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(progress: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(245))
        tlStore(_tlObject, 24, progress)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SendMessageAction.Cons_sendMessageUploadVideoAction {
    @_alwaysEmitIntoClient var progress: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(progress: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1540))
        tlStore(_tlObject, 24, progress)
        self.init(tlObject: _tlObject)
    }
}
