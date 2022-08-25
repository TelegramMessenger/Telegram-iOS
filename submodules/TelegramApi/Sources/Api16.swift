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
                return ("photo", [("flags", String(describing: flags)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference)), ("date", String(describing: date)), ("sizes", String(describing: sizes)), ("videoSizes", String(describing: videoSizes)), ("dcId", String(describing: dcId))])
                case .photoEmpty(let id):
                return ("photoEmpty", [("id", String(describing: id))])
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
                return ("photoCachedSize", [("type", String(describing: type)), ("w", String(describing: w)), ("h", String(describing: h)), ("bytes", String(describing: bytes))])
                case .photoPathSize(let type, let bytes):
                return ("photoPathSize", [("type", String(describing: type)), ("bytes", String(describing: bytes))])
                case .photoSize(let type, let w, let h, let size):
                return ("photoSize", [("type", String(describing: type)), ("w", String(describing: w)), ("h", String(describing: h)), ("size", String(describing: size))])
                case .photoSizeEmpty(let type):
                return ("photoSizeEmpty", [("type", String(describing: type))])
                case .photoSizeProgressive(let type, let w, let h, let sizes):
                return ("photoSizeProgressive", [("type", String(describing: type)), ("w", String(describing: w)), ("h", String(describing: h)), ("sizes", String(describing: sizes))])
                case .photoStrippedSize(let type, let bytes):
                return ("photoStrippedSize", [("type", String(describing: type)), ("bytes", String(describing: bytes))])
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
        case poll(id: Int64, flags: Int32, question: String, answers: [Api.PollAnswer], closePeriod: Int32?, closeDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .poll(let id, let flags, let question, let answers, let closePeriod, let closeDate):
                    if boxed {
                        buffer.appendInt32(-2032041631)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(question, buffer: buffer, boxed: false)
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
                return ("poll", [("id", String(describing: id)), ("flags", String(describing: flags)), ("question", String(describing: question)), ("answers", String(describing: answers)), ("closePeriod", String(describing: closePeriod)), ("closeDate", String(describing: closeDate))])
    }
    }
    
        public static func parse_poll(_ reader: BufferReader) -> Poll? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
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
        case pollAnswer(text: String, option: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pollAnswer(let text, let option):
                    if boxed {
                        buffer.appendInt32(1823064809)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .pollAnswer(let text, let option):
                return ("pollAnswer", [("text", String(describing: text)), ("option", String(describing: option))])
    }
    }
    
        public static func parse_pollAnswer(_ reader: BufferReader) -> PollAnswer? {
            var _1: String?
            _1 = parseString(reader)
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
                return ("pollAnswerVoters", [("flags", String(describing: flags)), ("option", String(describing: option)), ("voters", String(describing: voters))])
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
        case pollResults(flags: Int32, results: [Api.PollAnswerVoters]?, totalVoters: Int32?, recentVoters: [Int64]?, solution: String?, solutionEntities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .pollResults(let flags, let results, let totalVoters, let recentVoters, let solution, let solutionEntities):
                    if boxed {
                        buffer.appendInt32(-591909213)
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
                        serializeInt64(item, buffer: buffer, boxed: false)
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
                return ("pollResults", [("flags", String(describing: flags)), ("results", String(describing: results)), ("totalVoters", String(describing: totalVoters)), ("recentVoters", String(describing: recentVoters)), ("solution", String(describing: solution)), ("solutionEntities", String(describing: solutionEntities))])
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
            var _4: [Int64]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
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
                return ("popularContact", [("clientId", String(describing: clientId)), ("importers", String(describing: importers))])
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
                return ("postAddress", [("streetLine1", String(describing: streetLine1)), ("streetLine2", String(describing: streetLine2)), ("city", String(describing: city)), ("state", String(describing: state)), ("countryIso2", String(describing: countryIso2)), ("postCode", String(describing: postCode))])
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
    enum PremiumGiftOption: TypeConstructorDescription {
        case premiumGiftOption(flags: Int32, months: Int32, currency: String, amount: Int64, botUrl: String, storeProduct: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .premiumGiftOption(let flags, let months, let currency, let amount, let botUrl, let storeProduct):
                    if boxed {
                        buffer.appendInt32(1958953753)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
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
                case .premiumGiftOption(let flags, let months, let currency, let amount, let botUrl, let storeProduct):
                return ("premiumGiftOption", [("flags", String(describing: flags)), ("months", String(describing: months)), ("currency", String(describing: currency)), ("amount", String(describing: amount)), ("botUrl", String(describing: botUrl)), ("storeProduct", String(describing: storeProduct))])
    }
    }
    
        public static func parse_premiumGiftOption(_ reader: BufferReader) -> PremiumGiftOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.PremiumGiftOption.premiumGiftOption(flags: _1!, months: _2!, currency: _3!, amount: _4!, botUrl: _5!, storeProduct: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PremiumSubscriptionOption: TypeConstructorDescription {
        case premiumSubscriptionOption(flags: Int32, months: Int32, currency: String, amount: Int64, botUrl: String, storeProduct: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .premiumSubscriptionOption(let flags, let months, let currency, let amount, let botUrl, let storeProduct):
                    if boxed {
                        buffer.appendInt32(-1225711938)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
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
                case .premiumSubscriptionOption(let flags, let months, let currency, let amount, let botUrl, let storeProduct):
                return ("premiumSubscriptionOption", [("flags", String(describing: flags)), ("months", String(describing: months)), ("currency", String(describing: currency)), ("amount", String(describing: amount)), ("botUrl", String(describing: botUrl)), ("storeProduct", String(describing: storeProduct))])
    }
    }
    
        public static func parse_premiumSubscriptionOption(_ reader: BufferReader) -> PremiumSubscriptionOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.PremiumSubscriptionOption.premiumSubscriptionOption(flags: _1!, months: _2!, currency: _3!, amount: _4!, botUrl: _5!, storeProduct: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum PrivacyKey: TypeConstructorDescription {
        case privacyKeyAddedByPhone
        case privacyKeyChatInvite
        case privacyKeyForwards
        case privacyKeyPhoneCall
        case privacyKeyPhoneNumber
        case privacyKeyPhoneP2P
        case privacyKeyProfilePhoto
        case privacyKeyStatusTimestamp
        case privacyKeyVoiceMessages
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyKeyAddedByPhone:
                    if boxed {
                        buffer.appendInt32(1124062251)
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
                case .privacyKeyAddedByPhone:
                return ("privacyKeyAddedByPhone", [])
                case .privacyKeyChatInvite:
                return ("privacyKeyChatInvite", [])
                case .privacyKeyForwards:
                return ("privacyKeyForwards", [])
                case .privacyKeyPhoneCall:
                return ("privacyKeyPhoneCall", [])
                case .privacyKeyPhoneNumber:
                return ("privacyKeyPhoneNumber", [])
                case .privacyKeyPhoneP2P:
                return ("privacyKeyPhoneP2P", [])
                case .privacyKeyProfilePhoto:
                return ("privacyKeyProfilePhoto", [])
                case .privacyKeyStatusTimestamp:
                return ("privacyKeyStatusTimestamp", [])
                case .privacyKeyVoiceMessages:
                return ("privacyKeyVoiceMessages", [])
    }
    }
    
        public static func parse_privacyKeyAddedByPhone(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyAddedByPhone
        }
        public static func parse_privacyKeyChatInvite(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyChatInvite
        }
        public static func parse_privacyKeyForwards(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyForwards
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
        public static func parse_privacyKeyStatusTimestamp(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyStatusTimestamp
        }
        public static func parse_privacyKeyVoiceMessages(_ reader: BufferReader) -> PrivacyKey? {
            return Api.PrivacyKey.privacyKeyVoiceMessages
        }
    
    }
}
public extension Api {
    enum PrivacyRule: TypeConstructorDescription {
        case privacyValueAllowAll
        case privacyValueAllowChatParticipants(chats: [Int64])
        case privacyValueAllowContacts
        case privacyValueAllowUsers(users: [Int64])
        case privacyValueDisallowAll
        case privacyValueDisallowChatParticipants(chats: [Int64])
        case privacyValueDisallowContacts
        case privacyValueDisallowUsers(users: [Int64])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyValueAllowAll:
                    if boxed {
                        buffer.appendInt32(1698855810)
                    }
                    
                    break
                case .privacyValueAllowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(1796427406)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueAllowContacts:
                    if boxed {
                        buffer.appendInt32(-123988)
                    }
                    
                    break
                case .privacyValueAllowUsers(let users):
                    if boxed {
                        buffer.appendInt32(-1198497870)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueDisallowAll:
                    if boxed {
                        buffer.appendInt32(-1955338397)
                    }
                    
                    break
                case .privacyValueDisallowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(1103656293)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueDisallowContacts:
                    if boxed {
                        buffer.appendInt32(-125240806)
                    }
                    
                    break
                case .privacyValueDisallowUsers(let users):
                    if boxed {
                        buffer.appendInt32(-463335103)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .privacyValueAllowAll:
                return ("privacyValueAllowAll", [])
                case .privacyValueAllowChatParticipants(let chats):
                return ("privacyValueAllowChatParticipants", [("chats", String(describing: chats))])
                case .privacyValueAllowContacts:
                return ("privacyValueAllowContacts", [])
                case .privacyValueAllowUsers(let users):
                return ("privacyValueAllowUsers", [("users", String(describing: users))])
                case .privacyValueDisallowAll:
                return ("privacyValueDisallowAll", [])
                case .privacyValueDisallowChatParticipants(let chats):
                return ("privacyValueDisallowChatParticipants", [("chats", String(describing: chats))])
                case .privacyValueDisallowContacts:
                return ("privacyValueDisallowContacts", [])
                case .privacyValueDisallowUsers(let users):
                return ("privacyValueDisallowUsers", [("users", String(describing: users))])
    }
    }
    
        public static func parse_privacyValueAllowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowAll
        }
        public static func parse_privacyValueAllowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueAllowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueAllowContacts(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowContacts
        }
        public static func parse_privacyValueAllowUsers(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueAllowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueDisallowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowAll
        }
        public static func parse_privacyValueDisallowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueDisallowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueDisallowContacts(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowContacts
        }
        public static func parse_privacyValueDisallowUsers(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueDisallowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
