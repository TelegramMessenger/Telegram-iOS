public extension Api {
    enum SendAsPeer: TypeConstructorDescription {
        public class Cons_sendAsPeer: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public init(flags: Int32, peer: Api.Peer) {
                self.flags = flags
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendAsPeer", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer))])
            }
        }
        case sendAsPeer(Cons_sendAsPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sendAsPeer(let _data):
                if boxed {
                    buffer.appendInt32(-1206095820)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sendAsPeer(let _data):
                return ("sendAsPeer", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer))])
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
                return Api.SendAsPeer.sendAsPeer(Cons_sendAsPeer(flags: _1!, peer: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SendMessageAction: TypeConstructorDescription {
        public class Cons_inputSendMessageRichMessageDraftAction: TypeConstructorDescription {
            public var flags: Int32
            public var randomId: Int64
            public var richMessage: Api.InputRichMessage
            public init(flags: Int32, randomId: Int64, richMessage: Api.InputRichMessage) {
                self.flags = flags
                self.randomId = randomId
                self.richMessage = richMessage
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSendMessageRichMessageDraftAction", [("flags", ConstructorParameterDescription(self.flags)), ("randomId", ConstructorParameterDescription(self.randomId)), ("richMessage", ConstructorParameterDescription(self.richMessage))])
            }
        }
        public class Cons_sendMessageEmojiInteraction: TypeConstructorDescription {
            public var emoticon: String
            public var msgId: Int32
            public var interaction: Api.DataJSON
            public init(emoticon: String, msgId: Int32, interaction: Api.DataJSON) {
                self.emoticon = emoticon
                self.msgId = msgId
                self.interaction = interaction
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageEmojiInteraction", [("emoticon", ConstructorParameterDescription(self.emoticon)), ("msgId", ConstructorParameterDescription(self.msgId)), ("interaction", ConstructorParameterDescription(self.interaction))])
            }
        }
        public class Cons_sendMessageEmojiInteractionSeen: TypeConstructorDescription {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageEmojiInteractionSeen", [("emoticon", ConstructorParameterDescription(self.emoticon))])
            }
        }
        public class Cons_sendMessageHistoryImportAction: TypeConstructorDescription {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageHistoryImportAction", [("progress", ConstructorParameterDescription(self.progress))])
            }
        }
        public class Cons_sendMessageRichMessageDraftAction: TypeConstructorDescription {
            public var flags: Int32
            public var randomId: Int64
            public var richMessage: Api.RichMessage
            public init(flags: Int32, randomId: Int64, richMessage: Api.RichMessage) {
                self.flags = flags
                self.randomId = randomId
                self.richMessage = richMessage
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageRichMessageDraftAction", [("flags", ConstructorParameterDescription(self.flags)), ("randomId", ConstructorParameterDescription(self.randomId)), ("richMessage", ConstructorParameterDescription(self.richMessage))])
            }
        }
        public class Cons_sendMessageStopDraftAction: TypeConstructorDescription {
            public var randomId: Int64
            public init(randomId: Int64) {
                self.randomId = randomId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageStopDraftAction", [("randomId", ConstructorParameterDescription(self.randomId))])
            }
        }
        public class Cons_sendMessageTextDraftAction: TypeConstructorDescription {
            public var flags: Int32
            public var randomId: Int64
            public var text: Api.TextWithEntities
            public init(flags: Int32, randomId: Int64, text: Api.TextWithEntities) {
                self.flags = flags
                self.randomId = randomId
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageTextDraftAction", [("flags", ConstructorParameterDescription(self.flags)), ("randomId", ConstructorParameterDescription(self.randomId)), ("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_sendMessageUploadAudioAction: TypeConstructorDescription {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageUploadAudioAction", [("progress", ConstructorParameterDescription(self.progress))])
            }
        }
        public class Cons_sendMessageUploadDocumentAction: TypeConstructorDescription {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageUploadDocumentAction", [("progress", ConstructorParameterDescription(self.progress))])
            }
        }
        public class Cons_sendMessageUploadPhotoAction: TypeConstructorDescription {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageUploadPhotoAction", [("progress", ConstructorParameterDescription(self.progress))])
            }
        }
        public class Cons_sendMessageUploadRoundAction: TypeConstructorDescription {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageUploadRoundAction", [("progress", ConstructorParameterDescription(self.progress))])
            }
        }
        public class Cons_sendMessageUploadVideoAction: TypeConstructorDescription {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sendMessageUploadVideoAction", [("progress", ConstructorParameterDescription(self.progress))])
            }
        }
        case inputSendMessageRichMessageDraftAction(Cons_inputSendMessageRichMessageDraftAction)
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageChooseStickerAction
        case sendMessageEmojiInteraction(Cons_sendMessageEmojiInteraction)
        case sendMessageEmojiInteractionSeen(Cons_sendMessageEmojiInteractionSeen)
        case sendMessageGamePlayAction
        case sendMessageGeoLocationAction
        case sendMessageHistoryImportAction(Cons_sendMessageHistoryImportAction)
        case sendMessageRecordAudioAction
        case sendMessageRecordRoundAction
        case sendMessageRecordVideoAction
        case sendMessageRichMessageDraftAction(Cons_sendMessageRichMessageDraftAction)
        case sendMessageStopDraftAction(Cons_sendMessageStopDraftAction)
        case sendMessageTextDraftAction(Cons_sendMessageTextDraftAction)
        case sendMessageTypingAction
        case sendMessageUploadAudioAction(Cons_sendMessageUploadAudioAction)
        case sendMessageUploadDocumentAction(Cons_sendMessageUploadDocumentAction)
        case sendMessageUploadPhotoAction(Cons_sendMessageUploadPhotoAction)
        case sendMessageUploadRoundAction(Cons_sendMessageUploadRoundAction)
        case sendMessageUploadVideoAction(Cons_sendMessageUploadVideoAction)
        case speakingInGroupCallAction

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputSendMessageRichMessageDraftAction(let _data):
                if boxed {
                    buffer.appendInt32(-1455962178)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                _data.richMessage.serialize(buffer, true)
                break
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
            case .sendMessageEmojiInteraction(let _data):
                if boxed {
                    buffer.appendInt32(630664139)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                _data.interaction.serialize(buffer, true)
                break
            case .sendMessageEmojiInteractionSeen(let _data):
                if boxed {
                    buffer.appendInt32(-1234857938)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
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
            case .sendMessageHistoryImportAction(let _data):
                if boxed {
                    buffer.appendInt32(-606432698)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
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
            case .sendMessageRichMessageDraftAction(let _data):
                if boxed {
                    buffer.appendInt32(1381386387)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                _data.richMessage.serialize(buffer, true)
                break
            case .sendMessageStopDraftAction(let _data):
                if boxed {
                    buffer.appendInt32(-67566928)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                break
            case .sendMessageTextDraftAction(let _data):
                if boxed {
                    buffer.appendInt32(909162586)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                _data.text.serialize(buffer, true)
                break
            case .sendMessageTypingAction:
                if boxed {
                    buffer.appendInt32(381645902)
                }
                break
            case .sendMessageUploadAudioAction(let _data):
                if boxed {
                    buffer.appendInt32(-212740181)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadDocumentAction(let _data):
                if boxed {
                    buffer.appendInt32(-1441998364)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadPhotoAction(let _data):
                if boxed {
                    buffer.appendInt32(-774682074)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadRoundAction(let _data):
                if boxed {
                    buffer.appendInt32(608050278)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadVideoAction(let _data):
                if boxed {
                    buffer.appendInt32(-378127636)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .speakingInGroupCallAction:
                if boxed {
                    buffer.appendInt32(-651419003)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputSendMessageRichMessageDraftAction(let _data):
                return ("inputSendMessageRichMessageDraftAction", [("flags", ConstructorParameterDescription(_data.flags)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("richMessage", ConstructorParameterDescription(_data.richMessage))])
            case .sendMessageCancelAction:
                return ("sendMessageCancelAction", [])
            case .sendMessageChooseContactAction:
                return ("sendMessageChooseContactAction", [])
            case .sendMessageChooseStickerAction:
                return ("sendMessageChooseStickerAction", [])
            case .sendMessageEmojiInteraction(let _data):
                return ("sendMessageEmojiInteraction", [("emoticon", ConstructorParameterDescription(_data.emoticon)), ("msgId", ConstructorParameterDescription(_data.msgId)), ("interaction", ConstructorParameterDescription(_data.interaction))])
            case .sendMessageEmojiInteractionSeen(let _data):
                return ("sendMessageEmojiInteractionSeen", [("emoticon", ConstructorParameterDescription(_data.emoticon))])
            case .sendMessageGamePlayAction:
                return ("sendMessageGamePlayAction", [])
            case .sendMessageGeoLocationAction:
                return ("sendMessageGeoLocationAction", [])
            case .sendMessageHistoryImportAction(let _data):
                return ("sendMessageHistoryImportAction", [("progress", ConstructorParameterDescription(_data.progress))])
            case .sendMessageRecordAudioAction:
                return ("sendMessageRecordAudioAction", [])
            case .sendMessageRecordRoundAction:
                return ("sendMessageRecordRoundAction", [])
            case .sendMessageRecordVideoAction:
                return ("sendMessageRecordVideoAction", [])
            case .sendMessageRichMessageDraftAction(let _data):
                return ("sendMessageRichMessageDraftAction", [("flags", ConstructorParameterDescription(_data.flags)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("richMessage", ConstructorParameterDescription(_data.richMessage))])
            case .sendMessageStopDraftAction(let _data):
                return ("sendMessageStopDraftAction", [("randomId", ConstructorParameterDescription(_data.randomId))])
            case .sendMessageTextDraftAction(let _data):
                return ("sendMessageTextDraftAction", [("flags", ConstructorParameterDescription(_data.flags)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("text", ConstructorParameterDescription(_data.text))])
            case .sendMessageTypingAction:
                return ("sendMessageTypingAction", [])
            case .sendMessageUploadAudioAction(let _data):
                return ("sendMessageUploadAudioAction", [("progress", ConstructorParameterDescription(_data.progress))])
            case .sendMessageUploadDocumentAction(let _data):
                return ("sendMessageUploadDocumentAction", [("progress", ConstructorParameterDescription(_data.progress))])
            case .sendMessageUploadPhotoAction(let _data):
                return ("sendMessageUploadPhotoAction", [("progress", ConstructorParameterDescription(_data.progress))])
            case .sendMessageUploadRoundAction(let _data):
                return ("sendMessageUploadRoundAction", [("progress", ConstructorParameterDescription(_data.progress))])
            case .sendMessageUploadVideoAction(let _data):
                return ("sendMessageUploadVideoAction", [("progress", ConstructorParameterDescription(_data.progress))])
            case .speakingInGroupCallAction:
                return ("speakingInGroupCallAction", [])
            }
        }

        public static func parse_inputSendMessageRichMessageDraftAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.InputRichMessage?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputRichMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SendMessageAction.inputSendMessageRichMessageDraftAction(Cons_inputSendMessageRichMessageDraftAction(flags: _1!, randomId: _2!, richMessage: _3!))
            }
            else {
                return nil
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
                return Api.SendMessageAction.sendMessageEmojiInteraction(Cons_sendMessageEmojiInteraction(emoticon: _1!, msgId: _2!, interaction: _3!))
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
                return Api.SendMessageAction.sendMessageEmojiInteractionSeen(Cons_sendMessageEmojiInteractionSeen(emoticon: _1!))
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
                return Api.SendMessageAction.sendMessageHistoryImportAction(Cons_sendMessageHistoryImportAction(progress: _1!))
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
        public static func parse_sendMessageRichMessageDraftAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.RichMessage?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.RichMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SendMessageAction.sendMessageRichMessageDraftAction(Cons_sendMessageRichMessageDraftAction(flags: _1!, randomId: _2!, richMessage: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageStopDraftAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageStopDraftAction(Cons_sendMessageStopDraftAction(randomId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageTextDraftAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SendMessageAction.sendMessageTextDraftAction(Cons_sendMessageTextDraftAction(flags: _1!, randomId: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageTypingAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageTypingAction
        }
        public static func parse_sendMessageUploadAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadAudioAction(Cons_sendMessageUploadAudioAction(progress: _1!))
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
                return Api.SendMessageAction.sendMessageUploadDocumentAction(Cons_sendMessageUploadDocumentAction(progress: _1!))
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
                return Api.SendMessageAction.sendMessageUploadPhotoAction(Cons_sendMessageUploadPhotoAction(progress: _1!))
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
                return Api.SendMessageAction.sendMessageUploadRoundAction(Cons_sendMessageUploadRoundAction(progress: _1!))
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
                return Api.SendMessageAction.sendMessageUploadVideoAction(Cons_sendMessageUploadVideoAction(progress: _1!))
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
        public class Cons_shippingOption: TypeConstructorDescription {
            public var id: String
            public var title: String
            public var prices: [Api.LabeledPrice]
            public init(id: String, title: String, prices: [Api.LabeledPrice]) {
                self.id = id
                self.title = title
                self.prices = prices
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("shippingOption", [("id", ConstructorParameterDescription(self.id)), ("title", ConstructorParameterDescription(self.title)), ("prices", ConstructorParameterDescription(self.prices))])
            }
        }
        case shippingOption(Cons_shippingOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .shippingOption(let _data):
                if boxed {
                    buffer.appendInt32(-1239335713)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.prices.count))
                for item in _data.prices {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .shippingOption(let _data):
                return ("shippingOption", [("id", ConstructorParameterDescription(_data.id)), ("title", ConstructorParameterDescription(_data.title)), ("prices", ConstructorParameterDescription(_data.prices))])
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
                return Api.ShippingOption.shippingOption(Cons_shippingOption(id: _1!, title: _2!, prices: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SmsJob: TypeConstructorDescription {
        public class Cons_smsJob: TypeConstructorDescription {
            public var jobId: String
            public var phoneNumber: String
            public var text: String
            public init(jobId: String, phoneNumber: String, text: String) {
                self.jobId = jobId
                self.phoneNumber = phoneNumber
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("smsJob", [("jobId", ConstructorParameterDescription(self.jobId)), ("phoneNumber", ConstructorParameterDescription(self.phoneNumber)), ("text", ConstructorParameterDescription(self.text))])
            }
        }
        case smsJob(Cons_smsJob)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .smsJob(let _data):
                if boxed {
                    buffer.appendInt32(-425595208)
                }
                serializeString(_data.jobId, buffer: buffer, boxed: false)
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .smsJob(let _data):
                return ("smsJob", [("jobId", ConstructorParameterDescription(_data.jobId)), ("phoneNumber", ConstructorParameterDescription(_data.phoneNumber)), ("text", ConstructorParameterDescription(_data.text))])
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
                return Api.SmsJob.smsJob(Cons_smsJob(jobId: _1!, phoneNumber: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription {
        public class Cons_sponsoredMessage: TypeConstructorDescription {
            public var flags: Int32
            public var randomId: Buffer
            public var url: String
            public var title: String
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var photo: Api.Photo?
            public var media: Api.MessageMedia?
            public var color: Api.PeerColor?
            public var buttonText: String
            public var sponsorInfo: String?
            public var additionalInfo: String?
            public var minDisplayDuration: Int32?
            public var maxDisplayDuration: Int32?
            public init(flags: Int32, randomId: Buffer, url: String, title: String, message: String, entities: [Api.MessageEntity]?, photo: Api.Photo?, media: Api.MessageMedia?, color: Api.PeerColor?, buttonText: String, sponsorInfo: String?, additionalInfo: String?, minDisplayDuration: Int32?, maxDisplayDuration: Int32?) {
                self.flags = flags
                self.randomId = randomId
                self.url = url
                self.title = title
                self.message = message
                self.entities = entities
                self.photo = photo
                self.media = media
                self.color = color
                self.buttonText = buttonText
                self.sponsorInfo = sponsorInfo
                self.additionalInfo = additionalInfo
                self.minDisplayDuration = minDisplayDuration
                self.maxDisplayDuration = maxDisplayDuration
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sponsoredMessage", [("flags", ConstructorParameterDescription(self.flags)), ("randomId", ConstructorParameterDescription(self.randomId)), ("url", ConstructorParameterDescription(self.url)), ("title", ConstructorParameterDescription(self.title)), ("message", ConstructorParameterDescription(self.message)), ("entities", ConstructorParameterDescription(self.entities)), ("photo", ConstructorParameterDescription(self.photo)), ("media", ConstructorParameterDescription(self.media)), ("color", ConstructorParameterDescription(self.color)), ("buttonText", ConstructorParameterDescription(self.buttonText)), ("sponsorInfo", ConstructorParameterDescription(self.sponsorInfo)), ("additionalInfo", ConstructorParameterDescription(self.additionalInfo)), ("minDisplayDuration", ConstructorParameterDescription(self.minDisplayDuration)), ("maxDisplayDuration", ConstructorParameterDescription(self.maxDisplayDuration))])
            }
        }
        case sponsoredMessage(Cons_sponsoredMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredMessage(let _data):
                if boxed {
                    buffer.appendInt32(2109703795)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeBytes(_data.randomId, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    _data.media!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    _data.color!.serialize(buffer, true)
                }
                serializeString(_data.buttonText, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeString(_data.sponsorInfo!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.additionalInfo!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.minDisplayDuration!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.maxDisplayDuration!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sponsoredMessage(let _data):
                return ("sponsoredMessage", [("flags", ConstructorParameterDescription(_data.flags)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("url", ConstructorParameterDescription(_data.url)), ("title", ConstructorParameterDescription(_data.title)), ("message", ConstructorParameterDescription(_data.message)), ("entities", ConstructorParameterDescription(_data.entities)), ("photo", ConstructorParameterDescription(_data.photo)), ("media", ConstructorParameterDescription(_data.media)), ("color", ConstructorParameterDescription(_data.color)), ("buttonText", ConstructorParameterDescription(_data.buttonText)), ("sponsorInfo", ConstructorParameterDescription(_data.sponsorInfo)), ("additionalInfo", ConstructorParameterDescription(_data.additionalInfo)), ("minDisplayDuration", ConstructorParameterDescription(_data.minDisplayDuration)), ("maxDisplayDuration", ConstructorParameterDescription(_data.maxDisplayDuration))])
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
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _7: Api.Photo?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _8: Api.MessageMedia?
            if Int(_1 ?? 0) & Int(1 << 14) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.MessageMedia
                }
            }
            var _9: Api.PeerColor?
            if Int(_1 ?? 0) & Int(1 << 13) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _10: String?
            _10 = parseString(reader)
            var _11: String?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                _11 = parseString(reader)
            }
            var _12: String?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _12 = parseString(reader)
            }
            var _13: Int32?
            if Int(_1 ?? 0) & Int(1 << 15) != 0 {
                _13 = reader.readInt32()
            }
            var _14: Int32?
            if Int(_1 ?? 0) & Int(1 << 15) != 0 {
                _14 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 14) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 13) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _11 != nil
            let _c12 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _12 != nil
            let _c13 = (Int(_1 ?? 0) & Int(1 << 15) == 0) || _13 != nil
            let _c14 = (Int(_1 ?? 0) & Int(1 << 15) == 0) || _14 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 {
                return Api.SponsoredMessage.sponsoredMessage(Cons_sponsoredMessage(flags: _1!, randomId: _2!, url: _3!, title: _4!, message: _5!, entities: _6, photo: _7, media: _8, color: _9, buttonText: _10!, sponsorInfo: _11, additionalInfo: _12, minDisplayDuration: _13, maxDisplayDuration: _14))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SponsoredMessageReportOption: TypeConstructorDescription {
        public class Cons_sponsoredMessageReportOption: TypeConstructorDescription {
            public var text: String
            public var option: Buffer
            public init(text: String, option: Buffer) {
                self.text = text
                self.option = option
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sponsoredMessageReportOption", [("text", ConstructorParameterDescription(self.text)), ("option", ConstructorParameterDescription(self.option))])
            }
        }
        case sponsoredMessageReportOption(Cons_sponsoredMessageReportOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredMessageReportOption(let _data):
                if boxed {
                    buffer.appendInt32(1124938064)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeBytes(_data.option, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sponsoredMessageReportOption(let _data):
                return ("sponsoredMessageReportOption", [("text", ConstructorParameterDescription(_data.text)), ("option", ConstructorParameterDescription(_data.option))])
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
                return Api.SponsoredMessageReportOption.sponsoredMessageReportOption(Cons_sponsoredMessageReportOption(text: _1!, option: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SponsoredPeer: TypeConstructorDescription {
        public class Cons_sponsoredPeer: TypeConstructorDescription {
            public var flags: Int32
            public var randomId: Buffer
            public var peer: Api.Peer
            public var sponsorInfo: String?
            public var additionalInfo: String?
            public init(flags: Int32, randomId: Buffer, peer: Api.Peer, sponsorInfo: String?, additionalInfo: String?) {
                self.flags = flags
                self.randomId = randomId
                self.peer = peer
                self.sponsorInfo = sponsorInfo
                self.additionalInfo = additionalInfo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sponsoredPeer", [("flags", ConstructorParameterDescription(self.flags)), ("randomId", ConstructorParameterDescription(self.randomId)), ("peer", ConstructorParameterDescription(self.peer)), ("sponsorInfo", ConstructorParameterDescription(self.sponsorInfo)), ("additionalInfo", ConstructorParameterDescription(self.additionalInfo))])
            }
        }
        case sponsoredPeer(Cons_sponsoredPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredPeer(let _data):
                if boxed {
                    buffer.appendInt32(-963180333)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeBytes(_data.randomId, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.sponsorInfo!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.additionalInfo!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sponsoredPeer(let _data):
                return ("sponsoredPeer", [("flags", ConstructorParameterDescription(_data.flags)), ("randomId", ConstructorParameterDescription(_data.randomId)), ("peer", ConstructorParameterDescription(_data.peer)), ("sponsorInfo", ConstructorParameterDescription(_data.sponsorInfo)), ("additionalInfo", ConstructorParameterDescription(_data.additionalInfo))])
            }
        }

        public static func parse_sponsoredPeer(_ reader: BufferReader) -> SponsoredPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.SponsoredPeer.sponsoredPeer(Cons_sponsoredPeer(flags: _1!, randomId: _2!, peer: _3!, sponsorInfo: _4, additionalInfo: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGift: TypeConstructorDescription {
        public class Cons_starGift: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var sticker: Api.Document
            public var stars: Int64
            public var availabilityRemains: Int32?
            public var availabilityTotal: Int32?
            public var availabilityResale: Int64?
            public var convertStars: Int64
            public var firstSaleDate: Int32?
            public var lastSaleDate: Int32?
            public var upgradeStars: Int64?
            public var resellMinStars: Int64?
            public var title: String?
            public var releasedBy: Api.Peer?
            public var perUserTotal: Int32?
            public var perUserRemains: Int32?
            public var lockedUntilDate: Int32?
            public var auctionSlug: String?
            public var giftsPerRound: Int32?
            public var auctionStartDate: Int32?
            public var upgradeVariants: Int32?
            public var background: Api.StarGiftBackground?
            public init(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, availabilityResale: Int64?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?, upgradeStars: Int64?, resellMinStars: Int64?, title: String?, releasedBy: Api.Peer?, perUserTotal: Int32?, perUserRemains: Int32?, lockedUntilDate: Int32?, auctionSlug: String?, giftsPerRound: Int32?, auctionStartDate: Int32?, upgradeVariants: Int32?, background: Api.StarGiftBackground?) {
                self.flags = flags
                self.id = id
                self.sticker = sticker
                self.stars = stars
                self.availabilityRemains = availabilityRemains
                self.availabilityTotal = availabilityTotal
                self.availabilityResale = availabilityResale
                self.convertStars = convertStars
                self.firstSaleDate = firstSaleDate
                self.lastSaleDate = lastSaleDate
                self.upgradeStars = upgradeStars
                self.resellMinStars = resellMinStars
                self.title = title
                self.releasedBy = releasedBy
                self.perUserTotal = perUserTotal
                self.perUserRemains = perUserRemains
                self.lockedUntilDate = lockedUntilDate
                self.auctionSlug = auctionSlug
                self.giftsPerRound = giftsPerRound
                self.auctionStartDate = auctionStartDate
                self.upgradeVariants = upgradeVariants
                self.background = background
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starGift", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("sticker", ConstructorParameterDescription(self.sticker)), ("stars", ConstructorParameterDescription(self.stars)), ("availabilityRemains", ConstructorParameterDescription(self.availabilityRemains)), ("availabilityTotal", ConstructorParameterDescription(self.availabilityTotal)), ("availabilityResale", ConstructorParameterDescription(self.availabilityResale)), ("convertStars", ConstructorParameterDescription(self.convertStars)), ("firstSaleDate", ConstructorParameterDescription(self.firstSaleDate)), ("lastSaleDate", ConstructorParameterDescription(self.lastSaleDate)), ("upgradeStars", ConstructorParameterDescription(self.upgradeStars)), ("resellMinStars", ConstructorParameterDescription(self.resellMinStars)), ("title", ConstructorParameterDescription(self.title)), ("releasedBy", ConstructorParameterDescription(self.releasedBy)), ("perUserTotal", ConstructorParameterDescription(self.perUserTotal)), ("perUserRemains", ConstructorParameterDescription(self.perUserRemains)), ("lockedUntilDate", ConstructorParameterDescription(self.lockedUntilDate)), ("auctionSlug", ConstructorParameterDescription(self.auctionSlug)), ("giftsPerRound", ConstructorParameterDescription(self.giftsPerRound)), ("auctionStartDate", ConstructorParameterDescription(self.auctionStartDate)), ("upgradeVariants", ConstructorParameterDescription(self.upgradeVariants)), ("background", ConstructorParameterDescription(self.background))])
            }
        }
        public class Cons_starGiftUnique: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var giftId: Int64
            public var title: String
            public var slug: String
            public var num: Int32
            public var ownerId: Api.Peer?
            public var ownerName: String?
            public var ownerAddress: String?
            public var attributes: [Api.StarGiftAttribute]
            public var availabilityIssued: Int32
            public var availabilityTotal: Int32
            public var giftAddress: String?
            public var resellAmount: [Api.StarsAmount]?
            public var releasedBy: Api.Peer?
            public var valueAmount: Int64?
            public var valueCurrency: String?
            public var valueUsdAmount: Int64?
            public var themePeer: Api.Peer?
            public var peerColor: Api.PeerColor?
            public var hostId: Api.Peer?
            public var offerMinStars: Int32?
            public var craftChancePermille: Int32?
            public init(flags: Int32, id: Int64, giftId: Int64, title: String, slug: String, num: Int32, ownerId: Api.Peer?, ownerName: String?, ownerAddress: String?, attributes: [Api.StarGiftAttribute], availabilityIssued: Int32, availabilityTotal: Int32, giftAddress: String?, resellAmount: [Api.StarsAmount]?, releasedBy: Api.Peer?, valueAmount: Int64?, valueCurrency: String?, valueUsdAmount: Int64?, themePeer: Api.Peer?, peerColor: Api.PeerColor?, hostId: Api.Peer?, offerMinStars: Int32?, craftChancePermille: Int32?) {
                self.flags = flags
                self.id = id
                self.giftId = giftId
                self.title = title
                self.slug = slug
                self.num = num
                self.ownerId = ownerId
                self.ownerName = ownerName
                self.ownerAddress = ownerAddress
                self.attributes = attributes
                self.availabilityIssued = availabilityIssued
                self.availabilityTotal = availabilityTotal
                self.giftAddress = giftAddress
                self.resellAmount = resellAmount
                self.releasedBy = releasedBy
                self.valueAmount = valueAmount
                self.valueCurrency = valueCurrency
                self.valueUsdAmount = valueUsdAmount
                self.themePeer = themePeer
                self.peerColor = peerColor
                self.hostId = hostId
                self.offerMinStars = offerMinStars
                self.craftChancePermille = craftChancePermille
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starGiftUnique", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("giftId", ConstructorParameterDescription(self.giftId)), ("title", ConstructorParameterDescription(self.title)), ("slug", ConstructorParameterDescription(self.slug)), ("num", ConstructorParameterDescription(self.num)), ("ownerId", ConstructorParameterDescription(self.ownerId)), ("ownerName", ConstructorParameterDescription(self.ownerName)), ("ownerAddress", ConstructorParameterDescription(self.ownerAddress)), ("attributes", ConstructorParameterDescription(self.attributes)), ("availabilityIssued", ConstructorParameterDescription(self.availabilityIssued)), ("availabilityTotal", ConstructorParameterDescription(self.availabilityTotal)), ("giftAddress", ConstructorParameterDescription(self.giftAddress)), ("resellAmount", ConstructorParameterDescription(self.resellAmount)), ("releasedBy", ConstructorParameterDescription(self.releasedBy)), ("valueAmount", ConstructorParameterDescription(self.valueAmount)), ("valueCurrency", ConstructorParameterDescription(self.valueCurrency)), ("valueUsdAmount", ConstructorParameterDescription(self.valueUsdAmount)), ("themePeer", ConstructorParameterDescription(self.themePeer)), ("peerColor", ConstructorParameterDescription(self.peerColor)), ("hostId", ConstructorParameterDescription(self.hostId)), ("offerMinStars", ConstructorParameterDescription(self.offerMinStars)), ("craftChancePermille", ConstructorParameterDescription(self.craftChancePermille))])
            }
        }
        case starGift(Cons_starGift)
        case starGiftUnique(Cons_starGiftUnique)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGift(let _data):
                if boxed {
                    buffer.appendInt32(825922887)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                _data.sticker.serialize(buffer, true)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.availabilityRemains!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.availabilityTotal!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.availabilityResale!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.convertStars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.firstSaleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.lastSaleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt64(_data.upgradeStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.resellMinStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.releasedBy!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt32(_data.perUserTotal!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt32(_data.perUserRemains!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeInt32(_data.lockedUntilDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeString(_data.auctionSlug!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.giftsPerRound!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.auctionStartDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeInt32(_data.upgradeVariants!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    _data.background!.serialize(buffer, true)
                }
                break
            case .starGiftUnique(let _data):
                if boxed {
                    buffer.appendInt32(-2047825459)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.giftId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                serializeInt32(_data.num, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.ownerId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.ownerName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.ownerAddress!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.availabilityIssued, buffer: buffer, boxed: false)
                serializeInt32(_data.availabilityTotal, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.giftAddress!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.resellAmount!.count))
                    for item in _data.resellAmount! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.releasedBy!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.valueAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.valueCurrency!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.valueUsdAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.themePeer!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    _data.peerColor!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    _data.hostId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt32(_data.offerMinStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeInt32(_data.craftChancePermille!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starGift(let _data):
                return ("starGift", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("sticker", ConstructorParameterDescription(_data.sticker)), ("stars", ConstructorParameterDescription(_data.stars)), ("availabilityRemains", ConstructorParameterDescription(_data.availabilityRemains)), ("availabilityTotal", ConstructorParameterDescription(_data.availabilityTotal)), ("availabilityResale", ConstructorParameterDescription(_data.availabilityResale)), ("convertStars", ConstructorParameterDescription(_data.convertStars)), ("firstSaleDate", ConstructorParameterDescription(_data.firstSaleDate)), ("lastSaleDate", ConstructorParameterDescription(_data.lastSaleDate)), ("upgradeStars", ConstructorParameterDescription(_data.upgradeStars)), ("resellMinStars", ConstructorParameterDescription(_data.resellMinStars)), ("title", ConstructorParameterDescription(_data.title)), ("releasedBy", ConstructorParameterDescription(_data.releasedBy)), ("perUserTotal", ConstructorParameterDescription(_data.perUserTotal)), ("perUserRemains", ConstructorParameterDescription(_data.perUserRemains)), ("lockedUntilDate", ConstructorParameterDescription(_data.lockedUntilDate)), ("auctionSlug", ConstructorParameterDescription(_data.auctionSlug)), ("giftsPerRound", ConstructorParameterDescription(_data.giftsPerRound)), ("auctionStartDate", ConstructorParameterDescription(_data.auctionStartDate)), ("upgradeVariants", ConstructorParameterDescription(_data.upgradeVariants)), ("background", ConstructorParameterDescription(_data.background))])
            case .starGiftUnique(let _data):
                return ("starGiftUnique", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("giftId", ConstructorParameterDescription(_data.giftId)), ("title", ConstructorParameterDescription(_data.title)), ("slug", ConstructorParameterDescription(_data.slug)), ("num", ConstructorParameterDescription(_data.num)), ("ownerId", ConstructorParameterDescription(_data.ownerId)), ("ownerName", ConstructorParameterDescription(_data.ownerName)), ("ownerAddress", ConstructorParameterDescription(_data.ownerAddress)), ("attributes", ConstructorParameterDescription(_data.attributes)), ("availabilityIssued", ConstructorParameterDescription(_data.availabilityIssued)), ("availabilityTotal", ConstructorParameterDescription(_data.availabilityTotal)), ("giftAddress", ConstructorParameterDescription(_data.giftAddress)), ("resellAmount", ConstructorParameterDescription(_data.resellAmount)), ("releasedBy", ConstructorParameterDescription(_data.releasedBy)), ("valueAmount", ConstructorParameterDescription(_data.valueAmount)), ("valueCurrency", ConstructorParameterDescription(_data.valueCurrency)), ("valueUsdAmount", ConstructorParameterDescription(_data.valueUsdAmount)), ("themePeer", ConstructorParameterDescription(_data.themePeer)), ("peerColor", ConstructorParameterDescription(_data.peerColor)), ("hostId", ConstructorParameterDescription(_data.hostId)), ("offerMinStars", ConstructorParameterDescription(_data.offerMinStars)), ("craftChancePermille", ConstructorParameterDescription(_data.craftChancePermille))])
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int64?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Int64?
            _8 = reader.readInt64()
            var _9: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Int64?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _11 = reader.readInt64()
            }
            var _12: Int64?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _12 = reader.readInt64()
            }
            var _13: String?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _13 = parseString(reader)
            }
            var _14: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _14 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _15: Int32?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _15 = reader.readInt32()
            }
            var _16: Int32?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _16 = reader.readInt32()
            }
            var _17: Int32?
            if Int(_1 ?? 0) & Int(1 << 9) != 0 {
                _17 = reader.readInt32()
            }
            var _18: String?
            if Int(_1 ?? 0) & Int(1 << 11) != 0 {
                _18 = parseString(reader)
            }
            var _19: Int32?
            if Int(_1 ?? 0) & Int(1 << 11) != 0 {
                _19 = reader.readInt32()
            }
            var _20: Int32?
            if Int(_1 ?? 0) & Int(1 << 11) != 0 {
                _20 = reader.readInt32()
            }
            var _21: Int32?
            if Int(_1 ?? 0) & Int(1 << 12) != 0 {
                _21 = reader.readInt32()
            }
            var _22: Api.StarGiftBackground?
            if Int(_1 ?? 0) & Int(1 << 13) != 0 {
                if let signature = reader.readInt32() {
                    _22 = Api.parse(reader, signature: signature) as? Api.StarGiftBackground
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _12 != nil
            let _c13 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _13 != nil
            let _c14 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _14 != nil
            let _c15 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _15 != nil
            let _c16 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1 ?? 0) & Int(1 << 9) == 0) || _17 != nil
            let _c18 = (Int(_1 ?? 0) & Int(1 << 11) == 0) || _18 != nil
            let _c19 = (Int(_1 ?? 0) & Int(1 << 11) == 0) || _19 != nil
            let _c20 = (Int(_1 ?? 0) & Int(1 << 11) == 0) || _20 != nil
            let _c21 = (Int(_1 ?? 0) & Int(1 << 12) == 0) || _21 != nil
            let _c22 = (Int(_1 ?? 0) & Int(1 << 13) == 0) || _22 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
                return Api.StarGift.starGift(Cons_starGift(flags: _1!, id: _2!, sticker: _3!, stars: _4!, availabilityRemains: _5, availabilityTotal: _6, availabilityResale: _7, convertStars: _8!, firstSaleDate: _9, lastSaleDate: _10, upgradeStars: _11, resellMinStars: _12, title: _13, releasedBy: _14, perUserTotal: _15, perUserRemains: _16, lockedUntilDate: _17, auctionSlug: _18, giftsPerRound: _19, auctionStartDate: _20, upgradeVariants: _21, background: _22))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftUnique(_ reader: BufferReader) -> StarGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _8: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _8 = parseString(reader)
            }
            var _9: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _9 = parseString(reader)
            }
            var _10: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: String?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _13 = parseString(reader)
            }
            var _14: [Api.StarsAmount]?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsAmount.self)
                }
            }
            var _15: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _16: Int64?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _16 = reader.readInt64()
            }
            var _17: String?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _17 = parseString(reader)
            }
            var _18: Int64?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _18 = reader.readInt64()
            }
            var _19: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _19 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _20: Api.PeerColor?
            if Int(_1 ?? 0) & Int(1 << 11) != 0 {
                if let signature = reader.readInt32() {
                    _20 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _21: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 12) != 0 {
                if let signature = reader.readInt32() {
                    _21 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _22: Int32?
            if Int(_1 ?? 0) & Int(1 << 13) != 0 {
                _22 = reader.readInt32()
            }
            var _23: Int32?
            if Int(_1 ?? 0) & Int(1 << 16) != 0 {
                _23 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _13 != nil
            let _c14 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _14 != nil
            let _c15 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _15 != nil
            let _c16 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _17 != nil
            let _c18 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _18 != nil
            let _c19 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _19 != nil
            let _c20 = (Int(_1 ?? 0) & Int(1 << 11) == 0) || _20 != nil
            let _c21 = (Int(_1 ?? 0) & Int(1 << 12) == 0) || _21 != nil
            let _c22 = (Int(_1 ?? 0) & Int(1 << 13) == 0) || _22 != nil
            let _c23 = (Int(_1 ?? 0) & Int(1 << 16) == 0) || _23 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 {
                return Api.StarGift.starGiftUnique(Cons_starGiftUnique(flags: _1!, id: _2!, giftId: _3!, title: _4!, slug: _5!, num: _6!, ownerId: _7, ownerName: _8, ownerAddress: _9, attributes: _10!, availabilityIssued: _11!, availabilityTotal: _12!, giftAddress: _13, resellAmount: _14, releasedBy: _15, valueAmount: _16, valueCurrency: _17, valueUsdAmount: _18, themePeer: _19, peerColor: _20, hostId: _21, offerMinStars: _22, craftChancePermille: _23))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftActiveAuctionState: TypeConstructorDescription {
        public class Cons_starGiftActiveAuctionState: TypeConstructorDescription {
            public var gift: Api.StarGift
            public var state: Api.StarGiftAuctionState
            public var userState: Api.StarGiftAuctionUserState
            public init(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState) {
                self.gift = gift
                self.state = state
                self.userState = userState
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starGiftActiveAuctionState", [("gift", ConstructorParameterDescription(self.gift)), ("state", ConstructorParameterDescription(self.state)), ("userState", ConstructorParameterDescription(self.userState))])
            }
        }
        case starGiftActiveAuctionState(Cons_starGiftActiveAuctionState)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftActiveAuctionState(let _data):
                if boxed {
                    buffer.appendInt32(-753154979)
                }
                _data.gift.serialize(buffer, true)
                _data.state.serialize(buffer, true)
                _data.userState.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starGiftActiveAuctionState(let _data):
                return ("starGiftActiveAuctionState", [("gift", ConstructorParameterDescription(_data.gift)), ("state", ConstructorParameterDescription(_data.state)), ("userState", ConstructorParameterDescription(_data.userState))])
            }
        }

        public static func parse_starGiftActiveAuctionState(_ reader: BufferReader) -> StarGiftActiveAuctionState? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _2: Api.StarGiftAuctionState?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionState
            }
            var _3: Api.StarGiftAuctionUserState?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionUserState
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StarGiftActiveAuctionState.starGiftActiveAuctionState(Cons_starGiftActiveAuctionState(gift: _1!, state: _2!, userState: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAttribute: TypeConstructorDescription {
        public class Cons_starGiftAttributeBackdrop: TypeConstructorDescription {
            public var name: String
            public var backdropId: Int32
            public var centerColor: Int32
            public var edgeColor: Int32
            public var patternColor: Int32
            public var textColor: Int32
            public var rarity: Api.StarGiftAttributeRarity
            public init(name: String, backdropId: Int32, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarity: Api.StarGiftAttributeRarity) {
                self.name = name
                self.backdropId = backdropId
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.patternColor = patternColor
                self.textColor = textColor
                self.rarity = rarity
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starGiftAttributeBackdrop", [("name", ConstructorParameterDescription(self.name)), ("backdropId", ConstructorParameterDescription(self.backdropId)), ("centerColor", ConstructorParameterDescription(self.centerColor)), ("edgeColor", ConstructorParameterDescription(self.edgeColor)), ("patternColor", ConstructorParameterDescription(self.patternColor)), ("textColor", ConstructorParameterDescription(self.textColor)), ("rarity", ConstructorParameterDescription(self.rarity))])
            }
        }
        public class Cons_starGiftAttributeModel: TypeConstructorDescription {
            public var flags: Int32
            public var name: String
            public var document: Api.Document
            public var rarity: Api.StarGiftAttributeRarity
            public init(flags: Int32, name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
                self.flags = flags
                self.name = name
                self.document = document
                self.rarity = rarity
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starGiftAttributeModel", [("flags", ConstructorParameterDescription(self.flags)), ("name", ConstructorParameterDescription(self.name)), ("document", ConstructorParameterDescription(self.document)), ("rarity", ConstructorParameterDescription(self.rarity))])
            }
        }
        public class Cons_starGiftAttributeOriginalDetails: TypeConstructorDescription {
            public var flags: Int32
            public var senderId: Api.Peer?
            public var recipientId: Api.Peer
            public var date: Int32
            public var message: Api.TextWithEntities?
            public init(flags: Int32, senderId: Api.Peer?, recipientId: Api.Peer, date: Int32, message: Api.TextWithEntities?) {
                self.flags = flags
                self.senderId = senderId
                self.recipientId = recipientId
                self.date = date
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starGiftAttributeOriginalDetails", [("flags", ConstructorParameterDescription(self.flags)), ("senderId", ConstructorParameterDescription(self.senderId)), ("recipientId", ConstructorParameterDescription(self.recipientId)), ("date", ConstructorParameterDescription(self.date)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_starGiftAttributePattern: TypeConstructorDescription {
            public var name: String
            public var document: Api.Document
            public var rarity: Api.StarGiftAttributeRarity
            public init(name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
                self.name = name
                self.document = document
                self.rarity = rarity
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starGiftAttributePattern", [("name", ConstructorParameterDescription(self.name)), ("document", ConstructorParameterDescription(self.document)), ("rarity", ConstructorParameterDescription(self.rarity))])
            }
        }
        case starGiftAttributeBackdrop(Cons_starGiftAttributeBackdrop)
        case starGiftAttributeModel(Cons_starGiftAttributeModel)
        case starGiftAttributeOriginalDetails(Cons_starGiftAttributeOriginalDetails)
        case starGiftAttributePattern(Cons_starGiftAttributePattern)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeBackdrop(let _data):
                if boxed {
                    buffer.appendInt32(-1624963868)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeInt32(_data.backdropId, buffer: buffer, boxed: false)
                serializeInt32(_data.centerColor, buffer: buffer, boxed: false)
                serializeInt32(_data.edgeColor, buffer: buffer, boxed: false)
                serializeInt32(_data.patternColor, buffer: buffer, boxed: false)
                serializeInt32(_data.textColor, buffer: buffer, boxed: false)
                _data.rarity.serialize(buffer, true)
                break
            case .starGiftAttributeModel(let _data):
                if boxed {
                    buffer.appendInt32(1448235490)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                _data.rarity.serialize(buffer, true)
                break
            case .starGiftAttributeOriginalDetails(let _data):
                if boxed {
                    buffer.appendInt32(-524291476)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.senderId!.serialize(buffer, true)
                }
                _data.recipientId.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .starGiftAttributePattern(let _data):
                if boxed {
                    buffer.appendInt32(1315997162)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                _data.rarity.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starGiftAttributeBackdrop(let _data):
                return ("starGiftAttributeBackdrop", [("name", ConstructorParameterDescription(_data.name)), ("backdropId", ConstructorParameterDescription(_data.backdropId)), ("centerColor", ConstructorParameterDescription(_data.centerColor)), ("edgeColor", ConstructorParameterDescription(_data.edgeColor)), ("patternColor", ConstructorParameterDescription(_data.patternColor)), ("textColor", ConstructorParameterDescription(_data.textColor)), ("rarity", ConstructorParameterDescription(_data.rarity))])
            case .starGiftAttributeModel(let _data):
                return ("starGiftAttributeModel", [("flags", ConstructorParameterDescription(_data.flags)), ("name", ConstructorParameterDescription(_data.name)), ("document", ConstructorParameterDescription(_data.document)), ("rarity", ConstructorParameterDescription(_data.rarity))])
            case .starGiftAttributeOriginalDetails(let _data):
                return ("starGiftAttributeOriginalDetails", [("flags", ConstructorParameterDescription(_data.flags)), ("senderId", ConstructorParameterDescription(_data.senderId)), ("recipientId", ConstructorParameterDescription(_data.recipientId)), ("date", ConstructorParameterDescription(_data.date)), ("message", ConstructorParameterDescription(_data.message))])
            case .starGiftAttributePattern(let _data):
                return ("starGiftAttributePattern", [("name", ConstructorParameterDescription(_data.name)), ("document", ConstructorParameterDescription(_data.document)), ("rarity", ConstructorParameterDescription(_data.rarity))])
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
            var _7: Api.StarGiftAttributeRarity?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeRarity
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.StarGiftAttribute.starGiftAttributeBackdrop(Cons_starGiftAttributeBackdrop(name: _1!, backdropId: _2!, centerColor: _3!, edgeColor: _4!, patternColor: _5!, textColor: _6!, rarity: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeModel(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Document?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _4: Api.StarGiftAttributeRarity?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeRarity
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StarGiftAttribute.starGiftAttributeModel(Cons_starGiftAttributeModel(flags: _1!, name: _2!, document: _3!, rarity: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeOriginalDetails(_ reader: BufferReader) -> StarGiftAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.TextWithEntities?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarGiftAttribute.starGiftAttributeOriginalDetails(Cons_starGiftAttributeOriginalDetails(flags: _1!, senderId: _2, recipientId: _3!, date: _4!, message: _5))
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
            var _3: Api.StarGiftAttributeRarity?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeRarity
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StarGiftAttribute.starGiftAttributePattern(Cons_starGiftAttributePattern(name: _1!, document: _2!, rarity: _3!))
            }
            else {
                return nil
            }
        }
    }
}
