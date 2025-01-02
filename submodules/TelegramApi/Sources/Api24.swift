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
        case starGift(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?, upgradeStars: Int64?)
        case starGiftUnique(id: Int64, title: String, num: Int32, ownerId: Int64, attributes: [Api.StarGiftAttribute], availabilityIssued: Int32, availabilityTotal: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGift(let flags, let id, let sticker, let stars, let availabilityRemains, let availabilityTotal, let convertStars, let firstSaleDate, let lastSaleDate, let upgradeStars):
                    if boxed {
                        buffer.appendInt32(46953416)
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
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(upgradeStars!, buffer: buffer, boxed: false)}
                    break
                case .starGiftUnique(let id, let title, let num, let ownerId, let attributes, let availabilityIssued, let availabilityTotal):
                    if boxed {
                        buffer.appendInt32(1779697613)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt32(num, buffer: buffer, boxed: false)
                    serializeInt64(ownerId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(availabilityIssued, buffer: buffer, boxed: false)
                    serializeInt32(availabilityTotal, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGift(let flags, let id, let sticker, let stars, let availabilityRemains, let availabilityTotal, let convertStars, let firstSaleDate, let lastSaleDate, let upgradeStars):
                return ("starGift", [("flags", flags as Any), ("id", id as Any), ("sticker", sticker as Any), ("stars", stars as Any), ("availabilityRemains", availabilityRemains as Any), ("availabilityTotal", availabilityTotal as Any), ("convertStars", convertStars as Any), ("firstSaleDate", firstSaleDate as Any), ("lastSaleDate", lastSaleDate as Any), ("upgradeStars", upgradeStars as Any)])
                case .starGiftUnique(let id, let title, let num, let ownerId, let attributes, let availabilityIssued, let availabilityTotal):
                return ("starGiftUnique", [("id", id as Any), ("title", title as Any), ("num", num as Any), ("ownerId", ownerId as Any), ("attributes", attributes as Any), ("availabilityIssued", availabilityIssued as Any), ("availabilityTotal", availabilityTotal as Any)])
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
            var _10: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_10 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.StarGift.starGift(flags: _1!, id: _2!, sticker: _3!, stars: _4!, availabilityRemains: _5, availabilityTotal: _6, convertStars: _7!, firstSaleDate: _8, lastSaleDate: _9, upgradeStars: _10)
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftUnique(_ reader: BufferReader) -> StarGift? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.StarGift.starGiftUnique(id: _1!, title: _2!, num: _3!, ownerId: _4!, attributes: _5!, availabilityIssued: _6!, availabilityTotal: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarGiftAttribute: TypeConstructorDescription {
        case starGiftAttributeBackdrop(name: String, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarityPermille: Int32)
        case starGiftAttributeModel(name: String, document: Api.Document, rarityPermille: Int32)
        case starGiftAttributeOriginalDetails(flags: Int32, senderId: Int64?, recipientId: Int64, date: Int32, message: Api.TextWithEntities?)
        case starGiftAttributePattern(name: String, document: Api.Document, rarityPermille: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAttributeBackdrop(let name, let centerColor, let edgeColor, let patternColor, let textColor, let rarityPermille):
                    if boxed {
                        buffer.appendInt32(-1809377438)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeInt32(centerColor, buffer: buffer, boxed: false)
                    serializeInt32(edgeColor, buffer: buffer, boxed: false)
                    serializeInt32(patternColor, buffer: buffer, boxed: false)
                    serializeInt32(textColor, buffer: buffer, boxed: false)
                    serializeInt32(rarityPermille, buffer: buffer, boxed: false)
                    break
                case .starGiftAttributeModel(let name, let document, let rarityPermille):
                    if boxed {
                        buffer.appendInt32(970559507)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    serializeInt32(rarityPermille, buffer: buffer, boxed: false)
                    break
                case .starGiftAttributeOriginalDetails(let flags, let senderId, let recipientId, let date, let message):
                    if boxed {
                        buffer.appendInt32(-1070837941)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(senderId!, buffer: buffer, boxed: false)}
                    serializeInt64(recipientId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {message!.serialize(buffer, true)}
                    break
                case .starGiftAttributePattern(let name, let document, let rarityPermille):
                    if boxed {
                        buffer.appendInt32(330104601)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    serializeInt32(rarityPermille, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAttributeBackdrop(let name, let centerColor, let edgeColor, let patternColor, let textColor, let rarityPermille):
                return ("starGiftAttributeBackdrop", [("name", name as Any), ("centerColor", centerColor as Any), ("edgeColor", edgeColor as Any), ("patternColor", patternColor as Any), ("textColor", textColor as Any), ("rarityPermille", rarityPermille as Any)])
                case .starGiftAttributeModel(let name, let document, let rarityPermille):
                return ("starGiftAttributeModel", [("name", name as Any), ("document", document as Any), ("rarityPermille", rarityPermille as Any)])
                case .starGiftAttributeOriginalDetails(let flags, let senderId, let recipientId, let date, let message):
                return ("starGiftAttributeOriginalDetails", [("flags", flags as Any), ("senderId", senderId as Any), ("recipientId", recipientId as Any), ("date", date as Any), ("message", message as Any)])
                case .starGiftAttributePattern(let name, let document, let rarityPermille):
                return ("starGiftAttributePattern", [("name", name as Any), ("document", document as Any), ("rarityPermille", rarityPermille as Any)])
    }
    }
    
        public static func parse_starGiftAttributeBackdrop(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarGiftAttribute.starGiftAttributeBackdrop(name: _1!, centerColor: _2!, edgeColor: _3!, patternColor: _4!, textColor: _5!, rarityPermille: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeModel(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StarGiftAttribute.starGiftAttributeModel(name: _1!, document: _2!, rarityPermille: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeOriginalDetails(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt64() }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarGiftAttribute.starGiftAttributeOriginalDetails(flags: _1!, senderId: _2, recipientId: _3!, date: _4!, message: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributePattern(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StarGiftAttribute.starGiftAttributePattern(name: _1!, document: _2!, rarityPermille: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarRefProgram: TypeConstructorDescription {
        case starRefProgram(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starRefProgram(let flags, let botId, let commissionPermille, let durationMonths, let endDate, let dailyRevenuePerUser):
                    if boxed {
                        buffer.appendInt32(-586389774)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeInt32(commissionPermille, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(durationMonths!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(endDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {dailyRevenuePerUser!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starRefProgram(let flags, let botId, let commissionPermille, let durationMonths, let endDate, let dailyRevenuePerUser):
                return ("starRefProgram", [("flags", flags as Any), ("botId", botId as Any), ("commissionPermille", commissionPermille as Any), ("durationMonths", durationMonths as Any), ("endDate", endDate as Any), ("dailyRevenuePerUser", dailyRevenuePerUser as Any)])
    }
    }
    
        public static func parse_starRefProgram(_ reader: BufferReader) -> StarRefProgram? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            var _6: Api.StarsAmount?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarRefProgram.starRefProgram(flags: _1!, botId: _2!, commissionPermille: _3!, durationMonths: _4, endDate: _5, dailyRevenuePerUser: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsAmount: TypeConstructorDescription {
        case starsAmount(amount: Int64, nanos: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsAmount(let amount, let nanos):
                    if boxed {
                        buffer.appendInt32(-1145654109)
                    }
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    serializeInt32(nanos, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsAmount(let amount, let nanos):
                return ("starsAmount", [("amount", amount as Any), ("nanos", nanos as Any)])
    }
    }
    
        public static func parse_starsAmount(_ reader: BufferReader) -> StarsAmount? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarsAmount.starsAmount(amount: _1!, nanos: _2!)
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
