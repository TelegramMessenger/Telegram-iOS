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
                return ("replyInlineMarkup", [("rows", String(describing: rows))])
                case .replyKeyboardForceReply(let flags, let placeholder):
                return ("replyKeyboardForceReply", [("flags", String(describing: flags)), ("placeholder", String(describing: placeholder))])
                case .replyKeyboardHide(let flags):
                return ("replyKeyboardHide", [("flags", String(describing: flags))])
                case .replyKeyboardMarkup(let flags, let rows, let placeholder):
                return ("replyKeyboardMarkup", [("flags", String(describing: flags)), ("rows", String(describing: rows)), ("placeholder", String(describing: placeholder))])
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
    enum RestrictionReason: TypeConstructorDescription {
        case restrictionReason(platform: String, reason: String, text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .restrictionReason(let platform, let reason, let text):
                    if boxed {
                        buffer.appendInt32(-797791052)
                    }
                    serializeString(platform, buffer: buffer, boxed: false)
                    serializeString(reason, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .restrictionReason(let platform, let reason, let text):
                return ("restrictionReason", [("platform", String(describing: platform)), ("reason", String(describing: reason)), ("text", String(describing: text))])
    }
    }
    
        public static func parse_restrictionReason(_ reader: BufferReader) -> RestrictionReason? {
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
                return Api.RestrictionReason.restrictionReason(platform: _1!, reason: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum RichText: TypeConstructorDescription {
        case textAnchor(text: Api.RichText, name: String)
        case textBold(text: Api.RichText)
        case textConcat(texts: [Api.RichText])
        case textEmail(text: Api.RichText, email: String)
        case textEmpty
        case textFixed(text: Api.RichText)
        case textImage(documentId: Int64, w: Int32, h: Int32)
        case textItalic(text: Api.RichText)
        case textMarked(text: Api.RichText)
        case textPhone(text: Api.RichText, phone: String)
        case textPlain(text: String)
        case textStrike(text: Api.RichText)
        case textSubscript(text: Api.RichText)
        case textSuperscript(text: Api.RichText)
        case textUnderline(text: Api.RichText)
        case textUrl(text: Api.RichText, url: String, webpageId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .textAnchor(let text, let name):
                    if boxed {
                        buffer.appendInt32(894777186)
                    }
                    text.serialize(buffer, true)
                    serializeString(name, buffer: buffer, boxed: false)
                    break
                case .textBold(let text):
                    if boxed {
                        buffer.appendInt32(1730456516)
                    }
                    text.serialize(buffer, true)
                    break
                case .textConcat(let texts):
                    if boxed {
                        buffer.appendInt32(2120376535)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(texts.count))
                    for item in texts {
                        item.serialize(buffer, true)
                    }
                    break
                case .textEmail(let text, let email):
                    if boxed {
                        buffer.appendInt32(-564523562)
                    }
                    text.serialize(buffer, true)
                    serializeString(email, buffer: buffer, boxed: false)
                    break
                case .textEmpty:
                    if boxed {
                        buffer.appendInt32(-599948721)
                    }
                    
                    break
                case .textFixed(let text):
                    if boxed {
                        buffer.appendInt32(1816074681)
                    }
                    text.serialize(buffer, true)
                    break
                case .textImage(let documentId, let w, let h):
                    if boxed {
                        buffer.appendInt32(136105807)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .textItalic(let text):
                    if boxed {
                        buffer.appendInt32(-653089380)
                    }
                    text.serialize(buffer, true)
                    break
                case .textMarked(let text):
                    if boxed {
                        buffer.appendInt32(55281185)
                    }
                    text.serialize(buffer, true)
                    break
                case .textPhone(let text, let phone):
                    if boxed {
                        buffer.appendInt32(483104362)
                    }
                    text.serialize(buffer, true)
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
                case .textPlain(let text):
                    if boxed {
                        buffer.appendInt32(1950782688)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .textStrike(let text):
                    if boxed {
                        buffer.appendInt32(-1678197867)
                    }
                    text.serialize(buffer, true)
                    break
                case .textSubscript(let text):
                    if boxed {
                        buffer.appendInt32(-311786236)
                    }
                    text.serialize(buffer, true)
                    break
                case .textSuperscript(let text):
                    if boxed {
                        buffer.appendInt32(-939827711)
                    }
                    text.serialize(buffer, true)
                    break
                case .textUnderline(let text):
                    if boxed {
                        buffer.appendInt32(-1054465340)
                    }
                    text.serialize(buffer, true)
                    break
                case .textUrl(let text, let url, let webpageId):
                    if boxed {
                        buffer.appendInt32(1009288385)
                    }
                    text.serialize(buffer, true)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(webpageId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .textAnchor(let text, let name):
                return ("textAnchor", [("text", String(describing: text)), ("name", String(describing: name))])
                case .textBold(let text):
                return ("textBold", [("text", String(describing: text))])
                case .textConcat(let texts):
                return ("textConcat", [("texts", String(describing: texts))])
                case .textEmail(let text, let email):
                return ("textEmail", [("text", String(describing: text)), ("email", String(describing: email))])
                case .textEmpty:
                return ("textEmpty", [])
                case .textFixed(let text):
                return ("textFixed", [("text", String(describing: text))])
                case .textImage(let documentId, let w, let h):
                return ("textImage", [("documentId", String(describing: documentId)), ("w", String(describing: w)), ("h", String(describing: h))])
                case .textItalic(let text):
                return ("textItalic", [("text", String(describing: text))])
                case .textMarked(let text):
                return ("textMarked", [("text", String(describing: text))])
                case .textPhone(let text, let phone):
                return ("textPhone", [("text", String(describing: text)), ("phone", String(describing: phone))])
                case .textPlain(let text):
                return ("textPlain", [("text", String(describing: text))])
                case .textStrike(let text):
                return ("textStrike", [("text", String(describing: text))])
                case .textSubscript(let text):
                return ("textSubscript", [("text", String(describing: text))])
                case .textSuperscript(let text):
                return ("textSuperscript", [("text", String(describing: text))])
                case .textUnderline(let text):
                return ("textUnderline", [("text", String(describing: text))])
                case .textUrl(let text, let url, let webpageId):
                return ("textUrl", [("text", String(describing: text)), ("url", String(describing: url)), ("webpageId", String(describing: webpageId))])
    }
    }
    
        public static func parse_textAnchor(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RichText.textAnchor(text: _1!, name: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_textBold(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textBold(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textConcat(_ reader: BufferReader) -> RichText? {
            var _1: [Api.RichText]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RichText.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textConcat(texts: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textEmail(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RichText.textEmail(text: _1!, email: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_textEmpty(_ reader: BufferReader) -> RichText? {
            return Api.RichText.textEmpty
        }
        public static func parse_textFixed(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textFixed(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textImage(_ reader: BufferReader) -> RichText? {
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
                return Api.RichText.textImage(documentId: _1!, w: _2!, h: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_textItalic(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textItalic(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textMarked(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textMarked(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textPhone(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RichText.textPhone(text: _1!, phone: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_textPlain(_ reader: BufferReader) -> RichText? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textPlain(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textStrike(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textStrike(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textSubscript(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textSubscript(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textSuperscript(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textSuperscript(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textUnderline(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.RichText.textUnderline(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_textUrl(_ reader: BufferReader) -> RichText? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.RichText.textUrl(text: _1!, url: _2!, webpageId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SavedContact: TypeConstructorDescription {
        case savedPhoneContact(phone: String, firstName: String, lastName: String, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedPhoneContact(let phone, let firstName, let lastName, let date):
                    if boxed {
                        buffer.appendInt32(289586518)
                    }
                    serializeString(phone, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedPhoneContact(let phone, let firstName, let lastName, let date):
                return ("savedPhoneContact", [("phone", String(describing: phone)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("date", String(describing: date))])
    }
    }
    
        public static func parse_savedPhoneContact(_ reader: BufferReader) -> SavedContact? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SavedContact.savedPhoneContact(phone: _1!, firstName: _2!, lastName: _3!, date: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
