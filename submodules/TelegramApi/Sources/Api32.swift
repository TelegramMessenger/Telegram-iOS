public extension Api.help {
    enum AppUpdate: TypeConstructorDescription {
        case appUpdate(flags: Int32, id: Int32, version: String, text: String, entities: [Api.MessageEntity], document: Api.Document?, url: String?, sticker: Api.Document?)
        case noAppUpdate
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .appUpdate(let flags, let id, let version, let text, let entities, let document, let url, let sticker):
                    if boxed {
                        buffer.appendInt32(-860107216)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(version, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {sticker!.serialize(buffer, true)}
                    break
                case .noAppUpdate:
                    if boxed {
                        buffer.appendInt32(-1000708810)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .appUpdate(let flags, let id, let version, let text, let entities, let document, let url, let sticker):
                return ("appUpdate", [("flags", flags as Any), ("id", id as Any), ("version", version as Any), ("text", text as Any), ("entities", entities as Any), ("document", document as Any), ("url", url as Any), ("sticker", sticker as Any)])
                case .noAppUpdate:
                return ("noAppUpdate", [])
    }
    }
    
        public static func parse_appUpdate(_ reader: BufferReader) -> AppUpdate? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            var _6: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = parseString(reader) }
            var _8: Api.Document?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.help.AppUpdate.appUpdate(flags: _1!, id: _2!, version: _3!, text: _4!, entities: _5!, document: _6, url: _7, sticker: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_noAppUpdate(_ reader: BufferReader) -> AppUpdate? {
            return Api.help.AppUpdate.noAppUpdate
        }
    
    }
}
public extension Api.help {
    enum CountriesList: TypeConstructorDescription {
        case countriesList(countries: [Api.help.Country], hash: Int32)
        case countriesListNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .countriesList(let countries, let hash):
                    if boxed {
                        buffer.appendInt32(-2016381538)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(countries.count))
                    for item in countries {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    break
                case .countriesListNotModified:
                    if boxed {
                        buffer.appendInt32(-1815339214)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .countriesList(let countries, let hash):
                return ("countriesList", [("countries", countries as Any), ("hash", hash as Any)])
                case .countriesListNotModified:
                return ("countriesListNotModified", [])
    }
    }
    
        public static func parse_countriesList(_ reader: BufferReader) -> CountriesList? {
            var _1: [Api.help.Country]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.help.Country.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.CountriesList.countriesList(countries: _1!, hash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_countriesListNotModified(_ reader: BufferReader) -> CountriesList? {
            return Api.help.CountriesList.countriesListNotModified
        }
    
    }
}
public extension Api.help {
    enum Country: TypeConstructorDescription {
        case country(flags: Int32, iso2: String, defaultName: String, name: String?, countryCodes: [Api.help.CountryCode])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .country(let flags, let iso2, let defaultName, let name, let countryCodes):
                    if boxed {
                        buffer.appendInt32(-1014526429)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(iso2, buffer: buffer, boxed: false)
                    serializeString(defaultName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(name!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(countryCodes.count))
                    for item in countryCodes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .country(let flags, let iso2, let defaultName, let name, let countryCodes):
                return ("country", [("flags", flags as Any), ("iso2", iso2 as Any), ("defaultName", defaultName as Any), ("name", name as Any), ("countryCodes", countryCodes as Any)])
    }
    }
    
        public static func parse_country(_ reader: BufferReader) -> Country? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: [Api.help.CountryCode]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.help.CountryCode.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.help.Country.country(flags: _1!, iso2: _2!, defaultName: _3!, name: _4, countryCodes: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum CountryCode: TypeConstructorDescription {
        case countryCode(flags: Int32, countryCode: String, prefixes: [String]?, patterns: [String]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .countryCode(let flags, let countryCode, let prefixes, let patterns):
                    if boxed {
                        buffer.appendInt32(1107543535)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(countryCode, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prefixes!.count))
                    for item in prefixes! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(patterns!.count))
                    for item in patterns! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .countryCode(let flags, let countryCode, let prefixes, let patterns):
                return ("countryCode", [("flags", flags as Any), ("countryCode", countryCode as Any), ("prefixes", prefixes as Any), ("patterns", patterns as Any)])
    }
    }
    
        public static func parse_countryCode(_ reader: BufferReader) -> CountryCode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [String]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            var _4: [String]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.help.CountryCode.countryCode(flags: _1!, countryCode: _2!, prefixes: _3, patterns: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum DeepLinkInfo: TypeConstructorDescription {
        case deepLinkInfo(flags: Int32, message: String, entities: [Api.MessageEntity]?)
        case deepLinkInfoEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .deepLinkInfo(let flags, let message, let entities):
                    if boxed {
                        buffer.appendInt32(1783556146)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .deepLinkInfoEmpty:
                    if boxed {
                        buffer.appendInt32(1722786150)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .deepLinkInfo(let flags, let message, let entities):
                return ("deepLinkInfo", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any)])
                case .deepLinkInfoEmpty:
                return ("deepLinkInfoEmpty", [])
    }
    }
    
        public static func parse_deepLinkInfo(_ reader: BufferReader) -> DeepLinkInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.help.DeepLinkInfo.deepLinkInfo(flags: _1!, message: _2!, entities: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_deepLinkInfoEmpty(_ reader: BufferReader) -> DeepLinkInfo? {
            return Api.help.DeepLinkInfo.deepLinkInfoEmpty
        }
    
    }
}
public extension Api.help {
    enum InviteText: TypeConstructorDescription {
        case inviteText(message: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inviteText(let message):
                    if boxed {
                        buffer.appendInt32(415997816)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inviteText(let message):
                return ("inviteText", [("message", message as Any)])
    }
    }
    
        public static func parse_inviteText(_ reader: BufferReader) -> InviteText? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.InviteText.inviteText(message: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum PassportConfig: TypeConstructorDescription {
        case passportConfig(hash: Int32, countriesLangs: Api.DataJSON)
        case passportConfigNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passportConfig(let hash, let countriesLangs):
                    if boxed {
                        buffer.appendInt32(-1600596305)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    countriesLangs.serialize(buffer, true)
                    break
                case .passportConfigNotModified:
                    if boxed {
                        buffer.appendInt32(-1078332329)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passportConfig(let hash, let countriesLangs):
                return ("passportConfig", [("hash", hash as Any), ("countriesLangs", countriesLangs as Any)])
                case .passportConfigNotModified:
                return ("passportConfigNotModified", [])
    }
    }
    
        public static func parse_passportConfig(_ reader: BufferReader) -> PassportConfig? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.PassportConfig.passportConfig(hash: _1!, countriesLangs: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_passportConfigNotModified(_ reader: BufferReader) -> PassportConfig? {
            return Api.help.PassportConfig.passportConfigNotModified
        }
    
    }
}
public extension Api.help {
    enum PeerColorOption: TypeConstructorDescription {
        case peerColorOption(flags: Int32, colorId: Int32, colors: Api.help.PeerColorSet?, darkColors: Api.help.PeerColorSet?, channelMinLevel: Int32?, groupMinLevel: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerColorOption(let flags, let colorId, let colors, let darkColors, let channelMinLevel, let groupMinLevel):
                    if boxed {
                        buffer.appendInt32(-1377014082)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(colorId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {colors!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {darkColors!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(channelMinLevel!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(groupMinLevel!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerColorOption(let flags, let colorId, let colors, let darkColors, let channelMinLevel, let groupMinLevel):
                return ("peerColorOption", [("flags", flags as Any), ("colorId", colorId as Any), ("colors", colors as Any), ("darkColors", darkColors as Any), ("channelMinLevel", channelMinLevel as Any), ("groupMinLevel", groupMinLevel as Any)])
    }
    }
    
        public static func parse_peerColorOption(_ reader: BufferReader) -> PeerColorOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.help.PeerColorSet?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.help.PeerColorSet
            } }
            var _4: Api.help.PeerColorSet?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.help.PeerColorSet
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.help.PeerColorOption.peerColorOption(flags: _1!, colorId: _2!, colors: _3, darkColors: _4, channelMinLevel: _5, groupMinLevel: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum PeerColorSet: TypeConstructorDescription {
        case peerColorProfileSet(paletteColors: [Int32], bgColors: [Int32], storyColors: [Int32])
        case peerColorSet(colors: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerColorProfileSet(let paletteColors, let bgColors, let storyColors):
                    if boxed {
                        buffer.appendInt32(1987928555)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(paletteColors.count))
                    for item in paletteColors {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(bgColors.count))
                    for item in bgColors {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(storyColors.count))
                    for item in storyColors {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .peerColorSet(let colors):
                    if boxed {
                        buffer.appendInt32(639736408)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(colors.count))
                    for item in colors {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerColorProfileSet(let paletteColors, let bgColors, let storyColors):
                return ("peerColorProfileSet", [("paletteColors", paletteColors as Any), ("bgColors", bgColors as Any), ("storyColors", storyColors as Any)])
                case .peerColorSet(let colors):
                return ("peerColorSet", [("colors", colors as Any)])
    }
    }
    
        public static func parse_peerColorProfileSet(_ reader: BufferReader) -> PeerColorSet? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.help.PeerColorSet.peerColorProfileSet(paletteColors: _1!, bgColors: _2!, storyColors: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_peerColorSet(_ reader: BufferReader) -> PeerColorSet? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.PeerColorSet.peerColorSet(colors: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum PeerColors: TypeConstructorDescription {
        case peerColors(hash: Int32, colors: [Api.help.PeerColorOption])
        case peerColorsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerColors(let hash, let colors):
                    if boxed {
                        buffer.appendInt32(16313608)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(colors.count))
                    for item in colors {
                        item.serialize(buffer, true)
                    }
                    break
                case .peerColorsNotModified:
                    if boxed {
                        buffer.appendInt32(732034510)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerColors(let hash, let colors):
                return ("peerColors", [("hash", hash as Any), ("colors", colors as Any)])
                case .peerColorsNotModified:
                return ("peerColorsNotModified", [])
    }
    }
    
        public static func parse_peerColors(_ reader: BufferReader) -> PeerColors? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.help.PeerColorOption]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.help.PeerColorOption.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.PeerColors.peerColors(hash: _1!, colors: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_peerColorsNotModified(_ reader: BufferReader) -> PeerColors? {
            return Api.help.PeerColors.peerColorsNotModified
        }
    
    }
}
public extension Api.help {
    enum PremiumPromo: TypeConstructorDescription {
        case premiumPromo(statusText: String, statusEntities: [Api.MessageEntity], videoSections: [String], videos: [Api.Document], periodOptions: [Api.PremiumSubscriptionOption], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .premiumPromo(let statusText, let statusEntities, let videoSections, let videos, let periodOptions, let users):
                    if boxed {
                        buffer.appendInt32(1395946908)
                    }
                    serializeString(statusText, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(statusEntities.count))
                    for item in statusEntities {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(videoSections.count))
                    for item in videoSections {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(videos.count))
                    for item in videos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(periodOptions.count))
                    for item in periodOptions {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .premiumPromo(let statusText, let statusEntities, let videoSections, let videos, let periodOptions, let users):
                return ("premiumPromo", [("statusText", statusText as Any), ("statusEntities", statusEntities as Any), ("videoSections", videoSections as Any), ("videos", videos as Any), ("periodOptions", periodOptions as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_premiumPromo(_ reader: BufferReader) -> PremiumPromo? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            var _3: [String]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            var _4: [Api.Document]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            var _5: [Api.PremiumSubscriptionOption]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PremiumSubscriptionOption.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.help.PremiumPromo.premiumPromo(statusText: _1!, statusEntities: _2!, videoSections: _3!, videos: _4!, periodOptions: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum PromoData: TypeConstructorDescription {
        case promoData(flags: Int32, expires: Int32, peer: Api.Peer?, psaType: String?, psaMessage: String?, pendingSuggestions: [String], dismissedSuggestions: [String], customPendingSuggestion: Api.PendingSuggestion?, chats: [Api.Chat], users: [Api.User])
        case promoDataEmpty(expires: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .promoData(let flags, let expires, let peer, let psaType, let psaMessage, let pendingSuggestions, let dismissedSuggestions, let customPendingSuggestion, let chats, let users):
                    if boxed {
                        buffer.appendInt32(145021050)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {peer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(psaType!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(psaMessage!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(pendingSuggestions.count))
                    for item in pendingSuggestions {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dismissedSuggestions.count))
                    for item in dismissedSuggestions {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    if Int(flags) & Int(1 << 4) != 0 {customPendingSuggestion!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .promoDataEmpty(let expires):
                    if boxed {
                        buffer.appendInt32(-1728664459)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .promoData(let flags, let expires, let peer, let psaType, let psaMessage, let pendingSuggestions, let dismissedSuggestions, let customPendingSuggestion, let chats, let users):
                return ("promoData", [("flags", flags as Any), ("expires", expires as Any), ("peer", peer as Any), ("psaType", psaType as Any), ("psaMessage", psaMessage as Any), ("pendingSuggestions", pendingSuggestions as Any), ("dismissedSuggestions", dismissedSuggestions as Any), ("customPendingSuggestion", customPendingSuggestion as Any), ("chats", chats as Any), ("users", users as Any)])
                case .promoDataEmpty(let expires):
                return ("promoDataEmpty", [("expires", expires as Any)])
    }
    }
    
        public static func parse_promoData(_ reader: BufferReader) -> PromoData? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: [String]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            var _7: [String]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            var _8: Api.PendingSuggestion?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.PendingSuggestion
            } }
            var _9: [Api.Chat]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _10: [Api.User]?
            if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.help.PromoData.promoData(flags: _1!, expires: _2!, peer: _3, psaType: _4, psaMessage: _5, pendingSuggestions: _6!, dismissedSuggestions: _7!, customPendingSuggestion: _8, chats: _9!, users: _10!)
            }
            else {
                return nil
            }
        }
        public static func parse_promoDataEmpty(_ reader: BufferReader) -> PromoData? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.PromoData.promoDataEmpty(expires: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum RecentMeUrls: TypeConstructorDescription {
        case recentMeUrls(urls: [Api.RecentMeUrl], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .recentMeUrls(let urls, let chats, let users):
                    if boxed {
                        buffer.appendInt32(235081943)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(urls.count))
                    for item in urls {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .recentMeUrls(let urls, let chats, let users):
                return ("recentMeUrls", [("urls", urls as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_recentMeUrls(_ reader: BufferReader) -> RecentMeUrls? {
            var _1: [Api.RecentMeUrl]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RecentMeUrl.self)
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.help.RecentMeUrls.recentMeUrls(urls: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum Support: TypeConstructorDescription {
        case support(phoneNumber: String, user: Api.User)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .support(let phoneNumber, let user):
                    if boxed {
                        buffer.appendInt32(398898678)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    user.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .support(let phoneNumber, let user):
                return ("support", [("phoneNumber", phoneNumber as Any), ("user", user as Any)])
    }
    }
    
        public static func parse_support(_ reader: BufferReader) -> Support? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.Support.support(phoneNumber: _1!, user: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum SupportName: TypeConstructorDescription {
        case supportName(name: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .supportName(let name):
                    if boxed {
                        buffer.appendInt32(-1945767479)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .supportName(let name):
                return ("supportName", [("name", name as Any)])
    }
    }
    
        public static func parse_supportName(_ reader: BufferReader) -> SupportName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.SupportName.supportName(name: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum TermsOfService: TypeConstructorDescription {
        case termsOfService(flags: Int32, id: Api.DataJSON, text: String, entities: [Api.MessageEntity], minAgeConfirm: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .termsOfService(let flags, let id, let text, let entities, let minAgeConfirm):
                    if boxed {
                        buffer.appendInt32(2013922064)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    serializeString(text, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(minAgeConfirm!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .termsOfService(let flags, let id, let text, let entities, let minAgeConfirm):
                return ("termsOfService", [("flags", flags as Any), ("id", id as Any), ("text", text as Any), ("entities", entities as Any), ("minAgeConfirm", minAgeConfirm as Any)])
    }
    }
    
        public static func parse_termsOfService(_ reader: BufferReader) -> TermsOfService? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.help.TermsOfService.termsOfService(flags: _1!, id: _2!, text: _3!, entities: _4!, minAgeConfirm: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum TermsOfServiceUpdate: TypeConstructorDescription {
        case termsOfServiceUpdate(expires: Int32, termsOfService: Api.help.TermsOfService)
        case termsOfServiceUpdateEmpty(expires: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .termsOfServiceUpdate(let expires, let termsOfService):
                    if boxed {
                        buffer.appendInt32(686618977)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    termsOfService.serialize(buffer, true)
                    break
                case .termsOfServiceUpdateEmpty(let expires):
                    if boxed {
                        buffer.appendInt32(-483352705)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .termsOfServiceUpdate(let expires, let termsOfService):
                return ("termsOfServiceUpdate", [("expires", expires as Any), ("termsOfService", termsOfService as Any)])
                case .termsOfServiceUpdateEmpty(let expires):
                return ("termsOfServiceUpdateEmpty", [("expires", expires as Any)])
    }
    }
    
        public static func parse_termsOfServiceUpdate(_ reader: BufferReader) -> TermsOfServiceUpdate? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.help.TermsOfService?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.help.TermsOfService
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.TermsOfServiceUpdate.termsOfServiceUpdate(expires: _1!, termsOfService: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_termsOfServiceUpdateEmpty(_ reader: BufferReader) -> TermsOfServiceUpdate? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.TermsOfServiceUpdate.termsOfServiceUpdateEmpty(expires: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.help {
    enum TimezonesList: TypeConstructorDescription {
        case timezonesList(timezones: [Api.Timezone], hash: Int32)
        case timezonesListNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .timezonesList(let timezones, let hash):
                    if boxed {
                        buffer.appendInt32(2071260529)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(timezones.count))
                    for item in timezones {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    break
                case .timezonesListNotModified:
                    if boxed {
                        buffer.appendInt32(-1761146676)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .timezonesList(let timezones, let hash):
                return ("timezonesList", [("timezones", timezones as Any), ("hash", hash as Any)])
                case .timezonesListNotModified:
                return ("timezonesListNotModified", [])
    }
    }
    
        public static func parse_timezonesList(_ reader: BufferReader) -> TimezonesList? {
            var _1: [Api.Timezone]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Timezone.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.TimezonesList.timezonesList(timezones: _1!, hash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_timezonesListNotModified(_ reader: BufferReader) -> TimezonesList? {
            return Api.help.TimezonesList.timezonesListNotModified
        }
    
    }
}
public extension Api.help {
    enum UserInfo: TypeConstructorDescription {
        case userInfo(message: String, entities: [Api.MessageEntity], author: String, date: Int32)
        case userInfoEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userInfo(let message, let entities, let author, let date):
                    if boxed {
                        buffer.appendInt32(32192344)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    serializeString(author, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .userInfoEmpty:
                    if boxed {
                        buffer.appendInt32(-206688531)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userInfo(let message, let entities, let author, let date):
                return ("userInfo", [("message", message as Any), ("entities", entities as Any), ("author", author as Any), ("date", date as Any)])
                case .userInfoEmpty:
                return ("userInfoEmpty", [])
    }
    }
    
        public static func parse_userInfo(_ reader: BufferReader) -> UserInfo? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.help.UserInfo.userInfo(message: _1!, entities: _2!, author: _3!, date: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_userInfoEmpty(_ reader: BufferReader) -> UserInfo? {
            return Api.help.UserInfo.userInfoEmpty
        }
    
    }
}
public extension Api.messages {
    enum AffectedFoundMessages: TypeConstructorDescription {
        case affectedFoundMessages(pts: Int32, ptsCount: Int32, offset: Int32, messages: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .affectedFoundMessages(let pts, let ptsCount, let offset, let messages):
                    if boxed {
                        buffer.appendInt32(-275956116)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .affectedFoundMessages(let pts, let ptsCount, let offset, let messages):
                return ("affectedFoundMessages", [("pts", pts as Any), ("ptsCount", ptsCount as Any), ("offset", offset as Any), ("messages", messages as Any)])
    }
    }
    
        public static func parse_affectedFoundMessages(_ reader: BufferReader) -> AffectedFoundMessages? {
            var _1: Int32?
            _1 = reader.readInt32()
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
                return Api.messages.AffectedFoundMessages.affectedFoundMessages(pts: _1!, ptsCount: _2!, offset: _3!, messages: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum AffectedHistory: TypeConstructorDescription {
        case affectedHistory(pts: Int32, ptsCount: Int32, offset: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .affectedHistory(let pts, let ptsCount, let offset):
                    if boxed {
                        buffer.appendInt32(-1269012015)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .affectedHistory(let pts, let ptsCount, let offset):
                return ("affectedHistory", [("pts", pts as Any), ("ptsCount", ptsCount as Any), ("offset", offset as Any)])
    }
    }
    
        public static func parse_affectedHistory(_ reader: BufferReader) -> AffectedHistory? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.AffectedHistory.affectedHistory(pts: _1!, ptsCount: _2!, offset: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum AffectedMessages: TypeConstructorDescription {
        case affectedMessages(pts: Int32, ptsCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .affectedMessages(let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-2066640507)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .affectedMessages(let pts, let ptsCount):
                return ("affectedMessages", [("pts", pts as Any), ("ptsCount", ptsCount as Any)])
    }
    }
    
        public static func parse_affectedMessages(_ reader: BufferReader) -> AffectedMessages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.AffectedMessages.affectedMessages(pts: _1!, ptsCount: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
