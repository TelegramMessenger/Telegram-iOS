import TelegramApiObjC
public extension Api {
    enum PhoneCallDiscardReason: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_phoneCallDiscardReasonMigrateConferenceCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case phoneCallDiscardReasonBusy
        case phoneCallDiscardReasonDisconnect
        case phoneCallDiscardReasonHangup
        case phoneCallDiscardReasonMigrateConferenceCall(Cons_phoneCallDiscardReasonMigrateConferenceCall)
        case phoneCallDiscardReasonMissed


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .phoneCallDiscardReasonBusy
            case 1:
                self = .phoneCallDiscardReasonDisconnect
            case 2:
                self = .phoneCallDiscardReasonHangup
            case 3:
                self = .phoneCallDiscardReasonMigrateConferenceCall(Cons_phoneCallDiscardReasonMigrateConferenceCall(tlObject: object))
            case 4:
                self = .phoneCallDiscardReasonMissed
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .phoneCallDiscardReasonBusy:
                return TLObjectSingleton(TLApiConstructorAt(1656))
            case .phoneCallDiscardReasonDisconnect:
                return TLObjectSingleton(TLApiConstructorAt(1463))
            case .phoneCallDiscardReasonHangup:
                return TLObjectSingleton(TLApiConstructorAt(569))
            case .phoneCallDiscardReasonMigrateConferenceCall(let _data):
                return _data.tlObject
            case .phoneCallDiscardReasonMissed:
                return TLObjectSingleton(TLApiConstructorAt(847))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PhoneCallDiscardReason] {
            return tlObjectsAt(object, offset).map { Api.PhoneCallDiscardReason(tlObject: $0) }
        }

    }
}
public extension Api.PhoneCallDiscardReason.Cons_phoneCallDiscardReasonMigrateConferenceCall {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1032))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PhoneCallProtocol: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_phoneCallProtocol {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case phoneCallProtocol(Cons_phoneCallProtocol)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .phoneCallProtocol(Cons_phoneCallProtocol(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .phoneCallProtocol(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PhoneCallProtocol] {
            return tlObjectsAt(object, offset).map { Api.PhoneCallProtocol(tlObject: $0) }
        }

    }
}
public extension Api.PhoneCallProtocol.Cons_phoneCallProtocol {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var minLayer: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var maxLayer: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var libraryVersions: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 40) } }
    }
    init(flags: Int32, minLayer: Int32, maxLayer: Int32, libraryVersions: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1670))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, minLayer)
        tlStore(_tlObject, 32, maxLayer)
        tlStoreReference(_tlObject, 40, libraryVersions as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PhoneConnection: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_phoneConnection {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_phoneConnectionWebrtc {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case phoneConnection(Cons_phoneConnection)
        case phoneConnectionWebrtc(Cons_phoneConnectionWebrtc)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .phoneConnection(Cons_phoneConnection(tlObject: object))
            case 1:
                self = .phoneConnectionWebrtc(Cons_phoneConnectionWebrtc(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .phoneConnection(let _data):
                return _data.tlObject
            case .phoneConnectionWebrtc(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PhoneConnection] {
            return tlObjectsAt(object, offset).map { Api.PhoneConnection(tlObject: $0) }
        }

    }
}
public extension Api.PhoneConnection.Cons_phoneConnection {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var ip: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var ipv6: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var port: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerTag: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 56) } }
    }
    init(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, peerTag: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1006))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStoreReference(_tlObject, 40, ip as NSString)
        tlStoreReference(_tlObject, 48, ipv6 as NSString)
        tlStore(_tlObject, 28, port)
        tlStoreReference(_tlObject, 56, peerTag.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhoneConnection.Cons_phoneConnectionWebrtc {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var ip: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var ipv6: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var port: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var username: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var password: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    init(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, username: String, password: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(632))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStoreReference(_tlObject, 40, ip as NSString)
        tlStoreReference(_tlObject, 48, ipv6 as NSString)
        tlStore(_tlObject, 28, port)
        tlStoreReference(_tlObject, 56, username as NSString)
        tlStoreReference(_tlObject, 64, password as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Photo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_photo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_photoEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case photo(Cons_photo)
        case photoEmpty(Cons_photoEmpty)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .photo(Cons_photo(tlObject: object))
            case 1:
                self = .photoEmpty(Cons_photoEmpty(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .photo(let _data):
                return _data.tlObject
            case .photoEmpty(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Photo] {
            return tlObjectsAt(object, offset).map { Api.Photo(tlObject: $0) }
        }

    }
}
public extension Api.Photo.Cons_photo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var sizes: [Api.PhotoSize] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PhotoSize.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var videoSizes: [Api.VideoSize]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.VideoSize.tlArray(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, sizes: [Api.PhotoSize], videoSizes: [Api.VideoSize]?, dcId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1658))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, id)
        tlStore(_tlObject, 48, accessHash)
        tlStoreReference(_tlObject, 56, fileReference.makeData() as NSData)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 64, sizes.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, videoSizes.map { value in value.map { item in item.tlObject } as NSArray })
        tlStore(_tlObject, 32, dcId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Photo.Cons_photoEmpty {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(240))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PhotoSize: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_photoCachedSize {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_photoPathSize {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_photoSize {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_photoSizeEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_photoSizeProgressive {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_photoStrippedSize {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case photoCachedSize(Cons_photoCachedSize)
        case photoPathSize(Cons_photoPathSize)
        case photoSize(Cons_photoSize)
        case photoSizeEmpty(Cons_photoSizeEmpty)
        case photoSizeProgressive(Cons_photoSizeProgressive)
        case photoStrippedSize(Cons_photoStrippedSize)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .photoCachedSize(Cons_photoCachedSize(tlObject: object))
            case 1:
                self = .photoPathSize(Cons_photoPathSize(tlObject: object))
            case 2:
                self = .photoSize(Cons_photoSize(tlObject: object))
            case 3:
                self = .photoSizeEmpty(Cons_photoSizeEmpty(tlObject: object))
            case 4:
                self = .photoSizeProgressive(Cons_photoSizeProgressive(tlObject: object))
            case 5:
                self = .photoStrippedSize(Cons_photoStrippedSize(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .photoCachedSize(let _data):
                return _data.tlObject
            case .photoPathSize(let _data):
                return _data.tlObject
            case .photoSize(let _data):
                return _data.tlObject
            case .photoSizeEmpty(let _data):
                return _data.tlObject
            case .photoSizeProgressive(let _data):
                return _data.tlObject
            case .photoStrippedSize(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PhotoSize] {
            return tlObjectsAt(object, offset).map { Api.PhotoSize(tlObject: $0) }
        }

    }
}
public extension Api.PhotoSize.Cons_photoCachedSize {
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(type: String, w: Int32, h: Int32, bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(15))
        tlStoreReference(_tlObject, 32, type as NSString)
        tlStore(_tlObject, 24, w)
        tlStore(_tlObject, 28, h)
        tlStoreReference(_tlObject, 40, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhotoSize.Cons_photoPathSize {
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(type: String, bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1408))
        tlStoreReference(_tlObject, 24, type as NSString)
        tlStoreReference(_tlObject, 32, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhotoSize.Cons_photoSize {
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var size: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(type: String, w: Int32, h: Int32, size: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(747))
        tlStoreReference(_tlObject, 40, type as NSString)
        tlStore(_tlObject, 24, w)
        tlStore(_tlObject, 28, h)
        tlStore(_tlObject, 32, size)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhotoSize.Cons_photoSizeEmpty {
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(type: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(91))
        tlStoreReference(_tlObject, 24, type as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhotoSize.Cons_photoSizeProgressive {
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var sizes: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 40) } }
    }
    init(type: String, w: Int32, h: Int32, sizes: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1650))
        tlStoreReference(_tlObject, 32, type as NSString)
        tlStore(_tlObject, 24, w)
        tlStore(_tlObject, 28, h)
        tlStoreReference(_tlObject, 40, tlPackInt32(sizes) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhotoSize.Cons_photoStrippedSize {
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(type: String, bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1464))
        tlStoreReference(_tlObject, 24, type as NSString)
        tlStoreReference(_tlObject, 32, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Poll: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_poll {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case poll(Cons_poll)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .poll(Cons_poll(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .poll(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Poll] {
            return tlObjectsAt(object, offset).map { Api.Poll(tlObject: $0) }
        }

    }
}
public extension Api.Poll.Cons_poll {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var question: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var answers: [Api.PollAnswer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PollAnswer.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var closePeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var closeDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var countriesIso2: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringsAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) } }
    }
    init(id: Int64, flags: Int32, question: Api.TextWithEntities, answers: [Api.PollAnswer], closePeriod: Int32?, closeDate: Int32?, countriesIso2: [String]?, hash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(956))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 40, id)
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, question.tlObject)
        tlStoreReference(_tlObject, 56, answers.map { item in item.tlObject } as NSArray)
        if let _tlValue = closePeriod { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = closeDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 64, countriesIso2.map { value in value as NSArray })
        tlStore(_tlObject, 72, hash)
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PollAnswer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPollAnswer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pollAnswer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPollAnswer(Cons_inputPollAnswer)
        case pollAnswer(Cons_pollAnswer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPollAnswer(Cons_inputPollAnswer(tlObject: object))
            case 1:
                self = .pollAnswer(Cons_pollAnswer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPollAnswer(let _data):
                return _data.tlObject
            case .pollAnswer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PollAnswer] {
            return tlObjectsAt(object, offset).map { Api.PollAnswer(tlObject: $0) }
        }

    }
}
public extension Api.PollAnswer.Cons_inputPollAnswer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var media: Api.InputMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputMedia(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, text: Api.TextWithEntities, media: Api.InputMedia?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(170))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        tlStoreReference(_tlObject, 40, media?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PollAnswer.Cons_pollAnswer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var option: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var addedBy: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var date: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, text: Api.TextWithEntities, option: Buffer, media: Api.MessageMedia?, addedBy: Api.Peer?, date: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(487))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        tlStoreReference(_tlObject, 40, option.makeData() as NSData)
        tlStoreReference(_tlObject, 48, media?.tlObject)
        tlStoreReference(_tlObject, 56, addedBy?.tlObject)
        if let _tlValue = date { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PollAnswerVoters: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pollAnswerVoters {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pollAnswerVoters(Cons_pollAnswerVoters)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pollAnswerVoters(Cons_pollAnswerVoters(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pollAnswerVoters(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PollAnswerVoters] {
            return tlObjectsAt(object, offset).map { Api.PollAnswerVoters(tlObject: $0) }
        }

    }
}
public extension Api.PollAnswerVoters.Cons_pollAnswerVoters {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var option: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var voters: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var recentVoters: [Api.Peer]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Peer.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, option: Buffer, voters: Int32?, recentVoters: [Api.Peer]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(347))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, option.makeData() as NSData)
        if let _tlValue = voters { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, recentVoters.map { value in value.map { item in item.tlObject } as NSArray })
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PollResults: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pollResults {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pollResults(Cons_pollResults)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pollResults(Cons_pollResults(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pollResults(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PollResults] {
            return tlObjectsAt(object, offset).map { Api.PollResults(tlObject: $0) }
        }

    }
}
public extension Api.PollResults.Cons_pollResults {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var results: [Api.PollAnswerVoters]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.PollAnswerVoters.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var totalVoters: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var recentVoters: [Api.Peer]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Peer.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var solution: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var solutionEntities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.MessageEntity.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var solutionMedia: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, results: [Api.PollAnswerVoters]?, totalVoters: Int32?, recentVoters: [Api.Peer]?, solution: String?, solutionEntities: [Api.MessageEntity]?, solutionMedia: Api.MessageMedia?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1217))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, results.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = totalVoters { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, recentVoters.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, solution.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, solutionEntities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 64, solutionMedia?.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PopularContact: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_popularContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case popularContact(Cons_popularContact)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .popularContact(Cons_popularContact(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .popularContact(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PopularContact] {
            return tlObjectsAt(object, offset).map { Api.PopularContact(tlObject: $0) }
        }

    }
}
public extension Api.PopularContact.Cons_popularContact {
    @_alwaysEmitIntoClient var clientId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var importers: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(clientId: Int64, importers: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(595))
        tlStore(_tlObject, 32, clientId)
        tlStore(_tlObject, 24, importers)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PostAddress: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_postAddress {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case postAddress(Cons_postAddress)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .postAddress(Cons_postAddress(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .postAddress(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PostAddress] {
            return tlObjectsAt(object, offset).map { Api.PostAddress(tlObject: $0) }
        }

    }
}
public extension Api.PostAddress.Cons_postAddress {
    @_alwaysEmitIntoClient var streetLine1: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var streetLine2: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var city: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var state: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var countryIso2: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var postCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    init(streetLine1: String, streetLine2: String, city: String, state: String, countryIso2: String, postCode: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(206))
        tlStoreReference(_tlObject, 24, streetLine1 as NSString)
        tlStoreReference(_tlObject, 32, streetLine2 as NSString)
        tlStoreReference(_tlObject, 40, city as NSString)
        tlStoreReference(_tlObject, 48, state as NSString)
        tlStoreReference(_tlObject, 56, countryIso2 as NSString)
        tlStoreReference(_tlObject, 64, postCode as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PostInteractionCounters: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_postInteractionCountersMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_postInteractionCountersStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case postInteractionCountersMessage(Cons_postInteractionCountersMessage)
        case postInteractionCountersStory(Cons_postInteractionCountersStory)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .postInteractionCountersMessage(Cons_postInteractionCountersMessage(tlObject: object))
            case 1:
                self = .postInteractionCountersStory(Cons_postInteractionCountersStory(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .postInteractionCountersMessage(let _data):
                return _data.tlObject
            case .postInteractionCountersStory(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PostInteractionCounters] {
            return tlObjectsAt(object, offset).map { Api.PostInteractionCounters(tlObject: $0) }
        }

    }
}
public extension Api.PostInteractionCounters.Cons_postInteractionCountersMessage {
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var views: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var forwards: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reactions: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(msgId: Int32, views: Int32, forwards: Int32, reactions: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1510))
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 28, views)
        tlStore(_tlObject, 32, forwards)
        tlStore(_tlObject, 36, reactions)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PostInteractionCounters.Cons_postInteractionCountersStory {
    @_alwaysEmitIntoClient var storyId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var views: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var forwards: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reactions: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(storyId: Int32, views: Int32, forwards: Int32, reactions: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(877))
        tlStore(_tlObject, 24, storyId)
        tlStore(_tlObject, 28, views)
        tlStore(_tlObject, 32, forwards)
        tlStore(_tlObject, 36, reactions)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PremiumGiftCodeOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_premiumGiftCodeOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case premiumGiftCodeOption(Cons_premiumGiftCodeOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .premiumGiftCodeOption(Cons_premiumGiftCodeOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .premiumGiftCodeOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PremiumGiftCodeOption] {
            return tlObjectsAt(object, offset).map { Api.PremiumGiftCodeOption(tlObject: $0) }
        }

    }
}
public extension Api.PremiumGiftCodeOption.Cons_premiumGiftCodeOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var months: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var storeProduct: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var storeQuantity: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    init(flags: Int32, users: Int32, months: Int32, storeProduct: String?, storeQuantity: Int32?, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(249))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, users)
        tlStore(_tlObject, 32, months)
        tlStoreReference(_tlObject, 40, storeProduct.map { value in value as NSString })
        if let _tlValue = storeQuantity { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, currency as NSString)
        tlStore(_tlObject, 56, amount)
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PremiumSubscriptionOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_premiumSubscriptionOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case premiumSubscriptionOption(Cons_premiumSubscriptionOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .premiumSubscriptionOption(Cons_premiumSubscriptionOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .premiumSubscriptionOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PremiumSubscriptionOption] {
            return tlObjectsAt(object, offset).map { Api.PremiumSubscriptionOption(tlObject: $0) }
        }

    }
}
public extension Api.PremiumSubscriptionOption.Cons_premiumSubscriptionOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var transaction: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var months: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var botUrl: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var storeProduct: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    init(flags: Int32, transaction: String?, months: Int32, currency: String, amount: Int64, botUrl: String, storeProduct: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(607))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, transaction.map { value in value as NSString })
        tlStore(_tlObject, 28, months)
        tlStoreReference(_tlObject, 40, currency as NSString)
        tlStore(_tlObject, 48, amount)
        tlStoreReference(_tlObject, 56, botUrl as NSString)
        tlStoreReference(_tlObject, 64, storeProduct.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PrepaidGiveaway: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_prepaidGiveaway {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_prepaidStarsGiveaway {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case prepaidGiveaway(Cons_prepaidGiveaway)
        case prepaidStarsGiveaway(Cons_prepaidStarsGiveaway)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .prepaidGiveaway(Cons_prepaidGiveaway(tlObject: object))
            case 1:
                self = .prepaidStarsGiveaway(Cons_prepaidStarsGiveaway(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .prepaidGiveaway(let _data):
                return _data.tlObject
            case .prepaidStarsGiveaway(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PrepaidGiveaway] {
            return tlObjectsAt(object, offset).map { Api.PrepaidGiveaway(tlObject: $0) }
        }

    }
}
public extension Api.PrepaidGiveaway.Cons_prepaidGiveaway {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var months: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var quantity: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(id: Int64, months: Int32, quantity: Int32, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1151))
        tlStore(_tlObject, 40, id)
        tlStore(_tlObject, 24, months)
        tlStore(_tlObject, 28, quantity)
        tlStore(_tlObject, 32, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PrepaidGiveaway.Cons_prepaidStarsGiveaway {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var quantity: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var boosts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(id: Int64, stars: Int64, quantity: Int32, boosts: Int32, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(993))
        tlStore(_tlObject, 40, id)
        tlStore(_tlObject, 48, stars)
        tlStore(_tlObject, 24, quantity)
        tlStore(_tlObject, 28, boosts)
        tlStore(_tlObject, 32, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PrivacyKey: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case privacyKeyAbout
        case privacyKeyAddedByPhone
        case privacyKeyBirthday
        case privacyKeyChatInvite
        case privacyKeyForwards
        case privacyKeyNoPaidMessages
        case privacyKeyPhoneCall
        case privacyKeyPhoneNumber
        case privacyKeyPhoneP2P
        case privacyKeyProfilePhoto
        case privacyKeySavedMusic
        case privacyKeyStarGiftsAutoSave
        case privacyKeyStatusTimestamp
        case privacyKeyVoiceMessages


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .privacyKeyAbout
            case 1:
                self = .privacyKeyAddedByPhone
            case 2:
                self = .privacyKeyBirthday
            case 3:
                self = .privacyKeyChatInvite
            case 4:
                self = .privacyKeyForwards
            case 5:
                self = .privacyKeyNoPaidMessages
            case 6:
                self = .privacyKeyPhoneCall
            case 7:
                self = .privacyKeyPhoneNumber
            case 8:
                self = .privacyKeyPhoneP2P
            case 9:
                self = .privacyKeyProfilePhoto
            case 10:
                self = .privacyKeySavedMusic
            case 11:
                self = .privacyKeyStarGiftsAutoSave
            case 12:
                self = .privacyKeyStatusTimestamp
            case 13:
                self = .privacyKeyVoiceMessages
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .privacyKeyAbout:
                return TLObjectSingleton(TLApiConstructorAt(1067))
            case .privacyKeyAddedByPhone:
                return TLObjectSingleton(TLApiConstructorAt(436))
            case .privacyKeyBirthday:
                return TLObjectSingleton(TLApiConstructorAt(217))
            case .privacyKeyChatInvite:
                return TLObjectSingleton(TLApiConstructorAt(519))
            case .privacyKeyForwards:
                return TLObjectSingleton(TLApiConstructorAt(673))
            case .privacyKeyNoPaidMessages:
                return TLObjectSingleton(TLApiConstructorAt(150))
            case .privacyKeyPhoneCall:
                return TLObjectSingleton(TLApiConstructorAt(392))
            case .privacyKeyPhoneNumber:
                return TLObjectSingleton(TLApiConstructorAt(1374))
            case .privacyKeyPhoneP2P:
                return TLObjectSingleton(TLApiConstructorAt(365))
            case .privacyKeyProfilePhoto:
                return TLObjectSingleton(TLApiConstructorAt(953))
            case .privacyKeySavedMusic:
                return TLObjectSingleton(TLApiConstructorAt(1691))
            case .privacyKeyStarGiftsAutoSave:
                return TLObjectSingleton(TLApiConstructorAt(281))
            case .privacyKeyStatusTimestamp:
                return TLObjectSingleton(TLApiConstructorAt(1234))
            case .privacyKeyVoiceMessages:
                return TLObjectSingleton(TLApiConstructorAt(47))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PrivacyKey] {
            return tlObjectsAt(object, offset).map { Api.PrivacyKey(tlObject: $0) }
        }

    }
}
