public extension Api {
    enum ReceivedNotifyMessage: TypeConstructorDescription {
        public class Cons_receivedNotifyMessage {
            public var id: Int32
            public var flags: Int32
            public init(id: Int32, flags: Int32) {
                self.id = id
                self.flags = flags
            }
        }
        case receivedNotifyMessage(Cons_receivedNotifyMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .receivedNotifyMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1551583367)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .receivedNotifyMessage(let _data):
                return ("receivedNotifyMessage", [("id", _data.id as Any), ("flags", _data.flags as Any)])
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
                return Api.ReceivedNotifyMessage.receivedNotifyMessage(Cons_receivedNotifyMessage(id: _1!, flags: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum RecentMeUrl: TypeConstructorDescription {
        public class Cons_recentMeUrlChat {
            public var url: String
            public var chatId: Int64
            public init(url: String, chatId: Int64) {
                self.url = url
                self.chatId = chatId
            }
        }
        public class Cons_recentMeUrlChatInvite {
            public var url: String
            public var chatInvite: Api.ChatInvite
            public init(url: String, chatInvite: Api.ChatInvite) {
                self.url = url
                self.chatInvite = chatInvite
            }
        }
        public class Cons_recentMeUrlStickerSet {
            public var url: String
            public var set: Api.StickerSetCovered
            public init(url: String, set: Api.StickerSetCovered) {
                self.url = url
                self.set = set
            }
        }
        public class Cons_recentMeUrlUnknown {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        public class Cons_recentMeUrlUser {
            public var url: String
            public var userId: Int64
            public init(url: String, userId: Int64) {
                self.url = url
                self.userId = userId
            }
        }
        case recentMeUrlChat(Cons_recentMeUrlChat)
        case recentMeUrlChatInvite(Cons_recentMeUrlChatInvite)
        case recentMeUrlStickerSet(Cons_recentMeUrlStickerSet)
        case recentMeUrlUnknown(Cons_recentMeUrlUnknown)
        case recentMeUrlUser(Cons_recentMeUrlUser)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .recentMeUrlChat(let _data):
                if boxed {
                    buffer.appendInt32(-1294306862)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                break
            case .recentMeUrlChatInvite(let _data):
                if boxed {
                    buffer.appendInt32(-347535331)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                _data.chatInvite.serialize(buffer, true)
                break
            case .recentMeUrlStickerSet(let _data):
                if boxed {
                    buffer.appendInt32(-1140172836)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                _data.set.serialize(buffer, true)
                break
            case .recentMeUrlUnknown(let _data):
                if boxed {
                    buffer.appendInt32(1189204285)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .recentMeUrlUser(let _data):
                if boxed {
                    buffer.appendInt32(-1188296222)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .recentMeUrlChat(let _data):
                return ("recentMeUrlChat", [("url", _data.url as Any), ("chatId", _data.chatId as Any)])
            case .recentMeUrlChatInvite(let _data):
                return ("recentMeUrlChatInvite", [("url", _data.url as Any), ("chatInvite", _data.chatInvite as Any)])
            case .recentMeUrlStickerSet(let _data):
                return ("recentMeUrlStickerSet", [("url", _data.url as Any), ("set", _data.set as Any)])
            case .recentMeUrlUnknown(let _data):
                return ("recentMeUrlUnknown", [("url", _data.url as Any)])
            case .recentMeUrlUser(let _data):
                return ("recentMeUrlUser", [("url", _data.url as Any), ("userId", _data.userId as Any)])
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
                return Api.RecentMeUrl.recentMeUrlChat(Cons_recentMeUrlChat(url: _1!, chatId: _2!))
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
                return Api.RecentMeUrl.recentMeUrlChatInvite(Cons_recentMeUrlChatInvite(url: _1!, chatInvite: _2!))
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
                return Api.RecentMeUrl.recentMeUrlStickerSet(Cons_recentMeUrlStickerSet(url: _1!, set: _2!))
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
                return Api.RecentMeUrl.recentMeUrlUnknown(Cons_recentMeUrlUnknown(url: _1!))
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
                return Api.RecentMeUrl.recentMeUrlUser(Cons_recentMeUrlUser(url: _1!, userId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum RecentStory: TypeConstructorDescription {
        public class Cons_recentStory {
            public var flags: Int32
            public var maxId: Int32?
            public init(flags: Int32, maxId: Int32?) {
                self.flags = flags
                self.maxId = maxId
            }
        }
        case recentStory(Cons_recentStory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .recentStory(let _data):
                if boxed {
                    buffer.appendInt32(1897752877)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.maxId!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .recentStory(let _data):
                return ("recentStory", [("flags", _data.flags as Any), ("maxId", _data.maxId as Any)])
            }
        }

        public static func parse_recentStory(_ reader: BufferReader) -> RecentStory? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.RecentStory.recentStory(Cons_recentStory(flags: _1!, maxId: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ReplyMarkup: TypeConstructorDescription {
        public class Cons_replyInlineMarkup {
            public var rows: [Api.KeyboardButtonRow]
            public init(rows: [Api.KeyboardButtonRow]) {
                self.rows = rows
            }
        }
        public class Cons_replyKeyboardForceReply {
            public var flags: Int32
            public var placeholder: String?
            public init(flags: Int32, placeholder: String?) {
                self.flags = flags
                self.placeholder = placeholder
            }
        }
        public class Cons_replyKeyboardHide {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_replyKeyboardMarkup {
            public var flags: Int32
            public var rows: [Api.KeyboardButtonRow]
            public var placeholder: String?
            public init(flags: Int32, rows: [Api.KeyboardButtonRow], placeholder: String?) {
                self.flags = flags
                self.rows = rows
                self.placeholder = placeholder
            }
        }
        case replyInlineMarkup(Cons_replyInlineMarkup)
        case replyKeyboardForceReply(Cons_replyKeyboardForceReply)
        case replyKeyboardHide(Cons_replyKeyboardHide)
        case replyKeyboardMarkup(Cons_replyKeyboardMarkup)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .replyInlineMarkup(let _data):
                if boxed {
                    buffer.appendInt32(1218642516)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rows.count))
                for item in _data.rows {
                    item.serialize(buffer, true)
                }
                break
            case .replyKeyboardForceReply(let _data):
                if boxed {
                    buffer.appendInt32(-2035021048)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.placeholder!, buffer: buffer, boxed: false)
                }
                break
            case .replyKeyboardHide(let _data):
                if boxed {
                    buffer.appendInt32(-1606526075)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .replyKeyboardMarkup(let _data):
                if boxed {
                    buffer.appendInt32(-2049074735)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rows.count))
                for item in _data.rows {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.placeholder!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .replyInlineMarkup(let _data):
                return ("replyInlineMarkup", [("rows", _data.rows as Any)])
            case .replyKeyboardForceReply(let _data):
                return ("replyKeyboardForceReply", [("flags", _data.flags as Any), ("placeholder", _data.placeholder as Any)])
            case .replyKeyboardHide(let _data):
                return ("replyKeyboardHide", [("flags", _data.flags as Any)])
            case .replyKeyboardMarkup(let _data):
                return ("replyKeyboardMarkup", [("flags", _data.flags as Any), ("rows", _data.rows as Any), ("placeholder", _data.placeholder as Any)])
            }
        }

        public static func parse_replyInlineMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: [Api.KeyboardButtonRow]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButtonRow.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReplyMarkup.replyInlineMarkup(Cons_replyInlineMarkup(rows: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardForceReply(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.ReplyMarkup.replyKeyboardForceReply(Cons_replyKeyboardForceReply(flags: _1!, placeholder: _2))
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
                return Api.ReplyMarkup.replyKeyboardHide(Cons_replyKeyboardHide(flags: _1!))
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
            if Int(_1!) & Int(1 << 3) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ReplyMarkup.replyKeyboardMarkup(Cons_replyKeyboardMarkup(flags: _1!, rows: _2!, placeholder: _3))
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
        public class Cons_reportResultAddComment {
            public var flags: Int32
            public var option: Buffer
            public init(flags: Int32, option: Buffer) {
                self.flags = flags
                self.option = option
            }
        }
        public class Cons_reportResultChooseOption {
            public var title: String
            public var options: [Api.MessageReportOption]
            public init(title: String, options: [Api.MessageReportOption]) {
                self.title = title
                self.options = options
            }
        }
        case reportResultAddComment(Cons_reportResultAddComment)
        case reportResultChooseOption(Cons_reportResultChooseOption)
        case reportResultReported

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .reportResultAddComment(let _data):
                if boxed {
                    buffer.appendInt32(1862904881)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeBytes(_data.option, buffer: buffer, boxed: false)
                break
            case .reportResultChooseOption(let _data):
                if boxed {
                    buffer.appendInt32(-253435722)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.options.count))
                for item in _data.options {
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
            case .reportResultAddComment(let _data):
                return ("reportResultAddComment", [("flags", _data.flags as Any), ("option", _data.option as Any)])
            case .reportResultChooseOption(let _data):
                return ("reportResultChooseOption", [("title", _data.title as Any), ("options", _data.options as Any)])
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
                return Api.ReportResult.reportResultAddComment(Cons_reportResultAddComment(flags: _1!, option: _2!))
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
                return Api.ReportResult.reportResultChooseOption(Cons_reportResultChooseOption(title: _1!, options: _2!))
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
        public class Cons_requestPeerTypeBroadcast {
            public var flags: Int32
            public var hasUsername: Api.Bool?
            public var userAdminRights: Api.ChatAdminRights?
            public var botAdminRights: Api.ChatAdminRights?
            public init(flags: Int32, hasUsername: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?) {
                self.flags = flags
                self.hasUsername = hasUsername
                self.userAdminRights = userAdminRights
                self.botAdminRights = botAdminRights
            }
        }
        public class Cons_requestPeerTypeChat {
            public var flags: Int32
            public var hasUsername: Api.Bool?
            public var forum: Api.Bool?
            public var userAdminRights: Api.ChatAdminRights?
            public var botAdminRights: Api.ChatAdminRights?
            public init(flags: Int32, hasUsername: Api.Bool?, forum: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?) {
                self.flags = flags
                self.hasUsername = hasUsername
                self.forum = forum
                self.userAdminRights = userAdminRights
                self.botAdminRights = botAdminRights
            }
        }
        public class Cons_requestPeerTypeUser {
            public var flags: Int32
            public var bot: Api.Bool?
            public var premium: Api.Bool?
            public init(flags: Int32, bot: Api.Bool?, premium: Api.Bool?) {
                self.flags = flags
                self.bot = bot
                self.premium = premium
            }
        }
        case requestPeerTypeBroadcast(Cons_requestPeerTypeBroadcast)
        case requestPeerTypeChat(Cons_requestPeerTypeChat)
        case requestPeerTypeUser(Cons_requestPeerTypeUser)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .requestPeerTypeBroadcast(let _data):
                if boxed {
                    buffer.appendInt32(865857388)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.hasUsername!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.userAdminRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.botAdminRights!.serialize(buffer, true)
                }
                break
            case .requestPeerTypeChat(let _data):
                if boxed {
                    buffer.appendInt32(-906990053)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.hasUsername!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.forum!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.userAdminRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.botAdminRights!.serialize(buffer, true)
                }
                break
            case .requestPeerTypeUser(let _data):
                if boxed {
                    buffer.appendInt32(1597737472)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.bot!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.premium!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .requestPeerTypeBroadcast(let _data):
                return ("requestPeerTypeBroadcast", [("flags", _data.flags as Any), ("hasUsername", _data.hasUsername as Any), ("userAdminRights", _data.userAdminRights as Any), ("botAdminRights", _data.botAdminRights as Any)])
            case .requestPeerTypeChat(let _data):
                return ("requestPeerTypeChat", [("flags", _data.flags as Any), ("hasUsername", _data.hasUsername as Any), ("forum", _data.forum as Any), ("userAdminRights", _data.userAdminRights as Any), ("botAdminRights", _data.botAdminRights as Any)])
            case .requestPeerTypeUser(let _data):
                return ("requestPeerTypeUser", [("flags", _data.flags as Any), ("bot", _data.bot as Any), ("premium", _data.premium as Any)])
            }
        }

        public static func parse_requestPeerTypeBroadcast(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _3: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            var _4: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.RequestPeerType.requestPeerTypeBroadcast(Cons_requestPeerTypeBroadcast(flags: _1!, hasUsername: _2, userAdminRights: _3, botAdminRights: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_requestPeerTypeChat(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _4: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            var _5: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 4) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.RequestPeerType.requestPeerTypeChat(Cons_requestPeerTypeChat(flags: _1!, hasUsername: _2, forum: _3, userAdminRights: _4, botAdminRights: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_requestPeerTypeUser(_ reader: BufferReader) -> RequestPeerType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.RequestPeerType.requestPeerTypeUser(Cons_requestPeerTypeUser(flags: _1!, bot: _2, premium: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum RequestedPeer: TypeConstructorDescription {
        public class Cons_requestedPeerChannel {
            public var flags: Int32
            public var channelId: Int64
            public var title: String?
            public var username: String?
            public var photo: Api.Photo?
            public init(flags: Int32, channelId: Int64, title: String?, username: String?, photo: Api.Photo?) {
                self.flags = flags
                self.channelId = channelId
                self.title = title
                self.username = username
                self.photo = photo
            }
        }
        public class Cons_requestedPeerChat {
            public var flags: Int32
            public var chatId: Int64
            public var title: String?
            public var photo: Api.Photo?
            public init(flags: Int32, chatId: Int64, title: String?, photo: Api.Photo?) {
                self.flags = flags
                self.chatId = chatId
                self.title = title
                self.photo = photo
            }
        }
        public class Cons_requestedPeerUser {
            public var flags: Int32
            public var userId: Int64
            public var firstName: String?
            public var lastName: String?
            public var username: String?
            public var photo: Api.Photo?
            public init(flags: Int32, userId: Int64, firstName: String?, lastName: String?, username: String?, photo: Api.Photo?) {
                self.flags = flags
                self.userId = userId
                self.firstName = firstName
                self.lastName = lastName
                self.username = username
                self.photo = photo
            }
        }
        case requestedPeerChannel(Cons_requestedPeerChannel)
        case requestedPeerChat(Cons_requestedPeerChat)
        case requestedPeerUser(Cons_requestedPeerUser)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .requestedPeerChannel(let _data):
                if boxed {
                    buffer.appendInt32(-1952185372)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.username!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                break
            case .requestedPeerChat(let _data):
                if boxed {
                    buffer.appendInt32(1929860175)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                break
            case .requestedPeerUser(let _data):
                if boxed {
                    buffer.appendInt32(-701500310)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.firstName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.lastName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.username!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .requestedPeerChannel(let _data):
                return ("requestedPeerChannel", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("title", _data.title as Any), ("username", _data.username as Any), ("photo", _data.photo as Any)])
            case .requestedPeerChat(let _data):
                return ("requestedPeerChat", [("flags", _data.flags as Any), ("chatId", _data.chatId as Any), ("title", _data.title as Any), ("photo", _data.photo as Any)])
            case .requestedPeerUser(let _data):
                return ("requestedPeerUser", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("username", _data.username as Any), ("photo", _data.photo as Any)])
            }
        }

        public static func parse_requestedPeerChannel(_ reader: BufferReader) -> RequestedPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.RequestedPeer.requestedPeerChannel(Cons_requestedPeerChannel(flags: _1!, channelId: _2!, title: _3, username: _4, photo: _5))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.RequestedPeer.requestedPeerChat(Cons_requestedPeerChat(flags: _1!, chatId: _2!, title: _3, photo: _4))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.RequestedPeer.requestedPeerUser(Cons_requestedPeerUser(flags: _1!, userId: _2!, firstName: _3, lastName: _4, username: _5, photo: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum RequirementToContact: TypeConstructorDescription {
        public class Cons_requirementToContactPaidMessages {
            public var starsAmount: Int64
            public init(starsAmount: Int64) {
                self.starsAmount = starsAmount
            }
        }
        case requirementToContactEmpty
        case requirementToContactPaidMessages(Cons_requirementToContactPaidMessages)
        case requirementToContactPremium

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .requirementToContactEmpty:
                if boxed {
                    buffer.appendInt32(84580409)
                }
                break
            case .requirementToContactPaidMessages(let _data):
                if boxed {
                    buffer.appendInt32(-1258914157)
                }
                serializeInt64(_data.starsAmount, buffer: buffer, boxed: false)
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
            case .requirementToContactPaidMessages(let _data):
                return ("requirementToContactPaidMessages", [("starsAmount", _data.starsAmount as Any)])
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
                return Api.RequirementToContact.requirementToContactPaidMessages(Cons_requirementToContactPaidMessages(starsAmount: _1!))
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
