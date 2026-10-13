import TelegramApiObjC
public extension Api {
    enum ChatAdminWithInvites: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatAdminWithInvites {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatAdminWithInvites(Cons_chatAdminWithInvites)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatAdminWithInvites(Cons_chatAdminWithInvites(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatAdminWithInvites(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatAdminWithInvites] {
            return tlObjectsAt(object, offset).map { Api.ChatAdminWithInvites(tlObject: $0) }
        }

    }
}
public extension Api.ChatAdminWithInvites.Cons_chatAdminWithInvites {
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var invitesCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var revokedInvitesCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(adminId: Int64, invitesCount: Int32, revokedInvitesCount: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1614))
        tlStore(_tlObject, 32, adminId)
        tlStore(_tlObject, 24, invitesCount)
        tlStore(_tlObject, 28, revokedInvitesCount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatBannedRights: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatBannedRights {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatBannedRights(Cons_chatBannedRights)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatBannedRights(Cons_chatBannedRights(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatBannedRights(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatBannedRights] {
            return tlObjectsAt(object, offset).map { Api.ChatBannedRights(tlObject: $0) }
        }

    }
}
public extension Api.ChatBannedRights.Cons_chatBannedRights {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var untilDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, untilDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1035))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, untilDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatFull: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelFull {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatFull {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_communityFull {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelFull(Cons_channelFull)
        case chatFull(Cons_chatFull)
        case communityFull(Cons_communityFull)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelFull(Cons_channelFull(tlObject: object))
            case 1:
                self = .chatFull(Cons_chatFull(tlObject: object))
            case 2:
                self = .communityFull(Cons_communityFull(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelFull(let _data):
                return _data.tlObject
            case .chatFull(let _data):
                return _data.tlObject
            case .communityFull(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatFull] {
            return tlObjectsAt(object, offset).map { Api.ChatFull(tlObject: $0) }
        }

    }
}
public extension Api.ChatFull.Cons_channelFull {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var flags2: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 120, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var about: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 128) } }
    }
    @_alwaysEmitIntoClient var participantsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var adminsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var kickedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var bannedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 3) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var onlineCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 4) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var readInboxMaxId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var readOutboxMaxId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 60, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var chatPhoto: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 136)) } }
    }
    @_alwaysEmitIntoClient var notifySettings: Api.PeerNotifySettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerNotifySettings(tlObject: tlObjectAt(self.tlObject, 144)) } }
    }
    @_alwaysEmitIntoClient var exportedInvite: Api.ExportedChatInvite? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var botInfo: [Api.BotInfo] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BotInfo.tlArray(self.tlObject, 160) } }
    }
    @_alwaysEmitIntoClient var migratedFromChatId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 5) ? tlBase(self.tlObject).load(fromByteOffset: 168, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var migratedFromMaxId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 6) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var pinnedMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 7) ? tlBase(self.tlObject).load(fromByteOffset: 68, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stickerset: Api.StickerSet? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 176) ? nil : Api.StickerSet(tlObject: tlObjectAt(self.tlObject, 176)) } }
    }
    @_alwaysEmitIntoClient var availableMinId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 8) ? tlBase(self.tlObject).load(fromByteOffset: 72, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var folderId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 9) ? tlBase(self.tlObject).load(fromByteOffset: 76, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var linkedChatId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 10) ? tlBase(self.tlObject).load(fromByteOffset: 184, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var location: Api.ChannelLocation? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 192) ? nil : Api.ChannelLocation(tlObject: tlObjectAt(self.tlObject, 192)) } }
    }
    @_alwaysEmitIntoClient var slowmodeSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 11) ? tlBase(self.tlObject).load(fromByteOffset: 80, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var slowmodeNextSendDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 12) ? tlBase(self.tlObject).load(fromByteOffset: 84, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var statsDc: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 13) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 92, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var call: Api.InputGroupCall? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 200) ? nil : Api.InputGroupCall(tlObject: tlObjectAt(self.tlObject, 200)) } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 14) ? tlBase(self.tlObject).load(fromByteOffset: 96, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var pendingSuggestions: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 208) ? nil : tlStringsAt(self.tlObject, 208) } }
    }
    @_alwaysEmitIntoClient var groupcallDefaultJoinAs: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 216) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 216)) } }
    }
    @_alwaysEmitIntoClient var themeEmoticon: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 224) ? nil : tlStringAt(self.tlObject, 224) } }
    }
    @_alwaysEmitIntoClient var requestsPending: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 15) ? tlBase(self.tlObject).load(fromByteOffset: 100, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var recentRequesters: [Int64]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 232) ? nil : tlInt64sAt(self.tlObject, 232) } }
    }
    @_alwaysEmitIntoClient var defaultSendAs: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 240) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 240)) } }
    }
    @_alwaysEmitIntoClient var availableReactions: Api.ChatReactions? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 248) ? nil : Api.ChatReactions(tlObject: tlObjectAt(self.tlObject, 248)) } }
    }
    @_alwaysEmitIntoClient var reactionsLimit: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 16) ? tlBase(self.tlObject).load(fromByteOffset: 104, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stories: Api.PeerStories? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 256) ? nil : Api.PeerStories(tlObject: tlObjectAt(self.tlObject, 256)) } }
    }
    @_alwaysEmitIntoClient var wallpaper: Api.WallPaper? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 264) ? nil : Api.WallPaper(tlObject: tlObjectAt(self.tlObject, 264)) } }
    }
    @_alwaysEmitIntoClient var boostsApplied: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 17) ? tlBase(self.tlObject).load(fromByteOffset: 108, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var boostsUnrestrict: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 18) ? tlBase(self.tlObject).load(fromByteOffset: 112, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var emojiset: Api.StickerSet? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 272) ? nil : Api.StickerSet(tlObject: tlObjectAt(self.tlObject, 272)) } }
    }
    @_alwaysEmitIntoClient var botVerification: Api.BotVerification? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 280) ? nil : Api.BotVerification(tlObject: tlObjectAt(self.tlObject, 280)) } }
    }
    @_alwaysEmitIntoClient var stargiftsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 19) ? tlBase(self.tlObject).load(fromByteOffset: 116, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var sendPaidMessagesStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 20) ? tlBase(self.tlObject).load(fromByteOffset: 288, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var mainTab: Api.ProfileTab? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 296) ? nil : Api.ProfileTab(tlObject: tlObjectAt(self.tlObject, 296)) } }
    }
    @_alwaysEmitIntoClient var guardBotId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 312, 21) ? tlBase(self.tlObject).load(fromByteOffset: 304, as: Int64.self) : nil } }
    }
    init(flags: Int32, flags2: Int32, id: Int64, about: String, participantsCount: Int32?, adminsCount: Int32?, kickedCount: Int32?, bannedCount: Int32?, onlineCount: Int32?, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, chatPhoto: Api.Photo, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo], migratedFromChatId: Int64?, migratedFromMaxId: Int32?, pinnedMsgId: Int32?, stickerset: Api.StickerSet?, availableMinId: Int32?, folderId: Int32?, linkedChatId: Int64?, location: Api.ChannelLocation?, slowmodeSeconds: Int32?, slowmodeNextSendDate: Int32?, statsDc: Int32?, pts: Int32, call: Api.InputGroupCall?, ttlPeriod: Int32?, pendingSuggestions: [String]?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, defaultSendAs: Api.Peer?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?, stories: Api.PeerStories?, wallpaper: Api.WallPaper?, boostsApplied: Int32?, boostsUnrestrict: Int32?, emojiset: Api.StickerSet?, botVerification: Api.BotVerification?, stargiftsCount: Int32?, sendPaidMessagesStars: Int64?, mainTab: Api.ProfileTab?, guardBotId: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1050))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, flags2)
        tlStore(_tlObject, 120, id)
        tlStoreReference(_tlObject, 128, about as NSString)
        if let _tlValue = participantsCount { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = adminsCount { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = kickedCount { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = bannedCount { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = onlineCount { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 4 }
        tlStore(_tlObject, 52, readInboxMaxId)
        tlStore(_tlObject, 56, readOutboxMaxId)
        tlStore(_tlObject, 60, unreadCount)
        tlStoreReference(_tlObject, 136, chatPhoto.tlObject)
        tlStoreReference(_tlObject, 144, notifySettings.tlObject)
        tlStoreReference(_tlObject, 152, exportedInvite?.tlObject)
        tlStoreReference(_tlObject, 160, botInfo.map { item in item.tlObject } as NSArray)
        if let _tlValue = migratedFromChatId { tlStore(_tlObject, 168, _tlValue); _tlPresent |= 1 << 5 }
        if let _tlValue = migratedFromMaxId { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 6 }
        if let _tlValue = pinnedMsgId { tlStore(_tlObject, 68, _tlValue); _tlPresent |= 1 << 7 }
        tlStoreReference(_tlObject, 176, stickerset?.tlObject)
        if let _tlValue = availableMinId { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 8 }
        if let _tlValue = folderId { tlStore(_tlObject, 76, _tlValue); _tlPresent |= 1 << 9 }
        if let _tlValue = linkedChatId { tlStore(_tlObject, 184, _tlValue); _tlPresent |= 1 << 10 }
        tlStoreReference(_tlObject, 192, location?.tlObject)
        if let _tlValue = slowmodeSeconds { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 11 }
        if let _tlValue = slowmodeNextSendDate { tlStore(_tlObject, 84, _tlValue); _tlPresent |= 1 << 12 }
        if let _tlValue = statsDc { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 13 }
        tlStore(_tlObject, 92, pts)
        tlStoreReference(_tlObject, 200, call?.tlObject)
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 96, _tlValue); _tlPresent |= 1 << 14 }
        tlStoreReference(_tlObject, 208, pendingSuggestions.map { value in value as NSArray })
        tlStoreReference(_tlObject, 216, groupcallDefaultJoinAs?.tlObject)
        tlStoreReference(_tlObject, 224, themeEmoticon.map { value in value as NSString })
        if let _tlValue = requestsPending { tlStore(_tlObject, 100, _tlValue); _tlPresent |= 1 << 15 }
        tlStoreReference(_tlObject, 232, recentRequesters.map { value in tlPackInt64(value) as NSData })
        tlStoreReference(_tlObject, 240, defaultSendAs?.tlObject)
        tlStoreReference(_tlObject, 248, availableReactions?.tlObject)
        if let _tlValue = reactionsLimit { tlStore(_tlObject, 104, _tlValue); _tlPresent |= 1 << 16 }
        tlStoreReference(_tlObject, 256, stories?.tlObject)
        tlStoreReference(_tlObject, 264, wallpaper?.tlObject)
        if let _tlValue = boostsApplied { tlStore(_tlObject, 108, _tlValue); _tlPresent |= 1 << 17 }
        if let _tlValue = boostsUnrestrict { tlStore(_tlObject, 112, _tlValue); _tlPresent |= 1 << 18 }
        tlStoreReference(_tlObject, 272, emojiset?.tlObject)
        tlStoreReference(_tlObject, 280, botVerification?.tlObject)
        if let _tlValue = stargiftsCount { tlStore(_tlObject, 116, _tlValue); _tlPresent |= 1 << 19 }
        if let _tlValue = sendPaidMessagesStars { tlStore(_tlObject, 288, _tlValue); _tlPresent |= 1 << 20 }
        tlStoreReference(_tlObject, 296, mainTab?.tlObject)
        if let _tlValue = guardBotId { tlStore(_tlObject, 304, _tlValue); _tlPresent |= 1 << 21 }
        tlStore(_tlObject, 312, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatFull.Cons_chatFull {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var about: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var participants: Api.ChatParticipants {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatParticipants(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var chatPhoto: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var notifySettings: Api.PeerNotifySettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerNotifySettings(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var exportedInvite: Api.ExportedChatInvite? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var botInfo: [Api.BotInfo]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.BotInfo.tlArray(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var pinnedMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 144, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var folderId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 144, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var call: Api.InputGroupCall? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.InputGroupCall(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 144, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var groupcallDefaultJoinAs: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    @_alwaysEmitIntoClient var themeEmoticon: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : tlStringAt(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var requestsPending: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 144, 3) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var recentRequesters: [Int64]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : tlInt64sAt(self.tlObject, 128) } }
    }
    @_alwaysEmitIntoClient var availableReactions: Api.ChatReactions? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : Api.ChatReactions(tlObject: tlObjectAt(self.tlObject, 136)) } }
    }
    @_alwaysEmitIntoClient var reactionsLimit: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 144, 4) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int64, about: String, participants: Api.ChatParticipants, chatPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo]?, pinnedMsgId: Int32?, folderId: Int32?, call: Api.InputGroupCall?, ttlPeriod: Int32?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(253))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 48, id)
        tlStoreReference(_tlObject, 56, about as NSString)
        tlStoreReference(_tlObject, 64, participants.tlObject)
        tlStoreReference(_tlObject, 72, chatPhoto?.tlObject)
        tlStoreReference(_tlObject, 80, notifySettings.tlObject)
        tlStoreReference(_tlObject, 88, exportedInvite?.tlObject)
        tlStoreReference(_tlObject, 96, botInfo.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = pinnedMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = folderId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 104, call?.tlObject)
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 112, groupcallDefaultJoinAs?.tlObject)
        tlStoreReference(_tlObject, 120, themeEmoticon.map { value in value as NSString })
        if let _tlValue = requestsPending { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 3 }
        tlStoreReference(_tlObject, 128, recentRequesters.map { value in tlPackInt64(value) as NSData })
        tlStoreReference(_tlObject, 136, availableReactions?.tlObject)
        if let _tlValue = reactionsLimit { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 4 }
        tlStore(_tlObject, 144, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatFull.Cons_communityFull {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var about: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chatPhoto: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var linkedPeers: [Api.CommunityPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.CommunityPeer.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var adminsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var kickedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var peerLinkRequestsPending: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int64, about: String, chatPhoto: Api.Photo, linkedPeers: [Api.CommunityPeer], adminsCount: Int32?, kickedCount: Int32?, peerLinkRequestsPending: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1357))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, id)
        tlStoreReference(_tlObject, 48, about as NSString)
        tlStoreReference(_tlObject, 56, chatPhoto.tlObject)
        tlStoreReference(_tlObject, 64, linkedPeers.map { item in item.tlObject } as NSArray)
        if let _tlValue = adminsCount { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = kickedCount { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = peerLinkRequestsPending { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum ChatInvite: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatInviteAlready {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatInvitePeek {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatInvite(Cons_chatInvite)
        case chatInviteAlready(Cons_chatInviteAlready)
        case chatInvitePeek(Cons_chatInvitePeek)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatInvite(Cons_chatInvite(tlObject: object))
            case 1:
                self = .chatInviteAlready(Cons_chatInviteAlready(tlObject: object))
            case 2:
                self = .chatInvitePeek(Cons_chatInvitePeek(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatInvite(let _data):
                return _data.tlObject
            case .chatInviteAlready(let _data):
                return _data.tlObject
            case .chatInvitePeek(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatInvite] {
            return tlObjectsAt(object, offset).map { Api.ChatInvite(tlObject: $0) }
        }

    }
}
public extension Api.ChatInvite.Cons_chatInvite {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var about: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var participantsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var participants: [Api.User]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.User.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var color: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var subscriptionPricing: Api.StarsSubscriptionPricing? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.StarsSubscriptionPricing(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var subscriptionFormId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var botVerification: Api.BotVerification? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.BotVerification(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    init(flags: Int32, title: String, about: String?, photo: Api.Photo, participantsCount: Int32, participants: [Api.User]?, color: Int32, subscriptionPricing: Api.StarsSubscriptionPricing?, subscriptionFormId: Int64?, botVerification: Api.BotVerification?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(594))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, about.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, photo.tlObject)
        tlStore(_tlObject, 28, participantsCount)
        tlStoreReference(_tlObject, 64, participants.map { value in value.map { item in item.tlObject } as NSArray })
        tlStore(_tlObject, 32, color)
        tlStoreReference(_tlObject, 72, subscriptionPricing?.tlObject)
        if let _tlValue = subscriptionFormId { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 88, botVerification?.tlObject)
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatInvite.Cons_chatInviteAlready {
    @_alwaysEmitIntoClient var chat: Api.Chat {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(chat: Api.Chat) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(588))
        tlStoreReference(_tlObject, 24, chat.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatInvite.Cons_chatInvitePeek {
    @_alwaysEmitIntoClient var chat: Api.Chat {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(chat: Api.Chat, expires: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(620))
        tlStoreReference(_tlObject, 32, chat.tlObject)
        tlStore(_tlObject, 24, expires)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatInviteImporter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatInviteImporter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatInviteImporter(Cons_chatInviteImporter)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatInviteImporter(Cons_chatInviteImporter(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatInviteImporter(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatInviteImporter] {
            return tlObjectsAt(object, offset).map { Api.ChatInviteImporter(tlObject: $0) }
        }

    }
}
public extension Api.ChatInviteImporter.Cons_chatInviteImporter {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var about: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var approvedBy: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    init(flags: Int32, userId: Int64, date: Int32, about: String?, approvedBy: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(899))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 40, about.map { value in value as NSString })
        if let _tlValue = approvedBy { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatOnlines: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatOnlines {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatOnlines(Cons_chatOnlines)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatOnlines(Cons_chatOnlines(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatOnlines(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatOnlines] {
            return tlObjectsAt(object, offset).map { Api.ChatOnlines(tlObject: $0) }
        }

    }
}
public extension Api.ChatOnlines.Cons_chatOnlines {
    @_alwaysEmitIntoClient var onlines: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(onlines: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1591))
        tlStore(_tlObject, 24, onlines)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatParticipant: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatParticipant {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatParticipantAdmin {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatParticipantCreator {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatParticipant(Cons_chatParticipant)
        case chatParticipantAdmin(Cons_chatParticipantAdmin)
        case chatParticipantCreator(Cons_chatParticipantCreator)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatParticipant(Cons_chatParticipant(tlObject: object))
            case 1:
                self = .chatParticipantAdmin(Cons_chatParticipantAdmin(tlObject: object))
            case 2:
                self = .chatParticipantCreator(Cons_chatParticipantCreator(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatParticipant(let _data):
                return _data.tlObject
            case .chatParticipantAdmin(let _data):
                return _data.tlObject
            case .chatParticipantCreator(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatParticipant] {
            return tlObjectsAt(object, offset).map { Api.ChatParticipant(tlObject: $0) }
        }

    }
}
public extension Api.ChatParticipant.Cons_chatParticipant {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var inviterId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(360))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 40, inviterId)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 48, rank.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatParticipant.Cons_chatParticipantAdmin {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var inviterId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(28))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 40, inviterId)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 48, rank.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatParticipant.Cons_chatParticipantCreator {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var rank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, userId: Int64, rank: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1488))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStoreReference(_tlObject, 40, rank.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatParticipants: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatParticipants {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatParticipantsForbidden {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatParticipants(Cons_chatParticipants)
        case chatParticipantsForbidden(Cons_chatParticipantsForbidden)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatParticipants(Cons_chatParticipants(tlObject: object))
            case 1:
                self = .chatParticipantsForbidden(Cons_chatParticipantsForbidden(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatParticipants(let _data):
                return _data.tlObject
            case .chatParticipantsForbidden(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatParticipants] {
            return tlObjectsAt(object, offset).map { Api.ChatParticipants(tlObject: $0) }
        }

    }
}
public extension Api.ChatParticipants.Cons_chatParticipants {
    @_alwaysEmitIntoClient var chatId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participants: [Api.ChatParticipant] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatParticipant.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(chatId: Int64, participants: [Api.ChatParticipant], version: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(388))
        tlStore(_tlObject, 32, chatId)
        tlStoreReference(_tlObject, 40, participants.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 24, version)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatParticipants.Cons_chatParticipantsForbidden {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var chatId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var selfParticipant: Api.ChatParticipant? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ChatParticipant(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, chatId: Int64, selfParticipant: Api.ChatParticipant?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(867))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, chatId)
        tlStoreReference(_tlObject, 40, selfParticipant?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatPhoto: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatPhoto(Cons_chatPhoto)
        case chatPhotoEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatPhoto(Cons_chatPhoto(tlObject: object))
            case 1:
                self = .chatPhotoEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatPhoto(let _data):
                return _data.tlObject
            case .chatPhotoEmpty:
                return TLObjectSingleton(TLApiConstructorAt(357))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatPhoto] {
            return tlObjectsAt(object, offset).map { Api.ChatPhoto(tlObject: $0) }
        }

    }
}
public extension Api.ChatPhoto.Cons_chatPhoto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var photoId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var strippedThumb: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(187))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, photoId)
        tlStoreReference(_tlObject, 40, strippedThumb.map { value in value.makeData() as NSData })
        tlStore(_tlObject, 28, dcId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatReactions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatReactionsAll {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatReactionsSome {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatReactionsAll(Cons_chatReactionsAll)
        case chatReactionsNone
        case chatReactionsSome(Cons_chatReactionsSome)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatReactionsAll(Cons_chatReactionsAll(tlObject: object))
            case 1:
                self = .chatReactionsNone
            case 2:
                self = .chatReactionsSome(Cons_chatReactionsSome(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatReactionsAll(let _data):
                return _data.tlObject
            case .chatReactionsNone:
                return TLObjectSingleton(TLApiConstructorAt(1552))
            case .chatReactionsSome(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatReactions] {
            return tlObjectsAt(object, offset).map { Api.ChatReactions(tlObject: $0) }
        }

    }
}
public extension Api.ChatReactions.Cons_chatReactionsAll {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(537))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatReactions.Cons_chatReactionsSome {
    @_alwaysEmitIntoClient var reactions: [Api.Reaction] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Reaction.tlArray(self.tlObject, 24) } }
    }
    init(reactions: [Api.Reaction]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(655))
        tlStoreReference(_tlObject, 24, reactions.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ChatTheme: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatTheme {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatThemeUniqueGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatTheme(Cons_chatTheme)
        case chatThemeUniqueGift(Cons_chatThemeUniqueGift)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatTheme(Cons_chatTheme(tlObject: object))
            case 1:
                self = .chatThemeUniqueGift(Cons_chatThemeUniqueGift(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatTheme(let _data):
                return _data.tlObject
            case .chatThemeUniqueGift(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ChatTheme] {
            return tlObjectsAt(object, offset).map { Api.ChatTheme(tlObject: $0) }
        }

    }
}
public extension Api.ChatTheme.Cons_chatTheme {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(emoticon: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1311))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ChatTheme.Cons_chatThemeUniqueGift {
    @_alwaysEmitIntoClient var gift: Api.StarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var themeSettings: [Api.ThemeSettings] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ThemeSettings.tlArray(self.tlObject, 32) } }
    }
    init(gift: Api.StarGift, themeSettings: [Api.ThemeSettings]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(333))
        tlStoreReference(_tlObject, 24, gift.tlObject)
        tlStoreReference(_tlObject, 32, themeSettings.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum CodeSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_codeSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case codeSettings(Cons_codeSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .codeSettings(Cons_codeSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .codeSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.CodeSettings] {
            return tlObjectsAt(object, offset).map { Api.CodeSettings(tlObject: $0) }
        }

    }
}
public extension Api.CodeSettings.Cons_codeSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var logoutTokens: [Buffer]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlBuffersAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var token: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var appSandbox: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, logoutTokens: [Buffer]?, token: String?, appSandbox: Api.Bool?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1129))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, logoutTokens.map { value in value.map { item in item.makeData() } as NSArray })
        tlStoreReference(_tlObject, 40, token.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, appSandbox?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum CommunityPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_communityPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case communityPeer(Cons_communityPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .communityPeer(Cons_communityPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .communityPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.CommunityPeer] {
            return tlObjectsAt(object, offset).map { Api.CommunityPeer(tlObject: $0) }
        }

    }
}
public extension Api.CommunityPeer.Cons_communityPeer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var visible: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, visible: Api.Bool?, peer: Api.Peer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(755))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, visible?.tlObject)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum CommunityPeerRequest: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_communityPeerRequest {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case communityPeerRequest(Cons_communityPeerRequest)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .communityPeerRequest(Cons_communityPeerRequest(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .communityPeerRequest(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.CommunityPeerRequest] {
            return tlObjectsAt(object, offset).map { Api.CommunityPeerRequest(tlObject: $0) }
        }

    }
}
public extension Api.CommunityPeerRequest.Cons_communityPeerRequest {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var requestedBy: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, peer: Api.Peer, requestedBy: Int64, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(797))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 40, requestedBy)
        tlStore(_tlObject, 28, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Config: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_config {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case config(Cons_config)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .config(Cons_config(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .config(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Config] {
            return tlObjectsAt(object, offset).map { Api.Config(tlObject: $0) }
        }

    }
}
public extension Api.Config.Cons_config {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var testMode: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var thisDc: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var dcOptions: [Api.DcOption] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DcOption.tlArray(self.tlObject, 160) } }
    }
    @_alwaysEmitIntoClient var dcTxtDomainName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 168) } }
    }
    @_alwaysEmitIntoClient var chatSizeMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var megagroupSizeMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var forwardedCountMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var onlineUpdatePeriodMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offlineBlurTimeoutMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offlineIdleTimeoutMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 60, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var onlineCloudTimeoutMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var notifyCloudDelayMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 68, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var notifyDefaultDelayMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 72, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pushChatPeriodMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 76, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pushChatLimit: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 80, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var editTimeLimit: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 84, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var revokeTimeLimit: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 88, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var revokePmTimeLimit: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 92, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ratingEDecay: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 96, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stickersRecentLimit: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 100, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var channelsReadMediaPeriod: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 104, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var tmpSessions: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 248, 0) ? tlBase(self.tlObject).load(fromByteOffset: 108, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var callReceiveTimeoutMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 112, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var callRingTimeoutMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 116, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var callConnectTimeoutMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 120, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var callPacketTimeoutMs: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 124, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var meUrlPrefix: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 176) } }
    }
    @_alwaysEmitIntoClient var autoupdateUrlPrefix: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 184) ? nil : tlStringAt(self.tlObject, 184) } }
    }
    @_alwaysEmitIntoClient var gifSearchUsername: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 192) ? nil : tlStringAt(self.tlObject, 192) } }
    }
    @_alwaysEmitIntoClient var venueSearchUsername: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 200) ? nil : tlStringAt(self.tlObject, 200) } }
    }
    @_alwaysEmitIntoClient var imgSearchUsername: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 208) ? nil : tlStringAt(self.tlObject, 208) } }
    }
    @_alwaysEmitIntoClient var staticMapsProvider: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 216) ? nil : tlStringAt(self.tlObject, 216) } }
    }
    @_alwaysEmitIntoClient var captionLengthMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 128, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var messageLengthMax: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 132, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var webfileDcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 136, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var suggestedLangCode: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 224) ? nil : tlStringAt(self.tlObject, 224) } }
    }
    @_alwaysEmitIntoClient var langPackVersion: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 248, 1) ? tlBase(self.tlObject).load(fromByteOffset: 140, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var baseLangPackVersion: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 248, 2) ? tlBase(self.tlObject).load(fromByteOffset: 144, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var reactionsDefault: Api.Reaction? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 232) ? nil : Api.Reaction(tlObject: tlObjectAt(self.tlObject, 232)) } }
    }
    @_alwaysEmitIntoClient var autologinToken: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 240) ? nil : tlStringAt(self.tlObject, 240) } }
    }
    init(flags: Int32, date: Int32, expires: Int32, testMode: Api.Bool, thisDc: Int32, dcOptions: [Api.DcOption], dcTxtDomainName: String, chatSizeMax: Int32, megagroupSizeMax: Int32, forwardedCountMax: Int32, onlineUpdatePeriodMs: Int32, offlineBlurTimeoutMs: Int32, offlineIdleTimeoutMs: Int32, onlineCloudTimeoutMs: Int32, notifyCloudDelayMs: Int32, notifyDefaultDelayMs: Int32, pushChatPeriodMs: Int32, pushChatLimit: Int32, editTimeLimit: Int32, revokeTimeLimit: Int32, revokePmTimeLimit: Int32, ratingEDecay: Int32, stickersRecentLimit: Int32, channelsReadMediaPeriod: Int32, tmpSessions: Int32?, callReceiveTimeoutMs: Int32, callRingTimeoutMs: Int32, callConnectTimeoutMs: Int32, callPacketTimeoutMs: Int32, meUrlPrefix: String, autoupdateUrlPrefix: String?, gifSearchUsername: String?, venueSearchUsername: String?, imgSearchUsername: String?, staticMapsProvider: String?, captionLengthMax: Int32, messageLengthMax: Int32, webfileDcId: Int32, suggestedLangCode: String?, langPackVersion: Int32?, baseLangPackVersion: Int32?, reactionsDefault: Api.Reaction?, autologinToken: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1362))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 32, expires)
        tlStoreReference(_tlObject, 152, testMode.tlObject)
        tlStore(_tlObject, 36, thisDc)
        tlStoreReference(_tlObject, 160, dcOptions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 168, dcTxtDomainName as NSString)
        tlStore(_tlObject, 40, chatSizeMax)
        tlStore(_tlObject, 44, megagroupSizeMax)
        tlStore(_tlObject, 48, forwardedCountMax)
        tlStore(_tlObject, 52, onlineUpdatePeriodMs)
        tlStore(_tlObject, 56, offlineBlurTimeoutMs)
        tlStore(_tlObject, 60, offlineIdleTimeoutMs)
        tlStore(_tlObject, 64, onlineCloudTimeoutMs)
        tlStore(_tlObject, 68, notifyCloudDelayMs)
        tlStore(_tlObject, 72, notifyDefaultDelayMs)
        tlStore(_tlObject, 76, pushChatPeriodMs)
        tlStore(_tlObject, 80, pushChatLimit)
        tlStore(_tlObject, 84, editTimeLimit)
        tlStore(_tlObject, 88, revokeTimeLimit)
        tlStore(_tlObject, 92, revokePmTimeLimit)
        tlStore(_tlObject, 96, ratingEDecay)
        tlStore(_tlObject, 100, stickersRecentLimit)
        tlStore(_tlObject, 104, channelsReadMediaPeriod)
        if let _tlValue = tmpSessions { tlStore(_tlObject, 108, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 112, callReceiveTimeoutMs)
        tlStore(_tlObject, 116, callRingTimeoutMs)
        tlStore(_tlObject, 120, callConnectTimeoutMs)
        tlStore(_tlObject, 124, callPacketTimeoutMs)
        tlStoreReference(_tlObject, 176, meUrlPrefix as NSString)
        tlStoreReference(_tlObject, 184, autoupdateUrlPrefix.map { value in value as NSString })
        tlStoreReference(_tlObject, 192, gifSearchUsername.map { value in value as NSString })
        tlStoreReference(_tlObject, 200, venueSearchUsername.map { value in value as NSString })
        tlStoreReference(_tlObject, 208, imgSearchUsername.map { value in value as NSString })
        tlStoreReference(_tlObject, 216, staticMapsProvider.map { value in value as NSString })
        tlStore(_tlObject, 128, captionLengthMax)
        tlStore(_tlObject, 132, messageLengthMax)
        tlStore(_tlObject, 136, webfileDcId)
        tlStoreReference(_tlObject, 224, suggestedLangCode.map { value in value as NSString })
        if let _tlValue = langPackVersion { tlStore(_tlObject, 140, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = baseLangPackVersion { tlStore(_tlObject, 144, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 232, reactionsDefault?.tlObject)
        tlStoreReference(_tlObject, 240, autologinToken.map { value in value as NSString })
        tlStore(_tlObject, 248, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ConnectedBot: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_connectedBot {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case connectedBot(Cons_connectedBot)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .connectedBot(Cons_connectedBot(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .connectedBot(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ConnectedBot] {
            return tlObjectsAt(object, offset).map { Api.ConnectedBot(tlObject: $0) }
        }

    }
}
public extension Api.ConnectedBot.Cons_connectedBot {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var recipients: Api.BusinessBotRecipients {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessBotRecipients(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var rights: Api.BusinessBotRights {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessBotRights(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var device: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var date: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var location: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    init(flags: Int32, botId: Int64, recipients: Api.BusinessBotRecipients, rights: Api.BusinessBotRights, device: String?, date: Int32?, location: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(25))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, botId)
        tlStoreReference(_tlObject, 40, recipients.tlObject)
        tlStoreReference(_tlObject, 48, rights.tlObject)
        tlStoreReference(_tlObject, 56, device.map { value in value as NSString })
        if let _tlValue = date { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, location.map { value in value as NSString })
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ConnectedBotStarRef: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_connectedBotStarRef {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case connectedBotStarRef(Cons_connectedBotStarRef)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .connectedBotStarRef(Cons_connectedBotStarRef(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .connectedBotStarRef(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ConnectedBotStarRef] {
            return tlObjectsAt(object, offset).map { Api.ConnectedBotStarRef(tlObject: $0) }
        }

    }
}
public extension Api.ConnectedBotStarRef.Cons_connectedBotStarRef {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var commissionPermille: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var durationMonths: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var participants: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var revenue: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    init(flags: Int32, url: String, date: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, participants: Int64, revenue: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(171))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, url as NSString)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 48, botId)
        tlStore(_tlObject, 32, commissionPermille)
        if let _tlValue = durationMonths { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, participants)
        tlStore(_tlObject, 64, revenue)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Contact: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_contact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case contact(Cons_contact)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .contact(Cons_contact(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .contact(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Contact] {
            return tlObjectsAt(object, offset).map { Api.Contact(tlObject: $0) }
        }

    }
}
public extension Api.Contact.Cons_contact {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var mutual: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(userId: Int64, mutual: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(124))
        tlStore(_tlObject, 24, userId)
        tlStoreReference(_tlObject, 32, mutual.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ContactBirthday: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_contactBirthday {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case contactBirthday(Cons_contactBirthday)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .contactBirthday(Cons_contactBirthday(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .contactBirthday(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ContactBirthday] {
            return tlObjectsAt(object, offset).map { Api.ContactBirthday(tlObject: $0) }
        }

    }
}
public extension Api.ContactBirthday.Cons_contactBirthday {
    @_alwaysEmitIntoClient var contactId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var birthday: Api.Birthday {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Birthday(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(contactId: Int64, birthday: Api.Birthday) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(196))
        tlStore(_tlObject, 24, contactId)
        tlStoreReference(_tlObject, 32, birthday.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ContactStatus: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_contactStatus {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case contactStatus(Cons_contactStatus)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .contactStatus(Cons_contactStatus(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .contactStatus(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ContactStatus] {
            return tlObjectsAt(object, offset).map { Api.ContactStatus(tlObject: $0) }
        }

    }
}
public extension Api.ContactStatus.Cons_contactStatus {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var status: Api.UserStatus {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.UserStatus(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(userId: Int64, status: Api.UserStatus) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(143))
        tlStore(_tlObject, 24, userId)
        tlStoreReference(_tlObject, 32, status.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum CurrencyRate: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_currencyRate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case currencyRate(Cons_currencyRate)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .currencyRate(Cons_currencyRate(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .currencyRate(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.CurrencyRate] {
            return tlObjectsAt(object, offset).map { Api.CurrencyRate(tlObject: $0) }
        }

    }
}
public extension Api.CurrencyRate.Cons_currencyRate {
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var rate: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    init(currency: String, rate: Double) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(308))
        tlStoreReference(_tlObject, 24, currency as NSString)
        tlStore(_tlObject, 32, rate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum DataJSON: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dataJSON {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dataJSON(Cons_dataJSON)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dataJSON(Cons_dataJSON(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dataJSON(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DataJSON] {
            return tlObjectsAt(object, offset).map { Api.DataJSON(tlObject: $0) }
        }

    }
}
public extension Api.DataJSON.Cons_dataJSON {
    @_alwaysEmitIntoClient var data: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(data: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(809))
        tlStoreReference(_tlObject, 24, data as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum DcOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dcOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dcOption(Cons_dcOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dcOption(Cons_dcOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dcOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DcOption] {
            return tlObjectsAt(object, offset).map { Api.DcOption(tlObject: $0) }
        }

    }
}
public extension Api.DcOption.Cons_dcOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ipAddress: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var port: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var secret: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlBufferAt(self.tlObject, 48) } }
    }
    init(flags: Int32, id: Int32, ipAddress: String, port: Int32, secret: Buffer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(161))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, ipAddress as NSString)
        tlStore(_tlObject, 32, port)
        tlStoreReference(_tlObject, 48, secret.map { value in value.makeData() as NSData })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum DefaultHistoryTTL: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_defaultHistoryTTL {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case defaultHistoryTTL(Cons_defaultHistoryTTL)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .defaultHistoryTTL(Cons_defaultHistoryTTL(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .defaultHistoryTTL(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DefaultHistoryTTL] {
            return tlObjectsAt(object, offset).map { Api.DefaultHistoryTTL(tlObject: $0) }
        }

    }
}
public extension Api.DefaultHistoryTTL.Cons_defaultHistoryTTL {
    @_alwaysEmitIntoClient var period: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(period: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(440))
        tlStore(_tlObject, 24, period)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum Dialog: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dialog {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dialogCommunity {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dialogFolder {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dialog(Cons_dialog)
        case dialogCommunity(Cons_dialogCommunity)
        case dialogFolder(Cons_dialogFolder)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dialog(Cons_dialog(tlObject: object))
            case 1:
                self = .dialogCommunity(Cons_dialogCommunity(tlObject: object))
            case 2:
                self = .dialogFolder(Cons_dialogFolder(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dialog(let _data):
                return _data.tlObject
            case .dialogCommunity(let _data):
                return _data.tlObject
            case .dialogFolder(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Dialog] {
            return tlObjectsAt(object, offset).map { Api.Dialog(tlObject: $0) }
        }

    }
}
public extension Api.Dialog.Cons_dialog {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var topMessage: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var readInboxMaxId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var readOutboxMaxId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadMentionsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadReactionsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadPollVotesCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var notifySettings: Api.PeerNotifySettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerNotifySettings(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var pts: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var draft: Api.DraftMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.DraftMessage(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var folderId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 1) ? tlBase(self.tlObject).load(fromByteOffset: 60, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 2) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int32.self) : nil } }
    }
    init(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, unreadPollVotesCount: Int32, notifySettings: Api.PeerNotifySettings, pts: Int32?, draft: Api.DraftMessage?, folderId: Int32?, ttlPeriod: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1687))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 72, peer.tlObject)
        tlStore(_tlObject, 28, topMessage)
        tlStore(_tlObject, 32, readInboxMaxId)
        tlStore(_tlObject, 36, readOutboxMaxId)
        tlStore(_tlObject, 40, unreadCount)
        tlStore(_tlObject, 44, unreadMentionsCount)
        tlStore(_tlObject, 48, unreadReactionsCount)
        tlStore(_tlObject, 52, unreadPollVotesCount)
        tlStoreReference(_tlObject, 80, notifySettings.tlObject)
        if let _tlValue = pts { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 88, draft?.tlObject)
        if let _tlValue = folderId { tlStore(_tlObject, 60, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Dialog.Cons_dialogCommunity {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var communityId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var notifySettings: Api.PeerNotifySettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerNotifySettings(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, communityId: Int64, notifySettings: Api.PeerNotifySettings) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1642))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, communityId)
        tlStoreReference(_tlObject, 40, notifySettings.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Dialog.Cons_dialogFolder {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var folder: Api.Folder {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Folder(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var topMessage: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadMutedPeersCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadUnmutedPeersCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadMutedMessagesCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadUnmutedMessagesCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    init(flags: Int32, folder: Api.Folder, peer: Api.Peer, topMessage: Int32, unreadMutedPeersCount: Int32, unreadUnmutedPeersCount: Int32, unreadMutedMessagesCount: Int32, unreadUnmutedMessagesCount: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(725))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, folder.tlObject)
        tlStoreReference(_tlObject, 56, peer.tlObject)
        tlStore(_tlObject, 28, topMessage)
        tlStore(_tlObject, 32, unreadMutedPeersCount)
        tlStore(_tlObject, 36, unreadUnmutedPeersCount)
        tlStore(_tlObject, 40, unreadMutedMessagesCount)
        tlStore(_tlObject, 44, unreadUnmutedMessagesCount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum DialogFilter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dialogFilter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dialogFilterChatlist {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dialogFilter(Cons_dialogFilter)
        case dialogFilterChatlist(Cons_dialogFilterChatlist)
        case dialogFilterDefault


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dialogFilter(Cons_dialogFilter(tlObject: object))
            case 1:
                self = .dialogFilterChatlist(Cons_dialogFilterChatlist(tlObject: object))
            case 2:
                self = .dialogFilterDefault
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dialogFilter(let _data):
                return _data.tlObject
            case .dialogFilterChatlist(let _data):
                return _data.tlObject
            case .dialogFilterDefault:
                return TLObjectSingleton(TLApiConstructorAt(344))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DialogFilter] {
            return tlObjectsAt(object, offset).map { Api.DialogFilter(tlObject: $0) }
        }

    }
}
public extension Api.DialogFilter.Cons_dialogFilter {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var emoticon: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var color: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var pinnedPeers: [Api.InputPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var includePeers: [Api.InputPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var excludePeers: [Api.InputPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer.tlArray(self.tlObject, 72) } }
    }
    init(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer], excludePeers: [Api.InputPeer]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1112))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, title.tlObject)
        tlStoreReference(_tlObject, 48, emoticon.map { value in value as NSString })
        if let _tlValue = color { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, pinnedPeers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, includePeers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, excludePeers.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DialogFilter.Cons_dialogFilterChatlist {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var emoticon: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var color: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var pinnedPeers: [Api.InputPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var includePeers: [Api.InputPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(963))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, title.tlObject)
        tlStoreReference(_tlObject, 48, emoticon.map { value in value as NSString })
        if let _tlValue = color { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, pinnedPeers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, includePeers.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
