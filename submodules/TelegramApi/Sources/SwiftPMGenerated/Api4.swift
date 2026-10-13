import TelegramApiObjC
public extension Api {
    enum ChannelAdminLogEventsFilter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelAdminLogEventsFilter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelAdminLogEventsFilter(Cons_channelAdminLogEventsFilter)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelAdminLogEventsFilter(Cons_channelAdminLogEventsFilter(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelAdminLogEventsFilter(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChannelAdminLogEventsFilter] {
            return tlObjectsAt(object, offset).map { Api.ChannelAdminLogEventsFilter(tlObject: $0) }
        }

    }
}
public extension Api.ChannelAdminLogEventsFilter.Cons_channelAdminLogEventsFilter {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1547))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChannelLocation: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelLocation(Cons_channelLocation)
        case channelLocationEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelLocation(Cons_channelLocation(tlObject: object))
            case 1:
                self = .channelLocationEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelLocation(let _data):
                return _data.tlObject
            case .channelLocationEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1273))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChannelLocation] {
            return tlObjectsAt(object, offset).map { Api.ChannelLocation(tlObject: $0) }
        }

    }
}
public extension Api.ChannelLocation.Cons_channelLocation {
    @_alwaysEmitIntoClient var geoPoint: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(geoPoint: Api.GeoPoint, address: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(226))
        tlStoreReference(_tlObject, 24, geoPoint.tlObject)
        tlStoreReference(_tlObject, 32, address as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChannelMessagesFilter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelMessagesFilter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelMessagesFilter(Cons_channelMessagesFilter)
        case channelMessagesFilterEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelMessagesFilter(Cons_channelMessagesFilter(tlObject: object))
            case 1:
                self = .channelMessagesFilterEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelMessagesFilter(let _data):
                return _data.tlObject
            case .channelMessagesFilterEmpty:
                return TLObjectSingleton(TLApiConstructorAt(951))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChannelMessagesFilter] {
            return tlObjectsAt(object, offset).map { Api.ChannelMessagesFilter(tlObject: $0) }
        }

    }
}
public extension Api.ChannelMessagesFilter.Cons_channelMessagesFilter {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ranges: [Api.MessageRange] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageRange.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, ranges: [Api.MessageRange]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1367))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, ranges.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChannelParticipant: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelParticipant {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantAdmin {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantBanned {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantCreator {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantLeft {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantSelf {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelParticipant(Cons_channelParticipant)
        case channelParticipantAdmin(Cons_channelParticipantAdmin)
        case channelParticipantBanned(Cons_channelParticipantBanned)
        case channelParticipantCreator(Cons_channelParticipantCreator)
        case channelParticipantLeft(Cons_channelParticipantLeft)
        case channelParticipantSelf(Cons_channelParticipantSelf)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelParticipant(Cons_channelParticipant(tlObject: object))
            case 1:
                self = .channelParticipantAdmin(Cons_channelParticipantAdmin(tlObject: object))
            case 2:
                self = .channelParticipantBanned(Cons_channelParticipantBanned(tlObject: object))
            case 3:
                self = .channelParticipantCreator(Cons_channelParticipantCreator(tlObject: object))
            case 4:
                self = .channelParticipantLeft(Cons_channelParticipantLeft(tlObject: object))
            case 5:
                self = .channelParticipantSelf(Cons_channelParticipantSelf(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelParticipant(let _data):
                return _data.tlObject
            case .channelParticipantAdmin(let _data):
                return _data.tlObject
            case .channelParticipantBanned(let _data):
                return _data.tlObject
            case .channelParticipantCreator(let _data):
                return _data.tlObject
            case .channelParticipantLeft(let _data):
                return _data.tlObject
            case .channelParticipantSelf(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChannelParticipant] {
            return tlObjectsAt(object, offset).map { Api.ChannelParticipant(tlObject: $0) }
        }

    }
}
public extension Api.ChannelParticipant.Cons_channelParticipant {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var subscriptionUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, userId: Int64, date: Int32, subscriptionUntilDate: Int32?, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(183))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, userId)
        tlStore(_tlObject, 28, date)
        if let _tlValue = subscriptionUntilDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, rank.map { value in value as NSString })
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipant.Cons_channelParticipantAdmin {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var inviterId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var promotedBy: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminRights: Api.ChatAdminRights {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    init(flags: Int32, userId: Int64, inviterId: Int64?, promotedBy: Int64, date: Int32, adminRights: Api.ChatAdminRights, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(336))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        if let _tlValue = inviterId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, promotedBy)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 56, adminRights.tlObject)
        tlStoreReference(_tlObject, 64, rank.map { value in value as NSString })
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipant.Cons_channelParticipantBanned {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var kickedBy: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bannedRights: Api.ChatBannedRights {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatBannedRights(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, peer: Api.Peer, kickedBy: Int64, date: Int32, bannedRights: Api.ChatBannedRights, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1406))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 40, kickedBy)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 48, bannedRights.tlObject)
        tlStoreReference(_tlObject, 56, rank.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipant.Cons_channelParticipantCreator {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var adminRights: Api.ChatAdminRights {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, userId: Int64, adminRights: Api.ChatAdminRights, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(303))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStoreReference(_tlObject, 40, adminRights.tlObject)
        tlStoreReference(_tlObject, 48, rank.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipant.Cons_channelParticipantLeft {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.Peer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(174))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipant.Cons_channelParticipantSelf {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var inviterId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var subscriptionUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, subscriptionUntilDate: Int32?, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1107))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, userId)
        tlStore(_tlObject, 48, inviterId)
        tlStore(_tlObject, 28, date)
        if let _tlValue = subscriptionUntilDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, rank.map { value in value as NSString })
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChannelParticipantsFilter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelParticipantsBanned {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantsContacts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantsKicked {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantsMentions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelParticipantsSearch {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelParticipantsAdmins
        case channelParticipantsBanned(Cons_channelParticipantsBanned)
        case channelParticipantsBots
        case channelParticipantsContacts(Cons_channelParticipantsContacts)
        case channelParticipantsKicked(Cons_channelParticipantsKicked)
        case channelParticipantsMentions(Cons_channelParticipantsMentions)
        case channelParticipantsRecent
        case channelParticipantsSearch(Cons_channelParticipantsSearch)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelParticipantsAdmins
            case 1:
                self = .channelParticipantsBanned(Cons_channelParticipantsBanned(tlObject: object))
            case 2:
                self = .channelParticipantsBots
            case 3:
                self = .channelParticipantsContacts(Cons_channelParticipantsContacts(tlObject: object))
            case 4:
                self = .channelParticipantsKicked(Cons_channelParticipantsKicked(tlObject: object))
            case 5:
                self = .channelParticipantsMentions(Cons_channelParticipantsMentions(tlObject: object))
            case 6:
                self = .channelParticipantsRecent
            case 7:
                self = .channelParticipantsSearch(Cons_channelParticipantsSearch(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelParticipantsAdmins:
                return TLObjectSingleton(TLApiConstructorAt(1181))
            case .channelParticipantsBanned(let _data):
                return _data.tlObject
            case .channelParticipantsBots:
                return TLObjectSingleton(TLApiConstructorAt(1154))
            case .channelParticipantsContacts(let _data):
                return _data.tlObject
            case .channelParticipantsKicked(let _data):
                return _data.tlObject
            case .channelParticipantsMentions(let _data):
                return _data.tlObject
            case .channelParticipantsRecent:
                return TLObjectSingleton(TLApiConstructorAt(1463))
            case .channelParticipantsSearch(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChannelParticipantsFilter] {
            return tlObjectsAt(object, offset).map { Api.ChannelParticipantsFilter(tlObject: $0) }
        }

    }
}
public extension Api.ChannelParticipantsFilter.Cons_channelParticipantsBanned {
    @_alwaysEmitIntoClient var q: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(q: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(122))
        tlStoreReference(_tlObject, 24, q as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipantsFilter.Cons_channelParticipantsContacts {
    @_alwaysEmitIntoClient var q: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(q: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1235))
        tlStoreReference(_tlObject, 24, q as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipantsFilter.Cons_channelParticipantsKicked {
    @_alwaysEmitIntoClient var q: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(q: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1069))
        tlStoreReference(_tlObject, 24, q as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipantsFilter.Cons_channelParticipantsMentions {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var q: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var topMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, q: String?, topMsgId: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1474))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, q.map { value in value as NSString })
        if let _tlValue = topMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChannelParticipantsFilter.Cons_channelParticipantsSearch {
    @_alwaysEmitIntoClient var q: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(q: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(44))
        tlStoreReference(_tlObject, 24, q as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum Chat: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelForbidden {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatForbidden {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_community {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_communityForbidden {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channel(Cons_channel)
        case channelForbidden(Cons_channelForbidden)
        case chat(Cons_chat)
        case chatEmpty(Cons_chatEmpty)
        case chatForbidden(Cons_chatForbidden)
        case community(Cons_community)
        case communityForbidden(Cons_communityForbidden)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channel(Cons_channel(tlObject: object))
            case 1:
                self = .channelForbidden(Cons_channelForbidden(tlObject: object))
            case 2:
                self = .chat(Cons_chat(tlObject: object))
            case 3:
                self = .chatEmpty(Cons_chatEmpty(tlObject: object))
            case 4:
                self = .chatForbidden(Cons_chatForbidden(tlObject: object))
            case 5:
                self = .community(Cons_community(tlObject: object))
            case 6:
                self = .communityForbidden(Cons_communityForbidden(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channel(let _data):
                return _data.tlObject
            case .channelForbidden(let _data):
                return _data.tlObject
            case .chat(let _data):
                return _data.tlObject
            case .chatEmpty(let _data):
                return _data.tlObject
            case .chatForbidden(let _data):
                return _data.tlObject
            case .community(let _data):
                return _data.tlObject
            case .communityForbidden(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Chat] {
            return tlObjectsAt(object, offset).map { Api.Chat(tlObject: $0) }
        }

    }
}
public extension Api.Chat.Cons_channel {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var flags2: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var username: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var photo: Api.ChatPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatPhoto(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var restrictionReason: [Api.RestrictionReason]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.RestrictionReason.tlArray(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var adminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var bannedRights: Api.ChatBannedRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.ChatBannedRights(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var defaultBannedRights: Api.ChatBannedRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : Api.ChatBannedRights(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    @_alwaysEmitIntoClient var participantsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var usernames: [Api.Username]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : Api.Username.tlArray(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var storiesMaxId: Api.RecentStory? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : Api.RecentStory(tlObject: tlObjectAt(self.tlObject, 128)) } }
    }
    @_alwaysEmitIntoClient var color: Api.PeerColor? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 136)) } }
    }
    @_alwaysEmitIntoClient var profileColor: Api.PeerColor? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 144) ? nil : Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 144)) } }
    }
    @_alwaysEmitIntoClient var emojiStatus: Api.EmojiStatus? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.EmojiStatus(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var level: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var subscriptionUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 3) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var botVerificationIcon: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 4) ? tlBase(self.tlObject).load(fromByteOffset: 160, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var sendPaidMessagesStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 5) ? tlBase(self.tlObject).load(fromByteOffset: 168, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var linkedMonoforumId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 6) ? tlBase(self.tlObject).load(fromByteOffset: 176, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var linkedCommunityId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 7) ? tlBase(self.tlObject).load(fromByteOffset: 184, as: Int64.self) : nil } }
    }
    init(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, title: String, username: String?, photo: Api.ChatPhoto, date: Int32, restrictionReason: [Api.RestrictionReason]?, adminRights: Api.ChatAdminRights?, bannedRights: Api.ChatBannedRights?, defaultBannedRights: Api.ChatBannedRights?, participantsCount: Int32?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, emojiStatus: Api.EmojiStatus?, level: Int32?, subscriptionUntilDate: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?, linkedMonoforumId: Int64?, linkedCommunityId: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1399))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, flags2)
        tlStore(_tlObject, 48, id)
        if let _tlValue = accessHash { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, title as NSString)
        tlStoreReference(_tlObject, 72, username.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, photo.tlObject)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 88, restrictionReason.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 96, adminRights?.tlObject)
        tlStoreReference(_tlObject, 104, bannedRights?.tlObject)
        tlStoreReference(_tlObject, 112, defaultBannedRights?.tlObject)
        if let _tlValue = participantsCount { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 120, usernames.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 128, storiesMaxId?.tlObject)
        tlStoreReference(_tlObject, 136, color?.tlObject)
        tlStoreReference(_tlObject, 144, profileColor?.tlObject)
        tlStoreReference(_tlObject, 152, emojiStatus?.tlObject)
        if let _tlValue = level { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = subscriptionUntilDate { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = botVerificationIcon { tlStore(_tlObject, 160, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = sendPaidMessagesStars { tlStore(_tlObject, 168, _tlValue); _tlPresent |= 1 << 5 }
        if let _tlValue = linkedMonoforumId { tlStore(_tlObject, 176, _tlValue); _tlPresent |= 1 << 6 }
        if let _tlValue = linkedCommunityId { tlStore(_tlObject, 184, _tlValue); _tlPresent |= 1 << 7 }
        tlStore(_tlObject, 192, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Chat.Cons_channelForbidden {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var untilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, title: String, untilDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(151))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStoreReference(_tlObject, 48, title as NSString)
        if let _tlValue = untilDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Chat.Cons_chat {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var photo: Api.ChatPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatPhoto(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var participantsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var migratedTo: Api.InputChannel? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.InputChannel(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var adminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var defaultBannedRights: Api.ChatBannedRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.ChatBannedRights(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, id: Int64, title: String, photo: Api.ChatPhoto, participantsCount: Int32, date: Int32, version: Int32, migratedTo: Api.InputChannel?, adminRights: Api.ChatAdminRights?, defaultBannedRights: Api.ChatBannedRights?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(427))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, id)
        tlStoreReference(_tlObject, 48, title as NSString)
        tlStoreReference(_tlObject, 56, photo.tlObject)
        tlStore(_tlObject, 28, participantsCount)
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 36, version)
        tlStoreReference(_tlObject, 64, migratedTo?.tlObject)
        tlStoreReference(_tlObject, 72, adminRights?.tlObject)
        tlStoreReference(_tlObject, 80, defaultBannedRights?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Chat.Cons_chatEmpty {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(266))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Chat.Cons_chatForbidden {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(id: Int64, title: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(651))
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 32, title as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Chat.Cons_community {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var flags2: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var photo: Api.ChatPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatPhoto(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var defaultBannedRights: Api.ChatBannedRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.ChatBannedRights(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, title: String, photo: Api.ChatPhoto, date: Int32, adminRights: Api.ChatAdminRights?, defaultBannedRights: Api.ChatBannedRights?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(653))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, flags2)
        tlStore(_tlObject, 40, id)
        if let _tlValue = accessHash { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, title as NSString)
        tlStoreReference(_tlObject, 64, photo.tlObject)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 72, adminRights?.tlObject)
        tlStoreReference(_tlObject, 80, defaultBannedRights?.tlObject)
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Chat.Cons_communityForbidden {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64?, title: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1692))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        if let _tlValue = accessHash { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, title as NSString)
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatAdminRights: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatAdminRights {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatAdminRights(Cons_chatAdminRights)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatAdminRights(Cons_chatAdminRights(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatAdminRights(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatAdminRights] {
            return tlObjectsAt(object, offset).map { Api.ChatAdminRights(tlObject: $0) }
        }

    }
}
public extension Api.ChatAdminRights.Cons_chatAdminRights {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(613))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
