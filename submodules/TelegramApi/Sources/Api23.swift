public extension Api {
    enum SendAsPeer: TypeConstructorDescription {
        case sendAsPeer(flags: Int32, peer: Api.Peer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sendAsPeer(let flags, let peer):
                    if boxed {
                        buffer.appendInt32(-1206095820)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sendAsPeer(let flags, let peer):
                return ("sendAsPeer", [("flags", flags as Any), ("peer", peer as Any)])
    }
    }
    
        public static func parse_sendAsPeer(_ reader: BufferReader) -> SendAsPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SendAsPeer.sendAsPeer(flags: _1!, peer: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SendMessageAction: TypeConstructorDescription {
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageChooseStickerAction
        case sendMessageEmojiInteraction(emoticon: String, msgId: Int32, interaction: Api.DataJSON)
        case sendMessageEmojiInteractionSeen(emoticon: String)
        case sendMessageGamePlayAction
        case sendMessageGeoLocationAction
        case sendMessageHistoryImportAction(progress: Int32)
        case sendMessageRecordAudioAction
        case sendMessageRecordRoundAction
        case sendMessageRecordVideoAction
        case sendMessageTypingAction
        case sendMessageUploadAudioAction(progress: Int32)
        case sendMessageUploadDocumentAction(progress: Int32)
        case sendMessageUploadPhotoAction(progress: Int32)
        case sendMessageUploadRoundAction(progress: Int32)
        case sendMessageUploadVideoAction(progress: Int32)
        case speakingInGroupCallAction
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sendMessageCancelAction:
                    if boxed {
                        buffer.appendInt32(-44119819)
                    }
                    
                    break
                case .sendMessageChooseContactAction:
                    if boxed {
                        buffer.appendInt32(1653390447)
                    }
                    
                    break
                case .sendMessageChooseStickerAction:
                    if boxed {
                        buffer.appendInt32(-1336228175)
                    }
                    
                    break
                case .sendMessageEmojiInteraction(let emoticon, let msgId, let interaction):
                    if boxed {
                        buffer.appendInt32(630664139)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    interaction.serialize(buffer, true)
                    break
                case .sendMessageEmojiInteractionSeen(let emoticon):
                    if boxed {
                        buffer.appendInt32(-1234857938)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .sendMessageGamePlayAction:
                    if boxed {
                        buffer.appendInt32(-580219064)
                    }
                    
                    break
                case .sendMessageGeoLocationAction:
                    if boxed {
                        buffer.appendInt32(393186209)
                    }
                    
                    break
                case .sendMessageHistoryImportAction(let progress):
                    if boxed {
                        buffer.appendInt32(-606432698)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageRecordAudioAction:
                    if boxed {
                        buffer.appendInt32(-718310409)
                    }
                    
                    break
                case .sendMessageRecordRoundAction:
                    if boxed {
                        buffer.appendInt32(-1997373508)
                    }
                    
                    break
                case .sendMessageRecordVideoAction:
                    if boxed {
                        buffer.appendInt32(-1584933265)
                    }
                    
                    break
                case .sendMessageTypingAction:
                    if boxed {
                        buffer.appendInt32(381645902)
                    }
                    
                    break
                case .sendMessageUploadAudioAction(let progress):
                    if boxed {
                        buffer.appendInt32(-212740181)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadDocumentAction(let progress):
                    if boxed {
                        buffer.appendInt32(-1441998364)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadPhotoAction(let progress):
                    if boxed {
                        buffer.appendInt32(-774682074)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadRoundAction(let progress):
                    if boxed {
                        buffer.appendInt32(608050278)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadVideoAction(let progress):
                    if boxed {
                        buffer.appendInt32(-378127636)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .speakingInGroupCallAction:
                    if boxed {
                        buffer.appendInt32(-651419003)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sendMessageCancelAction:
                return ("sendMessageCancelAction", [])
                case .sendMessageChooseContactAction:
                return ("sendMessageChooseContactAction", [])
                case .sendMessageChooseStickerAction:
                return ("sendMessageChooseStickerAction", [])
                case .sendMessageEmojiInteraction(let emoticon, let msgId, let interaction):
                return ("sendMessageEmojiInteraction", [("emoticon", emoticon as Any), ("msgId", msgId as Any), ("interaction", interaction as Any)])
                case .sendMessageEmojiInteractionSeen(let emoticon):
                return ("sendMessageEmojiInteractionSeen", [("emoticon", emoticon as Any)])
                case .sendMessageGamePlayAction:
                return ("sendMessageGamePlayAction", [])
                case .sendMessageGeoLocationAction:
                return ("sendMessageGeoLocationAction", [])
                case .sendMessageHistoryImportAction(let progress):
                return ("sendMessageHistoryImportAction", [("progress", progress as Any)])
                case .sendMessageRecordAudioAction:
                return ("sendMessageRecordAudioAction", [])
                case .sendMessageRecordRoundAction:
                return ("sendMessageRecordRoundAction", [])
                case .sendMessageRecordVideoAction:
                return ("sendMessageRecordVideoAction", [])
                case .sendMessageTypingAction:
                return ("sendMessageTypingAction", [])
                case .sendMessageUploadAudioAction(let progress):
                return ("sendMessageUploadAudioAction", [("progress", progress as Any)])
                case .sendMessageUploadDocumentAction(let progress):
                return ("sendMessageUploadDocumentAction", [("progress", progress as Any)])
                case .sendMessageUploadPhotoAction(let progress):
                return ("sendMessageUploadPhotoAction", [("progress", progress as Any)])
                case .sendMessageUploadRoundAction(let progress):
                return ("sendMessageUploadRoundAction", [("progress", progress as Any)])
                case .sendMessageUploadVideoAction(let progress):
                return ("sendMessageUploadVideoAction", [("progress", progress as Any)])
                case .speakingInGroupCallAction:
                return ("speakingInGroupCallAction", [])
    }
    }
    
        public static func parse_sendMessageCancelAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageCancelAction
        }
        public static func parse_sendMessageChooseContactAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageChooseContactAction
        }
        public static func parse_sendMessageChooseStickerAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageChooseStickerAction
        }
        public static func parse_sendMessageEmojiInteraction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.DataJSON?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SendMessageAction.sendMessageEmojiInteraction(emoticon: _1!, msgId: _2!, interaction: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageEmojiInteractionSeen(_ reader: BufferReader) -> SendMessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageEmojiInteractionSeen(emoticon: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageGamePlayAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageGamePlayAction
        }
        public static func parse_sendMessageGeoLocationAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageGeoLocationAction
        }
        public static func parse_sendMessageHistoryImportAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageHistoryImportAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageRecordAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordAudioAction
        }
        public static func parse_sendMessageRecordRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordRoundAction
        }
        public static func parse_sendMessageRecordVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordVideoAction
        }
        public static func parse_sendMessageTypingAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageTypingAction
        }
        public static func parse_sendMessageUploadAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadAudioAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadDocumentAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadDocumentAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadPhotoAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadPhotoAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadRoundAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadVideoAction(progress: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_speakingInGroupCallAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.speakingInGroupCallAction
        }
    
    }
}
public extension Api {
    enum ShippingOption: TypeConstructorDescription {
        case shippingOption(id: String, title: String, prices: [Api.LabeledPrice])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .shippingOption(let id, let title, let prices):
                    if boxed {
                        buffer.appendInt32(-1239335713)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prices.count))
                    for item in prices {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .shippingOption(let id, let title, let prices):
                return ("shippingOption", [("id", id as Any), ("title", title as Any), ("prices", prices as Any)])
    }
    }
    
        public static func parse_shippingOption(_ reader: BufferReader) -> ShippingOption? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.LabeledPrice]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LabeledPrice.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ShippingOption.shippingOption(id: _1!, title: _2!, prices: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SmsJob: TypeConstructorDescription {
        case smsJob(jobId: String, phoneNumber: String, text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .smsJob(let jobId, let phoneNumber, let text):
                    if boxed {
                        buffer.appendInt32(-425595208)
                    }
                    serializeString(jobId, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .smsJob(let jobId, let phoneNumber, let text):
                return ("smsJob", [("jobId", jobId as Any), ("phoneNumber", phoneNumber as Any), ("text", text as Any)])
    }
    }
    
        public static func parse_smsJob(_ reader: BufferReader) -> SmsJob? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SmsJob.smsJob(jobId: _1!, phoneNumber: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription {
        case sponsoredMessage(flags: Int32, randomId: Buffer, url: String, title: String, message: String, entities: [Api.MessageEntity]?, photo: Api.Photo?, media: Api.MessageMedia?, color: Api.PeerColor?, buttonText: String, sponsorInfo: String?, additionalInfo: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessage(let flags, let randomId, let url, let title, let message, let entities, let photo, let media, let color, let buttonText, let sponsorInfo, let additionalInfo):
                    if boxed {
                        buffer.appendInt32(1301522832)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 13) != 0 {color!.serialize(buffer, true)}
                    serializeString(buttonText, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 7) != 0 {serializeString(sponsorInfo!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(additionalInfo!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredMessage(let flags, let randomId, let url, let title, let message, let entities, let photo, let media, let color, let buttonText, let sponsorInfo, let additionalInfo):
                return ("sponsoredMessage", [("flags", flags as Any), ("randomId", randomId as Any), ("url", url as Any), ("title", title as Any), ("message", message as Any), ("entities", entities as Any), ("photo", photo as Any), ("media", media as Any), ("color", color as Any), ("buttonText", buttonText as Any), ("sponsorInfo", sponsorInfo as Any), ("additionalInfo", additionalInfo as Any)])
    }
    }
    
        public static func parse_sponsoredMessage(_ reader: BufferReader) -> SponsoredMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _7: Api.Photo?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _8: Api.MessageMedia?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _9: Api.PeerColor?
            if Int(_1!) & Int(1 << 13) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PeerColor
            } }
            var _10: String?
            _10 = parseString(reader)
            var _11: String?
            if Int(_1!) & Int(1 << 7) != 0 {_11 = parseString(reader) }
            var _12: String?
            if Int(_1!) & Int(1 << 8) != 0 {_12 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 14) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 13) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 7) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 8) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.SponsoredMessage.sponsoredMessage(flags: _1!, randomId: _2!, url: _3!, title: _4!, message: _5!, entities: _6, photo: _7, media: _8, color: _9, buttonText: _10!, sponsorInfo: _11, additionalInfo: _12)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SponsoredMessageReportOption: TypeConstructorDescription {
        case sponsoredMessageReportOption(text: String, option: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessageReportOption(let text, let option):
                    if boxed {
                        buffer.appendInt32(1124938064)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredMessageReportOption(let text, let option):
                return ("sponsoredMessageReportOption", [("text", text as Any), ("option", option as Any)])
    }
    }
    
        public static func parse_sponsoredMessageReportOption(_ reader: BufferReader) -> SponsoredMessageReportOption? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SponsoredMessageReportOption.sponsoredMessageReportOption(text: _1!, option: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarGift: TypeConstructorDescription {
        case starGift(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGift(let flags, let id, let sticker, let stars, let availabilityRemains, let availabilityTotal, let convertStars, let firstSaleDate, let lastSaleDate):
                    if boxed {
                        buffer.appendInt32(1237678029)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    sticker.serialize(buffer, true)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(availabilityRemains!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(availabilityTotal!, buffer: buffer, boxed: false)}
                    serializeInt64(convertStars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(firstSaleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(lastSaleDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGift(let flags, let id, let sticker, let stars, let availabilityRemains, let availabilityTotal, let convertStars, let firstSaleDate, let lastSaleDate):
                return ("starGift", [("flags", flags as Any), ("id", id as Any), ("sticker", sticker as Any), ("stars", stars as Any), ("availabilityRemains", availabilityRemains as Any), ("availabilityTotal", availabilityTotal as Any), ("convertStars", convertStars as Any), ("firstSaleDate", firstSaleDate as Any), ("lastSaleDate", lastSaleDate as Any)])
    }
    }
    
        public static func parse_starGift(_ reader: BufferReader) -> StarGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Document?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_9 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.StarGift.starGift(flags: _1!, id: _2!, sticker: _3!, stars: _4!, availabilityRemains: _5, availabilityTotal: _6, convertStars: _7!, firstSaleDate: _8, lastSaleDate: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsGiftOption: TypeConstructorDescription {
        case starsGiftOption(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiftOption(let flags, let stars, let storeProduct, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(1577421297)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiftOption(let flags, let stars, let storeProduct, let currency, let amount):
                return ("starsGiftOption", [("flags", flags as Any), ("stars", stars as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_starsGiftOption(_ reader: BufferReader) -> StarsGiftOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsGiftOption.starsGiftOption(flags: _1!, stars: _2!, storeProduct: _3, currency: _4!, amount: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsGiveawayOption: TypeConstructorDescription {
        case starsGiveawayOption(flags: Int32, stars: Int64, yearlyBoosts: Int32, storeProduct: String?, currency: String, amount: Int64, winners: [Api.StarsGiveawayWinnersOption])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiveawayOption(let flags, let stars, let yearlyBoosts, let storeProduct, let currency, let amount, let winners):
                    if boxed {
                        buffer.appendInt32(-1798404822)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    serializeInt32(yearlyBoosts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(winners.count))
                    for item in winners {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiveawayOption(let flags, let stars, let yearlyBoosts, let storeProduct, let currency, let amount, let winners):
                return ("starsGiveawayOption", [("flags", flags as Any), ("stars", stars as Any), ("yearlyBoosts", yearlyBoosts as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any), ("winners", winners as Any)])
    }
    }
    
        public static func parse_starsGiveawayOption(_ reader: BufferReader) -> StarsGiveawayOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: [Api.StarsGiveawayWinnersOption]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsGiveawayWinnersOption.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.StarsGiveawayOption.starsGiveawayOption(flags: _1!, stars: _2!, yearlyBoosts: _3!, storeProduct: _4, currency: _5!, amount: _6!, winners: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsGiveawayWinnersOption: TypeConstructorDescription {
        case starsGiveawayWinnersOption(flags: Int32, users: Int32, perUserStars: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiveawayWinnersOption(let flags, let users, let perUserStars):
                    if boxed {
                        buffer.appendInt32(1411605001)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(users, buffer: buffer, boxed: false)
                    serializeInt64(perUserStars, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiveawayWinnersOption(let flags, let users, let perUserStars):
                return ("starsGiveawayWinnersOption", [("flags", flags as Any), ("users", users as Any), ("perUserStars", perUserStars as Any)])
    }
    }
    
        public static func parse_starsGiveawayWinnersOption(_ reader: BufferReader) -> StarsGiveawayWinnersOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StarsGiveawayWinnersOption.starsGiveawayWinnersOption(flags: _1!, users: _2!, perUserStars: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsRevenueStatus: TypeConstructorDescription {
        case starsRevenueStatus(flags: Int32, currentBalance: Int64, availableBalance: Int64, overallRevenue: Int64, nextWithdrawalAt: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueStatus(let flags, let currentBalance, let availableBalance, let overallRevenue, let nextWithdrawalAt):
                    if boxed {
                        buffer.appendInt32(2033461574)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(currentBalance, buffer: buffer, boxed: false)
                    serializeInt64(availableBalance, buffer: buffer, boxed: false)
                    serializeInt64(overallRevenue, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(nextWithdrawalAt!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueStatus(let flags, let currentBalance, let availableBalance, let overallRevenue, let nextWithdrawalAt):
                return ("starsRevenueStatus", [("flags", flags as Any), ("currentBalance", currentBalance as Any), ("availableBalance", availableBalance as Any), ("overallRevenue", overallRevenue as Any), ("nextWithdrawalAt", nextWithdrawalAt as Any)])
    }
    }
    
        public static func parse_starsRevenueStatus(_ reader: BufferReader) -> StarsRevenueStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsRevenueStatus.starsRevenueStatus(flags: _1!, currentBalance: _2!, availableBalance: _3!, overallRevenue: _4!, nextWithdrawalAt: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsSubscription: TypeConstructorDescription {
        case starsSubscription(flags: Int32, id: String, peer: Api.Peer, untilDate: Int32, pricing: Api.StarsSubscriptionPricing, chatInviteHash: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsSubscription(let flags, let id, let peer, let untilDate, let pricing, let chatInviteHash):
                    if boxed {
                        buffer.appendInt32(1401868056)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    pricing.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(chatInviteHash!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsSubscription(let flags, let id, let peer, let untilDate, let pricing, let chatInviteHash):
                return ("starsSubscription", [("flags", flags as Any), ("id", id as Any), ("peer", peer as Any), ("untilDate", untilDate as Any), ("pricing", pricing as Any), ("chatInviteHash", chatInviteHash as Any)])
    }
    }
    
        public static func parse_starsSubscription(_ reader: BufferReader) -> StarsSubscription? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.StarsSubscriptionPricing?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StarsSubscriptionPricing
            }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarsSubscription.starsSubscription(flags: _1!, id: _2!, peer: _3!, untilDate: _4!, pricing: _5!, chatInviteHash: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsSubscriptionPricing: TypeConstructorDescription {
        case starsSubscriptionPricing(period: Int32, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsSubscriptionPricing(let period, let amount):
                    if boxed {
                        buffer.appendInt32(88173912)
                    }
                    serializeInt32(period, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsSubscriptionPricing(let period, let amount):
                return ("starsSubscriptionPricing", [("period", period as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_starsSubscriptionPricing(_ reader: BufferReader) -> StarsSubscriptionPricing? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarsSubscriptionPricing.starsSubscriptionPricing(period: _1!, amount: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsTopupOption: TypeConstructorDescription {
        case starsTopupOption(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsTopupOption(let flags, let stars, let storeProduct, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(198776256)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsTopupOption(let flags, let stars, let storeProduct, let currency, let amount):
                return ("starsTopupOption", [("flags", flags as Any), ("stars", stars as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_starsTopupOption(_ reader: BufferReader) -> StarsTopupOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsTopupOption.starsTopupOption(flags: _1!, stars: _2!, storeProduct: _3, currency: _4!, amount: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsTransaction: TypeConstructorDescription {
        case starsTransaction(flags: Int32, id: String, stars: Int64, date: Int32, peer: Api.StarsTransactionPeer, title: String?, description: String?, photo: Api.WebDocument?, transactionDate: Int32?, transactionUrl: String?, botPayload: Buffer?, msgId: Int32?, extendedMedia: [Api.MessageMedia]?, subscriptionPeriod: Int32?, giveawayPostId: Int32?, stargift: Api.StarGift?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsTransaction(let flags, let id, let stars, let date, let peer, let title, let description, let photo, let transactionDate, let transactionUrl, let botPayload, let msgId, let extendedMedia, let subscriptionPeriod, let giveawayPostId, let stargift):
                    if boxed {
                        buffer.appendInt32(178185410)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(transactionDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(transactionUrl!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeBytes(botPayload!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt32(msgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(extendedMedia!.count))
                    for item in extendedMedia! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 12) != 0 {serializeInt32(subscriptionPeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt32(giveawayPostId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {stargift!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsTransaction(let flags, let id, let stars, let date, let peer, let title, let description, let photo, let transactionDate, let transactionUrl, let botPayload, let msgId, let extendedMedia, let subscriptionPeriod, let giveawayPostId, let stargift):
                return ("starsTransaction", [("flags", flags as Any), ("id", id as Any), ("stars", stars as Any), ("date", date as Any), ("peer", peer as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("transactionDate", transactionDate as Any), ("transactionUrl", transactionUrl as Any), ("botPayload", botPayload as Any), ("msgId", msgId as Any), ("extendedMedia", extendedMedia as Any), ("subscriptionPeriod", subscriptionPeriod as Any), ("giveawayPostId", giveawayPostId as Any), ("stargift", stargift as Any)])
    }
    }
    
        public static func parse_starsTransaction(_ reader: BufferReader) -> StarsTransaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.StarsTransactionPeer?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StarsTransactionPeer
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _9: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_9 = reader.readInt32() }
            var _10: String?
            if Int(_1!) & Int(1 << 5) != 0 {_10 = parseString(reader) }
            var _11: Buffer?
            if Int(_1!) & Int(1 << 7) != 0 {_11 = parseBytes(reader) }
            var _12: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {_12 = reader.readInt32() }
            var _13: [Api.MessageMedia]?
            if Int(_1!) & Int(1 << 9) != 0 {if let _ = reader.readInt32() {
                _13 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageMedia.self)
            } }
            var _14: Int32?
            if Int(_1!) & Int(1 << 12) != 0 {_14 = reader.readInt32() }
            var _15: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {_15 = reader.readInt32() }
            var _16: Api.StarGift?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.StarGift
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 5) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 7) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 8) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 9) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 12) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 13) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 14) == 0) || _16 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 {
                return Api.StarsTransaction.starsTransaction(flags: _1!, id: _2!, stars: _3!, date: _4!, peer: _5!, title: _6, description: _7, photo: _8, transactionDate: _9, transactionUrl: _10, botPayload: _11, msgId: _12, extendedMedia: _13, subscriptionPeriod: _14, giveawayPostId: _15, stargift: _16)
            }
            else {
                return nil
            }
        }
    
    }
}
