import TelegramApiObjC
public extension Api {
    indirect enum PageButton: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pageButton {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pageButton(Cons_pageButton)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pageButton(Cons_pageButton(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pageButton(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageButton] {
            return tlObjectsAt(object, offset).map { Api.PageButton(tlObject: $0) }
        }

    }
}
public extension Api.PageButton.Cons_pageButton {
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(672))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        tlStoreReference(_tlObject, 40, type.tlObject)
        tlStoreReference(_tlObject, 48, style?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PageCaption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pageCaption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pageCaption(Cons_pageCaption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pageCaption(Cons_pageCaption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pageCaption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageCaption] {
            return tlObjectsAt(object, offset).map { Api.PageCaption(tlObject: $0) }
        }

    }
}
public extension Api.PageCaption.Cons_pageCaption {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var credit: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(text: Api.RichText, credit: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(709))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, credit.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PageListItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pageListItemBlocks {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageListItemText {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pageListItemBlocks(Cons_pageListItemBlocks)
        case pageListItemText(Cons_pageListItemText)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pageListItemBlocks(Cons_pageListItemBlocks(tlObject: object))
            case 1:
                self = .pageListItemText(Cons_pageListItemText(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pageListItemBlocks(let _data):
                return _data.tlObject
            case .pageListItemText(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageListItem] {
            return tlObjectsAt(object, offset).map { Api.PageListItem(tlObject: $0) }
        }

    }
}
public extension Api.PageListItem.Cons_pageListItemBlocks {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, blocks: [Api.PageBlock]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(638))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, blocks.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageListItem.Cons_pageListItemText {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(299))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PageListOrderedItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pageListOrderedItemBlocks {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageListOrderedItemText {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pageListOrderedItemBlocks(Cons_pageListOrderedItemBlocks)
        case pageListOrderedItemText(Cons_pageListOrderedItemText)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pageListOrderedItemBlocks(Cons_pageListOrderedItemBlocks(tlObject: object))
            case 1:
                self = .pageListOrderedItemText(Cons_pageListOrderedItemText(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pageListOrderedItemBlocks(let _data):
                return _data.tlObject
            case .pageListOrderedItemText(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageListOrderedItem] {
            return tlObjectsAt(object, offset).map { Api.PageListOrderedItem(tlObject: $0) }
        }

    }
}
public extension Api.PageListOrderedItem.Cons_pageListOrderedItemBlocks {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var num: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var value: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var type: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, num: String?, blocks: [Api.PageBlock], value: Int32?, type: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(920))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, num.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, blocks.map { item in item.tlObject } as NSArray)
        if let _tlValue = value { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, type.map { value in value as NSString })
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageListOrderedItem.Cons_pageListOrderedItemText {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var num: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var value: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var type: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, num: String?, text: Api.RichText, value: Int32?, type: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(129))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, num.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, text.tlObject)
        if let _tlValue = value { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, type.map { value in value as NSString })
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PageRelatedArticle: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pageRelatedArticle {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pageRelatedArticle(Cons_pageRelatedArticle)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pageRelatedArticle(Cons_pageRelatedArticle(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pageRelatedArticle(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageRelatedArticle] {
            return tlObjectsAt(object, offset).map { Api.PageRelatedArticle(tlObject: $0) }
        }

    }
}
public extension Api.PageRelatedArticle.Cons_pageRelatedArticle {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var webpageId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var description: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var photoId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var author: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var publishedDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, url: String, webpageId: Int64, title: String?, description: String?, photoId: Int64?, author: String?, publishedDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1170))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 40, webpageId)
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, description.map { value in value as NSString })
        if let _tlValue = photoId { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 72, author.map { value in value as NSString })
        if let _tlValue = publishedDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PageTableCell: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pageTableCell {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pageTableCell(Cons_pageTableCell)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pageTableCell(Cons_pageTableCell(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pageTableCell(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageTableCell] {
            return tlObjectsAt(object, offset).map { Api.PageTableCell(tlObject: $0) }
        }

    }
}
public extension Api.PageTableCell.Cons_pageTableCell {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.RichText? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.RichText(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var colspan: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var rowspan: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, text: Api.RichText?, colspan: Int32?, rowspan: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(332))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, text?.tlObject)
        if let _tlValue = colspan { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = rowspan { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PageTableRow: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pageTableRow {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pageTableRow(Cons_pageTableRow)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pageTableRow(Cons_pageTableRow(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pageTableRow(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageTableRow] {
            return tlObjectsAt(object, offset).map { Api.PageTableRow(tlObject: $0) }
        }

    }
}
public extension Api.PageTableRow.Cons_pageTableRow {
    @_alwaysEmitIntoClient var cells: [Api.PageTableCell] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageTableCell.tlArray(self.tlObject, 24) } }
    }
    init(cells: [Api.PageTableCell]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1480))
        tlStoreReference(_tlObject, 24, cells.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PaidReactionPrivacy: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paidReactionPrivacyPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paidReactionPrivacyAnonymous
        case paidReactionPrivacyDefault
        case paidReactionPrivacyPeer(Cons_paidReactionPrivacyPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paidReactionPrivacyAnonymous
            case 1:
                self = .paidReactionPrivacyDefault
            case 2:
                self = .paidReactionPrivacyPeer(Cons_paidReactionPrivacyPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paidReactionPrivacyAnonymous:
                return TLObjectSingleton(TLApiConstructorAt(210))
            case .paidReactionPrivacyDefault:
                return TLObjectSingleton(TLApiConstructorAt(222))
            case .paidReactionPrivacyPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PaidReactionPrivacy] {
            return tlObjectsAt(object, offset).map { Api.PaidReactionPrivacy(tlObject: $0) }
        }

    }
}
public extension Api.PaidReactionPrivacy.Cons_paidReactionPrivacyPeer {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.InputPeer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1449))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Passkey: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passkey {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passkey(Cons_passkey)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passkey(Cons_passkey(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passkey(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Passkey] {
            return tlObjectsAt(object, offset).map { Api.Passkey(tlObject: $0) }
        }

    }
}
public extension Api.Passkey.Cons_passkey {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var softwareEmojiId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var lastUsageDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: String, name: String, date: Int32, softwareEmojiId: Int64?, lastUsageDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(978))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, id as NSString)
        tlStoreReference(_tlObject, 48, name as NSString)
        tlStore(_tlObject, 28, date)
        if let _tlValue = softwareEmojiId { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = lastUsageDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PasswordKdfAlgo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow)
        case passwordKdfAlgoUnknown


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(tlObject: object))
            case 1:
                self = .passwordKdfAlgoUnknown
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(let _data):
                return _data.tlObject
            case .passwordKdfAlgoUnknown:
                return TLObjectSingleton(TLApiConstructorAt(1398))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PasswordKdfAlgo] {
            return tlObjectsAt(object, offset).map { Api.PasswordKdfAlgo(tlObject: $0) }
        }

    }
}
public extension Api.PasswordKdfAlgo.Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow {
    @_alwaysEmitIntoClient var salt1: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var salt2: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var g: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var p: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    init(salt1: Buffer, salt2: Buffer, g: Int32, p: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(372))
        tlStoreReference(_tlObject, 32, salt1.makeData() as NSData)
        tlStoreReference(_tlObject, 40, salt2.makeData() as NSData)
        tlStore(_tlObject, 24, g)
        tlStoreReference(_tlObject, 48, p.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PaymentCharge: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paymentCharge {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paymentCharge(Cons_paymentCharge)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paymentCharge(Cons_paymentCharge(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paymentCharge(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PaymentCharge] {
            return tlObjectsAt(object, offset).map { Api.PaymentCharge(tlObject: $0) }
        }

    }
}
public extension Api.PaymentCharge.Cons_paymentCharge {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var providerChargeId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(id: String, providerChargeId: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1545))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, providerChargeId as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PaymentFormMethod: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paymentFormMethod {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paymentFormMethod(Cons_paymentFormMethod)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paymentFormMethod(Cons_paymentFormMethod(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paymentFormMethod(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PaymentFormMethod] {
            return tlObjectsAt(object, offset).map { Api.PaymentFormMethod(tlObject: $0) }
        }

    }
}
public extension Api.PaymentFormMethod.Cons_paymentFormMethod {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(url: String, title: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(877))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStoreReference(_tlObject, 32, title as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PaymentRequestedInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paymentRequestedInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paymentRequestedInfo(Cons_paymentRequestedInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paymentRequestedInfo(Cons_paymentRequestedInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paymentRequestedInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PaymentRequestedInfo] {
            return tlObjectsAt(object, offset).map { Api.PaymentRequestedInfo(tlObject: $0) }
        }

    }
}
public extension Api.PaymentRequestedInfo.Cons_paymentRequestedInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var name: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var phone: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var email: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var shippingAddress: Api.PostAddress? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.PostAddress(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, name: String?, phone: String?, email: String?, shippingAddress: Api.PostAddress?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(928))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, name.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, phone.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, email.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, shippingAddress?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PaymentSavedCredentials: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paymentSavedCredentialsCard {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paymentSavedCredentialsCard(Cons_paymentSavedCredentialsCard)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paymentSavedCredentialsCard(Cons_paymentSavedCredentialsCard(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paymentSavedCredentialsCard(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PaymentSavedCredentials] {
            return tlObjectsAt(object, offset).map { Api.PaymentSavedCredentials(tlObject: $0) }
        }

    }
}
public extension Api.PaymentSavedCredentials.Cons_paymentSavedCredentialsCard {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(id: String, title: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1369))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, title as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Peer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerChannel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_peerChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_peerUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerChannel(Cons_peerChannel)
        case peerChat(Cons_peerChat)
        case peerUser(Cons_peerUser)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerChannel(Cons_peerChannel(tlObject: object))
            case 1:
                self = .peerChat(Cons_peerChat(tlObject: object))
            case 2:
                self = .peerUser(Cons_peerUser(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerChannel(let _data):
                return _data.tlObject
            case .peerChat(let _data):
                return _data.tlObject
            case .peerUser(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Peer] {
            return tlObjectsAt(object, offset).map { Api.Peer(tlObject: $0) }
        }

    }
}
public extension Api.Peer.Cons_peerChannel {
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(channelId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1064))
        tlStore(_tlObject, 24, channelId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Peer.Cons_peerChat {
    @_alwaysEmitIntoClient var chatId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(chatId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(350))
        tlStore(_tlObject, 24, chatId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Peer.Cons_peerUser {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(580))
        tlStore(_tlObject, 24, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PeerBlocked: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerBlocked {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerBlocked(Cons_peerBlocked)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerBlocked(Cons_peerBlocked(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerBlocked(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PeerBlocked] {
            return tlObjectsAt(object, offset).map { Api.PeerBlocked(tlObject: $0) }
        }

    }
}
public extension Api.PeerBlocked.Cons_peerBlocked {
    @_alwaysEmitIntoClient var peerId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peerId: Api.Peer, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1535))
        tlStoreReference(_tlObject, 32, peerId.tlObject)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PeerColor: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPeerColorCollectible {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_peerColor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_peerColorCollectible {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPeerColorCollectible(Cons_inputPeerColorCollectible)
        case peerColor(Cons_peerColor)
        case peerColorCollectible(Cons_peerColorCollectible)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPeerColorCollectible(Cons_inputPeerColorCollectible(tlObject: object))
            case 1:
                self = .peerColor(Cons_peerColor(tlObject: object))
            case 2:
                self = .peerColorCollectible(Cons_peerColorCollectible(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPeerColorCollectible(let _data):
                return _data.tlObject
            case .peerColor(let _data):
                return _data.tlObject
            case .peerColorCollectible(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PeerColor] {
            return tlObjectsAt(object, offset).map { Api.PeerColor(tlObject: $0) }
        }

    }
}
public extension Api.PeerColor.Cons_inputPeerColorCollectible {
    @_alwaysEmitIntoClient var collectibleId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(collectibleId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1217))
        tlStore(_tlObject, 24, collectibleId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PeerColor.Cons_peerColor {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var color: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var backgroundEmojiId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) : nil } }
    }
    init(flags: Int32, color: Int32?, backgroundEmojiId: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1192))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = color { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = backgroundEmojiId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PeerColor.Cons_peerColorCollectible {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var collectibleId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var giftEmojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var backgroundEmojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accentColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var colors: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var darkAccentColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var darkColors: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlInt32sAt(self.tlObject, 72) } }
    }
    init(flags: Int32, collectibleId: Int64, giftEmojiId: Int64, backgroundEmojiId: Int64, accentColor: Int32, colors: [Int32], darkAccentColor: Int32?, darkColors: [Int32]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1225))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, collectibleId)
        tlStore(_tlObject, 48, giftEmojiId)
        tlStore(_tlObject, 56, backgroundEmojiId)
        tlStore(_tlObject, 28, accentColor)
        tlStoreReference(_tlObject, 64, tlPackInt32(colors) as NSData)
        if let _tlValue = darkAccentColor { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 72, darkColors.map { value in tlPackInt32(value) as NSData })
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PeerLocated: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerLocated {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_peerSelfLocated {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerLocated(Cons_peerLocated)
        case peerSelfLocated(Cons_peerSelfLocated)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerLocated(Cons_peerLocated(tlObject: object))
            case 1:
                self = .peerSelfLocated(Cons_peerSelfLocated(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerLocated(let _data):
                return _data.tlObject
            case .peerSelfLocated(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PeerLocated] {
            return tlObjectsAt(object, offset).map { Api.PeerLocated(tlObject: $0) }
        }

    }
}
public extension Api.PeerLocated.Cons_peerLocated {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var distance: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(peer: Api.Peer, expires: Int32, distance: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1345))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, expires)
        tlStore(_tlObject, 28, distance)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PeerLocated.Cons_peerSelfLocated {
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(expires: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1654))
        tlStore(_tlObject, 24, expires)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PeerNotifySettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerNotifySettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerNotifySettings(Cons_peerNotifySettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerNotifySettings(Cons_peerNotifySettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerNotifySettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PeerNotifySettings] {
            return tlObjectsAt(object, offset).map { Api.PeerNotifySettings(tlObject: $0) }
        }

    }
}
public extension Api.PeerNotifySettings.Cons_peerNotifySettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var showPreviews: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var silent: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var muteUntil: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 112, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var iosSound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var androidSound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var otherSound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var storiesMuted: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var storiesHideSender: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var storiesIosSound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var storiesAndroidSound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var storiesOtherSound: Api.NotificationSound? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    init(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, iosSound: Api.NotificationSound?, androidSound: Api.NotificationSound?, otherSound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesIosSound: Api.NotificationSound?, storiesAndroidSound: Api.NotificationSound?, storiesOtherSound: Api.NotificationSound?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(987))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, showPreviews?.tlObject)
        tlStoreReference(_tlObject, 40, silent?.tlObject)
        if let _tlValue = muteUntil { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, iosSound?.tlObject)
        tlStoreReference(_tlObject, 56, androidSound?.tlObject)
        tlStoreReference(_tlObject, 64, otherSound?.tlObject)
        tlStoreReference(_tlObject, 72, storiesMuted?.tlObject)
        tlStoreReference(_tlObject, 80, storiesHideSender?.tlObject)
        tlStoreReference(_tlObject, 88, storiesIosSound?.tlObject)
        tlStoreReference(_tlObject, 96, storiesAndroidSound?.tlObject)
        tlStoreReference(_tlObject, 104, storiesOtherSound?.tlObject)
        tlStore(_tlObject, 112, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PeerSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerSettings(Cons_peerSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerSettings(Cons_peerSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PeerSettings] {
            return tlObjectsAt(object, offset).map { Api.PeerSettings(tlObject: $0) }
        }

    }
}
public extension Api.PeerSettings.Cons_peerSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geoDistance: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var requestChatTitle: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var requestChatDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var businessBotId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 2) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var businessBotManageUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var chargePaidMessageStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 3) ? tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var registrationMonth: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var phoneCountry: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var nameChangeDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 4) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var photoChangeDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 5) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    init(flags: Int32, geoDistance: Int32?, requestChatTitle: String?, requestChatDate: Int32?, businessBotId: Int64?, businessBotManageUrl: String?, chargePaidMessageStars: Int64?, registrationMonth: String?, phoneCountry: String?, nameChangeDate: Int32?, photoChangeDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1627))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = geoDistance { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, requestChatTitle.map { value in value as NSString })
        if let _tlValue = requestChatDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = businessBotId { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 64, businessBotManageUrl.map { value in value as NSString })
        if let _tlValue = chargePaidMessageStars { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 3 }
        tlStoreReference(_tlObject, 80, registrationMonth.map { value in value as NSString })
        tlStoreReference(_tlObject, 88, phoneCountry.map { value in value as NSString })
        if let _tlValue = nameChangeDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = photoChangeDate { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 5 }
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PeerStories: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerStories {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerStories(Cons_peerStories)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerStories(Cons_peerStories(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerStories(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PeerStories] {
            return tlObjectsAt(object, offset).map { Api.PeerStories(tlObject: $0) }
        }

    }
}
public extension Api.PeerStories.Cons_peerStories {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var maxReadId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stories: [Api.StoryItem] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryItem.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, peer: Api.Peer, maxReadId: Int32?, stories: [Api.StoryItem]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(997))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        if let _tlValue = maxReadId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, stories.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PendingSuggestion: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pendingSuggestion {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pendingSuggestion(Cons_pendingSuggestion)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pendingSuggestion(Cons_pendingSuggestion(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pendingSuggestion(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PendingSuggestion] {
            return tlObjectsAt(object, offset).map { Api.PendingSuggestion(tlObject: $0) }
        }

    }
}
public extension Api.PendingSuggestion.Cons_pendingSuggestion {
    @_alwaysEmitIntoClient var suggestion: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var title: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var description: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(suggestion: String, title: Api.TextWithEntities, description: Api.TextWithEntities, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1525))
        tlStoreReference(_tlObject, 24, suggestion as NSString)
        tlStoreReference(_tlObject, 32, title.tlObject)
        tlStoreReference(_tlObject, 40, description.tlObject)
        tlStoreReference(_tlObject, 48, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum PhoneCall: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_phoneCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_phoneCallAccepted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_phoneCallDiscarded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_phoneCallEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_phoneCallRequested {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_phoneCallWaiting {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case phoneCall(Cons_phoneCall)
        case phoneCallAccepted(Cons_phoneCallAccepted)
        case phoneCallDiscarded(Cons_phoneCallDiscarded)
        case phoneCallEmpty(Cons_phoneCallEmpty)
        case phoneCallRequested(Cons_phoneCallRequested)
        case phoneCallWaiting(Cons_phoneCallWaiting)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .phoneCall(Cons_phoneCall(tlObject: object))
            case 1:
                self = .phoneCallAccepted(Cons_phoneCallAccepted(tlObject: object))
            case 2:
                self = .phoneCallDiscarded(Cons_phoneCallDiscarded(tlObject: object))
            case 3:
                self = .phoneCallEmpty(Cons_phoneCallEmpty(tlObject: object))
            case 4:
                self = .phoneCallRequested(Cons_phoneCallRequested(tlObject: object))
            case 5:
                self = .phoneCallWaiting(Cons_phoneCallWaiting(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .phoneCall(let _data):
                return _data.tlObject
            case .phoneCallAccepted(let _data):
                return _data.tlObject
            case .phoneCallDiscarded(let _data):
                return _data.tlObject
            case .phoneCallEmpty(let _data):
                return _data.tlObject
            case .phoneCallRequested(let _data):
                return _data.tlObject
            case .phoneCallWaiting(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PhoneCall] {
            return tlObjectsAt(object, offset).map { Api.PhoneCall(tlObject: $0) }
        }

    }
}
public extension Api.PhoneCall.Cons_phoneCall {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var gAOrB: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var keyFingerprint: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var `protocol`: Api.PhoneCallProtocol {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PhoneCallProtocol(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var connections: [Api.PhoneConnection] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PhoneConnection.tlArray(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var startDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var customParameters: Api.DataJSON? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64, `protocol`: Api.PhoneCallProtocol, connections: [Api.PhoneConnection], startDate: Int32, customParameters: Api.DataJSON?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(305))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, id)
        tlStore(_tlObject, 48, accessHash)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 56, adminId)
        tlStore(_tlObject, 64, participantId)
        tlStoreReference(_tlObject, 72, gAOrB.makeData() as NSData)
        tlStore(_tlObject, 80, keyFingerprint)
        tlStoreReference(_tlObject, 88, `protocol`.tlObject)
        tlStoreReference(_tlObject, 96, connections.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 32, startDate)
        tlStoreReference(_tlObject, 104, customParameters?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhoneCall.Cons_phoneCallAccepted {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var gB: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var `protocol`: Api.PhoneCallProtocol {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PhoneCallProtocol(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gB: Buffer, `protocol`: Api.PhoneCallProtocol) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(348))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 48, adminId)
        tlStore(_tlObject, 56, participantId)
        tlStoreReference(_tlObject, 64, gB.makeData() as NSData)
        tlStoreReference(_tlObject, 72, `protocol`.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhoneCall.Cons_phoneCallDiscarded {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var reason: Api.PhoneCallDiscardReason? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.PhoneCallDiscardReason(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var duration: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(524))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStoreReference(_tlObject, 40, reason?.tlObject)
        if let _tlValue = duration { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhoneCall.Cons_phoneCallEmpty {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(542))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhoneCall.Cons_phoneCallRequested {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var gAHash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var `protocol`: Api.PhoneCallProtocol {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PhoneCallProtocol(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAHash: Buffer, `protocol`: Api.PhoneCallProtocol) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(127))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 48, adminId)
        tlStore(_tlObject, 56, participantId)
        tlStoreReference(_tlObject, 64, gAHash.makeData() as NSData)
        tlStoreReference(_tlObject, 72, `protocol`.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PhoneCall.Cons_phoneCallWaiting {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var `protocol`: Api.PhoneCallProtocol {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PhoneCallProtocol(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var receiveDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, `protocol`: Api.PhoneCallProtocol, receiveDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1321))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, id)
        tlStore(_tlObject, 48, accessHash)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 56, adminId)
        tlStore(_tlObject, 64, participantId)
        tlStoreReference(_tlObject, 72, `protocol`.tlObject)
        if let _tlValue = receiveDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
