import TelegramApiObjC
public extension Api.bots {
    enum AccessSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_accessSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case accessSettings(Cons_accessSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .accessSettings(Cons_accessSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .accessSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.bots.AccessSettings] {
            return tlObjectsAt(object, offset).map { Api.bots.AccessSettings(tlObject: $0) }
        }

    }
}
public extension Api.bots.AccessSettings.Cons_accessSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var addUsers: [Api.User]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.User.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, addUsers: [Api.User]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1442))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, addUsers.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.bots {
    enum BotInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botInfo(Cons_botInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botInfo(Cons_botInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.bots.BotInfo] {
            return tlObjectsAt(object, offset).map { Api.bots.BotInfo(tlObject: $0) }
        }

    }
}
public extension Api.bots.BotInfo.Cons_botInfo {
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var about: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(name: String, about: String, description: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1520))
        tlStoreReference(_tlObject, 24, name as NSString)
        tlStoreReference(_tlObject, 32, about as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.bots {
    enum ExportedBotToken: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedBotToken {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedBotToken(Cons_exportedBotToken)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedBotToken(Cons_exportedBotToken(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedBotToken(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.bots.ExportedBotToken] {
            return tlObjectsAt(object, offset).map { Api.bots.ExportedBotToken(tlObject: $0) }
        }

    }
}
public extension Api.bots.ExportedBotToken.Cons_exportedBotToken {
    @_alwaysEmitIntoClient var token: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(token: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(388))
        tlStoreReference(_tlObject, 24, token as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.bots {
    enum PopularAppBots: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_popularAppBots {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case popularAppBots(Cons_popularAppBots)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .popularAppBots(Cons_popularAppBots(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .popularAppBots(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.bots.PopularAppBots] {
            return tlObjectsAt(object, offset).map { Api.bots.PopularAppBots(tlObject: $0) }
        }

    }
}
public extension Api.bots.PopularAppBots.Cons_popularAppBots {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, nextOffset: String?, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(169))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.bots {
    enum PreviewInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_previewInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case previewInfo(Cons_previewInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .previewInfo(Cons_previewInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .previewInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.bots.PreviewInfo] {
            return tlObjectsAt(object, offset).map { Api.bots.PreviewInfo(tlObject: $0) }
        }

    }
}
public extension Api.bots.PreviewInfo.Cons_previewInfo {
    @_alwaysEmitIntoClient var media: [Api.BotPreviewMedia] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BotPreviewMedia.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var langCodes: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 32) } }
    }
    init(media: [Api.BotPreviewMedia], langCodes: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(82))
        tlStoreReference(_tlObject, 24, media.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, langCodes as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.bots {
    enum RequestedButton: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_requestedButton {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case requestedButton(Cons_requestedButton)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .requestedButton(Cons_requestedButton(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .requestedButton(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.bots.RequestedButton] {
            return tlObjectsAt(object, offset).map { Api.bots.RequestedButton(tlObject: $0) }
        }

    }
}
public extension Api.bots.RequestedButton.Cons_requestedButton {
    @_alwaysEmitIntoClient var webappReqId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(webappReqId: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1585))
        tlStoreReference(_tlObject, 24, webappReqId as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.channels {
    enum AdminLogResults: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_adminLogResults {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case adminLogResults(Cons_adminLogResults)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .adminLogResults(Cons_adminLogResults(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .adminLogResults(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.channels.AdminLogResults] {
            return tlObjectsAt(object, offset).map { Api.channels.AdminLogResults(tlObject: $0) }
        }

    }
}
public extension Api.channels.AdminLogResults.Cons_adminLogResults {
    @_alwaysEmitIntoClient var events: [Api.ChannelAdminLogEvent] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelAdminLogEvent.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(events: [Api.ChannelAdminLogEvent], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1558))
        tlStoreReference(_tlObject, 24, events.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.channels {
    enum ChannelParticipant: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelParticipant {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelParticipant(Cons_channelParticipant)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelParticipant(Cons_channelParticipant(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelParticipant(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.channels.ChannelParticipant] {
            return tlObjectsAt(object, offset).map { Api.channels.ChannelParticipant(tlObject: $0) }
        }

    }
}
public extension Api.channels.ChannelParticipant.Cons_channelParticipant {
    @_alwaysEmitIntoClient var participant: Api.ChannelParticipant {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(participant: Api.ChannelParticipant, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1456))
        tlStoreReference(_tlObject, 24, participant.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.channels {
    enum ChannelParticipants: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelParticipants {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelParticipants(Cons_channelParticipants)
        case channelParticipantsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelParticipants(Cons_channelParticipants(tlObject: object))
            case 1:
                self = .channelParticipantsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelParticipants(let _data):
                return _data.tlObject
            case .channelParticipantsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1575))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.channels.ChannelParticipants] {
            return tlObjectsAt(object, offset).map { Api.channels.ChannelParticipants(tlObject: $0) }
        }

    }
}
public extension Api.channels.ChannelParticipants.Cons_channelParticipants {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var participants: [Api.ChannelParticipant] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChannelParticipant.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(count: Int32, participants: [Api.ChannelParticipant], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(994))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, participants.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.channels {
    enum SendAsPeers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sendAsPeers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sendAsPeers(Cons_sendAsPeers)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sendAsPeers(Cons_sendAsPeers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sendAsPeers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.channels.SendAsPeers] {
            return tlObjectsAt(object, offset).map { Api.channels.SendAsPeers(tlObject: $0) }
        }

    }
}
public extension Api.channels.SendAsPeers.Cons_sendAsPeers {
    @_alwaysEmitIntoClient var peers: [Api.SendAsPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SendAsPeer.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(peers: [Api.SendAsPeer], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1613))
        tlStoreReference(_tlObject, 24, peers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.channels {
    enum SponsoredMessageReportResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sponsoredMessageReportResultChooseOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sponsoredMessageReportResultAdsHidden
        case sponsoredMessageReportResultChooseOption(Cons_sponsoredMessageReportResultChooseOption)
        case sponsoredMessageReportResultReported


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sponsoredMessageReportResultAdsHidden
            case 1:
                self = .sponsoredMessageReportResultChooseOption(Cons_sponsoredMessageReportResultChooseOption(tlObject: object))
            case 2:
                self = .sponsoredMessageReportResultReported
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sponsoredMessageReportResultAdsHidden:
                return TLObjectSingleton(TLApiConstructorAt(404))
            case .sponsoredMessageReportResultChooseOption(let _data):
                return _data.tlObject
            case .sponsoredMessageReportResultReported:
                return TLObjectSingleton(TLApiConstructorAt(1122))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.channels.SponsoredMessageReportResult] {
            return tlObjectsAt(object, offset).map { Api.channels.SponsoredMessageReportResult(tlObject: $0) }
        }

    }
}
public extension Api.channels.SponsoredMessageReportResult.Cons_sponsoredMessageReportResultChooseOption {
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var options: [Api.SponsoredMessageReportOption] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SponsoredMessageReportOption.tlArray(self.tlObject, 32) } }
    }
    init(title: String, options: [Api.SponsoredMessageReportOption]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(840))
        tlStoreReference(_tlObject, 24, title as NSString)
        tlStoreReference(_tlObject, 32, options.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.chatlists {
    enum ChatlistInvite: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatlistInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatlistInviteAlready {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatlistInvite(Cons_chatlistInvite)
        case chatlistInviteAlready(Cons_chatlistInviteAlready)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatlistInvite(Cons_chatlistInvite(tlObject: object))
            case 1:
                self = .chatlistInviteAlready(Cons_chatlistInviteAlready(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatlistInvite(let _data):
                return _data.tlObject
            case .chatlistInviteAlready(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.chatlists.ChatlistInvite] {
            return tlObjectsAt(object, offset).map { Api.chatlists.ChatlistInvite(tlObject: $0) }
        }

    }
}
public extension Api.chatlists.ChatlistInvite.Cons_chatlistInvite {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var emoticon: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var peers: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, title: Api.TextWithEntities, emoticon: String?, peers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1583))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title.tlObject)
        tlStoreReference(_tlObject, 40, emoticon.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, peers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.chatlists.ChatlistInvite.Cons_chatlistInviteAlready {
    @_alwaysEmitIntoClient var filterId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var missingPeers: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var alreadyPeers: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(filterId: Int32, missingPeers: [Api.Peer], alreadyPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1653))
        tlStore(_tlObject, 24, filterId)
        tlStoreReference(_tlObject, 32, missingPeers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, alreadyPeers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.chatlists {
    enum ChatlistUpdates: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatlistUpdates {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatlistUpdates(Cons_chatlistUpdates)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatlistUpdates(Cons_chatlistUpdates(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatlistUpdates(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.chatlists.ChatlistUpdates] {
            return tlObjectsAt(object, offset).map { Api.chatlists.ChatlistUpdates(tlObject: $0) }
        }

    }
}
public extension Api.chatlists.ChatlistUpdates.Cons_chatlistUpdates {
    @_alwaysEmitIntoClient var missingPeers: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(missingPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(934))
        tlStoreReference(_tlObject, 24, missingPeers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.chatlists {
    enum ExportedChatlistInvite: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedChatlistInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedChatlistInvite(Cons_exportedChatlistInvite)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedChatlistInvite(Cons_exportedChatlistInvite(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedChatlistInvite(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.chatlists.ExportedChatlistInvite] {
            return tlObjectsAt(object, offset).map { Api.chatlists.ExportedChatlistInvite(tlObject: $0) }
        }

    }
}
public extension Api.chatlists.ExportedChatlistInvite.Cons_exportedChatlistInvite {
    @_alwaysEmitIntoClient var filter: Api.DialogFilter {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DialogFilter(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var invite: Api.ExportedChatlistInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatlistInvite(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(filter: Api.DialogFilter, invite: Api.ExportedChatlistInvite) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(103))
        tlStoreReference(_tlObject, 24, filter.tlObject)
        tlStoreReference(_tlObject, 32, invite.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.chatlists {
    enum ExportedInvites: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedInvites {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedInvites(Cons_exportedInvites)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedInvites(Cons_exportedInvites(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedInvites(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.chatlists.ExportedInvites] {
            return tlObjectsAt(object, offset).map { Api.chatlists.ExportedInvites(tlObject: $0) }
        }

    }
}
public extension Api.chatlists.ExportedInvites.Cons_exportedInvites {
    @_alwaysEmitIntoClient var invites: [Api.ExportedChatlistInvite] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatlistInvite.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(invites: [Api.ExportedChatlistInvite], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(102))
        tlStoreReference(_tlObject, 24, invites.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.communities {
    enum ParticipantJoinedChats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_participantJoinedChats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case participantJoinedChats(Cons_participantJoinedChats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .participantJoinedChats(Cons_participantJoinedChats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .participantJoinedChats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.communities.ParticipantJoinedChats] {
            return tlObjectsAt(object, offset).map { Api.communities.ParticipantJoinedChats(tlObject: $0) }
        }

    }
}
public extension Api.communities.ParticipantJoinedChats.Cons_participantJoinedChats {
    @_alwaysEmitIntoClient var creatorChatIds: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var joinedChatIds: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(creatorChatIds: [Int64], joinedChatIds: [Int64], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(899))
        tlStoreReference(_tlObject, 24, tlPackInt64(creatorChatIds) as NSData)
        tlStoreReference(_tlObject, 32, tlPackInt64(joinedChatIds) as NSData)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.communities {
    enum PeerLinkRequests: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerLinkRequests {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerLinkRequests(Cons_peerLinkRequests)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerLinkRequests(Cons_peerLinkRequests(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerLinkRequests(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.communities.PeerLinkRequests] {
            return tlObjectsAt(object, offset).map { Api.communities.PeerLinkRequests(tlObject: $0) }
        }

    }
}
public extension Api.communities.PeerLinkRequests.Cons_peerLinkRequests {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var totalCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var requests: [Api.CommunityPeerRequest] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.CommunityPeerRequest.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, totalCount: Int32, requests: [Api.CommunityPeerRequest], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(235))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, totalCount)
        tlStoreReference(_tlObject, 32, requests.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum Blocked: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_blocked {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_blockedSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case blocked(Cons_blocked)
        case blockedSlice(Cons_blockedSlice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .blocked(Cons_blocked(tlObject: object))
            case 1:
                self = .blockedSlice(Cons_blockedSlice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .blocked(let _data):
                return _data.tlObject
            case .blockedSlice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.Blocked] {
            return tlObjectsAt(object, offset).map { Api.contacts.Blocked(tlObject: $0) }
        }

    }
}
public extension Api.contacts.Blocked.Cons_blocked {
    @_alwaysEmitIntoClient var blocked: [Api.PeerBlocked] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerBlocked.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(73))
        tlStoreReference(_tlObject, 24, blocked.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts.Blocked.Cons_blockedSlice {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var blocked: [Api.PeerBlocked] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerBlocked.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(count: Int32, blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1468))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, blocked.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum ContactBirthdays: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_contactBirthdays {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case contactBirthdays(Cons_contactBirthdays)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .contactBirthdays(Cons_contactBirthdays(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .contactBirthdays(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.ContactBirthdays] {
            return tlObjectsAt(object, offset).map { Api.contacts.ContactBirthdays(tlObject: $0) }
        }

    }
}
public extension Api.contacts.ContactBirthdays.Cons_contactBirthdays {
    @_alwaysEmitIntoClient var contacts: [Api.ContactBirthday] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ContactBirthday.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(contacts: [Api.ContactBirthday], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(106))
        tlStoreReference(_tlObject, 24, contacts.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum Contacts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_contacts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case contacts(Cons_contacts)
        case contactsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .contacts(Cons_contacts(tlObject: object))
            case 1:
                self = .contactsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .contacts(let _data):
                return _data.tlObject
            case .contactsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1197))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.Contacts] {
            return tlObjectsAt(object, offset).map { Api.contacts.Contacts(tlObject: $0) }
        }

    }
}
public extension Api.contacts.Contacts.Cons_contacts {
    @_alwaysEmitIntoClient var contacts: [Api.Contact] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Contact.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var savedCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(contacts: [Api.Contact], savedCount: Int32, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1537))
        tlStoreReference(_tlObject, 32, contacts.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 24, savedCount)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum Found: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_found {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case found(Cons_found)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .found(Cons_found(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .found(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.Found] {
            return tlObjectsAt(object, offset).map { Api.contacts.Found(tlObject: $0) }
        }

    }
}
public extension Api.contacts.Found.Cons_found {
    @_alwaysEmitIntoClient var myResults: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var results: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(myResults: [Api.Peer], results: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1157))
        tlStoreReference(_tlObject, 24, myResults.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, results.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum ImportedContacts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_importedContacts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case importedContacts(Cons_importedContacts)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .importedContacts(Cons_importedContacts(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .importedContacts(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.ImportedContacts] {
            return tlObjectsAt(object, offset).map { Api.contacts.ImportedContacts(tlObject: $0) }
        }

    }
}
public extension Api.contacts.ImportedContacts.Cons_importedContacts {
    @_alwaysEmitIntoClient var imported: [Api.ImportedContact] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ImportedContact.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var popularInvites: [Api.PopularContact] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PopularContact.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var retryContacts: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(imported: [Api.ImportedContact], popularInvites: [Api.PopularContact], retryContacts: [Int64], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(769))
        tlStoreReference(_tlObject, 24, imported.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, popularInvites.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, tlPackInt64(retryContacts) as NSData)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum ResolvedPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_resolvedPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case resolvedPeer(Cons_resolvedPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .resolvedPeer(Cons_resolvedPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .resolvedPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.ResolvedPeer] {
            return tlObjectsAt(object, offset).map { Api.contacts.ResolvedPeer(tlObject: $0) }
        }

    }
}
public extension Api.contacts.ResolvedPeer.Cons_resolvedPeer {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(peer: Api.Peer, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(809))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum SponsoredPeers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sponsoredPeers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sponsoredPeers(Cons_sponsoredPeers)
        case sponsoredPeersEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sponsoredPeers(Cons_sponsoredPeers(tlObject: object))
            case 1:
                self = .sponsoredPeersEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sponsoredPeers(let _data):
                return _data.tlObject
            case .sponsoredPeersEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1535))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.SponsoredPeers] {
            return tlObjectsAt(object, offset).map { Api.contacts.SponsoredPeers(tlObject: $0) }
        }

    }
}
public extension Api.contacts.SponsoredPeers.Cons_sponsoredPeers {
    @_alwaysEmitIntoClient var peers: [Api.SponsoredPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SponsoredPeer.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(peers: [Api.SponsoredPeer], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1540))
        tlStoreReference(_tlObject, 24, peers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.contacts {
    enum TopPeers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_topPeers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case topPeers(Cons_topPeers)
        case topPeersDisabled
        case topPeersNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .topPeers(Cons_topPeers(tlObject: object))
            case 1:
                self = .topPeersDisabled
            case 2:
                self = .topPeersNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .topPeers(let _data):
                return _data.tlObject
            case .topPeersDisabled:
                return TLObjectSingleton(TLApiConstructorAt(1179))
            case .topPeersNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1447))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.contacts.TopPeers] {
            return tlObjectsAt(object, offset).map { Api.contacts.TopPeers(tlObject: $0) }
        }

    }
}
public extension Api.contacts.TopPeers.Cons_topPeers {
    @_alwaysEmitIntoClient var categories: [Api.TopPeerCategoryPeers] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TopPeerCategoryPeers.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(categories: [Api.TopPeerCategoryPeers], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(714))
        tlStoreReference(_tlObject, 24, categories.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ephemeral {
    enum WelcomeMessages: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_welcomeMessages {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case welcomeMessages(Cons_welcomeMessages)
        case welcomeMessagesNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .welcomeMessages(Cons_welcomeMessages(tlObject: object))
            case 1:
                self = .welcomeMessagesNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .welcomeMessages(let _data):
                return _data.tlObject
            case .welcomeMessagesNotModified:
                return TLObjectSingleton(TLApiConstructorAt(582))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ephemeral.WelcomeMessages] {
            return tlObjectsAt(object, offset).map { Api.ephemeral.WelcomeMessages(tlObject: $0) }
        }

    }
}
public extension Api.ephemeral.WelcomeMessages.Cons_welcomeMessages {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var messages: [Api.EphemeralMessage] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EphemeralMessage.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, messages: [Api.EphemeralMessage]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(99))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, messages.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
