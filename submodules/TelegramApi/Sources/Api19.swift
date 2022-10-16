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
                return ("sendAsPeer", [("flags", String(describing: flags)), ("peer", String(describing: peer))])
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
                return ("sendMessageEmojiInteraction", [("emoticon", String(describing: emoticon)), ("msgId", String(describing: msgId)), ("interaction", String(describing: interaction))])
                case .sendMessageEmojiInteractionSeen(let emoticon):
                return ("sendMessageEmojiInteractionSeen", [("emoticon", String(describing: emoticon))])
                case .sendMessageGamePlayAction:
                return ("sendMessageGamePlayAction", [])
                case .sendMessageGeoLocationAction:
                return ("sendMessageGeoLocationAction", [])
                case .sendMessageHistoryImportAction(let progress):
                return ("sendMessageHistoryImportAction", [("progress", String(describing: progress))])
                case .sendMessageRecordAudioAction:
                return ("sendMessageRecordAudioAction", [])
                case .sendMessageRecordRoundAction:
                return ("sendMessageRecordRoundAction", [])
                case .sendMessageRecordVideoAction:
                return ("sendMessageRecordVideoAction", [])
                case .sendMessageTypingAction:
                return ("sendMessageTypingAction", [])
                case .sendMessageUploadAudioAction(let progress):
                return ("sendMessageUploadAudioAction", [("progress", String(describing: progress))])
                case .sendMessageUploadDocumentAction(let progress):
                return ("sendMessageUploadDocumentAction", [("progress", String(describing: progress))])
                case .sendMessageUploadPhotoAction(let progress):
                return ("sendMessageUploadPhotoAction", [("progress", String(describing: progress))])
                case .sendMessageUploadRoundAction(let progress):
                return ("sendMessageUploadRoundAction", [("progress", String(describing: progress))])
                case .sendMessageUploadVideoAction(let progress):
                return ("sendMessageUploadVideoAction", [("progress", String(describing: progress))])
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
                return ("shippingOption", [("id", String(describing: id)), ("title", String(describing: title)), ("prices", String(describing: prices))])
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
    enum SimpleWebViewResult: TypeConstructorDescription {
        case simpleWebViewResultUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .simpleWebViewResultUrl(let url):
                    if boxed {
                        buffer.appendInt32(-2010155333)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .simpleWebViewResultUrl(let url):
                return ("simpleWebViewResultUrl", [("url", String(describing: url))])
    }
    }
    
        public static func parse_simpleWebViewResultUrl(_ reader: BufferReader) -> SimpleWebViewResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SimpleWebViewResult.simpleWebViewResultUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription {
        case sponsoredMessage(flags: Int32, randomId: Buffer, fromId: Api.Peer?, chatInvite: Api.ChatInvite?, chatInviteHash: String?, channelPost: Int32?, startParam: String?, message: String, entities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessage(let flags, let randomId, let fromId, let chatInvite, let chatInviteHash, let channelPost, let startParam, let message, let entities):
                    if boxed {
                        buffer.appendInt32(981691896)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {chatInvite!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(chatInviteHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(channelPost!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredMessage(let flags, let randomId, let fromId, let chatInvite, let chatInviteHash, let channelPost, let startParam, let message, let entities):
                return ("sponsoredMessage", [("flags", String(describing: flags)), ("randomId", String(describing: randomId)), ("fromId", String(describing: fromId)), ("chatInvite", String(describing: chatInvite)), ("chatInviteHash", String(describing: chatInviteHash)), ("channelPost", String(describing: channelPost)), ("startParam", String(describing: startParam)), ("message", String(describing: message)), ("entities", String(describing: entities))])
    }
    }
    
        public static func parse_sponsoredMessage(_ reader: BufferReader) -> SponsoredMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Api.ChatInvite?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatInvite
            } }
            var _5: String?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = parseString(reader) }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = reader.readInt32() }
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
            var _8: String?
            _8 = parseString(reader)
            var _9: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.SponsoredMessage.sponsoredMessage(flags: _1!, randomId: _2!, fromId: _3, chatInvite: _4, chatInviteHash: _5, channelPost: _6, startParam: _7, message: _8!, entities: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsAbsValueAndPrev: TypeConstructorDescription {
        case statsAbsValueAndPrev(current: Double, previous: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsAbsValueAndPrev(let current, let previous):
                    if boxed {
                        buffer.appendInt32(-884757282)
                    }
                    serializeDouble(current, buffer: buffer, boxed: false)
                    serializeDouble(previous, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsAbsValueAndPrev(let current, let previous):
                return ("statsAbsValueAndPrev", [("current", String(describing: current)), ("previous", String(describing: previous))])
    }
    }
    
        public static func parse_statsAbsValueAndPrev(_ reader: BufferReader) -> StatsAbsValueAndPrev? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsAbsValueAndPrev.statsAbsValueAndPrev(current: _1!, previous: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsDateRangeDays: TypeConstructorDescription {
        case statsDateRangeDays(minDate: Int32, maxDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsDateRangeDays(let minDate, let maxDate):
                    if boxed {
                        buffer.appendInt32(-1237848657)
                    }
                    serializeInt32(minDate, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsDateRangeDays(let minDate, let maxDate):
                return ("statsDateRangeDays", [("minDate", String(describing: minDate)), ("maxDate", String(describing: maxDate))])
    }
    }
    
        public static func parse_statsDateRangeDays(_ reader: BufferReader) -> StatsDateRangeDays? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsDateRangeDays.statsDateRangeDays(minDate: _1!, maxDate: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGraph: TypeConstructorDescription {
        case statsGraph(flags: Int32, json: Api.DataJSON, zoomToken: String?)
        case statsGraphAsync(token: String)
        case statsGraphError(error: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGraph(let flags, let json, let zoomToken):
                    if boxed {
                        buffer.appendInt32(-1901828938)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    json.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(zoomToken!, buffer: buffer, boxed: false)}
                    break
                case .statsGraphAsync(let token):
                    if boxed {
                        buffer.appendInt32(1244130093)
                    }
                    serializeString(token, buffer: buffer, boxed: false)
                    break
                case .statsGraphError(let error):
                    if boxed {
                        buffer.appendInt32(-1092839390)
                    }
                    serializeString(error, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGraph(let flags, let json, let zoomToken):
                return ("statsGraph", [("flags", String(describing: flags)), ("json", String(describing: json)), ("zoomToken", String(describing: zoomToken))])
                case .statsGraphAsync(let token):
                return ("statsGraphAsync", [("token", String(describing: token))])
                case .statsGraphError(let error):
                return ("statsGraphError", [("error", String(describing: error))])
    }
    }
    
        public static func parse_statsGraph(_ reader: BufferReader) -> StatsGraph? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StatsGraph.statsGraph(flags: _1!, json: _2!, zoomToken: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_statsGraphAsync(_ reader: BufferReader) -> StatsGraph? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsGraph.statsGraphAsync(token: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_statsGraphError(_ reader: BufferReader) -> StatsGraph? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsGraph.statsGraphError(error: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGroupTopAdmin: TypeConstructorDescription {
        case statsGroupTopAdmin(userId: Int64, deleted: Int32, kicked: Int32, banned: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGroupTopAdmin(let userId, let deleted, let kicked, let banned):
                    if boxed {
                        buffer.appendInt32(-682079097)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(deleted, buffer: buffer, boxed: false)
                    serializeInt32(kicked, buffer: buffer, boxed: false)
                    serializeInt32(banned, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGroupTopAdmin(let userId, let deleted, let kicked, let banned):
                return ("statsGroupTopAdmin", [("userId", String(describing: userId)), ("deleted", String(describing: deleted)), ("kicked", String(describing: kicked)), ("banned", String(describing: banned))])
    }
    }
    
        public static func parse_statsGroupTopAdmin(_ reader: BufferReader) -> StatsGroupTopAdmin? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StatsGroupTopAdmin.statsGroupTopAdmin(userId: _1!, deleted: _2!, kicked: _3!, banned: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGroupTopInviter: TypeConstructorDescription {
        case statsGroupTopInviter(userId: Int64, invitations: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGroupTopInviter(let userId, let invitations):
                    if boxed {
                        buffer.appendInt32(1398765469)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(invitations, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGroupTopInviter(let userId, let invitations):
                return ("statsGroupTopInviter", [("userId", String(describing: userId)), ("invitations", String(describing: invitations))])
    }
    }
    
        public static func parse_statsGroupTopInviter(_ reader: BufferReader) -> StatsGroupTopInviter? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsGroupTopInviter.statsGroupTopInviter(userId: _1!, invitations: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGroupTopPoster: TypeConstructorDescription {
        case statsGroupTopPoster(userId: Int64, messages: Int32, avgChars: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGroupTopPoster(let userId, let messages, let avgChars):
                    if boxed {
                        buffer.appendInt32(-1660637285)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(messages, buffer: buffer, boxed: false)
                    serializeInt32(avgChars, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGroupTopPoster(let userId, let messages, let avgChars):
                return ("statsGroupTopPoster", [("userId", String(describing: userId)), ("messages", String(describing: messages)), ("avgChars", String(describing: avgChars))])
    }
    }
    
        public static func parse_statsGroupTopPoster(_ reader: BufferReader) -> StatsGroupTopPoster? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StatsGroupTopPoster.statsGroupTopPoster(userId: _1!, messages: _2!, avgChars: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsPercentValue: TypeConstructorDescription {
        case statsPercentValue(part: Double, total: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsPercentValue(let part, let total):
                    if boxed {
                        buffer.appendInt32(-875679776)
                    }
                    serializeDouble(part, buffer: buffer, boxed: false)
                    serializeDouble(total, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsPercentValue(let part, let total):
                return ("statsPercentValue", [("part", String(describing: part)), ("total", String(describing: total))])
    }
    }
    
        public static func parse_statsPercentValue(_ reader: BufferReader) -> StatsPercentValue? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsPercentValue.statsPercentValue(part: _1!, total: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsURL: TypeConstructorDescription {
        case statsURL(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsURL(let url):
                    if boxed {
                        buffer.appendInt32(1202287072)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsURL(let url):
                return ("statsURL", [("url", String(describing: url))])
    }
    }
    
        public static func parse_statsURL(_ reader: BufferReader) -> StatsURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsURL.statsURL(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
