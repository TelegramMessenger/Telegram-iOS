public extension Api {
    enum PhoneCallDiscardReason: TypeConstructorDescription {
        case phoneCallDiscardReasonAllowGroupCall(encryptedKey: Buffer)
        case phoneCallDiscardReasonBusy
        case phoneCallDiscardReasonDisconnect
        case phoneCallDiscardReasonHangup
        case phoneCallDiscardReasonMissed
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCallDiscardReasonAllowGroupCall(let encryptedKey):
                    if boxed {
                        buffer.appendInt32(-1344096199)
                    }
                    serializeBytes(encryptedKey, buffer: buffer, boxed: false)
                    break
                case .phoneCallDiscardReasonBusy:
                    if boxed {
                        buffer.appendInt32(-84416311)
                    }
                    
                    break
                case .phoneCallDiscardReasonDisconnect:
                    if boxed {
                        buffer.appendInt32(-527056480)
                    }
                    
                    break
                case .phoneCallDiscardReasonHangup:
                    if boxed {
                        buffer.appendInt32(1471006352)
                    }
                    
                    break
                case .phoneCallDiscardReasonMissed:
                    if boxed {
                        buffer.appendInt32(-2048646399)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCallDiscardReasonAllowGroupCall(let encryptedKey):
                return ("phoneCallDiscardReasonAllowGroupCall", [("encryptedKey", encryptedKey as Any)])
                case .phoneCallDiscardReasonBusy:
                return ("phoneCallDiscardReasonBusy", [])
                case .phoneCallDiscardReasonDisconnect:
                return ("phoneCallDiscardReasonDisconnect", [])
                case .phoneCallDiscardReasonHangup:
                return ("phoneCallDiscardReasonHangup", [])
                case .phoneCallDiscardReasonMissed:
                return ("phoneCallDiscardReasonMissed", [])
    }
    }
    
        public static func parse_phoneCallDiscardReasonAllowGroupCall(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.PhoneCallDiscardReason.phoneCallDiscardReasonAllowGroupCall(encryptedKey: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_phoneCallDiscardReasonBusy(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonBusy
        }
        public static func parse_phoneCallDiscardReasonDisconnect(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonDisconnect
        }
        public static func parse_phoneCallDiscardReasonHangup(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonHangup
        }
        public static func parse_phoneCallDiscardReasonMissed(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            return Api.PhoneCallDiscardReason.phoneCallDiscardReasonMissed
        }
    
    }
}
public extension Api {
    enum PhoneCallProtocol: TypeConstructorDescription {
        case phoneCallProtocol(flags: Int32, minLayer: Int32, maxLayer: Int32, libraryVersions: [String])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCallProtocol(let flags, let minLayer, let maxLayer, let libraryVersions):
                    if boxed {
                        buffer.appendInt32(-58224696)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(minLayer, buffer: buffer, boxed: false)
                    serializeInt32(maxLayer, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(libraryVersions.count))
                    for item in libraryVersions {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCallProtocol(let flags, let minLayer, let maxLayer, let libraryVersions):
                return ("phoneCallProtocol", [("flags", flags as Any), ("minLayer", minLayer as Any), ("maxLayer", maxLayer as Any), ("libraryVersions", libraryVersions as Any)])
    }
    }
    
        public static func parse_phoneCallProtocol(_ reader: BufferReader) -> PhoneCallProtocol? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [String]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PhoneCallProtocol.phoneCallProtocol(flags: _1!, minLayer: _2!, maxLayer: _3!, libraryVersions: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PhoneConnection: TypeConstructorDescription {
        case phoneConnection(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, peerTag: Buffer)
        case phoneConnectionWebrtc(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, username: String, password: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneConnection(let flags, let id, let ip, let ipv6, let port, let peerTag):
                    if boxed {
                        buffer.appendInt32(-1665063993)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(ip, buffer: buffer, boxed: false)
                    serializeString(ipv6, buffer: buffer, boxed: false)
                    serializeInt32(port, buffer: buffer, boxed: false)
                    serializeBytes(peerTag, buffer: buffer, boxed: false)
                    break
                case .phoneConnectionWebrtc(let flags, let id, let ip, let ipv6, let port, let username, let password):
                    if boxed {
                        buffer.appendInt32(1667228533)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(ip, buffer: buffer, boxed: false)
                    serializeString(ipv6, buffer: buffer, boxed: false)
                    serializeInt32(port, buffer: buffer, boxed: false)
                    serializeString(username, buffer: buffer, boxed: false)
                    serializeString(password, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneConnection(let flags, let id, let ip, let ipv6, let port, let peerTag):
                return ("phoneConnection", [("flags", flags as Any), ("id", id as Any), ("ip", ip as Any), ("ipv6", ipv6 as Any), ("port", port as Any), ("peerTag", peerTag as Any)])
                case .phoneConnectionWebrtc(let flags, let id, let ip, let ipv6, let port, let username, let password):
                return ("phoneConnectionWebrtc", [("flags", flags as Any), ("id", id as Any), ("ip", ip as Any), ("ipv6", ipv6 as Any), ("port", port as Any), ("username", username as Any), ("password", password as Any)])
    }
    }
    
        public static func parse_phoneConnection(_ reader: BufferReader) -> PhoneConnection? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Buffer?
            _6 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.PhoneConnection.phoneConnection(flags: _1!, id: _2!, ip: _3!, ipv6: _4!, port: _5!, peerTag: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_phoneConnectionWebrtc(_ reader: BufferReader) -> PhoneConnection? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            _6 = parseString(reader)
            var _7: String?
            _7 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PhoneConnection.phoneConnectionWebrtc(flags: _1!, id: _2!, ip: _3!, ipv6: _4!, port: _5!, username: _6!, password: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Photo: TypeConstructorDescription {
        case photo(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, sizes: [Api.PhotoSize], videoSizes: [Api.VideoSize]?, dcId: Int32)
        case photoEmpty(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photo(let flags, let id, let accessHash, let fileReference, let date, let sizes, let videoSizes, let dcId):
                    if boxed {
                        buffer.appendInt32(-82216347)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sizes.count))
                    for item in sizes {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(videoSizes!.count))
                    for item in videoSizes! {
                        item.serialize(buffer, true)
                    }}
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    break
                case .photoEmpty(let id):
                    if boxed {
                        buffer.appendInt32(590459437)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photo(let flags, let id, let accessHash, let fileReference, let date, let sizes, let videoSizes, let dcId):
                return ("photo", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("fileReference", fileReference as Any), ("date", date as Any), ("sizes", sizes as Any), ("videoSizes", videoSizes as Any), ("dcId", dcId as Any)])
                case .photoEmpty(let id):
                return ("photoEmpty", [("id", id as Any)])
    }
    }
    
        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.PhotoSize]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhotoSize.self)
            }
            var _7: [Api.VideoSize]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.VideoSize.self)
            } }
            var _8: Int32?
            _8 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Photo.photo(flags: _1!, id: _2!, accessHash: _3!, fileReference: _4!, date: _5!, sizes: _6!, videoSizes: _7, dcId: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_photoEmpty(_ reader: BufferReader) -> Photo? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Photo.photoEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PhotoSize: TypeConstructorDescription {
        case photoCachedSize(type: String, w: Int32, h: Int32, bytes: Buffer)
        case photoPathSize(type: String, bytes: Buffer)
        case photoSize(type: String, w: Int32, h: Int32, size: Int32)
        case photoSizeEmpty(type: String)
        case photoSizeProgressive(type: String, w: Int32, h: Int32, sizes: [Int32])
        case photoStrippedSize(type: String, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photoCachedSize(let type, let w, let h, let bytes):
                    if boxed {
                        buffer.appendInt32(35527382)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
                case .photoPathSize(let type, let bytes):
                    if boxed {
                        buffer.appendInt32(-668906175)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
                case .photoSize(let type, let w, let h, let size):
                    if boxed {
                        buffer.appendInt32(1976012384)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    break
                case .photoSizeEmpty(let type):
                    if boxed {
                        buffer.appendInt32(236446268)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    break
                case .photoSizeProgressive(let type, let w, let h, let sizes):
                    if boxed {
                        buffer.appendInt32(-96535659)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sizes.count))
                    for item in sizes {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .photoStrippedSize(let type, let bytes):
                    if boxed {
                        buffer.appendInt32(-525288402)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photoCachedSize(let type, let w, let h, let bytes):
                return ("photoCachedSize", [("type", type as Any), ("w", w as Any), ("h", h as Any), ("bytes", bytes as Any)])
                case .photoPathSize(let type, let bytes):
                return ("photoPathSize", [("type", type as Any), ("bytes", bytes as Any)])
                case .photoSize(let type, let w, let h, let size):
                return ("photoSize", [("type", type as Any), ("w", w as Any), ("h", h as Any), ("size", size as Any)])
                case .photoSizeEmpty(let type):
                return ("photoSizeEmpty", [("type", type as Any)])
                case .photoSizeProgressive(let type, let w, let h, let sizes):
                return ("photoSizeProgressive", [("type", type as Any), ("w", w as Any), ("h", h as Any), ("sizes", sizes as Any)])
                case .photoStrippedSize(let type, let bytes):
                return ("photoStrippedSize", [("type", type as Any), ("bytes", bytes as Any)])
    }
    }
    
        public static func parse_photoCachedSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PhotoSize.photoCachedSize(type: _1!, w: _2!, h: _3!, bytes: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_photoPathSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PhotoSize.photoPathSize(type: _1!, bytes: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_photoSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
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
                return Api.PhotoSize.photoSize(type: _1!, w: _2!, h: _3!, size: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_photoSizeEmpty(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.PhotoSize.photoSizeEmpty(type: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_photoSizeProgressive(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Int32]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PhotoSize.photoSizeProgressive(type: _1!, w: _2!, h: _3!, sizes: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_photoStrippedSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PhotoSize.photoStrippedSize(type: _1!, bytes: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Poll: TypeConstructorDescription {
        case poll(id: Int64, flags: Int32, question: Api.TextWithEntities, answers: [Api.PollAnswer], closePeriod: Int32?, closeDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .poll(let id, let flags, let question, let answers, let closePeriod, let closeDate):
                    if boxed {
                        buffer.appendInt32(1484026161)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    question.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(answers.count))
                    for item in answers {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(closePeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(closeDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .poll(let id, let flags, let question, let answers, let closePeriod, let closeDate):
                return ("poll", [("id", id as Any), ("flags", flags as Any), ("question", question as Any), ("answers", answers as Any), ("closePeriod", closePeriod as Any), ("closeDate", closeDate as Any)])
    }
    }
    
        public static func parse_poll(_ reader: BufferReader) -> Poll? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _4: [Api.PollAnswer]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PollAnswer.self)
            }
            var _5: Int32?
            if Int(_2!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_2!) & Int(1 << 5) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_2!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_2!) & Int(1 << 5) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Poll.poll(id: _1!, flags: _2!, question: _3!, answers: _4!, closePeriod: _5, closeDate: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PollAnswer: TypeConstructorDescription {
        case pollAnswer(text: Api.TextWithEntities, option: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pollAnswer(let text, let option):
                    if boxed {
                        buffer.appendInt32(-15277366)
                    }
                    text.serialize(buffer, true)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pollAnswer(let text, let option):
                return ("pollAnswer", [("text", text as Any), ("option", option as Any)])
    }
    }
    
        public static func parse_pollAnswer(_ reader: BufferReader) -> PollAnswer? {
            var _1: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PollAnswer.pollAnswer(text: _1!, option: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PollAnswerVoters: TypeConstructorDescription {
        case pollAnswerVoters(flags: Int32, option: Buffer, voters: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pollAnswerVoters(let flags, let option, let voters):
                    if boxed {
                        buffer.appendInt32(997055186)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    serializeInt32(voters, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pollAnswerVoters(let flags, let option, let voters):
                return ("pollAnswerVoters", [("flags", flags as Any), ("option", option as Any), ("voters", voters as Any)])
    }
    }
    
        public static func parse_pollAnswerVoters(_ reader: BufferReader) -> PollAnswerVoters? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PollAnswerVoters.pollAnswerVoters(flags: _1!, option: _2!, voters: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PollResults: TypeConstructorDescription {
        case pollResults(flags: Int32, results: [Api.PollAnswerVoters]?, totalVoters: Int32?, recentVoters: [Api.Peer]?, solution: String?, solutionEntities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pollResults(let flags, let results, let totalVoters, let recentVoters, let solution, let solutionEntities):
                    if boxed {
                        buffer.appendInt32(2061444128)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(results!.count))
                    for item in results! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(totalVoters!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentVoters!.count))
                    for item in recentVoters! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(solution!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(solutionEntities!.count))
                    for item in solutionEntities! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pollResults(let flags, let results, let totalVoters, let recentVoters, let solution, let solutionEntities):
                return ("pollResults", [("flags", flags as Any), ("results", results as Any), ("totalVoters", totalVoters as Any), ("recentVoters", recentVoters as Any), ("solution", solution as Any), ("solutionEntities", solutionEntities as Any)])
    }
    }
    
        public static func parse_pollResults(_ reader: BufferReader) -> PollResults? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PollAnswerVoters]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PollAnswerVoters.self)
            } }
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt32() }
            var _4: [Api.Peer]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            } }
            var _5: String?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = parseString(reader) }
            var _6: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.PollResults.pollResults(flags: _1!, results: _2, totalVoters: _3, recentVoters: _4, solution: _5, solutionEntities: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PopularContact: TypeConstructorDescription {
        case popularContact(clientId: Int64, importers: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .popularContact(let clientId, let importers):
                    if boxed {
                        buffer.appendInt32(1558266229)
                    }
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    serializeInt32(importers, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .popularContact(let clientId, let importers):
                return ("popularContact", [("clientId", clientId as Any), ("importers", importers as Any)])
    }
    }
    
        public static func parse_popularContact(_ reader: BufferReader) -> PopularContact? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PopularContact.popularContact(clientId: _1!, importers: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PostAddress: TypeConstructorDescription {
        case postAddress(streetLine1: String, streetLine2: String, city: String, state: String, countryIso2: String, postCode: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .postAddress(let streetLine1, let streetLine2, let city, let state, let countryIso2, let postCode):
                    if boxed {
                        buffer.appendInt32(512535275)
                    }
                    serializeString(streetLine1, buffer: buffer, boxed: false)
                    serializeString(streetLine2, buffer: buffer, boxed: false)
                    serializeString(city, buffer: buffer, boxed: false)
                    serializeString(state, buffer: buffer, boxed: false)
                    serializeString(countryIso2, buffer: buffer, boxed: false)
                    serializeString(postCode, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .postAddress(let streetLine1, let streetLine2, let city, let state, let countryIso2, let postCode):
                return ("postAddress", [("streetLine1", streetLine1 as Any), ("streetLine2", streetLine2 as Any), ("city", city as Any), ("state", state as Any), ("countryIso2", countryIso2 as Any), ("postCode", postCode as Any)])
    }
    }
    
        public static func parse_postAddress(_ reader: BufferReader) -> PostAddress? {
            var _1: String?
            _1 = parseString(reader)
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
                return Api.PostAddress.postAddress(streetLine1: _1!, streetLine2: _2!, city: _3!, state: _4!, countryIso2: _5!, postCode: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PostInteractionCounters: TypeConstructorDescription {
        case postInteractionCountersMessage(msgId: Int32, views: Int32, forwards: Int32, reactions: Int32)
        case postInteractionCountersStory(storyId: Int32, views: Int32, forwards: Int32, reactions: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .postInteractionCountersMessage(let msgId, let views, let forwards, let reactions):
                    if boxed {
                        buffer.appendInt32(-419066241)
                    }
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(views, buffer: buffer, boxed: false)
                    serializeInt32(forwards, buffer: buffer, boxed: false)
                    serializeInt32(reactions, buffer: buffer, boxed: false)
                    break
                case .postInteractionCountersStory(let storyId, let views, let forwards, let reactions):
                    if boxed {
                        buffer.appendInt32(-1974989273)
                    }
                    serializeInt32(storyId, buffer: buffer, boxed: false)
                    serializeInt32(views, buffer: buffer, boxed: false)
                    serializeInt32(forwards, buffer: buffer, boxed: false)
                    serializeInt32(reactions, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .postInteractionCountersMessage(let msgId, let views, let forwards, let reactions):
                return ("postInteractionCountersMessage", [("msgId", msgId as Any), ("views", views as Any), ("forwards", forwards as Any), ("reactions", reactions as Any)])
                case .postInteractionCountersStory(let storyId, let views, let forwards, let reactions):
                return ("postInteractionCountersStory", [("storyId", storyId as Any), ("views", views as Any), ("forwards", forwards as Any), ("reactions", reactions as Any)])
    }
    }
    
        public static func parse_postInteractionCountersMessage(_ reader: BufferReader) -> PostInteractionCounters? {
            var _1: Int32?
            _1 = reader.readInt32()
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
                return Api.PostInteractionCounters.postInteractionCountersMessage(msgId: _1!, views: _2!, forwards: _3!, reactions: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_postInteractionCountersStory(_ reader: BufferReader) -> PostInteractionCounters? {
            var _1: Int32?
            _1 = reader.readInt32()
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
                return Api.PostInteractionCounters.postInteractionCountersStory(storyId: _1!, views: _2!, forwards: _3!, reactions: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PremiumGiftCodeOption: TypeConstructorDescription {
        case premiumGiftCodeOption(flags: Int32, users: Int32, months: Int32, storeProduct: String?, storeQuantity: Int32?, currency: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .premiumGiftCodeOption(let flags, let users, let months, let storeProduct, let storeQuantity, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(629052971)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(users, buffer: buffer, boxed: false)
                    serializeInt32(months, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(storeQuantity!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .premiumGiftCodeOption(let flags, let users, let months, let storeProduct, let storeQuantity, let currency, let amount):
                return ("premiumGiftCodeOption", [("flags", flags as Any), ("users", users as Any), ("months", months as Any), ("storeProduct", storeProduct as Any), ("storeQuantity", storeQuantity as Any), ("currency", currency as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_premiumGiftCodeOption(_ reader: BufferReader) -> PremiumGiftCodeOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            var _6: String?
            _6 = parseString(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PremiumGiftCodeOption.premiumGiftCodeOption(flags: _1!, users: _2!, months: _3!, storeProduct: _4, storeQuantity: _5, currency: _6!, amount: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PremiumSubscriptionOption: TypeConstructorDescription {
        case premiumSubscriptionOption(flags: Int32, transaction: String?, months: Int32, currency: String, amount: Int64, botUrl: String, storeProduct: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .premiumSubscriptionOption(let flags, let transaction, let months, let currency, let amount, let botUrl, let storeProduct):
                    if boxed {
                        buffer.appendInt32(1596792306)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(transaction!, buffer: buffer, boxed: false)}
                    serializeInt32(months, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    serializeString(botUrl, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .premiumSubscriptionOption(let flags, let transaction, let months, let currency, let amount, let botUrl, let storeProduct):
                return ("premiumSubscriptionOption", [("flags", flags as Any), ("transaction", transaction as Any), ("months", months as Any), ("currency", currency as Any), ("amount", amount as Any), ("botUrl", botUrl as Any), ("storeProduct", storeProduct as Any)])
    }
    }
    
        public static func parse_premiumSubscriptionOption(_ reader: BufferReader) -> PremiumSubscriptionOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 3) != 0 {_2 = parseString(reader) }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: String?
            _6 = parseString(reader)
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PremiumSubscriptionOption.premiumSubscriptionOption(flags: _1!, transaction: _2, months: _3!, currency: _4!, amount: _5!, botUrl: _6!, storeProduct: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PrepaidGiveaway: TypeConstructorDescription {
        case prepaidGiveaway(id: Int64, months: Int32, quantity: Int32, date: Int32)
        case prepaidStarsGiveaway(id: Int64, stars: Int64, quantity: Int32, boosts: Int32, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .prepaidGiveaway(let id, let months, let quantity, let date):
                    if boxed {
                        buffer.appendInt32(-1303143084)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(months, buffer: buffer, boxed: false)
                    serializeInt32(quantity, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .prepaidStarsGiveaway(let id, let stars, let quantity, let boosts, let date):
                    if boxed {
                        buffer.appendInt32(-1700956192)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    serializeInt32(quantity, buffer: buffer, boxed: false)
                    serializeInt32(boosts, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .prepaidGiveaway(let id, let months, let quantity, let date):
                return ("prepaidGiveaway", [("id", id as Any), ("months", months as Any), ("quantity", quantity as Any), ("date", date as Any)])
                case .prepaidStarsGiveaway(let id, let stars, let quantity, let boosts, let date):
                return ("prepaidStarsGiveaway", [("id", id as Any), ("stars", stars as Any), ("quantity", quantity as Any), ("boosts", boosts as Any), ("date", date as Any)])
    }
    }
    
        public static func parse_prepaidGiveaway(_ reader: BufferReader) -> PrepaidGiveaway? {
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
                return Api.PrepaidGiveaway.prepaidGiveaway(id: _1!, months: _2!, quantity: _3!, date: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_prepaidStarsGiveaway(_ reader: BufferReader) -> PrepaidGiveaway? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PrepaidGiveaway.prepaidStarsGiveaway(id: _1!, stars: _2!, quantity: _3!, boosts: _4!, date: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PrivacyKey: TypeConstructorDescription {
        case privacyKeyAbout
        case privacyKeyAddedByPhone
        case privacyKeyBirthday
        case privacyKeyChatInvite
        case privacyKeyForwards
        case privacyKeyNoPaidMessages
        case privacyKeyPhoneCall
        case privacyKeyPhoneNumber
        case privacyKeyPhoneP2P
        case privacyKeyProfilePhoto
        case privacyKeyStarGiftsAutoSave
        case privacyKeyStatusTimestamp
        case privacyKeyVoiceMessages
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyKeyAbout:
                    if boxed {
                        buffer.appendInt32(-1534675103)
                    }
                    
                    break
                case .privacyKeyAddedByPhone:
                    if boxed {
                        buffer.appendInt32(1124062251)
                    }
                    
                    break
                case .privacyKeyBirthday:
                    if boxed {
                        buffer.appendInt32(536913176)
                    }
                    
                    break
                case .privacyKeyChatInvite:
                    if boxed {
                        buffer.appendInt32(1343122938)
                    }
                    
                    break
                case .privacyKeyForwards:
                    if boxed {
                        buffer.appendInt32(1777096355)
                    }
                    
                    break
                case .privacyKeyNoPaidMessages:
                    if boxed {
                        buffer.appendInt32(399722706)
                    }
                    
                    break
                case .privacyKeyPhoneCall:
                    if boxed {
                        buffer.appendInt32(1030105979)
                    }
                    
                    break
                case .privacyKeyPhoneNumber:
                    if boxed {
                        buffer.appendInt32(-778378131)
                    }
                    
                    break
                case .privacyKeyPhoneP2P:
                    if boxed {
                        buffer.appendInt32(961092808)
                    }
                    
                    break
                case .privacyKeyProfilePhoto:
                    if boxed {
                        buffer.appendInt32(-1777000467)
                    }
                    
                    break
                case .privacyKeyStarGiftsAutoSave:
                    if boxed {
                        buffer.appendInt32(749010424)
                    }
                    
                    break
                case .privacyKeyStatusTimestamp:
                    if boxed {
                        buffer.appendInt32(-1137792208)
                    }
                    
                    break
                case .privacyKeyVoiceMessages:
                    if boxed {
                        buffer.appendInt32(110621716)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .privacyKeyAbout:
                return ("privacyKeyAbout", [])
                case .privacyKeyAddedByPhone:
                return ("privacyKeyAddedByPhone", [])
                case .privacyKeyBirthday:
                return ("privacyKeyBirthday", [])
                case .privacyKeyChatInvite:
                return ("privacyKeyChatInvite", [])
                case .privacyKeyForwards:
                return ("privacyKeyForwards", [])
                case .privacyKeyNoPaidMessages:
                return ("privacyKeyNoPaidMessages", [])
                case .privacyKeyPhoneCall:
                return ("privacyKeyPhoneCall", [])
                case .privacyKeyPhoneNumber:
                return ("privacyKeyPhoneNumber", [])
                case .privacyKeyPhoneP2P:
                return ("privacyKeyPhoneP2P", [])
                case .privacyKeyProfilePhoto:
                return ("privacyKeyProfilePhoto", [])
                case .privacyKeyStarGiftsAutoSave:
                return ("privacyKeyStarGiftsAutoSave", [])
                case .privacyKeyStatusTimestamp:
                return ("privacyKeyStatusTimestamp", [])
                case .privacyKeyVoiceMessages:
                return ("privacyKeyVoiceMessages", [])
    }
    }
    
        public static func parse_privacyKeyAbout(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyAbout
        }
        public static func parse_privacyKeyAddedByPhone(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyAddedByPhone
        }
        public static func parse_privacyKeyBirthday(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyBirthday
        }
        public static func parse_privacyKeyChatInvite(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyChatInvite
        }
        public static func parse_privacyKeyForwards(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyForwards
        }
        public static func parse_privacyKeyNoPaidMessages(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyNoPaidMessages
        }
        public static func parse_privacyKeyPhoneCall(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyPhoneCall
        }
        public static func parse_privacyKeyPhoneNumber(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyPhoneNumber
        }
        public static func parse_privacyKeyPhoneP2P(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyPhoneP2P
        }
        public static func parse_privacyKeyProfilePhoto(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyProfilePhoto
        }
        public static func parse_privacyKeyStarGiftsAutoSave(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyStarGiftsAutoSave
        }
        public static func parse_privacyKeyStatusTimestamp(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyStatusTimestamp
        }
        public static func parse_privacyKeyVoiceMessages(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyVoiceMessages
        }
    
    }
}
