import TelegramApiObjC
public extension Api {
    enum InputPrivacyRule: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPrivacyValueAllowChatParticipants {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPrivacyValueAllowUsers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPrivacyValueDisallowChatParticipants {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPrivacyValueDisallowUsers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
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


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPrivacyValueAllowAll
            case 1:
                self = .inputPrivacyValueAllowBots
            case 2:
                self = .inputPrivacyValueAllowChatParticipants(Cons_inputPrivacyValueAllowChatParticipants(tlObject: object))
            case 3:
                self = .inputPrivacyValueAllowCloseFriends
            case 4:
                self = .inputPrivacyValueAllowContacts
            case 5:
                self = .inputPrivacyValueAllowPremium
            case 6:
                self = .inputPrivacyValueAllowUsers(Cons_inputPrivacyValueAllowUsers(tlObject: object))
            case 7:
                self = .inputPrivacyValueDisallowAll
            case 8:
                self = .inputPrivacyValueDisallowBots
            case 9:
                self = .inputPrivacyValueDisallowChatParticipants(Cons_inputPrivacyValueDisallowChatParticipants(tlObject: object))
            case 10:
                self = .inputPrivacyValueDisallowContacts
            case 11:
                self = .inputPrivacyValueDisallowUsers(Cons_inputPrivacyValueDisallowUsers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPrivacyValueAllowAll:
                return TLObjectSingleton(TLApiConstructorAt(158))
            case .inputPrivacyValueAllowBots:
                return TLObjectSingleton(TLApiConstructorAt(586))
            case .inputPrivacyValueAllowChatParticipants(let _data):
                return _data.tlObject
            case .inputPrivacyValueAllowCloseFriends:
                return TLObjectSingleton(TLApiConstructorAt(298))
            case .inputPrivacyValueAllowContacts:
                return TLObjectSingleton(TLApiConstructorAt(83))
            case .inputPrivacyValueAllowPremium:
                return TLObjectSingleton(TLApiConstructorAt(774))
            case .inputPrivacyValueAllowUsers(let _data):
                return _data.tlObject
            case .inputPrivacyValueDisallowAll:
                return TLObjectSingleton(TLApiConstructorAt(1412))
            case .inputPrivacyValueDisallowBots:
                return TLObjectSingleton(TLApiConstructorAt(1317))
            case .inputPrivacyValueDisallowChatParticipants(let _data):
                return _data.tlObject
            case .inputPrivacyValueDisallowContacts:
                return TLObjectSingleton(TLApiConstructorAt(76))
            case .inputPrivacyValueDisallowUsers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputPrivacyRule] {
            return tlObjectsAt(object, offset).map { Api.InputPrivacyRule(tlObject: $0) }
        }

    }
}
public extension Api.InputPrivacyRule.Cons_inputPrivacyValueAllowChatParticipants {
    @_alwaysEmitIntoClient var chats: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    init(chats: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(847))
        tlStoreReference(_tlObject, 24, tlPackInt64(chats) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPrivacyRule.Cons_inputPrivacyValueAllowUsers {
    @_alwaysEmitIntoClient var users: [Api.InputUser] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser.tlArray(self.tlObject, 24) } }
    }
    init(users: [Api.InputUser]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(117))
        tlStoreReference(_tlObject, 24, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPrivacyRule.Cons_inputPrivacyValueDisallowChatParticipants {
    @_alwaysEmitIntoClient var chats: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    init(chats: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1539))
        tlStoreReference(_tlObject, 24, tlPackInt64(chats) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputPrivacyRule.Cons_inputPrivacyValueDisallowUsers {
    @_alwaysEmitIntoClient var users: [Api.InputUser] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser.tlArray(self.tlObject, 24) } }
    }
    init(users: [Api.InputUser]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(922))
        tlStoreReference(_tlObject, 24, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputQuickReplyShortcut: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputQuickReplyShortcut {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputQuickReplyShortcutId {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputQuickReplyShortcut(Cons_inputQuickReplyShortcut)
        case inputQuickReplyShortcutId(Cons_inputQuickReplyShortcutId)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputQuickReplyShortcut(Cons_inputQuickReplyShortcut(tlObject: object))
            case 1:
                self = .inputQuickReplyShortcutId(Cons_inputQuickReplyShortcutId(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputQuickReplyShortcut(let _data):
                return _data.tlObject
            case .inputQuickReplyShortcutId(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputQuickReplyShortcut] {
            return tlObjectsAt(object, offset).map { Api.InputQuickReplyShortcut(tlObject: $0) }
        }

    }
}
public extension Api.InputQuickReplyShortcut.Cons_inputQuickReplyShortcut {
    @_alwaysEmitIntoClient var shortcut: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(shortcut: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(246))
        tlStoreReference(_tlObject, 24, shortcut as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputQuickReplyShortcut.Cons_inputQuickReplyShortcutId {
    @_alwaysEmitIntoClient var shortcutId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(shortcutId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(9))
        tlStore(_tlObject, 24, shortcutId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputReplyTo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputReplyToEphemeralMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputReplyToMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputReplyToMonoForum {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputReplyToStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputReplyToEphemeralMessage(Cons_inputReplyToEphemeralMessage)
        case inputReplyToMessage(Cons_inputReplyToMessage)
        case inputReplyToMonoForum(Cons_inputReplyToMonoForum)
        case inputReplyToStory(Cons_inputReplyToStory)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputReplyToEphemeralMessage(Cons_inputReplyToEphemeralMessage(tlObject: object))
            case 1:
                self = .inputReplyToMessage(Cons_inputReplyToMessage(tlObject: object))
            case 2:
                self = .inputReplyToMonoForum(Cons_inputReplyToMonoForum(tlObject: object))
            case 3:
                self = .inputReplyToStory(Cons_inputReplyToStory(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputReplyToEphemeralMessage(let _data):
                return _data.tlObject
            case .inputReplyToMessage(let _data):
                return _data.tlObject
            case .inputReplyToMonoForum(let _data):
                return _data.tlObject
            case .inputReplyToStory(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputReplyTo] {
            return tlObjectsAt(object, offset).map { Api.InputReplyTo(tlObject: $0) }
        }

    }
}
public extension Api.InputReplyTo.Cons_inputReplyToEphemeralMessage {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(421))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputReplyTo.Cons_inputReplyToMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var replyToMsgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var topMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var replyToPeerId: Api.InputPeer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var quoteText: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var quoteEntities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageEntity.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var quoteOffset: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var monoforumPeerId: Api.InputPeer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var todoItemId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var pollOption: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlBufferAt(self.tlObject, 80) } }
    }
    init(flags: Int32, replyToMsgId: Int32, topMsgId: Int32?, replyToPeerId: Api.InputPeer?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, monoforumPeerId: Api.InputPeer?, todoItemId: Int32?, pollOption: Buffer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(378))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, replyToMsgId)
        if let _tlValue = topMsgId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, replyToPeerId?.tlObject)
        tlStoreReference(_tlObject, 56, quoteText.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, quoteEntities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = quoteOffset { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 72, monoforumPeerId?.tlObject)
        if let _tlValue = todoItemId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 80, pollOption.map { value in value.makeData() as NSData })
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputReplyTo.Cons_inputReplyToMonoForum {
    @_alwaysEmitIntoClient var monoforumPeerId: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(monoforumPeerId: Api.InputPeer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(675))
        tlStoreReference(_tlObject, 24, monoforumPeerId.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputReplyTo.Cons_inputReplyToStory {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var storyId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.InputPeer, storyId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(577))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, storyId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputRichFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputRichFileDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputRichFilePhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputRichFileDocument(Cons_inputRichFileDocument)
        case inputRichFilePhoto(Cons_inputRichFilePhoto)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputRichFileDocument(Cons_inputRichFileDocument(tlObject: object))
            case 1:
                self = .inputRichFilePhoto(Cons_inputRichFilePhoto(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputRichFileDocument(let _data):
                return _data.tlObject
            case .inputRichFilePhoto(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputRichFile] {
            return tlObjectsAt(object, offset).map { Api.InputRichFile(tlObject: $0) }
        }

    }
}
public extension Api.InputRichFile.Cons_inputRichFileDocument {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var document: Api.InputDocument {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(id: String, document: Api.InputDocument) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(843))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, document.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputRichFile.Cons_inputRichFilePhoto {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var photo: Api.InputPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(id: String, photo: Api.InputPhoto) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1005))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, photo.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputRichMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputRichMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputRichMessageHTML {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputRichMessageMarkdown {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputRichMessage(Cons_inputRichMessage)
        case inputRichMessageHTML(Cons_inputRichMessageHTML)
        case inputRichMessageMarkdown(Cons_inputRichMessageMarkdown)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputRichMessage(Cons_inputRichMessage(tlObject: object))
            case 1:
                self = .inputRichMessageHTML(Cons_inputRichMessageHTML(tlObject: object))
            case 2:
                self = .inputRichMessageMarkdown(Cons_inputRichMessageMarkdown(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputRichMessage(let _data):
                return _data.tlObject
            case .inputRichMessageHTML(let _data):
                return _data.tlObject
            case .inputRichMessageMarkdown(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputRichMessage] {
            return tlObjectsAt(object, offset).map { Api.InputRichMessage(tlObject: $0) }
        }

    }
}
public extension Api.InputRichMessage.Cons_inputRichMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var photos: [Api.InputPhoto]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputPhoto.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.InputDocument]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputDocument.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.InputUser]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.InputUser.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, blocks: [Api.PageBlock], photos: [Api.InputPhoto]?, documents: [Api.InputDocument]?, users: [Api.InputUser]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1504))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, blocks.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, photos.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, documents.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, users.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputRichMessage.Cons_inputRichMessageHTML {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var html: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var files: [Api.InputRichFile]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputRichFile.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, html: String, files: [Api.InputRichFile]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1433))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, html as NSString)
        tlStoreReference(_tlObject, 40, files.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputRichMessage.Cons_inputRichMessageMarkdown {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var markdown: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var files: [Api.InputRichFile]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputRichFile.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, markdown: String, files: [Api.InputRichFile]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, markdown as NSString)
        tlStoreReference(_tlObject, 40, files.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputSavedStarGift: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputSavedStarGiftChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputSavedStarGiftSlug {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputSavedStarGiftUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputSavedStarGiftChat(Cons_inputSavedStarGiftChat)
        case inputSavedStarGiftSlug(Cons_inputSavedStarGiftSlug)
        case inputSavedStarGiftUser(Cons_inputSavedStarGiftUser)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputSavedStarGiftChat(Cons_inputSavedStarGiftChat(tlObject: object))
            case 1:
                self = .inputSavedStarGiftSlug(Cons_inputSavedStarGiftSlug(tlObject: object))
            case 2:
                self = .inputSavedStarGiftUser(Cons_inputSavedStarGiftUser(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputSavedStarGiftChat(let _data):
                return _data.tlObject
            case .inputSavedStarGiftSlug(let _data):
                return _data.tlObject
            case .inputSavedStarGiftUser(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputSavedStarGift] {
            return tlObjectsAt(object, offset).map { Api.InputSavedStarGift(tlObject: $0) }
        }

    }
}
public extension Api.InputSavedStarGift.Cons_inputSavedStarGiftChat {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var savedId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(peer: Api.InputPeer, savedId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1597))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, savedId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputSavedStarGift.Cons_inputSavedStarGiftSlug {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(224))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputSavedStarGift.Cons_inputSavedStarGiftUser {
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(msgId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(671))
        tlStore(_tlObject, 24, msgId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputSecureFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputSecureFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputSecureFileUploaded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputSecureFile(Cons_inputSecureFile)
        case inputSecureFileUploaded(Cons_inputSecureFileUploaded)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputSecureFile(Cons_inputSecureFile(tlObject: object))
            case 1:
                self = .inputSecureFileUploaded(Cons_inputSecureFileUploaded(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputSecureFile(let _data):
                return _data.tlObject
            case .inputSecureFileUploaded(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputSecureFile] {
            return tlObjectsAt(object, offset).map { Api.InputSecureFile(tlObject: $0) }
        }

    }
}
public extension Api.InputSecureFile.Cons_inputSecureFile {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(543))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputSecureFile.Cons_inputSecureFileUploaded {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var parts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var md5Checksum: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var fileHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var secret: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 56) } }
    }
    init(id: Int64, parts: Int32, md5Checksum: String, fileHash: Buffer, secret: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(323))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, parts)
        tlStoreReference(_tlObject, 40, md5Checksum as NSString)
        tlStoreReference(_tlObject, 48, fileHash.makeData() as NSData)
        tlStoreReference(_tlObject, 56, secret.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputSecureValue: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputSecureValue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputSecureValue(Cons_inputSecureValue)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputSecureValue(Cons_inputSecureValue(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputSecureValue(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputSecureValue] {
            return tlObjectsAt(object, offset).map { Api.InputSecureValue(tlObject: $0) }
        }

    }
}
public extension Api.InputSecureValue.Cons_inputSecureValue {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var type: Api.SecureValueType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueType(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var data: Api.SecureData? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.SecureData(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var frontSide: Api.InputSecureFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputSecureFile(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var reverseSide: Api.InputSecureFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.InputSecureFile(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var selfie: Api.InputSecureFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.InputSecureFile(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var translation: [Api.InputSecureFile]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.InputSecureFile.tlArray(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var files: [Api.InputSecureFile]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.InputSecureFile.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var plainData: Api.SecurePlainData? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.SecurePlainData(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    init(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.InputSecureFile?, reverseSide: Api.InputSecureFile?, selfie: Api.InputSecureFile?, translation: [Api.InputSecureFile]?, files: [Api.InputSecureFile]?, plainData: Api.SecurePlainData?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1436))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, type.tlObject)
        tlStoreReference(_tlObject, 40, data?.tlObject)
        tlStoreReference(_tlObject, 48, frontSide?.tlObject)
        tlStoreReference(_tlObject, 56, reverseSide?.tlObject)
        tlStoreReference(_tlObject, 64, selfie?.tlObject)
        tlStoreReference(_tlObject, 72, translation.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, files.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 88, plainData?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputSingleMedia: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputSingleMedia {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputSingleMedia(Cons_inputSingleMedia)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputSingleMedia(Cons_inputSingleMedia(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputSingleMedia(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputSingleMedia] {
            return tlObjectsAt(object, offset).map { Api.InputSingleMedia(tlObject: $0) }
        }

    }
}
public extension Api.InputSingleMedia.Cons_inputSingleMedia {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var media: Api.InputMedia {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputMedia(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.MessageEntity.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, media: Api.InputMedia, randomId: Int64, message: String, entities: [Api.MessageEntity]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(189))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, media.tlObject)
        tlStore(_tlObject, 40, randomId)
        tlStoreReference(_tlObject, 48, message as NSString)
        tlStoreReference(_tlObject, 56, entities.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputStarGiftAuction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputStarGiftAuction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStarGiftAuctionSlug {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputStarGiftAuction(Cons_inputStarGiftAuction)
        case inputStarGiftAuctionSlug(Cons_inputStarGiftAuctionSlug)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputStarGiftAuction(Cons_inputStarGiftAuction(tlObject: object))
            case 1:
                self = .inputStarGiftAuctionSlug(Cons_inputStarGiftAuctionSlug(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputStarGiftAuction(let _data):
                return _data.tlObject
            case .inputStarGiftAuctionSlug(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputStarGiftAuction] {
            return tlObjectsAt(object, offset).map { Api.InputStarGiftAuction(tlObject: $0) }
        }

    }
}
public extension Api.InputStarGiftAuction.Cons_inputStarGiftAuction {
    @_alwaysEmitIntoClient var giftId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(giftId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(20))
        tlStore(_tlObject, 24, giftId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStarGiftAuction.Cons_inputStarGiftAuctionSlug {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(791))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputStarsTransaction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputStarsTransaction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputStarsTransaction(Cons_inputStarsTransaction)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputStarsTransaction(Cons_inputStarsTransaction(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputStarsTransaction(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputStarsTransaction] {
            return tlObjectsAt(object, offset).map { Api.InputStarsTransaction(tlObject: $0) }
        }

    }
}
public extension Api.InputStarsTransaction.Cons_inputStarsTransaction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, id: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(223))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id as NSString)
        self.init(tlObject: _tlObject)
    }
}
