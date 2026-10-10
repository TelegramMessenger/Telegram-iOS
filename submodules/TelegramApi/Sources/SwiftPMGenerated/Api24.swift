import TelegramApiObjC
public extension Api {
    indirect enum RichText: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_textAnchor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textAutoEmail {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textAutoPhone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textAutoUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textBankCard {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textBold {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textBotCommand {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textButton {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textCashtag {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textConcat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textCustomEmoji {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textDate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textDiff {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textEmail {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textFixed {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textHashtag {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textImage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textItalic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textMarked {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textMath {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textMention {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textMentionName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textPhone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textPlain {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textSpoiler {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textStrike {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textSubscript {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textSuperscript {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textTonAddress {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textUnderline {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_textUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case textAnchor(Cons_textAnchor)
        case textAutoEmail(Cons_textAutoEmail)
        case textAutoPhone(Cons_textAutoPhone)
        case textAutoUrl(Cons_textAutoUrl)
        case textBankCard(Cons_textBankCard)
        case textBold(Cons_textBold)
        case textBotCommand(Cons_textBotCommand)
        case textButton(Cons_textButton)
        case textCashtag(Cons_textCashtag)
        case textConcat(Cons_textConcat)
        case textCustomEmoji(Cons_textCustomEmoji)
        case textDate(Cons_textDate)
        case textDiff(Cons_textDiff)
        case textEmail(Cons_textEmail)
        case textEmpty
        case textFixed(Cons_textFixed)
        case textHashtag(Cons_textHashtag)
        case textImage(Cons_textImage)
        case textItalic(Cons_textItalic)
        case textMarked(Cons_textMarked)
        case textMath(Cons_textMath)
        case textMention(Cons_textMention)
        case textMentionName(Cons_textMentionName)
        case textPhone(Cons_textPhone)
        case textPlain(Cons_textPlain)
        case textSpoiler(Cons_textSpoiler)
        case textStrike(Cons_textStrike)
        case textSubscript(Cons_textSubscript)
        case textSuperscript(Cons_textSuperscript)
        case textTonAddress(Cons_textTonAddress)
        case textUnderline(Cons_textUnderline)
        case textUrl(Cons_textUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .textAnchor(Cons_textAnchor(tlObject: object))
            case 1:
                self = .textAutoEmail(Cons_textAutoEmail(tlObject: object))
            case 2:
                self = .textAutoPhone(Cons_textAutoPhone(tlObject: object))
            case 3:
                self = .textAutoUrl(Cons_textAutoUrl(tlObject: object))
            case 4:
                self = .textBankCard(Cons_textBankCard(tlObject: object))
            case 5:
                self = .textBold(Cons_textBold(tlObject: object))
            case 6:
                self = .textBotCommand(Cons_textBotCommand(tlObject: object))
            case 7:
                self = .textButton(Cons_textButton(tlObject: object))
            case 8:
                self = .textCashtag(Cons_textCashtag(tlObject: object))
            case 9:
                self = .textConcat(Cons_textConcat(tlObject: object))
            case 10:
                self = .textCustomEmoji(Cons_textCustomEmoji(tlObject: object))
            case 11:
                self = .textDate(Cons_textDate(tlObject: object))
            case 12:
                self = .textDiff(Cons_textDiff(tlObject: object))
            case 13:
                self = .textEmail(Cons_textEmail(tlObject: object))
            case 14:
                self = .textEmpty
            case 15:
                self = .textFixed(Cons_textFixed(tlObject: object))
            case 16:
                self = .textHashtag(Cons_textHashtag(tlObject: object))
            case 17:
                self = .textImage(Cons_textImage(tlObject: object))
            case 18:
                self = .textItalic(Cons_textItalic(tlObject: object))
            case 19:
                self = .textMarked(Cons_textMarked(tlObject: object))
            case 20:
                self = .textMath(Cons_textMath(tlObject: object))
            case 21:
                self = .textMention(Cons_textMention(tlObject: object))
            case 22:
                self = .textMentionName(Cons_textMentionName(tlObject: object))
            case 23:
                self = .textPhone(Cons_textPhone(tlObject: object))
            case 24:
                self = .textPlain(Cons_textPlain(tlObject: object))
            case 25:
                self = .textSpoiler(Cons_textSpoiler(tlObject: object))
            case 26:
                self = .textStrike(Cons_textStrike(tlObject: object))
            case 27:
                self = .textSubscript(Cons_textSubscript(tlObject: object))
            case 28:
                self = .textSuperscript(Cons_textSuperscript(tlObject: object))
            case 29:
                self = .textTonAddress(Cons_textTonAddress(tlObject: object))
            case 30:
                self = .textUnderline(Cons_textUnderline(tlObject: object))
            case 31:
                self = .textUrl(Cons_textUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .textAnchor(let _data):
                return _data.tlObject
            case .textAutoEmail(let _data):
                return _data.tlObject
            case .textAutoPhone(let _data):
                return _data.tlObject
            case .textAutoUrl(let _data):
                return _data.tlObject
            case .textBankCard(let _data):
                return _data.tlObject
            case .textBold(let _data):
                return _data.tlObject
            case .textBotCommand(let _data):
                return _data.tlObject
            case .textButton(let _data):
                return _data.tlObject
            case .textCashtag(let _data):
                return _data.tlObject
            case .textConcat(let _data):
                return _data.tlObject
            case .textCustomEmoji(let _data):
                return _data.tlObject
            case .textDate(let _data):
                return _data.tlObject
            case .textDiff(let _data):
                return _data.tlObject
            case .textEmail(let _data):
                return _data.tlObject
            case .textEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1434))
            case .textFixed(let _data):
                return _data.tlObject
            case .textHashtag(let _data):
                return _data.tlObject
            case .textImage(let _data):
                return _data.tlObject
            case .textItalic(let _data):
                return _data.tlObject
            case .textMarked(let _data):
                return _data.tlObject
            case .textMath(let _data):
                return _data.tlObject
            case .textMention(let _data):
                return _data.tlObject
            case .textMentionName(let _data):
                return _data.tlObject
            case .textPhone(let _data):
                return _data.tlObject
            case .textPlain(let _data):
                return _data.tlObject
            case .textSpoiler(let _data):
                return _data.tlObject
            case .textStrike(let _data):
                return _data.tlObject
            case .textSubscript(let _data):
                return _data.tlObject
            case .textSuperscript(let _data):
                return _data.tlObject
            case .textTonAddress(let _data):
                return _data.tlObject
            case .textUnderline(let _data):
                return _data.tlObject
            case .textUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RichText] {
            return tlObjectsAt(object, offset).map { Api.RichText(tlObject: $0) }
        }

    }
}
public extension Api.RichText.Cons_textAnchor {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(text: Api.RichText, name: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(341))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, name as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textAutoEmail {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1310))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textAutoPhone {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(247))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textAutoUrl {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1115))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textBankCard {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1211))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textBold {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(658))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textBotCommand {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(21))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textButton {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var type: Api.InlineButtonType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InlineButtonType(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var style: Api.RichButtonStyle? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.RichButtonStyle(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, text: Api.RichText, type: Api.InlineButtonType, style: Api.RichButtonStyle?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1135))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        tlStoreReference(_tlObject, 40, type.tlObject)
        tlStoreReference(_tlObject, 48, style?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textCashtag {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(788))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textConcat {
    @_alwaysEmitIntoClient var texts: [Api.RichText] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText.tlArray(self.tlObject, 24) } }
    }
    init(texts: [Api.RichText]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(807))
        tlStoreReference(_tlObject, 24, texts.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textCustomEmoji {
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var alt: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(documentId: Int64, alt: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1053))
        tlStore(_tlObject, 24, documentId)
        tlStoreReference(_tlObject, 32, alt as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textDate {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, text: Api.RichText, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1075))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        tlStore(_tlObject, 28, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textDiff {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var oldText: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(text: Api.RichText, oldText: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(958))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, oldText.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textEmail {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var email: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(text: Api.RichText, email: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1451))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, email as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textFixed {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(687))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textHashtag {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(531))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textImage {
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(documentId: Int64, w: Int32, h: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(56))
        tlStore(_tlObject, 32, documentId)
        tlStore(_tlObject, 24, w)
        tlStore(_tlObject, 28, h)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textItalic {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1414))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textMarked {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(26))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textMath {
    @_alwaysEmitIntoClient var source: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(source: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1012))
        tlStoreReference(_tlObject, 24, source as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textMention {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1354))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textMentionName {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(text: Api.RichText, userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(11))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStore(_tlObject, 32, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textPhone {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var phone: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(text: Api.RichText, phone: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(190))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, phone as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textPlain {
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(736))
        tlStoreReference(_tlObject, 24, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textSpoiler {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(494))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textStrike {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1003))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textSubscript {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1556))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textSuperscript {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1321))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textTonAddress {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(390))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textUnderline {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1276))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RichText.Cons_textUrl {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var webpageId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(text: Api.RichText, url: String, webpageId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(383))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 40, webpageId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SavedContact: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedPhoneContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedPhoneContact(Cons_savedPhoneContact)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedPhoneContact(Cons_savedPhoneContact(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedPhoneContact(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SavedContact] {
            return tlObjectsAt(object, offset).map { Api.SavedContact(tlObject: $0) }
        }

    }
}
public extension Api.SavedContact.Cons_savedPhoneContact {
    @_alwaysEmitIntoClient var phone: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var firstName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var lastName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(phone: String, firstName: String, lastName: String, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(105))
        tlStoreReference(_tlObject, 32, phone as NSString)
        tlStoreReference(_tlObject, 40, firstName as NSString)
        tlStoreReference(_tlObject, 48, lastName as NSString)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum SavedDialog: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_monoForumDialog {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_savedDialog {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case monoForumDialog(Cons_monoForumDialog)
        case savedDialog(Cons_savedDialog)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .monoForumDialog(Cons_monoForumDialog(tlObject: object))
            case 1:
                self = .savedDialog(Cons_savedDialog(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .monoForumDialog(let _data):
                return _data.tlObject
            case .savedDialog(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SavedDialog] {
            return tlObjectsAt(object, offset).map { Api.SavedDialog(tlObject: $0) }
        }

    }
}
public extension Api.SavedDialog.Cons_monoForumDialog {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
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
    @_alwaysEmitIntoClient var unreadReactionsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var draft: Api.DraftMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.DraftMessage(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadReactionsCount: Int32, draft: Api.DraftMessage?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(639))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, peer.tlObject)
        tlStore(_tlObject, 28, topMessage)
        tlStore(_tlObject, 32, readInboxMaxId)
        tlStore(_tlObject, 36, readOutboxMaxId)
        tlStore(_tlObject, 40, unreadCount)
        tlStore(_tlObject, 44, unreadReactionsCount)
        tlStoreReference(_tlObject, 56, draft?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SavedDialog.Cons_savedDialog {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var topMessage: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, peer: Api.Peer, topMessage: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1242))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, topMessage)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SavedReactionTag: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedReactionTag {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedReactionTag(Cons_savedReactionTag)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedReactionTag(Cons_savedReactionTag(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedReactionTag(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SavedReactionTag] {
            return tlObjectsAt(object, offset).map { Api.SavedReactionTag(tlObject: $0) }
        }

    }
}
public extension Api.SavedReactionTag.Cons_savedReactionTag {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reaction: Api.Reaction {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Reaction(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, reaction: Api.Reaction, title: String?, count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1343))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, reaction.tlObject)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        tlStore(_tlObject, 28, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SavedStarGift: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedStarGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedStarGift(Cons_savedStarGift)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedStarGift(Cons_savedStarGift(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedStarGift(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SavedStarGift] {
            return tlObjectsAt(object, offset).map { Api.SavedStarGift(tlObject: $0) }
        }

    }
}
public extension Api.SavedStarGift.Cons_savedStarGift {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var gift: Api.StarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var savedId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 1) ? tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var convertStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 2) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var upgradeStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 3) ? tlBase(self.tlObject).load(fromByteOffset: 96, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var canExportAt: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 4) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var transferStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 5) ? tlBase(self.tlObject).load(fromByteOffset: 104, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var canTransferAt: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 6) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var canResellAt: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 7) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var collectionId: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlInt32sAt(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var prepaidUpgradeHash: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : tlStringAt(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var dropOriginalDetailsStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 8) ? tlBase(self.tlObject).load(fromByteOffset: 128, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var giftNum: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 9) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var canCraftAt: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 10) ? tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) : nil } }
    }
    init(flags: Int32, fromId: Api.Peer?, date: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, msgId: Int32?, savedId: Int64?, convertStars: Int64?, upgradeStars: Int64?, canExportAt: Int32?, transferStars: Int64?, canTransferAt: Int32?, canResellAt: Int32?, collectionId: [Int32]?, prepaidUpgradeHash: String?, dropOriginalDetailsStars: Int64?, giftNum: Int32?, canCraftAt: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(430))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 56, fromId?.tlObject)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 64, gift.tlObject)
        tlStoreReference(_tlObject, 72, message?.tlObject)
        if let _tlValue = msgId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = savedId { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = convertStars { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = upgradeStars { tlStore(_tlObject, 96, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = canExportAt { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = transferStars { tlStore(_tlObject, 104, _tlValue); _tlPresent |= 1 << 5 }
        if let _tlValue = canTransferAt { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 6 }
        if let _tlValue = canResellAt { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 7 }
        tlStoreReference(_tlObject, 112, collectionId.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 120, prepaidUpgradeHash.map { value in value as NSString })
        if let _tlValue = dropOriginalDetailsStars { tlStore(_tlObject, 128, _tlValue); _tlPresent |= 1 << 8 }
        if let _tlValue = giftNum { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 9 }
        if let _tlValue = canCraftAt { tlStore(_tlObject, 52, _tlValue); _tlPresent |= 1 << 10 }
        tlStore(_tlObject, 136, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SearchPostsFlood: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_searchPostsFlood {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case searchPostsFlood(Cons_searchPostsFlood)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .searchPostsFlood(Cons_searchPostsFlood(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .searchPostsFlood(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SearchPostsFlood] {
            return tlObjectsAt(object, offset).map { Api.SearchPostsFlood(tlObject: $0) }
        }

    }
}
public extension Api.SearchPostsFlood.Cons_searchPostsFlood {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var totalDaily: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var remains: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var waitTill: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var starsAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(flags: Int32, totalDaily: Int32, remains: Int32, waitTill: Int32?, starsAmount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(400))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, totalDaily)
        tlStore(_tlObject, 32, remains)
        if let _tlValue = waitTill { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, starsAmount)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SearchResultsCalendarPeriod: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_searchResultsCalendarPeriod {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case searchResultsCalendarPeriod(Cons_searchResultsCalendarPeriod)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .searchResultsCalendarPeriod(Cons_searchResultsCalendarPeriod(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .searchResultsCalendarPeriod(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SearchResultsCalendarPeriod] {
            return tlObjectsAt(object, offset).map { Api.SearchResultsCalendarPeriod(tlObject: $0) }
        }

    }
}
public extension Api.SearchResultsCalendarPeriod.Cons_searchResultsCalendarPeriod {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var minMsgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var maxMsgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(date: Int32, minMsgId: Int32, maxMsgId: Int32, count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1329))
        tlStore(_tlObject, 24, date)
        tlStore(_tlObject, 28, minMsgId)
        tlStore(_tlObject, 32, maxMsgId)
        tlStore(_tlObject, 36, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SearchResultsPosition: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_searchResultPosition {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case searchResultPosition(Cons_searchResultPosition)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .searchResultPosition(Cons_searchResultPosition(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .searchResultPosition(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SearchResultsPosition] {
            return tlObjectsAt(object, offset).map { Api.SearchResultsPosition(tlObject: $0) }
        }

    }
}
public extension Api.SearchResultsPosition.Cons_searchResultPosition {
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(msgId: Int32, date: Int32, offset: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(812))
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 32, offset)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecureCredentialsEncrypted: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_secureCredentialsEncrypted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case secureCredentialsEncrypted(Cons_secureCredentialsEncrypted)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secureCredentialsEncrypted(Cons_secureCredentialsEncrypted(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secureCredentialsEncrypted(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecureCredentialsEncrypted] {
            return tlObjectsAt(object, offset).map { Api.SecureCredentialsEncrypted(tlObject: $0) }
        }

    }
}
public extension Api.SecureCredentialsEncrypted.Cons_secureCredentialsEncrypted {
    @_alwaysEmitIntoClient var data: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var hash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var secret: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(data: Buffer, hash: Buffer, secret: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(329))
        tlStoreReference(_tlObject, 24, data.makeData() as NSData)
        tlStoreReference(_tlObject, 32, hash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, secret.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecureData: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_secureData {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case secureData(Cons_secureData)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secureData(Cons_secureData(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secureData(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecureData] {
            return tlObjectsAt(object, offset).map { Api.SecureData(tlObject: $0) }
        }

    }
}
public extension Api.SecureData.Cons_secureData {
    @_alwaysEmitIntoClient var data: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var dataHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var secret: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(data: Buffer, dataHash: Buffer, secret: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(882))
        tlStoreReference(_tlObject, 24, data.makeData() as NSData)
        tlStoreReference(_tlObject, 32, dataHash.makeData() as NSData)
        tlStoreReference(_tlObject, 40, secret.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecureFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_secureFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case secureFile(Cons_secureFile)
        case secureFileEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secureFile(Cons_secureFile(tlObject: object))
            case 1:
                self = .secureFileEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secureFile(let _data):
                return _data.tlObject
            case .secureFileEmpty:
                return TLObjectSingleton(TLApiConstructorAt(638))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecureFile] {
            return tlObjectsAt(object, offset).map { Api.SecureFile(tlObject: $0) }
        }

    }
}
public extension Api.SecureFile.Cons_secureFile {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var size: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fileHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var secret: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 64) } }
    }
    init(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, date: Int32, fileHash: Buffer, secret: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(797))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStore(_tlObject, 48, size)
        tlStore(_tlObject, 24, dcId)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 56, fileHash.makeData() as NSData)
        tlStoreReference(_tlObject, 64, secret.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecurePasswordKdfAlgo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_securePasswordKdfAlgoSHA512 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000)
        case securePasswordKdfAlgoSHA512(Cons_securePasswordKdfAlgoSHA512)
        case securePasswordKdfAlgoUnknown


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(tlObject: object))
            case 1:
                self = .securePasswordKdfAlgoSHA512(Cons_securePasswordKdfAlgoSHA512(tlObject: object))
            case 2:
                self = .securePasswordKdfAlgoUnknown
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let _data):
                return _data.tlObject
            case .securePasswordKdfAlgoSHA512(let _data):
                return _data.tlObject
            case .securePasswordKdfAlgoUnknown:
                return TLObjectSingleton(TLApiConstructorAt(0))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecurePasswordKdfAlgo] {
            return tlObjectsAt(object, offset).map { Api.SecurePasswordKdfAlgo(tlObject: $0) }
        }

    }
}
public extension Api.SecurePasswordKdfAlgo.Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000 {
    @_alwaysEmitIntoClient var salt: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    init(salt: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1231))
        tlStoreReference(_tlObject, 24, salt.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecurePasswordKdfAlgo.Cons_securePasswordKdfAlgoSHA512 {
    @_alwaysEmitIntoClient var salt: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    init(salt: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(851))
        tlStoreReference(_tlObject, 24, salt.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SecurePlainData: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_securePlainEmail {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_securePlainPhone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case securePlainEmail(Cons_securePlainEmail)
        case securePlainPhone(Cons_securePlainPhone)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .securePlainEmail(Cons_securePlainEmail(tlObject: object))
            case 1:
                self = .securePlainPhone(Cons_securePlainPhone(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .securePlainEmail(let _data):
                return _data.tlObject
            case .securePlainPhone(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SecurePlainData] {
            return tlObjectsAt(object, offset).map { Api.SecurePlainData(tlObject: $0) }
        }

    }
}
public extension Api.SecurePlainData.Cons_securePlainEmail {
    @_alwaysEmitIntoClient var email: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(email: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(232))
        tlStoreReference(_tlObject, 24, email as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.SecurePlainData.Cons_securePlainPhone {
    @_alwaysEmitIntoClient var phone: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(phone: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(799))
        tlStoreReference(_tlObject, 24, phone as NSString)
        self.init(tlObject: _tlObject)
    }
}
