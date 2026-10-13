import TelegramApiObjC
public extension Api {
    enum AccountDaysTTL: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_accountDaysTTL {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case accountDaysTTL(Cons_accountDaysTTL)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .accountDaysTTL(Cons_accountDaysTTL(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .accountDaysTTL(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AccountDaysTTL] {
            return tlObjectsAt(object, offset).map { Api.AccountDaysTTL(tlObject: $0) }
        }

    }
}
public extension Api.AccountDaysTTL.Cons_accountDaysTTL {
    @_alwaysEmitIntoClient var days: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(days: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1216))
        tlStore(_tlObject, 24, days)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AiComposeTone: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_aiComposeTone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_aiComposeToneDefault {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case aiComposeTone(Cons_aiComposeTone)
        case aiComposeToneDefault(Cons_aiComposeToneDefault)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .aiComposeTone(Cons_aiComposeTone(tlObject: object))
            case 1:
                self = .aiComposeToneDefault(Cons_aiComposeToneDefault(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .aiComposeTone(let _data):
                return _data.tlObject
            case .aiComposeToneDefault(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AiComposeTone] {
            return tlObjectsAt(object, offset).map { Api.AiComposeTone(tlObject: $0) }
        }

    }
}
public extension Api.AiComposeTone.Cons_aiComposeTone {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var emojiId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var prompt: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var installsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var authorId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 2) ? tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var exampleEnglish: Api.AiComposeToneExample? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.AiComposeToneExample(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, emojiId: Int64?, prompt: String?, installsCount: Int32?, authorId: Int64?, exampleEnglish: Api.AiComposeToneExample?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1379))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStoreReference(_tlObject, 48, slug as NSString)
        tlStoreReference(_tlObject, 56, title as NSString)
        if let _tlValue = emojiId { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 72, prompt.map { value in value as NSString })
        if let _tlValue = installsCount { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = authorId { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 88, exampleEnglish?.tlObject)
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.AiComposeTone.Cons_aiComposeToneDefault {
    @_alwaysEmitIntoClient var tone: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var emojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(tone: String, emojiId: Int64, title: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1009))
        tlStoreReference(_tlObject, 24, tone as NSString)
        tlStore(_tlObject, 32, emojiId)
        tlStoreReference(_tlObject, 40, title as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AiComposeToneExample: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_aiComposeToneExample {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case aiComposeToneExample(Cons_aiComposeToneExample)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .aiComposeToneExample(Cons_aiComposeToneExample(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .aiComposeToneExample(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AiComposeToneExample] {
            return tlObjectsAt(object, offset).map { Api.AiComposeToneExample(tlObject: $0) }
        }

    }
}
public extension Api.AiComposeToneExample.Cons_aiComposeToneExample {
    @_alwaysEmitIntoClient var from: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var to: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(from: Api.TextWithEntities, to: Api.TextWithEntities) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1607))
        tlStoreReference(_tlObject, 24, from.tlObject)
        tlStoreReference(_tlObject, 32, to.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AttachMenuBot: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_attachMenuBot {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case attachMenuBot(Cons_attachMenuBot)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .attachMenuBot(Cons_attachMenuBot(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .attachMenuBot(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AttachMenuBot] {
            return tlObjectsAt(object, offset).map { Api.AttachMenuBot(tlObject: $0) }
        }

    }
}
public extension Api.AttachMenuBot.Cons_attachMenuBot {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var peerTypes: [Api.AttachMenuPeerType]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.AttachMenuPeerType.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var icons: [Api.AttachMenuBotIcon] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AttachMenuBotIcon.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, botId: Int64, shortName: String, peerTypes: [Api.AttachMenuPeerType]?, icons: [Api.AttachMenuBotIcon]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1425))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, botId)
        tlStoreReference(_tlObject, 40, shortName as NSString)
        tlStoreReference(_tlObject, 48, peerTypes.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, icons.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AttachMenuBotIcon: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_attachMenuBotIcon {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case attachMenuBotIcon(Cons_attachMenuBotIcon)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .attachMenuBotIcon(Cons_attachMenuBotIcon(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .attachMenuBotIcon(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AttachMenuBotIcon] {
            return tlObjectsAt(object, offset).map { Api.AttachMenuBotIcon(tlObject: $0) }
        }

    }
}
public extension Api.AttachMenuBotIcon.Cons_attachMenuBotIcon {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var icon: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var colors: [Api.AttachMenuBotIconColor]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.AttachMenuBotIconColor.tlArray(self.tlObject, 48) } }
    }
    init(flags: Int32, name: String, icon: Api.Document, colors: [Api.AttachMenuBotIconColor]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1164))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, name as NSString)
        tlStoreReference(_tlObject, 40, icon.tlObject)
        tlStoreReference(_tlObject, 48, colors.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AttachMenuBotIconColor: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_attachMenuBotIconColor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case attachMenuBotIconColor(Cons_attachMenuBotIconColor)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .attachMenuBotIconColor(Cons_attachMenuBotIconColor(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .attachMenuBotIconColor(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AttachMenuBotIconColor] {
            return tlObjectsAt(object, offset).map { Api.AttachMenuBotIconColor(tlObject: $0) }
        }

    }
}
public extension Api.AttachMenuBotIconColor.Cons_attachMenuBotIconColor {
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var color: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(name: String, color: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(448))
        tlStoreReference(_tlObject, 32, name as NSString)
        tlStore(_tlObject, 24, color)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AttachMenuBots: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_attachMenuBots {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case attachMenuBots(Cons_attachMenuBots)
        case attachMenuBotsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .attachMenuBots(Cons_attachMenuBots(tlObject: object))
            case 1:
                self = .attachMenuBotsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .attachMenuBots(let _data):
                return _data.tlObject
            case .attachMenuBotsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1608))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AttachMenuBots] {
            return tlObjectsAt(object, offset).map { Api.AttachMenuBots(tlObject: $0) }
        }

    }
}
public extension Api.AttachMenuBots.Cons_attachMenuBots {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var bots: [Api.AttachMenuBot] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AttachMenuBot.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(hash: Int64, bots: [Api.AttachMenuBot], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(384))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, bots.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AttachMenuBotsBot: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_attachMenuBotsBot {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case attachMenuBotsBot(Cons_attachMenuBotsBot)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .attachMenuBotsBot(Cons_attachMenuBotsBot(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .attachMenuBotsBot(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AttachMenuBotsBot] {
            return tlObjectsAt(object, offset).map { Api.AttachMenuBotsBot(tlObject: $0) }
        }

    }
}
public extension Api.AttachMenuBotsBot.Cons_attachMenuBotsBot {
    @_alwaysEmitIntoClient var bot: Api.AttachMenuBot {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AttachMenuBot(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(bot: Api.AttachMenuBot, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(944))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AttachMenuPeerType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case attachMenuPeerTypeBotPM
        case attachMenuPeerTypeBroadcast
        case attachMenuPeerTypeChat
        case attachMenuPeerTypePM
        case attachMenuPeerTypeSameBotPM


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .attachMenuPeerTypeBotPM
            case 1:
                self = .attachMenuPeerTypeBroadcast
            case 2:
                self = .attachMenuPeerTypeChat
            case 3:
                self = .attachMenuPeerTypePM
            case 4:
                self = .attachMenuPeerTypeSameBotPM
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .attachMenuPeerTypeBotPM:
                return TLObjectSingleton(TLApiConstructorAt(1302))
            case .attachMenuPeerTypeBroadcast:
                return TLObjectSingleton(TLApiConstructorAt(799))
            case .attachMenuPeerTypeChat:
                return TLObjectSingleton(TLApiConstructorAt(34))
            case .attachMenuPeerTypePM:
                return TLObjectSingleton(TLApiConstructorAt(1602))
            case .attachMenuPeerTypeSameBotPM:
                return TLObjectSingleton(TLApiConstructorAt(808))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AttachMenuPeerType] {
            return tlObjectsAt(object, offset).map { Api.AttachMenuPeerType(tlObject: $0) }
        }

    }
}
public extension Api {
    enum AuctionBidLevel: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_auctionBidLevel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case auctionBidLevel(Cons_auctionBidLevel)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .auctionBidLevel(Cons_auctionBidLevel(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .auctionBidLevel(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AuctionBidLevel] {
            return tlObjectsAt(object, offset).map { Api.AuctionBidLevel(tlObject: $0) }
        }

    }
}
public extension Api.AuctionBidLevel.Cons_auctionBidLevel {
    @_alwaysEmitIntoClient var pos: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(pos: Int32, amount: Int64, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(310))
        tlStore(_tlObject, 24, pos)
        tlStore(_tlObject, 32, amount)
        tlStore(_tlObject, 28, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Authorization: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_authorization {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case authorization(Cons_authorization)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .authorization(Cons_authorization(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .authorization(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Authorization] {
            return tlObjectsAt(object, offset).map { Api.Authorization(tlObject: $0) }
        }

    }
}
public extension Api.Authorization.Cons_authorization {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var deviceModel: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var platform: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var systemVersion: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var apiId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var appName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var appVersion: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var dateCreated: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var dateActive: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ip: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var country: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var region: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 104) } }
    }
    init(flags: Int32, hash: Int64, deviceModel: String, platform: String, systemVersion: String, apiId: Int32, appName: String, appVersion: String, dateCreated: Int32, dateActive: Int32, ip: String, country: String, region: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1128))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, hash)
        tlStoreReference(_tlObject, 48, deviceModel as NSString)
        tlStoreReference(_tlObject, 56, platform as NSString)
        tlStoreReference(_tlObject, 64, systemVersion as NSString)
        tlStore(_tlObject, 28, apiId)
        tlStoreReference(_tlObject, 72, appName as NSString)
        tlStoreReference(_tlObject, 80, appVersion as NSString)
        tlStore(_tlObject, 32, dateCreated)
        tlStore(_tlObject, 36, dateActive)
        tlStoreReference(_tlObject, 88, ip as NSString)
        tlStoreReference(_tlObject, 96, country as NSString)
        tlStoreReference(_tlObject, 104, region as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AutoDownloadSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_autoDownloadSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case autoDownloadSettings(Cons_autoDownloadSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .autoDownloadSettings(Cons_autoDownloadSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .autoDownloadSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AutoDownloadSettings] {
            return tlObjectsAt(object, offset).map { Api.AutoDownloadSettings(tlObject: $0) }
        }

    }
}
public extension Api.AutoDownloadSettings.Cons_autoDownloadSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var photoSizeMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var videoSizeMax: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileSizeMax: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var videoUploadMaxbitrate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var smallQueueActiveOperationsMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var largeQueueActiveOperationsMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    init(flags: Int32, photoSizeMax: Int32, videoSizeMax: Int64, fileSizeMax: Int64, videoUploadMaxbitrate: Int32, smallQueueActiveOperationsMax: Int32, largeQueueActiveOperationsMax: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1228))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, photoSizeMax)
        tlStore(_tlObject, 48, videoSizeMax)
        tlStore(_tlObject, 56, fileSizeMax)
        tlStore(_tlObject, 32, videoUploadMaxbitrate)
        tlStore(_tlObject, 36, smallQueueActiveOperationsMax)
        tlStore(_tlObject, 40, largeQueueActiveOperationsMax)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AutoSaveException: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_autoSaveException {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case autoSaveException(Cons_autoSaveException)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .autoSaveException(Cons_autoSaveException(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .autoSaveException(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AutoSaveException] {
            return tlObjectsAt(object, offset).map { Api.AutoSaveException(tlObject: $0) }
        }

    }
}
public extension Api.AutoSaveException.Cons_autoSaveException {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var settings: Api.AutoSaveSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoSaveSettings(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(peer: Api.Peer, settings: Api.AutoSaveSettings) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(831))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, settings.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AutoSaveSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_autoSaveSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case autoSaveSettings(Cons_autoSaveSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .autoSaveSettings(Cons_autoSaveSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .autoSaveSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AutoSaveSettings] {
            return tlObjectsAt(object, offset).map { Api.AutoSaveSettings(tlObject: $0) }
        }

    }
}
public extension Api.AutoSaveSettings.Cons_autoSaveSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var videoMaxSize: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) : nil } }
    }
    init(flags: Int32, videoMaxSize: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1334))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = videoMaxSize { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AvailableEffect: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_availableEffect {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case availableEffect(Cons_availableEffect)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .availableEffect(Cons_availableEffect(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .availableEffect(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AvailableEffect] {
            return tlObjectsAt(object, offset).map { Api.AvailableEffect(tlObject: $0) }
        }

    }
}
public extension Api.AvailableEffect.Cons_availableEffect {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var staticIconId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var effectStickerId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var effectAnimationId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 1) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) : nil } }
    }
    init(flags: Int32, id: Int64, emoticon: String, staticIconId: Int64?, effectStickerId: Int64, effectAnimationId: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(945))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStoreReference(_tlObject, 40, emoticon as NSString)
        if let _tlValue = staticIconId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, effectStickerId)
        if let _tlValue = effectAnimationId { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum AvailableReaction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_availableReaction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case availableReaction(Cons_availableReaction)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .availableReaction(Cons_availableReaction(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .availableReaction(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.AvailableReaction] {
            return tlObjectsAt(object, offset).map { Api.AvailableReaction(tlObject: $0) }
        }

    }
}
public extension Api.AvailableReaction.Cons_availableReaction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reaction: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var staticIcon: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var appearAnimation: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var selectAnimation: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var activateAnimation: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var effectAnimation: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var aroundAnimation: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var centerIcon: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    init(flags: Int32, reaction: String, title: String, staticIcon: Api.Document, appearAnimation: Api.Document, selectAnimation: Api.Document, activateAnimation: Api.Document, effectAnimation: Api.Document, aroundAnimation: Api.Document?, centerIcon: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1282))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, reaction as NSString)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, staticIcon.tlObject)
        tlStoreReference(_tlObject, 56, appearAnimation.tlObject)
        tlStoreReference(_tlObject, 64, selectAnimation.tlObject)
        tlStoreReference(_tlObject, 72, activateAnimation.tlObject)
        tlStoreReference(_tlObject, 80, effectAnimation.tlObject)
        tlStoreReference(_tlObject, 88, aroundAnimation?.tlObject)
        tlStoreReference(_tlObject, 96, centerIcon?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BankCardOpenUrl: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_bankCardOpenUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case bankCardOpenUrl(Cons_bankCardOpenUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .bankCardOpenUrl(Cons_bankCardOpenUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .bankCardOpenUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BankCardOpenUrl] {
            return tlObjectsAt(object, offset).map { Api.BankCardOpenUrl(tlObject: $0) }
        }

    }
}
public extension Api.BankCardOpenUrl.Cons_bankCardOpenUrl {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(url: String, name: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1634))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStoreReference(_tlObject, 32, name as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BaseTheme: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case baseThemeArctic
        case baseThemeClassic
        case baseThemeDay
        case baseThemeNight
        case baseThemeTinted


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .baseThemeArctic
            case 1:
                self = .baseThemeClassic
            case 2:
                self = .baseThemeDay
            case 3:
                self = .baseThemeNight
            case 4:
                self = .baseThemeTinted
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .baseThemeArctic:
                return TLObjectSingleton(TLApiConstructorAt(589))
            case .baseThemeClassic:
                return TLObjectSingleton(TLApiConstructorAt(1309))
            case .baseThemeDay:
                return TLObjectSingleton(TLApiConstructorAt(1681))
            case .baseThemeNight:
                return TLObjectSingleton(TLApiConstructorAt(1209))
            case .baseThemeTinted:
                return TLObjectSingleton(TLApiConstructorAt(698))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BaseTheme] {
            return tlObjectsAt(object, offset).map { Api.BaseTheme(tlObject: $0) }
        }

    }
}
public extension Api {
    enum Birthday: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_birthday {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case birthday(Cons_birthday)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .birthday(Cons_birthday(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .birthday(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Birthday] {
            return tlObjectsAt(object, offset).map { Api.Birthday(tlObject: $0) }
        }

    }
}
public extension Api.Birthday.Cons_birthday {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var day: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var month: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var year: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, day: Int32, month: Int32, year: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(694))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, day)
        tlStore(_tlObject, 32, month)
        if let _tlValue = year { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Bool: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case boolFalse
        case boolTrue


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .boolFalse
            case 1:
                self = .boolTrue
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .boolFalse:
                return TLObjectSingleton(TLApiConstructorAt(1245))
            case .boolTrue:
                return TLObjectSingleton(TLApiConstructorAt(988))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Bool] {
            return tlObjectsAt(object, offset).map { Api.Bool(tlObject: $0) }
        }

    }
}
public extension Api {
    enum Boost: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_boost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case boost(Cons_boost)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .boost(Cons_boost(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .boost(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Boost] {
            return tlObjectsAt(object, offset).map { Api.Boost(tlObject: $0) }
        }

    }
}
public extension Api.Boost.Cons_boost {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var userId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var giveawayMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var usedGiftSlug: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var multiplier: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 3) ? tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) : nil } }
    }
    init(flags: Int32, id: String, userId: Int64?, giveawayMsgId: Int32?, date: Int32, expires: Int32, usedGiftSlug: String?, multiplier: Int32?, stars: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(483))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, id as NSString)
        if let _tlValue = userId { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = giveawayMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 36, expires)
        tlStoreReference(_tlObject, 64, usedGiftSlug.map { value in value as NSString })
        if let _tlValue = multiplier { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = stars { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 3 }
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotApp: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botApp {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botApp(Cons_botApp)
        case botAppNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botApp(Cons_botApp(tlObject: object))
            case 1:
                self = .botAppNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botApp(let _data):
                return _data.tlObject
            case .botAppNotModified:
                return TLObjectSingleton(TLApiConstructorAt(601))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotApp] {
            return tlObjectsAt(object, offset).map { Api.BotApp(tlObject: $0) }
        }

    }
}
public extension Api.BotApp.Cons_botApp {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?, hash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(960))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStoreReference(_tlObject, 48, shortName as NSString)
        tlStoreReference(_tlObject, 56, title as NSString)
        tlStoreReference(_tlObject, 64, description as NSString)
        tlStoreReference(_tlObject, 72, photo.tlObject)
        tlStoreReference(_tlObject, 80, document?.tlObject)
        tlStore(_tlObject, 88, hash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotAppSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botAppSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botAppSettings(Cons_botAppSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botAppSettings(Cons_botAppSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botAppSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotAppSettings] {
            return tlObjectsAt(object, offset).map { Api.BotAppSettings(tlObject: $0) }
        }

    }
}
public extension Api.BotAppSettings.Cons_botAppSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var placeholderPath: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlBufferAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var backgroundColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var backgroundDarkColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var headerColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var headerDarkColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 3) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    init(flags: Int32, placeholderPath: Buffer?, backgroundColor: Int32?, backgroundDarkColor: Int32?, headerColor: Int32?, headerDarkColor: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1340))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, placeholderPath.map { value in value.makeData() as NSData })
        if let _tlValue = backgroundColor { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = backgroundDarkColor { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = headerColor { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = headerDarkColor { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 3 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotBusinessConnection: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botBusinessConnection {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botBusinessConnection(Cons_botBusinessConnection)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botBusinessConnection(Cons_botBusinessConnection(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botBusinessConnection(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotBusinessConnection] {
            return tlObjectsAt(object, offset).map { Api.BotBusinessConnection(tlObject: $0) }
        }

    }
}
public extension Api.BotBusinessConnection.Cons_botBusinessConnection {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var connectionId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var rights: Api.BusinessBotRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.BusinessBotRights(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, connectionId: String, userId: Int64, dcId: Int32, date: Int32, rights: Api.BusinessBotRights?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(917))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, connectionId as NSString)
        tlStore(_tlObject, 48, userId)
        tlStore(_tlObject, 28, dcId)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 56, rights?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotCommand: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botCommand {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botCommand(Cons_botCommand)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botCommand(Cons_botCommand(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botCommand(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotCommand] {
            return tlObjectsAt(object, offset).map { Api.BotCommand(tlObject: $0) }
        }

    }
}
public extension Api.BotCommand.Cons_botCommand {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var command: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, command: String, description: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(975))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, command as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum BotCommandScope: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botCommandScopePeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botCommandScopePeerAdmins {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botCommandScopePeerUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botCommandScopeChatAdmins
        case botCommandScopeChats
        case botCommandScopeDefault
        case botCommandScopePeer(Cons_botCommandScopePeer)
        case botCommandScopePeerAdmins(Cons_botCommandScopePeerAdmins)
        case botCommandScopePeerUser(Cons_botCommandScopePeerUser)
        case botCommandScopeUsers


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botCommandScopeChatAdmins
            case 1:
                self = .botCommandScopeChats
            case 2:
                self = .botCommandScopeDefault
            case 3:
                self = .botCommandScopePeer(Cons_botCommandScopePeer(tlObject: object))
            case 4:
                self = .botCommandScopePeerAdmins(Cons_botCommandScopePeerAdmins(tlObject: object))
            case 5:
                self = .botCommandScopePeerUser(Cons_botCommandScopePeerUser(tlObject: object))
            case 6:
                self = .botCommandScopeUsers
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botCommandScopeChatAdmins:
                return TLObjectSingleton(TLApiConstructorAt(1224))
            case .botCommandScopeChats:
                return TLObjectSingleton(TLApiConstructorAt(713))
            case .botCommandScopeDefault:
                return TLObjectSingleton(TLApiConstructorAt(302))
            case .botCommandScopePeer(let _data):
                return _data.tlObject
            case .botCommandScopePeerAdmins(let _data):
                return _data.tlObject
            case .botCommandScopePeerUser(let _data):
                return _data.tlObject
            case .botCommandScopeUsers:
                return TLObjectSingleton(TLApiConstructorAt(385))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotCommandScope] {
            return tlObjectsAt(object, offset).map { Api.BotCommandScope(tlObject: $0) }
        }

    }
}
public extension Api.BotCommandScope.Cons_botCommandScopePeer {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.InputPeer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1440))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotCommandScope.Cons_botCommandScopePeerAdmins {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.InputPeer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(413))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotCommandScope.Cons_botCommandScopePeerUser {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var userId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(peer: Api.InputPeer, userId: Api.InputUser) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(65))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        self.init(tlObject: _tlObject)
    }
}
