public extension Api {
    indirect enum InputFileLocation: TypeConstructorDescription {
        case inputDocumentFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputEncryptedFileLocation(id: Int64, accessHash: Int64)
        case inputFileLocation(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer)
        case inputGroupCallStream(flags: Int32, call: Api.InputGroupCall, timeMs: Int64, scale: Int32, videoChannel: Int32?, videoQuality: Int32?)
        case inputPeerPhotoFileLocation(flags: Int32, peer: Api.InputPeer, photoId: Int64)
        case inputPhotoFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputPhotoLegacyFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, volumeId: Int64, localId: Int32, secret: Int64)
        case inputSecureFileLocation(id: Int64, accessHash: Int64)
        case inputStickerSetThumb(stickerset: Api.InputStickerSet, thumbVersion: Int32)
        case inputTakeoutFileLocation
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDocumentFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                    if boxed {
                        buffer.appendInt32(-1160743548)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeString(thumbSize, buffer: buffer, boxed: false)
                    break
                case .inputEncryptedFileLocation(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-182231723)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputFileLocation(let volumeId, let localId, let secret, let fileReference):
                    if boxed {
                        buffer.appendInt32(-539317279)
                    }
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    serializeInt64(secret, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
                case .inputGroupCallStream(let flags, let call, let timeMs, let scale, let videoChannel, let videoQuality):
                    if boxed {
                        buffer.appendInt32(93890858)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    serializeInt64(timeMs, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(videoChannel!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(videoQuality!, buffer: buffer, boxed: false)}
                    break
                case .inputPeerPhotoFileLocation(let flags, let peer, let photoId):
                    if boxed {
                        buffer.appendInt32(925204121)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt64(photoId, buffer: buffer, boxed: false)
                    break
                case .inputPhotoFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                    if boxed {
                        buffer.appendInt32(1075322878)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeString(thumbSize, buffer: buffer, boxed: false)
                    break
                case .inputPhotoLegacyFileLocation(let id, let accessHash, let fileReference, let volumeId, let localId, let secret):
                    if boxed {
                        buffer.appendInt32(-667654413)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    serializeInt64(secret, buffer: buffer, boxed: false)
                    break
                case .inputSecureFileLocation(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-876089816)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetThumb(let stickerset, let thumbVersion):
                    if boxed {
                        buffer.appendInt32(-1652231205)
                    }
                    stickerset.serialize(buffer, true)
                    serializeInt32(thumbVersion, buffer: buffer, boxed: false)
                    break
                case .inputTakeoutFileLocation:
                    if boxed {
                        buffer.appendInt32(700340377)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDocumentFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                return ("inputDocumentFileLocation", [("id", id as Any), ("accessHash", accessHash as Any), ("fileReference", fileReference as Any), ("thumbSize", thumbSize as Any)])
                case .inputEncryptedFileLocation(let id, let accessHash):
                return ("inputEncryptedFileLocation", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputFileLocation(let volumeId, let localId, let secret, let fileReference):
                return ("inputFileLocation", [("volumeId", volumeId as Any), ("localId", localId as Any), ("secret", secret as Any), ("fileReference", fileReference as Any)])
                case .inputGroupCallStream(let flags, let call, let timeMs, let scale, let videoChannel, let videoQuality):
                return ("inputGroupCallStream", [("flags", flags as Any), ("call", call as Any), ("timeMs", timeMs as Any), ("scale", scale as Any), ("videoChannel", videoChannel as Any), ("videoQuality", videoQuality as Any)])
                case .inputPeerPhotoFileLocation(let flags, let peer, let photoId):
                return ("inputPeerPhotoFileLocation", [("flags", flags as Any), ("peer", peer as Any), ("photoId", photoId as Any)])
                case .inputPhotoFileLocation(let id, let accessHash, let fileReference, let thumbSize):
                return ("inputPhotoFileLocation", [("id", id as Any), ("accessHash", accessHash as Any), ("fileReference", fileReference as Any), ("thumbSize", thumbSize as Any)])
                case .inputPhotoLegacyFileLocation(let id, let accessHash, let fileReference, let volumeId, let localId, let secret):
                return ("inputPhotoLegacyFileLocation", [("id", id as Any), ("accessHash", accessHash as Any), ("fileReference", fileReference as Any), ("volumeId", volumeId as Any), ("localId", localId as Any), ("secret", secret as Any)])
                case .inputSecureFileLocation(let id, let accessHash):
                return ("inputSecureFileLocation", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputStickerSetThumb(let stickerset, let thumbVersion):
                return ("inputStickerSetThumb", [("stickerset", stickerset as Any), ("thumbVersion", thumbVersion as Any)])
                case .inputTakeoutFileLocation:
                return ("inputTakeoutFileLocation", [])
    }
    }
    
        public static func parse_inputDocumentFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputFileLocation.inputDocumentFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!)
        }
        public static func parse_inputEncryptedFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputFileLocation.inputEncryptedFileLocation(id: _1!, accessHash: _2!)
        }
        public static func parse_inputFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputFileLocation.inputFileLocation(volumeId: _1!, localId: _2!, secret: _3!, fileReference: _4!)
        }
        public static func parse_inputGroupCallStream(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.InputFileLocation.inputGroupCallStream(flags: _1!, call: _2!, timeMs: _3!, scale: _4!, videoChannel: _5, videoQuality: _6)
        }
        public static func parse_inputPeerPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputFileLocation.inputPeerPhotoFileLocation(flags: _1!, peer: _2!, photoId: _3!)
        }
        public static func parse_inputPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputFileLocation.inputPhotoFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!)
        }
        public static func parse_inputPhotoLegacyFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.InputFileLocation.inputPhotoLegacyFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, volumeId: _4!, localId: _5!, secret: _6!)
        }
        public static func parse_inputSecureFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputFileLocation.inputSecureFileLocation(id: _1!, accessHash: _2!)
        }
        public static func parse_inputStickerSetThumb(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputFileLocation.inputStickerSetThumb(stickerset: _1!, thumbVersion: _2!)
        }
        public static func parse_inputTakeoutFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            return Api.InputFileLocation.inputTakeoutFileLocation
        }
    
    }
}
public extension Api {
    indirect enum InputFolderPeer: TypeConstructorDescription {
        case inputFolderPeer(peer: Api.InputPeer, folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputFolderPeer(let peer, let folderId):
                    if boxed {
                        buffer.appendInt32(-70073706)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputFolderPeer(let peer, let folderId):
                return ("inputFolderPeer", [("peer", peer as Any), ("folderId", folderId as Any)])
    }
    }
    
        public static func parse_inputFolderPeer(_ reader: BufferReader) -> InputFolderPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputFolderPeer.inputFolderPeer(peer: _1!, folderId: _2!)
        }
    
    }
}
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
                return ("inputGameID", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputGameShortName(let botId, let shortName):
                return ("inputGameShortName", [("botId", botId as Any), ("shortName", shortName as Any)])
    }
    }
    
        public static func parse_inputGameID(_ reader: BufferReader) -> InputGame? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputGame.inputGameID(id: _1!, accessHash: _2!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputGame.inputGameShortName(botId: _1!, shortName: _2!)
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
                return ("inputGeoPoint", [("flags", flags as Any), ("lat", lat as Any), ("long", long as Any), ("accuracyRadius", accuracyRadius as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputGeoPoint.inputGeoPoint(flags: _1!, lat: _2!, long: _3!, accuracyRadius: _4)
        }
        public static func parse_inputGeoPointEmpty(_ reader: BufferReader) -> InputGeoPoint? {
            return Api.InputGeoPoint.inputGeoPointEmpty
        }
    
    }
}
public extension Api {
    enum InputGroupCall: TypeConstructorDescription {
        case inputGroupCall(id: Int64, accessHash: Int64)
        case inputGroupCallInviteMessage(msgId: Int32)
        case inputGroupCallSlug(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputGroupCall(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-659913713)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputGroupCallInviteMessage(let msgId):
                    if boxed {
                        buffer.appendInt32(-1945083841)
                    }
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .inputGroupCallSlug(let slug):
                    if boxed {
                        buffer.appendInt32(-33127873)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputGroupCall(let id, let accessHash):
                return ("inputGroupCall", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputGroupCallInviteMessage(let msgId):
                return ("inputGroupCallInviteMessage", [("msgId", msgId as Any)])
                case .inputGroupCallSlug(let slug):
                return ("inputGroupCallSlug", [("slug", slug as Any)])
    }
    }
    
        public static func parse_inputGroupCall(_ reader: BufferReader) -> InputGroupCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputGroupCall.inputGroupCall(id: _1!, accessHash: _2!)
        }
        public static func parse_inputGroupCallInviteMessage(_ reader: BufferReader) -> InputGroupCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputGroupCall.inputGroupCallInviteMessage(msgId: _1!)
        }
        public static func parse_inputGroupCallSlug(_ reader: BufferReader) -> InputGroupCall? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputGroupCall.inputGroupCallSlug(slug: _1!)
        }
    
    }
}
public extension Api {
    indirect enum InputInvoice: TypeConstructorDescription {
        case inputInvoiceBusinessBotTransferStars(bot: Api.InputUser, stars: Int64)
        case inputInvoiceChatInviteSubscription(hash: String)
        case inputInvoiceMessage(peer: Api.InputPeer, msgId: Int32)
        case inputInvoicePremiumAuthCode(purpose: Api.InputStorePaymentPurpose)
        case inputInvoicePremiumGiftCode(purpose: Api.InputStorePaymentPurpose, option: Api.PremiumGiftCodeOption)
        case inputInvoicePremiumGiftStars(flags: Int32, userId: Api.InputUser, months: Int32, message: Api.TextWithEntities?)
        case inputInvoiceSlug(slug: String)
        case inputInvoiceStarGift(flags: Int32, peer: Api.InputPeer, giftId: Int64, message: Api.TextWithEntities?)
        case inputInvoiceStarGiftAuctionBid(flags: Int32, peer: Api.InputPeer?, giftId: Int64, bidAmount: Int64, message: Api.TextWithEntities?)
        case inputInvoiceStarGiftDropOriginalDetails(stargift: Api.InputSavedStarGift)
        case inputInvoiceStarGiftPrepaidUpgrade(peer: Api.InputPeer, hash: String)
        case inputInvoiceStarGiftResale(flags: Int32, slug: String, toId: Api.InputPeer)
        case inputInvoiceStarGiftTransfer(stargift: Api.InputSavedStarGift, toId: Api.InputPeer)
        case inputInvoiceStarGiftUpgrade(flags: Int32, stargift: Api.InputSavedStarGift)
        case inputInvoiceStars(purpose: Api.InputStorePaymentPurpose)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputInvoiceBusinessBotTransferStars(let bot, let stars):
                    if boxed {
                        buffer.appendInt32(-191267262)
                    }
                    bot.serialize(buffer, true)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    break
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
                case .inputInvoicePremiumAuthCode(let purpose):
                    if boxed {
                        buffer.appendInt32(1048049172)
                    }
                    purpose.serialize(buffer, true)
                    break
                case .inputInvoicePremiumGiftCode(let purpose, let option):
                    if boxed {
                        buffer.appendInt32(-1734841331)
                    }
                    purpose.serialize(buffer, true)
                    option.serialize(buffer, true)
                    break
                case .inputInvoicePremiumGiftStars(let flags, let userId, let months, let message):
                    if boxed {
                        buffer.appendInt32(-625298705)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    serializeInt32(months, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {message!.serialize(buffer, true)}
                    break
                case .inputInvoiceSlug(let slug):
                    if boxed {
                        buffer.appendInt32(-1020867857)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
                case .inputInvoiceStarGift(let flags, let peer, let giftId, let message):
                    if boxed {
                        buffer.appendInt32(-396206446)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt64(giftId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {message!.serialize(buffer, true)}
                    break
                case .inputInvoiceStarGiftAuctionBid(let flags, let peer, let giftId, let bidAmount, let message):
                    if boxed {
                        buffer.appendInt32(516618768)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {peer!.serialize(buffer, true)}
                    serializeInt64(giftId, buffer: buffer, boxed: false)
                    serializeInt64(bidAmount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {message!.serialize(buffer, true)}
                    break
                case .inputInvoiceStarGiftDropOriginalDetails(let stargift):
                    if boxed {
                        buffer.appendInt32(153344209)
                    }
                    stargift.serialize(buffer, true)
                    break
                case .inputInvoiceStarGiftPrepaidUpgrade(let peer, let hash):
                    if boxed {
                        buffer.appendInt32(-1710536520)
                    }
                    peer.serialize(buffer, true)
                    serializeString(hash, buffer: buffer, boxed: false)
                    break
                case .inputInvoiceStarGiftResale(let flags, let slug, let toId):
                    if boxed {
                        buffer.appendInt32(-1012968668)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    toId.serialize(buffer, true)
                    break
                case .inputInvoiceStarGiftTransfer(let stargift, let toId):
                    if boxed {
                        buffer.appendInt32(1247763417)
                    }
                    stargift.serialize(buffer, true)
                    toId.serialize(buffer, true)
                    break
                case .inputInvoiceStarGiftUpgrade(let flags, let stargift):
                    if boxed {
                        buffer.appendInt32(1300335965)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    stargift.serialize(buffer, true)
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
                case .inputInvoiceBusinessBotTransferStars(let bot, let stars):
                return ("inputInvoiceBusinessBotTransferStars", [("bot", bot as Any), ("stars", stars as Any)])
                case .inputInvoiceChatInviteSubscription(let hash):
                return ("inputInvoiceChatInviteSubscription", [("hash", hash as Any)])
                case .inputInvoiceMessage(let peer, let msgId):
                return ("inputInvoiceMessage", [("peer", peer as Any), ("msgId", msgId as Any)])
                case .inputInvoicePremiumAuthCode(let purpose):
                return ("inputInvoicePremiumAuthCode", [("purpose", purpose as Any)])
                case .inputInvoicePremiumGiftCode(let purpose, let option):
                return ("inputInvoicePremiumGiftCode", [("purpose", purpose as Any), ("option", option as Any)])
                case .inputInvoicePremiumGiftStars(let flags, let userId, let months, let message):
                return ("inputInvoicePremiumGiftStars", [("flags", flags as Any), ("userId", userId as Any), ("months", months as Any), ("message", message as Any)])
                case .inputInvoiceSlug(let slug):
                return ("inputInvoiceSlug", [("slug", slug as Any)])
                case .inputInvoiceStarGift(let flags, let peer, let giftId, let message):
                return ("inputInvoiceStarGift", [("flags", flags as Any), ("peer", peer as Any), ("giftId", giftId as Any), ("message", message as Any)])
                case .inputInvoiceStarGiftAuctionBid(let flags, let peer, let giftId, let bidAmount, let message):
                return ("inputInvoiceStarGiftAuctionBid", [("flags", flags as Any), ("peer", peer as Any), ("giftId", giftId as Any), ("bidAmount", bidAmount as Any), ("message", message as Any)])
                case .inputInvoiceStarGiftDropOriginalDetails(let stargift):
                return ("inputInvoiceStarGiftDropOriginalDetails", [("stargift", stargift as Any)])
                case .inputInvoiceStarGiftPrepaidUpgrade(let peer, let hash):
                return ("inputInvoiceStarGiftPrepaidUpgrade", [("peer", peer as Any), ("hash", hash as Any)])
                case .inputInvoiceStarGiftResale(let flags, let slug, let toId):
                return ("inputInvoiceStarGiftResale", [("flags", flags as Any), ("slug", slug as Any), ("toId", toId as Any)])
                case .inputInvoiceStarGiftTransfer(let stargift, let toId):
                return ("inputInvoiceStarGiftTransfer", [("stargift", stargift as Any), ("toId", toId as Any)])
                case .inputInvoiceStarGiftUpgrade(let flags, let stargift):
                return ("inputInvoiceStarGiftUpgrade", [("flags", flags as Any), ("stargift", stargift as Any)])
                case .inputInvoiceStars(let purpose):
                return ("inputInvoiceStars", [("purpose", purpose as Any)])
    }
    }
    
        public static func parse_inputInvoiceBusinessBotTransferStars(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputInvoice.inputInvoiceBusinessBotTransferStars(bot: _1!, stars: _2!)
        }
        public static func parse_inputInvoiceChatInviteSubscription(_ reader: BufferReader) -> InputInvoice? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputInvoice.inputInvoiceChatInviteSubscription(hash: _1!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputInvoice.inputInvoiceMessage(peer: _1!, msgId: _2!)
        }
        public static func parse_inputInvoicePremiumAuthCode(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputStorePaymentPurpose?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStorePaymentPurpose
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputInvoice.inputInvoicePremiumAuthCode(purpose: _1!)
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputInvoice.inputInvoicePremiumGiftCode(purpose: _1!, option: _2!)
        }
        public static func parse_inputInvoicePremiumGiftStars(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputUser?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputInvoice.inputInvoicePremiumGiftStars(flags: _1!, userId: _2!, months: _3!, message: _4)
        }
        public static func parse_inputInvoiceSlug(_ reader: BufferReader) -> InputInvoice? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputInvoice.inputInvoiceSlug(slug: _1!)
        }
        public static func parse_inputInvoiceStarGift(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.InputInvoice.inputInvoiceStarGift(flags: _1!, peer: _2!, giftId: _3!, message: _4)
        }
        public static func parse_inputInvoiceStarGiftAuctionBid(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            } }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.InputInvoice.inputInvoiceStarGiftAuctionBid(flags: _1!, peer: _2, giftId: _3!, bidAmount: _4!, message: _5)
        }
        public static func parse_inputInvoiceStarGiftDropOriginalDetails(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputSavedStarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputSavedStarGift
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputInvoice.inputInvoiceStarGiftDropOriginalDetails(stargift: _1!)
        }
        public static func parse_inputInvoiceStarGiftPrepaidUpgrade(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputInvoice.inputInvoiceStarGiftPrepaidUpgrade(peer: _1!, hash: _2!)
        }
        public static func parse_inputInvoiceStarGiftResale(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputPeer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.InputInvoice.inputInvoiceStarGiftResale(flags: _1!, slug: _2!, toId: _3!)
        }
        public static func parse_inputInvoiceStarGiftTransfer(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputSavedStarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputSavedStarGift
            }
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputInvoice.inputInvoiceStarGiftTransfer(stargift: _1!, toId: _2!)
        }
        public static func parse_inputInvoiceStarGiftUpgrade(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputSavedStarGift?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputSavedStarGift
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.InputInvoice.inputInvoiceStarGiftUpgrade(flags: _1!, stargift: _2!)
        }
        public static func parse_inputInvoiceStars(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputStorePaymentPurpose?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStorePaymentPurpose
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.InputInvoice.inputInvoiceStars(purpose: _1!)
        }
    
    }
}
