public extension Api {
    indirect enum InputInvoice: TypeConstructorDescription {
        case inputInvoiceChatInviteSubscription(hash: String)
        case inputInvoiceMessage(peer: Api.InputPeer, msgId: Int32)
        case inputInvoicePremiumGiftCode(purpose: Api.InputStorePaymentPurpose, option: Api.PremiumGiftCodeOption)
        case inputInvoiceSlug(slug: String)
        case inputInvoiceStarGift(flags: Int32, userId: Api.InputUser, giftId: Int64, message: Api.TextWithEntities?)
        case inputInvoiceStars(purpose: Api.InputStorePaymentPurpose)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputInvoiceChatInviteSubscription(let hash):
                    if boxed {
                        buffer.appendInt32(887591921)
                    }
                    serializeString(hash, buffer: buffer, boxed: false)
                    break
                case .inputInvoiceMessage(let peer, let msgId):
                    if boxed {
                        buffer.appendInt32(-977967015)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .inputInvoicePremiumGiftCode(let purpose, let option):
                    if boxed {
                        buffer.appendInt32(-1734841331)
                    }
                    purpose.serialize(buffer, true)
                    option.serialize(buffer, true)
                    break
                case .inputInvoiceSlug(let slug):
                    if boxed {
                        buffer.appendInt32(-1020867857)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
                case .inputInvoiceStarGift(let flags, let userId, let giftId, let message):
                    if boxed {
                        buffer.appendInt32(634962392)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt64(giftId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {message!.serialize(buffer, true)}
                    break
                case .inputInvoiceStars(let purpose):
                    if boxed {
                        buffer.appendInt32(1710230755)
                    }
                    purpose.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputInvoiceChatInviteSubscription(let hash):
                return ("inputInvoiceChatInviteSubscription", [("hash", hash as Any)])
                case .inputInvoiceMessage(let peer, let msgId):
                return ("inputInvoiceMessage", [("peer", peer as Any), ("msgId", msgId as Any)])
                case .inputInvoicePremiumGiftCode(let purpose, let option):
                return ("inputInvoicePremiumGiftCode", [("purpose", purpose as Any), ("option", option as Any)])
                case .inputInvoiceSlug(let slug):
                return ("inputInvoiceSlug", [("slug", slug as Any)])
                case .inputInvoiceStarGift(let flags, let userId, let giftId, let message):
                return ("inputInvoiceStarGift", [("flags", flags as Any), ("userId", userId as Any), ("giftId", giftId as Any), ("message", message as Any)])
                case .inputInvoiceStars(let purpose):
                return ("inputInvoiceStars", [("purpose", purpose as Any)])
    }
    }
    
        public static func parse_inputInvoiceChatInviteSubscription(_ reader: BufferReader) -> InputInvoice? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoiceChatInviteSubscription(hash: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceMessage(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoiceMessage(peer: _1!, msgId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoicePremiumGiftCode(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputStorePaymentPurpose?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStorePaymentPurpose
            }
            var _2: Api.PremiumGiftCodeOption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PremiumGiftCodeOption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoicePremiumGiftCode(purpose: _1!, option: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceSlug(_ reader: BufferReader) -> InputInvoice? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoiceSlug(slug: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGift(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputUser?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputInvoice.inputInvoiceStarGift(flags: _1!, userId: _2!, giftId: _3!, message: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStars(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputStorePaymentPurpose?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStorePaymentPurpose
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoiceStars(purpose: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputMedia: TypeConstructorDescription {
        case inputMediaContact(phoneNumber: String, firstName: String, lastName: String, vcard: String)
        case inputMediaDice(emoticon: String)
        case inputMediaDocument(flags: Int32, id: Api.InputDocument, ttlSeconds: Int32?, query: String?)
        case inputMediaDocumentExternal(flags: Int32, url: String, ttlSeconds: Int32?)
        case inputMediaEmpty
        case inputMediaGame(id: Api.InputGame)
        case inputMediaGeoLive(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?)
        case inputMediaGeoPoint(geoPoint: Api.InputGeoPoint)
        case inputMediaInvoice(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String?, providerData: Api.DataJSON, startParam: String?, extendedMedia: Api.InputMedia?)
        case inputMediaPaidMedia(flags: Int32, starsAmount: Int64, extendedMedia: [Api.InputMedia], payload: String?)
        case inputMediaPhoto(flags: Int32, id: Api.InputPhoto, ttlSeconds: Int32?)
        case inputMediaPhotoExternal(flags: Int32, url: String, ttlSeconds: Int32?)
        case inputMediaPoll(flags: Int32, poll: Api.Poll, correctAnswers: [Buffer]?, solution: String?, solutionEntities: [Api.MessageEntity]?)
        case inputMediaStory(peer: Api.InputPeer, id: Int32)
        case inputMediaUploadedDocument(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, mimeType: String, attributes: [Api.DocumentAttribute], stickers: [Api.InputDocument]?, ttlSeconds: Int32?)
        case inputMediaUploadedPhoto(flags: Int32, file: Api.InputFile, stickers: [Api.InputDocument]?, ttlSeconds: Int32?)
        case inputMediaVenue(geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case inputMediaWebPage(flags: Int32, url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMediaContact(let phoneNumber, let firstName, let lastName, let vcard):
                    if boxed {
                        buffer.appendInt32(-122978821)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    break
                case .inputMediaDice(let emoticon):
                    if boxed {
                        buffer.appendInt32(-428884101)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .inputMediaDocument(let flags, let id, let ttlSeconds, let query):
                    if boxed {
                        buffer.appendInt32(860303448)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(query!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaDocumentExternal(let flags, let url, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-78455655)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaEmpty:
                    if boxed {
                        buffer.appendInt32(-1771768449)
                    }
                    
                    break
                case .inputMediaGame(let id):
                    if boxed {
                        buffer.appendInt32(-750828557)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputMediaGeoLive(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius):
                    if boxed {
                        buffer.appendInt32(-1759532989)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(heading!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(period!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(proximityNotificationRadius!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaGeoPoint(let geoPoint):
                    if boxed {
                        buffer.appendInt32(-104578748)
                    }
                    geoPoint.serialize(buffer, true)
                    break
                case .inputMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let startParam, let extendedMedia):
                    if boxed {
                        buffer.appendInt32(1080028941)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(provider!, buffer: buffer, boxed: false)}
                    providerData.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {extendedMedia!.serialize(buffer, true)}
                    break
                case .inputMediaPaidMedia(let flags, let starsAmount, let extendedMedia, let payload):
                    if boxed {
                        buffer.appendInt32(-1005571194)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(starsAmount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(extendedMedia.count))
                    for item in extendedMedia {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(payload!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaPhoto(let flags, let id, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-1279654347)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaPhotoExternal(let flags, let url, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-440664550)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaPoll(let flags, let poll, let correctAnswers, let solution, let solutionEntities):
                    if boxed {
                        buffer.appendInt32(261416433)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    poll.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(correctAnswers!.count))
                    for item in correctAnswers! {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(solution!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(solutionEntities!.count))
                    for item in solutionEntities! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .inputMediaStory(let peer, let id):
                    if boxed {
                        buffer.appendInt32(-1979852936)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .inputMediaUploadedDocument(let flags, let file, let thumb, let mimeType, let attributes, let stickers, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(1530447553)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {thumb!.serialize(buffer, true)}
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers!.count))
                    for item in stickers! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaUploadedPhoto(let flags, let file, let stickers, let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(505969924)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers!.count))
                    for item in stickers! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(ttlSeconds!, buffer: buffer, boxed: false)}
                    break
                case .inputMediaVenue(let geoPoint, let title, let address, let provider, let venueId, let venueType):
                    if boxed {
                        buffer.appendInt32(-1052959727)
                    }
                    geoPoint.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    break
                case .inputMediaWebPage(let flags, let url):
                    if boxed {
                        buffer.appendInt32(-1038383031)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMediaContact(let phoneNumber, let firstName, let lastName, let vcard):
                return ("inputMediaContact", [("phoneNumber", phoneNumber as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("vcard", vcard as Any)])
                case .inputMediaDice(let emoticon):
                return ("inputMediaDice", [("emoticon", emoticon as Any)])
                case .inputMediaDocument(let flags, let id, let ttlSeconds, let query):
                return ("inputMediaDocument", [("flags", flags as Any), ("id", id as Any), ("ttlSeconds", ttlSeconds as Any), ("query", query as Any)])
                case .inputMediaDocumentExternal(let flags, let url, let ttlSeconds):
                return ("inputMediaDocumentExternal", [("flags", flags as Any), ("url", url as Any), ("ttlSeconds", ttlSeconds as Any)])
                case .inputMediaEmpty:
                return ("inputMediaEmpty", [])
                case .inputMediaGame(let id):
                return ("inputMediaGame", [("id", id as Any)])
                case .inputMediaGeoLive(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius):
                return ("inputMediaGeoLive", [("flags", flags as Any), ("geoPoint", geoPoint as Any), ("heading", heading as Any), ("period", period as Any), ("proximityNotificationRadius", proximityNotificationRadius as Any)])
                case .inputMediaGeoPoint(let geoPoint):
                return ("inputMediaGeoPoint", [("geoPoint", geoPoint as Any)])
                case .inputMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let startParam, let extendedMedia):
                return ("inputMediaInvoice", [("flags", flags as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("payload", payload as Any), ("provider", provider as Any), ("providerData", providerData as Any), ("startParam", startParam as Any), ("extendedMedia", extendedMedia as Any)])
                case .inputMediaPaidMedia(let flags, let starsAmount, let extendedMedia, let payload):
                return ("inputMediaPaidMedia", [("flags", flags as Any), ("starsAmount", starsAmount as Any), ("extendedMedia", extendedMedia as Any), ("payload", payload as Any)])
                case .inputMediaPhoto(let flags, let id, let ttlSeconds):
                return ("inputMediaPhoto", [("flags", flags as Any), ("id", id as Any), ("ttlSeconds", ttlSeconds as Any)])
                case .inputMediaPhotoExternal(let flags, let url, let ttlSeconds):
                return ("inputMediaPhotoExternal", [("flags", flags as Any), ("url", url as Any), ("ttlSeconds", ttlSeconds as Any)])
                case .inputMediaPoll(let flags, let poll, let correctAnswers, let solution, let solutionEntities):
                return ("inputMediaPoll", [("flags", flags as Any), ("poll", poll as Any), ("correctAnswers", correctAnswers as Any), ("solution", solution as Any), ("solutionEntities", solutionEntities as Any)])
                case .inputMediaStory(let peer, let id):
                return ("inputMediaStory", [("peer", peer as Any), ("id", id as Any)])
                case .inputMediaUploadedDocument(let flags, let file, let thumb, let mimeType, let attributes, let stickers, let ttlSeconds):
                return ("inputMediaUploadedDocument", [("flags", flags as Any), ("file", file as Any), ("thumb", thumb as Any), ("mimeType", mimeType as Any), ("attributes", attributes as Any), ("stickers", stickers as Any), ("ttlSeconds", ttlSeconds as Any)])
                case .inputMediaUploadedPhoto(let flags, let file, let stickers, let ttlSeconds):
                return ("inputMediaUploadedPhoto", [("flags", flags as Any), ("file", file as Any), ("stickers", stickers as Any), ("ttlSeconds", ttlSeconds as Any)])
                case .inputMediaVenue(let geoPoint, let title, let address, let provider, let venueId, let venueType):
                return ("inputMediaVenue", [("geoPoint", geoPoint as Any), ("title", title as Any), ("address", address as Any), ("provider", provider as Any), ("venueId", venueId as Any), ("venueType", venueType as Any)])
                case .inputMediaWebPage(let flags, let url):
                return ("inputMediaWebPage", [("flags", flags as Any), ("url", url as Any)])
    }
    }
    
        public static func parse_inputMediaContact(_ reader: BufferReader) -> InputMedia? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, vcard: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDice(_ reader: BufferReader) -> InputMedia? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaDice(emoticon: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDocument(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaDocument(flags: _1!, id: _2!, ttlSeconds: _3, query: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaDocumentExternal(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaDocumentExternal(flags: _1!, url: _2!, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaEmpty(_ reader: BufferReader) -> InputMedia? {
            return Api.InputMedia.inputMediaEmpty
        }
        public static func parse_inputMediaGame(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGame?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGame
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaGame(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaGeoLive(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputMedia.inputMediaGeoLive(flags: _1!, geoPoint: _2!, heading: _3, period: _4, proximityNotificationRadius: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaGeoPoint(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMedia.inputMediaGeoPoint(geoPoint: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaInvoice(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
            } }
            var _5: Api.Invoice?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = parseString(reader) }
            var _8: Api.DataJSON?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _9: String?
            if Int(_1!) & Int(1 << 1) != 0 {_9 = parseString(reader) }
            var _10: Api.InputMedia?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.InputMedia
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 2) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.InputMedia.inputMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, invoice: _5!, payload: _6!, provider: _7, providerData: _8!, startParam: _9, extendedMedia: _10)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPaidMedia(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.InputMedia]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputMedia.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaPaidMedia(flags: _1!, starsAmount: _2!, extendedMedia: _3!, payload: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPhoto(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaPhoto(flags: _1!, id: _2!, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPhotoExternal(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputMedia.inputMediaPhotoExternal(flags: _1!, url: _2!, ttlSeconds: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaPoll(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Poll?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Poll
            }
            var _3: [Buffer]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputMedia.inputMediaPoll(flags: _1!, poll: _2!, correctAnswers: _3, solution: _4, solutionEntities: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaStory(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMedia.inputMediaStory(peer: _1!, id: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaUploadedDocument(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            }
            var _3: Api.InputFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            var _6: [Api.InputDocument]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputDocument.self)
            } }
            var _7: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputMedia.inputMediaUploadedDocument(flags: _1!, file: _2!, thumb: _3, mimeType: _4!, attributes: _5!, stickers: _6, ttlSeconds: _7)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaUploadedPhoto(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            }
            var _3: [Api.InputDocument]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputDocument.self)
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputMedia.inputMediaUploadedPhoto(flags: _1!, file: _2!, stickers: _3, ttlSeconds: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaVenue(_ reader: BufferReader) -> InputMedia? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputMedia.inputMediaVenue(geoPoint: _1!, title: _2!, address: _3!, provider: _4!, venueId: _5!, venueType: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaWebPage(_ reader: BufferReader) -> InputMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMedia.inputMediaWebPage(flags: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputMessage: TypeConstructorDescription {
        case inputMessageCallbackQuery(id: Int32, queryId: Int64)
        case inputMessageID(id: Int32)
        case inputMessagePinned
        case inputMessageReplyTo(id: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMessageCallbackQuery(let id, let queryId):
                    if boxed {
                        buffer.appendInt32(-1392895362)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    break
                case .inputMessageID(let id):
                    if boxed {
                        buffer.appendInt32(-1502174430)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .inputMessagePinned:
                    if boxed {
                        buffer.appendInt32(-2037963464)
                    }
                    
                    break
                case .inputMessageReplyTo(let id):
                    if boxed {
                        buffer.appendInt32(-1160215659)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMessageCallbackQuery(let id, let queryId):
                return ("inputMessageCallbackQuery", [("id", id as Any), ("queryId", queryId as Any)])
                case .inputMessageID(let id):
                return ("inputMessageID", [("id", id as Any)])
                case .inputMessagePinned:
                return ("inputMessagePinned", [])
                case .inputMessageReplyTo(let id):
                return ("inputMessageReplyTo", [("id", id as Any)])
    }
    }
    
        public static func parse_inputMessageCallbackQuery(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputMessage.inputMessageCallbackQuery(id: _1!, queryId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessageID(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageID(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessagePinned(_ reader: BufferReader) -> InputMessage? {
            return Api.InputMessage.inputMessagePinned
        }
        public static func parse_inputMessageReplyTo(_ reader: BufferReader) -> InputMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputMessage.inputMessageReplyTo(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputNotifyPeer: TypeConstructorDescription {
        case inputNotifyBroadcasts
        case inputNotifyChats
        case inputNotifyForumTopic(peer: Api.InputPeer, topMsgId: Int32)
        case inputNotifyPeer(peer: Api.InputPeer)
        case inputNotifyUsers
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputNotifyBroadcasts:
                    if boxed {
                        buffer.appendInt32(-1311015810)
                    }
                    
                    break
                case .inputNotifyChats:
                    if boxed {
                        buffer.appendInt32(1251338318)
                    }
                    
                    break
                case .inputNotifyForumTopic(let peer, let topMsgId):
                    if boxed {
                        buffer.appendInt32(1548122514)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    break
                case .inputNotifyPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-1195615476)
                    }
                    peer.serialize(buffer, true)
                    break
                case .inputNotifyUsers:
                    if boxed {
                        buffer.appendInt32(423314455)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputNotifyBroadcasts:
                return ("inputNotifyBroadcasts", [])
                case .inputNotifyChats:
                return ("inputNotifyChats", [])
                case .inputNotifyForumTopic(let peer, let topMsgId):
                return ("inputNotifyForumTopic", [("peer", peer as Any), ("topMsgId", topMsgId as Any)])
                case .inputNotifyPeer(let peer):
                return ("inputNotifyPeer", [("peer", peer as Any)])
                case .inputNotifyUsers:
                return ("inputNotifyUsers", [])
    }
    }
    
        public static func parse_inputNotifyBroadcasts(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyBroadcasts
        }
        public static func parse_inputNotifyChats(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyChats
        }
        public static func parse_inputNotifyForumTopic(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputNotifyPeer.inputNotifyForumTopic(peer: _1!, topMsgId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputNotifyPeer(_ reader: BufferReader) -> InputNotifyPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputNotifyPeer.inputNotifyPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputNotifyUsers(_ reader: BufferReader) -> InputNotifyPeer? {
            return Api.InputNotifyPeer.inputNotifyUsers
        }
    
    }
}
