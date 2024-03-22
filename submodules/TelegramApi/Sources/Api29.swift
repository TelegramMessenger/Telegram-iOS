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
        case promoData(flags: Int32, expires: Int32, peer: Api.Peer, chats: [Api.Chat], users: [Api.User], psaType: String?, psaMessage: String?)
        case promoDataEmpty(expires: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .promoData(let flags, let expires, let peer, let chats, let users, let psaType, let psaMessage):
                    if boxed {
                        buffer.appendInt32(-1942390465)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
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
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(psaType!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(psaMessage!, buffer: buffer, boxed: false)}
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
                case .promoData(let flags, let expires, let peer, let chats, let users, let psaType, let psaMessage):
                return ("promoData", [("flags", flags as Any), ("expires", expires as Any), ("peer", peer as Any), ("chats", chats as Any), ("users", users as Any), ("psaType", psaType as Any), ("psaMessage", psaMessage as Any)])
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
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.help.PromoData.promoData(flags: _1!, expires: _2!, peer: _3!, chats: _4!, users: _5!, psaType: _6, psaMessage: _7)
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
public extension Api.messages {
    enum AllStickers: TypeConstructorDescription {
        case allStickers(hash: Int64, sets: [Api.StickerSet])
        case allStickersNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .allStickers(let hash, let sets):
                    if boxed {
                        buffer.appendInt32(-843329861)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sets.count))
                    for item in sets {
                        item.serialize(buffer, true)
                    }
                    break
                case .allStickersNotModified:
                    if boxed {
                        buffer.appendInt32(-395967805)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .allStickers(let hash, let sets):
                return ("allStickers", [("hash", hash as Any), ("sets", sets as Any)])
                case .allStickersNotModified:
                return ("allStickersNotModified", [])
    }
    }
    
        public static func parse_allStickers(_ reader: BufferReader) -> AllStickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StickerSet]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSet.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.AllStickers.allStickers(hash: _1!, sets: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_allStickersNotModified(_ reader: BufferReader) -> AllStickers? {
            return Api.messages.AllStickers.allStickersNotModified
        }
    
    }
}
public extension Api.messages {
    enum ArchivedStickers: TypeConstructorDescription {
        case archivedStickers(count: Int32, sets: [Api.StickerSetCovered])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .archivedStickers(let count, let sets):
                    if boxed {
                        buffer.appendInt32(1338747336)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sets.count))
                    for item in sets {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .archivedStickers(let count, let sets):
                return ("archivedStickers", [("count", count as Any), ("sets", sets as Any)])
    }
    }
    
        public static func parse_archivedStickers(_ reader: BufferReader) -> ArchivedStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.ArchivedStickers.archivedStickers(count: _1!, sets: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum AvailableReactions: TypeConstructorDescription {
        case availableReactions(hash: Int32, reactions: [Api.AvailableReaction])
        case availableReactionsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .availableReactions(let hash, let reactions):
                    if boxed {
                        buffer.appendInt32(1989032621)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reactions.count))
                    for item in reactions {
                        item.serialize(buffer, true)
                    }
                    break
                case .availableReactionsNotModified:
                    if boxed {
                        buffer.appendInt32(-1626924713)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .availableReactions(let hash, let reactions):
                return ("availableReactions", [("hash", hash as Any), ("reactions", reactions as Any)])
                case .availableReactionsNotModified:
                return ("availableReactionsNotModified", [])
    }
    }
    
        public static func parse_availableReactions(_ reader: BufferReader) -> AvailableReactions? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.AvailableReaction]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AvailableReaction.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.AvailableReactions.availableReactions(hash: _1!, reactions: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_availableReactionsNotModified(_ reader: BufferReader) -> AvailableReactions? {
            return Api.messages.AvailableReactions.availableReactionsNotModified
        }
    
    }
}
public extension Api.messages {
    enum BotApp: TypeConstructorDescription {
        case botApp(flags: Int32, app: Api.BotApp)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botApp(let flags, let app):
                    if boxed {
                        buffer.appendInt32(-347034123)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    app.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botApp(let flags, let app):
                return ("botApp", [("flags", flags as Any), ("app", app as Any)])
    }
    }
    
        public static func parse_botApp(_ reader: BufferReader) -> BotApp? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BotApp?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BotApp
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.BotApp.botApp(flags: _1!, app: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum BotCallbackAnswer: TypeConstructorDescription {
        case botCallbackAnswer(flags: Int32, message: String?, url: String?, cacheTime: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botCallbackAnswer(let flags, let message, let url, let cacheTime):
                    if boxed {
                        buffer.appendInt32(911761060)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(message!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    serializeInt32(cacheTime, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botCallbackAnswer(let flags, let message, let url, let cacheTime):
                return ("botCallbackAnswer", [("flags", flags as Any), ("message", message as Any), ("url", url as Any), ("cacheTime", cacheTime as Any)])
    }
    }
    
        public static func parse_botCallbackAnswer(_ reader: BufferReader) -> BotCallbackAnswer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: String?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.BotCallbackAnswer.botCallbackAnswer(flags: _1!, message: _2, url: _3, cacheTime: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum BotResults: TypeConstructorDescription {
        case botResults(flags: Int32, queryId: Int64, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, switchWebview: Api.InlineBotWebView?, results: [Api.BotInlineResult], cacheTime: Int32, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botResults(let flags, let queryId, let nextOffset, let switchPm, let switchWebview, let results, let cacheTime, let users):
                    if boxed {
                        buffer.appendInt32(-534646026)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {switchPm!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {switchWebview!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(results.count))
                    for item in results {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(cacheTime, buffer: buffer, boxed: false)
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
                case .botResults(let flags, let queryId, let nextOffset, let switchPm, let switchWebview, let results, let cacheTime, let users):
                return ("botResults", [("flags", flags as Any), ("queryId", queryId as Any), ("nextOffset", nextOffset as Any), ("switchPm", switchPm as Any), ("switchWebview", switchWebview as Any), ("results", results as Any), ("cacheTime", cacheTime as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_botResults(_ reader: BufferReader) -> BotResults? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: Api.InlineBotSwitchPM?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InlineBotSwitchPM
            } }
            var _5: Api.InlineBotWebView?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InlineBotWebView
            } }
            var _6: [Api.BotInlineResult]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInlineResult.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.messages.BotResults.botResults(flags: _1!, queryId: _2!, nextOffset: _3, switchPm: _4, switchWebview: _5, results: _6!, cacheTime: _7!, users: _8!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum ChatAdminsWithInvites: TypeConstructorDescription {
        case chatAdminsWithInvites(admins: [Api.ChatAdminWithInvites], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatAdminsWithInvites(let admins, let users):
                    if boxed {
                        buffer.appendInt32(-1231326505)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(admins.count))
                    for item in admins {
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
                case .chatAdminsWithInvites(let admins, let users):
                return ("chatAdminsWithInvites", [("admins", admins as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_chatAdminsWithInvites(_ reader: BufferReader) -> ChatAdminsWithInvites? {
            var _1: [Api.ChatAdminWithInvites]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChatAdminWithInvites.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.ChatAdminsWithInvites.chatAdminsWithInvites(admins: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
