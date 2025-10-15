public extension Api {
    enum ReceivedNotifyMessage: TypeConstructorDescription {
        case receivedNotifyMessage(id: Int32, flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .receivedNotifyMessage(let id, let flags):
                    if boxed {
                        buffer.appendInt32(-1551583367)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .receivedNotifyMessage(let id, let flags):
                return ("receivedNotifyMessage", [("id", id as Any), ("flags", flags as Any)])
    }
    }
    
        public static func parse_receivedNotifyMessage(_ reader: BufferReader) -> ReceivedNotifyMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReceivedNotifyMessage.receivedNotifyMessage(id: _1!, flags: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum RecentMeUrl: TypeConstructorDescription {
        case recentMeUrlChat(url: String, chatId: Int64)
        case recentMeUrlChatInvite(url: String, chatInvite: Api.ChatInvite)
        case recentMeUrlStickerSet(url: String, set: Api.StickerSetCovered)
        case recentMeUrlUnknown(url: String)
        case recentMeUrlUser(url: String, userId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .recentMeUrlChat(let url, let chatId):
                    if boxed {
                        buffer.appendInt32(-1294306862)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .recentMeUrlChatInvite(let url, let chatInvite):
                    if boxed {
                        buffer.appendInt32(-347535331)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    chatInvite.serialize(buffer, true)
                    break
                case .recentMeUrlStickerSet(let url, let set):
                    if boxed {
                        buffer.appendInt32(-1140172836)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    set.serialize(buffer, true)
                    break
                case .recentMeUrlUnknown(let url):
                    if boxed {
                        buffer.appendInt32(1189204285)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .recentMeUrlUser(let url, let userId):
                    if boxed {
                        buffer.appendInt32(-1188296222)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .recentMeUrlChat(let url, let chatId):
                return ("recentMeUrlChat", [("url", url as Any), ("chatId", chatId as Any)])
                case .recentMeUrlChatInvite(let url, let chatInvite):
                return ("recentMeUrlChatInvite", [("url", url as Any), ("chatInvite", chatInvite as Any)])
                case .recentMeUrlStickerSet(let url, let set):
                return ("recentMeUrlStickerSet", [("url", url as Any), ("set", set as Any)])
                case .recentMeUrlUnknown(let url):
                return ("recentMeUrlUnknown", [("url", url as Any)])
                case .recentMeUrlUser(let url, let userId):
                return ("recentMeUrlUser", [("url", url as Any), ("userId", userId as Any)])
    }
    }
    
        public static func parse_recentMeUrlChat(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlChat(url: _1!, chatId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlChatInvite(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.ChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlChatInvite(url: _1!, chatInvite: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlStickerSet(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.StickerSetCovered?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StickerSetCovered
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlStickerSet(url: _1!, set: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlUnknown(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.RecentMeUrl.recentMeUrlUnknown(url: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlUser(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlUser(url: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ReplyMarkup: TypeConstructorDescription {
        case replyInlineMarkup(rows: [Api.KeyboardButtonRow])
        case replyKeyboardForceReply(flags: Int32, placeholder: String?)
        case replyKeyboardHide(flags: Int32)
        case replyKeyboardMarkup(flags: Int32, rows: [Api.KeyboardButtonRow], placeholder: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .replyInlineMarkup(let rows):
                    if boxed {
                        buffer.appendInt32(1218642516)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rows.count))
                    for item in rows {
                        item.serialize(buffer, true)
                    }
                    break
                case .replyKeyboardForceReply(let flags, let placeholder):
                    if boxed {
                        buffer.appendInt32(-2035021048)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(placeholder!, buffer: buffer, boxed: false)}
                    break
                case .replyKeyboardHide(let flags):
                    if boxed {
                        buffer.appendInt32(-1606526075)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .replyKeyboardMarkup(let flags, let rows, let placeholder):
                    if boxed {
                        buffer.appendInt32(-2049074735)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rows.count))
                    for item in rows {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(placeholder!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .replyInlineMarkup(let rows):
                return ("replyInlineMarkup", [("rows", rows as Any)])
                case .replyKeyboardForceReply(let flags, let placeholder):
                return ("replyKeyboardForceReply", [("flags", flags as Any), ("placeholder", placeholder as Any)])
                case .replyKeyboardHide(let flags):
                return ("replyKeyboardHide", [("flags", flags as Any)])
                case .replyKeyboardMarkup(let flags, let rows, let placeholder):
                return ("replyKeyboardMarkup", [("flags", flags as Any), ("rows", rows as Any), ("placeholder", placeholder as Any)])
    }
    }
    
        public static func parse_replyInlineMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: [Api.KeyboardButtonRow]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButtonRow.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReplyMarkup.replyInlineMarkup(rows: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardForceReply(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 3) != 0 {_2 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.ReplyMarkup.replyKeyboardForceReply(flags: _1!, placeholder: _2)
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardHide(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReplyMarkup.replyKeyboardHide(flags: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.KeyboardButtonRow]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButtonRow.self)
            }
            var _3: String?
            if Int(_1!) & Int(1 << 3) != 0 {_3 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ReplyMarkup.replyKeyboardMarkup(flags: _1!, rows: _2!, placeholder: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ReportReason: TypeConstructorDescription {
        case inputReportReasonChildAbuse
        case inputReportReasonCopyright
        case inputReportReasonFake
        case inputReportReasonGeoIrrelevant
        case inputReportReasonIllegalDrugs
        case inputReportReasonOther
        case inputReportReasonPersonalDetails
        case inputReportReasonPornography
        case inputReportReasonSpam
        case inputReportReasonViolence
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputReportReasonChildAbuse:
                    if boxed {
                        buffer.appendInt32(-1376497949)
                    }
                    
                    break
                case .inputReportReasonCopyright:
                    if boxed {
                        buffer.appendInt32(-1685456582)
                    }
                    
                    break
                case .inputReportReasonFake:
                    if boxed {
                        buffer.appendInt32(-170010905)
                    }
                    
                    break
                case .inputReportReasonGeoIrrelevant:
                    if boxed {
                        buffer.appendInt32(-606798099)
                    }
                    
                    break
                case .inputReportReasonIllegalDrugs:
                    if boxed {
                        buffer.appendInt32(177124030)
                    }
                    
                    break
                case .inputReportReasonOther:
                    if boxed {
                        buffer.appendInt32(-1041980751)
                    }
                    
                    break
                case .inputReportReasonPersonalDetails:
                    if boxed {
                        buffer.appendInt32(-1631091139)
                    }
                    
                    break
                case .inputReportReasonPornography:
                    if boxed {
                        buffer.appendInt32(777640226)
                    }
                    
                    break
                case .inputReportReasonSpam:
                    if boxed {
                        buffer.appendInt32(1490799288)
                    }
                    
                    break
                case .inputReportReasonViolence:
                    if boxed {
                        buffer.appendInt32(505595789)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputReportReasonChildAbuse:
                return ("inputReportReasonChildAbuse", [])
                case .inputReportReasonCopyright:
                return ("inputReportReasonCopyright", [])
                case .inputReportReasonFake:
                return ("inputReportReasonFake", [])
                case .inputReportReasonGeoIrrelevant:
                return ("inputReportReasonGeoIrrelevant", [])
                case .inputReportReasonIllegalDrugs:
                return ("inputReportReasonIllegalDrugs", [])
                case .inputReportReasonOther:
                return ("inputReportReasonOther", [])
                case .inputReportReasonPersonalDetails:
                return ("inputReportReasonPersonalDetails", [])
                case .inputReportReasonPornography:
                return ("inputReportReasonPornography", [])
                case .inputReportReasonSpam:
                return ("inputReportReasonSpam", [])
                case .inputReportReasonViolence:
                return ("inputReportReasonViolence", [])
    }
    }
    
        public static func parse_inputReportReasonChildAbuse(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonChildAbuse
        }
        public static func parse_inputReportReasonCopyright(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonCopyright
        }
        public static func parse_inputReportReasonFake(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonFake
        }
        public static func parse_inputReportReasonGeoIrrelevant(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonGeoIrrelevant
        }
        public static func parse_inputReportReasonIllegalDrugs(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonIllegalDrugs
        }
        public static func parse_inputReportReasonOther(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonOther
        }
        public static func parse_inputReportReasonPersonalDetails(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonPersonalDetails
        }
        public static func parse_inputReportReasonPornography(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonPornography
        }
        public static func parse_inputReportReasonSpam(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonSpam
        }
        public static func parse_inputReportReasonViolence(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonViolence
        }
    
    }
}
public extension Api {
    enum ReportResult: TypeConstructorDescription {
        case reportResultAddComment(flags: Int32, option: Buffer)
        case reportResultChooseOption(title: String, options: [Api.MessageReportOption])
        case reportResultReported
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .reportResultAddComment(let flags, let option):
                    if boxed {
                        buffer.appendInt32(1862904881)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    break
                case .reportResultChooseOption(let title, let options):
                    if boxed {
                        buffer.appendInt32(-253435722)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        item.serialize(buffer, true)
                    }
                    break
                case .reportResultReported:
                    if boxed {
                        buffer.appendInt32(-1917633461)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .reportResultAddComment(let flags, let option):
                return ("reportResultAddComment", [("flags", flags as Any), ("option", option as Any)])
                case .reportResultChooseOption(let title, let options):
                return ("reportResultChooseOption", [("title", title as Any), ("options", options as Any)])
                case .reportResultReported:
                return ("reportResultReported", [])
    }
    }
    
        public static func parse_reportResultAddComment(_ reader: BufferReader) -> ReportResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReportResult.reportResultAddComment(flags: _1!, option: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_reportResultChooseOption(_ reader: BufferReader) -> ReportResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.MessageReportOption]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageReportOption.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReportResult.reportResultChooseOption(title: _1!, options: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_reportResultReported(_ reader: BufferReader) -> ReportResult? {
            return Api.ReportResult.reportResultReported
        }
    
    }
}
public extension Api {
    enum RequestPeerType: TypeConstructorDescription {
        case requestPeerTypeBroadcast(flags: Int32, hasUsername: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?)
        case requestPeerTypeChat(flags: Int32, hasUsername: Api.Bool?, forum: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?)
        case requestPeerTypeUser(flags: Int32, bot: Api.Bool?, premium: Api.Bool?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .requestPeerTypeBroadcast(let flags, let hasUsername, let userAdminRights, let botAdminRights):
                    if boxed {
                        buffer.appendInt32(865857388)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {hasUsername!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {userAdminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {botAdminRights!.serialize(buffer, true)}
                    break
                case .requestPeerTypeChat(let flags, let hasUsername, let forum, let userAdminRights, let botAdminRights):
                    if boxed {
                        buffer.appendInt32(-906990053)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {hasUsername!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {forum!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {userAdminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {botAdminRights!.serialize(buffer, true)}
                    break
                case .requestPeerTypeUser(let flags, let bot, let premium):
                    if boxed {
                        buffer.appendInt32(1597737472)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {bot!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {premium!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .requestPeerTypeBroadcast(let flags, let hasUsername, let userAdminRights, let botAdminRights):
                return ("requestPeerTypeBroadcast", [("flags", flags as Any), ("hasUsername", hasUsername as Any), ("userAdminRights", userAdminRights as Any), ("botAdminRights", botAdminRights as Any)])
                case .requestPeerTypeChat(let flags, let hasUsername, let forum, let userAdminRights, let botAdminRights):
                return ("requestPeerTypeChat", [("flags", flags as Any), ("hasUsername", hasUsername as Any), ("forum", forum as Any), ("userAdminRights", userAdminRights as Any), ("botAdminRights", botAdminRights as Any)])
                case .requestPeerTypeUser(let flags, let bot, let premium):
                return ("requestPeerTypeUser", [("flags", flags as Any), ("bot", bot as Any), ("premium", premium as Any)])
    }
    }
    
        public static func parse_requestPeerTypeBroadcast(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _4: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.RequestPeerType.requestPeerTypeBroadcast(flags: _1!, hasUsername: _2, userAdminRights: _3, botAdminRights: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_requestPeerTypeChat(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _4: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _5: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 4) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.RequestPeerType.requestPeerTypeChat(flags: _1!, hasUsername: _2, forum: _3, userAdminRights: _4, botAdminRights: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_requestPeerTypeUser(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.RequestPeerType.requestPeerTypeUser(flags: _1!, bot: _2, premium: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum RequestedPeer: TypeConstructorDescription {
        case requestedPeerChannel(flags: Int32, channelId: Int64, title: String?, username: String?, photo: Api.Photo?)
        case requestedPeerChat(flags: Int32, chatId: Int64, title: String?, photo: Api.Photo?)
        case requestedPeerUser(flags: Int32, userId: Int64, firstName: String?, lastName: String?, username: String?, photo: Api.Photo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .requestedPeerChannel(let flags, let channelId, let title, let username, let photo):
                    if boxed {
                        buffer.appendInt32(-1952185372)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    break
                case .requestedPeerChat(let flags, let chatId, let title, let photo):
                    if boxed {
                        buffer.appendInt32(1929860175)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    break
                case .requestedPeerUser(let flags, let userId, let firstName, let lastName, let username, let photo):
                    if boxed {
                        buffer.appendInt32(-701500310)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .requestedPeerChannel(let flags, let channelId, let title, let username, let photo):
                return ("requestedPeerChannel", [("flags", flags as Any), ("channelId", channelId as Any), ("title", title as Any), ("username", username as Any), ("photo", photo as Any)])
                case .requestedPeerChat(let flags, let chatId, let title, let photo):
                return ("requestedPeerChat", [("flags", flags as Any), ("chatId", chatId as Any), ("title", title as Any), ("photo", photo as Any)])
                case .requestedPeerUser(let flags, let userId, let firstName, let lastName, let username, let photo):
                return ("requestedPeerUser", [("flags", flags as Any), ("userId", userId as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("username", username as Any), ("photo", photo as Any)])
    }
    }
    
        public static func parse_requestedPeerChannel(_ reader: BufferReader) -> RequestedPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.RequestedPeer.requestedPeerChannel(flags: _1!, channelId: _2!, title: _3, username: _4, photo: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_requestedPeerChat(_ reader: BufferReader) -> RequestedPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.RequestedPeer.requestedPeerChat(flags: _1!, chatId: _2!, title: _3, photo: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_requestedPeerUser(_ reader: BufferReader) -> RequestedPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.RequestedPeer.requestedPeerUser(flags: _1!, userId: _2!, firstName: _3, lastName: _4, username: _5, photo: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum RequirementToContact: TypeConstructorDescription {
        case requirementToContactEmpty
        case requirementToContactPaidMessages(starsAmount: Int64)
        case requirementToContactPremium
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .requirementToContactEmpty:
                    if boxed {
                        buffer.appendInt32(84580409)
                    }
                    
                    break
                case .requirementToContactPaidMessages(let starsAmount):
                    if boxed {
                        buffer.appendInt32(-1258914157)
                    }
                    serializeInt64(starsAmount, buffer: buffer, boxed: false)
                    break
                case .requirementToContactPremium:
                    if boxed {
                        buffer.appendInt32(-444472087)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .requirementToContactEmpty:
                return ("requirementToContactEmpty", [])
                case .requirementToContactPaidMessages(let starsAmount):
                return ("requirementToContactPaidMessages", [("starsAmount", starsAmount as Any)])
                case .requirementToContactPremium:
                return ("requirementToContactPremium", [])
    }
    }
    
        public static func parse_requirementToContactEmpty(_ reader: BufferReader) -> RequirementToContact? {
            return Api.RequirementToContact.requirementToContactEmpty
        }
        public static func parse_requirementToContactPaidMessages(_ reader: BufferReader) -> RequirementToContact? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.RequirementToContact.requirementToContactPaidMessages(starsAmount: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_requirementToContactPremium(_ reader: BufferReader) -> RequirementToContact? {
            return Api.RequirementToContact.requirementToContactPremium
        }
    
    }
}
