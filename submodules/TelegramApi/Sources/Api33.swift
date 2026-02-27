public extension Api.help {
    enum AppUpdate: TypeConstructorDescription {
        public class Cons_appUpdate {
            public var flags: Int32
            public var id: Int32
            public var version: String
            public var text: String
            public var entities: [Api.MessageEntity]
            public var document: Api.Document?
            public var url: String?
            public var sticker: Api.Document?
            public init(flags: Int32, id: Int32, version: String, text: String, entities: [Api.MessageEntity], document: Api.Document?, url: String?, sticker: Api.Document?) {
                self.flags = flags
                self.id = id
                self.version = version
                self.text = text
                self.entities = entities
                self.document = document
                self.url = url
                self.sticker = sticker
            }
        }
        case appUpdate(Cons_appUpdate)
        case noAppUpdate

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .appUpdate(let _data):
                if boxed {
                    buffer.appendInt32(-860107216)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.version, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.entities.count))
                for item in _data.entities {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.sticker!.serialize(buffer, true)
                }
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
            case .appUpdate(let _data):
                return ("appUpdate", [("flags", _data.flags as Any), ("id", _data.id as Any), ("version", _data.version as Any), ("text", _data.text as Any), ("entities", _data.entities as Any), ("document", _data.document as Any), ("url", _data.url as Any), ("sticker", _data.sticker as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _7 = parseString(reader)
            }
            var _8: Api.Document?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.help.AppUpdate.appUpdate(Cons_appUpdate(flags: _1!, id: _2!, version: _3!, text: _4!, entities: _5!, document: _6, url: _7, sticker: _8))
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
        public class Cons_countriesList {
            public var countries: [Api.help.Country]
            public var hash: Int32
            public init(countries: [Api.help.Country], hash: Int32) {
                self.countries = countries
                self.hash = hash
            }
        }
        case countriesList(Cons_countriesList)
        case countriesListNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .countriesList(let _data):
                if boxed {
                    buffer.appendInt32(-2016381538)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.countries.count))
                for item in _data.countries {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
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
            case .countriesList(let _data):
                return ("countriesList", [("countries", _data.countries as Any), ("hash", _data.hash as Any)])
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
                return Api.help.CountriesList.countriesList(Cons_countriesList(countries: _1!, hash: _2!))
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
        public class Cons_country {
            public var flags: Int32
            public var iso2: String
            public var defaultName: String
            public var name: String?
            public var countryCodes: [Api.help.CountryCode]
            public init(flags: Int32, iso2: String, defaultName: String, name: String?, countryCodes: [Api.help.CountryCode]) {
                self.flags = flags
                self.iso2 = iso2
                self.defaultName = defaultName
                self.name = name
                self.countryCodes = countryCodes
            }
        }
        case country(Cons_country)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .country(let _data):
                if boxed {
                    buffer.appendInt32(-1014526429)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.iso2, buffer: buffer, boxed: false)
                serializeString(_data.defaultName, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.name!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.countryCodes.count))
                for item in _data.countryCodes {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .country(let _data):
                return ("country", [("flags", _data.flags as Any), ("iso2", _data.iso2 as Any), ("defaultName", _data.defaultName as Any), ("name", _data.name as Any), ("countryCodes", _data.countryCodes as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
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
                return Api.help.Country.country(Cons_country(flags: _1!, iso2: _2!, defaultName: _3!, name: _4, countryCodes: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum CountryCode: TypeConstructorDescription {
        public class Cons_countryCode {
            public var flags: Int32
            public var countryCode: String
            public var prefixes: [String]?
            public var patterns: [String]?
            public init(flags: Int32, countryCode: String, prefixes: [String]?, patterns: [String]?) {
                self.flags = flags
                self.countryCode = countryCode
                self.prefixes = prefixes
                self.patterns = patterns
            }
        }
        case countryCode(Cons_countryCode)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .countryCode(let _data):
                if boxed {
                    buffer.appendInt32(1107543535)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.countryCode, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.prefixes!.count))
                    for item in _data.prefixes! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.patterns!.count))
                    for item in _data.patterns! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .countryCode(let _data):
                return ("countryCode", [("flags", _data.flags as Any), ("countryCode", _data.countryCode as Any), ("prefixes", _data.prefixes as Any), ("patterns", _data.patterns as Any)])
            }
        }

        public static func parse_countryCode(_ reader: BufferReader) -> CountryCode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [String]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            var _4: [String]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.help.CountryCode.countryCode(Cons_countryCode(flags: _1!, countryCode: _2!, prefixes: _3, patterns: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum DeepLinkInfo: TypeConstructorDescription {
        public class Cons_deepLinkInfo {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?) {
                self.flags = flags
                self.message = message
                self.entities = entities
            }
        }
        case deepLinkInfo(Cons_deepLinkInfo)
        case deepLinkInfoEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .deepLinkInfo(let _data):
                if boxed {
                    buffer.appendInt32(1783556146)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
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
            case .deepLinkInfo(let _data):
                return ("deepLinkInfo", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.help.DeepLinkInfo.deepLinkInfo(Cons_deepLinkInfo(flags: _1!, message: _2!, entities: _3))
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
        public class Cons_inviteText {
            public var message: String
            public init(message: String) {
                self.message = message
            }
        }
        case inviteText(Cons_inviteText)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inviteText(let _data):
                if boxed {
                    buffer.appendInt32(415997816)
                }
                serializeString(_data.message, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inviteText(let _data):
                return ("inviteText", [("message", _data.message as Any)])
            }
        }

        public static func parse_inviteText(_ reader: BufferReader) -> InviteText? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.InviteText.inviteText(Cons_inviteText(message: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum PassportConfig: TypeConstructorDescription {
        public class Cons_passportConfig {
            public var hash: Int32
            public var countriesLangs: Api.DataJSON
            public init(hash: Int32, countriesLangs: Api.DataJSON) {
                self.hash = hash
                self.countriesLangs = countriesLangs
            }
        }
        case passportConfig(Cons_passportConfig)
        case passportConfigNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passportConfig(let _data):
                if boxed {
                    buffer.appendInt32(-1600596305)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                _data.countriesLangs.serialize(buffer, true)
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
            case .passportConfig(let _data):
                return ("passportConfig", [("hash", _data.hash as Any), ("countriesLangs", _data.countriesLangs as Any)])
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
                return Api.help.PassportConfig.passportConfig(Cons_passportConfig(hash: _1!, countriesLangs: _2!))
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
        public class Cons_peerColorOption {
            public var flags: Int32
            public var colorId: Int32
            public var colors: Api.help.PeerColorSet?
            public var darkColors: Api.help.PeerColorSet?
            public var channelMinLevel: Int32?
            public var groupMinLevel: Int32?
            public init(flags: Int32, colorId: Int32, colors: Api.help.PeerColorSet?, darkColors: Api.help.PeerColorSet?, channelMinLevel: Int32?, groupMinLevel: Int32?) {
                self.flags = flags
                self.colorId = colorId
                self.colors = colors
                self.darkColors = darkColors
                self.channelMinLevel = channelMinLevel
                self.groupMinLevel = groupMinLevel
            }
        }
        case peerColorOption(Cons_peerColorOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerColorOption(let _data):
                if boxed {
                    buffer.appendInt32(-1377014082)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.colorId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.colors!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.darkColors!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.channelMinLevel!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.groupMinLevel!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerColorOption(let _data):
                return ("peerColorOption", [("flags", _data.flags as Any), ("colorId", _data.colorId as Any), ("colors", _data.colors as Any), ("darkColors", _data.darkColors as Any), ("channelMinLevel", _data.channelMinLevel as Any), ("groupMinLevel", _data.groupMinLevel as Any)])
            }
        }

        public static func parse_peerColorOption(_ reader: BufferReader) -> PeerColorOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.help.PeerColorSet?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.help.PeerColorSet
                }
            }
            var _4: Api.help.PeerColorSet?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.help.PeerColorSet
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.help.PeerColorOption.peerColorOption(Cons_peerColorOption(flags: _1!, colorId: _2!, colors: _3, darkColors: _4, channelMinLevel: _5, groupMinLevel: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum PeerColorSet: TypeConstructorDescription {
        public class Cons_peerColorProfileSet {
            public var paletteColors: [Int32]
            public var bgColors: [Int32]
            public var storyColors: [Int32]
            public init(paletteColors: [Int32], bgColors: [Int32], storyColors: [Int32]) {
                self.paletteColors = paletteColors
                self.bgColors = bgColors
                self.storyColors = storyColors
            }
        }
        public class Cons_peerColorSet {
            public var colors: [Int32]
            public init(colors: [Int32]) {
                self.colors = colors
            }
        }
        case peerColorProfileSet(Cons_peerColorProfileSet)
        case peerColorSet(Cons_peerColorSet)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerColorProfileSet(let _data):
                if boxed {
                    buffer.appendInt32(1987928555)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.paletteColors.count))
                for item in _data.paletteColors {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.bgColors.count))
                for item in _data.bgColors {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.storyColors.count))
                for item in _data.storyColors {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .peerColorSet(let _data):
                if boxed {
                    buffer.appendInt32(639736408)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.colors.count))
                for item in _data.colors {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerColorProfileSet(let _data):
                return ("peerColorProfileSet", [("paletteColors", _data.paletteColors as Any), ("bgColors", _data.bgColors as Any), ("storyColors", _data.storyColors as Any)])
            case .peerColorSet(let _data):
                return ("peerColorSet", [("colors", _data.colors as Any)])
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
                return Api.help.PeerColorSet.peerColorProfileSet(Cons_peerColorProfileSet(paletteColors: _1!, bgColors: _2!, storyColors: _3!))
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
                return Api.help.PeerColorSet.peerColorSet(Cons_peerColorSet(colors: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum PeerColors: TypeConstructorDescription {
        public class Cons_peerColors {
            public var hash: Int32
            public var colors: [Api.help.PeerColorOption]
            public init(hash: Int32, colors: [Api.help.PeerColorOption]) {
                self.hash = hash
                self.colors = colors
            }
        }
        case peerColors(Cons_peerColors)
        case peerColorsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerColors(let _data):
                if boxed {
                    buffer.appendInt32(16313608)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.colors.count))
                for item in _data.colors {
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
            case .peerColors(let _data):
                return ("peerColors", [("hash", _data.hash as Any), ("colors", _data.colors as Any)])
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
                return Api.help.PeerColors.peerColors(Cons_peerColors(hash: _1!, colors: _2!))
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
        public class Cons_premiumPromo {
            public var statusText: String
            public var statusEntities: [Api.MessageEntity]
            public var videoSections: [String]
            public var videos: [Api.Document]
            public var periodOptions: [Api.PremiumSubscriptionOption]
            public var users: [Api.User]
            public init(statusText: String, statusEntities: [Api.MessageEntity], videoSections: [String], videos: [Api.Document], periodOptions: [Api.PremiumSubscriptionOption], users: [Api.User]) {
                self.statusText = statusText
                self.statusEntities = statusEntities
                self.videoSections = videoSections
                self.videos = videos
                self.periodOptions = periodOptions
                self.users = users
            }
        }
        case premiumPromo(Cons_premiumPromo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .premiumPromo(let _data):
                if boxed {
                    buffer.appendInt32(1395946908)
                }
                serializeString(_data.statusText, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.statusEntities.count))
                for item in _data.statusEntities {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.videoSections.count))
                for item in _data.videoSections {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.videos.count))
                for item in _data.videos {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.periodOptions.count))
                for item in _data.periodOptions {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .premiumPromo(let _data):
                return ("premiumPromo", [("statusText", _data.statusText as Any), ("statusEntities", _data.statusEntities as Any), ("videoSections", _data.videoSections as Any), ("videos", _data.videos as Any), ("periodOptions", _data.periodOptions as Any), ("users", _data.users as Any)])
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
                return Api.help.PremiumPromo.premiumPromo(Cons_premiumPromo(statusText: _1!, statusEntities: _2!, videoSections: _3!, videos: _4!, periodOptions: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum PromoData: TypeConstructorDescription {
        public class Cons_promoData {
            public var flags: Int32
            public var expires: Int32
            public var peer: Api.Peer?
            public var psaType: String?
            public var psaMessage: String?
            public var pendingSuggestions: [String]
            public var dismissedSuggestions: [String]
            public var customPendingSuggestion: Api.PendingSuggestion?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, expires: Int32, peer: Api.Peer?, psaType: String?, psaMessage: String?, pendingSuggestions: [String], dismissedSuggestions: [String], customPendingSuggestion: Api.PendingSuggestion?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.expires = expires
                self.peer = peer
                self.psaType = psaType
                self.psaMessage = psaMessage
                self.pendingSuggestions = pendingSuggestions
                self.dismissedSuggestions = dismissedSuggestions
                self.customPendingSuggestion = customPendingSuggestion
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_promoDataEmpty {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        case promoData(Cons_promoData)
        case promoDataEmpty(Cons_promoDataEmpty)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .promoData(let _data):
                if boxed {
                    buffer.appendInt32(145021050)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.peer!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.psaType!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.psaMessage!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.pendingSuggestions.count))
                for item in _data.pendingSuggestions {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dismissedSuggestions.count))
                for item in _data.dismissedSuggestions {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.customPendingSuggestion!.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .promoDataEmpty(let _data):
                if boxed {
                    buffer.appendInt32(-1728664459)
                }
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .promoData(let _data):
                return ("promoData", [("flags", _data.flags as Any), ("expires", _data.expires as Any), ("peer", _data.peer as Any), ("psaType", _data.psaType as Any), ("psaMessage", _data.psaMessage as Any), ("pendingSuggestions", _data.pendingSuggestions as Any), ("dismissedSuggestions", _data.dismissedSuggestions as Any), ("customPendingSuggestion", _data.customPendingSuggestion as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .promoDataEmpty(let _data):
                return ("promoDataEmpty", [("expires", _data.expires as Any)])
            }
        }

        public static func parse_promoData(_ reader: BufferReader) -> PromoData? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: [String]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            var _7: [String]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            var _8: Api.PendingSuggestion?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.PendingSuggestion
                }
            }
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
                return Api.help.PromoData.promoData(Cons_promoData(flags: _1!, expires: _2!, peer: _3, psaType: _4, psaMessage: _5, pendingSuggestions: _6!, dismissedSuggestions: _7!, customPendingSuggestion: _8, chats: _9!, users: _10!))
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
                return Api.help.PromoData.promoDataEmpty(Cons_promoDataEmpty(expires: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum RecentMeUrls: TypeConstructorDescription {
        public class Cons_recentMeUrls {
            public var urls: [Api.RecentMeUrl]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(urls: [Api.RecentMeUrl], chats: [Api.Chat], users: [Api.User]) {
                self.urls = urls
                self.chats = chats
                self.users = users
            }
        }
        case recentMeUrls(Cons_recentMeUrls)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .recentMeUrls(let _data):
                if boxed {
                    buffer.appendInt32(235081943)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.urls.count))
                for item in _data.urls {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .recentMeUrls(let _data):
                return ("recentMeUrls", [("urls", _data.urls as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
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
                return Api.help.RecentMeUrls.recentMeUrls(Cons_recentMeUrls(urls: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum Support: TypeConstructorDescription {
        public class Cons_support {
            public var phoneNumber: String
            public var user: Api.User
            public init(phoneNumber: String, user: Api.User) {
                self.phoneNumber = phoneNumber
                self.user = user
            }
        }
        case support(Cons_support)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .support(let _data):
                if boxed {
                    buffer.appendInt32(398898678)
                }
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                _data.user.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .support(let _data):
                return ("support", [("phoneNumber", _data.phoneNumber as Any), ("user", _data.user as Any)])
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
                return Api.help.Support.support(Cons_support(phoneNumber: _1!, user: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum SupportName: TypeConstructorDescription {
        public class Cons_supportName {
            public var name: String
            public init(name: String) {
                self.name = name
            }
        }
        case supportName(Cons_supportName)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .supportName(let _data):
                if boxed {
                    buffer.appendInt32(-1945767479)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .supportName(let _data):
                return ("supportName", [("name", _data.name as Any)])
            }
        }

        public static func parse_supportName(_ reader: BufferReader) -> SupportName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.SupportName.supportName(Cons_supportName(name: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum TermsOfService: TypeConstructorDescription {
        public class Cons_termsOfService {
            public var flags: Int32
            public var id: Api.DataJSON
            public var text: String
            public var entities: [Api.MessageEntity]
            public var minAgeConfirm: Int32?
            public init(flags: Int32, id: Api.DataJSON, text: String, entities: [Api.MessageEntity], minAgeConfirm: Int32?) {
                self.flags = flags
                self.id = id
                self.text = text
                self.entities = entities
                self.minAgeConfirm = minAgeConfirm
            }
        }
        case termsOfService(Cons_termsOfService)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .termsOfService(let _data):
                if boxed {
                    buffer.appendInt32(2013922064)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.id.serialize(buffer, true)
                serializeString(_data.text, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.entities.count))
                for item in _data.entities {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.minAgeConfirm!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .termsOfService(let _data):
                return ("termsOfService", [("flags", _data.flags as Any), ("id", _data.id as Any), ("text", _data.text as Any), ("entities", _data.entities as Any), ("minAgeConfirm", _data.minAgeConfirm as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.help.TermsOfService.termsOfService(Cons_termsOfService(flags: _1!, id: _2!, text: _3!, entities: _4!, minAgeConfirm: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum TermsOfServiceUpdate: TypeConstructorDescription {
        public class Cons_termsOfServiceUpdate {
            public var expires: Int32
            public var termsOfService: Api.help.TermsOfService
            public init(expires: Int32, termsOfService: Api.help.TermsOfService) {
                self.expires = expires
                self.termsOfService = termsOfService
            }
        }
        public class Cons_termsOfServiceUpdateEmpty {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        case termsOfServiceUpdate(Cons_termsOfServiceUpdate)
        case termsOfServiceUpdateEmpty(Cons_termsOfServiceUpdateEmpty)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .termsOfServiceUpdate(let _data):
                if boxed {
                    buffer.appendInt32(686618977)
                }
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                _data.termsOfService.serialize(buffer, true)
                break
            case .termsOfServiceUpdateEmpty(let _data):
                if boxed {
                    buffer.appendInt32(-483352705)
                }
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .termsOfServiceUpdate(let _data):
                return ("termsOfServiceUpdate", [("expires", _data.expires as Any), ("termsOfService", _data.termsOfService as Any)])
            case .termsOfServiceUpdateEmpty(let _data):
                return ("termsOfServiceUpdateEmpty", [("expires", _data.expires as Any)])
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
                return Api.help.TermsOfServiceUpdate.termsOfServiceUpdate(Cons_termsOfServiceUpdate(expires: _1!, termsOfService: _2!))
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
                return Api.help.TermsOfServiceUpdate.termsOfServiceUpdateEmpty(Cons_termsOfServiceUpdateEmpty(expires: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum TimezonesList: TypeConstructorDescription {
        public class Cons_timezonesList {
            public var timezones: [Api.Timezone]
            public var hash: Int32
            public init(timezones: [Api.Timezone], hash: Int32) {
                self.timezones = timezones
                self.hash = hash
            }
        }
        case timezonesList(Cons_timezonesList)
        case timezonesListNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .timezonesList(let _data):
                if boxed {
                    buffer.appendInt32(2071260529)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.timezones.count))
                for item in _data.timezones {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
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
            case .timezonesList(let _data):
                return ("timezonesList", [("timezones", _data.timezones as Any), ("hash", _data.hash as Any)])
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
                return Api.help.TimezonesList.timezonesList(Cons_timezonesList(timezones: _1!, hash: _2!))
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
        public class Cons_userInfo {
            public var message: String
            public var entities: [Api.MessageEntity]
            public var author: String
            public var date: Int32
            public init(message: String, entities: [Api.MessageEntity], author: String, date: Int32) {
                self.message = message
                self.entities = entities
                self.author = author
                self.date = date
            }
        }
        case userInfo(Cons_userInfo)
        case userInfoEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .userInfo(let _data):
                if boxed {
                    buffer.appendInt32(32192344)
                }
                serializeString(_data.message, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.entities.count))
                for item in _data.entities {
                    item.serialize(buffer, true)
                }
                serializeString(_data.author, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
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
            case .userInfo(let _data):
                return ("userInfo", [("message", _data.message as Any), ("entities", _data.entities as Any), ("author", _data.author as Any), ("date", _data.date as Any)])
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
                return Api.help.UserInfo.userInfo(Cons_userInfo(message: _1!, entities: _2!, author: _3!, date: _4!))
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
        public class Cons_affectedFoundMessages {
            public var pts: Int32
            public var ptsCount: Int32
            public var offset: Int32
            public var messages: [Int32]
            public init(pts: Int32, ptsCount: Int32, offset: Int32, messages: [Int32]) {
                self.pts = pts
                self.ptsCount = ptsCount
                self.offset = offset
                self.messages = messages
            }
        }
        case affectedFoundMessages(Cons_affectedFoundMessages)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .affectedFoundMessages(let _data):
                if boxed {
                    buffer.appendInt32(-275956116)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .affectedFoundMessages(let _data):
                return ("affectedFoundMessages", [("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any), ("offset", _data.offset as Any), ("messages", _data.messages as Any)])
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
                return Api.messages.AffectedFoundMessages.affectedFoundMessages(Cons_affectedFoundMessages(pts: _1!, ptsCount: _2!, offset: _3!, messages: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum AffectedHistory: TypeConstructorDescription {
        public class Cons_affectedHistory {
            public var pts: Int32
            public var ptsCount: Int32
            public var offset: Int32
            public init(pts: Int32, ptsCount: Int32, offset: Int32) {
                self.pts = pts
                self.ptsCount = ptsCount
                self.offset = offset
            }
        }
        case affectedHistory(Cons_affectedHistory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .affectedHistory(let _data):
                if boxed {
                    buffer.appendInt32(-1269012015)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .affectedHistory(let _data):
                return ("affectedHistory", [("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any), ("offset", _data.offset as Any)])
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
                return Api.messages.AffectedHistory.affectedHistory(Cons_affectedHistory(pts: _1!, ptsCount: _2!, offset: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum AffectedMessages: TypeConstructorDescription {
        public class Cons_affectedMessages {
            public var pts: Int32
            public var ptsCount: Int32
            public init(pts: Int32, ptsCount: Int32) {
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        case affectedMessages(Cons_affectedMessages)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .affectedMessages(let _data):
                if boxed {
                    buffer.appendInt32(-2066640507)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .affectedMessages(let _data):
                return ("affectedMessages", [("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
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
                return Api.messages.AffectedMessages.affectedMessages(Cons_affectedMessages(pts: _1!, ptsCount: _2!))
            }
            else {
                return nil
            }
        }
    }
}
