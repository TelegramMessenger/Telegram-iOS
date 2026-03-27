public extension Api {
    enum KeyboardButtonRow: TypeConstructorDescription {
        public class Cons_keyboardButtonRow: TypeConstructorDescription {
            public var buttons: [Api.KeyboardButton]
            public init(buttons: [Api.KeyboardButton]) {
                self.buttons = buttons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("keyboardButtonRow", [("buttons", ConstructorParameterDescription(self.buttons))])
            }
        }
        case keyboardButtonRow(Cons_keyboardButtonRow)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .keyboardButtonRow(let _data):
                if boxed {
                    buffer.appendInt32(2002815875)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.buttons.count))
                for item in _data.buttons {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .keyboardButtonRow(let _data):
                return ("keyboardButtonRow", [("buttons", ConstructorParameterDescription(_data.buttons))])
            }
        }

        public static func parse_keyboardButtonRow(_ reader: BufferReader) -> KeyboardButtonRow? {
            var _1: [Api.KeyboardButton]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButton.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButtonRow.keyboardButtonRow(Cons_keyboardButtonRow(buttons: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum KeyboardButtonStyle: TypeConstructorDescription {
        public class Cons_keyboardButtonStyle: TypeConstructorDescription {
            public var flags: Int32
            public var icon: Int64?
            public init(flags: Int32, icon: Int64?) {
                self.flags = flags
                self.icon = icon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("keyboardButtonStyle", [("flags", ConstructorParameterDescription(self.flags)), ("icon", ConstructorParameterDescription(self.icon))])
            }
        }
        case keyboardButtonStyle(Cons_keyboardButtonStyle)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .keyboardButtonStyle(let _data):
                if boxed {
                    buffer.appendInt32(1339896880)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt64(_data.icon!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .keyboardButtonStyle(let _data):
                return ("keyboardButtonStyle", [("flags", ConstructorParameterDescription(_data.flags)), ("icon", ConstructorParameterDescription(_data.icon))])
            }
        }

        public static func parse_keyboardButtonStyle(_ reader: BufferReader) -> KeyboardButtonStyle? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {
                _2 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButtonStyle.keyboardButtonStyle(Cons_keyboardButtonStyle(flags: _1!, icon: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LabeledPrice: TypeConstructorDescription {
        public class Cons_labeledPrice: TypeConstructorDescription {
            public var label: String
            public var amount: Int64
            public init(label: String, amount: Int64) {
                self.label = label
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("labeledPrice", [("label", ConstructorParameterDescription(self.label)), ("amount", ConstructorParameterDescription(self.amount))])
            }
        }
        case labeledPrice(Cons_labeledPrice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .labeledPrice(let _data):
                if boxed {
                    buffer.appendInt32(-886477832)
                }
                serializeString(_data.label, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .labeledPrice(let _data):
                return ("labeledPrice", [("label", ConstructorParameterDescription(_data.label)), ("amount", ConstructorParameterDescription(_data.amount))])
            }
        }

        public static func parse_labeledPrice(_ reader: BufferReader) -> LabeledPrice? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.LabeledPrice.labeledPrice(Cons_labeledPrice(label: _1!, amount: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LangPackDifference: TypeConstructorDescription {
        public class Cons_langPackDifference: TypeConstructorDescription {
            public var langCode: String
            public var fromVersion: Int32
            public var version: Int32
            public var strings: [Api.LangPackString]
            public init(langCode: String, fromVersion: Int32, version: Int32, strings: [Api.LangPackString]) {
                self.langCode = langCode
                self.fromVersion = fromVersion
                self.version = version
                self.strings = strings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackDifference", [("langCode", ConstructorParameterDescription(self.langCode)), ("fromVersion", ConstructorParameterDescription(self.fromVersion)), ("version", ConstructorParameterDescription(self.version)), ("strings", ConstructorParameterDescription(self.strings))])
            }
        }
        case langPackDifference(Cons_langPackDifference)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .langPackDifference(let _data):
                if boxed {
                    buffer.appendInt32(-209337866)
                }
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                serializeInt32(_data.fromVersion, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.strings.count))
                for item in _data.strings {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .langPackDifference(let _data):
                return ("langPackDifference", [("langCode", ConstructorParameterDescription(_data.langCode)), ("fromVersion", ConstructorParameterDescription(_data.fromVersion)), ("version", ConstructorParameterDescription(_data.version)), ("strings", ConstructorParameterDescription(_data.strings))])
            }
        }

        public static func parse_langPackDifference(_ reader: BufferReader) -> LangPackDifference? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.LangPackString]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackString.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.LangPackDifference.langPackDifference(Cons_langPackDifference(langCode: _1!, fromVersion: _2!, version: _3!, strings: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LangPackLanguage: TypeConstructorDescription {
        public class Cons_langPackLanguage: TypeConstructorDescription {
            public var flags: Int32
            public var name: String
            public var nativeName: String
            public var langCode: String
            public var baseLangCode: String?
            public var pluralCode: String
            public var stringsCount: Int32
            public var translatedCount: Int32
            public var translationsUrl: String
            public init(flags: Int32, name: String, nativeName: String, langCode: String, baseLangCode: String?, pluralCode: String, stringsCount: Int32, translatedCount: Int32, translationsUrl: String) {
                self.flags = flags
                self.name = name
                self.nativeName = nativeName
                self.langCode = langCode
                self.baseLangCode = baseLangCode
                self.pluralCode = pluralCode
                self.stringsCount = stringsCount
                self.translatedCount = translatedCount
                self.translationsUrl = translationsUrl
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackLanguage", [("flags", ConstructorParameterDescription(self.flags)), ("name", ConstructorParameterDescription(self.name)), ("nativeName", ConstructorParameterDescription(self.nativeName)), ("langCode", ConstructorParameterDescription(self.langCode)), ("baseLangCode", ConstructorParameterDescription(self.baseLangCode)), ("pluralCode", ConstructorParameterDescription(self.pluralCode)), ("stringsCount", ConstructorParameterDescription(self.stringsCount)), ("translatedCount", ConstructorParameterDescription(self.translatedCount)), ("translationsUrl", ConstructorParameterDescription(self.translationsUrl))])
            }
        }
        case langPackLanguage(Cons_langPackLanguage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .langPackLanguage(let _data):
                if boxed {
                    buffer.appendInt32(-288727837)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeString(_data.nativeName, buffer: buffer, boxed: false)
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.baseLangCode!, buffer: buffer, boxed: false)
                }
                serializeString(_data.pluralCode, buffer: buffer, boxed: false)
                serializeInt32(_data.stringsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.translatedCount, buffer: buffer, boxed: false)
                serializeString(_data.translationsUrl, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .langPackLanguage(let _data):
                return ("langPackLanguage", [("flags", ConstructorParameterDescription(_data.flags)), ("name", ConstructorParameterDescription(_data.name)), ("nativeName", ConstructorParameterDescription(_data.nativeName)), ("langCode", ConstructorParameterDescription(_data.langCode)), ("baseLangCode", ConstructorParameterDescription(_data.baseLangCode)), ("pluralCode", ConstructorParameterDescription(_data.pluralCode)), ("stringsCount", ConstructorParameterDescription(_data.stringsCount)), ("translatedCount", ConstructorParameterDescription(_data.translatedCount)), ("translationsUrl", ConstructorParameterDescription(_data.translationsUrl))])
            }
        }

        public static func parse_langPackLanguage(_ reader: BufferReader) -> LangPackLanguage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            _6 = parseString(reader)
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.LangPackLanguage.langPackLanguage(Cons_langPackLanguage(flags: _1!, name: _2!, nativeName: _3!, langCode: _4!, baseLangCode: _5, pluralCode: _6!, stringsCount: _7!, translatedCount: _8!, translationsUrl: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LangPackString: TypeConstructorDescription {
        public class Cons_langPackString: TypeConstructorDescription {
            public var key: String
            public var value: String
            public init(key: String, value: String) {
                self.key = key
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackString", [("key", ConstructorParameterDescription(self.key)), ("value", ConstructorParameterDescription(self.value))])
            }
        }
        public class Cons_langPackStringDeleted: TypeConstructorDescription {
            public var key: String
            public init(key: String) {
                self.key = key
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackStringDeleted", [("key", ConstructorParameterDescription(self.key))])
            }
        }
        public class Cons_langPackStringPluralized: TypeConstructorDescription {
            public var flags: Int32
            public var key: String
            public var zeroValue: String?
            public var oneValue: String?
            public var twoValue: String?
            public var fewValue: String?
            public var manyValue: String?
            public var otherValue: String
            public init(flags: Int32, key: String, zeroValue: String?, oneValue: String?, twoValue: String?, fewValue: String?, manyValue: String?, otherValue: String) {
                self.flags = flags
                self.key = key
                self.zeroValue = zeroValue
                self.oneValue = oneValue
                self.twoValue = twoValue
                self.fewValue = fewValue
                self.manyValue = manyValue
                self.otherValue = otherValue
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackStringPluralized", [("flags", ConstructorParameterDescription(self.flags)), ("key", ConstructorParameterDescription(self.key)), ("zeroValue", ConstructorParameterDescription(self.zeroValue)), ("oneValue", ConstructorParameterDescription(self.oneValue)), ("twoValue", ConstructorParameterDescription(self.twoValue)), ("fewValue", ConstructorParameterDescription(self.fewValue)), ("manyValue", ConstructorParameterDescription(self.manyValue)), ("otherValue", ConstructorParameterDescription(self.otherValue))])
            }
        }
        case langPackString(Cons_langPackString)
        case langPackStringDeleted(Cons_langPackStringDeleted)
        case langPackStringPluralized(Cons_langPackStringPluralized)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .langPackString(let _data):
                if boxed {
                    buffer.appendInt32(-892239370)
                }
                serializeString(_data.key, buffer: buffer, boxed: false)
                serializeString(_data.value, buffer: buffer, boxed: false)
                break
            case .langPackStringDeleted(let _data):
                if boxed {
                    buffer.appendInt32(695856818)
                }
                serializeString(_data.key, buffer: buffer, boxed: false)
                break
            case .langPackStringPluralized(let _data):
                if boxed {
                    buffer.appendInt32(1816636575)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.key, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.zeroValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.oneValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.twoValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.fewValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.manyValue!, buffer: buffer, boxed: false)
                }
                serializeString(_data.otherValue, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .langPackString(let _data):
                return ("langPackString", [("key", ConstructorParameterDescription(_data.key)), ("value", ConstructorParameterDescription(_data.value))])
            case .langPackStringDeleted(let _data):
                return ("langPackStringDeleted", [("key", ConstructorParameterDescription(_data.key))])
            case .langPackStringPluralized(let _data):
                return ("langPackStringPluralized", [("flags", ConstructorParameterDescription(_data.flags)), ("key", ConstructorParameterDescription(_data.key)), ("zeroValue", ConstructorParameterDescription(_data.zeroValue)), ("oneValue", ConstructorParameterDescription(_data.oneValue)), ("twoValue", ConstructorParameterDescription(_data.twoValue)), ("fewValue", ConstructorParameterDescription(_data.fewValue)), ("manyValue", ConstructorParameterDescription(_data.manyValue)), ("otherValue", ConstructorParameterDescription(_data.otherValue))])
            }
        }

        public static func parse_langPackString(_ reader: BufferReader) -> LangPackString? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.LangPackString.langPackString(Cons_langPackString(key: _1!, value: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_langPackStringDeleted(_ reader: BufferReader) -> LangPackString? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.LangPackString.langPackStringDeleted(Cons_langPackStringDeleted(key: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_langPackStringPluralized(_ reader: BufferReader) -> LangPackString? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {
                _7 = parseString(reader)
            }
            var _8: String?
            _8 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.LangPackString.langPackStringPluralized(Cons_langPackStringPluralized(flags: _1!, key: _2!, zeroValue: _3, oneValue: _4, twoValue: _5, fewValue: _6, manyValue: _7, otherValue: _8!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MaskCoords: TypeConstructorDescription {
        public class Cons_maskCoords: TypeConstructorDescription {
            public var n: Int32
            public var x: Double
            public var y: Double
            public var zoom: Double
            public init(n: Int32, x: Double, y: Double, zoom: Double) {
                self.n = n
                self.x = x
                self.y = y
                self.zoom = zoom
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("maskCoords", [("n", ConstructorParameterDescription(self.n)), ("x", ConstructorParameterDescription(self.x)), ("y", ConstructorParameterDescription(self.y)), ("zoom", ConstructorParameterDescription(self.zoom))])
            }
        }
        case maskCoords(Cons_maskCoords)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .maskCoords(let _data):
                if boxed {
                    buffer.appendInt32(-1361650766)
                }
                serializeInt32(_data.n, buffer: buffer, boxed: false)
                serializeDouble(_data.x, buffer: buffer, boxed: false)
                serializeDouble(_data.y, buffer: buffer, boxed: false)
                serializeDouble(_data.zoom, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .maskCoords(let _data):
                return ("maskCoords", [("n", ConstructorParameterDescription(_data.n)), ("x", ConstructorParameterDescription(_data.x)), ("y", ConstructorParameterDescription(_data.y)), ("zoom", ConstructorParameterDescription(_data.zoom))])
            }
        }

        public static func parse_maskCoords(_ reader: BufferReader) -> MaskCoords? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Double?
            _4 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MaskCoords.maskCoords(Cons_maskCoords(n: _1!, x: _2!, y: _3!, zoom: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum MediaArea: TypeConstructorDescription {
        public class Cons_inputMediaAreaChannelPost: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var channel: Api.InputChannel
            public var msgId: Int32
            public init(coordinates: Api.MediaAreaCoordinates, channel: Api.InputChannel, msgId: Int32) {
                self.coordinates = coordinates
                self.channel = channel
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("channel", ConstructorParameterDescription(self.channel)), ("msgId", ConstructorParameterDescription(self.msgId))])
            }
        }
        public class Cons_inputMediaAreaVenue: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var queryId: Int64
            public var resultId: String
            public init(coordinates: Api.MediaAreaCoordinates, queryId: Int64, resultId: String) {
                self.coordinates = coordinates
                self.queryId = queryId
                self.resultId = resultId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaAreaVenue", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("queryId", ConstructorParameterDescription(self.queryId)), ("resultId", ConstructorParameterDescription(self.resultId))])
            }
        }
        public class Cons_mediaAreaChannelPost: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var channelId: Int64
            public var msgId: Int32
            public init(coordinates: Api.MediaAreaCoordinates, channelId: Int64, msgId: Int32) {
                self.coordinates = coordinates
                self.channelId = channelId
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("channelId", ConstructorParameterDescription(self.channelId)), ("msgId", ConstructorParameterDescription(self.msgId))])
            }
        }
        public class Cons_mediaAreaGeoPoint: TypeConstructorDescription {
            public var flags: Int32
            public var coordinates: Api.MediaAreaCoordinates
            public var geo: Api.GeoPoint
            public var address: Api.GeoPointAddress?
            public init(flags: Int32, coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, address: Api.GeoPointAddress?) {
                self.flags = flags
                self.coordinates = coordinates
                self.geo = geo
                self.address = address
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaGeoPoint", [("flags", ConstructorParameterDescription(self.flags)), ("coordinates", ConstructorParameterDescription(self.coordinates)), ("geo", ConstructorParameterDescription(self.geo)), ("address", ConstructorParameterDescription(self.address))])
            }
        }
        public class Cons_mediaAreaStarGift: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var slug: String
            public init(coordinates: Api.MediaAreaCoordinates, slug: String) {
                self.coordinates = coordinates
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaStarGift", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        public class Cons_mediaAreaSuggestedReaction: TypeConstructorDescription {
            public var flags: Int32
            public var coordinates: Api.MediaAreaCoordinates
            public var reaction: Api.Reaction
            public init(flags: Int32, coordinates: Api.MediaAreaCoordinates, reaction: Api.Reaction) {
                self.flags = flags
                self.coordinates = coordinates
                self.reaction = reaction
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaSuggestedReaction", [("flags", ConstructorParameterDescription(self.flags)), ("coordinates", ConstructorParameterDescription(self.coordinates)), ("reaction", ConstructorParameterDescription(self.reaction))])
            }
        }
        public class Cons_mediaAreaUrl: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var url: String
            public init(coordinates: Api.MediaAreaCoordinates, url: String) {
                self.coordinates = coordinates
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaUrl", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        public class Cons_mediaAreaVenue: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var geo: Api.GeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public init(coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
                self.coordinates = coordinates
                self.geo = geo
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaVenue", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("geo", ConstructorParameterDescription(self.geo)), ("title", ConstructorParameterDescription(self.title)), ("address", ConstructorParameterDescription(self.address)), ("provider", ConstructorParameterDescription(self.provider)), ("venueId", ConstructorParameterDescription(self.venueId)), ("venueType", ConstructorParameterDescription(self.venueType))])
            }
        }
        public class Cons_mediaAreaWeather: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var emoji: String
            public var temperatureC: Double
            public var color: Int32
            public init(coordinates: Api.MediaAreaCoordinates, emoji: String, temperatureC: Double, color: Int32) {
                self.coordinates = coordinates
                self.emoji = emoji
                self.temperatureC = temperatureC
                self.color = color
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaWeather", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("emoji", ConstructorParameterDescription(self.emoji)), ("temperatureC", ConstructorParameterDescription(self.temperatureC)), ("color", ConstructorParameterDescription(self.color))])
            }
        }
        case inputMediaAreaChannelPost(Cons_inputMediaAreaChannelPost)
        case inputMediaAreaVenue(Cons_inputMediaAreaVenue)
        case mediaAreaChannelPost(Cons_mediaAreaChannelPost)
        case mediaAreaGeoPoint(Cons_mediaAreaGeoPoint)
        case mediaAreaStarGift(Cons_mediaAreaStarGift)
        case mediaAreaSuggestedReaction(Cons_mediaAreaSuggestedReaction)
        case mediaAreaUrl(Cons_mediaAreaUrl)
        case mediaAreaVenue(Cons_mediaAreaVenue)
        case mediaAreaWeather(Cons_mediaAreaWeather)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMediaAreaChannelPost(let _data):
                if boxed {
                    buffer.appendInt32(577893055)
                }
                _data.coordinates.serialize(buffer, true)
                _data.channel.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            case .inputMediaAreaVenue(let _data):
                if boxed {
                    buffer.appendInt32(-1300094593)
                }
                _data.coordinates.serialize(buffer, true)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeString(_data.resultId, buffer: buffer, boxed: false)
                break
            case .mediaAreaChannelPost(let _data):
                if boxed {
                    buffer.appendInt32(1996756655)
                }
                _data.coordinates.serialize(buffer, true)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            case .mediaAreaGeoPoint(let _data):
                if boxed {
                    buffer.appendInt32(-891992787)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.coordinates.serialize(buffer, true)
                _data.geo.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.address!.serialize(buffer, true)
                }
                break
            case .mediaAreaStarGift(let _data):
                if boxed {
                    buffer.appendInt32(1468491885)
                }
                _data.coordinates.serialize(buffer, true)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            case .mediaAreaSuggestedReaction(let _data):
                if boxed {
                    buffer.appendInt32(340088945)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.coordinates.serialize(buffer, true)
                _data.reaction.serialize(buffer, true)
                break
            case .mediaAreaUrl(let _data):
                if boxed {
                    buffer.appendInt32(926421125)
                }
                _data.coordinates.serialize(buffer, true)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .mediaAreaVenue(let _data):
                if boxed {
                    buffer.appendInt32(-1098720356)
                }
                _data.coordinates.serialize(buffer, true)
                _data.geo.serialize(buffer, true)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeString(_data.provider, buffer: buffer, boxed: false)
                serializeString(_data.venueId, buffer: buffer, boxed: false)
                serializeString(_data.venueType, buffer: buffer, boxed: false)
                break
            case .mediaAreaWeather(let _data):
                if boxed {
                    buffer.appendInt32(1235637404)
                }
                _data.coordinates.serialize(buffer, true)
                serializeString(_data.emoji, buffer: buffer, boxed: false)
                serializeDouble(_data.temperatureC, buffer: buffer, boxed: false)
                serializeInt32(_data.color, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMediaAreaChannelPost(let _data):
                return ("inputMediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("channel", ConstructorParameterDescription(_data.channel)), ("msgId", ConstructorParameterDescription(_data.msgId))])
            case .inputMediaAreaVenue(let _data):
                return ("inputMediaAreaVenue", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("queryId", ConstructorParameterDescription(_data.queryId)), ("resultId", ConstructorParameterDescription(_data.resultId))])
            case .mediaAreaChannelPost(let _data):
                return ("mediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("channelId", ConstructorParameterDescription(_data.channelId)), ("msgId", ConstructorParameterDescription(_data.msgId))])
            case .mediaAreaGeoPoint(let _data):
                return ("mediaAreaGeoPoint", [("flags", ConstructorParameterDescription(_data.flags)), ("coordinates", ConstructorParameterDescription(_data.coordinates)), ("geo", ConstructorParameterDescription(_data.geo)), ("address", ConstructorParameterDescription(_data.address))])
            case .mediaAreaStarGift(let _data):
                return ("mediaAreaStarGift", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("slug", ConstructorParameterDescription(_data.slug))])
            case .mediaAreaSuggestedReaction(let _data):
                return ("mediaAreaSuggestedReaction", [("flags", ConstructorParameterDescription(_data.flags)), ("coordinates", ConstructorParameterDescription(_data.coordinates)), ("reaction", ConstructorParameterDescription(_data.reaction))])
            case .mediaAreaUrl(let _data):
                return ("mediaAreaUrl", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("url", ConstructorParameterDescription(_data.url))])
            case .mediaAreaVenue(let _data):
                return ("mediaAreaVenue", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("geo", ConstructorParameterDescription(_data.geo)), ("title", ConstructorParameterDescription(_data.title)), ("address", ConstructorParameterDescription(_data.address)), ("provider", ConstructorParameterDescription(_data.provider)), ("venueId", ConstructorParameterDescription(_data.venueId)), ("venueType", ConstructorParameterDescription(_data.venueType))])
            case .mediaAreaWeather(let _data):
                return ("mediaAreaWeather", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("emoji", ConstructorParameterDescription(_data.emoji)), ("temperatureC", ConstructorParameterDescription(_data.temperatureC)), ("color", ConstructorParameterDescription(_data.color))])
            }
        }

        public static func parse_inputMediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Api.InputChannel?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputChannel
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.inputMediaAreaChannelPost(Cons_inputMediaAreaChannelPost(coordinates: _1!, channel: _2!, msgId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.inputMediaAreaVenue(Cons_inputMediaAreaVenue(coordinates: _1!, queryId: _2!, resultId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.mediaAreaChannelPost(Cons_mediaAreaChannelPost(coordinates: _1!, channelId: _2!, msgId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaGeoPoint(_ reader: BufferReader) -> MediaArea? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _3: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _4: Api.GeoPointAddress?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.GeoPointAddress
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MediaArea.mediaAreaGeoPoint(Cons_mediaAreaGeoPoint(flags: _1!, coordinates: _2!, geo: _3!, address: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaStarGift(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MediaArea.mediaAreaStarGift(Cons_mediaAreaStarGift(coordinates: _1!, slug: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaSuggestedReaction(_ reader: BufferReader) -> MediaArea? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.mediaAreaSuggestedReaction(Cons_mediaAreaSuggestedReaction(flags: _1!, coordinates: _2!, reaction: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaUrl(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MediaArea.mediaAreaUrl(Cons_mediaAreaUrl(coordinates: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
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
                return Api.MediaArea.mediaAreaVenue(Cons_mediaAreaVenue(coordinates: _1!, geo: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaWeather(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MediaArea.mediaAreaWeather(Cons_mediaAreaWeather(coordinates: _1!, emoji: _2!, temperatureC: _3!, color: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MediaAreaCoordinates: TypeConstructorDescription {
        public class Cons_mediaAreaCoordinates: TypeConstructorDescription {
            public var flags: Int32
            public var x: Double
            public var y: Double
            public var w: Double
            public var h: Double
            public var rotation: Double
            public var radius: Double?
            public init(flags: Int32, x: Double, y: Double, w: Double, h: Double, rotation: Double, radius: Double?) {
                self.flags = flags
                self.x = x
                self.y = y
                self.w = w
                self.h = h
                self.rotation = rotation
                self.radius = radius
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaCoordinates", [("flags", ConstructorParameterDescription(self.flags)), ("x", ConstructorParameterDescription(self.x)), ("y", ConstructorParameterDescription(self.y)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("rotation", ConstructorParameterDescription(self.rotation)), ("radius", ConstructorParameterDescription(self.radius))])
            }
        }
        case mediaAreaCoordinates(Cons_mediaAreaCoordinates)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .mediaAreaCoordinates(let _data):
                if boxed {
                    buffer.appendInt32(-808853502)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeDouble(_data.x, buffer: buffer, boxed: false)
                serializeDouble(_data.y, buffer: buffer, boxed: false)
                serializeDouble(_data.w, buffer: buffer, boxed: false)
                serializeDouble(_data.h, buffer: buffer, boxed: false)
                serializeDouble(_data.rotation, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeDouble(_data.radius!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .mediaAreaCoordinates(let _data):
                return ("mediaAreaCoordinates", [("flags", ConstructorParameterDescription(_data.flags)), ("x", ConstructorParameterDescription(_data.x)), ("y", ConstructorParameterDescription(_data.y)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("rotation", ConstructorParameterDescription(_data.rotation)), ("radius", ConstructorParameterDescription(_data.radius))])
            }
        }

        public static func parse_mediaAreaCoordinates(_ reader: BufferReader) -> MediaAreaCoordinates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Double?
            _4 = reader.readDouble()
            var _5: Double?
            _5 = reader.readDouble()
            var _6: Double?
            _6 = reader.readDouble()
            var _7: Double?
            if Int(_1!) & Int(1 << 0) != 0 {
                _7 = reader.readDouble()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MediaAreaCoordinates.mediaAreaCoordinates(Cons_mediaAreaCoordinates(flags: _1!, x: _2!, y: _3!, w: _4!, h: _5!, rotation: _6!, radius: _7))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum Message: TypeConstructorDescription {
        public class Cons_message: TypeConstructorDescription {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int32
            public var fromId: Api.Peer?
            public var fromBoostsApplied: Int32?
            public var fromRank: String?
            public var peerId: Api.Peer
            public var savedPeerId: Api.Peer?
            public var fwdFrom: Api.MessageFwdHeader?
            public var viaBotId: Int64?
            public var viaBusinessBotId: Int64?
            public var replyTo: Api.MessageReplyHeader?
            public var date: Int32
            public var message: String
            public var media: Api.MessageMedia?
            public var replyMarkup: Api.ReplyMarkup?
            public var entities: [Api.MessageEntity]?
            public var views: Int32?
            public var forwards: Int32?
            public var replies: Api.MessageReplies?
            public var editDate: Int32?
            public var postAuthor: String?
            public var groupedId: Int64?
            public var reactions: Api.MessageReactions?
            public var restrictionReason: [Api.RestrictionReason]?
            public var ttlPeriod: Int32?
            public var quickReplyShortcutId: Int32?
            public var effect: Int64?
            public var factcheck: Api.FactCheck?
            public var reportDeliveryUntilDate: Int32?
            public var paidMessageStars: Int64?
            public var suggestedPost: Api.SuggestedPost?
            public var scheduleRepeatPeriod: Int32?
            public var summaryFromLanguage: String?
            public init(flags: Int32, flags2: Int32, id: Int32, fromId: Api.Peer?, fromBoostsApplied: Int32?, fromRank: String?, peerId: Api.Peer, savedPeerId: Api.Peer?, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, viaBusinessBotId: Int64?, replyTo: Api.MessageReplyHeader?, date: Int32, message: String, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?, editDate: Int32?, postAuthor: String?, groupedId: Int64?, reactions: Api.MessageReactions?, restrictionReason: [Api.RestrictionReason]?, ttlPeriod: Int32?, quickReplyShortcutId: Int32?, effect: Int64?, factcheck: Api.FactCheck?, reportDeliveryUntilDate: Int32?, paidMessageStars: Int64?, suggestedPost: Api.SuggestedPost?, scheduleRepeatPeriod: Int32?, summaryFromLanguage: String?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.fromId = fromId
                self.fromBoostsApplied = fromBoostsApplied
                self.fromRank = fromRank
                self.peerId = peerId
                self.savedPeerId = savedPeerId
                self.fwdFrom = fwdFrom
                self.viaBotId = viaBotId
                self.viaBusinessBotId = viaBusinessBotId
                self.replyTo = replyTo
                self.date = date
                self.message = message
                self.media = media
                self.replyMarkup = replyMarkup
                self.entities = entities
                self.views = views
                self.forwards = forwards
                self.replies = replies
                self.editDate = editDate
                self.postAuthor = postAuthor
                self.groupedId = groupedId
                self.reactions = reactions
                self.restrictionReason = restrictionReason
                self.ttlPeriod = ttlPeriod
                self.quickReplyShortcutId = quickReplyShortcutId
                self.effect = effect
                self.factcheck = factcheck
                self.reportDeliveryUntilDate = reportDeliveryUntilDate
                self.paidMessageStars = paidMessageStars
                self.suggestedPost = suggestedPost
                self.scheduleRepeatPeriod = scheduleRepeatPeriod
                self.summaryFromLanguage = summaryFromLanguage
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("message", [("flags", ConstructorParameterDescription(self.flags)), ("flags2", ConstructorParameterDescription(self.flags2)), ("id", ConstructorParameterDescription(self.id)), ("fromId", ConstructorParameterDescription(self.fromId)), ("fromBoostsApplied", ConstructorParameterDescription(self.fromBoostsApplied)), ("fromRank", ConstructorParameterDescription(self.fromRank)), ("peerId", ConstructorParameterDescription(self.peerId)), ("savedPeerId", ConstructorParameterDescription(self.savedPeerId)), ("fwdFrom", ConstructorParameterDescription(self.fwdFrom)), ("viaBotId", ConstructorParameterDescription(self.viaBotId)), ("viaBusinessBotId", ConstructorParameterDescription(self.viaBusinessBotId)), ("replyTo", ConstructorParameterDescription(self.replyTo)), ("date", ConstructorParameterDescription(self.date)), ("message", ConstructorParameterDescription(self.message)), ("media", ConstructorParameterDescription(self.media)), ("replyMarkup", ConstructorParameterDescription(self.replyMarkup)), ("entities", ConstructorParameterDescription(self.entities)), ("views", ConstructorParameterDescription(self.views)), ("forwards", ConstructorParameterDescription(self.forwards)), ("replies", ConstructorParameterDescription(self.replies)), ("editDate", ConstructorParameterDescription(self.editDate)), ("postAuthor", ConstructorParameterDescription(self.postAuthor)), ("groupedId", ConstructorParameterDescription(self.groupedId)), ("reactions", ConstructorParameterDescription(self.reactions)), ("restrictionReason", ConstructorParameterDescription(self.restrictionReason)), ("ttlPeriod", ConstructorParameterDescription(self.ttlPeriod)), ("quickReplyShortcutId", ConstructorParameterDescription(self.quickReplyShortcutId)), ("effect", ConstructorParameterDescription(self.effect)), ("factcheck", ConstructorParameterDescription(self.factcheck)), ("reportDeliveryUntilDate", ConstructorParameterDescription(self.reportDeliveryUntilDate)), ("paidMessageStars", ConstructorParameterDescription(self.paidMessageStars)), ("suggestedPost", ConstructorParameterDescription(self.suggestedPost)), ("scheduleRepeatPeriod", ConstructorParameterDescription(self.scheduleRepeatPeriod)), ("summaryFromLanguage", ConstructorParameterDescription(self.summaryFromLanguage))])
            }
        }
        public class Cons_messageEmpty: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var peerId: Api.Peer?
            public init(flags: Int32, id: Int32, peerId: Api.Peer?) {
                self.flags = flags
                self.id = id
                self.peerId = peerId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageEmpty", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("peerId", ConstructorParameterDescription(self.peerId))])
            }
        }
        public class Cons_messageService: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var fromId: Api.Peer?
            public var peerId: Api.Peer
            public var savedPeerId: Api.Peer?
            public var replyTo: Api.MessageReplyHeader?
            public var date: Int32
            public var action: Api.MessageAction
            public var reactions: Api.MessageReactions?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, savedPeerId: Api.Peer?, replyTo: Api.MessageReplyHeader?, date: Int32, action: Api.MessageAction, reactions: Api.MessageReactions?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.peerId = peerId
                self.savedPeerId = savedPeerId
                self.replyTo = replyTo
                self.date = date
                self.action = action
                self.reactions = reactions
                self.ttlPeriod = ttlPeriod
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageService", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("fromId", ConstructorParameterDescription(self.fromId)), ("peerId", ConstructorParameterDescription(self.peerId)), ("savedPeerId", ConstructorParameterDescription(self.savedPeerId)), ("replyTo", ConstructorParameterDescription(self.replyTo)), ("date", ConstructorParameterDescription(self.date)), ("action", ConstructorParameterDescription(self.action)), ("reactions", ConstructorParameterDescription(self.reactions)), ("ttlPeriod", ConstructorParameterDescription(self.ttlPeriod))])
            }
        }
        case message(Cons_message)
        case messageEmpty(Cons_messageEmpty)
        case messageService(Cons_messageService)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .message(let _data):
                if boxed {
                    buffer.appendInt32(988112002)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.flags2, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 29) != 0 {
                    serializeInt32(_data.fromBoostsApplied!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 12) != 0 {
                    serializeString(_data.fromRank!, buffer: buffer, boxed: false)
                }
                _data.peerId.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 28) != 0 {
                    _data.savedPeerId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.fwdFrom!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt64(_data.viaBotId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 0) != 0 {
                    serializeInt64(_data.viaBusinessBotId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.replyTo!.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.media!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.views!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.forwards!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 23) != 0 {
                    _data.replies!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.editDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.postAuthor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    serializeInt64(_data.groupedId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    _data.reactions!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 22) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.restrictionReason!.count))
                    for item in _data.restrictionReason! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 30) != 0 {
                    serializeInt32(_data.quickReplyShortcutId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 2) != 0 {
                    serializeInt64(_data.effect!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 3) != 0 {
                    _data.factcheck!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 5) != 0 {
                    serializeInt32(_data.reportDeliveryUntilDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 6) != 0 {
                    serializeInt64(_data.paidMessageStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 7) != 0 {
                    _data.suggestedPost!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 10) != 0 {
                    serializeInt32(_data.scheduleRepeatPeriod!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 11) != 0 {
                    serializeString(_data.summaryFromLanguage!, buffer: buffer, boxed: false)
                }
                break
            case .messageEmpty(let _data):
                if boxed {
                    buffer.appendInt32(-1868117372)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.peerId!.serialize(buffer, true)
                }
                break
            case .messageService(let _data):
                if boxed {
                    buffer.appendInt32(2055212554)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                _data.peerId.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 28) != 0 {
                    _data.savedPeerId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.replyTo!.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.action.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    _data.reactions!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .message(let _data):
                return ("message", [("flags", ConstructorParameterDescription(_data.flags)), ("flags2", ConstructorParameterDescription(_data.flags2)), ("id", ConstructorParameterDescription(_data.id)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("fromBoostsApplied", ConstructorParameterDescription(_data.fromBoostsApplied)), ("fromRank", ConstructorParameterDescription(_data.fromRank)), ("peerId", ConstructorParameterDescription(_data.peerId)), ("savedPeerId", ConstructorParameterDescription(_data.savedPeerId)), ("fwdFrom", ConstructorParameterDescription(_data.fwdFrom)), ("viaBotId", ConstructorParameterDescription(_data.viaBotId)), ("viaBusinessBotId", ConstructorParameterDescription(_data.viaBusinessBotId)), ("replyTo", ConstructorParameterDescription(_data.replyTo)), ("date", ConstructorParameterDescription(_data.date)), ("message", ConstructorParameterDescription(_data.message)), ("media", ConstructorParameterDescription(_data.media)), ("replyMarkup", ConstructorParameterDescription(_data.replyMarkup)), ("entities", ConstructorParameterDescription(_data.entities)), ("views", ConstructorParameterDescription(_data.views)), ("forwards", ConstructorParameterDescription(_data.forwards)), ("replies", ConstructorParameterDescription(_data.replies)), ("editDate", ConstructorParameterDescription(_data.editDate)), ("postAuthor", ConstructorParameterDescription(_data.postAuthor)), ("groupedId", ConstructorParameterDescription(_data.groupedId)), ("reactions", ConstructorParameterDescription(_data.reactions)), ("restrictionReason", ConstructorParameterDescription(_data.restrictionReason)), ("ttlPeriod", ConstructorParameterDescription(_data.ttlPeriod)), ("quickReplyShortcutId", ConstructorParameterDescription(_data.quickReplyShortcutId)), ("effect", ConstructorParameterDescription(_data.effect)), ("factcheck", ConstructorParameterDescription(_data.factcheck)), ("reportDeliveryUntilDate", ConstructorParameterDescription(_data.reportDeliveryUntilDate)), ("paidMessageStars", ConstructorParameterDescription(_data.paidMessageStars)), ("suggestedPost", ConstructorParameterDescription(_data.suggestedPost)), ("scheduleRepeatPeriod", ConstructorParameterDescription(_data.scheduleRepeatPeriod)), ("summaryFromLanguage", ConstructorParameterDescription(_data.summaryFromLanguage))])
            case .messageEmpty(let _data):
                return ("messageEmpty", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("peerId", ConstructorParameterDescription(_data.peerId))])
            case .messageService(let _data):
                return ("messageService", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("peerId", ConstructorParameterDescription(_data.peerId)), ("savedPeerId", ConstructorParameterDescription(_data.savedPeerId)), ("replyTo", ConstructorParameterDescription(_data.replyTo)), ("date", ConstructorParameterDescription(_data.date)), ("action", ConstructorParameterDescription(_data.action)), ("reactions", ConstructorParameterDescription(_data.reactions)), ("ttlPeriod", ConstructorParameterDescription(_data.ttlPeriod))])
            }
        }

        public static func parse_message(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 29) != 0 {
                _5 = reader.readInt32()
            }
            var _6: String?
            if Int(_2!) & Int(1 << 12) != 0 {
                _6 = parseString(reader)
            }
            var _7: Api.Peer?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _8: Api.Peer?
            if Int(_1!) & Int(1 << 28) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _9: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
                }
            }
            var _10: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {
                _10 = reader.readInt64()
            }
            var _11: Int64?
            if Int(_2!) & Int(1 << 0) != 0 {
                _11 = reader.readInt64()
            }
            var _12: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
                }
            }
            var _13: Int32?
            _13 = reader.readInt32()
            var _14: String?
            _14 = parseString(reader)
            var _15: Api.MessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.MessageMedia
                }
            }
            var _16: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _16 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            var _17: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let _ = reader.readInt32() {
                    _17 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _18: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _18 = reader.readInt32()
            }
            var _19: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _19 = reader.readInt32()
            }
            var _20: Api.MessageReplies?
            if Int(_1!) & Int(1 << 23) != 0 {
                if let signature = reader.readInt32() {
                    _20 = Api.parse(reader, signature: signature) as? Api.MessageReplies
                }
            }
            var _21: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {
                _21 = reader.readInt32()
            }
            var _22: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _22 = parseString(reader)
            }
            var _23: Int64?
            if Int(_1!) & Int(1 << 17) != 0 {
                _23 = reader.readInt64()
            }
            var _24: Api.MessageReactions?
            if Int(_1!) & Int(1 << 20) != 0 {
                if let signature = reader.readInt32() {
                    _24 = Api.parse(reader, signature: signature) as? Api.MessageReactions
                }
            }
            var _25: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 22) != 0 {
                if let _ = reader.readInt32() {
                    _25 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
                }
            }
            var _26: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {
                _26 = reader.readInt32()
            }
            var _27: Int32?
            if Int(_1!) & Int(1 << 30) != 0 {
                _27 = reader.readInt32()
            }
            var _28: Int64?
            if Int(_2!) & Int(1 << 2) != 0 {
                _28 = reader.readInt64()
            }
            var _29: Api.FactCheck?
            if Int(_2!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _29 = Api.parse(reader, signature: signature) as? Api.FactCheck
                }
            }
            var _30: Int32?
            if Int(_2!) & Int(1 << 5) != 0 {
                _30 = reader.readInt32()
            }
            var _31: Int64?
            if Int(_2!) & Int(1 << 6) != 0 {
                _31 = reader.readInt64()
            }
            var _32: Api.SuggestedPost?
            if Int(_2!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _32 = Api.parse(reader, signature: signature) as? Api.SuggestedPost
                }
            }
            var _33: Int32?
            if Int(_2!) & Int(1 << 10) != 0 {
                _33 = reader.readInt32()
            }
            var _34: String?
            if Int(_2!) & Int(1 << 11) != 0 {
                _34 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 8) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 29) == 0) || _5 != nil
            let _c6 = (Int(_2!) & Int(1 << 12) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 28) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            let _c11 = (Int(_2!) & Int(1 << 0) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 3) == 0) || _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 9) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 6) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 7) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 10) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 10) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 23) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 15) == 0) || _21 != nil
            let _c22 = (Int(_1!) & Int(1 << 16) == 0) || _22 != nil
            let _c23 = (Int(_1!) & Int(1 << 17) == 0) || _23 != nil
            let _c24 = (Int(_1!) & Int(1 << 20) == 0) || _24 != nil
            let _c25 = (Int(_1!) & Int(1 << 22) == 0) || _25 != nil
            let _c26 = (Int(_1!) & Int(1 << 25) == 0) || _26 != nil
            let _c27 = (Int(_1!) & Int(1 << 30) == 0) || _27 != nil
            let _c28 = (Int(_2!) & Int(1 << 2) == 0) || _28 != nil
            let _c29 = (Int(_2!) & Int(1 << 3) == 0) || _29 != nil
            let _c30 = (Int(_2!) & Int(1 << 5) == 0) || _30 != nil
            let _c31 = (Int(_2!) & Int(1 << 6) == 0) || _31 != nil
            let _c32 = (Int(_2!) & Int(1 << 7) == 0) || _32 != nil
            let _c33 = (Int(_2!) & Int(1 << 10) == 0) || _33 != nil
            let _c34 = (Int(_2!) & Int(1 << 11) == 0) || _34 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 && _c34 {
                return Api.Message.message(Cons_message(flags: _1!, flags2: _2!, id: _3!, fromId: _4, fromBoostsApplied: _5, fromRank: _6, peerId: _7!, savedPeerId: _8, fwdFrom: _9, viaBotId: _10, viaBusinessBotId: _11, replyTo: _12, date: _13!, message: _14!, media: _15, replyMarkup: _16, entities: _17, views: _18, forwards: _19, replies: _20, editDate: _21, postAuthor: _22, groupedId: _23, reactions: _24, restrictionReason: _25, ttlPeriod: _26, quickReplyShortcutId: _27, effect: _28, factcheck: _29, reportDeliveryUntilDate: _30, paidMessageStars: _31, suggestedPost: _32, scheduleRepeatPeriod: _33, summaryFromLanguage: _34))
            }
            else {
                return nil
            }
        }
        public static func parse_messageEmpty(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Message.messageEmpty(Cons_messageEmpty(flags: _1!, id: _2!, peerId: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_messageService(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.Peer?
            if Int(_1!) & Int(1 << 28) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _6: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
                }
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.MessageAction?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.MessageAction
            }
            var _9: Api.MessageReactions?
            if Int(_1!) & Int(1 << 20) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.MessageReactions
                }
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {
                _10 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 28) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 20) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 25) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.Message.messageService(Cons_messageService(flags: _1!, id: _2!, fromId: _3, peerId: _4!, savedPeerId: _5, replyTo: _6, date: _7!, action: _8!, reactions: _9, ttlPeriod: _10))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum MessageAction: TypeConstructorDescription {
        public class Cons_messageActionBoostApply: TypeConstructorDescription {
            public var boosts: Int32
            public init(boosts: Int32) {
                self.boosts = boosts
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionBoostApply", [("boosts", ConstructorParameterDescription(self.boosts))])
            }
        }
        public class Cons_messageActionBotAllowed: TypeConstructorDescription {
            public var flags: Int32
            public var domain: String?
            public var app: Api.BotApp?
            public init(flags: Int32, domain: String?, app: Api.BotApp?) {
                self.flags = flags
                self.domain = domain
                self.app = app
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionBotAllowed", [("flags", ConstructorParameterDescription(self.flags)), ("domain", ConstructorParameterDescription(self.domain)), ("app", ConstructorParameterDescription(self.app))])
            }
        }
        public class Cons_messageActionChangeCreator: TypeConstructorDescription {
            public var newCreatorId: Int64
            public init(newCreatorId: Int64) {
                self.newCreatorId = newCreatorId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChangeCreator", [("newCreatorId", ConstructorParameterDescription(self.newCreatorId))])
            }
        }
        public class Cons_messageActionChannelCreate: TypeConstructorDescription {
            public var title: String
            public init(title: String) {
                self.title = title
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChannelCreate", [("title", ConstructorParameterDescription(self.title))])
            }
        }
        public class Cons_messageActionChannelMigrateFrom: TypeConstructorDescription {
            public var title: String
            public var chatId: Int64
            public init(title: String, chatId: Int64) {
                self.title = title
                self.chatId = chatId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChannelMigrateFrom", [("title", ConstructorParameterDescription(self.title)), ("chatId", ConstructorParameterDescription(self.chatId))])
            }
        }
        public class Cons_messageActionChatAddUser: TypeConstructorDescription {
            public var users: [Int64]
            public init(users: [Int64]) {
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChatAddUser", [("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_messageActionChatCreate: TypeConstructorDescription {
            public var title: String
            public var users: [Int64]
            public init(title: String, users: [Int64]) {
                self.title = title
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChatCreate", [("title", ConstructorParameterDescription(self.title)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_messageActionChatDeleteUser: TypeConstructorDescription {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChatDeleteUser", [("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        public class Cons_messageActionChatEditPhoto: TypeConstructorDescription {
            public var photo: Api.Photo
            public init(photo: Api.Photo) {
                self.photo = photo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChatEditPhoto", [("photo", ConstructorParameterDescription(self.photo))])
            }
        }
        public class Cons_messageActionChatEditTitle: TypeConstructorDescription {
            public var title: String
            public init(title: String) {
                self.title = title
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChatEditTitle", [("title", ConstructorParameterDescription(self.title))])
            }
        }
        public class Cons_messageActionChatJoinedByLink: TypeConstructorDescription {
            public var inviterId: Int64
            public init(inviterId: Int64) {
                self.inviterId = inviterId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChatJoinedByLink", [("inviterId", ConstructorParameterDescription(self.inviterId))])
            }
        }
        public class Cons_messageActionChatMigrateTo: TypeConstructorDescription {
            public var channelId: Int64
            public init(channelId: Int64) {
                self.channelId = channelId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionChatMigrateTo", [("channelId", ConstructorParameterDescription(self.channelId))])
            }
        }
        public class Cons_messageActionConferenceCall: TypeConstructorDescription {
            public var flags: Int32
            public var callId: Int64
            public var duration: Int32?
            public var otherParticipants: [Api.Peer]?
            public init(flags: Int32, callId: Int64, duration: Int32?, otherParticipants: [Api.Peer]?) {
                self.flags = flags
                self.callId = callId
                self.duration = duration
                self.otherParticipants = otherParticipants
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionConferenceCall", [("flags", ConstructorParameterDescription(self.flags)), ("callId", ConstructorParameterDescription(self.callId)), ("duration", ConstructorParameterDescription(self.duration)), ("otherParticipants", ConstructorParameterDescription(self.otherParticipants))])
            }
        }
        public class Cons_messageActionCustomAction: TypeConstructorDescription {
            public var message: String
            public init(message: String) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionCustomAction", [("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_messageActionGameScore: TypeConstructorDescription {
            public var gameId: Int64
            public var score: Int32
            public init(gameId: Int64, score: Int32) {
                self.gameId = gameId
                self.score = score
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGameScore", [("gameId", ConstructorParameterDescription(self.gameId)), ("score", ConstructorParameterDescription(self.score))])
            }
        }
        public class Cons_messageActionGeoProximityReached: TypeConstructorDescription {
            public var fromId: Api.Peer
            public var toId: Api.Peer
            public var distance: Int32
            public init(fromId: Api.Peer, toId: Api.Peer, distance: Int32) {
                self.fromId = fromId
                self.toId = toId
                self.distance = distance
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGeoProximityReached", [("fromId", ConstructorParameterDescription(self.fromId)), ("toId", ConstructorParameterDescription(self.toId)), ("distance", ConstructorParameterDescription(self.distance))])
            }
        }
        public class Cons_messageActionGiftCode: TypeConstructorDescription {
            public var flags: Int32
            public var boostPeer: Api.Peer?
            public var days: Int32
            public var slug: String
            public var currency: String?
            public var amount: Int64?
            public var cryptoCurrency: String?
            public var cryptoAmount: Int64?
            public var message: Api.TextWithEntities?
            public init(flags: Int32, boostPeer: Api.Peer?, days: Int32, slug: String, currency: String?, amount: Int64?, cryptoCurrency: String?, cryptoAmount: Int64?, message: Api.TextWithEntities?) {
                self.flags = flags
                self.boostPeer = boostPeer
                self.days = days
                self.slug = slug
                self.currency = currency
                self.amount = amount
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGiftCode", [("flags", ConstructorParameterDescription(self.flags)), ("boostPeer", ConstructorParameterDescription(self.boostPeer)), ("days", ConstructorParameterDescription(self.days)), ("slug", ConstructorParameterDescription(self.slug)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("cryptoCurrency", ConstructorParameterDescription(self.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(self.cryptoAmount)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_messageActionGiftPremium: TypeConstructorDescription {
            public var flags: Int32
            public var currency: String
            public var amount: Int64
            public var days: Int32
            public var cryptoCurrency: String?
            public var cryptoAmount: Int64?
            public var message: Api.TextWithEntities?
            public init(flags: Int32, currency: String, amount: Int64, days: Int32, cryptoCurrency: String?, cryptoAmount: Int64?, message: Api.TextWithEntities?) {
                self.flags = flags
                self.currency = currency
                self.amount = amount
                self.days = days
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGiftPremium", [("flags", ConstructorParameterDescription(self.flags)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("days", ConstructorParameterDescription(self.days)), ("cryptoCurrency", ConstructorParameterDescription(self.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(self.cryptoAmount)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_messageActionGiftStars: TypeConstructorDescription {
            public var flags: Int32
            public var currency: String
            public var amount: Int64
            public var stars: Int64
            public var cryptoCurrency: String?
            public var cryptoAmount: Int64?
            public var transactionId: String?
            public init(flags: Int32, currency: String, amount: Int64, stars: Int64, cryptoCurrency: String?, cryptoAmount: Int64?, transactionId: String?) {
                self.flags = flags
                self.currency = currency
                self.amount = amount
                self.stars = stars
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.transactionId = transactionId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGiftStars", [("flags", ConstructorParameterDescription(self.flags)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("stars", ConstructorParameterDescription(self.stars)), ("cryptoCurrency", ConstructorParameterDescription(self.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(self.cryptoAmount)), ("transactionId", ConstructorParameterDescription(self.transactionId))])
            }
        }
        public class Cons_messageActionGiftTon: TypeConstructorDescription {
            public var flags: Int32
            public var currency: String
            public var amount: Int64
            public var cryptoCurrency: String
            public var cryptoAmount: Int64
            public var transactionId: String?
            public init(flags: Int32, currency: String, amount: Int64, cryptoCurrency: String, cryptoAmount: Int64, transactionId: String?) {
                self.flags = flags
                self.currency = currency
                self.amount = amount
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.transactionId = transactionId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGiftTon", [("flags", ConstructorParameterDescription(self.flags)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("cryptoCurrency", ConstructorParameterDescription(self.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(self.cryptoAmount)), ("transactionId", ConstructorParameterDescription(self.transactionId))])
            }
        }
        public class Cons_messageActionGiveawayLaunch: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64?
            public init(flags: Int32, stars: Int64?) {
                self.flags = flags
                self.stars = stars
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGiveawayLaunch", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars))])
            }
        }
        public class Cons_messageActionGiveawayResults: TypeConstructorDescription {
            public var flags: Int32
            public var winnersCount: Int32
            public var unclaimedCount: Int32
            public init(flags: Int32, winnersCount: Int32, unclaimedCount: Int32) {
                self.flags = flags
                self.winnersCount = winnersCount
                self.unclaimedCount = unclaimedCount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGiveawayResults", [("flags", ConstructorParameterDescription(self.flags)), ("winnersCount", ConstructorParameterDescription(self.winnersCount)), ("unclaimedCount", ConstructorParameterDescription(self.unclaimedCount))])
            }
        }
        public class Cons_messageActionGroupCall: TypeConstructorDescription {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public var duration: Int32?
            public init(flags: Int32, call: Api.InputGroupCall, duration: Int32?) {
                self.flags = flags
                self.call = call
                self.duration = duration
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGroupCall", [("flags", ConstructorParameterDescription(self.flags)), ("call", ConstructorParameterDescription(self.call)), ("duration", ConstructorParameterDescription(self.duration))])
            }
        }
        public class Cons_messageActionGroupCallScheduled: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public var scheduleDate: Int32
            public init(call: Api.InputGroupCall, scheduleDate: Int32) {
                self.call = call
                self.scheduleDate = scheduleDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionGroupCallScheduled", [("call", ConstructorParameterDescription(self.call)), ("scheduleDate", ConstructorParameterDescription(self.scheduleDate))])
            }
        }
        public class Cons_messageActionInviteToGroupCall: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public var users: [Int64]
            public init(call: Api.InputGroupCall, users: [Int64]) {
                self.call = call
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionInviteToGroupCall", [("call", ConstructorParameterDescription(self.call)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_messageActionManagedBotCreated: TypeConstructorDescription {
            public var botId: Int64
            public init(botId: Int64) {
                self.botId = botId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionManagedBotCreated", [("botId", ConstructorParameterDescription(self.botId))])
            }
        }
        public class Cons_messageActionNewCreatorPending: TypeConstructorDescription {
            public var newCreatorId: Int64
            public init(newCreatorId: Int64) {
                self.newCreatorId = newCreatorId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionNewCreatorPending", [("newCreatorId", ConstructorParameterDescription(self.newCreatorId))])
            }
        }
        public class Cons_messageActionNoForwardsRequest: TypeConstructorDescription {
            public var flags: Int32
            public var prevValue: Api.Bool
            public var newValue: Api.Bool
            public init(flags: Int32, prevValue: Api.Bool, newValue: Api.Bool) {
                self.flags = flags
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionNoForwardsRequest", [("flags", ConstructorParameterDescription(self.flags)), ("prevValue", ConstructorParameterDescription(self.prevValue)), ("newValue", ConstructorParameterDescription(self.newValue))])
            }
        }
        public class Cons_messageActionNoForwardsToggle: TypeConstructorDescription {
            public var prevValue: Api.Bool
            public var newValue: Api.Bool
            public init(prevValue: Api.Bool, newValue: Api.Bool) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionNoForwardsToggle", [("prevValue", ConstructorParameterDescription(self.prevValue)), ("newValue", ConstructorParameterDescription(self.newValue))])
            }
        }
        public class Cons_messageActionPaidMessagesPrice: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64
            public init(flags: Int32, stars: Int64) {
                self.flags = flags
                self.stars = stars
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPaidMessagesPrice", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars))])
            }
        }
        public class Cons_messageActionPaidMessagesRefunded: TypeConstructorDescription {
            public var count: Int32
            public var stars: Int64
            public init(count: Int32, stars: Int64) {
                self.count = count
                self.stars = stars
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPaidMessagesRefunded", [("count", ConstructorParameterDescription(self.count)), ("stars", ConstructorParameterDescription(self.stars))])
            }
        }
        public class Cons_messageActionPaymentRefunded: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var currency: String
            public var totalAmount: Int64
            public var payload: Buffer?
            public var charge: Api.PaymentCharge
            public init(flags: Int32, peer: Api.Peer, currency: String, totalAmount: Int64, payload: Buffer?, charge: Api.PaymentCharge) {
                self.flags = flags
                self.peer = peer
                self.currency = currency
                self.totalAmount = totalAmount
                self.payload = payload
                self.charge = charge
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPaymentRefunded", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("currency", ConstructorParameterDescription(self.currency)), ("totalAmount", ConstructorParameterDescription(self.totalAmount)), ("payload", ConstructorParameterDescription(self.payload)), ("charge", ConstructorParameterDescription(self.charge))])
            }
        }
        public class Cons_messageActionPaymentSent: TypeConstructorDescription {
            public var flags: Int32
            public var currency: String
            public var totalAmount: Int64
            public var invoiceSlug: String?
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, currency: String, totalAmount: Int64, invoiceSlug: String?, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.currency = currency
                self.totalAmount = totalAmount
                self.invoiceSlug = invoiceSlug
                self.subscriptionUntilDate = subscriptionUntilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPaymentSent", [("flags", ConstructorParameterDescription(self.flags)), ("currency", ConstructorParameterDescription(self.currency)), ("totalAmount", ConstructorParameterDescription(self.totalAmount)), ("invoiceSlug", ConstructorParameterDescription(self.invoiceSlug)), ("subscriptionUntilDate", ConstructorParameterDescription(self.subscriptionUntilDate))])
            }
        }
        public class Cons_messageActionPaymentSentMe: TypeConstructorDescription {
            public var flags: Int32
            public var currency: String
            public var totalAmount: Int64
            public var payload: Buffer
            public var info: Api.PaymentRequestedInfo?
            public var shippingOptionId: String?
            public var charge: Api.PaymentCharge
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, currency: String, totalAmount: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, charge: Api.PaymentCharge, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.currency = currency
                self.totalAmount = totalAmount
                self.payload = payload
                self.info = info
                self.shippingOptionId = shippingOptionId
                self.charge = charge
                self.subscriptionUntilDate = subscriptionUntilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPaymentSentMe", [("flags", ConstructorParameterDescription(self.flags)), ("currency", ConstructorParameterDescription(self.currency)), ("totalAmount", ConstructorParameterDescription(self.totalAmount)), ("payload", ConstructorParameterDescription(self.payload)), ("info", ConstructorParameterDescription(self.info)), ("shippingOptionId", ConstructorParameterDescription(self.shippingOptionId)), ("charge", ConstructorParameterDescription(self.charge)), ("subscriptionUntilDate", ConstructorParameterDescription(self.subscriptionUntilDate))])
            }
        }
        public class Cons_messageActionPhoneCall: TypeConstructorDescription {
            public var flags: Int32
            public var callId: Int64
            public var reason: Api.PhoneCallDiscardReason?
            public var duration: Int32?
            public init(flags: Int32, callId: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?) {
                self.flags = flags
                self.callId = callId
                self.reason = reason
                self.duration = duration
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPhoneCall", [("flags", ConstructorParameterDescription(self.flags)), ("callId", ConstructorParameterDescription(self.callId)), ("reason", ConstructorParameterDescription(self.reason)), ("duration", ConstructorParameterDescription(self.duration))])
            }
        }
        public class Cons_messageActionPollAppendAnswer: TypeConstructorDescription {
            public var answer: Api.PollAnswer
            public init(answer: Api.PollAnswer) {
                self.answer = answer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPollAppendAnswer", [("answer", ConstructorParameterDescription(self.answer))])
            }
        }
        public class Cons_messageActionPollDeleteAnswer: TypeConstructorDescription {
            public var answer: Api.PollAnswer
            public init(answer: Api.PollAnswer) {
                self.answer = answer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPollDeleteAnswer", [("answer", ConstructorParameterDescription(self.answer))])
            }
        }
        public class Cons_messageActionPrizeStars: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64
            public var transactionId: String
            public var boostPeer: Api.Peer
            public var giveawayMsgId: Int32
            public init(flags: Int32, stars: Int64, transactionId: String, boostPeer: Api.Peer, giveawayMsgId: Int32) {
                self.flags = flags
                self.stars = stars
                self.transactionId = transactionId
                self.boostPeer = boostPeer
                self.giveawayMsgId = giveawayMsgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionPrizeStars", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars)), ("transactionId", ConstructorParameterDescription(self.transactionId)), ("boostPeer", ConstructorParameterDescription(self.boostPeer)), ("giveawayMsgId", ConstructorParameterDescription(self.giveawayMsgId))])
            }
        }
        public class Cons_messageActionRequestedPeer: TypeConstructorDescription {
            public var buttonId: Int32
            public var peers: [Api.Peer]
            public init(buttonId: Int32, peers: [Api.Peer]) {
                self.buttonId = buttonId
                self.peers = peers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionRequestedPeer", [("buttonId", ConstructorParameterDescription(self.buttonId)), ("peers", ConstructorParameterDescription(self.peers))])
            }
        }
        public class Cons_messageActionRequestedPeerSentMe: TypeConstructorDescription {
            public var buttonId: Int32
            public var peers: [Api.RequestedPeer]
            public init(buttonId: Int32, peers: [Api.RequestedPeer]) {
                self.buttonId = buttonId
                self.peers = peers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionRequestedPeerSentMe", [("buttonId", ConstructorParameterDescription(self.buttonId)), ("peers", ConstructorParameterDescription(self.peers))])
            }
        }
        public class Cons_messageActionSecureValuesSent: TypeConstructorDescription {
            public var types: [Api.SecureValueType]
            public init(types: [Api.SecureValueType]) {
                self.types = types
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSecureValuesSent", [("types", ConstructorParameterDescription(self.types))])
            }
        }
        public class Cons_messageActionSecureValuesSentMe: TypeConstructorDescription {
            public var values: [Api.SecureValue]
            public var credentials: Api.SecureCredentialsEncrypted
            public init(values: [Api.SecureValue], credentials: Api.SecureCredentialsEncrypted) {
                self.values = values
                self.credentials = credentials
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSecureValuesSentMe", [("values", ConstructorParameterDescription(self.values)), ("credentials", ConstructorParameterDescription(self.credentials))])
            }
        }
        public class Cons_messageActionSetChatTheme: TypeConstructorDescription {
            public var theme: Api.ChatTheme
            public init(theme: Api.ChatTheme) {
                self.theme = theme
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSetChatTheme", [("theme", ConstructorParameterDescription(self.theme))])
            }
        }
        public class Cons_messageActionSetChatWallPaper: TypeConstructorDescription {
            public var flags: Int32
            public var wallpaper: Api.WallPaper
            public init(flags: Int32, wallpaper: Api.WallPaper) {
                self.flags = flags
                self.wallpaper = wallpaper
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSetChatWallPaper", [("flags", ConstructorParameterDescription(self.flags)), ("wallpaper", ConstructorParameterDescription(self.wallpaper))])
            }
        }
        public class Cons_messageActionSetMessagesTTL: TypeConstructorDescription {
            public var flags: Int32
            public var period: Int32
            public var autoSettingFrom: Int64?
            public init(flags: Int32, period: Int32, autoSettingFrom: Int64?) {
                self.flags = flags
                self.period = period
                self.autoSettingFrom = autoSettingFrom
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSetMessagesTTL", [("flags", ConstructorParameterDescription(self.flags)), ("period", ConstructorParameterDescription(self.period)), ("autoSettingFrom", ConstructorParameterDescription(self.autoSettingFrom))])
            }
        }
        public class Cons_messageActionStarGift: TypeConstructorDescription {
            public var flags: Int32
            public var gift: Api.StarGift
            public var message: Api.TextWithEntities?
            public var convertStars: Int64?
            public var upgradeMsgId: Int32?
            public var upgradeStars: Int64?
            public var fromId: Api.Peer?
            public var peer: Api.Peer?
            public var savedId: Int64?
            public var prepaidUpgradeHash: String?
            public var giftMsgId: Int32?
            public var toId: Api.Peer?
            public var giftNum: Int32?
            public init(flags: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, convertStars: Int64?, upgradeMsgId: Int32?, upgradeStars: Int64?, fromId: Api.Peer?, peer: Api.Peer?, savedId: Int64?, prepaidUpgradeHash: String?, giftMsgId: Int32?, toId: Api.Peer?, giftNum: Int32?) {
                self.flags = flags
                self.gift = gift
                self.message = message
                self.convertStars = convertStars
                self.upgradeMsgId = upgradeMsgId
                self.upgradeStars = upgradeStars
                self.fromId = fromId
                self.peer = peer
                self.savedId = savedId
                self.prepaidUpgradeHash = prepaidUpgradeHash
                self.giftMsgId = giftMsgId
                self.toId = toId
                self.giftNum = giftNum
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionStarGift", [("flags", ConstructorParameterDescription(self.flags)), ("gift", ConstructorParameterDescription(self.gift)), ("message", ConstructorParameterDescription(self.message)), ("convertStars", ConstructorParameterDescription(self.convertStars)), ("upgradeMsgId", ConstructorParameterDescription(self.upgradeMsgId)), ("upgradeStars", ConstructorParameterDescription(self.upgradeStars)), ("fromId", ConstructorParameterDescription(self.fromId)), ("peer", ConstructorParameterDescription(self.peer)), ("savedId", ConstructorParameterDescription(self.savedId)), ("prepaidUpgradeHash", ConstructorParameterDescription(self.prepaidUpgradeHash)), ("giftMsgId", ConstructorParameterDescription(self.giftMsgId)), ("toId", ConstructorParameterDescription(self.toId)), ("giftNum", ConstructorParameterDescription(self.giftNum))])
            }
        }
        public class Cons_messageActionStarGiftPurchaseOffer: TypeConstructorDescription {
            public var flags: Int32
            public var gift: Api.StarGift
            public var price: Api.StarsAmount
            public var expiresAt: Int32
            public init(flags: Int32, gift: Api.StarGift, price: Api.StarsAmount, expiresAt: Int32) {
                self.flags = flags
                self.gift = gift
                self.price = price
                self.expiresAt = expiresAt
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionStarGiftPurchaseOffer", [("flags", ConstructorParameterDescription(self.flags)), ("gift", ConstructorParameterDescription(self.gift)), ("price", ConstructorParameterDescription(self.price)), ("expiresAt", ConstructorParameterDescription(self.expiresAt))])
            }
        }
        public class Cons_messageActionStarGiftPurchaseOfferDeclined: TypeConstructorDescription {
            public var flags: Int32
            public var gift: Api.StarGift
            public var price: Api.StarsAmount
            public init(flags: Int32, gift: Api.StarGift, price: Api.StarsAmount) {
                self.flags = flags
                self.gift = gift
                self.price = price
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionStarGiftPurchaseOfferDeclined", [("flags", ConstructorParameterDescription(self.flags)), ("gift", ConstructorParameterDescription(self.gift)), ("price", ConstructorParameterDescription(self.price))])
            }
        }
        public class Cons_messageActionStarGiftUnique: TypeConstructorDescription {
            public var flags: Int32
            public var gift: Api.StarGift
            public var canExportAt: Int32?
            public var transferStars: Int64?
            public var fromId: Api.Peer?
            public var peer: Api.Peer?
            public var savedId: Int64?
            public var resaleAmount: Api.StarsAmount?
            public var canTransferAt: Int32?
            public var canResellAt: Int32?
            public var dropOriginalDetailsStars: Int64?
            public var canCraftAt: Int32?
            public init(flags: Int32, gift: Api.StarGift, canExportAt: Int32?, transferStars: Int64?, fromId: Api.Peer?, peer: Api.Peer?, savedId: Int64?, resaleAmount: Api.StarsAmount?, canTransferAt: Int32?, canResellAt: Int32?, dropOriginalDetailsStars: Int64?, canCraftAt: Int32?) {
                self.flags = flags
                self.gift = gift
                self.canExportAt = canExportAt
                self.transferStars = transferStars
                self.fromId = fromId
                self.peer = peer
                self.savedId = savedId
                self.resaleAmount = resaleAmount
                self.canTransferAt = canTransferAt
                self.canResellAt = canResellAt
                self.dropOriginalDetailsStars = dropOriginalDetailsStars
                self.canCraftAt = canCraftAt
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionStarGiftUnique", [("flags", ConstructorParameterDescription(self.flags)), ("gift", ConstructorParameterDescription(self.gift)), ("canExportAt", ConstructorParameterDescription(self.canExportAt)), ("transferStars", ConstructorParameterDescription(self.transferStars)), ("fromId", ConstructorParameterDescription(self.fromId)), ("peer", ConstructorParameterDescription(self.peer)), ("savedId", ConstructorParameterDescription(self.savedId)), ("resaleAmount", ConstructorParameterDescription(self.resaleAmount)), ("canTransferAt", ConstructorParameterDescription(self.canTransferAt)), ("canResellAt", ConstructorParameterDescription(self.canResellAt)), ("dropOriginalDetailsStars", ConstructorParameterDescription(self.dropOriginalDetailsStars)), ("canCraftAt", ConstructorParameterDescription(self.canCraftAt))])
            }
        }
        public class Cons_messageActionSuggestBirthday: TypeConstructorDescription {
            public var birthday: Api.Birthday
            public init(birthday: Api.Birthday) {
                self.birthday = birthday
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSuggestBirthday", [("birthday", ConstructorParameterDescription(self.birthday))])
            }
        }
        public class Cons_messageActionSuggestProfilePhoto: TypeConstructorDescription {
            public var photo: Api.Photo
            public init(photo: Api.Photo) {
                self.photo = photo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSuggestProfilePhoto", [("photo", ConstructorParameterDescription(self.photo))])
            }
        }
        public class Cons_messageActionSuggestedPostApproval: TypeConstructorDescription {
            public var flags: Int32
            public var rejectComment: String?
            public var scheduleDate: Int32?
            public var price: Api.StarsAmount?
            public init(flags: Int32, rejectComment: String?, scheduleDate: Int32?, price: Api.StarsAmount?) {
                self.flags = flags
                self.rejectComment = rejectComment
                self.scheduleDate = scheduleDate
                self.price = price
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSuggestedPostApproval", [("flags", ConstructorParameterDescription(self.flags)), ("rejectComment", ConstructorParameterDescription(self.rejectComment)), ("scheduleDate", ConstructorParameterDescription(self.scheduleDate)), ("price", ConstructorParameterDescription(self.price))])
            }
        }
        public class Cons_messageActionSuggestedPostRefund: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSuggestedPostRefund", [("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        public class Cons_messageActionSuggestedPostSuccess: TypeConstructorDescription {
            public var price: Api.StarsAmount
            public init(price: Api.StarsAmount) {
                self.price = price
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionSuggestedPostSuccess", [("price", ConstructorParameterDescription(self.price))])
            }
        }
        public class Cons_messageActionTodoAppendTasks: TypeConstructorDescription {
            public var list: [Api.TodoItem]
            public init(list: [Api.TodoItem]) {
                self.list = list
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionTodoAppendTasks", [("list", ConstructorParameterDescription(self.list))])
            }
        }
        public class Cons_messageActionTodoCompletions: TypeConstructorDescription {
            public var completed: [Int32]
            public var incompleted: [Int32]
            public init(completed: [Int32], incompleted: [Int32]) {
                self.completed = completed
                self.incompleted = incompleted
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionTodoCompletions", [("completed", ConstructorParameterDescription(self.completed)), ("incompleted", ConstructorParameterDescription(self.incompleted))])
            }
        }
        public class Cons_messageActionTopicCreate: TypeConstructorDescription {
            public var flags: Int32
            public var title: String
            public var iconColor: Int32
            public var iconEmojiId: Int64?
            public init(flags: Int32, title: String, iconColor: Int32, iconEmojiId: Int64?) {
                self.flags = flags
                self.title = title
                self.iconColor = iconColor
                self.iconEmojiId = iconEmojiId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionTopicCreate", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("iconColor", ConstructorParameterDescription(self.iconColor)), ("iconEmojiId", ConstructorParameterDescription(self.iconEmojiId))])
            }
        }
        public class Cons_messageActionTopicEdit: TypeConstructorDescription {
            public var flags: Int32
            public var title: String?
            public var iconEmojiId: Int64?
            public var closed: Api.Bool?
            public var hidden: Api.Bool?
            public init(flags: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?, hidden: Api.Bool?) {
                self.flags = flags
                self.title = title
                self.iconEmojiId = iconEmojiId
                self.closed = closed
                self.hidden = hidden
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionTopicEdit", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("iconEmojiId", ConstructorParameterDescription(self.iconEmojiId)), ("closed", ConstructorParameterDescription(self.closed)), ("hidden", ConstructorParameterDescription(self.hidden))])
            }
        }
        public class Cons_messageActionWebViewDataSent: TypeConstructorDescription {
            public var text: String
            public init(text: String) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionWebViewDataSent", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_messageActionWebViewDataSentMe: TypeConstructorDescription {
            public var text: String
            public var data: String
            public init(text: String, data: String) {
                self.text = text
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("messageActionWebViewDataSentMe", [("text", ConstructorParameterDescription(self.text)), ("data", ConstructorParameterDescription(self.data))])
            }
        }
        case messageActionBoostApply(Cons_messageActionBoostApply)
        case messageActionBotAllowed(Cons_messageActionBotAllowed)
        case messageActionChangeCreator(Cons_messageActionChangeCreator)
        case messageActionChannelCreate(Cons_messageActionChannelCreate)
        case messageActionChannelMigrateFrom(Cons_messageActionChannelMigrateFrom)
        case messageActionChatAddUser(Cons_messageActionChatAddUser)
        case messageActionChatCreate(Cons_messageActionChatCreate)
        case messageActionChatDeletePhoto
        case messageActionChatDeleteUser(Cons_messageActionChatDeleteUser)
        case messageActionChatEditPhoto(Cons_messageActionChatEditPhoto)
        case messageActionChatEditTitle(Cons_messageActionChatEditTitle)
        case messageActionChatJoinedByLink(Cons_messageActionChatJoinedByLink)
        case messageActionChatJoinedByRequest
        case messageActionChatMigrateTo(Cons_messageActionChatMigrateTo)
        case messageActionConferenceCall(Cons_messageActionConferenceCall)
        case messageActionContactSignUp
        case messageActionCustomAction(Cons_messageActionCustomAction)
        case messageActionEmpty
        case messageActionGameScore(Cons_messageActionGameScore)
        case messageActionGeoProximityReached(Cons_messageActionGeoProximityReached)
        case messageActionGiftCode(Cons_messageActionGiftCode)
        case messageActionGiftPremium(Cons_messageActionGiftPremium)
        case messageActionGiftStars(Cons_messageActionGiftStars)
        case messageActionGiftTon(Cons_messageActionGiftTon)
        case messageActionGiveawayLaunch(Cons_messageActionGiveawayLaunch)
        case messageActionGiveawayResults(Cons_messageActionGiveawayResults)
        case messageActionGroupCall(Cons_messageActionGroupCall)
        case messageActionGroupCallScheduled(Cons_messageActionGroupCallScheduled)
        case messageActionHistoryClear
        case messageActionInviteToGroupCall(Cons_messageActionInviteToGroupCall)
        case messageActionManagedBotCreated(Cons_messageActionManagedBotCreated)
        case messageActionNewCreatorPending(Cons_messageActionNewCreatorPending)
        case messageActionNoForwardsRequest(Cons_messageActionNoForwardsRequest)
        case messageActionNoForwardsToggle(Cons_messageActionNoForwardsToggle)
        case messageActionPaidMessagesPrice(Cons_messageActionPaidMessagesPrice)
        case messageActionPaidMessagesRefunded(Cons_messageActionPaidMessagesRefunded)
        case messageActionPaymentRefunded(Cons_messageActionPaymentRefunded)
        case messageActionPaymentSent(Cons_messageActionPaymentSent)
        case messageActionPaymentSentMe(Cons_messageActionPaymentSentMe)
        case messageActionPhoneCall(Cons_messageActionPhoneCall)
        case messageActionPinMessage
        case messageActionPollAppendAnswer(Cons_messageActionPollAppendAnswer)
        case messageActionPollDeleteAnswer(Cons_messageActionPollDeleteAnswer)
        case messageActionPrizeStars(Cons_messageActionPrizeStars)
        case messageActionRequestedPeer(Cons_messageActionRequestedPeer)
        case messageActionRequestedPeerSentMe(Cons_messageActionRequestedPeerSentMe)
        case messageActionScreenshotTaken
        case messageActionSecureValuesSent(Cons_messageActionSecureValuesSent)
        case messageActionSecureValuesSentMe(Cons_messageActionSecureValuesSentMe)
        case messageActionSetChatTheme(Cons_messageActionSetChatTheme)
        case messageActionSetChatWallPaper(Cons_messageActionSetChatWallPaper)
        case messageActionSetMessagesTTL(Cons_messageActionSetMessagesTTL)
        case messageActionStarGift(Cons_messageActionStarGift)
        case messageActionStarGiftPurchaseOffer(Cons_messageActionStarGiftPurchaseOffer)
        case messageActionStarGiftPurchaseOfferDeclined(Cons_messageActionStarGiftPurchaseOfferDeclined)
        case messageActionStarGiftUnique(Cons_messageActionStarGiftUnique)
        case messageActionSuggestBirthday(Cons_messageActionSuggestBirthday)
        case messageActionSuggestProfilePhoto(Cons_messageActionSuggestProfilePhoto)
        case messageActionSuggestedPostApproval(Cons_messageActionSuggestedPostApproval)
        case messageActionSuggestedPostRefund(Cons_messageActionSuggestedPostRefund)
        case messageActionSuggestedPostSuccess(Cons_messageActionSuggestedPostSuccess)
        case messageActionTodoAppendTasks(Cons_messageActionTodoAppendTasks)
        case messageActionTodoCompletions(Cons_messageActionTodoCompletions)
        case messageActionTopicCreate(Cons_messageActionTopicCreate)
        case messageActionTopicEdit(Cons_messageActionTopicEdit)
        case messageActionWebViewDataSent(Cons_messageActionWebViewDataSent)
        case messageActionWebViewDataSentMe(Cons_messageActionWebViewDataSentMe)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageActionBoostApply(let _data):
                if boxed {
                    buffer.appendInt32(-872240531)
                }
                serializeInt32(_data.boosts, buffer: buffer, boxed: false)
                break
            case .messageActionBotAllowed(let _data):
                if boxed {
                    buffer.appendInt32(-988359047)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.domain!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.app!.serialize(buffer, true)
                }
                break
            case .messageActionChangeCreator(let _data):
                if boxed {
                    buffer.appendInt32(-511160261)
                }
                serializeInt64(_data.newCreatorId, buffer: buffer, boxed: false)
                break
            case .messageActionChannelCreate(let _data):
                if boxed {
                    buffer.appendInt32(-1781355374)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                break
            case .messageActionChannelMigrateFrom(let _data):
                if boxed {
                    buffer.appendInt32(-365344535)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                break
            case .messageActionChatAddUser(let _data):
                if boxed {
                    buffer.appendInt32(365886720)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .messageActionChatCreate(let _data):
                if boxed {
                    buffer.appendInt32(-1119368275)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .messageActionChatDeletePhoto:
                if boxed {
                    buffer.appendInt32(-1780220945)
                }
                break
            case .messageActionChatDeleteUser(let _data):
                if boxed {
                    buffer.appendInt32(-1539362612)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .messageActionChatEditPhoto(let _data):
                if boxed {
                    buffer.appendInt32(2144015272)
                }
                _data.photo.serialize(buffer, true)
                break
            case .messageActionChatEditTitle(let _data):
                if boxed {
                    buffer.appendInt32(-1247687078)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                break
            case .messageActionChatJoinedByLink(let _data):
                if boxed {
                    buffer.appendInt32(51520707)
                }
                serializeInt64(_data.inviterId, buffer: buffer, boxed: false)
                break
            case .messageActionChatJoinedByRequest:
                if boxed {
                    buffer.appendInt32(-339958837)
                }
                break
            case .messageActionChatMigrateTo(let _data):
                if boxed {
                    buffer.appendInt32(-519864430)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                break
            case .messageActionConferenceCall(let _data):
                if boxed {
                    buffer.appendInt32(805187450)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.callId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.duration!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.otherParticipants!.count))
                    for item in _data.otherParticipants! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .messageActionContactSignUp:
                if boxed {
                    buffer.appendInt32(-202219658)
                }
                break
            case .messageActionCustomAction(let _data):
                if boxed {
                    buffer.appendInt32(-85549226)
                }
                serializeString(_data.message, buffer: buffer, boxed: false)
                break
            case .messageActionEmpty:
                if boxed {
                    buffer.appendInt32(-1230047312)
                }
                break
            case .messageActionGameScore(let _data):
                if boxed {
                    buffer.appendInt32(-1834538890)
                }
                serializeInt64(_data.gameId, buffer: buffer, boxed: false)
                serializeInt32(_data.score, buffer: buffer, boxed: false)
                break
            case .messageActionGeoProximityReached(let _data):
                if boxed {
                    buffer.appendInt32(-1730095465)
                }
                _data.fromId.serialize(buffer, true)
                _data.toId.serialize(buffer, true)
                serializeInt32(_data.distance, buffer: buffer, boxed: false)
                break
            case .messageActionGiftCode(let _data):
                if boxed {
                    buffer.appendInt32(834962247)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.boostPeer!.serialize(buffer, true)
                }
                serializeInt32(_data.days, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.currency!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt64(_data.amount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.cryptoCurrency!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt64(_data.cryptoAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .messageActionGiftPremium(let _data):
                if boxed {
                    buffer.appendInt32(1223234306)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeInt32(_data.days, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.cryptoCurrency!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.cryptoAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .messageActionGiftStars(let _data):
                if boxed {
                    buffer.appendInt32(1171632161)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.cryptoCurrency!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.cryptoAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.transactionId!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionGiftTon(let _data):
                if boxed {
                    buffer.appendInt32(-1465661799)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeString(_data.cryptoCurrency, buffer: buffer, boxed: false)
                serializeInt64(_data.cryptoAmount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.transactionId!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionGiveawayLaunch(let _data):
                if boxed {
                    buffer.appendInt32(-1475391004)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.stars!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionGiveawayResults(let _data):
                if boxed {
                    buffer.appendInt32(-2015170219)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.winnersCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unclaimedCount, buffer: buffer, boxed: false)
                break
            case .messageActionGroupCall(let _data):
                if boxed {
                    buffer.appendInt32(2047704898)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.call.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.duration!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionGroupCallScheduled(let _data):
                if boxed {
                    buffer.appendInt32(-1281329567)
                }
                _data.call.serialize(buffer, true)
                serializeInt32(_data.scheduleDate, buffer: buffer, boxed: false)
                break
            case .messageActionHistoryClear:
                if boxed {
                    buffer.appendInt32(-1615153660)
                }
                break
            case .messageActionInviteToGroupCall(let _data):
                if boxed {
                    buffer.appendInt32(1345295095)
                }
                _data.call.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .messageActionManagedBotCreated(let _data):
                if boxed {
                    buffer.appendInt32(375414334)
                }
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                break
            case .messageActionNewCreatorPending(let _data):
                if boxed {
                    buffer.appendInt32(-1333866363)
                }
                serializeInt64(_data.newCreatorId, buffer: buffer, boxed: false)
                break
            case .messageActionNoForwardsRequest(let _data):
                if boxed {
                    buffer.appendInt32(1042781114)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .messageActionNoForwardsToggle(let _data):
                if boxed {
                    buffer.appendInt32(-1082301070)
                }
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .messageActionPaidMessagesPrice(let _data):
                if boxed {
                    buffer.appendInt32(-2068281992)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                break
            case .messageActionPaidMessagesRefunded(let _data):
                if boxed {
                    buffer.appendInt32(-1407246387)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                break
            case .messageActionPaymentRefunded(let _data):
                if boxed {
                    buffer.appendInt32(1102307842)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.payload!, buffer: buffer, boxed: false)
                }
                _data.charge.serialize(buffer, true)
                break
            case .messageActionPaymentSent(let _data):
                if boxed {
                    buffer.appendInt32(-970673810)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.invoiceSlug!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.subscriptionUntilDate!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionPaymentSentMe(let _data):
                if boxed {
                    buffer.appendInt32(-6288180)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                serializeBytes(_data.payload, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.info!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.shippingOptionId!, buffer: buffer, boxed: false)
                }
                _data.charge.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.subscriptionUntilDate!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionPhoneCall(let _data):
                if boxed {
                    buffer.appendInt32(-2132731265)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.callId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.reason!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.duration!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionPinMessage:
                if boxed {
                    buffer.appendInt32(-1799538451)
                }
                break
            case .messageActionPollAppendAnswer(let _data):
                if boxed {
                    buffer.appendInt32(-1650340500)
                }
                _data.answer.serialize(buffer, true)
                break
            case .messageActionPollDeleteAnswer(let _data):
                if boxed {
                    buffer.appendInt32(966161628)
                }
                _data.answer.serialize(buffer, true)
                break
            case .messageActionPrizeStars(let _data):
                if boxed {
                    buffer.appendInt32(-1341372510)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                serializeString(_data.transactionId, buffer: buffer, boxed: false)
                _data.boostPeer.serialize(buffer, true)
                serializeInt32(_data.giveawayMsgId, buffer: buffer, boxed: false)
                break
            case .messageActionRequestedPeer(let _data):
                if boxed {
                    buffer.appendInt32(827428507)
                }
                serializeInt32(_data.buttonId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
                    item.serialize(buffer, true)
                }
                break
            case .messageActionRequestedPeerSentMe(let _data):
                if boxed {
                    buffer.appendInt32(-1816979384)
                }
                serializeInt32(_data.buttonId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
                    item.serialize(buffer, true)
                }
                break
            case .messageActionScreenshotTaken:
                if boxed {
                    buffer.appendInt32(1200788123)
                }
                break
            case .messageActionSecureValuesSent(let _data):
                if boxed {
                    buffer.appendInt32(-648257196)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.types.count))
                for item in _data.types {
                    item.serialize(buffer, true)
                }
                break
            case .messageActionSecureValuesSentMe(let _data):
                if boxed {
                    buffer.appendInt32(455635795)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.values.count))
                for item in _data.values {
                    item.serialize(buffer, true)
                }
                _data.credentials.serialize(buffer, true)
                break
            case .messageActionSetChatTheme(let _data):
                if boxed {
                    buffer.appendInt32(-1189364422)
                }
                _data.theme.serialize(buffer, true)
                break
            case .messageActionSetChatWallPaper(let _data):
                if boxed {
                    buffer.appendInt32(1348510708)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.wallpaper.serialize(buffer, true)
                break
            case .messageActionSetMessagesTTL(let _data):
                if boxed {
                    buffer.appendInt32(1007897979)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.period, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.autoSettingFrom!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionStarGift(let _data):
                if boxed {
                    buffer.appendInt32(-366202413)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.gift.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.convertStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.upgradeMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.upgradeStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    _data.peer!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeInt64(_data.savedId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeString(_data.prepaidUpgradeHash!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.giftMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    _data.toId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 19) != 0 {
                    serializeInt32(_data.giftNum!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionStarGiftPurchaseOffer(let _data):
                if boxed {
                    buffer.appendInt32(2000845012)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.gift.serialize(buffer, true)
                _data.price.serialize(buffer, true)
                serializeInt32(_data.expiresAt, buffer: buffer, boxed: false)
                break
            case .messageActionStarGiftPurchaseOfferDeclined(let _data):
                if boxed {
                    buffer.appendInt32(1940760427)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.gift.serialize(buffer, true)
                _data.price.serialize(buffer, true)
                break
            case .messageActionStarGiftUnique(let _data):
                if boxed {
                    buffer.appendInt32(-423422686)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.gift.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.canExportAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.transferStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    _data.peer!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt64(_data.savedId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.resaleAmount!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeInt32(_data.canTransferAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.canResellAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeInt64(_data.dropOriginalDetailsStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.canCraftAt!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionSuggestBirthday(let _data):
                if boxed {
                    buffer.appendInt32(747579941)
                }
                _data.birthday.serialize(buffer, true)
                break
            case .messageActionSuggestProfilePhoto(let _data):
                if boxed {
                    buffer.appendInt32(1474192222)
                }
                _data.photo.serialize(buffer, true)
                break
            case .messageActionSuggestedPostApproval(let _data):
                if boxed {
                    buffer.appendInt32(-293988970)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.rejectComment!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.scheduleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.price!.serialize(buffer, true)
                }
                break
            case .messageActionSuggestedPostRefund(let _data):
                if boxed {
                    buffer.appendInt32(1777932024)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .messageActionSuggestedPostSuccess(let _data):
                if boxed {
                    buffer.appendInt32(-1780625559)
                }
                _data.price.serialize(buffer, true)
                break
            case .messageActionTodoAppendTasks(let _data):
                if boxed {
                    buffer.appendInt32(-940721021)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.list.count))
                for item in _data.list {
                    item.serialize(buffer, true)
                }
                break
            case .messageActionTodoCompletions(let _data):
                if boxed {
                    buffer.appendInt32(-864265079)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.completed.count))
                for item in _data.completed {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.incompleted.count))
                for item in _data.incompleted {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .messageActionTopicCreate(let _data):
                if boxed {
                    buffer.appendInt32(228168278)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeInt32(_data.iconColor, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.iconEmojiId!, buffer: buffer, boxed: false)
                }
                break
            case .messageActionTopicEdit(let _data):
                if boxed {
                    buffer.appendInt32(-1064024032)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt64(_data.iconEmojiId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.closed!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.hidden!.serialize(buffer, true)
                }
                break
            case .messageActionWebViewDataSent(let _data):
                if boxed {
                    buffer.appendInt32(-1262252875)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .messageActionWebViewDataSentMe(let _data):
                if boxed {
                    buffer.appendInt32(1205698681)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.data, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .messageActionBoostApply(let _data):
                return ("messageActionBoostApply", [("boosts", ConstructorParameterDescription(_data.boosts))])
            case .messageActionBotAllowed(let _data):
                return ("messageActionBotAllowed", [("flags", ConstructorParameterDescription(_data.flags)), ("domain", ConstructorParameterDescription(_data.domain)), ("app", ConstructorParameterDescription(_data.app))])
            case .messageActionChangeCreator(let _data):
                return ("messageActionChangeCreator", [("newCreatorId", ConstructorParameterDescription(_data.newCreatorId))])
            case .messageActionChannelCreate(let _data):
                return ("messageActionChannelCreate", [("title", ConstructorParameterDescription(_data.title))])
            case .messageActionChannelMigrateFrom(let _data):
                return ("messageActionChannelMigrateFrom", [("title", ConstructorParameterDescription(_data.title)), ("chatId", ConstructorParameterDescription(_data.chatId))])
            case .messageActionChatAddUser(let _data):
                return ("messageActionChatAddUser", [("users", ConstructorParameterDescription(_data.users))])
            case .messageActionChatCreate(let _data):
                return ("messageActionChatCreate", [("title", ConstructorParameterDescription(_data.title)), ("users", ConstructorParameterDescription(_data.users))])
            case .messageActionChatDeletePhoto:
                return ("messageActionChatDeletePhoto", [])
            case .messageActionChatDeleteUser(let _data):
                return ("messageActionChatDeleteUser", [("userId", ConstructorParameterDescription(_data.userId))])
            case .messageActionChatEditPhoto(let _data):
                return ("messageActionChatEditPhoto", [("photo", ConstructorParameterDescription(_data.photo))])
            case .messageActionChatEditTitle(let _data):
                return ("messageActionChatEditTitle", [("title", ConstructorParameterDescription(_data.title))])
            case .messageActionChatJoinedByLink(let _data):
                return ("messageActionChatJoinedByLink", [("inviterId", ConstructorParameterDescription(_data.inviterId))])
            case .messageActionChatJoinedByRequest:
                return ("messageActionChatJoinedByRequest", [])
            case .messageActionChatMigrateTo(let _data):
                return ("messageActionChatMigrateTo", [("channelId", ConstructorParameterDescription(_data.channelId))])
            case .messageActionConferenceCall(let _data):
                return ("messageActionConferenceCall", [("flags", ConstructorParameterDescription(_data.flags)), ("callId", ConstructorParameterDescription(_data.callId)), ("duration", ConstructorParameterDescription(_data.duration)), ("otherParticipants", ConstructorParameterDescription(_data.otherParticipants))])
            case .messageActionContactSignUp:
                return ("messageActionContactSignUp", [])
            case .messageActionCustomAction(let _data):
                return ("messageActionCustomAction", [("message", ConstructorParameterDescription(_data.message))])
            case .messageActionEmpty:
                return ("messageActionEmpty", [])
            case .messageActionGameScore(let _data):
                return ("messageActionGameScore", [("gameId", ConstructorParameterDescription(_data.gameId)), ("score", ConstructorParameterDescription(_data.score))])
            case .messageActionGeoProximityReached(let _data):
                return ("messageActionGeoProximityReached", [("fromId", ConstructorParameterDescription(_data.fromId)), ("toId", ConstructorParameterDescription(_data.toId)), ("distance", ConstructorParameterDescription(_data.distance))])
            case .messageActionGiftCode(let _data):
                return ("messageActionGiftCode", [("flags", ConstructorParameterDescription(_data.flags)), ("boostPeer", ConstructorParameterDescription(_data.boostPeer)), ("days", ConstructorParameterDescription(_data.days)), ("slug", ConstructorParameterDescription(_data.slug)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("cryptoCurrency", ConstructorParameterDescription(_data.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(_data.cryptoAmount)), ("message", ConstructorParameterDescription(_data.message))])
            case .messageActionGiftPremium(let _data):
                return ("messageActionGiftPremium", [("flags", ConstructorParameterDescription(_data.flags)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("days", ConstructorParameterDescription(_data.days)), ("cryptoCurrency", ConstructorParameterDescription(_data.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(_data.cryptoAmount)), ("message", ConstructorParameterDescription(_data.message))])
            case .messageActionGiftStars(let _data):
                return ("messageActionGiftStars", [("flags", ConstructorParameterDescription(_data.flags)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("stars", ConstructorParameterDescription(_data.stars)), ("cryptoCurrency", ConstructorParameterDescription(_data.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(_data.cryptoAmount)), ("transactionId", ConstructorParameterDescription(_data.transactionId))])
            case .messageActionGiftTon(let _data):
                return ("messageActionGiftTon", [("flags", ConstructorParameterDescription(_data.flags)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("cryptoCurrency", ConstructorParameterDescription(_data.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(_data.cryptoAmount)), ("transactionId", ConstructorParameterDescription(_data.transactionId))])
            case .messageActionGiveawayLaunch(let _data):
                return ("messageActionGiveawayLaunch", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars))])
            case .messageActionGiveawayResults(let _data):
                return ("messageActionGiveawayResults", [("flags", ConstructorParameterDescription(_data.flags)), ("winnersCount", ConstructorParameterDescription(_data.winnersCount)), ("unclaimedCount", ConstructorParameterDescription(_data.unclaimedCount))])
            case .messageActionGroupCall(let _data):
                return ("messageActionGroupCall", [("flags", ConstructorParameterDescription(_data.flags)), ("call", ConstructorParameterDescription(_data.call)), ("duration", ConstructorParameterDescription(_data.duration))])
            case .messageActionGroupCallScheduled(let _data):
                return ("messageActionGroupCallScheduled", [("call", ConstructorParameterDescription(_data.call)), ("scheduleDate", ConstructorParameterDescription(_data.scheduleDate))])
            case .messageActionHistoryClear:
                return ("messageActionHistoryClear", [])
            case .messageActionInviteToGroupCall(let _data):
                return ("messageActionInviteToGroupCall", [("call", ConstructorParameterDescription(_data.call)), ("users", ConstructorParameterDescription(_data.users))])
            case .messageActionManagedBotCreated(let _data):
                return ("messageActionManagedBotCreated", [("botId", ConstructorParameterDescription(_data.botId))])
            case .messageActionNewCreatorPending(let _data):
                return ("messageActionNewCreatorPending", [("newCreatorId", ConstructorParameterDescription(_data.newCreatorId))])
            case .messageActionNoForwardsRequest(let _data):
                return ("messageActionNoForwardsRequest", [("flags", ConstructorParameterDescription(_data.flags)), ("prevValue", ConstructorParameterDescription(_data.prevValue)), ("newValue", ConstructorParameterDescription(_data.newValue))])
            case .messageActionNoForwardsToggle(let _data):
                return ("messageActionNoForwardsToggle", [("prevValue", ConstructorParameterDescription(_data.prevValue)), ("newValue", ConstructorParameterDescription(_data.newValue))])
            case .messageActionPaidMessagesPrice(let _data):
                return ("messageActionPaidMessagesPrice", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars))])
            case .messageActionPaidMessagesRefunded(let _data):
                return ("messageActionPaidMessagesRefunded", [("count", ConstructorParameterDescription(_data.count)), ("stars", ConstructorParameterDescription(_data.stars))])
            case .messageActionPaymentRefunded(let _data):
                return ("messageActionPaymentRefunded", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("currency", ConstructorParameterDescription(_data.currency)), ("totalAmount", ConstructorParameterDescription(_data.totalAmount)), ("payload", ConstructorParameterDescription(_data.payload)), ("charge", ConstructorParameterDescription(_data.charge))])
            case .messageActionPaymentSent(let _data):
                return ("messageActionPaymentSent", [("flags", ConstructorParameterDescription(_data.flags)), ("currency", ConstructorParameterDescription(_data.currency)), ("totalAmount", ConstructorParameterDescription(_data.totalAmount)), ("invoiceSlug", ConstructorParameterDescription(_data.invoiceSlug)), ("subscriptionUntilDate", ConstructorParameterDescription(_data.subscriptionUntilDate))])
            case .messageActionPaymentSentMe(let _data):
                return ("messageActionPaymentSentMe", [("flags", ConstructorParameterDescription(_data.flags)), ("currency", ConstructorParameterDescription(_data.currency)), ("totalAmount", ConstructorParameterDescription(_data.totalAmount)), ("payload", ConstructorParameterDescription(_data.payload)), ("info", ConstructorParameterDescription(_data.info)), ("shippingOptionId", ConstructorParameterDescription(_data.shippingOptionId)), ("charge", ConstructorParameterDescription(_data.charge)), ("subscriptionUntilDate", ConstructorParameterDescription(_data.subscriptionUntilDate))])
            case .messageActionPhoneCall(let _data):
                return ("messageActionPhoneCall", [("flags", ConstructorParameterDescription(_data.flags)), ("callId", ConstructorParameterDescription(_data.callId)), ("reason", ConstructorParameterDescription(_data.reason)), ("duration", ConstructorParameterDescription(_data.duration))])
            case .messageActionPinMessage:
                return ("messageActionPinMessage", [])
            case .messageActionPollAppendAnswer(let _data):
                return ("messageActionPollAppendAnswer", [("answer", ConstructorParameterDescription(_data.answer))])
            case .messageActionPollDeleteAnswer(let _data):
                return ("messageActionPollDeleteAnswer", [("answer", ConstructorParameterDescription(_data.answer))])
            case .messageActionPrizeStars(let _data):
                return ("messageActionPrizeStars", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars)), ("transactionId", ConstructorParameterDescription(_data.transactionId)), ("boostPeer", ConstructorParameterDescription(_data.boostPeer)), ("giveawayMsgId", ConstructorParameterDescription(_data.giveawayMsgId))])
            case .messageActionRequestedPeer(let _data):
                return ("messageActionRequestedPeer", [("buttonId", ConstructorParameterDescription(_data.buttonId)), ("peers", ConstructorParameterDescription(_data.peers))])
            case .messageActionRequestedPeerSentMe(let _data):
                return ("messageActionRequestedPeerSentMe", [("buttonId", ConstructorParameterDescription(_data.buttonId)), ("peers", ConstructorParameterDescription(_data.peers))])
            case .messageActionScreenshotTaken:
                return ("messageActionScreenshotTaken", [])
            case .messageActionSecureValuesSent(let _data):
                return ("messageActionSecureValuesSent", [("types", ConstructorParameterDescription(_data.types))])
            case .messageActionSecureValuesSentMe(let _data):
                return ("messageActionSecureValuesSentMe", [("values", ConstructorParameterDescription(_data.values)), ("credentials", ConstructorParameterDescription(_data.credentials))])
            case .messageActionSetChatTheme(let _data):
                return ("messageActionSetChatTheme", [("theme", ConstructorParameterDescription(_data.theme))])
            case .messageActionSetChatWallPaper(let _data):
                return ("messageActionSetChatWallPaper", [("flags", ConstructorParameterDescription(_data.flags)), ("wallpaper", ConstructorParameterDescription(_data.wallpaper))])
            case .messageActionSetMessagesTTL(let _data):
                return ("messageActionSetMessagesTTL", [("flags", ConstructorParameterDescription(_data.flags)), ("period", ConstructorParameterDescription(_data.period)), ("autoSettingFrom", ConstructorParameterDescription(_data.autoSettingFrom))])
            case .messageActionStarGift(let _data):
                return ("messageActionStarGift", [("flags", ConstructorParameterDescription(_data.flags)), ("gift", ConstructorParameterDescription(_data.gift)), ("message", ConstructorParameterDescription(_data.message)), ("convertStars", ConstructorParameterDescription(_data.convertStars)), ("upgradeMsgId", ConstructorParameterDescription(_data.upgradeMsgId)), ("upgradeStars", ConstructorParameterDescription(_data.upgradeStars)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("peer", ConstructorParameterDescription(_data.peer)), ("savedId", ConstructorParameterDescription(_data.savedId)), ("prepaidUpgradeHash", ConstructorParameterDescription(_data.prepaidUpgradeHash)), ("giftMsgId", ConstructorParameterDescription(_data.giftMsgId)), ("toId", ConstructorParameterDescription(_data.toId)), ("giftNum", ConstructorParameterDescription(_data.giftNum))])
            case .messageActionStarGiftPurchaseOffer(let _data):
                return ("messageActionStarGiftPurchaseOffer", [("flags", ConstructorParameterDescription(_data.flags)), ("gift", ConstructorParameterDescription(_data.gift)), ("price", ConstructorParameterDescription(_data.price)), ("expiresAt", ConstructorParameterDescription(_data.expiresAt))])
            case .messageActionStarGiftPurchaseOfferDeclined(let _data):
                return ("messageActionStarGiftPurchaseOfferDeclined", [("flags", ConstructorParameterDescription(_data.flags)), ("gift", ConstructorParameterDescription(_data.gift)), ("price", ConstructorParameterDescription(_data.price))])
            case .messageActionStarGiftUnique(let _data):
                return ("messageActionStarGiftUnique", [("flags", ConstructorParameterDescription(_data.flags)), ("gift", ConstructorParameterDescription(_data.gift)), ("canExportAt", ConstructorParameterDescription(_data.canExportAt)), ("transferStars", ConstructorParameterDescription(_data.transferStars)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("peer", ConstructorParameterDescription(_data.peer)), ("savedId", ConstructorParameterDescription(_data.savedId)), ("resaleAmount", ConstructorParameterDescription(_data.resaleAmount)), ("canTransferAt", ConstructorParameterDescription(_data.canTransferAt)), ("canResellAt", ConstructorParameterDescription(_data.canResellAt)), ("dropOriginalDetailsStars", ConstructorParameterDescription(_data.dropOriginalDetailsStars)), ("canCraftAt", ConstructorParameterDescription(_data.canCraftAt))])
            case .messageActionSuggestBirthday(let _data):
                return ("messageActionSuggestBirthday", [("birthday", ConstructorParameterDescription(_data.birthday))])
            case .messageActionSuggestProfilePhoto(let _data):
                return ("messageActionSuggestProfilePhoto", [("photo", ConstructorParameterDescription(_data.photo))])
            case .messageActionSuggestedPostApproval(let _data):
                return ("messageActionSuggestedPostApproval", [("flags", ConstructorParameterDescription(_data.flags)), ("rejectComment", ConstructorParameterDescription(_data.rejectComment)), ("scheduleDate", ConstructorParameterDescription(_data.scheduleDate)), ("price", ConstructorParameterDescription(_data.price))])
            case .messageActionSuggestedPostRefund(let _data):
                return ("messageActionSuggestedPostRefund", [("flags", ConstructorParameterDescription(_data.flags))])
            case .messageActionSuggestedPostSuccess(let _data):
                return ("messageActionSuggestedPostSuccess", [("price", ConstructorParameterDescription(_data.price))])
            case .messageActionTodoAppendTasks(let _data):
                return ("messageActionTodoAppendTasks", [("list", ConstructorParameterDescription(_data.list))])
            case .messageActionTodoCompletions(let _data):
                return ("messageActionTodoCompletions", [("completed", ConstructorParameterDescription(_data.completed)), ("incompleted", ConstructorParameterDescription(_data.incompleted))])
            case .messageActionTopicCreate(let _data):
                return ("messageActionTopicCreate", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("iconColor", ConstructorParameterDescription(_data.iconColor)), ("iconEmojiId", ConstructorParameterDescription(_data.iconEmojiId))])
            case .messageActionTopicEdit(let _data):
                return ("messageActionTopicEdit", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("iconEmojiId", ConstructorParameterDescription(_data.iconEmojiId)), ("closed", ConstructorParameterDescription(_data.closed)), ("hidden", ConstructorParameterDescription(_data.hidden))])
            case .messageActionWebViewDataSent(let _data):
                return ("messageActionWebViewDataSent", [("text", ConstructorParameterDescription(_data.text))])
            case .messageActionWebViewDataSentMe(let _data):
                return ("messageActionWebViewDataSentMe", [("text", ConstructorParameterDescription(_data.text)), ("data", ConstructorParameterDescription(_data.data))])
            }
        }

        public static func parse_messageActionBoostApply(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionBoostApply(Cons_messageActionBoostApply(boosts: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionBotAllowed(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: Api.BotApp?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.BotApp
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionBotAllowed(Cons_messageActionBotAllowed(flags: _1!, domain: _2, app: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChangeCreator(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChangeCreator(Cons_messageActionChangeCreator(newCreatorId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChannelCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChannelCreate(Cons_messageActionChannelCreate(title: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChannelMigrateFrom(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChannelMigrateFrom(Cons_messageActionChannelMigrateFrom(title: _1!, chatId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatAddUser(_ reader: BufferReader) -> MessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatAddUser(Cons_messageActionChatAddUser(users: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChatCreate(Cons_messageActionChatCreate(title: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatDeletePhoto(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionChatDeletePhoto
        }
        public static func parse_messageActionChatDeleteUser(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatDeleteUser(Cons_messageActionChatDeleteUser(userId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatEditPhoto(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatEditPhoto(Cons_messageActionChatEditPhoto(photo: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatEditTitle(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatEditTitle(Cons_messageActionChatEditTitle(title: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatJoinedByLink(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatJoinedByLink(Cons_messageActionChatJoinedByLink(inviterId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatJoinedByRequest(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionChatJoinedByRequest
        }
        public static func parse_messageActionChatMigrateTo(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatMigrateTo(Cons_messageActionChatMigrateTo(channelId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionConferenceCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = reader.readInt32()
            }
            var _4: [Api.Peer]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionConferenceCall(Cons_messageActionConferenceCall(flags: _1!, callId: _2!, duration: _3, otherParticipants: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionContactSignUp(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionContactSignUp
        }
        public static func parse_messageActionCustomAction(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionCustomAction(Cons_messageActionCustomAction(message: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionEmpty(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionEmpty
        }
        public static func parse_messageActionGameScore(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGameScore(Cons_messageActionGameScore(gameId: _1!, score: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGeoProximityReached(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionGeoProximityReached(Cons_messageActionGeoProximityReached(fromId: _1!, toId: _2!, distance: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGiftCode(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = reader.readInt64()
            }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _7 = parseString(reader)
            }
            var _8: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {
                _8 = reader.readInt64()
            }
            var _9: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.MessageAction.messageActionGiftCode(Cons_messageActionGiftCode(flags: _1!, boostPeer: _2, days: _3!, slug: _4!, currency: _5, amount: _6, cryptoCurrency: _7, cryptoAmount: _8, message: _9))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGiftPremium(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt64()
            }
            var _7: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MessageAction.messageActionGiftPremium(Cons_messageActionGiftPremium(flags: _1!, currency: _2!, amount: _3!, days: _4!, cryptoCurrency: _5, cryptoAmount: _6, message: _7))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGiftStars(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt64()
            }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _7 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MessageAction.messageActionGiftStars(Cons_messageActionGiftStars(flags: _1!, currency: _2!, amount: _3!, stars: _4!, cryptoCurrency: _5, cryptoAmount: _6, transactionId: _7))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGiftTon(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MessageAction.messageActionGiftTon(Cons_messageActionGiftTon(flags: _1!, currency: _2!, amount: _3!, cryptoCurrency: _4!, cryptoAmount: _5!, transactionId: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGiveawayLaunch(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGiveawayLaunch(Cons_messageActionGiveawayLaunch(flags: _1!, stars: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGiveawayResults(_ reader: BufferReader) -> MessageAction? {
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
                return Api.MessageAction.messageActionGiveawayResults(Cons_messageActionGiveawayResults(flags: _1!, winnersCount: _2!, unclaimedCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGroupCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionGroupCall(Cons_messageActionGroupCall(flags: _1!, call: _2!, duration: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGroupCallScheduled(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGroupCallScheduled(Cons_messageActionGroupCallScheduled(call: _1!, scheduleDate: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionHistoryClear(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionHistoryClear
        }
        public static func parse_messageActionInviteToGroupCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionInviteToGroupCall(Cons_messageActionInviteToGroupCall(call: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionManagedBotCreated(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionManagedBotCreated(Cons_messageActionManagedBotCreated(botId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionNewCreatorPending(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionNewCreatorPending(Cons_messageActionNewCreatorPending(newCreatorId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionNoForwardsRequest(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionNoForwardsRequest(Cons_messageActionNoForwardsRequest(flags: _1!, prevValue: _2!, newValue: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionNoForwardsToggle(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionNoForwardsToggle(Cons_messageActionNoForwardsToggle(prevValue: _1!, newValue: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaidMessagesPrice(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionPaidMessagesPrice(Cons_messageActionPaidMessagesPrice(flags: _1!, stars: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaidMessagesRefunded(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionPaidMessagesRefunded(Cons_messageActionPaidMessagesRefunded(count: _1!, stars: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentRefunded(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = parseBytes(reader)
            }
            var _6: Api.PaymentCharge?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.PaymentCharge
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MessageAction.messageActionPaymentRefunded(Cons_messageActionPaymentRefunded(flags: _1!, peer: _2!, currency: _3!, totalAmount: _4!, payload: _5, charge: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentSent(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageAction.messageActionPaymentSent(Cons_messageActionPaymentSent(flags: _1!, currency: _2!, totalAmount: _3!, invoiceSlug: _4, subscriptionUntilDate: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
                }
            }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = parseString(reader)
            }
            var _7: Api.PaymentCharge?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PaymentCharge
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.MessageAction.messageActionPaymentSentMe(Cons_messageActionPaymentSentMe(flags: _1!, currency: _2!, totalAmount: _3!, payload: _4!, info: _5, shippingOptionId: _6, charge: _7!, subscriptionUntilDate: _8))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPhoneCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PhoneCallDiscardReason?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.PhoneCallDiscardReason
                }
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionPhoneCall(Cons_messageActionPhoneCall(flags: _1!, callId: _2!, reason: _3, duration: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPinMessage(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionPinMessage
        }
        public static func parse_messageActionPollAppendAnswer(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.PollAnswer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PollAnswer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionPollAppendAnswer(Cons_messageActionPollAppendAnswer(answer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPollDeleteAnswer(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.PollAnswer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PollAnswer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionPollDeleteAnswer(Cons_messageActionPollDeleteAnswer(answer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPrizeStars(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageAction.messageActionPrizeStars(Cons_messageActionPrizeStars(flags: _1!, stars: _2!, transactionId: _3!, boostPeer: _4!, giveawayMsgId: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionRequestedPeer(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Peer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionRequestedPeer(Cons_messageActionRequestedPeer(buttonId: _1!, peers: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionRequestedPeerSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.RequestedPeer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RequestedPeer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionRequestedPeerSentMe(Cons_messageActionRequestedPeerSentMe(buttonId: _1!, peers: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionScreenshotTaken(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionScreenshotTaken
        }
        public static func parse_messageActionSecureValuesSent(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.SecureValueType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValueType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSecureValuesSent(Cons_messageActionSecureValuesSent(types: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSecureValuesSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.SecureValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
            }
            var _2: Api.SecureCredentialsEncrypted?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureCredentialsEncrypted
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionSecureValuesSentMe(Cons_messageActionSecureValuesSentMe(values: _1!, credentials: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetChatTheme(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.ChatTheme?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatTheme
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSetChatTheme(Cons_messageActionSetChatTheme(theme: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetChatWallPaper(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.WallPaper?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WallPaper
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionSetChatWallPaper(Cons_messageActionSetChatWallPaper(flags: _1!, wallpaper: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetMessagesTTL(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionSetMessagesTTL(Cons_messageActionSetMessagesTTL(flags: _1!, period: _2!, autoSettingFrom: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionStarGift(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarGift?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _3: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {
                _6 = reader.readInt64()
            }
            var _7: Api.Peer?
            if Int(_1!) & Int(1 << 11) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _8: Api.Peer?
            if Int(_1!) & Int(1 << 12) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 12) != 0 {
                _9 = reader.readInt64()
            }
            var _10: String?
            if Int(_1!) & Int(1 << 14) != 0 {
                _10 = parseString(reader)
            }
            var _11: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {
                _11 = reader.readInt32()
            }
            var _12: Api.Peer?
            if Int(_1!) & Int(1 << 18) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 19) != 0 {
                _13 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 5) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 8) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 12) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 12) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 15) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 18) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 19) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.MessageAction.messageActionStarGift(Cons_messageActionStarGift(flags: _1!, gift: _2!, message: _3, convertStars: _4, upgradeMsgId: _5, upgradeStars: _6, fromId: _7, peer: _8, savedId: _9, prepaidUpgradeHash: _10, giftMsgId: _11, toId: _12, giftNum: _13))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionStarGiftPurchaseOffer(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarGift?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _3: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionStarGiftPurchaseOffer(Cons_messageActionStarGiftPurchaseOffer(flags: _1!, gift: _2!, price: _3!, expiresAt: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionStarGiftPurchaseOfferDeclined(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarGift?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _3: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionStarGiftPurchaseOfferDeclined(Cons_messageActionStarGiftPurchaseOfferDeclined(flags: _1!, gift: _2!, price: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionStarGiftUnique(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarGift?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Api.Peer?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _6: Api.Peer?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _7: Int64?
            if Int(_1!) & Int(1 << 7) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Api.StarsAmount?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.StarsAmount
                }
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Int64?
            if Int(_1!) & Int(1 << 12) != 0 {
                _11 = reader.readInt64()
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {
                _12 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 6) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 7) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 8) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 9) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 10) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 12) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 15) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.MessageAction.messageActionStarGiftUnique(Cons_messageActionStarGiftUnique(flags: _1!, gift: _2!, canExportAt: _3, transferStars: _4, fromId: _5, peer: _6, savedId: _7, resaleAmount: _8, canTransferAt: _9, canResellAt: _10, dropOriginalDetailsStars: _11, canCraftAt: _12))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSuggestBirthday(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Birthday?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Birthday
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSuggestBirthday(Cons_messageActionSuggestBirthday(birthday: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSuggestProfilePhoto(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSuggestProfilePhoto(Cons_messageActionSuggestProfilePhoto(photo: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSuggestedPostApproval(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _2 = parseString(reader)
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.StarsAmount?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.StarsAmount
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionSuggestedPostApproval(Cons_messageActionSuggestedPostApproval(flags: _1!, rejectComment: _2, scheduleDate: _3, price: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSuggestedPostRefund(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSuggestedPostRefund(Cons_messageActionSuggestedPostRefund(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSuggestedPostSuccess(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSuggestedPostSuccess(Cons_messageActionSuggestedPostSuccess(price: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionTodoAppendTasks(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.TodoItem]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TodoItem.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionTodoAppendTasks(Cons_messageActionTodoAppendTasks(list: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionTodoCompletions(_ reader: BufferReader) -> MessageAction? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionTodoCompletions(Cons_messageActionTodoCompletions(completed: _1!, incompleted: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionTopicCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionTopicCreate(Cons_messageActionTopicCreate(flags: _1!, title: _2!, iconColor: _3!, iconEmojiId: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionTopicEdit(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt64()
            }
            var _4: Api.Bool?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _5: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageAction.messageActionTopicEdit(Cons_messageActionTopicEdit(flags: _1!, title: _2, iconEmojiId: _3, closed: _4, hidden: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionWebViewDataSent(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionWebViewDataSent(Cons_messageActionWebViewDataSent(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionWebViewDataSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionWebViewDataSentMe(Cons_messageActionWebViewDataSentMe(text: _1!, data: _2!))
            }
            else {
                return nil
            }
        }
    }
}
