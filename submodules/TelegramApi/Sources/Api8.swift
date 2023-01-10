public extension Api {
    indirect enum InputGame: TypeConstructorDescription {
        case inputGameID(id: Int64, accessHash: Int64)
        case inputGameShortName(botId: Api.InputUser, shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputGameID(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(53231223)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputGameShortName(let botId, let shortName):
                    if boxed {
                        buffer.appendInt32(-1020139510)
                    }
                    botId.serialize(buffer, true)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputGameID(let id, let accessHash):
                return ("inputGameID", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputGameShortName(let botId, let shortName):
                return ("inputGameShortName", [("botId", String(describing: botId)), ("shortName", String(describing: shortName))])
    }
    }
    
        public static func parse_inputGameID(_ reader: BufferReader) -> InputGame? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGame.inputGameID(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputGameShortName(_ reader: BufferReader) -> InputGame? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGame.inputGameShortName(botId: _1!, shortName: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputGeoPoint: TypeConstructorDescription {
        case inputGeoPoint(flags: Int32, lat: Double, long: Double, accuracyRadius: Int32?)
        case inputGeoPointEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputGeoPoint(let flags, let lat, let long, let accuracyRadius):
                    if boxed {
                        buffer.appendInt32(1210199983)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeDouble(lat, buffer: buffer, boxed: false)
                    serializeDouble(long, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(accuracyRadius!, buffer: buffer, boxed: false)}
                    break
                case .inputGeoPointEmpty:
                    if boxed {
                        buffer.appendInt32(-457104426)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputGeoPoint(let flags, let lat, let long, let accuracyRadius):
                return ("inputGeoPoint", [("flags", String(describing: flags)), ("lat", String(describing: lat)), ("long", String(describing: long)), ("accuracyRadius", String(describing: accuracyRadius))])
                case .inputGeoPointEmpty:
                return ("inputGeoPointEmpty", [])
    }
    }
    
        public static func parse_inputGeoPoint(_ reader: BufferReader) -> InputGeoPoint? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputGeoPoint.inputGeoPoint(flags: _1!, lat: _2!, long: _3!, accuracyRadius: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputGeoPointEmpty(_ reader: BufferReader) -> InputGeoPoint? {
            return Api.InputGeoPoint.inputGeoPointEmpty
        }
    
    }
}
public extension Api {
    enum InputGroupCall: TypeConstructorDescription {
        case inputGroupCall(id: Int64, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputGroupCall(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-659913713)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputGroupCall(let id, let accessHash):
                return ("inputGroupCall", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
    }
    }
    
        public static func parse_inputGroupCall(_ reader: BufferReader) -> InputGroupCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGroupCall.inputGroupCall(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputInvoice: TypeConstructorDescription {
        case inputInvoiceMessage(peer: Api.InputPeer, msgId: Int32)
        case inputInvoiceSlug(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputInvoiceMessage(let peer, let msgId):
                    if boxed {
                        buffer.appendInt32(-977967015)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .inputInvoiceSlug(let slug):
                    if boxed {
                        buffer.appendInt32(-1020867857)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputInvoiceMessage(let peer, let msgId):
                return ("inputInvoiceMessage", [("peer", String(describing: peer)), ("msgId", String(describing: msgId))])
                case .inputInvoiceSlug(let slug):
                return ("inputInvoiceSlug", [("slug", String(describing: slug))])
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
        case inputMediaInvoice(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, startParam: String?, extendedMedia: Api.InputMedia?)
        case inputMediaPhoto(flags: Int32, id: Api.InputPhoto, ttlSeconds: Int32?)
        case inputMediaPhotoExternal(flags: Int32, url: String, ttlSeconds: Int32?)
        case inputMediaPoll(flags: Int32, poll: Api.Poll, correctAnswers: [Buffer]?, solution: String?, solutionEntities: [Api.MessageEntity]?)
        case inputMediaUploadedDocument(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, mimeType: String, attributes: [Api.DocumentAttribute], stickers: [Api.InputDocument]?, ttlSeconds: Int32?)
        case inputMediaUploadedPhoto(flags: Int32, file: Api.InputFile, stickers: [Api.InputDocument]?, ttlSeconds: Int32?)
        case inputMediaVenue(geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
    
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
                        buffer.appendInt32(-1900697899)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    providerData.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {extendedMedia!.serialize(buffer, true)}
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
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMediaContact(let phoneNumber, let firstName, let lastName, let vcard):
                return ("inputMediaContact", [("phoneNumber", String(describing: phoneNumber)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("vcard", String(describing: vcard))])
                case .inputMediaDice(let emoticon):
                return ("inputMediaDice", [("emoticon", String(describing: emoticon))])
                case .inputMediaDocument(let flags, let id, let ttlSeconds, let query):
                return ("inputMediaDocument", [("flags", String(describing: flags)), ("id", String(describing: id)), ("ttlSeconds", String(describing: ttlSeconds)), ("query", String(describing: query))])
                case .inputMediaDocumentExternal(let flags, let url, let ttlSeconds):
                return ("inputMediaDocumentExternal", [("flags", String(describing: flags)), ("url", String(describing: url)), ("ttlSeconds", String(describing: ttlSeconds))])
                case .inputMediaEmpty:
                return ("inputMediaEmpty", [])
                case .inputMediaGame(let id):
                return ("inputMediaGame", [("id", String(describing: id))])
                case .inputMediaGeoLive(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius):
                return ("inputMediaGeoLive", [("flags", String(describing: flags)), ("geoPoint", String(describing: geoPoint)), ("heading", String(describing: heading)), ("period", String(describing: period)), ("proximityNotificationRadius", String(describing: proximityNotificationRadius))])
                case .inputMediaGeoPoint(let geoPoint):
                return ("inputMediaGeoPoint", [("geoPoint", String(describing: geoPoint))])
                case .inputMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let startParam, let extendedMedia):
                return ("inputMediaInvoice", [("flags", String(describing: flags)), ("title", String(describing: title)), ("description", String(describing: description)), ("photo", String(describing: photo)), ("invoice", String(describing: invoice)), ("payload", String(describing: payload)), ("provider", String(describing: provider)), ("providerData", String(describing: providerData)), ("startParam", String(describing: startParam)), ("extendedMedia", String(describing: extendedMedia))])
                case .inputMediaPhoto(let flags, let id, let ttlSeconds):
                return ("inputMediaPhoto", [("flags", String(describing: flags)), ("id", String(describing: id)), ("ttlSeconds", String(describing: ttlSeconds))])
                case .inputMediaPhotoExternal(let flags, let url, let ttlSeconds):
                return ("inputMediaPhotoExternal", [("flags", String(describing: flags)), ("url", String(describing: url)), ("ttlSeconds", String(describing: ttlSeconds))])
                case .inputMediaPoll(let flags, let poll, let correctAnswers, let solution, let solutionEntities):
                return ("inputMediaPoll", [("flags", String(describing: flags)), ("poll", String(describing: poll)), ("correctAnswers", String(describing: correctAnswers)), ("solution", String(describing: solution)), ("solutionEntities", String(describing: solutionEntities))])
                case .inputMediaUploadedDocument(let flags, let file, let thumb, let mimeType, let attributes, let stickers, let ttlSeconds):
                return ("inputMediaUploadedDocument", [("flags", String(describing: flags)), ("file", String(describing: file)), ("thumb", String(describing: thumb)), ("mimeType", String(describing: mimeType)), ("attributes", String(describing: attributes)), ("stickers", String(describing: stickers)), ("ttlSeconds", String(describing: ttlSeconds))])
                case .inputMediaUploadedPhoto(let flags, let file, let stickers, let ttlSeconds):
                return ("inputMediaUploadedPhoto", [("flags", String(describing: flags)), ("file", String(describing: file)), ("stickers", String(describing: stickers)), ("ttlSeconds", String(describing: ttlSeconds))])
                case .inputMediaVenue(let geoPoint, let title, let address, let provider, let venueId, let venueType):
                return ("inputMediaVenue", [("geoPoint", String(describing: geoPoint)), ("title", String(describing: title)), ("address", String(describing: address)), ("provider", String(describing: provider)), ("venueId", String(describing: venueId)), ("venueType", String(describing: venueType))])
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
            _7 = parseString(reader)
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
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 2) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.InputMedia.inputMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, invoice: _5!, payload: _6!, provider: _7!, providerData: _8!, startParam: _9, extendedMedia: _10)
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
                return ("inputMessageCallbackQuery", [("id", String(describing: id)), ("queryId", String(describing: queryId))])
                case .inputMessageID(let id):
                return ("inputMessageID", [("id", String(describing: id))])
                case .inputMessagePinned:
                return ("inputMessagePinned", [])
                case .inputMessageReplyTo(let id):
                return ("inputMessageReplyTo", [("id", String(describing: id))])
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
                return ("inputNotifyForumTopic", [("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId))])
                case .inputNotifyPeer(let peer):
                return ("inputNotifyPeer", [("peer", String(describing: peer))])
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
public extension Api {
    enum InputPaymentCredentials: TypeConstructorDescription {
        case inputPaymentCredentials(flags: Int32, data: Api.DataJSON)
        case inputPaymentCredentialsApplePay(paymentData: Api.DataJSON)
        case inputPaymentCredentialsGooglePay(paymentToken: Api.DataJSON)
        case inputPaymentCredentialsSaved(id: String, tmpPassword: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPaymentCredentials(let flags, let data):
                    if boxed {
                        buffer.appendInt32(873977640)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsApplePay(let paymentData):
                    if boxed {
                        buffer.appendInt32(178373535)
                    }
                    paymentData.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsGooglePay(let paymentToken):
                    if boxed {
                        buffer.appendInt32(-1966921727)
                    }
                    paymentToken.serialize(buffer, true)
                    break
                case .inputPaymentCredentialsSaved(let id, let tmpPassword):
                    if boxed {
                        buffer.appendInt32(-1056001329)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeBytes(tmpPassword, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPaymentCredentials(let flags, let data):
                return ("inputPaymentCredentials", [("flags", String(describing: flags)), ("data", String(describing: data))])
                case .inputPaymentCredentialsApplePay(let paymentData):
                return ("inputPaymentCredentialsApplePay", [("paymentData", String(describing: paymentData))])
                case .inputPaymentCredentialsGooglePay(let paymentToken):
                return ("inputPaymentCredentialsGooglePay", [("paymentToken", String(describing: paymentToken))])
                case .inputPaymentCredentialsSaved(let id, let tmpPassword):
                return ("inputPaymentCredentialsSaved", [("id", String(describing: id)), ("tmpPassword", String(describing: tmpPassword))])
    }
    }
    
        public static func parse_inputPaymentCredentials(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPaymentCredentials.inputPaymentCredentials(flags: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsApplePay(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsApplePay(paymentData: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsGooglePay(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsGooglePay(paymentToken: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPaymentCredentialsSaved(_ reader: BufferReader) -> InputPaymentCredentials? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputPaymentCredentials.inputPaymentCredentialsSaved(id: _1!, tmpPassword: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
