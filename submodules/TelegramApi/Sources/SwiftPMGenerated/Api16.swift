import TelegramApiObjC
public extension Api {
    indirect enum MessageEntity: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputMessageEntityMentionName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityBankCard {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityBlockquote {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityBold {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityBotCommand {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityCashtag {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityCustomEmoji {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityDiffDelete {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityDiffInsert {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityDiffReplace {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityEmail {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityFormattedDate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityHashtag {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityItalic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityMention {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityMentionName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityPhone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityPre {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntitySpoiler {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityStrike {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityTextUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityTonAddress {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityUnderline {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityUnknown {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEntityUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputMessageEntityMentionName(Cons_inputMessageEntityMentionName)
        case messageEntityBankCard(Cons_messageEntityBankCard)
        case messageEntityBlockquote(Cons_messageEntityBlockquote)
        case messageEntityBold(Cons_messageEntityBold)
        case messageEntityBotCommand(Cons_messageEntityBotCommand)
        case messageEntityCashtag(Cons_messageEntityCashtag)
        case messageEntityCode(Cons_messageEntityCode)
        case messageEntityCustomEmoji(Cons_messageEntityCustomEmoji)
        case messageEntityDiffDelete(Cons_messageEntityDiffDelete)
        case messageEntityDiffInsert(Cons_messageEntityDiffInsert)
        case messageEntityDiffReplace(Cons_messageEntityDiffReplace)
        case messageEntityEmail(Cons_messageEntityEmail)
        case messageEntityFormattedDate(Cons_messageEntityFormattedDate)
        case messageEntityHashtag(Cons_messageEntityHashtag)
        case messageEntityItalic(Cons_messageEntityItalic)
        case messageEntityMention(Cons_messageEntityMention)
        case messageEntityMentionName(Cons_messageEntityMentionName)
        case messageEntityPhone(Cons_messageEntityPhone)
        case messageEntityPre(Cons_messageEntityPre)
        case messageEntitySpoiler(Cons_messageEntitySpoiler)
        case messageEntityStrike(Cons_messageEntityStrike)
        case messageEntityTextUrl(Cons_messageEntityTextUrl)
        case messageEntityTonAddress(Cons_messageEntityTonAddress)
        case messageEntityUnderline(Cons_messageEntityUnderline)
        case messageEntityUnknown(Cons_messageEntityUnknown)
        case messageEntityUrl(Cons_messageEntityUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputMessageEntityMentionName(Cons_inputMessageEntityMentionName(tlObject: object))
            case 1:
                self = .messageEntityBankCard(Cons_messageEntityBankCard(tlObject: object))
            case 2:
                self = .messageEntityBlockquote(Cons_messageEntityBlockquote(tlObject: object))
            case 3:
                self = .messageEntityBold(Cons_messageEntityBold(tlObject: object))
            case 4:
                self = .messageEntityBotCommand(Cons_messageEntityBotCommand(tlObject: object))
            case 5:
                self = .messageEntityCashtag(Cons_messageEntityCashtag(tlObject: object))
            case 6:
                self = .messageEntityCode(Cons_messageEntityCode(tlObject: object))
            case 7:
                self = .messageEntityCustomEmoji(Cons_messageEntityCustomEmoji(tlObject: object))
            case 8:
                self = .messageEntityDiffDelete(Cons_messageEntityDiffDelete(tlObject: object))
            case 9:
                self = .messageEntityDiffInsert(Cons_messageEntityDiffInsert(tlObject: object))
            case 10:
                self = .messageEntityDiffReplace(Cons_messageEntityDiffReplace(tlObject: object))
            case 11:
                self = .messageEntityEmail(Cons_messageEntityEmail(tlObject: object))
            case 12:
                self = .messageEntityFormattedDate(Cons_messageEntityFormattedDate(tlObject: object))
            case 13:
                self = .messageEntityHashtag(Cons_messageEntityHashtag(tlObject: object))
            case 14:
                self = .messageEntityItalic(Cons_messageEntityItalic(tlObject: object))
            case 15:
                self = .messageEntityMention(Cons_messageEntityMention(tlObject: object))
            case 16:
                self = .messageEntityMentionName(Cons_messageEntityMentionName(tlObject: object))
            case 17:
                self = .messageEntityPhone(Cons_messageEntityPhone(tlObject: object))
            case 18:
                self = .messageEntityPre(Cons_messageEntityPre(tlObject: object))
            case 19:
                self = .messageEntitySpoiler(Cons_messageEntitySpoiler(tlObject: object))
            case 20:
                self = .messageEntityStrike(Cons_messageEntityStrike(tlObject: object))
            case 21:
                self = .messageEntityTextUrl(Cons_messageEntityTextUrl(tlObject: object))
            case 22:
                self = .messageEntityTonAddress(Cons_messageEntityTonAddress(tlObject: object))
            case 23:
                self = .messageEntityUnderline(Cons_messageEntityUnderline(tlObject: object))
            case 24:
                self = .messageEntityUnknown(Cons_messageEntityUnknown(tlObject: object))
            case 25:
                self = .messageEntityUrl(Cons_messageEntityUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputMessageEntityMentionName(let _data):
                return _data.tlObject
            case .messageEntityBankCard(let _data):
                return _data.tlObject
            case .messageEntityBlockquote(let _data):
                return _data.tlObject
            case .messageEntityBold(let _data):
                return _data.tlObject
            case .messageEntityBotCommand(let _data):
                return _data.tlObject
            case .messageEntityCashtag(let _data):
                return _data.tlObject
            case .messageEntityCode(let _data):
                return _data.tlObject
            case .messageEntityCustomEmoji(let _data):
                return _data.tlObject
            case .messageEntityDiffDelete(let _data):
                return _data.tlObject
            case .messageEntityDiffInsert(let _data):
                return _data.tlObject
            case .messageEntityDiffReplace(let _data):
                return _data.tlObject
            case .messageEntityEmail(let _data):
                return _data.tlObject
            case .messageEntityFormattedDate(let _data):
                return _data.tlObject
            case .messageEntityHashtag(let _data):
                return _data.tlObject
            case .messageEntityItalic(let _data):
                return _data.tlObject
            case .messageEntityMention(let _data):
                return _data.tlObject
            case .messageEntityMentionName(let _data):
                return _data.tlObject
            case .messageEntityPhone(let _data):
                return _data.tlObject
            case .messageEntityPre(let _data):
                return _data.tlObject
            case .messageEntitySpoiler(let _data):
                return _data.tlObject
            case .messageEntityStrike(let _data):
                return _data.tlObject
            case .messageEntityTextUrl(let _data):
                return _data.tlObject
            case .messageEntityTonAddress(let _data):
                return _data.tlObject
            case .messageEntityUnderline(let _data):
                return _data.tlObject
            case .messageEntityUnknown(let _data):
                return _data.tlObject
            case .messageEntityUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageEntity] {
            return tlObjectsAt(object, offset).map { Api.MessageEntity(tlObject: $0) }
        }

    }
}
public extension Api.MessageEntity.Cons_inputMessageEntityMentionName {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(offset: Int32, length: Int32, userId: Api.InputUser) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(225))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityBankCard {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(756))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityBlockquote {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1606))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, offset)
        tlStore(_tlObject, 32, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityBold {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1249))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityBotCommand {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(697))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityCashtag {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(495))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityCode {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(263))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityCustomEmoji {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(offset: Int32, length: Int32, documentId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1336))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        tlStore(_tlObject, 32, documentId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityDiffDelete {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(43))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityDiffInsert {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(723))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityDiffReplace {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var oldText: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(offset: Int32, length: Int32, oldText: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1327))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        tlStoreReference(_tlObject, 32, oldText as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityEmail {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(646))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityFormattedDate {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(flags: Int32, offset: Int32, length: Int32, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(924))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, offset)
        tlStore(_tlObject, 32, length)
        tlStore(_tlObject, 36, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityHashtag {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(708))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityItalic {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(835))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityMention {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1663))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityMentionName {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(offset: Int32, length: Int32, userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1450))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        tlStore(_tlObject, 32, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityPhone {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1006))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityPre {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var language: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(offset: Int32, length: Int32, language: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(737))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        tlStoreReference(_tlObject, 32, language as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntitySpoiler {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(321))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityStrike {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1270))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityTextUrl {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(offset: Int32, length: Int32, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(762))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        tlStoreReference(_tlObject, 32, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityTonAddress {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1696))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityUnderline {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1013))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityUnknown {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1236))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageEntity.Cons_messageEntityUrl {
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(offset: Int32, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(704))
        tlStore(_tlObject, 24, offset)
        tlStore(_tlObject, 28, length)
        self.init(tlObject: _tlObject)
    }
}
