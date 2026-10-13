import TelegramApiObjC
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1386))
        tlStoreReference(_tlObject, 32, provider as NSString)
        tlStoreReference(_tlObject, 40, sessionId as NSString)
        tlStoreReference(_tlObject, 48, url as NSString)
        tlStore(_tlObject, 24, expiresDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum OutboxReadDate: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_outboxReadDate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case outboxReadDate(Cons_outboxReadDate)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .outboxReadDate(Cons_outboxReadDate(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .outboxReadDate(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.OutboxReadDate] {
            return tlObjectsAt(object, offset).map { Api.OutboxReadDate(tlObject: $0) }
        }

    }
}
public extension Api.OutboxReadDate.Cons_outboxReadDate {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(377))
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Page: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_page {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case page(Cons_page)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .page(Cons_page(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .page(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Page] {
            return tlObjectsAt(object, offset).map { Api.Page(tlObject: $0) }
        }

    }
}
public extension Api.Page.Cons_page {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var photos: [Api.Photo] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var views: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, url: String, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document], views: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(977))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStoreReference(_tlObject, 40, blocks.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, photos.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, documents.map { item in item.tlObject } as NSArray)
        if let _tlValue = views { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum PageBlock: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPageBlockMap {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockAnchor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockAudio {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockAuthorDate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockBlockquote {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockBlockquoteBlocks {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockButtonRow {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockChannel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockCollage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockCover {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockDetails {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockEmbed {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockEmbedPost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockFooter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockHeader {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockHeading1 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockHeading2 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockHeading3 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockHeading4 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockHeading5 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockHeading6 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockKicker {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockMap {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockMath {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockOrderedList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockParagraph {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockPreformatted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockPullquote {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockRelatedArticles {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockSlideshow {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockSubheader {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockSubtitle {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockTable {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockThinking {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockTitle {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_pageBlockVideo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPageBlockMap(Cons_inputPageBlockMap)
        case pageBlockAnchor(Cons_pageBlockAnchor)
        case pageBlockAudio(Cons_pageBlockAudio)
        case pageBlockAuthorDate(Cons_pageBlockAuthorDate)
        case pageBlockBlockquote(Cons_pageBlockBlockquote)
        case pageBlockBlockquoteBlocks(Cons_pageBlockBlockquoteBlocks)
        case pageBlockButtonRow(Cons_pageBlockButtonRow)
        case pageBlockChannel(Cons_pageBlockChannel)
        case pageBlockCollage(Cons_pageBlockCollage)
        case pageBlockCover(Cons_pageBlockCover)
        case pageBlockDetails(Cons_pageBlockDetails)
        case pageBlockDivider
        case pageBlockDocument(Cons_pageBlockDocument)
        case pageBlockEmbed(Cons_pageBlockEmbed)
        case pageBlockEmbedPost(Cons_pageBlockEmbedPost)
        case pageBlockFooter(Cons_pageBlockFooter)
        case pageBlockHeader(Cons_pageBlockHeader)
        case pageBlockHeading1(Cons_pageBlockHeading1)
        case pageBlockHeading2(Cons_pageBlockHeading2)
        case pageBlockHeading3(Cons_pageBlockHeading3)
        case pageBlockHeading4(Cons_pageBlockHeading4)
        case pageBlockHeading5(Cons_pageBlockHeading5)
        case pageBlockHeading6(Cons_pageBlockHeading6)
        case pageBlockKicker(Cons_pageBlockKicker)
        case pageBlockList(Cons_pageBlockList)
        case pageBlockMap(Cons_pageBlockMap)
        case pageBlockMath(Cons_pageBlockMath)
        case pageBlockOrderedList(Cons_pageBlockOrderedList)
        case pageBlockParagraph(Cons_pageBlockParagraph)
        case pageBlockPhoto(Cons_pageBlockPhoto)
        case pageBlockPreformatted(Cons_pageBlockPreformatted)
        case pageBlockPullquote(Cons_pageBlockPullquote)
        case pageBlockRelatedArticles(Cons_pageBlockRelatedArticles)
        case pageBlockSlideshow(Cons_pageBlockSlideshow)
        case pageBlockSubheader(Cons_pageBlockSubheader)
        case pageBlockSubtitle(Cons_pageBlockSubtitle)
        case pageBlockTable(Cons_pageBlockTable)
        case pageBlockThinking(Cons_pageBlockThinking)
        case pageBlockTitle(Cons_pageBlockTitle)
        case pageBlockUnsupported
        case pageBlockVideo(Cons_pageBlockVideo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPageBlockMap(Cons_inputPageBlockMap(tlObject: object))
            case 1:
                self = .pageBlockAnchor(Cons_pageBlockAnchor(tlObject: object))
            case 2:
                self = .pageBlockAudio(Cons_pageBlockAudio(tlObject: object))
            case 3:
                self = .pageBlockAuthorDate(Cons_pageBlockAuthorDate(tlObject: object))
            case 4:
                self = .pageBlockBlockquote(Cons_pageBlockBlockquote(tlObject: object))
            case 5:
                self = .pageBlockBlockquoteBlocks(Cons_pageBlockBlockquoteBlocks(tlObject: object))
            case 6:
                self = .pageBlockButtonRow(Cons_pageBlockButtonRow(tlObject: object))
            case 7:
                self = .pageBlockChannel(Cons_pageBlockChannel(tlObject: object))
            case 8:
                self = .pageBlockCollage(Cons_pageBlockCollage(tlObject: object))
            case 9:
                self = .pageBlockCover(Cons_pageBlockCover(tlObject: object))
            case 10:
                self = .pageBlockDetails(Cons_pageBlockDetails(tlObject: object))
            case 11:
                self = .pageBlockDivider
            case 12:
                self = .pageBlockDocument(Cons_pageBlockDocument(tlObject: object))
            case 13:
                self = .pageBlockEmbed(Cons_pageBlockEmbed(tlObject: object))
            case 14:
                self = .pageBlockEmbedPost(Cons_pageBlockEmbedPost(tlObject: object))
            case 15:
                self = .pageBlockFooter(Cons_pageBlockFooter(tlObject: object))
            case 16:
                self = .pageBlockHeader(Cons_pageBlockHeader(tlObject: object))
            case 17:
                self = .pageBlockHeading1(Cons_pageBlockHeading1(tlObject: object))
            case 18:
                self = .pageBlockHeading2(Cons_pageBlockHeading2(tlObject: object))
            case 19:
                self = .pageBlockHeading3(Cons_pageBlockHeading3(tlObject: object))
            case 20:
                self = .pageBlockHeading4(Cons_pageBlockHeading4(tlObject: object))
            case 21:
                self = .pageBlockHeading5(Cons_pageBlockHeading5(tlObject: object))
            case 22:
                self = .pageBlockHeading6(Cons_pageBlockHeading6(tlObject: object))
            case 23:
                self = .pageBlockKicker(Cons_pageBlockKicker(tlObject: object))
            case 24:
                self = .pageBlockList(Cons_pageBlockList(tlObject: object))
            case 25:
                self = .pageBlockMap(Cons_pageBlockMap(tlObject: object))
            case 26:
                self = .pageBlockMath(Cons_pageBlockMath(tlObject: object))
            case 27:
                self = .pageBlockOrderedList(Cons_pageBlockOrderedList(tlObject: object))
            case 28:
                self = .pageBlockParagraph(Cons_pageBlockParagraph(tlObject: object))
            case 29:
                self = .pageBlockPhoto(Cons_pageBlockPhoto(tlObject: object))
            case 30:
                self = .pageBlockPreformatted(Cons_pageBlockPreformatted(tlObject: object))
            case 31:
                self = .pageBlockPullquote(Cons_pageBlockPullquote(tlObject: object))
            case 32:
                self = .pageBlockRelatedArticles(Cons_pageBlockRelatedArticles(tlObject: object))
            case 33:
                self = .pageBlockSlideshow(Cons_pageBlockSlideshow(tlObject: object))
            case 34:
                self = .pageBlockSubheader(Cons_pageBlockSubheader(tlObject: object))
            case 35:
                self = .pageBlockSubtitle(Cons_pageBlockSubtitle(tlObject: object))
            case 36:
                self = .pageBlockTable(Cons_pageBlockTable(tlObject: object))
            case 37:
                self = .pageBlockThinking(Cons_pageBlockThinking(tlObject: object))
            case 38:
                self = .pageBlockTitle(Cons_pageBlockTitle(tlObject: object))
            case 39:
                self = .pageBlockUnsupported
            case 40:
                self = .pageBlockVideo(Cons_pageBlockVideo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPageBlockMap(let _data):
                return _data.tlObject
            case .pageBlockAnchor(let _data):
                return _data.tlObject
            case .pageBlockAudio(let _data):
                return _data.tlObject
            case .pageBlockAuthorDate(let _data):
                return _data.tlObject
            case .pageBlockBlockquote(let _data):
                return _data.tlObject
            case .pageBlockBlockquoteBlocks(let _data):
                return _data.tlObject
            case .pageBlockButtonRow(let _data):
                return _data.tlObject
            case .pageBlockChannel(let _data):
                return _data.tlObject
            case .pageBlockCollage(let _data):
                return _data.tlObject
            case .pageBlockCover(let _data):
                return _data.tlObject
            case .pageBlockDetails(let _data):
                return _data.tlObject
            case .pageBlockDivider:
                return TLObjectSingleton(TLApiConstructorAt(1433))
            case .pageBlockDocument(let _data):
                return _data.tlObject
            case .pageBlockEmbed(let _data):
                return _data.tlObject
            case .pageBlockEmbedPost(let _data):
                return _data.tlObject
            case .pageBlockFooter(let _data):
                return _data.tlObject
            case .pageBlockHeader(let _data):
                return _data.tlObject
            case .pageBlockHeading1(let _data):
                return _data.tlObject
            case .pageBlockHeading2(let _data):
                return _data.tlObject
            case .pageBlockHeading3(let _data):
                return _data.tlObject
            case .pageBlockHeading4(let _data):
                return _data.tlObject
            case .pageBlockHeading5(let _data):
                return _data.tlObject
            case .pageBlockHeading6(let _data):
                return _data.tlObject
            case .pageBlockKicker(let _data):
                return _data.tlObject
            case .pageBlockList(let _data):
                return _data.tlObject
            case .pageBlockMap(let _data):
                return _data.tlObject
            case .pageBlockMath(let _data):
                return _data.tlObject
            case .pageBlockOrderedList(let _data):
                return _data.tlObject
            case .pageBlockParagraph(let _data):
                return _data.tlObject
            case .pageBlockPhoto(let _data):
                return _data.tlObject
            case .pageBlockPreformatted(let _data):
                return _data.tlObject
            case .pageBlockPullquote(let _data):
                return _data.tlObject
            case .pageBlockRelatedArticles(let _data):
                return _data.tlObject
            case .pageBlockSlideshow(let _data):
                return _data.tlObject
            case .pageBlockSubheader(let _data):
                return _data.tlObject
            case .pageBlockSubtitle(let _data):
                return _data.tlObject
            case .pageBlockTable(let _data):
                return _data.tlObject
            case .pageBlockThinking(let _data):
                return _data.tlObject
            case .pageBlockTitle(let _data):
                return _data.tlObject
            case .pageBlockUnsupported:
                return TLObjectSingleton(TLApiConstructorAt(119))
            case .pageBlockVideo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PageBlock] {
            return tlObjectsAt(object, offset).map { Api.PageBlock(tlObject: $0) }
        }

    }
}
public extension Api.PageBlock.Cons_inputPageBlockMap {
    @_alwaysEmitIntoClient var geo: Api.InputGeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var zoom: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(geo: Api.InputGeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(567))
        tlStoreReference(_tlObject, 40, geo.tlObject)
        tlStore(_tlObject, 24, zoom)
        tlStore(_tlObject, 28, w)
        tlStore(_tlObject, 32, h)
        tlStoreReference(_tlObject, 48, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockAnchor {
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(name: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1370))
        tlStoreReference(_tlObject, 24, name as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockAudio {
    @_alwaysEmitIntoClient var audioId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(audioId: Int64, caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(823))
        tlStore(_tlObject, 24, audioId)
        tlStoreReference(_tlObject, 32, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockAuthorDate {
    @_alwaysEmitIntoClient var author: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var publishedDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(author: Api.RichText, publishedDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1227))
        tlStoreReference(_tlObject, 32, author.tlObject)
        tlStore(_tlObject, 24, publishedDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockBlockquote {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var caption: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, text: Api.RichText, caption: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(659))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, text.tlObject)
        tlStoreReference(_tlObject, 40, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockBlockquoteBlocks {
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var caption: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(blocks: [Api.PageBlock], caption: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(96))
        tlStoreReference(_tlObject, 24, blocks.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockButtonRow {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var buttons: [Api.PageButton] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageButton.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, buttons: [Api.PageButton]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(698))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, buttons.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockChannel {
    @_alwaysEmitIntoClient var channel: Api.Chat {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(channel: Api.Chat) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1584))
        tlStoreReference(_tlObject, 24, channel.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockCollage {
    @_alwaysEmitIntoClient var items: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(items: [Api.PageBlock], caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(651))
        tlStoreReference(_tlObject, 24, items.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockCover {
    @_alwaysEmitIntoClient var cover: Api.PageBlock {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(cover: Api.PageBlock) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(371))
        tlStoreReference(_tlObject, 24, cover.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockDetails {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var title: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(757))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, blocks.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, title.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockDocument {
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(documentId: Int64, caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(362))
        tlStore(_tlObject, 24, documentId)
        tlStoreReference(_tlObject, 32, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockEmbed {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var html: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var posterPhotoId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var w: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var h: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 2) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1094))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, url.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, html.map { value in value as NSString })
        if let _tlValue = posterPhotoId { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = w { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = h { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 64, caption.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockEmbedPost {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var webpageId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var authorPhotoId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var author: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1609))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 40, webpageId)
        tlStore(_tlObject, 48, authorPhotoId)
        tlStoreReference(_tlObject, 56, author as NSString)
        tlStore(_tlObject, 24, date)
        tlStoreReference(_tlObject, 64, blocks.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockFooter {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(463))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockHeader {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1274))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockHeading1 {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1232))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockHeading2 {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(62))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockHeading3 {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(662))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockHeading4 {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1188))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockHeading5 {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1441))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockHeading6 {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(663))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockKicker {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(200))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockList {
    @_alwaysEmitIntoClient var items: [Api.PageListItem] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageListItem.tlArray(self.tlObject, 24) } }
    }
    init(items: [Api.PageListItem]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1503))
        tlStoreReference(_tlObject, 24, items.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockMap {
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var zoom: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1073))
        tlStoreReference(_tlObject, 40, geo.tlObject)
        tlStore(_tlObject, 24, zoom)
        tlStore(_tlObject, 28, w)
        tlStore(_tlObject, 32, h)
        tlStoreReference(_tlObject, 48, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockMath {
    @_alwaysEmitIntoClient var source: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(source: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(579))
        tlStoreReference(_tlObject, 24, source as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockOrderedList {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var items: [Api.PageListOrderedItem] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageListOrderedItem.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var start: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var type: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, items: [Api.PageListOrderedItem], start: Int32?, type: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(215))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, items.map { item in item.tlObject } as NSArray)
        if let _tlValue = start { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, type.map { value in value as NSString })
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockParagraph {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(453))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockPhoto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var photoId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var webpageId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    init(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(146))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, photoId)
        tlStoreReference(_tlObject, 40, caption.tlObject)
        tlStoreReference(_tlObject, 48, url.map { value in value as NSString })
        if let _tlValue = webpageId { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockPreformatted {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var language: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(text: Api.RichText, language: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1279))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, language as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockPullquote {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var caption: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(text: Api.RichText, caption: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(511))
        tlStoreReference(_tlObject, 24, text.tlObject)
        tlStoreReference(_tlObject, 32, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockRelatedArticles {
    @_alwaysEmitIntoClient var title: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var articles: [Api.PageRelatedArticle] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageRelatedArticle.tlArray(self.tlObject, 32) } }
    }
    init(title: Api.RichText, articles: [Api.PageRelatedArticle]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(138))
        tlStoreReference(_tlObject, 24, title.tlObject)
        tlStoreReference(_tlObject, 32, articles.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockSlideshow {
    @_alwaysEmitIntoClient var items: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(items: [Api.PageBlock], caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(23))
        tlStoreReference(_tlObject, 24, items.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockSubheader {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1597))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockSubtitle {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(919))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockTable {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var rows: [Api.PageTableRow] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageTableRow.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1269))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title.tlObject)
        tlStoreReference(_tlObject, 40, rows.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockThinking {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(384))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockTitle {
    @_alwaysEmitIntoClient var text: Api.RichText {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichText(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(text: Api.RichText) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(717))
        tlStoreReference(_tlObject, 24, text.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PageBlock.Cons_pageBlockVideo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var videoId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var caption: Api.PageCaption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageCaption(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, videoId: Int64, caption: Api.PageCaption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(800))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, videoId)
        tlStoreReference(_tlObject, 40, caption.tlObject)
        self.init(tlObject: _tlObject)
    }
}
