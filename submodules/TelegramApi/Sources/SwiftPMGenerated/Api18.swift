import TelegramApiObjC
public extension Api {
    indirect enum MessageReplyHeader: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageReplyHeader {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageReplyStoryHeader {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageReplyHeader(Cons_messageReplyHeader)
        case messageReplyStoryHeader(Cons_messageReplyStoryHeader)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageReplyHeader(Cons_messageReplyHeader(tlObject: object))
            case 1:
                self = .messageReplyStoryHeader(Cons_messageReplyStoryHeader(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageReplyHeader(let _data):
                return _data.tlObject
            case .messageReplyStoryHeader(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageReplyHeader] {
            return tlObjectsAt(object, offset).map { Api.MessageReplyHeader(tlObject: $0) }
        }

    }
}
public extension Api.MessageReplyHeader.Cons_messageReplyHeader {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var replyToMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var replyToPeerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var replyFrom: Api.MessageFwdHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.MessageFwdHeader(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var replyMedia: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var replyToTopId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var quoteText: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var quoteEntities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.MessageEntity.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var quoteOffset: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var todoItemId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 3) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var pollOption: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : tlBufferAt(self.tlObject, 88) } }
    }
    init(flags: Int32, replyToMsgId: Int32?, replyToPeerId: Api.Peer?, replyFrom: Api.MessageFwdHeader?, replyMedia: Api.MessageMedia?, replyToTopId: Int32?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, todoItemId: Int32?, pollOption: Buffer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(181))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = replyToMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, replyToPeerId?.tlObject)
        tlStoreReference(_tlObject, 56, replyFrom?.tlObject)
        tlStoreReference(_tlObject, 64, replyMedia?.tlObject)
        if let _tlValue = replyToTopId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 72, quoteText.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, quoteEntities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = quoteOffset { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = todoItemId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 3 }
        tlStoreReference(_tlObject, 88, pollOption.map { value in value.makeData() as NSData })
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageReplyHeader.Cons_messageReplyStoryHeader {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var storyId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.Peer, storyId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(94))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, storyId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessageReportOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageReportOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageReportOption(Cons_messageReportOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageReportOption(Cons_messageReportOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageReportOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageReportOption] {
            return tlObjectsAt(object, offset).map { Api.MessageReportOption(tlObject: $0) }
        }

    }
}
public extension Api.MessageReportOption.Cons_messageReportOption {
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var option: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(text: String, option: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(773))
        tlStoreReference(_tlObject, 24, text as NSString)
        tlStoreReference(_tlObject, 32, option.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessageViews: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageViews {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageViews(Cons_messageViews)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageViews(Cons_messageViews(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageViews(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageViews] {
            return tlObjectsAt(object, offset).map { Api.MessageViews(tlObject: $0) }
        }

    }
}
public extension Api.MessageViews.Cons_messageViews {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var views: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var forwards: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var replies: Api.MessageReplies? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.MessageReplies(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(449))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = views { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = forwards { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 40, replies?.tlObject)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessagesFilter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputMessagesFilterPhoneCalls {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputMessagesFilterChatPhotos
        case inputMessagesFilterContacts
        case inputMessagesFilterDocument
        case inputMessagesFilterEmpty
        case inputMessagesFilterGeo
        case inputMessagesFilterGif
        case inputMessagesFilterMusic
        case inputMessagesFilterMyMentions
        case inputMessagesFilterPhoneCalls(Cons_inputMessagesFilterPhoneCalls)
        case inputMessagesFilterPhotoVideo
        case inputMessagesFilterPhotos
        case inputMessagesFilterPinned
        case inputMessagesFilterPoll
        case inputMessagesFilterRoundVideo
        case inputMessagesFilterRoundVoice
        case inputMessagesFilterUrl
        case inputMessagesFilterVideo
        case inputMessagesFilterVoice


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputMessagesFilterChatPhotos
            case 1:
                self = .inputMessagesFilterContacts
            case 2:
                self = .inputMessagesFilterDocument
            case 3:
                self = .inputMessagesFilterEmpty
            case 4:
                self = .inputMessagesFilterGeo
            case 5:
                self = .inputMessagesFilterGif
            case 6:
                self = .inputMessagesFilterMusic
            case 7:
                self = .inputMessagesFilterMyMentions
            case 8:
                self = .inputMessagesFilterPhoneCalls(Cons_inputMessagesFilterPhoneCalls(tlObject: object))
            case 9:
                self = .inputMessagesFilterPhotoVideo
            case 10:
                self = .inputMessagesFilterPhotos
            case 11:
                self = .inputMessagesFilterPinned
            case 12:
                self = .inputMessagesFilterPoll
            case 13:
                self = .inputMessagesFilterRoundVideo
            case 14:
                self = .inputMessagesFilterRoundVoice
            case 15:
                self = .inputMessagesFilterUrl
            case 16:
                self = .inputMessagesFilterVideo
            case 17:
                self = .inputMessagesFilterVoice
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputMessagesFilterChatPhotos:
                return TLObjectSingleton(TLApiConstructorAt(372))
            case .inputMessagesFilterContacts:
                return TLObjectSingleton(TLApiConstructorAt(1461))
            case .inputMessagesFilterDocument:
                return TLObjectSingleton(TLApiConstructorAt(1023))
            case .inputMessagesFilterEmpty:
                return TLObjectSingleton(TLApiConstructorAt(572))
            case .inputMessagesFilterGeo:
                return TLObjectSingleton(TLApiConstructorAt(1509))
            case .inputMessagesFilterGif:
                return TLObjectSingleton(TLApiConstructorAt(1696))
            case .inputMessagesFilterMusic:
                return TLObjectSingleton(TLApiConstructorAt(357))
            case .inputMessagesFilterMyMentions:
                return TLObjectSingleton(TLApiConstructorAt(1282))
            case .inputMessagesFilterPhoneCalls(let _data):
                return _data.tlObject
            case .inputMessagesFilterPhotoVideo:
                return TLObjectSingleton(TLApiConstructorAt(562))
            case .inputMessagesFilterPhotos:
                return TLObjectSingleton(TLApiConstructorAt(952))
            case .inputMessagesFilterPinned:
                return TLObjectSingleton(TLApiConstructorAt(182))
            case .inputMessagesFilterPoll:
                return TLObjectSingleton(TLApiConstructorAt(1649))
            case .inputMessagesFilterRoundVideo:
                return TLObjectSingleton(TLApiConstructorAt(1181))
            case .inputMessagesFilterRoundVoice:
                return TLObjectSingleton(TLApiConstructorAt(780))
            case .inputMessagesFilterUrl:
                return TLObjectSingleton(TLApiConstructorAt(808))
            case .inputMessagesFilterVideo:
                return TLObjectSingleton(TLApiConstructorAt(1033))
            case .inputMessagesFilterVoice:
                return TLObjectSingleton(TLApiConstructorAt(528))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessagesFilter] {
            return tlObjectsAt(object, offset).map { Api.MessagesFilter(tlObject: $0) }
        }

    }
}
public extension Api.MessagesFilter.Cons_inputMessagesFilterPhoneCalls {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(818))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MissingInvitee: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_missingInvitee {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case missingInvitee(Cons_missingInvitee)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .missingInvitee(Cons_missingInvitee(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .missingInvitee(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MissingInvitee] {
            return tlObjectsAt(object, offset).map { Api.MissingInvitee(tlObject: $0) }
        }

    }
}
public extension Api.MissingInvitee.Cons_missingInvitee {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(flags: Int32, userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(623))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MyBoost: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_myBoost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case myBoost(Cons_myBoost)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .myBoost(Cons_myBoost(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .myBoost(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MyBoost] {
            return tlObjectsAt(object, offset).map { Api.MyBoost(tlObject: $0) }
        }

    }
}
public extension Api.MyBoost.Cons_myBoost {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var slot: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var cooldownUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    init(flags: Int32, slot: Int32, peer: Api.Peer?, date: Int32, expires: Int32, cooldownUntilDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1302))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, slot)
        tlStoreReference(_tlObject, 48, peer?.tlObject)
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 36, expires)
        if let _tlValue = cooldownUntilDate { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum NearestDc: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_nearestDc {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case nearestDc(Cons_nearestDc)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .nearestDc(Cons_nearestDc(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .nearestDc(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.NearestDc] {
            return tlObjectsAt(object, offset).map { Api.NearestDc(tlObject: $0) }
        }

    }
}
public extension Api.NearestDc.Cons_nearestDc {
    @_alwaysEmitIntoClient var country: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var thisDc: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var nearestDc: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(country: String, thisDc: Int32, nearestDc: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(902))
        tlStoreReference(_tlObject, 32, country as NSString)
        tlStore(_tlObject, 24, thisDc)
        tlStore(_tlObject, 28, nearestDc)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum NotificationSound: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_notificationSoundLocal {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_notificationSoundRingtone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case notificationSoundDefault
        case notificationSoundLocal(Cons_notificationSoundLocal)
        case notificationSoundNone
        case notificationSoundRingtone(Cons_notificationSoundRingtone)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .notificationSoundDefault
            case 1:
                self = .notificationSoundLocal(Cons_notificationSoundLocal(tlObject: object))
            case 2:
                self = .notificationSoundNone
            case 3:
                self = .notificationSoundRingtone(Cons_notificationSoundRingtone(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .notificationSoundDefault:
                return TLObjectSingleton(TLApiConstructorAt(964))
            case .notificationSoundLocal(let _data):
                return _data.tlObject
            case .notificationSoundNone:
                return TLObjectSingleton(TLApiConstructorAt(702))
            case .notificationSoundRingtone(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.NotificationSound] {
            return tlObjectsAt(object, offset).map { Api.NotificationSound(tlObject: $0) }
        }

    }
}
public extension Api.NotificationSound.Cons_notificationSoundLocal {
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var data: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(title: String, data: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(831))
        tlStoreReference(_tlObject, 24, title as NSString)
        tlStoreReference(_tlObject, 32, data as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.NotificationSound.Cons_notificationSoundRingtone {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1690))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum NotifyPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_notifyCommunity {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_notifyForumTopic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_notifyPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case notifyBroadcasts
        case notifyChats
        case notifyCommunity(Cons_notifyCommunity)
        case notifyForumTopic(Cons_notifyForumTopic)
        case notifyPeer(Cons_notifyPeer)
        case notifyUsers


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .notifyBroadcasts
            case 1:
                self = .notifyChats
            case 2:
                self = .notifyCommunity(Cons_notifyCommunity(tlObject: object))
            case 3:
                self = .notifyForumTopic(Cons_notifyForumTopic(tlObject: object))
            case 4:
                self = .notifyPeer(Cons_notifyPeer(tlObject: object))
            case 5:
                self = .notifyUsers
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .notifyBroadcasts:
                return TLObjectSingleton(TLApiConstructorAt(1395))
            case .notifyChats:
                return TLObjectSingleton(TLApiConstructorAt(1267))
            case .notifyCommunity(let _data):
                return _data.tlObject
            case .notifyForumTopic(let _data):
                return _data.tlObject
            case .notifyPeer(let _data):
                return _data.tlObject
            case .notifyUsers:
                return TLObjectSingleton(TLApiConstructorAt(1176))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.NotifyPeer] {
            return tlObjectsAt(object, offset).map { Api.NotifyPeer(tlObject: $0) }
        }

    }
}
public extension Api.NotifyPeer.Cons_notifyCommunity {
    @_alwaysEmitIntoClient var communityId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(communityId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1253))
        tlStore(_tlObject, 24, communityId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.NotifyPeer.Cons_notifyForumTopic {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var topMsgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.Peer, topMsgId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(237))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, topMsgId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.NotifyPeer.Cons_notifyPeer {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.Peer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1035))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum OnrampAvailability: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_onrampAvailability {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case onrampAvailability(Cons_onrampAvailability)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .onrampAvailability(Cons_onrampAvailability(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .onrampAvailability(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.OnrampAvailability] {
            return tlObjectsAt(object, offset).map { Api.OnrampAvailability(tlObject: $0) }
        }

    }
}
public extension Api.OnrampAvailability.Cons_onrampAvailability {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var countryCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var state: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var methods: [Api.OnrampMethodAvailability] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.OnrampMethodAvailability.tlArray(self.tlObject, 48) } }
    }
    init(flags: Int32, countryCode: String, state: String?, methods: [Api.OnrampMethodAvailability]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1644))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, countryCode as NSString)
        tlStoreReference(_tlObject, 40, state.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, methods.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum OnrampLimits: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_onrampLimits {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case onrampLimits(Cons_onrampLimits)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .onrampLimits(Cons_onrampLimits(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .onrampLimits(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.OnrampLimits] {
            return tlObjectsAt(object, offset).map { Api.OnrampLimits(tlObject: $0) }
        }

    }
}
public extension Api.OnrampLimits.Cons_onrampLimits {
    @_alwaysEmitIntoClient var baseCurrency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var baseMinAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var baseMaxAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var cryptoMinAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var cryptoMaxAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var paymentMethod: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    init(baseCurrency: String, baseMinAmount: String, baseMaxAmount: String, cryptoMinAmount: String, cryptoMaxAmount: String, paymentMethod: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(789))
        tlStoreReference(_tlObject, 24, baseCurrency as NSString)
        tlStoreReference(_tlObject, 32, baseMinAmount as NSString)
        tlStoreReference(_tlObject, 40, baseMaxAmount as NSString)
        tlStoreReference(_tlObject, 48, cryptoMinAmount as NSString)
        tlStoreReference(_tlObject, 56, cryptoMaxAmount as NSString)
        tlStoreReference(_tlObject, 64, paymentMethod as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum OnrampMethodAvailability: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_onrampMethodAvailability {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case onrampMethodAvailability(Cons_onrampMethodAvailability)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .onrampMethodAvailability(Cons_onrampMethodAvailability(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .onrampMethodAvailability(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.OnrampMethodAvailability] {
            return tlObjectsAt(object, offset).map { Api.OnrampMethodAvailability(tlObject: $0) }
        }

    }
}
public extension Api.OnrampMethodAvailability.Cons_onrampMethodAvailability {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var paymentMethod: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, paymentMethod: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1022))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, paymentMethod as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum OnrampProviderInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_onrampProviderInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case onrampProviderInfo(Cons_onrampProviderInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .onrampProviderInfo(Cons_onrampProviderInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .onrampProviderInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.OnrampProviderInfo] {
            return tlObjectsAt(object, offset).map { Api.OnrampProviderInfo(tlObject: $0) }
        }

    }
}
public extension Api.OnrampProviderInfo.Cons_onrampProviderInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var cryptoCurrencies: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 48) } }
    }
    init(flags: Int32, id: String, name: String, cryptoCurrencies: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(88))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStoreReference(_tlObject, 40, name as NSString)
        tlStoreReference(_tlObject, 48, cryptoCurrencies as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum OnrampQuote: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_onrampQuote {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case onrampQuote(Cons_onrampQuote)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .onrampQuote(Cons_onrampQuote(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .onrampQuote(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.OnrampQuote] {
            return tlObjectsAt(object, offset).map { Api.OnrampQuote(tlObject: $0) }
        }

    }
}
public extension Api.OnrampQuote.Cons_onrampQuote {
    @_alwaysEmitIntoClient var baseCurrency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var baseAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var cryptoCurrency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var cryptoAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var cryptoPrice: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var feeAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var extraFeeAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var networkFeeAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var totalAmount: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var paymentMethod: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 104) } }
    }
    @_alwaysEmitIntoClient var expiresDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(baseCurrency: String, baseAmount: String, cryptoCurrency: String, cryptoAmount: String, cryptoPrice: String, feeAmount: String, extraFeeAmount: String, networkFeeAmount: String, totalAmount: String, paymentMethod: String, expiresDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(782))
        tlStoreReference(_tlObject, 32, baseCurrency as NSString)
        tlStoreReference(_tlObject, 40, baseAmount as NSString)
        tlStoreReference(_tlObject, 48, cryptoCurrency as NSString)
        tlStoreReference(_tlObject, 56, cryptoAmount as NSString)
        tlStoreReference(_tlObject, 64, cryptoPrice as NSString)
        tlStoreReference(_tlObject, 72, feeAmount as NSString)
        tlStoreReference(_tlObject, 80, extraFeeAmount as NSString)
        tlStoreReference(_tlObject, 88, networkFeeAmount as NSString)
        tlStoreReference(_tlObject, 96, totalAmount as NSString)
        tlStoreReference(_tlObject, 104, paymentMethod as NSString)
        tlStore(_tlObject, 24, expiresDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum OnrampSession: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_onrampSession {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case onrampSession(Cons_onrampSession)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .onrampSession(Cons_onrampSession(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .onrampSession(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.OnrampSession] {
            return tlObjectsAt(object, offset).map { Api.OnrampSession(tlObject: $0) }
        }

    }
}
public extension Api.OnrampSession.Cons_onrampSession {
    @_alwaysEmitIntoClient var provider: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var sessionId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var expiresDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(provider: String, sessionId: String, url: String, expiresDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1376))
        tlStoreReference(_tlObject, 32, provider as NSString)
        tlStoreReference(_tlObject, 40, sessionId as NSString)
        tlStoreReference(_tlObject, 48, url as NSString)
        tlStore(_tlObject, 24, expiresDate)
        self.init(tlObject: _tlObject)
    }
}
