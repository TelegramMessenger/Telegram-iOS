public extension Api {
    enum AccountDaysTTL: TypeConstructorDescription {
        case accountDaysTTL(days: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .accountDaysTTL(let days):
                    if boxed {
                        buffer.appendInt32(-1194283041)
                    }
                    serializeInt32(days, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .accountDaysTTL(let days):
                return ("accountDaysTTL", [("days", days as Any)])
    }
    }
    
        public static func parse_accountDaysTTL(_ reader: BufferReader) -> AccountDaysTTL? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.AccountDaysTTL.accountDaysTTL(days: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AppWebViewResult: TypeConstructorDescription {
        case appWebViewResultUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .appWebViewResultUrl(let url):
                    if boxed {
                        buffer.appendInt32(1008422669)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .appWebViewResultUrl(let url):
                return ("appWebViewResultUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_appWebViewResultUrl(_ reader: BufferReader) -> AppWebViewResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.AppWebViewResult.appWebViewResultUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AttachMenuBot: TypeConstructorDescription {
        case attachMenuBot(flags: Int32, botId: Int64, shortName: String, peerTypes: [Api.AttachMenuPeerType]?, icons: [Api.AttachMenuBotIcon])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .attachMenuBot(let flags, let botId, let shortName, let peerTypes, let icons):
                    if boxed {
                        buffer.appendInt32(-653423106)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peerTypes!.count))
                    for item in peerTypes! {
                        item.serialize(buffer, true)
                    }}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(icons.count))
                    for item in icons {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .attachMenuBot(let flags, let botId, let shortName, let peerTypes, let icons):
                return ("attachMenuBot", [("flags", flags as Any), ("botId", botId as Any), ("shortName", shortName as Any), ("peerTypes", peerTypes as Any), ("icons", icons as Any)])
    }
    }
    
        public static func parse_attachMenuBot(_ reader: BufferReader) -> AttachMenuBot? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.AttachMenuPeerType]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuPeerType.self)
            } }
            var _5: [Api.AttachMenuBotIcon]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuBotIcon.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.AttachMenuBot.attachMenuBot(flags: _1!, botId: _2!, shortName: _3!, peerTypes: _4, icons: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AttachMenuBotIcon: TypeConstructorDescription {
        case attachMenuBotIcon(flags: Int32, name: String, icon: Api.Document, colors: [Api.AttachMenuBotIconColor]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .attachMenuBotIcon(let flags, let name, let icon, let colors):
                    if boxed {
                        buffer.appendInt32(-1297663893)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    icon.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(colors!.count))
                    for item in colors! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .attachMenuBotIcon(let flags, let name, let icon, let colors):
                return ("attachMenuBotIcon", [("flags", flags as Any), ("name", name as Any), ("icon", icon as Any), ("colors", colors as Any)])
    }
    }
    
        public static func parse_attachMenuBotIcon(_ reader: BufferReader) -> AttachMenuBotIcon? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Document?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _4: [Api.AttachMenuBotIconColor]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuBotIconColor.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.AttachMenuBotIcon.attachMenuBotIcon(flags: _1!, name: _2!, icon: _3!, colors: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AttachMenuBotIconColor: TypeConstructorDescription {
        case attachMenuBotIconColor(name: String, color: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .attachMenuBotIconColor(let name, let color):
                    if boxed {
                        buffer.appendInt32(1165423600)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeInt32(color, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .attachMenuBotIconColor(let name, let color):
                return ("attachMenuBotIconColor", [("name", name as Any), ("color", color as Any)])
    }
    }
    
        public static func parse_attachMenuBotIconColor(_ reader: BufferReader) -> AttachMenuBotIconColor? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.AttachMenuBotIconColor.attachMenuBotIconColor(name: _1!, color: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AttachMenuBots: TypeConstructorDescription {
        case attachMenuBots(hash: Int64, bots: [Api.AttachMenuBot], users: [Api.User])
        case attachMenuBotsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .attachMenuBots(let hash, let bots, let users):
                    if boxed {
                        buffer.appendInt32(1011024320)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(bots.count))
                    for item in bots {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .attachMenuBotsNotModified:
                    if boxed {
                        buffer.appendInt32(-237467044)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .attachMenuBots(let hash, let bots, let users):
                return ("attachMenuBots", [("hash", hash as Any), ("bots", bots as Any), ("users", users as Any)])
                case .attachMenuBotsNotModified:
                return ("attachMenuBotsNotModified", [])
    }
    }
    
        public static func parse_attachMenuBots(_ reader: BufferReader) -> AttachMenuBots? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.AttachMenuBot]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuBot.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.AttachMenuBots.attachMenuBots(hash: _1!, bots: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_attachMenuBotsNotModified(_ reader: BufferReader) -> AttachMenuBots? {
            return Api.AttachMenuBots.attachMenuBotsNotModified
        }
    
    }
}
public extension Api {
    enum AttachMenuBotsBot: TypeConstructorDescription {
        case attachMenuBotsBot(bot: Api.AttachMenuBot, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .attachMenuBotsBot(let bot, let users):
                    if boxed {
                        buffer.appendInt32(-1816172929)
                    }
                    bot.serialize(buffer, true)
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
                case .attachMenuBotsBot(let bot, let users):
                return ("attachMenuBotsBot", [("bot", bot as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_attachMenuBotsBot(_ reader: BufferReader) -> AttachMenuBotsBot? {
            var _1: Api.AttachMenuBot?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.AttachMenuBot
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.AttachMenuBotsBot.attachMenuBotsBot(bot: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AttachMenuPeerType: TypeConstructorDescription {
        case attachMenuPeerTypeBotPM
        case attachMenuPeerTypeBroadcast
        case attachMenuPeerTypeChat
        case attachMenuPeerTypePM
        case attachMenuPeerTypeSameBotPM
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .attachMenuPeerTypeBotPM:
                    if boxed {
                        buffer.appendInt32(-1020528102)
                    }
                    
                    break
                case .attachMenuPeerTypeBroadcast:
                    if boxed {
                        buffer.appendInt32(2080104188)
                    }
                    
                    break
                case .attachMenuPeerTypeChat:
                    if boxed {
                        buffer.appendInt32(84480319)
                    }
                    
                    break
                case .attachMenuPeerTypePM:
                    if boxed {
                        buffer.appendInt32(-247016673)
                    }
                    
                    break
                case .attachMenuPeerTypeSameBotPM:
                    if boxed {
                        buffer.appendInt32(2104224014)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .attachMenuPeerTypeBotPM:
                return ("attachMenuPeerTypeBotPM", [])
                case .attachMenuPeerTypeBroadcast:
                return ("attachMenuPeerTypeBroadcast", [])
                case .attachMenuPeerTypeChat:
                return ("attachMenuPeerTypeChat", [])
                case .attachMenuPeerTypePM:
                return ("attachMenuPeerTypePM", [])
                case .attachMenuPeerTypeSameBotPM:
                return ("attachMenuPeerTypeSameBotPM", [])
    }
    }
    
        public static func parse_attachMenuPeerTypeBotPM(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeBotPM
        }
        public static func parse_attachMenuPeerTypeBroadcast(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeBroadcast
        }
        public static func parse_attachMenuPeerTypeChat(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeChat
        }
        public static func parse_attachMenuPeerTypePM(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypePM
        }
        public static func parse_attachMenuPeerTypeSameBotPM(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeSameBotPM
        }
    
    }
}
public extension Api {
    enum Authorization: TypeConstructorDescription {
        case authorization(flags: Int32, hash: Int64, deviceModel: String, platform: String, systemVersion: String, apiId: Int32, appName: String, appVersion: String, dateCreated: Int32, dateActive: Int32, ip: String, country: String, region: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorization(let flags, let hash, let deviceModel, let platform, let systemVersion, let apiId, let appName, let appVersion, let dateCreated, let dateActive, let ip, let country, let region):
                    if boxed {
                        buffer.appendInt32(-1392388579)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    serializeString(deviceModel, buffer: buffer, boxed: false)
                    serializeString(platform, buffer: buffer, boxed: false)
                    serializeString(systemVersion, buffer: buffer, boxed: false)
                    serializeInt32(apiId, buffer: buffer, boxed: false)
                    serializeString(appName, buffer: buffer, boxed: false)
                    serializeString(appVersion, buffer: buffer, boxed: false)
                    serializeInt32(dateCreated, buffer: buffer, boxed: false)
                    serializeInt32(dateActive, buffer: buffer, boxed: false)
                    serializeString(ip, buffer: buffer, boxed: false)
                    serializeString(country, buffer: buffer, boxed: false)
                    serializeString(region, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorization(let flags, let hash, let deviceModel, let platform, let systemVersion, let apiId, let appName, let appVersion, let dateCreated, let dateActive, let ip, let country, let region):
                return ("authorization", [("flags", flags as Any), ("hash", hash as Any), ("deviceModel", deviceModel as Any), ("platform", platform as Any), ("systemVersion", systemVersion as Any), ("apiId", apiId as Any), ("appName", appName as Any), ("appVersion", appVersion as Any), ("dateCreated", dateCreated as Any), ("dateActive", dateActive as Any), ("ip", ip as Any), ("country", country as Any), ("region", region as Any)])
    }
    }
    
        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            _7 = parseString(reader)
            var _8: String?
            _8 = parseString(reader)
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: String?
            _11 = parseString(reader)
            var _12: String?
            _12 = parseString(reader)
            var _13: String?
            _13 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.Authorization.authorization(flags: _1!, hash: _2!, deviceModel: _3!, platform: _4!, systemVersion: _5!, apiId: _6!, appName: _7!, appVersion: _8!, dateCreated: _9!, dateActive: _10!, ip: _11!, country: _12!, region: _13!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AutoDownloadSettings: TypeConstructorDescription {
        case autoDownloadSettings(flags: Int32, photoSizeMax: Int32, videoSizeMax: Int64, fileSizeMax: Int64, videoUploadMaxbitrate: Int32, smallQueueActiveOperationsMax: Int32, largeQueueActiveOperationsMax: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoDownloadSettings(let flags, let photoSizeMax, let videoSizeMax, let fileSizeMax, let videoUploadMaxbitrate, let smallQueueActiveOperationsMax, let largeQueueActiveOperationsMax):
                    if boxed {
                        buffer.appendInt32(-1163561432)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(photoSizeMax, buffer: buffer, boxed: false)
                    serializeInt64(videoSizeMax, buffer: buffer, boxed: false)
                    serializeInt64(fileSizeMax, buffer: buffer, boxed: false)
                    serializeInt32(videoUploadMaxbitrate, buffer: buffer, boxed: false)
                    serializeInt32(smallQueueActiveOperationsMax, buffer: buffer, boxed: false)
                    serializeInt32(largeQueueActiveOperationsMax, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .autoDownloadSettings(let flags, let photoSizeMax, let videoSizeMax, let fileSizeMax, let videoUploadMaxbitrate, let smallQueueActiveOperationsMax, let largeQueueActiveOperationsMax):
                return ("autoDownloadSettings", [("flags", flags as Any), ("photoSizeMax", photoSizeMax as Any), ("videoSizeMax", videoSizeMax as Any), ("fileSizeMax", fileSizeMax as Any), ("videoUploadMaxbitrate", videoUploadMaxbitrate as Any), ("smallQueueActiveOperationsMax", smallQueueActiveOperationsMax as Any), ("largeQueueActiveOperationsMax", largeQueueActiveOperationsMax as Any)])
    }
    }
    
        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.AutoDownloadSettings.autoDownloadSettings(flags: _1!, photoSizeMax: _2!, videoSizeMax: _3!, fileSizeMax: _4!, videoUploadMaxbitrate: _5!, smallQueueActiveOperationsMax: _6!, largeQueueActiveOperationsMax: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AutoSaveException: TypeConstructorDescription {
        case autoSaveException(peer: Api.Peer, settings: Api.AutoSaveSettings)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoSaveException(let peer, let settings):
                    if boxed {
                        buffer.appendInt32(-2124403385)
                    }
                    peer.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .autoSaveException(let peer, let settings):
                return ("autoSaveException", [("peer", peer as Any), ("settings", settings as Any)])
    }
    }
    
        public static func parse_autoSaveException(_ reader: BufferReader) -> AutoSaveException? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.AutoSaveSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.AutoSaveSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.AutoSaveException.autoSaveException(peer: _1!, settings: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AutoSaveSettings: TypeConstructorDescription {
        case autoSaveSettings(flags: Int32, videoMaxSize: Int64?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoSaveSettings(let flags, let videoMaxSize):
                    if boxed {
                        buffer.appendInt32(-934791986)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(videoMaxSize!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .autoSaveSettings(let flags, let videoMaxSize):
                return ("autoSaveSettings", [("flags", flags as Any), ("videoMaxSize", videoMaxSize as Any)])
    }
    }
    
        public static func parse_autoSaveSettings(_ reader: BufferReader) -> AutoSaveSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_2 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.AutoSaveSettings.autoSaveSettings(flags: _1!, videoMaxSize: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum AvailableReaction: TypeConstructorDescription {
        case availableReaction(flags: Int32, reaction: String, title: String, staticIcon: Api.Document, appearAnimation: Api.Document, selectAnimation: Api.Document, activateAnimation: Api.Document, effectAnimation: Api.Document, aroundAnimation: Api.Document?, centerIcon: Api.Document?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .availableReaction(let flags, let reaction, let title, let staticIcon, let appearAnimation, let selectAnimation, let activateAnimation, let effectAnimation, let aroundAnimation, let centerIcon):
                    if boxed {
                        buffer.appendInt32(-1065882623)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(reaction, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    staticIcon.serialize(buffer, true)
                    appearAnimation.serialize(buffer, true)
                    selectAnimation.serialize(buffer, true)
                    activateAnimation.serialize(buffer, true)
                    effectAnimation.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {aroundAnimation!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {centerIcon!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .availableReaction(let flags, let reaction, let title, let staticIcon, let appearAnimation, let selectAnimation, let activateAnimation, let effectAnimation, let aroundAnimation, let centerIcon):
                return ("availableReaction", [("flags", flags as Any), ("reaction", reaction as Any), ("title", title as Any), ("staticIcon", staticIcon as Any), ("appearAnimation", appearAnimation as Any), ("selectAnimation", selectAnimation as Any), ("activateAnimation", activateAnimation as Any), ("effectAnimation", effectAnimation as Any), ("aroundAnimation", aroundAnimation as Any), ("centerIcon", centerIcon as Any)])
    }
    }
    
        public static func parse_availableReaction(_ reader: BufferReader) -> AvailableReaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Document?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _5: Api.Document?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _6: Api.Document?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _7: Api.Document?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _8: Api.Document?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _9: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _10: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.AvailableReaction.availableReaction(flags: _1!, reaction: _2!, title: _3!, staticIcon: _4!, appearAnimation: _5!, selectAnimation: _6!, activateAnimation: _7!, effectAnimation: _8!, aroundAnimation: _9, centerIcon: _10)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BankCardOpenUrl: TypeConstructorDescription {
        case bankCardOpenUrl(url: String, name: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .bankCardOpenUrl(let url, let name):
                    if boxed {
                        buffer.appendInt32(-177732982)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .bankCardOpenUrl(let url, let name):
                return ("bankCardOpenUrl", [("url", url as Any), ("name", name as Any)])
    }
    }
    
        public static func parse_bankCardOpenUrl(_ reader: BufferReader) -> BankCardOpenUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BankCardOpenUrl.bankCardOpenUrl(url: _1!, name: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BaseTheme: TypeConstructorDescription {
        case baseThemeArctic
        case baseThemeClassic
        case baseThemeDay
        case baseThemeNight
        case baseThemeTinted
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .baseThemeArctic:
                    if boxed {
                        buffer.appendInt32(1527845466)
                    }
                    
                    break
                case .baseThemeClassic:
                    if boxed {
                        buffer.appendInt32(-1012849566)
                    }
                    
                    break
                case .baseThemeDay:
                    if boxed {
                        buffer.appendInt32(-69724536)
                    }
                    
                    break
                case .baseThemeNight:
                    if boxed {
                        buffer.appendInt32(-1212997976)
                    }
                    
                    break
                case .baseThemeTinted:
                    if boxed {
                        buffer.appendInt32(1834973166)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .baseThemeArctic:
                return ("baseThemeArctic", [])
                case .baseThemeClassic:
                return ("baseThemeClassic", [])
                case .baseThemeDay:
                return ("baseThemeDay", [])
                case .baseThemeNight:
                return ("baseThemeNight", [])
                case .baseThemeTinted:
                return ("baseThemeTinted", [])
    }
    }
    
        public static func parse_baseThemeArctic(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeArctic
        }
        public static func parse_baseThemeClassic(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeClassic
        }
        public static func parse_baseThemeDay(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeDay
        }
        public static func parse_baseThemeNight(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeNight
        }
        public static func parse_baseThemeTinted(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeTinted
        }
    
    }
}
public extension Api {
    enum Bool: TypeConstructorDescription {
        case boolFalse
        case boolTrue
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .boolFalse:
                    if boxed {
                        buffer.appendInt32(-1132882121)
                    }
                    
                    break
                case .boolTrue:
                    if boxed {
                        buffer.appendInt32(-1720552011)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .boolFalse:
                return ("boolFalse", [])
                case .boolTrue:
                return ("boolTrue", [])
    }
    }
    
        public static func parse_boolFalse(_ reader: BufferReader) -> Bool? {
            return Api.Bool.boolFalse
        }
        public static func parse_boolTrue(_ reader: BufferReader) -> Bool? {
            return Api.Bool.boolTrue
        }
    
    }
}
public extension Api {
    enum BotApp: TypeConstructorDescription {
        case botApp(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?, hash: Int64)
        case botAppNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botApp(let flags, let id, let accessHash, let shortName, let title, let description, let photo, let document, let hash):
                    if boxed {
                        buffer.appendInt32(-1778593322)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {document!.serialize(buffer, true)}
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    break
                case .botAppNotModified:
                    if boxed {
                        buffer.appendInt32(1571189943)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botApp(let flags, let id, let accessHash, let shortName, let title, let description, let photo, let document, let hash):
                return ("botApp", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("shortName", shortName as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("document", document as Any), ("hash", hash as Any)])
                case .botAppNotModified:
                return ("botAppNotModified", [])
    }
    }
    
        public static func parse_botApp(_ reader: BufferReader) -> BotApp? {
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
            var _6: String?
            _6 = parseString(reader)
            var _7: Api.Photo?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _8: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _9: Int64?
            _9 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.BotApp.botApp(flags: _1!, id: _2!, accessHash: _3!, shortName: _4!, title: _5!, description: _6!, photo: _7!, document: _8, hash: _9!)
            }
            else {
                return nil
            }
        }
        public static func parse_botAppNotModified(_ reader: BufferReader) -> BotApp? {
            return Api.BotApp.botAppNotModified
        }
    
    }
}
public extension Api {
    enum BotCommand: TypeConstructorDescription {
        case botCommand(command: String, description: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botCommand(let command, let description):
                    if boxed {
                        buffer.appendInt32(-1032140601)
                    }
                    serializeString(command, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botCommand(let command, let description):
                return ("botCommand", [("command", command as Any), ("description", description as Any)])
    }
    }
    
        public static func parse_botCommand(_ reader: BufferReader) -> BotCommand? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BotCommand.botCommand(command: _1!, description: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum BotCommandScope: TypeConstructorDescription {
        case botCommandScopeChatAdmins
        case botCommandScopeChats
        case botCommandScopeDefault
        case botCommandScopePeer(peer: Api.InputPeer)
        case botCommandScopePeerAdmins(peer: Api.InputPeer)
        case botCommandScopePeerUser(peer: Api.InputPeer, userId: Api.InputUser)
        case botCommandScopeUsers
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botCommandScopeChatAdmins:
                    if boxed {
                        buffer.appendInt32(-1180016534)
                    }
                    
                    break
                case .botCommandScopeChats:
                    if boxed {
                        buffer.appendInt32(1877059713)
                    }
                    
                    break
                case .botCommandScopeDefault:
                    if boxed {
                        buffer.appendInt32(795652779)
                    }
                    
                    break
                case .botCommandScopePeer(let peer):
                    if boxed {
                        buffer.appendInt32(-610432643)
                    }
                    peer.serialize(buffer, true)
                    break
                case .botCommandScopePeerAdmins(let peer):
                    if boxed {
                        buffer.appendInt32(1071145937)
                    }
                    peer.serialize(buffer, true)
                    break
                case .botCommandScopePeerUser(let peer, let userId):
                    if boxed {
                        buffer.appendInt32(169026035)
                    }
                    peer.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    break
                case .botCommandScopeUsers:
                    if boxed {
                        buffer.appendInt32(1011811544)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botCommandScopeChatAdmins:
                return ("botCommandScopeChatAdmins", [])
                case .botCommandScopeChats:
                return ("botCommandScopeChats", [])
                case .botCommandScopeDefault:
                return ("botCommandScopeDefault", [])
                case .botCommandScopePeer(let peer):
                return ("botCommandScopePeer", [("peer", peer as Any)])
                case .botCommandScopePeerAdmins(let peer):
                return ("botCommandScopePeerAdmins", [("peer", peer as Any)])
                case .botCommandScopePeerUser(let peer, let userId):
                return ("botCommandScopePeerUser", [("peer", peer as Any), ("userId", userId as Any)])
                case .botCommandScopeUsers:
                return ("botCommandScopeUsers", [])
    }
    }
    
        public static func parse_botCommandScopeChatAdmins(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeChatAdmins
        }
        public static func parse_botCommandScopeChats(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeChats
        }
        public static func parse_botCommandScopeDefault(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeDefault
        }
        public static func parse_botCommandScopePeer(_ reader: BufferReader) -> BotCommandScope? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.BotCommandScope.botCommandScopePeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_botCommandScopePeerAdmins(_ reader: BufferReader) -> BotCommandScope? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.BotCommandScope.botCommandScopePeerAdmins(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_botCommandScopePeerUser(_ reader: BufferReader) -> BotCommandScope? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Api.InputUser?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BotCommandScope.botCommandScopePeerUser(peer: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_botCommandScopeUsers(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeUsers
        }
    
    }
}
