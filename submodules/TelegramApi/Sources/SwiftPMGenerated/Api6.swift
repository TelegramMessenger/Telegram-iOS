import TelegramApiObjC
public extension Api {
    enum DialogFilterSuggested: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dialogFilterSuggested {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dialogFilterSuggested(Cons_dialogFilterSuggested)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dialogFilterSuggested(Cons_dialogFilterSuggested(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dialogFilterSuggested(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DialogFilterSuggested] {
            return tlObjectsAt(object, offset).map { Api.DialogFilterSuggested(tlObject: $0) }
        }

    }
}
public extension Api.DialogFilterSuggested.Cons_dialogFilterSuggested {
    @_alwaysEmitIntoClient var filter: Api.DialogFilter {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DialogFilter(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(filter: Api.DialogFilter, description: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(768))
        tlStoreReference(_tlObject, 24, filter.tlObject)
        tlStoreReference(_tlObject, 32, description as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum DialogPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dialogPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dialogPeerCommunity {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dialogPeerFolder {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dialogPeer(Cons_dialogPeer)
        case dialogPeerCommunity(Cons_dialogPeerCommunity)
        case dialogPeerFolder(Cons_dialogPeerFolder)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dialogPeer(Cons_dialogPeer(tlObject: object))
            case 1:
                self = .dialogPeerCommunity(Cons_dialogPeerCommunity(tlObject: object))
            case 2:
                self = .dialogPeerFolder(Cons_dialogPeerFolder(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dialogPeer(let _data):
                return _data.tlObject
            case .dialogPeerCommunity(let _data):
                return _data.tlObject
            case .dialogPeerFolder(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DialogPeer] {
            return tlObjectsAt(object, offset).map { Api.DialogPeer(tlObject: $0) }
        }

    }
}
public extension Api.DialogPeer.Cons_dialogPeer {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.Peer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1509))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DialogPeer.Cons_dialogPeerCommunity {
    @_alwaysEmitIntoClient var communityId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(communityId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(300))
        tlStore(_tlObject, 24, communityId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DialogPeer.Cons_dialogPeerFolder {
    @_alwaysEmitIntoClient var folderId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(folderId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(529))
        tlStore(_tlObject, 24, folderId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum DisallowedGiftsSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_disallowedGiftsSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case disallowedGiftsSettings(Cons_disallowedGiftsSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .disallowedGiftsSettings(Cons_disallowedGiftsSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .disallowedGiftsSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DisallowedGiftsSettings] {
            return tlObjectsAt(object, offset).map { Api.DisallowedGiftsSettings(tlObject: $0) }
        }

    }
}
public extension Api.DisallowedGiftsSettings.Cons_disallowedGiftsSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(728))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Document: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_document {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_documentEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case document(Cons_document)
        case documentEmpty(Cons_documentEmpty)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .document(Cons_document(tlObject: object))
            case 1:
                self = .documentEmpty(Cons_documentEmpty(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .document(let _data):
                return _data.tlObject
            case .documentEmpty(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Document] {
            return tlObjectsAt(object, offset).map { Api.Document(tlObject: $0) }
        }

    }
}
public extension Api.Document.Cons_document {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var mimeType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var size: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var thumbs: [Api.PhotoSize]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.PhotoSize.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var videoThumbs: [Api.VideoSize]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.VideoSize.tlArray(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.DocumentAttribute] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DocumentAttribute.tlArray(self.tlObject, 96) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, mimeType: String, size: Int64, thumbs: [Api.PhotoSize]?, videoThumbs: [Api.VideoSize]?, dcId: Int32, attributes: [Api.DocumentAttribute]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(918))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, id)
        tlStore(_tlObject, 48, accessHash)
        tlStoreReference(_tlObject, 56, fileReference.makeData() as NSData)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 64, mimeType as NSString)
        tlStore(_tlObject, 72, size)
        tlStoreReference(_tlObject, 80, thumbs.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 88, videoThumbs.map { value in value.map { item in item.tlObject } as NSArray })
        tlStore(_tlObject, 32, dcId)
        tlStoreReference(_tlObject, 96, attributes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Document.Cons_documentEmpty {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(351))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum DocumentAttribute: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_documentAttributeAudio {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_documentAttributeCustomEmoji {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_documentAttributeFilename {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_documentAttributeImageSize {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_documentAttributeSticker {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_documentAttributeVideo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case documentAttributeAnimated
        case documentAttributeAudio(Cons_documentAttributeAudio)
        case documentAttributeCustomEmoji(Cons_documentAttributeCustomEmoji)
        case documentAttributeFilename(Cons_documentAttributeFilename)
        case documentAttributeHasStickers
        case documentAttributeImageSize(Cons_documentAttributeImageSize)
        case documentAttributeSticker(Cons_documentAttributeSticker)
        case documentAttributeVideo(Cons_documentAttributeVideo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .documentAttributeAnimated
            case 1:
                self = .documentAttributeAudio(Cons_documentAttributeAudio(tlObject: object))
            case 2:
                self = .documentAttributeCustomEmoji(Cons_documentAttributeCustomEmoji(tlObject: object))
            case 3:
                self = .documentAttributeFilename(Cons_documentAttributeFilename(tlObject: object))
            case 4:
                self = .documentAttributeHasStickers
            case 5:
                self = .documentAttributeImageSize(Cons_documentAttributeImageSize(tlObject: object))
            case 6:
                self = .documentAttributeSticker(Cons_documentAttributeSticker(tlObject: object))
            case 7:
                self = .documentAttributeVideo(Cons_documentAttributeVideo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .documentAttributeAnimated:
                return TLObjectSingleton(TLApiConstructorAt(109))
            case .documentAttributeAudio(let _data):
                return _data.tlObject
            case .documentAttributeCustomEmoji(let _data):
                return _data.tlObject
            case .documentAttributeFilename(let _data):
                return _data.tlObject
            case .documentAttributeHasStickers:
                return TLObjectSingleton(TLApiConstructorAt(974))
            case .documentAttributeImageSize(let _data):
                return _data.tlObject
            case .documentAttributeSticker(let _data):
                return _data.tlObject
            case .documentAttributeVideo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DocumentAttribute] {
            return tlObjectsAt(object, offset).map { Api.DocumentAttribute(tlObject: $0) }
        }

    }
}
public extension Api.DocumentAttribute.Cons_documentAttributeAudio {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var duration: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var performer: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var waveform: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlBufferAt(self.tlObject, 48) } }
    }
    init(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(976))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, duration)
        tlStoreReference(_tlObject, 32, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, performer.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, waveform.map { value in value.makeData() as NSData })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DocumentAttribute.Cons_documentAttributeCustomEmoji {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var alt: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var stickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, alt: String, stickerset: Api.InputStickerSet) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1691))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, alt as NSString)
        tlStoreReference(_tlObject, 40, stickerset.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DocumentAttribute.Cons_documentAttributeFilename {
    @_alwaysEmitIntoClient var fileName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(fileName: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(132))
        tlStoreReference(_tlObject, 24, fileName as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DocumentAttribute.Cons_documentAttributeImageSize {
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(w: Int32, h: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(690))
        tlStore(_tlObject, 24, w)
        tlStore(_tlObject, 28, h)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DocumentAttribute.Cons_documentAttributeSticker {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var alt: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var stickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var maskCoords: Api.MaskCoords? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MaskCoords(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, alt: String, stickerset: Api.InputStickerSet, maskCoords: Api.MaskCoords?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(632))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, alt as NSString)
        tlStoreReference(_tlObject, 40, stickerset.tlObject)
        tlStoreReference(_tlObject, 48, maskCoords?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DocumentAttribute.Cons_documentAttributeVideo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var duration: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var preloadPrefixSize: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var videoStartTs: Double? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Double.self) : nil } }
    }
    @_alwaysEmitIntoClient var videoCodec: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, duration: Double, w: Int32, h: Int32, preloadPrefixSize: Int32?, videoStartTs: Double?, videoCodec: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(441))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, duration)
        tlStore(_tlObject, 28, w)
        tlStore(_tlObject, 32, h)
        if let _tlValue = preloadPrefixSize { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = videoStartTs { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 56, videoCodec.map { value in value as NSString })
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum DraftMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_draftMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_draftMessageEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case draftMessage(Cons_draftMessage)
        case draftMessageEmpty(Cons_draftMessageEmpty)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .draftMessage(Cons_draftMessage(tlObject: object))
            case 1:
                self = .draftMessageEmpty(Cons_draftMessageEmpty(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .draftMessage(let _data):
                return _data.tlObject
            case .draftMessageEmpty(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.DraftMessage] {
            return tlObjectsAt(object, offset).map { Api.DraftMessage(tlObject: $0) }
        }

    }
}
public extension Api.DraftMessage.Cons_draftMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var replyTo: Api.InputReplyTo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.InputReplyTo(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MessageEntity.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var media: Api.InputMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.InputMedia(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var effect: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var suggestedPost: Api.SuggestedPost? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.SuggestedPost(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var richMessage: Api.RichMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.RichMessage(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, replyTo: Api.InputReplyTo?, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, date: Int32, effect: Int64?, suggestedPost: Api.SuggestedPost?, richMessage: Api.RichMessage?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(619))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, replyTo?.tlObject)
        tlStoreReference(_tlObject, 40, message as NSString)
        tlStoreReference(_tlObject, 48, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, media?.tlObject)
        tlStore(_tlObject, 28, date)
        if let _tlValue = effect { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 72, suggestedPost?.tlObject)
        tlStoreReference(_tlObject, 80, richMessage?.tlObject)
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.DraftMessage.Cons_draftMessageEmpty {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 32, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, date: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(175))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = date { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmailVerification: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emailVerificationApple {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_emailVerificationCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_emailVerificationGoogle {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emailVerificationApple(Cons_emailVerificationApple)
        case emailVerificationCode(Cons_emailVerificationCode)
        case emailVerificationGoogle(Cons_emailVerificationGoogle)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emailVerificationApple(Cons_emailVerificationApple(tlObject: object))
            case 1:
                self = .emailVerificationCode(Cons_emailVerificationCode(tlObject: object))
            case 2:
                self = .emailVerificationGoogle(Cons_emailVerificationGoogle(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emailVerificationApple(let _data):
                return _data.tlObject
            case .emailVerificationCode(let _data):
                return _data.tlObject
            case .emailVerificationGoogle(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmailVerification] {
            return tlObjectsAt(object, offset).map { Api.EmailVerification(tlObject: $0) }
        }

    }
}
public extension Api.EmailVerification.Cons_emailVerificationApple {
    @_alwaysEmitIntoClient var token: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(token: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(969))
        tlStoreReference(_tlObject, 24, token as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EmailVerification.Cons_emailVerificationCode {
    @_alwaysEmitIntoClient var code: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(code: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(932))
        tlStoreReference(_tlObject, 24, code as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EmailVerification.Cons_emailVerificationGoogle {
    @_alwaysEmitIntoClient var token: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(token: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1439))
        tlStoreReference(_tlObject, 24, token as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmailVerifyPurpose: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emailVerifyPurposeLoginSetup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emailVerifyPurposeLoginChange
        case emailVerifyPurposeLoginSetup(Cons_emailVerifyPurposeLoginSetup)
        case emailVerifyPurposePassport


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emailVerifyPurposeLoginChange
            case 1:
                self = .emailVerifyPurposeLoginSetup(Cons_emailVerifyPurposeLoginSetup(tlObject: object))
            case 2:
                self = .emailVerifyPurposePassport
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emailVerifyPurposeLoginChange:
                return TLObjectSingleton(TLApiConstructorAt(535))
            case .emailVerifyPurposeLoginSetup(let _data):
                return _data.tlObject
            case .emailVerifyPurposePassport:
                return TLObjectSingleton(TLApiConstructorAt(1242))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmailVerifyPurpose] {
            return tlObjectsAt(object, offset).map { Api.EmailVerifyPurpose(tlObject: $0) }
        }

    }
}
public extension Api.EmailVerifyPurpose.Cons_emailVerifyPurposeLoginSetup {
    @_alwaysEmitIntoClient var phoneNumber: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var phoneCodeHash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(phoneNumber: String, phoneCodeHash: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(437))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, phoneCodeHash as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmojiGroup: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiGroup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_emojiGroupGreeting {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_emojiGroupPremium {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiGroup(Cons_emojiGroup)
        case emojiGroupGreeting(Cons_emojiGroupGreeting)
        case emojiGroupPremium(Cons_emojiGroupPremium)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiGroup(Cons_emojiGroup(tlObject: object))
            case 1:
                self = .emojiGroupGreeting(Cons_emojiGroupGreeting(tlObject: object))
            case 2:
                self = .emojiGroupPremium(Cons_emojiGroupPremium(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiGroup(let _data):
                return _data.tlObject
            case .emojiGroupGreeting(let _data):
                return _data.tlObject
            case .emojiGroupPremium(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmojiGroup] {
            return tlObjectsAt(object, offset).map { Api.EmojiGroup(tlObject: $0) }
        }

    }
}
public extension Api.EmojiGroup.Cons_emojiGroup {
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var iconEmojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var emoticons: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 40) } }
    }
    init(title: String, iconEmojiId: Int64, emoticons: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(790))
        tlStoreReference(_tlObject, 24, title as NSString)
        tlStore(_tlObject, 32, iconEmojiId)
        tlStoreReference(_tlObject, 40, emoticons as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EmojiGroup.Cons_emojiGroupGreeting {
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var iconEmojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var emoticons: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 40) } }
    }
    init(title: String, iconEmojiId: Int64, emoticons: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(827))
        tlStoreReference(_tlObject, 24, title as NSString)
        tlStore(_tlObject, 32, iconEmojiId)
        tlStoreReference(_tlObject, 40, emoticons as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EmojiGroup.Cons_emojiGroupPremium {
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var iconEmojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(title: String, iconEmojiId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(59))
        tlStoreReference(_tlObject, 24, title as NSString)
        tlStore(_tlObject, 32, iconEmojiId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmojiKeyword: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiKeyword {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_emojiKeywordDeleted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiKeyword(Cons_emojiKeyword)
        case emojiKeywordDeleted(Cons_emojiKeywordDeleted)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiKeyword(Cons_emojiKeyword(tlObject: object))
            case 1:
                self = .emojiKeywordDeleted(Cons_emojiKeywordDeleted(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiKeyword(let _data):
                return _data.tlObject
            case .emojiKeywordDeleted(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmojiKeyword] {
            return tlObjectsAt(object, offset).map { Api.EmojiKeyword(tlObject: $0) }
        }

    }
}
public extension Api.EmojiKeyword.Cons_emojiKeyword {
    @_alwaysEmitIntoClient var keyword: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var emoticons: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 32) } }
    }
    init(keyword: String, emoticons: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1404))
        tlStoreReference(_tlObject, 24, keyword as NSString)
        tlStoreReference(_tlObject, 32, emoticons as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EmojiKeyword.Cons_emojiKeywordDeleted {
    @_alwaysEmitIntoClient var keyword: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var emoticons: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 32) } }
    }
    init(keyword: String, emoticons: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(241))
        tlStoreReference(_tlObject, 24, keyword as NSString)
        tlStoreReference(_tlObject, 32, emoticons as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmojiKeywordsDifference: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiKeywordsDifference {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiKeywordsDifference(Cons_emojiKeywordsDifference)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiKeywordsDifference(Cons_emojiKeywordsDifference(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiKeywordsDifference(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmojiKeywordsDifference] {
            return tlObjectsAt(object, offset).map { Api.EmojiKeywordsDifference(tlObject: $0) }
        }

    }
}
public extension Api.EmojiKeywordsDifference.Cons_emojiKeywordsDifference {
    @_alwaysEmitIntoClient var langCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var fromVersion: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var keywords: [Api.EmojiKeyword] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EmojiKeyword.tlArray(self.tlObject, 40) } }
    }
    init(langCode: String, fromVersion: Int32, version: Int32, keywords: [Api.EmojiKeyword]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(595))
        tlStoreReference(_tlObject, 32, langCode as NSString)
        tlStore(_tlObject, 24, fromVersion)
        tlStore(_tlObject, 28, version)
        tlStoreReference(_tlObject, 40, keywords.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmojiLanguage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiLanguage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiLanguage(Cons_emojiLanguage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiLanguage(Cons_emojiLanguage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiLanguage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmojiLanguage] {
            return tlObjectsAt(object, offset).map { Api.EmojiLanguage(tlObject: $0) }
        }

    }
}
public extension Api.EmojiLanguage.Cons_emojiLanguage {
    @_alwaysEmitIntoClient var langCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(langCode: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1173))
        tlStoreReference(_tlObject, 24, langCode as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmojiList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiList(Cons_emojiList)
        case emojiListNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiList(Cons_emojiList(tlObject: object))
            case 1:
                self = .emojiListNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiList(let _data):
                return _data.tlObject
            case .emojiListNotModified:
                return TLObjectSingleton(TLApiConstructorAt(459))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmojiList] {
            return tlObjectsAt(object, offset).map { Api.EmojiList(tlObject: $0) }
        }

    }
}
public extension Api.EmojiList.Cons_emojiList {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var documentId: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 32) } }
    }
    init(hash: Int64, documentId: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(785))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, tlPackInt64(documentId) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmojiStatus: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiStatus {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_emojiStatusCollectible {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputEmojiStatusCollectible {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiStatus(Cons_emojiStatus)
        case emojiStatusCollectible(Cons_emojiStatusCollectible)
        case emojiStatusEmpty
        case inputEmojiStatusCollectible(Cons_inputEmojiStatusCollectible)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiStatus(Cons_emojiStatus(tlObject: object))
            case 1:
                self = .emojiStatusCollectible(Cons_emojiStatusCollectible(tlObject: object))
            case 2:
                self = .emojiStatusEmpty
            case 3:
                self = .inputEmojiStatusCollectible(Cons_inputEmojiStatusCollectible(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiStatus(let _data):
                return _data.tlObject
            case .emojiStatusCollectible(let _data):
                return _data.tlObject
            case .emojiStatusEmpty:
                return TLObjectSingleton(TLApiConstructorAt(286))
            case .inputEmojiStatusCollectible(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmojiStatus] {
            return tlObjectsAt(object, offset).map { Api.EmojiStatus(tlObject: $0) }
        }

    }
}
public extension Api.EmojiStatus.Cons_emojiStatus {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var until: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, documentId: Int64, until: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1526))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, documentId)
        if let _tlValue = until { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EmojiStatus.Cons_emojiStatusCollectible {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var collectibleId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var patternDocumentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var centerColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var edgeColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var patternColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var textColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var until: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    init(flags: Int32, collectibleId: Int64, documentId: Int64, title: String, slug: String, patternDocumentId: Int64, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, until: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(724))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 48, collectibleId)
        tlStore(_tlObject, 56, documentId)
        tlStoreReference(_tlObject, 64, title as NSString)
        tlStoreReference(_tlObject, 72, slug as NSString)
        tlStore(_tlObject, 80, patternDocumentId)
        tlStore(_tlObject, 28, centerColor)
        tlStore(_tlObject, 32, edgeColor)
        tlStore(_tlObject, 36, patternColor)
        tlStore(_tlObject, 40, textColor)
        if let _tlValue = until { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EmojiStatus.Cons_inputEmojiStatusCollectible {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var collectibleId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var until: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, collectibleId: Int64, until: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(50))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, collectibleId)
        if let _tlValue = until { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EmojiURL: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiURL {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiURL(Cons_emojiURL)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiURL(Cons_emojiURL(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiURL(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EmojiURL] {
            return tlObjectsAt(object, offset).map { Api.EmojiURL(tlObject: $0) }
        }

    }
}
public extension Api.EmojiURL.Cons_emojiURL {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1083))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EncryptedChat: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_encryptedChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_encryptedChatDiscarded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_encryptedChatEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_encryptedChatRequested {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_encryptedChatWaiting {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case encryptedChat(Cons_encryptedChat)
        case encryptedChatDiscarded(Cons_encryptedChatDiscarded)
        case encryptedChatEmpty(Cons_encryptedChatEmpty)
        case encryptedChatRequested(Cons_encryptedChatRequested)
        case encryptedChatWaiting(Cons_encryptedChatWaiting)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .encryptedChat(Cons_encryptedChat(tlObject: object))
            case 1:
                self = .encryptedChatDiscarded(Cons_encryptedChatDiscarded(tlObject: object))
            case 2:
                self = .encryptedChatEmpty(Cons_encryptedChatEmpty(tlObject: object))
            case 3:
                self = .encryptedChatRequested(Cons_encryptedChatRequested(tlObject: object))
            case 4:
                self = .encryptedChatWaiting(Cons_encryptedChatWaiting(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .encryptedChat(let _data):
                return _data.tlObject
            case .encryptedChatDiscarded(let _data):
                return _data.tlObject
            case .encryptedChatEmpty(let _data):
                return _data.tlObject
            case .encryptedChatRequested(let _data):
                return _data.tlObject
            case .encryptedChatWaiting(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EncryptedChat] {
            return tlObjectsAt(object, offset).map { Api.EncryptedChat(tlObject: $0) }
        }

    }
}
public extension Api.EncryptedChat.Cons_encryptedChat {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var gAOrB: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var keyFingerprint: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    init(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(623))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 40, adminId)
        tlStore(_tlObject, 48, participantId)
        tlStoreReference(_tlObject, 56, gAOrB.makeData() as NSData)
        tlStore(_tlObject, 64, keyFingerprint)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EncryptedChat.Cons_encryptedChatDiscarded {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(201))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EncryptedChat.Cons_encryptedChatEmpty {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1120))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EncryptedChat.Cons_encryptedChatRequested {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var folderId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var gA: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 64) } }
    }
    init(flags: Int32, folderId: Int32?, id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gA: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(468))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = folderId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStore(_tlObject, 36, date)
        tlStore(_tlObject, 48, adminId)
        tlStore(_tlObject, 56, participantId)
        tlStoreReference(_tlObject, 64, gA.makeData() as NSData)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EncryptedChat.Cons_encryptedChatWaiting {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    init(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(659))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 40, adminId)
        tlStore(_tlObject, 48, participantId)
        self.init(tlObject: _tlObject)
    }
}
