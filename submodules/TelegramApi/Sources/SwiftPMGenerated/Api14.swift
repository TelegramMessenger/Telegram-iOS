import TelegramApiObjC
public extension Api {
    enum JSONObjectValue: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_jsonObjectValue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case jsonObjectValue(Cons_jsonObjectValue)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .jsonObjectValue(Cons_jsonObjectValue(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .jsonObjectValue(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.JSONObjectValue] {
            return tlObjectsAt(object, offset).map { Api.JSONObjectValue(tlObject: $0) }
        }

    }
}
public extension Api.JSONObjectValue.Cons_jsonObjectValue {
    @_alwaysEmitIntoClient var key: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var value: Api.JSONValue {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.JSONValue(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(key: String, value: Api.JSONValue) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1282))
        tlStoreReference(_tlObject, 24, key as NSString)
        tlStoreReference(_tlObject, 32, value.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum JSONValue: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_jsonArray {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_jsonBool {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_jsonNumber {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_jsonObject {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_jsonString {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case jsonArray(Cons_jsonArray)
        case jsonBool(Cons_jsonBool)
        case jsonNull
        case jsonNumber(Cons_jsonNumber)
        case jsonObject(Cons_jsonObject)
        case jsonString(Cons_jsonString)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .jsonArray(Cons_jsonArray(tlObject: object))
            case 1:
                self = .jsonBool(Cons_jsonBool(tlObject: object))
            case 2:
                self = .jsonNull
            case 3:
                self = .jsonNumber(Cons_jsonNumber(tlObject: object))
            case 4:
                self = .jsonObject(Cons_jsonObject(tlObject: object))
            case 5:
                self = .jsonString(Cons_jsonString(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .jsonArray(let _data):
                return _data.tlObject
            case .jsonBool(let _data):
                return _data.tlObject
            case .jsonNull:
                return TLObjectSingleton(TLApiConstructorAt(410))
            case .jsonNumber(let _data):
                return _data.tlObject
            case .jsonObject(let _data):
                return _data.tlObject
            case .jsonString(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.JSONValue] {
            return tlObjectsAt(object, offset).map { Api.JSONValue(tlObject: $0) }
        }

    }
}
public extension Api.JSONValue.Cons_jsonArray {
    @_alwaysEmitIntoClient var value: [Api.JSONValue] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.JSONValue.tlArray(self.tlObject, 24) } }
    }
    init(value: [Api.JSONValue]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1637))
        tlStoreReference(_tlObject, 24, value.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.JSONValue.Cons_jsonBool {
    @_alwaysEmitIntoClient var value: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(value: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1327))
        tlStoreReference(_tlObject, 24, value.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.JSONValue.Cons_jsonNumber {
    @_alwaysEmitIntoClient var value: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Double.self) } }
    }
    init(value: Double) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(277))
        tlStore(_tlObject, 24, value)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.JSONValue.Cons_jsonObject {
    @_alwaysEmitIntoClient var value: [Api.JSONObjectValue] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.JSONObjectValue.tlArray(self.tlObject, 24) } }
    }
    init(value: [Api.JSONObjectValue]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(989))
        tlStoreReference(_tlObject, 24, value.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.JSONValue.Cons_jsonString {
    @_alwaysEmitIntoClient var value: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(value: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1203))
        tlStoreReference(_tlObject, 24, value as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum JoinChatBotResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_joinChatBotResultWebView {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case joinChatBotResultApproved
        case joinChatBotResultDeclined
        case joinChatBotResultQueued
        case joinChatBotResultWebView(Cons_joinChatBotResultWebView)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .joinChatBotResultApproved
            case 1:
                self = .joinChatBotResultDeclined
            case 2:
                self = .joinChatBotResultQueued
            case 3:
                self = .joinChatBotResultWebView(Cons_joinChatBotResultWebView(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .joinChatBotResultApproved:
                return TLObjectSingleton(TLApiConstructorAt(1133))
            case .joinChatBotResultDeclined:
                return TLObjectSingleton(TLApiConstructorAt(98))
            case .joinChatBotResultQueued:
                return TLObjectSingleton(TLApiConstructorAt(980))
            case .joinChatBotResultWebView(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.JoinChatBotResult] {
            return tlObjectsAt(object, offset).map { Api.JoinChatBotResult(tlObject: $0) }
        }

    }
}
public extension Api.JoinChatBotResult.Cons_joinChatBotResultWebView {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1412))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum KeyboardButton: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_keyboardButton {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case keyboardButton(Cons_keyboardButton)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .keyboardButton(Cons_keyboardButton(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .keyboardButton(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.KeyboardButton] {
            return tlObjectsAt(object, offset).map { Api.KeyboardButton(tlObject: $0) }
        }

    }
}
public extension Api.KeyboardButton.Cons_keyboardButton {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var style: Api.KeyboardButtonStyle? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.KeyboardButtonStyle(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var type: Api.ButtonType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ButtonType(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, style: Api.KeyboardButtonStyle?, text: String, type: Api.ButtonType) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(301))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, style?.tlObject)
        tlStoreReference(_tlObject, 40, text as NSString)
        tlStoreReference(_tlObject, 48, type.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum KeyboardButtonRow: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_keyboardButtonRow {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case keyboardButtonRow(Cons_keyboardButtonRow)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .keyboardButtonRow(Cons_keyboardButtonRow(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .keyboardButtonRow(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.KeyboardButtonRow] {
            return tlObjectsAt(object, offset).map { Api.KeyboardButtonRow(tlObject: $0) }
        }

    }
}
public extension Api.KeyboardButtonRow.Cons_keyboardButtonRow {
    @_alwaysEmitIntoClient var buttons: [Api.KeyboardButton] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.KeyboardButton.tlArray(self.tlObject, 24) } }
    }
    init(buttons: [Api.KeyboardButton]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(766))
        tlStoreReference(_tlObject, 24, buttons.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum KeyboardButtonStyle: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_keyboardButtonStyle {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case keyboardButtonStyle(Cons_keyboardButtonStyle)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .keyboardButtonStyle(Cons_keyboardButtonStyle(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .keyboardButtonStyle(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.KeyboardButtonStyle] {
            return tlObjectsAt(object, offset).map { Api.KeyboardButtonStyle(tlObject: $0) }
        }

    }
}
public extension Api.KeyboardButtonStyle.Cons_keyboardButtonStyle {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var icon: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) : nil } }
    }
    init(flags: Int32, icon: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(517))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = icon { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum KeyboardInlineButton: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_keyboardInlineButton {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case keyboardInlineButton(Cons_keyboardInlineButton)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .keyboardInlineButton(Cons_keyboardInlineButton(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .keyboardInlineButton(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.KeyboardInlineButton] {
            return tlObjectsAt(object, offset).map { Api.KeyboardInlineButton(tlObject: $0) }
        }

    }
}
public extension Api.KeyboardInlineButton.Cons_keyboardInlineButton {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var style: Api.KeyboardButtonStyle? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.KeyboardButtonStyle(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var type: Api.InlineButtonType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InlineButtonType(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, style: Api.KeyboardButtonStyle?, text: String, type: Api.InlineButtonType) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(111))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, style?.tlObject)
        tlStoreReference(_tlObject, 40, text as NSString)
        tlStoreReference(_tlObject, 48, type.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum KeyboardInlineButtonRow: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_keyboardInlineButtonRow {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case keyboardInlineButtonRow(Cons_keyboardInlineButtonRow)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .keyboardInlineButtonRow(Cons_keyboardInlineButtonRow(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .keyboardInlineButtonRow(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.KeyboardInlineButtonRow] {
            return tlObjectsAt(object, offset).map { Api.KeyboardInlineButtonRow(tlObject: $0) }
        }

    }
}
public extension Api.KeyboardInlineButtonRow.Cons_keyboardInlineButtonRow {
    @_alwaysEmitIntoClient var buttons: [Api.KeyboardInlineButton] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.KeyboardInlineButton.tlArray(self.tlObject, 24) } }
    }
    init(buttons: [Api.KeyboardInlineButton]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(167))
        tlStoreReference(_tlObject, 24, buttons.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum LabeledPrice: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_labeledPrice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case labeledPrice(Cons_labeledPrice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .labeledPrice(Cons_labeledPrice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .labeledPrice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.LabeledPrice] {
            return tlObjectsAt(object, offset).map { Api.LabeledPrice(tlObject: $0) }
        }

    }
}
public extension Api.LabeledPrice.Cons_labeledPrice {
    @_alwaysEmitIntoClient var label: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(label: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1350))
        tlStoreReference(_tlObject, 24, label as NSString)
        tlStore(_tlObject, 32, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum LangPackDifference: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_langPackDifference {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case langPackDifference(Cons_langPackDifference)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .langPackDifference(Cons_langPackDifference(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .langPackDifference(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.LangPackDifference] {
            return tlObjectsAt(object, offset).map { Api.LangPackDifference(tlObject: $0) }
        }

    }
}
public extension Api.LangPackDifference.Cons_langPackDifference {
    @_alwaysEmitIntoClient var langCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var fromVersion: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var strings: [Api.LangPackString] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.LangPackString.tlArray(self.tlObject, 40) } }
    }
    init(langCode: String, fromVersion: Int32, version: Int32, strings: [Api.LangPackString]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1615))
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStore(_tlObject, 24, fromVersion)
        tlStore(_tlObject, 28, version)
        tlStoreReference(_tlObject, 40, strings.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum LangPackLanguage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_langPackLanguage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case langPackLanguage(Cons_langPackLanguage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .langPackLanguage(Cons_langPackLanguage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .langPackLanguage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.LangPackLanguage] {
            return tlObjectsAt(object, offset).map { Api.LangPackLanguage(tlObject: $0) }
        }

    }
}
public extension Api.LangPackLanguage.Cons_langPackLanguage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var nativeName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var langCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var baseLangCode: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var pluralCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var stringsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var translatedCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var translationsUrl: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 80) } }
    }
    init(flags: Int32, name: String, nativeName: String, langCode: String, baseLangCode: String?, pluralCode: String, stringsCount: Int32, translatedCount: Int32, translationsUrl: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1582))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, name as NSString)
        tlStoreReference(_tlObject, 48, nativeName as NSString)
        tlStoreReference(_tlObject, 56, langCode as NSString)
        tlStoreReference(_tlObject, 64, baseLangCode.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, pluralCode as NSString)
        tlStore(_tlObject, 28, stringsCount)
        tlStore(_tlObject, 32, translatedCount)
        tlStoreReference(_tlObject, 80, translationsUrl as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum LangPackString: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_langPackString {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_langPackStringDeleted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_langPackStringPluralized {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case langPackString(Cons_langPackString)
        case langPackStringDeleted(Cons_langPackStringDeleted)
        case langPackStringPluralized(Cons_langPackStringPluralized)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .langPackString(Cons_langPackString(tlObject: object))
            case 1:
                self = .langPackStringDeleted(Cons_langPackStringDeleted(tlObject: object))
            case 2:
                self = .langPackStringPluralized(Cons_langPackStringPluralized(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .langPackString(let _data):
                return _data.tlObject
            case .langPackStringDeleted(let _data):
                return _data.tlObject
            case .langPackStringPluralized(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.LangPackString] {
            return tlObjectsAt(object, offset).map { Api.LangPackString(tlObject: $0) }
        }

    }
}
public extension Api.LangPackString.Cons_langPackString {
    @_alwaysEmitIntoClient var key: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var value: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(key: String, value: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1346))
        tlStoreReference(_tlObject, 24, key as NSString)
        tlStoreReference(_tlObject, 32, value as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.LangPackString.Cons_langPackStringDeleted {
    @_alwaysEmitIntoClient var key: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(key: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(267))
        tlStoreReference(_tlObject, 24, key as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.LangPackString.Cons_langPackStringPluralized {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var key: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var zeroValue: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var oneValue: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var twoValue: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var fewValue: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var manyValue: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var otherValue: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 80) } }
    }
    init(flags: Int32, key: String, zeroValue: String?, oneValue: String?, twoValue: String?, fewValue: String?, manyValue: String?, otherValue: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(692))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, key as NSString)
        tlStoreReference(_tlObject, 40, zeroValue.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, oneValue.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, twoValue.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, fewValue.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, manyValue.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, otherValue as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MaskCoords: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_maskCoords {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case maskCoords(Cons_maskCoords)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .maskCoords(Cons_maskCoords(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .maskCoords(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MaskCoords] {
            return tlObjectsAt(object, offset).map { Api.MaskCoords(tlObject: $0) }
        }

    }
}
public extension Api.MaskCoords.Cons_maskCoords {
    @_alwaysEmitIntoClient var n: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var x: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var y: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var zoom: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Double.self) } }
    }
    init(n: Int32, x: Double, y: Double, zoom: Double) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1139))
        tlStore(_tlObject, 24, n)
        tlStore(_tlObject, 32, x)
        tlStore(_tlObject, 40, y)
        tlStore(_tlObject, 48, zoom)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum MediaArea: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputMediaAreaChannelPost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaAreaVenue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_mediaAreaChannelPost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_mediaAreaGeoPoint {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_mediaAreaStarGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_mediaAreaSuggestedReaction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_mediaAreaUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_mediaAreaVenue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_mediaAreaWeather {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputMediaAreaChannelPost(Cons_inputMediaAreaChannelPost)
        case inputMediaAreaVenue(Cons_inputMediaAreaVenue)
        case mediaAreaChannelPost(Cons_mediaAreaChannelPost)
        case mediaAreaGeoPoint(Cons_mediaAreaGeoPoint)
        case mediaAreaStarGift(Cons_mediaAreaStarGift)
        case mediaAreaSuggestedReaction(Cons_mediaAreaSuggestedReaction)
        case mediaAreaUrl(Cons_mediaAreaUrl)
        case mediaAreaVenue(Cons_mediaAreaVenue)
        case mediaAreaWeather(Cons_mediaAreaWeather)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputMediaAreaChannelPost(Cons_inputMediaAreaChannelPost(tlObject: object))
            case 1:
                self = .inputMediaAreaVenue(Cons_inputMediaAreaVenue(tlObject: object))
            case 2:
                self = .mediaAreaChannelPost(Cons_mediaAreaChannelPost(tlObject: object))
            case 3:
                self = .mediaAreaGeoPoint(Cons_mediaAreaGeoPoint(tlObject: object))
            case 4:
                self = .mediaAreaStarGift(Cons_mediaAreaStarGift(tlObject: object))
            case 5:
                self = .mediaAreaSuggestedReaction(Cons_mediaAreaSuggestedReaction(tlObject: object))
            case 6:
                self = .mediaAreaUrl(Cons_mediaAreaUrl(tlObject: object))
            case 7:
                self = .mediaAreaVenue(Cons_mediaAreaVenue(tlObject: object))
            case 8:
                self = .mediaAreaWeather(Cons_mediaAreaWeather(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputMediaAreaChannelPost(let _data):
                return _data.tlObject
            case .inputMediaAreaVenue(let _data):
                return _data.tlObject
            case .mediaAreaChannelPost(let _data):
                return _data.tlObject
            case .mediaAreaGeoPoint(let _data):
                return _data.tlObject
            case .mediaAreaStarGift(let _data):
                return _data.tlObject
            case .mediaAreaSuggestedReaction(let _data):
                return _data.tlObject
            case .mediaAreaUrl(let _data):
                return _data.tlObject
            case .mediaAreaVenue(let _data):
                return _data.tlObject
            case .mediaAreaWeather(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MediaArea] {
            return tlObjectsAt(object, offset).map { Api.MediaArea(tlObject: $0) }
        }

    }
}
public extension Api.MediaArea.Cons_inputMediaAreaChannelPost {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var channel: Api.InputChannel {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputChannel(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, channel: Api.InputChannel, msgId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(238))
        tlStoreReference(_tlObject, 32, coordinates.tlObject)
        tlStoreReference(_tlObject, 40, channel.tlObject)
        tlStore(_tlObject, 24, msgId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_inputMediaAreaVenue {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var queryId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var resultId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, queryId: Int64, resultId: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1160))
        tlStoreReference(_tlObject, 24, coordinates.tlObject)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, resultId as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_mediaAreaChannelPost {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, channelId: Int64, msgId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(762))
        tlStoreReference(_tlObject, 32, coordinates.tlObject)
        tlStore(_tlObject, 40, channelId)
        tlStore(_tlObject, 24, msgId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_mediaAreaGeoPoint {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var address: Api.GeoPointAddress? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.GeoPointAddress(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, address: Api.GeoPointAddress?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1347))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, coordinates.tlObject)
        tlStoreReference(_tlObject, 40, geo.tlObject)
        tlStoreReference(_tlObject, 48, address?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_mediaAreaStarGift {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(568))
        tlStoreReference(_tlObject, 24, coordinates.tlObject)
        tlStoreReference(_tlObject, 32, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_mediaAreaSuggestedReaction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var reaction: Api.Reaction {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Reaction(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, coordinates: Api.MediaAreaCoordinates, reaction: Api.Reaction) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(124))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, coordinates.tlObject)
        tlStoreReference(_tlObject, 40, reaction.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_mediaAreaUrl {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(355))
        tlStoreReference(_tlObject, 24, coordinates.tlObject)
        tlStoreReference(_tlObject, 32, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_mediaAreaVenue {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var provider: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var venueId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var venueType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1265))
        tlStoreReference(_tlObject, 24, coordinates.tlObject)
        tlStoreReference(_tlObject, 32, geo.tlObject)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, address as NSString)
        tlStoreReference(_tlObject, 56, provider as NSString)
        tlStoreReference(_tlObject, 64, venueId as NSString)
        tlStoreReference(_tlObject, 72, venueType as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MediaArea.Cons_mediaAreaWeather {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var emoji: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var temperatureC: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var color: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, emoji: String, temperatureC: Double, color: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(473))
        tlStoreReference(_tlObject, 32, coordinates.tlObject)
        tlStoreReference(_tlObject, 40, emoji as NSString)
        tlStore(_tlObject, 48, temperatureC)
        tlStore(_tlObject, 24, color)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MediaAreaCoordinates: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_mediaAreaCoordinates {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case mediaAreaCoordinates(Cons_mediaAreaCoordinates)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .mediaAreaCoordinates(Cons_mediaAreaCoordinates(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .mediaAreaCoordinates(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MediaAreaCoordinates] {
            return tlObjectsAt(object, offset).map { Api.MediaAreaCoordinates(tlObject: $0) }
        }

    }
}
public extension Api.MediaAreaCoordinates.Cons_mediaAreaCoordinates {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var x: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var y: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var w: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var h: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var rotation: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var radius: Double? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 72, as: Double.self) : nil } }
    }
    init(flags: Int32, x: Double, y: Double, w: Double, h: Double, rotation: Double, radius: Double?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1375))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, x)
        tlStore(_tlObject, 40, y)
        tlStore(_tlObject, 48, w)
        tlStore(_tlObject, 56, h)
        tlStore(_tlObject, 64, rotation)
        if let _tlValue = radius { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum Message: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_message {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageService {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case message(Cons_message)
        case messageEmpty(Cons_messageEmpty)
        case messageService(Cons_messageService)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .message(Cons_message(tlObject: object))
            case 1:
                self = .messageEmpty(Cons_messageEmpty(tlObject: object))
            case 2:
                self = .messageService(Cons_messageService(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .message(let _data):
                return _data.tlObject
            case .messageEmpty(let _data):
                return _data.tlObject
            case .messageService(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Message] {
            return tlObjectsAt(object, offset).map { Api.Message(tlObject: $0) }
        }

    }
}
public extension Api.Message.Cons_message {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var flags2: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var fromBoostsApplied: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var fromRank: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var savedPeerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var fwdFrom: Api.MessageFwdHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.MessageFwdHeader(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var viaBotId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 1) ? tlBase(self.tlObject).load(fromByteOffset: 112, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var viaBusinessBotId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 2) ? tlBase(self.tlObject).load(fromByteOffset: 120, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var guestchatViaFrom: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 128)) } }
    }
    @_alwaysEmitIntoClient var replyTo: Api.MessageReplyHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : Api.MessageReplyHeader(tlObject: tlObjectAt(self.tlObject, 136)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 144) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 160) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 160)) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 168) ? nil : Api.MessageEntity.tlArray(self.tlObject, 168) } }
    }
    @_alwaysEmitIntoClient var views: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 3) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var forwards: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 4) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var replies: Api.MessageReplies? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 176) ? nil : Api.MessageReplies(tlObject: tlObjectAt(self.tlObject, 176)) } }
    }
    @_alwaysEmitIntoClient var editDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 5) ? tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var postAuthor: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 184) ? nil : tlStringAt(self.tlObject, 184) } }
    }
    @_alwaysEmitIntoClient var groupedId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 6) ? tlBase(self.tlObject).load(fromByteOffset: 192, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var reactions: Api.MessageReactions? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 200) ? nil : Api.MessageReactions(tlObject: tlObjectAt(self.tlObject, 200)) } }
    }
    @_alwaysEmitIntoClient var restrictionReason: [Api.RestrictionReason]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 208) ? nil : Api.RestrictionReason.tlArray(self.tlObject, 208) } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 7) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var quickReplyShortcutId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 8) ? tlBase(self.tlObject).load(fromByteOffset: 60, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var effect: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 9) ? tlBase(self.tlObject).load(fromByteOffset: 216, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var factcheck: Api.FactCheck? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 224) ? nil : Api.FactCheck(tlObject: tlObjectAt(self.tlObject, 224)) } }
    }
    @_alwaysEmitIntoClient var reportDeliveryUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 10) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var paidMessageStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 11) ? tlBase(self.tlObject).load(fromByteOffset: 232, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var suggestedPost: Api.SuggestedPost? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 240) ? nil : Api.SuggestedPost(tlObject: tlObjectAt(self.tlObject, 240)) } }
    }
    @_alwaysEmitIntoClient var scheduleRepeatPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 264, 12) ? tlBase(self.tlObject).load(fromByteOffset: 68, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var summaryFromLanguage: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 248) ? nil : tlStringAt(self.tlObject, 248) } }
    }
    @_alwaysEmitIntoClient var richMessage: Api.RichMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 256) ? nil : Api.RichMessage(tlObject: tlObjectAt(self.tlObject, 256)) } }
    }
    init(flags: Int32, flags2: Int32, id: Int32, fromId: Api.Peer?, fromBoostsApplied: Int32?, fromRank: String?, peerId: Api.Peer, savedPeerId: Api.Peer?, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, viaBusinessBotId: Int64?, guestchatViaFrom: Api.Peer?, replyTo: Api.MessageReplyHeader?, date: Int32, message: String, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?, editDate: Int32?, postAuthor: String?, groupedId: Int64?, reactions: Api.MessageReactions?, restrictionReason: [Api.RestrictionReason]?, ttlPeriod: Int32?, quickReplyShortcutId: Int32?, effect: Int64?, factcheck: Api.FactCheck?, reportDeliveryUntilDate: Int32?, paidMessageStars: Int64?, suggestedPost: Api.SuggestedPost?, scheduleRepeatPeriod: Int32?, summaryFromLanguage: String?, richMessage: Api.RichMessage?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(753))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, flags2)
        tlStore(_tlObject, 32, id)
        tlStoreReference(_tlObject, 72, fromId?.tlObject)
        if let _tlValue = fromBoostsApplied { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 80, fromRank.map { value in value as NSString })
        tlStoreReference(_tlObject, 88, peerId.tlObject)
        tlStoreReference(_tlObject, 96, savedPeerId?.tlObject)
        tlStoreReference(_tlObject, 104, fwdFrom?.tlObject)
        if let _tlValue = viaBotId { tlStore(_tlObject, 112, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = viaBusinessBotId { tlStore(_tlObject, 120, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 128, guestchatViaFrom?.tlObject)
        tlStoreReference(_tlObject, 136, replyTo?.tlObject)
        tlStore(_tlObject, 40, date)
        tlStoreReference(_tlObject, 144, message as NSString)
        tlStoreReference(_tlObject, 152, media?.tlObject)
        tlStoreReference(_tlObject, 160, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 168, entities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = views { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = forwards { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 4 }
        tlStoreReference(_tlObject, 176, replies?.tlObject)
        if let _tlValue = editDate { tlStore(_tlObject, 52, _tlValue); _tlPresent |= 1 << 5 }
        tlStoreReference(_tlObject, 184, postAuthor.map { value in value as NSString })
        if let _tlValue = groupedId { tlStore(_tlObject, 192, _tlValue); _tlPresent |= 1 << 6 }
        tlStoreReference(_tlObject, 200, reactions?.tlObject)
        tlStoreReference(_tlObject, 208, restrictionReason.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 7 }
        if let _tlValue = quickReplyShortcutId { tlStore(_tlObject, 60, _tlValue); _tlPresent |= 1 << 8 }
        if let _tlValue = effect { tlStore(_tlObject, 216, _tlValue); _tlPresent |= 1 << 9 }
        tlStoreReference(_tlObject, 224, factcheck?.tlObject)
        if let _tlValue = reportDeliveryUntilDate { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 10 }
        if let _tlValue = paidMessageStars { tlStore(_tlObject, 232, _tlValue); _tlPresent |= 1 << 11 }
        tlStoreReference(_tlObject, 240, suggestedPost?.tlObject)
        if let _tlValue = scheduleRepeatPeriod { tlStore(_tlObject, 68, _tlValue); _tlPresent |= 1 << 12 }
        tlStoreReference(_tlObject, 248, summaryFromLanguage.map { value in value as NSString })
        tlStoreReference(_tlObject, 256, richMessage?.tlObject)
        tlStore(_tlObject, 264, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Message.Cons_messageEmpty {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, id: Int32, peerId: Api.Peer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(927))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 32, peerId?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Message.Cons_messageService {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var savedPeerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var replyTo: Api.MessageReplyHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageReplyHeader(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var action: Api.MessageAction {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageAction(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var reactions: Api.MessageReactions? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.MessageReactions(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, savedPeerId: Api.Peer?, replyTo: Api.MessageReplyHeader?, date: Int32, action: Api.MessageAction, reactions: Api.MessageReactions?, ttlPeriod: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(787))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, fromId?.tlObject)
        tlStoreReference(_tlObject, 48, peerId.tlObject)
        tlStoreReference(_tlObject, 56, savedPeerId?.tlObject)
        tlStoreReference(_tlObject, 64, replyTo?.tlObject)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 72, action.tlObject)
        tlStoreReference(_tlObject, 80, reactions?.tlObject)
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
